unit nextpas.core.simd.intrinsics.x86.sse2;
// Disposition: STABLE — low-level intrinsics, used by the SSE2 backend

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

{
  Role marker (2026-05-09):
  - Active SSE2 intrinsics leaf
  - active raw ISA leaf for SSE2 128-bit primitives
  - only qualified on x86/x86_64 targets
  - TM128/raw intrinsic surface only
  - no TVec/TMask facade, no dispatch registration, no runtime control-plane knowledge
  - 128-bit delegation frontier already has raw semantic parity coverage
}

// === SSE2 Intrinsics 完整接口 ===
// SSE2 is the baseline x86-64 SIMD ISA and is available on every x86-64 CPU.
// It provides 128-bit vector operations and forms the foundation for later x86 SIMD families.
// 类型 TM128 对应 __m128i / __m128 / __m128d，前缀统一 simd_

uses
  nextpas.core.simd.intrinsics.base;

// === 1️⃣ Load / Store ===
// Integer Load/Store
function simd_load_si128(const Ptr: Pointer): TM128;
function simd_loadu_si128(const Ptr: Pointer): TM128;
procedure simd_store_si128(var Dest; constref Src: TM128);
procedure simd_storeu_si128(var Dest; constref Src: TM128);
function simd_loadl_epi64(const Ptr: Pointer): TM128; // Load lower 64-bit integer
procedure simd_storel_epi64(var Dest; constref Src: TM128); // Store lower 64-bit integer
procedure simd_maskmoveu_si128(constref Src: TM128; constref Mask: TM128; var Dest); // Conditional store using mask

// Double Load/Store
function simd_load_pd(const Ptr: Pointer): TM128;
function simd_loadu_pd(const Ptr: Pointer): TM128;
procedure simd_store_pd(var Dest; constref Src: TM128);
procedure simd_storeu_pd(var Dest; constref Src: TM128);
function simd_loadr_pd(const Ptr: Pointer): TM128; // Load reverse packed double
procedure simd_storer_pd(var Dest; constref Src: TM128); // Store reverse packed double
function simd_loadh_pd(constref A: TM128; const Ptr: Pointer): TM128; // Load high double
function simd_loadl_pd(constref A: TM128; const Ptr: Pointer): TM128; // Load low double
procedure simd_storeh_pd(var Dest; constref Src: TM128); // Store high double
procedure simd_storel_pd(var Dest; constref Src: TM128); // Store low double
function simd_load_sd(const Ptr: Pointer): TM128; // Load scalar double
procedure simd_store_sd(var Dest; constref Src: TM128); // Store scalar double

// Single Load/Store
function simd_load_ps(const Ptr: Pointer): TM128;
function simd_loadu_ps(const Ptr: Pointer): TM128;
procedure simd_store_ps(var Dest; constref Src: TM128);
procedure simd_storeu_ps(var Dest; constref Src: TM128);

// === 2️⃣ Set / Zero / Broadcast ===
// Zero
function simd_setzero_si128: TM128;
function simd_setzero_pd: TM128;
function simd_setzero_ps: TM128;

// Set1 (Broadcast)
function simd_set1_epi8(Value: ShortInt): TM128;
function simd_set1_epi16(Value: SmallInt): TM128;
function simd_set1_epi32(Value: LongInt): TM128;
function simd_set1_epi64x(Value: Int64): TM128;
function simd_set1_ps(Value: Single): TM128;
function simd_set1_pd(Value: Double): TM128;

// Set (Reverse order)
function simd_setr_epi32(a, b, c, d: LongInt): TM128;
function simd_set_epi32(a, b, c, d: LongInt): TM128;
function simd_setr_pd(a, b: Double): TM128;
function simd_set_epi64x(a, b: Int64): TM128;
function simd_set_epi8(a15, a14, a13, a12, a11, a10, a9, a8, a7, a6, a5, a4, a3, a2, a1, a0: ShortInt): TM128; // Set 16 8-bit integers
function simd_setr_epi8(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15: ShortInt): TM128; // Set reverse 16 8-bit integers
function simd_set_epi16(a7, a6, a5, a4, a3, a2, a1, a0: SmallInt): TM128; // Set 8 16-bit integers
function simd_setr_epi16(a0, a1, a2, a3, a4, a5, a6, a7: SmallInt): TM128; // Set reverse 8 16-bit integers
function simd_set_epi64(a, b: Int64): TM128; // Set 2 64-bit integers
function simd_setr_epi64(a, b: Int64): TM128; // Set reverse 2 64-bit integers
function simd_set_pd(a, b: Double): TM128; // Set 2 doubles (high, low)

// === 3️⃣ Integer Arithmetic ===
// Add
function simd_add_epi8(constref a, b: TM128): TM128;
function simd_add_epi16(constref a, b: TM128): TM128;
function simd_add_epi32(constref a, b: TM128): TM128;
function simd_add_epi64(constref a, b: TM128): TM128;

// Sub
function simd_sub_epi8(constref a, b: TM128): TM128;
function simd_sub_epi16(constref a, b: TM128): TM128;
function simd_sub_epi32(constref a, b: TM128): TM128;
function simd_sub_epi64(constref a, b: TM128): TM128;

// Saturated Add/Sub
function simd_adds_epi8(constref a, b: TM128): TM128;   // signed saturated add
function simd_adds_epi16(constref a, b: TM128): TM128;
function simd_subs_epi8(constref a, b: TM128): TM128;   // signed saturated sub
function simd_subs_epi16(constref a, b: TM128): TM128;
function simd_adds_epu8(constref a, b: TM128): TM128; // unsigned saturated add 8-bit
function simd_adds_epu16(constref a, b: TM128): TM128; // unsigned saturated add 16-bit
function simd_subs_epu8(constref a, b: TM128): TM128; // unsigned saturated sub 8-bit
function simd_subs_epu16(constref a, b: TM128): TM128; // unsigned saturated sub 16-bit

// Min/Max
function simd_max_epi8(constref a, b: TM128): TM128;
function simd_max_epi16(constref a, b: TM128): TM128;
function simd_min_epi8(constref a, b: TM128): TM128;
function simd_min_epi16(constref a, b: TM128): TM128;
function simd_max_epu8(constref a, b: TM128): TM128; // Max unsigned 8-bit
function simd_min_epu8(constref a, b: TM128): TM128; // Min unsigned 8-bit

// Multiply
function simd_mul_epu32(constref a, b: TM128): TM128;   // unsigned 32-bit multiply
function simd_mullo_epi16(constref a, b: TM128): TM128; // signed 16-bit multiply low
function simd_mulhi_epi16(constref a, b: TM128): TM128; // signed 16-bit multiply high
function simd_mulhi_epu16(constref a, b: TM128): TM128; // unsigned 16-bit multiply high
function simd_madd_epi16(constref a, b: TM128): TM128; // Multiply and add 16-bit to 32-bit

// Average
function simd_avg_epu8(constref a, b: TM128): TM128; // Average unsigned 8-bit
function simd_avg_epu16(constref a, b: TM128): TM128; // Average unsigned 16-bit

// SAD
function simd_sad_epu8(constref a, b: TM128): TM128; // Sum of absolute differences unsigned 8-bit

// === 4️⃣ Floating-Point Arithmetic ===
// Single Precision
function simd_add_ps(constref a, b: TM128): TM128;
function simd_sub_ps(constref a, b: TM128): TM128;
function simd_mul_ps(constref a, b: TM128): TM128;
function simd_div_ps(constref a, b: TM128): TM128;
function simd_sqrt_ps(constref a: TM128): TM128;
function simd_min_ps(constref a, b: TM128): TM128; // Min single
function simd_max_ps(constref a, b: TM128): TM128; // Max single

// Double Precision
function simd_add_pd(constref a, b: TM128): TM128;
function simd_sub_pd(constref a, b: TM128): TM128;
function simd_mul_pd(constref a, b: TM128): TM128;
function simd_div_pd(constref a, b: TM128): TM128;
function simd_sqrt_pd(constref a: TM128): TM128;
function simd_min_pd(constref a, b: TM128): TM128; // Min packed double
function simd_max_pd(constref a, b: TM128): TM128; // Max packed double
function simd_add_sd(constref a, b: TM128): TM128; // Add scalar double
function simd_sub_sd(constref a, b: TM128): TM128; // Sub scalar double
function simd_mul_sd(constref a, b: TM128): TM128; // Mul scalar double
function simd_div_sd(constref a, b: TM128): TM128; // Div scalar double
function simd_sqrt_sd(constref a, b: TM128): TM128; // Sqrt scalar double (a upper pass through)
function simd_min_sd(constref a, b: TM128): TM128; // Min scalar double
function simd_max_sd(constref a, b: TM128): TM128; // Max scalar double

// === 5️⃣ Logical Operations ===
function simd_and_si128(constref a, b: TM128): TM128;
function simd_or_si128(constref a, b: TM128): TM128;
function simd_xor_si128(constref a, b: TM128): TM128;
function simd_andnot_si128(constref a, b: TM128): TM128;  // ~a & b
function simd_and_pd(constref a, b: TM128): TM128; // And packed double
function simd_or_pd(constref a, b: TM128): TM128; // Or packed double
function simd_xor_pd(constref a, b: TM128): TM128; // Xor packed double
function simd_andnot_pd(constref a, b: TM128): TM128; // Andnot packed double

// === 6️⃣ Compare / Mask ===
// Integer Compare
function simd_cmpeq_epi8(constref a, b: TM128): TM128;
function simd_cmpeq_epi16(constref a, b: TM128): TM128;
function simd_cmpeq_epi32(constref a, b: TM128): TM128;
function simd_cmpgt_epi8(constref a, b: TM128): TM128;
function simd_cmpgt_epi16(constref a, b: TM128): TM128;
function simd_cmpgt_epi32(constref a, b: TM128): TM128;
function simd_cmplt_epi8(constref a, b: TM128): TM128;
function simd_cmplt_epi16(constref a, b: TM128): TM128;
function simd_cmplt_epi32(constref a, b: TM128): TM128;

// Floating-Point Compare
function simd_cmpeq_pd(constref a, b: TM128): TM128;
function simd_cmplt_pd(constref a, b: TM128): TM128;
function simd_cmple_pd(constref a, b: TM128): TM128;
function simd_cmpgt_pd(constref a, b: TM128): TM128;
function simd_cmpge_pd(constref a, b: TM128): TM128;
function simd_cmpneq_pd(constref a, b: TM128): TM128;
function simd_cmpnlt_pd(constref a, b: TM128): TM128; // Not less than packed double
function simd_cmpnle_pd(constref a, b: TM128): TM128; // Not less or equal packed double
function simd_cmpngt_pd(constref a, b: TM128): TM128; // Not greater than packed double
function simd_cmpnge_pd(constref a, b: TM128): TM128; // Not greater or equal packed double
function simd_cmpord_pd(constref a, b: TM128): TM128; // Ordered packed double
function simd_cmpunord_pd(constref a, b: TM128): TM128; // Unordered packed double
function simd_cmpeq_sd(constref a, b: TM128): TM128; // Equal scalar double
function simd_cmplt_sd(constref a, b: TM128): TM128; // Less than scalar double
function simd_cmple_sd(constref a, b: TM128): TM128; // Less or equal scalar double
function simd_cmpgt_sd(constref a, b: TM128): TM128; // Greater than scalar double
function simd_cmpge_sd(constref a, b: TM128): TM128; // Greater or equal scalar double
function simd_cmpneq_sd(constref a, b: TM128): TM128; // Not equal scalar double
function simd_cmpnlt_sd(constref a, b: TM128): TM128; // Not less than scalar double
function simd_cmpnle_sd(constref a, b: TM128): TM128; // Not less or equal scalar double
function simd_cmpngt_sd(constref a, b: TM128): TM128; // Not greater than scalar double
function simd_cmpnge_sd(constref a, b: TM128): TM128; // Not greater or equal scalar double
function simd_cmpord_sd(constref a, b: TM128): TM128; // Ordered scalar double
function simd_cmpunord_sd(constref a, b: TM128): TM128; // Unordered scalar double
function simd_comieq_sd(constref a, b: TM128): Integer; // Scalar ordered equal compare, return int
function simd_comilt_sd(constref a, b: TM128): Integer; // Scalar ordered less than compare, return int
function simd_comile_sd(constref a, b: TM128): Integer; // Scalar ordered less or equal, return int
function simd_comigt_sd(constref a, b: TM128): Integer; // Scalar ordered greater than, return int
function simd_comige_sd(constref a, b: TM128): Integer; // Scalar ordered greater or equal, return int
function simd_comineq_sd(constref a, b: TM128): Integer; // Scalar ordered not equal, return int
function simd_ucomieq_sd(constref a, b: TM128): Integer; // Scalar unordered equal compare, return int
function simd_ucomilt_sd(constref a, b: TM128): Integer; // Scalar unordered less than, return int
function simd_ucomile_sd(constref a, b: TM128): Integer; // Scalar unordered less or equal, return int
function simd_ucomigt_sd(constref a, b: TM128): Integer; // Scalar unordered greater than, return int
function simd_ucomige_sd(constref a, b: TM128): Integer; // Scalar unordered greater or equal, return int
function simd_ucomineq_sd(constref a, b: TM128): Integer; // Scalar unordered not equal, return int

// Move Mask
function simd_movemask_epi8(constref a: TM128): Integer;
function simd_movemask_ps(constref a: TM128): Integer;
function simd_movemask_pd(constref a: TM128): Integer;

// === 7️⃣ Shuffle / Unpack / Permute ===
// Shuffle
function simd_shuffle_epi32(constref a: TM128; imm8: Byte): TM128;
function simd_shuffle_pd(constref a, b: TM128; imm8: Byte): TM128;
function simd_shuffle_ps(constref a, b: TM128; imm8: Byte): TM128; // Shuffle single
function simd_shufflelo_epi16(constref a: TM128; imm8: Byte): TM128; // Shuffle low 16-bit
function simd_shufflehi_epi16(constref a: TM128; imm8: Byte): TM128; // Shuffle high 16-bit

// Unpack
function simd_unpacklo_epi8(constref a, b: TM128): TM128;
function simd_unpackhi_epi8(constref a, b: TM128): TM128;
function simd_unpacklo_epi16(constref a, b: TM128): TM128;
function simd_unpackhi_epi16(constref a, b: TM128): TM128;
function simd_unpacklo_epi32(constref a, b: TM128): TM128;
function simd_unpackhi_epi32(constref a, b: TM128): TM128;
function simd_unpacklo_epi64(constref a, b: TM128): TM128;
function simd_unpackhi_epi64(constref a, b: TM128): TM128;
function simd_unpacklo_pd(constref a, b: TM128): TM128;
function simd_unpackhi_pd(constref a, b: TM128): TM128;
function simd_unpacklo_ps(constref a, b: TM128): TM128; // Unpack low single
function simd_unpackhi_ps(constref a, b: TM128): TM128; // Unpack high single

// === 8️⃣ Shift / Rotate (Integers) ===
// Left Shift
function simd_slli_epi16(constref a: TM128; imm8: Byte): TM128;
function simd_slli_epi32(constref a: TM128; imm8: Byte): TM128;
function simd_slli_epi64(constref a: TM128; imm8: Byte): TM128;
function simd_slli_si128(constref a: TM128; imm8: Byte): TM128; // Left shift bytes in 128-bit

// Right Shift (Logical)
function simd_srli_epi16(constref a: TM128; imm8: Byte): TM128;
function simd_srli_epi32(constref a: TM128; imm8: Byte): TM128;
function simd_srli_epi64(constref a: TM128; imm8: Byte): TM128;
function simd_srli_si128(constref a: TM128; imm8: Byte): TM128; // Right shift bytes in 128-bit

// Right Shift (Arithmetic)
function simd_srai_epi16(constref a: TM128; imm8: Byte): TM128;
function simd_srai_epi32(constref a: TM128; imm8: Byte): TM128;
function simd_srai_si128(constref a: TM128; imm8: Byte): TM128; // Arithmetic right shift bytes (sign extend)

// === 9️⃣ Conversion / Cast ===
// Type Conversion
function simd_cvtepi32_pd(constref a: TM128): TM128;
function simd_cvtpd_epi32(constref a: TM128): TM128;
function simd_cvtepi32_ps(constref a: TM128): TM128;
function simd_cvtps_epi32(constref a: TM128): TM128;
function simd_cvtpd_ps(constref a: TM128): TM128; // Packed double to packed single
function simd_cvtps_pd(constref a: TM128): TM128; // Packed single to packed double
function simd_cvtsd_ss(constref a, b: TM128): TM128; // Scalar double to scalar single
function simd_cvtss_sd(constref a, b: TM128): TM128; // Scalar single to scalar double
function simd_cvttpd_epi32(constref a: TM128): TM128; // Truncate packed double to epi32
function simd_cvttpd_ps(constref a: TM128): TM128; // Truncate packed double to single
function simd_cvttps_epi32(constref a: TM128): TM128; // Truncate packed single to epi32
function simd_cvtsd_si32(constref a: TM128): Integer; // Scalar double to si32
function simd_cvtsd_si64(constref a: TM128): Int64; // Scalar double to si64
function simd_cvttsd_si32(constref a: TM128): Integer; // Truncate scalar double to si32
function simd_cvttsd_si64(constref a: TM128): Int64; // Truncate scalar double to si64

// Scalar Conversion
function simd_cvtsi32_si128(a: Integer): TM128;
function simd_cvtsi64_si128(a: Int64): TM128;
function simd_cvtsi128_si32(constref a: TM128): Integer;
function simd_cvtsi128_si64(constref a: TM128): Int64;
function simd_cvtsi32_sd(constref a: TM128; b: Integer): TM128; // si32 to scalar double
function simd_cvtsi64_sd(constref a: TM128; b: Int64): TM128; // si64 to scalar double

// Cast (No Conversion)
function simd_castpd_si128(constref a: TM128): TM128;
function simd_castps_si128(constref a: TM128): TM128;
function simd_castsi128_pd(constref a: TM128): TM128;
function simd_castsi128_ps(constref a: TM128): TM128;
function simd_castpd_ps(constref a: TM128): TM128; // Cast double to single
function simd_castps_pd(constref a: TM128): TM128; // Cast single to double

// === 🔟 Pack / Insert / Extract / Move ===
function simd_packs_epi16(constref a, b: TM128): TM128; // Pack signed 16-bit to signed 8-bit with saturation
function simd_packs_epi32(constref a, b: TM128): TM128; // Pack signed 32-bit to signed 16-bit with saturation
function simd_packus_epi16(constref a, b: TM128): TM128; // Pack signed 16-bit to unsigned 8-bit with saturation
function simd_insert_epi16(constref a: TM128; Value: Integer; imm8: Byte): TM128; // Insert 16-bit at position
function simd_extract_epi16(constref a: TM128; imm8: Byte): Integer; // Extract 16-bit at position
function simd_move_sd(constref a, b: TM128): TM128; // Move scalar double
function simd_move_epi64(constref a: TM128): TM128; // Move 64-bit integer

// === 1️⃣1️⃣ Cache Control / Stream / Fence ===
procedure simd_clflush(const Ptr: Pointer); // Cache line flush
procedure simd_lfence; // Load fence
procedure simd_mfence; // Memory fence
procedure simd_pause; // Pause (spin loop hint)
procedure simd_stream_pd(var Dest; constref Src: TM128); // Non-temporal store packed double
procedure simd_stream_ps(var Dest; constref Src: TM128); // Non-temporal store packed single
procedure simd_stream_si128(var Dest; constref Src: TM128); // Non-temporal store 128-bit
procedure simd_stream_si32(var Dest; Value: Integer); // Non-temporal store 32-bit
procedure simd_stream_si64(var Dest; Value: Int64); // Non-temporal store 64-bit

implementation

uses
  nextpas.core.simd.mathutil;

{$PUSH}
{$WARN 5057 OFF} // raw leaf / assembler 路径的 Result 初始化误报
{$WARN 6018 OFF} // 手写 ASM 与显式 Exit 导致的不可达代码误报

type
  TSimdDoubleMaskCompareKind = (
    dmckEq,
    dmckLt,
    dmckLe,
    dmckGt,
    dmckGe,
    dmckNe,
    dmckNlt,
    dmckNle,
    dmckNgt,
    dmckNge,
    dmckOrd,
    dmckUnord
  );

  TSimdDoubleMinMaxKind = (
    dmmkMin,
    dmmkMax
  );

  TSimdBinaryArithmeticKind = (
    bakAdd,
    bakSub,
    bakMul
  );

function BuildPackedDoubleCompareMask(constref a, b: TM128; const aKind: TSimdDoubleMaskCompareKind): TM128; forward;
function BuildScalarDoubleCompareMask(constref a, b: TM128; const aKind: TSimdDoubleMaskCompareKind): TM128; forward;
function BuildPackedSingleMinMax(constref a, b: TM128; const aKind: TSimdDoubleMinMaxKind): TM128; forward;
function BuildPackedDoubleMinMax(constref a, b: TM128; const aKind: TSimdDoubleMinMaxKind): TM128; forward;
function BuildScalarDoubleMinMax(constref a, b: TM128; const aKind: TSimdDoubleMinMaxKind): TM128; forward;
function SelectSingleSpecialArithmeticBits(
  const aLeftBits, aRightBits: DWord;
  const aLeftValue, aRightValue: Single;
  const aKind: TSimdBinaryArithmeticKind
): DWord; forward;
function SelectDoubleSpecialArithmeticBits(
  const aLeftBits, aRightBits: QWord;
  const aLeftValue, aRightValue: Double;
  const aKind: TSimdBinaryArithmeticKind
): QWord; forward;
function BuildPackedSingleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; forward;
function BuildPackedDoubleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; forward;
function BuildScalarDoubleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; forward;
function SelectSingleSqrtBits(const aBits: DWord; const aValue: Single): DWord; forward;
function SelectDoubleSqrtBits(const aBits: QWord; const aValue: Double): QWord; forward;
function BuildPackedSingleSqrt(constref a: TM128): TM128; forward;
function BuildPackedDoubleSqrt(constref a: TM128): TM128; forward;
function BuildScalarDoubleSqrt(constref a, b: TM128): TM128; forward;

// === SSE2 Intrinsics 实现 ===
// Active raw-leaf bodies live here as the SSE2 128-bit delegation frontier.
// === 1️⃣ Load / Store 实现 ===
function simd_load_si128(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movdqa xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movdqa xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: argument arrives on the stack.
    mov eax, [esp + 4]
    movdqa xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_loadu_si128(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movdqu xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movdqu xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: argument arrives on the stack.
    mov eax, [esp + 4]
    movdqu xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_store_si128(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx
    movdqu xmm0, [rdx] // Src is a constref parameter and need not be aligned.
    movdqa [rcx], xmm0    // Store aligned data to the destination.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi
    movdqu xmm0, [rsi] // Src is a constref parameter and need not be aligned.
    movdqa [rdi], xmm0    // Store aligned data to the destination.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movdqu xmm0, [edx] // Src is a constref parameter and need not be aligned.
    movdqa [eax], xmm0    // Store aligned data to the destination.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_storeu_si128(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx
    movdqu xmm0, [rdx]    // 非对齐加载源数据
    movdqu [rcx], xmm0    // 非对齐存储到目标
  {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi
    movdqu xmm0, [rsi]    // 非对齐加载源数据
    movdqu [rdi], xmm0    // 非对齐存储到目标
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movdqu xmm0, [edx]    // 非对齐加载源数据
    movdqu [eax], xmm0    // 非对齐存储到目标
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

// Double Load/Store
function simd_load_pd(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movapd xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movapd xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: argument arrives on the stack.
    mov eax, [esp + 4]
    movapd xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_loadu_pd(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movupd xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movupd xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: argument arrives on the stack.
    mov eax, [esp + 4]
    movupd xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_store_pd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx
    movupd xmm0, [rdx] // Src is a constref parameter and need not be aligned.
    movapd [rcx], xmm0    // Store aligned data to the destination.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi
    movupd xmm0, [rsi] // Src is a constref parameter and need not be aligned.
    movapd [rdi], xmm0    // Store aligned data to the destination.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movupd xmm0, [edx] // Src is a constref parameter and need not be aligned.
    movapd [eax], xmm0    // Store aligned data to the destination.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_storeu_pd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx
    movupd xmm0, [rdx]    // 非对齐加载源数据
    movupd [rcx], xmm0    // 非对齐存储到目标
  {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi
    movupd xmm0, [rsi]    // 非对齐加载源数据
    movupd [rdi], xmm0    // 非对齐存储到目标
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movupd xmm0, [edx]    // 非对齐加载源数据
    movupd [eax], xmm0    // 非对齐存储到目标
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

// Single Load/Store
function simd_load_ps(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movaps xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movaps xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: argument arrives on the stack.
    mov eax, [esp + 4]
    movaps xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_loadu_ps(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movups xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movups xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: argument arrives on the stack.
    mov eax, [esp + 4]
    movups xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_store_ps(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx
    movups xmm0, [rdx] // Src is a constref parameter and need not be aligned.
    movaps [rcx], xmm0    // Store aligned data to the destination.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi
    movups xmm0, [rsi] // Src is a constref parameter and need not be aligned.
    movaps [rdi], xmm0    // Store aligned data to the destination.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movups xmm0, [edx] // Src is a constref parameter and need not be aligned.
    movaps [eax], xmm0    // Store aligned data to the destination.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_storeu_ps(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx
    movups xmm0, [rdx]    // 非对齐加载源数据
    movups [rcx], xmm0    // 非对齐存储到目标
  {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi
    movups xmm0, [rsi]    // 非对齐加载源数据
    movups [rdi], xmm0    // 非对齐存储到目标
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movups xmm0, [edx]    // 非对齐加载源数据
    movups [eax], xmm0    // 非对齐存储到目标
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

// === 2️⃣ Set / Zero / Broadcast 实现 ===
function simd_setzero_si128: TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
  // Intel 语法:
  // Zero all bits by XORing xmm0 with itself.
  pxor xmm0, xmm0
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_setzero_pd: TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
  // Intel 语法:
  // Zero both packed double lanes.
  xorpd xmm0, xmm0
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_setzero_ps: TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
  // Intel 语法:
  // Zero all packed single-precision lanes.
  xorps xmm0, xmm0
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set1_epi8(Value: ShortInt): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Value in rcx (8-bit scalar)
    movd xmm0, ecx // Move Value into the low 32 bits of xmm0.
    punpcklbw xmm0, xmm0  // 复制字节: 01010101 -> 0011001100110011
    punpcklwd xmm0, xmm0  // Replicate byte pairs across each word lane.
    pshufd xmm0, xmm0, 0  // Broadcast the replicated dword to all lanes.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Value in rdi (8-bit scalar)
    movd xmm0, edi
    punpcklbw xmm0, xmm0
    punpcklwd xmm0, xmm0
    pshufd xmm0, xmm0, 0
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: Value arrives on the stack.
    mov eax, [esp + 4]
    movd xmm0, eax
    punpcklbw xmm0, xmm0
    punpcklwd xmm0, xmm0
    pshufd xmm0, xmm0, 0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set1_epi16(Value: SmallInt): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Value in rcx (16-bit scalar)
    movd xmm0, ecx // Move Value into the low 32 bits of xmm0.
    punpcklwd xmm0, xmm0  // Replicate the 16-bit value within the low dword.
    pshufd xmm0, xmm0, 0  // Broadcast the replicated dword to all lanes.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Value in rdi (16-bit scalar)
    movd xmm0, edi
    punpcklwd xmm0, xmm0
    pshufd xmm0, xmm0, 0
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: Value arrives on the stack.
    mov eax, [esp + 4]
    movd xmm0, eax
    punpcklwd xmm0, xmm0
    pshufd xmm0, xmm0, 0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set1_epi32(Value: LongInt): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Value in rcx (32-bit scalar)
    movd xmm0, ecx // Move Value into the low 32 bits of xmm0.
    pshufd xmm0, xmm0, 0  // Broadcast the 32-bit lane to the full register.
  {$ELSE}
    // Linux/macOS x64 System V ABI: Value in rdi (32-bit scalar)
    movd xmm0, edi
    pshufd xmm0, xmm0, 0
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: Value arrives on the stack.
    mov eax, [esp + 4]
    movd xmm0, eax
    pshufd xmm0, xmm0, 0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set1_epi64x(Value: Int64): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Value in rcx (64-bit scalar)
    movq xmm0, rcx // Move Value into the low 64 bits of xmm0.
    punpcklqdq xmm0, xmm0 // Replicate the low 64-bit lane into the high lane.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Value in rdi (64-bit scalar)
    movq xmm0, rdi
    punpcklqdq xmm0, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: Value arrives on the stack (8 bytes).
    movq xmm0, [esp + 4] // Load the 64-bit scalar directly from the stack.
    punpcklqdq xmm0, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set1_ps(Value: Single): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Value already arrives in xmm0 (single-precision scalar)
    shufps xmm0, xmm0, 0  // Broadcast xmm0[0] to every single-precision lane.
  {$ELSE}
    // Linux/macOS x64 System V ABI: Value already arrives in xmm0
    shufps xmm0, xmm0, 0
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: Value arrives on the stack.
    movss xmm0, [esp + 4] // 加载单精度浮点数
    shufps xmm0, xmm0, 0  // Broadcast the loaded scalar to every lane.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set1_pd(Value: Double): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Value already arrives in xmm0 (double-precision scalar)
    unpcklpd xmm0, xmm0   // Replicate the low 64-bit lane into the high lane.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Value already arrives in xmm0
    unpcklpd xmm0, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: Value arrives on the stack (8 bytes).
    movsd xmm0, [esp + 4] // 加载双精度浮点数
    unpcklpd xmm0, xmm0   // Replicate the low lane into the high lane.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === 复杂 Set 函数实现 ===
// Earlier duplicate Set bodies were removed; keep the later canonical block.
// === Set 函数实现 ===
function simd_setr_epi32(a, b, c, d: LongInt): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a在rcx, b在rdx, c在r8, d在r9
    movd xmm0, ecx        // a -> xmm0[31:0]
    movd xmm1, edx        // b -> xmm1[31:0]
    punpckldq xmm0, xmm1  // xmm0 = [b, a, 0, 0]
    movd xmm1, r8d        // c -> xmm1[31:0]
    movd xmm2, r9d        // d -> xmm2[31:0]
    punpckldq xmm1, xmm2  // xmm1 = [d, c, 0, 0]
    punpcklqdq xmm0, xmm1 // xmm0 = [d, c, b, a]
  {$ELSE}
    // Linux/macOS x64 System V ABI: a在rdi, b在rsi, c在rdx, d在rcx
    movd xmm0, edi
    movd xmm1, esi
    punpckldq xmm0, xmm1
    movd xmm1, edx
    movd xmm2, ecx
    punpckldq xmm1, xmm2
    punpcklqdq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movd xmm0, eax
    movd xmm1, edx
    punpckldq xmm0, xmm1
    mov eax, [esp + 12]   // c
    mov edx, [esp + 16]   // d
    movd xmm1, eax
    movd xmm2, edx
    punpckldq xmm1, xmm2
    punpcklqdq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set_epi32(a, b, c, d: LongInt): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a在rcx, b在rdx, c在r8, d在r9
    // Result order is [a, b, c, d] from high lane to low lane.
    movd xmm0, r9d        // d -> xmm0[31:0]
    movd xmm1, r8d        // c -> xmm1[31:0]
    punpckldq xmm0, xmm1  // xmm0 = [c, d, 0, 0]
    movd xmm1, edx        // b -> xmm1[31:0]
    movd xmm2, ecx        // a -> xmm2[31:0]
    punpckldq xmm1, xmm2  // xmm1 = [a, b, 0, 0]
    punpcklqdq xmm0, xmm1 // xmm0 = [a, b, c, d]
  {$ELSE}
    // Linux/macOS x64 System V ABI: a在rdi, b在rsi, c在rdx, d在rcx
    movd xmm0, ecx        // d
    movd xmm1, edx        // c
    punpckldq xmm0, xmm1
    movd xmm1, esi        // b
    movd xmm2, edi        // a
    punpckldq xmm1, xmm2
    punpcklqdq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 16]   // d
    mov edx, [esp + 12]   // c
    movd xmm0, eax
    movd xmm1, edx
    punpckldq xmm0, xmm1
    mov eax, [esp + 8]    // b
    mov edx, [esp + 4]    // a
    movd xmm1, eax
    movd xmm2, edx
    punpckldq xmm1, xmm2
    punpcklqdq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_setr_pd(a, b: Double): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a在xmm0, b在xmm1
    unpcklpd xmm0, xmm1   // xmm0 = [b, a] (高位, 低位)
  {$ELSE}
    // Linux/macOS x64 System V ABI: a在xmm0, b在xmm1
    unpcklpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    movsd xmm0, [esp + 4]  // a (8字节)
    movsd xmm1, [esp + 12] // b (8字节)
    unpcklpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_set_epi64x(a, b: Int64): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a在rcx, b在rdx
    // Result is [a, b] with a in the high 64-bit lane and b in the low lane.
    movq xmm0, rdx // Move b into the low 64-bit lane.
    movq xmm1, rcx // Move a into the low 64-bit lane of xmm1.
    punpcklqdq xmm0, xmm1 // xmm0 = [a, b]
  {$ELSE}
    // Linux/macOS x64 System V ABI: a在rdi, b在rsi
    movq xmm0, rsi // Move b into the low 64-bit lane.
    movq xmm1, rdi // Move a into the low 64-bit lane of xmm1.
    punpcklqdq xmm0, xmm1 // xmm0 = [a, b]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    movq xmm0, [esp + 12] // b (8字节)
    movq xmm1, [esp + 4]  // a (8字节)
    punpcklqdq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === Remaining raw-leaf implementations ===
// Keep the active raw-leaf bodies here so the unit continues to compile.
// These entry points can be replaced with fuller handwritten assembly later.
// Current focus is raw-leaf coverage for the key functions below.
function simd_add_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a in rcx, b in rdx
    movdqu xmm0, [rcx]    // Load a.
    movdqu xmm1, [rdx]    // Load b.
    paddb xmm0, xmm1      // Add sixteen 8-bit integer lanes in parallel.
    {$ELSE}
    // Linux/macOS x64 System V ABI: a in rdi, b in rsi
    movdqu xmm0, [rdi]    // Load a.
    movdqu xmm1, [rsi]    // Load b.
    paddb xmm0, xmm1      // Add sixteen 8-bit integer lanes in parallel.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    paddb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmpeq_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pcmpeqb xmm0, xmm1  // Compare packed 8-bit lanes for equality.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pcmpeqb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pcmpeqb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_and_si128(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pand xmm0, xmm1  // Bitwise AND across the full 128-bit vectors.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pand xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pand xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// simd_movemask_epi8 now lives in the dedicated handwritten assembly block.
// === 3️⃣ Integer Arithmetic 剩余实现 ===
function simd_add_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a in rcx, b in rdx
    movdqu xmm0, [rcx]    // Load a.
    movdqu xmm1, [rdx]    // Load b.
    paddw xmm0, xmm1      // Add eight 16-bit integer lanes in parallel.
    {$ELSE}
    // Linux/macOS x64 System V ABI: a in rdi, b in rsi
    movdqu xmm0, [rdi]    // Load a.
    movdqu xmm1, [rsi]    // Load b.
    paddw xmm0, xmm1      // Add eight 16-bit integer lanes in parallel.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    paddw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_add_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a in rcx, b in rdx
    movdqu xmm0, [rcx]    // Load a.
    movdqu xmm1, [rdx]    // Load b.
    paddd xmm0, xmm1      // Add four 32-bit integer lanes in parallel.
    {$ELSE}
    // Linux/macOS x64 System V ABI: a in rdi, b in rsi
    movdqu xmm0, [rdi]    // Load a.
    movdqu xmm1, [rsi]    // Load b.
    paddd xmm0, xmm1      // Add four 32-bit integer lanes in parallel.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    paddd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_add_epi64(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a in rcx, b in rdx
    movdqu xmm0, [rcx]    // Load a.
    movdqu xmm1, [rdx]    // Load b.
    paddq xmm0, xmm1      // Add two 64-bit integer lanes in parallel.
    {$ELSE}
    // Linux/macOS x64 System V ABI: a in rdi, b in rsi
    movdqu xmm0, [rdi]    // Load a.
    movdqu xmm1, [rsi]    // Load b.
    paddq xmm0, xmm1      // Add two 64-bit integer lanes in parallel.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    paddq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_sub_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: a in rcx, b in rdx
    movdqu xmm0, [rcx]    // Load a.
    movdqu xmm1, [rdx]    // Load b.
    psubb xmm0, xmm1      // Subtract sixteen 8-bit integer lanes in parallel.
    {$ELSE}
    // Linux/macOS x64 System V ABI: a in rdi, b in rsi
    movdqu xmm0, [rdi]    // Load a.
    movdqu xmm1, [rsi]    // Load b.
    psubb xmm0, xmm1      // Subtract sixteen 8-bit integer lanes in parallel.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    psubb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_sub_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubw xmm0, xmm1
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_sub_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubd xmm0, xmm1
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_sub_epi64(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubq xmm0, xmm1
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_adds_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; paddsb xmm0, xmm1  // Signed saturated add on 8-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; paddsb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; paddsb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_adds_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; paddsw xmm0, xmm1  // Signed saturated add on 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; paddsw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; paddsw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_subs_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubsb xmm0, xmm1  // Signed saturated subtract on 8-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubsb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubsb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_subs_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubsw xmm0, xmm1  // Signed saturated subtract on 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubsw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubsw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_max_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    movdqu xmm1, [rdx]    // 加载 b
    movdqu xmm2, xmm0     // 复制 a
    pcmpgtb xmm2, xmm1    // Build the mask for lanes where a > b.
    pand xmm0, xmm2       // Keep the larger lanes from a.
    pandn xmm2, xmm1      // 选择 b 中较大的元素
    por xmm0, xmm2        // 合并结果
  {$ELSE}
    movdqu xmm0, [rdi]
    movdqu xmm1, [rsi]
    movdqu xmm2, xmm0
    pcmpgtb xmm2, xmm1
    pand xmm0, xmm2
    pandn xmm2, xmm1
    por xmm0, xmm2
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]
    movdqu xmm0, [eax]; movdqu xmm1, [edx]
    movdqu xmm2, xmm0; pcmpgtb xmm2, xmm1
    pand xmm0, xmm2; pandn xmm2, xmm1; por xmm0, xmm2
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_max_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmaxsw xmm0, xmm1  // Signed max on 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmaxsw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmaxsw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_min_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    movdqu xmm1, [rdx]    // 加载 b
    movdqu xmm2, xmm1     // 复制 b
    pcmpgtb xmm2, xmm0    // Build the mask for lanes where b > a.
    pand xmm0, xmm2       // Keep the smaller lanes from a.
    pandn xmm2, xmm1      // 选择 b 中较小的元素
    por xmm0, xmm2        // 合并结果
  {$ELSE}
    movdqu xmm0, [rdi]
    movdqu xmm1, [rsi]
    movdqu xmm2, xmm1
    pcmpgtb xmm2, xmm0
    pand xmm0, xmm2
    pandn xmm2, xmm1
    por xmm0, xmm2
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]
    movdqu xmm0, [eax]; movdqu xmm1, [edx]
    movdqu xmm2, xmm1; pcmpgtb xmm2, xmm0
    pand xmm0, xmm2; pandn xmm2, xmm1; por xmm0, xmm2
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_min_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pminsw xmm0, xmm1  // Signed min on 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pminsw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pminsw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_mul_epu32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmuludq xmm0, xmm1  // Unsigned 32-bit multiply producing 64-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmuludq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmuludq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_mullo_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmullw xmm0, xmm1  // Keep the low 16-bit product lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmullw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmullw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === 4️⃣ Floating-Point Arithmetic 实现 ===
function simd_add_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleSpecialArithmetic(a, b, bakAdd);
end;

function simd_sub_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleSpecialArithmetic(a, b, bakSub);
end;

function simd_mul_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleSpecialArithmetic(a, b, bakMul);
end;

function SingleBitsIsZero(const aBits: DWord): Boolean; inline;
begin
  Result := (aBits and DWord($7FFFFFFF)) = 0;
end;

function DoubleBitsIsZero(const aBits: QWord): Boolean; inline;
begin
  Result := (aBits and QWord($7FFFFFFFFFFFFFFF)) = 0;
end;

function BuildSingleInfinityBits(const aNegative: Boolean): DWord; inline;
begin
  if aNegative then
    Exit(DWord($FF800000));
  Result := DWord($7F800000);
end;

function BuildDoubleInfinityBits(const aNegative: Boolean): QWord; inline;
begin
  if aNegative then
    Exit(QWord($FFF0000000000000));
  Result := QWord($7FF0000000000000);
end;

function SelectSingleSpecialArithmeticBits(
  const aLeftBits, aRightBits: DWord;
  const aLeftValue, aRightValue: Single;
  const aKind: TSimdBinaryArithmeticKind
): DWord; inline;
const
  CANONICAL_SINGLE_QNAN = DWord($7FC00000);
var
  LResult: Single;
begin
  if SimdIsNaN(aLeftValue) then
    Exit(aLeftBits);
  if SimdIsNaN(aRightValue) then
    Exit(aRightBits);

  case aKind of
    bakAdd:
      if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) and
        (((aLeftBits xor aRightBits) and DWord($80000000)) <> 0) then
        Exit(CANONICAL_SINGLE_QNAN);
    bakSub:
      if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) and
        (((aLeftBits xor aRightBits) and DWord($80000000)) = 0) then
        Exit(CANONICAL_SINGLE_QNAN);
    bakMul:
      if (SingleBitsIsZero(aLeftBits) and SimdIsInfinite(aRightValue)) or
        (SingleBitsIsZero(aRightBits) and SimdIsInfinite(aLeftValue)) then
        Exit(CANONICAL_SINGLE_QNAN);
  end;

  case aKind of
    bakAdd: LResult := aLeftValue + aRightValue;
    bakSub: LResult := aLeftValue - aRightValue;
  else
    LResult := aLeftValue * aRightValue;
  end;
  Move(LResult, Result, SizeOf(Result));
end;

function SelectDoubleSpecialArithmeticBits(
  const aLeftBits, aRightBits: QWord;
  const aLeftValue, aRightValue: Double;
  const aKind: TSimdBinaryArithmeticKind
): QWord; inline;
const
  CANONICAL_DOUBLE_QNAN = QWord($7FF8000000000000);
var
  LResult: Double;
begin
  if SimdIsNaN(aLeftValue) then
    Exit(aLeftBits);
  if SimdIsNaN(aRightValue) then
    Exit(aRightBits);

  case aKind of
    bakAdd:
      if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) and
        (((aLeftBits xor aRightBits) and QWord($8000000000000000)) <> 0) then
        Exit(CANONICAL_DOUBLE_QNAN);
    bakSub:
      if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) and
        (((aLeftBits xor aRightBits) and QWord($8000000000000000)) = 0) then
        Exit(CANONICAL_DOUBLE_QNAN);
    bakMul:
      if (DoubleBitsIsZero(aLeftBits) and SimdIsInfinite(aRightValue)) or
        (DoubleBitsIsZero(aRightBits) and SimdIsInfinite(aLeftValue)) then
        Exit(CANONICAL_DOUBLE_QNAN);
  end;

  case aKind of
    bakAdd: LResult := aLeftValue + aRightValue;
    bakSub: LResult := aLeftValue - aRightValue;
  else
    LResult := aLeftValue * aRightValue;
  end;
  Move(LResult, Result, SizeOf(Result));
end;

function BuildPackedSingleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do
    Result.m128i_u32[LLane] := SelectSingleSpecialArithmeticBits(
      a.m128i_u32[LLane],
      b.m128i_u32[LLane],
      a.m128_f32[LLane],
      b.m128_f32[LLane],
      aKind
    );
end;

function BuildPackedDoubleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 1 do
    Result.m128i_u64[LLane] := SelectDoubleSpecialArithmeticBits(
      a.m128i_u64[LLane],
      b.m128i_u64[LLane],
      a.m128d_f64[LLane],
      b.m128d_f64[LLane],
      aKind
    );
end;

function BuildScalarDoubleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; inline;
begin
  Result := a;
  Result.m128i_u64[0] := SelectDoubleSpecialArithmeticBits(
    a.m128i_u64[0],
    b.m128i_u64[0],
    a.m128d_f64[0],
    b.m128d_f64[0],
    aKind
  );
end;

function SelectSingleDivBits(
  const aLeftBits, aRightBits: DWord;
  const aLeftValue, aRightValue: Single
): DWord; inline;
const
  CANONICAL_SINGLE_QNAN = DWord($7FC00000);
var
  LNegative: Boolean;
  LResult: Single;
begin
  if SimdIsNaN(aLeftValue) then
    Exit(aLeftBits);
  if SimdIsNaN(aRightValue) then
    Exit(aRightBits);
  if SingleBitsIsZero(aRightBits) then
  begin
    if SingleBitsIsZero(aLeftBits) then
      Exit(CANONICAL_SINGLE_QNAN);
    LNegative := ((aLeftBits xor aRightBits) and DWord($80000000)) <> 0;
    Exit(BuildSingleInfinityBits(LNegative));
  end;
  if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) then
    Exit(CANONICAL_SINGLE_QNAN);
  LResult := aLeftValue / aRightValue;
  Move(LResult, Result, SizeOf(Result));
end;

function SelectDoubleDivBits(
  const aLeftBits, aRightBits: QWord;
  const aLeftValue, aRightValue: Double
): QWord; inline;
const
  CANONICAL_DOUBLE_QNAN = QWord($7FF8000000000000);
var
  LNegative: Boolean;
  LResult: Double;
begin
  if SimdIsNaN(aLeftValue) then
    Exit(aLeftBits);
  if SimdIsNaN(aRightValue) then
    Exit(aRightBits);
  if DoubleBitsIsZero(aRightBits) then
  begin
    if DoubleBitsIsZero(aLeftBits) then
      Exit(CANONICAL_DOUBLE_QNAN);
    LNegative := ((aLeftBits xor aRightBits) and QWord($8000000000000000)) <> 0;
    Exit(BuildDoubleInfinityBits(LNegative));
  end;
  if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) then
    Exit(CANONICAL_DOUBLE_QNAN);
  LResult := aLeftValue / aRightValue;
  Move(LResult, Result, SizeOf(Result));
end;

function BuildPackedSingleDiv(constref a, b: TM128): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do
    Result.m128i_u32[LLane] := SelectSingleDivBits(
      a.m128i_u32[LLane],
      b.m128i_u32[LLane],
      a.m128_f32[LLane],
      b.m128_f32[LLane]
    );
end;

function BuildPackedDoubleDiv(constref a, b: TM128): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 1 do
    Result.m128i_u64[LLane] := SelectDoubleDivBits(
      a.m128i_u64[LLane],
      b.m128i_u64[LLane],
      a.m128d_f64[LLane],
      b.m128d_f64[LLane]
    );
end;

function BuildScalarDoubleDiv(constref a, b: TM128): TM128; inline;
begin
  Result := a;
  Result.m128i_u64[0] := SelectDoubleDivBits(
    a.m128i_u64[0],
    b.m128i_u64[0],
    a.m128d_f64[0],
    b.m128d_f64[0]
  );
end;

function simd_div_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleDiv(a, b);
end;

function simd_sqrt_ps(constref a: TM128): TM128;
begin
  Result := BuildPackedSingleSqrt(a);
end;

function simd_add_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleSpecialArithmetic(a, b, bakAdd);
end;

function simd_sub_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleSpecialArithmetic(a, b, bakSub);
end;

function simd_mul_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleSpecialArithmetic(a, b, bakMul);
end;

function simd_div_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleDiv(a, b);
end;

function SelectSingleSqrtBits(const aBits: DWord; const aValue: Single): DWord; inline;
const
  CANONICAL_SINGLE_QNAN = DWord($7FC00000);
var
  LResult: Single;
begin
  if SimdIsNaN(aValue) then
    Exit(aBits);
  if aValue < 0 then
    Exit(CANONICAL_SINGLE_QNAN);
  LResult := Sqrt(aValue);
  Move(LResult, Result, SizeOf(Result));
end;

function SelectDoubleSqrtBits(const aBits: QWord; const aValue: Double): QWord; inline;
const
  CANONICAL_DOUBLE_QNAN = QWord($7FF8000000000000);
var
  LResult: Double;
begin
  if SimdIsNaN(aValue) then
    Exit(aBits);
  if aValue < 0 then
    Exit(CANONICAL_DOUBLE_QNAN);
  LResult := Sqrt(aValue);
  Move(LResult, Result, SizeOf(Result));
end;

function BuildPackedSingleSqrt(constref a: TM128): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do
    Result.m128i_u32[LLane] := SelectSingleSqrtBits(
      a.m128i_u32[LLane],
      a.m128_f32[LLane]
    );
end;

function BuildPackedDoubleSqrt(constref a: TM128): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 1 do
    Result.m128i_u64[LLane] := SelectDoubleSqrtBits(
      a.m128i_u64[LLane],
      a.m128d_f64[LLane]
    );
end;

function BuildScalarDoubleSqrt(constref a, b: TM128): TM128; inline;
begin
  Result := a;
  Result.m128i_u64[0] := SelectDoubleSqrtBits(
    b.m128i_u64[0],
    b.m128d_f64[0]
  );
end;

function simd_sqrt_pd(constref a: TM128): TM128;
begin
  Result := BuildPackedDoubleSqrt(a);
end;

// === 5️⃣ Logical Operations 剩余实现 ===
function simd_or_si128(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; por xmm0, xmm1  // Bitwise OR across the 128-bit vector.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; por xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; por xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_xor_si128(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pxor xmm0, xmm1  // 128位逻辑异或
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pxor xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pxor xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_andnot_si128(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pandn xmm0, xmm1  // 128位逻辑与非 (~a & b)
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pandn xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pandn xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === 6️⃣ Compare / Mask 剩余实现 ===
function simd_cmpeq_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pcmpeqw xmm0, xmm1  // Compare 16-bit integer lanes for equality.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pcmpeqw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pcmpeqw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmpeq_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pcmpeqd xmm0, xmm1  // Compare 32-bit integer lanes for equality.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pcmpeqd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pcmpeqd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmpgt_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pcmpgtb xmm0, xmm1  // Signed greater-than compare on 8-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pcmpgtb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pcmpgtb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmpgt_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pcmpgtw xmm0, xmm1  // Signed greater-than compare on 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pcmpgtw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pcmpgtw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmpgt_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pcmpgtd xmm0, xmm1  // Signed greater-than compare on 32-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pcmpgtd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pcmpgtd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === 否定比较函数实现 ===
function simd_cmpnlt_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckNlt);
end;

function simd_cmpnle_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckNle);
end;

function simd_cmpngt_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckNgt);
end;

function simd_cmpnge_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckNge);
end;

function simd_cmplt_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rdx]; movdqu xmm1, [rcx]; pcmpgtb xmm0, xmm1  // 小于 = 交换操作数的大于
  {$ELSE}
    movdqu xmm0, [rsi]; movdqu xmm1, [rdi]; pcmpgtb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [edx]; movdqu xmm1, [eax]; pcmpgtb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmplt_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rdx]; movdqu xmm1, [rcx]; pcmpgtw xmm0, xmm1  // 小于 = 交换操作数的大于
  {$ELSE}
    movdqu xmm0, [rsi]; movdqu xmm1, [rdi]; pcmpgtw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [edx]; movdqu xmm1, [eax]; pcmpgtw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cmplt_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rdx]; movdqu xmm1, [rcx]; pcmpgtd xmm0, xmm1  // 小于 = 交换操作数的大于
  {$ELSE}
    movdqu xmm0, [rsi]; movdqu xmm1, [rdi]; pcmpgtd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [edx]; movdqu xmm1, [eax]; pcmpgtd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === Double-precision comparison helpers ===
function simd_cmpeq_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckEq);
end;

function simd_cmplt_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckLt);
end;

function simd_cmple_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckLe);
end;

function simd_cmpgt_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckGt);
end;

function simd_cmpge_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckGe);
end;

function simd_cmpneq_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckNe);
end;

// Move mask support lives in the assembler version above.
// === 7️⃣ Shuffle / Unpack / Permute 实现 ===
function simd_shuffle_epi32(constref a: TM128; imm8: Byte): TM128;
var
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do
    Result.m128i_i32[LIndex] := a.m128i_i32[(imm8 shr (LIndex * 2)) and $3];
end;

function simd_shuffle_pd(constref a, b: TM128; imm8: Byte): TM128;
begin
  Result.m128d_f64[0] := a.m128d_f64[imm8 and $1];
  Result.m128d_f64[1] := b.m128d_f64[(imm8 shr 1) and $1];
end;

function simd_shuffle_ps(constref a, b: TM128; imm8: Byte): TM128;
begin
  Result.m128_f32[0] := a.m128_f32[imm8 and $3];
  Result.m128_f32[1] := a.m128_f32[(imm8 shr 2) and $3];
  Result.m128_f32[2] := b.m128_f32[(imm8 shr 4) and $3];
  Result.m128_f32[3] := b.m128_f32[(imm8 shr 6) and $3];
end;

function simd_shufflelo_epi16(constref a: TM128; imm8: Byte): TM128;
var
  LIndex: Integer;
begin
  Result := a;
  for LIndex := 0 to 3 do
    Result.m128i_u16[LIndex] := a.m128i_u16[(imm8 shr (LIndex * 2)) and $3];
end;

function simd_shufflehi_epi16(constref a: TM128; imm8: Byte): TM128;
var
  LIndex: Integer;
begin
  Result := a;
  for LIndex := 0 to 3 do
    Result.m128i_u16[4 + LIndex] := a.m128i_u16[4 + ((imm8 shr (LIndex * 2)) and $3)];
end;

function simd_unpacklo_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpcklbw xmm0, xmm1  // Interleave the low byte lanes.
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpcklbw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpcklbw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpackhi_epi8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpckhbw xmm0, xmm1  // Interleave the high byte lanes.
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpckhbw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpckhbw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpacklo_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpcklwd xmm0, xmm1  // Interleave the low 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpcklwd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpcklwd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpackhi_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpckhwd xmm0, xmm1  // Interleave the high 16-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpckhwd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpckhwd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpacklo_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpckldq xmm0, xmm1  // Interleave the low 32-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpckldq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpckldq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpackhi_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpckhdq xmm0, xmm1  // Interleave the high 32-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpckhdq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpckhdq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpacklo_epi64(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpcklqdq xmm0, xmm1  // Interleave the low 64-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpcklqdq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpcklqdq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpackhi_epi64(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; punpckhqdq xmm0, xmm1  // Interleave the high 64-bit lanes.
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; punpckhqdq xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; punpckhqdq xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpacklo_pd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movupd xmm1, [rdx]; unpcklpd xmm0, xmm1  // 低双精度解包
  {$ELSE}
    movupd xmm0, [rdi]; movupd xmm1, [rsi]; unpcklpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movupd xmm1, [edx]; unpcklpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpackhi_pd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movupd xmm1, [rdx]; unpckhpd xmm0, xmm1  // 高双精度解包
  {$ELSE}
    movupd xmm0, [rdi]; movupd xmm1, [rsi]; unpckhpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movupd xmm1, [edx]; unpckhpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === 8️⃣ Shift / Rotate 实现 ===
function simd_slli_epi16(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    cmp dl, 16; jae @zero // 如果移位 >= 16，结果为 0
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx        // Load the shift amount.
    psllw xmm0, xmm1      // Shift 16-bit lanes left.
    jmp @done
@zero:
    pxor xmm0, xmm0       // 清零
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 16; jae @zero
    cmp sil, 0; je @done
    movd xmm1, esi
    psllw xmm0, xmm1
    jmp @done
@zero:
    pxor xmm0, xmm0
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]
    movdqu xmm0, [eax]
    cmp dl, 16; jae @zero
    cmp dl, 0; je @done
    movd xmm1, edx; psllw xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_slli_epi32(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 32; jae @zero // 如果移位 >= 32，结果为 0
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; pslld xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 32; jae @zero
    cmp sil, 0; je @done
    movd xmm1, esi; pslld xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 32; jae @zero
    cmp dl, 0; je @done
    movd xmm1, edx; pslld xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_slli_epi64(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 64; jae @zero // 如果移位 >= 64，结果为 0
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; psllq xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 64; jae @zero
    cmp sil, 0; je @done
    movd xmm1, esi; psllq xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 64; jae @zero
    cmp dl, 0; je @done
    movd xmm1, edx; psllq xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_srli_epi16(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 16; jae @zero // 如果移位 >= 16，结果为 0
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; psrlw xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 16; jae @zero
    cmp sil, 0; je @done
    movd xmm1, esi; psrlw xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 16; jae @zero
    cmp dl, 0; je @done
    movd xmm1, edx; psrlw xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_srli_epi32(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 32; jae @zero // 如果移位 >= 32，结果为 0
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; psrld xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 32; jae @zero
    cmp sil, 0; je @done
    movd xmm1, esi; psrld xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 32; jae @zero
    cmp dl, 0; je @done
    movd xmm1, edx; psrld xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_srli_epi64(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 64; jae @zero // 如果移位 >= 64，结果为 0
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; psrlq xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 64; jae @zero
    cmp sil, 0; je @done
    movd xmm1, esi; psrlq xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 64; jae @zero
    cmp dl, 0; je @done
    movd xmm1, edx; psrlq xmm0, xmm1; jmp @done
@zero: pxor xmm0, xmm0
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_srai_epi16(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 16; jae @max // If the shift is too large, saturate to the sign-filled result.
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; psraw xmm0, xmm1; jmp @done
@max:
    psraw xmm0, 15       // Saturate to the sign-filled result.
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 16; jae @max
    cmp sil, 0; je @done
    movd xmm1, esi; psraw xmm0, xmm1; jmp @done
@max: psraw xmm0, 15
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 16; jae @max
    cmp dl, 0; je @done
    movd xmm1, edx; psraw xmm0, xmm1; jmp @done
@max: psraw xmm0, 15
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_srai_epi32(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]
    cmp dl, 32; jae @max // If the shift is too large, saturate to the sign-filled result.
    cmp dl, 0; je @done // If the shift is zero, keep the value unchanged.
    movd xmm1, edx; psrad xmm0, xmm1; jmp @done
@max:
    psrad xmm0, 31       // Saturate to the sign-filled result.
@done:
  {$ELSE}
    movdqu xmm0, [rdi]
    cmp sil, 32; jae @max
    cmp sil, 0; je @done
    movd xmm1, esi; psrad xmm0, xmm1; jmp @done
@max: psrad xmm0, 31
@done:
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]
    cmp dl, 32; jae @max
    cmp dl, 0; je @done
    movd xmm1, edx; psrad xmm0, xmm1; jmp @done
@max: psrad xmm0, 31
@done:
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

  // === 字节级移位函数实现 ===
  function simd_slli_si128(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
  {$ENDIF}
  asm
  {$IFDEF CPUX86_64}
    {$IFDEF WINDOWS}
      movdqu xmm0, [rcx]
      cmp dl, 0; je @done
      cmp dl, 16; jae @zero
      cmp dl, 1; je @s1
      cmp dl, 2; je @s2
      cmp dl, 3; je @s3
      cmp dl, 4; je @s4
      cmp dl, 5; je @s5
      cmp dl, 6; je @s6
      cmp dl, 7; je @s7
      cmp dl, 8; je @s8
      cmp dl, 9; je @s9
      cmp dl, 10; je @s10
      cmp dl, 11; je @s11
      cmp dl, 12; je @s12
      cmp dl, 13; je @s13
      cmp dl, 14; je @s14
      cmp dl, 15; je @s15
      jmp @zero
  @s1: pslldq xmm0, 1; jmp @done
  @s2: pslldq xmm0, 2; jmp @done
  @s3: pslldq xmm0, 3; jmp @done
  @s4: pslldq xmm0, 4; jmp @done
  @s5: pslldq xmm0, 5; jmp @done
  @s6: pslldq xmm0, 6; jmp @done
  @s7: pslldq xmm0, 7; jmp @done
  @s8: pslldq xmm0, 8; jmp @done
  @s9: pslldq xmm0, 9; jmp @done
  @s10: pslldq xmm0, 10; jmp @done
  @s11: pslldq xmm0, 11; jmp @done
  @s12: pslldq xmm0, 12; jmp @done
  @s13: pslldq xmm0, 13; jmp @done
  @s14: pslldq xmm0, 14; jmp @done
  @s15: pslldq xmm0, 15; jmp @done
  @zero:
      pxor xmm0, xmm0
  @done:
    {$ELSE}
      movdqu xmm0, [rdi]
      cmp sil, 0; je @done
      cmp sil, 16; jae @zero
      cmp sil, 1; je @s1
      cmp sil, 2; je @s2
      cmp sil, 3; je @s3
      cmp sil, 4; je @s4
      cmp sil, 5; je @s5
      cmp sil, 6; je @s6
      cmp sil, 7; je @s7
      cmp sil, 8; je @s8
      cmp sil, 9; je @s9
      cmp sil, 10; je @s10
      cmp sil, 11; je @s11
      cmp sil, 12; je @s12
      cmp sil, 13; je @s13
      cmp sil, 14; je @s14
      cmp sil, 15; je @s15
      jmp @zero
  @s1: pslldq xmm0, 1; jmp @done
  @s2: pslldq xmm0, 2; jmp @done
  @s3: pslldq xmm0, 3; jmp @done
  @s4: pslldq xmm0, 4; jmp @done
  @s5: pslldq xmm0, 5; jmp @done
  @s6: pslldq xmm0, 6; jmp @done
  @s7: pslldq xmm0, 7; jmp @done
  @s8: pslldq xmm0, 8; jmp @done
  @s9: pslldq xmm0, 9; jmp @done
  @s10: pslldq xmm0, 10; jmp @done
  @s11: pslldq xmm0, 11; jmp @done
  @s12: pslldq xmm0, 12; jmp @done
  @s13: pslldq xmm0, 13; jmp @done
  @s14: pslldq xmm0, 14; jmp @done
  @s15: pslldq xmm0, 15; jmp @done
  @zero:
      pxor xmm0, xmm0
  @done:
    {$ENDIF}
  {$ELSEIF CPUX86}
      mov eax, [esp + 4]; mov edx, [esp + 8]
      movdqu xmm0, [eax]
      cmp dl, 0; je @done
      cmp dl, 16; jae @zero
      cmp dl, 1; je @s1
      cmp dl, 2; je @s2
      cmp dl, 3; je @s3
      cmp dl, 4; je @s4
      cmp dl, 5; je @s5
      cmp dl, 6; je @s6
      cmp dl, 7; je @s7
      cmp dl, 8; je @s8
      cmp dl, 9; je @s9
      cmp dl, 10; je @s10
      cmp dl, 11; je @s11
      cmp dl, 12; je @s12
      cmp dl, 13; je @s13
      cmp dl, 14; je @s14
      cmp dl, 15; je @s15
      jmp @zero
  @s1: pslldq xmm0, 1; jmp @done
  @s2: pslldq xmm0, 2; jmp @done
  @s3: pslldq xmm0, 3; jmp @done
  @s4: pslldq xmm0, 4; jmp @done
  @s5: pslldq xmm0, 5; jmp @done
  @s6: pslldq xmm0, 6; jmp @done
  @s7: pslldq xmm0, 7; jmp @done
  @s8: pslldq xmm0, 8; jmp @done
  @s9: pslldq xmm0, 9; jmp @done
  @s10: pslldq xmm0, 10; jmp @done
  @s11: pslldq xmm0, 11; jmp @done
  @s12: pslldq xmm0, 12; jmp @done
  @s13: pslldq xmm0, 13; jmp @done
  @s14: pslldq xmm0, 14; jmp @done
  @s15: pslldq xmm0, 15; jmp @done
  @zero:
      pxor xmm0, xmm0
  @done:
  {$ELSE}
      {$ERROR Unsupported CPU}
  {$ENDIF}
  {$IFDEF CPUX86_64}
    movq rax, xmm0
    movdqa xmm1, xmm0
    psrldq xmm1, 8
    movq rdx, xmm1
  {$ENDIF}
  end;

  function simd_srli_si128(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
  {$ENDIF}
  asm
  {$IFDEF CPUX86_64}
    {$IFDEF WINDOWS}
      movdqu xmm0, [rcx]
      cmp dl, 0; je @done
      cmp dl, 16; jae @zero
      cmp dl, 1; je @s1
      cmp dl, 2; je @s2
      cmp dl, 3; je @s3
      cmp dl, 4; je @s4
      cmp dl, 5; je @s5
      cmp dl, 6; je @s6
      cmp dl, 7; je @s7
      cmp dl, 8; je @s8
      cmp dl, 9; je @s9
      cmp dl, 10; je @s10
      cmp dl, 11; je @s11
      cmp dl, 12; je @s12
      cmp dl, 13; je @s13
      cmp dl, 14; je @s14
      cmp dl, 15; je @s15
      jmp @zero
  @s1: psrldq xmm0, 1; jmp @done
  @s2: psrldq xmm0, 2; jmp @done
  @s3: psrldq xmm0, 3; jmp @done
  @s4: psrldq xmm0, 4; jmp @done
  @s5: psrldq xmm0, 5; jmp @done
  @s6: psrldq xmm0, 6; jmp @done
  @s7: psrldq xmm0, 7; jmp @done
  @s8: psrldq xmm0, 8; jmp @done
  @s9: psrldq xmm0, 9; jmp @done
  @s10: psrldq xmm0, 10; jmp @done
  @s11: psrldq xmm0, 11; jmp @done
  @s12: psrldq xmm0, 12; jmp @done
  @s13: psrldq xmm0, 13; jmp @done
  @s14: psrldq xmm0, 14; jmp @done
  @s15: psrldq xmm0, 15; jmp @done
  @zero:
      pxor xmm0, xmm0
  @done:
    {$ELSE}
      movdqu xmm0, [rdi]
      cmp sil, 0; je @done
      cmp sil, 16; jae @zero
      cmp sil, 1; je @s1
      cmp sil, 2; je @s2
      cmp sil, 3; je @s3
      cmp sil, 4; je @s4
      cmp sil, 5; je @s5
      cmp sil, 6; je @s6
      cmp sil, 7; je @s7
      cmp sil, 8; je @s8
      cmp sil, 9; je @s9
      cmp sil, 10; je @s10
      cmp sil, 11; je @s11
      cmp sil, 12; je @s12
      cmp sil, 13; je @s13
      cmp sil, 14; je @s14
      cmp sil, 15; je @s15
      jmp @zero
  @s1: psrldq xmm0, 1; jmp @done
  @s2: psrldq xmm0, 2; jmp @done
  @s3: psrldq xmm0, 3; jmp @done
  @s4: psrldq xmm0, 4; jmp @done
  @s5: psrldq xmm0, 5; jmp @done
  @s6: psrldq xmm0, 6; jmp @done
  @s7: psrldq xmm0, 7; jmp @done
  @s8: psrldq xmm0, 8; jmp @done
  @s9: psrldq xmm0, 9; jmp @done
  @s10: psrldq xmm0, 10; jmp @done
  @s11: psrldq xmm0, 11; jmp @done
  @s12: psrldq xmm0, 12; jmp @done
  @s13: psrldq xmm0, 13; jmp @done
  @s14: psrldq xmm0, 14; jmp @done
  @s15: psrldq xmm0, 15; jmp @done
  @zero:
      pxor xmm0, xmm0
  @done:
    {$ENDIF}
  {$ELSEIF CPUX86}
      mov eax, [esp + 4]; mov edx, [esp + 8]
      movdqu xmm0, [eax]
      cmp dl, 0; je @done
      cmp dl, 16; jae @zero
      cmp dl, 1; je @s1
      cmp dl, 2; je @s2
      cmp dl, 3; je @s3
      cmp dl, 4; je @s4
      cmp dl, 5; je @s5
      cmp dl, 6; je @s6
      cmp dl, 7; je @s7
      cmp dl, 8; je @s8
      cmp dl, 9; je @s9
      cmp dl, 10; je @s10
      cmp dl, 11; je @s11
      cmp dl, 12; je @s12
      cmp dl, 13; je @s13
      cmp dl, 14; je @s14
      cmp dl, 15; je @s15
      jmp @zero
  @s1: psrldq xmm0, 1; jmp @done
  @s2: psrldq xmm0, 2; jmp @done
  @s3: psrldq xmm0, 3; jmp @done
  @s4: psrldq xmm0, 4; jmp @done
  @s5: psrldq xmm0, 5; jmp @done
  @s6: psrldq xmm0, 6; jmp @done
  @s7: psrldq xmm0, 7; jmp @done
  @s8: psrldq xmm0, 8; jmp @done
  @s9: psrldq xmm0, 9; jmp @done
  @s10: psrldq xmm0, 10; jmp @done
  @s11: psrldq xmm0, 11; jmp @done
  @s12: psrldq xmm0, 12; jmp @done
  @s13: psrldq xmm0, 13; jmp @done
  @s14: psrldq xmm0, 14; jmp @done
  @s15: psrldq xmm0, 15; jmp @done
  @zero:
      pxor xmm0, xmm0
  @done:
  {$ELSE}
      {$ERROR Unsupported CPU}
  {$ENDIF}
  {$IFDEF CPUX86_64}
    movq rax, xmm0
    movdqa xmm1, xmm0
    psrldq xmm1, 8
    movq rdx, xmm1
  {$ENDIF}
  end;

function ConvertSingleToInt32Nearest(const aValue: Single): LongInt; inline;
begin
  if SimdIsNaN(aValue) or SimdIsInfinite(aValue) or
     (aValue < -2147483648.5) or (aValue >= 2147483647.5) then
    Exit(LongInt($80000000));

  Result := LongInt(Round(aValue));
end;

function ConvertSingleToInt32Trunc(const aValue: Single): LongInt; inline;
begin
  if SimdIsNaN(aValue) or SimdIsInfinite(aValue) or
     (aValue <= -2147483649.0) or (aValue >= 2147483648.0) then
    Exit(LongInt($80000000));

  Result := LongInt(Trunc(aValue));
end;

function ConvertDoubleToInt32Nearest(const aValue: Double): LongInt; inline;
begin
  if SimdIsNaN(aValue) or SimdIsInfinite(aValue) or
     (aValue < -2147483648.5) or (aValue >= 2147483647.5) then
    Exit(LongInt($80000000));

  Result := LongInt(Round(aValue));
end;

function ConvertDoubleToInt32Trunc(const aValue: Double): LongInt; inline;
begin
  if SimdIsNaN(aValue) or SimdIsInfinite(aValue) or
     (aValue <= -2147483649.0) or (aValue >= 2147483648.0) then
    Exit(LongInt($80000000));

  Result := LongInt(Trunc(aValue));
end;

function ConvertDoubleToInt64Nearest(const aValue: Double): Int64; inline;
begin
  if SimdIsNaN(aValue) or SimdIsInfinite(aValue) or
     (aValue < -9223372036854775808.0) or (aValue >= 9223372036854775808.0) then
    Exit(Int64(QWord($8000000000000000)));

  Result := Round(aValue);
end;

function ConvertDoubleToInt64Trunc(const aValue: Double): Int64; inline;
begin
  if SimdIsNaN(aValue) or SimdIsInfinite(aValue) or
     (aValue < -9223372036854775808.0) or (aValue >= 9223372036854775808.0) then
    Exit(Int64(QWord($8000000000000000)));

  Result := Trunc(aValue);
end;

function BuildPackedSingleToInt32Nearest(constref a: TM128): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do
    Result.m128i_i32[LLane] := ConvertSingleToInt32Nearest(a.m128_f32[LLane]);
end;

function BuildPackedSingleToInt32Trunc(constref a: TM128): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do
    Result.m128i_i32[LLane] := ConvertSingleToInt32Trunc(a.m128_f32[LLane]);
end;

function BuildPackedDoubleToInt32Nearest(constref a: TM128): TM128; inline;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.m128i_i32[0] := ConvertDoubleToInt32Nearest(a.m128d_f64[0]);
  Result.m128i_i32[1] := ConvertDoubleToInt32Nearest(a.m128d_f64[1]);
end;

function BuildPackedDoubleToInt32Trunc(constref a: TM128): TM128; inline;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.m128i_i32[0] := ConvertDoubleToInt32Trunc(a.m128d_f64[0]);
  Result.m128i_i32[1] := ConvertDoubleToInt32Trunc(a.m128d_f64[1]);
end;

function ConvertDoubleToSingleBits(const aBits: QWord; const aValue: Double): DWord; inline;
const
  MAX_SINGLE_AS_DOUBLE = 3.4028234663852886e38;
var
  LSingle: Single;
begin
  if SimdIsNaN(aValue) then
  begin
    if (aBits and QWord($8000000000000000)) <> 0 then
      Exit(DWord($FFC00000));
    Exit(DWord($7FC00000));
  end;

  if SimdIsInfinite(aValue) or (aValue > MAX_SINGLE_AS_DOUBLE) or (aValue < -MAX_SINGLE_AS_DOUBLE) then
  begin
    if (aBits and QWord($8000000000000000)) <> 0 then
      Exit(DWord($FF800000));
    Exit(DWord($7F800000));
  end;

  LSingle := Single(aValue);
  Move(LSingle, Result, SizeOf(Result));
end;

function BuildPackedDoubleToSingle(constref a: TM128): TM128; inline;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.m128i_u32[0] := ConvertDoubleToSingleBits(a.m128i_u64[0], a.m128d_f64[0]);
  Result.m128i_u32[1] := ConvertDoubleToSingleBits(a.m128i_u64[1], a.m128d_f64[1]);
end;

function BuildScalarDoubleToSingle(constref a, b: TM128): TM128; inline;
begin
  Result := a;
  Result.m128i_u32[0] := ConvertDoubleToSingleBits(b.m128i_u64[0], b.m128d_f64[0]);
end;

// === 9️⃣ Conversion / Cast 实现 ===
function simd_cvtepi32_pd(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    cvtdq2pd xmm0, xmm0   // Convert 32-bit integers to double-precision lanes.
    {$ELSE}
    movdqu xmm0, [rdi]
    cvtdq2pd xmm0, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // a
    movdqu xmm0, [eax]
    cvtdq2pd xmm0, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtpd_epi32(constref a: TM128): TM128;
begin
  Result := BuildPackedDoubleToInt32Nearest(a);
end;

function simd_cvtepi32_ps(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    cvtdq2ps xmm0, xmm0   // Convert 32-bit integers to single-precision lanes.
    {$ELSE}
    movdqu xmm0, [rdi]
    cvtdq2ps xmm0, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // a
    movdqu xmm0, [eax]
    cvtdq2ps xmm0, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtps_epi32(constref a: TM128): TM128;
begin
  Result := BuildPackedSingleToInt32Nearest(a);
end;

function simd_cvtsi32_si128(a: Integer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movd xmm0, ecx        // Insert the 32-bit integer into the low lane of the 128-bit value.
  {$ELSE}
    movd xmm0, edi        // Linux/macOS x64
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // a
    movd xmm0, eax
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtsi64_si128(a: Int64): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movq xmm0, rcx        // Insert the 64-bit integer into the low lane of the 128-bit value.
  {$ELSE}
    movq xmm0, rdi        // Linux/macOS x64
  {$ENDIF}
{$ELSEIF CPUX86}
    movq xmm0, [esp + 4]  // 64位参数在栈上
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtsi128_si32(constref a: TM128): Integer; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    movd eax, xmm0        // Extract the low 32-bit lane.
    {$ELSE}
    movdqu xmm0, [rdi]
    movd eax, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov edx, [esp + 4]    // a
    movdqu xmm0, [edx]
    movd eax, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

function simd_cvtsi128_si64(constref a: TM128): Int64; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    movq rax, xmm0        // Extract the low 64-bit lane.
    {$ELSE}
    movdqu xmm0, [rdi]
    movq rax, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov edx, [esp + 4]    // a
    movdqu xmm0, [edx]
    movq [esp + 8], xmm0  // Write the 64-bit return value back to the caller frame.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

// === 浮点精度转换函数 ===
function simd_cvtpd_ps(constref a: TM128): TM128;
begin
  Result := BuildPackedDoubleToSingle(a);
end;

function simd_cvtps_pd(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rcx]    // 加载 a
    cvtps2pd xmm0, xmm0   // Convert singles to double-precision lanes.
    {$ELSE}
    movups xmm0, [rdi]
    cvtps2pd xmm0, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // a
    movups xmm0, [eax]
    cvtps2pd xmm0, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === 截断转换函数 ===
function simd_cvttps_epi32(constref a: TM128): TM128;
begin
  Result := BuildPackedSingleToInt32Trunc(a);
end;

function simd_cvttpd_epi32(constref a: TM128): TM128;
begin
  Result := BuildPackedDoubleToInt32Trunc(a);
end;

// 重复的转换和 Cast 函数实现已删除，保留汇编版本

// === 新添加函数的占位实现 ===

// Load/store helper additions.
function simd_loadl_epi64(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    pxor xmm0, xmm0
    movq xmm0, [rcx]
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    pxor xmm0, xmm0
    movq xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: the pointer argument arrives on the stack.
    mov eax, [esp + 4]
    pxor xmm0, xmm0
    movq xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_storel_epi64(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx.
    movq xmm0, [rdx] // Load the low 64 bits from the source value.
    movq [rcx], xmm0      // Store the low 64 bits to the destination.
  {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi.
    movq xmm0, [rsi] // Load the low 64 bits from the source value.
    movq [rdi], xmm0      // Store the low 64 bits to the destination.
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movq xmm0, [edx] // Load the low 64 bits from the source value.
    movq [eax], xmm0      // Store the low 64 bits to the destination.
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_maskmoveu_si128(constref Src: TM128; constref Mask: TM128; var Dest); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Src in rcx, Mask in rdx, Dest in r8
    movdqu xmm0, [rcx] // Src is a constref parameter and need not be aligned.
    movdqu xmm1, [rdx]    // Mask is a constref parameter and need not be aligned.
    push rdi              // Save rdi before reusing it for maskmovdqu.
    mov rdi, r8           // The destination pointer must be placed in rdi.
    maskmovdqu xmm0, xmm1
    pop rdi               // Restore rdi.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Src in rdi, Mask in rsi, Dest in rdx
    push rdi              // Save the original rdi value.
    movdqu xmm0, [rdi] // Src is a constref parameter and need not be aligned.
    movdqu xmm1, [rsi]    // Mask is a constref parameter and need not be aligned.
    mov rdi, rdx
    // The destination pointer must be placed in rdi.
    maskmovdqu xmm0, xmm1
    pop rdi               // Restore the original rdi value.
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]    // Src
    mov edx, [esp + 8]    // Mask
    push edi              // Save edi before reusing it for the destination pointer.
    mov edi, [esp + 16]   // Dest after the push-adjusted stack offset.
    movdqu xmm0, [eax]
    movdqu xmm1, [edx]
    maskmovdqu xmm0, xmm1 // Conditionally store bytes to [edi].
    pop edi               // Restore edi.
    {$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

function simd_loadr_pd(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movupd xmm0, [rcx]     // 加载两个双精度数
    shufpd xmm0, xmm0, 1   // Swap the low and high double lanes.
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movupd xmm0, [rdi]     // 加载两个双精度数
    shufpd xmm0, xmm0, 1   // Swap the low and high double lanes.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: the pointer argument arrives on the stack.
    mov eax, [esp + 4]
    movupd xmm0, [eax]
    shufpd xmm0, xmm0, 1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_storer_pd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx.
    movupd xmm0, [rdx] // Src is a constref parameter and need not be aligned.
    shufpd xmm0, xmm0, 1 // Swap the low and high double lanes.
    movupd [rcx], xmm0     // Store the reordered vector.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi.
    movupd xmm0, [rsi] // Src is a constref parameter and need not be aligned.
    shufpd xmm0, xmm0, 1 // Swap the low and high double lanes.
    movupd [rdi], xmm0     // Store the reordered vector.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]     // Dest
    mov edx, [esp + 8]     // Src
    movupd xmm0, [edx]
    shufpd xmm0, xmm0, 1
    movupd [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

function simd_loadh_pd(constref A: TM128; const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: A in rcx, Ptr in rdx.
    movupd xmm0, [rcx]     // A is a constref parameter and need not be aligned.
    movhpd xmm0, [rdx]     // Replace the high double lane from Ptr.
    {$ELSE}
    // Linux/macOS x64 System V ABI: A in rdi, Ptr in rsi.
    movupd xmm0, [rdi]     // A is a constref parameter and need not be aligned.
    movhpd xmm0, [rsi]     // Replace the high double lane from Ptr.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]     // A
    mov edx, [esp + 8]     // Ptr
    movupd xmm0, [eax]
    movhpd xmm0, [edx]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_loadl_pd(constref A: TM128; const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: A in rcx, Ptr in rdx.
    movupd xmm0, [rcx]     // A is a constref parameter and need not be aligned.
    movlpd xmm0, [rdx]     // Replace the low double lane from Ptr.
    {$ELSE}
    // Linux/macOS x64 System V ABI: A in rdi, Ptr in rsi.
    movupd xmm0, [rdi]     // A is a constref parameter and need not be aligned.
    movlpd xmm0, [rsi]     // Replace the low double lane from Ptr.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]     // A
    mov edx, [esp + 8]     // Ptr
    movupd xmm0, [eax]
    movlpd xmm0, [edx]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_storeh_pd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx.
    movupd xmm0, [rdx]     // Src is a constref parameter and need not be aligned.
    movhpd [rcx], xmm0     // Store the high double lane to the destination.
  {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi.
    movupd xmm0, [rsi]     // Src is a constref parameter and need not be aligned.
    movhpd [rdi], xmm0     // Store the high double lane to the destination.
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]     // Dest
    mov edx, [esp + 8]     // Src
    movupd xmm0, [edx]
    movhpd [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_storel_pd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx.
    movupd xmm0, [rdx]     // Src is a constref parameter and need not be aligned.
    movlpd [rcx], xmm0     // Store the low double lane to the destination.
  {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi.
    movupd xmm0, [rsi]     // Src is a constref parameter and need not be aligned.
    movlpd [rdi], xmm0     // Store the low double lane to the destination.
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]     // Dest
    mov edx, [esp + 8]     // Src
    movupd xmm0, [edx]
    movlpd [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

function simd_load_sd(const Ptr: Pointer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: 第一个参数在 rcx
    movsd xmm0, [rcx]      // 加载标量双精度，高位自动清零
  {$ELSE}
    // Linux/macOS x64 System V ABI: 第一个参数在 rdi
    movsd xmm0, [rdi]      // 加载标量双精度，高位自动清零
  {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: the pointer argument arrives on the stack.
    mov eax, [esp + 4]
    movsd xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

procedure simd_store_sd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    // Windows x64: Dest in rcx, Src in rdx.
    movupd xmm0, [rdx] // Src is a constref parameter and need not be aligned.
    movsd [rcx], xmm0      // Store the scalar double to the destination.
    {$ELSE}
    // Linux/macOS x64 System V ABI: Dest in rdi, Src in rsi.
    movupd xmm0, [rsi] // Src is a constref parameter and need not be aligned.
    movsd [rdi], xmm0      // Store the scalar double to the destination.
    {$ENDIF}
{$ELSEIF CPUX86}
    // x86 32-bit: arguments arrive on the stack.
    mov eax, [esp + 4]     // Dest
    mov edx, [esp + 8]     // Src
    movupd xmm0, [edx]
    movsd [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

// New set helpers.
function simd_set_epi8(a15, a14, a13, a12, a11, a10, a9, a8, a7, a6, a5, a4, a3, a2, a1, a0: ShortInt): TM128;
begin
  Result.m128i_i8[0] := a0; Result.m128i_i8[1] := a1; Result.m128i_i8[2] := a2; Result.m128i_i8[3] := a3;
  Result.m128i_i8[4] := a4; Result.m128i_i8[5] := a5; Result.m128i_i8[6] := a6; Result.m128i_i8[7] := a7;
  Result.m128i_i8[8] := a8; Result.m128i_i8[9] := a9; Result.m128i_i8[10] := a10; Result.m128i_i8[11] := a11;
  Result.m128i_i8[12] := a12; Result.m128i_i8[13] := a13; Result.m128i_i8[14] := a14; Result.m128i_i8[15] := a15;
end;

function simd_setr_epi8(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15: ShortInt): TM128;
begin
  Result.m128i_i8[0] := a0; Result.m128i_i8[1] := a1; Result.m128i_i8[2] := a2; Result.m128i_i8[3] := a3;
  Result.m128i_i8[4] := a4; Result.m128i_i8[5] := a5; Result.m128i_i8[6] := a6; Result.m128i_i8[7] := a7;
  Result.m128i_i8[8] := a8; Result.m128i_i8[9] := a9; Result.m128i_i8[10] := a10; Result.m128i_i8[11] := a11;
  Result.m128i_i8[12] := a12; Result.m128i_i8[13] := a13; Result.m128i_i8[14] := a14; Result.m128i_i8[15] := a15;
end;

function simd_set_epi16(a7, a6, a5, a4, a3, a2, a1, a0: SmallInt): TM128;
begin
  Result.m128i_i16[0] := a0; Result.m128i_i16[1] := a1; Result.m128i_i16[2] := a2; Result.m128i_i16[3] := a3;
  Result.m128i_i16[4] := a4; Result.m128i_i16[5] := a5; Result.m128i_i16[6] := a6; Result.m128i_i16[7] := a7;
end;

function simd_setr_epi16(a0, a1, a2, a3, a4, a5, a6, a7: SmallInt): TM128;
begin
  Result.m128i_i16[0] := a0; Result.m128i_i16[1] := a1; Result.m128i_i16[2] := a2; Result.m128i_i16[3] := a3;
  Result.m128i_i16[4] := a4; Result.m128i_i16[5] := a5; Result.m128i_i16[6] := a6; Result.m128i_i16[7] := a7;
end;

function simd_set_epi64(a, b: Int64): TM128;
begin
  Result.m128i_i64[0] := b; Result.m128i_i64[1] := a;
end;

function simd_setr_epi64(a, b: Int64): TM128;
begin
  Result.m128i_i64[0] := a; Result.m128i_i64[1] := b;
end;

function simd_set_pd(a, b: Double): TM128;
begin
  Result.m128d_f64[0] := b; Result.m128d_f64[1] := a;
end;

// Integer arithmetic helpers
function simd_adds_epu8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; paddusb xmm0, xmm1  // Unsigned saturated add (8-bit lanes)
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; paddusb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; paddusb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_adds_epu16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; paddusw xmm0, xmm1  // Unsigned saturated add (16-bit lanes)
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; paddusw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; paddusw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_subs_epu8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubusb xmm0, xmm1  // Unsigned saturated subtract (8-bit lanes)
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubusb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubusb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_subs_epu16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psubusw xmm0, xmm1  // Unsigned saturated subtract (16-bit lanes)
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psubusw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psubusw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_mulhi_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmulhw xmm0, xmm1  // Signed 16-bit high-half multiply
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmulhw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmulhw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_mulhi_epu16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmulhuw xmm0, xmm1  // Unsigned 16-bit high-half multiply
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmulhuw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmulhuw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_madd_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmaddwd xmm0, xmm1  // Multiply adjacent i16 pairs and add
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmaddwd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmaddwd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_avg_epu8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pavgb xmm0, xmm1  // Unsigned average (8-bit lanes), (a+b+1)/2
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pavgb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pavgb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_avg_epu16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pavgw xmm0, xmm1  // Unsigned average (16-bit lanes), (a+b+1)/2
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pavgw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pavgw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_sad_epu8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; psadbw xmm0, xmm1  // Sum of absolute byte differences
  {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; psadbw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; psadbw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// Floating-point helpers
function simd_min_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleMinMax(a, b, dmmkMin);
end;

function simd_max_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleMinMax(a, b, dmmkMax);
end;

function simd_min_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleMinMax(a, b, dmmkMin);
end;

function simd_max_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleMinMax(a, b, dmmkMax);
end;

function simd_add_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleSpecialArithmetic(a, b, bakAdd);
end;

function simd_sub_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleSpecialArithmetic(a, b, bakSub);
end;

function simd_mul_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleSpecialArithmetic(a, b, bakMul);
end;

function simd_div_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleDiv(a, b);
end;

function simd_sqrt_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleSqrt(a, b);
end;

function simd_min_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleMinMax(a, b, dmmkMin);
end;

function simd_max_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleMinMax(a, b, dmmkMax);
end;

// === 双精度逻辑运算实现 ===
function simd_and_pd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movupd xmm1, [rdx]; andpd xmm0, xmm1  // Packed double bitwise AND
    {$ELSE}
    movupd xmm0, [rdi]; movupd xmm1, [rsi]; andpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movupd xmm1, [edx]; andpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_or_pd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movupd xmm1, [rdx]; orpd xmm0, xmm1  // Packed double bitwise OR
    {$ELSE}
    movupd xmm0, [rdi]; movupd xmm1, [rsi]; orpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movupd xmm1, [edx]; orpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_xor_pd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movupd xmm1, [rdx]; xorpd xmm0, xmm1  // 双精度逻辑异或
  {$ELSE}
    movupd xmm0, [rdi]; movupd xmm1, [rsi]; xorpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movupd xmm1, [edx]; xorpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_andnot_pd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movupd xmm1, [rdx]; andnpd xmm0, xmm1  // 双精度逻辑与非 (~a & b)
  {$ELSE}
    movupd xmm0, [rdi]; movupd xmm1, [rsi]; andnpd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movupd xmm1, [edx]; andnpd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// Duplicate compare helpers removed; keep asm versions
function simd_cmpord_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckOrd);
end;

function simd_cmpunord_pd(constref a, b: TM128): TM128;
begin
  Result := BuildPackedDoubleCompareMask(a, b, dmckUnord);
end;

// === Scalar double compare helpers ===
function simd_cmpeq_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckEq);
end;

function simd_cmplt_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckLt);
end;

function simd_cmple_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckLe);
end;

function simd_cmpgt_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckGt);
end;

function simd_cmpge_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckGe);
end;

function simd_cmpneq_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckNe);
end;

function simd_cmpnlt_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckNlt);
end;

function simd_cmpnle_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckNle);
end;

function simd_cmpngt_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckNgt);
end;

function simd_cmpnge_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckNge);
end;

function simd_cmpord_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckOrd);
end;

function simd_cmpunord_sd(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleCompareMask(a, b, dmckUnord);
end;

// 有序比较返回整数
type
  TSimdScalarCompareKind = (
    sckEq,
    sckLt,
    sckLe,
    sckGt,
    sckGe,
    sckNe
  );

function EvaluateScalarCompareSd(constref a, b: TM128; const aKind: TSimdScalarCompareKind): Integer; inline;
var
  LA: Double;
  LB: Double;
  LUnordered: Boolean;
begin
  LA := a.m128d_f64[0];
  LB := b.m128d_f64[0];
  LUnordered := SimdIsNaN(LA) or SimdIsNaN(LB);

  case aKind of
    sckEq:
      if (not LUnordered) and (LA = LB) then
        Exit(1);
    sckLt:
      if (not LUnordered) and (LA < LB) then
        Exit(1);
    sckLe:
      if (not LUnordered) and (LA <= LB) then
        Exit(1);
    sckGt:
      if (not LUnordered) and (LA > LB) then
        Exit(1);
    sckGe:
      if (not LUnordered) and (LA >= LB) then
        Exit(1);
    sckNe:
      if LUnordered or (LA <> LB) then
        Exit(1);
  end;

  Result := 0;
end;

function EvaluateDoubleMaskCompare(const aLeft, aRight: Double; const aKind: TSimdDoubleMaskCompareKind): Boolean; inline;
var
  LUnordered: Boolean;
begin
  LUnordered := SimdIsNaN(aLeft) or SimdIsNaN(aRight);

  case aKind of
    dmckEq:
      Result := (not LUnordered) and (aLeft = aRight);
    dmckLt:
      Result := (not LUnordered) and (aLeft < aRight);
    dmckLe:
      Result := (not LUnordered) and (aLeft <= aRight);
    dmckGt:
      Result := (not LUnordered) and (aLeft > aRight);
    dmckGe:
      Result := (not LUnordered) and (aLeft >= aRight);
    dmckNe:
      Result := LUnordered or (aLeft <> aRight);
    dmckNlt:
      Result := LUnordered or (aLeft >= aRight);
    dmckNle:
      Result := LUnordered or (aLeft > aRight);
    dmckNgt:
      Result := LUnordered or (aLeft <= aRight);
    dmckNge:
      Result := LUnordered or (aLeft < aRight);
    dmckOrd:
      Result := not LUnordered;
    dmckUnord:
      Result := LUnordered;
  else
    Result := False;
  end;
end;

function BooleanToMask64(const aValue: Boolean): Int64; inline;
begin
  if aValue then
    Exit(-1);
  Result := 0;
end;

function BuildPackedDoubleCompareMask(constref a, b: TM128; const aKind: TSimdDoubleMaskCompareKind): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 1 do
    Result.m128i_i64[LLane] := BooleanToMask64(
      EvaluateDoubleMaskCompare(a.m128d_f64[LLane], b.m128d_f64[LLane], aKind)
    );
end;

function BuildScalarDoubleCompareMask(constref a, b: TM128; const aKind: TSimdDoubleMaskCompareKind): TM128; inline;
begin
  Result := a;
  Result.m128i_i64[0] := BooleanToMask64(
    EvaluateDoubleMaskCompare(a.m128d_f64[0], b.m128d_f64[0], aKind)
  );
end;

function SelectSingleMinMaxBits(
  const aLeftBits, aRightBits: DWord;
  const aLeftValue, aRightValue: Single;
  const aKind: TSimdDoubleMinMaxKind
): DWord; inline;
begin
  if SimdIsNaN(aLeftValue) or SimdIsNaN(aRightValue) then
    Exit(aRightBits);

  if SingleBitsIsZero(aLeftBits) and SingleBitsIsZero(aRightBits) then
    Exit(aRightBits);

  case aKind of
    dmmkMin:
      if aLeftValue < aRightValue then
        Exit(aLeftBits);
    dmmkMax:
      if aLeftValue > aRightValue then
        Exit(aLeftBits);
  end;

  Result := aRightBits;
end;

function SelectDoubleMinMaxBits(
  const aLeftBits, aRightBits: QWord;
  const aLeftValue, aRightValue: Double;
  const aKind: TSimdDoubleMinMaxKind
): QWord; inline;
begin
  if SimdIsNaN(aLeftValue) or SimdIsNaN(aRightValue) then
    Exit(aRightBits);

  if DoubleBitsIsZero(aLeftBits) and DoubleBitsIsZero(aRightBits) then
    Exit(aRightBits);

  case aKind of
    dmmkMin:
      if aLeftValue < aRightValue then
        Exit(aLeftBits);
    dmmkMax:
      if aLeftValue > aRightValue then
        Exit(aLeftBits);
  end;

  Result := aRightBits;
end;

function BuildPackedSingleMinMax(constref a, b: TM128; const aKind: TSimdDoubleMinMaxKind): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do
    Result.m128i_u32[LLane] := SelectSingleMinMaxBits(
      a.m128i_u32[LLane],
      b.m128i_u32[LLane],
      a.m128_f32[LLane],
      b.m128_f32[LLane],
      aKind
    );
end;

function BuildPackedDoubleMinMax(constref a, b: TM128; const aKind: TSimdDoubleMinMaxKind): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 1 do
    Result.m128i_u64[LLane] := SelectDoubleMinMaxBits(
      a.m128i_u64[LLane],
      b.m128i_u64[LLane],
      a.m128d_f64[LLane],
      b.m128d_f64[LLane],
      aKind
    );
end;

function BuildScalarDoubleMinMax(constref a, b: TM128; const aKind: TSimdDoubleMinMaxKind): TM128; inline;
begin
  Result := a;
  Result.m128i_u64[0] := SelectDoubleMinMaxBits(
    a.m128i_u64[0],
    b.m128i_u64[0],
    a.m128d_f64[0],
    b.m128d_f64[0],
    aKind
  );
end;

function simd_comieq_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckEq);
end;

function simd_comilt_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckLt);
end;

function simd_comile_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckLe);
end;

function simd_comigt_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckGt);
end;

function simd_comige_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckGe);
end;

function simd_comineq_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckNe);
end;

// `ucomi*` and `comi*` share the same boolean result contract here.
function simd_ucomieq_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckEq);
end;

function simd_ucomilt_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckLt);
end;

function simd_ucomile_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckLe);
end;

function simd_ucomigt_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckGt);
end;

function simd_ucomige_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckGe);
end;

function simd_ucomineq_sd(constref a, b: TM128): Integer;
begin
  Result := EvaluateScalarCompareSd(a, b, sckNe);
end;

// === Pack / Insert / Extract / Move helpers ===
function simd_packs_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; packsswb xmm0, xmm1  // Pack signed 16-bit lanes into signed 8-bit lanes
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; packsswb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; packsswb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_packs_epi32(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; packssdw xmm0, xmm1  // Pack signed 32-bit lanes into signed 16-bit lanes
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; packssdw xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; packssdw xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_packus_epi16(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; packuswb xmm0, xmm1  // Pack signed 16-bit lanes into unsigned 8-bit lanes
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; packuswb xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; packuswb xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

  function simd_insert_epi16(constref a: TM128; Value: Integer; imm8: Byte): TM128;
begin
  Result := a;
  Result.m128i_u16[imm8 and $7] := Word(Value and $FFFF);
end;

function simd_extract_epi16(constref a: TM128; imm8: Byte): Integer;
begin
  Result := a.m128i_u16[imm8 and $7];
end;

function simd_move_sd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]    // 加载 a
    movsd xmm1, [rdx]      // Load low 64 bits of b
    movsd xmm0, xmm1       // Copy scalar double into the low lane
    {$ELSE}
    movupd xmm0, [rdi]
    movsd xmm1, [rsi]
    movsd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // a
    mov edx, [esp + 8]    // b
    movupd xmm0, [eax]
    movsd xmm1, [edx]
    movsd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_move_epi64(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    movq xmm0, xmm0       // 移动64位，高位清零
  {$ELSE}
    movdqu xmm0, [rdi]
    movq xmm0, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // a
    movdqu xmm0, [eax]
    movq xmm0, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_movemask_epi8(constref a: TM128): Integer; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 加载 a
    pmovmskb eax, xmm0    // 提取8位符号位掩码
  {$ELSE}
    movdqu xmm0, [rdi]
    pmovmskb eax, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov edx, [esp + 4]    // a
    movdqu xmm0, [edx]
    pmovmskb eax, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

function simd_movemask_pd(constref a: TM128): Integer; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]    // 加载 a
    movmskpd eax, xmm0    // 提取双精度符号位掩码
  {$ELSE}
    movupd xmm0, [rdi]
    movmskpd eax, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov edx, [esp + 4]    // a
    movupd xmm0, [edx]
    movmskpd eax, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

function simd_movemask_ps(constref a: TM128): Integer; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rcx]    // 加载 a
    movmskps eax, xmm0    // 提取单精度符号位掩码
  {$ELSE}
    movups xmm0, [rdi]
    movmskps eax, xmm0
  {$ENDIF}
{$ELSEIF CPUX86}
    mov edx, [esp + 4]    // a
    movups xmm0, [edx]
    movmskps eax, xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

// === Cast helpers (reinterpret only) ===
function simd_castpd_si128(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]    // 直接复制，无转换
  {$ELSE}
    movupd xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]
    movupd xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_castsi128_pd(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 直接复制，无转换
  {$ELSE}
    movdqu xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]
    movdqu xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_castps_si128(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rcx]    // 直接复制，无转换
  {$ELSE}
    movups xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]
    movups xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_castsi128_ps(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]    // 直接复制，无转换
  {$ELSE}
    movdqu xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]
    movdqu xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_castpd_ps(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]    // 直接复制，无转换
  {$ELSE}
    movupd xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]
    movupd xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_castps_pd(constref a: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rcx]    // 直接复制，无转换
  {$ELSE}
    movups xmm0, [rdi]
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]
    movups xmm0, [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpacklo_ps(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rcx]; movups xmm1, [rdx]; unpcklps xmm0, xmm1  // Unpack low packed singles
    {$ELSE}
    movups xmm0, [rdi]; movups xmm1, [rsi]; unpcklps xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movups xmm0, [eax]; movups xmm1, [edx]; unpcklps xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_unpackhi_ps(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rcx]; movups xmm1, [rdx]; unpckhps xmm0, xmm1  // Unpack high packed singles
    {$ELSE}
    movups xmm0, [rdi]; movups xmm1, [rsi]; unpckhps xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movups xmm0, [eax]; movups xmm1, [edx]; unpckhps xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtsd_ss(constref a, b: TM128): TM128;
begin
  Result := BuildScalarDoubleToSingle(a, b);
end;

function simd_cvtss_sd(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; movss xmm1, [rdx]; cvtss2sd xmm0, xmm1  // Convert scalar single to scalar double
    {$ELSE}
    movupd xmm0, [rdi]; movss xmm1, [rsi]; cvtss2sd xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; movss xmm1, [edx]; cvtss2sd xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvttpd_ps(constref a: TM128): TM128;
begin
  Result := BuildPackedDoubleToSingle(a);
end;

  function simd_srai_si128(constref a: TM128; imm8: Byte): TM128; {$IFDEF FPC}assembler; nostackframe;
  {$ENDIF}
  asm
  {$IFDEF CPUX86_64}
    {$IFDEF WINDOWS}
      movdqu xmm0, [rcx]
      cmp dl, 0; je @done
  
      pxor xmm1, xmm1
      mov al, [rcx + 15]
      test al, $80
      jz @fill_ready
      pcmpeqb xmm1, xmm1
  @fill_ready:
      cmp dl, 16; jae @allfill
      cmp dl, 1; je @s1
      cmp dl, 2; je @s2
      cmp dl, 3; je @s3
      cmp dl, 4; je @s4
      cmp dl, 5; je @s5
      cmp dl, 6; je @s6
      cmp dl, 7; je @s7
      cmp dl, 8; je @s8
      cmp dl, 9; je @s9
      cmp dl, 10; je @s10
      cmp dl, 11; je @s11
      cmp dl, 12; je @s12
      cmp dl, 13; je @s13
      cmp dl, 14; je @s14
      cmp dl, 15; je @s15
      jmp @allfill
  @s1: psrldq xmm0, 1; pslldq xmm1, 15; por xmm0, xmm1; jmp @done
  @s2: psrldq xmm0, 2; pslldq xmm1, 14; por xmm0, xmm1; jmp @done
  @s3: psrldq xmm0, 3; pslldq xmm1, 13; por xmm0, xmm1; jmp @done
  @s4: psrldq xmm0, 4; pslldq xmm1, 12; por xmm0, xmm1; jmp @done
  @s5: psrldq xmm0, 5; pslldq xmm1, 11; por xmm0, xmm1; jmp @done
  @s6: psrldq xmm0, 6; pslldq xmm1, 10; por xmm0, xmm1; jmp @done
  @s7: psrldq xmm0, 7; pslldq xmm1, 9; por xmm0, xmm1; jmp @done
  @s8: psrldq xmm0, 8; pslldq xmm1, 8; por xmm0, xmm1; jmp @done
  @s9: psrldq xmm0, 9; pslldq xmm1, 7; por xmm0, xmm1; jmp @done
  @s10: psrldq xmm0, 10; pslldq xmm1, 6; por xmm0, xmm1; jmp @done
  @s11: psrldq xmm0, 11; pslldq xmm1, 5; por xmm0, xmm1; jmp @done
  @s12: psrldq xmm0, 12; pslldq xmm1, 4; por xmm0, xmm1; jmp @done
  @s13: psrldq xmm0, 13; pslldq xmm1, 3; por xmm0, xmm1; jmp @done
  @s14: psrldq xmm0, 14; pslldq xmm1, 2; por xmm0, xmm1; jmp @done
  @s15: psrldq xmm0, 15; pslldq xmm1, 1; por xmm0, xmm1; jmp @done
  @allfill:
      movdqa xmm0, xmm1
  @done:
    {$ELSE}
      movdqu xmm0, [rdi]
      cmp sil, 0; je @done
  
      pxor xmm1, xmm1
      mov al, [rdi + 15]
      test al, $80
      jz @fill_ready
      pcmpeqb xmm1, xmm1
  @fill_ready:
      cmp sil, 16; jae @allfill
      cmp sil, 1; je @s1
      cmp sil, 2; je @s2
      cmp sil, 3; je @s3
      cmp sil, 4; je @s4
      cmp sil, 5; je @s5
      cmp sil, 6; je @s6
      cmp sil, 7; je @s7
      cmp sil, 8; je @s8
      cmp sil, 9; je @s9
      cmp sil, 10; je @s10
      cmp sil, 11; je @s11
      cmp sil, 12; je @s12
      cmp sil, 13; je @s13
      cmp sil, 14; je @s14
      cmp sil, 15; je @s15
      jmp @allfill
  @s1: psrldq xmm0, 1; pslldq xmm1, 15; por xmm0, xmm1; jmp @done
  @s2: psrldq xmm0, 2; pslldq xmm1, 14; por xmm0, xmm1; jmp @done
  @s3: psrldq xmm0, 3; pslldq xmm1, 13; por xmm0, xmm1; jmp @done
  @s4: psrldq xmm0, 4; pslldq xmm1, 12; por xmm0, xmm1; jmp @done
  @s5: psrldq xmm0, 5; pslldq xmm1, 11; por xmm0, xmm1; jmp @done
  @s6: psrldq xmm0, 6; pslldq xmm1, 10; por xmm0, xmm1; jmp @done
  @s7: psrldq xmm0, 7; pslldq xmm1, 9; por xmm0, xmm1; jmp @done
  @s8: psrldq xmm0, 8; pslldq xmm1, 8; por xmm0, xmm1; jmp @done
  @s9: psrldq xmm0, 9; pslldq xmm1, 7; por xmm0, xmm1; jmp @done
  @s10: psrldq xmm0, 10; pslldq xmm1, 6; por xmm0, xmm1; jmp @done
  @s11: psrldq xmm0, 11; pslldq xmm1, 5; por xmm0, xmm1; jmp @done
  @s12: psrldq xmm0, 12; pslldq xmm1, 4; por xmm0, xmm1; jmp @done
  @s13: psrldq xmm0, 13; pslldq xmm1, 3; por xmm0, xmm1; jmp @done
  @s14: psrldq xmm0, 14; pslldq xmm1, 2; por xmm0, xmm1; jmp @done
  @s15: psrldq xmm0, 15; pslldq xmm1, 1; por xmm0, xmm1; jmp @done
  @allfill:
      movdqa xmm0, xmm1
  @done:
    {$ENDIF}
  {$ELSEIF CPUX86}
      mov ecx, [esp + 4]; mov edx, [esp + 8]
      movdqu xmm0, [ecx]
      cmp dl, 0; je @done
  
      pxor xmm1, xmm1
      mov al, [ecx + 15]
      test al, $80
      jz @fill_ready
      pcmpeqb xmm1, xmm1
  @fill_ready:
      cmp dl, 16; jae @allfill
      cmp dl, 1; je @s1
      cmp dl, 2; je @s2
      cmp dl, 3; je @s3
      cmp dl, 4; je @s4
      cmp dl, 5; je @s5
      cmp dl, 6; je @s6
      cmp dl, 7; je @s7
      cmp dl, 8; je @s8
      cmp dl, 9; je @s9
      cmp dl, 10; je @s10
      cmp dl, 11; je @s11
      cmp dl, 12; je @s12
      cmp dl, 13; je @s13
      cmp dl, 14; je @s14
      cmp dl, 15; je @s15
      jmp @allfill
  @s1: psrldq xmm0, 1; pslldq xmm1, 15; por xmm0, xmm1; jmp @done
  @s2: psrldq xmm0, 2; pslldq xmm1, 14; por xmm0, xmm1; jmp @done
  @s3: psrldq xmm0, 3; pslldq xmm1, 13; por xmm0, xmm1; jmp @done
  @s4: psrldq xmm0, 4; pslldq xmm1, 12; por xmm0, xmm1; jmp @done
  @s5: psrldq xmm0, 5; pslldq xmm1, 11; por xmm0, xmm1; jmp @done
  @s6: psrldq xmm0, 6; pslldq xmm1, 10; por xmm0, xmm1; jmp @done
  @s7: psrldq xmm0, 7; pslldq xmm1, 9; por xmm0, xmm1; jmp @done
  @s8: psrldq xmm0, 8; pslldq xmm1, 8; por xmm0, xmm1; jmp @done
  @s9: psrldq xmm0, 9; pslldq xmm1, 7; por xmm0, xmm1; jmp @done
  @s10: psrldq xmm0, 10; pslldq xmm1, 6; por xmm0, xmm1; jmp @done
  @s11: psrldq xmm0, 11; pslldq xmm1, 5; por xmm0, xmm1; jmp @done
  @s12: psrldq xmm0, 12; pslldq xmm1, 4; por xmm0, xmm1; jmp @done
  @s13: psrldq xmm0, 13; pslldq xmm1, 3; por xmm0, xmm1; jmp @done
  @s14: psrldq xmm0, 14; pslldq xmm1, 2; por xmm0, xmm1; jmp @done
  @s15: psrldq xmm0, 15; pslldq xmm1, 1; por xmm0, xmm1; jmp @done
  @allfill:
      movdqa xmm0, xmm1
  @done:
  {$ELSE}
      {$ERROR Unsupported CPU}
  {$ENDIF}
  {$IFDEF CPUX86_64}
    movq rax, xmm0
    movdqa xmm1, xmm0
    psrldq xmm1, 8
    movq rdx, xmm1
  {$ENDIF}
  end;

function simd_max_epu8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pmaxub xmm0, xmm1  // Unsigned 8-bit maximum
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pmaxub xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pmaxub xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_min_epu8(constref a, b: TM128): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rcx]; movdqu xmm1, [rdx]; pminub xmm0, xmm1  // Unsigned 8-bit minimum
    {$ELSE}
    movdqu xmm0, [rdi]; movdqu xmm1, [rsi]; pminub xmm0, xmm1
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movdqu xmm0, [eax]; movdqu xmm1, [edx]; pminub xmm0, xmm1
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtsd_si32(constref a: TM128): Integer;
begin
  Result := ConvertDoubleToInt32Nearest(a.m128d_f64[0]);
end;

function simd_cvtsd_si64(constref a: TM128): Int64;
begin
  Result := ConvertDoubleToInt64Nearest(a.m128d_f64[0]);
end;

function simd_cvttsd_si32(constref a: TM128): Integer;
begin
  Result := ConvertDoubleToInt32Trunc(a.m128d_f64[0]);
end;

function simd_cvttsd_si64(constref a: TM128): Int64;
begin
  Result := ConvertDoubleToInt64Trunc(a.m128d_f64[0]);
end;

function simd_cvtsi32_sd(constref a: TM128; b: Integer): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; cvtsi2sd xmm0, edx  // 32位整数转标量双精度
    {$ELSE}
    movupd xmm0, [rdi]; cvtsi2sd xmm0, esi
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; mov edx, [esp + 8]; movupd xmm0, [eax]; cvtsi2sd xmm0, edx
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

function simd_cvtsi64_sd(constref a: TM128; b: Int64): TM128; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rcx]; cvtsi2sd xmm0, rdx  // 64位整数转标量双精度
    {$ELSE}
    movupd xmm0, [rdi]; cvtsi2sd xmm0, rsi
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]; movupd xmm0, [eax]; cvtsi2sd xmm0, qword ptr [esp + 8]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
{$IFDEF CPUX86_64}
  movq rax, xmm0
  movdqa xmm1, xmm0
  psrldq xmm1, 8
  movq rdx, xmm1
{$ENDIF}
end;

// === Cache control / stream / fence helpers ===
procedure simd_clflush(const Ptr: Pointer); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    clflush [rcx]         // Flush cache line
    {$ELSE}
    clflush [rdi]         // Linux/macOS x64
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // Ptr
    clflush [eax]
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_lfence; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
    lfence                // 加载栅栏
end;

procedure simd_mfence; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
    mfence                // 内存栅栏
end;

procedure simd_pause; {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
    pause                 // 暂停指令（自旋循环提示）
end;

procedure simd_stream_pd(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movupd xmm0, [rdx]    // 加载 Src
    movntpd [rcx], xmm0   // 非临时存储双精度
  {$ELSE}
    movupd xmm0, [rsi]    // 加载 Src
    movntpd [rdi], xmm0   // 非临时存储双精度
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movupd xmm0, [edx]
    movntpd [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_stream_ps(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movups xmm0, [rdx]    // 加载 Src
    movntps [rcx], xmm0   // 非临时存储单精度
  {$ELSE}
    movups xmm0, [rsi]    // 加载 Src
    movntps [rdi], xmm0   // 非临时存储单精度
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movups xmm0, [edx]
    movntps [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_stream_si128(var Dest; constref Src: TM128); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movdqu xmm0, [rdx]    // 加载 Src
    movntdq [rcx], xmm0   // Non-temporal store of 128-bit integer data
    {$ELSE}
    movdqu xmm0, [rsi]    // 加载 Src
    movntdq [rdi], xmm0   // Non-temporal store of 128-bit integer data
    {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Src
    movdqu xmm0, [edx]
    movntdq [eax], xmm0
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_stream_si32(var Dest; Value: Integer); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movnti [rcx], edx     // Non-temporal store of 32-bit integer data
    {$ELSE}
    movnti [rdi], esi     // Linux/macOS x64
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Value
    movnti [eax], edx
{$ELSE}
    {$ERROR Unsupported CPU}
{$ENDIF}
end;

procedure simd_stream_si64(var Dest; Value: Int64); {$IFDEF FPC}assembler; nostackframe;
{$ENDIF}
asm
{$IFDEF CPUX86_64}
  {$IFDEF WINDOWS}
    movnti [rcx], rdx     // Non-temporal store of 64-bit integer data
    {$ELSE}
    movnti [rdi], rsi     // Linux/macOS x64
  {$ENDIF}
{$ELSEIF CPUX86}
    mov eax, [esp + 4]    // Dest
    mov edx, [esp + 8]    // Low 32 bits of Value
    mov ecx, [esp + 12]   // High 32 bits of Value
    movnti [eax], edx
    movnti [eax + 4], ecx
    {$ELSE}
  {$ERROR Unsupported CPU}
{$ENDIF}
end;

{$POP}

end.

