{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Connecting through an SSH tunnel (ADR-0048).

  SSHConnectToInstance replaces myx_connect_to_instance wherever the program connects to a server. A connection whose
  advanced options contain SSH_TUNNEL=Yes is connected through a tunnel (SSHTunnel.pas) to 127.0.0.1 and the tunnel's
  local port; any other connection goes to myx_connect_to_instance unchanged. Tunnels are kept in a pool and shared
  by all connections with the same SSH settings and target (the program opens several: the main one, the threads of
  result tabs, the one that cancels queries); a tunnel whose SSH connection broke is opened again on the next
  connect. Questions to the user (host key, password, passphrase) are always asked in the main thread, through the
  procedures SSHConnectUI sets: this unit stays free of the LCL, because QueryCancel (and so the tests) uses it.

  Advanced options read (the C connect code ignores names it does not know, so earlier releases keep them):
    SSH_TUNNEL=Yes        use the tunnel
    SSH_HOST=...          SSH server or a Host alias of ~/.ssh/config
    SSH_PORT=...          default: from the config, else 22
    SSH_USER=...          default: from the config, else the local user
    SSH_AUTH=agent|key|password   default: agent (the agent and the default keys, as `ssh` does)
    SSH_KEYFILE=...       for SSH_AUTH=key
    SSH_CONFIG=...        another ssh config file instead of ~/.ssh/config
    SSH_KNOWN_HOSTS=...   another known_hosts file instead of ~/.ssh/known_hosts }
unit SSHConnect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, myx_public_interface, SSHTunnel;

const
  // SSHConnectToInstance: the tunnel could not be opened; SSHErrorMessage says why
  CONNECT_SSH_FAILED = -30;

type
  // the questions to the user (SSHConnectUI); called in the main thread. Without them unknown host keys are refused
  // and nothing is asked.
  TSSHVerifyHostKeyProc = function(const Host, Fingerprint: String; State: TSSHHostKeyState): Boolean;
  TSSHAskSecretProc = function(const Prompt: String; out Secret: String): Boolean;

var
  SSHVerifyHostKeyProc: TSSHVerifyHostKeyProc = nil;
  SSHAskSecretProc: TSSHAskSecretProc = nil;

// like myx_connect_to_instance: 0 when connected
function SSHConnectToInstance(UserConn: PMYX_USER_CONNECTION; MySQL: Pointer): Integer;
function UsesSSHTunnel(UserConn: PMYX_USER_CONNECTION): Boolean;
// the reason of the last CONNECT_SSH_FAILED
function SSHErrorMessage: String;
procedure CloseSSHTunnels;

implementation

type
  TPoolEntry = class
    Key: String;
    Tunnel: TSSHTunnel;
    // what the user typed, kept for reopening the tunnel from a thread without asking again
    Password, Passphrase: String;
  end;

  // runs the questions of a tunnel in the main thread
  TAsker = class
  private
    FHost, FFingerprint, FPrompt, FSecret: String;
    FState: TSSHHostKeyState;
    FAnswer: Boolean;
    procedure DoVerify;
    procedure DoAsk;
  public
    Entry: TPoolEntry;
    function VerifyHostKey(Sender: TObject; const Host, Fingerprint: String; State: TSSHHostKeyState): Boolean;
    function AskSecret(Sender: TObject; Kind: TSSHSecretKind; const Prompt: String; out Secret: String): Boolean;
  end;

var
  Pool: TList = nil;
  PoolLock: TCriticalSection = nil;
  LastError: String = '';

function Option(UserConn: PMYX_USER_CONNECTION; const Name: String): String;
var
  I: Integer;
  S: String;
begin
  Result := '';
  for I := 0 to Integer(UserConn^.advanced_options_num) - 1 do
  begin
    S := String(UserConn^.advanced_options[I]);
    if CompareText(Copy(S, 1, Length(Name) + 1), Name + '=') = 0 then
      Exit(Copy(S, Length(Name) + 2, MaxInt));
  end;
end;

function UsesSSHTunnel(UserConn: PMYX_USER_CONNECTION): Boolean;
begin
  Result := (UserConn <> nil) and SameText(Option(UserConn, 'SSH_TUNNEL'), 'Yes')
    and (Option(UserConn, 'SSH_HOST') <> '');
end;

function SSHErrorMessage: String;
begin
  PoolLock.Enter;
  try
    Result := LastError;
  finally
    PoolLock.Leave;
  end;
end;

{ TAsker }

procedure TAsker.DoVerify;
begin
  FAnswer := Assigned(SSHVerifyHostKeyProc) and SSHVerifyHostKeyProc(FHost, FFingerprint, FState);
end;

procedure TAsker.DoAsk;
begin
  FSecret := '';
  FAnswer := Assigned(SSHAskSecretProc) and SSHAskSecretProc(FPrompt, FSecret);
end;

function TAsker.VerifyHostKey(Sender: TObject; const Host, Fingerprint: String; State: TSSHHostKeyState): Boolean;
begin
  FHost := Host;
  FFingerprint := Fingerprint;
  FState := State;
  if GetCurrentThreadId = MainThreadID then
    DoVerify
  else
    TThread.Synchronize(nil, @DoVerify);
  Result := FAnswer;
end;

function TAsker.AskSecret(Sender: TObject; Kind: TSSHSecretKind; const Prompt: String; out Secret: String): Boolean;
begin
  FPrompt := Prompt;
  FSecret := '';
  if GetCurrentThreadId = MainThreadID then
    DoAsk
  else
    TThread.Synchronize(nil, @DoAsk);
  Secret := FSecret;
  Result := FAnswer and (FSecret <> '');
  if Result then
    if Kind = sskPassword then
      Entry.Password := Secret
    else
      Entry.Passphrase := Secret;
end;

{ pool }

function EntryKey(UserConn: PMYX_USER_CONNECTION): String;
begin
  Result := Option(UserConn, 'SSH_HOST') + '|' + Option(UserConn, 'SSH_PORT') + '|' + Option(UserConn, 'SSH_USER') +
    '|' + Option(UserConn, 'SSH_AUTH') + '|' + Option(UserConn, 'SSH_KEYFILE') + '|' +
    Option(UserConn, 'SSH_CONFIG') + '|' + Option(UserConn, 'SSH_KNOWN_HOSTS') + '|' + String(UserConn^.hostname) +
    '|' + IntToStr(UserConn^.port);
end;

// the main thread must keep answering Synchronize while a thread opens a tunnel and asks a question
procedure EnterPool;
begin
  if GetCurrentThreadId = MainThreadID then
    while not PoolLock.TryEnter do
      CheckSynchronize(10)
  else
    PoolLock.Enter;
end;

// returns the local port of a working tunnel for this connection, 0 when it could not be opened (LastError)
function TunnelPort(UserConn: PMYX_USER_CONNECTION): Integer;
var
  Key, Auth, Target: String;
  Entry: TPoolEntry;
  Asker: TAsker;
  I: Integer;
begin
  Result := 0;
  Key := EntryKey(UserConn);
  EnterPool;
  try
    Entry := nil;
    for I := 0 to Pool.Count - 1 do
      if TPoolEntry(Pool[I]).Key = Key then
        Entry := TPoolEntry(Pool[I]);
    if (Entry <> nil) and Entry.Tunnel.Active then
      Exit(Entry.Tunnel.LocalPort);
    if Entry = nil then
    begin
      Entry := TPoolEntry.Create;
      Entry.Key := Key;
      Entry.Tunnel := TSSHTunnel.Create;
      Pool.Add(Entry);
    end;
    with Entry.Tunnel do
    begin
      SSHHost := Option(UserConn, 'SSH_HOST');
      SSHPort := StrToIntDef(Option(UserConn, 'SSH_PORT'), 0);
      SSHUser := Option(UserConn, 'SSH_USER');
      Auth := LowerCase(Option(UserConn, 'SSH_AUTH'));
      if Auth = 'key' then
        AuthMode := samKeyFile
      else if Auth = 'password' then
        AuthMode := samPassword
      else
        AuthMode := samAuto;
      KeyFile := Option(UserConn, 'SSH_KEYFILE');
      ConfigFile := Option(UserConn, 'SSH_CONFIG');
      KnownHostsFile := Option(UserConn, 'SSH_KNOWN_HOSTS');
      Target := String(UserConn^.hostname);
      if (Target = '') or SameText(Target, 'localhost') then
        Target := '127.0.0.1';
      TargetHost := Target;
      TargetPort := UserConn^.port;
      if TargetPort = 0 then
        TargetPort := 3306;
      Password := Entry.Password;
      Passphrase := Entry.Passphrase;
    end;
    Asker := TAsker.Create;
    try
      Asker.Entry := Entry;
      Entry.Tunnel.OnVerifyHostKey := @Asker.VerifyHostKey;
      Entry.Tunnel.OnAskSecret := @Asker.AskSecret;
      try
        Entry.Tunnel.Open;
        Result := Entry.Tunnel.LocalPort;
        LastError := '';
      except
        on E: Exception do
          LastError := E.Message;
      end;
    finally
      Entry.Tunnel.OnVerifyHostKey := nil;
      Entry.Tunnel.OnAskSecret := nil;
      Asker.Free;
    end;
  finally
    PoolLock.Leave;
  end;
end;

function SSHConnectToInstance(UserConn: PMYX_USER_CONNECTION; MySQL: Pointer): Integer;
var
  Port: Integer;
  Copy: TMYX_USER_CONNECTION;
begin
  if not UsesSSHTunnel(UserConn) then
    Exit(myx_connect_to_instance(UserConn, MySQL));
  Port := TunnelPort(UserConn);
  if Port = 0 then
    Exit(CONNECT_SSH_FAILED);
  Copy := TMYX_USER_CONNECTION.Create(UserConn);
  try
    Copy.hostname := '127.0.0.1';
    Copy.port := Port;
    Result := myx_connect_to_instance(Copy.get_record_pointer, MySQL);
  finally
    Copy.Free;
  end;
end;

procedure CloseSSHTunnels;
var
  I: Integer;
begin
  if Pool = nil then
    Exit;
  PoolLock.Enter;
  try
    for I := 0 to Pool.Count - 1 do
    begin
      TPoolEntry(Pool[I]).Tunnel.Free;
      TPoolEntry(Pool[I]).Free;
    end;
    Pool.Clear;
  finally
    PoolLock.Leave;
  end;
end;

initialization
  Pool := TList.Create;
  PoolLock := TCriticalSection.Create;

finalization
  CloseSSHTunnels;
  FreeAndNil(Pool);
  FreeAndNil(PoolLock);

end.
