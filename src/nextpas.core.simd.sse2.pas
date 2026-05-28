unit nextpas.core.simd.sse2;


{$I nextpas.core.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.backend.priority;

// === SSE2 Backend Adapter ===
// Role:
// - thin backend adapter / backend assembly layer
// - owns TVec* / TMask* facade semantics, dispatch registration, compare-mask translation
// - wide_emulation, mem/text/stat helpers, and multi-register composition stay here
// - must not depend on nextpas.core.simd.intrinsics.sse2
// Current production truth source for SSE2 remains this unit.

// Register the SSE2 backend
procedure RegisterSSE2Backend;

// === SSE2 门面函数声明 ===

// 内存操作函数
function MemEqual_SSE2(a, b: Pointer; len: SizeUInt): LongBool;
function MemFindByte_SSE2(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
procedure MemCopy_SSE2(src, dst: Pointer; len: SizeUInt);
procedure MemSet_SSE2(dst: Pointer; len: SizeUInt; value: Byte);

// 统计函数
function SumBytes_SSE2(p: Pointer; len: SizeUInt): UInt64;
function CountByte_SSE2(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;

// 饱和算术（SSE2 PADDS/PSUBS 指令加速）
function SSE2I8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
function SSE2I8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
function SSE2I16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
function SSE2I16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
function SSE2U8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
function SSE2U8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
function SSE2U16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
function SSE2U16x8SatSub(const a, b: TVecU16x8): TVecU16x8;

// I16x8 操作（SSE2 PADDW/PSUBW/PMULLW 等指令）
function SSE2AddI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2SubI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2MulI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2AndI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2OrI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2XorI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2NotI16x8(const a: TVecI16x8): TVecI16x8;
function SSE2AndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2ShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
function SSE2ShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
function SSE2ShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
function SSE2CmpEqI16x8(const a, b: TVecI16x8): TMask8;
function SSE2CmpLtI16x8(const a, b: TVecI16x8): TMask8;
function SSE2CmpGtI16x8(const a, b: TVecI16x8): TMask8;
function SSE2CmpLeI16x8(const a, b: TVecI16x8): TMask8;
function SSE2CmpGeI16x8(const a, b: TVecI16x8): TMask8;
function SSE2CmpNeI16x8(const a, b: TVecI16x8): TMask8;
function SSE2MinI16x8(const a, b: TVecI16x8): TVecI16x8;
function SSE2MaxI16x8(const a, b: TVecI16x8): TVecI16x8;

// I8x16 操作（SSE2 PADDB/PSUBB 等指令）
function SSE2AddI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2SubI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2AndI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2OrI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2XorI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2NotI8x16(const a: TVecI8x16): TVecI8x16;
function SSE2AndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2CmpEqI8x16(const a, b: TVecI8x16): TMask16;
function SSE2CmpLtI8x16(const a, b: TVecI8x16): TMask16;
function SSE2CmpGtI8x16(const a, b: TVecI8x16): TMask16;
function SSE2CmpLeI8x16(const a, b: TVecI8x16): TMask16;
function SSE2CmpGeI8x16(const a, b: TVecI8x16): TMask16;
function SSE2CmpNeI8x16(const a, b: TVecI8x16): TMask16;
function SSE2MinI8x16(const a, b: TVecI8x16): TVecI8x16;
function SSE2MaxI8x16(const a, b: TVecI8x16): TVecI8x16;

// U32x4 操作
function SSE2AddU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2SubU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2MulU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2AndU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2OrU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2XorU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2NotU32x4(const a: TVecU32x4): TVecU32x4;
function SSE2AndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2ShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
function SSE2ShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
function SSE2CmpEqU32x4(const a, b: TVecU32x4): TMask4;
function SSE2CmpLtU32x4(const a, b: TVecU32x4): TMask4;
function SSE2CmpGtU32x4(const a, b: TVecU32x4): TMask4;
function SSE2CmpLeU32x4(const a, b: TVecU32x4): TMask4;
function SSE2CmpGeU32x4(const a, b: TVecU32x4): TMask4;
function SSE2CmpNeU32x4(const a, b: TVecU32x4): TMask4;
function SSE2MinU32x4(const a, b: TVecU32x4): TVecU32x4;
function SSE2MaxU32x4(const a, b: TVecU32x4): TVecU32x4;

// U16x8 操作
function SSE2AddU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2SubU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2MulU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2AndU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2OrU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2XorU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2NotU16x8(const a: TVecU16x8): TVecU16x8;
function SSE2AndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2ShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
function SSE2ShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
function SSE2CmpEqU16x8(const a, b: TVecU16x8): TMask8;
function SSE2CmpLtU16x8(const a, b: TVecU16x8): TMask8;
function SSE2CmpGtU16x8(const a, b: TVecU16x8): TMask8;
function SSE2CmpLeU16x8(const a, b: TVecU16x8): TMask8;
function SSE2CmpGeU16x8(const a, b: TVecU16x8): TMask8;
function SSE2CmpNeU16x8(const a, b: TVecU16x8): TMask8;
function SSE2MinU16x8(const a, b: TVecU16x8): TVecU16x8;
function SSE2MaxU16x8(const a, b: TVecU16x8): TVecU16x8;

// U8x16 操作
function SSE2AddU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2SubU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2AndU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2OrU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2XorU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2NotU8x16(const a: TVecU8x16): TVecU8x16;
function SSE2AndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2CmpEqU8x16(const a, b: TVecU8x16): TMask16;
function SSE2CmpLtU8x16(const a, b: TVecU8x16): TMask16;
function SSE2CmpGtU8x16(const a, b: TVecU8x16): TMask16;
function SSE2CmpLeU8x16(const a, b: TVecU8x16): TMask16;
function SSE2CmpGeU8x16(const a, b: TVecU8x16): TMask16;
function SSE2CmpNeU8x16(const a, b: TVecU8x16): TMask16;
function SSE2MinU8x16(const a, b: TVecU8x16): TVecU8x16;
function SSE2MaxU8x16(const a, b: TVecU8x16): TVecU8x16;

// I64x2 比较操作（SSE2 模拟 - 无原生 64 位比较指令）
// SSE2 没有 PCMPGTQ 指令（SSE4.2+），使用 32 位比较组合模拟
function SSE2CmpEqI64x2(const a, b: TVecI64x2): TMask2;
function SSE2CmpNeI64x2(const a, b: TVecI64x2): TMask2;
function SSE2CmpGtI64x2(const a, b: TVecI64x2): TMask2;
function SSE2CmpLtI64x2(const a, b: TVecI64x2): TMask2;
function SSE2CmpGeI64x2(const a, b: TVecI64x2): TMask2;
function SSE2CmpLeI64x2(const a, b: TVecI64x2): TMask2;

// ============================================================================
// 512-bit 向量的 SSE2 渐进降级实现
// 策略: 使用 2×256-bit 操作 (利用已有的 F32x8/F64x4/I32x8)
// ============================================================================

// === F32x16 操作 (16×Float32) ===
function SSE2AddF32x16(const a, b: TVecF32x16): TVecF32x16;
function SSE2SubF32x16(const a, b: TVecF32x16): TVecF32x16;
function SSE2MulF32x16(const a, b: TVecF32x16): TVecF32x16;
function SSE2DivF32x16(const a, b: TVecF32x16): TVecF32x16;
function SSE2AbsF32x16(const a: TVecF32x16): TVecF32x16;
function SSE2SqrtF32x16(const a: TVecF32x16): TVecF32x16;
function SSE2MinF32x16(const a, b: TVecF32x16): TVecF32x16;
function SSE2MaxF32x16(const a, b: TVecF32x16): TVecF32x16;
function SSE2FmaF32x16(const a, b, c: TVecF32x16): TVecF32x16;
function SSE2FloorF32x16(const a: TVecF32x16): TVecF32x16;
function SSE2CeilF32x16(const a: TVecF32x16): TVecF32x16;
function SSE2RoundF32x16(const a: TVecF32x16): TVecF32x16;
function SSE2TruncF32x16(const a: TVecF32x16): TVecF32x16;
function SSE2ClampF32x16(const a, minVal, maxVal: TVecF32x16): TVecF32x16;
function SSE2ReduceAddF32x16(const a: TVecF32x16): Single;
function SSE2ReduceMinF32x16(const a: TVecF32x16): Single;
function SSE2ReduceMaxF32x16(const a: TVecF32x16): Single;
function SSE2ReduceMulF32x16(const a: TVecF32x16): Single;
function SSE2LoadF32x16(p: PSingle): TVecF32x16;
procedure SSE2StoreF32x16(p: PSingle; const a: TVecF32x16);
function SSE2SplatF32x16(value: Single): TVecF32x16;
function SSE2ZeroF32x16: TVecF32x16;
function SSE2CmpEqF32x16(const a, b: TVecF32x16): TMask16;
function SSE2CmpLtF32x16(const a, b: TVecF32x16): TMask16;
function SSE2CmpLeF32x16(const a, b: TVecF32x16): TMask16;
function SSE2CmpGtF32x16(const a, b: TVecF32x16): TMask16;
function SSE2CmpGeF32x16(const a, b: TVecF32x16): TMask16;
function SSE2CmpNeF32x16(const a, b: TVecF32x16): TMask16;
function SSE2SelectF32x16(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16;

// === F64x8 操作 (8×Float64) ===
function SSE2AddF64x8(const a, b: TVecF64x8): TVecF64x8;
function SSE2SubF64x8(const a, b: TVecF64x8): TVecF64x8;
function SSE2MulF64x8(const a, b: TVecF64x8): TVecF64x8;
function SSE2DivF64x8(const a, b: TVecF64x8): TVecF64x8;
function SSE2AbsF64x8(const a: TVecF64x8): TVecF64x8;
function SSE2SqrtF64x8(const a: TVecF64x8): TVecF64x8;
function SSE2MinF64x8(const a, b: TVecF64x8): TVecF64x8;
function SSE2MaxF64x8(const a, b: TVecF64x8): TVecF64x8;
function SSE2FmaF64x8(const a, b, c: TVecF64x8): TVecF64x8;
function SSE2FloorF64x8(const a: TVecF64x8): TVecF64x8;
function SSE2CeilF64x8(const a: TVecF64x8): TVecF64x8;
function SSE2RoundF64x8(const a: TVecF64x8): TVecF64x8;
function SSE2TruncF64x8(const a: TVecF64x8): TVecF64x8;
function SSE2ClampF64x8(const a, minVal, maxVal: TVecF64x8): TVecF64x8;
function SSE2ReduceAddF64x8(const a: TVecF64x8): Double;
function SSE2ReduceMinF64x8(const a: TVecF64x8): Double;
function SSE2ReduceMaxF64x8(const a: TVecF64x8): Double;
function SSE2ReduceMulF64x8(const a: TVecF64x8): Double;
function SSE2LoadF64x8(p: PDouble): TVecF64x8;
procedure SSE2StoreF64x8(p: PDouble; const a: TVecF64x8);
function SSE2SplatF64x8(value: Double): TVecF64x8;
function SSE2ZeroF64x8: TVecF64x8;
function SSE2CmpEqF64x8(const a, b: TVecF64x8): TMask8;
function SSE2CmpLtF64x8(const a, b: TVecF64x8): TMask8;
function SSE2CmpLeF64x8(const a, b: TVecF64x8): TMask8;
function SSE2CmpGtF64x8(const a, b: TVecF64x8): TMask8;
function SSE2CmpGeF64x8(const a, b: TVecF64x8): TMask8;
function SSE2CmpNeF64x8(const a, b: TVecF64x8): TMask8;
function SSE2SelectF64x8(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8;

// Select 操作 (条件选择: mask[i] != 0 ? a[i] : b[i])
function SSE2SelectI32x4(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4;
function SSE2SelectF32x8(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8;
function SSE2SelectF64x4(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4;

// === I32x16 操作 (16×Int32) ===
function SSE2AddI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2SubI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2MulI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2AndI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2OrI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2XorI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2NotI32x16(const a: TVecI32x16): TVecI32x16;
function SSE2AndNotI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2ShiftLeftI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
function SSE2ShiftRightI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
function SSE2ShiftRightArithI32x16(const a: TVecI32x16; count: Integer): TVecI32x16;
function SSE2CmpEqI32x16(const a, b: TVecI32x16): TMask16;
function SSE2CmpLtI32x16(const a, b: TVecI32x16): TMask16;
function SSE2CmpGtI32x16(const a, b: TVecI32x16): TMask16;
function SSE2CmpLeI32x16(const a, b: TVecI32x16): TMask16;
function SSE2CmpGeI32x16(const a, b: TVecI32x16): TMask16;
function SSE2CmpNeI32x16(const a, b: TVecI32x16): TMask16;
function SSE2MinI32x16(const a, b: TVecI32x16): TVecI32x16;
function SSE2MaxI32x16(const a, b: TVecI32x16): TVecI32x16;

// ============================================================================
// I64x4 操作 (256-bit AVX2 仿真，使用 2×I64x2)
// ============================================================================
function SSE2AddI64x4(const a, b: TVecI64x4): TVecI64x4;
function SSE2SubI64x4(const a, b: TVecI64x4): TVecI64x4;
function SSE2AndI64x4(const a, b: TVecI64x4): TVecI64x4;
function SSE2OrI64x4(const a, b: TVecI64x4): TVecI64x4;
function SSE2XorI64x4(const a, b: TVecI64x4): TVecI64x4;
function SSE2NotI64x4(const a: TVecI64x4): TVecI64x4;
function SSE2AndNotI64x4(const a, b: TVecI64x4): TVecI64x4;
function SSE2ShiftLeftI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
function SSE2ShiftRightI64x4(const a: TVecI64x4; count: Integer): TVecI64x4;
function SSE2CmpEqI64x4(const a, b: TVecI64x4): TMask4;
function SSE2CmpLtI64x4(const a, b: TVecI64x4): TMask4;
function SSE2CmpGtI64x4(const a, b: TVecI64x4): TMask4;
function SSE2CmpLeI64x4(const a, b: TVecI64x4): TMask4;
function SSE2CmpGeI64x4(const a, b: TVecI64x4): TMask4;
function SSE2CmpNeI64x4(const a, b: TVecI64x4): TMask4;
function SSE2LoadI64x4(p: PInt64): TVecI64x4;
procedure SSE2StoreI64x4(p: PInt64; const a: TVecI64x4);
function SSE2SplatI64x4(value: Int64): TVecI64x4;
function SSE2ZeroI64x4: TVecI64x4;

// ============================================================================
// U32x8 操作 (256-bit AVX2 仿真，使用 2×U32x4)
// ============================================================================
function SSE2AddU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2SubU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2MulU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2AndU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2OrU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2XorU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2NotU32x8(const a: TVecU32x8): TVecU32x8;
function SSE2AndNotU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2ShiftLeftU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
function SSE2ShiftRightU32x8(const a: TVecU32x8; count: Integer): TVecU32x8;
function SSE2CmpEqU32x8(const a, b: TVecU32x8): TMask8;
function SSE2CmpLtU32x8(const a, b: TVecU32x8): TMask8;
function SSE2CmpGtU32x8(const a, b: TVecU32x8): TMask8;
function SSE2CmpLeU32x8(const a, b: TVecU32x8): TMask8;
function SSE2CmpGeU32x8(const a, b: TVecU32x8): TMask8;
function SSE2CmpNeU32x8(const a, b: TVecU32x8): TMask8;
function SSE2MinU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2MaxU32x8(const a, b: TVecU32x8): TVecU32x8;
function SSE2SplatU32x8(value: UInt32): TVecU32x8;

// ============================================================================
// U64x4 操作 (256-bit AVX2 仿真，使用 2×U64x2)
// ============================================================================
function SSE2AddU64x4(const a, b: TVecU64x4): TVecU64x4;
function SSE2SubU64x4(const a, b: TVecU64x4): TVecU64x4;
function SSE2AndU64x4(const a, b: TVecU64x4): TVecU64x4;
function SSE2OrU64x4(const a, b: TVecU64x4): TVecU64x4;
function SSE2XorU64x4(const a, b: TVecU64x4): TVecU64x4;
function SSE2NotU64x4(const a: TVecU64x4): TVecU64x4;
function SSE2ShiftLeftU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
function SSE2ShiftRightU64x4(const a: TVecU64x4; count: Integer): TVecU64x4;
function SSE2CmpEqU64x4(const a, b: TVecU64x4): TMask4;
function SSE2CmpLtU64x4(const a, b: TVecU64x4): TMask4;
function SSE2CmpGtU64x4(const a, b: TVecU64x4): TMask4;
function SSE2CmpLeU64x4(const a, b: TVecU64x4): TMask4;
function SSE2CmpGeU64x4(const a, b: TVecU64x4): TMask4;
function SSE2CmpNeU64x4(const a, b: TVecU64x4): TMask4;

// ============================================================================
// I64x8 操作 (512-bit AVX-512 仿真，使用 4×I64x2 或 2×I64x4)
// ============================================================================
function SSE2AddI64x8(const a, b: TVecI64x8): TVecI64x8;
function SSE2SubI64x8(const a, b: TVecI64x8): TVecI64x8;
function SSE2AndI64x8(const a, b: TVecI64x8): TVecI64x8;
function SSE2OrI64x8(const a, b: TVecI64x8): TVecI64x8;
function SSE2XorI64x8(const a, b: TVecI64x8): TVecI64x8;
function SSE2NotI64x8(const a: TVecI64x8): TVecI64x8;
function SSE2ShiftLeftI64x8(const a: TVecI64x8; count: Integer): TVecI64x8;
function SSE2ShiftRightI64x8(const a: TVecI64x8; count: Integer): TVecI64x8;
function SSE2CmpEqI64x8(const a, b: TVecI64x8): TMask8;
function SSE2CmpLtI64x8(const a, b: TVecI64x8): TMask8;
function SSE2CmpGtI64x8(const a, b: TVecI64x8): TMask8;
function SSE2CmpLeI64x8(const a, b: TVecI64x8): TMask8;
function SSE2CmpGeI64x8(const a, b: TVecI64x8): TMask8;
function SSE2CmpNeI64x8(const a, b: TVecI64x8): TMask8;
function SSE2LoadI64x8(p: PInt64): TVecI64x8;
procedure SSE2StoreI64x8(p: PInt64; const a: TVecI64x8);
function SSE2SplatI64x8(value: Int64): TVecI64x8;
function SSE2ZeroI64x8: TVecI64x8;

// ============================================================================
// Extract/Insert 操作 (通过数组索引实现)
// ============================================================================
// F64x2
function SSE2ExtractF64x2(const a: TVecF64x2; index: Integer): Double;
function SSE2InsertF64x2(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2;
// I32x4
function SSE2ExtractI32x4(const a: TVecI32x4; index: Integer): Int32;
function SSE2InsertI32x4(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
// I64x2
function SSE2ExtractI64x2(const a: TVecI64x2; index: Integer): Int64;
function SSE2InsertI64x2(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2;
// F32x8
function SSE2ExtractF32x8(const a: TVecF32x8; index: Integer): Single;
function SSE2InsertF32x8(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8;
// F64x4
function SSE2ExtractF64x4(const a: TVecF64x4; index: Integer): Double;
function SSE2InsertF64x4(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4;
// I32x8
function SSE2ExtractI32x8(const a: TVecI32x8; index: Integer): Int32;
function SSE2InsertI32x8(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8;
// I64x4
function SSE2ExtractI64x4(const a: TVecI64x4; index: Integer): Int64;
function SSE2InsertI64x4(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4;
// F32x16
function SSE2ExtractF32x16(const a: TVecF32x16; index: Integer): Single;
function SSE2InsertF32x16(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16;
// I32x16
function SSE2ExtractI32x16(const a: TVecI32x16; index: Integer): Int32;
function SSE2InsertI32x16(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16;

// ============================================================================
// Facade 函数 (高级内存和文本操作)
// ============================================================================
function MemDiffRange_SSE2(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
procedure MemReverse_SSE2(p: Pointer; len: SizeUInt);
procedure ToLowerAscii_SSE2(p: Pointer; len: SizeUInt);
procedure ToUpperAscii_SSE2(p: Pointer; len: SizeUInt);
function AsciiIEqual_SSE2(a, b: Pointer; len: SizeUInt): Boolean;
function BytesIndexOf_SSE2(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt;
function Utf8Validate_SSE2(p: Pointer; len: SizeUInt): Boolean;

implementation

uses
  SysUtils,
  Math,  // RTL Math 单元
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.scalar,
  nextpas.core.simd.intrinsics.base,
  nextpas.core.simd.intrinsics.x86.sse2;

{$PUSH}
{$WARN 5026 OFF} // 低层桥接函数通过 raw leaf 间接使用参数，FPC 误报“未使用”

procedure Vec128ToRaw(const a; out raw: TM128); inline;
begin
  raw := PTM128(@a)^;
end;

procedure RawToVec128(const raw: TM128; out a); inline;
begin
  PTM128(@a)^ := raw;
end;

function RawWordMaskToMask8(const raw: TM128): TMask8; inline;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to 7 do
    if raw.m128i_u16[i] <> 0 then
      Result := Result or (1 shl i);
end;

// === SSE2 128-bit Bitwise Raw Helpers ===
// Typed wrappers keep dispatch signatures distinct; these kernels own the
// shared 128-bit bitwise behavior across lane width and signedness.

procedure SSE2AndVecRaw(const aPtr, bPtr, rPtr: Pointer); inline;
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pand   xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2OrVecRaw(const aPtr, bPtr, rPtr: Pointer); inline;
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    por    xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2XorVecRaw(const aPtr, bPtr, rPtr: Pointer); inline;
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pxor   xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2NotVecRaw(const aPtr, rPtr: Pointer); inline;
var
  pa, pr: Pointer;
begin
  pa := aPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rcx, pr
    movdqu xmm0, [rax]
    pcmpeqd xmm1, xmm1
    pxor   xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2AndNotVecRaw(const aPtr, bPtr, rPtr: Pointer); inline;
var
  pa, pb, pr: Pointer;
begin
  pa := aPtr;
  pb := bPtr;
  pr := rPtr;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pandn  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

// === SSE2 128-bit Shift Raw Helpers ===
// Typed wrappers and wide-emulation lanes should delegate to these helpers
// instead of duplicating the same load/shift/store sequence per width.

procedure SSE2ShiftLeftWordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psllw  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftRightWordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psrlw  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftRightArithWordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psraw  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftLeftDwordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    pslld  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftRightDwordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psrld  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftRightArithDwordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psrad  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftLeftQwordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psllq  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

procedure SSE2ShiftRightQwordVecRaw(const aPtr, rPtr: Pointer; aCount: Integer); inline;
var
  LPa, LPr: Pointer;
begin
  LPa := aPtr;
  LPr := rPtr;
  asm
    mov    rax, LPa
    mov    rcx, LPr
    mov    edx, aCount
    movdqu xmm0, [rax]
    movd   xmm1, edx
    psrlq  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

// === SSE2 Arithmetic Operations ===
// Note: FPC x86-64 calling convention:
//   - First 6 integer/pointer args: RDI, RSI, RDX, RCX, R8, R9
//   - Float args: XMM0-XMM7
//   - Result pointer for large structs: hidden first arg in RDI
//   - For const record params, pointer is passed

function SSE2AddF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    addps  xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE2SubF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    subps  xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE2MulF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    mulps  xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE2DivF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    divps  xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE2AddF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    addpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

function SSE2SubF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    subpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

function SSE2MulF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    mulpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

function SSE2DivF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    divpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

// ============================================================================
// F64x2 Math Operations (SSE2)
// ============================================================================

function SSE2SqrtF64x2(const a: TVecF64x2): TVecF64x2;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movupd xmm0, [rax]
    sqrtpd xmm0, xmm0
    movupd [rcx], xmm0
  end;
end;

function SSE2MinF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    minpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

function SSE2MaxF64x2(const a, b: TVecF64x2): TVecF64x2;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    maxpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

function SSE2AbsF64x2(const a: TVecF64x2): TVecF64x2;
var
  pa, pr: Pointer;
const
  SignMask: array[0..1] of UInt64 = ($7FFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF);
begin
  pa := @a;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rip + SignMask]
    andpd  xmm0, xmm1
    movupd [rcx], xmm0
  end;
end;

// ============================================================================
// F64x2 Comparison Operations (SSE2)
// ============================================================================

function SSE2CmpEqF64x2(const a, b: TVecF64x2): TMask2;
var pa, pb: Pointer; mask: Integer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    cmpeqpd xmm0, xmm1
    movmskpd eax, xmm0
    mov mask, eax
  end;
  Result := TMask2(mask);
end;

function SSE2CmpLtF64x2(const a, b: TVecF64x2): TMask2;
var pa, pb: Pointer; mask: Integer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    cmpltpd xmm0, xmm1
    movmskpd eax, xmm0
    mov mask, eax
  end;
  Result := TMask2(mask);
end;

function SSE2CmpLeF64x2(const a, b: TVecF64x2): TMask2;
var pa, pb: Pointer; mask: Integer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movupd xmm0, [rax]
    movupd xmm1, [rdx]
    cmplepd xmm0, xmm1
    movmskpd eax, xmm0
    mov mask, eax
  end;
  Result := TMask2(mask);
end;

function SSE2CmpGtF64x2(const a, b: TVecF64x2): TMask2;
var pa, pb: Pointer; mask: Integer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movupd xmm0, [rdx]
    movupd xmm1, [rax]
    cmpltpd xmm0, xmm1
    movmskpd eax, xmm0
    mov mask, eax
  end;
  Result := TMask2(mask);
end;

function SSE2CmpGeF64x2(const a, b: TVecF64x2): TMask2;
var pa, pb: Pointer; mask: Integer;
begin
  pa := @a; pb := @b;
  asm
    mov rax, pa
    mov rdx, pb
    movupd xmm0, [rdx]
    movupd xmm1, [rax]
    cmplepd xmm0, xmm1
    movmskpd eax, xmm0
    mov mask, eax
  end;
  Result := TMask2(mask);
end;

function SSE2CmpNeF64x2(const a, b: TVecF64x2): TMask2;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpneq_pd(LA, LB);
  Result := TMask2(simd_movemask_pd(LR));
end;

// ============================================================================
// F64x2 Utility Operations (SSE2)
// ============================================================================

function SSE2LoadF64x2(p: PDouble): TVecF64x2;
var
  LR: TM128;
begin
  LR := simd_loadu_pd(p);
  RawToVec128(LR, Result);
end;

function SSE2SplatF64x2(value: Double): TVecF64x2;
var
  LR: TM128;
begin
  LR := simd_set1_pd(value);
  RawToVec128(LR, Result);
end;

function SSE2ZeroF64x2: TVecF64x2;
var
  LR: TM128;
begin
  LR := simd_setzero_pd;
  RawToVec128(LR, Result);
end;

procedure SSE2StoreF64x2(p: PDouble; const v: TVecF64x2);
var
  LV: TM128;
begin
  Vec128ToRaw(v, LV);
  simd_storeu_pd(p, LV);
end;

// ============================================================================
// I32x4 Bitwise Operations (SSE2)
// ============================================================================

function SSE2AndI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_and_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2OrI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_or_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2XorI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_xor_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2NotI32x4(const a: TVecI32x4): TVecI32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_xor_si128(LA, simd_setzero_si128);
  RawToVec128(LR, Result);
end;

function SSE2AndNotI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_andnot_si128(LA, LB);
  RawToVec128(LR, Result);
end;

// ============================================================================
// I32x4 Shift Operations (SSE2)
// ============================================================================

function SSE2ShiftLeftI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_slli_epi32(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2ShiftRightI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_srli_epi32(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2ShiftRightArithI32x4(const a: TVecI32x4; count: Integer): TVecI32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_srai_epi32(LA, count);
  RawToVec128(LR, Result);
end;

// ============================================================================
// I32x4 Comparison Operations (SSE2)
// ============================================================================

function SSE2CmpEqI32x4(const a, b: TVecI32x4): TMask4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpeq_epi32(LA, LB);
  Result := TMask4(simd_movemask_ps(LR));
end;

function SSE2CmpGtI32x4(const a, b: TVecI32x4): TMask4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpgt_epi32(LA, LB);
  Result := TMask4(simd_movemask_ps(LR));
end;

function SSE2CmpLtI32x4(const a, b: TVecI32x4): TMask4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmplt_epi32(LA, LB);
  Result := TMask4(simd_movemask_ps(LR));
end;

function SSE2CmpLeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor SSE2CmpGtI32x4(a, b));
end;

function SSE2CmpGeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor SSE2CmpGtI32x4(b, a));
end;

function SSE2CmpNeI32x4(const a, b: TVecI32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor SSE2CmpEqI32x4(a, b));
end;

// ============================================================================
// I32x4 Min/Max Operations (SSE2 emulation - no native instruction)
// Note: SSE4.1 has PMINSD/PMAXSD, but SSE2 needs emulation
// ============================================================================

function SSE2MinI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // min(a,b) = (a < b) ? a : b = blend(b, a, a < b)
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqa xmm2, xmm1       // copy b
    pcmpgtd xmm2, xmm0      // b > a (i.e., a < b)
    // mask in xmm2: all 1s where a < b
    movdqa xmm3, xmm0       // copy a
    pand   xmm3, xmm2       // a & mask
    pandn  xmm2, xmm1       // b & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx], xmm3
  end;
end;

function SSE2MaxI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // max(a,b) = (a > b) ? a : b = blend(b, a, a > b)
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqa xmm2, xmm0       // copy a
    pcmpgtd xmm2, xmm1      // a > b
    // mask in xmm2: all 1s where a > b
    movdqa xmm3, xmm0       // copy a
    pand   xmm3, xmm2       // a & mask
    pandn  xmm2, xmm1       // b & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx], xmm3
  end;
end;

function SSE2AddI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    paddd  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

function SSE2SubI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    psubd  xmm0, xmm1
    movdqu [rcx], xmm0
  end;
end;

// SSE2 has no direct 4-lane 32-bit multiply, but low 32-bit products can be
// reconstructed with PMULUDQ on even lanes plus a shifted odd-lane pass.
// Signed/unsigned low 32-bit results are identical modulo 2^32.
function SSE2MulI32x4(const a, b: TVecI32x4): TVecI32x4;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr

    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1

    pmuludq xmm0, xmm1

    psrldq xmm2, 4
    psrldq xmm3, 4
    pmuludq xmm2, xmm3

    pshufd xmm0, xmm0, $08
    pshufd xmm2, xmm2, $08
    punpckldq xmm0, xmm2

    movdqu [rcx], xmm0
  end;
end;

// ============================================================================
// I16x8 Operations (SSE2)
// ============================================================================

function SSE2AddI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_add_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2SubI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_sub_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2MulI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_mullo_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2AndI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_and_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2OrI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_or_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2XorI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_xor_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2NotI16x8(const a: TVecI16x8): TVecI16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_xor_si128(LA, simd_setzero_si128);
  RawToVec128(LR, Result);
end;

function SSE2AndNotI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_andnot_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2ShiftLeftI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_slli_epi16(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2ShiftRightI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_srli_epi16(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2ShiftRightArithI16x8(const a: TVecI16x8; count: Integer): TVecI16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_srai_epi16(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2CmpEqI16x8(const a, b: TVecI16x8): TMask8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpeq_epi16(LA, LB);
  Result := RawWordMaskToMask8(LR);
end;

function SSE2CmpLtI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := SSE2CmpGtI16x8(b, a);
end;

function SSE2CmpGtI16x8(const a, b: TVecI16x8): TMask8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpgt_epi16(LA, LB);
  Result := RawWordMaskToMask8(LR);
end;

function SSE2CmpLeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor SSE2CmpGtI16x8(a, b));
end;

function SSE2CmpGeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor SSE2CmpGtI16x8(b, a));
end;

function SSE2CmpNeI16x8(const a, b: TVecI16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor SSE2CmpEqI16x8(a, b));
end;

function SSE2MinI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_min_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2MaxI16x8(const a, b: TVecI16x8): TVecI16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_max_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

// ============================================================================
// I8x16 Operations (SSE2)
// ============================================================================

function SSE2AddI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_add_epi8(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2SubI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_sub_epi8(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2AndI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_and_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2OrI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_or_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2XorI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_xor_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2NotI8x16(const a: TVecI8x16): TVecI8x16;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_xor_si128(LA, simd_setzero_si128);
  RawToVec128(LR, Result);
end;

function SSE2AndNotI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_andnot_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2CmpEqI8x16(const a, b: TVecI8x16): TMask16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpeq_epi8(LA, LB);
  Result := TMask16(simd_movemask_epi8(LR));
end;

function SSE2CmpLtI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := SSE2CmpGtI8x16(b, a);
end;

function SSE2CmpGtI8x16(const a, b: TVecI8x16): TMask16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpgt_epi8(LA, LB);
  Result := TMask16(simd_movemask_epi8(LR));
end;

function SSE2CmpLeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor SSE2CmpGtI8x16(a, b));
end;

function SSE2CmpGeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor SSE2CmpGtI8x16(b, a));
end;

function SSE2CmpNeI8x16(const a, b: TVecI8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor SSE2CmpEqI8x16(a, b));
end;

function SSE2MinI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // SSE2 doesn't have PMINSB (SSE4.1), so we emulate with compare+blend
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqa xmm2, xmm1       // copy b
    pcmpgtb xmm2, xmm0      // b > a (i.e., a < b)
    movdqa xmm3, xmm0       // copy a
    pand   xmm3, xmm2       // a & mask
    pandn  xmm2, xmm1       // b & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx], xmm3
  end;
end;

function SSE2MaxI8x16(const a, b: TVecI8x16): TVecI8x16;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // SSE2 doesn't have PMAXSB (SSE4.1), so we emulate with compare+blend
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqa xmm2, xmm0       // copy a
    pcmpgtb xmm2, xmm1      // a > b
    movdqa xmm3, xmm0       // copy a
    pand   xmm3, xmm2       // a & mask
    pandn  xmm2, xmm1       // b & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx], xmm3
  end;
end;

// ============================================================================
// U32x4 Operations (SSE2)
// ============================================================================

function SSE2AddU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_add_epi32(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2SubU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_sub_epi32(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2MulU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  pa, pb, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // SSE2 reconstructs 4x32-bit low products with PMULUDQ on even lanes and a
  // second shifted pass for odd lanes, then repacks the low dwords.
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr

    movdqu xmm0, [rax]       // a
    movdqu xmm1, [rdx]       // b
    movdqa xmm2, xmm0        // 备份 a
    movdqa xmm3, xmm1        // 备份 b

    pmuludq xmm0, xmm1

    psrldq  xmm2, 4
    psrldq  xmm3, 4
    pmuludq xmm2, xmm3

    pshufd xmm0, xmm0, $08
    pshufd xmm2, xmm2, $08

    punpckldq xmm0, xmm2

    movdqu [rcx], xmm0
  end;
end;

function SSE2AndU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_and_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2OrU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_or_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2XorU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_xor_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2NotU32x4(const a: TVecU32x4): TVecU32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_xor_si128(LA, simd_setzero_si128);
  RawToVec128(LR, Result);
end;

function SSE2AndNotU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_andnot_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2ShiftLeftU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_slli_epi32(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2ShiftRightU32x4(const a: TVecU32x4; count: Integer): TVecU32x4;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_srli_epi32(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2CmpEqU32x4(const a, b: TVecU32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    pcmpeqd  xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpLtU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := SSE2CmpGtU32x4(b, a);
end;

function SSE2CmpGtU32x4(const a, b: TVecU32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
const
  SignFlip: array[0..3] of UInt32 = ($80000000, $80000000, $80000000, $80000000);
begin
  pa := @a;
  pb := @b;
  // Unsigned compare: flip sign bit to use signed comparison
  asm
    mov      rax, pa
    mov      rdx, pb
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    movdqu   xmm4, [rip + SignFlip]
    pxor     xmm0, xmm4       // flip sign of a
    pxor     xmm1, xmm4       // flip sign of b
    pcmpgtd  xmm0, xmm1       // signed(a) > signed(b)
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpLeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor SSE2CmpGtU32x4(a, b));
end;

function SSE2CmpGeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor SSE2CmpGtU32x4(b, a));
end;

function SSE2CmpNeU32x4(const a, b: TVecU32x4): TMask4;
begin
  Result := TMask4(MASK4_ALL_SET xor SSE2CmpEqU32x4(a, b));
end;

function SSE2MinU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  pa, pb, pr: Pointer;
const
  SignFlip: array[0..3] of UInt32 = ($80000000, $80000000, $80000000, $80000000);
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // Unsigned min: flip sign bit to use signed comparison
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqu xmm4, [rip + SignFlip]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1
    pxor   xmm2, xmm4       // flip sign of a
    pxor   xmm3, xmm4       // flip sign of b
    pcmpgtd xmm3, xmm2      // signed(b) > signed(a)
    movdqa xmm5, xmm0       // copy a
    pand   xmm5, xmm3       // a & mask
    pandn  xmm3, xmm1       // b & ~mask
    por    xmm5, xmm3       // combine
    movdqu [rcx], xmm5
  end;
end;

function SSE2MaxU32x4(const a, b: TVecU32x4): TVecU32x4;
var
  pa, pb, pr: Pointer;
const
  SignFlip: array[0..3] of UInt32 = ($80000000, $80000000, $80000000, $80000000);
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // Unsigned max: flip sign bit to use signed comparison
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqu xmm4, [rip + SignFlip]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1
    pxor   xmm2, xmm4       // flip sign of a
    pxor   xmm3, xmm4       // flip sign of b
    pcmpgtd xmm2, xmm3      // signed(a) > signed(b)
    movdqa xmm5, xmm0       // copy a
    pand   xmm5, xmm2       // a & mask
    pandn  xmm2, xmm1       // b & ~mask
    por    xmm5, xmm2       // combine
    movdqu [rcx], xmm5
  end;
end;

// ============================================================================
// U16x8 Operations (SSE2)
// ============================================================================

function SSE2AddU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_add_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2SubU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_sub_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2MulU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_mullo_epi16(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2AndU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_and_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2OrU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_or_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2XorU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_xor_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2NotU16x8(const a: TVecU16x8): TVecU16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_xor_si128(LA, simd_setzero_si128);
  RawToVec128(LR, Result);
end;

function SSE2AndNotU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_andnot_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2ShiftLeftU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_slli_epi16(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2ShiftRightU16x8(const a: TVecU16x8; count: Integer): TVecU16x8;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_srli_epi16(LA, count);
  RawToVec128(LR, Result);
end;

function SSE2CmpEqU16x8(const a, b: TVecU16x8): TMask8;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpeq_epi16(LA, LB);
  Result := RawWordMaskToMask8(LR);
end;

function SSE2CmpLtU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := SSE2CmpGtU16x8(b, a);
end;

function SSE2CmpGtU16x8(const a, b: TVecU16x8): TMask8;
var
  LA, LB, LFlip, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LFlip := simd_set1_epi16(-32768);
  LA := simd_xor_si128(LA, LFlip);
  LB := simd_xor_si128(LB, LFlip);
  LR := simd_cmpgt_epi16(LA, LB);
  Result := RawWordMaskToMask8(LR);
end;

function SSE2CmpLeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor SSE2CmpGtU16x8(a, b));
end;

function SSE2CmpGeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor SSE2CmpGtU16x8(b, a));
end;

function SSE2CmpNeU16x8(const a, b: TVecU16x8): TMask8;
begin
  Result := TMask8(MASK8_ALL_SET xor SSE2CmpEqU16x8(a, b));
end;

function SSE2MinU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  pa, pb, pr: Pointer;
const
  SignFlip: array[0..7] of UInt16 = ($8000, $8000, $8000, $8000, $8000, $8000, $8000, $8000);
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // Unsigned min: flip sign bit to use signed comparison
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqu xmm4, [rip + SignFlip]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1
    pxor   xmm2, xmm4       // flip sign of a
    pxor   xmm3, xmm4       // flip sign of b
    pcmpgtw xmm3, xmm2      // signed(b) > signed(a)
    movdqa xmm5, xmm0       // copy a
    pand   xmm5, xmm3       // a & mask
    pandn  xmm3, xmm1       // b & ~mask
    por    xmm5, xmm3       // combine
    movdqu [rcx], xmm5
  end;
end;

function SSE2MaxU16x8(const a, b: TVecU16x8): TVecU16x8;
var
  pa, pb, pr: Pointer;
const
  SignFlip: array[0..7] of UInt16 = ($8000, $8000, $8000, $8000, $8000, $8000, $8000, $8000);
begin
  pa := @a;
  pb := @b;
  pr := @Result;
  // Unsigned max: flip sign bit to use signed comparison
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]      // a
    movdqu xmm1, [rdx]      // b
    movdqu xmm4, [rip + SignFlip]
    movdqa xmm2, xmm0
    movdqa xmm3, xmm1
    pxor   xmm2, xmm4       // flip sign of a
    pxor   xmm3, xmm4       // flip sign of b
    pcmpgtw xmm2, xmm3      // signed(a) > signed(b)
    movdqa xmm5, xmm0       // copy a
    pand   xmm5, xmm2       // a & mask
    pandn  xmm2, xmm1       // b & ~mask
    por    xmm5, xmm2       // combine
    movdqu [rcx], xmm5
  end;
end;

// ============================================================================
// U8x16 Operations (SSE2)
// ============================================================================

function SSE2AddU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_add_epi8(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2SubU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_sub_epi8(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2AndU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_and_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2OrU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_or_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2XorU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_xor_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2NotU8x16(const a: TVecU8x16): TVecU8x16;
var
  LA, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  LR := simd_xor_si128(LA, simd_setzero_si128);
  RawToVec128(LR, Result);
end;

function SSE2AndNotU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_andnot_si128(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2CmpEqU8x16(const a, b: TVecU8x16): TMask16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_cmpeq_epi8(LA, LB);
  Result := TMask16(simd_movemask_epi8(LR));
end;

function SSE2CmpLtU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := SSE2CmpGtU8x16(b, a);
end;

function SSE2CmpGtU8x16(const a, b: TVecU8x16): TMask16;
var
  LA, LB, LFlip, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LFlip := simd_set1_epi8(-128);
  LA := simd_xor_si128(LA, LFlip);
  LB := simd_xor_si128(LB, LFlip);
  LR := simd_cmpgt_epi8(LA, LB);
  Result := TMask16(simd_movemask_epi8(LR));
end;

function SSE2CmpLeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor SSE2CmpGtU8x16(a, b));
end;

function SSE2CmpGeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor SSE2CmpGtU8x16(b, a));
end;

function SSE2CmpNeU8x16(const a, b: TVecU8x16): TMask16;
begin
  Result := TMask16(MASK16_ALL_SET xor SSE2CmpEqU8x16(a, b));
end;

function SSE2MinU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_min_epu8(LA, LB);
  RawToVec128(LR, Result);
end;

function SSE2MaxU8x16(const a, b: TVecU8x16): TVecU8x16;
var
  LA, LB, LR: TM128;
begin
  Vec128ToRaw(a, LA);
  Vec128ToRaw(b, LB);
  LR := simd_max_epu8(LA, LB);
  RawToVec128(LR, Result);
end;

// === SSE2 Comparison Operations ===

function SSE2CmpEqF32x4(const a, b: TVecF32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpeqps  xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpLtF32x4(const a, b: TVecF32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpltps  xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpLeF32x4(const a, b: TVecF32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpleps  xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpGtF32x4(const a, b: TVecF32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  // GT: swap operands and use LT
  pa := @a;
  pb := @b;
  asm
    mov      rax, pb
    mov      rdx, pa
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpltps  xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpGeF32x4(const a, b: TVecF32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  // GE: swap operands and use LE
  pa := @a;
  pb := @b;
  asm
    mov      rax, pb
    mov      rdx, pa
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpleps  xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

function SSE2CmpNeF32x4(const a, b: TVecF32x4): TMask4;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpneqps xmm0, xmm1
    movmskps eax, xmm0
    mov      mask, eax
  end;
  Result := TMask4(mask);
end;

// === SSE2 Math Functions ===

function SSE2AbsF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
begin
  pr := @Result;
  pa := @a;
  asm
    mov     rax, pa
    mov     rdx, pr
    movups  xmm0, [rax]
    pcmpeqd xmm1, xmm1       // all 1s
    psrld   xmm1, 1          // shift right to get 0x7FFFFFFF
    andps   xmm0, xmm1
    movups  [rdx], xmm0
  end;
end;

function SSE2SqrtF32x4(const a: TVecF32x4): TVecF32x4;
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov rax, pa
    mov rcx, pr
    movups xmm0, [rax]
    sqrtps xmm0, xmm0
    movups [rcx], xmm0
  end;
end;

function SSE2MinF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    minps  xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

function SSE2MaxF32x4(const a, b: TVecF32x4): TVecF32x4;
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov rax, pa
    mov rdx, pb
    mov rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    maxps  xmm0, xmm1
    movups [rcx], xmm0
  end;
end;

// === SSE2 Reduction Operations ===

function SSE2ReduceAddF32x4(const a: TVecF32x4): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov     rax, pa
    movups  xmm0, [rax]
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $4E
    addps   xmm0, xmm1
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $B1
    addss   xmm0, xmm1
    movss   [result], xmm0
  end;
end;

function SSE2ReduceMinF32x4(const a: TVecF32x4): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov     rax, pa
    movups  xmm0, [rax]
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $4E
    minps   xmm0, xmm1
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $B1
    minss   xmm0, xmm1
    movss   [result], xmm0
  end;
end;

function SSE2ReduceMaxF32x4(const a: TVecF32x4): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov     rax, pa
    movups  xmm0, [rax]
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $4E
    maxps   xmm0, xmm1
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $B1
    maxss   xmm0, xmm1
    movss   [result], xmm0
  end;
end;

function SSE2ReduceMulF32x4(const a: TVecF32x4): Single;
var
  pa: Pointer;
begin
  pa := @a;
  asm
    mov     rax, pa
    movups  xmm0, [rax]
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $4E
    mulps   xmm0, xmm1
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $B1
    mulss   xmm0, xmm1
    movss   [result], xmm0
  end;
end;

// === SSE2 Memory Operations ===

function SSE2LoadF32x4(p: PSingle): TVecF32x4;
var
  LR: TM128;
begin
  Assert(p <> nil, 'SSE2LoadF32x4: pointer is nil');
  LR := simd_loadu_ps(p);
  RawToVec128(LR, Result);
end;

function SSE2LoadF32x4Aligned(p: PSingle): TVecF32x4;
var
  LR: TM128;
begin
  Assert(p <> nil, 'SSE2LoadF32x4Aligned: pointer is nil');
  {$PUSH}{$WARN 4055 OFF}
  Assert((PtrUInt(p) and $F) = 0, 'SSE2LoadF32x4Aligned: Pointer must be 16-byte aligned');
  {$POP}
  LR := simd_load_ps(p);
  RawToVec128(LR, Result);
end;

procedure SSE2StoreF32x4(p: PSingle; const a: TVecF32x4);
{$PUSH}
{$WARN 5026 OFF}
begin
  Assert(p <> nil, 'SSE2StoreF32x4: pointer is nil');
  simd_storeu_ps(p, PTM128(@a)^);
end;
{$POP}

{$PUSH}
{$WARN 5026 OFF}
procedure SSE2StoreF32x4Aligned(p: PSingle; const a: TVecF32x4);
begin
  Assert(p <> nil, 'SSE2StoreF32x4Aligned: pointer is nil');
  {$PUSH}{$WARN 4055 OFF}
  Assert((PtrUInt(p) and $F) = 0, 'SSE2StoreF32x4Aligned: Pointer must be 16-byte aligned');
  {$POP}
  simd_store_ps(p, PTM128(@a)^);
end;
{$POP}

// === SSE2 Utility Operations ===

function SSE2SplatF32x4(value: Single): TVecF32x4;
var
  LR: TM128;
begin
  LR := simd_set1_ps(value);
  RawToVec128(LR, Result);
end;

function SSE2ZeroF32x4: TVecF32x4;
var
  LR: TM128;
begin
  LR := simd_setzero_ps;
  RawToVec128(LR, Result);
end;

function SSE2SelectF32x4(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4;
begin
  Result := ScalarSelectF32x4(mask, a, b);
end;

function SSE2ExtractF32x4(const a: TVecF32x4; index: Integer): Single;
begin
  Result := ScalarExtractF32x4(a, index);
end;

function SSE2InsertF32x4(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
begin
  Result := ScalarInsertF32x4(a, value, index);
end;

// === F32x8 Operations (simulate with 2x F32x4) ===

// 2×128-bit SSE2 ASM 实现
function SSE2AddF32x8(const a, b: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    // Load 2×128-bit
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    // Add
    addps  xmm0, xmm2
    addps  xmm1, xmm3
    // Store
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AddF32x4(a.lo, b.lo);
  Result.hi := SSE2AddF32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2SubF32x8(const a, b: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    subps  xmm0, xmm2
    subps  xmm1, xmm3
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2SubF32x4(a.lo, b.lo);
  Result.hi := SSE2SubF32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2MulF32x8(const a, b: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    mulps  xmm0, xmm2
    mulps  xmm1, xmm3
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2MulF32x4(a.lo, b.lo);
  Result.hi := SSE2MulF32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2DivF32x8(const a, b: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    divps  xmm0, xmm2
    divps  xmm1, xmm3
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2DivF32x4(a.lo, b.lo);
  Result.hi := SSE2DivF32x4(a.hi, b.hi);
{$ENDIF}
end;

// === F32x8 Comparison Operations (direct 2×128-bit ASM) ===
// Converted from recursive calls to eliminate function call overhead

function SSE2CmpEqF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (first 128 bits)
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpeqps  xmm0, xmm1      // a.lo == b.lo
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (second 128 bits)
    movups   xmm0, [rax+16]
    movups   xmm1, [rdx+16]
    cmpeqps  xmm0, xmm1      // a.hi == b.hi
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpLtF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (first 128 bits)
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpltps  xmm0, xmm1      // a.lo < b.lo
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (second 128 bits)
    movups   xmm0, [rax+16]
    movups   xmm1, [rdx+16]
    cmpltps  xmm0, xmm1      // a.hi < b.hi
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpLeF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (first 128 bits)
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpleps  xmm0, xmm1      // a.lo <= b.lo
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (second 128 bits)
    movups   xmm0, [rax+16]
    movups   xmm1, [rdx+16]
    cmpleps  xmm0, xmm1      // a.hi <= b.hi
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpGtF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  // GT: swap operands and use LT
  pa := @a;
  pb := @b;
  asm
    mov      rax, pb
    mov      rdx, pa
    // Compare lo (first 128 bits) - swapped operands
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpltps  xmm0, xmm1      // b.lo < a.lo => a.lo > b.lo
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (second 128 bits) - swapped operands
    movups   xmm0, [rax+16]
    movups   xmm1, [rdx+16]
    cmpltps  xmm0, xmm1      // b.hi < a.hi => a.hi > b.hi
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpGeF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  // GE: swap operands and use LE
  pa := @a;
  pb := @b;
  asm
    mov      rax, pb
    mov      rdx, pa
    // Compare lo (first 128 bits) - swapped operands
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpleps  xmm0, xmm1      // b.lo <= a.lo => a.lo >= b.lo
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (second 128 bits) - swapped operands
    movups   xmm0, [rax+16]
    movups   xmm1, [rdx+16]
    cmpleps  xmm0, xmm1      // b.hi <= a.hi => a.hi >= b.hi
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpNeF32x8(const a, b: TVecF32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (first 128 bits)
    movups   xmm0, [rax]
    movups   xmm1, [rdx]
    cmpneqps xmm0, xmm1      // a.lo != b.lo
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (second 128 bits)
    movups   xmm0, [rax+16]
    movups   xmm1, [rdx+16]
    cmpneqps xmm0, xmm1      // a.hi != b.hi
    movmskps eax, xmm0       // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

// === SSE2 Memory Functions ===

function MemEqual_SSE2(a, b: Pointer; len: SizeUInt): LongBool;
var
  pa, pb: PByte;
  i: SizeUInt;
  maskA, maskB: Integer;
begin
  {$PUSH}{$Q-}{$R-}  // Disable overflow/range checks for SIMD loop
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
  i := 0;

  // Process 16 bytes at a time using SSE2
  while i + 16 <= len do
  begin
    asm
      mov   rax, pa
      mov   rdx, pb
      add   rax, i
      add   rdx, i
      movdqu xmm0, [rax]
      movdqu xmm1, [rdx]
      pcmpeqb xmm0, xmm1
      pmovmskb eax, xmm0
      mov   maskA, eax
    end;

    if maskA <> $FFFF then
    begin
      Result := False;
      Exit;
    end;

    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    if pa[i] <> pb[i] then
    begin
      Result := False;
      Exit;
    end;
    Inc(i);
  end;

  Result := True;
  {$POP}
end;

function MemFindByte_SSE2(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
var
  pb: PByte;
  i: SizeUInt;
  mask: Integer;
  bitPos: Integer;
begin
  if (len = 0) or (p = nil) then
  begin
    Result := -1;
    Exit;
  end;

  pb := PByte(p);
  i := 0;

  // Process 16 bytes at a time using SSE2
  while i + 16 <= len do
  begin
    asm
      mov      rax, pb
      add      rax, i
      movzx    edx, value
      movd     xmm1, edx
      punpcklbw xmm1, xmm1
      pshuflw  xmm1, xmm1, 0
      punpcklqdq xmm1, xmm1  // Broadcast value to all 16 bytes
      movdqu   xmm0, [rax]
      pcmpeqb  xmm0, xmm1
      pmovmskb eax, xmm0
      mov      mask, eax
    end;

    if mask <> 0 then
    begin
      // Find first set bit
      asm
        bsf eax, mask
        mov bitPos, eax
      end;
      Result := PtrInt(i) + bitPos;
      Exit;
    end;

    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    if pb[i] = value then
    begin
      Result := PtrInt(i);
      Exit;
    end;
    Inc(i);
  end;

  Result := -1;
end;

procedure MemCopy_SSE2(src, dst: Pointer; len: SizeUInt); assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // RDI = src, RSI = dst, RDX = len
  test rdx, rdx
  jz @done
  test rdi, rdi
  jz @done
  test rsi, rsi
  jz @done
  cmp rdi, rsi
  je @done

  xor rcx, rcx           // i = 0

@loop16:
  lea rax, [rcx + 16]
  cmp rax, rdx
  ja @remainder
  movdqu xmm0, [rdi + rcx]
  movdqu [rsi + rcx], xmm0
  add rcx, 16
  jmp @loop16

@remainder:
  cmp rcx, rdx
  jae @done
  mov al, [rdi + rcx]
  mov [rsi + rcx], al
  inc rcx
  jmp @remainder

@done:
  {$ELSE}
  // Windows x64: RCX = src, RDX = dst, R8 = len
  test r8, r8
  jz @done
  test rcx, rcx
  jz @done
  test rdx, rdx
  jz @done
  cmp rcx, rdx
  je @done

  xor r9, r9            // i = 0

@loop16:
  lea rax, [r9 + 16]
  cmp rax, r8
  ja @remainder
  movdqu xmm0, [rcx + r9]
  movdqu [rdx + r9], xmm0
  add r9, 16
  jmp @loop16

@remainder:
  cmp r9, r8
  jae @done
  mov al, [rcx + r9]
  mov [rdx + r9], al
  inc r9
  jmp @remainder

@done:
  {$ENDIF}
end;

procedure MemSet_SSE2(dst: Pointer; len: SizeUInt; value: Byte); assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // RDI = dst, RSI = len, RDX = value
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  // Broadcast value to all 16 bytes
  movd xmm0, edx
  punpcklbw xmm0, xmm0
  pshuflw xmm0, xmm0, 0
  punpcklqdq xmm0, xmm0

  xor rcx, rcx           // i = 0

@loop16:
  lea rax, [rcx + 16]
  cmp rax, rsi
  ja @remainder
  movdqu [rdi + rcx], xmm0
  add rcx, 16
  jmp @loop16

@remainder:
  cmp rcx, rsi
  jae @done
  mov [rdi + rcx], dl
  inc rcx
  jmp @remainder

@done:
  {$ELSE}
  // Windows x64: RCX = dst, RDX = len, R8 = value
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done

  // Broadcast value to all 16 bytes
  movzx r8d, r8b
  movd xmm0, r8d
  punpcklbw xmm0, xmm0
  pshuflw xmm0, xmm0, 0
  punpcklqdq xmm0, xmm0

  xor r9, r9             // i = 0
  mov al, r8b

@loop16:
  lea rax, [r9 + 16]
  cmp rax, rdx
  ja @remainder
  movdqu [rcx + r9], xmm0
  add r9, 16
  jmp @loop16

@remainder:
  cmp r9, rdx
  jae @done
  mov [rcx + r9], al
  inc r9
  jmp @remainder

@done:
  {$ENDIF}
end;

function SumBytes_SSE2(p: Pointer; len: SizeUInt): UInt64;
var
  pb: PByte;
  i: SizeUInt;
  sum0, sum1, sum2, sum3: UInt32;
begin
  {$PUSH}{$Q-}{$R-}  // Disable overflow/range checks for SIMD loop
  if (len = 0) or (p = nil) then
  begin
    Result := 0;
    Exit;
  end;

  pb := PByte(p);
  i := 0;
  sum0 := 0;
  sum1 := 0;
  sum2 := 0;
  sum3 := 0;

  // Process 16 bytes at a time using SSE2
  // Use psadbw (sum of absolute differences) with zero to sum bytes
  while i + 16 <= len do
  begin
    asm
      mov      rax, pb
      add      rax, i
      movdqu   xmm0, [rax]
      pxor     xmm1, xmm1      // Zero register
      psadbw   xmm0, xmm1      // Sum bytes: result in low 16 bits of each 64-bit lane
      movd     eax, xmm0       // Get lower 64-bit sum
      add      sum0, eax
      psrldq   xmm0, 8         // Shift right 8 bytes
      movd     eax, xmm0       // Get upper 64-bit sum
      add      sum1, eax
    end;
    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    Inc(sum2, pb[i]);
    Inc(i);
  end;

  Result := UInt64(sum0) + UInt64(sum1) + UInt64(sum2) + UInt64(sum3);
  {$POP}
end;

function CountByte_SSE2(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; assembler; nostackframe;
// SysV: RDI = p, RSI = len, RDX = value
// Win64: RCX = p, RDX = len, R8 = value
// Use SWAR popcount for 16-bit mask
asm
  {$IFDEF UNIX}
  xor rax, rax           // count = 0
  test rsi, rsi
  jz @done
  test rdi, rdi
  jz @done

  // Broadcast value to all 16 bytes in xmm1
  movzx edx, dl
  movd xmm1, edx
  punpcklbw xmm1, xmm1
  pshuflw xmm1, xmm1, 0
  punpcklqdq xmm1, xmm1

  xor rcx, rcx           // i = 0

@loop16:
  lea r8, [rcx + 16]
  cmp r8, rsi
  ja @remainder
  movdqu xmm0, [rdi + rcx]
  pcmpeqb xmm0, xmm1
  pmovmskb r8d, xmm0
  // Popcount using SWAR
  mov r9d, r8d
  shr r9d, 1
  and r9d, $5555
  sub r8d, r9d
  mov r9d, r8d
  shr r9d, 2
  and r8d, $3333
  and r9d, $3333
  add r8d, r9d
  mov r9d, r8d
  shr r9d, 4
  add r8d, r9d
  and r8d, $0F0F
  mov r9d, r8d
  shr r9d, 8
  add r8d, r9d
  and r8d, $FF
  add rax, r8
  add rcx, 16
  jmp @loop16

@remainder:
  cmp rcx, rsi
  jae @done
  movzx r8d, byte ptr [rdi + rcx]
  cmp r8d, edx
  jne @skip
  inc rax
@skip:
  inc rcx
  jmp @remainder

@done:
  {$ELSE}
  xor rax, rax           // count = 0
  test rdx, rdx
  jz @done
  test rcx, rcx
  jz @done

  // Broadcast value to all 16 bytes in xmm1
  movzx r8d, r8b
  movd xmm1, r8d
  punpcklbw xmm1, xmm1
  pshuflw xmm1, xmm1, 0
  punpcklqdq xmm1, xmm1

  xor r9, r9             // i = 0

@loop16:
  lea r10, [r9 + 16]
  cmp r10, rdx
  ja @remainder
  movdqu xmm0, [rcx + r9]
  pcmpeqb xmm0, xmm1
  pmovmskb r10d, xmm0
  // Popcount using SWAR
  mov r11d, r10d
  shr r11d, 1
  and r11d, $5555
  sub r10d, r11d
  mov r11d, r10d
  shr r11d, 2
  and r10d, $3333
  and r11d, $3333
  add r10d, r11d
  mov r11d, r10d
  shr r11d, 4
  add r10d, r11d
  and r10d, $0F0F
  mov r11d, r10d
  shr r11d, 8
  add r10d, r11d
  and r10d, $FF
  add rax, r10
  add r9, 16
  jmp @loop16

@remainder:
  cmp r9, rdx
  jae @done
  movzx r10d, byte ptr [rcx + r9]
  cmp r10d, r8d
  jne @skip
  inc rax
@skip:
  inc r9
  jmp @remainder

@done:
  {$ENDIF}
end;

// === Extended Math Functions ===

// FMA emulation: a*b + c (SSE2 has no native FMA)
function SSE2FmaF32x4(const a, b, c: TVecF32x4): TVecF32x4;
var
  pa, pb, pc, pr: Pointer;
begin
  pa := @a;
  pb := @b;
  pc := @c;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pc
    mov    r8, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    movups xmm2, [rcx]
    mulps  xmm0, xmm1
    addps  xmm0, xmm2
    movups [r8], xmm0
  end;
end;

// Reciprocal approximation (1/x)
function SSE2RcpF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
begin
  pa := @a;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movups xmm0, [rax]
    rcpps  xmm0, xmm0     // Approximate reciprocal (12-bit precision)
    movups [rcx], xmm0
  end;
end;

// Reciprocal square root approximation (1/sqrt(x))
function SSE2RsqrtF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
begin
  pa := @a;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movups xmm0, [rax]
    rsqrtps xmm0, xmm0    // Approximate rsqrt (12-bit precision)
    movups [rcx], xmm0
  end;
end;

// Floor/Ceil/Round/Trunc: Use SSE4.1 roundps if available, otherwise scalar fallback
// SSE4.1 roundps immediate values:
//   0 = Round to nearest (even)
//   1 = Round toward negative infinity (floor)
//   2 = Round toward positive infinity (ceil)
//   3 = Round toward zero (truncate)

var
  g_HasSSE41: Boolean = False;
  g_SSE41CheckState: LongInt = 0; // 0=未检查, 1=检查中, 2=已完成

// Thread-safe SSE4.1 detection using atomic operations
procedure CheckSSE41;
var
  oldState: LongInt;
begin
  // 快速路径: 已完成检查
  if g_SSE41CheckState = 2 then Exit;

  oldState := InterlockedCompareExchange(g_SSE41CheckState, 1, 0);
  if oldState = 0 then
  begin
    // 我们是第一个检查者
    g_HasSSE41 := HasSSE41;
    WriteBarrier;
    InterlockedExchange(g_SSE41CheckState, 2);
  end
  else if oldState = 1 then
  begin
    // 另一个线程正在检查，自旋等待
    while g_SSE41CheckState <> 2 do
    begin
      ReadBarrier;
      ThreadSwitch;
    end;
  end;
  // oldState = 2: 已完成，直接返回
end;

function SSE2FloorF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
  LIndex: Integer;
begin
  CheckSSE41;
  if g_HasSSE41 then
  begin
    pa := @a;
    pr := @Result;
    asm
      mov    rax, pa
      mov    rcx, pr
      movups xmm0, [rax]
      // roundps xmm0, xmm0, 1  (floor)
      db $66, $0F, $3A, $08, $C0, $01
      movups [rcx], xmm0
    end;
  end
  else
  begin
    for LIndex := 0 to 3 do
    begin
      if IsNan(a.f[LIndex]) or IsInfinite(a.f[LIndex]) then
      begin
        Result.f[LIndex] := a.f[LIndex];
        Continue;
      end;

      Result.f[LIndex] := Int(a.f[LIndex]);
      if (a.f[LIndex] < 0) and (Result.f[LIndex] <> a.f[LIndex]) then
        Result.f[LIndex] := Result.f[LIndex] - 1.0;
    end;
  end;
end;

function SSE2CeilF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
  LIndex: Integer;
begin
  CheckSSE41;
  if g_HasSSE41 then
  begin
    pa := @a;
    pr := @Result;
    asm
      mov    rax, pa
      mov    rcx, pr
      movups xmm0, [rax]
      // roundps xmm0, xmm0, 2  (ceil)
      db $66, $0F, $3A, $08, $C0, $02
      movups [rcx], xmm0
    end;
  end
  else
  begin
    for LIndex := 0 to 3 do
    begin
      if IsNan(a.f[LIndex]) or IsInfinite(a.f[LIndex]) then
      begin
        Result.f[LIndex] := a.f[LIndex];
        Continue;
      end;

      Result.f[LIndex] := Int(a.f[LIndex]);
      if (a.f[LIndex] > 0) and (Result.f[LIndex] <> a.f[LIndex]) then
        Result.f[LIndex] := Result.f[LIndex] + 1.0;
    end;
  end;
end;

function SSE2RoundF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
  LIndex: Integer;
  LBits: DWord;
begin
  CheckSSE41;
  if g_HasSSE41 then
  begin
    pa := @a;
    pr := @Result;
    asm
      mov    rax, pa
      mov    rcx, pr
      movups xmm0, [rax]
      // roundps xmm0, xmm0, 0  (round to nearest even)
      db $66, $0F, $3A, $08, $C0, $00
      movups [rcx], xmm0
    end;
  end
  else
  begin
    LBits := 0;
    for LIndex := 0 to 3 do
      if IsNan(a.f[LIndex]) or IsInfinite(a.f[LIndex]) then
        Result.f[LIndex] := a.f[LIndex]
      else
      begin
        Result.f[LIndex] := Round(a.f[LIndex]);
        if Result.f[LIndex] = 0.0 then
        begin
          Move(a.f[LIndex], LBits, SizeOf(LBits));
          if (LBits and DWord($80000000)) <> 0 then
            Result.f[LIndex] := -0.0;
        end;
      end;
  end;
end;

function SSE2TruncF32x4(const a: TVecF32x4): TVecF32x4;
var
  pa, pr: Pointer;
  LIndex: Integer;
  LBits: DWord;
begin
  CheckSSE41;
  if g_HasSSE41 then
  begin
    pa := @a;
    pr := @Result;
    asm
      mov    rax, pa
      mov    rcx, pr
      movups xmm0, [rax]
      // roundps xmm0, xmm0, 3  (truncate)
      db $66, $0F, $3A, $08, $C0, $03
      movups [rcx], xmm0
    end;
  end
  else
  begin
    LBits := 0;
    for LIndex := 0 to 3 do
      if IsNan(a.f[LIndex]) or IsInfinite(a.f[LIndex]) then
        Result.f[LIndex] := a.f[LIndex]
      else
      begin
        Result.f[LIndex] := Int(a.f[LIndex]);
        if Result.f[LIndex] = 0.0 then
        begin
          Move(a.f[LIndex], LBits, SizeOf(LBits));
          if (LBits and DWord($80000000)) <> 0 then
            Result.f[LIndex] := -0.0;
        end;
      end;
  end;
end;

// Clamp using SSE2 min/max
function SSE2ClampF32x4(const a, minVal, maxVal: TVecF32x4): TVecF32x4;
var
  pa, pMin, pMax, pr: Pointer;
begin
  pa := @a;
  pMin := @minVal;
  pMax := @maxVal;
  pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pMin
    mov    rcx, pMax
    mov    r8, pr
    movups xmm0, [rax]
    movups xmm1, [rdx]
    movups xmm2, [rcx]
    maxps  xmm0, xmm1     // max(a, minVal)
    minps  xmm0, xmm2     // min(result, maxVal)
    movups [r8], xmm0
  end;
end;

// === Vector Math Functions ===

// Dot product (4 elements)
function SSE2DotF32x4(const a, b: TVecF32x4): Single;
var
  pa, pb: Pointer;
begin
  pa := @a;
  pb := @b;
  asm
    mov     rax, pa
    mov     rdx, pb
    movups  xmm0, [rax]
    movups  xmm1, [rdx]
    mulps   xmm0, xmm1     // Element-wise multiply
    // Horizontal add: [a*b, c*d, e*f, g*h] -> sum
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $4E // Swap high/low pairs
    addps   xmm0, xmm1
    movaps  xmm1, xmm0
    shufps  xmm1, xmm1, $B1 // Swap adjacent
    addss   xmm0, xmm1
    movss   [result], xmm0
  end;
end;

// Dot product (3 elements, ignore w)
function SSE2DotF32x3(const a, b: TVecF32x4): Single;
var
  t: TVecF32x4;
  pa, pb: Pointer;
begin
  pa := @a;
  pb := @b;
  asm
    mov     rax, pa
    mov     rdx, pb
    movups  xmm0, [rax]
    movups  xmm1, [rdx]
    mulps   xmm0, xmm1
    // Zero the w component before summing
    xorps   xmm1, xmm1
    movss   xmm1, xmm0     // xmm1 = [x, 0, 0, 0]
    shufps  xmm0, xmm0, $E9 // xmm0 = [y, z, z, w]
    addss   xmm1, xmm0     // x + y
    shufps  xmm0, xmm0, $E9
    addss   xmm1, xmm0     // x + y + z
    movss   [result], xmm1
  end;
end;

// Cross product (3D)
function SSE2CrossF32x3(const a, b: TVecF32x4): TVecF32x4;
var
  pa, pb, pr: Pointer;
begin
  // Cross = (a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x, 0)
  pa := @a;
  pb := @b;
  pr := @Result;
  asm
    mov     rax, pa
    mov     rdx, pb
    mov     rcx, pr
    movups  xmm0, [rax]        // a = [x, y, z, w]
    movups  xmm1, [rdx]        // b = [x, y, z, w]

    // Shuffle a: [y, z, x, w]
    movaps  xmm2, xmm0
    shufps  xmm2, xmm2, $C9    // 11 00 10 01 -> y,z,x,w

    // Shuffle b: [z, x, y, w]
    movaps  xmm3, xmm1
    shufps  xmm3, xmm3, $D2    // 11 01 00 10 -> z,x,y,w

    mulps   xmm2, xmm3         // [a.y*b.z, a.z*b.x, a.x*b.y, ...]

    // Shuffle a: [z, x, y, w]
    movaps  xmm4, xmm0
    shufps  xmm4, xmm4, $D2

    // Shuffle b: [y, z, x, w]
    movaps  xmm5, xmm1
    shufps  xmm5, xmm5, $C9

    mulps   xmm4, xmm5         // [a.z*b.y, a.x*b.z, a.y*b.x, ...]

    subps   xmm2, xmm4         // Subtract to get [x', y', z', w']

    movups  [rcx], xmm2
  end;
  Result.f[3] := 0.0; // Ensure w=0
end;

// === SSE2 Optimized Length / Normalize ===

function SSE2LengthWithOptionalZeroW(const a: TVecF32x4; aZeroW: Boolean): Single;
var
  LPA: Pointer;
begin
  LPA := @a;
  if aZeroW then
  begin
    asm
      mov     rax, LPA
      movups  xmm0, [rax]
      pcmpeqd xmm1, xmm1
      psrldq  xmm1, 4
      andps   xmm0, xmm1
      mulps   xmm0, xmm0
      movaps  xmm1, xmm0
      shufps  xmm1, xmm1, $4E
      addps   xmm0, xmm1
      movaps  xmm1, xmm0
      shufps  xmm1, xmm1, $B1
      addss   xmm0, xmm1
      sqrtss  xmm0, xmm0
      movss   [result], xmm0
    end;
  end
  else
  begin
    asm
      mov     rax, LPA
      movups  xmm0, [rax]
      mulps   xmm0, xmm0
      movaps  xmm1, xmm0
      shufps  xmm1, xmm1, $4E
      addps   xmm0, xmm1
      movaps  xmm1, xmm0
      shufps  xmm1, xmm1, $B1
      addss   xmm0, xmm1
      sqrtss  xmm0, xmm0
      movss   [result], xmm0
    end;
  end;
end;

function SSE2NormalizeByLength(const a: TVecF32x4; const aLen: Single; aZeroW: Boolean): TVecF32x4;
var
  LPA, LPR: Pointer;
begin
  if aLen > 0.0 then
  begin
    LPA := @a;
    LPR := @Result;
    asm
      mov     rax, LPA
      mov     rcx, LPR
      movups  xmm0, [rax]
      movss   xmm1, aLen
      shufps  xmm1, xmm1, 0
      divps   xmm0, xmm1
      movups  [rcx], xmm0
    end;
    if aZeroW then
      Result.f[3] := 0.0;
  end
  else
  begin
    Result := a;
    if aZeroW then
      Result.f[3] := 0.0;
  end;
end;

function SSE2LengthF32x4(const a: TVecF32x4): Single;
begin
  Result := SSE2LengthWithOptionalZeroW(a, False);
end;

function SSE2LengthF32x3(const a: TVecF32x4): Single;
begin
  Result := SSE2LengthWithOptionalZeroW(a, True);
end;

function SSE2NormalizeF32x4(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
begin
  len := SSE2LengthWithOptionalZeroW(a, False);
  Result := SSE2NormalizeByLength(a, len, False);
end;

function SSE2NormalizeF32x3(const a: TVecF32x4): TVecF32x4;
var
  len: Single;
begin
  len := SSE2LengthWithOptionalZeroW(a, True);
  Result := SSE2NormalizeByLength(a, len, True);
end;

// F32x8 扩展函数 - 使用 2x F32x4 仿真

function SSE2FmaF32x8(const a, b, c: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pc, pr: Pointer;
begin
  pa := @a; pb := @b; pc := @c; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    r8,  pc
    mov    rcx, pr
    // Load a
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Load b
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    // Multiply a * b
    mulps  xmm0, xmm2
    mulps  xmm1, xmm3
    // Load c
    movups xmm4, [r8]
    movups xmm5, [r8+16]
    // Add c
    addps  xmm0, xmm4
    addps  xmm1, xmm5
    // Store
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2FmaF32x4(a.lo, b.lo, c.lo);
  Result.hi := SSE2FmaF32x4(a.hi, b.hi, c.hi);
{$ENDIF}
end;

function SSE2FloorF32x8(const a: TVecF32x8): TVecF32x8;
begin
  Result.lo := SSE2FloorF32x4(a.lo);
  Result.hi := SSE2FloorF32x4(a.hi);
end;

function SSE2CeilF32x8(const a: TVecF32x8): TVecF32x8;
begin
  Result.lo := SSE2CeilF32x4(a.lo);
  Result.hi := SSE2CeilF32x4(a.hi);
end;

function SSE2RoundF32x8(const a: TVecF32x8): TVecF32x8;
begin
  Result.lo := SSE2RoundF32x4(a.lo);
  Result.hi := SSE2RoundF32x4(a.hi);
end;

function SSE2TruncF32x8(const a: TVecF32x8): TVecF32x8;
begin
  Result.lo := SSE2TruncF32x4(a.lo);
  Result.hi := SSE2TruncF32x4(a.hi);
end;

function SSE2AbsF32x8(const a: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Create sign mask (0x7FFFFFFF)
    pcmpeqd xmm2, xmm2       // all 1s
    psrld   xmm2, 1           // clear sign bit
    movaps  xmm3, xmm2
    // Clear sign bits
    andps   xmm0, xmm2
    andps   xmm1, xmm3
    movups  [rcx], xmm0
    movups  [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AbsF32x4(a.lo);
  Result.hi := SSE2AbsF32x4(a.hi);
{$ENDIF}
end;

function SSE2SqrtF32x8(const a: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    sqrtps xmm0, xmm0
    sqrtps xmm1, xmm1
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2SqrtF32x4(a.lo);
  Result.hi := SSE2SqrtF32x4(a.hi);
{$ENDIF}
end;

function SSE2MinF32x8(const a, b: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    minps  xmm0, xmm2
    minps  xmm1, xmm3
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2MinF32x4(a.lo, b.lo);
  Result.hi := SSE2MinF32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2MaxF32x8(const a, b: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    maxps  xmm0, xmm2
    maxps  xmm1, xmm3
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2MaxF32x4(a.lo, b.lo);
  Result.hi := SSE2MaxF32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2ClampF32x8(const a, minVal, maxVal: TVecF32x8): TVecF32x8;
{$IFDEF CPUX64}
var pa, pmin, pmax, pr: Pointer;
begin
  pa := @a; pmin := @minVal; pmax := @maxVal; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pmin
    mov    r8,  pmax
    mov    rcx, pr
    // Load a
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Load minVal
    movups xmm2, [rdx]
    movups xmm3, [rdx+16]
    // Max with minVal
    maxps  xmm0, xmm2
    maxps  xmm1, xmm3
    // Load maxVal
    movups xmm4, [r8]
    movups xmm5, [r8+16]
    // Min with maxVal
    minps  xmm0, xmm4
    minps  xmm1, xmm5
    // Store
    movups [rcx], xmm0
    movups [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2ClampF32x4(a.lo, minVal.lo, maxVal.lo);
  Result.hi := SSE2ClampF32x4(a.hi, minVal.hi, maxVal.hi);
{$ENDIF}
end;

function SSE2ReduceAddF32x8(const a: TVecF32x8): Single;
{$IFDEF CPUX64}
var pa: Pointer; res: Single;
begin
  pa := @a;
  asm
    mov    rax, pa
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Merge lo + hi
    addps  xmm0, xmm1
    // Horizontal add (SSE3 style, but we use SSE2 shuffles)
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $4E      // swap high/low 64-bit
    addps  xmm0, xmm1
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $B1      // swap adjacent pairs
    addps  xmm0, xmm1
    movss  res, xmm0
  end;
  Result := res;
{$ELSE}
begin
  Result := SSE2ReduceAddF32x4(a.lo) + SSE2ReduceAddF32x4(a.hi);
{$ENDIF}
end;

function SSE2ReduceMinF32x8(const a: TVecF32x8): Single;
{$IFDEF CPUX64}
var pa: Pointer; res: Single;
begin
  pa := @a;
  asm
    mov    rax, pa
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Merge lo + hi with min
    minps  xmm0, xmm1
    // Horizontal min
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $4E
    minps  xmm0, xmm1
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $B1
    minps  xmm0, xmm1
    movss  res, xmm0
  end;
  Result := res;
{$ELSE}
var
  lo, hi: Single;
begin
  lo := SSE2ReduceMinF32x4(a.lo);
  hi := SSE2ReduceMinF32x4(a.hi);
  if lo < hi then Result := lo else Result := hi;
{$ENDIF}
end;

function SSE2ReduceMaxF32x8(const a: TVecF32x8): Single;
{$IFDEF CPUX64}
var pa: Pointer; res: Single;
begin
  pa := @a;
  asm
    mov    rax, pa
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Merge lo + hi with max
    maxps  xmm0, xmm1
    // Horizontal max
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $4E
    maxps  xmm0, xmm1
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $B1
    maxps  xmm0, xmm1
    movss  res, xmm0
  end;
  Result := res;
{$ELSE}
var
  lo, hi: Single;
begin
  lo := SSE2ReduceMaxF32x4(a.lo);
  hi := SSE2ReduceMaxF32x4(a.hi);
  if lo > hi then Result := lo else Result := hi;
{$ENDIF}
end;

function SSE2ReduceMulF32x8(const a: TVecF32x8): Single;
{$IFDEF CPUX64}
var pa: Pointer; res: Single;
begin
  pa := @a;
  asm
    mov    rax, pa
    movups xmm0, [rax]
    movups xmm1, [rax+16]
    // Merge lo * hi
    mulps  xmm0, xmm1
    // Horizontal mul
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $4E
    mulps  xmm0, xmm1
    movaps xmm1, xmm0
    shufps xmm1, xmm1, $B1
    mulps  xmm0, xmm1
    movss  res, xmm0
  end;
  Result := res;
{$ELSE}
begin
  Result := SSE2ReduceMulF32x4(a.lo) * SSE2ReduceMulF32x4(a.hi);
{$ENDIF}
end;

function SSE2LoadF32x8(p: PSingle): TVecF32x8;
begin
  Result.lo := SSE2LoadF32x4(p);
  Result.hi := SSE2LoadF32x4(p + 4);
end;

procedure SSE2StoreF32x8(p: PSingle; const a: TVecF32x8);
begin
  SSE2StoreF32x4(p, a.lo);
  SSE2StoreF32x4(p + 4, a.hi);
end;

function SSE2SplatF32x8(value: Single): TVecF32x8;
begin
  Result.lo := SSE2SplatF32x4(value);
  Result.hi := SSE2SplatF32x4(value);
end;

function SSE2ZeroF32x8: TVecF32x8;
begin
  Result.lo := SSE2ZeroF32x4;
  Result.hi := SSE2ZeroF32x4;
end;

// === Additional Facade Functions with SSE2 ===

// MinMax with SSE2
procedure MinMaxBytes_SSE2(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
var
  pb: PByte;
  i: SizeUInt;
  minAcc, maxAcc: Integer;
begin
  if (len = 0) or (p = nil) then
  begin
    minVal := 0;
    maxVal := 0;
    Exit;
  end;

  pb := PByte(p);
  i := 0;
  minAcc := 255;
  maxAcc := 0;

  // Process 16 bytes at a time
  while i + 16 <= len do
  begin
    asm
      mov     rax, pb
      add     rax, i
      movdqu  xmm0, [rax]

      // Get min
      movdqa  xmm1, xmm0
      psrlw   xmm1, 8
      pminub  xmm0, xmm1
      movdqa  xmm1, xmm0
      psrld   xmm1, 16
      pminub  xmm0, xmm1
      movdqa  xmm1, xmm0
      psrlq   xmm1, 32
      pminub  xmm0, xmm1
      movdqa  xmm1, xmm0
      psrldq  xmm1, 8
      pminub  xmm0, xmm1
      movd    eax, xmm0
      and     eax, $FF
      cmp     eax, minAcc
      jge     @skipmin
      mov     minAcc, eax
    @skipmin:

      // Get max
      mov     rax, pb
      add     rax, i
      movdqu  xmm0, [rax]
      movdqa  xmm1, xmm0
      psrlw   xmm1, 8
      pmaxub  xmm0, xmm1
      movdqa  xmm1, xmm0
      psrld   xmm1, 16
      pmaxub  xmm0, xmm1
      movdqa  xmm1, xmm0
      psrlq   xmm1, 32
      pmaxub  xmm0, xmm1
      movdqa  xmm1, xmm0
      psrldq  xmm1, 8
      pmaxub  xmm0, xmm1
      movd    eax, xmm0
      and     eax, $FF
      cmp     eax, maxAcc
      jle     @skipmax
      mov     maxAcc, eax
    @skipmax:
    end;
    Inc(i, 16);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    if pb[i] < minAcc then
      minAcc := pb[i];
    if pb[i] > maxAcc then
      maxAcc := pb[i];
    Inc(i);
  end;

  minVal := Byte(minAcc);
  maxVal := Byte(maxAcc);
end;

// Popcount with SSE2 (using lookup table)
function BitsetPopCount_SSE2(p: Pointer; len: SizeUInt): SizeUInt;
var
  pb: PByte;
  i: SizeUInt;
  count: SizeUInt;
  b: Byte;
const
  PopCountTable: array[0..15] of Byte = (
    0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
  );
begin
  if (len = 0) or (p = nil) then
  begin
    Result := 0;
    Exit;
  end;

  pb := PByte(p);
  count := 0;
  i := 0;

  // Use SWAR technique for bulk processing
  while i + 8 <= len do
  begin
    asm
      mov     rax, pb
      add     rax, i
      mov     rdx, [rax]      // Load 8 bytes

      // SWAR popcount
      mov     rcx, rdx
      shr     rcx, 1
      mov     r8, $5555555555555555
      and     rcx, r8
      sub     rdx, rcx

      mov     rcx, rdx
      shr     rcx, 2
      mov     r8, $3333333333333333
      and     rdx, r8
      and     rcx, r8
      add     rdx, rcx

      mov     rcx, rdx
      shr     rcx, 4
      add     rdx, rcx
      mov     r8, $0F0F0F0F0F0F0F0F
      and     rdx, r8

      mov     r8, $0101010101010101
      imul    rdx, r8
      shr     rdx, 56

      add     count, rdx
    end;
    Inc(i, 8);
  end;

  // Handle remaining bytes
  while i < len do
  begin
    b := pb[i];
    Inc(count, PopCountTable[b and $0F] + PopCountTable[b shr 4]);
    Inc(i);
  end;

  Result := count;
end;

// === Saturating Arithmetic (SSE2 硬件加速) ===
// SSE2 提供专门的饱和算术指令，比标量实现快 8-16x

// I8x16 有符号饱和加法 (PADDSB)
function SSE2I8x16SatAdd(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  // x86-64 SysV ABI: a -> RDI, b -> RSI, Result -> RAX
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  paddsb xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  // Windows x64: a -> RCX, b -> RDX, Result -> RAX
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  paddsb xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// I8x16 有符号饱和减法 (PSUBSB)
function SSE2I8x16SatSub(const a, b: TVecI8x16): TVecI8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  psubsb xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  psubsb xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// I16x8 有符号饱和加法 (PADDSW)
function SSE2I16x8SatAdd(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  paddsw xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  paddsw xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// I16x8 有符号饱和减法 (PSUBSW)
function SSE2I16x8SatSub(const a, b: TVecI16x8): TVecI16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  psubsw xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  psubsw xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// U8x16 无符号饱和加法 (PADDUSB)
function SSE2U8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  paddusb xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  paddusb xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// U8x16 无符号饱和减法 (PSUBUSB)
function SSE2U8x16SatSub(const a, b: TVecU8x16): TVecU8x16; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  psubusb xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  psubusb xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// U16x8 无符号饱和加法 (PADDUSW)
function SSE2U16x8SatAdd(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  paddusw xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  paddusw xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// U16x8 无符号饱和减法 (PSUBUSW)
function SSE2U16x8SatSub(const a, b: TVecU16x8): TVecU16x8; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  psubusw xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  psubusw xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// === I64x2 Arithmetic and Bitwise Operations (SSE2) ===
// SSE2 提供 paddq/psubq 用于 64-bit 整数运算

// I64x2 加法 (PADDQ)
function SSE2AddI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  paddq  xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  paddq  xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// I64x2 减法 (PSUBQ)
function SSE2SubI64x2(const a, b: TVecI64x2): TVecI64x2; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  psubq  xmm0, xmm1
  movdqu [rax], xmm0
  {$ELSE}
  movdqu xmm0, [rcx]
  movdqu xmm1, [rdx]
  psubq  xmm0, xmm1
  movdqu [rax], xmm0
  {$ENDIF}
end;

// I64x2 位与 (PAND)
function SSE2AndI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  SSE2AndVecRaw(@a, @b, @Result);
end;

// I64x2 位或 (POR)
function SSE2OrI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  SSE2OrVecRaw(@a, @b, @Result);
end;

// I64x2 位异或 (PXOR)
function SSE2XorI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  SSE2XorVecRaw(@a, @b, @Result);
end;

// I64x2 位非 (PXOR with all 1s)
function SSE2NotI64x2(const a: TVecI64x2): TVecI64x2;
begin
  SSE2NotVecRaw(@a, @Result);
end;

function SSE2AndNotI64x2(const a, b: TVecI64x2): TVecI64x2;
begin
  SSE2AndNotVecRaw(@a, @b, @Result);
end;

// === I64x2 Comparison Operations (SSE2 emulation) ===
// SSE2 没有原生 64 位整数比较指令（PCMPEQQ 是 SSE4.1）
// 使用两个 32 位比较 + AND/OR 逻辑实现

// CmpEqI64x2: 使用两个 32 位比较 + AND
// 比较高 32 位和低 32 位是否都相等
// pcmpeqd xmm0, xmm1  // 32位比较
// pshufd xmm2, xmm0, 0xB1  // 交换每个 64 位元素内的高低 32 位
// pand xmm0, xmm2  // 两部分都相等才算相等
function SSE2CmpEqI64x2(const a, b: TVecI64x2): TMask2;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov    rax, pa
    mov    rdx, pb
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pcmpeqd xmm0, xmm1       // 32 位元素比较: [a0L==b0L, a0H==b0H, a1L==b1L, a1H==b1H]
    pshufd  xmm2, xmm0, $B1  // 交换高低 32 位: [a0H==b0H, a0L==b0L, a1H==b1H, a1L==b1L]
    pand    xmm0, xmm2       // 每个 64 位元素：高低都相等才为真
    movmskpd eax, xmm0       // 提取每个 64 位元素的符号位（位 63）
    mov    mask, eax
  end;
  Result := TMask2(mask);
end;

// CmpNeI64x2: NOT(CmpEq)
function SSE2CmpNeI64x2(const a, b: TVecI64x2): TMask2;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov    rax, pa
    mov    rdx, pb
    movdqu xmm0, [rax]
    movdqu xmm1, [rdx]
    pcmpeqd xmm0, xmm1       // 32 位比较
    pshufd  xmm2, xmm0, $B1  // 交换高低 32 位
    pand    xmm0, xmm2       // AND
    pcmpeqd xmm3, xmm3       // 全 1
    pxor    xmm0, xmm3       // NOT
    movmskpd eax, xmm0
    mov    mask, eax
  end;
  Result := TMask2(mask);
end;

// CmpGtI64x2: 64 位有符号大于比较（SSE2 模拟）
// 算法: (a_high > b_high) || (a_high == b_high && a_low > b_low)
// 注意: 高 32 位使用有符号比较，低 32 位使用无符号比较
function SSE2CmpGtI64x2(const a, b: TVecI64x2): TMask2;
var
  pa, pb: Pointer;
  mask: Integer;
begin
  pa := @a;
  pb := @b;
  asm
    mov    rax, pa
    mov    rdx, pb
    movdqu xmm0, [rax]         // xmm0 = a = [a0L, a0H, a1L, a1H]
    movdqu xmm1, [rdx]         // xmm1 = b = [b0L, b0H, b1L, b1H]

    // Step 1: 计算 a_high > b_high (有符号 32 位比较)
    movdqa xmm2, xmm0
    pcmpgtd xmm2, xmm1         // xmm2 = [a0L>b0L?, a0H>b0H?, a1L>b1L?, a1H>b1H?]
    pshufd xmm3, xmm2, $F5     // xmm3 = [a0H>b0H?, a0H>b0H?, a1H>b1H?, a1H>b1H?] ($F5 = 11_11_01_01)

    // Step 2: 计算 a_high == b_high
    movdqa xmm4, xmm0
    pcmpeqd xmm4, xmm1         // xmm4 = [a0L==b0L?, a0H==b0H?, a1L==b1L?, a1H==b1H?]
    pshufd xmm5, xmm4, $F5     // xmm5 = [a0H==b0H?, a0H==b0H?, a1H==b1H?, a1H==b1H?]

    // Step 3: 计算 a_low > b_low (无符号比较)
    // 无符号比较技巧: 翻转符号位后用有符号比较
    // a_low >u b_low  <=>  (a_low ^ 0x80000000) >s (b_low ^ 0x80000000)
    movdqa xmm6, xmm0
    movdqa xmm7, xmm1
    // 准备 0x80000000 常量
    pcmpeqd xmm4, xmm4         // 全 1
    psrld   xmm4, 31           // 每个 dword = 1
    pslld   xmm4, 31           // 每个 dword = 0x80000000
    pxor    xmm6, xmm4         // 翻转 a 的符号位
    pxor    xmm7, xmm4         // 翻转 b 的符号位
    pcmpgtd xmm6, xmm7         // 无符号比较结果
    pshufd  xmm6, xmm6, $A0    // 只保留低 32 位结果 [a0L>b0L?, 0, a1L>b1L?, 0] ($A0 = 10_10_00_00)

    // Step 4: 组合结果
    // result = (a_high > b_high) || ((a_high == b_high) && (a_low > b_low))
    pand   xmm5, xmm6          // (a_high == b_high) && (a_low > b_low)
    por    xmm3, xmm5          // 最终结果

    // Step 5: 提取每个 64 位元素的最高位
    movmskpd eax, xmm3
    mov    mask, eax
  end;
  Result := TMask2(mask);
end;

// CmpLtI64x2: a < b = b > a
function SSE2CmpLtI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := SSE2CmpGtI64x2(b, a);
end;

// CmpGeI64x2: a >= b = NOT(a < b) = NOT(b > a)
function SSE2CmpGeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := TMask2((not Byte(SSE2CmpGtI64x2(b, a))) and 3);
end;

// CmpLeI64x2: a <= b = NOT(a > b)
function SSE2CmpLeI64x2(const a, b: TVecI64x2): TMask2;
begin
  Result := TMask2((not Byte(SSE2CmpGtI64x2(a, b))) and 3);
end;

// === Mask Operations SIMD Implementation ===
// 使用 bsf (bit scan forward) 和 SWAR popcount 加速
// Mask 类型是小整数（TMask2/4/8/16），可以用标量指令优化

// --- TMask2 Operations (2 bits) ---
function SSE2Mask2All(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3        // 只保留低 2 位
  cmp   edi, 3        // 检查是否都为 1
  sete  al            // 设置结果
  {$ELSE}
  and   ecx, 3
  cmp   ecx, 3
  sete  al
  {$ENDIF}
end;

function SSE2Mask2Any(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 3        // 测试低 2 位
  setne al            // 任何位设置则为 true
  {$ELSE}
  test  ecx, 3
  setne al
  {$ENDIF}
end;

function SSE2Mask2None(mask: TMask2): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 3
  sete  al            // 没有位设置则为 true
  {$ELSE}
  test  ecx, 3
  sete  al
  {$ENDIF}
end;

function SSE2Mask2PopCount(mask: TMask2): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3        // 只保留低 2 位
  mov   eax, edi
  shr   eax, 1        // 第二位移到位 0
  and   eax, 1        // 取第二位
  and   edi, 1        // 取第一位
  add   eax, edi      // 相加
  {$ELSE}
  and   ecx, 3
  mov   eax, ecx
  shr   eax, 1
  and   eax, 1
  and   ecx, 1
  add   eax, ecx
  {$ENDIF}
end;

function SSE2Mask2FirstSet(mask: TMask2): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 3        // 只保留低 2 位
  bsf   eax, edi      // 找第一个设置的位
  jnz   @done
  mov   eax, -1       // 没有设置的位
@done:
  {$ELSE}
  and   ecx, 3
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

// --- TMask4 Operations (4 bits) ---
function SSE2Mask4All(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 15       // 只保留低 4 位
  cmp   edi, 15
  sete  al
  {$ELSE}
  and   ecx, 15
  cmp   ecx, 15
  sete  al
  {$ENDIF}
end;

function SSE2Mask4Any(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 15
  setne al
  {$ELSE}
  test  ecx, 15
  setne al
  {$ENDIF}
end;

function SSE2Mask4None(mask: TMask4): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  edi, 15
  sete  al
  {$ELSE}
  test  ecx, 15
  sete  al
  {$ENDIF}
end;

function SSE2Mask4PopCount(mask: TMask4): Integer; assembler; nostackframe;
// SWAR popcount for 4 bits
asm
  {$IFDEF UNIX}
  and   edi, 15
  mov   eax, edi
  shr   eax, 1
  and   eax, $5       // 0101 pattern
  sub   edi, eax
  mov   eax, edi
  shr   eax, 2
  and   edi, $3       // 0011 pattern
  and   eax, $3
  add   eax, edi
  {$ELSE}
  and   ecx, 15
  mov   eax, ecx
  shr   eax, 1
  and   eax, $5
  sub   ecx, eax
  mov   eax, ecx
  shr   eax, 2
  and   ecx, $3
  and   eax, $3
  add   eax, ecx
  {$ENDIF}
end;

function SSE2Mask4FirstSet(mask: TMask4): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  and   edi, 15
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  and   ecx, 15
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

// --- TMask8 Operations (8 bits) ---
function SSE2Mask8All(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  cmp   dil, $FF
  sete  al
  {$ELSE}
  cmp   cl, $FF
  sete  al
  {$ENDIF}
end;

function SSE2Mask8Any(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  dil, dil
  setne al
  {$ELSE}
  test  cl, cl
  setne al
  {$ENDIF}
end;

function SSE2Mask8None(mask: TMask8): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  dil, dil
  sete  al
  {$ELSE}
  test  cl, cl
  sete  al
  {$ENDIF}
end;

function SSE2Mask8PopCount(mask: TMask8): Integer; assembler; nostackframe;
// SWAR popcount for 8 bits
asm
  {$IFDEF UNIX}
  movzx eax, dil
  mov   edx, eax
  shr   edx, 1
  and   edx, $55
  sub   eax, edx
  mov   edx, eax
  shr   edx, 2
  and   eax, $33
  and   edx, $33
  add   eax, edx
  mov   edx, eax
  shr   edx, 4
  add   eax, edx
  and   eax, $0F
  {$ELSE}
  movzx eax, cl
  mov   edx, eax
  shr   edx, 1
  and   edx, $55
  sub   eax, edx
  mov   edx, eax
  shr   edx, 2
  and   eax, $33
  and   edx, $33
  add   eax, edx
  mov   edx, eax
  shr   edx, 4
  add   eax, edx
  and   eax, $0F
  {$ENDIF}
end;

function SSE2Mask8FirstSet(mask: TMask8): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movzx edi, dil
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  movzx ecx, cl
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

// --- TMask16 Operations (16 bits) ---
function SSE2Mask16All(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  cmp   di, $FFFF
  sete  al
  {$ELSE}
  cmp   cx, $FFFF
  sete  al
  {$ENDIF}
end;

function SSE2Mask16Any(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  di, di
  setne al
  {$ELSE}
  test  cx, cx
  setne al
  {$ENDIF}
end;

function SSE2Mask16None(mask: TMask16): Boolean; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  test  di, di
  sete  al
  {$ELSE}
  test  cx, cx
  sete  al
  {$ENDIF}
end;

function SSE2Mask16PopCount(mask: TMask16): Integer; assembler; nostackframe;
// SWAR popcount for 16 bits
asm
  {$IFDEF UNIX}
  movzx eax, di
  mov   edx, eax
  shr   edx, 1
  and   edx, $5555
  sub   eax, edx
  mov   edx, eax
  shr   edx, 2
  and   eax, $3333
  and   edx, $3333
  add   eax, edx
  mov   edx, eax
  shr   edx, 4
  add   eax, edx
  and   eax, $0F0F
  mov   edx, eax
  shr   edx, 8
  add   eax, edx
  and   eax, $FF
  {$ELSE}
  movzx eax, cx
  mov   edx, eax
  shr   edx, 1
  and   edx, $5555
  sub   eax, edx
  mov   edx, eax
  shr   edx, 2
  and   eax, $3333
  and   edx, $3333
  add   eax, edx
  mov   edx, eax
  shr   edx, 4
  add   eax, edx
  and   eax, $0F0F
  mov   edx, eax
  shr   edx, 8
  add   eax, edx
  and   eax, $FF
  {$ENDIF}
end;

function SSE2Mask16FirstSet(mask: TMask16): Integer; assembler; nostackframe;
asm
  {$IFDEF UNIX}
  movzx edi, di
  bsf   eax, edi
  jnz   @done
  mov   eax, -1
@done:
  {$ELSE}
  movzx ecx, cx
  bsf   eax, ecx
  jnz   @done
  mov   eax, -1
@done:
  {$ENDIF}
end;

{$I nextpas.core.simd.sse2.select.inc}

// F64x2 扩展函数 - 用于构建 F64x4 分解实现

function SSE2NormalizeSignedZeroDouble(const aInput, aOutput: Double): Double; inline;
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

function SSE2FloorF64Lane(const aValue: Double): Double; inline;
var
  LFloor: Double;
begin
  if IsNan(aValue) or IsInfinite(aValue) then
    Exit(aValue);
  LFloor := Floor(aValue);
  Result := SSE2NormalizeSignedZeroDouble(aValue, LFloor);
end;

function SSE2CeilF64Lane(const aValue: Double): Double; inline;
var
  LCeil: Double;
begin
  if IsNan(aValue) or IsInfinite(aValue) then
    Exit(aValue);
  LCeil := Ceil(aValue);
  Result := SSE2NormalizeSignedZeroDouble(aValue, LCeil);
end;

function SSE2RoundF64Lane(const aValue: Double): Double; inline;
var
  LRounded: Double;
begin
  if IsNan(aValue) or IsInfinite(aValue) then
    Exit(aValue);
  LRounded := Round(aValue);
  Result := SSE2NormalizeSignedZeroDouble(aValue, LRounded);
end;

function SSE2TruncF64Lane(const aValue: Double): Double; inline;
var
  LTruncated: Double;
begin
  if IsNan(aValue) or IsInfinite(aValue) then
    Exit(aValue);
  LTruncated := Trunc(aValue);
  Result := SSE2NormalizeSignedZeroDouble(aValue, LTruncated);
end;

function SSE2FloorF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SSE2FloorF64Lane(a.d[0]);
  Result.d[1] := SSE2FloorF64Lane(a.d[1]);
end;

function SSE2CeilF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SSE2CeilF64Lane(a.d[0]);
  Result.d[1] := SSE2CeilF64Lane(a.d[1]);
end;

function SSE2RoundF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SSE2RoundF64Lane(a.d[0]);
  Result.d[1] := SSE2RoundF64Lane(a.d[1]);
end;

function SSE2TruncF64x2(const a: TVecF64x2): TVecF64x2;
begin
  Result.d[0] := SSE2TruncF64Lane(a.d[0]);
  Result.d[1] := SSE2TruncF64Lane(a.d[1]);
end;

function SSE2FmaF64x2(const a, b, c: TVecF64x2): TVecF64x2;
begin
  // FMA: a * b + c，SSE2 没有 FMA 指令，用乘加分离
  Result.d[0] := a.d[0] * b.d[0] + c.d[0];
  Result.d[1] := a.d[1] * b.d[1] + c.d[1];
end;

function SSE2ClampF64x2(const a, minVal, maxVal: TVecF64x2): TVecF64x2;
begin
  Result := SSE2MaxF64x2(SSE2MinF64x2(a, maxVal), minVal);
end;

function SSE2ReduceAddF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] + a.d[1];
end;

function SSE2ReduceMinF64x2(const a: TVecF64x2): Double;
begin
  if a.d[0] < a.d[1] then Result := a.d[0] else Result := a.d[1];
end;

function SSE2ReduceMaxF64x2(const a: TVecF64x2): Double;
begin
  if a.d[0] > a.d[1] then Result := a.d[0] else Result := a.d[1];
end;

function SSE2ReduceMulF64x2(const a: TVecF64x2): Double;
begin
  Result := a.d[0] * a.d[1];
end;

// F64x4 分解实现 - 使用 2x F64x2

// F64x4 2×128-bit SSE2 ASM 实现
function SSE2AddF64x4(const a, b: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    addpd  xmm0, xmm2
    addpd  xmm1, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AddF64x2(a.lo, b.lo);
  Result.hi := SSE2AddF64x2(a.hi, b.hi);
{$ENDIF}
end;

function SSE2SubF64x4(const a, b: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    subpd  xmm0, xmm2
    subpd  xmm1, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2SubF64x2(a.lo, b.lo);
  Result.hi := SSE2SubF64x2(a.hi, b.hi);
{$ENDIF}
end;

function SSE2MulF64x4(const a, b: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    mulpd  xmm0, xmm2
    mulpd  xmm1, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2MulF64x2(a.lo, b.lo);
  Result.hi := SSE2MulF64x2(a.hi, b.hi);
{$ENDIF}
end;

function SSE2DivF64x4(const a, b: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    divpd  xmm0, xmm2
    divpd  xmm1, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2DivF64x2(a.lo, b.lo);
  Result.hi := SSE2DivF64x2(a.hi, b.hi);
{$ENDIF}
end;

function SSE2FmaF64x4(const a, b, c: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pc, pr: Pointer;
begin
  pa := @a; pb := @b; pc := @c; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    r8,  pc
    mov    rcx, pr
    // Load a
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Load b
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    // Multiply a * b
    mulpd  xmm0, xmm2
    mulpd  xmm1, xmm3
    // Load c
    movupd xmm4, [r8]
    movupd xmm5, [r8+16]
    // Add c
    addpd  xmm0, xmm4
    addpd  xmm1, xmm5
    // Store
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2FmaF64x2(a.lo, b.lo, c.lo);
  Result.hi := SSE2FmaF64x2(a.hi, b.hi, c.hi);
{$ENDIF}
end;

// Reciprocal: 1.0 / a
function SSE2RcpF64x4(const a: TVecF64x4): TVecF64x4;
var
  one: TVecF64x2;
begin
  one := SSE2SplatF64x2(1.0);
  Result.lo := SSE2DivF64x2(one, a.lo);
  Result.hi := SSE2DivF64x2(one, a.hi);
end;

function SSE2FloorF64x4(const a: TVecF64x4): TVecF64x4;
begin
  Result.lo := SSE2FloorF64x2(a.lo);
  Result.hi := SSE2FloorF64x2(a.hi);
end;

function SSE2CeilF64x4(const a: TVecF64x4): TVecF64x4;
begin
  Result.lo := SSE2CeilF64x2(a.lo);
  Result.hi := SSE2CeilF64x2(a.hi);
end;

function SSE2RoundF64x4(const a: TVecF64x4): TVecF64x4;
begin
  Result.lo := SSE2RoundF64x2(a.lo);
  Result.hi := SSE2RoundF64x2(a.hi);
end;

function SSE2TruncF64x4(const a: TVecF64x4): TVecF64x4;
begin
  Result.lo := SSE2TruncF64x2(a.lo);
  Result.hi := SSE2TruncF64x2(a.hi);
end;

function SSE2AbsF64x4(const a: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Create sign mask for double (0x7FFFFFFFFFFFFFFF)
    pcmpeqd xmm2, xmm2       // all 1s
    psrlq   xmm2, 1          // clear sign bit (64-bit)
    movapd  xmm3, xmm2
    // Clear sign bits
    andpd   xmm0, xmm2
    andpd   xmm1, xmm3
    movupd  [rcx], xmm0
    movupd  [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AbsF64x2(a.lo);
  Result.hi := SSE2AbsF64x2(a.hi);
{$ENDIF}
end;

function SSE2SqrtF64x4(const a: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    sqrtpd xmm0, xmm0
    sqrtpd xmm1, xmm1
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2SqrtF64x2(a.lo);
  Result.hi := SSE2SqrtF64x2(a.hi);
{$ENDIF}
end;

function SSE2MinF64x4(const a, b: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    minpd  xmm0, xmm2
    minpd  xmm1, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2MinF64x2(a.lo, b.lo);
  Result.hi := SSE2MinF64x2(a.hi, b.hi);
{$ENDIF}
end;

function SSE2MaxF64x4(const a, b: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    maxpd  xmm0, xmm2
    maxpd  xmm1, xmm3
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2MaxF64x2(a.lo, b.lo);
  Result.hi := SSE2MaxF64x2(a.hi, b.hi);
{$ENDIF}
end;

function SSE2ClampF64x4(const a, minVal, maxVal: TVecF64x4): TVecF64x4;
{$IFDEF CPUX64}
var pa, pmin, pmax, pr: Pointer;
begin
  pa := @a; pmin := @minVal; pmax := @maxVal; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pmin
    mov    r8,  pmax
    mov    rcx, pr
    // Load a
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Load minVal
    movupd xmm2, [rdx]
    movupd xmm3, [rdx+16]
    // Max with minVal
    maxpd  xmm0, xmm2
    maxpd  xmm1, xmm3
    // Load maxVal
    movupd xmm4, [r8]
    movupd xmm5, [r8+16]
    // Min with maxVal
    minpd  xmm0, xmm4
    minpd  xmm1, xmm5
    // Store
    movupd [rcx], xmm0
    movupd [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2ClampF64x2(a.lo, minVal.lo, maxVal.lo);
  Result.hi := SSE2ClampF64x2(a.hi, minVal.hi, maxVal.hi);
{$ENDIF}
end;

function SSE2ReduceAddF64x4(const a: TVecF64x4): Double;
{$IFDEF CPUX64}
var pa: Pointer; res: Double;
begin
  pa := @a;
  asm
    mov    rax, pa
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Merge lo + hi
    addpd  xmm0, xmm1
    // Horizontal add for 2 doubles
    movapd xmm1, xmm0
    shufpd xmm1, xmm1, 1      // swap high/low double
    addpd  xmm0, xmm1
    movlpd res, xmm0
  end;
  Result := res;
{$ELSE}
begin
  Result := SSE2ReduceAddF64x2(a.lo) + SSE2ReduceAddF64x2(a.hi);
{$ENDIF}
end;

function SSE2ReduceMinF64x4(const a: TVecF64x4): Double;
{$IFDEF CPUX64}
var pa: Pointer; res: Double;
begin
  pa := @a;
  asm
    mov    rax, pa
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Merge with min
    minpd  xmm0, xmm1
    // Horizontal min
    movapd xmm1, xmm0
    shufpd xmm1, xmm1, 1
    minpd  xmm0, xmm1
    movlpd res, xmm0
  end;
  Result := res;
{$ELSE}
var
  lo, hi: Double;
begin
  lo := SSE2ReduceMinF64x2(a.lo);
  hi := SSE2ReduceMinF64x2(a.hi);
  if lo < hi then Result := lo else Result := hi;
{$ENDIF}
end;

function SSE2ReduceMaxF64x4(const a: TVecF64x4): Double;
{$IFDEF CPUX64}
var pa: Pointer; res: Double;
begin
  pa := @a;
  asm
    mov    rax, pa
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Merge with max
    maxpd  xmm0, xmm1
    // Horizontal max
    movapd xmm1, xmm0
    shufpd xmm1, xmm1, 1
    maxpd  xmm0, xmm1
    movlpd res, xmm0
  end;
  Result := res;
{$ELSE}
var
  lo, hi: Double;
begin
  lo := SSE2ReduceMaxF64x2(a.lo);
  hi := SSE2ReduceMaxF64x2(a.hi);
  if lo > hi then Result := lo else Result := hi;
{$ENDIF}
end;

function SSE2ReduceMulF64x4(const a: TVecF64x4): Double;
{$IFDEF CPUX64}
var pa: Pointer; res: Double;
begin
  pa := @a;
  asm
    mov    rax, pa
    movupd xmm0, [rax]
    movupd xmm1, [rax+16]
    // Merge with mul
    mulpd  xmm0, xmm1
    // Horizontal mul
    movapd xmm1, xmm0
    shufpd xmm1, xmm1, 1
    mulpd  xmm0, xmm1
    movlpd res, xmm0
  end;
  Result := res;
{$ELSE}
begin
  Result := SSE2ReduceMulF64x2(a.lo) * SSE2ReduceMulF64x2(a.hi);
{$ENDIF}
end;

function SSE2LoadF64x4(p: PDouble): TVecF64x4;
begin
  Result.lo := SSE2LoadF64x2(p);
  Result.hi := SSE2LoadF64x2(p + 2);
end;

procedure SSE2StoreF64x4(p: PDouble; const a: TVecF64x4);
begin
  SSE2StoreF64x2(p, a.lo);
  SSE2StoreF64x2(p + 2, a.hi);
end;

function SSE2SplatF64x4(value: Double): TVecF64x4;
begin
  Result.lo := SSE2SplatF64x2(value);
  Result.hi := SSE2SplatF64x2(value);
end;

function SSE2ZeroF64x4: TVecF64x4;
begin
  Result.lo := SSE2ZeroF64x2;
  Result.hi := SSE2ZeroF64x2;
end;

// F64x4 Comparison Operations (2×128-bit SSE2 ASM)

function SSE2CmpEqF64x4(const a, b: TVecF64x4): TMask4;
{$IFDEF CPUX64}
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // 加载并比较 lo (2×double)
    movupd   xmm0, [rax]
    movupd   xmm1, [rdx]
    cmpeqpd  xmm0, xmm1      // 比较 a.lo == b.lo
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      lo_mask, eax
    // 加载并比较 hi (2×double)
    movupd   xmm0, [rax+16]
    movupd   xmm1, [rdx+16]
    cmpeqpd  xmm0, xmm1      // 比较 a.hi == b.hi
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      hi_mask, eax
  end;
  Result := TMask4(lo_mask or (hi_mask shl 2));
{$ELSE}
begin
  Result := TMask4(Byte(SSE2CmpEqF64x2(a.lo, b.lo)) or (Byte(SSE2CmpEqF64x2(a.hi, b.hi)) shl 2));
{$ENDIF}
end;

function SSE2CmpLtF64x4(const a, b: TVecF64x4): TMask4;
{$IFDEF CPUX64}
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // 加载并比较 lo (2×double)
    movupd   xmm0, [rax]
    movupd   xmm1, [rdx]
    cmpltpd  xmm0, xmm1      // 比较 a.lo < b.lo
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      lo_mask, eax
    // 加载并比较 hi (2×double)
    movupd   xmm0, [rax+16]
    movupd   xmm1, [rdx+16]
    cmpltpd  xmm0, xmm1      // 比较 a.hi < b.hi
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      hi_mask, eax
  end;
  Result := TMask4(lo_mask or (hi_mask shl 2));
{$ELSE}
begin
  Result := TMask4(Byte(SSE2CmpLtF64x2(a.lo, b.lo)) or (Byte(SSE2CmpLtF64x2(a.hi, b.hi)) shl 2));
{$ENDIF}
end;

function SSE2CmpLeF64x4(const a, b: TVecF64x4): TMask4;
{$IFDEF CPUX64}
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // 加载并比较 lo (2×double)
    movupd   xmm0, [rax]
    movupd   xmm1, [rdx]
    cmplepd  xmm0, xmm1      // 比较 a.lo <= b.lo
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      lo_mask, eax
    // 加载并比较 hi (2×double)
    movupd   xmm0, [rax+16]
    movupd   xmm1, [rdx+16]
    cmplepd  xmm0, xmm1      // 比较 a.hi <= b.hi
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      hi_mask, eax
  end;
  Result := TMask4(lo_mask or (hi_mask shl 2));
{$ELSE}
begin
  Result := TMask4(Byte(SSE2CmpLeF64x2(a.lo, b.lo)) or (Byte(SSE2CmpLeF64x2(a.hi, b.hi)) shl 2));
{$ENDIF}
end;

function SSE2CmpGtF64x4(const a, b: TVecF64x4): TMask4;
{$IFDEF CPUX64}
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  // GT: a > b is same as b < a
  asm
    mov      rax, pa
    mov      rdx, pb
    // 加载并比较 lo (2×double)
    movupd   xmm0, [rdx]     // load b.lo
    movupd   xmm1, [rax]     // load a.lo
    cmpltpd  xmm0, xmm1      // 比较 b.lo < a.lo
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      lo_mask, eax
    // 加载并比较 hi (2×double)
    movupd   xmm0, [rdx+16]  // load b.hi
    movupd   xmm1, [rax+16]  // load a.hi
    cmpltpd  xmm0, xmm1      // 比较 b.hi < a.hi
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      hi_mask, eax
  end;
  Result := TMask4(lo_mask or (hi_mask shl 2));
{$ELSE}
begin
  Result := TMask4(Byte(SSE2CmpGtF64x2(a.lo, b.lo)) or (Byte(SSE2CmpGtF64x2(a.hi, b.hi)) shl 2));
{$ENDIF}
end;

function SSE2CmpGeF64x4(const a, b: TVecF64x4): TMask4;
{$IFDEF CPUX64}
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  // GE: a >= b is same as b <= a
  asm
    mov      rax, pa
    mov      rdx, pb
    // 加载并比较 lo (2×double)
    movupd   xmm0, [rdx]     // load b.lo
    movupd   xmm1, [rax]     // load a.lo
    cmplepd  xmm0, xmm1      // 比较 b.lo <= a.lo
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      lo_mask, eax
    // 加载并比较 hi (2×double)
    movupd   xmm0, [rdx+16]  // load b.hi
    movupd   xmm1, [rax+16]  // load a.hi
    cmplepd  xmm0, xmm1      // 比较 b.hi <= a.hi
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      hi_mask, eax
  end;
  Result := TMask4(lo_mask or (hi_mask shl 2));
{$ELSE}
begin
  Result := TMask4(Byte(SSE2CmpGeF64x2(a.lo, b.lo)) or (Byte(SSE2CmpGeF64x2(a.hi, b.hi)) shl 2));
{$ENDIF}
end;

function SSE2CmpNeF64x4(const a, b: TVecF64x4): TMask4;
{$IFDEF CPUX64}
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // 加载并比较 lo (2×double)
    movupd   xmm0, [rax]
    movupd   xmm1, [rdx]
    cmpneqpd xmm0, xmm1      // 比较 a.lo != b.lo
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      lo_mask, eax
    // 加载并比较 hi (2×double)
    movupd   xmm0, [rax+16]
    movupd   xmm1, [rdx+16]
    cmpneqpd xmm0, xmm1      // 比较 a.hi != b.hi
    movmskpd eax, xmm0       // 提取掩码到 eax (2-bit)
    mov      hi_mask, eax
  end;
  Result := TMask4(lo_mask or (hi_mask shl 2));
{$ELSE}
begin
  Result := TMask4(Byte(SSE2CmpNeF64x2(a.lo, b.lo)) or (Byte(SSE2CmpNeF64x2(a.hi, b.hi)) shl 2));
{$ENDIF}
end;

// I32x8 分解实现 - 使用 2x I32x4

// I32x8 2×128-bit SSE2 ASM 实现
function SSE2AddI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    movdqu xmm2, [rdx]
    movdqu xmm3, [rdx+16]
    paddd  xmm0, xmm2
    paddd  xmm1, xmm3
    movdqu [rcx], xmm0
    movdqu [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AddI32x4(a.lo, b.lo);
  Result.hi := SSE2AddI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2SubI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    movdqu xmm2, [rdx]
    movdqu xmm3, [rdx+16]
    psubd  xmm0, xmm2
    psubd  xmm1, xmm3
    movdqu [rcx], xmm0
    movdqu [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2SubI32x4(a.lo, b.lo);
  Result.hi := SSE2SubI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2MulI32x8(const a, b: TVecI32x8): TVecI32x8;
begin
  Result.lo := SSE2MulI32x4(a.lo, b.lo);
  Result.hi := SSE2MulI32x4(a.hi, b.hi);
end;

function SSE2AndI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    movdqu xmm2, [rdx]
    movdqu xmm3, [rdx+16]
    pand   xmm0, xmm2
    pand   xmm1, xmm3
    movdqu [rcx], xmm0
    movdqu [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AndI32x4(a.lo, b.lo);
  Result.hi := SSE2AndI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2OrI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    movdqu xmm2, [rdx]
    movdqu xmm3, [rdx+16]
    por    xmm0, xmm2
    por    xmm1, xmm3
    movdqu [rcx], xmm0
    movdqu [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2OrI32x4(a.lo, b.lo);
  Result.hi := SSE2OrI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2XorI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    movdqu xmm2, [rdx]
    movdqu xmm3, [rdx+16]
    pxor   xmm0, xmm2
    pxor   xmm1, xmm3
    movdqu [rcx], xmm0
    movdqu [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2XorI32x4(a.lo, b.lo);
  Result.hi := SSE2XorI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2NotI32x8(const a: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pr: Pointer;
begin
  pa := @a; pr := @Result;
  asm
    mov    rax, pa
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    // Create all 1s
    pcmpeqd xmm2, xmm2
    movdqa  xmm3, xmm2
    // XOR with all 1s = NOT
    pxor    xmm0, xmm2
    pxor    xmm1, xmm3
    movdqu  [rcx], xmm0
    movdqu  [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2NotI32x4(a.lo);
  Result.hi := SSE2NotI32x4(a.hi);
{$ENDIF}
end;

function SSE2AndNotI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    movdqu xmm0, [rax]
    movdqu xmm1, [rax+16]
    movdqu xmm2, [rdx]
    movdqu xmm3, [rdx+16]
    pandn  xmm0, xmm2
    pandn  xmm1, xmm3
    movdqu [rcx], xmm0
    movdqu [rcx+16], xmm1
  end;
{$ELSE}
begin
  Result.lo := SSE2AndNotI32x4(a.lo, b.lo);
  Result.hi := SSE2AndNotI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2ShiftLeftI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
{$IFDEF CPUX64}
begin
  SSE2ShiftLeftDwordVecRaw(@a.lo, @Result.lo, count);
  SSE2ShiftLeftDwordVecRaw(@a.hi, @Result.hi, count);
{$ELSE}
begin
  Result.lo := SSE2ShiftLeftI32x4(a.lo, count);
  Result.hi := SSE2ShiftLeftI32x4(a.hi, count);
{$ENDIF}
end;

function SSE2ShiftRightI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
{$IFDEF CPUX64}
begin
  SSE2ShiftRightDwordVecRaw(@a.lo, @Result.lo, count);
  SSE2ShiftRightDwordVecRaw(@a.hi, @Result.hi, count);
{$ELSE}
begin
  Result.lo := SSE2ShiftRightI32x4(a.lo, count);
  Result.hi := SSE2ShiftRightI32x4(a.hi, count);
{$ENDIF}
end;

function SSE2ShiftRightArithI32x8(const a: TVecI32x8; count: Integer): TVecI32x8;
{$IFDEF CPUX64}
begin
  SSE2ShiftRightArithDwordVecRaw(@a.lo, @Result.lo, count);
  SSE2ShiftRightArithDwordVecRaw(@a.hi, @Result.hi, count);
{$ELSE}
begin
  Result.lo := SSE2ShiftRightArithI32x4(a.lo, count);
  Result.hi := SSE2ShiftRightArithI32x4(a.hi, count);
{$ENDIF}
end;

function SSE2CmpEqI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (4×int32)
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    pcmpeqd  xmm0, xmm1     // a.lo == b.lo
    movmskps eax, xmm0      // Extract 4-bit mask
    mov      lo_mask, eax
    // Compare hi (4×int32)
    movdqu   xmm0, [rax+16]
    movdqu   xmm1, [rdx+16]
    pcmpeqd  xmm0, xmm1     // a.hi == b.hi
    movmskps eax, xmm0      // Extract 4-bit mask
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpLtI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  // LT: a < b is same as b > a
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (4×int32)
    movdqu   xmm0, [rdx]      // load b.lo
    movdqu   xmm1, [rax]      // load a.lo
    pcmpgtd  xmm0, xmm1       // b.lo > a.lo
    movmskps eax, xmm0
    mov      lo_mask, eax
    // Compare hi (4×int32)
    movdqu   xmm0, [rdx+16]   // load b.hi
    movdqu   xmm1, [rax+16]   // load a.hi
    pcmpgtd  xmm0, xmm1       // b.hi > a.hi
    movmskps eax, xmm0
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpGtI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (4×int32)
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    pcmpgtd  xmm0, xmm1       // a.lo > b.lo
    movmskps eax, xmm0
    mov      lo_mask, eax
    // Compare hi (4×int32)
    movdqu   xmm0, [rax+16]
    movdqu   xmm1, [rdx+16]
    pcmpgtd  xmm0, xmm1       // a.hi > b.hi
    movmskps eax, xmm0
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpLeI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  // LE: a <= b is same as NOT(a > b)
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (4×int32)
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    pcmpgtd  xmm0, xmm1       // a.lo > b.lo
    pcmpeqd  xmm2, xmm2       // all ones
    pxor     xmm0, xmm2       // NOT(a.lo > b.lo)
    movmskps eax, xmm0
    mov      lo_mask, eax
    // Compare hi (4×int32)
    movdqu   xmm0, [rax+16]
    movdqu   xmm1, [rdx+16]
    pcmpgtd  xmm0, xmm1       // a.hi > b.hi
    pcmpeqd  xmm2, xmm2       // all ones
    pxor     xmm0, xmm2       // NOT(a.hi > b.hi)
    movmskps eax, xmm0
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpGeI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  // GE: a >= b is same as NOT(b > a)
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (4×int32)
    movdqu   xmm0, [rdx]      // load b.lo
    movdqu   xmm1, [rax]      // load a.lo
    pcmpgtd  xmm0, xmm1       // b.lo > a.lo
    pcmpeqd  xmm2, xmm2       // all ones
    pxor     xmm0, xmm2       // NOT(b.lo > a.lo)
    movmskps eax, xmm0
    mov      lo_mask, eax
    // Compare hi (4×int32)
    movdqu   xmm0, [rdx+16]   // load b.hi
    movdqu   xmm1, [rax+16]   // load a.hi
    pcmpgtd  xmm0, xmm1       // b.hi > a.hi
    pcmpeqd  xmm2, xmm2       // all ones
    pxor     xmm0, xmm2       // NOT(b.hi > a.hi)
    movmskps eax, xmm0
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2CmpNeI32x8(const a, b: TVecI32x8): TMask8;
var
  pa, pb: Pointer;
  lo_mask, hi_mask: UInt32;
begin
  pa := @a;
  pb := @b;
  // NE: NOT(a == b)
  asm
    mov      rax, pa
    mov      rdx, pb
    // Compare lo (4×int32)
    movdqu   xmm0, [rax]
    movdqu   xmm1, [rdx]
    pcmpeqd  xmm0, xmm1       // a.lo == b.lo
    pcmpeqd  xmm2, xmm2       // all ones
    pxor     xmm0, xmm2       // NOT(a.lo == b.lo)
    movmskps eax, xmm0
    mov      lo_mask, eax
    // Compare hi (4×int32)
    movdqu   xmm0, [rax+16]
    movdqu   xmm1, [rdx+16]
    pcmpeqd  xmm0, xmm1       // a.hi == b.hi
    pcmpeqd  xmm2, xmm2       // all ones
    pxor     xmm0, xmm2       // NOT(a.hi == b.hi)
    movmskps eax, xmm0
    mov      hi_mask, eax
  end;
  Result := TMask8(lo_mask or (hi_mask shl 4));
end;

function SSE2MinI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  // min(a,b) = (a < b) ? a : b = blend(b, a, a < b)
  // Process 2×128-bit using pcmpgtd + pand/pandn/por
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    // First 128-bit (lo)
    movdqu xmm0, [rax]      // a.lo
    movdqu xmm1, [rdx]      // b.lo
    movdqa xmm2, xmm1       // copy b.lo
    pcmpgtd xmm2, xmm0      // b.lo > a.lo (i.e., a.lo < b.lo)
    movdqa xmm3, xmm0       // copy a.lo
    pand   xmm3, xmm2       // a.lo & mask
    pandn  xmm2, xmm1       // b.lo & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx], xmm3
    // Second 128-bit (hi)
    movdqu xmm0, [rax+16]   // a.hi
    movdqu xmm1, [rdx+16]   // b.hi
    movdqa xmm2, xmm1       // copy b.hi
    pcmpgtd xmm2, xmm0      // b.hi > a.hi
    movdqa xmm3, xmm0       // copy a.hi
    pand   xmm3, xmm2       // a.hi & mask
    pandn  xmm2, xmm1       // b.hi & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx+16], xmm3
  end;
{$ELSE}
begin
  Result.lo := SSE2MinI32x4(a.lo, b.lo);
  Result.hi := SSE2MinI32x4(a.hi, b.hi);
{$ENDIF}
end;

function SSE2MaxI32x8(const a, b: TVecI32x8): TVecI32x8;
{$IFDEF CPUX64}
var pa, pb, pr: Pointer;
begin
  pa := @a; pb := @b; pr := @Result;
  // max(a,b) = (a > b) ? a : b = blend(b, a, a > b)
  // Process 2×128-bit using pcmpgtd + pand/pandn/por
  asm
    mov    rax, pa
    mov    rdx, pb
    mov    rcx, pr
    // First 128-bit (lo)
    movdqu xmm0, [rax]      // a.lo
    movdqu xmm1, [rdx]      // b.lo
    movdqa xmm2, xmm0       // copy a.lo
    pcmpgtd xmm2, xmm1      // a.lo > b.lo
    movdqa xmm3, xmm0       // copy a.lo
    pand   xmm3, xmm2       // a.lo & mask
    pandn  xmm2, xmm1       // b.lo & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx], xmm3
    // Second 128-bit (hi)
    movdqu xmm0, [rax+16]   // a.hi
    movdqu xmm1, [rdx+16]   // b.hi
    movdqa xmm2, xmm0       // copy a.hi
    pcmpgtd xmm2, xmm1      // a.hi > b.hi
    movdqa xmm3, xmm0       // copy a.hi
    pand   xmm3, xmm2       // a.hi & mask
    pandn  xmm2, xmm1       // b.hi & ~mask
    por    xmm3, xmm2       // combine
    movdqu [rcx+16], xmm3
  end;
{$ELSE}
begin
  Result.lo := SSE2MaxI32x4(a.lo, b.lo);
  Result.hi := SSE2MaxI32x4(a.hi, b.hi);
{$ENDIF}
end;

{$I nextpas.core.simd.sse2.wide_emulation.inc}

// === Batch Array Operations ===

{$I nextpas.core.simd.sse2.batch.inc}

// === Backend Registration ===

{$I nextpas.core.simd.sse2.register.inc}

{$POP}

end.
