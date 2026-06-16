unit nextpas.core.simd.scalar;
{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
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
  nextpas.core.simd.mathutil;
{$I nextpas.core.simd.scalar.arith.inc}
{$I nextpas.core.simd.scalar.compare.inc}
{$I nextpas.core.simd.scalar.math.inc}
{$I nextpas.core.simd.scalar.reduce.inc}
{$I nextpas.core.simd.scalar.memory.inc}
{$I nextpas.core.simd.scalar.convert.inc}
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
{$I nextpas.core.simd.scalar.facade.inc}
{$I nextpas.core.simd.scalar.bitwise.inc}
{$I nextpas.core.simd.scalar.narrow.inc}
initialization
  // Register scalar backend on unit initialization
  RegisterScalarBackend;
end.
