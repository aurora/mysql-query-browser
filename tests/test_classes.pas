{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_classes;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface,
  myx_public_interface, test_support;

type
  { The generated wrapper classes (TMYX_*) that the ported UI code works with. }
  TClassesTest = class(TTestCase)
  published
    procedure TestUserConnectionRoundTrip;
    procedure TestConnectWithClass;
    procedure TestCatalogsAsClasses;
    procedure TestStringWrapperFreesResult;
    procedure TestListAssignIsDeep;
    procedure TestNonAsciiThroughWideStringWrappers;
    procedure TestObjectFieldsAreConstructorParameters;
  end;

implementation

function NewConnection: TMYX_USER_CONNECTION;
begin
  Result := TMYX_USER_CONNECTION.Create('local test', 'user', 'secret', '127.0.0.1', 3306,
    'sch', '/tmp/x', 'some notes', MYX_MYSQL_CONN, MYX_HISTORY_USER_CONNECTION);
end;

procedure TClassesTest.TestUserConnectionRoundTrip;
var
  C, C2: TMYX_USER_CONNECTION;
  Rec: PMYX_USER_CONNECTION;
begin
  C := NewConnection;
  try
    C.advanced_options.Values['COMPRESS'] := 'Yes';
    C.advanced_options.Add('FOO=bar');
    Rec := C.get_record_pointer;
    AssertEquals('name', 'local test', String(Rec^.connection_name));
    AssertEquals('port', 3306, Integer(Rec^.port));
    AssertEquals('options count', 2, Integer(Rec^.advanced_options_num));
    AssertEquals('option 0', 'COMPRESS=Yes', String(Rec^.advanced_options[0]));
    AssertEquals('option 1', 'FOO=bar', String(Rec^.advanced_options[1]));
    AssertTrue('options terminated', Rec^.advanced_options[2] = nil);

    // and back into a new object
    C2 := TMYX_USER_CONNECTION.Create(Rec);
    try
      AssertEquals('username', 'user', C2.username);
      AssertEquals('notes', 'some notes', C2.notes);
      AssertEquals('type', Integer(MYX_MYSQL_CONN), Integer(C2.connection_type));
      AssertEquals('storage', Integer(MYX_HISTORY_USER_CONNECTION), Integer(C2.storage_type));
      AssertEquals('options', 2, C2.advanced_options.Count);
      AssertEquals('option value', 'bar', C2.advanced_options.Values['FOO']);
    finally
      C2.Free;
    end;

    // changing the object and asking again updates the same record
    C.username := 'other';
    C.advanced_options.Clear;
    Rec := C.get_record_pointer;
    AssertEquals('username updated', 'other', String(Rec^.username));
    AssertEquals('options cleared', 0, Integer(Rec^.advanced_options_num));
    AssertTrue('options freed', Rec^.advanced_options = nil);
  finally
    C.Free;
  end;
end;

procedure TClassesTest.TestConnectWithClass;
var
  My: PMYSQL;
  C: TMYX_USER_CONNECTION;
  Rec: PMYX_USER_CONNECTION;
begin
  // build the connection from the QBR_TEST_* settings, exactly like the connect dialog does
  My := ConnectTestServer;       // validates the settings
  DisconnectTestServer(My);
  C := TMYX_USER_CONNECTION.Create('t', GetEnvironmentVariable('QBR_TEST_USER'),
    GetEnvironmentVariable('QBR_TEST_PASSWORD'), GetEnvironmentVariable('QBR_TEST_HOST'),
    StrToIntDef(GetEnvironmentVariable('QBR_TEST_PORT'), 33306), '', '', '',
    MYX_MYSQL_CONN, MYX_HISTORY_USER_CONNECTION);
  try
    if C.username = '' then C.username := 'root';
    if C.password = '' then C.password := 'qbr-test';
    if C.hostname = '' then C.hostname := '127.0.0.1';
    Rec := C.get_record_pointer;
    My := myx_mysql_init;
    try
      AssertEquals('connect (' + myx_mysql_error(My) + ')', 0, myx_connect_to_instance(Rec, My));
    finally
      myx_mysql_close(My);
    end;
  finally
    C.Free;
  end;
end;

procedure TClassesTest.TestCatalogsAsClasses;
var
  My: PMYSQL;
  Raw: PMYX_CATALOGS;
  Cats: TMYX_CATALOGS;
  I: Integer;
  Found: Boolean;
begin
  My := ConnectTestServer;
  try
    Raw := myx_get_catalogs(My);
    AssertNotNull('catalogs', Raw);
    try
      Cats := TMYX_CATALOGS.Create(Raw);       // copies everything into Pascal objects
    finally
      myx_free_catalogs(Raw);                 // the C data is released like in the old code
    end;
    try
      AssertTrue('a catalog', Cats.catalogs.Count >= 1);
      Found := False;
      for I := 0 to Cats.catalogs[0].schemata.Count - 1 do
        if SameText(Cats.catalogs[0].schemata[I].schema_name, 'mysql') then
          Found := True;
      AssertTrue('schema mysql is listed (data survives myx_free_catalogs)', Found);
    finally
      Cats.Free;
    end;
  finally
    DisconnectTestServer(My);
  end;
end;

procedure TClassesTest.TestStringWrapperFreesResult;
var
  My: PMYSQL;
  S: String;
  I: Integer;
begin
  My := ConnectTestServer;
  try
    // myx_mysql_error returns a g_strdup'ed string; the wrapper converts and g_free()s it
    for I := 1 to 1000 do
      S := myx_mysql_error(My);
    AssertEquals('no error pending', '', S);
    AssertEquals('quoted', '`a`', myx_convert_dbstr_utf8(My, '`a`'));
  finally
    DisconnectTestServer(My);
  end;
end;

procedure TClassesTest.TestListAssignIsDeep;
var
  A, B: TMYX_USER_CONNECTIONS;
  C: TMYX_USER_CONNECTION;
begin
  A := TMYX_USER_CONNECTIONS.Create(PMYX_USER_CONNECTIONS(nil));
  B := TMYX_USER_CONNECTIONS.Create(PMYX_USER_CONNECTIONS(nil));
  try
    C := NewConnection;
    A.user_connections.Add(C);
    B.Assign(A);
    AssertEquals('copied', 1, B.user_connections.Count);
    AssertFalse('different objects', B.user_connections[0] = A.user_connections[0]);
    A.user_connections[0].username := 'changed';
    AssertEquals('copy unaffected', 'user', B.user_connections[0].username);
  finally
    A.Free;
    B.Free;
  end;
end;

procedure TClassesTest.TestNonAsciiThroughWideStringWrappers;
var
  My: PMYSQL;
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
  Text, Got: String;
begin
  Text := 'K' + #$C3#$A4 + 'se ' + #$E2#$82#$AC;                 // "Kaese" with a-umlaut, plus euro sign
  My := ConnectTestServer;
  try
    Err := MYX_NO_ERROR;
    // the SQL travels as WideString through the wrapper and is UTF-8 encoded on the way to C
    Rs := myx_query_execute(My, 'SELECT ''' + Text + ''' AS x', 0, nil, @Err, nil, nil, nil, nil);
    AssertNotNull('resultset', Rs);
    try
      AssertEquals('error code', Integer(MYX_NO_ERROR), Integer(Err));
      SetString(Got, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
      AssertEquals('text survives the round trip', Text, Got);
    finally
      myx_query_free_resultset(Rs);
    end;
  finally
    DisconnectTestServer(My);
  end;
end;

procedure TClassesTest.TestObjectFieldsAreConstructorParameters;
var
  My: PMYSQL;
  Tables: PMYX_SCHEMA_TABLES;
  Schema, Empty: TMYX_SCHEMA;
begin
  // The original mapper made object fields constructor parameters (as record pointers), the way the
  // schema tree calls TMYX_SCHEMA.Create(name, escaped_name, catalog, nil, nil, nil).
  Empty := TMYX_SCHEMA.Create('s', 's', 'def', nil, nil, nil);
  try
    AssertEquals('name', 's', Empty.schema_name);
    AssertNull('no tables object', Empty.schema_tables);
  finally
    Empty.Free;
  end;

  My := ConnectTestServer;
  try
    Tables := myx_get_schema_tables(My, '', 'mysql');
    AssertNotNull('tables', Tables);
    try
      Schema := TMYX_SCHEMA.Create('mysql', 'mysql', 'def', Tables, nil, nil);   // copies from the pointer
    finally
      myx_free_schema_tables(Tables);
    end;
    try
      AssertNotNull('tables object built from the pointer', Schema.schema_tables);
      AssertTrue('the mysql schema has tables', Schema.schema_tables.schema_tables.Count > 0);
    finally
      Schema.Free;
    end;
  finally
    DisconnectTestServer(My);
  end;
end;

initialization
  RegisterTest(TClassesTest);

end.
