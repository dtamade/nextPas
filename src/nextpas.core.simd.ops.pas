unit nextpas.core.simd.ops;

{$mode objfpc}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.base;

// =============================================================
// SIMD 向量运算符重载
// - 默认公开入口最常用的 128-bit 运算符现在已回收到
//   nextpas.core.simd.base，以便 `uses nextpas.core.simd;` 直接生效。
// - 本单元保留更宽向量和兼容层所需的运算符重载实现。
// - 通过 dispatch 系统自动选择最佳 SIMD 后端
// =============================================================

// TVecI64x2 运算符 (P1.3)
operator + (const a, b: TVecI64x2): TVecI64x2; inline;
operator - (const a, b: TVecI64x2): TVecI64x2; inline;
operator - (const a: TVecI64x2): TVecI64x2; inline;
operator and (const a, b: TVecI64x2): TVecI64x2; inline;
operator or (const a, b: TVecI64x2): TVecI64x2; inline;
operator xor (const a, b: TVecI64x2): TVecI64x2; inline;
operator not (const a: TVecI64x2): TVecI64x2; inline;

// TVecU32x4 / TVecU64x2 / TVecU16x8 / TVecU8x16 运算符 (128-bit unsigned)
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

// === 256-bit 向量运算符 (Phase 2) ===
// TVecF32x8 运算符
operator + (const a, b: TVecF32x8): TVecF32x8; inline;
operator - (const a, b: TVecF32x8): TVecF32x8; inline;
operator * (const a, b: TVecF32x8): TVecF32x8; inline;
operator / (const a, b: TVecF32x8): TVecF32x8; inline;
operator - (const a: TVecF32x8): TVecF32x8; inline;

// TVecF64x4 运算符
operator + (const a, b: TVecF64x4): TVecF64x4; inline;
operator - (const a, b: TVecF64x4): TVecF64x4; inline;
operator * (const a, b: TVecF64x4): TVecF64x4; inline;
operator / (const a, b: TVecF64x4): TVecF64x4; inline;
operator - (const a: TVecF64x4): TVecF64x4; inline;

// TVecI32x8 运算符
operator + (const a, b: TVecI32x8): TVecI32x8; inline;
operator - (const a, b: TVecI32x8): TVecI32x8; inline;
operator * (const a, b: TVecI32x8): TVecI32x8; inline;
operator - (const a: TVecI32x8): TVecI32x8; inline;
operator and (const a, b: TVecI32x8): TVecI32x8; inline;
operator or (const a, b: TVecI32x8): TVecI32x8; inline;
operator xor (const a, b: TVecI32x8): TVecI32x8; inline;
operator not (const a: TVecI32x8): TVecI32x8; inline;

// TVecU32x8 / TVecU64x4 运算符
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

// === 512-bit 向量运算符 (AVX-512) ===
// TVecF32x16 运算符
operator + (const a, b: TVecF32x16): TVecF32x16; inline;
operator - (const a, b: TVecF32x16): TVecF32x16; inline;
operator * (const a, b: TVecF32x16): TVecF32x16; inline;
operator / (const a, b: TVecF32x16): TVecF32x16; inline;
operator - (const a: TVecF32x16): TVecF32x16; inline;

// TVecF64x8 运算符
operator + (const a, b: TVecF64x8): TVecF64x8; inline;
operator - (const a, b: TVecF64x8): TVecF64x8; inline;
operator * (const a, b: TVecF64x8): TVecF64x8; inline;
operator / (const a, b: TVecF64x8): TVecF64x8; inline;
operator - (const a: TVecF64x8): TVecF64x8; inline;

// TVecI32x16 运算符
operator + (const a, b: TVecI32x16): TVecI32x16; inline;
operator - (const a, b: TVecI32x16): TVecI32x16; inline;
operator * (const a, b: TVecI32x16): TVecI32x16; inline;
operator - (const a: TVecI32x16): TVecI32x16; inline;
operator and (const a, b: TVecI32x16): TVecI32x16; inline;
operator or (const a, b: TVecI32x16): TVecI32x16; inline;
operator xor (const a, b: TVecI32x16): TVecI32x16; inline;
operator not (const a: TVecI32x16): TVecI32x16; inline;

// TVecU32x16 / TVecU64x8 / TVecU8x64 运算符
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

implementation

uses
  nextpas.core.simd.dispatch,
  nextpas.core.simd.direct;

// === TVecI64x2 运算符实现 (128-bit, P1.3) ===
// ✅ P2-B: 简化运算符 - GetDirectDispatchTable 保证返回有效指针，所有槽位已填充
{$PUSH}{$R-}{$Q-}  // Disable overflow checks for wraparound semantics
operator + (const a, b: TVecI64x2): TVecI64x2;
begin
  Result := GetDirectDispatchTable^.AddI64x2(a, b);
end;

operator - (const a, b: TVecI64x2): TVecI64x2;
begin
  Result := GetDirectDispatchTable^.SubI64x2(a, b);
end;

operator - (const a: TVecI64x2): TVecI64x2;
begin
  Result.i[0] := -a.i[0];
  Result.i[1] := -a.i[1];
end;

operator and (const a, b: TVecI64x2): TVecI64x2;
begin
  Result.i[0] := a.i[0] and b.i[0];
  Result.i[1] := a.i[1] and b.i[1];
end;

operator or (const a, b: TVecI64x2): TVecI64x2;
begin
  Result.i[0] := a.i[0] or b.i[0];
  Result.i[1] := a.i[1] or b.i[1];
end;

operator xor (const a, b: TVecI64x2): TVecI64x2;
begin
  Result.i[0] := a.i[0] xor b.i[0];
  Result.i[1] := a.i[1] xor b.i[1];
end;

operator not (const a: TVecI64x2): TVecI64x2;
begin
  Result.i[0] := not a.i[0];
  Result.i[1] := not a.i[1];
end;
{$POP}

{$PUSH}{$R-}{$Q-}
// === TVecU32x4 / TVecU64x2 / TVecU16x8 / TVecU8x16 运算符实现 (128-bit unsigned) ===

operator + (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.AddU32x4(a, b);
end;

operator - (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.SubU32x4(a, b);
end;

operator * (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.MulU32x4(a, b);
end;

operator and (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.AndU32x4(a, b);
end;

operator or (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.OrU32x4(a, b);
end;

operator xor (const a, b: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.XorU32x4(a, b);
end;

operator not (const a: TVecU32x4): TVecU32x4;
begin
  Result := GetDirectDispatchTable^.NotU32x4(a);
end;

operator + (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := GetDirectDispatchTable^.AddU64x2(a, b);
end;

operator - (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := GetDirectDispatchTable^.SubU64x2(a, b);
end;

operator and (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := GetDirectDispatchTable^.AndU64x2(a, b);
end;

operator or (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := GetDirectDispatchTable^.OrU64x2(a, b);
end;

operator xor (const a, b: TVecU64x2): TVecU64x2;
begin
  Result := GetDirectDispatchTable^.XorU64x2(a, b);
end;

operator not (const a: TVecU64x2): TVecU64x2;
begin
  Result := GetDirectDispatchTable^.NotU64x2(a);
end;

operator + (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.AddU16x8(a, b);
end;

operator - (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.SubU16x8(a, b);
end;

operator * (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.MulU16x8(a, b);
end;

operator and (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.AndU16x8(a, b);
end;

operator or (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.OrU16x8(a, b);
end;

operator xor (const a, b: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.XorU16x8(a, b);
end;

operator not (const a: TVecU16x8): TVecU16x8;
begin
  Result := GetDirectDispatchTable^.NotU16x8(a);
end;

operator + (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := GetDirectDispatchTable^.AddU8x16(a, b);
end;

operator - (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := GetDirectDispatchTable^.SubU8x16(a, b);
end;

operator and (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := GetDirectDispatchTable^.AndU8x16(a, b);
end;

operator or (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := GetDirectDispatchTable^.OrU8x16(a, b);
end;

operator xor (const a, b: TVecU8x16): TVecU8x16;
begin
  Result := GetDirectDispatchTable^.XorU8x16(a, b);
end;

operator not (const a: TVecU8x16): TVecU8x16;
begin
  Result := GetDirectDispatchTable^.NotU8x16(a);
end;

{$POP}

// === TVecF32x8 运算符实现 (256-bit) ===
// ✅ P2-B: 简化运算符 - GetDirectDispatchTable 保证返回有效指针，所有槽位已填充

operator + (const a, b: TVecF32x8): TVecF32x8;
begin
  Result := GetDirectDispatchTable^.AddF32x8(a, b);
end;

operator - (const a, b: TVecF32x8): TVecF32x8;
begin
  Result := GetDirectDispatchTable^.SubF32x8(a, b);
end;

operator * (const a, b: TVecF32x8): TVecF32x8;
begin
  Result := GetDirectDispatchTable^.MulF32x8(a, b);
end;

operator / (const a, b: TVecF32x8): TVecF32x8;
begin
  Result := GetDirectDispatchTable^.DivF32x8(a, b);
end;

operator - (const a: TVecF32x8): TVecF32x8;
var i: Integer;
begin
  // Unary negation - no dispatch function, use scalar
  for i := 0 to 7 do
    Result.f[i] := -a.f[i];
end;

// === TVecF64x4 运算符实现 (256-bit) ===
// ✅ P2-B: 简化运算符 - GetDirectDispatchTable 保证返回有效指针，所有槽位已填充

operator + (const a, b: TVecF64x4): TVecF64x4;
begin
  Result := GetDirectDispatchTable^.AddF64x4(a, b);
end;

operator - (const a, b: TVecF64x4): TVecF64x4;
begin
  Result := GetDirectDispatchTable^.SubF64x4(a, b);
end;

operator * (const a, b: TVecF64x4): TVecF64x4;
begin
  Result := GetDirectDispatchTable^.MulF64x4(a, b);
end;

operator / (const a, b: TVecF64x4): TVecF64x4;
begin
  Result := GetDirectDispatchTable^.DivF64x4(a, b);
end;

operator - (const a: TVecF64x4): TVecF64x4;
var i: Integer;
begin
  for i := 0 to 3 do
    Result.d[i] := -a.d[i];
end;

// === TVecI32x8 运算符实现 (256-bit) ===
// ✅ P2-B: 简化运算符 - GetDirectDispatchTable 保证返回有效指针，所有槽位已填充

operator + (const a, b: TVecI32x8): TVecI32x8;
begin
  Result := GetDirectDispatchTable^.AddI32x8(a, b);
end;

operator - (const a, b: TVecI32x8): TVecI32x8;
begin
  Result := GetDirectDispatchTable^.SubI32x8(a, b);
end;

operator - (const a: TVecI32x8): TVecI32x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.i[i] := -a.i[i];
end;

// P1.1: 添加 I32x8 乘法运算符
operator * (const a, b: TVecI32x8): TVecI32x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.MulI32x8) then
    Result := dt^.MulI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] * b.i[i];
  end;
end;

// P1.1: 添加 I32x8 位运算符
operator and (const a, b: TVecI32x8): TVecI32x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.AndI32x8) then
    Result := dt^.AndI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] and b.i[i];
  end;
end;

operator or (const a, b: TVecI32x8): TVecI32x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.OrI32x8) then
    Result := dt^.OrI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] or b.i[i];
  end;
end;

operator xor (const a, b: TVecI32x8): TVecI32x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.XorI32x8) then
    Result := dt^.XorI32x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := a.i[i] xor b.i[i];
  end;
end;

operator not (const a: TVecI32x8): TVecI32x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.NotI32x8) then
    Result := dt^.NotI32x8(a)
  else
  begin
    for i := 0 to 7 do
      Result.i[i] := not a.i[i];
  end;
end;

{$PUSH}{$R-}{$Q-}
// === TVecU32x8 / TVecU64x4 运算符实现 (256-bit unsigned) ===

operator + (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.AddU32x8(a, b);
end;

operator - (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.SubU32x8(a, b);
end;

operator * (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.MulU32x8(a, b);
end;

operator and (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.AndU32x8(a, b);
end;

operator or (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.OrU32x8(a, b);
end;

operator xor (const a, b: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.XorU32x8(a, b);
end;

operator not (const a: TVecU32x8): TVecU32x8;
begin
  Result := GetDirectDispatchTable^.NotU32x8(a);
end;

operator + (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := GetDirectDispatchTable^.AddU64x4(a, b);
end;

operator - (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := GetDirectDispatchTable^.SubU64x4(a, b);
end;

operator and (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := GetDirectDispatchTable^.AndU64x4(a, b);
end;

operator or (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := GetDirectDispatchTable^.OrU64x4(a, b);
end;

operator xor (const a, b: TVecU64x4): TVecU64x4;
begin
  Result := GetDirectDispatchTable^.XorU64x4(a, b);
end;

operator not (const a: TVecU64x4): TVecU64x4;
begin
  Result := GetDirectDispatchTable^.NotU64x4(a);
end;

{$POP}

// === TVecF32x16 运算符实现 (512-bit AVX-512) ===
// P0 修复: 通过 dispatch 系统调用 AVX-512 实现

operator + (const a, b: TVecF32x16): TVecF32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.AddF32x16) then
    Result := dt^.AddF32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.f[i] := a.f[i] + b.f[i];
  end;
end;

operator - (const a, b: TVecF32x16): TVecF32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.SubF32x16) then
    Result := dt^.SubF32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.f[i] := a.f[i] - b.f[i];
  end;
end;

operator * (const a, b: TVecF32x16): TVecF32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.MulF32x16) then
    Result := dt^.MulF32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.f[i] := a.f[i] * b.f[i];
  end;
end;

operator / (const a, b: TVecF32x16): TVecF32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.DivF32x16) then
    Result := dt^.DivF32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.f[i] := a.f[i] / b.f[i];
  end;
end;

operator - (const a: TVecF32x16): TVecF32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.f[i] := -a.f[i];
end;

// === TVecF64x8 运算符实现 (512-bit AVX-512) ===
// P0 修复: 通过 dispatch 系统调用 AVX-512 实现

operator + (const a, b: TVecF64x8): TVecF64x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.AddF64x8) then
    Result := dt^.AddF64x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.d[i] := a.d[i] + b.d[i];
  end;
end;

operator - (const a, b: TVecF64x8): TVecF64x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.SubF64x8) then
    Result := dt^.SubF64x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.d[i] := a.d[i] - b.d[i];
  end;
end;

operator * (const a, b: TVecF64x8): TVecF64x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.MulF64x8) then
    Result := dt^.MulF64x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.d[i] := a.d[i] * b.d[i];
  end;
end;

operator / (const a, b: TVecF64x8): TVecF64x8;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.DivF64x8) then
    Result := dt^.DivF64x8(a, b)
  else
  begin
    for i := 0 to 7 do
      Result.d[i] := a.d[i] / b.d[i];
  end;
end;

operator - (const a: TVecF64x8): TVecF64x8;
var i: Integer;
begin
  for i := 0 to 7 do
    Result.d[i] := -a.d[i];
end;

// === TVecI32x16 运算符实现 (512-bit AVX-512) ===
// P0 修复: 通过 dispatch 系统调用 AVX-512 实现

operator + (const a, b: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.AddI32x16) then
    Result := dt^.AddI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] + b.i[i];
  end;
end;

operator - (const a, b: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.SubI32x16) then
    Result := dt^.SubI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] - b.i[i];
  end;
end;

operator - (const a: TVecI32x16): TVecI32x16;
var i: Integer;
begin
  for i := 0 to 15 do
    Result.i[i] := -a.i[i];
end;

// P1.2: 添加 I32x16 乘法运算符
operator * (const a, b: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.MulI32x16) then
    Result := dt^.MulI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] * b.i[i];
  end;
end;

// P1.2: 添加 I32x16 位运算符
operator and (const a, b: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.AndI32x16) then
    Result := dt^.AndI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] and b.i[i];
  end;
end;

operator or (const a, b: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.OrI32x16) then
    Result := dt^.OrI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] or b.i[i];
  end;
end;

operator xor (const a, b: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.XorI32x16) then
    Result := dt^.XorI32x16(a, b)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := a.i[i] xor b.i[i];
  end;
end;

operator not (const a: TVecI32x16): TVecI32x16;
var dt: PSimdDispatchTable;
    i: Integer;
begin
  dt := GetDirectDispatchTable;
  if (dt <> nil) and Assigned(dt^.NotI32x16) then
    Result := dt^.NotI32x16(a)
  else
  begin
    for i := 0 to 15 do
      Result.i[i] := not a.i[i];
  end;
end;

{$PUSH}{$R-}{$Q-}
// === TVecU32x16 / TVecU64x8 / TVecU8x64 运算符实现 (512-bit unsigned) ===

operator + (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.AddU32x16(a, b);
end;

operator - (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.SubU32x16(a, b);
end;

operator * (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.MulU32x16(a, b);
end;

operator and (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.AndU32x16(a, b);
end;

operator or (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.OrU32x16(a, b);
end;

operator xor (const a, b: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.XorU32x16(a, b);
end;

operator not (const a: TVecU32x16): TVecU32x16;
begin
  Result := GetDirectDispatchTable^.NotU32x16(a);
end;

operator + (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := GetDirectDispatchTable^.AddU64x8(a, b);
end;

operator - (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := GetDirectDispatchTable^.SubU64x8(a, b);
end;

operator and (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := GetDirectDispatchTable^.AndU64x8(a, b);
end;

operator or (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := GetDirectDispatchTable^.OrU64x8(a, b);
end;

operator xor (const a, b: TVecU64x8): TVecU64x8;
begin
  Result := GetDirectDispatchTable^.XorU64x8(a, b);
end;

operator not (const a: TVecU64x8): TVecU64x8;
begin
  Result := GetDirectDispatchTable^.NotU64x8(a);
end;

operator + (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := GetDirectDispatchTable^.AddU8x64(a, b);
end;

operator - (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := GetDirectDispatchTable^.SubU8x64(a, b);
end;

operator and (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := GetDirectDispatchTable^.AndU8x64(a, b);
end;

operator or (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := GetDirectDispatchTable^.OrU8x64(a, b);
end;

operator xor (const a, b: TVecU8x64): TVecU8x64;
begin
  Result := GetDirectDispatchTable^.XorU8x64(a, b);
end;

operator not (const a: TVecU8x64): TVecU8x64;
begin
  Result := GetDirectDispatchTable^.NotU8x64(a);
end;

{$POP}

end.
