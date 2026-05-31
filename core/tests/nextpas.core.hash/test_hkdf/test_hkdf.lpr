program test_hkdf;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.crypto.hkdf;
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
var LIKM, LSalt, LInfo, LPRK, LOKM: TBytes; LPass: Integer;
begin
  LPass := 0;
  WriteLn('=== HKDF RFC 5869 Test Vectors ===');

  // Test Case 1 (SHA-256)
  LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LSalt := HexToBytes('000102030405060708090a0b0c');
  LInfo := HexToBytes('f0f1f2f3f4f5f6f7f8f9');

  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  if ToHex(LPRK) = '077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5' then
  begin WriteLn('  [PASS] TC1 Extract'); Inc(LPass); end
  else begin WriteLn('  [FAIL] TC1 Extract: ', ToHex(LPRK)); Halt(1); end;

  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
  if ToHex(LOKM) = '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865' then
  begin WriteLn('  [PASS] TC1 Expand'); Inc(LPass); end
  else begin WriteLn('  [FAIL] TC1 Expand: ', ToHex(LOKM)); Halt(1); end;

  // Test Case 3 (SHA-256, zero-length salt and info)
  LIKM := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  SetLength(LSalt, 0);
  SetLength(LInfo, 0);
  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  if ToHex(LPRK) = '19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04' then
  begin WriteLn('  [PASS] TC3 Extract (empty salt)'); Inc(LPass); end
  else begin WriteLn('  [FAIL] TC3 Extract: ', ToHex(LPRK)); Halt(1); end;

  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 42);
  if ToHex(LOKM) = '8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8' then
  begin WriteLn('  [PASS] TC3 Expand (empty info)'); Inc(LPass); end
  else begin WriteLn('  [FAIL] TC3 Expand: ', ToHex(LOKM)); Halt(1); end;

  WriteLn; WriteLn('Results: ', LPass, ' passed');
end.
