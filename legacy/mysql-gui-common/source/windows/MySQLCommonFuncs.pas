unit MySQLCommonFuncs;

interface

uses
  gnugettext, SysUtils, AuxFuncs, Windows, Forms, TntRegistry, TntClasses, TntSysUtils;

function GetMySQLCommandLineClientPath: WideString;
function GetMySQLAdministratorCmd: WideString;
function GetMySQLQueryBrowserCmd: WideString;

procedure RegisterMySQLApplication(Name: WideString;
  Version: WideString; InstallPath: WideString);
function ScanRegistryForProductVersion(RegMainPath: WideString; RegAppName: WideString;
  Key: WideString; KeyType: Integer): WideString;

//----------------------------------------------------------------------------------------------------------------------

implementation

uses
  Math;
  
//----------------------------------------------------------------------------------------------------------------------

function GetMySQLCommandLineClientPath: WideString;

var
  InstallDir: WideString;

begin
  if(FileExists(GetProgramFilesDir+'MySQL\bin\mysql.exe'))then
    Result:=GetProgramFilesDir+'MySQL\bin\mysql.exe'
  else if(FileExists('c:\mysql\bin\mysql.exe'))then
    Result:='c:\mysql\bin\mysql.exe'
  else
  begin
    InstallDir:=ReadFromReg(HKEY_LOCAL_MACHINE,
      '\SOFTWARE\MySQL AB\MySQL Server 4.1', 'Location', 0, '', False);

    if(FileExists(IncludeTrailingPathDelimiter(InstallDir)+
      'bin\mysql.exe'))then
      Result:=IncludeTrailingPathDelimiter(InstallDir)+'bin\mysql.exe'
    else
    begin
      InstallDir:=ReadFromReg(HKEY_LOCAL_MACHINE,
        '\SOFTWARE\MySQL AB\MySQL Server 5.0', 'Location', 0, '', False);
      if (InstallDir='') then
        InstallDir := ScanRegistryForProductVersion('SOFTWARE\MySQL AB', 'MySQL Server', 'Location', 0);


      if(FileExists(IncludeTrailingPathDelimiter(InstallDir)+
        'bin\mysql.exe'))then
        Result:=IncludeTrailingPathDelimiter(InstallDir)+'bin\mysql.exe'
      else
        Result:='';
    end;
  end
end;

//----------------------------------------------------------------------------------------------------------------------

function GetMySQLAdministratorCmd: WideString;

var
  InstallDir: WideString;

begin
  if(FileExists(ExtractFilePath(Application.ExeName)+'MySQLAdministrator.exe'))then
    Result:=ExtractFilePath(Application.ExeName)+'MySQLAdministrator.exe'
  else
  begin
    InstallDir:=ReadFromReg(HKEY_LOCAL_MACHINE,
      '\SOFTWARE\MySQL AB\MySQL Administrator', 'Location', 0, '', False);

    if(FileExists(IncludeTrailingPathDelimiter(InstallDir)+'MySQLAdministrator.exe'))then
      Result:=IncludeTrailingPathDelimiter(InstallDir)+'MySQLAdministrator.exe'
    else
      Result:='';

    if(Result='')then
    begin
      InstallDir:=ReadFromReg(HKEY_LOCAL_MACHINE,
        '\SOFTWARE\MySQL AB\MySQL Administrator 1.0', 'Location', 0, '', False);
      if (InstallDir='') then
        InstallDir := ScanRegistryForProductVersion('SOFTWARE\MySQL AB', 'MySQL Administrator', 'Location', 0);

      if(FileExists(IncludeTrailingPathDelimiter(InstallDir)+'MySQLAdministrator.exe'))then
        Result:=IncludeTrailingPathDelimiter(InstallDir)+'MySQLAdministrator.exe'
      else
        Result:='';
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function GetMySQLQueryBrowserCmd: WideString;

var
  InstallDir: WideString;

begin
  if(FileExists(ExtractFilePath(Application.ExeName)+'MySQLQueryBrowser.exe'))then
    Result:=ExtractFilePath(Application.ExeName)+'MySQLQueryBrowser.exe'
  else
  begin
    InstallDir := ReadFromReg(HKEY_LOCAL_MACHINE,
      '\SOFTWARE\MySQL AB\MySQL Query Browser', 'Location', 0, '', False);

    if(FileExists(IncludeTrailingPathDelimiter(InstallDir)+'MySQLQueryBrowser.exe'))then
      Result:=IncludeTrailingPathDelimiter(InstallDir)+'MySQLQueryBrowser.exe'
    else
      Result:='';

    if(Result='')then
    begin
      InstallDir := ReadFromReg(HKEY_LOCAL_MACHINE,
        '\SOFTWARE\MySQL AB\MySQL Query Browser 1.0', 'Location', 0, '', False);
      if (InstallDir='') then
        InstallDir := ReadFromReg(HKEY_LOCAL_MACHINE,
          '\SOFTWARE\MySQL AB\MySQL Query Browser 1.1', 'Location', 0, '', False);
      if (InstallDir='') then
        InstallDir := ScanRegistryForProductVersion('SOFTWARE\MySQL AB', 'MySQL Query Browser', 'Location', 0);


      if(FileExists(IncludeTrailingPathDelimiter(InstallDir)+'MySQLQueryBrowser.exe'))then
        Result:=IncludeTrailingPathDelimiter(InstallDir)+'MySQLQueryBrowser.exe'
      else
        Result:='';
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function GetSubkeyNameByPrefix(RegMainPath: WideString; RegAppName: WideString) : WideString;

var
  ParentKey: HKEY;
  I: Integer;
  NumSubKeys: Integer;
  MaxKeySize: Integer;
  KeyName: WideString;
  KeyLen: Cardinal;
  L: Integer;
  RegResult: Integer;
  
begin
  Result := '';
  if RegOpenKeyExW(HKEY_LOCAL_MACHINE, PWideChar(RegMainPath), 0, KEY_READ, ParentKey) = ERROR_SUCCESS then
  begin
    if RegQueryInfoKey(ParentKey, nil, nil, nil, @NumSubKeys, @MaxKeySize, nil, nil, nil, nil, nil, nil) = ERROR_SUCCESS then
    begin
      // Add room for terminating 0.
      Inc(MaxKeySize);
      L := Length(RegAppName);
      SetLength(KeyName, MaxKeySize);
      for I := 0 to NumSubKeys - 1 do
      begin
        KeyLen := MaxKeySize;
        RegResult := RegEnumKeyExW(ParentKey, I, PWideChar(KeyName), KeyLen, nil, nil, nil, nil);
        if RegResult = ERROR_SUCCESS then
        begin
          if WideSameText(RegAppName, Copy(KeyName, 1, Min(L, KeyLen))) then
          begin
            Result := Copy(KeyName, 1, KeyLen);
            // Dont break as we are looking for the last key (in the hope the last key is also that with the
            // highest version number).
            // TODO: either return all installed version of one app or truly compare version numbers and pick the highest one.
          end;
        end;
      end;
    end;
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

function ScanRegistryForProductVersion(RegMainPath: WideString; RegAppName: WideString; Key: WideString; KeyType: Integer): WideString;

var
  FullAppKey: WideString;
//  i, j: Integer;

begin
  FullAppKey := RegMainPath + '\' + GetSubkeyNameByPrefix(RegMainPath, RegAppName);
  Result := ReadFromReg(HKEY_LOCAL_MACHINE, FullAppKey, Key, KeyType, '', False);

  // if you're going to uncomment code below notice a bug:
  // there's only one break - which breaks to outer loop,
  // thus always finding the version with lowest major
  // and highest minor numbers
{
  Result := '';

  for i:=10 downto 1 do
  begin
    for j:=30 downto 0 do
    begin
      Result := ReadFromReg(HKEY_LOCAL_MACHINE,
        Format(RegMainPath+'\'+RegAppName+' %d.%d', [i, j]),
        Key, KeyType, '', False);
      if (Result<>'') then
        break;
    end;
  end;
}
end;

//----------------------------------------------------------------------------------------------------------------------

procedure RegisterMySQLApplication(Name: WideString; Version: WideString; InstallPath: WideString);

var
  RegVersion: WideString;
  KeyName: WideString;
  MainVersion: WideString;
  p, p2: integer;
  
begin
  MainVersion:='';

  p:=Pos('.', Version);
  if(p>0)then
  begin
    p2:=Pos('.', Copy(Version, p+1, Length(Version)));

    if(p2>0)then
      MainVersion:=Copy(Version, 1, p2+1);
  end;

  if(MainVersion<>'')then
    KeyName:=Name+' '+MainVersion
  else
    KeyName:=Name;

  RegVersion:=ReadFromReg(HKEY_LOCAL_MACHINE,
    '\SOFTWARE\MySQL AB\'+KeyName, 'Version', 0, '');

  if(RegVersion<>Version)then
  begin
    WriteToReg(HKEY_LOCAL_MACHINE, '\SOFTWARE\MySQL AB\'+KeyName,
      'Version', 0, Version);
    WriteToReg(HKEY_LOCAL_MACHINE, '\SOFTWARE\MySQL AB\'+KeyName,
      'Location', 0, InstallPath);
  end;
end;

//----------------------------------------------------------------------------------------------------------------------

end.
