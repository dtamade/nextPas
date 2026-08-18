program test_crc32;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.checksum.crc32,
  nextpas.core.test;

const
  V123 = '123456789';
  VA = 'a';
  VABC = 'abc';
  VFOX = 'The quick brown fox jumps over the lazy dog';

{ 标准向量校验 + 增量语义 + 便捷封装 }

procedure TestStandardVectors;
var
  S: AnsiString;
begin
  S := V123;
  Check(Crc32Of(S[1], Length(S)) = $CBF43926, 'vector 123456789');
  S := VA;
  Check(Crc32Of(S[1], Length(S)) = $E8B7BE43, 'vector a');
  S := VABC;
  Check(Crc32Of(S[1], Length(S)) = $352441C2, 'vector abc');
  S := VFOX;
  Check(Crc32Of(S[1], Length(S)) = $414FA339, 'vector fox dog');
end;

procedure TestEmpty;
begin
  Check(Crc32Of(V123[1], 0) = 0, 'empty zero');
  Check(Crc32Update(0, nil, 0) = 0, 'update nil zero');
end;

procedure TestIncremental;
var
  C: LongWord;
  I: Integer;
  S: AnsiString;
begin
  S := V123;
  C := 0;
  { 逐字节增量 = 一次性结果 }
  for I := 1 to Length(S) do
    C := Crc32Update(C, @S[I], 1);
  Check(C = $CBF43926, 'incremental per byte');
  { 两段式增量 }
  C := Crc32Update(0, @S[1], 4);
  C := Crc32Update(C, @S[5], 5);
  Check(C = $CBF43926, 'incremental two chunks');
end;

procedure TestBytes;
var
  B: TBytes;
begin
  B := TBytes.Create(Ord('1'), Ord('2'), Ord('3'), Ord('4'), Ord('5'),
    Ord('6'), Ord('7'), Ord('8'), Ord('9'));
  Check(Crc32OfBytes(B) = $CBF43926, 'bytes vector');
  Check(Crc32OfBytes(nil) = 0, 'bytes nil');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.checksum.crc32');
  T.Test('standard vectors', @TestStandardVectors);
  T.Test('empty input', @TestEmpty);
  T.Test('incremental equals one-shot', @TestIncremental);
  T.Test('bytes helper', @TestBytes);
  if not T.Run then Halt(1);
end.