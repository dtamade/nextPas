program test_comprehensive;
{$mode objfpc}{$H+}
uses SysUtils, nextpas.core.hash.base, nextpas.core.hash.intf,
  nextpas.core.hash.sha256, nextpas.core.hash.sha512,
  nextpas.core.crypto.hmac, nextpas.core.crypto.hkdf, nextpas.core.hash;
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
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

procedure TestSHA256MillionA;
var LH: IHasher; LD: TSHA256Digest; I: Integer;
  LBlock: array[0..999] of Byte;
begin
  FillChar(LBlock[0], 1000, Ord('a'));
  LH := NewSHA256;
  for I := 1 to 1000 do
    LH.Write(LBlock[0], 1000);
  LH.Sum(LD, 32);
  Check('SHA-256(1M "a") = cdc76e5c...',
    ToHex(LD, 32) = 'cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0');
end;

procedure TestSHA512Full;
var LH: IHasher; LD: TSHA512Digest; LData: AnsiString;
begin
  LH := NewSHA512; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 64);
  Check('SHA-512("abc") full',
    ToHex(LD, 64) = 'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f');
end;

procedure TestSHA384Full;
var LH: IHasher; LD: TSHA384Digest; LData: AnsiString;
begin
  LH := NewSHA384; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 48);
  Check('SHA-384("abc") full',
    ToHex(LD, 48) = 'cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7');
end;

procedure TestBlockBoundary;
var LH1, LH2: IHasher; LD1, LD2: TSHA256Digest;
  LBuf: array[0..127] of Byte; I: Integer;
begin
  FillChar(LBuf[0], 128, $42);
  // Exactly 1 block (64 bytes)
  LH1 := NewSHA256; LH1.Write(LBuf[0], 64); LH1.Sum(LD1, 32);
  LH2 := NewSHA256;
  for I := 0 to 63 do LH2.Write(LBuf[I], 1);
  LH2.Sum(LD2, 32);
  Check('Block boundary: 64 bytes one-shot == byte-by-byte', CompareMem(@LD1[0], @LD2[0], 32));

  // block-1 (63 bytes)
  LH1 := NewSHA256; LH1.Write(LBuf[0], 63); LH1.Sum(LD1, 32);
  LH2 := NewSHA256; LH2.Write(LBuf[0], 32); LH2.Write(LBuf[32], 31); LH2.Sum(LD2, 32);
  Check('Block boundary: 63 bytes split', CompareMem(@LD1[0], @LD2[0], 32));

  // block+1 (65 bytes)
  LH1 := NewSHA256; LH1.Write(LBuf[0], 65); LH1.Sum(LD1, 32);
  LH2 := NewSHA256; LH2.Write(LBuf[0], 1); LH2.Write(LBuf[1], 64); LH2.Sum(LD2, 32);
  Check('Block boundary: 65 bytes split', CompareMem(@LD1[0], @LD2[0], 32));

  // 2 blocks (128 bytes)
  LH1 := NewSHA256; LH1.Write(LBuf[0], 128); LH1.Sum(LD1, 32);
  LH2 := NewSHA256; LH2.Write(LBuf[0], 100); LH2.Write(LBuf[100], 28); LH2.Sum(LD2, 32);
  Check('Block boundary: 128 bytes split at 100', CompareMem(@LD1[0], @LD2[0], 32));
end;

procedure TestHMACLongKey;
var LKey, LData: TBytes; LD: TSHA256Digest;
begin
  // RFC 4231 Test Case 3: key longer than block size
  LKey := HexToBytes('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
  LData := HexToBytes('54657374205573696e67204c6172676572205468616e20426c6f636b2d53697a65204b6579202d2048617368204b6579204669727374');
  LD := HmacSHA256(LKey, LData);
  Check('HMAC-SHA256 long key (RFC4231 TC6)',
    ToHex(LD, 32) = '60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54');
end;

procedure TestHMACsha384;
var LKey, LData: TBytes; LD: TSHA384Digest;
begin
  LKey := HexToBytes('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b');
  LData := TEncoding.UTF8.GetBytes(UnicodeString('Hi There'));
  LD := HmacSHA384(LKey, LData);
  Check('HMAC-SHA384 RFC4231 TC1',
    Copy(ToHex(LD, 48), 1, 16) = 'afd03944d8489562');
end;

procedure TestHKDFTC2;
var LIKM, LSalt, LInfo, LPRK, LOKM: TBytes;
begin
  // RFC 5869 Test Case 2 (long inputs)
  LIKM := HexToBytes('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f');
  LSalt := HexToBytes('606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeaf');
  LInfo := HexToBytes('b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff');
  LPRK := HKDF_ExtractBytes(haSHA256, LSalt, LIKM);
  Check('HKDF TC2 Extract',
    ToHex(LPRK[0], Length(LPRK)) = '06a6b88c5853361a06104c9ceb35b45cef760014904671014a193f40c15fc244');
  LOKM := HKDF_ExpandBytes(haSHA256, LPRK, LInfo, 82);
  Check('HKDF TC2 Expand (82 bytes)',
    Copy(ToHex(LOKM[0], Length(LOKM)), 1, 32) = 'b11e398dc80327a1c8e7f78c596a4934');
end;

procedure TestDigestToHex;
var LD: TSHA256Digest;
begin
  FillChar(LD[0], 32, 0);
  LD[0] := $AB; LD[31] := $CD;
  Check('DigestToHex', DigestToHex(LD, 32) = 'ab000000000000000000000000000000000000000000000000000000000000cd');
end;

begin
  WriteLn('=== Comprehensive hash/crypto tests ===');
  TestSHA256MillionA;
  TestSHA512Full;
  TestSHA384Full;
  TestBlockBoundary;
  TestHMACLongKey;
  TestHMACsha384;
  TestHKDFTC2;
  TestDigestToHex;
  WriteLn; WriteLn('Results: ', GPass, ' passed');
end.
