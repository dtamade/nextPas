program test_pure_pascal_aescbc;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.crypto.aescbc;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ABytes) - 1 do
    Result := Result + LowerCase(IntToHex(ABytes[I], 2));
end;

procedure TestAES128CBC_NIST;
var
  LKey, LIV, LPlaintext, LCiphertext, LDecrypted: TBytes;
begin
  WriteLn('Test: NIST AES-128-CBC (F.2.1/F.2.2)');
  LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LPlaintext := HexToBytes(
    '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710'
  );

  LCiphertext := AESCBCEncryptNoPadding(LKey, LIV, LPlaintext);
  Check(BytesToHex(LCiphertext) =
    '7649abac8119b246cee98e9b12e9197d' +
    '5086cb9b507219ee95db113a917678b2' +
    '73bed6b8e3c1743b7116e69e22229516' +
    '3ff1caa1681fac09120eca307586e1a7',
    'AES-128-CBC encrypt mismatch');

  LDecrypted := AESCBCDecryptNoPadding(LKey, LIV, LCiphertext);
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'AES-128-CBC decrypt mismatch');
end;

procedure TestAES256CBC_NIST;
var
  LKey, LIV, LPlaintext, LCiphertext, LDecrypted: TBytes;
begin
  WriteLn('Test: NIST AES-256-CBC (F.2.5/F.2.6)');
  LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
  LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
  LPlaintext := HexToBytes(
    '6bc1bee22e409f96e93d7e117393172a' +
    'ae2d8a571e03ac9c9eb76fac45af8e51' +
    '30c81c46a35ce411e5fbc1191a0a52ef' +
    'f69f2445df4f9b17ad2b417be66c3710'
  );

  LCiphertext := AESCBCEncryptNoPadding(LKey, LIV, LPlaintext);
  Check(BytesToHex(LCiphertext) =
    'f58c4c04d6e5f1ba779eabfb5f7bfbd6' +
    '9cfc4e967edb808d679f777bc6702c7d' +
    '39f23369a9d9bacfa530e26304231461' +
    'b2eb05e2c39be9fcda6c19078c6a9d1b',
    'AES-256-CBC encrypt mismatch');

  LDecrypted := AESCBCDecryptNoPadding(LKey, LIV, LCiphertext);
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'AES-256-CBC decrypt mismatch');
end;

procedure TestAESCBC_SingleBlock;
var
  LKey, LIV, LPlaintext, LCiphertext, LDecrypted: TBytes;
begin
  WriteLn('Test: AES-128-CBC single block');
  LKey := HexToBytes('00000000000000000000000000000000');
  LIV := HexToBytes('00000000000000000000000000000000');
  LPlaintext := HexToBytes('00000000000000000000000000000000');

  LCiphertext := AESCBCEncryptNoPadding(LKey, LIV, LPlaintext);
  Check(Length(LCiphertext) = 16, 'Single block should produce 16 bytes');

  LDecrypted := AESCBCDecryptNoPadding(LKey, LIV, LCiphertext);
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'Single block roundtrip');
end;

begin
  WriteLn('=== Pure Pascal AES-CBC Tests ===');
  WriteLn('');

  TestAES128CBC_NIST;
  TestAES256CBC_NIST;
  TestAESCBC_SingleBlock;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
