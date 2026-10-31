{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Outside Windows, the ported units use this unit instead of `Windows` (together with LCLIntf and
  LCLType, see docs/linux-port.md). It holds only Windows names that the LCL has under another
  name with the same meaning, so that the ported code can keep the original names. Windows-only
  behaviour is not emulated here: such code is guarded with IFDEF MSWINDOWS where it is used. }
unit WinAliases;

{$mode delphi}

{$IFDEF MSWINDOWS}
  {$Error This unit is not for Windows: use the unit Windows there. }
{$ENDIF}

interface

uses
  Types, LCLType, LMessages, Clipbrd;

const
  WM_USER = LM_USER;
  WM_DESTROY = LM_DESTROY;
  WM_TIMER = LM_TIMER;
  MB_APPLMODAL = 0;                     // also 0 on Windows: the default modality

type
  TWMDestroy = TLMDestroy;
  TWMTimer = TLMTimer;

// the LCL clipboard keeps text as UTF-8 under its one (dynamic) text format
function CF_UNICODETEXT: TClipboardFormat; inline;
function IsEqualIID(const IID1, IID2: TGUID): Boolean; inline;

// The "W" text functions take UTF-16; the LCL's take UTF-8.
function GetTextExtentPoint32W(DC: HDC; Str: PWideChar; Count: Integer; var Size: TSize): Boolean;
function DrawTextW(DC: HDC; Str: PWideChar; Count: Integer; var Rect: TRect; Flags: Cardinal): Integer;
function MessageBoxW(Wnd: HWND; Text, Caption: PWideChar; Flags: LongInt): Integer;

implementation

uses
  SysUtils, LCLIntf, Forms;

function ToUTF8(Str: PWideChar; Count: Integer): UTF8String;
var
  W: UnicodeString;
begin
  if Count < 0 then
    W := Str                          // -1: NUL terminated, as in the Windows API
  else
    SetString(W, Str, Count);
  Result := UTF8Encode(W);
end;

function GetTextExtentPoint32W(DC: HDC; Str: PWideChar; Count: Integer; var Size: TSize): Boolean;
var
  S: UTF8String;
begin
  S := ToUTF8(Str, Count);
  Result := GetTextExtentPoint(DC, PChar(S), Length(S), Size);
end;

function DrawTextW(DC: HDC; Str: PWideChar; Count: Integer; var Rect: TRect; Flags: Cardinal): Integer;
var
  S: UTF8String;
begin
  S := ToUTF8(Str, Count);
  Result := DrawText(DC, PChar(S), Length(S), Rect, Flags);
end;

function MessageBoxW(Wnd: HWND; Text, Caption: PWideChar; Flags: LongInt): Integer;
var
  T, C: UTF8String;
begin
  T := ToUTF8(Text, -1);
  C := ToUTF8(Caption, -1);
  Result := Application.MessageBox(PChar(T), PChar(C), Flags);
end;

function CF_UNICODETEXT: TClipboardFormat;
begin
  Result := CF_TEXT;
end;

function IsEqualIID(const IID1, IID2: TGUID): Boolean;
begin
  Result := IsEqualGUID(IID1, IID2);
end;

end.
