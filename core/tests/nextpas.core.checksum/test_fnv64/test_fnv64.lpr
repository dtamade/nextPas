program test_fnv64;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.checksum.fnv64,
  nextpas.core.test;

const
  VHELLO = 'hello';
  VA = 'a';
  VFOO = 'foobar';

{ IETF / Go hash/fnv64a 标准向量 + 增量语义 + hex 便捷封装 }

procedure TestStandardVectors;
var
  S: AnsiString;
begin
  S := VHELLO;
  Check(Fnv1a64Of(S[1], Length(S)) = QWord($A430D84680AABD0B), 'vector hello');
  S := VA;
  Check(Fnv1a64Of(S[1], Length(S)) = QWord($AF63DC4C8601EC8C), 'vector a');
  S := VFOO;
  Check(Fnv1a64Of(S[1], Length(S)) = QWord($85944171F73967E8), 'vector foobar');
end;

procedure TestEmpty;
begin
  Check(Fnv1a64Of(VHELLO[1], 0) = FNV1A64_OFFSET, 'empty is offset');
  Check(Fnv1a64Update(FNV1A64_OFFSET, nil, 0) = FNV1A64_OFFSET,
    'update nil zero');
  Check(Fnv1a64OfBytes(nil) = FNV1A64_OFFSET, 'bytes nil is offset');
  Check(Fnv1a64HexStr('') = 'cbf29ce484222325', 'hex empty is offset');
end;

procedure TestIncremental;
var
  C: QWord;
  I: Integer;
  S: AnsiString;
begin
  S := VHELLO;
  C := FNV1A64_OFFSET;
  for I := 1 to Length(S) do
    C := Fnv1a64Update(C, @S[I], 1);
  Check(C = QWord($A430D84680AABD0B), 'incremental per byte');
  C := Fnv1a64Update(FNV1A64_OFFSET, @S[1], 2);
  C := Fnv1a64Update(C, @S[3], 3);
  Check(C = QWord($A430D84680AABD0B), 'incremental two chunks');
end;

procedure TestBytes;
var
  B: TBytes;
begin
  B := TBytes.Create(Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
  Check(Fnv1a64OfBytes(B) = QWord($A430D84680AABD0B), 'bytes vector');
end;

procedure TestHex;
var
  S: AnsiString;
begin
  S := VHELLO;
  Check(Fnv1a64HexOf(S[1], Length(S)) = 'a430d84680aabd0b', 'hex hello');
  Check(Fnv1a64HexStr(VHELLO) = 'a430d84680aabd0b', 'hexstr hello');
  Check(Fnv1a64HexStr(VA) = 'af63dc4c8601ec8c', 'hexstr a');
  Check(Fnv1a64HexStr(VFOO) = '85944171f73967e8', 'hexstr foobar');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.checksum.fnv64');
  T.Test('standard vectors', @TestStandardVectors);
  T.Test('empty input', @TestEmpty);
  T.Test('incremental equals one-shot', @TestIncremental);
  T.Test('bytes helper', @TestBytes);
  T.Test('hex helpers', @TestHex);
  if not T.Run then Halt(1);
end.
