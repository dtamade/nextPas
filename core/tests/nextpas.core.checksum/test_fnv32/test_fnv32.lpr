program test_fnv32;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.checksum.fnv32,
  nextpas.core.test;

const
  VHELLO = 'hello';
  VA = 'a';
  VFOO = 'foobar';

{ IETF / Go hash/fnv 标准向量 + 增量语义 + 便捷封装 }

procedure TestStandardVectors;
var
  S: AnsiString;
begin
  S := VHELLO;
  Check(Fnv1a32Of(S[1], Length(S)) = $4F9F2CAB, 'vector hello');
  S := VA;
  Check(Fnv1a32Of(S[1], Length(S)) = $E40C292C, 'vector a');
  S := VFOO;
  Check(Fnv1a32Of(S[1], Length(S)) = $BF9CF968, 'vector foobar');
end;

procedure TestEmpty;
begin
  Check(Fnv1a32Of(VHELLO[1], 0) = FNV1A32_OFFSET, 'empty is offset');
  Check(Fnv1a32Update(FNV1A32_OFFSET, nil, 0) = FNV1A32_OFFSET,
    'update nil zero');
  Check(Fnv1a32OfBytes(nil) = FNV1A32_OFFSET, 'bytes nil is offset');
end;

procedure TestIncremental;
var
  C: LongWord;
  I: Integer;
  S: AnsiString;
begin
  S := VHELLO;
  C := FNV1A32_OFFSET;
  for I := 1 to Length(S) do
    C := Fnv1a32Update(C, @S[I], 1);
  Check(C = $4F9F2CAB, 'incremental per byte');
  C := Fnv1a32Update(FNV1A32_OFFSET, @S[1], 2);
  C := Fnv1a32Update(C, @S[3], 3);
  Check(C = $4F9F2CAB, 'incremental two chunks');
end;

procedure TestBytes;
var
  B: TBytes;
begin
  B := TBytes.Create(Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
  Check(Fnv1a32OfBytes(B) = $4F9F2CAB, 'bytes vector');
end;

procedure TestMatchesHashBytes;
var
  S: AnsiString;
begin
  S := VHELLO;
  Check(Fnv1a32Of(S[1], Length(S)) = HashBytes(@S[1], Length(S)),
    'checksum FNV-1a matches HashBytes');
  Check(Fnv1a32OfBytes(nil) = HashBytes(nil, 0),
    'empty checksum FNV-1a matches HashBytes');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.checksum.fnv32');
  T.Test('standard vectors', @TestStandardVectors);
  T.Test('empty input', @TestEmpty);
  T.Test('incremental equals one-shot', @TestIncremental);
  T.Test('bytes helper', @TestBytes);
  T.Test('agrees with HashBytes', @TestMatchesHashBytes);
  if not T.Run then Halt(1);
end.
