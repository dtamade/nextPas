program test_api_coverage_wide_vectors;

{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  nextpas.core.text.conv,
  Math,
  nextpas.core.simd.base,
  nextpas.core.simd,
  nextpas.core.simd.api_coverage.support;

procedure TestF32x8ExtMath;
var
  a: TVecF32x8;
  b: TVecF32x8;
  c: TVecF32x8;
  r: TVecF32x8;
  i: Integer;
begin
  a := VecF32x8Make(1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5);
  r := VecF32x8Floor(a);
  Check(r.f[0] = 1.0, 'F32x8Floor[0]');
  Check(r.f[7] = 8.0, 'F32x8Floor[7]');
  r := VecF32x8Ceil(a);
  Check(r.f[0] = 2.0, 'F32x8Ceil[0]');
  Check(r.f[7] = 9.0, 'F32x8Ceil[7]');
  r := VecF32x8Round(a);
  Check(r.f[0] = 2.0, 'F32x8Round[0]');
  r := VecF32x8Trunc(a);
  Check(r.f[0] = 1.0, 'F32x8Trunc[0]');
  Check(r.f[7] = 8.0, 'F32x8Trunc[7]');
  a := VecF32x8Make(-5, 0, 5, 10, 15, 20, 25, 30);
  b := VecF32x8Splat(0);
  c := VecF32x8Splat(20);
  r := VecF32x8Clamp(a, b, c);
  Check(r.f[0] = 0, 'F32x8Clamp[-5]');
  Check(r.f[2] = 5, 'F32x8Clamp[5]');
  Check(r.f[7] = 20, 'F32x8Clamp[30]');
  a := VecF32x8Make(1, 2, 3, 4, 5, 6, 7, 8);
  b := VecF32x8Make(10, 20, 30, 40, 50, 60, 70, 80);
  c := VecF32x8Make(100, 200, 300, 400, 500, 600, 700, 800);
  r := VecF32x8Fma(a, b, c);
  Check(Abs(r.f[0] - 110) < 1e-4, 'F32x8Fma[0]');
  Check(Abs(r.f[7] - 1440) < 1e-1, 'F32x8Fma[7]');
  r := VecF32x8Load(PSingle(@a.f[0]));
  Check(r.f[0] = 1.0, 'F32x8Load');
  Check(r.f[7] = 8.0, 'F32x8Load[7]');
  r := VecF32x8Zero;
  for i := 0 to 7 do
    Check(r.f[i] = 0, 'F32x8Zero[' + IntToStr(i) + ']');
  r := VecF32x8Splat(3.14);
  for i := 0 to 7 do
    Check(Abs(r.f[i] - 3.14) < 1e-5, 'F32x8Splat[' + IntToStr(i) + ']');
  a := VecF32x8Make(1, 2, 3, 4, 5, 6, 7, 8);
  VecF32x8Store(PSingle(@b.f[0]), a);
  Check(b.f[0] = 1.0, 'F32x8Store[0]');
  Check(b.f[7] = 8.0, 'F32x8Store[7]');
end;

procedure TestF64x4ExtMath;
var
  a: TVecF64x4;
  b: TVecF64x4;
  c: TVecF64x4;
  r: TVecF64x4;
  i: Integer;
begin
  a := VecF64x4Make(1.5, 2.5, 3.5, 4.5);
  r := VecF64x4Floor(a);
  Check(r.d[0] = 1.0, 'F64x4Floor[0]');
  Check(r.d[3] = 4.0, 'F64x4Floor[3]');
  r := VecF64x4Ceil(a);
  Check(r.d[0] = 2.0, 'F64x4Ceil[0]');
  Check(r.d[3] = 5.0, 'F64x4Ceil[3]');
  r := VecF64x4Round(a);
  Check(r.d[0] = 2.0, 'F64x4Round[0]');
  r := VecF64x4Trunc(a);
  Check(r.d[0] = 1.0, 'F64x4Trunc[0]');
  Check(r.d[3] = 4.0, 'F64x4Trunc[3]');
  a := VecF64x4Make(-5, 5, 25, 50);
  b := VecF64x4Make(0, 0, 0, 0);
  c := VecF64x4Make(20, 20, 20, 20);
  r := VecF64x4Clamp(a, b, c);
  Check(r.d[0] = 0, 'F64x4Clamp[-5]');
  Check(r.d[1] = 5, 'F64x4Clamp[5]');
  Check(r.d[3] = 20, 'F64x4Clamp[50]');
  a := VecF64x4Make(1, 2, 3, 4);
  b := VecF64x4Make(10, 20, 30, 40);
  c := VecF64x4Make(100, 200, 300, 400);
  r := VecF64x4Fma(a, b, c);
  Check(Abs(r.d[0] - 110) < 1e-10, 'F64x4Fma[0]');
  Check(Abs(r.d[3] - 560) < 1e-10, 'F64x4Fma[3]');
  r := VecF64x4Load(PDouble(@a.d[0]));
  Check(r.d[0] = 1.0, 'F64x4Load');
  Check(r.d[3] = 4.0, 'F64x4Load[3]');
  r := VecF64x4Zero;
  for i := 0 to 3 do
    Check(r.d[i] = 0, 'F64x4Zero[' + IntToStr(i) + ']');
  r := VecF64x4Splat(2.718);
  for i := 0 to 3 do
    Check(Abs(r.d[i] - 2.718) < 1e-10, 'F64x4Splat[' + IntToStr(i) + ']');
  a := VecF64x4Make(10, 20, 30, 40);
  VecF64x4Store(PDouble(@b.d[0]), a);
  Check(b.d[0] = 10, 'F64x4Store[0]');
  Check(b.d[3] = 40, 'F64x4Store[3]');
end;

procedure TestF64x2Clamp;
var
  a: TVecF64x2;
  lo: TVecF64x2;
  hi: TVecF64x2;
  r: TVecF64x2;
begin
  a := VecF64x2Make(-10, 50);
  lo := VecF64x2Make(0, 0);
  hi := VecF64x2Make(20, 20);
  r := VecF64x2Clamp(a, lo, hi);
  Check(r.d[0] = 0, 'F64x2Clamp[-10]');
  Check(r.d[1] = 20, 'F64x2Clamp[50]');
end;

procedure TestNarrowCmpLeGeNe;
var
  a16: TVecI16x8;
  b16: TVecI16x8;
  au8: TVecU8x16;
  bu8: TVecU8x16;
  ai8: TVecI8x16;
  bi8: TVecI8x16;
  au16: TVecU16x8;
  bu16: TVecU16x8;
  m8: TMask8;
  m16: TMask16;
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    a16.i[i] := Int16(i);
    b16.i[i] := Int16(4);
  end;
  m8 := VecI16x8CmpLe(a16, b16);
  Check((m8 and $1F) = $1F, 'I16x8CmpLe 0..4<=4');
  Check((m8 and $20) = 0, 'I16x8CmpLe 5>4');
  m8 := VecI16x8CmpGe(a16, b16);
  Check((m8 and $10) <> 0, 'I16x8CmpGe 4>=4');
  Check((m8 and $01) = 0, 'I16x8CmpGe 0<4');
  m8 := VecI16x8CmpNe(a16, b16);
  Check((m8 and $10) = 0, 'I16x8CmpNe 4=4 → 0');
  Check((m8 and $01) <> 0, 'I16x8CmpNe 0<>4 → 1');

  for i := 0 to 15 do
  begin
    ai8.i[i] := Int8(i);
    bi8.i[i] := Int8(8);
  end;
  m16 := VecI8x16CmpLe(ai8, bi8);
  Check((m16 and $1FF) = $1FF, 'I8x16CmpLe 0..8<=8');
  m16 := VecI8x16CmpGe(ai8, bi8);
  Check((m16 and $100) <> 0, 'I8x16CmpGe 8>=8');
  m16 := VecI8x16CmpNe(ai8, bi8);
  Check((m16 and $100) = 0, 'I8x16CmpNe 8=8');

  for i := 0 to 15 do
  begin
    au8.u[i] := Byte(i);
    bu8.u[i] := Byte(8);
  end;
  m16 := VecU8x16CmpLe(au8, bu8);
  Check((m16 and $1FF) = $1FF, 'U8x16CmpLe 0..8<=8');
  m16 := VecU8x16CmpGe(au8, bu8);
  Check((m16 and $100) <> 0, 'U8x16CmpGe 8>=8');
  m16 := VecU8x16CmpNe(au8, bu8);
  Check((m16 and $100) = 0, 'U8x16CmpNe 8=8');

  for i := 0 to 7 do
  begin
    au16.u[i] := Word(i);
    bu16.u[i] := Word(4);
  end;
  m8 := VecU16x8CmpLe(au16, bu16);
  Check((m8 and $1F) = $1F, 'U16x8CmpLe 0..4<=4');
  m8 := VecU16x8CmpGe(au16, bu16);
  Check((m8 and $10) <> 0, 'U16x8CmpGe 4>=4');
  m8 := VecU16x8CmpNe(au16, bu16);
  Check((m8 and $10) = 0, 'U16x8CmpNe 4=4');
end;

procedure TestWideFloatVectorSecondSample;
var
  a32: TVecF32x8;
  b32: TVecF32x8;
  c32: TVecF32x8;
  r32: TVecF32x8;
  a64: TVecF64x4;
  b64: TVecF64x4;
  c64: TVecF64x4;
  r64: TVecF64x4;
  a2: TVecF64x2;
  lo2: TVecF64x2;
  hi2: TVecF64x2;
  r2: TVecF64x2;
  buf32: array[0..7] of Single;
  buf64: array[0..3] of Double;
begin
  a32 := VecF32x8Make(1.25, -1.25, 2.5, -2.5, 3.75, -3.75, 4.5, -4.5);
  b32 := VecF32x8Splat(-1.0);
  c32 := VecF32x8Splat(2.0);
  r32 := VecF32x8Floor(a32);
  CheckFloat(r32.f[0], 1.0, 'F32x8Floor sample2[0]');
  r32 := VecF32x8Ceil(a32);
  CheckFloat(r32.f[1], -1.0, 'F32x8Ceil sample2[1]');
  r32 := VecF32x8Round(a32);
  Check(Abs(r32.f[2] - Round(r32.f[2])) < 1e-5, 'F32x8Round sample2[2] should be integer');
  r32 := VecF32x8Trunc(a32);
  CheckFloat(r32.f[3], -2.0, 'F32x8Trunc sample2[3]');
  r32 := VecF32x8Clamp(a32, b32, c32);
  CheckFloat(r32.f[6], 2.0, 'F32x8Clamp sample2[6]');
  r32 := VecF32x8Fma(a32, b32, c32);
  CheckFloat(r32.f[0], 0.75, 'F32x8Fma sample2[0]');
  buf32[0] := -8.0; buf32[1] := -6.0; buf32[2] := -4.0; buf32[3] := -2.0;
  buf32[4] := 2.0; buf32[5] := 4.0; buf32[6] := 6.0; buf32[7] := 8.0;
  r32 := VecF32x8Load(@buf32[0]);
  CheckFloat(r32.f[7], 8.0, 'F32x8Load sample2[7]');
  r32 := VecF32x8Zero;
  CheckFloat(r32.f[4], 0.0, 'F32x8Zero sample2[4]');
  VecF32x8Store(@buf32[0], a32);
  CheckFloat(buf32[5], -3.75, 'F32x8Store sample2[5]');

  a64 := VecF64x4Make(-1.25, 2.5, -3.75, 4.5);
  b64 := VecF64x4Splat(-2.0);
  c64 := VecF64x4Splat(1.5);
  r64 := VecF64x4Floor(a64);
  CheckDouble(r64.d[0], -2.0, 'F64x4Floor sample2[0]');
  r64 := VecF64x4Ceil(a64);
  CheckDouble(r64.d[2], -3.0, 'F64x4Ceil sample2[2]');
  r64 := VecF64x4Round(a64);
  CheckDouble(r64.d[1], 2.0, 'F64x4Round sample2[1]');
  r64 := VecF64x4Trunc(a64);
  CheckDouble(r64.d[3], 4.0, 'F64x4Trunc sample2[3]');
  r64 := VecF64x4Clamp(a64, VecF64x4Splat(-1.0), VecF64x4Splat(3.0));
  CheckDouble(r64.d[2], -1.0, 'F64x4Clamp sample2[2]');
  r64 := VecF64x4Fma(a64, b64, c64);
  CheckDouble(r64.d[0], 4.0, 'F64x4Fma sample2[0]');
  r64 := VecF64x4Lerp(a64, VecF64x4Zero, 0.25);
  CheckDouble(r64.d[1], 1.875, 'F64x4Lerp sample2[1]');
  buf64[0] := 6.0; buf64[1] := 7.0; buf64[2] := 8.0; buf64[3] := 9.0;
  r64 := VecF64x4Load(@buf64[0]);
  CheckDouble(r64.d[2], 8.0, 'F64x4Load sample2[2]');
  r64 := VecF64x4Zero;
  CheckDouble(r64.d[0], 0.0, 'F64x4Zero sample2[0]');
  r64 := VecF64x4Splat(-3.25);
  CheckDouble(r64.d[3], -3.25, 'F64x4Splat sample2[3]');
  VecF64x4Store(@buf64[0], a64);
  CheckDouble(buf64[1], 2.5, 'F64x4Store sample2[1]');

  a2 := VecF64x2Make(-5.0, 12.0);
  lo2 := VecF64x2Make(-2.0, 0.0);
  hi2 := VecF64x2Make(2.0, 10.0);
  r2 := VecF64x2Clamp(a2, lo2, hi2);
  CheckDouble(r2.d[0], -2.0, 'F64x2Clamp sample2[0]');
  CheckDouble(r2.d[1], 10.0, 'F64x2Clamp sample2[1]');
end;

procedure TestWideIntegerVectorSecondSample;
var
  ai16: TVecI16x8;
  bi16: TVecI16x8;
  abs16: TVecI16x8;
  ai32: TVecI32x4;
  lo32: TVecI32x4;
  hi32: TVecI32x4;
  ri32: TVecI32x4;
  ai32x8: TVecI32x8;
  lo32x8: TVecI32x8;
  hi32x8: TVecI32x8;
  ri32x8: TVecI32x8;
  ai8: TVecI8x16;
  bi8: TVecI8x16;
  au16: TVecU16x8;
  bu16: TVecU16x8;
  au32: TVecU32x4;
  bu32: TVecU32x4;
  au8: TVecU8x16;
  bu8: TVecU8x16;
  mask8: TMask8;
  mask16: TMask16;
  mask4: TMask4;
  buf32: array[0..3] of Int32;
  buf32x8: array[0..7] of Int32;
begin
  ai16 := MakeI16x8(-8, 7, -6, 5, -4, 3, -2, 1);
  abs16 := VecI16x8Abs(ai16);
  Check(abs16.i[0] = 8, 'I16x8Abs sample2[0]');
  bi16 := MakeI16x8(-8, 0, -7, 5, -5, 4, -2, 2);
  mask8 := VecI16x8CmpLe(ai16, bi16);
  Check((mask8 and $02) = 0, 'I16x8CmpLe sample2[1]');
  mask8 := VecI16x8CmpGe(ai16, bi16);
  Check((mask8 and $08) <> 0, 'I16x8CmpGe sample2[3]');
  mask8 := VecI16x8CmpNe(ai16, bi16);
  Check((mask8 and $01) = 0, 'I16x8CmpNe sample2[0]');

  ai32 := VecI32x4Make(-20, -1, 5, 100);
  lo32 := VecI32x4Splat(-5);
  hi32 := VecI32x4Splat(10);
  ri32 := VecI32x4Clamp(ai32, lo32, hi32);
  Check(ri32.i[0] = -5, 'I32x4Clamp sample2[0]');
  Check(VecI32x4ReduceAdd(ai32) = 84, 'I32x4ReduceAdd sample2');
  Check(VecI32x4ReduceMin(ai32) = -20, 'I32x4ReduceMin sample2');
  Check(VecI32x4ReduceMax(ai32) = 100, 'I32x4ReduceMax sample2');
  ri32 := VecI32x4Zero;
  Check(ri32.i[2] = 0, 'I32x4Zero sample2[2]');
  VecI32x4Store(@buf32[0], ai32);
  Check(buf32[3] = 100, 'I32x4Store sample2[3]');

  buf32x8[0] := -8; buf32x8[1] := -4; buf32x8[2] := -1; buf32x8[3] := 0;
  buf32x8[4] := 1; buf32x8[5] := 4; buf32x8[6] := 8; buf32x8[7] := 16;
  ai32x8 := VecI32x8Load(@buf32x8[0]);
  Check(ai32x8.i[6] = 8, 'I32x8Load sample2[6]');
  lo32x8 := VecI32x8Splat(-2);
  hi32x8 := VecI32x8Splat(6);
  ri32x8 := VecI32x8Clamp(ai32x8, lo32x8, hi32x8);
  Check(ri32x8.i[0] = -2, 'I32x8Clamp sample2[0]');
  Check(VecI32x8ReduceAdd(ai32x8) = 16, 'I32x8ReduceAdd sample2');
  Check(VecI32x8ReduceMin(ai32x8) = -8, 'I32x8ReduceMin sample2');
  Check(VecI32x8ReduceMax(ai32x8) = 16, 'I32x8ReduceMax sample2');
  ri32x8 := VecI32x8Zero;
  Check(ri32x8.i[7] = 0, 'I32x8Zero sample2[7]');
  VecI32x8Store(@buf32x8[0], ai32x8);
  Check(buf32x8[5] = 4, 'I32x8Store sample2[5]');

  ai8 := MakeI8x16(-8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7);
  bi8 := MakeI8x16(-8, -6, -7, -5, -5, -2, -2, 0, 0, 0, 3, 2, 4, 6, 5, 7);
  mask16 := VecI8x16CmpLe(ai8, bi8);
  Check((mask16 and $0002) <> 0, 'I8x16CmpLe sample2[1]');
  mask16 := VecI8x16CmpGe(ai8, bi8);
  Check((mask16 and $0400) = 0, 'I8x16CmpGe sample2[10]');
  mask16 := VecI8x16CmpNe(ai8, bi8);
  Check((mask16 and $2000) <> 0, 'I8x16CmpNe sample2[13]');

  au16 := MakeU16x8(1, 5, 9, 13, 17, 21, 25, 29);
  bu16 := MakeU16x8(1, 4, 10, 13, 16, 22, 24, 30);
  mask8 := VecU16x8CmpLe(au16, bu16);
  Check((mask8 and $01) <> 0, 'U16x8CmpLe sample2[0]');
  mask8 := VecU16x8CmpGe(au16, bu16);
  Check((mask8 and $02) <> 0, 'U16x8CmpGe sample2[1]');
  mask8 := VecU16x8CmpNe(au16, bu16);
  Check((mask8 and $08) = 0, 'U16x8CmpNe sample2[3]');

  au32 := MakeU32x4(1, 2, 3, 4);
  bu32 := MakeU32x4(1, 9, 3, 0);
  mask4 := VecU32x4CmpNe(au32, bu32);
  Check((mask4 and $02) <> 0, 'U32x4CmpNe sample2[1]');
  Check((mask4 and $04) = 0, 'U32x4CmpNe sample2[2]');

  au8 := MakeU8x16(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
  bu8 := MakeU8x16(1, 3, 2, 4, 4, 6, 8, 7, 9, 10, 10, 12, 14, 13, 15, 17);
  mask16 := VecU8x16CmpLe(au8, bu8);
  Check((mask16 and $0002) <> 0, 'U8x16CmpLe sample2[1]');
  mask16 := VecU8x16CmpGe(au8, bu8);
  Check((mask16 and $0010) <> 0, 'U8x16CmpGe sample2[4]');
  mask16 := VecU8x16CmpNe(au8, bu8);
  Check((mask16 and $0400) <> 0, 'U8x16CmpNe sample2[10]');
end;

begin
  StartApiCoverageSuite('API Coverage Wide Vectors');
  TestF32x8ExtMath;
  TestF64x4ExtMath;
  TestF64x2Clamp;
  TestNarrowCmpLeGeNe;
  TestWideFloatVectorSecondSample;
  TestWideIntegerVectorSecondSample;
  PrintApiCoverageSummary;
end.
