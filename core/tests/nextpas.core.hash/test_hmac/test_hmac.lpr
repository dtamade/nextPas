program test_hmac;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.hash.intf, nextpas.core.crypto.hmac;
var GPass: Integer = 0;
procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then begin Inc(GPass); WriteLn('  [PASS] ', AName); end
  else begin WriteLn('  [FAIL] ', AName); Halt(1); end;
end;
function ToHex(const ABuf; ALen: Integer): string;
var I: Integer; P: PByte;
begin Result := ''; P := @ABuf;
  for I := 0 to ALen-1 do Result := Result + LowerCase(IntToHex(P[I], 2));
end;
function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;
var
  LKey, LData: TBytes;
  LD256: TSHA256Digest;
  LH: IHasher;
  LD2: TSHA256Digest;
begin
  WriteLn('=== nextpas.core.crypto.hmac unit tests ===');

  // RFC 4231 Test Case 1: HMAC-SHA-256
  LKey := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LData := TEncoding.UTF8.GetBytes(UnicodeString('Hi There'));
  LD256 := HmacSHA256(LKey, LData);
  Check('RFC4231 TC1 HMAC-SHA256',
    ToHex(LD256, 32) = 'b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7');

  // RFC 4231 Test Case 2: HMAC-SHA-256 (key = "Jefe")
  LKey := TEncoding.UTF8.GetBytes(UnicodeString('Jefe'));
  LData := TEncoding.UTF8.GetBytes(UnicodeString('what do ya want for nothing?'));
  LD256 := HmacSHA256(LKey, LData);
  Check('RFC4231 TC2 HMAC-SHA256',
    ToHex(LD256, 32) = '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843');

  // Sum idempotent
  LH := NewHMAC(haSHA256, LKey[0], Length(LKey));
  LH.Write(LData[0], Length(LData));
  LH.Sum(LD256, 32);
  LH.Sum(LD2, 32);
  Check('HMAC Sum idempotent', CompareMem(@LD256[0], @LD2[0], 32));

  // Sum then Write gives different result
  LH.Write(LData[0], 1);
  LH.Sum(LD2, 32);
  Check('HMAC Sum+Write gives different', not CompareMem(@LD256[0], @LD2[0], 32));

  // Reset
  LH := NewHMAC(haSHA256, LKey[0], Length(LKey));
  LH.Write(LData[0], Length(LData));
  LH.Sum(LD256, 32);
  LH.Reset;
  LH.Write(LData[0], Length(LData));
  LH.Sum(LD2, 32);
  Check('HMAC Reset + same data = same result', CompareMem(@LD256[0], @LD2[0], 32));

  // Empty key
  SetLength(LKey, 0);
  LData := TEncoding.UTF8.GetBytes(UnicodeString('test'));
  LD256 := HmacSHA256(LKey, LData);
  Check('HMAC empty key does not crash', True);

  WriteLn; WriteLn('Results: ', GPass, ' passed');
end.
