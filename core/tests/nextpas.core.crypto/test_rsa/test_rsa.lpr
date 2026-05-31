program test_rsa;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.rsa;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestEncode_Format;
var
  LMsg, LEncoded: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LMsg := HexToBytes('48656c6c6f'); // "Hello"
  LOk := TryRSAES_PKCS1v15_Encode(LMsg, 64, LEncoded, LError);
  Check('encode: success', LOk);
  if LOk then
  begin
    Check('encode: length = key length', Length(LEncoded) = 64);
    Check('encode: starts with 00 02', (LEncoded[0] = $00) and (LEncoded[1] = $02));
    Check('encode: separator at correct position', LEncoded[64 - 5 - 1] = $00);
    Check('encode: message at end',
      (LEncoded[59] = $48) and (LEncoded[60] = $65) and
      (LEncoded[61] = $6c) and (LEncoded[62] = $6c) and (LEncoded[63] = $6f));
  end;
end;

procedure TestEncode_PaddingNonZero;
var
  LMsg, LEncoded: TBytes;
  LError: string;
  LOk: Boolean;
  I: Integer;
  LAllNonZero: Boolean;
begin
  LMsg := HexToBytes('aa');
  LOk := TryRSAES_PKCS1v15_Encode(LMsg, 64, LEncoded, LError);
  Check('padding: encode ok', LOk);
  if LOk then
  begin
    LAllNonZero := True;
    for I := 2 to 64 - 1 - 1 - 1 do
      if LEncoded[I] = 0 then
        LAllNonZero := False;
    Check('padding: all PS bytes non-zero', LAllNonZero);
  end;
end;

procedure TestEncode_MessageTooLong;
var
  LMsg, LEncoded: TBytes;
  LError: string;
  LOk: Boolean;
begin
  SetLength(LMsg, 54); // 64 - 11 + 1 = too long for 64-byte key
  LOk := TryRSAES_PKCS1v15_Encode(LMsg, 64, LEncoded, LError);
  Check('encode: message too long rejected', not LOk);
  Check('encode: error mentions length', Pos('too long', LError) > 0);
end;

procedure TestEncrypt_SmallKey;
var
  LMsg, LMod, LExp, LCipher: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LMsg := HexToBytes('48656c6c6f'); // "Hello"
  // Use a 64-byte (512-bit) modulus for testing
  LMod := HexToBytes(
    'D4BCD52406F2C926267E902E2B8F6B6B' +
    '5B1B3A5412C4A7C8E0F8B2D3C4A5B6C7' +
    'D8E9F0A1B2C3D4E5F6A7B8C9D0E1F2A3' +
    'B4C5D6E7F8091A2B3C4D5E6F70818293');
  LExp := HexToBytes('010001'); // 65537

  LOk := TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LCipher, LError);
  Check('encrypt: success', LOk);
  if LOk then
  begin
    Check('encrypt: ciphertext length = modulus length', Length(LCipher) = Length(LMod));
    Check('encrypt: ciphertext differs from plaintext', BytesToHex(LCipher) <> BytesToHex(LMsg));
  end;
end;

procedure TestEncrypt_ModulusTooShort;
var
  LMsg, LMod, LExp, LCipher: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LMsg := HexToBytes('aa');
  SetLength(LMod, 32); // Too short (< 64 bytes)
  LExp := HexToBytes('010001');
  LOk := TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LCipher, LError);
  Check('encrypt: short modulus rejected', not LOk);
end;

procedure TestEncrypt_Determinism;
var
  LMsg, LMod, LExp, LCipher1, LCipher2: TBytes;
  LError: string;
begin
  LMsg := HexToBytes('48656c6c6f');
  LMod := HexToBytes(
    'D4BCD52406F2C926267E902E2B8F6B6B' +
    '5B1B3A5412C4A7C8E0F8B2D3C4A5B6C7' +
    'D8E9F0A1B2C3D4E5F6A7B8C9D0E1F2A3' +
    'B4C5D6E7F8091A2B3C4D5E6F70818293');
  LExp := HexToBytes('010001');

  TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LCipher1, LError);
  TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LCipher2, LError);
  Check('encrypt: randomized (different each time)', BytesToHex(LCipher1) <> BytesToHex(LCipher2));
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== RSA PKCS#1 v1.5 Tests ===');
  WriteLn;

  TestEncode_Format;
  TestEncode_PaddingNonZero;
  TestEncode_MessageTooLong;
  TestEncrypt_SmallKey;
  TestEncrypt_ModulusTooShort;
  TestEncrypt_Determinism;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
