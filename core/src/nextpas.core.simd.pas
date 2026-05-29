unit nextpas.core.simd;


{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.runtime,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.utils      // Shuffle, Blend, Convert operations
{$IFDEF CPUX86_64}  // x86-64 SIMD backends use 64-bit assembly
  , nextpas.core.simd.sse2
  , nextpas.core.simd.sse3      // SSE3: horizontal ops (HADDPS, HSUBPS)
  , nextpas.core.simd.ssse3     // SSSE3: byte shuffle (PSHUFB), integer abs (PABS)
  , nextpas.core.simd.sse41     // SSE4.1: dot product (DPPS), rounding, PMULLD
  , nextpas.core.simd.sse42     // SSE4.2: CRC32, string ops, PCMPGTQ
  , nextpas.core.simd.avx2
  {$IFDEF SIMD_BACKEND_AVX512}
  , nextpas.core.simd.avx512
  {$ENDIF}
{$ENDIF}
{$IFDEF CPUI386}  // i386 SSE2 backend uses 32-bit assembly
  , nextpas.core.simd.sse2.i386
{$ENDIF}
{$IFDEF SIMD_ARM_AVAILABLE}
  , nextpas.core.simd.neon
{$ENDIF}
{$IF DEFINED(SIMD_RISCV_AVAILABLE) AND DEFINED(SIMD_EXPERIMENTAL_RISCVV)}
  nextpas.core.simd.riscvv  // ⚠️ Experimental backend: opt-in only; not wired into the default stable public façade.
{$ENDIF}
  ;

{**
  @abstract(Modern SIMD Framework for FreePascal)
  
  This is the main user interface for the SIMD framework, providing:
  @unorderedlist(
    @item(High-level vector types with type safety)
    @item(Automatic backend selection (Scalar/SSE2/AVX2/AVX-512/NEON))
    @item(Zero-overhead dispatch via function pointer tables)
    @item(Rust portable-simd compatible naming conventions)
  )
  
  @bold(Quick Start:)
  @longcode(#
  uses nextpas.core.simd;
  var a, b, c: TVecF32x4;
  begin
    a := VecF32x4Splat(1.5);
    b := VecF32x4Splat(2.0);
    c := VecF32x4Add(a, b);  // SIMD accelerated
  end;
  #)
  
  @seealso(nextpas.core.simd.dispatch)
  @seealso(nextpas.core.simd.base)
*}

// === Re-export Core Types ===
{$I nextpas.core.simd.types.inc}

// === Core Operator Overloads ===
operator + (const a, b: TVecF32x4): TVecF32x4; inline;
operator - (const a, b: TVecF32x4): TVecF32x4; inline;
operator * (const a, b: TVecF32x4): TVecF32x4; inline;
operator / (const a, b: TVecF32x4): TVecF32x4; inline;
operator - (const a: TVecF32x4): TVecF32x4; inline;
operator * (const a: TVecF32x4; s: Single): TVecF32x4; inline;
operator * (s: Single; const a: TVecF32x4): TVecF32x4; inline;
operator / (const a: TVecF32x4; s: Single): TVecF32x4; inline;

operator + (const a, b: TVecF64x2): TVecF64x2; inline;
operator - (const a, b: TVecF64x2): TVecF64x2; inline;
operator * (const a, b: TVecF64x2): TVecF64x2; inline;
operator / (const a, b: TVecF64x2): TVecF64x2; inline;
operator - (const a: TVecF64x2): TVecF64x2; inline;

operator + (const a, b: TVecI32x4): TVecI32x4; inline;
operator - (const a, b: TVecI32x4): TVecI32x4; inline;
operator - (const a: TVecI32x4): TVecI32x4; inline;

operator + (const a, b: TVecU32x4): TVecU32x4; inline;
operator - (const a, b: TVecU32x4): TVecU32x4; inline;
operator * (const a, b: TVecU32x4): TVecU32x4; inline;
operator and (const a, b: TVecU32x4): TVecU32x4; inline;
operator or (const a, b: TVecU32x4): TVecU32x4; inline;
operator xor (const a, b: TVecU32x4): TVecU32x4; inline;
operator not (const a: TVecU32x4): TVecU32x4; inline;

operator + (const a, b: TVecU64x2): TVecU64x2; inline;
operator - (const a, b: TVecU64x2): TVecU64x2; inline;
operator and (const a, b: TVecU64x2): TVecU64x2; inline;
operator or (const a, b: TVecU64x2): TVecU64x2; inline;
operator xor (const a, b: TVecU64x2): TVecU64x2; inline;
operator not (const a: TVecU64x2): TVecU64x2; inline;

operator + (const a, b: TVecU16x8): TVecU16x8; inline;
operator - (const a, b: TVecU16x8): TVecU16x8; inline;
operator * (const a, b: TVecU16x8): TVecU16x8; inline;
operator and (const a, b: TVecU16x8): TVecU16x8; inline;
operator or (const a, b: TVecU16x8): TVecU16x8; inline;
operator xor (const a, b: TVecU16x8): TVecU16x8; inline;
operator not (const a: TVecU16x8): TVecU16x8; inline;

operator + (const a, b: TVecU8x16): TVecU8x16; inline;
operator - (const a, b: TVecU8x16): TVecU8x16; inline;
operator and (const a, b: TVecU8x16): TVecU8x16; inline;
operator or (const a, b: TVecU8x16): TVecU8x16; inline;
operator xor (const a, b: TVecU8x16): TVecU8x16; inline;
operator not (const a: TVecU8x16): TVecU8x16; inline;

operator + (const a, b: TVecU32x8): TVecU32x8; inline;
operator - (const a, b: TVecU32x8): TVecU32x8; inline;
operator * (const a, b: TVecU32x8): TVecU32x8; inline;
operator and (const a, b: TVecU32x8): TVecU32x8; inline;
operator or (const a, b: TVecU32x8): TVecU32x8; inline;
operator xor (const a, b: TVecU32x8): TVecU32x8; inline;
operator not (const a: TVecU32x8): TVecU32x8; inline;

operator + (const a, b: TVecU64x4): TVecU64x4; inline;
operator - (const a, b: TVecU64x4): TVecU64x4; inline;
operator and (const a, b: TVecU64x4): TVecU64x4; inline;
operator or (const a, b: TVecU64x4): TVecU64x4; inline;
operator xor (const a, b: TVecU64x4): TVecU64x4; inline;
operator not (const a: TVecU64x4): TVecU64x4; inline;

operator + (const a, b: TVecU32x16): TVecU32x16; inline;
operator - (const a, b: TVecU32x16): TVecU32x16; inline;
operator * (const a, b: TVecU32x16): TVecU32x16; inline;
operator and (const a, b: TVecU32x16): TVecU32x16; inline;
operator or (const a, b: TVecU32x16): TVecU32x16; inline;
operator xor (const a, b: TVecU32x16): TVecU32x16; inline;
operator not (const a: TVecU32x16): TVecU32x16; inline;

operator + (const a, b: TVecU64x8): TVecU64x8; inline;
operator - (const a, b: TVecU64x8): TVecU64x8; inline;
operator and (const a, b: TVecU64x8): TVecU64x8; inline;
operator or (const a, b: TVecU64x8): TVecU64x8; inline;
operator xor (const a, b: TVecU64x8): TVecU64x8; inline;
operator not (const a: TVecU64x8): TVecU64x8; inline;

operator + (const a, b: TVecU8x64): TVecU8x64; inline;
operator - (const a, b: TVecU8x64): TVecU8x64; inline;
operator and (const a, b: TVecU8x64): TVecU8x64; inline;
operator or (const a, b: TVecU8x64): TVecU8x64; inline;
operator xor (const a, b: TVecU8x64): TVecU8x64; inline;
operator not (const a: TVecU8x64): TVecU8x64; inline;

// === High-Level Vector Operations ===

{** @abstract(F32x4 Arithmetic Operations - 4x Single-precision floats) *}

{**
  Element-wise addition of two 4-element float vectors.
  @param(a First operand vector)
  @param(b Second operand vector)
  @returns(Result vector where result[i] = a[i] + b[i])
*}
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;

{** Element-wise subtraction. @returns(result[i] = a[i] - b[i]) *}
function VecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;

{** Element-wise multiplication. @returns(result[i] = a[i] * b[i]) *}
function VecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;

{** Element-wise division. @returns(result[i] = a[i] / b[i]) *}
function VecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;

{** @abstract(F32x4 Comparison Operations)
  Returns TMask4 where bit i is set if condition holds for element i. *}

{** Equal comparison. @returns(mask[i] = (a[i] == b[i])) *}
function VecF32x4CmpEq(const a, b: TVecF32x4): TMask4; inline;

{** Less-than comparison. @returns(mask[i] = (a[i] < b[i])) *}
function VecF32x4CmpLt(const a, b: TVecF32x4): TMask4; inline;

{** Less-or-equal comparison. @returns(mask[i] = (a[i] <= b[i])) *}
function VecF32x4CmpLe(const a, b: TVecF32x4): TMask4; inline;

{** Greater-than comparison. @returns(mask[i] = (a[i] > b[i])) *}
function VecF32x4CmpGt(const a, b: TVecF32x4): TMask4; inline;

{** Greater-or-equal comparison. @returns(mask[i] = (a[i] >= b[i])) *}
function VecF32x4CmpGe(const a, b: TVecF32x4): TMask4; inline;

{** Not-equal comparison. @returns(mask[i] = (a[i] != b[i])) *}
function VecF32x4CmpNe(const a, b: TVecF32x4): TMask4; inline;

{** @abstract(F32x4 Math Functions) *}

{** Element-wise absolute value. @returns(result[i] = |a[i]|) *}
function VecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;

{** Element-wise square root. @returns(result[i] = sqrt(a[i])) *}
function VecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;

{** Element-wise minimum. @returns(result[i] = min(a[i], b[i])) *}
function VecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;

{** Element-wise maximum. @returns(result[i] = max(a[i], b[i])) *}
function VecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;

{** @abstract(F32x4 Extended Math Functions) *}

{**
  Fused multiply-add: a*b + c.
  Uses FMA instruction if available, otherwise emulated.
  @returns(result[i] = a[i] * b[i] + c[i])
*}
function VecF32x4Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;

{** Approximate reciprocal (12-bit precision). @returns(result[i] ≈ 1/a[i]) *}
function VecF32x4Rcp(const a: TVecF32x4): TVecF32x4; inline;

{** Approximate reciprocal square root (12-bit precision). @returns(result[i] ≈ 1/sqrt(a[i])) *}
function VecF32x4Rsqrt(const a: TVecF32x4): TVecF32x4; inline;

{** Floor (round toward -∞). @returns(result[i] = floor(a[i])) *}
function VecF32x4Floor(const a: TVecF32x4): TVecF32x4; inline;

{** Ceiling (round toward +∞). @returns(result[i] = ceil(a[i])) *}
function VecF32x4Ceil(const a: TVecF32x4): TVecF32x4; inline;

{** Round to nearest integer. @returns(result[i] = round(a[i])) *}
function VecF32x4Round(const a: TVecF32x4): TVecF32x4; inline;

{** Truncate toward zero. @returns(result[i] = trunc(a[i])) *}
function VecF32x4Trunc(const a: TVecF32x4): TVecF32x4; inline;

{** Clamp to range. @returns(result[i] = clamp(a[i], minVal[i], maxVal[i])) *}
function VecF32x4Clamp(const a, minVal, maxVal: TVecF32x4): TVecF32x4; inline;

{** @abstract(3D/4D Vector Math - Geometry operations) *}

{** 4-element dot product. @returns(a[0]*b[0] + a[1]*b[1] + a[2]*b[2] + a[3]*b[3]) *}
function VecF32x4Dot(const a, b: TVecF32x4): Single; inline;

{** 3-element dot product (ignores w). @returns(a.x*b.x + a.y*b.y + a.z*b.z) *}
function VecF32x3Dot(const a, b: TVecF32x4): Single; inline;

{** 3D cross product. @returns([a.y*b.z - a.z*b.y, a.z*b.x - a.x*b.z, a.x*b.y - a.y*b.x, 0]) *}
function VecF32x3Cross(const a, b: TVecF32x4): TVecF32x4; inline;

{** 4-element vector length. @returns(sqrt(dot(a, a))) *}
function VecF32x4Length(const a: TVecF32x4): Single; inline;

{** 3-element vector length (ignores w). @returns(sqrt(x² + y² + z²)) *}
function VecF32x3Length(const a: TVecF32x4): Single; inline;

{** Normalize 4-element vector. @returns(a / length(a)) *}
function VecF32x4Normalize(const a: TVecF32x4): TVecF32x4; inline;

{** Normalize 3-element vector (w=0). @returns([x,y,z,0] / length([x,y,z])) *}
function VecF32x3Normalize(const a: TVecF32x4): TVecF32x4; inline;

{** @abstract(FMA-optimized Dot Product Functions) *}

{** 8-element dot product (256-bit). @returns(sum of a[i]*b[i] for i=0..7) *}
function VecF32x8Dot(const a, b: TVecF32x8): Single; inline;

{** 2-element double-precision dot product. @returns(a[0]*b[0] + a[1]*b[1]) *}
function VecF64x2Dot(const a, b: TVecF64x2): Double; inline;

{** 4-element double-precision dot product (256-bit). @returns(sum of a[i]*b[i] for i=0..3) *}
function VecF64x4Dot(const a, b: TVecF64x4): Double; inline;

{** @abstract(F32x4 Reduction/Horizontal Operations) *}

{** Horizontal sum of all elements. @returns(a[0] + a[1] + a[2] + a[3]) *}
function VecF32x4ReduceAdd(const a: TVecF32x4): Single; inline;

{** Minimum of all elements. @returns(min(a[0], a[1], a[2], a[3])) *}
function VecF32x4ReduceMin(const a: TVecF32x4): Single; inline;

{** Maximum of all elements. @returns(max(a[0], a[1], a[2], a[3])) *}
function VecF32x4ReduceMax(const a: TVecF32x4): Single; inline;

{** Product of all elements. @returns(a[0] * a[1] * a[2] * a[3]) *}
function VecF32x4ReduceMul(const a: TVecF32x4): Single; inline;

{** @abstract(F32x4 Memory Operations) *}

{** Load 4 floats from memory (unaligned). @param(p Pointer to 4 consecutive floats) *}
function VecF32x4Load(p: PSingle): TVecF32x4; inline;

{** Load 4 floats from 16-byte aligned memory (faster). @param(p Must be 16-byte aligned) *}
function VecF32x4LoadAligned(p: PSingle): TVecF32x4; inline;

{** Store 4 floats to memory (unaligned). *}
procedure VecF32x4Store(p: PSingle; const a: TVecF32x4); inline;

{** Store 4 floats to 16-byte aligned memory (faster). @param(p Must be 16-byte aligned) *}
procedure VecF32x4StoreAligned(p: PSingle; const a: TVecF32x4); inline;

{** @abstract(F32x4 Utility Operations) *}

{** Broadcast scalar to all lanes. @returns([value, value, value, value]) *}
function VecF32x4Splat(value: Single): TVecF32x4; inline;

{** Create zero vector. @returns([0, 0, 0, 0]) *}
function VecF32x4Zero: TVecF32x4; inline;

{**
  Select elements based on mask.
  @param(mask Bit mask where bit i selects source for element i)
  @returns(result[i] = mask[i] ? a[i] : b[i])
*}
function VecF32x4Select(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4; inline;

{** Extract single element. @param(index Lane index 0-3) *}
function VecF32x4Extract(const a: TVecF32x4; index: Integer): Single; inline;

{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecF32x4Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; inline;

// === Extract/Insert Lane Operations ===
// These functions provide element-level access to SIMD vectors.
// Extract retrieves a single lane value; Insert creates a new vector with one lane modified.
// Index bounds are clamped to valid range (saturation strategy).

// F64x2 (128-bit, lanes 0-1)
{** Extract single element. @param(index Lane index 0-1) *}
function VecF64x2Extract(const a: TVecF64x2; index: Integer): Double; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecF64x2Insert(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2; inline;

// I32x4 (128-bit, lanes 0-3)
{** Extract single element. @param(index Lane index 0-3) *}
function VecI32x4Extract(const a: TVecI32x4; index: Integer): Int32; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecI32x4Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4; inline;

// I64x2 (128-bit, lanes 0-1)
{** Extract single element. @param(index Lane index 0-1) *}
function VecI64x2Extract(const a: TVecI64x2; index: Integer): Int64; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecI64x2Insert(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2; inline;

// F32x8 (256-bit, lanes 0-7)
{** Extract single element. @param(index Lane index 0-7) *}
function VecF32x8Extract(const a: TVecF32x8; index: Integer): Single; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecF32x8Insert(const a: TVecF32x8; value: Single; index: Integer): TVecF32x8; inline;

// F64x4 (256-bit, lanes 0-3)
{** Extract single element. @param(index Lane index 0-3) *}
function VecF64x4Extract(const a: TVecF64x4; index: Integer): Double; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecF64x4Insert(const a: TVecF64x4; value: Double; index: Integer): TVecF64x4; inline;

// I32x8 (256-bit, lanes 0-7)
{** Extract single element. @param(index Lane index 0-7) *}
function VecI32x8Extract(const a: TVecI32x8; index: Integer): Int32; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecI32x8Insert(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8; inline;

// I64x4 (256-bit, lanes 0-3)
{** Extract single element. @param(index Lane index 0-3) *}
function VecI64x4Extract(const a: TVecI64x4; index: Integer): Int64; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecI64x4Insert(const a: TVecI64x4; value: Int64; index: Integer): TVecI64x4; inline;

// F32x16 (512-bit, lanes 0-15)
{** Extract single element. @param(index Lane index 0-15) *}
function VecF32x16Extract(const a: TVecF32x16; index: Integer): Single; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecF32x16Insert(const a: TVecF32x16; value: Single; index: Integer): TVecF32x16; inline;

// I32x16 (512-bit, lanes 0-15)
{** Extract single element. @param(index Lane index 0-15) *}
function VecI32x16Extract(const a: TVecI32x16; index: Integer): Int32; inline;
{** Insert value at index. @returns(Vector with a[index] replaced by value) *}
function VecI32x16Insert(const a: TVecI32x16; value: Int32; index: Integer): TVecI32x16; inline;

// === F64x2 Operations (128-bit Double) ===
// 添加缺失的 F64x2 高级 API

// F64x2 arithmetic
function VecF64x2Add(const a, b: TVecF64x2): TVecF64x2; inline;
function VecF64x2Sub(const a, b: TVecF64x2): TVecF64x2; inline;
function VecF64x2Mul(const a, b: TVecF64x2): TVecF64x2; inline;
function VecF64x2Div(const a, b: TVecF64x2): TVecF64x2; inline;

// F64x2 comparison
function VecF64x2CmpEq(const a, b: TVecF64x2): TMask2; inline;
function VecF64x2CmpLt(const a, b: TVecF64x2): TMask2; inline;
function VecF64x2CmpLe(const a, b: TVecF64x2): TMask2; inline;
function VecF64x2CmpGt(const a, b: TVecF64x2): TMask2; inline;
function VecF64x2CmpGe(const a, b: TVecF64x2): TMask2; inline;
function VecF64x2CmpNe(const a, b: TVecF64x2): TMask2; inline;

// F64x2 math functions
function VecF64x2Abs(const a: TVecF64x2): TVecF64x2; inline;
function VecF64x2Sqrt(const a: TVecF64x2): TVecF64x2; inline;
function VecF64x2Min(const a, b: TVecF64x2): TVecF64x2; inline;
function VecF64x2Max(const a, b: TVecF64x2): TVecF64x2; inline;

// F64x2 extended math functions
{** Fused multiply-add: result = a * b + c (single rounding) *}
function VecF64x2Fma(const a, b, c: TVecF64x2): TVecF64x2; inline;

// F64x2 rounding functions
{** Floor: round towards negative infinity *}
function VecF64x2Floor(const a: TVecF64x2): TVecF64x2; inline;
{** Ceil: round towards positive infinity *}
function VecF64x2Ceil(const a: TVecF64x2): TVecF64x2; inline;
{** Round: round to nearest integer (banker's rounding) *}
function VecF64x2Round(const a: TVecF64x2): TVecF64x2; inline;
{** Trunc: round towards zero *}
function VecF64x2Trunc(const a: TVecF64x2): TVecF64x2; inline;

// F64x2 reduction
function VecF64x2ReduceAdd(const a: TVecF64x2): Double; inline;
function VecF64x2ReduceMin(const a: TVecF64x2): Double; inline;
function VecF64x2ReduceMax(const a: TVecF64x2): Double; inline;
function VecF64x2ReduceMul(const a: TVecF64x2): Double; inline;

// F64x2 memory operations
function VecF64x2Load(p: PDouble): TVecF64x2; inline;
procedure VecF64x2Store(p: PDouble; const a: TVecF64x2); inline;

// F64x2 utility operations
function VecF64x2Splat(value: Double): TVecF64x2; inline;
function VecF64x2Zero: TVecF64x2; inline;
function VecF64x2Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2; inline;

// 缺失的 Select 操作 (条件选择: mask[i] != 0 ? a[i] : b[i])
{** 根据向量掩码选择元素。掩码元素非零时选择 a，否则选择 b *}
function VecI32x4Select(const mask: TVecI32x4; const a, b: TVecI32x4): TVecI32x4; inline;
{** 根据向量掩码选择元素（256-bit）。掩码元素最高位为 1 时选择 a *}
function VecF32x8Select(const mask: TVecU32x8; const a, b: TVecF32x8): TVecF32x8; inline;
{** 根据向量掩码选择元素（256-bit）。掩码元素最高位为 1 时选择 a *}
function VecF64x4Select(const mask: TVecU64x4; const a, b: TVecF64x4): TVecF64x4; inline;

// Mask Operations (条件分支优化)
// TMask2 (2 元素向量的比较结果)
function Mask2All(mask: TMask2): Boolean; inline;    // 全部为 true
function Mask2Any(mask: TMask2): Boolean; inline;    // 至少一个为 true
function Mask2None(mask: TMask2): Boolean; inline;   // 全部为 false
function Mask2PopCount(mask: TMask2): Integer; inline;  // 为 true 的元素数
function Mask2FirstSet(mask: TMask2): Integer; inline;  // 第一个为 true 的索引，-1 if none

// TMask4 (4 元素向量的比较结果)
function Mask4All(mask: TMask4): Boolean; inline;
function Mask4Any(mask: TMask4): Boolean; inline;
function Mask4None(mask: TMask4): Boolean; inline;
function Mask4PopCount(mask: TMask4): Integer; inline;
function Mask4FirstSet(mask: TMask4): Integer; inline;

// TMask8 (8 元素向量的比较结果)
function Mask8All(mask: TMask8): Boolean; inline;
function Mask8Any(mask: TMask8): Boolean; inline;
function Mask8None(mask: TMask8): Boolean; inline;
function Mask8PopCount(mask: TMask8): Integer; inline;
function Mask8FirstSet(mask: TMask8): Integer; inline;

// TMask16 (16 元素向量的比较结果)
function Mask16All(mask: TMask16): Boolean; inline;
function Mask16Any(mask: TMask16): Boolean; inline;
function Mask16None(mask: TMask16): Boolean; inline;
function Mask16PopCount(mask: TMask16): Integer; inline;
function Mask16FirstSet(mask: TMask16): Integer; inline;

// === I32x4 Operations (128-bit Integer) ===
// 添加缺失的 I32x4 高级 API

// I32x4 arithmetic
function VecI32x4Add(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4Sub(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4Mul(const a, b: TVecI32x4): TVecI32x4; inline;

// I32x4 bitwise operations
function VecI32x4And(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4Or(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4Xor(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4Not(const a: TVecI32x4): TVecI32x4; inline;
function VecI32x4AndNot(const a, b: TVecI32x4): TVecI32x4; inline;

// I32x4 shift operations
function VecI32x4ShiftLeft(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
function VecI32x4ShiftRight(const a: TVecI32x4; count: Integer): TVecI32x4; inline;
function VecI32x4ShiftRightArith(const a: TVecI32x4; count: Integer): TVecI32x4; inline;

// I32x4 comparison
function VecI32x4CmpEq(const a, b: TVecI32x4): TMask4; inline;
function VecI32x4CmpLt(const a, b: TVecI32x4): TMask4; inline;
function VecI32x4CmpGt(const a, b: TVecI32x4): TMask4; inline;
function VecI32x4CmpLe(const a, b: TVecI32x4): TMask4; inline;  // 添加缺失 API
function VecI32x4CmpGe(const a, b: TVecI32x4): TMask4; inline;  // 添加缺失 API
function VecI32x4CmpNe(const a, b: TVecI32x4): TMask4; inline;  // 添加缺失 API

// I32x4 min/max
function VecI32x4Min(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4Max(const a, b: TVecI32x4): TVecI32x4; inline;

// === I64x2 Operations (128-bit Integer, 64-bit elements) ===
// 添加 I64x2 高级 API

// I64x2 arithmetic
function VecI64x2Add(const a, b: TVecI64x2): TVecI64x2; inline;
function VecI64x2Sub(const a, b: TVecI64x2): TVecI64x2; inline;

// I64x2 bitwise operations
function VecI64x2And(const a, b: TVecI64x2): TVecI64x2; inline;
function VecI64x2Or(const a, b: TVecI64x2): TVecI64x2; inline;
function VecI64x2Xor(const a, b: TVecI64x2): TVecI64x2; inline;
function VecI64x2Not(const a: TVecI64x2): TVecI64x2; inline;
function VecI64x2AndNot(const a, b: TVecI64x2): TVecI64x2; inline;

// I64x2 shift operations
function VecI64x2ShiftLeft(const a: TVecI64x2; count: Integer): TVecI64x2; inline;
function VecI64x2ShiftRight(const a: TVecI64x2; count: Integer): TVecI64x2; inline;
function VecI64x2ShiftRightArith(const a: TVecI64x2; count: Integer): TVecI64x2; inline;

// I64x2 comparison
function VecI64x2CmpEq(const a, b: TVecI64x2): TMask2; inline;
function VecI64x2CmpLt(const a, b: TVecI64x2): TMask2; inline;
function VecI64x2CmpGt(const a, b: TVecI64x2): TMask2; inline;
function VecI64x2CmpLe(const a, b: TVecI64x2): TMask2; inline;  // 添加缺失 API
function VecI64x2CmpGe(const a, b: TVecI64x2): TMask2; inline;  // 添加缺失 API
function VecI64x2CmpNe(const a, b: TVecI64x2): TMask2; inline;  // 添加缺失 API

// I64x2 min/max
function VecI64x2Min(const a, b: TVecI64x2): TVecI64x2; inline;
function VecI64x2Max(const a, b: TVecI64x2): TVecI64x2; inline;

// === U64x2 Operations (128-bit Unsigned 64-bit Integer) ===
// 添加 U64x2 高级 API

// U64x2 arithmetic
function VecU64x2Add(const a, b: TVecU64x2): TVecU64x2; inline;
function VecU64x2Sub(const a, b: TVecU64x2): TVecU64x2; inline;

// U64x2 bitwise operations
function VecU64x2And(const a, b: TVecU64x2): TVecU64x2; inline;
function VecU64x2Or(const a, b: TVecU64x2): TVecU64x2; inline;
function VecU64x2Xor(const a, b: TVecU64x2): TVecU64x2; inline;
function VecU64x2Not(const a: TVecU64x2): TVecU64x2; inline;
function VecU64x2AndNot(const a, b: TVecU64x2): TVecU64x2; inline;

// U64x2 comparison (unsigned)
function VecU64x2CmpEq(const a, b: TVecU64x2): TMask2; inline;
function VecU64x2CmpLt(const a, b: TVecU64x2): TMask2; inline;
function VecU64x2CmpGt(const a, b: TVecU64x2): TMask2; inline;

// U64x2 min/max (unsigned)
function VecU64x2Min(const a, b: TVecU64x2): TVecU64x2; inline;
function VecU64x2Max(const a, b: TVecU64x2): TVecU64x2; inline;

// === U32x4 Operations (128-bit Unsigned Integer) ===
// 添加 U32x4 高级 API

// U32x4 arithmetic (bit-identical to I32x4, different semantics)
function VecU32x4Add(const a, b: TVecU32x4): TVecU32x4; inline;
function VecU32x4Sub(const a, b: TVecU32x4): TVecU32x4; inline;
function VecU32x4Mul(const a, b: TVecU32x4): TVecU32x4; inline;

// U32x4 bitwise operations
function VecU32x4And(const a, b: TVecU32x4): TVecU32x4; inline;
function VecU32x4Or(const a, b: TVecU32x4): TVecU32x4; inline;
function VecU32x4Xor(const a, b: TVecU32x4): TVecU32x4; inline;
function VecU32x4Not(const a: TVecU32x4): TVecU32x4; inline;
function VecU32x4AndNot(const a, b: TVecU32x4): TVecU32x4; inline;

// U32x4 shift operations
function VecU32x4ShiftLeft(const a: TVecU32x4; count: Integer): TVecU32x4; inline;
function VecU32x4ShiftRight(const a: TVecU32x4; count: Integer): TVecU32x4; inline;

// U32x4 comparison (unsigned)
function VecU32x4CmpEq(const a, b: TVecU32x4): TMask4; inline;
function VecU32x4CmpLt(const a, b: TVecU32x4): TMask4; inline;
function VecU32x4CmpGt(const a, b: TVecU32x4): TMask4; inline;
function VecU32x4CmpLe(const a, b: TVecU32x4): TMask4; inline;
function VecU32x4CmpGe(const a, b: TVecU32x4): TMask4; inline;

// U32x4 min/max (unsigned)
function VecU32x4Min(const a, b: TVecU32x4): TVecU32x4; inline;
function VecU32x4Max(const a, b: TVecU32x4): TVecU32x4; inline;

// === F32x8 Operations (256-bit Float, AVX) ===
// 添加缺失的 F32x8 高级 API

// F32x8 arithmetic
function VecF32x8Add(const a, b: TVecF32x8): TVecF32x8; inline;
function VecF32x8Sub(const a, b: TVecF32x8): TVecF32x8; inline;
function VecF32x8Mul(const a, b: TVecF32x8): TVecF32x8; inline;
function VecF32x8Div(const a, b: TVecF32x8): TVecF32x8; inline;

// F32x8 comparison
function VecF32x8CmpEq(const a, b: TVecF32x8): TMask8; inline;
function VecF32x8CmpLt(const a, b: TVecF32x8): TMask8; inline;
function VecF32x8CmpLe(const a, b: TVecF32x8): TMask8; inline;
function VecF32x8CmpGt(const a, b: TVecF32x8): TMask8; inline;
function VecF32x8CmpGe(const a, b: TVecF32x8): TMask8; inline;
function VecF32x8CmpNe(const a, b: TVecF32x8): TMask8; inline;

// F32x8 math functions
function VecF32x8Abs(const a: TVecF32x8): TVecF32x8; inline;
function VecF32x8Sqrt(const a: TVecF32x8): TVecF32x8; inline;
function VecF32x8Min(const a, b: TVecF32x8): TVecF32x8; inline;
function VecF32x8Max(const a, b: TVecF32x8): TVecF32x8; inline;

// F32x8 reduction
function VecF32x8ReduceAdd(const a: TVecF32x8): Single; inline;
function VecF32x8ReduceMin(const a: TVecF32x8): Single; inline;
function VecF32x8ReduceMax(const a: TVecF32x8): Single; inline;
function VecF32x8ReduceMul(const a: TVecF32x8): Single; inline;

// === I32x8 Operations (256-bit Integer, AVX2) ===
// 添加缺失的 I32x8 高级 API

// I32x8 arithmetic
function VecI32x8Add(const a, b: TVecI32x8): TVecI32x8; inline;
function VecI32x8Sub(const a, b: TVecI32x8): TVecI32x8; inline;
function VecI32x8Mul(const a, b: TVecI32x8): TVecI32x8; inline;

// I32x8 bitwise operations
function VecI32x8And(const a, b: TVecI32x8): TVecI32x8; inline;
function VecI32x8Or(const a, b: TVecI32x8): TVecI32x8; inline;
function VecI32x8Xor(const a, b: TVecI32x8): TVecI32x8; inline;
function VecI32x8Not(const a: TVecI32x8): TVecI32x8; inline;
function VecI32x8AndNot(const a, b: TVecI32x8): TVecI32x8; inline;

// I32x8 shift operations
function VecI32x8ShiftLeft(const a: TVecI32x8; count: Integer): TVecI32x8; inline;
function VecI32x8ShiftRight(const a: TVecI32x8; count: Integer): TVecI32x8; inline;
function VecI32x8ShiftRightArith(const a: TVecI32x8; count: Integer): TVecI32x8; inline;

// I32x8 comparison
function VecI32x8CmpEq(const a, b: TVecI32x8): TMask8; inline;
function VecI32x8CmpLt(const a, b: TVecI32x8): TMask8; inline;
function VecI32x8CmpGt(const a, b: TVecI32x8): TMask8; inline;
function VecI32x8CmpLe(const a, b: TVecI32x8): TMask8; inline;  // 添加缺失 API
function VecI32x8CmpGe(const a, b: TVecI32x8): TMask8; inline;  // 添加缺失 API
function VecI32x8CmpNe(const a, b: TVecI32x8): TMask8; inline;  // 添加缺失 API

// I32x8 min/max
function VecI32x8Min(const a, b: TVecI32x8): TVecI32x8; inline;
function VecI32x8Max(const a, b: TVecI32x8): TVecI32x8; inline;

// === U32x8 Operations (256-bit Unsigned Integer, AVX2) ===
// 添加 U32x8 高级 API

// U32x8 arithmetic
function VecU32x8Add(const a, b: TVecU32x8): TVecU32x8; inline;
function VecU32x8Sub(const a, b: TVecU32x8): TVecU32x8; inline;
function VecU32x8Mul(const a, b: TVecU32x8): TVecU32x8; inline;

// U32x8 bitwise operations
function VecU32x8And(const a, b: TVecU32x8): TVecU32x8; inline;
function VecU32x8Or(const a, b: TVecU32x8): TVecU32x8; inline;
function VecU32x8Xor(const a, b: TVecU32x8): TVecU32x8; inline;
function VecU32x8Not(const a: TVecU32x8): TVecU32x8; inline;
function VecU32x8AndNot(const a, b: TVecU32x8): TVecU32x8; inline;

// U32x8 shift operations
function VecU32x8ShiftLeft(const a: TVecU32x8; count: Integer): TVecU32x8; inline;
function VecU32x8ShiftRight(const a: TVecU32x8; count: Integer): TVecU32x8; inline;

// U32x8 comparison (unsigned)
function VecU32x8CmpEq(const a, b: TVecU32x8): TMask8; inline;
function VecU32x8CmpLt(const a, b: TVecU32x8): TMask8; inline;
function VecU32x8CmpGt(const a, b: TVecU32x8): TMask8; inline;
function VecU32x8CmpLe(const a, b: TVecU32x8): TMask8; inline;
function VecU32x8CmpGe(const a, b: TVecU32x8): TMask8; inline;
function VecU32x8CmpNe(const a, b: TVecU32x8): TMask8; inline;

// U32x8 min/max (unsigned)
function VecU32x8Min(const a, b: TVecU32x8): TVecU32x8; inline;
function VecU32x8Max(const a, b: TVecU32x8): TVecU32x8; inline;

// === I64x4 Operations (256-bit, 64-bit signed integers) ===
// 添加 I64x4 高级 API (AVX2)

// I64x4 arithmetic
function VecI64x4Add(const a, b: TVecI64x4): TVecI64x4; inline;
function VecI64x4Sub(const a, b: TVecI64x4): TVecI64x4; inline;

// I64x4 bitwise operations
function VecI64x4And(const a, b: TVecI64x4): TVecI64x4; inline;
function VecI64x4Or(const a, b: TVecI64x4): TVecI64x4; inline;
function VecI64x4Xor(const a, b: TVecI64x4): TVecI64x4; inline;
function VecI64x4Not(const a: TVecI64x4): TVecI64x4; inline;
function VecI64x4AndNot(const a, b: TVecI64x4): TVecI64x4; inline;

// I64x4 shift operations (logical)
function VecI64x4ShiftLeft(const a: TVecI64x4; count: Integer): TVecI64x4; inline;
function VecI64x4ShiftRight(const a: TVecI64x4; count: Integer): TVecI64x4; inline;
function VecI64x4ShiftRightArith(const a: TVecI64x4; count: Integer): TVecI64x4; inline;

// I64x4 comparison
function VecI64x4CmpEq(const a, b: TVecI64x4): TMask4; inline;
function VecI64x4CmpLt(const a, b: TVecI64x4): TMask4; inline;
function VecI64x4CmpGt(const a, b: TVecI64x4): TMask4; inline;
function VecI64x4CmpLe(const a, b: TVecI64x4): TMask4; inline;
function VecI64x4CmpGe(const a, b: TVecI64x4): TMask4; inline;
function VecI64x4CmpNe(const a, b: TVecI64x4): TMask4; inline;

// I64x4 utility operations
function VecI64x4Load(p: PInt64): TVecI64x4; inline;
procedure VecI64x4Store(p: PInt64; const a: TVecI64x4); inline;
function VecI64x4Splat(value: Int64): TVecI64x4; inline;
function VecI64x4Zero: TVecI64x4; inline;

// === U64x4 Operations (256-bit, 64-bit unsigned integers) ===
// 添加 U64x4 高级 API (AVX2)

// U64x4 arithmetic
function VecU64x4Add(const a, b: TVecU64x4): TVecU64x4; inline;
function VecU64x4Sub(const a, b: TVecU64x4): TVecU64x4; inline;

// U64x4 bitwise operations
function VecU64x4And(const a, b: TVecU64x4): TVecU64x4; inline;
function VecU64x4Or(const a, b: TVecU64x4): TVecU64x4; inline;
function VecU64x4Xor(const a, b: TVecU64x4): TVecU64x4; inline;
function VecU64x4Not(const a: TVecU64x4): TVecU64x4; inline;

// U64x4 shift operations (logical)
function VecU64x4ShiftLeft(const a: TVecU64x4; count: Integer): TVecU64x4; inline;
function VecU64x4ShiftRight(const a: TVecU64x4; count: Integer): TVecU64x4; inline;

// U64x4 comparison (unsigned)
function VecU64x4CmpEq(const a, b: TVecU64x4): TMask4; inline;
function VecU64x4CmpLt(const a, b: TVecU64x4): TMask4; inline;
function VecU64x4CmpGt(const a, b: TVecU64x4): TMask4; inline;
function VecU64x4CmpLe(const a, b: TVecU64x4): TMask4; inline;
function VecU64x4CmpGe(const a, b: TVecU64x4): TMask4; inline;
function VecU64x4CmpNe(const a, b: TVecU64x4): TMask4; inline;

// U64x4 utility operations
function VecU64x4Splat(value: UInt64): TVecU64x4; inline;
function VecU64x4Zero: TVecU64x4; inline;

// === I16x8 Operations (128-bit, 16-bit signed integers) ===
// 添加 I16x8 高级 API

// I16x8 arithmetic
function VecI16x8Add(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8Sub(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8Mul(const a, b: TVecI16x8): TVecI16x8; inline;

// I16x8 bitwise operations
function VecI16x8And(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8Or(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8Xor(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8Not(const a: TVecI16x8): TVecI16x8; inline;
function VecI16x8AndNot(const a, b: TVecI16x8): TVecI16x8; inline;

// I16x8 shift operations
function VecI16x8ShiftLeft(const a: TVecI16x8; count: Integer): TVecI16x8; inline;
function VecI16x8ShiftRight(const a: TVecI16x8; count: Integer): TVecI16x8; inline;
function VecI16x8ShiftRightArith(const a: TVecI16x8; count: Integer): TVecI16x8; inline;

// I16x8 comparison
function VecI16x8CmpEq(const a, b: TVecI16x8): TMask8; inline;
function VecI16x8CmpLt(const a, b: TVecI16x8): TMask8; inline;
function VecI16x8CmpGt(const a, b: TVecI16x8): TMask8; inline;

// I16x8 min/max
function VecI16x8Min(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8Max(const a, b: TVecI16x8): TVecI16x8; inline;

// === I8x16 Operations (128-bit, 8-bit signed integers) ===
// 添加 I8x16 高级 API

// I8x16 arithmetic
function VecI8x16Add(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI8x16Sub(const a, b: TVecI8x16): TVecI8x16; inline;

// I8x16 bitwise operations
function VecI8x16And(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI8x16Or(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI8x16Xor(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI8x16Not(const a: TVecI8x16): TVecI8x16; inline;
function VecI8x16AndNot(const a, b: TVecI8x16): TVecI8x16; inline;

// I8x16 comparison
function VecI8x16CmpEq(const a, b: TVecI8x16): TMask16; inline;
function VecI8x16CmpLt(const a, b: TVecI8x16): TMask16; inline;
function VecI8x16CmpGt(const a, b: TVecI8x16): TMask16; inline;

// I8x16 min/max
function VecI8x16Min(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI8x16Max(const a, b: TVecI8x16): TVecI8x16; inline;

// === U8x16 Operations (128-bit, 8-bit unsigned integers) ===
// 添加 U8x16 高级 API

// U8x16 arithmetic
function VecU8x16Add(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU8x16Sub(const a, b: TVecU8x16): TVecU8x16; inline;

// U8x16 bitwise operations
function VecU8x16And(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU8x16Or(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU8x16Xor(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU8x16Not(const a: TVecU8x16): TVecU8x16; inline;
function VecU8x16AndNot(const a, b: TVecU8x16): TVecU8x16; inline;

// U8x16 comparison (unsigned)
function VecU8x16CmpEq(const a, b: TVecU8x16): TMask16; inline;
function VecU8x16CmpLt(const a, b: TVecU8x16): TMask16; inline;
function VecU8x16CmpGt(const a, b: TVecU8x16): TMask16; inline;

// U8x16 min/max (unsigned)
function VecU8x16Min(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU8x16Max(const a, b: TVecU8x16): TVecU8x16; inline;

// === U16x8 Operations (128-bit, 16-bit unsigned integers) ===
// 添加 U16x8 高级 API

// U16x8 arithmetic
function VecU16x8Add(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8Sub(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8Mul(const a, b: TVecU16x8): TVecU16x8; inline;

// U16x8 bitwise operations
function VecU16x8And(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8Or(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8Xor(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8Not(const a: TVecU16x8): TVecU16x8; inline;
function VecU16x8AndNot(const a, b: TVecU16x8): TVecU16x8; inline;

// U16x8 shift operations
function VecU16x8ShiftLeft(const a: TVecU16x8; count: Integer): TVecU16x8; inline;
function VecU16x8ShiftRight(const a: TVecU16x8; count: Integer): TVecU16x8; inline;

// U16x8 comparison (unsigned)
function VecU16x8CmpEq(const a, b: TVecU16x8): TMask8; inline;
function VecU16x8CmpLt(const a, b: TVecU16x8): TMask8; inline;
function VecU16x8CmpGt(const a, b: TVecU16x8): TMask8; inline;

// U16x8 min/max (unsigned)
function VecU16x8Min(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8Max(const a, b: TVecU16x8): TVecU16x8; inline;

// === F64x4 Operations (256-bit Double, AVX) ===
// 添加 F64x4 高级 API

// F64x4 arithmetic
function VecF64x4Add(const a, b: TVecF64x4): TVecF64x4; inline;
function VecF64x4Sub(const a, b: TVecF64x4): TVecF64x4; inline;
function VecF64x4Mul(const a, b: TVecF64x4): TVecF64x4; inline;
function VecF64x4Div(const a, b: TVecF64x4): TVecF64x4; inline;
function VecF64x4Rcp(const a: TVecF64x4): TVecF64x4; inline;

// F64x4 comparison
function VecF64x4CmpEq(const a, b: TVecF64x4): TMask4; inline;
function VecF64x4CmpLt(const a, b: TVecF64x4): TMask4; inline;
function VecF64x4CmpLe(const a, b: TVecF64x4): TMask4; inline;
function VecF64x4CmpGt(const a, b: TVecF64x4): TMask4; inline;
function VecF64x4CmpGe(const a, b: TVecF64x4): TMask4; inline;
function VecF64x4CmpNe(const a, b: TVecF64x4): TMask4; inline;

// F64x4 math functions
function VecF64x4Abs(const a: TVecF64x4): TVecF64x4; inline;
function VecF64x4Sqrt(const a: TVecF64x4): TVecF64x4; inline;
function VecF64x4Min(const a, b: TVecF64x4): TVecF64x4; inline;
function VecF64x4Max(const a, b: TVecF64x4): TVecF64x4; inline;

// F64x4 reduction
function VecF64x4ReduceAdd(const a: TVecF64x4): Double; inline;
function VecF64x4ReduceMin(const a: TVecF64x4): Double; inline;
function VecF64x4ReduceMax(const a: TVecF64x4): Double; inline;
function VecF64x4ReduceMul(const a: TVecF64x4): Double; inline;

// === F64x8 Operations (512-bit Double, AVX-512) ===
// 添加 F64x8 高级 API

// F64x8 arithmetic
function VecF64x8Add(const a, b: TVecF64x8): TVecF64x8; inline;
function VecF64x8Sub(const a, b: TVecF64x8): TVecF64x8; inline;
function VecF64x8Mul(const a, b: TVecF64x8): TVecF64x8; inline;
function VecF64x8Div(const a, b: TVecF64x8): TVecF64x8; inline;

// F64x8 comparison
function VecF64x8CmpEq(const a, b: TVecF64x8): TMask8; inline;
function VecF64x8CmpLt(const a, b: TVecF64x8): TMask8; inline;
function VecF64x8CmpLe(const a, b: TVecF64x8): TMask8; inline;
function VecF64x8CmpGt(const a, b: TVecF64x8): TMask8; inline;
function VecF64x8CmpGe(const a, b: TVecF64x8): TMask8; inline;
function VecF64x8CmpNe(const a, b: TVecF64x8): TMask8; inline;

// F64x8 math functions
function VecF64x8Abs(const a: TVecF64x8): TVecF64x8; inline;
function VecF64x8Sqrt(const a: TVecF64x8): TVecF64x8; inline;
function VecF64x8Min(const a, b: TVecF64x8): TVecF64x8; inline;
function VecF64x8Max(const a, b: TVecF64x8): TVecF64x8; inline;
function VecF64x8Clamp(const a, minVal, maxVal: TVecF64x8): TVecF64x8; inline;

// F64x8 extended math
function VecF64x8Fma(const a, b, c: TVecF64x8): TVecF64x8; inline;
function VecF64x8Floor(const a: TVecF64x8): TVecF64x8; inline;
function VecF64x8Ceil(const a: TVecF64x8): TVecF64x8; inline;
function VecF64x8Round(const a: TVecF64x8): TVecF64x8; inline;
function VecF64x8Trunc(const a: TVecF64x8): TVecF64x8; inline;

// F64x8 reduction
function VecF64x8ReduceAdd(const a: TVecF64x8): Double; inline;
function VecF64x8ReduceMin(const a: TVecF64x8): Double; inline;
function VecF64x8ReduceMax(const a: TVecF64x8): Double; inline;
function VecF64x8ReduceMul(const a: TVecF64x8): Double; inline;

// F64x8 memory/util
function VecF64x8Load(p: PDouble): TVecF64x8; inline;
procedure VecF64x8Store(p: PDouble; const a: TVecF64x8); inline;
function VecF64x8Splat(value: Double): TVecF64x8; inline;
function VecF64x8Zero: TVecF64x8; inline;
function VecF64x8Select(const mask: TMask8; const a, b: TVecF64x8): TVecF64x8; inline;

// === F32x16 Operations (512-bit Float, AVX-512) ===
// 添加 F32x16 高级 API

// F32x16 arithmetic
function VecF32x16Add(const a, b: TVecF32x16): TVecF32x16; inline;
function VecF32x16Sub(const a, b: TVecF32x16): TVecF32x16; inline;
function VecF32x16Mul(const a, b: TVecF32x16): TVecF32x16; inline;
function VecF32x16Div(const a, b: TVecF32x16): TVecF32x16; inline;

// F32x16 comparison
function VecF32x16CmpEq_Mask(const a, b: TVecF32x16): TMask16; inline;
function VecF32x16CmpLt_Mask(const a, b: TVecF32x16): TMask16; inline;
function VecF32x16CmpLe_Mask(const a, b: TVecF32x16): TMask16; inline;
function VecF32x16CmpGt_Mask(const a, b: TVecF32x16): TMask16; inline;
function VecF32x16CmpGe_Mask(const a, b: TVecF32x16): TMask16; inline;
function VecF32x16CmpNe_Mask(const a, b: TVecF32x16): TMask16; inline;

// F32x16 math functions
function VecF32x16Abs(const a: TVecF32x16): TVecF32x16; inline;
function VecF32x16Sqrt(const a: TVecF32x16): TVecF32x16; inline;
function VecF32x16Min(const a, b: TVecF32x16): TVecF32x16; inline;
function VecF32x16Max(const a, b: TVecF32x16): TVecF32x16; inline;
function VecF32x16Clamp(const a, minVal, maxVal: TVecF32x16): TVecF32x16; inline;

// F32x16 extended math
function VecF32x16Fma(const a, b, c: TVecF32x16): TVecF32x16; inline;
function VecF32x16Floor(const a: TVecF32x16): TVecF32x16; inline;
function VecF32x16Ceil(const a: TVecF32x16): TVecF32x16; inline;
function VecF32x16Round(const a: TVecF32x16): TVecF32x16; inline;
function VecF32x16Trunc(const a: TVecF32x16): TVecF32x16; inline;

// F32x16 reduction
function VecF32x16ReduceAdd(const a: TVecF32x16): Single; inline;
function VecF32x16ReduceMin(const a: TVecF32x16): Single; inline;
function VecF32x16ReduceMax(const a: TVecF32x16): Single; inline;
function VecF32x16ReduceMul(const a: TVecF32x16): Single; inline;

// F32x16 memory/util
function VecF32x16Load(p: PSingle): TVecF32x16; inline;
procedure VecF32x16Store(p: PSingle; const a: TVecF32x16); inline;
function VecF32x16Splat(value: Single): TVecF32x16; inline;
function VecF32x16Zero: TVecF32x16; inline;
function VecF32x16Select(const mask: TMask16; const a, b: TVecF32x16): TVecF32x16; inline;

// === I32x16 Operations (512-bit Integer, AVX-512) ===
// 添加 I32x16 高级 API

// I32x16 arithmetic
function VecI32x16Add(const a, b: TVecI32x16): TVecI32x16; inline;
function VecI32x16Sub(const a, b: TVecI32x16): TVecI32x16; inline;
function VecI32x16Mul(const a, b: TVecI32x16): TVecI32x16; inline;

// I32x16 bitwise operations
function VecI32x16And(const a, b: TVecI32x16): TVecI32x16; inline;
function VecI32x16Or(const a, b: TVecI32x16): TVecI32x16; inline;
function VecI32x16Xor(const a, b: TVecI32x16): TVecI32x16; inline;
function VecI32x16Not(const a: TVecI32x16): TVecI32x16; inline;
function VecI32x16AndNot(const a, b: TVecI32x16): TVecI32x16; inline;

// I32x16 shift operations
function VecI32x16ShiftLeft(const a: TVecI32x16; count: Integer): TVecI32x16; inline;
function VecI32x16ShiftRight(const a: TVecI32x16; count: Integer): TVecI32x16; inline;
function VecI32x16ShiftRightArith(const a: TVecI32x16; count: Integer): TVecI32x16; inline;

// I32x16 comparison
function VecI32x16CmpEq(const a, b: TVecI32x16): TMask16; inline;
function VecI32x16CmpLt(const a, b: TVecI32x16): TMask16; inline;
function VecI32x16CmpGt(const a, b: TVecI32x16): TMask16; inline;
function VecI32x16CmpLe(const a, b: TVecI32x16): TMask16; inline;  // 添加缺失 API
function VecI32x16CmpGe(const a, b: TVecI32x16): TMask16; inline;  // 添加缺失 API
function VecI32x16CmpNe(const a, b: TVecI32x16): TMask16; inline;  // 添加缺失 API

// I32x16 min/max
function VecI32x16Min(const a, b: TVecI32x16): TVecI32x16; inline;
function VecI32x16Max(const a, b: TVecI32x16): TVecI32x16; inline;

// === I64x8 Operations (512-bit Integer, AVX-512) ===
// I64x8 arithmetic
function VecI64x8Add(const a, b: TVecI64x8): TVecI64x8; inline;
function VecI64x8Sub(const a, b: TVecI64x8): TVecI64x8; inline;

// I64x8 bitwise operations
function VecI64x8And(const a, b: TVecI64x8): TVecI64x8; inline;
function VecI64x8Or(const a, b: TVecI64x8): TVecI64x8; inline;
function VecI64x8Xor(const a, b: TVecI64x8): TVecI64x8; inline;
function VecI64x8Not(const a: TVecI64x8): TVecI64x8; inline;

// I64x8 comparison
function VecI64x8CmpEq(const a, b: TVecI64x8): TMask8; inline;
function VecI64x8CmpLt(const a, b: TVecI64x8): TMask8; inline;
function VecI64x8CmpGt(const a, b: TVecI64x8): TMask8; inline;
function VecI64x8CmpLe(const a, b: TVecI64x8): TMask8; inline;
function VecI64x8CmpGe(const a, b: TVecI64x8): TMask8; inline;
function VecI64x8CmpNe(const a, b: TVecI64x8): TMask8; inline;

// === 512-bit Integer Wide Operations ===
// U32x16
function VecU32x16Add(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16Sub(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16Mul(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16And(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16Or(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16Xor(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16Not(const a: TVecU32x16): TVecU32x16; inline;
function VecU32x16AndNot(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16ShiftLeft(const a: TVecU32x16; count: Integer): TVecU32x16; inline;
function VecU32x16ShiftRight(const a: TVecU32x16; count: Integer): TVecU32x16; inline;
function VecU32x16CmpEq(const a, b: TVecU32x16): TMask16; inline;
function VecU32x16CmpLt(const a, b: TVecU32x16): TMask16; inline;
function VecU32x16CmpGt(const a, b: TVecU32x16): TMask16; inline;
function VecU32x16CmpLe(const a, b: TVecU32x16): TMask16; inline;
function VecU32x16CmpGe(const a, b: TVecU32x16): TMask16; inline;
function VecU32x16CmpNe(const a, b: TVecU32x16): TMask16; inline;
function VecU32x16Min(const a, b: TVecU32x16): TVecU32x16; inline;
function VecU32x16Max(const a, b: TVecU32x16): TVecU32x16; inline;

// U64x8
function VecU64x8Add(const a, b: TVecU64x8): TVecU64x8; inline;
function VecU64x8Sub(const a, b: TVecU64x8): TVecU64x8; inline;
function VecU64x8And(const a, b: TVecU64x8): TVecU64x8; inline;
function VecU64x8Or(const a, b: TVecU64x8): TVecU64x8; inline;
function VecU64x8Xor(const a, b: TVecU64x8): TVecU64x8; inline;
function VecU64x8Not(const a: TVecU64x8): TVecU64x8; inline;
function VecU64x8ShiftLeft(const a: TVecU64x8; count: Integer): TVecU64x8; inline;
function VecU64x8ShiftRight(const a: TVecU64x8; count: Integer): TVecU64x8; inline;
function VecU64x8CmpEq(const a, b: TVecU64x8): TMask8; inline;
function VecU64x8CmpLt(const a, b: TVecU64x8): TMask8; inline;
function VecU64x8CmpGt(const a, b: TVecU64x8): TMask8; inline;
function VecU64x8CmpLe(const a, b: TVecU64x8): TMask8; inline;
function VecU64x8CmpGe(const a, b: TVecU64x8): TMask8; inline;
function VecU64x8CmpNe(const a, b: TVecU64x8): TMask8; inline;

// I16x32
function VecI16x32Add(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32Sub(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32And(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32Or(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32Xor(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32Not(const a: TVecI16x32): TVecI16x32; inline;
function VecI16x32AndNot(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32ShiftLeft(const a: TVecI16x32; count: Integer): TVecI16x32; inline;
function VecI16x32ShiftRight(const a: TVecI16x32; count: Integer): TVecI16x32; inline;
function VecI16x32ShiftRightArith(const a: TVecI16x32; count: Integer): TVecI16x32; inline;
function VecI16x32CmpEq(const a, b: TVecI16x32): TMask32; inline;
function VecI16x32CmpLt(const a, b: TVecI16x32): TMask32; inline;
function VecI16x32CmpGt(const a, b: TVecI16x32): TMask32; inline;
function VecI16x32Min(const a, b: TVecI16x32): TVecI16x32; inline;
function VecI16x32Max(const a, b: TVecI16x32): TVecI16x32; inline;

// I8x64
function VecI8x64Add(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64Sub(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64And(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64Or(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64Xor(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64Not(const a: TVecI8x64): TVecI8x64; inline;
function VecI8x64AndNot(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64CmpEq(const a, b: TVecI8x64): TMask64; inline;
function VecI8x64CmpLt(const a, b: TVecI8x64): TMask64; inline;
function VecI8x64CmpGt(const a, b: TVecI8x64): TMask64; inline;
function VecI8x64Min(const a, b: TVecI8x64): TVecI8x64; inline;
function VecI8x64Max(const a, b: TVecI8x64): TVecI8x64; inline;

// U8x64
function VecU8x64Add(const a, b: TVecU8x64): TVecU8x64; inline;
function VecU8x64Sub(const a, b: TVecU8x64): TVecU8x64; inline;
function VecU8x64And(const a, b: TVecU8x64): TVecU8x64; inline;
function VecU8x64Or(const a, b: TVecU8x64): TVecU8x64; inline;
function VecU8x64Xor(const a, b: TVecU8x64): TVecU8x64; inline;
function VecU8x64Not(const a: TVecU8x64): TVecU8x64; inline;
function VecU8x64CmpEq(const a, b: TVecU8x64): TMask64; inline;
function VecU8x64CmpLt(const a, b: TVecU8x64): TMask64; inline;
function VecU8x64CmpGt(const a, b: TVecU8x64): TMask64; inline;
function VecU8x64Min(const a, b: TVecU8x64): TVecU8x64; inline;
function VecU8x64Max(const a, b: TVecU8x64): TVecU8x64; inline;

// === ArrayF32 Batch Helpers ===
procedure ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
procedure ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single); inline;
procedure ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single); inline;
procedure ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt); inline;
function ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single; inline;
function ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single; inline;
function ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single; inline;
function ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single; inline;

// === ArrayF64 Batch Helpers ===
procedure ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt); inline;
procedure ArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
procedure ArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double); inline;
procedure ArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double); inline;
procedure ArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double); inline;
function ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double; inline;
function ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double; inline;
function ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double; inline;
function ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double; inline;

// === Transcendental F32 Batch Helpers ===
procedure ArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single); inline;
procedure ArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;

// === Fused Batch Helpers (single-pass, reduced memory traffic) ===
procedure ArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;
procedure ArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt); inline;
procedure ArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single); inline;
procedure ArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single); inline;

// === Integer Batch Helpers ===
procedure ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
procedure ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
procedure ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt); inline;
procedure ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt); inline;

// === Type Conversion Batch Helpers ===
procedure ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt); inline;
procedure ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt); inline;

// === Bitwise Batch Helpers ===
procedure ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
procedure ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
procedure ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt); inline;
procedure ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer); inline;
procedure ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer); inline;

// === Saturating Arithmetic (音视频处理必需) ===
// 有符号饱和: I8 范围 [-128, 127], I16 范围 [-32768, 32767]
function VecI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI8x16SatSub(const a, b: TVecI8x16): TVecI8x16; inline;
function VecI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8; inline;
function VecI16x8SatSub(const a, b: TVecI16x8): TVecI16x8; inline;
// 无符号饱和: U8 范围 [0, 255], U16 范围 [0, 65535]
function VecU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU8x16SatSub(const a, b: TVecU8x16): TVecU8x16; inline;
function VecU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8; inline;
function VecU16x8SatSub(const a, b: TVecU16x8): TVecU16x8; inline;

// === Framework Information ===

// Get current backend information
{$I nextpas.core.simd.framework.intf.inc}
{$I nextpas.core.simd.public_abi.intf.inc}

// === Shuffle/Permute Operations (re-exported from simd.utils) ===

{**
  Shuffle elements within a single F32x4 vector.
  @param(a Source vector)
  @param(imm8 Shuffle control: bits [1:0]=idx0, [3:2]=idx1, [5:4]=idx2, [7:6]=idx3)
  @returns(result[i] = a[idx_i])
  @example MM_SHUFFLE(3,2,1,0) = identity, MM_SHUFFLE(0,0,0,0) = broadcast element 0
*}
function VecF32x4Shuffle(const a: TVecF32x4; imm8: Byte): TVecF32x4; inline;

{** Shuffle I32x4 elements. Same semantics as VecF32x4Shuffle. *}
function VecI32x4Shuffle(const a: TVecI32x4; imm8: Byte): TVecI32x4; inline;

{**
  Shuffle elements from two F32x4 vectors.
  @param(a First source vector)
  @param(b Second source vector)
  @param(imm8 Shuffle control: low 2 elements from a[idx], high 2 elements from b[idx])
  @returns(result[0..1] from a, result[2..3] from b)
*}
function VecF32x4Shuffle2(const a, b: TVecF32x4; imm8: Byte): TVecF32x4; inline;

// === Blend Operations (re-exported from simd.utils) ===

{**
  Blend two F32x4 vectors based on mask.
  @param(a First source vector)
  @param(b Second source vector)
  @param(mask Blend mask: bit i = 0 selects a[i], bit i = 1 selects b[i])
  @returns(result[i] = (mask & (1<<i)) ? b[i] : a[i])
*}
function VecF32x4Blend(const a, b: TVecF32x4; mask: Byte): TVecF32x4; inline;

{** Blend two F64x2 vectors. Bits 0-1 control elements 0-1. *}
function VecF64x2Blend(const a, b: TVecF64x2; mask: Byte): TVecF64x2; inline;

{** Blend two I32x4 vectors. Same semantics as VecF32x4Blend. *}
function VecI32x4Blend(const a, b: TVecI32x4; mask: Byte): TVecI32x4; inline;

// === Type Conversion Operations (re-exported from simd.utils) ===

{**
  Reinterpret F32x4 bits as I32x4 (no conversion, just bit reinterpret).
  @param(a Source vector)
  @returns(Bit-identical reinterpretation as I32x4)
*}
function VecF32x4IntoBits(const a: TVecF32x4): TVecI32x4; inline;

{**
  Reinterpret I32x4 bits as F32x4 (no conversion, just bit reinterpret).
  @param(a Source vector)
  @returns(Bit-identical reinterpretation as F32x4)
*}
function VecI32x4FromBitsF32(const a: TVecI32x4): TVecF32x4; inline;

{**
  Convert I32x4 to F32x4 (integer to float, value conversion).
  @param(a Source integer vector)
  @returns(result[i] = (float)a[i])
*}
function VecI32x4CastToF32x4(const a: TVecI32x4): TVecF32x4; inline;

{**
  Convert F32x4 to I32x4 (float to integer, truncate toward zero).
  @param(a Source float vector)
  @returns(result[i] = (int)trunc(a[i]))
*}
function VecF32x4CastToI32x4(const a: TVecF32x4): TVecI32x4; inline;

// Facade functions (dispatch-based bulk operations)
function MemEqual(a, b: Pointer; len: SizeUInt): LongBool; inline;
function MemFindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; inline;
function MemDiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; inline;
procedure MemCopy(src, dst: Pointer; len: SizeUInt); inline;
procedure MemSet(dst: Pointer; len: SizeUInt; value: Byte); inline;
procedure MemReverse(p: Pointer; len: SizeUInt); inline;
function SumBytes(p: Pointer; len: SizeUInt): UInt64; inline;
procedure MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); inline;
function CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; inline;
function Utf8Validate(p: Pointer; len: SizeUInt): Boolean; inline;
function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; inline;
procedure ToLowerAscii(p: Pointer; len: SizeUInt); inline;
procedure ToUpperAscii(p: Pointer; len: SizeUInt); inline;
function BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; inline;
function BitsetPopCount(p: Pointer; len: SizeUInt): SizeUInt; inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.simd.dataplane,
  nextpas.core.simd.memutils;

type
  TVecF32x4AddFunc = function(const a, b: TVecF32x4): TVecF32x4;
  TVecI16x32AddFunc = function(const a, b: TVecI16x32): TVecI16x32;
  TVecU32x16MulFunc = function(const a, b: TVecU32x16): TVecU32x16;
  TVecU64x8AddFunc = function(const a, b: TVecU64x8): TVecU64x8;
  TVecU8x64MaxFunc = function(const a, b: TVecU8x64): TVecU8x64;

var
  g_FastSimdDispatchPtr: Pointer = nil;
  g_FastVecF32x4AddPtr: Pointer = nil;
  g_FastVecI16x32AddPtr: Pointer = nil;
  g_FastVecU32x16MulPtr: Pointer = nil;
  g_FastVecU64x8AddPtr: Pointer = nil;
  g_FastVecU8x64MaxPtr: Pointer = nil;

procedure RebindSimdFacadeFastPaths;
var
  LDataPlane: PSimdDataPlane;
begin
  LDataPlane := GetCurrentSimdDataPlane;
  if LDataPlane = nil then
    Exit;

  atomic_store(g_FastSimdDispatchPtr, Pointer(LDataPlane^.Dispatch), mo_release);
  atomic_store(g_FastVecF32x4AddPtr, LDataPlane^.VecF32x4AddPtr, mo_release);
  atomic_store(g_FastVecI16x32AddPtr, LDataPlane^.VecI16x32AddPtr, mo_release);
  atomic_store(g_FastVecU32x16MulPtr, LDataPlane^.VecU32x16MulPtr, mo_release);
  atomic_store(g_FastVecU64x8AddPtr, LDataPlane^.VecU64x8AddPtr, mo_release);
  atomic_store(g_FastVecU8x64MaxPtr, LDataPlane^.VecU8x64MaxPtr, mo_release);
end;

procedure InvalidateSimdFacadeFastPaths;
begin
  atomic_store(g_FastSimdDispatchPtr, nil, mo_release);
  atomic_store(g_FastVecF32x4AddPtr, nil, mo_release);
  atomic_store(g_FastVecI16x32AddPtr, nil, mo_release);
  atomic_store(g_FastVecU32x16MulPtr, nil, mo_release);
  atomic_store(g_FastVecU64x8AddPtr, nil, mo_release);
  atomic_store(g_FastVecU8x64MaxPtr, nil, mo_release);
end;

function LoadSimdFacadeFastPath(var aFastPathPtr: Pointer): Pointer; inline;
begin
  // Use the platform default load order on the hot path:
  // x86/x86_64 stays relaxed (no compiler-barrier call), while weakly ordered
  // targets still get acquire semantics through nextpas.core.atomic defaults.
  Result := atomic_load(aFastPathPtr);
end;

function GetSimdFacadeDispatchFastPath: PSimdDispatchTable; inline;
var
  LDataPlane: PSimdDataPlane;
begin
  Result := PSimdDispatchTable(LoadSimdFacadeFastPath(g_FastSimdDispatchPtr));
  if Result <> nil then
    Exit;

  RebindSimdFacadeFastPaths;
  Result := PSimdDispatchTable(LoadSimdFacadeFastPath(g_FastSimdDispatchPtr));
  if Result <> nil then
    Exit;

  LDataPlane := GetCurrentSimdDataPlane;
  if LDataPlane <> nil then
  begin
    Result := LDataPlane^.Dispatch;
    atomic_store(g_FastSimdDispatchPtr, Pointer(Result), mo_release);
  end;
end;

{$I nextpas.core.simd.impl.core.inc}
{$I nextpas.core.simd.impl.wide.inc}

// Facade function implementations (dispatch-based)
function GetFacadeDispatch: PSimdDispatchTable; inline;
begin
  Result := GetSimdFacadeDispatchFastPath;
end;

function MemEqual(a, b: Pointer; len: SizeUInt): LongBool; inline;
begin Result := GetFacadeDispatch^.MemEqual(a, b, len); end;
function MemFindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; inline;
begin Result := GetFacadeDispatch^.MemFindByte(p, len, value); end;
function MemDiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean; inline;
begin Result := GetFacadeDispatch^.MemDiffRange(a, b, len, firstDiff, lastDiff); end;
procedure MemCopy(src, dst: Pointer; len: SizeUInt); inline;
begin GetFacadeDispatch^.MemCopy(src, dst, len); end;
procedure MemSet(dst: Pointer; len: SizeUInt; value: Byte); inline;
begin GetFacadeDispatch^.MemSet(dst, len, value); end;
procedure MemReverse(p: Pointer; len: SizeUInt); inline;
begin GetFacadeDispatch^.MemReverse(p, len); end;
function SumBytes(p: Pointer; len: SizeUInt): UInt64; inline;
begin Result := GetFacadeDispatch^.SumBytes(p, len); end;
procedure MinMaxBytes(p: Pointer; len: SizeUInt; out minVal, maxVal: Byte); inline;
begin GetFacadeDispatch^.MinMaxBytes(p, len, minVal, maxVal); end;
function CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt; inline;
begin Result := GetFacadeDispatch^.CountByte(p, len, value); end;
function Utf8Validate(p: Pointer; len: SizeUInt): Boolean; inline;
begin Result := GetFacadeDispatch^.Utf8Validate(p, len); end;
function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; inline;
begin Result := GetFacadeDispatch^.AsciiIEqual(a, b, len); end;
procedure ToLowerAscii(p: Pointer; len: SizeUInt); inline;
begin GetFacadeDispatch^.ToLowerAscii(p, len); end;
procedure ToUpperAscii(p: Pointer; len: SizeUInt); inline;
begin GetFacadeDispatch^.ToUpperAscii(p, len); end;
function BytesIndexOf(haystack: Pointer; haystackLen: SizeUInt; needle: Pointer; needleLen: SizeUInt): PtrInt; inline;
begin Result := GetFacadeDispatch^.BytesIndexOf(haystack, haystackLen, needle, needleLen); end;
function BitsetPopCount(p: Pointer; len: SizeUInt): SizeUInt; inline;
begin Result := GetFacadeDispatch^.BitsetPopCount(p, len); end;

procedure ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAddF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArraySubF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMulF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayDivF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMinF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMaxF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAbsF32(aSrc, aDst, aCount);
end;

procedure ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayNegF32(aSrc, aDst, aCount);
end;

procedure ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArraySqrtF32(aSrc, aDst, aCount);
end;

procedure ArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayRcpF32(aSrc, aDst, aCount);
end;

procedure ArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayRsqrtF32(aSrc, aDst, aCount);
end;

procedure ArrayRcpRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayRcpRefineF32(aSrc, aDst, aCount);
end;

procedure ArrayRsqrtRefineF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayRsqrtRefineF32(aSrc, aDst, aCount);
end;

procedure ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAddScalarF32(aSrc, aDst, aCount, aScalar);
end;

procedure ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMulScalarF32(aSrc, aDst, aCount, aScalar);
end;

procedure ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayClampF32(aSrc, aDst, aCount, aMin, aMax);
end;

procedure ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayFmaF32(aA, aB, aC, aDst, aCount);
end;

procedure ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAxpyF32(aAlpha, aX, aY, aDst, aCount);
end;

function ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceSumF32(aSrc, aCount);
end;

function ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceDotF32(aSrc1, aSrc2, aCount);
end;

function ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMinF32(aSrc, aCount);
end;

function ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMaxF32(aSrc, aCount);
end;

// === ArrayF64 Batch Implementation ===

procedure ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAddF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArraySubF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMulF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayDivF64(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAbsF64(aSrc, aDst, aCount);
end;

procedure ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayNegF64(aSrc, aDst, aCount);
end;

procedure ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArraySqrtF64(aSrc, aDst, aCount);
end;

procedure ArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMulScalarF64(aSrc, aDst, aCount, aScalar);
end;

procedure ArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAddScalarF64(aSrc, aDst, aCount, aScalar);
end;

procedure ArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayClampF64(aSrc, aDst, aCount, aMin, aMax);
end;

procedure ArrayLinearF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScale, aBias: Double);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayLinearF64(aSrc, aDst, aCount, aScale, aBias);
end;

function ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceSumF64(aSrc, aCount);
end;

function ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceDotF64(aSrc1, aSrc2, aCount);
end;

function ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMinF64(aSrc, aCount);
end;

function ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  Result := LDispatch^.ReduceMaxF64(aSrc, aCount);
end;

// === Transcendental F32 Batch Implementation ===

procedure ArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayExpF32(aSrc, aDst, aCount);
end;

procedure ArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayLogF32(aSrc, aDst, aCount);
end;

procedure ArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayPowF32(aSrc, aDst, aCount, aExponent);
end;

procedure ArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArraySinF32(aSrc, aDst, aCount);
end;

procedure ArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayCosF32(aSrc, aDst, aCount);
end;

// === Fused Batch Implementation ===

procedure ArrayLinearF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayLinearF32(aSrc, aDst, aCount, aScale, aBias);
end;

procedure ArrayAbsDiffF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAbsDiffF32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayReLUF32(aSrc, aDst, aCount);
end;

procedure ArrayNormF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMean, aInvStd: Single);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayNormF32(aSrc, aDst, aCount, aMean, aInvStd);
end;

procedure ArrayLinearReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScale, aBias: Single);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayLinearReLUF32(aSrc, aDst, aCount, aScale, aBias);
end;

// === Integer Batch Implementation ===

procedure ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAddI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArraySubI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayMulI16(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayPackSatI32toI16(aSrc, aDst, aCount);
end;

// === Type Conversion Batch Implementation ===

procedure ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayF32toI32(aSrc, aDst, aCount);
end;

procedure ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayI32toF32(aSrc, aDst, aCount);
end;

// === Bitwise Batch Implementation ===

procedure ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayAndI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayOrI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayXorI32(aSrc1, aSrc2, aDst, aCount);
end;

procedure ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayShlI32(aSrc, aDst, aCount, aShift);
end;

procedure ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
var LDispatch: PSimdDispatchTable;
begin
  LDispatch := GetSimdFacadeDispatchFastPath;
  LDispatch^.ArrayShrI32(aSrc, aDst, aCount, aShift);
end;

// === Saturating Arithmetic Implementation ===
// 饱和算术：结果被钳制到类型范围，而不是溢出回绕

function VecI8x16SatAdd(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.I8x16SatAdd(a, b);
end;

function VecI8x16SatSub(const a, b: TVecI8x16): TVecI8x16;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.I8x16SatSub(a, b);
end;

function VecI16x8SatAdd(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.I16x8SatAdd(a, b);
end;

function VecI16x8SatSub(const a, b: TVecI16x8): TVecI16x8;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.I16x8SatSub(a, b);
end;

function VecU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.U8x16SatAdd(a, b);
end;

function VecU8x16SatSub(const a, b: TVecU8x16): TVecU8x16;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.U8x16SatSub(a, b);
end;

function VecU16x8SatAdd(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.U16x8SatAdd(a, b);
end;

function VecU16x8SatSub(const a, b: TVecU16x8): TVecU16x8;
var dispatch: PSimdDispatchTable;
begin
  dispatch := GetSimdFacadeDispatchFastPath;
  Result := dispatch^.U16x8SatSub(a, b);
end;

// === Shuffle/Permute Operations (wrappers for simd.utils) ===

function VecF32x4Shuffle(const a: TVecF32x4; imm8: Byte): TVecF32x4;
begin
  Result := nextpas.core.simd.utils.VecF32x4Shuffle(a, imm8);
end;

function VecI32x4Shuffle(const a: TVecI32x4; imm8: Byte): TVecI32x4;
begin
  Result := nextpas.core.simd.utils.VecI32x4Shuffle(a, imm8);
end;

function VecF32x4Shuffle2(const a, b: TVecF32x4; imm8: Byte): TVecF32x4;
begin
  Result := nextpas.core.simd.utils.VecF32x4Shuffle2(a, b, imm8);
end;

// === Blend Operations (wrappers for simd.utils) ===

function VecF32x4Blend(const a, b: TVecF32x4; mask: Byte): TVecF32x4;
begin
  Result := nextpas.core.simd.utils.VecF32x4Blend(a, b, mask);
end;

function VecF64x2Blend(const a, b: TVecF64x2; mask: Byte): TVecF64x2;
begin
  Result := nextpas.core.simd.utils.VecF64x2Blend(a, b, mask);
end;

function VecI32x4Blend(const a, b: TVecI32x4; mask: Byte): TVecI32x4;
begin
  Result := nextpas.core.simd.utils.VecI32x4Blend(a, b, mask);
end;

// === Type Conversion Operations (wrappers for simd.utils) ===

function VecF32x4IntoBits(const a: TVecF32x4): TVecI32x4;
begin
  Result := nextpas.core.simd.utils.VecF32x4IntoBits(a);
end;

function VecI32x4FromBitsF32(const a: TVecI32x4): TVecF32x4;
begin
  Result := nextpas.core.simd.utils.VecI32x4FromBitsF32(a);
end;

function VecI32x4CastToF32x4(const a: TVecI32x4): TVecF32x4;
begin
  Result := nextpas.core.simd.utils.VecI32x4CastToF32x4(a);
end;

function VecF32x4CastToI32x4(const a: TVecF32x4): TVecI32x4;
begin
  Result := nextpas.core.simd.utils.VecF32x4CastToI32x4(a);
end;

{$I nextpas.core.simd.framework.impl.inc}
{$I nextpas.core.simd.public_abi.impl.inc}

initialization
  InitializeSimdPublicApiBinding;
  AddDispatchChangedHook(@InvalidateSimdFacadeFastPaths);
  RebindSimdFacadeFastPaths;
  if GetCurrentSimdPublicApiBindingState = nil then
    RebindSimdPublicApi;

finalization
  RemoveDispatchChangedHook(@InvalidateSimdFacadeFastPaths);
  FinalizeSimdPublicApiBinding;

end.
