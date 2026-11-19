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

// Qt keeps its own font database and does not see fonts added to fontconfig as above (the Qt6 build drew the forms
// with Noto Sans or DejaVu Sans instead). Under the Qt6 widgetset this adds the same files to Qt's database; it needs
// the QApplication, so it is called after Application.Initialize. Nothing to do for other widgetsets.
procedure AddBundledTahomaToQt;

var
  BundledTahomaLoaded: Boolean = False;    // the LCL's font list does not show fonts added after the toolkit started

implementation

uses
  SysUtils, DynLibs{$IFDEF LCLQT6}, qt6{$ENDIF};

const
  TahomaFiles: array[0..1] of String = ('tahoma.ttf', 'tahomabd.ttf');

function BundledFontDir: String;

begin
  Result := ExtractFilePath(ParamStr(0)) + 'fonts' + PathDelim;
end;

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

var
  I: Integer;
  Dir: String;

begin
  BundledTahomaLoaded := True;
  Dir := BundledFontDir;
  for I := Low(TahomaFiles) to High(TahomaFiles) do
    if not (FileExists(Dir + TahomaFiles[I]) and AddApplicationFont(Dir + TahomaFiles[I])) then
      BundledTahomaLoaded := False;
end;

procedure AddBundledTahomaToQt;

{$IFDEF LCLQT6}
var
  I: Integer;
  FileName: WideString;
{$ENDIF}

begin
  {$IFDEF LCLQT6}
  if not BundledTahomaLoaded then
    Exit;
  for I := Low(TahomaFiles) to High(TahomaFiles) do
  begin
    FileName := UTF8Decode(BundledFontDir + TahomaFiles[I]);
    if QFontDatabase_addApplicationFont(@FileName) < 0 then
      BundledTahomaLoaded := False;
  end;
  {$ENDIF}
end;

end.
