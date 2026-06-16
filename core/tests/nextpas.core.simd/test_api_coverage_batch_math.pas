program test_api_coverage_batch_math;

{$mode objfpc}{$H+}
{$Q-}{$R-}

uses
  nextpas.core.text.conv,
  Math,
  nextpas.core.simd,
  nextpas.core.simd.api_coverage.support;

procedure TestArrayF64;
var
  src: array[0..3] of Double;
  src2: array[0..3] of Double;
  src3: array[0..3] of Double;
  dst: array[0..3] of Double;
begin
  src[0] := 0; src[1] := Pi / 2; src[2] := Pi; src[3] := 1;
  ArraySinF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Sin[0]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Sin[pi/2]');
  ArrayCosF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 1.0) < 1e-10, 'Cos[0]');
  src[0] := 1; src[1] := Exp(1.0); src[2] := Exp(2.0); src[3] := 1;
  ArrayLogF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0]) < 1e-10, 'Log[1]');
  Check(Abs(dst[1] - 1.0) < 1e-10, 'Log[e]');
  src[0] := 0; src[1] := 1; src[2] := 2; src[3] := 3;
  ArrayExpF64(@src[0], @dst[0], 4);
  Check(Abs(dst[0] - 1.0) < 1e-10, 'Exp[0]');
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

begin
  StartApiCoverageSuite('API Coverage Batch Math');
  TestArrayF64;
  TestBatchF64Extra;
  TestBatchF64ThinCoverageSecondSample;
  TestBatchF32RefineAndConversionSecondSample;
  PrintApiCoverageSummary;
end.
