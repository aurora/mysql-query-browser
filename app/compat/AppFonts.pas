// SPDX-License-Identifier: GPL-2.0-or-later
unit AppFonts;

// Port: private fonts for platforms without the Windows font API. fontconfig's counterpart of
// AddFontResourceEx(FR_PRIVATE): the file is added to the application's font set, nothing is installed.

{$mode delphi}

interface

function AddApplicationFont(const FileName: String): Boolean;

// Tahoma is part of Windows and the forms of the original are laid out for it. Elsewhere the free stand-in that ships
// next to the program (fonts/tahoma.ttf, tahomabd.ttf; ADR-0028) is added. Must run before the first form is created:
// the LCL reads the font list once.
procedure AddBundledTahoma;

var
  BundledTahomaLoaded: Boolean = False;    // the LCL's font list does not show fonts added after the toolkit started

implementation

uses
  SysUtils, DynLibs;

// Loaded at run time so that fontconfig's development files are not needed for building.
function AddApplicationFont(const FileName: String): Boolean;

var
  Lib: TLibHandle;
  FcConfigAppFontAddFile: function(Config: Pointer; FileName: PChar): LongBool; cdecl;

begin
  Result := False;
  Lib := LoadLibrary('libfontconfig.so.1');
  if Lib = NilHandle then
    Exit;
  @FcConfigAppFontAddFile := GetProcedureAddress(Lib, 'FcConfigAppFontAddFile');
  if Assigned(FcConfigAppFontAddFile) then
    Result := FcConfigAppFontAddFile(nil, PChar(FileName));    // nil: the current configuration
end;

procedure AddBundledTahoma;

const
  Files: array[0..1] of String = ('tahoma.ttf', 'tahomabd.ttf');

var
  I: Integer;
  Dir: String;

begin
  BundledTahomaLoaded := True;
  Dir := ExtractFilePath(ParamStr(0)) + 'fonts' + PathDelim;
  for I := Low(Files) to High(Files) do
    if not (FileExists(Dir + Files[I]) and AddApplicationFont(Dir + Files[I])) then
      BundledTahomaLoaded := False;
end;

end.
