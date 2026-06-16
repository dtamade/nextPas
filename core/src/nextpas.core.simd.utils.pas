unit nextpas.core.simd.utils;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

interface

uses
  nextpas.core.simd.base;

// =============================================================
// 说明
// - 本单元包含 SIMD 工具函数，从 base.pas 分离以避免名称冲突
// - 包括：掩码函数、shuffle 函数、类型转换、gather/scatter、数学函数等
// =============================================================

// === 向量掩码构造函数 ===
function MaskF32x4AllTrue: TMaskF32x4; inline;
function MaskF32x4AllFalse: TMaskF32x4; inline;
function MaskF32x4Set(m0, m1, m2, m3: Boolean): TMaskF32x4; inline;
function MaskF32x4Test(const m: TMaskF32x4; index: Integer): Boolean; inline;
function MaskF32x4ToBitmask(const m: TMaskF32x4): TMask4; inline;
function MaskF32x4Any(const m: TMaskF32x4): Boolean; inline;
function MaskF32x4All(const m: TMaskF32x4): Boolean; inline;
function MaskF32x4None(const m: TMaskF32x4): Boolean; inline;
function MaskF32x4Select(const m: TMaskF32x4; const a, b: TVecF32x4): TVecF32x4; inline;

function MaskF64x2AllTrue: TMaskF64x2; inline;
function MaskF64x2AllFalse: TMaskF64x2; inline;
function MaskF64x2ToBitmask(const m: TMaskF64x2): TMask2; inline;

function MaskI32x4AllTrue: TMaskI32x4; inline;
function MaskI32x4AllFalse: TMaskI32x4; inline;
function MaskI32x4ToBitmask(const m: TMaskI32x4): TMask4; inline;

// 512-bit 掩码函数 (AVX-512)
function MaskF32x16AllTrue: TMaskF32x16; inline;
function MaskF32x16AllFalse: TMaskF32x16; inline;
function MaskF32x16ToBitmask(const m: TMaskF32x16): TMask16; inline;
function MaskF32x16Any(const m: TMaskF32x16): Boolean; inline;
function MaskF32x16All(const m: TMaskF32x16): Boolean; inline;
function MaskF32x16None(const m: TMaskF32x16): Boolean; inline;
function MaskF32x16FromBitmask(bm: TMask16): TMaskF32x16; inline;
function MaskF32x16Select(const m: TMaskF32x16; const a, b: TVecF32x16): TVecF32x16; inline;

// 512-bit 向量比较函数 (Phase 4)
function VecF32x16CmpEq(const a, b: TVecF32x16): TMaskF32x16; inline;
function VecF32x16CmpNe(const a, b: TVecF32x16): TMaskF32x16; inline;
function VecF32x16CmpLt(const a, b: TVecF32x16): TMaskF32x16; inline;
function VecF32x16CmpLe(const a, b: TVecF32x16): TMaskF32x16; inline;
function VecF32x16CmpGt(const a, b: TVecF32x16): TMaskF32x16; inline;
function VecF32x16CmpGe(const a, b: TVecF32x16): TMaskF32x16; inline;

function VecI32x16CmpEq(const a, b: TVecI32x16): TMaskI32x16; inline;
function VecI32x16CmpLt(const a, b: TVecI32x16): TMaskI32x16; inline;
function VecI32x16CmpGt(const a, b: TVecI32x16): TMaskI32x16; inline;

// === 类型转换函数 (Phase 1.4) ===
// IntoBits / FromBits - 位模式重新解释（不改变位）
function VecF32x4IntoBits(const a: TVecF32x4): TVecI32x4; inline;
function VecI32x4FromBitsF32(const a: TVecI32x4): TVecF32x4; inline;
function VecF64x2IntoBits(const a: TVecF64x2): TVecI64x2; inline;
function VecI64x2FromBitsF64(const a: TVecI64x2): TVecF64x2; inline;

// Cast - 元素级别转换（数值转换）
function VecF32x4CastToI32x4(const a: TVecF32x4): TVecI32x4; inline;
function VecI32x4CastToF32x4(const a: TVecI32x4): TVecF32x4; inline;
function VecF64x2CastToI64x2(const a: TVecF64x2): TVecI64x2; inline;
function VecI64x2CastToF64x2(const a: TVecI64x2): TVecF64x2; inline;

// Widen - 扩展宽度
function VecI16x8WidenLoI32x4(const a: TVecI16x8): TVecI32x4; inline;
function VecI16x8WidenHiI32x4(const a: TVecI16x8): TVecI32x4; inline;

// Narrow - 缩小宽度（截断）
function VecI32x4NarrowToI16x8(const a, b: TVecI32x4): TVecI16x8; inline;

// 精度转换 F32 <-> F64
function VecF32x4ToF64x2Lo(const a: TVecF32x4): TVecF64x2; inline;
function VecF64x2ToF32x4(const a, b: TVecF64x2): TVecF32x4; inline;

// === Shuffle/Swizzle 函数 (Phase 2) ===
function VecF32x4Shuffle(const a: TVecF32x4; imm8: Byte): TVecF32x4; inline;
function VecI32x4Shuffle(const a: TVecI32x4; imm8: Byte): TVecI32x4; inline;
function VecF32x4Shuffle2(const a, b: TVecF32x4; imm8: Byte): TVecF32x4; inline;
function VecF32x4Blend(const a, b: TVecF32x4; mask: Byte): TVecF32x4; inline;
function VecF64x2Blend(const a, b: TVecF64x2; mask: Byte): TVecF64x2; inline;
function VecI32x4Blend(const a, b: TVecI32x4; mask: Byte): TVecI32x4; inline;
function VecF32x4UnpackLo(const a, b: TVecF32x4): TVecF32x4; inline;
function VecF32x4UnpackHi(const a, b: TVecF32x4): TVecF32x4; inline;
function VecI32x4UnpackLo(const a, b: TVecI32x4): TVecI32x4; inline;
function VecI32x4UnpackHi(const a, b: TVecI32x4): TVecI32x4; inline;
function VecF32x4Broadcast(const a: TVecF32x4; index: Integer): TVecF32x4; inline;
function VecI32x4Broadcast(const a: TVecI32x4; index: Integer): TVecI32x4; inline;
function VecF32x4Reverse(const a: TVecF32x4): TVecF32x4; inline;
function VecI32x4Reverse(const a: TVecI32x4): TVecI32x4; inline;
function VecF32x4RotateLeft(const a: TVecF32x4; n: Integer): TVecF32x4; inline;
function VecI32x4RotateLeft(const a: TVecI32x4; n: Integer): TVecI32x4; inline;
function VecF32x4RotateRight(const a: TVecF32x4; n: Integer): TVecF32x4; inline;
function VecI32x4RotateRight(const a: TVecI32x4; n: Integer): TVecI32x4; inline;

// === Swizzle Dyn (Rust portable-simd 对齐) ===
// swizzle_dyn: 运行时动态索引排列（字节向量专用）
// 语义: 使用索引向量重新排列元素，越界索引返回 0
// Rust: fn swizzle_dyn(self, idxs: Simd<u8, N>) -> Self
function VecU8x16SwizzleDyn(const a, idxs: TVecU8x16): TVecU8x16; inline;
function VecU8x32SwizzleDyn(const a, idxs: TVecU8x32): TVecU8x32; inline;
function VecU8x64SwizzleDyn(const a, idxs: TVecU8x64): TVecU8x64; inline;

// 有符号字节向量变体
function VecI8x16SwizzleDyn(const a: TVecI8x16; const idxs: TVecU8x16): TVecI8x16; inline;
function VecI8x32SwizzleDyn(const a: TVecI8x32; const idxs: TVecU8x32): TVecI8x32; inline;
function VecI8x64SwizzleDyn(const a: TVecI8x64; const idxs: TVecU8x64): TVecI8x64; inline;

// === Shift Elements (Rust portable-simd 对齐) ===
// shift_elements_left: 元素向左移位，右侧填充 padding
// shift_elements_right: 元素向右移位，左侧填充 padding
function VecF32x4ShiftElementsLeft(const a: TVecF32x4; offset: Integer; padding: Single): TVecF32x4; inline;
function VecF32x4ShiftElementsRight(const a: TVecF32x4; offset: Integer; padding: Single): TVecF32x4; inline;
function VecI32x4ShiftElementsLeft(const a: TVecI32x4; offset: Integer; padding: Int32): TVecI32x4; inline;
function VecI32x4ShiftElementsRight(const a: TVecI32x4; offset: Integer; padding: Int32): TVecI32x4; inline;

// === Interleave/Deinterleave (Rust portable-simd 对齐) ===
// interleave: [a0,a1,a2,a3] + [b0,b1,b2,b3] -> ([a0,b0,a1,b1], [a2,b2,a3,b3])
// deinterleave: [a0,a1,a2,a3] + [b0,b1,b2,b3] -> ([a0,a2,b0,b2], [a1,a3,b1,b3])
procedure VecF32x4Interleave(const a, b: TVecF32x4; out lo, hi: TVecF32x4); inline;
procedure VecF32x4Deinterleave(const a, b: TVecF32x4; out even, odd: TVecF32x4); inline;
procedure VecI32x4Interleave(const a, b: TVecI32x4; out lo, hi: TVecI32x4); inline;
procedure VecI32x4Deinterleave(const a, b: TVecI32x4; out even, odd: TVecI32x4); inline;
function VecF32x4Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; inline;
function VecI32x4Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4; inline;
function VecF32x4Extract(const a: TVecF32x4; index: Integer): Single; inline;
function VecI32x4Extract(const a: TVecI32x4; index: Integer): Int32; inline;
function MM_SHUFFLE(d, c, b, a: Byte): Byte; inline;

// === Gather/Scatter 函数 (Phase 2.2) ===
function VecF32x4Gather(base: PSingle; const indices: TVecI32x4): TVecF32x4; inline;
function VecI32x4Gather(base: PInt32; const indices: TVecI32x4): TVecI32x4; inline;
procedure VecF32x4Scatter(base: PSingle; const indices: TVecI32x4; const values: TVecF32x4); inline;
procedure VecI32x4Scatter(base: PInt32; const indices: TVecI32x4; const values: TVecI32x4); inline;

// === Masked Gather/Scatter (Rust portable-simd 对齐) ===
// gather_select: 带掩码的 gather，enable=false 时使用 orVal
// scatter_select: 带掩码的 scatter，enable=false 时跳过写入
function VecF32x4GatherSelect(base: PSingle; const enable: TMask4; const indices: TVecI32x4; const orVal: TVecF32x4): TVecF32x4; inline;
function VecI32x4GatherSelect(base: PInt32; const enable: TMask4; const indices: TVecI32x4; const orVal: TVecI32x4): TVecI32x4; inline;
procedure VecF32x4ScatterSelect(base: PSingle; const enable: TMask4; const indices: TVecI32x4; const values: TVecF32x4); inline;
procedure VecI32x4ScatterSelect(base: PInt32; const enable: TMask4; const indices: TVecI32x4; const values: TVecI32x4); inline;

// === SIMD 数学函数 (Phase 4) ===
function VecF32x4Sin(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Cos(const a: TVecF32x4): TVecF32x4; inline;
procedure VecF32x4SinCos(const a: TVecF32x4; out sinResult, cosResult: TVecF32x4);
function VecF32x4Tan(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Exp(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Exp2(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Log(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Log2(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Log10(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Pow(const base, exponent: TVecF32x4): TVecF32x4; inline;
function VecF32x4Asin(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Acos(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Atan(const a: TVecF32x4): TVecF32x4; inline;
function VecF32x4Atan2(const y, x: TVecF32x4): TVecF32x4; inline;

// === 高级算法 (Phase 5) ===
function SortNet4I32(const a: TVecI32x4; ascending: Boolean = True): TVecI32x4;
function SortNet4F32(const a: TVecF32x4; ascending: Boolean = True): TVecF32x4;
function SortNet8I32(const a: TVecI32x8; ascending: Boolean = True): TVecI32x8;
function PrefixSumI32x4(const a: TVecI32x4; inclusive: Boolean = True): TVecI32x4;
function PrefixSumF32x4(const a: TVecF32x4; inclusive: Boolean = True): TVecF32x4;
procedure PrefixSumArrayI32(src, dst: PInt32; count: SizeUInt);
procedure PrefixSumArrayF32(src, dst: PSingle; count: SizeUInt);
function StrFindChar(p: Pointer; len: SizeUInt; ch: Byte): PtrInt;

// === Resize/Extract 函数 (Rust portable-simd 对齐) ===
// resize: 改变向量长度，扩展时填充 padding，缩小时截断
// extract: 从向量中提取连续子向量

// F32x4 <-> F32x8 转换
function VecF32x4ResizeToF32x8(const a: TVecF32x4; padding: Single): TVecF32x8; inline;
function VecF32x8ResizeToF32x4(const a: TVecF32x8): TVecF32x4; inline;
function VecF32x4Concat(const a, b: TVecF32x4): TVecF32x8; inline;

// F32x8 <-> F32x16 转换
function VecF32x8ResizeToF32x16(const a: TVecF32x8; padding: Single): TVecF32x16; inline;
function VecF32x16ResizeToF32x8(const a: TVecF32x16): TVecF32x8; inline;
function VecF32x8Concat(const a, b: TVecF32x8): TVecF32x16; inline;

// I32x4 <-> I32x8 转换
function VecI32x4ResizeToI32x8(const a: TVecI32x4; padding: Int32): TVecI32x8; inline;
function VecI32x8ResizeToI32x4(const a: TVecI32x8): TVecI32x4; inline;
function VecI32x4Concat(const a, b: TVecI32x4): TVecI32x8; inline;

// I32x8 <-> I32x16 转换
function VecI32x8ResizeToI32x16(const a: TVecI32x8; padding: Int32): TVecI32x16; inline;
function VecI32x16ResizeToI32x8(const a: TVecI32x16): TVecI32x8; inline;
function VecI32x8Concat(const a, b: TVecI32x8): TVecI32x16; inline;

// F64x2 <-> F64x4 转换
function VecF64x2ResizeToF64x4(const a: TVecF64x2; padding: Double): TVecF64x4; inline;
function VecF64x4ResizeToF64x2(const a: TVecF64x4): TVecF64x2; inline;
function VecF64x2Concat(const a, b: TVecF64x2): TVecF64x4; inline;

// F64x4 <-> F64x8 转换
function VecF64x4ResizeToF64x8(const a: TVecF64x4; padding: Double): TVecF64x8; inline;
function VecF64x8ResizeToF64x4(const a: TVecF64x8): TVecF64x4; inline;
function VecF64x4Concat(const a, b: TVecF64x4): TVecF64x8; inline;

// Extract - 提取子向量 (Rust: extract::<START, LEN>)
// 提取 F32x8 的低/高半部分
function VecF32x8ExtractLo(const a: TVecF32x8): TVecF32x4; inline;
function VecF32x8ExtractHi(const a: TVecF32x8): TVecF32x4; inline;

// 提取 I32x8 的低/高半部分
function VecI32x8ExtractLo(const a: TVecI32x8): TVecI32x4; inline;
function VecI32x8ExtractHi(const a: TVecI32x8): TVecI32x4; inline;

// 提取 F64x4 的低/高半部分
function VecF64x4ExtractLo(const a: TVecF64x4): TVecF64x2; inline;
function VecF64x4ExtractHi(const a: TVecF64x4): TVecF64x2; inline;

// 提取 F32x16 的低/高半部分
function VecF32x16ExtractLo(const a: TVecF32x16): TVecF32x8; inline;
function VecF32x16ExtractHi(const a: TVecF32x16): TVecF32x8; inline;

// 提取 I32x16 的低/高半部分
function VecI32x16ExtractLo(const a: TVecI32x16): TVecI32x8; inline;
function VecI32x16ExtractHi(const a: TVecI32x16): TVecI32x8; inline;

// 提取 F64x8 的低/高半部分
function VecF64x8ExtractLo(const a: TVecF64x8): TVecF64x4; inline;
function VecF64x8ExtractHi(const a: TVecF64x8): TVecF64x4; inline;

implementation

uses
  nextpas.core.simd.mathutil,
  nextpas.core.contracts;

procedure RequireGatherScatterBaseAssigned(base: Pointer; const apiName: string); inline;
begin
  ContractsRequireAssigned(base <> nil, apiName + ' base pointer');
end;

// === Shuffle/Swizzle 实现 ===
function MM_SHUFFLE(d, c, b, a: Byte): Byte; inline;
begin
  Result := (d shl 6) or (c shl 4) or (b shl 2) or a;
end;

function _pick4(const idx: Byte; const a: TVecF32x4): TVecF32x4;
var sel: array[0..3] of Byte;
begin
  sel[0] := idx and $3;
  sel[1] := (idx shr 2) and $3;
  sel[2] := (idx shr 4) and $3;
  sel[3] := (idx shr 6) and $3;
  Result.f[0] := a.f[sel[0]];
  Result.f[1] := a.f[sel[1]];
  Result.f[2] := a.f[sel[2]];
  Result.f[3] := a.f[sel[3]];
end;

function _pick4i(const idx: Byte; const a: TVecI32x4): TVecI32x4;
var sel: array[0..3] of Byte;
begin
  sel[0] := idx and $3;
  sel[1] := (idx shr 2) and $3;
  sel[2] := (idx shr 4) and $3;
  sel[3] := (idx shr 6) and $3;
  Result.i[0] := a.i[sel[0]];
  Result.i[1] := a.i[sel[1]];
  Result.i[2] := a.i[sel[2]];
  Result.i[3] := a.i[sel[3]];
end;

function VecF32x4Shuffle(const a: TVecF32x4; imm8: Byte): TVecF32x4;
begin
  Result := _pick4(imm8, a);
end;

function VecI32x4Shuffle(const a: TVecI32x4; imm8: Byte): TVecI32x4;
begin
  Result := _pick4i(imm8, a);
end;

function VecF32x4Shuffle2(const a, b: TVecF32x4; imm8: Byte): TVecF32x4;
var sel: array[0..3] of Byte;
    src: array[0..3] of Single;
begin
  sel[0] := imm8 and $3;
  sel[1] := (imm8 shr 2) and $3;
  sel[2] := (imm8 shr 4) and $3;
  sel[3] := (imm8 shr 6) and $3;
  src[0] := a.f[sel[0]];
  src[1] := a.f[sel[1]];
  src[2] := b.f[sel[2]];
  src[3] := b.f[sel[3]];
  Result.f[0] := src[0];
  Result.f[1] := src[1];
  Result.f[2] := src[2];
  Result.f[3] := src[3];
end;

function VecF32x4Blend(const a, b: TVecF32x4; mask: Byte): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if ((mask shr i) and 1) <> 0 then
      Result.f[i] := b.f[i]
    else
      Result.f[i] := a.f[i];
end;

function VecF64x2Blend(const a, b: TVecF64x2; mask: Byte): TVecF64x2;
var i: Integer;
begin
  for i := 0 to 1 do
    if ((mask shr i) and 1) <> 0 then
      Result.d[i] := b.d[i]
    else
      Result.d[i] := a.d[i];
end;

function VecI32x4Blend(const a, b: TVecI32x4; mask: Byte): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if ((mask shr i) and 1) <> 0 then
      Result.i[i] := b.i[i]
    else
      Result.i[i] := a.i[i];
end;

function VecF32x4UnpackLo(const a, b: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[0]; Result.f[1] := b.f[0];
  Result.f[2] := a.f[1]; Result.f[3] := b.f[1];
end;

function VecF32x4UnpackHi(const a, b: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[2]; Result.f[1] := b.f[2];
  Result.f[2] := a.f[3]; Result.f[3] := b.f[3];
end;

function VecI32x4UnpackLo(const a, b: TVecI32x4): TVecI32x4;
begin
  Result.i[0] := a.i[0]; Result.i[1] := b.i[0];
  Result.i[2] := a.i[1]; Result.i[3] := b.i[1];
end;

function VecI32x4UnpackHi(const a, b: TVecI32x4): TVecI32x4;
begin
  Result.i[0] := a.i[2]; Result.i[1] := b.i[2];
  Result.i[2] := a.i[3]; Result.i[3] := b.i[3];
end;

function VecF32x4Broadcast(const a: TVecF32x4; index: Integer): TVecF32x4;
var v: Single;
    idx: Integer;
begin
  // Saturate index to [0..3]
  if index < 0 then idx := 0
  else if index > 3 then idx := 3
  else idx := index;
  v := a.f[idx];
  Result.f[0] := v; Result.f[1] := v; Result.f[2] := v; Result.f[3] := v;
end;

function VecI32x4Broadcast(const a: TVecI32x4; index: Integer): TVecI32x4;
var v: Int32;
    idx: Integer;
begin
  // Saturate index to [0..3]
  if index < 0 then idx := 0
  else if index > 3 then idx := 3
  else idx := index;
  v := a.i[idx];
  Result.i[0] := v; Result.i[1] := v; Result.i[2] := v; Result.i[3] := v;
end;

function VecF32x4Reverse(const a: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[3];
  Result.f[1] := a.f[2];
  Result.f[2] := a.f[1];
  Result.f[3] := a.f[0];
end;

function VecI32x4Reverse(const a: TVecI32x4): TVecI32x4;
begin
  Result.i[0] := a.i[3];
  Result.i[1] := a.i[2];
  Result.i[2] := a.i[1];
  Result.i[3] := a.i[0];
end;

function VecF32x4RotateLeft(const a: TVecF32x4; n: Integer): TVecF32x4;
var k: Integer;
begin
  k := (n and 3);
  Result.f[0] := a.f[(0 + k) and 3];
  Result.f[1] := a.f[(1 + k) and 3];
  Result.f[2] := a.f[(2 + k) and 3];
  Result.f[3] := a.f[(3 + k) and 3];
end;

function VecI32x4RotateLeft(const a: TVecI32x4; n: Integer): TVecI32x4;
var k: Integer;
begin
  k := (n and 3);
  Result.i[0] := a.i[(0 + k) and 3];
  Result.i[1] := a.i[(1 + k) and 3];
  Result.i[2] := a.i[(2 + k) and 3];
  Result.i[3] := a.i[(3 + k) and 3];
end;

function VecF32x4RotateRight(const a: TVecF32x4; n: Integer): TVecF32x4;
var k: Integer;
begin
  k := (4 - (n and 3)) and 3;
  Result.f[0] := a.f[(0 + k) and 3];
  Result.f[1] := a.f[(1 + k) and 3];
  Result.f[2] := a.f[(2 + k) and 3];
  Result.f[3] := a.f[(3 + k) and 3];
end;

function VecI32x4RotateRight(const a: TVecI32x4; n: Integer): TVecI32x4;
var k: Integer;
begin
  k := (4 - (n and 3)) and 3;
  Result.i[0] := a.i[(0 + k) and 3];
  Result.i[1] := a.i[(1 + k) and 3];
  Result.i[2] := a.i[(2 + k) and 3];
  Result.i[3] := a.i[(3 + k) and 3];
end;

// === Shift Elements 实现 (Rust portable-simd 对齐) ===

function VecF32x4ShiftElementsLeft(const a: TVecF32x4; offset: Integer; padding: Single): TVecF32x4;
var i: Integer;
begin
  // 元素向左移位，右侧填充 padding
  // offset=1: [a1, a2, a3, padding]
  // offset=2: [a2, a3, padding, padding]
  for i := 0 to 3 do
  begin
    if i + offset < 4 then
      Result.f[i] := a.f[i + offset]
    else
      Result.f[i] := padding;
  end;
end;

function VecF32x4ShiftElementsRight(const a: TVecF32x4; offset: Integer; padding: Single): TVecF32x4;
var i: Integer;
begin
  // 元素向右移位，左侧填充 padding
  // offset=1: [padding, a0, a1, a2]
  // offset=2: [padding, padding, a0, a1]
  for i := 0 to 3 do
  begin
    if i - offset >= 0 then
      Result.f[i] := a.f[i - offset]
    else
      Result.f[i] := padding;
  end;
end;

function VecI32x4ShiftElementsLeft(const a: TVecI32x4; offset: Integer; padding: Int32): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if i + offset < 4 then
      Result.i[i] := a.i[i + offset]
    else
      Result.i[i] := padding;
  end;
end;

function VecI32x4ShiftElementsRight(const a: TVecI32x4; offset: Integer; padding: Int32): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    if i - offset >= 0 then
      Result.i[i] := a.i[i - offset]
    else
      Result.i[i] := padding;
  end;
end;

// === Interleave/Deinterleave 实现 (Rust portable-simd 对齐) ===

procedure VecF32x4Interleave(const a, b: TVecF32x4; out lo, hi: TVecF32x4);
begin
  // interleave: [a0,a1,a2,a3] + [b0,b1,b2,b3] -> ([a0,b0,a1,b1], [a2,b2,a3,b3])
  lo.f[0] := a.f[0];
  lo.f[1] := b.f[0];
  lo.f[2] := a.f[1];
  lo.f[3] := b.f[1];
  hi.f[0] := a.f[2];
  hi.f[1] := b.f[2];
  hi.f[2] := a.f[3];
  hi.f[3] := b.f[3];
end;

procedure VecF32x4Deinterleave(const a, b: TVecF32x4; out even, odd: TVecF32x4);
begin
  // deinterleave: [a0,a1,a2,a3] + [b0,b1,b2,b3] -> ([a0,a2,b0,b2], [a1,a3,b1,b3])
  even.f[0] := a.f[0];
  even.f[1] := a.f[2];
  even.f[2] := b.f[0];
  even.f[3] := b.f[2];
  odd.f[0] := a.f[1];
  odd.f[1] := a.f[3];
  odd.f[2] := b.f[1];
  odd.f[3] := b.f[3];
end;

procedure VecI32x4Interleave(const a, b: TVecI32x4; out lo, hi: TVecI32x4);
begin
  lo.i[0] := a.i[0];
  lo.i[1] := b.i[0];
  lo.i[2] := a.i[1];
  lo.i[3] := b.i[1];
  hi.i[0] := a.i[2];
  hi.i[1] := b.i[2];
  hi.i[2] := a.i[3];
  hi.i[3] := b.i[3];
end;

procedure VecI32x4Deinterleave(const a, b: TVecI32x4; out even, odd: TVecI32x4);
begin
  even.i[0] := a.i[0];
  even.i[1] := a.i[2];
  even.i[2] := b.i[0];
  even.i[3] := b.i[2];
  odd.i[0] := a.i[1];
  odd.i[1] := a.i[3];
  odd.i[2] := b.i[1];
  odd.i[3] := b.i[3];
end;

function VecF32x4Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
var
  idx: Integer;
begin
  Result := a;
  idx := index;
  if idx < 0 then
    idx := 0
  else if idx > 3 then
    idx := 3;
  Result.f[idx] := value;
end;

function VecI32x4Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
var
  idx: Integer;
begin
  Result := a;
  idx := index;
  if idx < 0 then
    idx := 0
  else if idx > 3 then
    idx := 3;
  Result.i[idx] := value;
end;

function VecF32x4Extract(const a: TVecF32x4; index: Integer): Single;
var
  idx: Integer;
begin
  idx := index;
  if idx < 0 then
    idx := 0
  else if idx > 3 then
    idx := 3;
  Result := a.f[idx];
end;

function VecI32x4Extract(const a: TVecI32x4; index: Integer): Int32;
var
  idx: Integer;
begin
  idx := index;
  if idx < 0 then
    idx := 0
  else if idx > 3 then
    idx := 3;
  Result := a.i[idx];
end;

// === TMaskF32x4 函数实现 ===

// ✅ P1-3: 展开循环优化
function MaskF32x4AllTrue: TMaskF32x4;
begin
  Result.m[0] := $FFFFFFFF;
  Result.m[1] := $FFFFFFFF;
  Result.m[2] := $FFFFFFFF;
  Result.m[3] := $FFFFFFFF;
end;

// ✅ P1-3: 展开循环优化
function MaskF32x4AllFalse: TMaskF32x4;
begin
  Result.m[0] := 0;
  Result.m[1] := 0;
  Result.m[2] := 0;
  Result.m[3] := 0;
end;

function MaskF32x4Set(m0, m1, m2, m3: Boolean): TMaskF32x4;
begin
  if m0 then Result.m[0] := $FFFFFFFF else Result.m[0] := 0;
  if m1 then Result.m[1] := $FFFFFFFF else Result.m[1] := 0;
  if m2 then Result.m[2] := $FFFFFFFF else Result.m[2] := 0;
  if m3 then Result.m[3] := $FFFFFFFF else Result.m[3] := 0;
end;

function MaskF32x4Test(const m: TMaskF32x4; index: Integer): Boolean;
var
  idx: Integer;
begin
  idx := index;
  if idx < 0 then
    idx := 0
  else if idx > 3 then
    idx := 3;
  Result := m.m[idx] <> 0;
end;

// ✅ P1-3: 展开循环优化
function MaskF32x4ToBitmask(const m: TMaskF32x4): TMask4;
begin
  Result := 0;
  if m.m[0] <> 0 then Result := Result or 1;
  if m.m[1] <> 0 then Result := Result or 2;
  if m.m[2] <> 0 then Result := Result or 4;
  if m.m[3] <> 0 then Result := Result or 8;
end;

function MaskF32x4Any(const m: TMaskF32x4): Boolean;
begin
  Result := (m.m[0] or m.m[1] or m.m[2] or m.m[3]) <> 0;
end;

function MaskF32x4All(const m: TMaskF32x4): Boolean;
begin
  Result := (m.m[0] and m.m[1] and m.m[2] and m.m[3]) = $FFFFFFFF;
end;

function MaskF32x4None(const m: TMaskF32x4): Boolean;
begin
  Result := (m.m[0] or m.m[1] or m.m[2] or m.m[3]) = 0;
end;

// ✅ P1-3: 展开循环优化
function MaskF32x4Select(const m: TMaskF32x4; const a, b: TVecF32x4): TVecF32x4;
begin
  if m.m[0] <> 0 then Result.f[0] := a.f[0] else Result.f[0] := b.f[0];
  if m.m[1] <> 0 then Result.f[1] := a.f[1] else Result.f[1] := b.f[1];
  if m.m[2] <> 0 then Result.f[2] := a.f[2] else Result.f[2] := b.f[2];
  if m.m[3] <> 0 then Result.f[3] := a.f[3] else Result.f[3] := b.f[3];
end;

// === TMaskF64x2 函数实现 ===

// ✅ P1-3: 展开循环优化
function MaskF64x2AllTrue: TMaskF64x2;
begin
  Result.m[0] := High(UInt64);
  Result.m[1] := High(UInt64);
end;

// ✅ P1-3: 展开循环优化
function MaskF64x2AllFalse: TMaskF64x2;
begin
  Result.m[0] := 0;
  Result.m[1] := 0;
end;

// ✅ P1-3: 展开循环优化
function MaskF64x2ToBitmask(const m: TMaskF64x2): TMask2;
begin
  Result := 0;
  if m.m[0] <> 0 then Result := Result or 1;
  if m.m[1] <> 0 then Result := Result or 2;
end;

// === TMaskI32x4 函数实现 ===

// ✅ P1-3: 展开循环优化
function MaskI32x4AllTrue: TMaskI32x4;
begin
  Result.m[0] := $FFFFFFFF;
  Result.m[1] := $FFFFFFFF;
  Result.m[2] := $FFFFFFFF;
  Result.m[3] := $FFFFFFFF;
end;

// ✅ P1-3: 展开循环优化
function MaskI32x4AllFalse: TMaskI32x4;
begin
  Result.m[0] := 0;
  Result.m[1] := 0;
  Result.m[2] := 0;
  Result.m[3] := 0;
end;

// ✅ P1-3: 展开循环优化
function MaskI32x4ToBitmask(const m: TMaskI32x4): TMask4;
begin
  Result := 0;
  if m.m[0] <> 0 then Result := Result or 1;
  if m.m[1] <> 0 then Result := Result or 2;
  if m.m[2] <> 0 then Result := Result or 4;
  if m.m[3] <> 0 then Result := Result or 8;
end;

// === TMaskF32x16 函数实现 (AVX-512) ===

function MaskF32x16AllTrue: TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.m[i] := $FFFFFFFF;
  Result.bits := $FFFF;
end;

function MaskF32x16AllFalse: TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.m[i] := 0;
  Result.bits := 0;
end;

function MaskF32x16ToBitmask(const m: TMaskF32x16): TMask16;
var i: Integer;
begin
  Result := 0;
  for i := 0 to 15 do
    if m.m[i] <> 0 then
      Result := Result or (1 shl i);
end;

function MaskF32x16Any(const m: TMaskF32x16): Boolean;
var i: Integer;
begin
  for i := 0 to 15 do
    if m.m[i] <> 0 then
      Exit(True);
  Result := False;
end;

function MaskF32x16All(const m: TMaskF32x16): Boolean;
var i: Integer;
begin
  for i := 0 to 15 do
    if m.m[i] <> $FFFFFFFF then
      Exit(False);
  Result := True;
end;

function MaskF32x16None(const m: TMaskF32x16): Boolean;
var i: Integer;
begin
  for i := 0 to 15 do
    if m.m[i] <> 0 then
      Exit(False);
  Result := True;
end;

function MaskF32x16FromBitmask(bm: TMask16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if (bm and (1 shl i)) <> 0 then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := bm;
end;

function MaskF32x16Select(const m: TMaskF32x16; const a, b: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if m.m[i] <> 0 then
      Result.f[i] := a.f[i]
    else
      Result.f[i] := b.f[i];
end;

// === 512-bit 向量比较函数实现 (Phase 4) ===

function VecF32x16CmpEq(const a, b: TVecF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.f[i] = b.f[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := MaskF32x16ToBitmask(Result);
end;

function VecF32x16CmpNe(const a, b: TVecF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.f[i] <> b.f[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := MaskF32x16ToBitmask(Result);
end;

function VecF32x16CmpLt(const a, b: TVecF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.f[i] < b.f[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := MaskF32x16ToBitmask(Result);
end;

function VecF32x16CmpLe(const a, b: TVecF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.f[i] <= b.f[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := MaskF32x16ToBitmask(Result);
end;

function VecF32x16CmpGt(const a, b: TVecF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.f[i] > b.f[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := MaskF32x16ToBitmask(Result);
end;

function VecF32x16CmpGe(const a, b: TVecF32x16): TMaskF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.f[i] >= b.f[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := MaskF32x16ToBitmask(Result);
end;

function VecI32x16CmpEq(const a, b: TVecI32x16): TMaskI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] = b.i[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := 0;
  for i := 0 to 15 do
    if Result.m[i] <> 0 then
      Result.bits := Result.bits or (1 shl i);
end;

function VecI32x16CmpLt(const a, b: TVecI32x16): TMaskI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] < b.i[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := 0;
  for i := 0 to 15 do
    if Result.m[i] <> 0 then
      Result.bits := Result.bits or (1 shl i);
end;

function VecI32x16CmpGt(const a, b: TVecI32x16): TMaskI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    if a.i[i] > b.i[i] then
      Result.m[i] := $FFFFFFFF
    else
      Result.m[i] := 0;
  Result.bits := 0;
  for i := 0 to 15 do
    if Result.m[i] <> 0 then
      Result.bits := Result.bits or (1 shl i);
end;

// === 类型转换函数实现 (Phase 1.4) ===

function VecF32x4IntoBits(const a: TVecF32x4): TVecI32x4;
begin
  Result.raw := a.raw;
end;

function VecI32x4FromBitsF32(const a: TVecI32x4): TVecF32x4;
begin
  Result.raw := a.raw;
end;

function VecF64x2IntoBits(const a: TVecF64x2): TVecI64x2;
begin
  Result.raw := a.raw;
end;

function VecI64x2FromBitsF64(const a: TVecI64x2): TVecF64x2;
begin
  Result.raw := a.raw;
end;

function VecF32x4CastToI32x4(const a: TVecF32x4): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := Trunc(a.f[i]);
end;

function VecI32x4CastToF32x4(const a: TVecI32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := a.i[i];
end;

function VecF64x2CastToI64x2(const a: TVecF64x2): TVecI64x2;
var i: Integer;
begin
  for i := 0 to 1 do
    Result.i[i] := Trunc(a.d[i]);
end;

function VecI64x2CastToF64x2(const a: TVecI64x2): TVecF64x2;
var i: Integer;
begin
  for i := 0 to 1 do
    Result.d[i] := a.i[i];
end;

function VecI16x8WidenLoI32x4(const a: TVecI16x8): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i];
end;

function VecI16x8WidenHiI32x4(const a: TVecI16x8): TVecI32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := a.i[i + 4];
end;

function VecI32x4NarrowToI16x8(const a, b: TVecI32x4): TVecI16x8;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.i[i] := Int16(a.i[i]);
  for i := 0 to 3 do
    Result.i[i + 4] := Int16(b.i[i]);
end;

function VecF32x4ToF64x2Lo(const a: TVecF32x4): TVecF64x2;
var i: Integer;
begin
  for i := 0 to 1 do
    Result.d[i] := a.f[i];
end;

function VecF64x2ToF32x4(const a, b: TVecF64x2): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 1 do
    Result.f[i] := Single(a.d[i]);
  for i := 0 to 1 do
    Result.f[i + 2] := Single(b.d[i]);
end;

// === SIMD 数学函数实现 (Phase 4) ===

function VecF32x4Sin(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Sin(a.f[i]);
end;

function VecF32x4Cos(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Cos(a.f[i]);
end;

procedure VecF32x4SinCos(const a: TVecF32x4; out sinResult, cosResult: TVecF32x4);
var i: Integer;
begin
  for i := 0 to 3 do
  begin
    sinResult.f[i] := Sin(a.f[i]);
    cosResult.f[i] := Cos(a.f[i]);
  end;
end;

function VecF32x4Tan(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdTanF32(a.f[i]);
end;

function VecF32x4Exp(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Exp(a.f[i]);
end;

function VecF32x4Exp2(const a: TVecF32x4): TVecF32x4;
const LN2 = 0.6931471805599453;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Exp(a.f[i] * LN2);
end;

function VecF32x4Log(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Ln(a.f[i]);
end;

function VecF32x4Log2(const a: TVecF32x4): TVecF32x4;
const INV_LN2 = 1.4426950408889634;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Ln(a.f[i]) * INV_LN2;
end;

function VecF32x4Log10(const a: TVecF32x4): TVecF32x4;
const INV_LN10 = 0.4342944819032518;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := Ln(a.f[i]) * INV_LN10;
end;

function VecF32x4Pow(const base, exponent: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    if base.f[i] > 0 then
      Result.f[i] := Exp(exponent.f[i] * Ln(base.f[i]))
    else if base.f[i] = 0 then
      Result.f[i] := 0
    else
      Result.f[i] := 0/0;  // NaN for negative base
end;

function VecF32x4Asin(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdArcSinF32(a.f[i]);
end;

function VecF32x4Acos(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdArcCosF32(a.f[i]);
end;

function VecF32x4Atan(const a: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := ArcTan(a.f[i]);
end;

function VecF32x4Atan2(const y, x: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.f[i] := SimdArcTan2F32(y.f[i], x.f[i]);
end;

// === 高级算法实现 (Phase 5) ===

function SortNet4I32(const a: TVecI32x4; ascending: Boolean): TVecI32x4;
var
  tmp: Int32;
begin
  Result := a;
  if ascending then
  begin
    if Result.i[0] > Result.i[1] then begin tmp := Result.i[0]; Result.i[0] := Result.i[1]; Result.i[1] := tmp; end;
    if Result.i[2] > Result.i[3] then begin tmp := Result.i[2]; Result.i[2] := Result.i[3]; Result.i[3] := tmp; end;
    if Result.i[0] > Result.i[2] then begin tmp := Result.i[0]; Result.i[0] := Result.i[2]; Result.i[2] := tmp; end;
    if Result.i[1] > Result.i[3] then begin tmp := Result.i[1]; Result.i[1] := Result.i[3]; Result.i[3] := tmp; end;
    if Result.i[1] > Result.i[2] then begin tmp := Result.i[1]; Result.i[1] := Result.i[2]; Result.i[2] := tmp; end;
  end
  else
  begin
    if Result.i[0] < Result.i[1] then begin tmp := Result.i[0]; Result.i[0] := Result.i[1]; Result.i[1] := tmp; end;
    if Result.i[2] < Result.i[3] then begin tmp := Result.i[2]; Result.i[2] := Result.i[3]; Result.i[3] := tmp; end;
    if Result.i[0] < Result.i[2] then begin tmp := Result.i[0]; Result.i[0] := Result.i[2]; Result.i[2] := tmp; end;
    if Result.i[1] < Result.i[3] then begin tmp := Result.i[1]; Result.i[1] := Result.i[3]; Result.i[3] := tmp; end;
    if Result.i[1] < Result.i[2] then begin tmp := Result.i[1]; Result.i[1] := Result.i[2]; Result.i[2] := tmp; end;
  end;
end;

function SortNet4F32(const a: TVecF32x4; ascending: Boolean): TVecF32x4;
var
  tmp: Single;
  function NeedSwap(const aLeft, aRight: Single): Boolean; inline;
  begin
    // Deterministic NaN policy: always push NaN lanes to the tail.
    if SimdIsNaN(aLeft) then
      Exit(not SimdIsNaN(aRight));
    if SimdIsNaN(aRight) then
      Exit(False);

    if ascending then
      Result := aLeft > aRight
    else
      Result := aLeft < aRight;
  end;
begin
  Result := a;
  if ascending then
  begin
    if NeedSwap(Result.f[0], Result.f[1]) then begin tmp := Result.f[0]; Result.f[0] := Result.f[1]; Result.f[1] := tmp; end;
    if NeedSwap(Result.f[2], Result.f[3]) then begin tmp := Result.f[2]; Result.f[2] := Result.f[3]; Result.f[3] := tmp; end;
    if NeedSwap(Result.f[0], Result.f[2]) then begin tmp := Result.f[0]; Result.f[0] := Result.f[2]; Result.f[2] := tmp; end;
    if NeedSwap(Result.f[1], Result.f[3]) then begin tmp := Result.f[1]; Result.f[1] := Result.f[3]; Result.f[3] := tmp; end;
    if NeedSwap(Result.f[1], Result.f[2]) then begin tmp := Result.f[1]; Result.f[1] := Result.f[2]; Result.f[2] := tmp; end;
  end
  else
  begin
    if NeedSwap(Result.f[0], Result.f[1]) then begin tmp := Result.f[0]; Result.f[0] := Result.f[1]; Result.f[1] := tmp; end;
    if NeedSwap(Result.f[2], Result.f[3]) then begin tmp := Result.f[2]; Result.f[2] := Result.f[3]; Result.f[3] := tmp; end;
    if NeedSwap(Result.f[0], Result.f[2]) then begin tmp := Result.f[0]; Result.f[0] := Result.f[2]; Result.f[2] := tmp; end;
    if NeedSwap(Result.f[1], Result.f[3]) then begin tmp := Result.f[1]; Result.f[1] := Result.f[3]; Result.f[3] := tmp; end;
    if NeedSwap(Result.f[1], Result.f[2]) then begin tmp := Result.f[1]; Result.f[1] := Result.f[2]; Result.f[2] := tmp; end;
  end;
end;

function SortNet8I32(const a: TVecI32x8; ascending: Boolean): TVecI32x8;
var
  tmp: Int32;
  i, j: Integer;
begin
  Result := a;
  Result.lo := SortNet4I32(Result.lo, ascending);
  Result.hi := SortNet4I32(Result.hi, ascending);

  if ascending then
  begin
    for i := 0 to 3 do
    begin
      if Result.i[i] > Result.i[i + 4] then
      begin
        tmp := Result.i[i]; Result.i[i] := Result.i[i + 4]; Result.i[i + 4] := tmp;
      end;
    end;
    for i := 1 to 3 do
      for j := i downto 1 do
        if Result.i[j-1] > Result.i[j] then
        begin
          tmp := Result.i[j-1]; Result.i[j-1] := Result.i[j]; Result.i[j] := tmp;
        end;
    for i := 5 to 7 do
      for j := i downto 5 do
        if Result.i[j-1] > Result.i[j] then
        begin
          tmp := Result.i[j-1]; Result.i[j-1] := Result.i[j]; Result.i[j] := tmp;
        end;
    for i := 1 to 6 do
      for j := i downto 1 do
        if Result.i[j-1] > Result.i[j] then
        begin
          tmp := Result.i[j-1]; Result.i[j-1] := Result.i[j]; Result.i[j] := tmp;
        end;
  end
  else
  begin
    for i := 0 to 3 do
    begin
      if Result.i[i] < Result.i[i + 4] then
      begin
        tmp := Result.i[i]; Result.i[i] := Result.i[i + 4]; Result.i[i + 4] := tmp;
      end;
    end;
    for i := 1 to 6 do
      for j := i downto 1 do
        if Result.i[j-1] < Result.i[j] then
        begin
          tmp := Result.i[j-1]; Result.i[j-1] := Result.i[j]; Result.i[j] := tmp;
        end;
  end;
end;

{$PUSH}{$R-}{$Q-}
function PrefixSumI32x4(const a: TVecI32x4; inclusive: Boolean): TVecI32x4;
begin
  if inclusive then
  begin
    Result.i[0] := a.i[0];
    Result.i[1] := a.i[0] + a.i[1];
    Result.i[2] := a.i[0] + a.i[1] + a.i[2];
    Result.i[3] := a.i[0] + a.i[1] + a.i[2] + a.i[3];
  end
  else
  begin
    Result.i[0] := 0;
    Result.i[1] := a.i[0];
    Result.i[2] := a.i[0] + a.i[1];
    Result.i[3] := a.i[0] + a.i[1] + a.i[2];
  end;
end;
{$POP}

function PrefixSumF32x4(const a: TVecF32x4; inclusive: Boolean): TVecF32x4;
begin
  if inclusive then
  begin
    Result.f[0] := a.f[0];
    Result.f[1] := a.f[0] + a.f[1];
    Result.f[2] := a.f[0] + a.f[1] + a.f[2];
    Result.f[3] := a.f[0] + a.f[1] + a.f[2] + a.f[3];
  end
  else
  begin
    Result.f[0] := 0;
    Result.f[1] := a.f[0];
    Result.f[2] := a.f[0] + a.f[1];
    Result.f[3] := a.f[0] + a.f[1] + a.f[2];
  end;
end;

// ✅ P1-6: SIMD 优化的前缀和数组
procedure PrefixSumArrayI32(src, dst: PInt32; count: SizeUInt);
var
  i, blocks, remaining: SizeUInt;
  sum: Int32;
  vec, prefixVec: TVecI32x4;
  pSrc, pDst: PInt32;
begin
  if count = 0 then Exit;
  if (src = nil) or (dst = nil) then Exit;

  sum := 0;
  pSrc := src;
  pDst := dst;

  // 快速路径: 按 4 元素块处理
  blocks := count div 4;
  {$PUSH}{$R-}{$Q-}
  for i := 0 to blocks - 1 do
  begin
    // 加载 4 个元素
    vec.i[0] := pSrc[0];
    vec.i[1] := pSrc[1];
    vec.i[2] := pSrc[2];
    vec.i[3] := pSrc[3];

    // 计算块内前缀和
    prefixVec := PrefixSumI32x4(vec, True);

    // 加上前面块的累加值
    pDst[0] := sum + prefixVec.i[0];
    pDst[1] := sum + prefixVec.i[1];
    pDst[2] := sum + prefixVec.i[2];
    pDst[3] := sum + prefixVec.i[3];

    // 更新累加值为本块最后一个结果
    sum := sum + prefixVec.i[3];

    Inc(pSrc, 4);
    Inc(pDst, 4);
  end;

  // 处理剩余的 0-3 个元素
  remaining := count mod 4;
  if remaining > 0 then
  begin
    for i := 0 to remaining - 1 do
    begin
      sum := sum + pSrc[i];
      pDst[i] := sum;
    end;
  end;
  {$POP}
end;

// ✅ P1-6: SIMD 优化的前缀和数组
procedure PrefixSumArrayF32(src, dst: PSingle; count: SizeUInt);
var
  i, blocks, remaining: SizeUInt;
  sum: Single;
  vec, prefixVec: TVecF32x4;
  pSrc, pDst: PSingle;
begin
  if count = 0 then Exit;
  if (src = nil) or (dst = nil) then Exit;

  sum := 0.0;
  pSrc := src;
  pDst := dst;

  // 快速路径: 按 4 元素块处理
  blocks := count div 4;
  for i := 0 to blocks - 1 do
  begin
    // 加载 4 个元素
    vec.f[0] := pSrc[0];
    vec.f[1] := pSrc[1];
    vec.f[2] := pSrc[2];
    vec.f[3] := pSrc[3];

    // 计算块内前缀和
    prefixVec := PrefixSumF32x4(vec, True);

    // 加上前面块的累加值
    pDst[0] := sum + prefixVec.f[0];
    pDst[1] := sum + prefixVec.f[1];
    pDst[2] := sum + prefixVec.f[2];
    pDst[3] := sum + prefixVec.f[3];

    // 更新累加值为本块最后一个结果
    sum := sum + prefixVec.f[3];

    Inc(pSrc, 4);
    Inc(pDst, 4);
  end;

  // 处理剩余的 0-3 个元素
  remaining := count mod 4;
  if remaining > 0 then
  begin
    for i := 0 to remaining - 1 do
    begin
      sum := sum + pSrc[i];
      pDst[i] := sum;
    end;
  end;
end;

function StrFindChar(p: Pointer; len: SizeUInt; ch: Byte): PtrInt;
var
  i: SizeUInt;
  pb: PByte;
begin
  if (p = nil) or (len = 0) then
    Exit(-1);

  pb := PByte(p);
  for i := 0 to len - 1 do
  begin
    if pb[i] = ch then
      Exit(i);
  end;

  Result := -1;
end;

// === Gather/Scatter 实现 ===
function VecF32x4Gather(base: PSingle; const indices: TVecI32x4): TVecF32x4;
begin
  RequireGatherScatterBaseAssigned(base, 'VecF32x4Gather');
  Result.f[0] := base[indices.i[0]];
  Result.f[1] := base[indices.i[1]];
  Result.f[2] := base[indices.i[2]];
  Result.f[3] := base[indices.i[3]];
end;

function VecI32x4Gather(base: PInt32; const indices: TVecI32x4): TVecI32x4;
begin
  RequireGatherScatterBaseAssigned(base, 'VecI32x4Gather');
  Result.i[0] := base[indices.i[0]];
  Result.i[1] := base[indices.i[1]];
  Result.i[2] := base[indices.i[2]];
  Result.i[3] := base[indices.i[3]];
end;

procedure VecF32x4Scatter(base: PSingle; const indices: TVecI32x4; const values: TVecF32x4);
begin
  RequireGatherScatterBaseAssigned(base, 'VecF32x4Scatter');
  base[indices.i[0]] := values.f[0];
  base[indices.i[1]] := values.f[1];
  base[indices.i[2]] := values.f[2];
  base[indices.i[3]] := values.f[3];
end;

procedure VecI32x4Scatter(base: PInt32; const indices: TVecI32x4; const values: TVecI32x4);
begin
  RequireGatherScatterBaseAssigned(base, 'VecI32x4Scatter');
  base[indices.i[0]] := values.i[0];
  base[indices.i[1]] := values.i[1];
  base[indices.i[2]] := values.i[2];
  base[indices.i[3]] := values.i[3];
end;

// === Masked Gather/Scatter 实现 (Rust portable-simd 对齐) ===
// gather_select: 带掩码的 gather，enable=false 时使用 orVal
// scatter_select: 带掩码的 scatter，enable=false 时跳过写入

function VecF32x4GatherSelect(base: PSingle; const enable: TMask4; const indices: TVecI32x4; const orVal: TVecF32x4): TVecF32x4;
var i: Integer;
begin
  if enable = 0 then
    Exit(orVal);

  RequireGatherScatterBaseAssigned(base, 'VecF32x4GatherSelect');
  for i := 0 to 3 do
  begin
    if (enable and (1 shl i)) <> 0 then
      Result.f[i] := base[indices.i[i]]
    else
      Result.f[i] := orVal.f[i];
  end;
end;

function VecI32x4GatherSelect(base: PInt32; const enable: TMask4; const indices: TVecI32x4; const orVal: TVecI32x4): TVecI32x4;
var i: Integer;
begin
  if enable = 0 then
    Exit(orVal);

  RequireGatherScatterBaseAssigned(base, 'VecI32x4GatherSelect');
  for i := 0 to 3 do
  begin
    if (enable and (1 shl i)) <> 0 then
      Result.i[i] := base[indices.i[i]]
    else
      Result.i[i] := orVal.i[i];
  end;
end;

procedure VecF32x4ScatterSelect(base: PSingle; const enable: TMask4; const indices: TVecI32x4; const values: TVecF32x4);
var i: Integer;
begin
  if enable = 0 then
    Exit;

  RequireGatherScatterBaseAssigned(base, 'VecF32x4ScatterSelect');
  for i := 0 to 3 do
  begin
    if (enable and (1 shl i)) <> 0 then
      base[indices.i[i]] := values.f[i];
    // enable=false 时跳过写入
  end;
end;

procedure VecI32x4ScatterSelect(base: PInt32; const enable: TMask4; const indices: TVecI32x4; const values: TVecI32x4);
var i: Integer;
begin
  if enable = 0 then
    Exit;

  RequireGatherScatterBaseAssigned(base, 'VecI32x4ScatterSelect');
  for i := 0 to 3 do
  begin
    if (enable and (1 shl i)) <> 0 then
      base[indices.i[i]] := values.i[i];
    // enable=false 时跳过写入
  end;
end;

// === Resize/Extract/Concat 函数实现 (Rust portable-simd 对齐) ===

// F32x4 <-> F32x8 转换
function VecF32x4ResizeToF32x8(const a: TVecF32x4; padding: Single): TVecF32x8;
var i: Integer;
begin
  // 低 4 个元素来自 a
  for i := 0 to 3 do
    Result.f[i] := a.f[i];
  // 高 4 个元素填充 padding
  for i := 4 to 7 do
    Result.f[i] := padding;
end;

function VecF32x8ResizeToF32x4(const a: TVecF32x8): TVecF32x4;
begin
  // 截断，仅保留低 4 个元素
  Result := a.lo;
end;

function VecF32x4Concat(const a, b: TVecF32x4): TVecF32x8;
begin
  Result.lo := a;
  Result.hi := b;
end;

// F32x8 <-> F32x16 转换
function VecF32x8ResizeToF32x16(const a: TVecF32x8; padding: Single): TVecF32x16;
var i: Integer;
begin
  // 低 8 个元素来自 a
  Result.lo := a;
  // 高 8 个元素填充 padding
  for i := 0 to 7 do
    Result.hi.f[i] := padding;
end;

function VecF32x16ResizeToF32x8(const a: TVecF32x16): TVecF32x8;
begin
  // 截断，仅保留低 8 个元素
  Result := a.lo;
end;

function VecF32x8Concat(const a, b: TVecF32x8): TVecF32x16;
begin
  Result.lo := a;
  Result.hi := b;
end;

// I32x4 <-> I32x8 转换
function VecI32x4ResizeToI32x8(const a: TVecI32x4; padding: Int32): TVecI32x8;
var i: Integer;
begin
  // 低 4 个元素来自 a
  for i := 0 to 3 do
    Result.i[i] := a.i[i];
  // 高 4 个元素填充 padding
  for i := 4 to 7 do
    Result.i[i] := padding;
end;

function VecI32x8ResizeToI32x4(const a: TVecI32x8): TVecI32x4;
begin
  // 截断，仅保留低 4 个元素
  Result := a.lo;
end;

function VecI32x4Concat(const a, b: TVecI32x4): TVecI32x8;
begin
  Result.lo := a;
  Result.hi := b;
end;

// I32x8 <-> I32x16 转换
function VecI32x8ResizeToI32x16(const a: TVecI32x8; padding: Int32): TVecI32x16;
var i: Integer;
begin
  // 低 8 个元素来自 a
  Result.lo := a;
  // 高 8 个元素填充 padding
  for i := 0 to 7 do
    Result.hi.i[i] := padding;
end;

function VecI32x16ResizeToI32x8(const a: TVecI32x16): TVecI32x8;
begin
  // 截断，仅保留低 8 个元素
  Result := a.lo;
end;

function VecI32x8Concat(const a, b: TVecI32x8): TVecI32x16;
begin
  Result.lo := a;
  Result.hi := b;
end;

// F64x2 <-> F64x4 转换
function VecF64x2ResizeToF64x4(const a: TVecF64x2; padding: Double): TVecF64x4;
var i: Integer;
begin
  // 低 2 个元素来自 a
  for i := 0 to 1 do
    Result.d[i] := a.d[i];
  // 高 2 个元素填充 padding
  for i := 2 to 3 do
    Result.d[i] := padding;
end;

function VecF64x4ResizeToF64x2(const a: TVecF64x4): TVecF64x2;
begin
  // 截断，仅保留低 2 个元素
  Result := a.lo;
end;

function VecF64x2Concat(const a, b: TVecF64x2): TVecF64x4;
begin
  Result.lo := a;
  Result.hi := b;
end;

// F64x4 <-> F64x8 转换
function VecF64x4ResizeToF64x8(const a: TVecF64x4; padding: Double): TVecF64x8;
var i: Integer;
begin
  // 低 4 个元素来自 a
  Result.lo := a;
  // 高 4 个元素填充 padding
  for i := 0 to 3 do
    Result.hi.d[i] := padding;
end;

function VecF64x8ResizeToF64x4(const a: TVecF64x8): TVecF64x4;
begin
  // 截断，仅保留低 4 个元素
  Result := a.lo;
end;

function VecF64x4Concat(const a, b: TVecF64x4): TVecF64x8;
begin
  Result.lo := a;
  Result.hi := b;
end;

// === Extract 函数实现 - 提取子向量 (Rust: extract::<START, LEN>) ===

// 提取 F32x8 的低/高半部分
function VecF32x8ExtractLo(const a: TVecF32x8): TVecF32x4;
begin
  Result := a.lo;
end;

function VecF32x8ExtractHi(const a: TVecF32x8): TVecF32x4;
begin
  Result := a.hi;
end;

// 提取 I32x8 的低/高半部分
function VecI32x8ExtractLo(const a: TVecI32x8): TVecI32x4;
begin
  Result := a.lo;
end;

function VecI32x8ExtractHi(const a: TVecI32x8): TVecI32x4;
begin
  Result := a.hi;
end;

// 提取 F64x4 的低/高半部分
function VecF64x4ExtractLo(const a: TVecF64x4): TVecF64x2;
begin
  Result := a.lo;
end;

function VecF64x4ExtractHi(const a: TVecF64x4): TVecF64x2;
begin
  Result := a.hi;
end;

// 提取 F32x16 的低/高半部分
function VecF32x16ExtractLo(const a: TVecF32x16): TVecF32x8;
begin
  Result := a.lo;
end;

function VecF32x16ExtractHi(const a: TVecF32x16): TVecF32x8;
begin
  Result := a.hi;
end;

// 提取 I32x16 的低/高半部分
function VecI32x16ExtractLo(const a: TVecI32x16): TVecI32x8;
begin
  Result := a.lo;
end;

function VecI32x16ExtractHi(const a: TVecI32x16): TVecI32x8;
begin
  Result := a.hi;
end;

// 提取 F64x8 的低/高半部分
function VecF64x8ExtractLo(const a: TVecF64x8): TVecF64x4;
begin
  Result := a.lo;
end;

function VecF64x8ExtractHi(const a: TVecF64x8): TVecF64x4;
begin
  Result := a.hi;
end;

// === Swizzle Dyn 实现 (Rust portable-simd 对齐) ===
// 语义: 使用索引向量重新排列元素，越界索引返回 0
// Rust fallback:
//   let mut array = [0; N];
//   for (i, k) in idxs.to_array().into_iter().enumerate() {
//       if (k as usize) < N {
//           array[i] = self[k as usize];
//       };
//   }
//   array.into()

function VecU8x16SwizzleDyn(const a, idxs: TVecU8x16): TVecU8x16;
var
  i: Integer;
  idx: Byte;
begin
  for i := 0 to 15 do
  begin
    idx := idxs.u[i];
    if idx < 16 then
      Result.u[i] := a.u[idx]
    else
      Result.u[i] := 0;  // 越界返回 0
  end;
end;

function VecU8x32SwizzleDyn(const a, idxs: TVecU8x32): TVecU8x32;
var
  i: Integer;
  idx: Byte;
begin
  for i := 0 to 31 do
  begin
    idx := idxs.u[i];
    if idx < 32 then
      Result.u[i] := a.u[idx]
    else
      Result.u[i] := 0;  // 越界返回 0
  end;
end;

function VecU8x64SwizzleDyn(const a, idxs: TVecU8x64): TVecU8x64;
var
  i: Integer;
  idx: Byte;
begin
  for i := 0 to 63 do
  begin
    idx := idxs.u[i];
    if idx < 64 then
      Result.u[i] := a.u[idx]
    else
      Result.u[i] := 0;  // 越界返回 0
  end;
end;

function VecI8x16SwizzleDyn(const a: TVecI8x16; const idxs: TVecU8x16): TVecI8x16;
var
  i: Integer;
  idx: Byte;
begin
  for i := 0 to 15 do
  begin
    idx := idxs.u[i];
    if idx < 16 then
      Result.i[i] := a.i[idx]
    else
      Result.i[i] := 0;  // 越界返回 0
  end;
end;

function VecI8x32SwizzleDyn(const a: TVecI8x32; const idxs: TVecU8x32): TVecI8x32;
var
  i: Integer;
  idx: Byte;
begin
  for i := 0 to 31 do
  begin
    idx := idxs.u[i];
    if idx < 32 then
      Result.i[i] := a.i[idx]
    else
      Result.i[i] := 0;  // 越界返回 0
  end;
end;

function VecI8x64SwizzleDyn(const a: TVecI8x64; const idxs: TVecU8x64): TVecI8x64;
var
  i: Integer;
  idx: Byte;
begin
  for i := 0 to 63 do
  begin
    idx := idxs.u[i];
    if idx < 64 then
      Result.i[i] := a.i[idx]
    else
      Result.i[i] := 0;  // 越界返回 0
  end;
end;

end.
