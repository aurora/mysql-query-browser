{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Testing a connection's settings (ADR-0051): connects through the program's own path (SSHConnectToInstance, so the
  SSH tunnel and its questions are part of it), reads the server version and closes the connection again. No LCL
  here: the connection manager runs it in a thread, the matrix self-test directly. }
unit ConnectionTest;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, myx_public_interface;

type
  TConnectionTestResult = record
    OK: Boolean;
    Text: String;
  end;

  // runs TestConnection in a thread; the caller waits for it, answering Synchronize (the tunnel's questions)
  TConnectionTestThread = class(TThread)
  private
    FConn: TMYX_USER_CONNECTION;
  protected
    procedure Execute; override;
  public
    Outcome: TConnectionTestResult;
    // takes a copy of Conn
    constructor Create(Conn: TMYX_USER_CONNECTION);
    destructor Destroy; override;
  end;

// blocks until connected or failed
function TestConnection(Conn: TMYX_USER_CONNECTION): TConnectionTestResult;

implementation

uses
  SSHConnect;

resourcestring
  SConnected = 'Connected to %s:%d, server version %s.';
  SThroughSSH = 'The connection went through the SSH server %s.';
  SFailed = 'Could not connect to %s:%d.';
  SServerError = 'MySQL error %d: %s';
  SNoMemory = 'Could not allocate the connection.';

function TestConnection(Conn: TMYX_USER_CONNECTION): TConnectionTestResult;
var
  Copy: TMYX_USER_CONNECTION;
  My: Pointer;
  RC: Integer;
  Host: String;
begin
  Result.OK := False;
  Result.Text := '';
  Copy := TMYX_USER_CONNECTION.Create('', '', '', '', 0, '', '', '', MYX_MYSQL_CONN, MYX_FAVORITE_USER_CONNECTION);
  try
    Copy.Assign(Conn);
    Host := Copy.hostname;
    if Host = '' then
      Host := 'localhost';
    My := myx_mysql_init;
    if My = nil then
    begin
      Result.Text := SNoMemory;
      Exit;
    end;
    try
      RC := SSHConnectToInstance(Copy.get_record_pointer, My);
      if RC = 0 then
      begin
        Result.OK := True;
        Result.Text := Format(SConnected, [Host, Copy.port, myx_get_mysql_full_version(My)]);
        if UsesSSHTunnel(Copy.get_record_pointer) then
          Result.Text := Result.Text + LineEnding + Format(SThroughSSH, [Copy.advanced_options.Values['SSH_HOST']]);
      end
      else if RC = CONNECT_SSH_FAILED then
        Result.Text := Format(SFailed, [Host, Copy.port]) + LineEnding + LineEnding + SSHErrorMessage
      else
        Result.Text := Format(SFailed, [Host, Copy.port]) + LineEnding + LineEnding +
          Format(SServerError, [myx_mysql_errno(My), myx_mysql_error(My)]);
    finally
      myx_mysql_close(My);
    end;
  finally
    Copy.Free;
  end;
end;

{ TConnectionTestThread }

constructor TConnectionTestThread.Create(Conn: TMYX_USER_CONNECTION);
begin
  FConn := TMYX_USER_CONNECTION.Create('', '', '', '', 0, '', '', '', MYX_MYSQL_CONN, MYX_FAVORITE_USER_CONNECTION);
  FConn.Assign(Conn);
  inherited Create(False);
end;

destructor TConnectionTestThread.Destroy;
begin
  FConn.Free;
  inherited Destroy;
end;

procedure TConnectionTestThread.Execute;
begin
  try
    Outcome := TestConnection(FConn);
  except
    on E: Exception do
    begin
      Outcome.OK := False;
      Outcome.Text := E.Message;
    end;
  end;
end;

end.
