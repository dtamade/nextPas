{
   nextpas.core.simd.arrays.testcase - Arrays 单元专用测试
   覆盖 F32/F64 reduction + element-wise 40+ 函数
}
unit nextpas.core.simd.arrays.testcase;

{$I ../../src/nextpas.core.settings.inc}

interface

uses
  nextpas.core.test, nextpas.core.simd.arrays;

{$M+}
type
  TTestCase_SimdArrays = class(TTestFixture)
  published
    procedure Test_SumF32;
    procedure Test_SumF64;
    procedure Test_SumKahanF32;
    procedure Test_SumKahanF64;
    procedure Test_MinF32;
    procedure Test_MinF64;
    procedure Test_MaxF32;
    procedure Test_MaxF64;
    procedure Test_MinMaxF32;
    procedure Test_MinMaxF64;
    procedure Test_MeanF32;
    procedure Test_MeanF64;
    procedure Test_VarianceF32;
    procedure Test_VarianceF64;
    procedure Test_StdDevF32;
    procedure Test_StdDevF64;
    procedure Test_DotProductF32;
    procedure Test_DotProductF64;
    procedure Test_L2NormF32;
    procedure Test_L2NormF64;
    procedure Test_ScaleF32;
    procedure Test_ScaleF64;
    procedure Test_AbsF32;
    procedure Test_AbsF64;
    procedure Test_NegF32;
    procedure Test_SqrtF32;
    procedure Test_AddScalarF32;
    procedure Test_AddScalarF64;
    procedure Test_AddArrayF32;
    procedure Test_AddArrayF64;
    procedure Test_SubArrayF32;
    procedure Test_MulArrayF32;
    procedure Test_DivArrayF32;
    procedure Test_MinArrayF32;
    procedure Test_MaxArrayF32;
    procedure Test_ClampF32;
    procedure Test_EmptyArray;
    procedure Test_SingleElement;
  end;

implementation

const
  EPS_F32 = 1E-5;
  EPS_F64 = 1E-12;

  F32_DATA: array[0..7] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  F32_NEG:  array[0..7] of Single = (-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0);
  F32_MIX:  array[0..7] of Single = (-3.0, 1.0, -4.0, 5.0, -2.0, 6.0, -1.0, 7.0);

  F64_DATA: array[0..7] of Double = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);
  F64_NEG:  array[0..7] of Double = (-1.0, -2.0, -3.0, -4.0, -5.0, -6.0, -7.0, -8.0);
  F64_MIX:  array[0..7] of Double = (-3.0, 1.0, -4.0, 5.0, -2.0, 6.0, -1.0, 7.0);

{ Helper: approximate comparison }
function NearEqualF32(A, B, AEps: Single): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

function NearEqualF64(A, B, AEps: Double): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

{ ============================================================================
  Reduction Tests - F32
  ============================================================================ }

procedure TTestCase_SimdArrays.Test_SumF32;
begin
  CheckTrue(NearEqualF32(SimdArraySumF32(@F32_DATA[0], 8), 36.0, EPS_F32), 'Sum F32 data');
  CheckTrue(NearEqualF32(SimdArraySumF32(@F32_NEG[0], 8), -36.0, EPS_F32), 'Sum F32 neg');
  CheckTrue(NearEqualF32(SimdArraySumF32(nil, 0), 0.0, EPS_F32), 'Sum F32 nil');
end;

procedure TTestCase_SimdArrays.Test_SumF64;
begin
  CheckTrue(NearEqualF64(SimdArraySumF64(@F64_DATA[0], 8), 36.0, EPS_F64), 'Sum F64 data');
  CheckTrue(NearEqualF64(SimdArraySumF64(@F64_NEG[0], 8), -36.0, EPS_F64), 'Sum F64 neg');
  CheckTrue(NearEqualF64(SimdArraySumF64(nil, 0), 0.0, EPS_F64), 'Sum F64 nil');
end;

procedure TTestCase_SimdArrays.Test_SumKahanF32;
begin
  CheckTrue(NearEqualF32(SimdArraySumKahanF32(@F32_DATA[0], 8), 36.0, EPS_F32), 'Kahan F32 data');
  CheckTrue(NearEqualF32(SimdArraySumKahanF32(@F32_NEG[0], 8), -36.0, EPS_F32), 'Kahan F32 neg');
end;

procedure TTestCase_SimdArrays.Test_SumKahanF64;
begin
  CheckTrue(NearEqualF64(SimdArraySumKahanF64(@F64_DATA[0], 8), 36.0, EPS_F64), 'Kahan F64 data');
  CheckTrue(NearEqualF64(SimdArraySumKahanF64(@F64_NEG[0], 8), -36.0, EPS_F64), 'Kahan F64 neg');
end;

{ ============================================================================
  Min/Max Tests
  ============================================================================ }

procedure TTestCase_SimdArrays.Test_MinF32;
begin
  CheckTrue(NearEqualF32(SimdArrayMinF32(@F32_DATA[0], 8), 1.0, EPS_F32), 'Min F32 data');
  CheckTrue(NearEqualF32(SimdArrayMinF32(@F32_NEG[0], 8), -8.0, EPS_F32), 'Min F32 neg');
end;

procedure TTestCase_SimdArrays.Test_MinF64;
begin
  CheckTrue(NearEqualF64(SimdArrayMinF64(@F64_DATA[0], 8), 1.0, EPS_F64), 'Min F64 data');
  CheckTrue(NearEqualF64(SimdArrayMinF64(@F64_NEG[0], 8), -8.0, EPS_F64), 'Min F64 neg');
end;

procedure TTestCase_SimdArrays.Test_MaxF32;
begin
  CheckTrue(NearEqualF32(SimdArrayMaxF32(@F32_DATA[0], 8), 8.0, EPS_F32), 'Max F32 data');
  CheckTrue(NearEqualF32(SimdArrayMaxF32(@F32_NEG[0], 8), -1.0, EPS_F32), 'Max F32 neg');
end;

procedure TTestCase_SimdArrays.Test_MaxF64;
begin
  CheckTrue(NearEqualF64(SimdArrayMaxF64(@F64_DATA[0], 8), 8.0, EPS_F64), 'Max F64 data');
  CheckTrue(NearEqualF64(SimdArrayMaxF64(@F64_NEG[0], 8), -1.0, EPS_F64), 'Max F64 neg');
end;

procedure TTestCase_SimdArrays.Test_MinMaxF32;
var
  LMin, LMax: Single;
begin
  SimdArrayMinMaxF32(@F32_DATA[0], 8, LMin, LMax);
  CheckTrue(NearEqualF32(LMin, 1.0, EPS_F32), 'MinMax F32 min');
  CheckTrue(NearEqualF32(LMax, 8.0, EPS_F32), 'MinMax F32 max');

  SimdArrayMinMaxF32(@F32_MIX[0], 8, LMin, LMax);
  CheckTrue(NearEqualF32(LMin, -4.0, EPS_F32), 'MinMax F32 mix min');
  CheckTrue(NearEqualF32(LMax, 7.0, EPS_F32), 'MinMax F32 mix max');
end;

procedure TTestCase_SimdArrays.Test_MinMaxF64;
var
  LMin, LMax: Double;
begin
  SimdArrayMinMaxF64(@F64_DATA[0], 8, LMin, LMax);
  CheckTrue(NearEqualF64(LMin, 1.0, EPS_F64), 'MinMax F64 min');
  CheckTrue(NearEqualF64(LMax, 8.0, EPS_F64), 'MinMax F64 max');
end;

{ ============================================================================
  Mean/Variance/StdDev Tests
  ============================================================================ }

procedure TTestCase_SimdArrays.Test_MeanF32;
begin
  CheckTrue(NearEqualF32(SimdArrayMeanF32(@F32_DATA[0], 8), 4.5, EPS_F32), 'Mean F32 data');
  CheckTrue(NearEqualF32(SimdArrayMeanF32(nil, 0), 0.0, EPS_F32), 'Mean F32 empty');
end;

procedure TTestCase_SimdArrays.Test_MeanF64;
begin
  CheckTrue(NearEqualF64(SimdArrayMeanF64(@F64_DATA[0], 8), 4.5, EPS_F64), 'Mean F64 data');
end;

procedure TTestCase_SimdArrays.Test_VarianceF32;
begin
  // Var([1..8]) with Bessel correction = 6.0
  CheckTrue(NearEqualF32(SimdArrayVarianceF32(@F32_DATA[0], 8), 6.0, EPS_F32), 'Variance F32');
end;

procedure TTestCase_SimdArrays.Test_VarianceF64;
begin
  CheckTrue(NearEqualF64(SimdArrayVarianceF64(@F64_DATA[0], 8), 6.0, EPS_F64), 'Variance F64');
end;

procedure TTestCase_SimdArrays.Test_StdDevF32;
begin
  // StdDev = sqrt(6.0) ~ 2.4495
  CheckTrue(NearEqualF32(SimdArrayStdDevF32(@F32_DATA[0], 8), 2.4495, 1E-3), 'StdDev F32');
end;

procedure TTestCase_SimdArrays.Test_StdDevF64;
begin
  CheckTrue(NearEqualF64(SimdArrayStdDevF64(@F64_DATA[0], 8), 2.4495, 1E-4), 'StdDev F64');
end;

{ ============================================================================
  DotProduct / L2Norm Tests
  ============================================================================ }

procedure TTestCase_SimdArrays.Test_DotProductF32;
begin
  // dot([1..8], [1..8]) = 1+4+9+16+25+36+49+64 = 204
  CheckTrue(NearEqualF32(SimdArrayDotProductF32(@F32_DATA[0], @F32_DATA[0], 8), 204.0, EPS_F32), 'Dot F32');
end;

procedure TTestCase_SimdArrays.Test_DotProductF64;
begin
  CheckTrue(NearEqualF64(SimdArrayDotProductF64(@F64_DATA[0], @F64_DATA[0], 8), 204.0, EPS_F64), 'Dot F64');
end;

procedure TTestCase_SimdArrays.Test_L2NormF32;
begin
  // norm = sqrt(204) ~ 14.2829
  CheckTrue(NearEqualF32(SimdArrayL2NormF32(@F32_DATA[0], 8), 14.2829, 1E-3), 'L2Norm F32');
end;

procedure TTestCase_SimdArrays.Test_L2NormF64;
begin
  CheckTrue(NearEqualF64(SimdArrayL2NormF64(@F64_DATA[0], 8), 14.2829, 1E-4), 'L2Norm F64');
end;

{ ============================================================================
  Element-wise Tests - F32
  ============================================================================ }

procedure TTestCase_SimdArrays.Test_ScaleF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayScaleF32(@F32_DATA[0], @LDst[0], 8, 2.0);
  CheckTrue(NearEqualF32(LDst[0], 2.0, EPS_F32), 'Scale F32 first');
  CheckTrue(NearEqualF32(LDst[7], 16.0, EPS_F32), 'Scale F32 last');
end;

procedure TTestCase_SimdArrays.Test_ScaleF64;
var
  LDst: array[0..7] of Double;
begin
  SimdArrayScaleF64(@F64_DATA[0], @LDst[0], 8, 3.0);
  CheckTrue(NearEqualF64(LDst[0], 3.0, EPS_F64), 'Scale F64 first');
  CheckTrue(NearEqualF64(LDst[7], 24.0, EPS_F64), 'Scale F64 last');
end;

procedure TTestCase_SimdArrays.Test_AbsF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayAbsF32(@F32_NEG[0], @LDst[0], 8);
  CheckTrue(NearEqualF32(LDst[0], 1.0, EPS_F32), 'Abs F32 first');
  CheckTrue(NearEqualF32(LDst[7], 8.0, EPS_F32), 'Abs F32 last');
end;

procedure TTestCase_SimdArrays.Test_AbsF64;
var
  LDst: array[0..7] of Double;
begin
  SimdArrayAbsF64(@F64_NEG[0], @LDst[0], 8);
  CheckTrue(NearEqualF64(LDst[0], 1.0, EPS_F64), 'Abs F64 first');
  CheckTrue(NearEqualF64(LDst[7], 8.0, EPS_F64), 'Abs F64 last');
end;

procedure TTestCase_SimdArrays.Test_NegF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayNegF32(@F32_DATA[0], @LDst[0], 8);
  CheckTrue(NearEqualF32(LDst[0], -1.0, EPS_F32), 'Neg F32 first');
  CheckTrue(NearEqualF32(LDst[7], -8.0, EPS_F32), 'Neg F32 last');
end;

procedure TTestCase_SimdArrays.Test_SqrtF32;
var
  LDst: array[0..3] of Single;
  LSrc: array[0..3] of Single = (4.0, 9.0, 16.0, 25.0);
begin
  SimdArraySqrtF32(@LSrc[0], @LDst[0], 4);
  CheckTrue(NearEqualF32(LDst[0], 2.0, EPS_F32), 'Sqrt 4');
  CheckTrue(NearEqualF32(LDst[1], 3.0, EPS_F32), 'Sqrt 9');
  CheckTrue(NearEqualF32(LDst[2], 4.0, EPS_F32), 'Sqrt 16');
  CheckTrue(NearEqualF32(LDst[3], 5.0, EPS_F32), 'Sqrt 25');
end;

procedure TTestCase_SimdArrays.Test_AddScalarF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayAddF32(@F32_DATA[0], @LDst[0], 8, 10.0);
  CheckTrue(NearEqualF32(LDst[0], 11.0, EPS_F32), 'Add scalar F32 first');
  CheckTrue(NearEqualF32(LDst[7], 18.0, EPS_F32), 'Add scalar F32 last');
end;

procedure TTestCase_SimdArrays.Test_AddScalarF64;
var
  LDst: array[0..7] of Double;
begin
  SimdArrayAddF64(@F64_DATA[0], @LDst[0], 8, 10.0);
  CheckTrue(NearEqualF64(LDst[0], 11.0, EPS_F64), 'Add scalar F64 first');
  CheckTrue(NearEqualF64(LDst[7], 18.0, EPS_F64), 'Add scalar F64 last');
end;

procedure TTestCase_SimdArrays.Test_AddArrayF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayAddArrayF32(@F32_DATA[0], @F32_NEG[0], @LDst[0], 8);
  // [1..8] + [-1..-8] = [0,0,0,0,0,0,0,0]
  CheckTrue(NearEqualF32(LDst[0], 0.0, EPS_F32), 'AddArray F32 first');
  CheckTrue(NearEqualF32(LDst[7], 0.0, EPS_F32), 'AddArray F32 last');
end;

procedure TTestCase_SimdArrays.Test_AddArrayF64;
var
  LDst: array[0..7] of Double;
begin
  SimdArrayAddArrayF64(@F64_DATA[0], @F64_NEG[0], @LDst[0], 8);
  CheckTrue(NearEqualF64(LDst[0], 0.0, EPS_F64), 'AddArray F64 first');
  CheckTrue(NearEqualF64(LDst[7], 0.0, EPS_F64), 'AddArray F64 last');
end;

procedure TTestCase_SimdArrays.Test_SubArrayF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArraySubArrayF32(@F32_DATA[0], @F32_NEG[0], @LDst[0], 8);
  // [1..8] - [-1..-8] = [2,4,6,8,10,12,14,16]
  CheckTrue(NearEqualF32(LDst[0], 2.0, EPS_F32), 'SubArray F32 first');
  CheckTrue(NearEqualF32(LDst[7], 16.0, EPS_F32), 'SubArray F32 last');
end;

procedure TTestCase_SimdArrays.Test_MulArrayF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayMulArrayF32(@F32_DATA[0], @F32_DATA[0], @LDst[0], 8);
  // [1..8] * [1..8] = [1,4,9,16,25,36,49,64]
  CheckTrue(NearEqualF32(LDst[0], 1.0, EPS_F32), 'MulArray F32 first');
  CheckTrue(NearEqualF32(LDst[3], 16.0, EPS_F32), 'MulArray F32 mid');
  CheckTrue(NearEqualF32(LDst[7], 64.0, EPS_F32), 'MulArray F32 last');
end;

procedure TTestCase_SimdArrays.Test_DivArrayF32;
var
  LDst: array[0..7] of Single;
  LDiv: array[0..7] of Single = (2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0);
begin
  SimdArrayDivArrayF32(@F32_DATA[0], @LDiv[0], @LDst[0], 8);
  // [1..8] / 2 = [0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4]
  CheckTrue(NearEqualF32(LDst[0], 0.5, EPS_F32), 'DivArray F32 first');
  CheckTrue(NearEqualF32(LDst[7], 4.0, EPS_F32), 'DivArray F32 last');
end;

procedure TTestCase_SimdArrays.Test_MinArrayF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayMinArrayF32(@F32_DATA[0], @F32_NEG[0], @LDst[0], 8);
  // min([1..8], [-1..-8]) = [-1,-2,-3,-4,-5,-6,-7,-8]
  CheckTrue(NearEqualF32(LDst[0], -1.0, EPS_F32), 'MinArray F32 first');
  CheckTrue(NearEqualF32(LDst[7], -8.0, EPS_F32), 'MinArray F32 last');
end;

procedure TTestCase_SimdArrays.Test_MaxArrayF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayMaxArrayF32(@F32_DATA[0], @F32_NEG[0], @LDst[0], 8);
  // max([1..8], [-1..-8]) = [1,2,3,4,5,6,7,8]
  CheckTrue(NearEqualF32(LDst[0], 1.0, EPS_F32), 'MaxArray F32 first');
  CheckTrue(NearEqualF32(LDst[7], 8.0, EPS_F32), 'MaxArray F32 last');
end;

procedure TTestCase_SimdArrays.Test_ClampF32;
var
  LDst: array[0..7] of Single;
begin
  SimdArrayClampF32(@F32_MIX[0], @LDst[0], 8, -2.0, 5.0);
  // clamp([-3,1,-4,5,-2,6,-1,7], -2, 5) = [-2,1,-2,5,-2,5,-1,5]
  CheckTrue(NearEqualF32(LDst[0], -2.0, EPS_F32), 'Clamp F32 lo');
  CheckTrue(NearEqualF32(LDst[2], -2.0, EPS_F32), 'Clamp F32 lo2');
  CheckTrue(NearEqualF32(LDst[5], 5.0, EPS_F32), 'Clamp F32 hi');
  CheckTrue(NearEqualF32(LDst[7], 5.0, EPS_F32), 'Clamp F32 hi2');
end;

{ ============================================================================
  Edge Cases
  ============================================================================ }

procedure TTestCase_SimdArrays.Test_EmptyArray;
begin
  CheckTrue(NearEqualF32(SimdArraySumF32(nil, 0), 0.0, EPS_F32), 'Empty sum F32');
  CheckTrue(NearEqualF64(SimdArraySumF64(nil, 0), 0.0, EPS_F64), 'Empty sum F64');
  CheckTrue(NearEqualF32(SimdArrayMeanF32(nil, 0), 0.0, EPS_F32), 'Empty mean F32');
  CheckTrue(NearEqualF64(SimdArrayMeanF64(nil, 0), 0.0, EPS_F64), 'Empty mean F64');
end;

procedure TTestCase_SimdArrays.Test_SingleElement;
var
  LSingleF32: Single = 42.0;
  LSingleF64: Double = 42.0;
begin
  CheckTrue(NearEqualF32(SimdArraySumF32(@LSingleF32, 1), 42.0, EPS_F32), 'Single sum F32');
  CheckTrue(NearEqualF64(SimdArraySumF64(@LSingleF64, 1), 42.0, EPS_F64), 'Single sum F64');
  CheckTrue(NearEqualF32(SimdArrayMinF32(@LSingleF32, 1), 42.0, EPS_F32), 'Single min F32');
  CheckTrue(NearEqualF32(SimdArrayMaxF32(@LSingleF32, 1), 42.0, EPS_F32), 'Single max F32');
  CheckTrue(NearEqualF32(SimdArrayMeanF32(@LSingleF32, 1), 42.0, EPS_F32), 'Single mean F32');
end;

end.
