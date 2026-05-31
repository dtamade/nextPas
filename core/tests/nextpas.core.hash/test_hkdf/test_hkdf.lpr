program test_hkdf;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.crypto.hkdf;

var GPass, GFail: Integer;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  [PASS] ', AName); end
  else begin Inc(GFail); WriteLn('  [FAIL] ', AName); end;
end;

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

procedure TestRFC5869_SHA256;
var
  LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
begin
  WriteLn('--- RFC 5869 SHA-256 ---');

  // TC1: Basic
  LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSalt := HexToBytes('000102030405060708090a0b0c');
  LInfo := HexToBytes('f0f1f2f3f4f5f6f7f8f9');
  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  Check('TC1 Extract',
    ToHex(LPRK) = '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5');
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
  Check('TC1 Expand',
    ToHex(LOKM) = '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865');

  // TC2: Longer inputs
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
  Check('TC2 Extract',
    ToHex(LPRK) = '06a6b88c5853361a06104c9ceb35b45cef760014904671014a193f40c15fc244');
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 82);
  Check('TC2 Expand length=82', Length(LOKM) = 82);
  Check('TC2 Expand prefix',
    Copy(ToHex(LOKM), 1, 32) = 'b11e398dc80327a1c8e7f78c596a4934');

  // TC3: Zero-length salt and info
  LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  SetLength(LSalt, 0);
  SetLength(LInfo, 0);
  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  Check('TC3 Extract (empty salt)',
    ToHex(LPRK) = '19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04');
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
  Check('TC3 Expand (empty info)',
    ToHex(LOKM) = '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8');
end;

procedure TestConvenienceFunctions;
var
  LIKM, LSalt, LInfo, LPRK1, LPRK2, LOKM1, LOKM2: TBytes;
begin
  WriteLn('--- Convenience functions ---');

  LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSalt := HexToBytes('000102030405060708090a0b0c');
  LInfo := HexToBytes('f0f1f2f3f4f5f6f7f8f9');

  // HKDF_Extract_SHA256 vs HKDF_ExtractBytes
  LPRK1 := HKDF_Extract_SHA256(LSalt, LIKM);
  LPRK2 := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  Check('HKDF_Extract_SHA256 == ExtractBytes', CompareMem(@LPRK1[0], @LPRK2[0], Length(LPRK1)));

  // HKDF_Expand_SHA256 vs HKDF_ExpandBytes
  LOKM1 := HKDF_Expand_SHA256(LPRK1, LInfo, 42);
  LOKM2 := HKDF_ExpandBytes(haSHA256, LPRK1, LInfo, 42);
  Check('HKDF_Expand_SHA256 == ExpandBytes', CompareMem(@LOKM1[0], @LOKM2[0], 42));
end;

procedure TestEdgeCases;
var
  LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
begin
  WriteLn('--- Edge cases ---');

  // Empty IKM
  SetLength(LIKM, 0);
  LSalt := HexToBytes('000102030405060708090a0b0c');
  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  Check('Empty IKM: PRK length=32', Length(LPRK) = 32);

  // OKM length = 1
  SetLength(LInfo, 0);
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 1);
  Check('OKM length=1', Length(LOKM) = 1);

  // OKM length = 32 (exactly one hash block)
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 32);
  Check('OKM length=32', Length(LOKM) = 32);

  // OKM length = 64 (two hash blocks)
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 64);
  Check('OKM length=64', Length(LOKM) = 64);

  // Low-level API: HKDF_ExtractBytes + HKDF_ExpandBytes with same data as TC1
  LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSalt := HexToBytes('000102030405060708090a0b0c');
  LInfo := HexToBytes('f0f1f2f3f4f5f6f7f8f9');
  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  Check('ExtractBytes = TC1',
    ToHex(LPRK) = '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5');
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
  Check('ExpandBytes = TC1',
    ToHex(LOKM) = '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865');
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== HKDF Tests (Enhanced) ===');
  WriteLn;

  TestRFC5869_SHA256;
  TestConvenienceFunctions;
  TestEdgeCases;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
