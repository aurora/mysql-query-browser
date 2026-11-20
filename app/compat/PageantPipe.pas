{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The named pipe of PuTTY's Pageant (0.75 and later) on Windows, for the SSH tunnel's agent (ADR-0048). Pageant
  speaks the OpenSSH agent protocol on it, so libssh uses it like the Windows OpenSSH agent's pipe.

  The name, as PuTTY 0.84 builds it (windows/utils/agent_named_pipe_name.c, cryptoapi.c, get_username.c):
    \\.\pipe\pageant.<user>.<suffix>
  <user> is GetUserNameExA(NameUserPrincipal) up to the first '@', else GetUserNameA. <suffix> is SHA-256, in
  lower-case hex, of the SSH string encoding (4-byte big-endian length, then the bytes) of "Pageant\0" zero-padded to
  16 bytes and encrypted in place with CryptProtectMemory(CRYPTPROTECTMEMORY_CROSS_PROCESS); when that call is not
  available or fails, the plain bytes are hashed. Elsewhere there is no Pageant: the functions return ''. }
unit PageantPipe;

{$mode objfpc}{$H+}

interface

// the pipe's name; '' outside Windows
function PageantPipeName: String;
// the pipe's name when Pageant runs, else ''
function RunningPageantPipe: String;

implementation

{$IFDEF MSWINDOWS}
uses
  Windows, SysUtils, dynlibs, OpenSSLCrypto;

const
  NameUserPrincipal = 8;
  CRYPTPROTECTMEMORY_BLOCK_SIZE = 16;
  CRYPTPROTECTMEMORY_CROSS_PROCESS = 1;

type
  TGetUserNameExA = function(NameFormat: Integer; lpNameBuffer: PChar; var nSize: ULONG): BOOLEAN; stdcall;
  TCryptProtectMemory = function(pDataIn: Pointer; cbDataIn: DWORD; dwFlags: DWORD): BOOL; stdcall;

function UserName: String;
var
  Lib: TLibHandle;
  GetEx: TGetUserNameExA;
  Size: ULONG;
  Buf: array[0..511] of Char;
  N: DWORD;
begin
  Result := '';
  Lib := LoadLibrary('secur32.dll');
  if Lib <> NilHandle then
  try
    Pointer(GetEx) := GetProcedureAddress(Lib, 'GetUserNameExA');
    Size := SizeOf(Buf);
    if Assigned(GetEx) and GetEx(NameUserPrincipal, @Buf[0], Size) then
    begin
      Result := StrPas(@Buf[0]);
      if Pos('@', Result) > 0 then
        Result := Copy(Result, 1, Pos('@', Result) - 1);
    end;
  finally
    FreeLibrary(Lib);
  end;
  if Result = '' then
  begin
    N := SizeOf(Buf);
    if GetUserNameA(@Buf[0], N) then
      Result := StrPas(@Buf[0]);
  end;
end;

function PageantPipeName: String;
var
  Lib: TLibHandle;
  Protect: TCryptProtectMemory;
  Data, Hashed, Hash: TBytesArray;
  I: Integer;
begin
  SetLength(Data, CRYPTPROTECTMEMORY_BLOCK_SIZE);   // "Pageant", its NUL and zeros up to one block
  FillChar(Data[0], Length(Data), 0);
  Move(PChar('Pageant')^, Data[0], 7);
  Lib := LoadLibrary('crypt32.dll');
  if Lib <> NilHandle then
  try
    Pointer(Protect) := GetProcedureAddress(Lib, 'CryptProtectMemory');
    if Assigned(Protect) then
      Protect(@Data[0], Length(Data), CRYPTPROTECTMEMORY_CROSS_PROCESS);
  finally
    FreeLibrary(Lib);
  end;
  SetLength(Hashed, 4);
  Hashed[0] := 0; Hashed[1] := 0; Hashed[2] := 0; Hashed[3] := Length(Data);
  SetLength(Hashed, 4 + Length(Data));
  Move(Data[0], Hashed[4], Length(Data));
  Hash := SHA256(Hashed);
  Result := '\\.\pipe\pageant.' + UserName + '.';
  for I := 0 to High(Hash) do
    Result := Result + LowerCase(IntToHex(Hash[I], 2));
end;

function RunningPageantPipe: String;
var
  Data: TWin32FindDataA;
  H: THandle;
begin
  Result := '';
  try
    Result := PageantPipeName;
  except
    Exit('');   // no libcrypto: no Pageant
  end;
  H := FindFirstFileA(PChar(Result), Data);
  if H = INVALID_HANDLE_VALUE then
    Exit('');
  Windows.FindClose(H);
end;

{$ELSE}

function PageantPipeName: String;
begin
  Result := '';
end;

function RunningPageantPipe: String;
begin
  Result := '';
end;
{$ENDIF}

end.
