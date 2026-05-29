unit nextpas.core.simd.avx512;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}
{$asmmode intel}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.mask,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.backend.priority;

// === AVX-512 Backend Implementation ===
// Provides SIMD-accelerated operations using x86-64 AVX-512 instructions.
// This backend requires AVX-512F support (Intel Skylake-X 2017+, AMD Zen 4 2022+).
// Uses 512-bit ZMM registers, processing 64 bytes per iteration.

// Register the AVX-512 backend
procedure RegisterAVX512Backend;

// Pure logical predicate: returns True iff the CPU has all sub-features required by this backend.
// NOTE: This does NOT include OS enabling checks (XCR0), which are handled separately via HasAVX512.
function X86HasAVX512BackendRequiredFeatures(const AX86: TX86Features): Boolean; inline;

// === AVX-512 门面函数声明 ===

// 内存操作函数
function MemEqual_AVX512(a, b: Pointer; len: SizeUInt): LongBool;
function MemFindByte_AVX512(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
procedure MemCopy_AVX512(src, dst: Pointer; len: SizeUInt);
procedure MemSet_AVX512(dst: Pointer; len: SizeUInt; value: Byte);

// 统计函数
function SumBytes_AVX512(p: Pointer; len: SizeUInt): UInt64;
procedure MinMaxBytes_AVX512(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte);
function CountByte_AVX512(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
function BitsetPopCount_AVX512(p: Pointer; len: SizeUInt): SizeUInt;

// 文本处理函数
function AsciiIEqual_AVX512(a, b: Pointer; len: SizeUInt): Boolean;
procedure ToLowerAscii_AVX512(p: Pointer; len: SizeUInt);
procedure ToUpperAscii_AVX512(p: Pointer; len: SizeUInt);

// 搜索函数
implementation

uses
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.avx2; // Fallback for some operations

{$I nextpas.core.simd.avx512.facade.inc}

// === AVX-512 Vector Type Operations ===

{$I nextpas.core.simd.avx512.f32x16_arith.inc}

{$I nextpas.core.simd.avx512.f64x8_arith.inc}

{$I nextpas.core.simd.avx512.wide_loadstore.inc}

{$I nextpas.core.simd.avx512.i32x16_arith.inc}

{$I nextpas.core.simd.avx512.i32x16_bitwise.inc}

{$I nextpas.core.simd.avx512.i32x16_shift.inc}

{$I nextpas.core.simd.avx512.i32x16_compare.inc}

{$I nextpas.core.simd.avx512.i32x16_minmax.inc}

{$I nextpas.core.simd.avx512.i32x16_loadstore.inc}

{$I nextpas.core.simd.avx512.i64x8_arith.inc}

{$I nextpas.core.simd.avx512.i64x8_bitwise.inc}

{$I nextpas.core.simd.avx512.i64x8_compare.inc}

{$I nextpas.core.simd.avx512.u32x16_family.inc}

{$I nextpas.core.simd.avx512.u64x8_family.inc}

{$I nextpas.core.simd.avx512.i16x32_family.inc}

{$I nextpas.core.simd.avx512.i8x64_family.inc}

{$I nextpas.core.simd.avx512.u8x64_family.inc}

{$I nextpas.core.simd.avx512.f32x16_compare.inc}

{$I nextpas.core.simd.avx512.f64x8_compare.inc}

{$I nextpas.core.simd.avx512.f32x16_math.inc}

{$I nextpas.core.simd.avx512.f64x8_math.inc}

{$I nextpas.core.simd.avx512.f32x16_fma_round.inc}

{$I nextpas.core.simd.avx512.f64x8_fma_round.inc}

{$I nextpas.core.simd.avx512.f32x16_reduce.inc}

{$I nextpas.core.simd.avx512.f64x8_reduce.inc}

{$I nextpas.core.simd.avx512.mask_sat.inc}

// === Batch Array Operations (512-bit ZMM) ===

{$I nextpas.core.simd.avx512.batch.inc}

// === Backend Registration ===

function X86HasAVX512BackendRequiredFeatures(const AX86: TX86Features): Boolean; inline;
begin
  Result := nextpas.core.simd.cpuinfo.base.X86HasAVX512BackendRequiredFeatures(AX86);
end;

{$I nextpas.core.simd.avx512.register.inc}


end.
