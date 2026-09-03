program test_comprehensive;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256,
  nextpas.core.hash.sha512,
  nextpas.core.hash,
  nextpas.core.test;

function ToHex(const ABuf; ALen: Integer): string;
var
  I: Integer;
  P: PByte;
begin
  Result := '';
  P := @ABuf;
  for I := 0 to ALen - 1 do
    Result := Result + LowerCase(IntToHex(P[I], 2));
end;

procedure TestSHA256MillionA;
var
  LH: IHasher;
  LD: TSHA256Digest;
  I: Integer;
  LBlock: array[0..999] of Byte;
begin
  FillChar(LBlock[0], 1000, Ord('a'));
  LH := NewSHA256;
  for I := 1 to 1000 do
    LH.Write(LBlock[0], 1000);
  LH.Sum(LD, 32);
  CheckEqual('cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0',
    ToHex(LD, 32));
end;

procedure TestSHA512Full;
var
  LH: IHasher;
  LD: TSHA512Digest;
  LData: AnsiString;
begin
  LH := NewSHA512; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 64);
  CheckEqual('ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f',
    ToHex(LD, 64));
end;

procedure TestSHA384Full;
var
  LH: IHasher;
  LD: TSHA384Digest;
  LData: AnsiString;
begin
  LH := NewSHA384; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 48);
  CheckEqual('cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7',
    ToHex(LD, 48));
end;

procedure TestBlockBoundary;
var
  LH1, LH2: IHasher;
  LD1, LD2: TSHA256Digest;
  LBuf: array[0..127] of Byte;
  I: Integer;
begin
  FillChar(LBuf[0], 128, $42);
  LH1 := NewSHA256; LH1.Write(LBuf[0], 64); LH1.Sum(LD1, 32);
  LH2 := NewSHA256;
  for I := 0 to 63 do LH2.Write(LBuf[I], 1);
  LH2.Sum(LD2, 32);
  CheckTrue(CompareMem(@LD1[0], @LD2[0], 32),
    '64 bytes one-shot == byte-by-byte');

  LH1 := NewSHA256; LH1.Write(LBuf[0], 63); LH1.Sum(LD1, 32);
  LH2 := NewSHA256; LH2.Write(LBuf[0], 32); LH2.Write(LBuf[32], 31); LH2.Sum(LD2, 32);
  CheckTrue(CompareMem(@LD1[0], @LD2[0], 32),
    '63 bytes split');

  LH1 := NewSHA256; LH1.Write(LBuf[0], 65); LH1.Sum(LD1, 32);
  LH2 := NewSHA256; LH2.Write(LBuf[0], 1); LH2.Write(LBuf[1], 64); LH2.Sum(LD2, 32);
  CheckTrue(CompareMem(@LD1[0], @LD2[0], 32),
    '65 bytes split');

  LH1 := NewSHA256; LH1.Write(LBuf[0], 128); LH1.Sum(LD1, 32);
  LH2 := NewSHA256; LH2.Write(LBuf[0], 100); LH2.Write(LBuf[100], 28); LH2.Sum(LD2, 32);
  CheckTrue(CompareMem(@LD1[0], @LD2[0], 32),
    '128 bytes split at 100');
end;

procedure TestDigestToHex;
var
  LD: TSHA256Digest;
begin
  FillChar(LD[0], 32, 0);
  LD[0] := $AB; LD[31] := $CD;
  CheckEqual('ab000000000000000000000000000000000000000000000000000000000000cd',
    DigestToHex(LD, 32));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('comprehensive');
  LSuite.Test('SHA-256 million "a"', @TestSHA256MillionA);
  LSuite.Test('SHA-512 full', @TestSHA512Full);
  LSuite.Test('SHA-384 full', @TestSHA384Full);
  LSuite.Test('block boundary', @TestBlockBoundary);
  LSuite.Test('DigestToHex', @TestDigestToHex);
  LRunner := TSuiteRunner.Create('nextpas.core.hash.comprehensive');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
