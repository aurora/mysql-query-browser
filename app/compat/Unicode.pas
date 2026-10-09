{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Replaces Mike Lischke's Unicode unit (character classification, wide string routines).
  Only the routines the ported sources use are provided; add more when the compiler asks. }
unit Unicode;

{$mode delphi}

interface

uses
  Classes, SysUtils, Character;

const
  WideNull = WideChar(#0);
  WideTabulator = WideChar(#9);
  WideSpace = WideChar(#32);
  WideLF = WideChar(#10);
  WideLineFeed = WideChar(#10);
  WideVerticalTab = WideChar(#11);
  WideFormFeed = WideChar(#12);
  WideCR = WideChar(#13);
  WideCarriageReturn = WideChar(#13);
  WideLineSeparator = WideChar($2028);
  WideParagraphSeparator = WideChar($2029);
  BOM_LSB_FIRST = WideChar($FEFF);
  BOM_MSB_FIRST = WideChar($FFFE);

type
  UCS4Char = Cardinal;
  TWideStringList = TStringList;
  TWideStrings = TStrings;

function UnicodeIsIdentifierStart(C: UCS4Char): Boolean;
function UnicodeIsIdentifierPart(C: UCS4Char): Boolean;
function UnicodeIsNumber(C: UCS4Char): Boolean;
function UnicodeIsHexDigit(C: UCS4Char): Boolean;
function UnicodeIsWhiteSpace(C: UCS4Char): Boolean;
procedure ExpandANSIString(const Source: PAnsiChar; Target: PWideChar; Count: Cardinal);
function StrScanW(Str: PWideChar; Chr: WideChar): PWideChar; overload;
function StrScanW(Str: PWideChar; Chr: WideChar; StrLen: Cardinal): PWideChar; overload;
function StrICompW(Str1, Str2: PWideChar): Integer;
procedure StrSwapByteOrder(Str: PWideChar);
function WideCharIn(C: WideChar; const Chars: array of WideChar): Boolean;
function StrLenW(Str: PWideChar): Cardinal;
function UTF8ToWideString(const S: AnsiString): WideString;
function WideStringToUTF8(const S: WideString): AnsiString;
function StrPosW(Str1, Str2: PWideChar): PWideChar;
function StrLCompW(Str1, Str2: PWideChar; MaxLen: Cardinal): Integer;

implementation

procedure ExpandANSIString(const Source: PAnsiChar; Target: PWideChar; Count: Cardinal);
var
  I: Cardinal;
begin
  for I := 0 to Count - 1 do
    Target[I] := WideChar(Ord(Source[I]));
end;

function StrScanW(Str: PWideChar; Chr: WideChar): PWideChar;
begin
  Result := nil;
  if Str = nil then
    Exit;
  while Str^ <> #0 do
  begin
    if Str^ = Chr then
      Exit(Str);
    Inc(Str);
  end;
  if Chr = #0 then
    Result := Str;
end;

function StrScanW(Str: PWideChar; Chr: WideChar; StrLen: Cardinal): PWideChar;
begin
  Result := nil;
  while StrLen > 0 do
  begin
    if Str^ = Chr then
      Exit(Str);
    Inc(Str);
    Dec(StrLen);
  end;
end;

function StrICompW(Str1, Str2: PWideChar): Integer;
begin
  Result := CompareText(UnicodeString(Str1), UnicodeString(Str2));
end;

procedure StrSwapByteOrder(Str: PWideChar);
begin
  while Str^ <> #0 do
  begin
    Str^ := WideChar(Swap(Word(Str^)));
    Inc(Str);
  end;
end;

function WideCharIn(C: WideChar; const Chars: array of WideChar): Boolean;
var
  I: Integer;
begin
  for I := Low(Chars) to High(Chars) do
    if Chars[I] = C then
      Exit(True);
  Result := False;
end;

function UnicodeIsIdentifierStart(C: UCS4Char): Boolean;
begin
  Result := (C <= $FFFF) and (TCharacter.IsLetter(WideChar(C)) or (C = Ord('_')));
end;

function UnicodeIsIdentifierPart(C: UCS4Char): Boolean;
begin
  Result := (C <= $FFFF) and (TCharacter.IsLetterOrDigit(WideChar(C)) or (C = Ord('_')) or (C = Ord('$')));
end;

function UnicodeIsNumber(C: UCS4Char): Boolean;
begin
  Result := (C <= $FFFF) and TCharacter.IsNumber(WideChar(C));
end;

function UnicodeIsHexDigit(C: UCS4Char): Boolean;
begin
  Result := (C < 128) and (AnsiChar(C) in ['0'..'9', 'A'..'F', 'a'..'f']);
end;

function UnicodeIsWhiteSpace(C: UCS4Char): Boolean;
begin
  Result := (C <= $FFFF) and (TCharacter.IsWhiteSpace(WideChar(C)) or (C = $2028) or (C = $2029));
end;

function UTF8ToWideString(const S: AnsiString): WideString;
begin
  Result := UTF8Decode(S);
end;

function WideStringToUTF8(const S: WideString): AnsiString;
begin
  Result := UTF8Encode(S);
end;

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
