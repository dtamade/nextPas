program test_api_coverage_core_vectors;

{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  nextpas.core.text.conv,
  Math,
  nextpas.core.simd.base,
  nextpas.core.simd,
  nextpas.core.simd.api_coverage.support;

procedure TestVecF32x4Make;
var
  v: TVecF32x4;
begin
  v := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  CheckFloat(v.f[0], 1.0, 'F32x4Make lane0');
  CheckFloat(v.f[1], 2.0, 'F32x4Make lane1');
  CheckFloat(v.f[2], 3.0, 'F32x4Make lane2');
  CheckFloat(v.f[3], 4.0, 'F32x4Make lane3');
  v := VecF32x4Make(0.0, 0.0, 0.0, 0.0);
  CheckFloat(v.f[0], 0.0, 'F32x4Make zeros');
  v := VecF32x4Make(-1.5, -2.5, -3.5, -4.5);
  CheckFloat(v.f[0], -1.5, 'F32x4Make neg0');
  CheckFloat(v.f[3], -4.5, 'F32x4Make neg3');
end;

procedure TestVecI32x4Make;
var
  v: TVecI32x4;
begin
  v := VecI32x4Make(10, 20, 30, 40);
  Check(v.i[0] = 10, 'I32x4Make lane0');
  Check(v.i[1] = 20, 'I32x4Make lane1');
  Check(v.i[2] = 30, 'I32x4Make lane2');
  Check(v.i[3] = 40, 'I32x4Make lane3');
  v := VecI32x4Make(0, -1, 2147483647, -2147483648);
  Check(v.i[0] = 0, 'I32x4Make zero');
  Check(v.i[1] = -1, 'I32x4Make neg1');
  Check(v.i[2] = 2147483647, 'I32x4Make MaxInt');
  Check(v.i[3] = -2147483648, 'I32x4Make MinInt');
end;

procedure TestVecF64x2Make;
var
  v: TVecF64x2;
begin
  v := VecF64x2Make(1.5, 2.5);
  CheckDouble(v.d[0], 1.5, 'F64x2Make lane0');
  CheckDouble(v.d[1], 2.5, 'F64x2Make lane1');
  v := VecF64x2Make(0.0, 0.0);
  CheckDouble(v.d[0], 0.0, 'F64x2Make zero0');
  v := VecF64x2Make(-100.25, 999.999);
  CheckDouble(v.d[0], -100.25, 'F64x2Make neg');
  CheckDouble(v.d[1], 999.999, 'F64x2Make large');
end;

procedure TestVecF32x8Make;
var
  v: TVecF32x8;
begin
  v := VecF32x8Make(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  CheckFloat(v.f[0], 1.0, 'F32x8Make lane0');
  CheckFloat(v.f[3], 4.0, 'F32x8Make lane3');
  CheckFloat(v.f[7], 8.0, 'F32x8Make lane7');
  v := VecF32x8Make(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
  CheckFloat(v.f[4], 0.0, 'F32x8Make zero4');
end;

procedure TestVecF64x4Make;
var
  v: TVecF64x4;
begin
  v := VecF64x4Make(1.1, 2.2, 3.3, 4.4);
  CheckDouble(v.d[0], 1.1, 'F64x4Make lane0');
  CheckDouble(v.d[1], 2.2, 'F64x4Make lane1');
  CheckDouble(v.d[2], 3.3, 'F64x4Make lane2');
  CheckDouble(v.d[3], 4.4, 'F64x4Make lane3');
  v := VecF64x4Make(0.0, -0.0, 1e100, -1e100);
  CheckDouble(v.d[0], 0.0, 'F64x4Make zero');
  CheckDouble(v.d[2], 1e100, 'F64x4Make large');
end;

procedure TestVecI32x4Abs;
var
  a: TVecI32x4;
  r: TVecI32x4;
begin
  a := VecI32x4Make(-5, 3, -100, 0);
  r := VecI32x4Abs(a);
  Check(r.i[0] = 5, 'I32x4Abs neg->pos');
  Check(r.i[1] = 3, 'I32x4Abs pos unchanged');
  Check(r.i[2] = 100, 'I32x4Abs neg100');
  Check(r.i[3] = 0, 'I32x4Abs zero');
  a := VecI32x4Make(2147483647, -2147483647, 1, -1);
  r := VecI32x4Abs(a);
  Check(r.i[0] = 2147483647, 'I32x4Abs MaxInt');
  Check(r.i[1] = 2147483647, 'I32x4Abs -MaxInt');
  Check(r.i[3] = 1, 'I32x4Abs -1');
end;

procedure TestVecI32x8Abs;
var
  a: TVecI32x8;
  r: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    a.i[i] := -(i + 1);
  r := VecI32x8Abs(a);
  for i := 0 to 7 do
    Check(r.i[i] = i + 1, 'I32x8Abs lane' + IntToStr(i));
  for i := 0 to 7 do
    a.i[i] := 0;
  r := VecI32x8Abs(a);
  Check(r.i[0] = 0, 'I32x8Abs zeros');
end;

procedure TestVecI16x8Abs;
var
  a: TVecI16x8;
  r: TVecI16x8;
begin
  a.i[0] := -1; a.i[1] := 1; a.i[2] := -32767; a.i[3] := 32767;
  a.i[4] := 0; a.i[5] := -100; a.i[6] := 100; a.i[7] := -1;
  r := VecI16x8Abs(a);
  Check(r.i[0] = 1, 'I16x8Abs -1');
  Check(r.i[1] = 1, 'I16x8Abs +1');
  Check(r.i[2] = 32767, 'I16x8Abs -32767');
  Check(r.i[3] = 32767, 'I16x8Abs +32767');
  Check(r.i[4] = 0, 'I16x8Abs 0');
  Check(r.i[5] = 100, 'I16x8Abs -100');
end;

procedure TestVecI8x16Abs;
var
  a: TVecI8x16;
  r: TVecI8x16;
  i: Integer;
begin
  for i := 0 to 15 do
    a.i[i] := Int8(-(i + 1));
  r := VecI8x16Abs(a);
  for i := 0 to 15 do
    Check(r.i[i] = Int8(i + 1), 'I8x16Abs lane' + IntToStr(i));
  a.i[0] := 0;
  a.i[1] := 127;
  a.i[2] := -127;
  r := VecI8x16Abs(a);
  Check(r.i[0] = 0, 'I8x16Abs zero');
  Check(r.i[1] = 127, 'I8x16Abs +127');
  Check(r.i[2] = 127, 'I8x16Abs -127');
end;

procedure TestVecI32x4Splat;
var
  v: TVecI32x4;
begin
  v := VecI32x4Splat(42);
  Check(v.i[0] = 42, 'I32x4Splat 42 lane0');
  Check(v.i[1] = 42, 'I32x4Splat 42 lane1');
  Check(v.i[2] = 42, 'I32x4Splat 42 lane2');
  Check(v.i[3] = 42, 'I32x4Splat 42 lane3');
  v := VecI32x4Splat(0);
  Check(v.i[0] = 0, 'I32x4Splat 0');
  v := VecI32x4Splat(-1);
  Check(v.i[0] = -1, 'I32x4Splat -1');
  Check(v.i[3] = -1, 'I32x4Splat -1 lane3');
end;

procedure TestVecI32x4Zero;
var
  v: TVecI32x4;
begin
  v := VecI32x4Zero;
  Check(v.i[0] = 0, 'I32x4Zero lane0');
  Check(v.i[1] = 0, 'I32x4Zero lane1');
  Check(v.i[2] = 0, 'I32x4Zero lane2');
  Check(v.i[3] = 0, 'I32x4Zero lane3');
end;

procedure TestVecI32x4LoadStore;
var
  src: array[0..3] of Int32;
  dst: array[0..3] of Int32;
  v: TVecI32x4;
begin
  src[0] := 100; src[1] := 200; src[2] := 300; src[3] := 400;
  v := VecI32x4Load(@src[0]);
  Check(v.i[0] = 100, 'I32x4Load lane0');
  Check(v.i[1] = 200, 'I32x4Load lane1');
  Check(v.i[2] = 300, 'I32x4Load lane2');
  Check(v.i[3] = 400, 'I32x4Load lane3');
  FillChar(dst, SizeOf(dst), 0);
  VecI32x4Store(@dst[0], v);
  Check(dst[0] = 100, 'I32x4Store lane0');
  Check(dst[1] = 200, 'I32x4Store lane1');
  Check(dst[2] = 300, 'I32x4Store lane2');
  Check(dst[3] = 400, 'I32x4Store lane3');
  src[0] := 0; src[1] := 0; src[2] := 0; src[3] := 0;
  v := VecI32x4Load(@src[0]);
  Check(v.i[0] = 0, 'I32x4Load zeros');
end;

procedure TestVecI32x8Splat;
var
  v: TVecI32x8;
  i: Integer;
begin
  v := VecI32x8Splat(77);
  for i := 0 to 7 do
    Check(v.i[i] = 77, 'I32x8Splat 77 lane' + IntToStr(i));
  v := VecI32x8Splat(0);
  Check(v.i[0] = 0, 'I32x8Splat 0');
  v := VecI32x8Splat(-999);
  Check(v.i[7] = -999, 'I32x8Splat -999 lane7');
end;

procedure TestVecI32x8Zero;
var
  v: TVecI32x8;
  i: Integer;
begin
  v := VecI32x8Zero;
  for i := 0 to 7 do
    Check(v.i[i] = 0, 'I32x8Zero lane' + IntToStr(i));
end;

procedure TestVecI32x8LoadStore;
var
  src: array[0..7] of Int32;
  dst: array[0..7] of Int32;
  v: TVecI32x8;
  i: Integer;
begin
  for i := 0 to 7 do
    src[i] := (i + 1) * 10;
  v := VecI32x8Load(@src[0]);
  for i := 0 to 7 do
    Check(v.i[i] = (i + 1) * 10, 'I32x8Load lane' + IntToStr(i));
  FillChar(dst, SizeOf(dst), 0);
  VecI32x8Store(@dst[0], v);
  for i := 0 to 7 do
    Check(dst[i] = (i + 1) * 10, 'I32x8Store lane' + IntToStr(i));
end;

procedure TestClampReduce;
var
  a4: TVecI32x4;
  lo4: TVecI32x4;
  hi4: TVecI32x4;
  r4: TVecI32x4;
  a8: TVecI32x8;
  lo8: TVecI32x8;
  hi8: TVecI32x8;
  r8: TVecI32x8;
begin
  a4 := VecI32x4Make(-10, 5, 50, 100);
  lo4 := VecI32x4Splat(0);
  hi4 := VecI32x4Splat(20);
  r4 := VecI32x4Clamp(a4, lo4, hi4);
  Check(r4.i[0] = 0, 'Clamp[-10]');
  Check(r4.i[1] = 5, 'Clamp[5]');
  Check(r4.i[2] = 20, 'Clamp[50]');
  a4 := VecI32x4Make(1, 2, 3, 4);
  Check(VecI32x4ReduceAdd(a4) = 10, 'ReduceAdd');
  Check(VecI32x4ReduceMin(a4) = 1, 'ReduceMin');
  Check(VecI32x4ReduceMax(a4) = 4, 'ReduceMax');
  a8.i[0] := 1; a8.i[1] := 2; a8.i[2] := 3; a8.i[3] := 4;
  a8.i[4] := 5; a8.i[5] := 6; a8.i[6] := 7; a8.i[7] := 8;
  Check(VecI32x8ReduceAdd(a8) = 36, 'I32x8ReduceAdd');
  Check(VecI32x8ReduceMin(a8) = 1, 'I32x8ReduceMin');
  Check(VecI32x8ReduceMax(a8) = 8, 'I32x8ReduceMax');
  lo8 := VecI32x8Splat(3);
  hi8 := VecI32x8Splat(6);
  r8 := VecI32x8Clamp(a8, lo8, hi8);
  Check(r8.i[0] = 3, 'I32x8Clamp[1]');
  Check(r8.i[7] = 6, 'I32x8Clamp[8]');
end;

procedure TestLerp;
var
  a: TVecF32x4;
  b: TVecF32x4;
  r: TVecF32x4;
  da: TVecF64x4;
  db: TVecF64x4;
  dr: TVecF64x4;
begin
  a := VecF32x4Make(0, 10, 20, 30);
  b := VecF32x4Make(100, 110, 120, 130);
  r := VecF32x4Lerp(a, b, 0.0);
  Check(Abs(r.f[0]) < 1e-5, 'Lerp t=0');
  r := VecF32x4Lerp(a, b, 1.0);
  Check(Abs(r.f[0] - 100) < 1e-5, 'Lerp t=1');
  r := VecF32x4Lerp(a, b, 0.5);
  Check(Abs(r.f[0] - 50) < 1e-4, 'Lerp t=0.5');
  da := VecF64x4Make(0, 100, 200, 300);
  db := VecF64x4Make(10, 110, 210, 310);
  dr := VecF64x4Lerp(da, db, 0.5);
  Check(Abs(dr.d[0] - 5.0) < 1e-10, 'F64Lerp');
end;

procedure TestCmpNe;
var
  a: TVecU32x4;
  b: TVecU32x4;
  m: TMask4;
begin
  a.u[0] := 1; a.u[1] := 2; a.u[2] := 3; a.u[3] := 4;
  b.u[0] := 1; b.u[1] := 99; b.u[2] := 3; b.u[3] := 99;
  m := VecU32x4CmpNe(a, b);
  Check((m and 1) = 0, 'CmpNe eq');
  Check((m and 2) <> 0, 'CmpNe ne');
end;

begin
  StartApiCoverageSuite('API Coverage Core Vectors');
  TestVecF32x4Make;
  TestVecI32x4Make;
  TestVecF64x2Make;
  TestVecF32x8Make;
  TestVecF64x4Make;
  TestVecI32x4Abs;
  TestVecI32x8Abs;
  TestVecI16x8Abs;
  TestVecI8x16Abs;
  TestVecI32x4Splat;
  TestVecI32x4Zero;
  TestVecI32x4LoadStore;
  TestVecI32x8Splat;
  TestVecI32x8Zero;
  TestVecI32x8LoadStore;
  TestClampReduce;
  TestLerp;
  TestCmpNe;
  PrintApiCoverageSummary;
end.
