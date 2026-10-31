// SPDX-License-Identifier: GPL-2.0-or-later
unit QueryCancel;

{$mode delphi}

// Cancels a running statement on the server with KILL QUERY over a second connection, guarded so
// that it can only ever hit the statement it was meant for (ADR-0020):
//
// - The thread that owns a connection brackets each cancellable operation with
//   BeginStatement(Ticket) / EndStatement(Ticket). Tickets are unique (NewTicket).
// - Cancel(Ticket) sends the KILL while holding the canceller's lock and only if exactly this ticket
//   is still running. The owner cannot end the ticket (and start anything else) while it is in flight.
// - If the statement ended on the server just before the KILL arrived, the kill flag may be left on
//   the idle connection. EndStatement then runs "DO 0" on the owner's connection to use it up.
// - The KILL is only sent when the second connection reaches the same server and session owner and
//   neither connection goes through a proxy (handshake thread id = CONNECTION_ID()).
// - Otherwise the caller may allow cutting the owner's socket instead, which stops nothing on the
//   server but never anything of another session.
//
// No LCL dependency, so the tests can use it directly.

interface

uses
  SysUtils, Classes, SyncObjs, myx_types, myx_public_interface;

const
  ER_QUERY_INTERRUPTED = 1317; // "Query execution was interrupted" (MySQL and MariaDB).
  CR_SERVER_GONE_ERROR = 2006; // After a cut, when nothing was being read.
  CR_SERVER_LOST = 2013;       // Lost connection during query, after a cut.

type
  TCancelResult = (
    crNotRunning,   // The ticket is not running (finished or never started); nothing was done.
    crKilled,       // KILL QUERY was sent for the ticket's statement.
    crCut,          // The owner's socket was shut down; the statement may still run on the server.
    crRefused       // The KILL was not safe and cutting was not allowed; nothing was done.
  );

  IQueryCanceller = interface
    ['{6B1E2B0C-5A0E-4E8B-9C57-0D3B8E7A2F41}']
    procedure Attach(MySQL: PMYSQL; UserConnection: TMYX_USER_CONNECTION; Embedded: Boolean);
    procedure Detach;
    function NewTicket: Int64;
    function BeginStatement(Ticket: Int64): Boolean;
    procedure EndStatement(Ticket: Int64);
    function Cancel(Ticket: Int64; AllowCut: Boolean): TCancelResult;
    function Cut(Ticket: Int64): Boolean;
    function IsRunning(Ticket: Int64): Boolean;
    function KillPossible: Boolean;
    function WasCancelled(Ticket: Int64): Boolean;
    function WasCut: Boolean;
  end;

  TQueryCanceller = class(TInterfacedObject, IQueryCanceller)
  private
    FLock: TCriticalSection;          // Guards the fields below; held while a KILL or cut is sent.
    FCancelSerial: TCriticalSection;  // One Cancel at a time (it uses FUserConnection's record).
    FMySQL: PMYSQL;
    FUserConnection: TMYX_USER_CONNECTION;
    FConnectionId: String;            // CONNECTION_ID() of FMySQL, as text.
    FIdentity: String;                // Server and session owner as seen from FMySQL.
    FKillPossible: Boolean;
    FCutPossible: Boolean;
    FNextTicket: Int64;
    FRunning: Int64;                  // Ticket between BeginStatement and EndStatement, 0 if none.
    FCancelled: Int64;                // Highest ticket a Cancel was asked for.
    FKillSent: Boolean;               // A KILL may have left the kill flag set on FMySQL.
    FCut: Boolean;                    // FMySQL's socket was shut down.
    function OpenCheckedConnection: PMYSQL;
  public
    constructor Create;
    destructor Destroy; override;

    // Owner thread, connection idle: reads the connection id and the server identity.
    procedure Attach(MySQL: PMYSQL; UserConnection: TMYX_USER_CONNECTION; Embedded: Boolean);
    // Owner thread, before the connection is closed. Afterwards nothing is sent for it any more.
    procedure Detach;

    function NewTicket: Int64;
    // Owner thread. False if the ticket (or a later one) was cancelled before it started: do not run it.
    function BeginStatement(Ticket: Int64): Boolean;
    // Owner thread, always after a successful BeginStatement, before the connection is used for
    // anything else (and before the owner releases a lock that guards the connection).
    procedure EndStatement(Ticket: Int64);
    // Any thread; blocks while the second connection is opened.
    function Cancel(Ticket: Int64; AllowCut: Boolean): TCancelResult;
    // Any thread: shut down the owner's socket if the ticket is running.
    function Cut(Ticket: Int64): Boolean;

    function IsRunning(Ticket: Int64): Boolean;
    function KillPossible: Boolean;
    function WasCancelled(Ticket: Int64): Boolean;
    function WasCut: Boolean;
  end;

  // Runs Cancel in a thread of its own, so the caller (e.g. the UI) does not wait for the second
  // connection. Holds a reference to the canceller until it is done.
  TCancelThread = class(TThread)
  private
    FCanceller: IQueryCanceller;
    FTicket: Int64;
    FAllowCut: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(const Canceller: IQueryCanceller; Ticket: Int64; AllowCut: Boolean);
  end;

procedure CancelInBackground(const Canceller: IQueryCanceller; Ticket: Int64; AllowCut: Boolean);
// True for the errors a cancelled statement ends with: interrupted by KILL, or connection lost after a cut.
function IsCancelError(ErrNo: Integer): Boolean;

//----------------------------------------------------------------------------------------------------------------------

implementation

const
  // The connection id, then the server and the session owner. Both connections must report the same
  // server and owner; the user part is the name the session logged in with, which is what
  // PROCESSLIST.USER shows.
  IdentitySQL = 'SELECT CONCAT_WS(CHAR(9), CONNECTION_ID(), @@hostname, @@port, @@server_id, ' +
    'SUBSTRING_INDEX(USER(), ''@'', 1))';
  // The same, but with the user of the target session (missing, and so a mismatch, if it is not
  // listed).
  TargetSQL = 'SELECT CONCAT_WS(CHAR(9), CONNECTION_ID(), @@hostname, @@port, @@server_id, ' +
    '(SELECT USER FROM information_schema.PROCESSLIST WHERE ID = %s))';

//----------------------------------------------------------------------------------------------------------------------

function ReadIdentity(MySQL: PMYSQL; const SQL: String; out ConnectionId, Identity: String): Boolean;

// Runs IdentitySQL or TargetSQL and splits off the connection id. Checks that it is the id the
// handshake gave this client: a proxy answers the handshake with its own id, while CONNECTION_ID()
// comes from the server behind it.

var
  Value: String;
  Tab: Integer;
  Id: Int64;

begin
  Value := myx_query_single_value(MySQL, SQL);
  Tab := Pos(#9, Value);
  ConnectionId := Copy(Value, 1, Tab - 1);
  Identity := Copy(Value, Tab + 1, MaxInt);
  Result := (Tab > 0) and TryStrToInt64(ConnectionId, Id) and (Id > 0) and
    (Cardinal(Id and $FFFFFFFF) = Cardinal(myx_get_thread_id(MySQL) and $FFFFFFFF));
end;

//----------------- TQueryCanceller ------------------------------------------------------------------------------------

constructor TQueryCanceller.Create;

begin
  inherited Create;

  FLock := TCriticalSection.Create;
  FCancelSerial := TCriticalSection.Create;
end;

//----------------------------------------------------------------------------------------------------------------------

destructor TQueryCanceller.Destroy;

begin
  FUserConnection.Free;
  FCancelSerial.Free;
  FLock.Free;

  inherited;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryCanceller.Attach(MySQL: PMYSQL; UserConnection: TMYX_USER_CONNECTION; Embedded: Boolean);

var
  ConnectionId, Identity: String;
  KillPossible: Boolean;
  Copy: TMYX_USER_CONNECTION;

begin
  KillPossible := False;
  Identity := '';
  Copy := nil;
  if Assigned(MySQL) and not Embedded and Assigned(UserConnection) then
  begin
    KillPossible := ReadIdentity(MySQL, IdentitySQL, ConnectionId, Identity);
    if KillPossible then
      Copy := TMYX_USER_CONNECTION.Create(UserConnection.get_record_pointer);
  end;

  FCancelSerial.Enter;
  try
    FLock.Enter;
    try
      FMySQL := MySQL;
      FCutPossible := Assigned(MySQL) and not Embedded;
      FKillPossible := KillPossible;
      FConnectionId := ConnectionId;
      FIdentity := Identity;
      FUserConnection.Free;
      FUserConnection := Copy;
      FRunning := 0;
      FKillSent := False;
      FCut := False;
    finally
      FLock.Leave;
    end;
  finally
    FCancelSerial.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryCanceller.Detach;

begin
  FLock.Enter;
  try
    FMySQL := nil;
    FKillPossible := False;
    FCutPossible := False;
    FRunning := 0;
    FKillSent := False;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.NewTicket: Int64;

begin
  FLock.Enter;
  try
    Inc(FNextTicket);
    Result := FNextTicket;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.BeginStatement(Ticket: Int64): Boolean;

begin
  FLock.Enter;
  try
    Result := FCancelled < Ticket;
    if Result then
      FRunning := Ticket;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TQueryCanceller.EndStatement(Ticket: Int64);

begin
  FLock.Enter;
  try
    if FRunning = Ticket then
      FRunning := 0;

    // Use up a kill flag that the KILL may have left on the idle connection, while no one else can
    // send anything on it. Its "interrupted" error is the expected outcome, any other is irrelevant.
    if FKillSent then
    begin
      FKillSent := False;
      if Assigned(FMySQL) and not FCut then
        myx_query_errno(FMySQL, 'DO 0');
    end;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.OpenCheckedConnection: PMYSQL;

// Opens the second connection and returns it if it reaches the same server and session owner as the
// owner's connection, directly. Returns nil otherwise. Called with FCancelSerial held.

var
  ConnectionId, Identity: String;
  Ok: Boolean;

begin
  Result := myx_mysql_init;
  if Result = nil then
    Exit;

  Ok := myx_connect_to_instance(FUserConnection.get_record_pointer, Result) = 0;
  Ok := Ok and ReadIdentity(Result, Format(TargetSQL, [FConnectionId]), ConnectionId, Identity);
  Ok := Ok and (Identity = FIdentity);
  if not Ok then
  begin
    myx_mysql_close(Result);
    Result := nil;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.Cancel(Ticket: Int64; AllowCut: Boolean): TCancelResult;

var
  Running, CanKill: Boolean;
  Killer: PMYSQL;

begin
  FCancelSerial.Enter;
  try
    FLock.Enter;
    try
      if FCancelled < Ticket then
        FCancelled := Ticket;
      Running := FRunning = Ticket;
      CanKill := FKillPossible;
    finally
      FLock.Leave;
    end;
    if not Running then
    begin
      Result := crNotRunning;
      Exit;
    end;

    Killer := nil;
    if CanKill then
      Killer := OpenCheckedConnection;
    try
      if Assigned(Killer) then
      begin
        FLock.Enter;
        try
          if FRunning <> Ticket then
            Result := crNotRunning
          else
          begin
            // The reply ("unknown thread" included) does not matter: either the statement is
            // interrupted, or it ended and EndStatement uses up the flag.
            myx_query_errno(Killer, 'KILL QUERY ' + FConnectionId);
            FKillSent := True;
            Result := crKilled;
          end;
        finally
          FLock.Leave;
        end;
        Exit;
      end;
    finally
      if Assigned(Killer) then
        myx_mysql_close(Killer);
    end;
  finally
    FCancelSerial.Leave;
  end;

  if AllowCut then
  begin
    if Cut(Ticket) then
      Result := crCut
    else
      Result := crNotRunning;
  end
  else
    Result := crRefused;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.Cut(Ticket: Int64): Boolean;

begin
  FLock.Enter;
  try
    if FCancelled < Ticket then
      FCancelled := Ticket;
    Result := (FRunning = Ticket) and FCutPossible and not FCut;
    if Result then
    begin
      myx_mysql_cancel(FMySQL);
      FCut := True;
    end;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.IsRunning(Ticket: Int64): Boolean;

begin
  FLock.Enter;
  try
    Result := FRunning = Ticket;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.KillPossible: Boolean;

begin
  FLock.Enter;
  try
    Result := FKillPossible;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.WasCancelled(Ticket: Int64): Boolean;

begin
  FLock.Enter;
  try
    Result := FCancelled >= Ticket;
  finally
    FLock.Leave;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function TQueryCanceller.WasCut: Boolean;

begin
  FLock.Enter;
  try
    Result := FCut;
  finally
    FLock.Leave;
  end;
end;

//----------------- TCancelThread --------------------------------------------------------------------------------------

constructor TCancelThread.Create(const Canceller: IQueryCanceller; Ticket: Int64; AllowCut: Boolean);

begin
  FCanceller := Canceller;
  FTicket := Ticket;
  FAllowCut := AllowCut;
  FreeOnTerminate := True;

  inherited Create(False);
end;

//----------------------------------------------------------------------------------------------------------------------

procedure TCancelThread.Execute;

begin
  try
    FCanceller.Cancel(FTicket, FAllowCut);
  except
    // Nothing to report to: the statement then simply runs to its end.
  end;
  FCanceller := nil;
end;

//----------------------------------------------------------------------------------------------------------------------

procedure CancelInBackground(const Canceller: IQueryCanceller; Ticket: Int64; AllowCut: Boolean);

begin
  if Assigned(Canceller) and (Ticket > 0) then
    TCancelThread.Create(Canceller, Ticket, AllowCut);
end;

//----------------------------------------------------------------------------------------------------------------------

function IsCancelError(ErrNo: Integer): Boolean;

begin
  Result := (ErrNo = ER_QUERY_INTERRUPTED) or (ErrNo = CR_SERVER_LOST) or (ErrNo = CR_SERVER_GONE_ERROR);
end;

end.
