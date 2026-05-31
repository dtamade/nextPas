program test_sha1;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.hash.intf, nextpas.core.hash.sha1;
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
var
  LH: IHasher; LD, LD2: TSHA1Digest; LData: AnsiString; I: Integer;
begin
  WriteLn('=== nextpas.core.hash.sha1 unit tests ===');

  // FIPS 180-4 test vectors
  LH := NewSHA1; LH.Sum(LD, 20);
  Check('SHA-1("") = da39a3ee5e6b...',
    ToHex(LD, 20) = 'da39a3ee5e6b4b0d3255bfef95601890afd80709');

  LH := NewSHA1; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 20);
  Check('SHA-1("abc") = a9993e36...',
    ToHex(LD, 20) = 'a9993e364706816aba3e25717850c26c9cd0d89d');

  LH := NewSHA1;
  LData := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
  LH.Write(LData[1], Length(LData)); LH.Sum(LD, 20);
  Check('SHA-1(448-bit) = 84983e44...',
    ToHex(LD, 20) = '84983e441c3bd26ebaae4aa1f95129e5e54670f1');

  // Incremental
  LData := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
  LH := NewSHA1; LH.Write(LData[1], Length(LData)); LH.Sum(LD, 20);
  LH := NewSHA1;
  for I := 1 to Length(LData) do LH.Write(LData[I], 1);
  LH.Sum(LD2, 20);
  Check('Incremental == one-shot', CompareMem(@LD[0], @LD2[0], 20));

  // Sum idempotent
  LH := NewSHA1; LData := 'x'; LH.Write(LData[1], 1);
  LH.Sum(LD, 20); LH.Sum(LD2, 20);
  Check('Sum idempotent', CompareMem(@LD[0], @LD2[0], 20));

  // Reset
  LH := NewSHA1; LH.Write(LData[1], 1); LH.Reset; LH.Sum(LD, 20);
  LH := NewSHA1; LH.Sum(LD2, 20);
  Check('Reset', CompareMem(@LD[0], @LD2[0], 20));

  // Metadata
  LH := NewSHA1;
  Check('DigestSize=20', LH.DigestSize = 20);
  Check('BlockSize=64', LH.BlockSize = 64);

  WriteLn; WriteLn('Results: ', GPass, ' passed');
end.
