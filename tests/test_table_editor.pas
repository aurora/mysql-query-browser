{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_table_editor;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface,
  test_support;

type
  { The table editor's model (myx_database_model.c): read a table, hand it through the Pascal class as
    EditorTable.pas does, and let the backend write the SQL for it. Four checks per table:

    - unchanged: the diff between the table and its unedited copy must be empty, otherwise the editor would
      change a table the user did not touch;
    - table comment edited, and a comment on every column: the editor's ALTER TABLE must have the same effect
      as plain ALTER TABLE ... COMMENT / MODIFY COLUMN ... COMMENT statements on a twin table (compared by
      SHOW CREATE TABLE), so the edit loses nothing else (engine, column types, defaults, indices, foreign
      keys, collations, generated columns ...). The column comments make the backend write every column
      definition again from its model;
    - the table read as a new one: the backend's CREATE TABLE must give the same definition as the twin.

    Tables that need a feature the server lacks are skipped on that server. }
  TTableEditorTest = class(TTestCase)
  private
    FMy: PMYSQL;
    FDatatypes: PMYX_DBM_DATATYPES;
    FVersion: PMYX_DBM_SERVER_VERSION;
    FMariaDB: Boolean;
    FMajor, FMinor, FPatch: Integer;
    function Value(const SQL: AnsiString; Column: Integer = 0): AnsiString;
    function ShowCreate(const Table: string): string;
    function AtLeast(Major, Minor, Patch: Integer): Boolean;
    procedure ExecScript(const SQL: string);
    function ReadTable(const Table: string): TMYX_DBM_TABLE_DATA;
    function DiffSQL(const Table: string; Edited: TMYX_DBM_TABLE_DATA): string;
    procedure ApplyAndCompare(const Table, Twin, What, Sql, TwinSQL: string);
    function ColumnCommentSQL(const Twin: string): string;
    procedure CheckTable(const Table, Body, Options: string; AsNewTable: Boolean = True);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestBasicInnoDB;
    procedure TestForeignKey;
    procedure TestMyISAM;
    procedure TestMemory;
    procedure TestTypes;
    procedure TestNewerTypes;
    procedure TestJson;
    procedure TestGeneratedColumns;
    procedure TestCheckConstraint;
    procedure TestColumnCollation;
    procedure TestAria;
    procedure TestInvisibleColumn;
    procedure TestFunctionalIndex;
    procedure TestEngineChange;
    procedure TestCharsets;
  end;

implementation

const
  SchemaName = 'qbr_tableedit_test';
  NewComment = 'edited by the table editor test';

function Env(const Name, Default: string): string;
begin
  Result := GetEnvironmentVariable(Name);
  if Result = '' then
    Result := Default;
end;

procedure TTableEditorTest.SetUp;
var
  Err: MYX_LIB_ERROR;
  V: string;
  Parts: TStringArray;
begin
  FMy := ConnectTestServer;
  V := Value('SELECT VERSION()');
  FMariaDB := Pos('mariadb', LowerCase(V)) > 0;
  Parts := V.Split(['.', '-']);
  FMajor := StrToIntDef(Parts[0], 0);
  FMinor := StrToIntDef(Parts[1], 0);
  FPatch := StrToIntDef(Parts[2], 0);

  Err := MYX_NO_ERROR;
  FDatatypes := myx_datatype_load(Env('QBR_TEST_XMLDIR', ExtractFilePath(ParamStr(0)) +
    '../../app/xml/') + 'mysqlx_dbm_datatypes.xml', @Err);
  AssertNotNull('datatypes loaded', FDatatypes);
  FVersion := myx_dbm_retrieve_server_version(FMy);

  ExecSQL(FMy, 'DROP DATABASE IF EXISTS ' + SchemaName);
  ExecSQL(FMy, 'CREATE DATABASE ' + SchemaName + ' DEFAULT CHARACTER SET utf8mb4');
  ExecSQL(FMy, 'USE ' + SchemaName);
end;

procedure TTableEditorTest.TearDown;
begin
  if FMy <> nil then
    ExecSQL(FMy, 'DROP DATABASE IF EXISTS ' + SchemaName);
  if FVersion <> nil then
    myx_dbm_free_server_version(FVersion);
  DisconnectTestServer(FMy);
end;

function TTableEditorTest.Value(const SQL: AnsiString; Column: Integer): AnsiString;
var
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
  F: PMYX_RS_FIELD;
begin
  Err := MYX_NO_ERROR;
  Rs := myx_query_execute(FMy, SQL, 0, nil, @Err, nil, nil, nil, nil);
  AssertNotNull(SQL, Rs);
  try
    F := Rs^.rows^.fields + Column;
    SetString(Result, F^.value, F^.value_length);
  finally
    myx_query_free_resultset(Rs);
  end;
end;

function TTableEditorTest.ShowCreate(const Table: string): string;
var
  I: Integer;
begin
  Result := Value('SHOW CREATE TABLE ' + SchemaName + '.' + Table, 1);
  // the counter differs between the twins and is not part of the definition
  I := Pos(' AUTO_INCREMENT=', Result);
  if I > 0 then
    Delete(Result, I, PosEx(' ', Result + ' ', I + 1) - I);
end;

function TTableEditorTest.AtLeast(Major, Minor, Patch: Integer): Boolean;
begin
  Result := (FMajor > Major) or ((FMajor = Major) and ((FMinor > Minor) or ((FMinor = Minor) and (FPatch >= Patch))));
end;

// the diff may hold several statements, each ending with ";" at the end of a line
procedure TTableEditorTest.ExecScript(const SQL: string);
var
  Lines: TStringList;
  Stmt, L: string;
  I: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := SQL;
    Stmt := '';
    for I := 0 to Lines.Count - 1 do
    begin
      L := Lines[I];
      Stmt := Stmt + L + LineEnding;
      if AnsiEndsStr(';', TrimRight(L)) then
      begin
        Stmt := Trim(Stmt);
        SetLength(Stmt, Length(Stmt) - 1);
        if Trim(Stmt) <> '' then
          ExecSQL(FMy, Stmt);
        Stmt := '';
      end;
    end;
    if Trim(Stmt) <> '' then
      ExecSQL(FMy, Trim(Stmt));
  finally
    Lines.Free;
  end;
end;

// what EditorTable.EditSchemaTable does: read, then keep the table in the Pascal class
function TTableEditorTest.ReadTable(const Table: string): TMYX_DBM_TABLE_DATA;
var
  Err: MYX_LIB_ERROR;
  Retrieved: PMYX_DBM_TABLE_DATA;
begin
  Err := MYX_NO_ERROR;
  Retrieved := myx_dbm_retrieve_table_data(FMy, FDatatypes, '', SchemaName, Table, @Err);
  AssertTrue(Table + ': read the table', (Retrieved <> nil) and (Err = MYX_NO_ERROR));
  try
    Result := TMYX_DBM_TABLE_DATA.Create(Retrieved);
  finally
    myx_dbm_free_table_data(Retrieved);
  end;
end;

// what EditorTable.ApplyChanges does: read the table again and diff against the edited copy
function TTableEditorTest.DiffSQL(const Table: string; Edited: TMYX_DBM_TABLE_DATA): string;
var
  Err: MYX_LIB_ERROR;
  Existing: PMYX_DBM_TABLE_DATA;
begin
  Err := MYX_NO_ERROR;
  Existing := myx_dbm_retrieve_table_data(FMy, FDatatypes, '', SchemaName, Table, @Err);
  try
    Result := myx_dbm_get_table_sql_diff(Existing, Edited.get_record_pointer, FVersion, @Err);
  finally
    myx_dbm_free_table_data(Existing);
  end;
end;

// runs the editor's SQL on Table and TwinSQL on the twin, then compares both definitions
procedure TTableEditorTest.ApplyAndCompare(const Table, Twin, What, Sql, TwinSQL: string);
var
  Expected, Actual: string;
begin
  AssertTrue(Table + ': ' + What + ' gives SQL', Sql <> '');
  try
    ExecScript(Sql);
  except
    on E: Exception do
      Fail(Table + ': ' + What + ': the generated SQL fails: ' + E.Message);
  end;
  ExecSQL(FMy, TwinSQL);
  Expected := StringReplace(ShowCreate(Twin), Twin, Table, [rfReplaceAll]);
  Actual := ShowCreate(Table);
  AssertEquals(Table + ': ' + What + ' changed nothing else' + LineEnding + 'SQL: ' + Sql, Expected, Actual);
end;

// the twin's ALTER TABLE for a comment on every column: each column line of SHOW CREATE TABLE, with COMMENT
function TTableEditorTest.ColumnCommentSQL(const Twin: string): string;
var
  Lines: TStringList;
  L: string;
  I, J: Integer;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := ShowCreate(Twin);
    for I := 0 to Lines.Count - 1 do
    begin
      L := Trim(Lines[I]);
      if (L = '') or (L[1] <> '`') then
        Continue;
      if L[Length(L)] = ',' then
        SetLength(L, Length(L) - 1);
      if Result <> '' then
        Result := Result + ', ';
      // the comment goes before a column CHECK (MariaDB's JSON columns carry CHECK (json_valid(...)))
      J := Pos(' CHECK (', L);
      if J > 0 then
        Insert(' COMMENT ''' + NewComment + '''', L, J)
      else
        L := L + ' COMMENT ''' + NewComment + '''';
      Result := Result + 'MODIFY COLUMN ' + L;
    end;
  finally
    Lines.Free;
  end;
  Result := 'ALTER TABLE ' + Twin + ' ' + Result;
end;

procedure TTableEditorTest.CheckTable(const Table, Body, Options: string; AsNewTable: Boolean);
var
  Edited: TMYX_DBM_TABLE_DATA;
  Sql, Twin: string;
  I: Integer;
  Err: MYX_LIB_ERROR;
begin
  Twin := Table + '_ref';
  ExecSQL(FMy, 'CREATE TABLE ' + Table + ' (' + Body + ') ' + Options);
  ExecSQL(FMy, 'CREATE TABLE ' + Twin + ' (' + Body + ') ' + Options);

  // 1. unchanged
  Edited := ReadTable(Table);
  try
    AssertEquals(Table + ': unchanged table gives no SQL', '', DiffSQL(Table, Edited));

    // 2. table comment (table options only)
    Edited.comment := NewComment;
    Sql := DiffSQL(Table, Edited);
  finally
    Edited.Free;
  end;
  ApplyAndCompare(Table, Twin, 'the table comment', Sql,
    'ALTER TABLE ' + Twin + ' COMMENT = ''' + NewComment + '''');

  // 3. a comment on every column: the backend writes each column definition again from its model
  Edited := ReadTable(Table);
  try
    for I := 0 to Edited.columns.Count - 1 do
      Edited.columns[I].comment := NewComment;
    Sql := DiffSQL(Table, Edited);
  finally
    Edited.Free;
  end;
  ApplyAndCompare(Table, Twin, 'the column comments', Sql, ColumnCommentSQL(Twin));

  // 4. the table as a new one (CREATE TABLE, as for a table the editor creates): the same definition as the twin
  if not AsNewTable then
    Exit;
  Edited := ReadTable(Twin);
  try
    Edited.name := Table + '_new';
    Edited.original_name := '';
    // constraint names are unique per schema
    for I := 0 to Edited.fks.Count - 1 do
      Edited.fks[I].name := StringReplace(Edited.fks[I].name, Twin, Table + '_new', []);
    Err := MYX_NO_ERROR;
    Sql := myx_dbm_get_table_sql_diff(nil, Edited.get_record_pointer, FVersion, @Err);
  finally
    Edited.Free;
  end;
  AssertTrue(Table + ': CREATE TABLE gives SQL', Sql <> '');
  try
    ExecScript(Sql);
  except
    on E: Exception do
      Fail(Table + ': the generated CREATE TABLE fails: ' + E.Message);
  end;
  AssertEquals(Table + ': CREATE TABLE gives the same table' + LineEnding + 'SQL: ' + Sql,
    StringReplace(ShowCreate(Twin), Twin, Table, [rfReplaceAll]),
    StringReplace(ShowCreate(Table + '_new'), Table + '_new', Table, [rfReplaceAll]));
end;

procedure TTableEditorTest.TestBasicInnoDB;
begin
  CheckTable('te_basic',
    'id INT NOT NULL AUTO_INCREMENT, ' +
    'email VARCHAR(100) NOT NULL, ' +
    'country CHAR(2) NOT NULL DEFAULT ''DE'', ' +
    'created DATETIME NULL, ' +
    'note TEXT, ' +
    'PRIMARY KEY (id), ' +
    'UNIQUE KEY uq_email (email), ' +
    'KEY idx_country_created (country, created)',
    'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT=''accounts''');
end;

procedure TTableEditorTest.TestForeignKey;
begin
  ExecSQL(FMy, 'CREATE TABLE te_parent (id INT NOT NULL PRIMARY KEY) ENGINE=InnoDB');
  CheckTable('te_fk',
    'id INT NOT NULL AUTO_INCREMENT, ' +
    'parent_id INT NOT NULL, ' +
    'other_id INT NULL, ' +
    'PRIMARY KEY (id), ' +
    'KEY idx_parent (parent_id), ' +
    'KEY idx_other (other_id), ' +
    'FOREIGN KEY (parent_id) REFERENCES te_parent (id) ON DELETE CASCADE ON UPDATE RESTRICT, ' +
    'FOREIGN KEY (other_id) REFERENCES te_parent (id) ON DELETE SET NULL ON UPDATE CASCADE',
    'ENGINE=InnoDB');
end;

procedure TTableEditorTest.TestMyISAM;
begin
  CheckTable('te_myisam', 'id INT NOT NULL PRIMARY KEY, name VARCHAR(20)', 'ENGINE=MyISAM');
end;

procedure TTableEditorTest.TestMemory;
begin
  CheckTable('te_memory', 'id INT NOT NULL PRIMARY KEY, name VARCHAR(20)', 'ENGINE=MEMORY');
end;

procedure TTableEditorTest.TestTypes;
begin
  CheckTable('te_types',
    'id INT UNSIGNED NOT NULL PRIMARY KEY, ' +
    'small TINYINT UNSIGNED NOT NULL DEFAULT 0, ' +
    'big BIGINT NULL, ' +
    'price DECIMAL(10,2) NOT NULL DEFAULT 0.00, ' +
    'ratio DOUBLE NULL, ' +
    'flags BIT(3) NULL, ' +
    'kind ENUM(''a'',''b'',''c'') NOT NULL DEFAULT ''a'', ' +
    'tags SET(''x'',''y'') NULL, ' +
    'born DATE NULL, ' +
    'at_time TIME NULL, ' +
    'stamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ' +
    'data BLOB NULL, ' +
    'body MEDIUMTEXT NULL',
    'ENGINE=InnoDB');
end;

procedure TTableEditorTest.TestNewerTypes;
var
  T: TMYX_DBM_TABLE_DATA;
  I, N: Integer;
begin
  // not in the original's mysqlx_dbm_datatypes.xml, added by ADR-0034
  CheckTable('te_newer',
    'id INT NOT NULL PRIMARY KEY, ' +
    'y YEAR NULL, ' +
    'b BINARY(4) NULL, ' +
    'vb VARBINARY(10) NULL, ' +
    'ms DATETIME(3) NULL',
    'ENGINE=InnoDB');
  ExecSQL(FMy, 'CREATE TABLE te_newer_json (id INT NOT NULL PRIMARY KEY, doc JSON NULL)');
  for N := 0 to 1 do
  begin
    if N = 0 then
      T := ReadTable('te_newer')
    else
      T := ReadTable('te_newer_json');
    try
      for I := 0 to T.columns.Count - 1 do
        // MariaDB reports JSON as longtext, which is in the list anyway
        AssertTrue(T.name + '.' + T.columns[I].name + ': the type is in the data type list (' +
          T.columns[I].datatype_name + ')', T.columns[I].datatype_pointer <> nil);
    finally
      T.Free;
    end;
  end;
end;

procedure TTableEditorTest.TestJson;
begin
  CheckTable('te_json', 'id INT NOT NULL PRIMARY KEY, doc JSON NULL', 'ENGINE=InnoDB');
end;

procedure TTableEditorTest.TestGeneratedColumns;
begin
  CheckTable('te_generated',
    'id INT NOT NULL PRIMARY KEY, ' +
    'a INT NOT NULL, ' +
    'b INT GENERATED ALWAYS AS (a * 2) STORED, ' +
    'c INT GENERATED ALWAYS AS (a + 1) VIRTUAL',
    'ENGINE=InnoDB');
end;

procedure TTableEditorTest.TestCheckConstraint;
begin
  // MySQL enforces (and shows) CHECK from 8.0.16; 5.7 parses and drops it
  if not FMariaDB and not AtLeast(8, 0, 16) then
    Exit;
  // table CHECK constraints are not in the editor's model: edits keep them (ALTER TABLE does not touch them), but
  // the editor cannot create them, so a copy as a new table would not have them
  CheckTable('te_check', 'id INT NOT NULL PRIMARY KEY, qty INT NOT NULL, CHECK (qty > 0)',
    'ENGINE=InnoDB', False);
end;

procedure TTableEditorTest.TestColumnCollation;
var
  Collation: string;
begin
  if FMariaDB or (FMajor < 8) then
    Collation := 'utf8mb4_unicode_ci'
  else
    Collation := 'utf8mb4_0900_as_cs';
  CheckTable('te_collation',
    'id INT NOT NULL PRIMARY KEY, ' +
    'name VARCHAR(50) CHARACTER SET utf8mb4 COLLATE ' + Collation + ' NOT NULL, ' +
    'code VARCHAR(10) CHARACTER SET latin1 COLLATE latin1_bin NULL',
    'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4');
end;

procedure TTableEditorTest.TestAria;
begin
  if not FMariaDB then
    Exit;
  CheckTable('te_aria', 'id INT NOT NULL PRIMARY KEY, name VARCHAR(20)', 'ENGINE=Aria');
end;

procedure TTableEditorTest.TestInvisibleColumn;
begin
  if FMariaDB then
  begin
    if not AtLeast(10, 3, 3) then
      Exit;
  end
  else if not AtLeast(8, 0, 23) then
    Exit;
  CheckTable('te_invisible', 'id INT NOT NULL PRIMARY KEY, secret INT NULL INVISIBLE', 'ENGINE=InnoDB');
end;

procedure TTableEditorTest.TestFunctionalIndex;
begin
  if FMariaDB or not AtLeast(8, 0, 13) then
    Exit;
  CheckTable('te_funcindex', 'id INT NOT NULL PRIMARY KEY, name VARCHAR(50) NOT NULL, KEY idx_lower ((LOWER(name)))',
    'ENGINE=InnoDB');
end;

// what EditorTable sets when another engine is chosen (ADR-0034): the enumeration value and the engine's name
procedure TTableEditorTest.TestEngineChange;

  procedure ChangeEngine(const Table: string; Engine: MYX_DBM_TABLE_ENGINE; const EngineName, Expected: string);
  var
    Edited: TMYX_DBM_TABLE_DATA;
    Sql: string;
  begin
    Edited := ReadTable(Table);
    try
      Edited.table_engine := Engine;
      Edited.engine_name := EngineName;
      Sql := DiffSQL(Table, Edited);
    finally
      Edited.Free;
    end;
    AssertTrue(Table + ' to ' + EngineName + ' gives SQL', Sql <> '');
    ExecScript(Sql);
    AssertTrue(Table + ' is ' + Expected + ' now' + LineEnding + 'SQL: ' + Sql,
      Pos('ENGINE=' + Expected + ' ', ShowCreate(Table)) > 0);
    // reading it again gives no SQL
    Edited := ReadTable(Table);
    try
      AssertEquals(Table + ' as ' + Expected + ' unchanged', '', DiffSQL(Table, Edited));
    finally
      Edited.Free;
    end;
  end;

begin
  ExecSQL(FMy, 'CREATE TABLE te_engine (id INT NOT NULL PRIMARY KEY, name VARCHAR(20)) ENGINE=MyISAM');
  ChangeEngine('te_engine', MYX_DBM_TE_INNODB, 'INNODB', 'InnoDB');
  if FMariaDB then
  begin
    // Aria has no value of its own; the name decides
    ChangeEngine('te_engine', MYX_DBM_TE_MYISAM, 'Aria', 'Aria');
    ChangeEngine('te_engine', MYX_DBM_TE_MYISAM, 'MYISAM', 'MyISAM');
  end
  else
    ChangeEngine('te_engine', MYX_DBM_TE_MYISAM, 'MYISAM', 'MyISAM');
end;

// the editor reads all character sets and collations when it opens; MariaDB 10.10+ lists collations without
// character set and id, which crashed it (nothing happened on "Edit Table")
procedure TTableEditorTest.TestCharsets;
var
  Err: MYX_LIB_ERROR;
  Cs: PMYX_DBM_CHARSETS;
  C: PMYX_DBM_CHARSET;
  Col: PMYX_DBM_COLLATION;
  I, J: Integer;
  FoundUtf8mb4: Boolean;
begin
  Err := MYX_NO_ERROR;
  Cs := myx_dbm_retrieve_charsets(FMy, @Err);
  AssertTrue('character sets read', (Cs <> nil) and (Err = MYX_NO_ERROR));
  try
    FoundUtf8mb4 := False;
    for I := 0 to Integer(Cs^.charsets_num) - 1 do
    begin
      C := Cs^.charsets + I;
      if C^.name = 'utf8mb4' then
      begin
        FoundUtf8mb4 := True;
        AssertTrue('utf8mb4 has collations', C^.collations_num > 0);
      end;
      for J := 0 to Integer(C^.collations_num) - 1 do
      begin
        Col := C^.collations + J;
        AssertTrue(string(C^.name) + ': collation ' + string(Col^.name) + ' belongs to it',
          (string(Col^.name) = string(C^.name)) or (Pos(string(C^.name) + '_', string(Col^.name)) = 1));
      end;
    end;
    AssertTrue('utf8mb4 found', FoundUtf8mb4);
  finally
    myx_free_charsets(Cs);
  end;
end;

initialization
  RegisterTest(TTableEditorTest);
end.
