{ SPDX-License-Identifier: GPL-2.0-or-later }
unit UserDataImport;

{$mode delphi}

// The user data folder of QueryMole and the one-time import from the folder of the original MySQL Query
// Browser (ADR-0030, superseding ADR-0019 in part). The old folder is only read: an installed original (and,
// on Windows and macOS, MySQL Workbench/Administrator, which share it) keeps working.

interface

// AppData is the platform's folder for application data with a trailing delimiter (AuxFuncs.GetApplicationDataDir:
// %APPDATA% on Windows, ~/Library/Application Support on macOS, empty on Linux); passed in so that this unit
// does not need the LCL and can be tested on its own.

// Default folder of QueryMole, with a trailing path delimiter:
// Windows %APPDATA%\QueryMole\, macOS ~/Library/Application Support/QueryMole/,
// Linux $XDG_CONFIG_HOME/querymole/ (default ~/.config/querymole/).
function DefaultUserDataDir(const AppData: String): String;

// Folder of the original on this platform, with a trailing path delimiter (ADR-0019):
// Windows %APPDATA%\MySQL\, macOS ~/Library/Application Support/MySQL/, Linux ~/.mysqlgui/.
function LegacyUserDataDir(const AppData: String): String;

// True for the files of the original that QueryMole uses (mysqlqb_*.xml, mysqlx_common_options.xml,
// mysqlx_user_connections.xml). Other files in the shared folder belong to other programs.
function IsImportedFile(const FileName: String): Boolean;

// Copies the imported files from OldDir to NewDir (which must exist) and returns their number. Existing
// files in NewDir are not overwritten. Nothing happens if OldDir does not exist.
function ImportUserData(const OldDir, NewDir: String): Integer;

implementation

uses
  SysUtils, Classes;

// -----------------------------------------------------------------------------

function DefaultUserDataDir(const AppData: String): String;

{$IFDEF LINUX}
var
  Base: String;
{$ENDIF}

begin
  {$IFNDEF LINUX}
  Result := AppData + 'QueryMole' + PathDelim;
  {$ELSE}
  Base := GetEnvironmentVariable('XDG_CONFIG_HOME');
  if (Base = '') or (Base[1] <> '/') then                 // the XDG spec ignores relative paths
    Base := GetUserDir + '.config';
  Result := IncludeTrailingPathDelimiter(Base) + 'querymole' + PathDelim;
  {$ENDIF}
end;

// -----------------------------------------------------------------------------

function LegacyUserDataDir(const AppData: String): String;

begin
  {$IFNDEF LINUX}
  Result := AppData + 'MySQL' + PathDelim;
  {$ELSE}
  Result := GetUserDir + '.mysqlgui' + PathDelim;
  {$ENDIF}
end;

// -----------------------------------------------------------------------------

function IsImportedFile(const FileName: String): Boolean;

var
  Name: String;

begin
  Name := LowerCase(FileName);
  Result := ((Copy(Name, 1, 8) = 'mysqlqb_') and (ExtractFileExt(Name) = '.xml')) or
    (Name = 'mysqlx_common_options.xml') or (Name = 'mysqlx_user_connections.xml');
end;

// -----------------------------------------------------------------------------

function CopyOneFile(const Source, Target: String): Boolean;

var
  Src, Dst: TFileStream;

begin
  Result := False;
  try
    Src := TFileStream.Create(Source, fmOpenRead or fmShareDenyNone);
    try
      Dst := TFileStream.Create(Target, fmCreate);
      try
        Dst.CopyFrom(Src, 0);
      finally
        Dst.Free;
      end;
    finally
      Src.Free;
    end;
    FileSetDate(Target, FileAge(Source));
    Result := True;
  except
    // An unreadable file is left out; the program then starts with its defaults for it.
    on EStreamError do
      DeleteFile(Target);
  end;
end;

// -----------------------------------------------------------------------------

function ImportUserData(const OldDir, NewDir: String): Integer;

var
  SR: TSearchRec;
  Old, New: String;

begin
  Result := 0;
  Old := IncludeTrailingPathDelimiter(OldDir);
  New := IncludeTrailingPathDelimiter(NewDir);
  if not DirectoryExists(ExcludeTrailingPathDelimiter(Old)) then
    Exit;
  if FindFirst(Old + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory = 0) and IsImportedFile(SR.Name) and not FileExists(New + SR.Name) then
        if CopyOneFile(Old + SR.Name, New + SR.Name) then
          Inc(Result);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

end.
