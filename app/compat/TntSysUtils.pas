{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces the TNT unit of the same name. Only what the ported sources use.
  The Wide* file functions operate on UTF-8 Strings/WideStrings via the RTL, which is
  Unicode aware in FPC. }
unit TntSysUtils;

{$mode delphi}

interface

uses
  SysUtils, Classes;

function WideDirectoryExists(const Name: WideString): Boolean;
function WideFileExists(const Name: WideString): Boolean;
function WideForceDirectories(const Dir: WideString): Boolean;
function WideExcludeTrailingPathDelimiter(const S: WideString): WideString;
function WideIncludeTrailingBackslash(const S: WideString): WideString;
function WideExtractFileName(const FileName: WideString): WideString;
function WideExtractFilePath(const FileName: WideString): WideString;
function WideSameStr(const S1, S2: WideString): Boolean;
function WideSameText(const S1, S2: WideString): Boolean;
function WideCompareText(const S1, S2: WideString): Integer;
function WideUpperCase(const S: WideString): WideString;
function WideStringReplace(const S, OldPattern, NewPattern: WideString; Flags: TReplaceFlags): WideString;

{ TNT: AdjustLineBreaks for WideStrings }
function TntAdjustLineBreaks(const S: WideString): WideString;

implementation

function WideDirectoryExists(const Name: WideString): Boolean;
begin
  Result := DirectoryExists(UTF8Encode(Name));
end;

function WideFileExists(const Name: WideString): Boolean;
begin
  Result := FileExists(UTF8Encode(Name));
end;

function WideForceDirectories(const Dir: WideString): Boolean;
begin
  Result := ForceDirectories(UTF8Encode(Dir));
end;

function WideExcludeTrailingPathDelimiter(const S: WideString): WideString;
begin
  Result := UTF8Decode(ExcludeTrailingPathDelimiter(UTF8Encode(S)));
end;

function WideIncludeTrailingBackslash(const S: WideString): WideString;
begin
  Result := UTF8Decode(IncludeTrailingPathDelimiter(UTF8Encode(S)));
end;

function WideExtractFileName(const FileName: WideString): WideString;
begin
  Result := UTF8Decode(ExtractFileName(UTF8Encode(FileName)));
end;

function WideExtractFilePath(const FileName: WideString): WideString;
begin
  Result := UTF8Decode(ExtractFilePath(UTF8Encode(FileName)));
end;

function WideSameStr(const S1, S2: WideString): Boolean;
begin
  Result := S1 = S2;
end;

function WideSameText(const S1, S2: WideString): Boolean;
begin
  Result := WideCompareText(S1, S2) = 0;
end;

function WideCompareText(const S1, S2: WideString): Integer;
begin
  Result := CompareText(UTF8Encode(S1), UTF8Encode(S2));
end;

function WideUpperCase(const S: WideString): WideString;
begin
  Result := UTF8Decode(UpperCase(UTF8Encode(S)));
end;

function WideStringReplace(const S, OldPattern, NewPattern: WideString; Flags: TReplaceFlags): WideString;
begin
  Result := UTF8Decode(StringReplace(UTF8Encode(S), UTF8Encode(OldPattern), UTF8Encode(NewPattern), Flags));
end;

function TntAdjustLineBreaks(const S: WideString): WideString;
begin
  Result := UTF8Decode(AdjustLineBreaks(UTF8Encode(S)));
end;

end.
