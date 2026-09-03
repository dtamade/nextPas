program test_hkdf;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.crypto.hkdf,
  nextpas.core.test;

function ToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('hkdf');

  LSuite.Test('RFC 5869 TC1 Extract', procedure
  var LIKM, LSalt, LPRK: TBytes;
  begin
    LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    LSalt := HexToBytes('000102030405060708090a0b0c');
    LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    CheckEqual('077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5',
      ToHex(LPRK));
  end);

  LSuite.Test('RFC 5869 TC1 Expand', procedure
  var LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
  begin
    LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    LSalt := HexToBytes('000102030405060708090a0b0c');
    LInfo := HexToBytes('f0f1f2f3f4f5f6f7f8f9');
    LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
    CheckEqual('3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865',
      ToHex(LOKM));
  end);

  LSuite.Test('RFC 5869 TC2 Extract', procedure
  var LIKM, LSalt, LPRK: TBytes;
  begin
    LIKM := HexToBytes('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f' +
      '202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f' +
      '404142434445464748494a4b4c4d4e4f');
    LSalt := HexToBytes('606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f' +
      '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f' +
      'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf');
    LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    CheckEqual('06a6b88c5853361a06104c9ceb35b45cef760014904671014a193f40c15fc244',
      ToHex(LPRK));
  end);

  LSuite.Test('RFC 5869 TC2 Expand', procedure
  var LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
  begin
    LIKM := HexToBytes('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f' +
      '202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f' +
      '404142434445464748494a4b4c4d4e4f');
    LSalt := HexToBytes('606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f' +
      '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f' +
      'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf');
    LInfo := HexToBytes('b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecf' +
      'd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeef' +
      'f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff');
    LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 82);
    CheckEqual(82, Length(LOKM));
    CheckEqual('b11e398dc80327a1c8e7f78c596a4934', Copy(ToHex(LOKM), 1, 32));
  end);

  LSuite.Test('RFC 5869 TC3 empty salt/info', procedure
  var LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
  begin
    LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    SetLength(LSalt, 0); SetLength(LInfo, 0);
    LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    CheckEqual('19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04',
      ToHex(LPRK));
    LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
    CheckEqual('8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8',
      ToHex(LOKM));
  end);

  LSuite.Test('convenience functions', procedure
  var LIKM, LSalt, LInfo, LPRK1, LPRK2, LOKM1, LOKM2: TBytes;
  begin
    LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
    LSalt := HexToBytes('000102030405060708090a0b0c');
    LInfo := HexToBytes('f0f1f2f3f4f5f6f7f8f9');
    LPRK1 := HKDF_Extract_SHA256(LSalt, LIKM);
    LPRK2 := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    CheckTrue(CompareMem(@LPRK1[0], @LPRK2[0], Length(LPRK1)));
    LOKM1 := HKDF_Expand_SHA256(LPRK1, LInfo, 42);
    LOKM2 := HKDF_ExpandBytes(haSHA256, LPRK1, LInfo, 42);
    CheckTrue(CompareMem(@LOKM1[0], @LOKM2[0], 42));
  end);

  LSuite.Test('edge cases', procedure
  var LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
  begin
    SetLength(LIKM, 0);
    LSalt := HexToBytes('000102030405060708090a0b0c');
    LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
    CheckEqual(32, Length(LPRK));
    SetLength(LInfo, 0);
    LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 1);
    CheckEqual(1, Length(LOKM));
    LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 32);
    CheckEqual(32, Length(LOKM));
    LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 64);
    CheckEqual(64, Length(LOKM));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.hkdf');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
