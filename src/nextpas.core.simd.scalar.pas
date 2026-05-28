unit nextpas.core.simd.scalar;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// === Scalar Backend Implementation ===
// This provides the reference implementation for all SIMD operations
// using pure scalar code. It serves as:
// 1. Fallback when no SIMD hardware is available
// 2. Reference for correctness testing
// 3. Performance baseline

// Register the scalar backend
procedure RegisterScalarBackend;

// === 标量门面函数声明 ===

// 内存操作函数
function MemEqual_Scalar(a, b: Pointer; len: SizeUInt): LongBool;
function MemFindByte_Scalar(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
function MemDiffRange_Scalar(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
procedure MemCopy_Scalar(src, dst: Pointer; len: SizeUInt);
procedure MemSet_Scalar(dst: Pointer; len: SizeUInt; value: Byte);
procedure MemReverse_Scalar(p: Pointer; len: SizeUInt);

// 统计函数
function SumBytes_Scalar(p: Pointer; len: SizeUInt): UInt64;
procedure MinMaxBytes_Scalar(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
function CountByte_Scalar(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;

// 文本处理函数
function Utf8Validate_Scalar(p: Pointer; len: SizeUInt): Boolean;
function AsciiIEqual_Scalar(a, b: Pointer; len: SizeUInt): Boolean;
procedure ToLowerAscii_Scalar(p: Pointer; len: SizeUInt);
procedure ToUpperAscii_Scalar(p: Pointer; len: SizeUInt);

// 搜索函数
function BytesIndexOf_Scalar(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;

// 位集函数
function BitsetPopCount_Scalar(p: Pointer; byteLen: SizeUInt): SizeUInt;

// === Batch Array Operations ===
procedure ScalarArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
procedure ScalarArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
procedure ScalarArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
procedure ScalarArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
function ScalarReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
function ScalarReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
function ScalarReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
function ScalarReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;

// === Batch Array Operations - F64 ===
procedure ScalarArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
procedure ScalarArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
procedure ScalarArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
procedure ScalarArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
function ScalarReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
function ScalarReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
function ScalarReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
function ScalarReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
procedure ScalarArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
procedure ScalarArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
procedure ScalarArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
procedure ScalarArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
procedure ScalarArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
procedure ScalarArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
procedure ScalarArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);

// === Batch Array Operations - Transcendental F32 ===
procedure ScalarArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
procedure ScalarArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);

// === Batch Array Operations - Integer ===
procedure ScalarArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
procedure ScalarArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
procedure ScalarArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
procedure ScalarArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);

// === Batch Array Operations - Type Conversion ===
procedure ScalarArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
procedure ScalarArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);

// === Batch Array Operations - Bitwise (I32) ===
procedure ScalarArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
procedure ScalarArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
procedure ScalarArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
procedure ScalarArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
procedure ScalarArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);

// === Fused Batch Operations ===
procedure ScalarArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
procedure ScalarArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ScalarArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
procedure ScalarArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);

// === 基础向量/数值参考实现（供其他后端回退使用） ===
// Arithmetic
function ScalarAddF32x4(const a, b: TVecF32x4): TVecF32x4;
function ScalarSubF32x4(const a, b: TVecF32x4): TVecF32x4;
function ScalarMulF32x4(const a, b: TVecF32x4): TVecF32x4;
function ScalarDivF32x4(const a, b: TVecF32x4): TVecF32x4;

function ScalarAddF32x8(const a, b: TVecF32x8): TVecF32x8;
function ScalarSubF32x8(const a, b: TVecF32x8): TVecF32x8;
function ScalarMulF32x8(const a, b: TVecF32x8): TVecF32x8;
function ScalarDivF32x8(const a, b: TVecF32x8): TVecF32x8;

function ScalarAddF64x2(const a, b: TVecF64x2): TVecF64x2;
function ScalarSubF64x2(const a, b: TVecF64x2): TVecF64x2;
function ScalarMulF64x2(const a, b: TVecF64x2): TVecF64x2;
function ScalarDivF64x2(const a, b: TVecF64x2): TVecF64x2;

// F64x4 Arithmetic (256-bit)
function ScalarAddF64x4(const a, b: TVecF64x4): TVecF64x4;
function ScalarSubF64x4(const a, b: TVecF64x4): TVecF64x4;
function ScalarMulF64x4(const a, b: TVecF64x4): TVecF64x4;
function ScalarDivF64x4(const a, b: TVecF64x4): TVecF64x4;

function ScalarAddI32x4(const a, b: TVecI32x4): TVecI32x4;
function ScalarSubI32x4(const a, b: TVecI32x4): TVecI32x4;
function ScalarMulI32x4(const a, b: TVecI32x4): TVecI32x4;
// I32x4 Bitwise
function ScalarAndI32x4(const a, b: TVecI32x4): TVecI32x4;
function ScalarOrI32x4(const a, b: TVecI32x4): TVecI32x4;
function ScalarXorI32x4(const a, b: TVecI32x4): TVecI32x4;
function ScalarNotI32x4(const a: TVecI32x4): TVecI32x4;
function ScalarAndNotI32x4(const a, b: TVecI32x4): TVecI32x4;
// I32x4 Shift
function ScalarShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
function ScalarShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
function ScalarShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
// I32x4 Comparison
function ScalarCmpEqI32x4(const a, b: TVecI32x4): TMask4;
function ScalarCmpLtI32x4(const a, b: TVecI32x4): TMask4;
function ScalarCmpGtI32x4(const a, b: TVecI32x4): TMask4;
function ScalarCmpLeI32x4(const a, b: TVecI32x4): TMask4;
function ScalarCmpGeI32x4(const a, b: TVecI32x4): TMask4;
function ScalarCmpNeI32x4(const a, b: TVecI32x4): TMask4;
// I32x4 MinMax
function ScalarMinI32x4(const a, b: TVecI32x4): TVecI32x4;
function ScalarMaxI32x4(const a, b: TVecI32x4): TVecI32x4;

// I64x2 Arithmetic
function ScalarAddI64x2(const a, b: TVecI64x2): TVecI64x2;
function ScalarSubI64x2(const a, b: TVecI64x2): TVecI64x2;
// I64x2 Bitwise
function ScalarAndI64x2(const a, b: TVecI64x2): TVecI64x2;
function ScalarOrI64x2(const a, b: TVecI64x2): TVecI64x2;
function ScalarXorI64x2(const a, b: TVecI64x2): TVecI64x2;
function ScalarNotI64x2(const a: TVecI64x2): TVecI64x2;
function ScalarAndNotI64x2(const a, b: TVecI64x2): TVecI64x2;
function ScalarShiftLeftI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
function ScalarShiftRightI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
function ScalarShiftRightArithI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
// I64x2 Comparison
function ScalarCmpEqI64x2(const a, b: TVecI64x2): TMask2;
function ScalarCmpLtI64x2(const a, b: TVecI64x2): TMask2;
function ScalarCmpGtI64x2(const a, b: TVecI64x2): TMask2;
function ScalarCmpLeI64x2(const a, b: TVecI64x2): TMask2;
function ScalarCmpGeI64x2(const a, b: TVecI64x2): TMask2;
function ScalarCmpNeI64x2(const a, b: TVecI64x2): TMask2;
function ScalarMinI64x2(const a, b: TVecI64x2): TVecI64x2;
function ScalarMaxI64x2(const a, b: TVecI64x2): TVecI64x2;

// U64x2 Operations
function ScalarAddU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarSubU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarAndU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarOrU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarXorU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarNotU64x2(const a: TVecU64x2): TVecU64x2;
function ScalarAndNotU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarCmpEqU64x2(const a, b: TVecU64x2): TMask2;
function ScalarCmpLtU64x2(const a, b: TVecU64x2): TMask2;
function ScalarCmpGtU64x2(const a, b: TVecU64x2): TMask2;
function ScalarMinU64x2(const a, b: TVecU64x2): TVecU64x2;
function ScalarMaxU64x2(const a, b: TVecU64x2): TVecU64x2;

// I64x4 Operations (256-bit, 4x64-bit signed)
// I64x4 Arithmetic
function ScalarAddI64x4(const a, b: TVecI64x4): TVecI64x4;
function ScalarSubI64x4(const a, b: TVecI64x4): TVecI64x4;
// I64x4 Bitwise
function ScalarAndI64x4(const a, b: TVecI64x4): TVecI64x4;
function ScalarOrI64x4(const a, b: TVecI64x4): TVecI64x4;
function ScalarXorI64x4(const a, b: TVecI64x4): TVecI64x4;
function ScalarNotI64x4(const a: TVecI64x4): TVecI64x4;
function ScalarAndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
// I64x4 Shift
function ScalarShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
function ScalarShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
function ScalarShiftRightArithI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
// I64x4 Comparison
function ScalarCmpEqI64x4(const a, b: TVecI64x4): TMask4;
function ScalarCmpLtI64x4(const a, b: TVecI64x4): TMask4;
function ScalarCmpGtI64x4(const a, b: TVecI64x4): TMask4;
function ScalarCmpLeI64x4(const a, b: TVecI64x4): TMask4;
function ScalarCmpGeI64x4(const a, b: TVecI64x4): TMask4;
function ScalarCmpNeI64x4(const a, b: TVecI64x4): TMask4;
// I64x4 Utility
function ScalarLoadI64x4(p: PInt64): TVecI64x4;
procedure ScalarStoreI64x4(p: PInt64; const a: TVecI64x4);
function ScalarSplatI64x4(value: Int64): TVecI64x4;
function ScalarZeroI64x4: TVecI64x4;

// U64x4 Operations (256-bit, 4x64-bit unsigned)
// U64x4 Arithmetic
function ScalarAddU64x4(const a, b: TVecU64x4): TVecU64x4;
function ScalarSubU64x4(const a, b: TVecU64x4): TVecU64x4;
// U64x4 Bitwise
function ScalarAndU64x4(const a, b: TVecU64x4): TVecU64x4;
function ScalarOrU64x4(const a, b: TVecU64x4): TVecU64x4;
function ScalarXorU64x4(const a, b: TVecU64x4): TVecU64x4;
function ScalarNotU64x4(const a: TVecU64x4): TVecU64x4;
// U64x4 Shift
function ScalarShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
function ScalarShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
// U64x4 Comparison (unsigned)
function ScalarCmpEqU64x4(const a, b: TVecU64x4): TMask4;
function ScalarCmpLtU64x4(const a, b: TVecU64x4): TMask4;
function ScalarCmpGtU64x4(const a, b: TVecU64x4): TMask4;
function ScalarCmpLeU64x4(const a, b: TVecU64x4): TMask4;
function ScalarCmpGeU64x4(const a, b: TVecU64x4): TMask4;
function ScalarCmpNeU64x4(const a, b: TVecU64x4): TMask4;

// I32x8 Arithmetic (256-bit)
function ScalarAddI32x8(const a, b: TVecI32x8): TVecI32x8;
function ScalarSubI32x8(const a, b: TVecI32x8): TVecI32x8;
function ScalarMulI32x8(const a, b: TVecI32x8): TVecI32x8;
// I32x8 Bitwise
function ScalarAndI32x8(const a, b: TVecI32x8): TVecI32x8;
function ScalarOrI32x8(const a, b: TVecI32x8): TVecI32x8;
function ScalarXorI32x8(const a, b: TVecI32x8): TVecI32x8;
function ScalarNotI32x8(const a: TVecI32x8): TVecI32x8;
function ScalarAndNotI32x8(const a, b: TVecI32x8): TVecI32x8;
// I32x8 Shift
function ScalarShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
function ScalarShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
function ScalarShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
// I32x8 Comparison
function ScalarCmpEqI32x8(const a, b: TVecI32x8): TMask8;
function ScalarCmpLtI32x8(const a, b: TVecI32x8): TMask8;
function ScalarCmpGtI32x8(const a, b: TVecI32x8): TMask8;
function ScalarCmpLeI32x8(const a, b: TVecI32x8): TMask8;
function ScalarCmpGeI32x8(const a, b: TVecI32x8): TMask8;
function ScalarCmpNeI32x8(const a, b: TVecI32x8): TMask8;
// I32x8 MinMax
function ScalarMinI32x8(const a, b: TVecI32x8): TVecI32x8;
function ScalarMaxI32x8(const a, b: TVecI32x8): TVecI32x8;

// F32x16 Arithmetic (512-bit)
function ScalarAddF32x16(const a, b: TVecF32x16): TVecF32x16;
function ScalarSubF32x16(const a, b: TVecF32x16): TVecF32x16;
function ScalarMulF32x16(const a, b: TVecF32x16): TVecF32x16;
function ScalarDivF32x16(const a, b: TVecF32x16): TVecF32x16;

// F64x8 Arithmetic (512-bit)
function ScalarAddF64x8(const a, b: TVecF64x8): TVecF64x8;
function ScalarSubF64x8(const a, b: TVecF64x8): TVecF64x8;
function ScalarMulF64x8(const a, b: TVecF64x8): TVecF64x8;
function ScalarDivF64x8(const a, b: TVecF64x8): TVecF64x8;

// I32x16 Arithmetic (512-bit)
function ScalarAddI32x16(const a, b: TVecI32x16): TVecI32x16;
function ScalarSubI32x16(const a, b: TVecI32x16): TVecI32x16;
function ScalarMulI32x16(const a, b: TVecI32x16): TVecI32x16;
// I32x16 Bitwise
function ScalarAndI32x16(const a, b: TVecI32x16): TVecI32x16;
function ScalarOrI32x16(const a, b: TVecI32x16): TVecI32x16;
function ScalarXorI32x16(const a, b: TVecI32x16): TVecI32x16;
function ScalarNotI32x16(const a: TVecI32x16): TVecI32x16;
function ScalarAndNotI32x16(const a, b: TVecI32x16): TVecI32x16;
// I32x16 Shift
function ScalarShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
function ScalarShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
function ScalarShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
// I32x16 Comparison
function ScalarCmpEqI32x16(const a, b: TVecI32x16): TMask16;
function ScalarCmpLtI32x16(const a, b: TVecI32x16): TMask16;
function ScalarCmpGtI32x16(const a, b: TVecI32x16): TMask16;
function ScalarCmpLeI32x16(const a, b: TVecI32x16): TMask16;
function ScalarCmpGeI32x16(const a, b: TVecI32x16): TMask16;
function ScalarCmpNeI32x16(const a, b: TVecI32x16): TMask16;
// I32x16 MinMax
function ScalarMinI32x16(const a, b: TVecI32x16): TVecI32x16;
function ScalarMaxI32x16(const a, b: TVecI32x16): TVecI32x16;

// I64x8 Arithmetic/Bitwise/Comparison (512-bit)
function ScalarAddI64x8(const a, b: TVecI64x8): TVecI64x8;
function ScalarSubI64x8(const a, b: TVecI64x8): TVecI64x8;
function ScalarAndI64x8(const a, b: TVecI64x8): TVecI64x8;
function ScalarOrI64x8(const a, b: TVecI64x8): TVecI64x8;
function ScalarXorI64x8(const a, b: TVecI64x8): TVecI64x8;
function ScalarNotI64x8(const a: TVecI64x8): TVecI64x8;
function ScalarCmpEqI64x8(const a, b: TVecI64x8): TMask8;
function ScalarCmpLtI64x8(const a, b: TVecI64x8): TMask8;
function ScalarCmpGtI64x8(const a, b: TVecI64x8): TMask8;
function ScalarCmpLeI64x8(const a, b: TVecI64x8): TMask8;
function ScalarCmpGeI64x8(const a, b: TVecI64x8): TMask8;
function ScalarCmpNeI64x8(const a, b: TVecI64x8): TMask8;

// U32x16 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit)
function ScalarAddU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarSubU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarMulU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarAndU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarOrU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarXorU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarNotU32x16(const a: TVecU32x16): TVecU32x16;
function ScalarAndNotU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarShiftLeftU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
function ScalarShiftRightU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
function ScalarCmpEqU32x16(const a, b: TVecU32x16): TMask16;
function ScalarCmpLtU32x16(const a, b: TVecU32x16): TMask16;
function ScalarCmpGtU32x16(const a, b: TVecU32x16): TMask16;
function ScalarCmpLeU32x16(const a, b: TVecU32x16): TMask16;
function ScalarCmpGeU32x16(const a, b: TVecU32x16): TMask16;
function ScalarCmpNeU32x16(const a, b: TVecU32x16): TMask16;
function ScalarMinU32x16(const a, b: TVecU32x16): TVecU32x16;
function ScalarMaxU32x16(const a, b: TVecU32x16): TVecU32x16;

// U64x8 Arithmetic/Bitwise/Shift/Comparison (512-bit)
function ScalarAddU64x8(const a, b: TVecU64x8): TVecU64x8;
function ScalarSubU64x8(const a, b: TVecU64x8): TVecU64x8;
function ScalarAndU64x8(const a, b: TVecU64x8): TVecU64x8;
function ScalarOrU64x8(const a, b: TVecU64x8): TVecU64x8;
function ScalarXorU64x8(const a, b: TVecU64x8): TVecU64x8;
function ScalarNotU64x8(const a: TVecU64x8): TVecU64x8;
function ScalarShiftLeftU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
function ScalarShiftRightU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
function ScalarCmpEqU64x8(const a, b: TVecU64x8): TMask8;
function ScalarCmpLtU64x8(const a, b: TVecU64x8): TMask8;
function ScalarCmpGtU64x8(const a, b: TVecU64x8): TMask8;
function ScalarCmpLeU64x8(const a, b: TVecU64x8): TMask8;
function ScalarCmpGeU64x8(const a, b: TVecU64x8): TMask8;
function ScalarCmpNeU64x8(const a, b: TVecU64x8): TMask8;

// I16x32 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit)
function ScalarAddI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarSubI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarAndI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarOrI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarXorI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarNotI16x32(const a: TVecI16x32): TVecI16x32;
function ScalarAndNotI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarShiftLeftI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
function ScalarShiftRightI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
function ScalarShiftRightArithI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
function ScalarCmpEqI16x32(const a, b: TVecI16x32): TMask32;
function ScalarCmpLtI16x32(const a, b: TVecI16x32): TMask32;
function ScalarCmpGtI16x32(const a, b: TVecI16x32): TMask32;
function ScalarMinI16x32(const a, b: TVecI16x32): TVecI16x32;
function ScalarMaxI16x32(const a, b: TVecI16x32): TVecI16x32;

// I8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit)
function ScalarAddI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarSubI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarAndI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarOrI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarXorI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarNotI8x64(const a: TVecI8x64): TVecI8x64;
function ScalarAndNotI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarCmpEqI8x64(const a, b: TVecI8x64): TMask64;
function ScalarCmpLtI8x64(const a, b: TVecI8x64): TMask64;
function ScalarCmpGtI8x64(const a, b: TVecI8x64): TMask64;
function ScalarMinI8x64(const a, b: TVecI8x64): TVecI8x64;
function ScalarMaxI8x64(const a, b: TVecI8x64): TVecI8x64;

// U8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit)
function ScalarAddU8x64(const a, b: TVecU8x64): TVecU8x64;
function ScalarSubU8x64(const a, b: TVecU8x64): TVecU8x64;
function ScalarAndU8x64(const a, b: TVecU8x64): TVecU8x64;
function ScalarOrU8x64(const a, b: TVecU8x64): TVecU8x64;
function ScalarXorU8x64(const a, b: TVecU8x64): TVecU8x64;
function ScalarNotU8x64(const a: TVecU8x64): TVecU8x64;
function ScalarCmpEqU8x64(const a, b: TVecU8x64): TMask64;
function ScalarCmpLtU8x64(const a, b: TVecU8x64): TMask64;
function ScalarCmpGtU8x64(const a, b: TVecU8x64): TMask64;
function ScalarMinU8x64(const a, b: TVecU8x64): TVecU8x64;
function ScalarMaxU8x64(const a, b: TVecU8x64): TVecU8x64;

// Comparison
function ScalarCmpEqF32x4(const a, b: TVecF32x4): TMask4;
function ScalarCmpLtF32x4(const a, b: TVecF32x4): TMask4;
function ScalarCmpLeF32x4(const a, b: TVecF32x4): TMask4;
function ScalarCmpGtF32x4(const a, b: TVecF32x4): TMask4;
function ScalarCmpGeF32x4(const a, b: TVecF32x4): TMask4;
function ScalarCmpNeF32x4(const a, b: TVecF32x4): TMask4;

// F64x2 比较操作
function ScalarCmpEqF64x2(const a, b: TVecF64x2): TMask2;
function ScalarCmpLtF64x2(const a, b: TVecF64x2): TMask2;
function ScalarCmpLeF64x2(const a, b: TVecF64x2): TMask2;
function ScalarCmpGtF64x2(const a, b: TVecF64x2): TMask2;
function ScalarCmpGeF64x2(const a, b: TVecF64x2): TMask2;
function ScalarCmpNeF64x2(const a, b: TVecF64x2): TMask2;

// 256-bit floating-point comparisons
// F32x8 (256-bit)
function ScalarCmpEqF32x8(const a, b: TVecF32x8): TMask8;
function ScalarCmpLtF32x8(const a, b: TVecF32x8): TMask8;
function ScalarCmpLeF32x8(const a, b: TVecF32x8): TMask8;
function ScalarCmpGtF32x8(const a, b: TVecF32x8): TMask8;
function ScalarCmpGeF32x8(const a, b: TVecF32x8): TMask8;
function ScalarCmpNeF32x8(const a, b: TVecF32x8): TMask8;
// F64x4 (256-bit)
function ScalarCmpEqF64x4(const a, b: TVecF64x4): TMask4;
function ScalarCmpLtF64x4(const a, b: TVecF64x4): TMask4;
function ScalarCmpLeF64x4(const a, b: TVecF64x4): TMask4;
function ScalarCmpGtF64x4(const a, b: TVecF64x4): TMask4;
function ScalarCmpGeF64x4(const a, b: TVecF64x4): TMask4;
function ScalarCmpNeF64x4(const a, b: TVecF64x4): TMask4;

// 512-bit floating-point comparisons
function ScalarCmpEqF32x16(const a, b: TVecF32x16): TMask16;
function ScalarCmpLtF32x16(const a, b: TVecF32x16): TMask16;
function ScalarCmpLeF32x16(const a, b: TVecF32x16): TMask16;
function ScalarCmpGtF32x16(const a, b: TVecF32x16): TMask16;
function ScalarCmpGeF32x16(const a, b: TVecF32x16): TMask16;
function ScalarCmpNeF32x16(const a, b: TVecF32x16): TMask16;
function ScalarCmpEqF64x8(const a, b: TVecF64x8): TMask8;
function ScalarCmpLtF64x8(const a, b: TVecF64x8): TMask8;
function ScalarCmpLeF64x8(const a, b: TVecF64x8): TMask8;
function ScalarCmpGtF64x8(const a, b: TVecF64x8): TMask8;
function ScalarCmpGeF64x8(const a, b: TVecF64x8): TMask8;
function ScalarCmpNeF64x8(const a, b: TVecF64x8): TMask8;

// Math
function ScalarAbsF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarSqrtF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarMinF32x4(const a, b: TVecF32x4): TVecF32x4;
function ScalarMaxF32x4(const a, b: TVecF32x4): TVecF32x4;

// F64x2 Math
function ScalarAbsF64x2(const a: TVecF64x2): TVecF64x2;
function ScalarSqrtF64x2(const a: TVecF64x2): TVecF64x2;
function ScalarMinF64x2(const a, b: TVecF64x2): TVecF64x2;
function ScalarMaxF64x2(const a, b: TVecF64x2): TVecF64x2;
function ScalarClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;

// F32x8 Math
function ScalarAbsF32x8(const a: TVecF32x8): TVecF32x8;
function ScalarSqrtF32x8(const a: TVecF32x8): TVecF32x8;
function ScalarMinF32x8(const a, b: TVecF32x8): TVecF32x8;
function ScalarMaxF32x8(const a, b: TVecF32x8): TVecF32x8;
function ScalarClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8;

// F64x4 Math
function ScalarAbsF64x4(const a: TVecF64x4): TVecF64x4;
function ScalarSqrtF64x4(const a: TVecF64x4): TVecF64x4;
function ScalarMinF64x4(const a, b: TVecF64x4): TVecF64x4;
function ScalarMaxF64x4(const a, b: TVecF64x4): TVecF64x4;
function ScalarClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;

// 512-bit float math
function ScalarAbsF32x16(const a: TVecF32x16): TVecF32x16;
function ScalarSqrtF32x16(const a: TVecF32x16): TVecF32x16;
function ScalarMinF32x16(const a, b: TVecF32x16): TVecF32x16;
function ScalarMaxF32x16(const a, b: TVecF32x16): TVecF32x16;
function ScalarClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
function ScalarAbsF64x8(const a: TVecF64x8): TVecF64x8;
function ScalarSqrtF64x8(const a: TVecF64x8): TVecF64x8;
function ScalarMinF64x8(const a, b: TVecF64x8): TVecF64x8;
function ScalarMaxF64x8(const a, b: TVecF64x8): TVecF64x8;
function ScalarClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;

// Reduction
function ScalarReduceAddF32x4(const a: TVecF32x4): Single;
function ScalarReduceMinF32x4(const a: TVecF32x4): Single;
function ScalarReduceMaxF32x4(const a: TVecF32x4): Single;
function ScalarReduceMulF32x4(const a: TVecF32x4): Single;

// F64x2 Reduction
function ScalarReduceAddF64x2(const a: TVecF64x2): Double;
function ScalarReduceMinF64x2(const a: TVecF64x2): Double;
function ScalarReduceMaxF64x2(const a: TVecF64x2): Double;
function ScalarReduceMulF64x2(const a: TVecF64x2): Double;

// F32x8 Reduction
function ScalarReduceAddF32x8(const a: TVecF32x8): Single;
function ScalarReduceMinF32x8(const a: TVecF32x8): Single;
function ScalarReduceMaxF32x8(const a: TVecF32x8): Single;
function ScalarReduceMulF32x8(const a: TVecF32x8): Single;

// F64x4 Reduction
function ScalarReduceAddF64x4(const a: TVecF64x4): Double;
function ScalarReduceMinF64x4(const a: TVecF64x4): Double;
function ScalarReduceMaxF64x4(const a: TVecF64x4): Double;
function ScalarReduceMulF64x4(const a: TVecF64x4): Double;

// 512-bit float reductions
function ScalarReduceAddF32x16(const a: TVecF32x16): Single;
function ScalarReduceMinF32x16(const a: TVecF32x16): Single;
function ScalarReduceMaxF32x16(const a: TVecF32x16): Single;
function ScalarReduceMulF32x16(const a: TVecF32x16): Single;
function ScalarReduceAddF64x8(const a: TVecF64x8): Double;
function ScalarReduceMinF64x8(const a: TVecF64x8): Double;
function ScalarReduceMaxF64x8(const a: TVecF64x8): Double;
function ScalarReduceMulF64x8(const a: TVecF64x8): Double;

// Load/Store
function ScalarLoadF32x4(p: PSingle): TVecF32x4;
function ScalarLoadF32x4Aligned(p: PSingle): TVecF32x4;
procedure ScalarStoreF32x4(p: PSingle; const a: TVecF32x4);
procedure ScalarStoreF32x4Aligned(p: PSingle; const a: TVecF32x4);

// Utility
function ScalarSplatF32x4(value: Single): TVecF32x4;
function ScalarZeroF32x4: TVecF32x4;
function ScalarSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
function ScalarExtractF32x4(const a: TVecF32x4; index: Integer): Single;
function ScalarInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;

// Extract/Insert Lane Operations
// F64x2 (128-bit)
function ScalarExtractF64x2(const a: TVecF64x2; index: Integer): Double;
function ScalarInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
// I32x4 (128-bit)
function ScalarExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
function ScalarInsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
// I64x2 (128-bit)
function ScalarExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
function ScalarInsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
// F32x8 (256-bit)
function ScalarExtractF32x8(const a: TVecF32x8; index: Integer): Single;
function ScalarInsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
// F64x4 (256-bit)
function ScalarExtractF64x4(const a: TVecF64x4; index: Integer): Double;
function ScalarInsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
// I32x8 (256-bit)
function ScalarExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
function ScalarInsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
// I64x4 (256-bit)
function ScalarExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
function ScalarInsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
// F32x16 (512-bit)
function ScalarExtractF32x16(const a: TVecF32x16; index: Integer): Single;
function ScalarInsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
// I32x16 (512-bit)
function ScalarExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
function ScalarInsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;

// 宽向量 Load/Store/Splat/Zero
// F64x2 (128-bit)
function ScalarLoadF64x2(p: PDouble): TVecF64x2;
procedure ScalarStoreF64x2(p: PDouble; const a: TVecF64x2);
function ScalarSplatF64x2(value: Double): TVecF64x2;
function ScalarZeroF64x2: TVecF64x2;
// F32x8 (256-bit)
function ScalarLoadF32x8(p: PSingle): TVecF32x8;
procedure ScalarStoreF32x8(p: PSingle; const a: TVecF32x8);
function ScalarSplatF32x8(value: Single): TVecF32x8;
function ScalarZeroF32x8: TVecF32x8;
// F64x4 (256-bit)
function ScalarLoadF64x4(p: PDouble): TVecF64x4;
procedure ScalarStoreF64x4(p: PDouble; const a: TVecF64x4);
function ScalarSplatF64x4(value: Double): TVecF64x4;
function ScalarZeroF64x4: TVecF64x4;
// F32x16 (512-bit)
function ScalarLoadF32x16(p: PSingle): TVecF32x16;
procedure ScalarStoreF32x16(p: PSingle; const a: TVecF32x16);
function ScalarSplatF32x16(value: Single): TVecF32x16;
function ScalarZeroF32x16: TVecF32x16;
// F64x8 (512-bit)
function ScalarLoadF64x8(p: PDouble): TVecF64x8;
procedure ScalarStoreF64x8(p: PDouble; const a: TVecF64x8);
function ScalarSplatF64x8(value: Double): TVecF64x8;
function ScalarZeroF64x8: TVecF64x8;

// 扩展数学函数
function ScalarFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
function ScalarRcpF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarRsqrtF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarFloorF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarCeilF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarRoundF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarTruncF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;

// 宽向量扩展数学函数
// F64x2 (128-bit)
function ScalarFmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;
function ScalarFloorF64x2(const a: TVecF64x2): TVecF64x2;
function ScalarCeilF64x2(const a: TVecF64x2): TVecF64x2;
function ScalarRoundF64x2(const a: TVecF64x2): TVecF64x2;
function ScalarTruncF64x2(const a: TVecF64x2): TVecF64x2;

// F32x8 (256-bit)
function ScalarFmaF32x8(const a, b, c: TVecF32x8): TVecF32x8;
function ScalarFloorF32x8(const a: TVecF32x8): TVecF32x8;
function ScalarCeilF32x8(const a: TVecF32x8): TVecF32x8;
function ScalarRoundF32x8(const a: TVecF32x8): TVecF32x8;
function ScalarTruncF32x8(const a: TVecF32x8): TVecF32x8;

// F64x4 (256-bit)
function ScalarFmaF64x4(const a, b, c: TVecF64x4): TVecF64x4;
function ScalarFloorF64x4(const a: TVecF64x4): TVecF64x4;
function ScalarCeilF64x4(const a: TVecF64x4): TVecF64x4;
function ScalarRoundF64x4(const a: TVecF64x4): TVecF64x4;
function ScalarTruncF64x4(const a: TVecF64x4): TVecF64x4;
function ScalarRcpF64x4(const a: TVecF64x4): TVecF64x4;

// F32x16 / F64x8 (512-bit)
function ScalarFmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
function ScalarFloorF32x16(const a: TVecF32x16): TVecF32x16;
function ScalarCeilF32x16(const a: TVecF32x16): TVecF32x16;
function ScalarRoundF32x16(const a: TVecF32x16): TVecF32x16;
function ScalarTruncF32x16(const a: TVecF32x16): TVecF32x16;
function ScalarFmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
function ScalarFloorF64x8(const a: TVecF64x8): TVecF64x8;
function ScalarCeilF64x8(const a: TVecF64x8): TVecF64x8;
function ScalarRoundF64x8(const a: TVecF64x8): TVecF64x8;
function ScalarTruncF64x8(const a: TVecF64x8): TVecF64x8;

// 3D/4D 向量数学函数
function ScalarDotF32x4(const a, b: TVecF32x4): Single;
function ScalarDotF32x3(const a, b: TVecF32x4): Single;
function ScalarCrossF32x3(const a, b: TVecF32x4): TVecF32x4;
function ScalarLengthF32x4(const a: TVecF32x4): Single;
function ScalarLengthF32x3(const a: TVecF32x4): Single;
function ScalarNormalizeF32x4(const a: TVecF32x4): TVecF32x4;
function ScalarNormalizeF32x3(const a: TVecF32x4): TVecF32x4;

// FMA-optimized Dot Product Functions
function ScalarDotF32x8(const a, b: TVecF32x8): Single;
function ScalarDotF64x2(const a, b: TVecF64x2): Double;
function ScalarDotF64x4(const a, b: TVecF64x4): Double;

// === Saturating Arithmetic ===
// Signed saturating (clamp to type range, no overflow)
function ScalarI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
function ScalarI8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
function ScalarI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
function ScalarI16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
// Unsigned saturating
function ScalarU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
function ScalarU8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
function ScalarU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
function ScalarU16x8SatSub(const a, b: TVecU16x8): TVecU16x8;

// === Narrow Integer Operations ===
// I16x8 Operations (16 functions)
function ScalarAddI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarSubI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarMulI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarAndI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarOrI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarXorI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarNotI16x8(const a: TVecI16x8): TVecI16x8;
function ScalarAndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
function ScalarShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
function ScalarShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
function ScalarCmpEqI16x8(const a, b: TVecI16x8): TMask8;
function ScalarCmpLtI16x8(const a, b: TVecI16x8): TMask8;
function ScalarCmpGtI16x8(const a, b: TVecI16x8): TMask8;
function ScalarCmpLeI16x8(const a, b: TVecI16x8): TMask8;
function ScalarCmpGeI16x8(const a, b: TVecI16x8): TMask8;
function ScalarCmpNeI16x8(const a, b: TVecI16x8): TMask8;
function ScalarMinI16x8(const a, b: TVecI16x8): TVecI16x8;
function ScalarMaxI16x8(const a, b: TVecI16x8): TVecI16x8;

// I8x16 Operations (12 functions)
function ScalarAddI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarSubI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarAndI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarOrI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarXorI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarNotI8x16(const a: TVecI8x16): TVecI8x16;
function ScalarAndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarCmpEqI8x16(const a, b: TVecI8x16): TMask16;
function ScalarCmpLtI8x16(const a, b: TVecI8x16): TMask16;
function ScalarCmpGtI8x16(const a, b: TVecI8x16): TMask16;
function ScalarCmpLeI8x16(const a, b: TVecI8x16): TMask16;
function ScalarCmpGeI8x16(const a, b: TVecI8x16): TMask16;
function ScalarCmpNeI8x16(const a, b: TVecI8x16): TMask16;
function ScalarMinI8x16(const a, b: TVecI8x16): TVecI8x16;
function ScalarMaxI8x16(const a, b: TVecI8x16): TVecI8x16;

// U32x4 Operations (17 functions)
function ScalarAddU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarSubU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarMulU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarAndU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarOrU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarXorU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarNotU32x4(const a: TVecU32x4): TVecU32x4;
function ScalarAndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
function ScalarShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
function ScalarCmpEqU32x4(const a, b: TVecU32x4): TMask4;
function ScalarCmpLtU32x4(const a, b: TVecU32x4): TMask4;
function ScalarCmpGtU32x4(const a, b: TVecU32x4): TMask4;
function ScalarCmpLeU32x4(const a, b: TVecU32x4): TMask4;
function ScalarCmpGeU32x4(const a, b: TVecU32x4): TMask4;
function ScalarCmpNeU32x4(const a, b: TVecU32x4): TMask4;
function ScalarMinU32x4(const a, b: TVecU32x4): TVecU32x4;
function ScalarMaxU32x4(const a, b: TVecU32x4): TVecU32x4;

// U32x8 Operations (256-bit, 8x32-bit unsigned)
function ScalarAddU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarSubU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarMulU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarAndU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarOrU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarXorU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarNotU32x8(const a: TVecU32x8): TVecU32x8;
function ScalarAndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
function ScalarShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
function ScalarCmpEqU32x8(const a, b: TVecU32x8): TMask8;
function ScalarCmpLtU32x8(const a, b: TVecU32x8): TMask8;
function ScalarCmpGtU32x8(const a, b: TVecU32x8): TMask8;
function ScalarCmpLeU32x8(const a, b: TVecU32x8): TMask8;
function ScalarCmpGeU32x8(const a, b: TVecU32x8): TMask8;
function ScalarCmpNeU32x8(const a, b: TVecU32x8): TMask8;
function ScalarMinU32x8(const a, b: TVecU32x8): TVecU32x8;
function ScalarMaxU32x8(const a, b: TVecU32x8): TVecU32x8;

// U16x8 Operations (15 functions)
function ScalarAddU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarSubU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarMulU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarAndU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarOrU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarXorU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarNotU16x8(const a: TVecU16x8): TVecU16x8;
function ScalarAndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
function ScalarShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
function ScalarCmpEqU16x8(const a, b: TVecU16x8): TMask8;
function ScalarCmpLtU16x8(const a, b: TVecU16x8): TMask8;
function ScalarCmpGtU16x8(const a, b: TVecU16x8): TMask8;
function ScalarCmpLeU16x8(const a, b: TVecU16x8): TMask8;
function ScalarCmpGeU16x8(const a, b: TVecU16x8): TMask8;
function ScalarCmpNeU16x8(const a, b: TVecU16x8): TMask8;
function ScalarMinU16x8(const a, b: TVecU16x8): TVecU16x8;
function ScalarMaxU16x8(const a, b: TVecU16x8): TVecU16x8;

// U8x16 Operations (12 functions)
function ScalarAddU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarSubU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarAndU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarOrU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarXorU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarNotU8x16(const a: TVecU8x16): TVecU8x16;
function ScalarAndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarCmpEqU8x16(const a, b: TVecU8x16): TMask16;
function ScalarCmpLtU8x16(const a, b: TVecU8x16): TMask16;
function ScalarCmpGtU8x16(const a, b: TVecU8x16): TMask16;
function ScalarCmpLeU8x16(const a, b: TVecU8x16): TMask16;
function ScalarCmpGeU8x16(const a, b: TVecU8x16): TMask16;
function ScalarCmpNeU8x16(const a, b: TVecU8x16): TMask16;
function ScalarMinU8x16(const a, b: TVecU8x16): TVecU8x16;
function ScalarMaxU8x16(const a, b: TVecU8x16): TVecU8x16;

// Mask 操作函数
// TMask2 (2 元素)
function ScalarMask2All(mask: TMask2): Boolean;
function ScalarMask2Any(mask: TMask2): Boolean;
function ScalarMask2None(mask: TMask2): Boolean;
function ScalarMask2PopCount(mask: TMask2): Integer;
function ScalarMask2FirstSet(mask: TMask2): Integer;
// TMask4 (4 元素)
function ScalarMask4All(mask: TMask4): Boolean;
function ScalarMask4Any(mask: TMask4): Boolean;
function ScalarMask4None(mask: TMask4): Boolean;
function ScalarMask4PopCount(mask: TMask4): Integer;
function ScalarMask4FirstSet(mask: TMask4): Integer;
// TMask8 (8 元素)
function ScalarMask8All(mask: TMask8): Boolean;
function ScalarMask8Any(mask: TMask8): Boolean;
function ScalarMask8None(mask: TMask8): Boolean;
function ScalarMask8PopCount(mask: TMask8): Integer;
function ScalarMask8FirstSet(mask: TMask8): Integer;
// TMask16 (16 元素)
function ScalarMask16All(mask: TMask16): Boolean;
function ScalarMask16Any(mask: TMask16): Boolean;
function ScalarMask16None(mask: TMask16): Boolean;
function ScalarMask16PopCount(mask: TMask16): Integer;
function ScalarMask16FirstSet(mask: TMask16): Integer;

// F64x2 Select
function ScalarSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;

// 512-bit Select
function ScalarSelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
function ScalarSelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;

// Select 操作 (条件选择: mask[i] != 0 ? a[i] : b[i])
function ScalarSelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
function ScalarSelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
function ScalarSelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;

implementation

uses
  Math,  // RTL Math 单元 (Abs, Sqrt, Min, Max, Floor, Ceil, Round, Trunc)
  SysUtils;

function ScalarNormalizeSignedZeroSingle(const aInput, aOutput: Single): Single; inline;
var
  LBits: DWord;
  LInput: Single;
begin
  Result := aOutput;
  if aOutput = 0.0 then
  begin
    LBits := 0;
    LInput := aInput;
    Move(LInput, LBits, SizeOf(LBits));
    if (LBits and DWord($80000000)) <> 0 then
      Result := -0.0;
  end;
end;

function ScalarNormalizeSignedZeroDouble(const aInput, aOutput: Double): Double; inline;
var
  LBits: QWord;
  LInput: Double;
begin
  Result := aOutput;
  if aOutput = 0.0 then
  begin
    LBits := 0;
    LInput := aInput;
    Move(LInput, LBits, SizeOf(LBits));
    if (LBits and QWord($8000000000000000)) <> 0 then
      Result := -0.0;
  end;
end;

// === Arithmetic Operations ===
// Generated by tools/simdgen - covers F32x4, F32x8, F64x2 Add/Sub/Mul/Div
{$I generated/nextpas.core.simd.scalar.arithmetic.base.inc}

// === Integer Arithmetic (disable overflow/range checks for wraparound semantics) ===
{$PUSH}{$R-}{$Q-}

// I32x4 Add/Sub/Mul + Bitwise + Comparison + Min/Max (generated)
{$I generated/nextpas.core.simd.scalar.i32x4.inc}

// I32x4 Shift Operations
function ScalarShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    // 超出范围时返回零（与 SIMD 行为一致）
    for i := 0 to 3 do
      Result.i[i] := 0;
  end
  else
  begin
    for i := 0 to 3 do
      Result.i[i] := a.i[i] shl count;
  end;
end;

function ScalarShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 3 do
      Result.i[i] := 0;
  end
  else
  begin
    // 逻辑右移（无符号）
    for i := 0 to 3 do
      Result.i[i] := Int32(UInt32(a.i[i]) shr count);
  end;
end;

function ScalarShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var i: Integer;
begin
  if count <= 0 then
  begin
    for i := 0 to 3 do
      Result.i[i] := a.i[i];
  end
  else if count >= 32 then
  begin
    // 算术右移超过31位，结果为全0或全1（取决于符号位）
    for i := 0 to 3 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
  end
  else
  begin
    // 算术右移（保留符号）
    for i := 0 to 3 do
      Result.i[i] := SarLongint(a.i[i], count);
  end;
end;

// I32x4 Comparison + Min/Max are in generated/nextpas.core.simd.scalar.i32x4.inc

// I64x2 Arithmetic Operations
function ScalarAddI64x2(const a, b: TVecI64x2): TVecI64x2;
var j: Integer;
begin
  for j := 0 to 1 do
    Result.i[j] := a.i[j] + b.i[j];
end;

function ScalarSubI64x2(const a, b: TVecI64x2): TVecI64x2;
var j: Integer;
begin
  for j := 0 to 1 do
    Result.i[j] := a.i[j] - b.i[j];
end;

// I64x2 Bitwise Operations
function ScalarAndI64x2(const a, b: TVecI64x2): TVecI64x2;
var j: Integer;
begin
  for j := 0 to 1 do
    Result.i[j] := a.i[j] and b.i[j];
end;

function ScalarOrI64x2(const a, b: TVecI64x2): TVecI64x2;
var j: Integer;
begin
  for j := 0 to 1 do
    Result.i[j] := a.i[j] or b.i[j];
end;

function ScalarXorI64x2(const a, b: TVecI64x2): TVecI64x2;
var j: Integer;
begin
  for j := 0 to 1 do
    Result.i[j] := a.i[j] xor b.i[j];
end;

function ScalarNotI64x2(const a: TVecI64x2): TVecI64x2;
var j: Integer;
begin
  for j := 0 to 1 do
    Result.i[j] := not a.i[j];
end;

function ScalarAndNotI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  Result.i[0] := (not a.i[0]) and b.i[0];
  Result.i[1] := (not a.i[1]) and b.i[1];
end;

function ScalarShiftLeftI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then begin Result.i[0] := 0; Result.i[1] := 0; Exit; end;
  Result.i[0] := a.i[0] shl count;
  Result.i[1] := a.i[1] shl count;
end;

function ScalarShiftRightI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then begin Result.i[0] := 0; Result.i[1] := 0; Exit; end;
  Result.i[0] := Int64(UInt64(a.i[0]) shr count);
  Result.i[1] := Int64(UInt64(a.i[1]) shr count);
end;

function ScalarShiftRightArithI64x2(const a: TVecI64x2; count: Integer): TVecI64x2;
var
  i: Integer;
begin
  if count <= 0 then
  begin
    Result := a;
    Exit;
  end;
  if count >= 64 then
  begin
    for i := 0 to 1 do
      if a.i[i] < 0 then Result.i[i] := -1
      else Result.i[i] := 0;
    Exit;
  end;
  Result.i[0] := SarInt64(a.i[0], count);
  Result.i[1] := SarInt64(a.i[1], count);
end;

// I64x2 Comparison Operations (missing from dispatch table)
function ScalarCmpEqI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := 0;
  if a.i[0] = b.i[0] then Result := Result or 1;
  if a.i[1] = b.i[1] then Result := Result or 2;
end;

function ScalarCmpLtI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := 0;
  if a.i[0] < b.i[0] then Result := Result or 1;
  if a.i[1] < b.i[1] then Result := Result or 2;
end;

function ScalarCmpGtI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := 0;
  if a.i[0] > b.i[0] then Result := Result or 1;
  if a.i[1] > b.i[1] then Result := Result or 2;
end;

function ScalarCmpLeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := 0;
  if a.i[0] <= b.i[0] then Result := Result or 1;
  if a.i[1] <= b.i[1] then Result := Result or 2;
end;

function ScalarCmpGeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := 0;
  if a.i[0] >= b.i[0] then Result := Result or 1;
  if a.i[1] >= b.i[1] then Result := Result or 2;
end;

function ScalarCmpNeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := 0;
  if a.i[0] <> b.i[0] then Result := Result or 1;
  if a.i[1] <> b.i[1] then Result := Result or 2;
end;

function ScalarMinI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  if a.i[0] < b.i[0] then Result.i[0] := a.i[0] else Result.i[0] := b.i[0];
  if a.i[1] < b.i[1] then Result.i[1] := a.i[1] else Result.i[1] := b.i[1];
end;

function ScalarMaxI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  if a.i[0] > b.i[0] then Result.i[0] := a.i[0] else Result.i[0] := b.i[0];
  if a.i[1] > b.i[1] then Result.i[1] := a.i[1] else Result.i[1] := b.i[1];
end;

function ScalarAddU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] + b.u[0];
  Result.u[1] := a.u[1] + b.u[1];
end;

function ScalarSubU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] - b.u[0];
  Result.u[1] := a.u[1] - b.u[1];
end;

function ScalarAndU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] and b.u[0];
  Result.u[1] := a.u[1] and b.u[1];
end;

function ScalarOrU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] or b.u[0];
  Result.u[1] := a.u[1] or b.u[1];
end;

function ScalarXorU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := a.u[0] xor b.u[0];
  Result.u[1] := a.u[1] xor b.u[1];
end;

function ScalarNotU64x2(const a: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := not a.u[0];
  Result.u[1] := not a.u[1];
end;

function ScalarAndNotU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  Result.u[0] := (not a.u[0]) and b.u[0];
  Result.u[1] := (not a.u[1]) and b.u[1];
end;

function ScalarCmpEqU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := 0;
  if a.u[0] = b.u[0] then Result := Result or 1;
  if a.u[1] = b.u[1] then Result := Result or 2;
end;

function ScalarCmpLtU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := 0;
  if a.u[0] < b.u[0] then Result := Result or 1;
  if a.u[1] < b.u[1] then Result := Result or 2;
end;

function ScalarCmpGtU64x2(const a, b: TVecU64x2): TMask2;
begin
  Result := 0;
  if a.u[0] > b.u[0] then Result := Result or 1;
  if a.u[1] > b.u[1] then Result := Result or 2;
end;

function ScalarMinU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  if a.u[0] < b.u[0] then Result.u[0] := a.u[0] else Result.u[0] := b.u[0];
  if a.u[1] < b.u[1] then Result.u[1] := a.u[1] else Result.u[1] := b.u[1];
end;

function ScalarMaxU64x2(const a, b: TVecU64x2): TVecU64x2;
begin
  if a.u[0] > b.u[0] then Result.u[0] := a.u[0] else Result.u[0] := b.u[0];
  if a.u[1] > b.u[1] then Result.u[1] := a.u[1] else Result.u[1] := b.u[1];
end;

// I64x4 Scalar Operations (256-bit, 4x64-bit signed)

function ScalarAddI64x4(const a, b: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI64x4(const a, b: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarAndI64x4(const a, b: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI64x4(const a, b: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI64x4(const a, b: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI64x4(const a: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
  begin
    for i := 0 to 3 do Result.i[i] := 0;
    Exit;
  end;
  for i := 0 to 3 do
    Result.i[i] := a.i[i] shl count;
end;

function ScalarShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
  begin
    for i := 0 to 3 do Result.i[i] := 0;
    Exit;
  end;
  for i := 0 to 3 do
    Result.i[i] := Int64(UInt64(a.i[i]) shr count);
end;

function ScalarShiftRightArithI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
  begin
    for i := 0 to 3 do
      if a.i[i] < 0 then Result.i[i] := -1
      else Result.i[i] := 0;
    Exit;
  end;
  for i := 0 to 3 do
    Result.i[i] := SarInt64(a.i[i], count);
end;

function ScalarCmpEqI64x4(const a, b: TVecI64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI64x4(const a, b: TVecI64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI64x4(const a, b: TVecI64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeI64x4(const a, b: TVecI64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI64x4(const a, b: TVecI64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI64x4(const a, b: TVecI64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarLoadI64x4(p: PInt64): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := (p + i)^;
end;

procedure ScalarStoreI64x4(p: PInt64; const a: TVecI64x4);
var i: Integer;
begin
  for i := 0 to 3 do
    (p + i)^ := a.i[i];
end;

function ScalarSplatI64x4(value: Int64): TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := value;
end;

function ScalarZeroI64x4: TVecI64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := 0;
end;

// U64x4 Scalar Operations (256-bit, 4x64-bit unsigned)

function ScalarAddU64x4(const a, b: TVecU64x4): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU64x4(const a, b: TVecU64x4): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarAndU64x4(const a, b: TVecU64x4): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU64x4(const a, b: TVecU64x4): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU64x4(const a, b: TVecU64x4): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU64x4(const a: TVecU64x4): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := not a.u[i];
end;

function ScalarShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if (count > 0) and (count < 64) then
      Result.u[i] := a.u[i] shl count
    else
      Result.u[i] := 0;
end;

function ScalarShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if (count > 0) and (count < 64) then
      Result.u[i] := a.u[i] shr count
    else
      Result.u[i] := 0;
end;

function ScalarCmpEqU64x4(const a, b: TVecU64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU64x4(const a, b: TVecU64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU64x4(const a, b: TVecU64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU64x4(const a, b: TVecU64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU64x4(const a, b: TVecU64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU64x4(const a, b: TVecU64x4): TMask4;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

// F64x4 Arithmetic Operations (256-bit) - generated
{$I generated/nextpas.core.simd.scalar.f64x4.arith.inc}
{$POP}

// === I32x8 Arithmetic Operations (256-bit) ===
{$PUSH}{$R-}{$Q-}

// I32x8 Add/Sub/Mul + Bitwise + Comparison + Min/Max (generated)
{$I generated/nextpas.core.simd.scalar.i32x8.inc}

// I32x8 Shift Operations
function ScalarShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
  end
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shl count;
  end;
end;

function ScalarShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
  end
  else
  begin
    // 逻辑右移（无符号）
    for i := 0 to 7 do
      Result.i[i] := Int32(UInt32(a.i[i]) shr count);
  end;
end;

function ScalarShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
var i: Integer;
begin
  if count <= 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i];
  end
  else if count >= 32 then
  begin
    // 算术右移超过31位，结果为全0或全1（取决于符号位）
    for i := 0 to 7 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
  end
  else
  begin
    // 算术右移（保留符号）
    for i := 0 to 7 do
      Result.i[i] := SarLongint(a.i[i], count);
  end;
end;


{$POP}

// === F32x16 Arithmetic Operations (512-bit) ===
{$I generated/nextpas.core.simd.scalar.f32x16.arith.inc}

// === F64x8 Arithmetic Operations (512-bit) ===
{$I generated/nextpas.core.simd.scalar.f64x8.arith.inc}

// === I32x16 Arithmetic Operations (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.i32x16.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 15 do
      Result.i[i] := 0;
  end
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] shl count;
  end;
end;

function ScalarShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
  begin
    for i := 0 to 15 do
      Result.i[i] := 0;
  end
  else
  begin
    // 逻辑右移（无符号）
    for i := 0 to 15 do
      Result.i[i] := Int32(UInt32(a.i[i]) shr count);
  end;
end;

function ScalarShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
var i: Integer;
begin
  if count <= 0 then
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i];
  end
  else if count >= 32 then
  begin
    // 算术右移超过31位，结果为全0或全1（取决于符号位）
    for i := 0 to 15 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
  end
  else
  begin
    // 算术右移（保留符号）
    for i := 0 to 15 do
      Result.i[i] := SarLongint(a.i[i], count);
  end;
end;

{$POP}

// === U32x16 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.u32x16.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
    for i := 0 to 15 do
      Result.u[i] := 0
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] shl count;
end;

function ScalarShiftRightU32x16(const a: TVecU32x16; count: Integer): TVecU32x16;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 32 then
    for i := 0 to 15 do
      Result.u[i] := 0
  else
    for i := 0 to 15 do
      Result.u[i] := a.u[i] shr count;
end;

{$POP}

// === U64x8 Arithmetic/Bitwise/Shift/Comparison (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.u64x8.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
    for i := 0 to 7 do
      Result.u[i] := 0
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shl count;
end;

function ScalarShiftRightU64x8(const a: TVecU64x8; count: Integer): TVecU64x8;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 64 then
    for i := 0 to 7 do
      Result.u[i] := 0
  else
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
end;

{$POP}

// === I16x32 Arithmetic/Bitwise/Shift/Comparison/MinMax (512-bit) ===
{$PUSH}{$R-}{$Q-}

{$I generated/nextpas.core.simd.scalar.i16x32.inc}

// Shift operations (hand-written, boundary checks)
function ScalarShiftLeftI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then
    for i := 0 to 31 do
      Result.i[i] := 0
  else
    for i := 0 to 31 do
      Result.i[i] := a.i[i] shl count;
end;

function ScalarShiftRightI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var i: Integer;
begin
  if count <= 0 then begin Result := a; Exit; end;
  if count >= 16 then
    for i := 0 to 31 do
      Result.i[i] := 0
  else
    for i := 0 to 31 do
      Result.i[i] := Int16(UInt16(a.i[i]) shr count);
end;

function ScalarShiftRightArithI16x32(const a: TVecI16x32; count: Integer): TVecI16x32;
var i: Integer;
begin
  if count <= 0 then
    for i := 0 to 31 do
      Result.i[i] := a.i[i]
  else if count >= 16 then
    for i := 0 to 31 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0
  else
    for i := 0 to 31 do
      Result.i[i] := Int16(SarLongint(a.i[i], count));
end;

{$POP}

// === I8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===
{$I generated/nextpas.core.simd.scalar.i8x64.inc}

// === U8x64 Arithmetic/Bitwise/Comparison/MinMax (512-bit) ===
{$I generated/nextpas.core.simd.scalar.u8x64.inc}

// === Comparison Operations ===
// Generated by tools/simdgen - covers F32x4, F64x2, F32x8, F64x4
{$I generated/nextpas.core.simd.scalar.compare.base.inc}

// === F32x16/F64x8 Comparison (512-bit) ===

function ScalarCmpEqF32x16(const a, b: TVecF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.f[i] = b.f[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtF32x16(const a, b: TVecF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.f[i] < b.f[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeF32x16(const a, b: TVecF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.f[i] <= b.f[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtF32x16(const a, b: TVecF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.f[i] > b.f[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeF32x16(const a, b: TVecF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.f[i] >= b.f[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeF32x16(const a, b: TVecF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.f[i] <> b.f[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpEqF64x8(const a, b: TVecF64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.d[i] = b.d[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtF64x8(const a, b: TVecF64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.d[i] < b.d[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeF64x8(const a, b: TVecF64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.d[i] <= b.d[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtF64x8(const a, b: TVecF64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.d[i] > b.d[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeF64x8(const a, b: TVecF64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.d[i] >= b.d[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeF64x8(const a, b: TVecF64x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.d[i] <> b.d[i] then
      Result := Result or (1 shl i);
end;

// === Math Functions ===

function ScalarAbsF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Abs(a.f[i]);
end;

function ScalarSqrtF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Sqrt(a.f[i]);
end;

function ScalarMinF32x4(const a, b: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Min(a.f[i], b.f[i]);
end;

function ScalarMaxF32x4(const a, b: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Max(a.f[i], b.f[i]);
end;

// === Extended Math Functions ===

function ScalarFmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function ScalarRcpF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := 1.0 / a.f[i];
end;

function ScalarRsqrtF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := 1.0 / Sqrt(a.f[i]);
end;

function ScalarFloorF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := Floor(a.f[i]);
  end;
end;

function ScalarCeilF32x4(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := Ceil(a.f[i]);
  end;
end;

function ScalarRoundF32x4(const a: TVecF32x4): TVecF32x4;
var
  i: Integer;
  LRounded: Single;
begin
  for i := 0 to 3 do
  begin
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LRounded := Round(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LRounded);
    end;
  end;
end;

function ScalarTruncF32x4(const a: TVecF32x4): TVecF32x4;
var
  i: Integer;
  LTrunced: Single;
begin
  for i := 0 to 3 do
  begin
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LTrunced := Trunc(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LTrunced);
    end;
  end;
end;

function ScalarClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Max(minVal.f[i], Min(a.f[i], maxVal.f[i]));
end;

// === Wide Vector Math Functions ===

// F64x2 Math
function ScalarAbsF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Abs(a.d[0]);
  Result.d[1] := Abs(a.d[1]);
end;

function ScalarSqrtF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Sqrt(a.d[0]);
  Result.d[1] := Sqrt(a.d[1]);
end;

function ScalarMinF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Min(a.d[0], b.d[0]);
  Result.d[1] := Min(a.d[1], b.d[1]);
end;

function ScalarMaxF64x2(const a, b: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Max(a.d[0], b.d[0]);
  Result.d[1] := Max(a.d[1], b.d[1]);
end;

function ScalarClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := Max(minVal.d[0], Min(a.d[0], maxVal.d[0]));
  Result.d[1] := Max(minVal.d[1], Min(a.d[1], maxVal.d[1]));
end;

// F32x8 Math
function ScalarAbsF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Abs(a.f[i]);
end;

function ScalarSqrtF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Sqrt(a.f[i]);
end;

function ScalarMinF32x8(const a, b: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Min(a.f[i], b.f[i]);
end;

function ScalarMaxF32x8(const a, b: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Max(a.f[i], b.f[i]);
end;

function ScalarClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := Max(minVal.f[i], Min(a.f[i], maxVal.f[i]));
end;

// F64x4 Math
function ScalarAbsF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Abs(a.d[i]);
end;

function ScalarSqrtF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Sqrt(a.d[i]);
end;

function ScalarMinF64x4(const a, b: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Min(a.d[i], b.d[i]);
end;

function ScalarMaxF64x4(const a, b: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Max(a.d[i], b.d[i]);
end;

function ScalarClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := Max(minVal.d[i], Min(a.d[i], maxVal.d[i]));
end;

// F32x16 (512-bit)
function ScalarAbsF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Abs(a.f[i]);
end;

function ScalarSqrtF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Sqrt(a.f[i]);
end;

function ScalarMinF32x16(const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Min(a.f[i], b.f[i]);
end;

function ScalarMaxF32x16(const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Max(a.f[i], b.f[i]);
end;

function ScalarClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := Max(minVal.f[i], Min(a.f[i], maxVal.f[i]));
end;

// F64x8 (512-bit)
function ScalarAbsF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Abs(a.d[i]);
end;

function ScalarSqrtF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Sqrt(a.d[i]);
end;

function ScalarMinF64x8(const a, b: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Min(a.d[i], b.d[i]);
end;

function ScalarMaxF64x8(const a, b: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Max(a.d[i], b.d[i]);
end;

function ScalarClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := Max(minVal.d[i], Min(a.d[i], maxVal.d[i]));
end;

// === Wide Vector Extended Math Functions ===

// F64x2 (128-bit)
function ScalarFmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := a.d[0] * b.d[0] + c.d[0];
  Result.d[1] := a.d[1] * b.d[1] + c.d[1];
end;

function ScalarFloorF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if IsNan(a.d[0]) or IsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
    Result.d[0] := Floor(a.d[0]);

  if IsNan(a.d[1]) or IsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
    Result.d[1] := Floor(a.d[1]);
end;

function ScalarCeilF64x2(const a: TVecF64x2): TVecF64x2;
begin
  if IsNan(a.d[0]) or IsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
    Result.d[0] := Ceil(a.d[0]);

  if IsNan(a.d[1]) or IsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
    Result.d[1] := Ceil(a.d[1]);
end;

function ScalarRoundF64x2(const a: TVecF64x2): TVecF64x2;
var
  LRounded: Double;
begin
  if IsNan(a.d[0]) or IsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
  begin
    LRounded := Round(a.d[0]);
    Result.d[0] := ScalarNormalizeSignedZeroDouble(a.d[0], LRounded);
  end;

  if IsNan(a.d[1]) or IsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
  begin
    LRounded := Round(a.d[1]);
    Result.d[1] := ScalarNormalizeSignedZeroDouble(a.d[1], LRounded);
  end;
end;

function ScalarTruncF64x2(const a: TVecF64x2): TVecF64x2;
var
  LTrunced: Double;
begin
  if IsNan(a.d[0]) or IsInfinite(a.d[0]) then
    Result.d[0] := a.d[0]
  else
  begin
    LTrunced := Trunc(a.d[0]);
    Result.d[0] := ScalarNormalizeSignedZeroDouble(a.d[0], LTrunced);
  end;

  if IsNan(a.d[1]) or IsInfinite(a.d[1]) then
    Result.d[1] := a.d[1]
  else
  begin
    LTrunced := Trunc(a.d[1]);
    Result.d[1] := ScalarNormalizeSignedZeroDouble(a.d[1], LTrunced);
  end;
end;

// F32x8 (256-bit)
function ScalarFmaF32x8(const a, b, c: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function ScalarFloorF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := Floor(a.f[i]);
end;

function ScalarCeilF32x8(const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := Ceil(a.f[i]);
end;

function ScalarRoundF32x8(const a: TVecF32x8): TVecF32x8;
var
  i: Integer;
  LRounded: Single;
begin
  for i := 0 to 7 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LRounded := Round(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LRounded);
    end;
end;

function ScalarTruncF32x8(const a: TVecF32x8): TVecF32x8;
var
  i: Integer;
  LTrunced: Single;
begin
  for i := 0 to 7 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LTrunced := Trunc(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LTrunced);
    end;
end;

// F64x4 (256-bit)
function ScalarFmaF64x4(const a, b, c: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := a.d[i] * b.d[i] + c.d[i];
end;

function ScalarFloorF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := Floor(a.d[i]);
end;

function ScalarCeilF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := Ceil(a.d[i]);
end;

function ScalarRoundF64x4(const a: TVecF64x4): TVecF64x4;
var
  i: Integer;
  LRounded: Double;
begin
  for i := 0 to 3 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LRounded := Round(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LRounded);
    end;
end;

function ScalarTruncF64x4(const a: TVecF64x4): TVecF64x4;
var
  i: Integer;
  LTrunced: Double;
begin
  for i := 0 to 3 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LTrunced := Trunc(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LTrunced);
    end;
end;

function ScalarRcpF64x4(const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := 1.0 / a.d[i];
end;

// F32x16 (512-bit)
function ScalarFmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := a.f[i] * b.f[i] + c.f[i];
end;

function ScalarFloorF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := Floor(a.f[i]);
end;

function ScalarCeilF32x16(const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := Ceil(a.f[i]);
end;

function ScalarRoundF32x16(const a: TVecF32x16): TVecF32x16;
var
  i: Integer;
  LRounded: Single;
begin
  for i := 0 to 15 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LRounded := Round(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LRounded);
    end;
end;

function ScalarTruncF32x16(const a: TVecF32x16): TVecF32x16;
var
  i: Integer;
  LTrunced: Single;
begin
  for i := 0 to 15 do
    if IsNan(a.f[i]) or IsInfinite(a.f[i]) then
      Result.f[i] := a.f[i]
    else
    begin
      LTrunced := Trunc(a.f[i]);
      Result.f[i] := ScalarNormalizeSignedZeroSingle(a.f[i], LTrunced);
    end;
end;

// F64x8 (512-bit)
function ScalarFmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := a.d[i] * b.d[i] + c.d[i];
end;

function ScalarFloorF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := Floor(a.d[i]);
end;

function ScalarCeilF64x8(const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := Ceil(a.d[i]);
end;

function ScalarRoundF64x8(const a: TVecF64x8): TVecF64x8;
var
  i: Integer;
  LRounded: Double;
begin
  for i := 0 to 7 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LRounded := Round(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LRounded);
    end;
end;

function ScalarTruncF64x8(const a: TVecF64x8): TVecF64x8;
var
  i: Integer;
  LTrunced: Double;
begin
  for i := 0 to 7 do
    if IsNan(a.d[i]) or IsInfinite(a.d[i]) then
      Result.d[i] := a.d[i]
    else
    begin
      LTrunced := Trunc(a.d[i]);
      Result.d[i] := ScalarNormalizeSignedZeroDouble(a.d[i], LTrunced);
    end;
end;

// === 3D/4D Vector Math ===

function ScalarDotF32x4(const a, b: TVecF32x4): Single;
begin
  Result := a.f[0] * b.f[0] + a.f[1] * b.f[1] + a.f[2] * b.f[2] + a.f[3] * b.f[3];
end;

function ScalarDotF32x3(const a, b: TVecF32x4): Single;
begin
  Result := a.f[0] * b.f[0] + a.f[1] * b.f[1] + a.f[2] * b.f[2];
end;

function ScalarCrossF32x3(const a, b: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[1] * b.f[2] - a.f[2] * b.f[1];
  Result.f[1] := a.f[2] * b.f[0] - a.f[0] * b.f[2];
  Result.f[2] := a.f[0] * b.f[1] - a.f[1] * b.f[0];
  Result.f[3] := 0.0;
end;

function ScalarLengthF32x4(const a: TVecF32x4): Single;
begin
  Result := Sqrt(a.f[0] * a.f[0] + a.f[1] * a.f[1] + a.f[2] * a.f[2] + a.f[3] * a.f[3]);
end;

function ScalarLengthF32x3(const a: TVecF32x4): Single;
begin
  Result := Sqrt(a.f[0] * a.f[0] + a.f[1] * a.f[1] + a.f[2] * a.f[2]);
end;

function ScalarNormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
  invLen: Single;
  i: Integer;
begin
  len := ScalarLengthF32x4(a);
  if len > 0.0 then
  begin
    invLen := 1.0 / len;
    for i := 0 to 3 do
      Result.f[i] := a.f[i] * invLen;
  end
  else
    Result := a;
end;

function ScalarNormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
  invLen: Single;
begin
  len := ScalarLengthF32x3(a);
  if len > 0.0 then
  begin
    invLen := 1.0 / len;
    Result.f[0] := a.f[0] * invLen;
    Result.f[1] := a.f[1] * invLen;
    Result.f[2] := a.f[2] * invLen;
    Result.f[3] := 0.0;
  end
  else
  begin
    Result := a;
    Result.f[3] := 0.0;
  end;
end;

// FMA-optimized Dot Product Functions (Scalar Reference)

function ScalarDotF32x8(const a, b: TVecF32x8): Single;
var
  i: Integer;
begin
  Result := 0.0;
  for i := 0 to 7 do
    Result := Result + a.f[i] * b.f[i];
end;

function ScalarDotF64x2(const a, b: TVecF64x2): Double;
begin
  Result := a.d[0] * b.d[0] + a.d[1] * b.d[1];
end;

function ScalarDotF64x4(const a, b: TVecF64x4): Double;
var
  i: Integer;
begin
  Result := 0.0;
  for i := 0 to 3 do
    Result := Result + a.d[i] * b.d[i];
end;

// === Reduction Operations ===

function ScalarReduceAddF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 3 do
    Result := Result + a.f[i];
end;

function ScalarReduceMinF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 3 do
    Result := Min(Result, a.f[i]);
end;

function ScalarReduceMaxF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 3 do
    Result := Max(Result, a.f[i]);
end;

function ScalarReduceMulF32x4(const a: TVecF32x4): Single;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 3 do
    Result := Result * a.f[i];
end;

// === Wide Vector Reduction Operations ===

// F64x2 Reduction
function ScalarReduceAddF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] + a.d[1];
end;

function ScalarReduceMinF64x2(const a: TVecF64x2): Double;
begin
  Result := Min(a.d[0], a.d[1]);
end;

function ScalarReduceMaxF64x2(const a: TVecF64x2): Double;
begin
  Result := Max(a.d[0], a.d[1]);
end;

function ScalarReduceMulF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] * a.d[1];
end;

// F32x8 Reduction
function ScalarReduceAddF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 7 do
    Result := Result + a.f[i];
end;

function ScalarReduceMinF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 7 do
    Result := Min(Result, a.f[i]);
end;

function ScalarReduceMaxF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 7 do
    Result := Max(Result, a.f[i]);
end;

function ScalarReduceMulF32x8(const a: TVecF32x8): Single;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 7 do
    Result := Result * a.f[i];
end;

// F64x4 Reduction
function ScalarReduceAddF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 3 do
    Result := Result + a.d[i];
end;

function ScalarReduceMinF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 3 do
    Result := Min(Result, a.d[i]);
end;

function ScalarReduceMaxF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 3 do
    Result := Max(Result, a.d[i]);
end;

function ScalarReduceMulF64x4(const a: TVecF64x4): Double;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 3 do
    Result := Result * a.d[i];
end;

// F32x16 (512-bit)
function ScalarReduceAddF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 15 do
    Result := Result + a.f[i];
end;

function ScalarReduceMinF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 15 do
    Result := Min(Result, a.f[i]);
end;

function ScalarReduceMaxF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := a.f[0];
  for i := 1 to 15 do
    Result := Max(Result, a.f[i]);
end;

function ScalarReduceMulF32x16(const a: TVecF32x16): Single;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 15 do
    Result := Result * a.f[i];
end;

// F64x8 (512-bit)
function ScalarReduceAddF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := 0.0;
  for i := 0 to 7 do
    Result := Result + a.d[i];
end;

function ScalarReduceMinF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 7 do
    Result := Min(Result, a.d[i]);
end;

function ScalarReduceMaxF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := a.d[0];
  for i := 1 to 7 do
    Result := Max(Result, a.d[i]);
end;

function ScalarReduceMulF64x8(const a: TVecF64x8): Double;
var i: Integer;
begin
  Result := 1.0;
  for i := 0 to 7 do
    Result := Result * a.d[i];
end;

// === Memory Operations ===

// Assert for nil pointer (performance-sensitive code)
function ScalarLoadF32x4(p: PSingle): TVecF32x4;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF32x4: pointer is nil');
  for i := 0 to 3 do
    Result.f[i] := p[i];
end;

function ScalarLoadF32x4Aligned(p: PSingle): TVecF32x4;
begin
  // For scalar implementation, aligned and unaligned are the same
  Result := ScalarLoadF32x4(p);
end;

procedure ScalarStoreF32x4(p: PSingle; const a: TVecF32x4);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF32x4: pointer is nil');
  for i := 0 to 3 do
    p[i] := a.f[i];
end;

procedure ScalarStoreF32x4Aligned(p: PSingle; const a: TVecF32x4);
begin
  // For scalar implementation, aligned and unaligned are the same
  ScalarStoreF32x4(p, a);
end;

// === Utility Operations ===

// 展开循环优化
function ScalarSplatF32x4(value: Single): TVecF32x4;
begin
  Result.f[0] := value;
  Result.f[1] := value;
  Result.f[2] := value;
  Result.f[3] := value;
end;

// 展开循环优化
function ScalarZeroF32x4: TVecF32x4;
begin
  Result.f[0] := 0.0;
  Result.f[1] := 0.0;
  Result.f[2] := 0.0;
  Result.f[3] := 0.0;
end;

function ScalarSelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if (mask and (1 shl i)) <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
end;

function ScalarExtractF32x4(const a: TVecF32x4; index: Integer): Single;
var
  safeIndex: Integer;
begin
  // use saturation strategy for index bounds (per project spec)
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.f[safeIndex];
end;

function ScalarInsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
var
  safeIndex: Integer;
begin
  // use saturation strategy for index bounds (per project spec)
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.f[safeIndex] := value;
end;

// === Extract/Insert Lane Operations ===

// F64x2 (128-bit)
function ScalarExtractF64x2(const a: TVecF64x2; index: Integer): Double;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a.d[safeIndex];
end;

function ScalarInsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a;
  Result.d[safeIndex] := value;
end;

// I32x4 (128-bit)
function ScalarExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.i[safeIndex];
end;

function ScalarInsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.i[safeIndex] := value;
end;

// I64x2 (128-bit)
function ScalarExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a.i[safeIndex];
end;

function ScalarInsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 1 then safeIndex := 1;
  Result := a;
  Result.i[safeIndex] := value;
end;

// F32x8 (256-bit)
function ScalarExtractF32x8(const a: TVecF32x8; index: Integer): Single;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a.f[safeIndex];
end;

function ScalarInsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a;
  Result.f[safeIndex] := value;
end;

// F64x4 (256-bit)
function ScalarExtractF64x4(const a: TVecF64x4; index: Integer): Double;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.d[safeIndex];
end;

function ScalarInsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.d[safeIndex] := value;
end;

// I32x8 (256-bit)
function ScalarExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a.i[safeIndex];
end;

function ScalarInsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 7 then safeIndex := 7;
  Result := a;
  Result.i[safeIndex] := value;
end;

// I64x4 (256-bit)
function ScalarExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a.i[safeIndex];
end;

function ScalarInsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 3 then safeIndex := 3;
  Result := a;
  Result.i[safeIndex] := value;
end;

// F32x16 (512-bit)
function ScalarExtractF32x16(const a: TVecF32x16; index: Integer): Single;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a.f[safeIndex];
end;

function ScalarInsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a;
  Result.f[safeIndex] := value;
end;

// I32x16 (512-bit)
function ScalarExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a.i[safeIndex];
end;

function ScalarInsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;
var
  safeIndex: Integer;
begin
  safeIndex := index;
  if safeIndex < 0 then safeIndex := 0
  else if safeIndex > 15 then safeIndex := 15;
  Result := a;
  Result.i[safeIndex] := value;
end;

// === Wide Vector Load/Store/Splat/Zero Functions ===

// F64x2 (128-bit)
function ScalarLoadF64x2(p: PDouble): TVecF64x2;
begin
  Assert(p <> nil, 'ScalarLoadF64x2: pointer is nil');
  Result.d[0] := p[0];
  Result.d[1] := p[1];
end;

procedure ScalarStoreF64x2(p: PDouble; const a: TVecF64x2);
begin
  Assert(p <> nil, 'ScalarStoreF64x2: pointer is nil');
  p[0] := a.d[0];
  p[1] := a.d[1];
end;

function ScalarSplatF64x2(value: Double): TVecF64x2;
begin
  Result.d[0] := value;
  Result.d[1] := value;
end;

function ScalarZeroF64x2: TVecF64x2;
begin
  Result.d[0] := 0.0;
  Result.d[1] := 0.0;
end;

// F32x8 (256-bit)
function ScalarLoadF32x8(p: PSingle): TVecF32x8;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF32x8: pointer is nil');
  for i := 0 to 7 do
    Result.f[i] := p[i];
end;

procedure ScalarStoreF32x8(p: PSingle; const a: TVecF32x8);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF32x8: pointer is nil');
  for i := 0 to 7 do
    p[i] := a.f[i];
end;

// 展开循环优化
function ScalarSplatF32x8(value: Single): TVecF32x8;
begin
  Result.f[0] := value;
  Result.f[1] := value;
  Result.f[2] := value;
  Result.f[3] := value;
  Result.f[4] := value;
  Result.f[5] := value;
  Result.f[6] := value;
  Result.f[7] := value;
end;

// 展开循环优化
function ScalarZeroF32x8: TVecF32x8;
begin
  Result.f[0] := 0.0;
  Result.f[1] := 0.0;
  Result.f[2] := 0.0;
  Result.f[3] := 0.0;
  Result.f[4] := 0.0;
  Result.f[5] := 0.0;
  Result.f[6] := 0.0;
  Result.f[7] := 0.0;
end;

// F64x4 (256-bit)
function ScalarLoadF64x4(p: PDouble): TVecF64x4;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF64x4: pointer is nil');
  for i := 0 to 3 do
    Result.d[i] := p[i];
end;

procedure ScalarStoreF64x4(p: PDouble; const a: TVecF64x4);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF64x4: pointer is nil');
  for i := 0 to 3 do
    p[i] := a.d[i];
end;

// 展开循环优化
function ScalarSplatF64x4(value: Double): TVecF64x4;
begin
  Result.d[0] := value;
  Result.d[1] := value;
  Result.d[2] := value;
  Result.d[3] := value;
end;

// 展开循环优化
function ScalarZeroF64x4: TVecF64x4;
begin
  Result.d[0] := 0.0;
  Result.d[1] := 0.0;
  Result.d[2] := 0.0;
  Result.d[3] := 0.0;
end;

// F32x16 (512-bit)
function ScalarLoadF32x16(p: PSingle): TVecF32x16;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF32x16: pointer is nil');
  for i := 0 to 15 do
    Result.f[i] := p[i];
end;

procedure ScalarStoreF32x16(p: PSingle; const a: TVecF32x16);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF32x16: pointer is nil');
  for i := 0 to 15 do
    p[i] := a.f[i];
end;

function ScalarSplatF32x16(value: Single): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := value;
end;

function ScalarZeroF32x16: TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := 0.0;
end;

// F64x8 (512-bit)
function ScalarLoadF64x8(p: PDouble): TVecF64x8;
var i: Integer;
begin
  Assert(p <> nil, 'ScalarLoadF64x8: pointer is nil');
  for i := 0 to 7 do
    Result.d[i] := p[i];
end;

procedure ScalarStoreF64x8(p: PDouble; const a: TVecF64x8);
var i: Integer;
begin
  Assert(p <> nil, 'ScalarStoreF64x8: pointer is nil');
  for i := 0 to 7 do
    p[i] := a.d[i];
end;

function ScalarSplatF64x8(value: Double): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := value;
end;

function ScalarZeroF64x8: TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := 0.0;
end;

// === Batch Array Operations (scalar reference implementations) ===

procedure ScalarArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;

procedure ScalarArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] - aSrc2[i];
end;

procedure ScalarArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] * aSrc2[i];
end;

procedure ScalarArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] / aSrc2[i];
end;

procedure ScalarArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc1[i] <= aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;

procedure ScalarArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc1[i] >= aSrc2[i] then
      aDst[i] := aSrc1[i]
    else
      aDst[i] := aSrc2[i];
end;

procedure ScalarArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LVal: LongWord;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    LVal := PLongWord(@aSrc[i])^ and $7FFFFFFF;
    PLongWord(@aDst[i])^ := LVal;
  end;
end;

procedure ScalarArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LVal: LongWord;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    LVal := PLongWord(@aSrc[i])^ xor $80000000;
    PLongWord(@aDst[i])^ := LVal;
  end;
end;

procedure ScalarArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Sqrt(aSrc[i]);
end;

procedure ScalarArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / aSrc[i];
end;

procedure ScalarArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / Sqrt(aSrc[i]);
end;

procedure ScalarArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / aSrc[i];
end;

procedure ScalarArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := 1.0 / Sqrt(aSrc[i]);
end;

procedure ScalarArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScalar;
end;

procedure ScalarArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] + aScalar;
end;

procedure ScalarArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var
  i: SizeUInt;
  v: Single;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v < aMin then v := aMin
    else if v > aMax then v := aMax;
    aDst[i] := v;
  end;
end;

procedure ScalarArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aA[i] * aB[i] + aC[i];
end;

procedure ScalarArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aAlpha * aX[i] + aY[i];
end;

function ScalarReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc[i];
end;

function ScalarReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc1[i] * aSrc2[i];
end;

function ScalarReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] < Result then Result := aSrc[i];
end;

function ScalarReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] > Result then Result := aSrc[i];
end;

// === Batch Array Operations - F64 (Scalar Reference) ===

procedure ScalarArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;

procedure ScalarArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] - aSrc2[i];
end;

procedure ScalarArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] * aSrc2[i];
end;

procedure ScalarArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] / aSrc2[i];
end;

function ScalarReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc[i];
end;

function ScalarReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  Result := 0;
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Result := Result + aSrc1[i] * aSrc2[i];
end;

function ScalarReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] < Result then Result := aSrc[i];
end;

function ScalarReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
var i: SizeUInt;
begin
  if aCount = 0 then begin Result := 0; Exit; end;
  Result := aSrc[0];
  for i := 1 to aCount - 1 do
    if aSrc[i] > Result then Result := aSrc[i];
end;

procedure ScalarArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Abs(aSrc[i]);
end;

procedure ScalarArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := -aSrc[i];
end;

procedure ScalarArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Sqrt(aSrc[i]);
end;

procedure ScalarArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScalar;
end;

procedure ScalarArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] + aScalar;
end;

procedure ScalarArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var i: SizeUInt; v: Double;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v < aMin then v := aMin
    else if v > aMax then v := aMax;
    aDst[i] := v;
  end;
end;

procedure ScalarArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScale + aBias;
end;

procedure ScalarArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Exp(aSrc[i]));
end;

procedure ScalarArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Ln(aSrc[i]));
end;

procedure ScalarArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(Math.Power(aSrc[i], aExponent));
end;

procedure ScalarArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Sin(aSrc[i]));
end;

procedure ScalarArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(System.Cos(aSrc[i]));
end;

procedure ScalarArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] + aSrc2[i];
end;

procedure ScalarArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] - aSrc2[i];
end;

procedure ScalarArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Int16(Int32(aSrc1[i]) * Int32(aSrc2[i]));
end;

procedure ScalarArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
var
  i: SizeUInt;
  v: Int32;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i];
    if v > 32767 then v := 32767
    else if v < -32768 then v := -32768;
    aDst[i] := Int16(v);
  end;
end;

procedure ScalarArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Round(aSrc[i]);
end;

procedure ScalarArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := Single(aSrc[i]);
end;

procedure ScalarArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] and aSrc2[i];
end;

procedure ScalarArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] or aSrc2[i];
end;

procedure ScalarArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc1[i] xor aSrc2[i];
end;

procedure ScalarArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] shl aShift;
end;

procedure ScalarArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := SarLongint(aSrc[i], aShift);
end;

// === Fused Batch Operations ===

procedure ScalarArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aSrc[i] * aScale + aBias;
end;

procedure ScalarArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := System.Abs(aSrc1[i] - aSrc2[i]);
end;

procedure ScalarArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    if aSrc[i] > 0 then aDst[i] := aSrc[i]
    else aDst[i] := 0;
end;

procedure ScalarArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := (aSrc[i] - aMean) * aInvStd;
end;

procedure ScalarArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var i: SizeUInt; v: Single;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    v := aSrc[i] * aScale + aBias;
    if v < 0 then v := 0;
    aDst[i] := v;
  end;
end;

// === Backend Registration ===

procedure RegisterScalarBackend;
var
  dispatchTable: TSimdDispatchTable;
begin
  // Fill with base scalar implementations
  dispatchTable := Default(TSimdDispatchTable);
  FillBaseDispatchTable(dispatchTable);

  // Set backend info
  dispatchTable.Backend := sbScalar;
  with dispatchTable.BackendInfo do
  begin
    Backend := sbScalar;
    Name := 'Scalar';
    Description := 'Pure scalar reference implementation';
    Capabilities := [scBasicArithmetic, scComparison, scMathFunctions, scReduction, scLoadStore];
    Available := True;
    Priority := GetSimdBackendPriorityValue(sbScalar);
  end;

  // Register the backend
  RegisterBackend(sbScalar, dispatchTable);
end;

// === 标量门面函数实现 ===

// 内存操作函数
// 优化为 8 字节批量比较
function MemEqual_Scalar(a, b: Pointer; len: SizeUInt): LongBool;
var
  pa, pb: PByte;
  pqa, pqb: PQWord;
  i, qwordCount, remaining: SizeUInt;
begin
  {$PUSH}{$Q-}{$R-}  // Disable overflow/range checks for SIMD-style loop
  if len = 0 then
  begin
    Result := True;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    Result := (a = b);
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);

  // 快速路径: 按 8 字节 (QWord) 批量比较
  qwordCount := len div 8;
  if qwordCount > 0 then
  begin
    pqa := PQWord(pa);
    pqb := PQWord(pb);
    for i := 0 to qwordCount - 1 do
    begin
      if pqa[i] <> pqb[i] then
      begin
        Result := False;
        Exit;
      end;
    end;
    // 移动指针到剩余字节
    pa := pa + qwordCount * 8;
    pb := pb + qwordCount * 8;
  end;

  // 处理剩余的 0-7 字节
  remaining := len mod 8;
  // 当 remaining=0 时，remaining-1 会下溢到 High(SizeUInt)
  if remaining > 0 then
    for i := 0 to remaining - 1 do
    begin
      if pa[i] <> pb[i] then
      begin
        Result := False;
        Exit;
      end;
    end;

  Result := True;
  {$POP}
end;

function MemFindByte_Scalar(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
var
  pb: PByte;
  i: SizeUInt;
begin
  if (len = 0) or (p = nil) then
  begin
    Result := -1;
    Exit;
  end;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if pb[i] = value then
    begin
      Result := PtrInt(i);
      Exit;
    end;
  end;

  Result := -1;
end;

function MemDiffRange_Scalar(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
var
  pa, pb: PByte;
  i: SizeUInt;
  foundFirst: Boolean;
begin
  firstDiff := 0;
  lastDiff := 0;

  if len = 0 then
  begin
    Result := False;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    if a <> b then
    begin
      firstDiff := 0;
      lastDiff := len - 1;
      Result := True;
    end
    else
      Result := False;
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);
  foundFirst := False;

  for i := 0 to len - 1 do
  begin
    if pa[i] <> pb[i] then
    begin
      if not foundFirst then
      begin
        firstDiff := i;
        foundFirst := True;
      end;
      lastDiff := i;
    end;
  end;

  Result := foundFirst;
end;

procedure MemCopy_Scalar(src, dst: Pointer; len: SizeUInt);
begin
  if (len = 0) or (src = nil) or (dst = nil) then
    Exit;

  Move(src^, dst^, len);
end;

procedure MemSet_Scalar(dst: Pointer; len: SizeUInt; value: Byte);
begin
  if (len = 0) or (dst = nil) then
    Exit;

  FillChar(dst^, len, value);
end;

procedure MemReverse_Scalar(p: Pointer; len: SizeUInt);
var
  pb: PByte;
  i: SizeUInt;
  temp: Byte;
begin
  if (len <= 1) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to (len div 2) - 1 do
  begin
    temp := pb[i];
    pb[i] := pb[len - 1 - i];
    pb[len - 1 - i] := temp;
  end;
end;

// 统计函数
// 优化为 8 字节批量读取并展开循环
function SumBytes_Scalar(p: Pointer; len: SizeUInt): UInt64;
var
  pb: PByte;
  pq: PQWord;
  i, qwordCount, remaining: SizeUInt;
  qval: QWord;
  sum0, sum1, sum2, sum3: UInt64;
begin
  {$PUSH}{$Q-}{$R-}  // Disable overflow/range checks for SIMD-style loop
  Result := 0;

  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  // 使用4路累加器减少依赖
  sum0 := 0;
  sum1 := 0;
  sum2 := 0;
  sum3 := 0;

  // 快速路径: 按 8 字节 (QWord) 批量读取
  qwordCount := len div 8;
  if qwordCount > 0 then
  begin
    pq := PQWord(pb);
    for i := 0 to qwordCount - 1 do
    begin
      qval := pq[i];
      // 提取并累加每个字节
      sum0 := sum0 + (qval and $FF);
      sum1 := sum1 + ((qval shr 8) and $FF);
      sum2 := sum2 + ((qval shr 16) and $FF);
      sum3 := sum3 + ((qval shr 24) and $FF);
      sum0 := sum0 + ((qval shr 32) and $FF);
      sum1 := sum1 + ((qval shr 40) and $FF);
      sum2 := sum2 + ((qval shr 48) and $FF);
      sum3 := sum3 + ((qval shr 56) and $FF);
    end;
    pb := pb + qwordCount * 8;
  end;

  // 处理剩余的 0-7 字节
  remaining := len mod 8;
  // 当 remaining=0 时，remaining-1 会下溢到 High(SizeUInt)
  if remaining > 0 then
    for i := 0 to remaining - 1 do
      sum0 := sum0 + pb[i];

  Result := sum0 + sum1 + sum2 + sum3;
  {$POP}
end;

procedure MinMaxBytes_Scalar(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
var
  pb: PByte;
  i: SizeUInt;
begin
  minVal := 255;
  maxVal := 0;

  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);
  minVal := pb[0];
  maxVal := pb[0];

  for i := 1 to len - 1 do
  begin
    if pb[i] < minVal then
      minVal := pb[i];
    if pb[i] > maxVal then
      maxVal := pb[i];
  end;
end;

function CountByte_Scalar(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
begin
  Result := 0;

  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if pb[i] = value then
      Inc(Result);
  end;
end;

// 文本处理函数
function Utf8Validate_Scalar(p: Pointer; len: SizeUInt): Boolean;
var
  pb: PByte;
  i: SizeUInt;
  b, b2: Byte;
  seqLen: Integer;
  j: Integer;
begin
  Result := True;

  // 空长度有效，空指针无效
  if len = 0 then
    Exit(True);
  if p = nil then
    Exit(False);

  pb := PByte(p);
  i := 0;

  while i < len do
  begin
    b := pb[i];

    // ASCII (0xxxxxxx)
    if (b and $80) = 0 then
    begin
      Inc(i);
      Continue;
    end;

    // Multi-byte sequence
    // 2-byte sequences: $C2-$DF (NOT $C0-$C1 which are overlong)
    if (b >= $C2) and (b <= $DF) then
      seqLen := 2
    // 3-byte sequences: $E0-$EF
    else if (b and $F0) = $E0 then
      seqLen := 3
    // 4-byte sequences: $F0-$F4
    else if (b >= $F0) and (b <= $F4) then
      seqLen := 4
    else
    begin
      // Invalid leading byte ($C0, $C1, $F5-$FF, or continuation byte)
      Result := False;
      Exit;
    end;

    // Check if we have enough bytes
    if i + SizeUInt(seqLen) > len then
    begin
      Result := False;
      Exit;
    end;

    // Check continuation bytes
    for j := 1 to seqLen - 1 do
    begin
      if (pb[i + SizeUInt(j)] and $C0) <> $80 then
      begin
        Result := False;
        Exit;
      end;
    end;

    // Additional checks for overlong sequences
    if seqLen = 3 then
    begin
      b2 := pb[i + 1];
      // E0 followed by 80-9F is overlong
      if (b = $E0) and (b2 < $A0) then
      begin
        Result := False;
        Exit;
      end;
      // ED followed by A0-BF is surrogate (invalid in UTF-8)
      if (b = $ED) and (b2 >= $A0) then
      begin
        Result := False;
        Exit;
      end;
    end
    else if seqLen = 4 then
    begin
      b2 := pb[i + 1];
      // F0 followed by 80-8F is overlong
      if (b = $F0) and (b2 < $90) then
      begin
        Result := False;
        Exit;
      end;
      // F4 followed by 90-BF is beyond Unicode range
      if (b = $F4) and (b2 >= $90) then
      begin
        Result := False;
        Exit;
      end;
    end;

    Inc(i, seqLen);
  end;
end;

function AsciiIEqual_Scalar(a, b: Pointer; len: SizeUInt): Boolean;
var
  pa, pb: PByte;
  i: SizeUInt;
  ca, cb: Byte;
begin
  if len = 0 then
  begin
    Result := True;
    Exit;
  end;

  if (a = nil) or (b = nil) then
  begin
    Result := (a = b);
    Exit;
  end;

  pa := PByte(a);
  pb := PByte(b);

  for i := 0 to len - 1 do
  begin
    ca := pa[i];
    cb := pb[i];

    // Convert to lowercase for comparison
    if (ca >= Ord('A')) and (ca <= Ord('Z')) then
      ca := ca + 32;
    if (cb >= Ord('A')) and (cb <= Ord('Z')) then
      cb := cb + 32;

    if ca <> cb then
    begin
      Result := False;
      Exit;
    end;
  end;

  Result := True;
end;

procedure ToLowerAscii_Scalar(p: Pointer; len: SizeUInt);
var
  pb: PByte;
  i: SizeUInt;
begin
  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if (pb[i] >= Ord('A')) and (pb[i] <= Ord('Z')) then
      pb[i] := pb[i] + 32;
  end;
end;

procedure ToUpperAscii_Scalar(p: Pointer; len: SizeUInt);
var
  pb: PByte;
  i: SizeUInt;
begin
  if (len = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  for i := 0 to len - 1 do
  begin
    if (pb[i] >= Ord('a')) and (pb[i] <= Ord('z')) then
      pb[i] := pb[i] - 32;
  end;
end;

// 搜索函数
function BytesIndexOf_Scalar(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
var
  ph, pn: PByte;
  i, j: SizeUInt;
  found: Boolean;
begin
  Result := -1;

  if (haystackLen = 0) or (needleLen = 0) or (haystack = nil) or (needle = nil) then
    Exit;

  if needleLen > haystackLen then
    Exit;

  ph := PByte(haystack);
  pn := PByte(needle);

  for i := 0 to haystackLen - needleLen do
  begin
    found := True;
    for j := 0 to needleLen - 1 do
    begin
      if ph[i + j] <> pn[j] then
      begin
        found := False;
        Break;
      end;
    end;

    if found then
    begin
      Result := PtrInt(i);
      Exit;
    end;
  end;
end;

// 位集函数
// 使用 256 字节查找表实现 O(1) 每字节的 popcount
const
  PopCountTable: array[0..255] of Byte = (
    0,1,1,2,1,2,2,3,1,2,2,3,2,3,3,4,  // 0x00-0x0F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x10-0x1F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x20-0x2F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x30-0x3F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x40-0x4F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x50-0x5F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x60-0x6F
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0x70-0x7F
    1,2,2,3,2,3,3,4,2,3,3,4,3,4,4,5,  // 0x80-0x8F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0x90-0x9F
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0xA0-0xAF
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0xB0-0xBF
    2,3,3,4,3,4,4,5,3,4,4,5,4,5,5,6,  // 0xC0-0xCF
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0xD0-0xDF
    3,4,4,5,4,5,5,6,4,5,5,6,5,6,6,7,  // 0xE0-0xEF
    4,5,5,6,5,6,6,7,5,6,6,7,6,7,7,8   // 0xF0-0xFF
  );

function BitsetPopCount_Scalar(p: Pointer; byteLen: SizeUInt): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
begin
  Result := 0;

  if (byteLen = 0) or (p = nil) then
    Exit;

  pb := PByte(p);

  // 使用查找表 O(1) 每字节，而非逐位循环 O(8)
  for i := 0 to byteLen - 1 do
    Result := Result + PopCountTable[pb[i]];
end;

// === Saturating Arithmetic Implementation ===
// 饱和算术：结果超出类型范围时钳位到边界值

{$PUSH}{$R-}{$Q-}  // 禁用溢出检查，我们自己处理饱和

// I8x16 Signed Saturating Add: [-128, 127]
function ScalarI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
  sum: Int32;
begin
  for i := 0 to 15 do
  begin
    sum := Int32(a.i[i]) + Int32(b.i[i]);
    if sum > 127 then
      Result.i[i] := 127
    else if sum < -128 then
      Result.i[i] := -128
    else
      Result.i[i] := Int8(sum);
  end;
end;

// I8x16 Signed Saturating Sub: [-128, 127]
function ScalarI8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
  diff: Int32;
begin
  for i := 0 to 15 do
  begin
    diff := Int32(a.i[i]) - Int32(b.i[i]);
    if diff > 127 then
      Result.i[i] := 127
    else if diff < -128 then
      Result.i[i] := -128
    else
      Result.i[i] := Int8(diff);
  end;
end;

// I16x8 Signed Saturating Add: [-32768, 32767]
function ScalarI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
  sum: Int32;
begin
  for i := 0 to 7 do
  begin
    sum := Int32(a.i[i]) + Int32(b.i[i]);
    if sum > 32767 then
      Result.i[i] := 32767
    else if sum < -32768 then
      Result.i[i] := -32768
    else
      Result.i[i] := Int16(sum);
  end;
end;

// I16x8 Signed Saturating Sub: [-32768, 32767]
function ScalarI16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
  diff: Int32;
begin
  for i := 0 to 7 do
  begin
    diff := Int32(a.i[i]) - Int32(b.i[i]);
    if diff > 32767 then
      Result.i[i] := 32767
    else if diff < -32768 then
      Result.i[i] := -32768
    else
      Result.i[i] := Int16(diff);
  end;
end;

// U8x16 Unsigned Saturating Add: [0, 255]
function ScalarU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
  sum: UInt32;
begin
  for i := 0 to 15 do
  begin
    sum := UInt32(a.u[i]) + UInt32(b.u[i]);
    if sum > 255 then
      Result.u[i] := 255
    else
      Result.u[i] := UInt8(sum);
  end;
end;

// U8x16 Unsigned Saturating Sub: [0, 255]
function ScalarU8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
  begin
    // 无符号减法：如果 b > a，结果饱和到 0
    if b.u[i] > a.u[i] then
      Result.u[i] := 0
    else
      Result.u[i] := a.u[i] - b.u[i];
  end;
end;

// U16x8 Unsigned Saturating Add: [0, 65535]
function ScalarU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
  sum: UInt32;
begin
  for i := 0 to 7 do
  begin
    sum := UInt32(a.u[i]) + UInt32(b.u[i]);
    if sum > 65535 then
      Result.u[i] := 65535
    else
      Result.u[i] := UInt16(sum);
  end;
end;

// U16x8 Unsigned Saturating Sub: [0, 65535]
function ScalarU16x8SatSub(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
  begin
    // 无符号减法：如果 b > a，结果饱和到 0
    if b.u[i] > a.u[i] then
      Result.u[i] := 0
    else
      Result.u[i] := a.u[i] - b.u[i];
  end;
end;

// Mask 操作实现
// === TMask2 操作 (2 有效位) ===
function ScalarMask2All(mask: TMask2): Boolean;
begin
  Result := (mask and $03) = $03;  // 两位都设置
end;

function ScalarMask2Any(mask: TMask2): Boolean;
begin
  Result := (mask and $03) <> 0;  // 至少一位设置
end;

function ScalarMask2None(mask: TMask2): Boolean;
begin
  Result := (mask and $03) = 0;  // 没有位设置
end;

function ScalarMask2PopCount(mask: TMask2): Integer;
var
  m: Byte;
begin
  m := mask and $03;
  Result := (m and 1) + ((m shr 1) and 1);
end;

function ScalarMask2FirstSet(mask: TMask2): Integer;
var
  m: Byte;
begin
  m := mask and $03;
  if m = 0 then
    Result := -1
  else if (m and 1) <> 0 then
    Result := 0
  else
    Result := 1;
end;

// === TMask4 操作 (4 有效位) ===
function ScalarMask4All(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) = $0F;
end;

function ScalarMask4Any(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) <> 0;
end;

function ScalarMask4None(mask: TMask4): Boolean;
begin
  Result := (mask and $0F) = 0;
end;

function ScalarMask4PopCount(mask: TMask4): Integer;
var
  m: Byte;
begin
  m := mask and $0F;
  Result := 0;
  while m <> 0 do
  begin
    Inc(Result, m and 1);
    m := m shr 1;
  end;
end;

function ScalarMask4FirstSet(mask: TMask4): Integer;
var
  m: Byte;
  i: Integer;
begin
  m := mask and $0F;
  if m = 0 then
    Exit(-1);
  for i := 0 to 3 do
    if (m and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

// === TMask8 操作 (8 有效位) ===
function ScalarMask8All(mask: TMask8): Boolean;
begin
  Result := mask = $FF;
end;

function ScalarMask8Any(mask: TMask8): Boolean;
begin
  Result := mask <> 0;
end;

function ScalarMask8None(mask: TMask8): Boolean;
begin
  Result := mask = 0;
end;

function ScalarMask8PopCount(mask: TMask8): Integer;
var
  m: Byte;
begin
  m := mask;
  Result := 0;
  while m <> 0 do
  begin
    Inc(Result, m and 1);
    m := m shr 1;
  end;
end;

function ScalarMask8FirstSet(mask: TMask8): Integer;
var
  i: Integer;
begin
  if mask = 0 then
    Exit(-1);
  for i := 0 to 7 do
    if (mask and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

// === TMask16 操作 (16 有效位) ===
function ScalarMask16All(mask: TMask16): Boolean;
begin
  Result := mask = $FFFF;
end;

function ScalarMask16Any(mask: TMask16): Boolean;
begin
  Result := mask <> 0;
end;

function ScalarMask16None(mask: TMask16): Boolean;
begin
  Result := mask = 0;
end;

function ScalarMask16PopCount(mask: TMask16): Integer;
var
  m: Word;
begin
  m := mask;
  Result := 0;
  while m <> 0 do
  begin
    Inc(Result, m and 1);
    m := m shr 1;
  end;
end;

function ScalarMask16FirstSet(mask: TMask16): Integer;
var
  i: Integer;
begin
  if mask = 0 then
    Exit(-1);
  for i := 0 to 15 do
    if (mask and (1 shl i)) <> 0 then
      Exit(i);
  Result := -1;
end;

// F64x2 Select 实现
function ScalarSelectF64x2(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2;
begin
  // mask 位 0 控制元素 0，位 1 控制元素 1
  // 位为 1 时选择 a，位为 0 时选择 b
  if (mask and 1) <> 0 then
    Result.d[0] := a.d[0]
  else
    Result.d[0] := b.d[0];
  if (mask and 2) <> 0 then
    Result.d[1] := a.d[1]
  else
    Result.d[1] := b.d[1];
end;

function ScalarSelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if (mask and (1 shl i)) <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
end;

function ScalarSelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if (mask and (1 shl i)) <> 0 then
      Result.d[i] := a.d[i]
    else
      Result.d[i] := b.d[i];
end;

// Select 操作实现 (条件选择: mask[i] != 0 ? a[i] : b[i])

function ScalarSelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := (a.i[i] and mask.i[i]) or (b.i[i] and (not mask.i[i]));
end;

function ScalarSelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
var i: Integer;
    la, lb, lr: UInt32;
begin
  for i := 0 to 7 do
  begin
    la := PDWord(@a.f[i])^;
    lb := PDWord(@b.f[i])^;
    lr := (la and mask.u[i]) or (lb and (not mask.u[i]));
    PDWord(@Result.f[i])^ := lr;
  end;
end;

function ScalarSelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;
var i: Integer;
    la, lb, lr: UInt64;
begin
  for i := 0 to 3 do
  begin
    la := PQWord(@a.d[i])^;
    lb := PQWord(@b.d[i])^;
    lr := (la and mask.u[i]) or (lb and (not mask.u[i]));
    PQWord(@Result.d[i])^ := lr;
  end;
end;

// === Narrow Integer Operations ===

// ============================================================================
// I16x8 Operations (16 functions)
// ============================================================================

function ScalarAddI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarMulI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] * b.i[i];
end;

function ScalarAndI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI16x8(const a: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 7 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.i[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := Int16(UInt16(a.i[i]) shr count);
  end
  else
    Result := a;
end;

function ScalarShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      if a.i[i] < 0 then
        Result.i[i] := -1
      else
        Result.i[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for I16x8
function ScalarCmpLeI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI16x8(const a, b: TVecI16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] < b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarMaxI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.i[i] > b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

// ============================================================================
// I8x16 Operations (12 functions)
// ============================================================================

function ScalarAddI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] + b.i[i];
end;

function ScalarSubI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] - b.i[i];
end;

function ScalarAndI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] and b.i[i];
end;

function ScalarOrI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] or b.i[i];
end;

function ScalarXorI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := a.i[i] xor b.i[i];
end;

function ScalarNotI8x16(const a: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := not a.i[i];
end;

function ScalarAndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 15 do
    Result.i[i] := (not a.i[i]) and b.i[i];
end;

function ScalarCmpEqI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] = b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for I8x16
function ScalarCmpLeI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] <= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] >= b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeI8x16(const a, b: TVecI8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.i[i] <> b.i[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

function ScalarMaxI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result.i[i] := a.i[i]
    else
      Result.i[i] := b.i[i];
end;

// ============================================================================
// U32x4 Operations (17 functions)
// ============================================================================

function ScalarAddU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU32x4(const a: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
var
  i: Integer;
begin
  if count >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
var
  i: Integer;
begin
  if count >= 32 then
  begin
    for i := 0 to 3 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 3 do
      Result.u[i] := a.u[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU32x4(const a, b: TVecU32x4): TMask4;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 3 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU32x4(const a, b: TVecU32x4): TMask4;
var
  LIndex: Integer;
begin
  Result := 0;
  for LIndex := 0 to 3 do
    if a.u[LIndex] <> b.u[LIndex] then
      Result := Result or (1 shl LIndex);
end;

function ScalarMinU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  i: Integer;
begin
  for i := 0 to 3 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

// ============================================================================
// U32x8 Operations (256-bit, 8x32-bit unsigned)
// ============================================================================

function ScalarAddU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU32x8(const a: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 7 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
var i: Integer;
begin
  if count >= 32 then
  begin
    for i := 0 to 7 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
var i: Integer;
begin
  if count >= 32 then
  begin
    for i := 0 to 7 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLeU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU32x8(const a, b: TVecU32x8): TMask8;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU32x8(const a, b: TVecU32x8): TVecU32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

// ============================================================================
// U16x8 Operations (15 functions)
// ============================================================================

function ScalarAddU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarMulU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] * b.u[i];
end;

function ScalarAndU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU16x8(const a: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 7 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shl count;
  end
  else
    Result := a;
end;

function ScalarShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
var
  i: Integer;
begin
  if count >= 16 then
  begin
    for i := 0 to 7 do
      Result.u[i] := 0;
  end
  else if count > 0 then
  begin
    for i := 0 to 7 do
      Result.u[i] := a.u[i] shr count;
  end
  else
    Result := a;
end;

function ScalarCmpEqU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for U16x8
function ScalarCmpLeU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU16x8(const a, b: TVecU16x8): TMask8;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  i: Integer;
begin
  for i := 0 to 7 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

// ============================================================================
// U8x16 Operations (12 functions)
// ============================================================================

function ScalarAddU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] + b.u[i];
end;

function ScalarSubU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] - b.u[i];
end;

function ScalarAndU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] and b.u[i];
end;

function ScalarOrU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] or b.u[i];
end;

function ScalarXorU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := a.u[i] xor b.u[i];
end;

function ScalarNotU8x16(const a: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    Result.u[i] := not a.u[i];
end;

function ScalarAndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  // AndNot: (not a) and b - 与 SIMD 指令 PANDN 语义一致
  for i := 0 to 15 do
    Result.u[i] := (not a.u[i]) and b.u[i];
end;

function ScalarCmpEqU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] = b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpLtU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] < b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGtU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] > b.u[i] then
      Result := Result or (1 shl i);
end;

// CmpLe/CmpGe/CmpNe for U8x16
function ScalarCmpLeU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] <= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpGeU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] >= b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarCmpNeU8x16(const a, b: TVecU8x16): TMask16;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if a.u[i] <> b.u[i] then
      Result := Result or (1 shl i);
end;

function ScalarMinU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.u[i] < b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

function ScalarMaxU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  i: Integer;
begin
  for i := 0 to 15 do
    if a.u[i] > b.u[i] then
      Result.u[i] := a.u[i]
    else
      Result.u[i] := b.u[i];
end;

{$POP}

initialization
  // Register scalar backend on unit initialization
  RegisterScalarBackend;

end.
