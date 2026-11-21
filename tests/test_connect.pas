{ SPDX-License-Identifier: GPL-2.0-or-later }
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
    procedure TestDetectedVersionMatchesServer;
    procedure TestWrongPasswordFails;
    procedure TestMissingSchemaStillConnects;
    procedure TestUnreachableHostWaitsOnce;
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

// The backend's version checks (myx_get_mysql_*_version, mysql_*version_is_later_or_equal_than) must see the
// server's real version. MariaDB 10.x sends "5.5.5-10.x.y-MariaDB" in the handshake (ADR-0004); Connector/C strips
// the prefix, a client that does not would make every MariaDB look like 5.5.
procedure TConnectTest.TestDetectedVersionMatchesServer;
var
  Conn: MYX_USER_CONNECTION;
  My: PMYSQL;
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
  Value, Expected: AnsiString;
  Parts: TStringArray;
  Detected: string;
begin
  FillConnection(Conn, Env('QBR_TEST_USER', 'root'), Env('QBR_TEST_PASSWORD', 'qbr-test'),
    Env('QBR_TEST_HOST', '127.0.0.1'));
  My := myx_mysql_init;
  AssertNotNull('myx_mysql_init', My);
  try
    AssertEquals('connect (' + myx_mysql_error(My) + ')', 0, myx_connect_to_instance(@Conn, My));
    Err := MYX_NO_ERROR;
    Rs := myx_query_execute(My, 'SELECT VERSION()', 0, nil, @Err, nil, nil, nil, nil);
    AssertNotNull('resultset', Rs);
    try
      SetString(Value, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
    finally
      myx_query_free_resultset(Rs);
    end;
    // "8.4.7", "10.11.19-MariaDB-ubu2204": the first three numbers
    Parts := Copy(Value, 1, Pos('-', Value + '-') - 1).Split(['.']);
    AssertTrue('VERSION() has three parts: ' + Value, Length(Parts) >= 3);
    Expected := Parts[0] + '.' + Parts[1] + '.' + Parts[2];
    Detected := Format('%d.%d.%d', [myx_get_mysql_major_version(My), myx_get_mysql_minor_version(My),
      myx_get_mysql_release(My)]);
    AssertEquals('version seen by the backend (server: ' + Value + ')', Expected, Detected);
    AssertEquals('later or equal than 5.7', 1, mysql_version_is_later_or_equal_than(My, 5, 7));
    AssertEquals('later or equal than itself', 1, mysql_full_version_is_later_or_equal_than(My,
      StrToInt(Parts[0]), StrToInt(Parts[1]), StrToInt(Parts[2])));
    AssertEquals('not later than the next major', 0, mysql_version_is_later_or_equal_than(My,
      StrToInt(Parts[0]) + 1, 0));
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

// the original's second attempt without the default schema stays for a schema that does not exist
procedure TConnectTest.TestMissingSchemaStillConnects;
var
  Conn: MYX_USER_CONNECTION;
  User, Pwd, Host, Schema: AnsiString;
  My: PMYSQL;
begin
  User := Env('QBR_TEST_USER', 'root');
  Pwd := Env('QBR_TEST_PASSWORD', 'qbr-test');
  Host := Env('QBR_TEST_HOST', '127.0.0.1');
  Schema := 'qbr_no_such_schema';
  FillConnection(Conn, User, Pwd, Host);
  Conn.schema := PAnsiChar(Schema);
  My := myx_mysql_init;
  try
    AssertEquals('connect without the missing schema (' + myx_mysql_error(My) + ')', 0,
      myx_connect_to_instance(@Conn, My));
  finally
    myx_mysql_close(My);
  end;
end;

// A host that never answers costs one connect timeout, not two: the second attempt only follows schema errors
// (2026-11-21; before, every failed connect was tried twice). 192.0.2.1 is TEST-NET-1, never routed.
procedure TConnectTest.TestUnreachableHostWaitsOnce;
var
  Conn: MYX_USER_CONNECTION;
  User, Pwd, Host, Schema, Timeout: AnsiString;
  Options: array[0..0] of PAnsiChar;
  My: PMYSQL;
  Start: QWord;
begin
  User := 'root';
  Pwd := 'x';
  Host := '192.0.2.1';
  Schema := 'mysql';
  Timeout := 'CONNECT_TIMEOUT=2';
  FillConnection(Conn, User, Pwd, Host);
  Conn.port := 3306;
  Conn.schema := PAnsiChar(Schema);
  Options[0] := PAnsiChar(Timeout);
  Conn.advanced_options := @Options[0];
  Conn.advanced_options_num := 1;
  My := myx_mysql_init;
  try
    Start := GetTickCount64;
    AssertTrue('must fail', myx_connect_to_instance(@Conn, My) <> 0);
    AssertTrue(Format('one attempt of 2 s, took %d ms', [GetTickCount64 - Start]), GetTickCount64 - Start < 3500);
  finally
    myx_mysql_close(My);
  end;
end;

initialization
  RegisterTest(TConnectTest);

end.
