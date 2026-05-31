program test_aescbc;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.aescbc;

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

{ NIST SP 800-38A Appendix F.2.1 — AES-128-CBC Encrypt }
procedure TestNIST_AES128CBC_Encrypt;
var
  LKey, LIV, LPlain, LExpected, LResult: TBytes;
begin
  LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LPlain := HexToBytes(
    '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710');
  LExpected := HexToBytes(
    '7649abac8119b246cee98e9b12e9197d' +
    '5086cb9b507219ee95db113a917678b2' +
    '73bed6b8e3c1743b7116e69e22229516' +
    '3ff1caa1681fac09120eca307586e1a7');

  LResult := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
  Check('NIST AES-128-CBC encrypt (4 blocks)', BytesToHex(LResult) = BytesToHex(LExpected));
end;

{ NIST SP 800-38A Appendix F.2.2 — AES-128-CBC Decrypt }
procedure TestNIST_AES128CBC_Decrypt;
var
  LKey, LIV, LCipher, LExpected, LResult: TBytes;
begin
  LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LCipher := HexToBytes(
    '7649abac8119b246cee98e9b12e9197d' +
    '5086cb9b507219ee95db113a917678b2' +
    '73bed6b8e3c1743b7116e69e22229516' +
    '3ff1caa1681fac09120eca307586e1a7');
  LExpected := HexToBytes(
    '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710');

  LResult := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
  Check('NIST AES-128-CBC decrypt (4 blocks)', BytesToHex(LResult) = BytesToHex(LExpected));
end;

{ NIST SP 800-38A Appendix F.2.5 — AES-256-CBC Encrypt }
procedure TestNIST_AES256CBC_Encrypt;
var
  LKey, LIV, LPlain, LExpected, LResult: TBytes;
begin
  LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LPlain := HexToBytes(
    '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710');
  LExpected := HexToBytes(
    'f58c4c04d6e5f1ba779eabfb5f7bfbd6' +
    '9cfc4e967edb808d679f777bc6702c7d' +
    '39f23369a9d9bacfa530e26304231461' +
    'b2eb05e2c39be9fcda6c19078c6a9d1b');

  LResult := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
  Check('NIST AES-256-CBC encrypt (4 blocks)', BytesToHex(LResult) = BytesToHex(LExpected));
end;

{ NIST SP 800-38A Appendix F.2.6 — AES-256-CBC Decrypt }
procedure TestNIST_AES256CBC_Decrypt;
var
  LKey, LIV, LCipher, LExpected, LResult: TBytes;
begin
  LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LCipher := HexToBytes(
    'f58c4c04d6e5f1ba779eabfb5f7bfbd6' +
    '9cfc4e967edb808d679f777bc6702c7d' +
    '39f23369a9d9bacfa530e26304231461' +
    'b2eb05e2c39be9fcda6c19078c6a9d1b');
  LExpected := HexToBytes(
    '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710');

  LResult := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
  Check('NIST AES-256-CBC decrypt (4 blocks)', BytesToHex(LResult) = BytesToHex(LExpected));
end;

{ Roundtrip: encrypt then decrypt recovers plaintext }
procedure TestRoundtrip;
var
  LKey, LIV, LPlain, LCipher, LRecovered: TBytes;
  I: Integer;
begin
  SetLength(LKey, 16);
  SetLength(LIV, 16);
  SetLength(LPlain, 48);
  for I := 0 to 15 do begin LKey[I] := Byte(I * 3 + 7); LIV[I] := Byte(I xor $AA); end;
  for I := 0 to 47 do LPlain[I] := Byte(I);

  LCipher := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
  Check('roundtrip ciphertext differs from plaintext', BytesToHex(LCipher) <> BytesToHex(LPlain));

  LRecovered := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
  Check('roundtrip decrypt recovers plaintext', BytesToHex(LRecovered) = BytesToHex(LPlain));
end;

{ Single block (16 bytes) }
procedure TestSingleBlock;
var
  LKey, LIV, LPlain, LCipher, LRecovered: TBytes;
begin
  LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LPlain := HexToBytes('6bc1bee22e409f96e93d7e117393172a');

  LCipher := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
  Check('single block encrypt', BytesToHex(LCipher) = '7649abac8119b246cee98e9b12e9197d');

  LRecovered := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
  Check('single block decrypt', BytesToHex(LRecovered) = BytesToHex(LPlain));
end;

{ Non-aligned input should raise exception }
procedure TestNonAligned;
var
  LKey, LIV, LBad: TBytes;
  LRaised: Boolean;
begin
  LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  SetLength(LBad, 15);

  LRaised := False;
  try
    AESCBCEncryptNoPadding(LKey, LIV, LBad);
  except
    LRaised := True;
  end;
  Check('non-aligned encrypt raises', LRaised);

  LRaised := False;
  try
    AESCBCDecryptNoPadding(LKey, LIV, LBad);
  except
    LRaised := True;
  end;
  Check('non-aligned decrypt raises', LRaised);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== AES-CBC (NIST SP 800-38A) Tests ===');
  WriteLn;

  TestNIST_AES128CBC_Encrypt;
  TestNIST_AES128CBC_Decrypt;
  TestNIST_AES256CBC_Encrypt;
  TestNIST_AES256CBC_Decrypt;
  TestRoundtrip;
  TestSingleBlock;
  TestNonAligned;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
