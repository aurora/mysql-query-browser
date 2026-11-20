{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Groups of stored connections (ADR-0051) live in the field storage_path of the original's connection file: it must
  come through loading and saving unchanged, so that earlier releases keep it too. No server needed. }
unit test_connection_groups;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, myx_types, myx_util_public_interface, myx_public_interface;

type
  TConnectionGroupsTest = class(TTestCase)
  published
    procedure TestStoragePathSurvivesSaveAndLoad;
  end;

implementation

procedure TConnectionGroupsTest.TestStoragePathSurvivesSaveAndLoad;
var
  Dir, First, Second: String;
  Text: TStringList;
  Stored: TMYX_USER_CONNECTIONS;
  Error: MYX_LIB_ERROR;

  function Load(const FileName: String): TMYX_USER_CONNECTIONS;
  var
    P: PMYX_USER_CONNECTIONS;
  begin
    P := myx_load_user_connections(WideString(FileName), @Error);
    AssertEquals('load ' + FileName, Ord(MYX_NO_ERROR), Ord(Error));
    try
      Result := TMYX_USER_CONNECTIONS.Create(P);
    finally
      myx_free_user_connections(P);
    end;
  end;

begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'qbr-groups-' + IntToStr(GetProcessID);
  ForceDirectories(Dir);
  First := Dir + '/first.xml';
  Second := Dir + '/second.xml';
  Text := TStringList.Create;
  try
    Text.Add('<?xml version="1.0"?>');
    Text.Add('<user_connections><last_connection>0</last_connection><password_storage_type>2</password_storage_type>');
    Text.Add('<user_connection><connection_name>ACME Production</connection_name><username>app</username>' +
      '<hostname>db1</hostname><port>3306</port><storage_path>Customers/ACME</storage_path>' +
      '<connection_type>0</connection_type><storage_type>1</storage_type><password></password></user_connection>');
    Text.Add('<user_connection><connection_name>Local</connection_name><username>root</username>' +
      '<hostname>127.0.0.1</hostname><port>3306</port><connection_type>0</connection_type>' +
      '<storage_type>1</storage_type><password></password></user_connection>');
    Text.Add('</user_connections>');
    Text.SaveToFile(First);
  finally
    Text.Free;
  end;
  try
    Stored := Load(First);
    try
      AssertEquals('two connections', 2, Stored.user_connections.Count);
      AssertEquals('group read', 'Customers/ACME', Stored.user_connections[0].storage_path);
      AssertEquals('no group', '', Stored.user_connections[1].storage_path);
      Stored.user_connections[1].storage_path := 'Local/Dev';
      AssertEquals('save', 0, myx_store_user_connections(Stored.get_record_pointer, MYX_PASSWORD_PLAINTEXT,
        WideString(Second)));
    finally
      Stored.Free;
    end;
    Stored := Load(Second);
    try
      AssertEquals('group kept', 'Customers/ACME', Stored.user_connections[0].storage_path);
      AssertEquals('new group saved', 'Local/Dev', Stored.user_connections[1].storage_path);
    finally
      Stored.Free;
    end;
  finally
    DeleteFile(First);
    DeleteFile(Second);
    RemoveDir(Dir);
  end;
end;

initialization
  RegisterTest(TConnectionGroupsTest);

end.
