unit test_support;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, myx_types, myx_util_public_interface, myx_public_interface;

{ Connects to the test server configured via QBR_TEST_* (see tests/README.md).
  Raises an exception when the connection fails. }
function ConnectTestServer: PMYSQL;
procedure DisconnectTestServer(My: PMYSQL);
procedure ExecSQL(My: PMYSQL; const SQL: AnsiString);

implementation

function Env(const Name, Default: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then
    Result := Default;
end;

function ConnectTestServer: PMYSQL;
var
  Conn: MYX_USER_CONNECTION;
  User, Pwd, Host: AnsiString;
begin
  User := Env('QBR_TEST_USER', 'root');
  Pwd := Env('QBR_TEST_PASSWORD', 'qbr-test');
  Host := Env('QBR_TEST_HOST', '127.0.0.1');
  FillChar(Conn, SizeOf(Conn), 0);
  Conn.connection_type := MYX_MYSQL_CONN;
  Conn.storage_type := MYX_FAVORITE_USER_CONNECTION;
  Conn.username := PAnsiChar(User);
  Conn.password := PAnsiChar(Pwd);
  Conn.hostname := PAnsiChar(Host);
  Conn.port := StrToInt(Env('QBR_TEST_PORT', '33306'));
  Result := myx_mysql_init;
  if myx_connect_to_instance(@Conn, Result) <> 0 then
    raise Exception.Create('connect failed: ' + myx_mysql_error(Result));
end;

procedure DisconnectTestServer(My: PMYSQL);
begin
  if My <> nil then
    myx_mysql_close(My);
end;

procedure ExecSQL(My: PMYSQL; const SQL: AnsiString);
begin
  if myx_mysql_query(My, PAnsiChar(SQL)) <> 0 then
    raise Exception.Create('SQL failed: ' + SQL + ' -> ' + myx_mysql_error(My));
end;

end.
