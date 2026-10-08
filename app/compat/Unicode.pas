{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces Mike Lischke's Unicode unit (character classification, wide string routines).
  Only the routines the ported sources use are provided; add more when the compiler asks. }
unit Unicode;

{$mode delphi}

interface

uses
  Classes, SysUtils;

type
  TWideStringList = TStringList;
  TWideStrings = TStrings;

function StrLenW(Str: PWideChar): Cardinal;
function StrPosW(Str1, Str2: PWideChar): PWideChar;
function StrLCompW(Str1, Str2: PWideChar; MaxLen: Cardinal): Integer;

implementation

function StrLenW(Str: PWideChar): Cardinal;
begin
  Result := 0;
  if Str = nil then
    Exit;
  while Str[Result] <> #0 do
    Inc(Result);
end;

function StrPosW(Str1, Str2: PWideChar): PWideChar;
var
  Len2, Len1, I: Cardinal;
begin
  Result := nil;
  if (Str1 = nil) or (Str2 = nil) or (Str2^ = #0) then
    Exit;
  Len1 := StrLenW(Str1);
  Len2 := StrLenW(Str2);
  if Len2 > Len1 then
    Exit;
  for I := 0 to Len1 - Len2 do
    if StrLCompW(@Str1[I], Str2, Len2) = 0 then
      Exit(@Str1[I]);
end;

function StrLCompW(Str1, Str2: PWideChar; MaxLen: Cardinal): Integer;
var
  I: Cardinal;
begin
  Result := 0;
  for I := 0 to MaxLen - 1 do
  begin
    Result := Ord(Str1[I]) - Ord(Str2[I]);
    if (Result <> 0) or (Str1[I] = #0) then
      Exit;
  end;
end;

end.
