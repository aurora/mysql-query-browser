{ SPDX-License-Identifier: GPL-2.0-or-later }
{ Reads PuTTY private key files (.ppk, formats 2 and 3) and turns the key into an unencrypted OpenSSH private key
  ("openssh-key-v1") in memory, which libssh imports (ADR-0048). Nothing is written to disk.

  The format, as PuTTY 0.84 reads it (sshpubk.c, ppk_load_s):
    PuTTY-User-Key-File-<2|3>: <algorithm>
    Encryption: none | aes256-cbc
    Comment: <text>
    Public-Lines: <n>, then the public blob in base64
    (format 3 and encrypted: Key-Derivation: Argon2id|Argon2i|Argon2d, Argon2-Memory (KiB), Argon2-Passes,
     Argon2-Parallelism, Argon2-Salt (hex))
    Private-Lines: <n>, then the private blob in base64 (encrypted with AES-256-CBC if so)
    Private-MAC: <hex>
  Keys: format 2 derives the AES key from SHA-1(uint32 counter || passphrase), the IV is zero, the MAC key is
  SHA-1("putty-private-key-file-mac-key" || passphrase), MAC HMAC-SHA1. Format 3 takes key, IV and MAC key (32 + 16
  + 32 bytes) from Argon2 over the passphrase and the salt, MAC HMAC-SHA256; unencrypted, the MAC key is empty. The
  MAC covers string(algorithm), string(encryption), string(comment), string(public blob), string(private blob).
  Private blobs: RSA d, p, q, iqmp (mpints); Ed25519 the 32-byte seed (string); ECDSA d (mpint). }
unit PuttyKey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, OpenSSLCrypto;

type
  TPuttyKeyResult = (pkOK, pkNeedPassphrase, pkWrongPassphrase, pkError);

function IsPuttyKeyFile(const FileName: String): Boolean;
// Converts the key; on pkError, ErrorText says why
function PuttyKeyToOpenSSH(const FileName, Passphrase: String; out PEM, ErrorText: String): TPuttyKeyResult;

implementation

uses
  base64, StrUtils;

type
  EPuttyKey = class(Exception);

  { reading and writing the SSH wire format }
  TReader = record
    Data: TBytesArray;
    Pos: Integer;
  end;

function ReadUInt32(var R: TReader): Cardinal;
begin
  if R.Pos + 4 > Length(R.Data) then
    raise EPuttyKey.Create('key blob too short');
  Result := (Cardinal(R.Data[R.Pos]) shl 24) or (Cardinal(R.Data[R.Pos + 1]) shl 16) or
    (Cardinal(R.Data[R.Pos + 2]) shl 8) or Cardinal(R.Data[R.Pos + 3]);
  Inc(R.Pos, 4);
end;

function ReadString(var R: TReader): TBytesArray;
var
  N: Cardinal;
begin
  N := ReadUInt32(R);
  if Int64(R.Pos) + N > Length(R.Data) then
    raise EPuttyKey.Create('key blob too short');
  Result := nil;
  SetLength(Result, N);
  if N > 0 then
    Move(R.Data[R.Pos], Result[0], N);
  Inc(R.Pos, N);
end;

function AsText(const B: TBytesArray): String;
begin
  SetLength(Result, Length(B));
  if Length(B) > 0 then
    Move(B[0], Result[1], Length(B));
end;

procedure Append(var B: TBytesArray; const Part: TBytesArray);
var
  N: Integer;
begin
  N := Length(B);
  SetLength(B, N + Length(Part));
  if Length(Part) > 0 then
    Move(Part[0], B[N], Length(Part));
end;

procedure AppendUInt32(var B: TBytesArray; V: Cardinal);
var
  P: TBytesArray;
begin
  SetLength(P, 4);
  P[0] := V shr 24; P[1] := (V shr 16) and $FF; P[2] := (V shr 8) and $FF; P[3] := V and $FF;
  Append(B, P);
end;

procedure AppendString(var B: TBytesArray; const S: TBytesArray);
begin
  AppendUInt32(B, Length(S));
  Append(B, S);
end;

function Concat2(const A, B: TBytesArray): TBytesArray;
begin
  Result := nil;
  Append(Result, A);
  Append(Result, B);
end;

function HexOf(const B: TBytesArray): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

function UnHex(const S: String): TBytesArray;
var
  I: Integer;
begin
  if Odd(Length(S)) then
    raise EPuttyKey.Create('bad hex value');
  Result := nil;
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(S, I * 2 + 1, 2));
end;

{ the file }

function IsPuttyKeyFile(const FileName: String): Boolean;
var
  F: TFileStream;
  Head: String;
begin
  Result := False;
  try
    F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Head, 20);
      Result := (F.Read(Head[1], 20) = 20) and (Head = 'PuTTY-User-Key-File-');
    finally
      F.Free;
    end;
  except
    Result := False;
  end;
end;

type
  TPpk = record
    Version: Integer;
    Algorithm, Encryption, Comment: String;
    PublicBlob, PrivateBlob: TBytesArray;
    KdfName: String;
    ArgonMemory, ArgonPasses, ArgonParallelism: Cardinal;
    ArgonSalt: TBytesArray;
    MAC: String;
  end;

procedure ParseFile(const FileName: String; out Ppk: TPpk);
var
  Lines: TStringList;
  Line: Integer;

  function Field(const Name: String): String;
  var
    S: String;
    P: Integer;
  begin
    if Line >= Lines.Count then
      raise EPuttyKey.CreateFmt('"%s" is missing', [Name]);
    S := Lines[Line];
    P := Pos(': ', S);
    if (P = 0) or (Copy(S, 1, P - 1) <> Name) then
      raise EPuttyKey.CreateFmt('"%s" expected in line %d', [Name, Line + 1]);
    Result := Copy(S, P + 2, MaxInt);
    Inc(Line);
  end;

  function Blob(const Name: String): TBytesArray;
  var
    N, I: Integer;
    Text: String;
  begin
    N := StrToIntDef(Field(Name), -1);
    if (N < 0) or (Line + N > Lines.Count) then
      raise EPuttyKey.CreateFmt('bad "%s"', [Name]);
    Text := '';
    for I := 0 to N - 1 do
      Text := Text + Trim(Lines[Line + I]);
    Inc(Line, N);
    Result := BytesOf(DecodeStringBase64(Text, True));
  end;

var
  Header: String;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);   // LF or CRLF
    Line := 0;
    if Lines.Count = 0 then
      raise EPuttyKey.Create('empty file');
    Header := Lines[0];
    if AnsiStartsStr('PuTTY-User-Key-File-3: ', Header) then
      Ppk.Version := 3
    else if AnsiStartsStr('PuTTY-User-Key-File-2: ', Header) then
      Ppk.Version := 2
    else if AnsiStartsStr('PuTTY-User-Key-File-1: ', Header) then
      raise EPuttyKey.Create('format 1 (PuTTY before 0.52) is not supported; save the key again with PuTTYgen')
    else
      raise EPuttyKey.Create('not a PuTTY key file of format 2 or 3');
    Ppk.Algorithm := Copy(Header, Pos(': ', Header) + 2, MaxInt);
    Line := 1;
    Ppk.Encryption := Field('Encryption');
    if (Ppk.Encryption <> 'none') and (Ppk.Encryption <> 'aes256-cbc') then
      raise EPuttyKey.CreateFmt('unknown encryption "%s"', [Ppk.Encryption]);
    Ppk.Comment := Field('Comment');
    Ppk.PublicBlob := Blob('Public-Lines');
    Ppk.KdfName := '';
    if (Ppk.Version = 3) and (Ppk.Encryption <> 'none') then
    begin
      Ppk.KdfName := Field('Key-Derivation');
      Ppk.ArgonMemory := StrToDWord(Field('Argon2-Memory'));
      Ppk.ArgonPasses := StrToDWord(Field('Argon2-Passes'));
      Ppk.ArgonParallelism := StrToDWord(Field('Argon2-Parallelism'));
      Ppk.ArgonSalt := UnHex(Field('Argon2-Salt'));
    end;
    Ppk.PrivateBlob := Blob('Private-Lines');
    Ppk.MAC := LowerCase(Field('Private-MAC'));
  finally
    Lines.Free;
  end;
end;

// decrypts the private blob and checks the MAC; False for a wrong passphrase
function Unlock(var Ppk: TPpk; const Passphrase: String): Boolean;
var
  Pass, Key, IV, MacKey, Derived, MacData, Mac: TBytesArray;
  Flavour: TArgon2Flavour;
begin
  Pass := BytesOf(Passphrase);
  Key := nil; IV := nil; MacKey := nil;
  if Ppk.Version = 2 then
  begin
    if Ppk.Encryption <> 'none' then
    begin
      Derived := nil;
      Append(Derived, SHA1(Concat2(BytesOf(#0#0#0#0), Pass)));
      Append(Derived, SHA1(Concat2(BytesOf(#0#0#0#1), Pass)));
      Key := Copy(Derived, 0, 32);
      SetLength(IV, 16);
      FillChar(IV[0], 16, 0);
    end;
    MacKey := SHA1(Concat2(BytesOf('putty-private-key-file-mac-key'), Pass));
  end
  else if Ppk.Encryption <> 'none' then
  begin
    if Ppk.KdfName = 'Argon2id' then Flavour := a2id
    else if Ppk.KdfName = 'Argon2i' then Flavour := a2i
    else if Ppk.KdfName = 'Argon2d' then Flavour := a2d
    else raise EPuttyKey.CreateFmt('unknown key derivation "%s"', [Ppk.KdfName]);
    Derived := Argon2(Flavour, Ppk.ArgonMemory, Ppk.ArgonPasses, Ppk.ArgonParallelism, Pass, Ppk.ArgonSalt, 80);
    Key := Copy(Derived, 0, 32);
    IV := Copy(Derived, 32, 16);
    MacKey := Copy(Derived, 48, 32);
  end;
  if Ppk.Encryption <> 'none' then
    AES256CBCDecrypt(Key, IV, Ppk.PrivateBlob);
  MacData := nil;
  AppendString(MacData, BytesOf(Ppk.Algorithm));
  AppendString(MacData, BytesOf(Ppk.Encryption));
  AppendString(MacData, BytesOf(Ppk.Comment));
  AppendString(MacData, Ppk.PublicBlob);
  AppendString(MacData, Ppk.PrivateBlob);
  if Ppk.Version = 2 then
    Mac := HMAC_SHA1(MacKey, MacData)
  else
    Mac := HMAC_SHA256(MacKey, MacData);
  Result := HexOf(Mac) = Ppk.MAC;
  if not Result and (Ppk.Encryption = 'none') then
    raise EPuttyKey.Create('the key file is damaged (MAC check failed)');
end;

// the private part of an "openssh-key-v1" file for this key
function OpenSSHPrivate(const Ppk: TPpk): TBytesArray;
var
  Pub, Priv: TReader;
  KeyType, Seed, PubKey, E, N, D, P, Q, IQMP, Curve, Point: TBytesArray;
  Check: Cardinal;
  Pad: Byte;
begin
  Pub.Data := Ppk.PublicBlob; Pub.Pos := 0;
  Priv.Data := Ppk.PrivateBlob; Priv.Pos := 0;
  KeyType := ReadString(Pub);
  if AsText(KeyType) <> Ppk.Algorithm then
    raise EPuttyKey.Create('the public key does not match the algorithm');
  Result := nil;
  Check := Random($7FFFFFFF);
  AppendUInt32(Result, Check);
  AppendUInt32(Result, Check);
  AppendString(Result, KeyType);
  if Ppk.Algorithm = 'ssh-rsa' then
  begin
    E := ReadString(Pub);
    N := ReadString(Pub);
    D := ReadString(Priv);
    P := ReadString(Priv);
    Q := ReadString(Priv);
    IQMP := ReadString(Priv);
    AppendString(Result, N);
    AppendString(Result, E);
    AppendString(Result, D);
    AppendString(Result, IQMP);
    AppendString(Result, P);
    AppendString(Result, Q);
  end
  else if Ppk.Algorithm = 'ssh-ed25519' then
  begin
    PubKey := ReadString(Pub);
    Seed := ReadString(Priv);
    if (Length(PubKey) <> 32) or (Length(Seed) <> 32) then
      raise EPuttyKey.Create('bad Ed25519 key');
    AppendString(Result, PubKey);
    AppendString(Result, Concat2(Seed, PubKey));
  end
  else if AnsiStartsStr('ecdsa-sha2-', Ppk.Algorithm) then
  begin
    Curve := ReadString(Pub);
    Point := ReadString(Pub);
    D := ReadString(Priv);
    AppendString(Result, Curve);
    AppendString(Result, Point);
    AppendString(Result, D);
  end
  else
    raise EPuttyKey.CreateFmt('key type "%s" is not supported (RSA, Ed25519 and ECDSA are)', [Ppk.Algorithm]);
  AppendString(Result, BytesOf(Ppk.Comment));
  Pad := 1;
  while Length(Result) mod 8 <> 0 do
  begin
    Append(Result, BytesOf(Chr(Pad)));
    Inc(Pad);
  end;
end;

function ToPEM(const Ppk: TPpk): String;
var
  Blob: TBytesArray;
  B64: String;
  I: Integer;
begin
  Blob := BytesOf('openssh-key-v1'#0);
  AppendString(Blob, BytesOf('none'));
  AppendString(Blob, BytesOf('none'));
  AppendString(Blob, nil);
  AppendUInt32(Blob, 1);
  AppendString(Blob, Ppk.PublicBlob);
  AppendString(Blob, OpenSSHPrivate(Ppk));
  B64 := EncodeStringBase64(AsText(Blob));
  Result := '-----BEGIN OPENSSH PRIVATE KEY-----'#10;
  I := 1;
  while I <= Length(B64) do
  begin
    Result := Result + Copy(B64, I, 70) + #10;
    Inc(I, 70);
  end;
  Result := Result + '-----END OPENSSH PRIVATE KEY-----'#10;
end;

function PuttyKeyToOpenSSH(const FileName, Passphrase: String; out PEM, ErrorText: String): TPuttyKeyResult;
var
  Ppk: TPpk;
begin
  PEM := '';
  ErrorText := '';
  try
    ParseFile(FileName, Ppk);
    if (Ppk.Encryption <> 'none') and (Passphrase = '') then
      Exit(pkNeedPassphrase);
    if not Unlock(Ppk, Passphrase) then
      Exit(pkWrongPassphrase);
    PEM := ToPEM(Ppk);
    Result := pkOK;
  except
    on E: Exception do
    begin
      ErrorText := E.Message;
      Result := pkError;
    end;
  end;
end;

initialization
  Randomize;

end.
