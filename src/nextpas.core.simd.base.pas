unit nextpas.core.simd.base;

{$I nextpas.core.settings.inc}

interface

// =============================================================
// 说明
// - 本单元是 SIMD 子系统的基础单元，仅包含类型定义和常量。
// - 工具函数（Mask*、Vec*、Shuffle 等）位于 nextpas.core.simd.utils 单元。
// - 默认公开入口的向量运算符重载位于 nextpas.core.simd 单元。
// - 更宽向量与兼容层运算符重载位于 nextpas.core.simd.ops 单元。
// =============================================================

// === 向量数据类型（record + variant 部分）===
// 注意: 对齐属性确保向量可安全用于 SIMD load/store 指令
// - 128-bit 向量: 16 字节对齐 (SSE/NEON)
// - 256-bit 向量: 32 字节对齐 (AVX/AVX2)
// - 512-bit 向量: 32 字节对齐 (AVX-512, FPC 最大支持)

{$PUSH}
{$CODEALIGN RECORDMIN=16}
type
  // 128-bit 有符号向量 (16 字节对齐)
  TVecF32x4 = record
    case Integer of
      0: (f: array[0..3] of Single);
      1: (raw: array[0..15] of Byte);
  end;

  TVecF64x2 = record
    case Integer of
      0: (d: array[0..1] of Double);
      1: (raw: array[0..15] of Byte);
  end;

  TVecI32x4 = record
    case Integer of
      0: (i: array[0..3] of Int32);
      1: (raw: array[0..15] of Byte);
  end;

  TVecI64x2 = record
    case Integer of
      0: (i: array[0..1] of Int64);
      1: (raw: array[0..15] of Byte);
  end;

  TVecI16x8 = record
    case Integer of
      0: (i: array[0..7] of Int16);
      1: (raw: array[0..15] of Byte);
  end;

  TVecI8x16 = record
    case Integer of
      0: (i: array[0..15] of Int8);
      1: (raw: array[0..15] of Byte);
  end;

  // 128-bit 无符号向量 (16 字节对齐)
  TVecU32x4 = record
    case Integer of
      0: (u: array[0..3] of UInt32);
      1: (raw: array[0..15] of Byte);
  end;

  TVecU64x2 = record
    case Integer of
      0: (u: array[0..1] of UInt64);
      1: (raw: array[0..15] of Byte);
  end;

  TVecU16x8 = record
    case Integer of
      0: (u: array[0..7] of UInt16);
      1: (raw: array[0..15] of Byte);
  end;

  TVecU8x16 = record
    case Integer of
      0: (u: array[0..15] of UInt8);
      1: (raw: array[0..15] of Byte);
  end;
{$POP}

{$PUSH}
// NOTE:
// RECORDMIN=32 can introduce padding between sub-record fields inside variant
// records (e.g. lo/hi) and break the intended 32-byte layout/aliasing.
// Use RECORDMIN=16 here to keep a stable 32-byte layout on all targets.
{$CODEALIGN RECORDMIN=16}
  // 256-bit 向量 (32 bytes payload)
  TVecF32x8 = record
    case Integer of
      0: (f: array[0..7] of Single);
      1: (lo, hi: TVecF32x4);
      2: (raw: array[0..31] of Byte);
  end;

  TVecF64x4 = record
    case Integer of
      0: (d: array[0..3] of Double);
      1: (lo, hi: TVecF64x2);
      2: (raw: array[0..31] of Byte);
  end;

  TVecI32x8 = record
    case Integer of
      0: (i: array[0..7] of Int32);
      1: (lo, hi: TVecI32x4);
      2: (raw: array[0..31] of Byte);
  end;

  // ✅ P0-FIX: 添加缺失的 TVecI64x4 类型 (256-bit signed 64-bit integer vector)
  TVecI64x4 = record
    case Integer of
      0: (i: array[0..3] of Int64);
      1: (lo, hi: TVecI64x2);
      2: (raw: array[0..31] of Byte);
  end;

  TVecI16x16 = record
    case Integer of
      0: (i: array[0..15] of Int16);
      1: (lo, hi: TVecI16x8);
      2: (raw: array[0..31] of Byte);
  end;

  TVecI8x32 = record
    case Integer of
      0: (i: array[0..31] of Int8);
      1: (lo, hi: TVecI8x16);
      2: (raw: array[0..31] of Byte);
  end;

  // 256-bit 无符号向量 (32 字节对齐)
  TVecU32x8 = record
    case Integer of
      0: (u: array[0..7] of UInt32);
      1: (lo, hi: TVecU32x4);
      2: (raw: array[0..31] of Byte);
  end;

  TVecU64x4 = record
    case Integer of
      0: (u: array[0..3] of UInt64);
      1: (lo, hi: TVecU64x2);
      2: (raw: array[0..31] of Byte);
  end;

  TVecU16x16 = record
    case Integer of
      0: (u: array[0..15] of UInt16);
      1: (lo, hi: TVecU16x8);
      2: (raw: array[0..31] of Byte);
  end;

  TVecU8x32 = record
    case Integer of
      0: (u: array[0..31] of UInt8);
      1: (lo, hi: TVecU8x16);
      2: (raw: array[0..31] of Byte);
  end;
{$POP}

{$PUSH}
{$CODEALIGN RECORDMIN=32}
  // 512-bit 向量类型 (32 字节对齐 - FPC 最大支持值)
  // 注意: AVX-512 理论需要 64 字节对齐，但 FPC CODEALIGN 最大支持 32
  // 对于栈分配，编译器通常会保证足够对齐
  TVecF32x16 = record
    case Integer of
      0: (f: array[0..15] of Single);
      1: (lo, hi: TVecF32x8);
      2: (raw: array[0..63] of Byte);
  end;

  TVecF64x8 = record
    case Integer of
      0: (d: array[0..7] of Double);
      1: (lo, hi: TVecF64x4);
      2: (raw: array[0..63] of Byte);
  end;

  TVecI32x16 = record
    case Integer of
      0: (i: array[0..15] of Int32);
      1: (lo, hi: TVecI32x8);
      2: (raw: array[0..63] of Byte);
  end;

  TVecI64x8 = record
    case Integer of
      0: (i: array[0..7] of Int64);
      1: (lo, hi: TVecI64x4);  // ✅ P0-FIX: 修复变体记录大小不匹配 (原为 TVecI64x2，仅 32 字节)
      2: (raw: array[0..63] of Byte);
  end;

  TVecI16x32 = record
    case Integer of
      0: (i: array[0..31] of Int16);
      1: (lo, hi: TVecI16x16);
      2: (raw: array[0..63] of Byte);
  end;

  TVecI8x64 = record
    case Integer of
      0: (i: array[0..63] of Int8);
      1: (lo, hi: TVecI8x32);
      2: (raw: array[0..63] of Byte);
  end;

  // 512-bit 无符号向量 (32 字节对齐)
  TVecU32x16 = record
    case Integer of
      0: (u: array[0..15] of UInt32);
      1: (lo, hi: TVecU32x8);
      2: (raw: array[0..63] of Byte);
  end;

  TVecU64x8 = record
    case Integer of
      0: (u: array[0..7] of UInt64);
      1: (lo, hi: TVecU64x4);
      2: (raw: array[0..63] of Byte);
  end;

  TVecU8x64 = record
    case Integer of
      0: (u: array[0..63] of UInt8);
      1: (lo, hi: TVecU8x32);
      2: (raw: array[0..63] of Byte);
  end;
{$POP}

// === 位掩码类型 ===
type
  TMask2  = type Byte;   // 仅 2 位有效
  TMask4  = type Byte;   // 仅 4 位有效
  TMask8  = type Byte;   // 仅 8 位有效
  TMask16 = type Word;   // 仅 16 位有效
  TMask32 = type DWord;  // 仅 32 位有效
  TMask64 = type QWord;  // 64 位有效

// === 向量掩码类型 ===
{$PUSH}
{$CODEALIGN RECORDMIN=16}
type
  // 128-bit F32x4 掩码 (16 字节对齐)
  TMaskF32x4 = record
    case Integer of
      0: (m: array[0..3] of UInt32);      // 每个元素 0 或 $FFFFFFFF
      1: (raw: array[0..15] of Byte);
  end;

  // 128-bit F64x2 掩码 (16 字节对齐)
  TMaskF64x2 = record
    case Integer of
      0: (m: array[0..1] of UInt64);      // 每个元素 0 或 $FFFFFFFFFFFFFFFF
      1: (raw: array[0..15] of Byte);
  end;

  // 128-bit I32x4 掩码 (16 字节对齐)
  TMaskI32x4 = record
    case Integer of
      0: (m: array[0..3] of UInt32);      // 每个元素 0 或 $FFFFFFFF
      1: (raw: array[0..15] of Byte);
  end;

  // 128-bit I64x2 掩码 (16 字节对齐)
  TMaskI64x2 = record
    case Integer of
      0: (m: array[0..1] of UInt64);
      1: (raw: array[0..15] of Byte);
  end;
{$POP}

{$PUSH}
{$CODEALIGN RECORDMIN=32}
  // 512-bit F32x16 掩码 (32 字节对齐)
  // Note: bits 作为独立字段，不与 m 数组重叠
  TMaskF32x16 = record
    m: array[0..15] of UInt32;     // 每个元素 0 或 $FFFFFFFF
    bits: UInt16;                   // AVX-512 k 寄存器位模式
  end;

  // 512-bit I32x16 掩码 (32 字节对齐)
  TMaskI32x16 = record
    m: array[0..15] of UInt32;
    bits: UInt16;
  end;

  // 512-bit F64x8 掩码 (32 字节对齐)
  TMaskF64x8 = record
    m: array[0..7] of UInt64;
    bits: UInt8;                    // AVX-512 k 寄存器 8 位
  end;
{$POP}

// === 元素类型枚举 ===
type
  TSimdElementType = (
    setFloat32,
    setFloat64,
    setInt8,
    setInt16,
    setInt32,
    setInt64,
    setUInt8,
    setUInt16,
    setUInt32,
    setUInt64
  );

// === 后端与能力 ===
type
  TSimdBackend = (
    sbScalar,
    sbSSE2,
    sbSSE3,     // SSE3 - 新增水平运算指令 (HADDPS, MOVDDUP 等)
    sbSSSE3,    // SSSE3 - 补充 SSE3 (PSHUFB, PALIGNR 等)
    sbSSE41,    // SSE4.1 - 扩展整数/浮点指令 (ROUNDPS, PBLENDVB 等)
    sbSSE42,    // SSE4.2 - 字符串处理/CRC32 (PCMPESTRI, CRC32 等)
    sbAVX2,
    sbAVX512,
    sbNEON,
    sbRISCVV    // ⚠️ EXPERIMENTAL - 实验性后端，API 可能变更
  );

  TSimdBackendArray = array of TSimdBackend;

  TSimdCapability = (
    scBasicArithmetic,
    scComparison,
    scMathFunctions,
    scReduction,
    scShuffle,
    scFMA,
    scFastMath,
    scIntegerOps,
    scLoadStore,
    scGather,
    scMaskedOps,
    sc512BitOps
  );
  TSimdCapabilities  = set of TSimdCapability;
  TSimdCapabilitySet = TSimdCapabilities; // 别名

  // Backend metadata is part of the in-repo dispatch contract, not a public
  // binary ABI surface. Name/Description are managed strings, so this record
  // must not be treated as POD-stable across compilers/runtimes.
  TSimdBackendInfo = record
    Backend: TSimdBackend;
    Name: string;
    Description: string;
    Capabilities: TSimdCapabilities;
    Available: Boolean;
    Priority: Integer;
  end;

// === 常量：便捷掩码 ===
const
  MASK2_ALL_SET  : TMask2  = $03;
  MASK4_ALL_SET  : TMask4  = $0F;
  MASK8_ALL_SET  : TMask8  = $FF;
  MASK16_ALL_SET : TMask16 = $FFFF;
  MASK32_ALL_SET : TMask32 = $FFFFFFFF;

  MASK2_NONE_SET  : TMask2  = $00;
  MASK4_NONE_SET  : TMask4  = $00;
  MASK8_NONE_SET  : TMask8  = $00;
  MASK16_NONE_SET : TMask16 = $0000;
  MASK32_NONE_SET : TMask32 = $00000000;

// === 掩码逻辑运算符 ===
// 512-bit 掩码逻辑运算符
operator and (const a, b: TMaskF32x16): TMaskF32x16; inline;
operator or (const a, b: TMaskF32x16): TMaskF32x16; inline;
operator xor (const a, b: TMaskF32x16): TMaskF32x16; inline;
operator not (const a: TMaskF32x16): TMaskF32x16; inline;

// TMaskF32x4 逻辑运算符
operator and (const a, b: TMaskF32x4): TMaskF32x4; inline;
operator or (const a, b: TMaskF32x4): TMaskF32x4; inline;
operator xor (const a, b: TMaskF32x4): TMaskF32x4; inline;
operator not (const a: TMaskF32x4): TMaskF32x4; inline;

implementation

// === TMaskF32x16 逻辑运算符实现 ===

operator and (const a, b: TMaskF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.m[i] := a.m[i] and b.m[i];
  Result.bits := a.bits and b.bits;
end;

operator or (const a, b: TMaskF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.m[i] := a.m[i] or b.m[i];
  Result.bits := a.bits or b.bits;
end;

operator xor (const a, b: TMaskF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.m[i] := a.m[i] xor b.m[i];
  Result.bits := a.bits xor b.bits;
end;

operator not (const a: TMaskF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.m[i] := not a.m[i];
  Result.bits := not a.bits;
end;

// === TMaskF32x4 逻辑运算符实现 ===

operator and (const a, b: TMaskF32x4): TMaskF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.m[i] := a.m[i] and b.m[i];
end;

operator or (const a, b: TMaskF32x4): TMaskF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.m[i] := a.m[i] or b.m[i];
end;

operator xor (const a, b: TMaskF32x4): TMaskF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.m[i] := a.m[i] xor b.m[i];
end;

operator not (const a: TMaskF32x4): TMaskF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.m[i] := not a.m[i];
end;

end.
