program test_md5;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.hash.intf, nextpas.core.hash.md5;
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
  LH: IHasher; LD, LD2: TMD5Digest; LData: AnsiString; I: Integer;
begin
  WriteLn('=== nextpas.core.hash.md5 unit tests ===');

  // RFC 1321 test vectors
  LH := NewMD5; LH.Sum(LD, 16);
  Check('MD5("") = d41d8cd9...', ToHex(LD, 16) = 'd41d8cd98f00b204e9800998ecf8427e');

  LH := NewMD5; LData := 'a'; LH.Write(LData[1], 1); LH.Sum(LD, 16);
  Check('MD5("a") = 0cc175b9...', ToHex(LD, 16) = '0cc175b9c0f1b6a831c399e269772661');

  LH := NewMD5; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 16);
  Check('MD5("abc") = 900150983cd24fb0...', ToHex(LD, 16) = '900150983cd24fb0d6963f7d28e17f72');

  LH := NewMD5; LData := 'message digest'; LH.Write(LData[1], Length(LData)); LH.Sum(LD, 16);
  Check('MD5("message digest")', ToHex(LD, 16) = 'f96b697d7cb7938d525a2f31aaf161d0');

  // Incremental == one-shot
  LData := 'abcdefghijklmnopqrstuvwxyz';
  LH := NewMD5; LH.Write(LData[1], Length(LData)); LH.Sum(LD, 16);
  LH := NewMD5;
  for I := 1 to Length(LData) do LH.Write(LData[I], 1);
  LH.Sum(LD2, 16);
  Check('Incremental == one-shot', CompareMem(@LD[0], @LD2[0], 16));

  // Sum does not mutate
  LH := NewMD5; LData := 'test'; LH.Write(LData[1], 4);
  LH.Sum(LD, 16); LH.Sum(LD2, 16);
  Check('Sum idempotent', CompareMem(@LD[0], @LD2[0], 16));

  // Reset
  LH := NewMD5; LH.Write(LData[1], 4); LH.Reset; LH.Sum(LD, 16);
  LH := NewMD5; LH.Sum(LD2, 16);
  Check('Reset returns to initial', CompareMem(@LD[0], @LD2[0], 16));

  // Metadata
  LH := NewMD5;
  Check('DigestSize=16', LH.DigestSize = 16);
  Check('BlockSize=64', LH.BlockSize = 64);

  WriteLn; WriteLn('Results: ', GPass, ' passed');
end.
