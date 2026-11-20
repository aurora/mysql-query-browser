{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The few primitives of OpenSSL's libcrypto (Apache-2.0) the PuTTY key reader needs (ADR-0048): SHA-1, SHA-256,
  HMAC, AES-256-CBC decryption and Argon2 (OpenSSL 3.2 and later). The library is loaded when first needed, not
  linked: libssh and Connector/C bring it on every platform (libcrypto.so.3; libcrypto-3-x64.dll from MSYS2), so a
  missing or too old copy only disables .ppk keys, with a message. }
unit OpenSSLCrypto;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  EOpenSSLCrypto = class(Exception);
  TBytesArray = array of Byte;
  TArgon2Flavour = (a2d, a2i, a2id);

function SHA1(const Data: TBytesArray): TBytesArray;
function SHA256(const Data: TBytesArray): TBytesArray;
function HMAC_SHA1(const Key, Data: TBytesArray): TBytesArray;
function HMAC_SHA256(const Key, Data: TBytesArray): TBytesArray;
// decrypts whole blocks in place, no padding
procedure AES256CBCDecrypt(const Key, IV: TBytesArray; var Data: TBytesArray);
function Argon2(Flavour: TArgon2Flavour; MemoryKiB, Passes, Parallelism: Cardinal;
  const Password, Salt: TBytesArray; OutLen: Integer): TBytesArray;

function BytesOf(const S: String): TBytesArray;

implementation

uses
  dynlibs, ctypes;

const
  {$IFDEF MSWINDOWS}
  LibNames: array[0..1] of String = ('libcrypto-3-x64.dll', 'libcrypto-3.dll');
  {$ELSE}
  LibNames: array[0..1] of String = ('libcrypto.so.3', 'libcrypto.so');
  {$ENDIF}

  // OSSL_PARAM data types
  OSSL_PARAM_UNSIGNED_INTEGER = 2;
  OSSL_PARAM_OCTET_STRING = 5;

type
  POSSL_PARAM = ^OSSL_PARAM;
  OSSL_PARAM = record
    key: PChar;
    data_type: cuint;
    data: Pointer;
    data_size: csize_t;
    return_size: csize_t;
  end;

var
  Lib: TLibHandle = NilHandle;
  p_EVP_sha1, p_EVP_sha256, p_EVP_aes_256_cbc: function: Pointer; cdecl;
  p_EVP_Digest: function(data: Pointer; count: csize_t; md: PByte; size: pcuint; type_: Pointer;
    impl: Pointer): cint; cdecl;
  p_HMAC: function(evp_md: Pointer; key: Pointer; key_len: cint; d: PByte; n: csize_t; md: PByte;
    md_len: pcuint): PByte; cdecl;
  p_EVP_CIPHER_CTX_new: function: Pointer; cdecl;
  p_EVP_CIPHER_CTX_free: procedure(ctx: Pointer); cdecl;
  p_EVP_DecryptInit_ex: function(ctx, cipher, impl: Pointer; key, iv: PByte): cint; cdecl;
  p_EVP_CIPHER_CTX_set_padding: function(ctx: Pointer; pad: cint): cint; cdecl;
  p_EVP_DecryptUpdate: function(ctx: Pointer; out_: PByte; outl: pcint; in_: PByte; inl: cint): cint; cdecl;
  p_EVP_KDF_fetch: function(libctx: Pointer; algorithm, properties: PChar): Pointer; cdecl;
  p_EVP_KDF_free: procedure(kdf: Pointer); cdecl;
  p_EVP_KDF_CTX_new: function(kdf: Pointer): Pointer; cdecl;
  p_EVP_KDF_CTX_free: procedure(ctx: Pointer); cdecl;
  p_EVP_KDF_derive: function(ctx: Pointer; key: PByte; keylen: csize_t; params: POSSL_PARAM): cint; cdecl;

function Load(var P; const Name: String; Required: Boolean = True): Boolean;
begin
  Pointer(P) := GetProcedureAddress(Lib, Name);
  Result := Pointer(P) <> nil;
  if not Result and Required then
    raise EOpenSSLCrypto.CreateFmt('libcrypto lacks %s', [Name]);
end;

procedure Need;
var
  I: Integer;
begin
  if Lib <> NilHandle then
    Exit;
  for I := Low(LibNames) to High(LibNames) do
  begin
    Lib := LoadLibrary(LibNames[I]);
    if Lib <> NilHandle then
      Break;
  end;
  if Lib = NilHandle then
    raise EOpenSSLCrypto.Create('OpenSSL''s libcrypto (version 3) was not found');
  Load(p_EVP_sha1, 'EVP_sha1');
  Load(p_EVP_sha256, 'EVP_sha256');
  Load(p_EVP_aes_256_cbc, 'EVP_aes_256_cbc');
  Load(p_EVP_Digest, 'EVP_Digest');
  Load(p_HMAC, 'HMAC');
  Load(p_EVP_CIPHER_CTX_new, 'EVP_CIPHER_CTX_new');
  Load(p_EVP_CIPHER_CTX_free, 'EVP_CIPHER_CTX_free');
  Load(p_EVP_DecryptInit_ex, 'EVP_DecryptInit_ex');
  Load(p_EVP_CIPHER_CTX_set_padding, 'EVP_CIPHER_CTX_set_padding');
  Load(p_EVP_DecryptUpdate, 'EVP_DecryptUpdate');
  // OpenSSL 3.0 has these; Argon2 itself needs 3.2 (checked when it is fetched)
  Load(p_EVP_KDF_fetch, 'EVP_KDF_fetch', False);
  Load(p_EVP_KDF_free, 'EVP_KDF_free', False);
  Load(p_EVP_KDF_CTX_new, 'EVP_KDF_CTX_new', False);
  Load(p_EVP_KDF_CTX_free, 'EVP_KDF_CTX_free', False);
  Load(p_EVP_KDF_derive, 'EVP_KDF_derive', False);
end;

function BytesOf(const S: String): TBytesArray;
begin
  Result := nil;
  SetLength(Result, Length(S));
  if S <> '' then
    Move(S[1], Result[0], Length(S));
end;

function DataPtr(const B: TBytesArray): Pointer;
const
  Empty: Byte = 0;
begin
  if Length(B) = 0 then Result := @Empty else Result := @B[0];
end;

function Digest(MD: Pointer; const Data: TBytesArray; Len: Integer): TBytesArray;
var
  N: cuint;
begin
  Result := nil;
  SetLength(Result, Len);
  N := Len;
  if p_EVP_Digest(DataPtr(Data), Length(Data), @Result[0], @N, MD, nil) <> 1 then
    raise EOpenSSLCrypto.Create('digest failed');
end;

function SHA1(const Data: TBytesArray): TBytesArray;
begin
  Need;
  Result := Digest(p_EVP_sha1(), Data, 20);
end;

function SHA256(const Data: TBytesArray): TBytesArray;
begin
  Need;
  Result := Digest(p_EVP_sha256(), Data, 32);
end;

function DoHMAC(MD: Pointer; const Key, Data: TBytesArray; Len: Integer): TBytesArray;
var
  N: cuint;
begin
  Result := nil;
  SetLength(Result, Len);
  N := Len;
  if p_HMAC(MD, DataPtr(Key), Length(Key), DataPtr(Data), Length(Data), @Result[0], @N) = nil then
    raise EOpenSSLCrypto.Create('HMAC failed');
end;

function HMAC_SHA1(const Key, Data: TBytesArray): TBytesArray;
begin
  Need;
  Result := DoHMAC(p_EVP_sha1(), Key, Data, 20);
end;

function HMAC_SHA256(const Key, Data: TBytesArray): TBytesArray;
begin
  Need;
  Result := DoHMAC(p_EVP_sha256(), Key, Data, 32);
end;

procedure AES256CBCDecrypt(const Key, IV: TBytesArray; var Data: TBytesArray);
var
  Ctx: Pointer;
  Plain: TBytesArray;
  N: cint;
begin
  Need;
  if (Length(Key) <> 32) or (Length(IV) <> 16) or (Length(Data) mod 16 <> 0) then
    raise EOpenSSLCrypto.Create('bad AES-256-CBC parameters');
  if Length(Data) = 0 then
    Exit;
  SetLength(Plain, Length(Data) + 16);
  Ctx := p_EVP_CIPHER_CTX_new();
  try
    if (p_EVP_DecryptInit_ex(Ctx, p_EVP_aes_256_cbc(), nil, @Key[0], @IV[0]) <> 1)
      or (p_EVP_CIPHER_CTX_set_padding(Ctx, 0) <> 1)
      or (p_EVP_DecryptUpdate(Ctx, @Plain[0], @N, @Data[0], Length(Data)) <> 1) or (N <> Length(Data)) then
      raise EOpenSSLCrypto.Create('AES-256-CBC decryption failed');
  finally
    p_EVP_CIPHER_CTX_free(Ctx);
  end;
  Move(Plain[0], Data[0], Length(Data));
end;

function Argon2(Flavour: TArgon2Flavour; MemoryKiB, Passes, Parallelism: Cardinal;
  const Password, Salt: TBytesArray; OutLen: Integer): TBytesArray;
const
  Names: array[TArgon2Flavour] of PChar = ('ARGON2D', 'ARGON2I', 'ARGON2ID');
var
  Kdf, Ctx: Pointer;
  Params: array[0..6] of OSSL_PARAM;
  Threads, Lanes, Iter, Mem: cuint32;

  procedure Param(I: Integer; Key: PChar; DataType: cuint; Data: Pointer; Size: csize_t);
  begin
    Params[I].key := Key;
    Params[I].data_type := DataType;
    Params[I].data := Data;
    Params[I].data_size := Size;
    Params[I].return_size := csize_t(-1);
  end;

begin
  Need;
  if not Assigned(p_EVP_KDF_fetch) then
    raise EOpenSSLCrypto.Create('this OpenSSL has no key derivation functions (3.0 or later is needed)');
  Kdf := p_EVP_KDF_fetch(nil, Names[Flavour], nil);
  if Kdf = nil then
    raise EOpenSSLCrypto.Create('this OpenSSL has no Argon2 (3.2 or later is needed)');
  try
    Ctx := p_EVP_KDF_CTX_new(Kdf);
    try
      Lanes := Parallelism;
      Iter := Passes;
      Mem := MemoryKiB;
      Threads := 1;   // more threads need OSSL_set_max_threads; one is enough for a key file
      Param(0, 'pass', OSSL_PARAM_OCTET_STRING, DataPtr(Password), Length(Password));
      Param(1, 'salt', OSSL_PARAM_OCTET_STRING, DataPtr(Salt), Length(Salt));
      Param(2, 'iter', OSSL_PARAM_UNSIGNED_INTEGER, @Iter, SizeOf(Iter));
      Param(3, 'lanes', OSSL_PARAM_UNSIGNED_INTEGER, @Lanes, SizeOf(Lanes));
      Param(4, 'memcost', OSSL_PARAM_UNSIGNED_INTEGER, @Mem, SizeOf(Mem));
      Param(5, 'threads', OSSL_PARAM_UNSIGNED_INTEGER, @Threads, SizeOf(Threads));
      FillChar(Params[6], SizeOf(Params[6]), 0);
      Result := nil;
      SetLength(Result, OutLen);
      if p_EVP_KDF_derive(Ctx, @Result[0], OutLen, @Params[0]) <> 1 then
        raise EOpenSSLCrypto.Create('Argon2 failed');
    finally
      p_EVP_KDF_CTX_free(Ctx);
    end;
  finally
    p_EVP_KDF_free(Kdf);
  end;
end;

end.
