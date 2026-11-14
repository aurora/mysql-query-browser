{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_edit_escaping;

{ Editing in the result grid builds UPDATE/INSERT/DELETE statements in myx_recordset.c. Values of every
  column type are escaped and column names quoted with doubled backticks, so a typed value or an unusual
  name cannot change which rows a statement affects. Needs a server (QBR_TEST_*). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface,
  test_support;

type
  TEditEscapingTest = class(TTestCase)
  private
    FMy: PMYSQL;
    function Value(const SQL: AnsiString): AnsiString;
    function Edit(Column: Integer; const NewValue: AnsiString): Integer;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestQuoteInNumberValue;
    procedure TestBacktickInNames;
  end;

implementation

const
  Table = 'qbr_edit.`t``x`';

procedure TEditEscapingTest.SetUp;
begin
  FMy := ConnectTestServer;
  ExecSQL(FMy, 'DROP DATABASE IF EXISTS qbr_edit');
  ExecSQL(FMy, 'CREATE DATABASE qbr_edit');
  ExecSQL(FMy, 'CREATE TABLE ' + Table + ' (id INT PRIMARY KEY, `n``x` INT, d DATE)');
  ExecSQL(FMy, 'INSERT INTO ' + Table + ' VALUES (1, 10, ''2026-01-01''), (2, 20, ''2026-01-02'')');
end;

procedure TEditEscapingTest.TearDown;
begin
  if FMy <> nil then
  begin
    ExecSQL(FMy, 'DROP DATABASE IF EXISTS qbr_edit');
    DisconnectTestServer(FMy);
  end;
end;

function TEditEscapingTest.Value(const SQL: AnsiString): AnsiString;
var
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
begin
  Err := MYX_NO_ERROR;
  Rs := myx_query_execute(FMy, SQL, 0, nil, @Err, nil, nil, nil, nil);
  AssertNotNull(SQL, Rs);
  try
    SetString(Result, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
  finally
    myx_query_free_resultset(Rs);
  end;
end;

// edits the first row (id 1) like the grid does; returns the number of errors
function TEditEscapingTest.Edit(Column: Integer; const NewValue: AnsiString): Integer;
var
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
  Action: PMYX_RS_ACTION;
  Errors: PMYX_RS_ACTION_ERRORS;
begin
  Err := MYX_NO_ERROR;
  Rs := myx_query_execute(FMy, 'SELECT * FROM ' + Table + ' ORDER BY id', 1, nil, @Err, nil, nil, nil, nil);
  AssertNotNull('result set', Rs);
  try
    AssertEquals('editable', 1, Rs^.editable);
    Action := _myx_query_create_action(MYX_RSA_UPDATE, 0,
      PMYX_RS_COLUMN(PtrUInt(Rs^.columns) + PtrUInt(SizeOf(MYX_RS_COLUMN) * Column)),
      Length(NewValue), PAnsiChar(NewValue));
    try
      myx_query_add_action(Rs, Action);
    finally
      myx_query_free_action(Action);
    end;
    Errors := myx_query_apply_actions(Rs);
    Result := 0;
    if Errors <> nil then
    begin
      Result := Errors^.errors_num;
      myx_query_free_action_errors(Errors);
    end;
  finally
    myx_query_free_resultset(Rs);
  end;
end;

procedure TEditEscapingTest.TestQuoteInNumberValue;
begin
  // the original wrote UPDATE ... SET `n`='11' -- ' WHERE `id`='1': the comment removed the WHERE clause
  Edit(1, '11'' -- ');
  AssertEquals('the other row is unchanged', '20', Value('SELECT `n``x` FROM ' + Table + ' WHERE id = 2'));
  Edit(2, '2026-03-03'' -- ');
  AssertEquals('the other row is unchanged (date)', '2026-01-02', Value('SELECT d FROM ' + Table + ' WHERE id = 2'));
end;

procedure TEditEscapingTest.TestBacktickInNames;
begin
  AssertEquals('errors', 0, Edit(1, '15'));
  AssertEquals('edited', '15', Value('SELECT `n``x` FROM ' + Table + ' WHERE id = 1'));
  AssertEquals('the other row is unchanged', '20', Value('SELECT `n``x` FROM ' + Table + ' WHERE id = 2'));
end;

initialization
  RegisterTest(TEditEscapingTest);

end.
