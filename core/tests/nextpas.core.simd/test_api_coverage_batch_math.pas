program test_api_coverage_batch_math;

{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  nextpas.core.text.conv, Math,
  nextpas.core.simd, nextpas.core.simd.api_coverage.support;

procedure TestArrayF64;
var
  src: array[0..3] of Double;
  src2: array[0..3] of Double;
  src3: array[0..3] of Double;
  dst: array[0..3] of Double;
  dst2: array[0..3] of Double;
begin
  src[0] := 0; src[1] := Pi / 2; src[2] := Pi; src[3] := 1;
  ArraySinF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Sin[0]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Sin[pi/2]');
  ArrayCosF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 1.0) < 1e-10, 'Cos[0]');

  // Test ArraySinCosF64
  ArraySinCosF64(@src[0], @dst[0], @dst2[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'SinCos Sin[0]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'SinCos Sin[pi/2]');
  Check(Abs(dst2[0] - 1.0) < 1e-10, 'SinCos Cos[0]');
  Check(Abs(dst2[1]) < 1e-10, 'SinCos Cos[pi/2]');

  src[0] := 1; src[1] := Exp(1.0); src[2] := Exp(2.0); src[3] := 1;
  ArrayLogF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Log[1]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Log[e]');

  // Test ArrayLog2F64
  src[0] := 1; src[1] := 2; src[2] := 4; src[3] := 8;
  ArrayLog2F64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Log2[1]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Log2[2]');
  Check(Abs(dst[2] - 2.0) < 1e-10, 'Log2[4]');
  Check(Abs(dst[3] - 3.0) < 1e-10, 'Log2[8]');

  // Test ArrayLog10F64
  src[0] := 1; src[1] := 10; src[2] := 100; src[3] := 1000;
  ArrayLog10F64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Log10[1]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Log10[10]');
  Check(Abs(dst[2] - 2.0) < 1e-10, 'Log10[100]');
  Check(Abs(dst[3] - 3.0) < 1e-10, 'Log10[1000]');

  src[0] := 0; src[1] := 1; src[2] := 2; src[3] := 3;
  ArrayExpF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 1.0) < 1e-10, 'Exp[0]');

  // Test ArrayCeilF64
  src[0] := 1.2; src[1] := 2.5; src[2] := 3.7; src[3] := 4.1;
  ArrayCeilF64(@src[0], @dst[0], 4);
  Check(dst[0] = 2.0, 'Ceil[1.2]');
  Check(dst[1] = 3.0, 'Ceil[2.5]');
  Check(dst[2] = 4.0, 'Ceil[3.7]');
  Check(dst[3] = 5.0, 'Ceil[4.1]');

  // Test ArrayFloorF64
  ArrayFloorF64(@src[0], @dst[0], 4);
  Check(dst[0] = 1.0, 'Floor[1.2]');
  Check(dst[1] = 2.0, 'Floor[2.5]');
  Check(dst[2] = 3.0, 'Floor[3.7]');
  Check(dst[3] = 4.0, 'Floor[4.1]');

  // Test ArrayRoundF64 — matches System.Round banker's (ties-to-even)
  ArrayRoundF64(@src[0], @dst[0], 4);
  Check(dst[0] = 1.0, 'Round[1.2]');
  Check(dst[1] = 2.0, 'Round[2.5]');  // 2.5 -> 2 (even), not half-up
  Check(dst[2] = 4.0, 'Round[3.7]');
  Check(dst[3] = 4.0, 'Round[4.1]');

  // Test ArrayTruncF64
  ArrayTruncF64(@src[0], @dst[0], 4);
  Check(dst[0] = 1.0, 'Trunc[1.2]');
  Check(dst[1] = 2.0, 'Trunc[2.5]');
  Check(dst[2] = 3.0, 'Trunc[3.7]');
  Check(dst[3] = 4.0, 'Trunc[4.1]');

  src[0] := 1; src[1] := 2; src[2] := 3; src[3] := 4;
  src2[0] := 10; src2[1] := 20; src2[2] := 30; src2[3] := 40;
  src3[0] := 100; src3[1] := 200; src3[2] := 300; src3[3] := 400;
  ArrayFmaF64(@src[0], @src2[0], @src3[0], @dst[0], 4);
  Check(Abs(dst[0] - 110) < 1e-10, 'Fma');
  ArrayMinF64(@src[0], @src2[0], @dst[0], 4);
  Check(dst[0] = 1.0, 'Min');
  ArrayMaxF64(@src[0], @src2[0], @dst[0], 4);
  Check(dst[0] = 10.0, 'Max');
end;

procedure TestBatchF64Extra;
var
  src: array[0..3] of Double;
  src2: array[0..3] of Double;
  dst: array[0..3] of Double;
  sf: array[0..3] of Single;
  sf2: array[0..3] of Single;
  sfd: array[0..3] of Single;
  dotResult: Double;
begin
  src[0] := 10; src[1] := 20; src[2] := 30; src[3] := 40;
  ArrayAddScalarF64(@src[0], @dst[0], 4, 5.0);
  Check(Abs(dst[0] - 15) < 1e-10, 'AddScalarF64[0]');
  Check(Abs(dst[3] - 45) < 1e-10, 'AddScalarF64[3]');
  ArrayMulScalarF64(@src[0], @dst[0], 4, 2.0);
  Check(Abs(dst[0] - 20) < 1e-10, 'MulScalarF64[0]');
  Check(Abs(dst[3] - 80) < 1e-10, 'MulScalarF64[3]');
  src[0] := -5; src[1] := 5; src[2] := 15; src[3] := 25;
  ArrayClampF64(@src[0], @dst[0], 4, 0, 20);
  Check(Abs(dst[0]) < 1e-10, 'ClampF64[-5→0]');
  Check(Abs(dst[1] - 5) < 1e-10, 'ClampF64[5]');
  Check(Abs(dst[3] - 20) < 1e-10, 'ClampF64[25→20]');
  src[0] := 1; src[1] := 2; src[2] := 3; src[3] := 4;
  src2[0] := 10; src2[1] := 20; src2[2] := 30; src2[3] := 40;
  dotResult := ReduceDotF64(@src[0], @src2[0], 4);
  Check(Abs(dotResult - 300) < 1e-10, 'ReduceDotF64=300');
  sf[0] := 10; sf[1] := 5; sf[2] := 3; sf[3] := 8;
  sf2[0] := 7; sf2[1] := 2; sf2[2] := 9; sf2[3] := 1;
  ArrayAbsDiffF32(@sf[0], @sf2[0], @sfd[0], 4);
  Check(Abs(sfd[0] - 3) < 1e-5, 'AbsDiffF32[0]');
  Check(Abs(sfd[2] - 6) < 1e-5, 'AbsDiffF32[2]');
  sf[0] := 10; sf[1] := 20; sf[2] := 30; sf[3] := 40;
  ArrayNormF32(@sf[0], @sfd[0], 4, 25.0, 0.1);
  Check(Abs(sfd[0] - (-1.5)) < 1e-4, 'NormF32[0]');
  src[0] := 1; src[1] := 2; src[2] := 3; src[3] := 4;
  ArrayLinearF64(@src[0], @dst[0], 4, 2.0, 10.0);
  Check(Abs(dst[0] - 12) < 1e-10, 'LinearF64[0]=1*2+10');
  Check(Abs(dst[3] - 18) < 1e-10, 'LinearF64[3]=4*2+10');
end;

procedure TestBatchF64ThinCoverageSecondSample;
var
  src: array[0..3] of Double;
  src2: array[0..3] of Double;
  src3: array[0..3] of Double;
  dst: array[0..3] of Double;
  dotResult: Double;
begin
  src[0] := 1.0; src[1] := 4.0; src[2] := 9.0; src[3] := 16.0;
  src2[0] := 2.0; src2[1] := 3.0; src2[2] := 4.0; src2[3] := 5.0;
  src3[0] := -1.0; src3[1] := -2.0; src3[2] := -3.0; src3[3] := -4.0;

  ArrayAddF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[1], 7.0, 'AddF64 sample2[1]');
  ArraySubF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[2], 5.0, 'SubF64 sample2[2]');
  ArrayMulF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[3], 80.0, 'MulF64 sample2[3]');
  ArrayDivF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[0], 0.5, 'DivF64 sample2[0]');

  src[0] := -1.5; src[1] := 2.0; src[2] := -3.5; src[3] := 0.0;
  ArrayAbsF64(@src[0], @dst[0], 4);
  CheckDouble(dst[0], 1.5, 'AbsF64 sample2[0]');
  ArrayNegF64(@src[0], @dst[0], 4);
  CheckDouble(dst[1], -2.0, 'NegF64 sample2[1]');

  src[0] := 1.0; src[1] := 4.0; src[2] := 9.0; src[3] := 16.0;
  ArraySqrtF64(@src[0], @dst[0], 4);
  CheckDouble(dst[2], 3.0, 'SqrtF64 sample2[2]');

  src[0] := 0.0; src[1] := Pi / 6; src[2] := Pi / 2; src[3] := Pi;
  ArraySinF64(@src[0], @dst[0], 4);
  CheckDouble(dst[1], 0.5, 'SinF64 sample2[1]');
  ArrayCosF64(@src[0], @dst[0], 4);
  CheckDouble(dst[3], -1.0, 'CosF64 sample2[3]');

  src[0] := 0.0; src[1] := 1.0; src[2] := -1.0; src[3] := 2.0;
  ArrayExpF64(@src[0], @dst[0], 4);
  CheckDouble(dst[2], Exp(-1.0), 'ExpF64 sample2[2]', 1e-8);
  src[0] := 1.0; src[1] := Exp(1.0); src[2] := Exp(2.0); src[3] := 10.0;
  ArrayLogF64(@src[0], @dst[0], 4);
  CheckDouble(dst[2], 2.0, 'LogF64 sample2[2]', 1e-8);

  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  src2[0] := 4.0; src2[1] := 3.0; src2[2] := 2.0; src2[3] := 1.0;
  src3[0] := 10.0; src3[1] := 20.0; src3[2] := 30.0; src3[3] := 40.0;
  ArrayFmaF64(@src[0], @src2[0], @src3[0], @dst[0], 4);
  CheckDouble(dst[0], 14.0, 'FmaF64 sample2[0]');
  ArrayMinF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[3], 1.0, 'MinF64 sample2[3]');
  ArrayMaxF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[0], 4.0, 'MaxF64 sample2[0]');

  ArrayAddScalarF64(@src[0], @dst[0], 4, -2.5);
  CheckDouble(dst[0], -1.5, 'AddScalarF64 sample2[0]');
  ArrayMulScalarF64(@src[0], @dst[0], 4, -0.5);
  CheckDouble(dst[3], -2.0, 'MulScalarF64 sample2[3]');

  src[0] := -2.0; src[1] := 0.5; src[2] := 5.0; src[3] := 11.0;
  ArrayClampF64(@src[0], @dst[0], 4, 0.0, 10.0);
  CheckDouble(dst[0], 0.0, 'ClampF64 sample2[0]');
  CheckDouble(dst[3], 10.0, 'ClampF64 sample2[3]');

  src[0] := -1.0; src[1] := 0.0; src[2] := 1.0; src[3] := 2.0;
  ArrayLinearF64(@src[0], @dst[0], 4, -3.0, 1.0);
  CheckDouble(dst[2], -2.0, 'LinearF64 sample2[2]');

  src[0] := -3.5; src[1] := 8.0; src[2] := 0.5; src[3] := 2.0;
  dotResult := ReduceDotF64(@src[0], @src2[0], 4);
  CheckDouble(dotResult, 13.0, 'ReduceDotF64 sample2');
  CheckDouble(ReduceSumF64(@src[0], 4), 7.0, 'ReduceSumF64 sample2');
  CheckDouble(ReduceMinF64(@src[0], 4), -3.5, 'ReduceMinF64 sample2');
  CheckDouble(ReduceMaxF64(@src[0], 4), 8.0, 'ReduceMaxF64 sample2');
end;

procedure TestBatchF32RefineAndConversionSecondSample;
var
  src: array[0..3] of Single;
  src2: array[0..3] of Single;
  dst: array[0..3] of Single;
  approx: array[0..3] of Single;
  srcI32: array[0..3] of Int32;
  dstI32: array[0..3] of Int32;
  srcI16A: array[0..3] of Int16;
  srcI16B: array[0..3] of Int16;
  dstI16: array[0..3] of Int16;
  srcPack: array[0..3] of Int32;
  dstPack: array[0..3] of Int16;
begin
  src[0] := 5.0; src[1] := 15.0; src[2] := 25.0; src[3] := 35.0;
  src2[0] := 2.0; src2[1] := 20.0; src2[2] := 30.0; src2[3] := 10.0;
  ArrayAbsDiffF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], 3.0, 'AbsDiffF32 sample2[0]');
  ArrayNormF32(@src[0], @dst[0], 4, 20.0, 0.5);
  CheckFloat(dst[2], 2.5, 'NormF32 sample2[2]');
  ArrayMaxF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[1], 20.0, 'MaxF32 sample2[1]');
  ArrayMinF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[3], 10.0, 'MinF32 sample2[3]');

  src[0] := 1.0; src[1] := -1.0; src[2] := 3.0; src[3] := -3.0;
  ArrayLinearReLUF32(@src[0], @dst[0], 4, 1.5, -1.0);
  CheckFloat(dst[0], 0.5, 'LinearReLUF32 sample2[0]');
  CheckFloat(dst[1], 0.0, 'LinearReLUF32 sample2[1]');
  src[0] := 1.0; src[1] := 4.0; src[2] := 9.0; src[3] := 16.0;
  ArrayPowF32(@src[0], @dst[0], 4, 0.5);
  CheckFloat(dst[3], 4.0, 'PowF32 sample2[3]');

  src[0] := 0.5; src[1] := 2.0; src[2] := 4.0; src[3] := 8.0;
  ArrayRcpF32(@src[0], @approx[0], 4);
  ArrayRcpRefineF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 2.0, 'RcpRefineF32 sample2[0]', 1e-4);
  ArrayRsqrtF32(@src[0], @approx[0], 4);
  ArrayRsqrtRefineF32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], 1.0 / Sqrt(2.0), 'RsqrtRefineF32 sample2[1]', 1e-4);

  src[0] := 1.0; src[1] := -2.0; src[2] := 3.0; src[3] := 0.0;
  ArrayF32toI32(@src[0], @dstI32[0], 4);
  Check(dstI32[2] = 3, 'F32toI32 sample2[2]');
  srcI32[0] := -10; srcI32[1] := 0; srcI32[2] := 20; srcI32[3] := 30;
  ArrayI32toF32(@srcI32[0], @dst[0], 4);
  CheckFloat(dst[0], -10.0, 'I32toF32 sample2[0]');

  srcI16A[0] := 3; srcI16A[1] := -4; srcI16A[2] := 5; srcI16A[3] := -6;
  srcI16B[0] := -2; srcI16B[1] := -3; srcI16B[2] := 4; srcI16B[3] := 1;
  ArrayMulI16(@srcI16A[0], @srcI16B[0], @dstI16[0], 4);
  Check(dstI16[1] = 12, 'MulI16 sample2[1]');

  srcPack[0] := 40000; srcPack[1] := -40000; srcPack[2] := 123; srcPack[3] := -456;
  ArrayPackSatI32toI16(@srcPack[0], @dstPack[0], 4);
  Check(dstPack[0] = 32767, 'PackSatI32toI16 sample2[0]');
  Check(dstPack[1] = -32768, 'PackSatI32toI16 sample2[1]');
  Check(dstPack[2] = 123, 'PackSatI32toI16 sample2[2]');
end;

procedure TestF64ExtendedOperations;
var
  src: array[0..3] of Double;
  src2: array[0..3] of Double;
  edge: array[0..3] of Double;
  dst: array[0..3] of Double;
begin
  // Test ArrayAxpyF64: y = a*x + y
  src[0] := 1; src[1] := 2; src[2] := 3; src[3] := 4;
  src2[0] := 10; src2[1] := 20; src2[2] := 30; src2[3] := 40;
  ArrayAxpyF64(2.0, @src[0], @src2[0], @dst[0], 4);
  Check(Abs(dst[0] - 12.0) < 1e-10, 'Axpy[0]');
  Check(Abs(dst[1] - 24.0) < 1e-10, 'Axpy[1]');
  Check(Abs(dst[2] - 36.0) < 1e-10, 'Axpy[2]');
  Check(Abs(dst[3] - 48.0) < 1e-10, 'Axpy[3]');

  // Test ArrayRcpF64: 1/x
  src[0] := 1; src[1] := 2; src[2] := 4; src[3] := 0.5;
  ArrayRcpF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 1.0) < 1e-10, 'Rcp[1]');
  Check(Abs(dst[1] - 0.5) < 1e-10, 'Rcp[2]');
  Check(Abs(dst[2] - 0.25) < 1e-10, 'Rcp[4]');
  Check(Abs(dst[3] - 2.0) < 1e-10, 'Rcp[0.5]');

  // Test ArrayRsqrtF64: 1/sqrt(x)
  // Compare against 1/Sqrt(x) (same formula as impl); 1/3 is not bit-exact for Sqrt(9).
  src[0] := 1; src[1] := 4; src[2] := 9; src[3] := 16;
  ArrayRsqrtF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 1.0/Sqrt(1.0)) < 1e-12, 'Rsqrt[1]');
  Check(Abs(dst[1] - 1.0/Sqrt(4.0)) < 1e-12, 'Rsqrt[4]');
  Check(Abs(dst[2] - 1.0/Sqrt(9.0)) < 1e-12, 'Rsqrt[9]');
  Check(Abs(dst[3] - 1.0/Sqrt(16.0)) < 1e-12, 'Rsqrt[16]');

  // Test ArrayTanF64
  src[0] := 0; src[1] := Pi/4; src[2] := Pi/6; src[3] := Pi/3;
  ArrayTanF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Tan[0]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Tan[pi/4]');
  Check(Abs(dst[2] - 1.0/Sqrt(3.0)) < 1e-6, 'Tan[pi/6]');

  // Test ArraySignF64
  src[0] := 5; src[1] := -3; src[2] := 0; src[3] := 0.001;
  ArraySignF64(@src[0], @dst[0], 4);
  Check(dst[0] = 1.0, 'Sign[5]');
  Check(dst[1] = -1.0, 'Sign[-3]');
  Check(dst[2] = 0.0, 'Sign[0]');
  Check(dst[3] = 1.0, 'Sign[0.001]');

  // Test ArrayFractF64
  src[0] := 1.5; src[1] := 2.7; src[2] := -1.3; src[3] := 3.0;
  ArrayFractF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 0.5) < 1e-10, 'Fract[1.5]');
  Check(Abs(dst[1] - 0.7) < 1e-10, 'Fract[2.7]');

  // Test ArrayModF64
  src[0] := 10; src[1] := 11; src[2] := 12; src[3] := 13;
  ArrayModF64(@src[0], @dst[0], 4, 3.0);
  Check(Abs(dst[0] - 1.0) < 1e-10, 'Mod[10,3]');
  Check(Abs(dst[1] - 2.0) < 1e-10, 'Mod[11,3]');
  Check(Abs(dst[2] - 0.0) < 1e-10, 'Mod[12,3]');
  Check(Abs(dst[3] - 1.0) < 1e-10, 'Mod[13,3]');

  // Test ArrayPowF64
  src[0] := 2; src[1] := 3; src[2] := 4; src[3] := 5;
  ArrayPowF64(@src[0], @dst[0], 4, 2.0);
  Check(Abs(dst[0] - 4.0) < 1e-10, 'Pow[2,2]');
  Check(Abs(dst[1] - 9.0) < 1e-10, 'Pow[3,2]');
  Check(Abs(dst[2] - 16.0) < 1e-10, 'Pow[4,2]');
  Check(Abs(dst[3] - 25.0) < 1e-10, 'Pow[5,2]');

  // Test ArrayLerpF64
  src[0] := 0; src[1] := 0; src[2] := 0; src[3] := 0;
  src2[0] := 10; src2[1] := 20; src2[2] := 30; src2[3] := 40;
  ArrayLerpF64(@src[0], @src2[0], @dst[0], 4, 0.5);
  Check(Abs(dst[0] - 5.0) < 1e-10, 'Lerp[0,10,0.5]');
  Check(Abs(dst[1] - 10.0) < 1e-10, 'Lerp[0,20,0.5]');

  // Test ArrayReLUF64
  src[0] := 1; src[1] := -2; src[2] := 0; src[3] := 3;
  ArrayReLUF64(@src[0], @dst[0], 4);
  Check(dst[0] = 1.0, 'ReLU[1]');
  Check(dst[1] = 0.0, 'ReLU[-2]');
  Check(dst[2] = 0.0, 'ReLU[0]');
  Check(dst[3] = 3.0, 'ReLU[3]');

  // Test ArrayAbsDiffF64
  src[0] := 5; src[1] := 3; src[2] := 1; src[3] := 4;
  src2[0] := 1; src2[1] := 7; src2[2] := 1; src2[3] := 4;
  ArrayAbsDiffF64(@src[0], @src2[0], @dst[0], 4);
  Check(dst[0] = 4.0, 'AbsDiff[5,1]');
  Check(dst[1] = 4.0, 'AbsDiff[3,7]');
  Check(dst[2] = 0.0, 'AbsDiff[1,1]');
  Check(dst[3] = 0.0, 'AbsDiff[4,4]');

  // Test ArrayNormF64
  src[0] := 10; src[1] := 20; src[2] := 30; src[3] := 40;
  ArrayNormF64(@src[0], @dst[0], 4, 25.0, 0.1);
  Check(Abs(dst[0] - (-1.5)) < 1e-10, 'Norm[10]');
  Check(Abs(dst[1] - (-0.5)) < 1e-10, 'Norm[20]');
  Check(Abs(dst[2] - 0.5) < 1e-10, 'Norm[30]');
  Check(Abs(dst[3] - 1.5) < 1e-10, 'Norm[40]');

  // Test ArrayLinearReLUF64
  src[0] := 1; src[1] := -1; src[2] := 2; src[3] := -2;
  ArrayLinearReLUF64(@src[0], @dst[0], 4, 2.0, 1.0);
  Check(dst[0] = 3.0, 'LinearReLU[1]');
  Check(dst[1] = 0.0, 'LinearReLU[-1]');
  Check(dst[2] = 5.0, 'LinearReLU[2]');
  Check(dst[3] = 0.0, 'LinearReLU[-2]');

  // Test ArrayStepF64
  edge[0] := 0; edge[1] := 0; edge[2] := 0; edge[3] := 0;
  src[0] := -1; src[1] := 0; src[2] := 1; src[3] := 0.5;
  ArrayStepF64(@edge[0], @src[0], @dst[0], 4);
  Check(dst[0] = 0.0, 'Step[-1]');
  Check(dst[1] = 1.0, 'Step[0]');
  Check(dst[2] = 1.0, 'Step[1]');
  Check(dst[3] = 1.0, 'Step[0.5]');

  // Test ArraySmoothstepF64 — Hermite smoothstep on [edge0, edge1]
  edge[0] := 0; edge[1] := 0; edge[2] := 0; edge[3] := 0;
  src2[0] := 1; src2[1] := 1; src2[2] := 1; src2[3] := 1;  // edge1
  src[0] := 0; src[1] := 0.5; src[2] := 1; src[3] := 0.25;
  ArraySmoothstepF64(@edge[0], @src2[0], @src[0], @dst[0], 4);
  Check(dst[0] = 0.0, 'Smoothstep[0]');
  // t=0.5 → t*t*(3-2*t) = 0.5
  Check(Abs(dst[1] - 0.5) < 1e-12, 'Smoothstep[0.5]');
  Check(dst[2] = 1.0, 'Smoothstep[1]');

  // Test ArrayAtan2F64
  src[0] := 0; src[1] := 1; src[2] := 1; src[3] := -1;
  src2[0] := 1; src2[1] := 0; src2[2] := 1; src2[3] := 1;
  ArrayAtan2F64(@src[0], @src2[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Atan2[0,1]');
  Check(Abs(dst[1] - Pi/2) < 1e-10, 'Atan2[1,0]');
  Check(Abs(dst[2] - Pi/4) < 1e-10, 'Atan2[1,1]');

  // Test ArrayHypotF64
  src[0] := 3; src[1] := 5; src[2] := 8; src[3] := 0;
  src2[0] := 4; src2[1] := 12; src2[2] := 15; src2[3] := 1;
  ArrayHypotF64(@src[0], @src2[0], @dst[0], 4);
  Check(Abs(dst[0] - 5.0) < 1e-10, 'Hypot[3,4]');
  Check(Abs(dst[1] - 13.0) < 1e-10, 'Hypot[5,12]');
  Check(Abs(dst[2] - 17.0) < 1e-10, 'Hypot[8,15]');
  Check(Abs(dst[3] - 1.0) < 1e-10, 'Hypot[0,1]');
end;

procedure TestBatchF64ExtendedSecondSample;
var
  src: array[0..3] of Double;
  src2: array[0..3] of Double;
  src3: array[0..3] of Double;
  edge: array[0..3] of Double;
  dst: array[0..3] of Double;
  dst2: array[0..3] of Double;
begin
  src[0] := 1.0; src[1] := 2.0; src[2] := 4.0; src[3] := 8.0;
  ArrayLog2F64(@src[0], @dst[0], 4);
  CheckDouble(dst[2], 2.0, 'Log2F64 sample2[2]');
  src[0] := 1.0; src[1] := 10.0; src[2] := 100.0; src[3] := 1000.0;
  ArrayLog10F64(@src[0], @dst[0], 4);
  CheckDouble(dst[2], 2.0, 'Log10F64 sample2[2]');

  src[0] := 1.25; src[1] := 2.5; src[2] := 3.75; src[3] := 4.1;
  ArrayCeilF64(@src[0], @dst[0], 4);
  CheckDouble(dst[0], 2.0, 'CeilF64 sample2[0]');
  ArrayFloorF64(@src[0], @dst[0], 4);
  CheckDouble(dst[1], 2.0, 'FloorF64 sample2[1]');
  ArrayRoundF64(@src[0], @dst[0], 4);
  CheckDouble(dst[0], 1.0, 'RoundF64 sample2[0]');
  ArrayTruncF64(@src[0], @dst[0], 4);
  CheckDouble(dst[2], 3.0, 'TruncF64 sample2[2]');

  src[0] := 0.0; src[1] := Pi / 4; src[2] := Pi / 6; src[3] := -Pi / 4;
  ArrayTanF64(@src[0], @dst[0], 4);
  CheckDouble(dst[1], 1.0, 'TanF64 sample2[1]', 1e-8);
  ArraySinCosF64(@src[0], @dst[0], @dst2[0], 4);
  CheckDouble(dst[0], 0.0, 'SinCosF64 Sin sample2[0]', 1e-10);
  CheckDouble(dst2[1], Cos(Pi / 4), 'SinCosF64 Cos sample2[1]', 1e-8);

  src[0] := 2.0; src[1] := -4.0; src[2] := 0.0; src[3] := 0.5;
  ArraySignF64(@src[0], @dst[0], 4);
  CheckDouble(dst[1], -1.0, 'SignF64 sample2[1]');
  src[0] := 2.25; src[1] := -1.75; src[2] := 3.0; src[3] := 0.125;
  ArrayFractF64(@src[0], @dst[0], 4);
  CheckDouble(dst[0], 0.25, 'FractF64 sample2[0]');
  src[0] := 7.0; src[1] := 8.0; src[2] := 9.0; src[3] := 10.0;
  ArrayModF64(@src[0], @dst[0], 4, 4.0);
  CheckDouble(dst[2], 1.0, 'ModF64 sample2[2]');
  src[0] := 2.0; src[1] := 3.0; src[2] := 4.0; src[3] := 5.0;
  ArrayPowF64(@src[0], @dst[0], 4, 3.0);
  CheckDouble(dst[1], 27.0, 'PowF64 sample2[1]');

  src[0] := 0.0; src[1] := 10.0; src[2] := 20.0; src[3] := 30.0;
  src2[0] := 10.0; src2[1] := 20.0; src2[2] := 30.0; src2[3] := 40.0;
  ArrayLerpF64(@src[0], @src2[0], @dst[0], 4, 0.25);
  CheckDouble(dst[0], 2.5, 'LerpF64 sample2[0]');

  src[0] := 2.0; src[1] := -3.0; src[2] := 0.0; src[3] := 4.0;
  ArrayReLUF64(@src[0], @dst[0], 4);
  CheckDouble(dst[1], 0.0, 'ReLUF64 sample2[1]');
  src[0] := 9.0; src[1] := 1.0; src[2] := 4.0; src[3] := 6.0;
  src2[0] := 3.0; src2[1] := 5.0; src2[2] := 4.0; src2[3] := 2.0;
  ArrayAbsDiffF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[0], 6.0, 'AbsDiffF64 sample2[0]');
  src[0] := 5.0; src[1] := 15.0; src[2] := 25.0; src[3] := 35.0;
  ArrayNormF64(@src[0], @dst[0], 4, 20.0, 0.5);
  CheckDouble(dst[2], 2.5, 'NormF64 sample2[2]');
  src[0] := 1.0; src[1] := -2.0; src[2] := 3.0; src[3] := -4.0;
  ArrayLinearReLUF64(@src[0], @dst[0], 4, 0.5, -1.0);
  CheckDouble(dst[0], 0.0, 'LinearReLUF64 sample2[0]');
  CheckDouble(dst[2], 0.5, 'LinearReLUF64 sample2[2]');

  edge[0] := 1.0; edge[1] := 1.0; edge[2] := 1.0; edge[3] := 1.0;
  src[0] := 0.0; src[1] := 1.0; src[2] := 2.0; src[3] := 0.5;
  ArrayStepF64(@edge[0], @src[0], @dst[0], 4);
  CheckDouble(dst[0], 0.0, 'StepF64 sample2[0]');
  CheckDouble(dst[2], 1.0, 'StepF64 sample2[2]');
  edge[0] := 0.0; edge[1] := 0.0; edge[2] := 0.0; edge[3] := 0.0;
  src2[0] := 2.0; src2[1] := 2.0; src2[2] := 2.0; src2[3] := 2.0;
  src[0] := 0.0; src[1] := 1.0; src[2] := 2.0; src[3] := 0.5;
  ArraySmoothstepF64(@edge[0], @src2[0], @src[0], @dst[0], 4);
  CheckDouble(dst[0], 0.0, 'SmoothstepF64 sample2[0]');
  CheckDouble(dst[2], 1.0, 'SmoothstepF64 sample2[2]');

  src[0] := 1.0; src[1] := 0.0; src[2] := -1.0; src[3] := 1.0;
  src2[0] := 0.0; src2[1] := 1.0; src2[2] := 1.0; src2[3] := 1.0;
  ArrayAtan2F64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[0], Pi / 2, 'Atan2F64 sample2[0]', 1e-10);
  src[0] := 6.0; src[1] := 9.0; src[2] := 0.0; src[3] := 5.0;
  src2[0] := 8.0; src2[1] := 12.0; src2[2] := 7.0; src2[3] := 12.0;
  ArrayHypotF64(@src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[0], 10.0, 'HypotF64 sample2[0]');
  CheckDouble(dst[1], 15.0, 'HypotF64 sample2[1]');

  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  src2[0] := 5.0; src2[1] := 6.0; src2[2] := 7.0; src2[3] := 8.0;
  ArrayAxpyF64(-1.0, @src[0], @src2[0], @dst[0], 4);
  CheckDouble(dst[0], 4.0, 'AxpyF64 sample2[0]');
  CheckDouble(dst[3], 4.0, 'AxpyF64 sample2[3]');
end;

procedure TestBatchF32MissingFacades;
var
  src: array[0..3] of Single;
  src2: array[0..3] of Single;
  src3: array[0..3] of Single;
  edge: array[0..3] of Single;
  dst: array[0..3] of Single;
  dst2: array[0..3] of Single;
begin
  src[0] := -5.0; src[1] := 5.0; src[2] := 15.0; src[3] := 25.0;
  ArrayClampF32(@src[0], @dst[0], 4, 0.0, 20.0);
  CheckFloat(dst[0], 0.0, 'ClampF32[-5]');
  CheckFloat(dst[1], 5.0, 'ClampF32[5]');
  CheckFloat(dst[3], 20.0, 'ClampF32[25]');

  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  src2[0] := 10.0; src2[1] := 20.0; src2[2] := 30.0; src2[3] := 40.0;
  src3[0] := 100.0; src3[1] := 200.0; src3[2] := 300.0; src3[3] := 400.0;
  ArrayFmaF32(@src[0], @src2[0], @src3[0], @dst[0], 4);
  CheckFloat(dst[0], 110.0, 'FmaF32[0]');
  CheckFloat(dst[3], 560.0, 'FmaF32[3]', 1e-3);

  src[0] := 0.0; src[1] := Pi / 4; src[2] := Pi / 6; src[3] := -Pi / 4;
  ArrayTanF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.0, 'TanF32[0]');
  CheckFloat(dst[1], 1.0, 'TanF32[pi/4]', 1e-4);
  ArraySinCosF32(@src[0], @dst[0], @dst2[0], 4);
  CheckFloat(dst[0], 0.0, 'SinCosF32 Sin[0]', 1e-5);
  CheckFloat(dst2[0], 1.0, 'SinCosF32 Cos[0]', 1e-5);

  src[0] := 1.0; src[1] := 2.0; src[2] := 4.0; src[3] := 8.0;
  ArrayLog2F32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], 1.0, 'Log2F32[2]');
  CheckFloat(dst[3], 3.0, 'Log2F32[8]');
  src[0] := 1.0; src[1] := 10.0; src[2] := 100.0; src[3] := 1000.0;
  ArrayLog10F32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], 1.0, 'Log10F32[10]');
  CheckFloat(dst[2], 2.0, 'Log10F32[100]');

  src[0] := 0.0; src[1] := 1.0; src[2] := 1.0; src[3] := -1.0;
  src2[0] := 1.0; src2[1] := 0.0; src2[2] := 1.0; src2[3] := 1.0;
  ArrayAtan2F32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], 0.0, 'Atan2F32[0,1]');
  CheckFloat(dst[1], Pi / 2, 'Atan2F32[1,0]', 1e-4);
  src[0] := 3.0; src[1] := 5.0; src[2] := 8.0; src[3] := 0.0;
  src2[0] := 4.0; src2[1] := 12.0; src2[2] := 15.0; src2[3] := 1.0;
  ArrayHypotF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], 5.0, 'HypotF32[3,4]');
  CheckFloat(dst[1], 13.0, 'HypotF32[5,12]');

  src[0] := 1.2; src[1] := 2.5; src[2] := 3.7; src[3] := 4.1;
  ArrayCeilF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 2.0, 'CeilF32[1.2]');
  CheckFloat(dst[2], 4.0, 'CeilF32[3.7]');
  ArrayFloorF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'FloorF32[1.2]');
  CheckFloat(dst[1], 2.0, 'FloorF32[2.5]');
  ArrayRoundF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'RoundF32[1.2]');
  CheckFloat(dst[1], 2.0, 'RoundF32[2.5 banker]');
  ArrayTruncF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'TruncF32[1.2]');
  CheckFloat(dst[2], 3.0, 'TruncF32[3.7]');

  src[0] := 1.5; src[1] := 2.7; src[2] := -1.3; src[3] := 3.0;
  ArrayFractF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.5, 'FractF32[1.5]');
  CheckFloat(dst[1], 0.7, 'FractF32[2.7]', 1e-4);

  src[0] := 0.0; src[1] := 0.0; src[2] := 0.0; src[3] := 0.0;
  src2[0] := 10.0; src2[1] := 20.0; src2[2] := 30.0; src2[3] := 40.0;
  ArrayLerpF32(@src[0], @src2[0], @dst[0], 4, 0.5);
  CheckFloat(dst[0], 5.0, 'LerpF32[0]');
  CheckFloat(dst[1], 10.0, 'LerpF32[1]');

  src[0] := 10.0; src[1] := 11.0; src[2] := 12.0; src[3] := 13.0;
  ArrayModF32(@src[0], @dst[0], 4, 3.0);
  CheckFloat(dst[0], 1.0, 'ModF32[10,3]');
  CheckFloat(dst[2], 0.0, 'ModF32[12,3]');

  src[0] := 5.0; src[1] := -3.0; src[2] := 0.0; src[3] := 0.001;
  ArraySignF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'SignF32[5]');
  CheckFloat(dst[1], -1.0, 'SignF32[-3]');
  CheckFloat(dst[2], 0.0, 'SignF32[0]');

  edge[0] := 0.0; edge[1] := 0.0; edge[2] := 0.0; edge[3] := 0.0;
  src[0] := -1.0; src[1] := 0.0; src[2] := 1.0; src[3] := 0.5;
  ArrayStepF32(@edge[0], @src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.0, 'StepF32[-1]');
  CheckFloat(dst[1], 1.0, 'StepF32[0]');
  CheckFloat(dst[2], 1.0, 'StepF32[1]');

  edge[0] := 0.0; edge[1] := 0.0; edge[2] := 0.0; edge[3] := 0.0;
  src2[0] := 1.0; src2[1] := 1.0; src2[2] := 1.0; src2[3] := 1.0;
  src[0] := 0.0; src[1] := 0.5; src[2] := 1.0; src[3] := 0.25;
  ArraySmoothstepF32(@edge[0], @src2[0], @src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.0, 'SmoothstepF32[0]');
  CheckFloat(dst[1], 0.5, 'SmoothstepF32[0.5]', 1e-5);
  CheckFloat(dst[2], 1.0, 'SmoothstepF32[1]');
end;

procedure TestBatchF32ExtendedSecondSample;
var
  src: array[0..3] of Single;
  src2: array[0..3] of Single;
  src3: array[0..3] of Single;
  edge: array[0..3] of Single;
  dst: array[0..3] of Single;
  dst2: array[0..3] of Single;
begin
  src[0] := -2.0; src[1] := 0.5; src[2] := 5.0; src[3] := 11.0;
  ArrayClampF32(@src[0], @dst[0], 4, 0.0, 10.0);
  CheckFloat(dst[0], 0.0, 'ClampF32 sample2[0]');
  CheckFloat(dst[3], 10.0, 'ClampF32 sample2[3]');

  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  src2[0] := 4.0; src2[1] := 3.0; src2[2] := 2.0; src2[3] := 1.0;
  src3[0] := 10.0; src3[1] := 20.0; src3[2] := 30.0; src3[3] := 40.0;
  ArrayFmaF32(@src[0], @src2[0], @src3[0], @dst[0], 4);
  CheckFloat(dst[0], 14.0, 'FmaF32 sample2[0]');
  ArrayMinF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'MinF32 sample2b[0]');
  ArrayMaxF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[3], 4.0, 'MaxF32 sample2b[3]');

  src[0] := 1.0; src[1] := 2.0; src[2] := 3.0; src[3] := 4.0;
  src2[0] := 10.0; src2[1] := 20.0; src2[2] := 30.0; src2[3] := 40.0;
  ArrayAxpyF32(2.0, @src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], 12.0, 'AxpyF32 sample2[0]');
  CheckFloat(dst[3], 48.0, 'AxpyF32 sample2[3]');
  src[0] := -3.5; src[1] := 8.0; src[2] := 0.5; src[3] := 2.0;
  CheckFloat(ReduceMinF32(@src[0], 4), -3.5, 'ReduceMinF32 sample2');

  src[0] := 0.0; src[1] := Pi / 6; src[2] := Pi / 3; src[3] := -Pi / 6;
  ArrayTanF32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], 1.0 / Sqrt(3.0), 'TanF32 sample2[1]', 1e-4);
  ArraySinCosF32(@src[0], @dst[0], @dst2[0], 4);
  CheckFloat(dst[1], 0.5, 'SinCosF32 Sin sample2[1]', 1e-4);
  CheckFloat(dst2[0], 1.0, 'SinCosF32 Cos sample2[0]', 1e-4);

  src[0] := 1.0; src[1] := 4.0; src[2] := 16.0; src[3] := 32.0;
  ArrayLog2F32(@src[0], @dst[0], 4);
  CheckFloat(dst[2], 4.0, 'Log2F32 sample2[2]');
  src[0] := 1.0; src[1] := 100.0; src[2] := 1000.0; src[3] := 0.1;
  ArrayLog10F32(@src[0], @dst[0], 4);
  CheckFloat(dst[2], 3.0, 'Log10F32 sample2[2]', 1e-4);

  src[0] := 1.0; src[1] := -1.0; src[2] := 0.0; src[3] := 1.0;
  src2[0] := 1.0; src2[1] := 1.0; src2[2] := 1.0; src2[3] := 0.0;
  ArrayAtan2F32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], Pi / 4, 'Atan2F32 sample2[0]', 1e-4);
  src[0] := 6.0; src[1] := 9.0; src[2] := 0.0; src[3] := 5.0;
  src2[0] := 8.0; src2[1] := 12.0; src2[2] := 7.0; src2[3] := 12.0;
  ArrayHypotF32(@src[0], @src2[0], @dst[0], 4);
  CheckFloat(dst[0], 10.0, 'HypotF32 sample2[0]');
  CheckFloat(dst[1], 15.0, 'HypotF32 sample2[1]');

  src[0] := 1.25; src[1] := -1.75; src[2] := 2.1; src[3] := -0.25;
  ArrayCeilF32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], -1.0, 'CeilF32 sample2[1]');
  ArrayFloorF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'FloorF32 sample2[0]');
  ArrayRoundF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 1.0, 'RoundF32 sample2[0]');
  ArrayTruncF32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], -1.0, 'TruncF32 sample2[1]');
  ArrayFractF32(@src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.25, 'FractF32 sample2[0]');

  src[0] := 0.0; src[1] := 10.0; src[2] := 20.0; src[3] := 30.0;
  src2[0] := 10.0; src2[1] := 20.0; src2[2] := 30.0; src2[3] := 40.0;
  ArrayLerpF32(@src[0], @src2[0], @dst[0], 4, 0.25);
  CheckFloat(dst[0], 2.5, 'LerpF32 sample2[0]');
  src[0] := 7.0; src[1] := 8.0; src[2] := 9.0; src[3] := 10.0;
  ArrayModF32(@src[0], @dst[0], 4, 4.0);
  CheckFloat(dst[2], 1.0, 'ModF32 sample2[2]');
  src[0] := 2.0; src[1] := -4.0; src[2] := 0.0; src[3] := 0.5;
  ArraySignF32(@src[0], @dst[0], 4);
  CheckFloat(dst[1], -1.0, 'SignF32 sample2[1]');

  edge[0] := 1.0; edge[1] := 1.0; edge[2] := 1.0; edge[3] := 1.0;
  src[0] := 0.0; src[1] := 1.0; src[2] := 2.0; src[3] := 0.5;
  ArrayStepF32(@edge[0], @src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.0, 'StepF32 sample2[0]');
  CheckFloat(dst[2], 1.0, 'StepF32 sample2[2]');
  edge[0] := 0.0; edge[1] := 0.0; edge[2] := 0.0; edge[3] := 0.0;
  src2[0] := 2.0; src2[1] := 2.0; src2[2] := 2.0; src2[3] := 2.0;
  src[0] := 0.0; src[1] := 1.0; src[2] := 2.0; src[3] := 0.5;
  ArraySmoothstepF32(@edge[0], @src2[0], @src[0], @dst[0], 4);
  CheckFloat(dst[0], 0.0, 'SmoothstepF32 sample2[0]');
  CheckFloat(dst[2], 1.0, 'SmoothstepF32 sample2[2]');
end;

begin
  StartApiCoverageSuite('API Coverage Batch Math');
  TestArrayF64;
  TestBatchF64Extra;
  TestBatchF64ThinCoverageSecondSample;
  TestBatchF32RefineAndConversionSecondSample;
  TestF64ExtendedOperations;
  TestBatchF64ExtendedSecondSample;
  TestBatchF32MissingFacades;
  TestBatchF32ExtendedSecondSample;
  PrintApiCoverageSummary;
end.
