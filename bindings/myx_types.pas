{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Hand-written. Types from system and MySQL headers that the generated
  myx_*_public_interface.pas units refer to (opaque, only used behind pointers),
  and helpers for the C memory that the generated wrapper classes build.

  Memory allocated here with GetMem is owned by the Pascal wrapper classes and
  released by them; memory returned by the C library is released with the
  library's own myx_free_* functions. }
unit myx_types;

{$mode objfpc}{$H+}
{$POINTERMATH ON}

interface

uses
  ctypes, Classes, SysUtils, AuxLists;

type
  PMYSQL = Pointer;
  PMYSQL_RES = Pointer;
  PMYSQL_FIELD = Pointer;
  PMYSQL_STMT = Pointer;
  PFILE = Pointer;

const
{$IFDEF WINDOWS}
  LIB_GLIB = 'libglib-2.0-0.dll';
{$ELSE}{$IFDEF DARWIN}
  LIB_GLIB = 'libglib-2.0.0.dylib';
{$ELSE}
  LIB_GLIB = 'libglib-2.0.so.0';
{$ENDIF}{$ENDIF}

{ g_free for strings the library returns that the caller has to release }
procedure g_free(P: Pointer); cdecl; external LIB_GLIB;

{ NULL-safe conversion of a C string (UTF-8) to a String }
function ConvertString(P: PAnsiChar): String;

{ (Re)allocate a NUL terminated copy of S in Dest }
procedure SetCString(var Dest: PAnsiChar; const S: String);
{ (Re)allocate a copy of the first Len bytes of S (binary data) in Dest }
procedure SetCBinary(var Dest: PAnsiChar; const S: String; Len: SizeInt);
procedure FreeCString(var P: PAnsiChar);

{ char** arrays with a separate count, as used in the library's structs }
procedure SetCStringArray(var Arr: PPAnsiChar; var Num: cuint; List: TStringList);
procedure FreeCStringArray(var Arr: PPAnsiChar; Num: cuint);
procedure SetCIntArray(var Arr: pcint; var Num: cuint; List: TIntegerList);

implementation

function ConvertString(P: PAnsiChar): String;
begin
  if P = nil then
    Result := ''
  else
    Result := String(P);
end;

procedure SetCString(var Dest: PAnsiChar; const S: String);
begin
  if Dest <> nil then
    FreeMem(Dest);
  GetMem(Dest, Length(S) + 1);
  if Length(S) > 0 then
    Move(S[1], Dest^, Length(S));
  Dest[Length(S)] := #0;
end;

procedure SetCBinary(var Dest: PAnsiChar; const S: String; Len: SizeInt);
var
  N: SizeInt;
begin
  if Dest <> nil then
    FreeMem(Dest);
  Dest := nil;
  if Len <= 0 then
    Exit;
  GetMem(Dest, Len);
  FillChar(Dest^, Len, 0);
  N := Length(S);
  if N > Len then
    N := Len;                                // never read past the string
  if N > 0 then
    Move(S[1], Dest^, N);
end;

procedure FreeCString(var P: PAnsiChar);
begin
  if P <> nil then
    FreeMem(P);
  P := nil;
end;

procedure FreeCStringArray(var Arr: PPAnsiChar; Num: cuint);
var
  I: Integer;
begin
  if Arr = nil then
    Exit;
  for I := 0 to Integer(Num) - 1 do
    FreeMem(Arr[I]);
  FreeMem(Arr);
  Arr := nil;
end;

procedure SetCStringArray(var Arr: PPAnsiChar; var Num: cuint; List: TStringList);
var
  I: Integer;
begin
  FreeCStringArray(Arr, Num);
  Num := List.Count;
  if List.Count = 0 then
    Exit;
  GetMem(Arr, SizeOf(PAnsiChar) * (List.Count + 1));
  for I := 0 to List.Count - 1 do
  begin
    Arr[I] := nil;
    SetCString(Arr[I], List[I]);
  end;
  Arr[List.Count] := nil;                  // terminating element
end;

procedure SetCIntArray(var Arr: pcint; var Num: cuint; List: TIntegerList);
var
  I: Integer;
begin
  if Arr <> nil then
    FreeMem(Arr);
  Arr := nil;
  Num := List.Count;
  if List.Count = 0 then
    Exit;
  GetMem(Arr, SizeOf(cint) * List.Count);
  for I := 0 to List.Count - 1 do
    Arr[I] := List[I];
end;

end.
