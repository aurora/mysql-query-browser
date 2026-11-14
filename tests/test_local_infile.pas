{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_local_infile;

{ LOAD DATA LOCAL: the client sends a local file only if the statement being executed names it
  (myx_library.c, myx_local_infile_init). A server can ask for a file in the reply to any statement;
  TLocalInfileTest checks the rule that decides it (no server needed), TLocalInfileServerTest that the
  user's own LOAD DATA LOCAL still works. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface, test_support;

type
  TLocalInfileTest = class(TTestCase)
  published
    procedure TestOwnStatement;
    procedure TestOtherFile;
    procedure TestNoLoadStatement;
    procedure TestQuoting;
  end;

  TLocalInfileServerTest = class(TTestCase)
  published
    procedure TestOwnLoadDataLocal;
  end;

implementation

function Allowed(const Statement, FileName: String): Boolean;
begin
  Result := myx_local_infile_allowed(Statement, FileName) <> 0;
end;

procedure TLocalInfileTest.TestOwnStatement;
begin
  AssertTrue(Allowed('LOAD DATA LOCAL INFILE ''/tmp/a.csv'' INTO TABLE t', '/tmp/a.csv'));
  AssertTrue('lower case, options', Allowed('load data low_priority local infile "/tmp/a.csv" into table t', '/tmp/a.csv'));
  AssertTrue('LOAD XML', Allowed('LOAD XML LOCAL INFILE ''/tmp/a.xml'' INTO TABLE t', '/tmp/a.xml'));
  AssertTrue('comments', Allowed('/* x */ LOAD DATA /* y */ LOCAL -- z'#10' INFILE ''/tmp/a.csv'' INTO TABLE t', '/tmp/a.csv'));
  AssertTrue('non-ASCII name', Allowed('LOAD DATA LOCAL INFILE ''/tmp/größe.csv'' INTO TABLE t', '/tmp/größe.csv'));
end;

procedure TLocalInfileTest.TestOtherFile;
begin
  AssertFalse(Allowed('LOAD DATA LOCAL INFILE ''/tmp/a.csv'' INTO TABLE t', '/etc/passwd'));
  AssertFalse('prefix', Allowed('LOAD DATA LOCAL INFILE ''/tmp/a.csv'' INTO TABLE t', '/tmp/a'));
  AssertFalse('without LOCAL', Allowed('LOAD DATA INFILE ''/tmp/a.csv'' INTO TABLE t', '/tmp/a.csv'));
end;

procedure TLocalInfileTest.TestNoLoadStatement;
begin
  AssertFalse(Allowed('SELECT 1', '/etc/passwd'));
  AssertFalse('the name in a string', Allowed('SELECT ''LOAD DATA LOCAL INFILE ''''/etc/passwd''''''', '/etc/passwd'));
  AssertFalse('the name in a comment', Allowed('SELECT 1 /* LOAD DATA LOCAL INFILE ''/etc/passwd'' */', '/etc/passwd'));
  AssertFalse('empty', Allowed('', '/etc/passwd'));
end;

procedure TLocalInfileTest.TestQuoting;
begin
  // the server resolves escapes depending on sql_mode, so both forms are accepted
  AssertTrue('backslash as written', Allowed('LOAD DATA LOCAL INFILE ''C:\\data\\a.csv'' INTO TABLE t', 'C:\\data\\a.csv'));
  AssertTrue('backslash resolved', Allowed('LOAD DATA LOCAL INFILE ''C:\\data\\a.csv'' INTO TABLE t', 'C:\data\a.csv'));
  AssertTrue('doubled quote', Allowed('LOAD DATA LOCAL INFILE ''/tmp/it''''s.csv'' INTO TABLE t', '/tmp/it''s.csv'));
  AssertFalse('unterminated', Allowed('LOAD DATA LOCAL INFILE ''/tmp/a.csv', '/tmp/a.csv'));
end;

procedure TLocalInfileServerTest.TestOwnLoadDataLocal;
var
  My: PMYSQL;
  FileName, OldValue: String;
  Lines: TStringList;
  Err: MYX_LIB_ERROR;
  Rs: PMYX_RESULTSET;
  Value: AnsiString;
begin
  FileName := GetTempDir + 'qbr_local_infile.csv';
  Lines := TStringList.Create;
  try
    Lines.Add('1');
    Lines.Add('2');
    Lines.Add('3');
    Lines.SaveToFile(FileName);
  finally
    Lines.Free;
  end;
  My := ConnectTestServer;
  try
    // the servers of the matrix (MySQL 8 and later by default) do not accept LOAD DATA LOCAL
    Err := MYX_NO_ERROR;
    Rs := myx_query_execute(My, 'SELECT @@GLOBAL.local_infile', 0, nil, @Err, nil, nil, nil, nil);
    AssertNotNull('local_infile', Rs);
    SetString(OldValue, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
    myx_query_free_resultset(Rs);
    ExecSQL(My, 'SET GLOBAL local_infile = 1');
    try
      ExecSQL(My, 'CREATE DATABASE IF NOT EXISTS qbr_infile');
      ExecSQL(My, 'CREATE TABLE qbr_infile.t (n INT)');
      ExecSQL(My, 'LOAD DATA LOCAL INFILE ''' + StringReplace(FileName, '\', '\\', [rfReplaceAll]) +
        ''' INTO TABLE qbr_infile.t');
      Rs := myx_query_execute(My, 'SELECT COUNT(*) FROM qbr_infile.t', 0, nil, @Err, nil, nil, nil, nil);
      AssertNotNull('count', Rs);
      SetString(Value, Rs^.rows^.fields^.value, Rs^.rows^.fields^.value_length);
      myx_query_free_resultset(Rs);
      AssertEquals('rows loaded from the local file', '3', Value);
    finally
      ExecSQL(My, 'DROP DATABASE IF EXISTS qbr_infile');
      ExecSQL(My, 'SET GLOBAL local_infile = ' + OldValue);
    end;
  finally
    DisconnectTestServer(My);
    DeleteFile(FileName);
  end;
end;

initialization
  RegisterTest(TLocalInfileTest);
  RegisterTest(TLocalInfileServerTest);

end.
