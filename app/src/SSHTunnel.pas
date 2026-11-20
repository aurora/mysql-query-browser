{ SPDX-License-Identifier: GPL-2.0-or-later }
{ SSH tunnel for database connections (ADR-0048).

  TSSHTunnel opens an SSH session with libssh (host key check against the user's known_hosts, ~/.ssh/config,
  authentication by agent and default keys, a key file or a password), listens on a free port of 127.0.0.1 and
  forwards every connection accepted there through a direct-tcpip channel to TargetHost:TargetPort as seen from the
  SSH server. The database client connects to 127.0.0.1:LocalPort.

  Open runs in the calling thread and asks the user through the events (host key, password, passphrase); after that
  a worker thread owns the session and moves the data. That thread never touches the LCL (AGENTS.md); libssh is used
  from one thread at a time. No LCL in this unit, so the tests use it directly. }
unit SSHTunnel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, ctypes, LibSSH;

type
  ESSHTunnel = class(Exception);

  // samAuto: the agent and the default keys (and IdentityFile from ~/.ssh/config), as `ssh` does
  TSSHAuthMode = (samAuto, samKeyFile, samPassword);

  TSSHHostKeyState = (
    hksUnknown,    // not in known_hosts (or no known_hosts file yet)
    hksChanged,    // a different key of the same type is recorded: possible attack
    hksOther);     // only a key of another type is recorded: possible attack

  // asked when the host key is not known: True trusts it and adds it to known_hosts. Changed keys are refused
  // without asking (as `ssh` does), the event only reports them (its result is ignored).
  TSSHVerifyHostKeyEvent = function(Sender: TObject; const Host, Fingerprint: String;
    State: TSSHHostKeyState): Boolean of object;
  TSSHSecretKind = (sskPassword, sskPassphrase);
  // asked for the password or a key's passphrase; False cancels
  TSSHAskSecretEvent = function(Sender: TObject; Kind: TSSHSecretKind; const Prompt: String;
    out Secret: String): Boolean of object;

  TSSHTunnel = class;

  TSSHForwarder = class(TThread)
  private
    FTunnel: TSSHTunnel;
  protected
    procedure Execute; override;
  public
    constructor Create(ATunnel: TSSHTunnel);
  end;

  TSSHTunnel = class
  private
    FSession: ssh_session;
    FListener: PtrInt;
    FLocalPort: Integer;
    FForwarder: TSSHForwarder;
    FLastError: String;
    FLock: TCriticalSection;
    procedure Fail(const Msg: String);
    procedure SetOption(Option: cint; const Value: String); overload;
    procedure SetOption(Option: cint; Value: cint); overload;
    procedure Configure;
    procedure CheckHostKey;
    procedure Authenticate;
    function AuthWithKeyFile: cint;
    function AuthWithPassword: cint;
    procedure Listen;
    procedure CloseListener;
    function GetActive: Boolean;
    function GetLastError: String;
    procedure SetLastError(const Msg: String);
  public
    SSHHost: String;          // host name or a Host alias of the ssh config
    SSHPort: Integer;         // 0: from the config, else 22
    SSHUser: String;          // '': from the config, else the local user
    AuthMode: TSSHAuthMode;
    KeyFile: String;          // samKeyFile
    Password: String;         // samPassword; asked for when empty
    Passphrase: String;       // for KeyFile; asked for when needed and empty
    TargetHost: String;       // the database server as seen from the SSH server
    TargetPort: Integer;
    ConfigFile: String;       // '': ~/.ssh/config and the system's ssh_config; else only this file
    KnownHostsFile: String;   // '': ~/.ssh/known_hosts
    GlobalKnownHostsFile: String; // '': the system's ssh_known_hosts
    IdentityAgent: String;    // '': SSH_AUTH_SOCK (on Windows the OpenSSH agent pipe)
    TimeoutSeconds: Integer;  // connecting and each blocking SSH operation
    OnVerifyHostKey: TSSHVerifyHostKeyEvent;
    OnAskSecret: TSSHAskSecretEvent;
    constructor Create;
    destructor Destroy; override;
    // connects, checks the host key, authenticates and starts forwarding; raises ESSHTunnel
    procedure Open;
    procedure Close;
    property Active: Boolean read GetActive;
    property LocalPort: Integer read FLocalPort;
    // why the forwarding stopped (the SSH connection broke), '' while it runs
    property LastError: String read GetLastError;
  end;

function SSHHostKeyFingerprint(Session: ssh_session): String;

implementation

uses
  Sockets{$IFDEF MSWINDOWS}, WinSock2{$ELSE}, BaseUnix, Unix{$ENDIF};

resourcestring
  SNoSession = 'Could not create an SSH session.';
  SConnectFailed = 'Could not connect to the SSH server %s: %s';
  SHostKeyRead = 'Could not read the host key of %s: %s';
  SHostKeyChanged = 'The host key of %s has changed (fingerprint %s). This can mean that someone intercepts ' +
    'the connection. If the key was changed on purpose, remove the old one from the known_hosts file.';
  SHostKeyOther = 'The host key of %s has a type that is not recorded for it (fingerprint %s). This can mean that ' +
    'someone intercepts the connection.';
  SHostKeyRejected = 'The host key of %s was not accepted.';
  SHostKeySaveFailed = 'Could not add the host key of %s to known_hosts: %s';
  SHostKeyCheckFailed = 'Could not check the host key of %s: %s';
  SAuthFailed = 'The SSH server %s did not accept the login (%s).';
  SAuthCancelled = 'The SSH login was cancelled.';
  SKeyFileRead = 'Could not read the key file %s (wrong passphrase or unsupported format).';
  SPuttyKey = 'The key file %s is in PuTTY format, which is not supported yet. Convert it with PuTTYgen ' +
    '(Conversions > Export OpenSSH key).';
  SAskPassword = 'Password for %s@%s:';
  SAskPassphrase = 'Passphrase for the key %s:';
  SListenFailed = 'Could not open a local port for the SSH tunnel.';
  SForwardFailed = 'The SSH server did not open the connection to %s:%d: %s';
  SConnectionLost = 'The SSH connection was lost: %s';

const
  BufferSize = 32768;
  InvalidSocket = PtrInt(-1);

{ sockets, the same on Unix and Windows as far as this unit needs them }

function CloseSock(S: PtrInt): Integer;
begin
  Result := CloseSocket(S);
end;

{$IFDEF MSWINDOWS}
type
  TSockSet = WinSock2.TFDSet;

procedure SetClear(var FDs: TSockSet);
begin
  FD_ZERO(FDs);
end;

procedure SetAdd(var FDs: TSockSet; S: PtrInt; var MaxFD: PtrInt);
begin
  FD_SET(TSocket(S), FDs);
  if S > MaxFD then MaxFD := S;
end;

function SetHas(var FDs: TSockSet; S: PtrInt): Boolean;
begin
  Result := FD_ISSET(TSocket(S), FDs);
end;

function WaitReadable(var FDs: TSockSet; MaxFD: PtrInt; TimeoutMs: Integer): Integer;
var
  TV: TTimeVal;
begin
  TV.tv_sec := TimeoutMs div 1000;
  TV.tv_usec := (TimeoutMs mod 1000) * 1000;
  Result := WinSock2.select(0, @FDs, nil, nil, @TV);
end;

{$ELSE}
type
  TSockSet = TFDSet;

procedure SetClear(var FDs: TSockSet);
begin
  fpFD_ZERO(FDs);
end;

procedure SetAdd(var FDs: TSockSet; S: PtrInt; var MaxFD: PtrInt);
begin
  fpFD_SET(cint(S), FDs);
  if S > MaxFD then MaxFD := S;
end;

function SetHas(var FDs: TSockSet; S: PtrInt): Boolean;
begin
  Result := fpFD_ISSET(cint(S), FDs) = 1;
end;

function WaitReadable(var FDs: TSockSet; MaxFD: PtrInt; TimeoutMs: Integer): Integer;
begin
  Result := fpSelect(cint(MaxFD + 1), @FDs, nil, nil, cint(TimeoutMs));
end;

{$ENDIF}

// sends all of Buf; False when the socket is gone
function SendAll(S: PtrInt; Buf: PByte; Len: Integer): Boolean;
var
  N: ssize_t;
begin
  while Len > 0 do
  begin
    N := fpSend(S, Buf, Len, 0);
    if N <= 0 then
      Exit(False);
    Inc(Buf, N);
    Dec(Len, N);
  end;
  Result := True;
end;

function SSHHostKeyFingerprint(Session: ssh_session): String;
var
  Key: ssh_key;
  Hash: PByte;
  HashLen: csize_t;
  Text: PChar;
begin
  Result := '';
  Key := nil;
  if ssh_get_server_publickey(Session, @Key) <> SSH_OK then
    Exit;
  try
    Hash := nil;
    if ssh_get_publickey_hash(Key, SSH_PUBLICKEY_HASH_SHA256, @Hash, @HashLen) <> SSH_OK then
      Exit;
    try
      Text := ssh_get_fingerprint_hash(SSH_PUBLICKEY_HASH_SHA256, Hash, HashLen);
      if Text <> nil then
      begin
        Result := Text;
        ssh_string_free_char(Text);
      end;
    finally
      ssh_clean_pubkey_hash(@Hash);
    end;
  finally
    ssh_key_free(Key);
  end;
end;

{ TSSHTunnel }

constructor TSSHTunnel.Create;
begin
  inherited Create;
  FListener := InvalidSocket;
  FLock := TCriticalSection.Create;
  TimeoutSeconds := 20;
end;

destructor TSSHTunnel.Destroy;
begin
  Close;
  FLock.Free;
  inherited Destroy;
end;

function TSSHTunnel.GetActive: Boolean;
begin
  Result := (FForwarder <> nil) and not FForwarder.Finished;
end;

function TSSHTunnel.GetLastError: String;
begin
  FLock.Enter;
  try
    Result := FLastError;
  finally
    FLock.Leave;
  end;
end;

procedure TSSHTunnel.SetLastError(const Msg: String);
begin
  FLock.Enter;
  try
    FLastError := Msg;
  finally
    FLock.Leave;
  end;
end;

procedure TSSHTunnel.Fail(const Msg: String);
begin
  Close;
  raise ESSHTunnel.Create(Msg);
end;

procedure TSSHTunnel.SetOption(Option: cint; const Value: String);
begin
  if ssh_options_set(FSession, Option, PChar(Value)) <> SSH_OK then
    Fail(String(ssh_get_error(FSession)));
end;

procedure TSSHTunnel.SetOption(Option: cint; Value: cint);
var
  V: cuint;
  L: clong;
begin
  // PORT takes an unsigned int, TIMEOUT a long, the others an int
  if Option = SSH_OPTIONS_TIMEOUT then
  begin
    L := Value;
    if ssh_options_set(FSession, Option, @L) <> SSH_OK then
      Fail(String(ssh_get_error(FSession)));
  end
  else
  begin
    V := cuint(Value);
    if ssh_options_set(FSession, Option, @V) <> SSH_OK then
      Fail(String(ssh_get_error(FSession)));
  end;
end;

// ssh_options_parse_config may overwrite what is set before it (libssh's documentation), so the host goes first, then
// the config, then what the connection names explicitly; after that ssh_connect must not read the config again.
procedure TSSHTunnel.Configure;
var
  NoConfig: Boolean;
begin
  SetOption(SSH_OPTIONS_HOST, SSHHost);
  if ConfigFile = '' then
    ssh_options_parse_config(FSession, nil)
  else
    ssh_options_parse_config(FSession, PChar(ConfigFile));
  NoConfig := False;
  ssh_options_set(FSession, SSH_OPTIONS_PROCESS_CONFIG, @NoConfig);
  if SSHPort > 0 then
    SetOption(SSH_OPTIONS_PORT, SSHPort);
  if SSHUser <> '' then
    SetOption(SSH_OPTIONS_USER, SSHUser);
  if KnownHostsFile <> '' then
    SetOption(SSH_OPTIONS_KNOWNHOSTS, KnownHostsFile);
  if GlobalKnownHostsFile <> '' then
    SetOption(SSH_OPTIONS_GLOBAL_KNOWNHOSTS, GlobalKnownHostsFile);
  if IdentityAgent <> '' then
    SetOption(SSH_OPTIONS_IDENTITY_AGENT, IdentityAgent);
  if TimeoutSeconds > 0 then
    SetOption(SSH_OPTIONS_TIMEOUT, TimeoutSeconds);
  SetOption(SSH_OPTIONS_NODELAY, 1);
end;

procedure TSSHTunnel.CheckHostKey;
var
  State: cint;
  Fingerprint: String;
  Accepted: Boolean;
begin
  State := ssh_session_is_known_server(FSession);
  if State = SSH_KNOWN_HOSTS_OK then
    Exit;
  Fingerprint := SSHHostKeyFingerprint(FSession);
  if Fingerprint = '' then
    Fail(Format(SHostKeyRead, [SSHHost, String(ssh_get_error(FSession))]));
  case State of
    SSH_KNOWN_HOSTS_CHANGED, SSH_KNOWN_HOSTS_OTHER:
      begin
        if Assigned(OnVerifyHostKey) then
          if State = SSH_KNOWN_HOSTS_CHANGED then
            OnVerifyHostKey(Self, SSHHost, Fingerprint, hksChanged)
          else
            OnVerifyHostKey(Self, SSHHost, Fingerprint, hksOther);
        if State = SSH_KNOWN_HOSTS_CHANGED then
          Fail(Format(SHostKeyChanged, [SSHHost, Fingerprint]))
        else
          Fail(Format(SHostKeyOther, [SSHHost, Fingerprint]));
      end;
    SSH_KNOWN_HOSTS_UNKNOWN, SSH_KNOWN_HOSTS_NOT_FOUND:
      begin
        Accepted := Assigned(OnVerifyHostKey) and OnVerifyHostKey(Self, SSHHost, Fingerprint, hksUnknown);
        if not Accepted then
          Fail(Format(SHostKeyRejected, [SSHHost]));
        if ssh_session_update_known_hosts(FSession) <> SSH_OK then
          Fail(Format(SHostKeySaveFailed, [SSHHost, String(ssh_get_error(FSession))]));
      end;
  else
    Fail(Format(SHostKeyCheckFailed, [SSHHost, String(ssh_get_error(FSession))]));
  end;
end;

function IsPuttyKey(const FileName: String): Boolean;
var
  F: TFileStream;
  Head: array[0..19] of Char;
begin
  Result := False;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      Result := (F.Read(Head, SizeOf(Head)) = SizeOf(Head)) and (Copy(Head, 1, 20) = 'PuTTY-User-Key-File-');
    finally
      F.Free;
    end;
  except
    Result := False;
  end;
end;

function TSSHTunnel.AuthWithKeyFile: cint;
var
  Key: ssh_key;
  Secret: String;
  Attempt: Integer;
  Pass: PChar;
begin
  if IsPuttyKey(KeyFile) then
    Fail(Format(SPuttyKey, [KeyFile]));
  Secret := Passphrase;
  for Attempt := 1 to 3 do
  begin
    Key := nil;
    if Secret = '' then Pass := nil else Pass := PChar(Secret);
    if ssh_pki_import_privkey_file(PChar(KeyFile), Pass, nil, nil, @Key) = SSH_OK then
    begin
      try
        Exit(ssh_userauth_publickey(FSession, nil, Key));
      finally
        ssh_key_free(Key);
      end;
    end;
    // probably encrypted: ask for the passphrase
    if not (Assigned(OnAskSecret)
      and OnAskSecret(Self, sskPassphrase, Format(SAskPassphrase, [KeyFile]), Secret)) then
      Fail(SAuthCancelled);
  end;
  Fail(Format(SKeyFileRead, [KeyFile]));
  Result := SSH_AUTH_ERROR;
end;

function TSSHTunnel.AuthWithPassword: cint;
var
  Secret: String;
  Attempt: Integer;
begin
  Secret := Password;
  Result := SSH_AUTH_DENIED;
  for Attempt := 1 to 3 do
  begin
    if Secret = '' then
      if not (Assigned(OnAskSecret)
        and OnAskSecret(Self, sskPassword, Format(SAskPassword, [SSHUser, SSHHost]), Secret)) then
        Fail(SAuthCancelled);
    Result := ssh_userauth_password(FSession, nil, PChar(Secret));
    if Result <> SSH_AUTH_DENIED then
      Exit;
    Secret := '';
  end;
end;

procedure TSSHTunnel.Authenticate;
var
  RC: cint;
begin
  RC := ssh_userauth_none(FSession, nil);
  if RC = SSH_AUTH_SUCCESS then
    Exit;
  case AuthMode of
    samAuto: RC := ssh_userauth_publickey_auto(FSession, nil, nil);
    samKeyFile: RC := AuthWithKeyFile;
    samPassword: RC := AuthWithPassword;
  end;
  if RC <> SSH_AUTH_SUCCESS then
    Fail(Format(SAuthFailed, [SSHHost, String(ssh_get_error(FSession))]));
end;

procedure TSSHTunnel.Listen;
var
  Addr: TInetSockAddr;
  Len: TSockLen;
begin
  FListener := fpSocket(AF_INET, SOCK_STREAM, 0);
  if FListener = InvalidSocket then
    Fail(SListenFailed);
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := 0;
  Addr.sin_addr := StrToNetAddr('127.0.0.1');
  if (fpBind(FListener, @Addr, SizeOf(Addr)) <> 0) or (fpListen(FListener, 8) <> 0) then
    Fail(SListenFailed);
  Len := SizeOf(Addr);
  if fpGetSockName(FListener, @Addr, @Len) <> 0 then
    Fail(SListenFailed);
  FLocalPort := ntohs(Addr.sin_port);
end;

procedure TSSHTunnel.CloseListener;
begin
  if FListener <> InvalidSocket then
  begin
    CloseSock(FListener);
    FListener := InvalidSocket;
  end;
end;

procedure TSSHTunnel.Open;
begin
  Close;
  SetLastError('');
  FSession := ssh_new;
  if FSession = nil then
    raise ESSHTunnel.Create(SNoSession);
  Configure;
  if ssh_connect(FSession) <> SSH_OK then
    Fail(Format(SConnectFailed, [SSHHost, String(ssh_get_error(FSession))]));
  CheckHostKey;
  Authenticate;
  Listen;
  FForwarder := TSSHForwarder.Create(Self);
end;

procedure TSSHTunnel.Close;
begin
  if FForwarder <> nil then
  begin
    FForwarder.Terminate;
    FForwarder.WaitFor;
    FreeAndNil(FForwarder);
  end;
  CloseListener;
  if FSession <> nil then
  begin
    ssh_disconnect(FSession);
    ssh_free(FSession);
    FSession := nil;
  end;
  FLocalPort := 0;
end;

{ TSSHForwarder }

type
  TClient = record
    Sock: PtrInt;
    Channel: ssh_channel;
  end;

constructor TSSHForwarder.Create(ATunnel: TSSHTunnel);
begin
  FTunnel := ATunnel;
  inherited Create(False);
end;

// one loop for the listener, every accepted client and the SSH session: libssh is not used from two threads
procedure TSSHForwarder.Execute;
var
  Clients: array of TClient;
  Buf: array[0..BufferSize - 1] of Byte;
  FDs: TSockSet;
  MaxFD, S: PtrInt;
  I, N, Pending: Integer;
  Chan: ssh_channel;
  Closed: Boolean;
  Session: ssh_session;

  procedure Drop(Index: Integer);
  begin
    with Clients[Index] do
    begin
      if Sock <> InvalidSocket then CloseSock(Sock);
      if Channel <> nil then
      begin
        ssh_channel_send_eof(Channel);
        ssh_channel_close(Channel);
        ssh_channel_free(Channel);
      end;
    end;
    Clients[Index] := Clients[High(Clients)];
    SetLength(Clients, Length(Clients) - 1);
  end;

begin
  Session := FTunnel.FSession;
  Clients := nil;
  try
    while not Terminated do
    begin
      if ssh_is_connected(Session) = 0 then
      begin
        FTunnel.SetLastError(Format(SConnectionLost, [String(ssh_get_error(Session))]));
        Break;
      end;

      // data the session has already received does not show on the socket: do not wait then
      Pending := 0;
      for I := 0 to High(Clients) do
        if ssh_channel_poll(Clients[I].Channel, 0) <> 0 then
          Inc(Pending);

      SetClear(FDs);
      MaxFD := 0;
      SetAdd(FDs, FTunnel.FListener, MaxFD);
      SetAdd(FDs, PtrInt(ssh_get_fd(Session)), MaxFD);
      for I := 0 to High(Clients) do
        SetAdd(FDs, Clients[I].Sock, MaxFD);
      if Pending > 0 then
        WaitReadable(FDs, MaxFD, 0)
      else
        WaitReadable(FDs, MaxFD, 100);

      if SetHas(FDs, FTunnel.FListener) then
      begin
        S := fpAccept(FTunnel.FListener, nil, nil);
        if S <> InvalidSocket then
        begin
          Chan := ssh_channel_new(Session);
          if (Chan <> nil) and (ssh_channel_open_forward(Chan, PChar(FTunnel.TargetHost), FTunnel.TargetPort,
            '127.0.0.1', FTunnel.FLocalPort) = SSH_OK) then
          begin
            SetLength(Clients, Length(Clients) + 1);
            Clients[High(Clients)].Sock := S;
            Clients[High(Clients)].Channel := Chan;
          end
          else
          begin
            FTunnel.SetLastError(Format(SForwardFailed, [FTunnel.TargetHost, FTunnel.TargetPort,
              String(ssh_get_error(Session))]));
            if Chan <> nil then ssh_channel_free(Chan);
            CloseSock(S);
          end;
        end;
      end;

      I := 0;
      while I <= High(Clients) do
      begin
        Closed := False;
        // client -> server
        if SetHas(FDs, Clients[I].Sock) then
        begin
          N := fpRecv(Clients[I].Sock, @Buf[0], BufferSize, 0);
          if N <= 0 then
            Closed := True
          else if ssh_channel_write(Clients[I].Channel, @Buf[0], N) <> N then
            Closed := True;
        end;
        // server -> client
        while not Closed do
        begin
          N := ssh_channel_read_nonblocking(Clients[I].Channel, @Buf[0], BufferSize, 0);
          if N > 0 then
          begin
            if not SendAll(Clients[I].Sock, @Buf[0], N) then
              Closed := True;
          end
          else
          begin
            if (N < 0) or (ssh_channel_is_eof(Clients[I].Channel) <> 0) then
              Closed := True;
            Break;
          end;
        end;
        if Closed then
          Drop(I)
        else
          Inc(I);
      end;
    end;
  finally
    while Length(Clients) > 0 do
      Drop(High(Clients));
  end;
end;

end.
