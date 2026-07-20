// === Facade Functions ===

function MemEqual_NEON(a, b: Pointer; len: SizeUInt): LongBool;
begin
  Result := MemEqual_Scalar(a, b, len);
end;

function MemFindByte_NEON(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
begin
  Result := MemFindByte_Scalar(p, len, value);
end;

function MemDiffRange_NEON(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
begin
  Result := MemDiffRange_Scalar(a, b, len, firstDiff, lastDiff);
end;

procedure MemCopy_NEON(src, dst: Pointer; len: SizeUInt);
begin
  MemCopy_Scalar(src, dst, len);
end;

procedure MemSet_NEON(dst: Pointer; len: SizeUInt; value: Byte);
begin
  MemSet_Scalar(dst, len, value);
end;

procedure MemReverse_NEON(p: Pointer; len: SizeUInt);
begin
  MemReverse_Scalar(p, len);
end;

function BytesIndexOf_NEON(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
begin
  Result := BytesIndexOf_Scalar(haystack, haystackLen, needle, needleLen);
end;

function Utf8Validate_NEON(p: Pointer; len: SizeUInt): Boolean;
begin
  Result := Utf8Validate_Scalar(p, len);
end;

function SumBytes_NEON(p: Pointer; len: SizeUInt): UInt64;
begin
  Result := SumBytes_Scalar(p, len);
end;

function CountByte_NEON(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
begin
  Result := CountByte_Scalar(p, len, value);
end;

function BitsetPopCount_NEON(p: Pointer; byteLen: SizeUInt): SizeUInt;
begin
  Result := BitsetPopCount_Scalar(p, byteLen);
end;

procedure MinMaxBytes_NEON(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
begin
  MinMaxBytes_Scalar(p, len, minVal, maxVal);
end;

procedure ToLowerAscii_NEON(p: Pointer; len: SizeUInt);
begin
  ToLowerAscii_Scalar(p, len);
end;

procedure ToUpperAscii_NEON(p: Pointer; len: SizeUInt);
begin
  ToUpperAscii_Scalar(p, len);
end;

function AsciiIEqual_NEON(a, b: Pointer; len: SizeUInt): Boolean;
begin
  Result := AsciiIEqual_Scalar(a, b, len);
end;

// === Phase 23a: BatchF32 ArrayAdd / ArraySub / ArrayMul (no-asm companions) ===

procedure NEONArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayAddF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArraySubF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayMulF32(aSrc1, aSrc2, aDst, aCount);
end;

// === Batch B1: BatchF32 ArrayDiv (no-asm companion) ===

procedure NEONArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayDivF32(aSrc1, aSrc2, aDst, aCount);
end;

// === Phase 23b: BatchF32 ArrayMin / ArrayMax / ArrayAbs / ArrayNeg (no-asm companions) ===

procedure NEONArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayMinF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayMaxF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayAbsF32(aSrc, aDst, aCount);
end;

procedure NEONArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayNegF32(aSrc, aDst, aCount);
end;

// === Batch B2: BatchF32 ArrayMulScalar / ArrayAddScalar (no-asm companions) ===

procedure NEONArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
begin
  ScalarArrayMulScalarF32(aSrc, aDst, aCount, aScalar);
end;

procedure NEONArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
begin
  ScalarArrayAddScalarF32(aSrc, aDst, aCount, aScalar);
end;

// === Batch B3: BatchF32 ArrayClamp / ArrayLerp (no-asm companions) ===

procedure NEONArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
begin
  ScalarArrayClampF32(aSrc, aDst, aCount, aMin, aMax);
end;

procedure NEONArrayLerpF32(aStart, aEnd, aDst: PSingle; aCount: SizeUInt; aT: Single);
begin
  ScalarArrayLerpF32(aStart, aEnd, aDst, aCount, aT);
end;

// === Batch B4: BatchF32 ArrayFma / ArrayAxpy (no-asm companions) ===

procedure NEONArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayFmaF32(aA, aB, aC, aDst, aCount);
end;

procedure NEONArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayAxpyF32(aAlpha, aX, aY, aDst, aCount);
end;

// === Batch B5: BatchF32 ArraySqrt / ReduceSum (no-asm companions) ===

procedure NEONArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArraySqrtF32(aSrc, aDst, aCount);
end;

function NEONReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := ScalarReduceSumF32(aSrc, aCount);
end;

// === Batch B6: BatchF32 ReduceMin / ReduceMax (no-asm companions) ===

function NEONReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := ScalarReduceMinF32(aSrc, aCount);
end;

function NEONReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := ScalarReduceMaxF32(aSrc, aCount);
end;

// === Batch B7: BatchF32 ArrayRcp / ReduceDot (no-asm companions) ===

procedure NEONArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayRcpF32(aSrc, aDst, aCount);
end;

function NEONReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
begin
  Result := ScalarReduceDotF32(aSrc1, aSrc2, aCount);
end;

// === Batch B8: BatchF32 ArrayRsqrt / ArrayRcpRefine (no-asm companions) ===

procedure NEONArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayRsqrtF32(aSrc, aDst, aCount);
end;

procedure NEONArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayRcpRefineF32(aSrc, aDst, aCount);
end;

// === Batch B9: BatchF32 ArrayRsqrtRefine (no-asm companion) ===

procedure NEONArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayRsqrtRefineF32(aSrc, aDst, aCount);
end;

// === Wave C1: BatchF32 ArrayLinear (no-asm companion) ===

procedure NEONArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
begin
  ScalarArrayLinearF32(aSrc, aDst, aCount, aScale, aBias);
end;

// === Wave C2: BatchF32 Ceil / Floor / Trunc (no-asm companions) ===

procedure NEONArrayCeilF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayCeilF32(aSrc, aDst, aCount);
end;

procedure NEONArrayFloorF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayFloorF32(aSrc, aDst, aCount);
end;

procedure NEONArrayTruncF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayTruncF32(aSrc, aDst, aCount);
end;

// === Wave C3: BatchF32 ReLU / AbsDiff (no-asm companions) ===

procedure NEONArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayReLUF32(aSrc, aDst, aCount);
end;

procedure NEONArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayAbsDiffF32(aSrc1, aSrc2, aDst, aCount);
end;

// === Wave C4a: BatchF64 core 8 (no-asm companions) ===

procedure NEONArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayAddF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArraySubF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayMulF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayDivF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayMinF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayMinF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayMaxF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayMaxF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure NEONArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayAbsF64(aSrc, aDst, aCount);
end;

procedure NEONArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayNegF64(aSrc, aDst, aCount);
end;

// === Wave C4b: BatchF64 Sqrt / broadcast / Reduce (no-asm companions) ===

procedure NEONArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArraySqrtF64(aSrc, aDst, aCount);
end;

procedure NEONArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
begin
  ScalarArrayMulScalarF64(aSrc, aDst, aCount, aScalar);
end;

procedure NEONArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
begin
  ScalarArrayAddScalarF64(aSrc, aDst, aCount, aScalar);
end;

function NEONReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  Result := ScalarReduceSumF64(aSrc, aCount);
end;

function NEONReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
begin
  Result := ScalarReduceDotF64(aSrc1, aSrc2, aCount);
end;

function NEONReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  Result := ScalarReduceMinF64(aSrc, aCount);
end;

function NEONReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin
  Result := ScalarReduceMaxF64(aSrc, aCount);
end;

// === Wave C4c: BatchF64 Linear / Clamp / Lerp / Fma / Axpy (no-asm companions) ===

procedure NEONArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
begin
  ScalarArrayLinearF64(aSrc, aDst, aCount, aScale, aBias);
end;

procedure NEONArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
begin
  ScalarArrayClampF64(aSrc, aDst, aCount, aMin, aMax);
end;

procedure NEONArrayLerpF64(aStart, aEnd, aDst: PDouble; aCount: SizeUInt; aT: Double);
begin
  ScalarArrayLerpF64(aStart, aEnd, aDst, aCount, aT);
end;

procedure NEONArrayFmaF64(aA, aB, aC, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayFmaF64(aA, aB, aC, aDst, aCount);
end;

procedure NEONArrayAxpyF64(aAlpha: Double; aX, aY, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayAxpyF64(aAlpha, aX, aY, aDst, aCount);
end;


// === Wave C4d: BatchF64 Ceil/Floor/Trunc + ReLU/AbsDiff (no-asm companions) ===

procedure NEONArrayCeilF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayCeilF64(aSrc, aDst, aCount);
end;

procedure NEONArrayFloorF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayFloorF64(aSrc, aDst, aCount);
end;

procedure NEONArrayTruncF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayTruncF64(aSrc, aDst, aCount);
end;

procedure NEONArrayReLUF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayReLUF64(aSrc, aDst, aCount);
end;

procedure NEONArrayAbsDiffF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayAbsDiffF64(aSrc1, aSrc2, aDst, aCount);
end;

// === Wave C4e: BatchF64 Rcp / Rsqrt / Refine (no-asm companions) ===

procedure NEONArrayRcpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayRcpF64(aSrc, aDst, aCount);
end;

procedure NEONArrayRsqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayRsqrtF64(aSrc, aDst, aCount);
end;

procedure NEONArrayRcpRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayRcpRefineF64(aSrc, aDst, aCount);
end;

procedure NEONArrayRsqrtRefineF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayRsqrtRefineF64(aSrc, aDst, aCount);
end;

// === Wave C5 sample: BatchF32 Sin / Exp (no-asm companions) ===

procedure NEONArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArraySinF32(aSrc, aDst, aCount);
end;

procedure NEONArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayExpF32(aSrc, aDst, aCount);
end;

// === Wave C5b: BatchF32 Cos / SinCos (no-asm companions) ===

procedure NEONArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayCosF32(aSrc, aDst, aCount);
end;

procedure NEONArraySinCosF32(aSrc, aSinDst, aCosDst: PSingle; aCount: SizeUInt);
begin
  ScalarArraySinCosF32(aSrc, aSinDst, aCosDst, aCount);
end;

// === Wave C5c: BatchF32 Log / Log2 / Log10 (no-asm companions) ===

procedure NEONArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayLogF32(aSrc, aDst, aCount);
end;

procedure NEONArrayLog2F32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayLog2F32(aSrc, aDst, aCount);
end;

procedure NEONArrayLog10F32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  ScalarArrayLog10F32(aSrc, aDst, aCount);
end;

// === Wave C5d: BatchF64 Sin / Exp (no-asm companions) ===

procedure NEONArraySinF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArraySinF64(aSrc, aDst, aCount);
end;

procedure NEONArrayExpF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin
  ScalarArrayExpF64(aSrc, aDst, aCount);
end;
