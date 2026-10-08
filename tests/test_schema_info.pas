unit test_schema_info;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util, myx_base, test_support;

type
  { Indices, table status and stored routines; these are the queries that
    differ most between MySQL 5.7 and 8.x. }
  TSchemaInfoTest = class(TTestCase)
  private
    FMy: PMYSQL;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestIndices;
    procedure TestTableStatus;
    procedure TestStoredRoutines;
  end;

implementation

const
  SchemaName = 'qbr_schemainfo_test';

procedure TSchemaInfoTest.SetUp;
begin
  FMy := ConnectTestServer;
  ExecSQL(FMy, 'DROP DATABASE IF EXISTS ' + SchemaName);
  ExecSQL(FMy, 'CREATE DATABASE ' + SchemaName + ' DEFAULT CHARACTER SET utf8');
  ExecSQL(FMy, 'CREATE TABLE ' + SchemaName + '.account (' +
    'id INT NOT NULL AUTO_INCREMENT, ' +
    'email VARCHAR(100) NOT NULL, ' +
    'country CHAR(2) NOT NULL, ' +
    'created DATETIME NULL, ' +
    'PRIMARY KEY (id), ' +
    'UNIQUE KEY uq_email (email), ' +
    'KEY idx_country_created (country, created)' +
    ') ENGINE=InnoDB COMMENT=''test accounts''');
  ExecSQL(FMy, 'INSERT INTO ' + SchemaName + '.account (email, country) VALUES ' +
    '(''a@example.org'', ''DE''), (''b@example.org'', ''AT'')');
  ExecSQL(FMy, 'CREATE PROCEDURE ' + SchemaName + '.p_add(IN a INT, OUT b INT) ' +
    'COMMENT ''adds one'' SET b = a + 1');
  ExecSQL(FMy, 'CREATE FUNCTION ' + SchemaName + '.f_twice(x INT) RETURNS INT ' +
    'DETERMINISTIC RETURN x * 2');
end;

procedure TSchemaInfoTest.TearDown;
begin
  if FMy <> nil then
    ExecSQL(FMy, 'DROP DATABASE IF EXISTS ' + SchemaName);
  DisconnectTestServer(FMy);
end;

procedure TSchemaInfoTest.TestIndices;
var
  Idx: PMYX_SCHEMA_INDICES;
  I: Integer;
  Ix: PMYX_TABLE_INDEX;
  Seen: TStringList;
begin
  Idx := myx_get_schema_indices(FMy, nil, SchemaName);
  AssertNotNull('indices', Idx);
  Seen := TStringList.Create;
  try
    for I := 0 to Idx^.indices_num - 1 do
    begin
      Ix := Idx^.indices + I;
      Seen.Add(Ix^.key_name);
      if Ix^.key_name = 'PRIMARY' then
      begin
        AssertEquals('primary is unique', 1, Ix^.unique);
        AssertEquals('primary columns', 1, Ix^.index_columns_num);
        AssertEquals('primary column name', 'id', Ix^.index_columns^.column_name);
      end
      else if Ix^.key_name = 'uq_email' then
      begin
        AssertEquals('uq_email is unique', 1, Ix^.unique);
        AssertEquals('uq_email table', 'account', Ix^.table_name);
      end
      else if Ix^.key_name = 'idx_country_created' then
      begin
        AssertEquals('idx_country_created is not unique', 0, Ix^.unique);
        AssertEquals('composite column count', 2, Ix^.index_columns_num);
        AssertEquals('first column', 'country', Ix^.index_columns^.column_name);
        AssertEquals('second column', 'created', (Ix^.index_columns + 1)^.column_name);
      end;
    end;
    Seen.Sort;
    AssertEquals('index names: ' + Seen.CommaText, 3, Seen.Count);
  finally
    Seen.Free;
    myx_free_schema_indices(Idx);
  end;
end;

procedure TSchemaInfoTest.TestTableStatus;
var
  St: PMYX_SCHEMA_TABLE_STATUS;
  T: PMYX_TABLE_STATUS;
begin
  St := myx_get_schema_table_status(FMy, nil, SchemaName);
  AssertNotNull('table status', St);
  try
    AssertEquals('one table', 1, St^.schema_tables_num);
    T := St^.schema_tables;
    AssertEquals('name', 'account', T^.table_name);
    AssertEquals('engine', 'innodb', LowerCase(T^.table_type));
    AssertEquals('comment', 'test accounts', T^.comment);
    AssertEquals('not invalid', 0, T^.invalid);
    AssertEquals('auto_increment is next id', '3', T^.auto_increment);
  finally
    myx_free_schema_table_status(St);
  end;
end;

procedure TSchemaInfoTest.TestStoredRoutines;
var
  Sps: PMYX_SCHEMA_STORED_PROCEDURES;
  I: Integer;
  Sp: PMYX_SCHEMA_STORED_PROCEDURE;
  GotProc, GotFunc: Boolean;
begin
  Sps := myx_get_schema_sps(FMy, nil, SchemaName);
  AssertNotNull('routines', Sps);
  GotProc := False;
  GotFunc := False;
  try
    AssertEquals('routine count', 2, Sps^.schema_sps_num);
    for I := 0 to Sps^.schema_sps_num - 1 do
    begin
      Sp := Sps^.schema_sps + I;
      if Sp^.name = 'p_add' then
      begin
        AssertEquals('p_add is a procedure', MSPT_PROCEDURE, Sp^.sp_type);
        AssertEquals('p_add comment', 'adds one', Sp^.comment);
        AssertEquals('p_add params', 2, Sp^.params_num);
        AssertEquals('param 1 is IN', MSPPT_IN, Sp^.params^.param_type);
        AssertEquals('param 1 name', 'a', Sp^.params^.name);
        AssertEquals('param 2 is OUT', MSPPT_OUT, (Sp^.params + 1)^.param_type);
        GotProc := True;
      end
      else if Sp^.name = 'f_twice' then
      begin
        AssertEquals('f_twice is a function', MSPT_FUNCTION, Sp^.sp_type);
        AssertTrue('f_twice returns int', Pos('int', LowerCase(Sp^.return_datatype)) = 1);
        GotFunc := True;
      end;
    end;
    AssertTrue('procedure found', GotProc);
    AssertTrue('function found', GotFunc);
  finally
    myx_free_schema_sps(Sps);
  end;
end;

initialization
  RegisterTest(TSchemaInfoTest);

end.
