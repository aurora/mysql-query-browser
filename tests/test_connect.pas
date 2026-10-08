unit test_connect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface;

type
  TConnectTest = class(TTestCase)
  private
    function Env(const Name, Default: string): string;
    procedure FillConnection(var Conn: MYX_USER_CONNECTION; const User, Pwd, Host: AnsiString);
  published
    procedure TestInterfaceVersion;
    procedure TestConnectAndSelectVersion;
    procedure TestWrongPasswordFails;
  end;

implementation

function TConnectTest.Env(const Name, Default: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then
    Result := Default;
end;

procedure TConnectTest.FillConnection(var Conn: MYX_USER_CONNECTION;
  const User, Pwd, Host: AnsiString);
begin
  FillChar(Conn, SizeOf(Conn), 0);
  Conn.connection_type := MYX_MYSQL_CONN;
  Conn.storage_type := MYX_FAVORITE_USER_CONNECTION;
  Conn.username := PAnsiChar(User);
  Conn.password := PAnsiChar(Pwd);
  Conn.hostname := PAnsiChar(Host);
  Conn.port := StrToInt(Env('QBR_TEST_PORT', '33306'));
  Conn.schema := nil;
end;

procedure TConnectTest.TestInterfaceVersion;
begin
  AssertTrue('library reports an interface version', myx_get_public_interface_version > 0);
end;

procedure TConnectTest.TestConnectAndSelectVersion;
var
  Conn: MYX_USER_CONNECTION;
  User, Pwd, Host: AnsiString;
  My: PMYSQL;
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
  Value: AnsiString;
begin
  User := Env('QBR_TEST_USER', 'root');
  Pwd := Env('QBR_TEST_PASSWORD', 'qbr-test');
  Host := Env('QBR_TEST_HOST', '127.0.0.1');
  FillConnection(Conn, User, Pwd, Host);

  My := myx_mysql_init;
  AssertNotNull('myx_mysql_init', My);
  try
    AssertEquals('connect (' + myx_mysql_error(My) + ')', 0, myx_connect_to_instance(@Conn, My));

    Err := MYX_NO_ERROR;
    Rs := myx_query_execute(My, 'SELECT VERSION()', 0, nil, @Err, nil, nil, nil, nil);
    AssertNotNull('resultset', Rs);
    try
      AssertEquals('error code', MYX_NO_ERROR, Err);
      AssertEquals('columns', 1, Rs^.columns_num);
      AssertEquals('rows', 1, Rs^.rows_num);
      SetString(Value, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
      AssertTrue('supported server version (>= 5.7), got ' + Value,
        (StrToIntDef(Copy(Value, 1, Pos('.', Value) - 1), 0) >= 8) or (Pos('5.7.', Value) = 1));
    finally
      myx_query_free_resultset(Rs);
    end;
  finally
    myx_mysql_close(My);
  end;
end;

procedure TConnectTest.TestWrongPasswordFails;
var
  Conn: MYX_USER_CONNECTION;
  My: PMYSQL;
begin
  FillConnection(Conn, Env('QBR_TEST_USER', 'root'), 'definitely-wrong', Env('QBR_TEST_HOST', '127.0.0.1'));
  My := myx_mysql_init;
  try
    AssertTrue('connect with wrong password must fail', myx_connect_to_instance(@Conn, My) <> 0);
  finally
    myx_mysql_close(My);
  end;
end;

initialization
  RegisterTest(TConnectTest);

end.
