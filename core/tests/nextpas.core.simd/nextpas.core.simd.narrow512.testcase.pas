unit nextpas.core.simd.narrow512.testcase;

{$I ../../src/nextpas.core.settings.inc}
{$R-}{$Q-}

interface

uses
  Classes, nextpas.core.text.conv, fpcunit, testregistry,
  nextpas.core.simd,
  nextpas.core.simd.base;

type
  TTestCase_Narrow512Ops = class(TTestCase)
  published
    procedure Test_VecI16x32_Add;
    procedure Test_VecI16x32_Sub;
    procedure Test_VecI16x32_And_Or_Xor;
    procedure Test_VecI16x32_ShiftLeft;
    procedure Test_VecI16x32_CmpEq;
    procedure Test_VecI16x32_MinMax;
    procedure Test_VecI8x64_Add;
    procedure Test_VecI8x64_Sub;
    procedure Test_VecI8x64_And_Or_Xor;
    procedure Test_VecI8x64_CmpEq;
    procedure Test_VecI8x64_MinMax;
    procedure Test_VecU32x16_Add;
    procedure Test_VecU32x16_Sub;
    procedure Test_VecU32x16_Mul;
    procedure Test_VecU32x16_ShiftLeft;
    procedure Test_VecU32x16_CmpEq;
    procedure Test_VecU32x16_MinMax;
    procedure Test_VecU64x8_Add;
    procedure Test_VecU64x8_Sub;
    procedure Test_VecU64x8_And_Or_Xor;
    procedure Test_VecU64x8_CmpEq;
    procedure Test_VecU8x64_Add;
    procedure Test_VecU8x64_Sub;
    procedure Test_VecU8x64_And_Or_Xor;
    procedure Test_VecU8x64_CmpEq;
    procedure Test_VecU8x64_MinMax;
  end;

implementation

// === I16x32 ===

procedure TTestCase_Narrow512Ops.Test_VecI16x32_Add;
var a, b, r: TVecI16x32; i: Integer;
begin
  for i := 0 to 31 do begin a.i[i] := i * 10; b.i[i] := i + 1; end;
  r := VecI16x32Add(a, b);
  for i := 0 to 31 do
    AssertEquals('I16x32 Add[' + IntToStr(i) + ']', i * 10 + i + 1, Integer(r.i[i]));
end;

procedure TTestCase_Narrow512Ops.Test_VecI16x32_Sub;
var a, b, r: TVecI16x32; i: Integer;
begin
  for i := 0 to 31 do begin a.i[i] := 100; b.i[i] := i; end;
  r := VecI16x32Sub(a, b);
  for i := 0 to 31 do
    AssertEquals('I16x32 Sub[' + IntToStr(i) + ']', 100 - i, Integer(r.i[i]));
end;

procedure TTestCase_Narrow512Ops.Test_VecI16x32_And_Or_Xor;
var a, b, r: TVecI16x32; i: Integer;
begin
  for i := 0 to 31 do begin a.i[i] := $FF; b.i[i] := $0F; end;
  r := VecI16x32And(a, b);
  AssertEquals('I16x32 And[0]', $0F, Integer(r.i[0]));
  r := VecI16x32Or(a, b);
  AssertEquals('I16x32 Or[0]', $FF, Integer(r.i[0]));
  r := VecI16x32Xor(a, b);
  AssertEquals('I16x32 Xor[0]', $F0, Integer(r.i[0]));
end;

procedure TTestCase_Narrow512Ops.Test_VecI16x32_ShiftLeft;
var a, r: TVecI16x32; i: Integer;
begin
  for i := 0 to 31 do a.i[i] := 1;
  r := VecI16x32ShiftLeft(a, 3);
  AssertEquals('I16x32 SHL[0]', 8, Integer(r.i[0]));
  AssertEquals('I16x32 SHL[31]', 8, Integer(r.i[31]));
end;

procedure TTestCase_Narrow512Ops.Test_VecI16x32_CmpEq;
var a, b: TVecI16x32; m: TMask32; i: Integer;
begin
  for i := 0 to 31 do begin a.i[i] := i; b.i[i] := i; end;
  b.i[0] := 999;
  b.i[15] := 999;
  m := VecI16x32CmpEq(a, b);
  AssertFalse('I16x32 CmpEq[0] should differ', (m and 1) <> 0);
  AssertTrue('I16x32 CmpEq[1] should match', (m and 2) <> 0);
  AssertFalse('I16x32 CmpEq[15] should differ', (m and (1 shl 15)) <> 0);
end;

procedure TTestCase_Narrow512Ops.Test_VecI16x32_MinMax;
var a, b, r: TVecI16x32; i: Integer;
begin
  for i := 0 to 31 do begin a.i[i] := 10; b.i[i] := 20; end;
  a.i[0] := 30;
  r := VecI16x32Min(a, b);
  AssertEquals('I16x32 Min[0]', 20, Integer(r.i[0]));
  AssertEquals('I16x32 Min[1]', 10, Integer(r.i[1]));
  r := VecI16x32Max(a, b);
  AssertEquals('I16x32 Max[0]', 30, Integer(r.i[0]));
  AssertEquals('I16x32 Max[1]', 20, Integer(r.i[1]));
end;

// === I8x64 ===

procedure TTestCase_Narrow512Ops.Test_VecI8x64_Add;
var a, b, r: TVecI8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.i[i] := i; b.i[i] := 1; end;
  r := VecI8x64Add(a, b);
  for i := 0 to 63 do
    AssertEquals('I8x64 Add[' + IntToStr(i) + ']', Int8(i + 1), r.i[i]);
end;

procedure TTestCase_Narrow512Ops.Test_VecI8x64_Sub;
var a, b, r: TVecI8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.i[i] := 50; b.i[i] := i; end;
  r := VecI8x64Sub(a, b);
  for i := 0 to 63 do
    AssertEquals('I8x64 Sub[' + IntToStr(i) + ']', Int8(50 - i), r.i[i]);
end;

procedure TTestCase_Narrow512Ops.Test_VecI8x64_And_Or_Xor;
var a, b, r: TVecI8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.i[i] := Int8($7F); b.i[i] := Int8($0F); end;
  r := VecI8x64And(a, b);
  AssertEquals('I8x64 And[0]', Int8($0F), r.i[0]);
  r := VecI8x64Or(a, b);
  AssertEquals('I8x64 Or[0]', Int8($7F), r.i[0]);
  r := VecI8x64Xor(a, b);
  AssertEquals('I8x64 Xor[0]', Int8($70), r.i[0]);
end;

procedure TTestCase_Narrow512Ops.Test_VecI8x64_CmpEq;
var a, b: TVecI8x64; m: TMask64; i: Integer;
begin
  for i := 0 to 63 do begin a.i[i] := i; b.i[i] := i; end;
  b.i[0] := 127;
  b.i[32] := 127;
  m := VecI8x64CmpEq(a, b);
  AssertFalse('I8x64 CmpEq[0]', (m and 1) <> 0);
  AssertTrue('I8x64 CmpEq[1]', (m and 2) <> 0);
  AssertFalse('I8x64 CmpEq[32]', (m and (QWord(1) shl 32)) <> 0);
end;

procedure TTestCase_Narrow512Ops.Test_VecI8x64_MinMax;
var a, b, r: TVecI8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.i[i] := 5; b.i[i] := 10; end;
  a.i[0] := 20;
  r := VecI8x64Min(a, b);
  AssertEquals('I8x64 Min[0]', Int8(10), r.i[0]);
  AssertEquals('I8x64 Min[1]', Int8(5), r.i[1]);
  r := VecI8x64Max(a, b);
  AssertEquals('I8x64 Max[0]', Int8(20), r.i[0]);
  AssertEquals('I8x64 Max[1]', Int8(10), r.i[1]);
end;

// === U32x16 ===

procedure TTestCase_Narrow512Ops.Test_VecU32x16_Add;
var a, b, r: TVecU32x16; i: Integer;
begin
  for i := 0 to 15 do begin a.u[i] := i * 100; b.u[i] := i + 1; end;
  r := VecU32x16Add(a, b);
  for i := 0 to 15 do
    AssertEquals('U32x16 Add[' + IntToStr(i) + ']', Integer(i * 100 + i + 1), Integer(r.u[i]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU32x16_Sub;
var a, b, r: TVecU32x16; i: Integer;
begin
  for i := 0 to 15 do begin a.u[i] := 1000; b.u[i] := i * 10; end;
  r := VecU32x16Sub(a, b);
  for i := 0 to 15 do
    AssertEquals('U32x16 Sub[' + IntToStr(i) + ']', Integer(1000 - i * 10), Integer(r.u[i]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU32x16_Mul;
var a, b, r: TVecU32x16; i: Integer;
begin
  for i := 0 to 15 do begin a.u[i] := 3; b.u[i] := 7; end;
  r := VecU32x16Mul(a, b);
  AssertEquals('U32x16 Mul[0]', 21, Integer(r.u[0]));
  AssertEquals('U32x16 Mul[15]', 21, Integer(r.u[15]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU32x16_ShiftLeft;
var a, r: TVecU32x16; i: Integer;
begin
  for i := 0 to 15 do a.u[i] := 1;
  r := VecU32x16ShiftLeft(a, 4);
  AssertEquals('U32x16 SHL[0]', 16, Integer(r.u[0]));
  AssertEquals('U32x16 SHL[15]', 16, Integer(r.u[15]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU32x16_CmpEq;
var a, b: TVecU32x16; m: TMask16; i: Integer;
begin
  for i := 0 to 15 do begin a.u[i] := i; b.u[i] := i; end;
  b.u[0] := 999;
  b.u[8] := 999;
  m := VecU32x16CmpEq(a, b);
  AssertFalse('U32x16 CmpEq[0]', (m and 1) <> 0);
  AssertTrue('U32x16 CmpEq[1]', (m and 2) <> 0);
  AssertFalse('U32x16 CmpEq[8]', (m and (1 shl 8)) <> 0);
end;

procedure TTestCase_Narrow512Ops.Test_VecU32x16_MinMax;
var a, b, r: TVecU32x16; i: Integer;
begin
  for i := 0 to 15 do begin a.u[i] := 50; b.u[i] := 100; end;
  a.u[0] := 200;
  r := VecU32x16Min(a, b);
  AssertEquals('U32x16 Min[0]', 100, Integer(r.u[0]));
  AssertEquals('U32x16 Min[1]', 50, Integer(r.u[1]));
  r := VecU32x16Max(a, b);
  AssertEquals('U32x16 Max[0]', 200, Integer(r.u[0]));
  AssertEquals('U32x16 Max[1]', 100, Integer(r.u[1]));
end;

// === U64x8 ===

procedure TTestCase_Narrow512Ops.Test_VecU64x8_Add;
var a, b, r: TVecU64x8; i: Integer;
begin
  for i := 0 to 7 do begin a.u[i] := i * 1000; b.u[i] := i + 1; end;
  r := VecU64x8Add(a, b);
  for i := 0 to 7 do
    AssertEquals('U64x8 Add[' + IntToStr(i) + ']', Int64(i * 1000 + i + 1), Int64(r.u[i]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU64x8_Sub;
var a, b, r: TVecU64x8; i: Integer;
begin
  for i := 0 to 7 do begin a.u[i] := 10000; b.u[i] := i * 100; end;
  r := VecU64x8Sub(a, b);
  for i := 0 to 7 do
    AssertEquals('U64x8 Sub[' + IntToStr(i) + ']', Int64(10000 - i * 100), Int64(r.u[i]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU64x8_And_Or_Xor;
var a, b, r: TVecU64x8; i: Integer;
begin
  for i := 0 to 7 do begin a.u[i] := $FF00; b.u[i] := $0FF0; end;
  r := VecU64x8And(a, b);
  AssertEquals('U64x8 And[0]', Int64($0F00), Int64(r.u[0]));
  r := VecU64x8Or(a, b);
  AssertEquals('U64x8 Or[0]', Int64($FFF0), Int64(r.u[0]));
  r := VecU64x8Xor(a, b);
  AssertEquals('U64x8 Xor[0]', Int64($F0F0), Int64(r.u[0]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU64x8_CmpEq;
var a, b: TVecU64x8; m: TMask8; i: Integer;
begin
  for i := 0 to 7 do begin a.u[i] := i; b.u[i] := i; end;
  b.u[0] := 999;
  b.u[4] := 999;
  m := VecU64x8CmpEq(a, b);
  AssertFalse('U64x8 CmpEq[0]', (m and 1) <> 0);
  AssertTrue('U64x8 CmpEq[1]', (m and 2) <> 0);
  AssertFalse('U64x8 CmpEq[4]', (m and (1 shl 4)) <> 0);
end;

// === U8x64 ===

procedure TTestCase_Narrow512Ops.Test_VecU8x64_Add;
var a, b, r: TVecU8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.u[i] := i; b.u[i] := 1; end;
  r := VecU8x64Add(a, b);
  for i := 0 to 63 do
    AssertEquals('U8x64 Add[' + IntToStr(i) + ']', Byte(i + 1), r.u[i]);
end;

procedure TTestCase_Narrow512Ops.Test_VecU8x64_Sub;
var a, b, r: TVecU8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.u[i] := 100; b.u[i] := i; end;
  r := VecU8x64Sub(a, b);
  for i := 0 to 63 do
    AssertEquals('U8x64 Sub[' + IntToStr(i) + ']', Byte(100 - i), r.u[i]);
end;

procedure TTestCase_Narrow512Ops.Test_VecU8x64_And_Or_Xor;
var a, b, r: TVecU8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.u[i] := $F0; b.u[i] := $0F; end;
  r := VecU8x64And(a, b);
  AssertEquals('U8x64 And[0]', 0, Integer(r.u[0]));
  r := VecU8x64Or(a, b);
  AssertEquals('U8x64 Or[0]', $FF, Integer(r.u[0]));
  r := VecU8x64Xor(a, b);
  AssertEquals('U8x64 Xor[0]', $FF, Integer(r.u[0]));
end;

procedure TTestCase_Narrow512Ops.Test_VecU8x64_CmpEq;
var a, b: TVecU8x64; m: TMask64; i: Integer;
begin
  for i := 0 to 63 do begin a.u[i] := i; b.u[i] := i; end;
  b.u[0] := 255;
  b.u[32] := 255;
  m := VecU8x64CmpEq(a, b);
  AssertFalse('U8x64 CmpEq[0]', (m and 1) <> 0);
  AssertTrue('U8x64 CmpEq[1]', (m and 2) <> 0);
  AssertFalse('U8x64 CmpEq[32]', (m and (QWord(1) shl 32)) <> 0);
end;

procedure TTestCase_Narrow512Ops.Test_VecU8x64_MinMax;
var a, b, r: TVecU8x64; i: Integer;
begin
  for i := 0 to 63 do begin a.u[i] := 50; b.u[i] := 100; end;
  a.u[0] := 200;
  r := VecU8x64Min(a, b);
  AssertEquals('U8x64 Min[0]', 100, Integer(r.u[0]));
  AssertEquals('U8x64 Min[1]', 50, Integer(r.u[1]));
  r := VecU8x64Max(a, b);
  AssertEquals('U8x64 Max[0]', 200, Integer(r.u[0]));
  AssertEquals('U8x64 Max[1]', 100, Integer(r.u[1]));
end;

initialization
  RegisterTest(TTestCase_Narrow512Ops);

end.