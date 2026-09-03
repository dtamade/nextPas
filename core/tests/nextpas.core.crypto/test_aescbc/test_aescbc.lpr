program test_aescbc;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.aescbc,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('aescbc');

  LSuite.Test('NIST AES-128-CBC encrypt', procedure
  var LKey, LIV, LPlain, LResult: TBytes;
  begin
    LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
    LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LPlain := HexToBytes('6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710');
    LResult := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
    CheckEqual('7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b273bed6b8e3c1743b7116e69e222295163ff1caa1681fac09120eca307586e1a7',
      BytesToHex(LResult));
  end);

  LSuite.Test('NIST AES-128-CBC decrypt', procedure
  var LKey, LIV, LCipher, LResult: TBytes;
  begin
    LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
    LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LCipher := HexToBytes('7649abac8119b246cee98e9b12e9197d5086cb9b507219ee95db113a917678b273bed6b8e3c1743b7116e69e222295163ff1caa1681fac09120eca307586e1a7');
    LResult := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
    CheckEqual('6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710',
      BytesToHex(LResult));
  end);

  LSuite.Test('NIST AES-256-CBC encrypt', procedure
  var LKey, LIV, LPlain, LResult: TBytes;
  begin
    LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
    LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LPlain := HexToBytes('6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710');
    LResult := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
    CheckEqual('f58c4c04d6e5f1ba779eabfb5f7bfbd69cfc4e967edb808d679f777bc6702c7d39f23369a9d9bacfa530e26304231461b2eb05e2c39be9fcda6c19078c6a9d1b',
      BytesToHex(LResult));
  end);

  LSuite.Test('NIST AES-256-CBC decrypt', procedure
  var LKey, LIV, LCipher, LResult: TBytes;
  begin
    LKey := HexToBytes('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4');
    LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LCipher := HexToBytes('f58c4c04d6e5f1ba779eabfb5f7bfbd69cfc4e967edb808d679f777bc6702c7d39f23369a9d9bacfa530e26304231461b2eb05e2c39be9fcda6c19078c6a9d1b');
    LResult := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
    CheckEqual('6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710',
      BytesToHex(LResult));
  end);

  LSuite.Test('roundtrip', procedure
  var LKey, LIV, LPlain, LCipher, LRecovered: TBytes; I: Integer;
  begin
    SetLength(LKey, 16); SetLength(LIV, 16); SetLength(LPlain, 48);
    for I := 0 to 15 do begin LKey[I] := Byte(I*3+7); LIV[I] := Byte(I xor $AA); end;
    for I := 0 to 47 do LPlain[I] := Byte(I);
    LCipher := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
    CheckTrue(BytesToHex(LCipher) <> BytesToHex(LPlain));
    LRecovered := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LRecovered));
  end);

  LSuite.Test('single block', procedure
  var LKey, LIV, LPlain, LCipher, LRecovered: TBytes;
  begin
    LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
    LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LPlain := HexToBytes('6bc1bee22e409f96e93d7e117393172a');
    LCipher := AESCBCEncryptNoPadding(LKey, LIV, LPlain);
    CheckEqual('7649abac8119b246cee98e9b12e9197d', BytesToHex(LCipher));
    LRecovered := AESCBCDecryptNoPadding(LKey, LIV, LCipher);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LRecovered));
  end);

  LSuite.Test('non-aligned raises', procedure
  var LKey, LIV, LBad: TBytes; LRaised: Boolean;
  begin
    LKey := HexToBytes('2b7e151628aed2a6abf7158809cf4f3c');
    LIV := HexToBytes('000102030405060708090a0b0c0d0e0f');
    SetLength(LBad, 15);
    LRaised := False;
    try AESCBCEncryptNoPadding(LKey, LIV, LBad); except LRaised := True; end;
    CheckTrue(LRaised);
    LRaised := False;
    try AESCBCDecryptNoPadding(LKey, LIV, LBad); except LRaised := True; end;
    CheckTrue(LRaised);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.aescbc');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
