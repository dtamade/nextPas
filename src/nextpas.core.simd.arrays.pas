{

```text
   ______   ______     ______   ______     ______   ______
  /\  ___\ /\  __ \   /\  ___\ /\  __ \   /\  ___\ /\  __ \
  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \  \ \  __\ \ \  __ \
   \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\  \ \_\    \ \_\ \_\
    \/_/     \/_/\/_/   \/_/     \/_/\/_/   \/_/     \/_/\/_/  Studio

```
# nextpas.core.simd.array

## Abstract

SIMD-accelerated array operations for floating-point data.
Provides high-level array APIs that automatically dispatch to the best available
SIMD backend (Scalar/SSE2/AVX2/AVX-512/NEON).

SIMD 加速的浮点数组操作。
提供高级数组 API，自动派发到最佳可用 SIMD 后端。

## Declaration

Author:    fafafaStudio
Contact:   dtamade@gmail.com | QQ Group: 685403987 | QQ:179033731
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.simd.arrays;

{$I nextpas.core.settings.inc}

interface

// ============================================================================
// Reduction Operations - F64 (Double)
// ============================================================================

{**
 * SimdArraySumF64
 *
 * @desc
 *   Sum all elements in a Double array using SIMD acceleration.
 *   使用 SIMD 加速求 Double 数组所有元素之和。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Sum of all elements
 *}
function SimdArraySumF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArraySumKahanF64
 *
 * @desc
 *   Sum all elements using Kahan compensated summation for higher accuracy.
 *   使用 Kahan 补偿求和算法，提供更高精度的求和结果。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Sum with reduced rounding error
 *}
function SimdArraySumKahanF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayMinF64
 *
 * @desc
 *   Find minimum value in a Double array.
 *   求 Double 数组的最小值。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Minimum value (+Inf for empty array)
 *}
function SimdArrayMinF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayMaxF64
 *
 * @desc
 *   Find maximum value in a Double array.
 *   求 Double 数组的最大值。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Maximum value (-Inf for empty array)
 *}
function SimdArrayMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayMinMaxF64
 *
 * @desc
 *   Find both minimum and maximum in one pass.
 *   一次遍历同时求最小值和最大值。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @param aMin - [out] Minimum value
 * @param aMax - [out] Maximum value
 *}
procedure SimdArrayMinMaxF64(aSrc: PDouble; aCount: SizeUInt; out aMin, aMax: Double);

{**
 * SimdArrayMeanF64
 *
 * @desc
 *   Calculate arithmetic mean of a Double array.
 *   求 Double 数组的算术平均值。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Mean value (0 for empty array)
 *}
function SimdArrayMeanF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayVarianceF64
 *
 * @desc
 *   Calculate sample variance (Bessel's correction: N-1 denominator).
 *   计算样本方差（使用 N-1 作为分母）。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Sample variance (0 for count <= 1)
 *}
function SimdArrayVarianceF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayPopulationVarianceF64
 *
 * @desc
 *   Calculate population variance (N denominator).
 *   计算总体方差（使用 N 作为分母）。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Population variance (0 for empty array)
 *}
function SimdArrayPopulationVarianceF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayStdDevF64
 *
 * @desc
 *   Calculate sample standard deviation.
 *   计算样本标准差。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Sample standard deviation
 *}
function SimdArrayStdDevF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayPopulationStdDevF64
 *
 * @desc
 *   Calculate population standard deviation.
 *   计算总体标准差。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns Population standard deviation
 *}
function SimdArrayPopulationStdDevF64(aSrc: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayDotProductF64
 *
 * @desc
 *   Calculate dot product of two Double arrays.
 *   计算两个 Double 数组的点积。
 *
 * @param aSrc1 - Pointer to first array
 * @param aSrc2 - Pointer to second array
 * @param aCount - Number of elements
 * @returns Dot product (sum of element-wise products)
 *}
function SimdArrayDotProductF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;

{**
 * SimdArrayL2NormF64
 *
 * @desc
 *   Calculate L2 norm (Euclidean length) of a Double array.
 *   计算 Double 数组的 L2 范数（欧几里得长度）。
 *
 * @param aSrc - Pointer to source array
 * @param aCount - Number of elements
 * @returns L2 norm (sqrt of sum of squares)
 *}
function SimdArrayL2NormF64(aSrc: PDouble; aCount: SizeUInt): Double;

// ============================================================================
// Reduction Operations - F32 (Single)
// ============================================================================

function SimdArraySumF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArraySumKahanF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
procedure SimdArrayMinMaxF32(aSrc: PSingle; aCount: SizeUInt; out aMin, aMax: Single);
function SimdArrayMeanF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayVarianceF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayPopulationVarianceF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayStdDevF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayPopulationStdDevF32(aSrc: PSingle; aCount: SizeUInt): Single;
function SimdArrayDotProductF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
function SimdArrayL2NormF32(aSrc: PSingle; aCount: SizeUInt): Single;

// ============================================================================
// Element-wise Operations - F64 (Double)
// ============================================================================

{**
 * SimdArrayScaleF64
 *
 * @desc
 *   Multiply all elements by a scalar factor.
 *   将所有元素乘以一个标量因子。
 *
 * @param aSrc - Pointer to source array
 * @param aDst - Pointer to destination array (can be same as aSrc for in-place)
 * @param aCount - Number of elements
 * @param aFactor - Scalar factor to multiply
 *}
procedure SimdArrayScaleF64(aSrc, aDst: PDouble; aCount: SizeUInt; aFactor: Double);

{**
 * SimdArrayAbsF64
 *
 * @desc
 *   Take absolute value of all elements.
 *   对所有元素取绝对值。
 *
 * @param aSrc - Pointer to source array
 * @param aDst - Pointer to destination array (can be same as aSrc for in-place)
 * @param aCount - Number of elements
 *}
procedure SimdArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);

{**
 * SimdArrayAddF64
 *
 * @desc
 *   Add a scalar value to all elements.
 *   对所有元素加上一个标量值。
 *
 * @param aSrc - Pointer to source array
 * @param aDst - Pointer to destination array (can be same as aSrc for in-place)
 * @param aCount - Number of elements
 * @param aValue - Scalar value to add
 *}
procedure SimdArrayAddF64(aSrc, aDst: PDouble; aCount: SizeUInt; aValue: Double);

{**
 * SimdArrayAddArrayF64
 *
 * @desc
 *   Add two arrays element-wise.
 *   两个数组逐元素相加。
 *
 * @param aSrc1 - Pointer to first source array
 * @param aSrc2 - Pointer to second source array
 * @param aDst - Pointer to destination array
 * @param aCount - Number of elements
 *}
procedure SimdArrayAddArrayF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);

// ============================================================================
// Element-wise Operations - F32 (Single)
// ============================================================================

procedure SimdArrayScaleF32(aSrc, aDst: PSingle; aCount: SizeUInt; aFactor: Single);
procedure SimdArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SimdArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayAddF32(aSrc, aDst: PSingle; aCount: SizeUInt; aValue: Single);
procedure SimdArrayAddArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArraySubArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayMulArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayDivArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayMinArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayMaxArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure SimdArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);

implementation

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.direct,
  nextpas.core.simd;

const
  // IEEE-754 special values for infinity (avoiding Math unit dependency)
  // IEEE-754 无穷常量（避免 Math 单元依赖）
  PosInfinityF64: Double = 1.0 / 0.0;
  NegInfinityF64: Double = -1.0 / 0.0;
  PosInfinityF32: Single = 1.0 / 0.0;
  NegInfinityF32: Single = -1.0 / 0.0;

// ============================================================================
// F64 Reduction Operations - Scalar Reference Implementation
// (Will be replaced by SIMD-optimized versions via dispatch)
// ============================================================================

function SimdArraySumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceSumF64(aSrc, aCount);
end;

function SimdArraySumKahanF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  LIndex: SizeUInt;
  LVec: TVecF64x4;
  LDispatch: PSimdDispatchTable;
  LHasLoadF64x4: Boolean;
  LHasReduceAddF64x4: Boolean;
  LSum, LC, LY, LT: Double;
  LBlockSum: Double;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);

  LDispatch := GetDirectDispatchTable;
  LHasLoadF64x4 := Assigned(LDispatch^.LoadF64x4);
  LHasReduceAddF64x4 := Assigned(LDispatch^.ReduceAddF64x4);

  LSum := 0.0;
  LC := 0.0;

  while aCount >= 4 do
  begin
    if LHasLoadF64x4 then
      LVec := LDispatch^.LoadF64x4(aSrc)
    else
    begin
      LVec.d[0] := aSrc[0];
      LVec.d[1] := aSrc[1];
      LVec.d[2] := aSrc[2];
      LVec.d[3] := aSrc[3];
    end;

    if LHasReduceAddF64x4 then
      LBlockSum := LDispatch^.ReduceAddF64x4(LVec)
    else
      LBlockSum := LVec.d[0] + LVec.d[1] + LVec.d[2] + LVec.d[3];

    LY := LBlockSum - LC;
    LT := LSum + LY;
    LC := (LT - LSum) - LY;
    LSum := LT;

    Inc(aSrc, 4);
    Dec(aCount, 4);
  end;

  if aCount > 0 then
    for LIndex := 0 to aCount - 1 do
    begin
      LY := aSrc[LIndex] - LC;
      LT := LSum + LY;
      LC := (LT - LSum) - LY;
      LSum := LT;
    end;

  Result := LSum;
end;

function SimdArrayMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(PosInfinityF64);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceMinF64(aSrc, aCount);
end;

function SimdArrayMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(NegInfinityF64);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceMaxF64(aSrc, aCount);
end;

procedure SimdArrayMinMaxF64(aSrc: PDouble; aCount: SizeUInt; out aMin, aMax: Double);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
  begin
    aMin := PosInfinityF64;
    aMax := NegInfinityF64;
    Exit;
  end;
  LDispatch := GetDirectDispatchTable;
  aMin := LDispatch^.ReduceMinF64(aSrc, aCount);
  aMax := LDispatch^.ReduceMaxF64(aSrc, aCount);
end;

function SimdArrayMeanF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  if aCount = 0 then
    Exit(0.0);
  Result := SimdArraySumF64(aSrc, aCount) / aCount;
end;

function SimdArrayCenteredSumSqF64(aSrc: PDouble; aCount: SizeUInt; aMean: Double): Double;
var
  LIndex: SizeUInt;
  LVec, LMeanVec, LDiff, LSquare: TVecF64x4;
  LDispatch: PSimdDispatchTable;
  LCanVectorize: Boolean;
  LHasReduceAddF64x4: Boolean;
  LDelta: Double;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);

  LDispatch := GetDirectDispatchTable;
  LCanVectorize := Assigned(LDispatch^.LoadF64x4)
    and Assigned(LDispatch^.SubF64x4)
    and Assigned(LDispatch^.MulF64x4);
  LHasReduceAddF64x4 := Assigned(LDispatch^.ReduceAddF64x4);
  Result := 0.0;

  if LCanVectorize then
  begin
    if Assigned(LDispatch^.SplatF64x4) then
      LMeanVec := LDispatch^.SplatF64x4(aMean)
    else
    begin
      LMeanVec.d[0] := aMean;
      LMeanVec.d[1] := aMean;
      LMeanVec.d[2] := aMean;
      LMeanVec.d[3] := aMean;
    end;

    while aCount >= 4 do
    begin
      LVec := LDispatch^.LoadF64x4(aSrc);
      LDiff := LDispatch^.SubF64x4(LVec, LMeanVec);
      LSquare := LDispatch^.MulF64x4(LDiff, LDiff);

      if LHasReduceAddF64x4 then
        Result := Result + LDispatch^.ReduceAddF64x4(LSquare)
      else
        Result := Result + LSquare.d[0] + LSquare.d[1] + LSquare.d[2] + LSquare.d[3];

      Inc(aSrc, 4);
      Dec(aCount, 4);
    end;
  end;

  if aCount > 0 then
    for LIndex := 0 to aCount - 1 do
    begin
      LDelta := aSrc[LIndex] - aMean;
      Result := Result + LDelta * LDelta;
    end;
end;


function SimdArrayVarianceF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  LMean: Double;
  LSumSq: Double;
begin
  if (aSrc = nil) or (aCount <= 1) then
    Exit(0.0);

  LMean := SimdArrayMeanF64(aSrc, aCount);
  LSumSq := SimdArrayCenteredSumSqF64(aSrc, aCount, LMean);
  Result := LSumSq / (aCount - 1);
end;

function SimdArrayPopulationVarianceF64(aSrc: PDouble; aCount: SizeUInt): Double;
var
  LMean: Double;
  LSumSq: Double;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);

  LMean := SimdArrayMeanF64(aSrc, aCount);
  LSumSq := SimdArrayCenteredSumSqF64(aSrc, aCount, LMean);
  Result := LSumSq / aCount;
end;

function SimdArrayStdDevF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  Result := System.Sqrt(SimdArrayVarianceF64(aSrc, aCount));
end;

function SimdArrayPopulationStdDevF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  Result := System.Sqrt(SimdArrayPopulationVarianceF64(aSrc, aCount));
end;

function SimdArrayDotProductF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aCount = 0) then
    Exit(0.0);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceDotF64(aSrc1, aSrc2, aCount);
end;

function SimdArrayL2NormF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  Result := System.Sqrt(SimdArrayDotProductF64(aSrc, aSrc, aCount));
end;

// ============================================================================
// F32 Reduction Operations
// ============================================================================

function SimdArraySumF32(aSrc: PSingle; aCount: SizeUInt): Single;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceSumF32(aSrc, aCount);
end;

function SimdArraySumKahanF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  LIndex: SizeUInt;
  LVec: TVecF32x8;
  LDispatch: PSimdDispatchTable;
  LHasLoadF32x8: Boolean;
  LHasReduceAddF32x8: Boolean;
  LSum, LC, LY, LT: Single;
  LBlockSum: Single;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);

  LDispatch := GetDirectDispatchTable;
  LHasLoadF32x8 := Assigned(LDispatch^.LoadF32x8);
  LHasReduceAddF32x8 := Assigned(LDispatch^.ReduceAddF32x8);

  LSum := 0.0;
  LC := 0.0;

  while aCount >= 8 do
  begin
    if LHasLoadF32x8 then
      LVec := LDispatch^.LoadF32x8(aSrc)
    else
    begin
      for LIndex := 0 to 7 do
        LVec.f[LIndex] := aSrc[LIndex];
    end;

    if LHasReduceAddF32x8 then
      LBlockSum := LDispatch^.ReduceAddF32x8(LVec)
    else
      LBlockSum :=
        LVec.f[0] + LVec.f[1] + LVec.f[2] + LVec.f[3]
        + LVec.f[4] + LVec.f[5] + LVec.f[6] + LVec.f[7];

    LY := LBlockSum - LC;
    LT := LSum + LY;
    LC := (LT - LSum) - LY;
    LSum := LT;

    Inc(aSrc, 8);
    Dec(aCount, 8);
  end;

  if aCount > 0 then
    for LIndex := 0 to aCount - 1 do
    begin
      LY := aSrc[LIndex] - LC;
      LT := LSum + LY;
      LC := (LT - LSum) - LY;
      LSum := LT;
    end;

  Result := LSum;
end;

function SimdArrayMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(PosInfinityF32);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceMinF32(aSrc, aCount);
end;

function SimdArrayMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(NegInfinityF32);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceMaxF32(aSrc, aCount);
end;

procedure SimdArrayMinMaxF32(aSrc: PSingle; aCount: SizeUInt; out aMin, aMax: Single);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aCount = 0) then
  begin
    aMin := PosInfinityF32;
    aMax := NegInfinityF32;
    Exit;
  end;
  LDispatch := GetDirectDispatchTable;
  aMin := LDispatch^.ReduceMinF32(aSrc, aCount);
  aMax := LDispatch^.ReduceMaxF32(aSrc, aCount);
end;

function SimdArrayMeanF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  if aCount = 0 then
    Exit(0.0);
  Result := SimdArraySumF32(aSrc, aCount) / aCount;
end;

function SimdArrayCenteredSumSqF32(aSrc: PSingle; aCount: SizeUInt; aMean: Single): Single;
var
  LIndex: SizeUInt;
  LVec, LMeanVec, LDiff, LSquare: TVecF32x8;
  LDispatch: PSimdDispatchTable;
  LCanVectorize: Boolean;
  LHasReduceAddF32x8: Boolean;
  LDelta: Single;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);

  LDispatch := GetDirectDispatchTable;
  LCanVectorize := Assigned(LDispatch^.LoadF32x8)
    and Assigned(LDispatch^.SubF32x8)
    and Assigned(LDispatch^.MulF32x8);
  LHasReduceAddF32x8 := Assigned(LDispatch^.ReduceAddF32x8);
  Result := 0.0;

  if LCanVectorize then
  begin
    if Assigned(LDispatch^.SplatF32x8) then
      LMeanVec := LDispatch^.SplatF32x8(aMean)
    else
      for LIndex := 0 to 7 do
        LMeanVec.f[LIndex] := aMean;

    while aCount >= 8 do
    begin
      LVec := LDispatch^.LoadF32x8(aSrc);
      LDiff := LDispatch^.SubF32x8(LVec, LMeanVec);
      LSquare := LDispatch^.MulF32x8(LDiff, LDiff);

      if LHasReduceAddF32x8 then
        Result := Result + LDispatch^.ReduceAddF32x8(LSquare)
      else
        Result := Result
          + LSquare.f[0] + LSquare.f[1] + LSquare.f[2] + LSquare.f[3]
          + LSquare.f[4] + LSquare.f[5] + LSquare.f[6] + LSquare.f[7];

      Inc(aSrc, 8);
      Dec(aCount, 8);
    end;
  end;

  if aCount > 0 then
    for LIndex := 0 to aCount - 1 do
    begin
      LDelta := aSrc[LIndex] - aMean;
      Result := Result + LDelta * LDelta;
    end;
end;


function SimdArrayVarianceF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  LMean: Single;
  LSumSq: Single;
begin
  if (aSrc = nil) or (aCount <= 1) then
    Exit(0.0);

  LMean := SimdArrayMeanF32(aSrc, aCount);
  LSumSq := SimdArrayCenteredSumSqF32(aSrc, aCount, LMean);
  Result := LSumSq / (aCount - 1);
end;

function SimdArrayPopulationVarianceF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  LMean: Single;
  LSumSq: Single;
begin
  if (aSrc = nil) or (aCount = 0) then
    Exit(0.0);

  LMean := SimdArrayMeanF32(aSrc, aCount);
  LSumSq := SimdArrayCenteredSumSqF32(aSrc, aCount, LMean);
  Result := LSumSq / aCount;
end;

function SimdArrayStdDevF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := System.Sqrt(SimdArrayVarianceF32(aSrc, aCount));
end;

function SimdArrayPopulationStdDevF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := System.Sqrt(SimdArrayPopulationVarianceF32(aSrc, aCount));
end;

function SimdArrayDotProductF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aCount = 0) then
    Exit(0.0);
  LDispatch := GetDirectDispatchTable;
  Result := LDispatch^.ReduceDotF32(aSrc1, aSrc2, aCount);
end;

function SimdArrayL2NormF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := System.Sqrt(SimdArrayDotProductF32(aSrc, aSrc, aCount));
end;

// ============================================================================
// F64 Element-wise Operations
// ============================================================================

procedure SimdArrayScaleF64(aSrc, aDst: PDouble; aCount: SizeUInt; aFactor: Double);
var
  LIndex: SizeUInt;
  LVecSrc, LVecFactor, LVecDst: TVecF64x4;
  LDispatch: PSimdDispatchTable;
  LCanVectorize: Boolean;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;

  LDispatch := GetDirectDispatchTable;
  LCanVectorize := Assigned(LDispatch^.LoadF64x4)
    and Assigned(LDispatch^.StoreF64x4)
    and Assigned(LDispatch^.SplatF64x4)
    and Assigned(LDispatch^.MulF64x4);

  if LCanVectorize then
  begin
    LVecFactor := LDispatch^.SplatF64x4(aFactor);

    while aCount >= 4 do
    begin
      LVecSrc := LDispatch^.LoadF64x4(aSrc);
      LVecDst := LDispatch^.MulF64x4(LVecSrc, LVecFactor);
      LDispatch^.StoreF64x4(aDst, LVecDst);
      Inc(aSrc, 4);
      Inc(aDst, 4);
      Dec(aCount, 4);
    end;
  end;

  if aCount > 0 then
    for LIndex := 0 to aCount - 1 do
      aDst[LIndex] := aSrc[LIndex] * aFactor;
end;

procedure SimdArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayAbsF64(aSrc, aDst, aCount);
end;

procedure SimdArrayAddF64(aSrc, aDst: PDouble; aCount: SizeUInt; aValue: Double);
var
  LIndex: SizeUInt;
  LVecSrc, LVecValue, LVecDst: TVecF64x4;
  LDispatch: PSimdDispatchTable;
  LCanVectorize: Boolean;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;

  LDispatch := GetDirectDispatchTable;
  LCanVectorize := Assigned(LDispatch^.LoadF64x4)
    and Assigned(LDispatch^.StoreF64x4)
    and Assigned(LDispatch^.SplatF64x4)
    and Assigned(LDispatch^.AddF64x4);

  if LCanVectorize then
  begin
    LVecValue := LDispatch^.SplatF64x4(aValue);

    while aCount >= 4 do
    begin
      LVecSrc := LDispatch^.LoadF64x4(aSrc);
      LVecDst := LDispatch^.AddF64x4(LVecSrc, LVecValue);
      LDispatch^.StoreF64x4(aDst, LVecDst);
      Inc(aSrc, 4);
      Inc(aDst, 4);
      Dec(aCount, 4);
    end;
  end;

  if aCount > 0 then
    for LIndex := 0 to aCount - 1 do
      aDst[LIndex] := aSrc[LIndex] + aValue;
end;

procedure SimdArrayAddArrayF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayAddF64(aSrc1, aSrc2, aDst, aCount);
end;

// ============================================================================
// F32 Element-wise Operations
// ============================================================================

procedure SimdArrayScaleF32(aSrc, aDst: PSingle; aCount: SizeUInt; aFactor: Single);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayMulScalarF32(aSrc, aDst, aCount, aFactor);
end;

procedure SimdArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;

  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayAbsF32(aSrc, aDst, aCount);
end;

procedure SimdArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;

  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayNegF32(aSrc, aDst, aCount);
end;

procedure SimdArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;

  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArraySqrtF32(aSrc, aDst, aCount);
end;

procedure SimdArrayAddF32(aSrc, aDst: PSingle; aCount: SizeUInt; aValue: Single);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayAddScalarF32(aSrc, aDst, aCount, aValue);
end;

procedure SimdArrayAddArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayAddF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArraySubArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArraySubF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayMulArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayMulF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayDivArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayDivF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayMinArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayMinF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayMaxArrayF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc1 = nil) or (aSrc2 = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayMaxF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure SimdArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var LDispatch: PSimdDispatchTable;
begin
  if (aSrc = nil) or (aDst = nil) or (aCount = 0) then
    Exit;
  LDispatch := GetDirectDispatchTable;
  LDispatch^.ArrayClampF32(aSrc, aDst, aCount, aMin, aMax);
end;

end.
