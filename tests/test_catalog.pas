unit test_catalog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util, myx_base, test_support;

type
  TCatalogTest = class(TTestCase)
  private
    FMy: PMYSQL;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSchemaListed;
    procedure TestTablesAndViews;
    procedure TestColumnDetails;
  end;

implementation

const
  SchemaName = 'qbr_catalog_test';

procedure TCatalogTest.SetUp;
begin
  FMy := ConnectTestServer;
  ExecSQL(FMy, 'DROP DATABASE IF EXISTS ' + SchemaName);
  ExecSQL(FMy, 'CREATE DATABASE ' + SchemaName + ' DEFAULT CHARACTER SET utf8');
  ExecSQL(FMy, 'CREATE TABLE ' + SchemaName + '.person (' +
    'id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, ' +
    'name VARCHAR(50) NOT NULL DEFAULT ''anon'', ' +
    'note TEXT NULL)');
  ExecSQL(FMy, 'CREATE TABLE ' + SchemaName + '.pet (id INT PRIMARY KEY, owner_id INT)');
  ExecSQL(FMy, 'CREATE VIEW ' + SchemaName + '.v_person AS SELECT id, name FROM ' +
    SchemaName + '.person');
end;

procedure TCatalogTest.TearDown;
begin
  if FMy <> nil then
    ExecSQL(FMy, 'DROP DATABASE IF EXISTS ' + SchemaName);
  DisconnectTestServer(FMy);
end;

procedure TCatalogTest.TestSchemaListed;
var
  Cats: PMYX_CATALOGS;
  C, S: Integer;
  Cat: PMYX_CATALOG;
  Found: Boolean;
begin
  Cats := myx_get_catalogs(FMy);
  AssertNotNull('catalogs', Cats);
  try
    AssertTrue('at least one catalog', Cats^.catalogs_num >= 1);
    Found := False;
    for C := 0 to Cats^.catalogs_num - 1 do
    begin
      Cat := Cats^.catalogs + C;
      for S := 0 to Cat^.schemata_num - 1 do
        if SameText((Cat^.schemata + S)^.schema_name, SchemaName) then
          Found := True;
    end;
    AssertTrue('test schema is listed', Found);
  finally
    myx_free_catalogs(Cats);
  end;
end;

procedure TCatalogTest.TestTablesAndViews;
var
  Tabs: PMYX_SCHEMA_TABLES;
  I: Integer;
  T: PMYX_SCHEMA_TABLE;
  Names: TStringList;
begin
  Tabs := myx_get_schema_tables(FMy, nil, SchemaName);
  AssertNotNull('tables', Tabs);
  Names := TStringList.Create;
  try
    for I := 0 to Tabs^.schema_tables_num - 1 do
    begin
      T := Tabs^.schema_tables + I;
      Names.Add(T^.table_name + ':' + IntToStr(T^.table_type));
    end;
    Names.Sort;
    AssertEquals('tables: ' + Names.CommaText, 3, Names.Count);
    AssertEquals('person', 'person:' + IntToStr(MSTT_BASE_TABLE), Names[0]);
    AssertEquals('pet', 'pet:' + IntToStr(MSTT_BASE_TABLE), Names[1]);
    AssertEquals('v_person', 'v_person:' + IntToStr(MSTT_VIEW), Names[2]);
  finally
    Names.Free;
    myx_free_schema_tables(Tabs);
  end;
end;

procedure TCatalogTest.TestColumnDetails;
var
  Tabs: PMYX_SCHEMA_TABLES;
  I, J: Integer;
  T: PMYX_SCHEMA_TABLE;
  Col: PMYX_SCHEMA_TABLE_COLUMN;
  Checked: Integer;
begin
  Tabs := myx_get_schema_tables(FMy, nil, SchemaName);
  AssertNotNull('tables', Tabs);
  Checked := 0;
  try
    for I := 0 to Tabs^.schema_tables_num - 1 do
    begin
      T := Tabs^.schema_tables + I;
      if T^.table_name <> 'person' then
        Continue;
      AssertEquals('person column count', 3, T^.columns_num);
      for J := 0 to T^.columns_num - 1 do
      begin
        Col := T^.columns + J;
        if Col^.column_name = 'id' then
        begin
          AssertEquals('id primary key', 1, Col^.primary_key);
          AssertEquals('id not null', 1, Col^.not_null);
          AssertTrue('id type is int: ' + Col^.column_type, Pos('int', LowerCase(Col^.column_type)) = 1);
          AssertTrue('id extra has auto_increment', Pos('auto_increment', LowerCase(Col^.extra)) > 0);
          Inc(Checked);
        end
        else if Col^.column_name = 'name' then
        begin
          AssertEquals('name not primary', 0, Col^.primary_key);
          AssertEquals('name not null', 1, Col^.not_null);
          AssertEquals('name type', 'varchar(50)', LowerCase(Col^.column_type));
          AssertEquals('name default', 'anon', Col^.default_value);
          Inc(Checked);
        end
        else if Col^.column_name = 'note' then
        begin
          AssertEquals('note nullable', 0, Col^.not_null);
          AssertEquals('note type', 'text', LowerCase(Col^.column_type));
          Inc(Checked);
        end;
      end;
    end;
    AssertEquals('all three person columns checked', 3, Checked);
  finally
    myx_free_schema_tables(Tabs);
  end;
end;

initialization
  RegisterTest(TCatalogTest);

end.
