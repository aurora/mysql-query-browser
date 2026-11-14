{ SPDX-License-Identifier: GPL-2.0-or-later }
unit test_user_data;

{ The one-time import of the original's user data into the folder of QueryMole (ADR-0030,
  app/src/UserDataImport.pas). Works in a temporary folder; no server needed. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, UserDataImport;

type
  TUserDataImportTest = class(TTestCase)
  private
    FRoot, FOld, FNew: String;
    procedure WriteFile(const FileName, Content: String);
    function ReadFile(const FileName: String): String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestImportedFiles;
    procedure TestCopiesOnlyTheQueryBrowsersFiles;
    procedure TestKeepsExistingFiles;
    procedure TestMissingOldFolder;
    procedure TestFolders;
  end;

implementation

procedure TUserDataImportTest.WriteFile(const FileName, Content: String);
var
  S: TStringStream;
begin
  S := TStringStream.Create(Content);
  try
    S.SaveToFile(FileName);
  finally
    S.Free;
  end;
end;

function TUserDataImportTest.ReadFile(const FileName: String): String;
var
  S: TStringStream;
begin
  S := TStringStream.Create('');
  try
    S.LoadFromFile(FileName);
    Result := S.DataString;
  finally
    S.Free;
  end;
end;

procedure TUserDataImportTest.SetUp;
begin
  FRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'qbr_userdata_' + IntToStr(GetProcessID) +
    PathDelim;
  FOld := FRoot + 'old' + PathDelim;
  FNew := FRoot + 'new' + PathDelim;
  ForceDirectories(FOld);
  ForceDirectories(FNew);
end;

procedure TUserDataImportTest.TearDown;

  procedure Clear(const Dir: String);
  var
    SR: TSearchRec;
  begin
    if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Attr and faDirectory = 0) then
          DeleteFile(Dir + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    RemoveDir(Dir);
  end;

begin
  Clear(FOld);
  Clear(FNew);
  RemoveDir(FRoot);
end;

procedure TUserDataImportTest.TestImportedFiles;
begin
  AssertTrue(IsImportedFile('mysqlqb_options.xml'));
  AssertTrue(IsImportedFile('mysqlqb_history.xml'));
  AssertTrue(IsImportedFile('mysqlqb_bookmark.xml'));
  AssertTrue(IsImportedFile('mysqlx_common_options.xml'));
  AssertTrue(IsImportedFile('mysqlx_user_connections.xml'));
  AssertTrue('case is ignored (Windows)', IsImportedFile('MySQLQB_Options.XML'));
  AssertFalse('MySQL Administrator', IsImportedFile('mysqladmin_options.xml'));
  AssertFalse('MySQL Workbench', IsImportedFile('Workbench'));
  AssertFalse('not XML', IsImportedFile('mysqlqb_options.bak'));
end;

procedure TUserDataImportTest.TestCopiesOnlyTheQueryBrowsersFiles;
begin
  WriteFile(FOld + 'mysqlqb_options.xml', '<options/>');
  WriteFile(FOld + 'mysqlx_user_connections.xml', '<connections/>');
  WriteFile(FOld + 'mysqladmin_options.xml', '<admin/>');
  AssertEquals('copied', 2, ImportUserData(FOld, FNew));
  AssertEquals('<options/>', ReadFile(FNew + 'mysqlqb_options.xml'));
  AssertEquals('<connections/>', ReadFile(FNew + 'mysqlx_user_connections.xml'));
  AssertFalse('other programs'' files stay', FileExists(FNew + 'mysqladmin_options.xml'));
  AssertTrue('the old folder is not changed', FileExists(FOld + 'mysqlqb_options.xml'));
end;

procedure TUserDataImportTest.TestKeepsExistingFiles;
begin
  WriteFile(FOld + 'mysqlqb_options.xml', 'old');
  WriteFile(FNew + 'mysqlqb_options.xml', 'new');
  AssertEquals(0, ImportUserData(FOld, FNew));
  AssertEquals('new', ReadFile(FNew + 'mysqlqb_options.xml'));
end;

procedure TUserDataImportTest.TestMissingOldFolder;
begin
  AssertEquals(0, ImportUserData(FRoot + 'does-not-exist', FNew));
end;

procedure TUserDataImportTest.TestFolders;
begin
  {$IFDEF LINUX}
  AssertEquals(GetUserDir + '.mysqlgui/', LegacyUserDataDir(''));
  AssertEquals('querymole/', Copy(DefaultUserDataDir(''), Length(DefaultUserDataDir('')) - 9, 10));
  {$ELSE}
  AssertEquals('C:\AppData\MySQL\', LegacyUserDataDir('C:\AppData\'));
  AssertEquals('C:\AppData\QueryMole\', DefaultUserDataDir('C:\AppData\'));
  {$ENDIF}
end;

initialization
  RegisterTest(TUserDataImportTest);

end.
