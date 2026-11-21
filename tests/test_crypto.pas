{ SPDX-License-Identifier: GPL-2.0-or-later }
{ The crypto primitives of the PuTTY key reader (app/compat/OpenSSLCrypto.pas) against published test vectors:
  HMAC-SHA1 (RFC 2202) and HMAC-SHA256 (RFC 4231), computed there from the digest. No server needed. }
unit test_crypto;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, OpenSSLCrypto;

type
  TCryptoTest = class(TTestCase)
  published
    procedure TestHMACSHA1;
    procedure TestHMACSHA256;
  end;

implementation

function Hex(const B: TBytesArray): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(B) do
    Result := Result + LowerCase(IntToHex(B[I], 2));
end;

function Repeated(B: Byte; N: Integer): TBytesArray;
begin
  Result := nil;
  SetLength(Result, N);
  FillChar(Result[0], N, B);
end;

procedure TCryptoTest.TestHMACSHA1;
begin
  // RFC 2202, test cases 1, 2 and 6 (key longer than the block)
  AssertEquals('case 1', 'b617318655057264e28bc0b6fb378c8ef146be00',
    Hex(HMAC_SHA1(Repeated($0B, 20), BytesOf('Hi There'))));
  AssertEquals('case 2', 'effcdf6ae5eb2fa2d27416d5f184df9c259a7c79',
    Hex(HMAC_SHA1(BytesOf('Jefe'), BytesOf('what do ya want for nothing?'))));
  AssertEquals('case 6', 'aa4ae5e15272d00e95705637ce8a3b55ed402112',
    Hex(HMAC_SHA1(Repeated($AA, 80), BytesOf('Test Using Larger Than Block-Size Key - Hash Key First'))));
end;

procedure TCryptoTest.TestHMACSHA256;
begin
  // RFC 4231, test cases 1, 2 and 6, and an empty key (the MAC key of an unencrypted format-3 .ppk)
  AssertEquals('case 1', 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7',
    Hex(HMAC_SHA256(Repeated($0B, 20), BytesOf('Hi There'))));
  AssertEquals('case 2', '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
    Hex(HMAC_SHA256(BytesOf('Jefe'), BytesOf('what do ya want for nothing?'))));
  AssertEquals('case 6', '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54',
    Hex(HMAC_SHA256(Repeated($AA, 131), BytesOf('Test Using Larger Than Block-Size Key - Hash Key First'))));
  AssertEquals('empty key', 'b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad',
    Hex(HMAC_SHA256(nil, nil)));
end;

initialization
  RegisterTest(TCryptoTest);

end.
