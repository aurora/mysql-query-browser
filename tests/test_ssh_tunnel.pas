{ SPDX-License-Identifier: GPL-2.0-or-later }
{ SSH tunnel (ADR-0048) against the OpenSSH container of tests/run-matrix.sh (tests/ci/sshd): host key handling,
  login by key file, encrypted key, password and ~/.ssh/config, and database connections through the tunnel to the
  test server. Needs QBR_TEST_SSH_PORT and QBR_TEST_SSH_DIR (the folder with the per-run keys); without them the
  tests are reported as ignored. }
unit test_ssh_tunnel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface, SSHTunnel;

type
  TSSHTunnelTest = class(TTestCase)
  private
    FDir: String;          // per-test files: known_hosts, config
    FKeyDir: String;
    FVerifyCalls: Integer;
    FLastState: TSSHHostKeyState;
    FAcceptHostKey: Boolean;
    FSecret: String;
    FAskCalls: Integer;
    function Enabled: Boolean;
    function NewTunnel: TSSHTunnel;
    function VerifyHostKey(Sender: TObject; const Host, Fingerprint: String; State: TSSHHostKeyState): Boolean;
    function AskSecret(Sender: TObject; Kind: TSSHSecretKind; const Prompt: String; out Secret: String): Boolean;
    function QueryVersion(Port: Integer): String;
    procedure ExpectFailure(Tunnel: TSSHTunnel; const Part: String);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestUnknownHostKeyRejected;
    procedure TestKeyFileAndQuery;
    procedure TestKnownHostIsNotAskedAgain;
    procedure TestChangedHostKeyRefused;
    procedure TestEncryptedKeyAsksPassphrase;
    procedure TestPassword;
    procedure TestWrongPasswordCancelled;
    procedure TestConfigHostAlias;
    procedure TestPuttyKeyExplained;
    procedure TestPuttyKeys;
    procedure TestPuttyWrongPassphrase;
    procedure TestReopenAfterClose;
  end;

implementation

function Env(const Name, Default: String): String;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then
    Result := Default;
end;

procedure WriteText(const FileName, Text: String);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := Text;
    L.SaveToFile(FileName);
  finally
    L.Free;
  end;
end;

function ReadText(const FileName: String): String;
var
  L: TStringList;
begin
  Result := '';
  if not FileExists(FileName) then Exit;
  L := TStringList.Create;
  try
    L.LoadFromFile(FileName);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

procedure TSSHTunnelTest.SetUp;
begin
  FKeyDir := Env('QBR_TEST_SSH_DIR', '');
  FDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'qbr-ssh-test-' + IntToStr(GetProcessID) + '-' +
    IntToStr(Random(1000000));
  ForceDirectories(FDir);
  FVerifyCalls := 0;
  FAskCalls := 0;
  FAcceptHostKey := True;
  FSecret := '';
  // no settings of the machine: an empty config, an empty known_hosts
  WriteText(FDir + '/config', '');
  WriteText(FDir + '/known_hosts', '');
end;

procedure TSSHTunnelTest.TearDown;
begin
  DeleteFile(FDir + '/config');
  DeleteFile(FDir + '/known_hosts');
  DeleteFile(FDir + '/fake.ppk');
  RemoveDir(FDir);
end;

function TSSHTunnelTest.Enabled: Boolean;
begin
  Result := (Env('QBR_TEST_SSH_PORT', '') <> '') and (FKeyDir <> '');
end;

function TSSHTunnelTest.NewTunnel: TSSHTunnel;
begin
  Result := TSSHTunnel.Create;
  Result.SSHHost := '127.0.0.1';
  Result.SSHPort := StrToInt(Env('QBR_TEST_SSH_PORT', '24022'));
  Result.SSHUser := 'qbr';
  Result.AuthMode := samKeyFile;
  Result.KeyFile := FKeyDir + '/id_ed25519';
  Result.TargetHost := '127.0.0.1';
  Result.TargetPort := StrToInt(Env('QBR_TEST_PORT', '33306'));
  Result.ConfigFile := FDir + '/config';
  Result.KnownHostsFile := FDir + '/known_hosts';
  Result.GlobalKnownHostsFile := FDir + '/no-global-known-hosts';
  Result.IdentityAgent := FDir + '/no-agent';
  Result.TimeoutSeconds := 15;
  Result.OnVerifyHostKey := @VerifyHostKey;
  Result.OnAskSecret := @AskSecret;
end;

function TSSHTunnelTest.VerifyHostKey(Sender: TObject; const Host, Fingerprint: String;
  State: TSSHHostKeyState): Boolean;
begin
  Inc(FVerifyCalls);
  FLastState := State;
  AssertTrue('fingerprint is SHA256: ' + Fingerprint, Pos('SHA256:', Fingerprint) = 1);
  Result := FAcceptHostKey;
end;

function TSSHTunnelTest.AskSecret(Sender: TObject; Kind: TSSHSecretKind; const Prompt: String;
  out Secret: String): Boolean;
begin
  Inc(FAskCalls);
  Secret := FSecret;
  Result := FSecret <> '';
end;

function TSSHTunnelTest.QueryVersion(Port: Integer): String;
var
  Conn: MYX_USER_CONNECTION;
  User, Pwd, Host: AnsiString;
  My: PMYSQL;
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
begin
  User := Env('QBR_TEST_USER', 'root');
  Pwd := Env('QBR_TEST_PASSWORD', 'qbr-test');
  Host := '127.0.0.1';
  FillChar(Conn, SizeOf(Conn), 0);
  Conn.connection_type := MYX_MYSQL_CONN;
  Conn.storage_type := MYX_FAVORITE_USER_CONNECTION;
  Conn.username := PAnsiChar(User);
  Conn.password := PAnsiChar(Pwd);
  Conn.hostname := PAnsiChar(Host);
  Conn.port := Port;
  My := myx_mysql_init;
  try
    AssertEquals('connect through the tunnel (' + myx_mysql_error(My) + ')', 0, myx_connect_to_instance(@Conn, My));
    Err := MYX_NO_ERROR;
    Rs := myx_query_execute(My, 'SELECT VERSION()', 0, nil, @Err, nil, nil, nil, nil);
    AssertNotNull('resultset', Rs);
    try
      SetString(Result, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
    finally
      myx_query_free_resultset(Rs);
    end;
  finally
    myx_mysql_close(My);
  end;
end;

procedure TSSHTunnelTest.ExpectFailure(Tunnel: TSSHTunnel; const Part: String);
var
  Msg: String;
begin
  Msg := '';
  try
    Tunnel.Open;
  except
    on E: ESSHTunnel do
      Msg := E.Message;
  end;
  AssertTrue('Open must fail', Msg <> '');
  AssertTrue('message mentions "' + Part + '": ' + Msg, Pos(LowerCase(Part), LowerCase(Msg)) > 0);
  AssertFalse('not active after a failure', Tunnel.Active);
end;

procedure TSSHTunnelTest.TestUnknownHostKeyRejected;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  FAcceptHostKey := False;
  T := NewTunnel;
  try
    ExpectFailure(T, 'not accepted');
    AssertEquals('asked once', 1, FVerifyCalls);
    AssertTrue('state unknown', FLastState = hksUnknown);
    AssertEquals('known_hosts stays empty', '', Trim(ReadText(FDir + '/known_hosts')));
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestKeyFileAndQuery;
var
  T: TSSHTunnel;
  Direct: String;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  Direct := QueryVersion(StrToInt(Env('QBR_TEST_PORT', '33306')));
  T := NewTunnel;
  try
    T.Open;
    AssertTrue('active', T.Active);
    AssertTrue('local port', T.LocalPort > 0);
    AssertEquals('host key asked once', 1, FVerifyCalls);
    AssertTrue('host key recorded', Pos('[127.0.0.1]:', ReadText(FDir + '/known_hosts')) > 0);
    // two connections one after the other and the same server answers as without the tunnel
    AssertEquals('first connection', Direct, QueryVersion(T.LocalPort));
    AssertEquals('second connection', Direct, QueryVersion(T.LocalPort));
    AssertEquals('no error', '', T.LastError);
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestKnownHostIsNotAskedAgain;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.Open;
    T.Close;
    T.Open;
    AssertEquals('asked only the first time', 1, FVerifyCalls);
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestChangedHostKeyRefused;
var
  T: TSSHTunnel;
  Recorded: TStringList;
  I: Integer;
  Fake: String;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.Open;
    T.Close;
    // replace the recorded key by another key of the same type (the user's key stands in for it)
    Fake := Trim(ReadText(FKeyDir + '/id_ed25519.pub'));
    Fake := Copy(Fake, 1, Pos(' ', Fake + ' ', Pos(' ', Fake) + 1) - 1);
    Recorded := TStringList.Create;
    try
      Recorded.LoadFromFile(FDir + '/known_hosts');
      for I := 0 to Recorded.Count - 1 do
        if Recorded[I] <> '' then
          Recorded[I] := Copy(Recorded[I], 1, Pos(' ', Recorded[I])) + Fake;
      Recorded.SaveToFile(FDir + '/known_hosts');
    finally
      Recorded.Free;
    end;
    FVerifyCalls := 0;
    ExpectFailure(T, 'host key');
    AssertEquals('reported once', 1, FVerifyCalls);
    AssertTrue('state changed or other', FLastState in [hksChanged, hksOther]);
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestEncryptedKeyAsksPassphrase;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.KeyFile := FKeyDir + '/id_ed25519_pass';
    FSecret := 'qbr-pass';
    T.Open;
    AssertTrue('passphrase asked', FAskCalls >= 1);
    AssertTrue('active', T.Active);
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestPassword;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.AuthMode := samPassword;
    T.Password := 'qbr-test';
    T.Open;
    AssertEquals('not asked', 0, FAskCalls);
    AssertTrue('query', QueryVersion(T.LocalPort) <> '');
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestWrongPasswordCancelled;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.AuthMode := samPassword;
    T.Password := 'wrong';
    FSecret := '';   // the prompt is cancelled
    ExpectFailure(T, 'cancelled');
    AssertEquals('asked again after the wrong password', 1, FAskCalls);
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestConfigHostAlias;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  WriteText(FDir + '/config',
    'Host qbr-bastion' + LineEnding +
    '  HostName 127.0.0.1' + LineEnding +
    '  Port ' + Env('QBR_TEST_SSH_PORT', '24022') + LineEnding +
    '  User qbr' + LineEnding +
    '  IdentityFile ' + FKeyDir + '/id_ed25519' + LineEnding);
  T := NewTunnel;
  try
    T.SSHHost := 'qbr-bastion';
    T.SSHPort := 0;
    T.SSHUser := '';
    T.AuthMode := samAuto;
    T.Open;
    AssertTrue('query', QueryVersion(T.LocalPort) <> '');
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestPuttyKeyExplained;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  WriteText(FDir + '/fake.ppk', 'PuTTY-User-Key-File-3: ssh-ed25519' + LineEnding + 'Encryption: none');
  T := NewTunnel;
  try
    T.KeyFile := FDir + '/fake.ppk';
    ExpectFailure(T, 'PuTTY');
  finally
    T.Free;
  end;
end;

// every .ppk variant run-matrix.sh makes with puttygen: formats 2 and 3, plain and encrypted (Argon2id, Argon2i),
// Ed25519, RSA and ECDSA
procedure TSSHTunnelTest.TestPuttyKeys;
const
  Keys: array[0..4] of String = ('ed25519-v3.ppk', 'ed25519-v2-pass.ppk', 'rsa-v3-pass.ppk', 'rsa-v2.ppk',
    'ecdsa-v3-argon2i-pass.ppk');
var
  T: TSSHTunnel;
  I: Integer;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  for I := Low(Keys) to High(Keys) do
  begin
    AssertTrue('test key ' + Keys[I] + ' exists', FileExists(FKeyDir + '/' + Keys[I]));
    FAskCalls := 0;
    FSecret := 'qbr-pass';
    T := NewTunnel;
    try
      T.KeyFile := FKeyDir + '/' + Keys[I];
      T.Open;
      AssertTrue(Keys[I] + ': active', T.Active);
      AssertEquals(Keys[I] + ': passphrase asked only for encrypted keys', Ord(Pos('-pass', Keys[I]) > 0),
        FAskCalls);
      if I = 0 then
        AssertTrue('query through the tunnel', QueryVersion(T.LocalPort) <> '');
    finally
      T.Free;
    end;
  end;
end;

procedure TSSHTunnelTest.TestPuttyWrongPassphrase;
var
  T: TSSHTunnel;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.KeyFile := FKeyDir + '/rsa-v3-pass.ppk';
    FSecret := 'not-the-passphrase';
    ExpectFailure(T, 'wrong passphrase');
    AssertEquals('asked three times', 3, FAskCalls);
  finally
    T.Free;
  end;
end;

procedure TSSHTunnelTest.TestReopenAfterClose;
var
  T: TSSHTunnel;
  Port: Integer;
begin
  if not Enabled then Ignore('no SSH test server (QBR_TEST_SSH_PORT, QBR_TEST_SSH_DIR)');
  T := NewTunnel;
  try
    T.Open;
    Port := T.LocalPort;
    T.Close;
    AssertFalse('closed', T.Active);
    AssertEquals('port released', 0, T.LocalPort);
    T.Open;
    AssertTrue('query after reopening', QueryVersion(T.LocalPort) <> '');
    AssertTrue('a port again', (T.LocalPort > 0) or (Port > 0));
  finally
    T.Free;
  end;
end;

initialization
  Randomize;
  RegisterTest(TSSHTunnelTest);

end.
