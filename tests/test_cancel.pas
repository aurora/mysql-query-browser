{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_cancel;

{ Cancelling statements on the server (ADR-0020, app/src/QueryCancel.pas). The rule under test: the
  statement being cancelled stops, and no other statement is ever interrupted. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface,
  QueryCancel;

type
  TCancelTest = class(TTestCase)
  private
    FUserConnection: TMYX_USER_CONNECTION;
    FOwner: PMYSQL;
    FCanceller: IQueryCanceller;
    function Connect: PMYSQL;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestKillIsPossibleOnDirectConnection;
    procedure TestSleepIsCancelled;
    procedure TestCancelledUpdateIsRolledBack;
    procedure TestCancelBeforeBeginSkipsStatement;
    procedure TestCancelAfterEndDoesNothing;
    procedure TestKillOnIdleConnectionDoesNotHitNextStatement;
    procedure TestCutFreesClientButNotServer;
    procedure TestRaceNeverHitsAnotherStatement;
  end;

implementation

type
  // Runs one statement inside BeginStatement/EndStatement on the owner's connection.
  TStatementThread = class(TThread)
  private
    FMySQL: PMYSQL;
    FCanceller: IQueryCanceller;
    FTicket: Int64;
    FSQL: String;
  protected
    procedure Execute; override;
  public
    Started: Boolean;
    ErrNo: Integer;
    Elapsed: QWord;
    constructor Create(MySQL: PMYSQL; const Canceller: IQueryCanceller; Ticket: Int64; const SQL: String);
  end;

  // Runs short tickets in a loop, each followed by a statement outside any ticket that must never be interrupted.
  TRaceThread = class(TThread)
  private
    FMySQL: PMYSQL;
    FCanceller: IQueryCanceller;
    FRounds: Integer;
  protected
    procedure Execute; override;
  public
    Current: Int64;      // The ticket that is about to run or running; read by the cancelling side.
    Done: Boolean;
    Interrupted: Integer; // Statements outside a ticket that failed or were cut short.
    FirstError: String;
    constructor Create(MySQL: PMYSQL; const Canceller: IQueryCanceller; Rounds: Integer);
  end;

function Env(const Name, Default: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then
    Result := Default;
end;

{ TStatementThread }

constructor TStatementThread.Create(MySQL: PMYSQL; const Canceller: IQueryCanceller; Ticket: Int64;
  const SQL: String);
begin
  FMySQL := MySQL;
  FCanceller := Canceller;
  FTicket := Ticket;
  FSQL := SQL;
  inherited Create(False);
end;

procedure TStatementThread.Execute;
var
  StartTime: QWord;
begin
  StartTime := GetTickCount64;
  Started := FCanceller.BeginStatement(FTicket);
  if Started then
  try
    ErrNo := myx_query_errno(FMySQL, FSQL);
  finally
    FCanceller.EndStatement(FTicket);
  end;
  Elapsed := GetTickCount64 - StartTime;
end;

{ TRaceThread }

constructor TRaceThread.Create(MySQL: PMYSQL; const Canceller: IQueryCanceller; Rounds: Integer);
begin
  FMySQL := MySQL;
  FCanceller := Canceller;
  FRounds := Rounds;
  inherited Create(False);
end;

procedure TRaceThread.Execute;
var
  I: Integer;
  Ticket: Int64;
  Value: String;
begin
  for I := 1 to FRounds do
  begin
    Ticket := FCanceller.NewTicket;
    InterLockedExchange64(Current, Ticket);
    if FCanceller.BeginStatement(Ticket) then
    try
      // Short, so that the KILL often arrives just after the statement ended.
      myx_query_errno(FMySQL, 'DO SLEEP(0.002 * ' + IntToStr(I mod 5) + ')');
    finally
      FCanceller.EndStatement(Ticket);
    end;

    // Not part of any ticket: a KILL meant for the ticket must never reach this one. SLEEP returns 1
    // instead of 0 when it is interrupted.
    Value := myx_query_single_value(FMySQL, 'SELECT SLEEP(0.003)');
    if Value <> '0' then
    begin
      Inc(Interrupted);
      if FirstError = '' then
        FirstError := Format('round %d: SLEEP returned "%s", errno %d', [I, Value, myx_mysql_errno(FMySQL)]);
    end;
  end;
  Done := True;
end;

{ TCancelTest }

function TCancelTest.Connect: PMYSQL;
begin
  Result := myx_mysql_init;
  if myx_connect_to_instance(FUserConnection.get_record_pointer, Result) <> 0 then
    raise Exception.Create('connect failed: ' + myx_mysql_error(Result));
end;

procedure TCancelTest.SetUp;
begin
  FUserConnection := TMYX_USER_CONNECTION.Create('', Env('QBR_TEST_USER', 'root'),
    Env('QBR_TEST_PASSWORD', 'qbr-test'), Env('QBR_TEST_HOST', '127.0.0.1'),
    StrToInt(Env('QBR_TEST_PORT', '33306')), '', '', '', MYX_MYSQL_CONN, MYX_FAVORITE_USER_CONNECTION);
  FOwner := Connect;
  FCanceller := TQueryCanceller.Create;
  FCanceller.Attach(FOwner, FUserConnection, False);
end;

procedure TCancelTest.TearDown;
begin
  if Assigned(FCanceller) then
    FCanceller.Detach;
  FCanceller := nil;
  if Assigned(FOwner) then
    myx_mysql_close(FOwner);
  FOwner := nil;
  FreeAndNil(FUserConnection);
end;

procedure TCancelTest.TestKillIsPossibleOnDirectConnection;
begin
  AssertTrue('a direct connection to the test server allows KILL', FCanceller.KillPossible);
end;

procedure TCancelTest.TestSleepIsCancelled;
var
  Ticket: Int64;
  T: TStatementThread;
begin
  Ticket := FCanceller.NewTicket;
  T := TStatementThread.Create(FOwner, FCanceller, Ticket, 'SELECT SLEEP(30)');
  try
    Sleep(500);
    AssertEquals('KILL sent', Ord(crKilled), Ord(FCanceller.Cancel(Ticket, False)));
    T.WaitFor;
    AssertTrue('statement ran', T.Started);
    AssertTrue(Format('stopped early (%d ms)', [T.Elapsed]), T.Elapsed < 5000);
  finally
    T.Free;
  end;
  AssertEquals('connection usable afterwards', '1', myx_query_single_value(FOwner, 'SELECT 1'));
end;

procedure TCancelTest.TestCancelledUpdateIsRolledBack;
var
  Ticket: Int64;
  T: TStatementThread;
  Other: PMYSQL;
begin
  Other := Connect;
  try
    AssertEquals(0, myx_query_errno(Other, 'CREATE DATABASE IF NOT EXISTS qbr_cancel_test'));
    AssertEquals(0, myx_query_errno(Other, 'DROP TABLE IF EXISTS qbr_cancel_test.t'));
    AssertEquals(0, myx_query_errno(Other,
      'CREATE TABLE qbr_cancel_test.t (id INT PRIMARY KEY, v INT NOT NULL) ENGINE=InnoDB'));
    AssertEquals(0, myx_query_errno(Other,
      'INSERT INTO qbr_cancel_test.t VALUES (1,0),(2,0),(3,0),(4,0),(5,0),(6,0),(7,0),(8,0),(9,0),(10,0)'));

    // Autocommit: one second per row, so it would commit after 10 s.
    Ticket := FCanceller.NewTicket;
    T := TStatementThread.Create(FOwner, FCanceller, Ticket,
      'UPDATE qbr_cancel_test.t SET v = v + 1 WHERE SLEEP(1) = 0');
    try
      Sleep(2500);
      AssertEquals('KILL sent', Ord(crKilled), Ord(FCanceller.Cancel(Ticket, False)));
      T.WaitFor;
      AssertEquals('interrupted', ER_QUERY_INTERRUPTED, T.ErrNo);
      AssertTrue(Format('stopped early (%d ms)', [T.Elapsed]), T.Elapsed < 8000);
    finally
      T.Free;
    end;

    AssertEquals('no row changed', '0', myx_query_single_value(Other, 'SELECT SUM(v) FROM qbr_cancel_test.t'));
  finally
    myx_query_errno(Other, 'DROP DATABASE IF EXISTS qbr_cancel_test');
    myx_mysql_close(Other);
  end;
end;

procedure TCancelTest.TestCancelBeforeBeginSkipsStatement;
var
  Ticket: Int64;
begin
  Ticket := FCanceller.NewTicket;
  AssertEquals('nothing to kill yet', Ord(crNotRunning), Ord(FCanceller.Cancel(Ticket, True)));
  AssertFalse('the cancelled ticket does not start', FCanceller.BeginStatement(Ticket));
  AssertTrue('the next ticket starts', FCanceller.BeginStatement(FCanceller.NewTicket));
end;

procedure TCancelTest.TestCancelAfterEndDoesNothing;
var
  Ticket: Int64;
begin
  Ticket := FCanceller.NewTicket;
  AssertTrue(FCanceller.BeginStatement(Ticket));
  AssertEquals(0, myx_query_errno(FOwner, 'DO 1'));
  FCanceller.EndStatement(Ticket);
  AssertEquals('ended ticket', Ord(crNotRunning), Ord(FCanceller.Cancel(Ticket, True)));
  AssertFalse('not cut', FCanceller.WasCut);
  AssertEquals('0', myx_query_single_value(FOwner, 'SELECT SLEEP(0.5)'));
end;

procedure TCancelTest.TestKillOnIdleConnectionDoesNotHitNextStatement;
var
  Ticket: Int64;
  Start: QWord;
begin
  // The worst case of the race: the ticket's statement has ended on the server, the KILL arrives at
  // the idle connection before EndStatement.
  Ticket := FCanceller.NewTicket;
  AssertTrue(FCanceller.BeginStatement(Ticket));
  AssertEquals(0, myx_query_errno(FOwner, 'DO 1'));
  AssertEquals('KILL sent to the idle connection', Ord(crKilled), Ord(FCanceller.Cancel(Ticket, False)));
  FCanceller.EndStatement(Ticket);

  Start := GetTickCount64;
  AssertEquals('next statement not interrupted', '0', myx_query_single_value(FOwner, 'SELECT SLEEP(1)'));
  AssertTrue('next statement ran fully', GetTickCount64 - Start >= 900);
end;

procedure TCancelTest.TestCutFreesClientButNotServer;
var
  Ticket: Int64;
  T: TStatementThread;
  Other: PMYSQL;
  Id: String;
begin
  Id := myx_query_single_value(FOwner, 'SELECT CONNECTION_ID()');
  Ticket := FCanceller.NewTicket;
  T := TStatementThread.Create(FOwner, FCanceller, Ticket, 'SELECT SLEEP(20)');
  try
    Sleep(500);
    AssertTrue('cut', FCanceller.Cut(Ticket));
    T.WaitFor;
    AssertTrue(Format('client freed (%d ms)', [T.Elapsed]), T.Elapsed < 5000);
    AssertTrue(Format('connection error (%d)', [T.ErrNo]), IsCancelError(T.ErrNo));
  finally
    T.Free;
  end;
  AssertTrue(FCanceller.WasCut);

  // The statement goes on on the server, which is why the canceller prefers KILL.
  Other := Connect;
  try
    AssertEquals('still running on the server', 'Query',
      myx_query_single_value(Other, 'SELECT COMMAND FROM information_schema.PROCESSLIST WHERE ID = ' + Id));
    myx_query_errno(Other, 'KILL ' + Id);
  finally
    myx_mysql_close(Other);
  end;
end;

procedure TCancelTest.TestRaceNeverHitsAnotherStatement;
const
  Rounds = 300;
var
  T: TRaceThread;
  Ticket, Last: Int64;
  Killed, Missed: Integer;
begin
  T := TRaceThread.Create(FOwner, FCanceller, Rounds);
  try
    Killed := 0;
    Missed := 0;
    Last := 0;
    while not T.Done do
    begin
      Ticket := InterLockedExchangeAdd64(T.Current, 0);
      if Ticket <> Last then
      begin
        Last := Ticket;
        Sleep(Random(8));
        case FCanceller.Cancel(Ticket, False) of
          crKilled: Inc(Killed);
          crNotRunning: Inc(Missed);
        else
          Fail('KILL refused on a direct connection');
        end;
      end
      else
        Sleep(0);
    end;
    T.WaitFor;
    AssertEquals('statements outside a ticket interrupted: ' + T.FirstError, 0, T.Interrupted);
    AssertTrue(Format('the race was exercised (killed %d, missed %d)', [Killed, Missed]), Killed > 10);
  finally
    T.Free;
  end;
end;

initialization
  RegisterTest(TCancelTest);
end.
