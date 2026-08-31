{**
 * nextpas.core.simd.inline — 全平台可内联的通用 SIMD 基座
 * 编译期直联 scalar/sse2/avx2/neon，不读分发表；与 dispatch 共存，供热路径
 * 显式 uses。本单元与 nextpas.core.simd.dispatch 语义一致，但永可内联。
 * 详细矩阵见 core/docs/simd/inline.md。
 *}
unit nextpas.core.simd.inline;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

// ── F32x4 ──
function InlineVecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Neg(const a: TVecF32x4): TVecF32x4; inline;
function InlineVecF32x4Load(p: PSingle): TVecF32x4; inline;
procedure InlineVecF32x4Store(p: PSingle; const a: TVecF32x4); inline;
function InlineVecF32x4Splat(v: Single): TVecF32x4; inline;
function InlineVecF32x4Zero: TVecF32x4; inline;

// ── F64x2 ──
function InlineVecF64x2Add(const a, b: TVecF64x2): TVecF64x2; inline;
function InlineVecF64x2Sub(const a, b: TVecF64x2): TVecF64x2; inline;
function InlineVecF64x2Mul(const a, b: TVecF64x2): TVecF64x2; inline;
function InlineVecF64x2Div(const a, b: TVecF64x2): TVecF64x2; inline;
function InlineVecF64x2Min(const a, b: TVecF64x2): TVecF64x2; inline;
function InlineVecF64x2Max(const a, b: TVecF64x2): TVecF64x2; inline;

// ── I32x4 / U32x4 ──
function InlineVecI32x4Add(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4Sub(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4Mul(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4And(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4Or(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4Xor(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4Min(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4Max(const a, b: TVecI32x4): TVecI32x4; inline;
function InlineVecI32x4CmpEq(const a, b: TVecI32x4): TMask4; inline;

// ── U8x16 ──（图形/图像热路径）
function InlineVecU8x16Add(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16Sub(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16SatAdd(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16SatSub(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16And(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16Or(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16Xor(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16Min(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16Max(const a, b: TVecU8x16): TVecU8x16; inline;
function InlineVecU8x16CmpEq(const a, b: TVecU8x16): TMask16; inline;
function InlineVecU8x16Load(p: PByte): TVecU8x16; inline;
procedure InlineVecU8x16Store(p: PByte; const a: TVecU8x16); inline;
function InlineVecU8x16Splat(v: Byte): TVecU8x16; inline;

// ── U16x8 ──
function InlineVecU16x8Add(const a, b: TVecU16x8): TVecU16x8; inline;
function InlineVecU16x8Min(const a, b: TVecU16x8): TVecU16x8; inline;
function InlineVecU16x8Max(const a, b: TVecU16x8): TVecU16x8; inline;

// ── 256-bit 扩展（AVX2，scalar 回退已可用） ──
function InlineVecF32x8Add(const a, b: TVecF32x8): TVecF32x8; inline;
function InlineVecF32x8Mul(const a, b: TVecF32x8): TVecF32x8; inline;

implementation

{$IFDEF CPUX86_64}
  {$I nextpas.core.simd.inline.x86_64.inc}
{$ELSEIF DEFINED(CPUAARCH64) OR DEFINED(CPUARM)}
  {$I nextpas.core.simd.inline.neon.inc}
{$ELSE}
  {$I nextpas.core.simd.inline.scalar.inc}
{$ENDIF}

end.
