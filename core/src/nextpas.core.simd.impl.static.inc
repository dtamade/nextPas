{
  nextpas.core.simd.impl.static.inc

  Static dispatch implementations for SIMD facade functions.
  When SIMD_STATIC_BACKEND is defined, these implementations directly call
  backend-specific functions, eliminating the ~15-20 cycles dispatch overhead.

  This file is included by nextpas.core.simd.pas when SIMD_STATIC_BACKEND is defined.
}

{$IFDEF SIMD_STATIC_BACKEND}

// === F32x4 Operations ===

function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Add(a, b); end;

function VecF32x4Sub(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Sub(a, b); end;

function VecF32x4Mul(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Mul(a, b); end;

function VecF32x4Div(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Div(a, b); end;

function VecF32x4Abs(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Abs(a); end;

function VecF32x4Sqrt(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Sqrt(a); end;

function VecF32x4Min(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Min(a, b); end;

function VecF32x4Max(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Max(a, b); end;

function VecF32x4Fma(const a, b, c: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Fma(a, b, c); end;

function VecF32x4Rcp(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Rcp(a); end;

function VecF32x4Rsqrt(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Rsqrt(a); end;

function VecF32x4Floor(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Floor(a); end;

function VecF32x4Ceil(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Ceil(a); end;

function VecF32x4Round(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Round(a); end;

function VecF32x4Trunc(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Trunc(a); end;

function VecF32x4Clamp(const a, minVal, maxVal: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Clamp(a, minVal, maxVal); end;

function VecF32x4Dot(const a, b: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4Dot(a, b); end;

function VecF32x4Dot3(const a, b: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4Dot3(a, b); end;

function VecF32x4Cross(const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Cross(a, b); end;

function VecF32x4Length(const a: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4Length(a); end;

function VecF32x4Length3(const a: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4Length3(a); end;

function VecF32x4Normalize(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Normalize(a); end;

function VecF32x4Normalize3(const a: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Normalize3(a); end;

function VecF32x4ReduceAdd(const a: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4ReduceAdd(a); end;

function VecF32x4ReduceMin(const a: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4ReduceMin(a); end;

function VecF32x4ReduceMax(const a: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4ReduceMax(a); end;

function VecF32x4ReduceMul(const a: TVecF32x4): Single; inline;
begin Result := SIMD_STATIC_VecF32x4ReduceMul(a); end;

function VecF32x4Load(p: PSingle): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Load(p); end;

function VecF32x4LoadAligned(p: PSingle): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4LoadAligned(p); end;

procedure VecF32x4Store(p: PSingle; const a: TVecF32x4); inline;
begin SIMD_STATIC_VecF32x4Store(p, a); end;

procedure VecF32x4StoreAligned(p: PSingle; const a: TVecF32x4); inline;
begin SIMD_STATIC_VecF32x4StoreAligned(p, a); end;

function VecF32x4Splat(value: Single): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Splat(value); end;

function VecF32x4Zero: TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Zero; end;

function VecF32x4Select(const mask: TMask4; const a, b: TVecF32x4): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Select(mask, a, b); end;

function VecF32x4Extract(const a: TVecF32x4; index: Integer): Single; inline;
begin Result := SIMD_STATIC_VecF32x4Extract(a, index); end;

function VecF32x4Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4; inline;
begin Result := SIMD_STATIC_VecF32x4Insert(a, value, index); end;

function VecF32x4CmpEq(const a, b: TVecF32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecF32x4CmpEq(a, b); end;

function VecF32x4CmpLt(const a, b: TVecF32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecF32x4CmpLt(a, b); end;

function VecF32x4CmpLe(const a, b: TVecF32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecF32x4CmpLe(a, b); end;

function VecF32x4CmpGt(const a, b: TVecF32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecF32x4CmpGt(a, b); end;

function VecF32x4CmpGe(const a, b: TVecF32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecF32x4CmpGe(a, b); end;

function VecF32x4CmpNe(const a, b: TVecF32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecF32x4CmpNe(a, b); end;

// === F64x2 Operations ===

function VecF64x2Add(const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Add(a, b); end;

function VecF64x2Sub(const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Sub(a, b); end;

function VecF64x2Mul(const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Mul(a, b); end;

function VecF64x2Div(const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Div(a, b); end;

function VecF64x2Abs(const a: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Abs(a); end;

function VecF64x2Sqrt(const a: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Sqrt(a); end;

function VecF64x2Min(const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Min(a, b); end;

function VecF64x2Max(const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Max(a, b); end;

function VecF64x2Fma(const a, b, c: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Fma(a, b, c); end;

function VecF64x2Floor(const a: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Floor(a); end;

function VecF64x2Ceil(const a: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Ceil(a); end;

function VecF64x2Round(const a: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Round(a); end;

function VecF64x2Trunc(const a: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Trunc(a); end;

function VecF64x2Clamp(const a, minVal, maxVal: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Clamp(a, minVal, maxVal); end;

function VecF64x2Dot(const a, b: TVecF64x2): Double; inline;
begin Result := SIMD_STATIC_VecF64x2Dot(a, b); end;

function VecF64x2ReduceAdd(const a: TVecF64x2): Double; inline;
begin Result := SIMD_STATIC_VecF64x2ReduceAdd(a); end;

function VecF64x2ReduceMin(const a: TVecF64x2): Double; inline;
begin Result := SIMD_STATIC_VecF64x2ReduceMin(a); end;

function VecF64x2ReduceMax(const a: TVecF64x2): Double; inline;
begin Result := SIMD_STATIC_VecF64x2ReduceMax(a); end;

function VecF64x2ReduceMul(const a: TVecF64x2): Double; inline;
begin Result := SIMD_STATIC_VecF64x2ReduceMul(a); end;

function VecF64x2Load(p: PDouble): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Load(p); end;

procedure VecF64x2Store(p: PDouble; const a: TVecF64x2); inline;
begin SIMD_STATIC_VecF64x2Store(p, a); end;

function VecF64x2Splat(value: Double): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Splat(value); end;

function VecF64x2Zero: TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Zero; end;

function VecF64x2Select(const mask: TMask2; const a, b: TVecF64x2): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Select(mask, a, b); end;

function VecF64x2Extract(const a: TVecF64x2; index: Integer): Double; inline;
begin Result := SIMD_STATIC_VecF64x2Extract(a, index); end;

function VecF64x2Insert(const a: TVecF64x2; value: Double; index: Integer): TVecF64x2; inline;
begin Result := SIMD_STATIC_VecF64x2Insert(a, value, index); end;

function VecF64x2CmpEq(const a, b: TVecF64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecF64x2CmpEq(a, b); end;

function VecF64x2CmpLt(const a, b: TVecF64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecF64x2CmpLt(a, b); end;

function VecF64x2CmpLe(const a, b: TVecF64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecF64x2CmpLe(a, b); end;

function VecF64x2CmpGt(const a, b: TVecF64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecF64x2CmpGt(a, b); end;

function VecF64x2CmpGe(const a, b: TVecF64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecF64x2CmpGe(a, b); end;

function VecF64x2CmpNe(const a, b: TVecF64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecF64x2CmpNe(a, b); end;

// === I32x4 Operations ===

function VecI32x4Add(const a, b: TVecI32x4): TVecI32x4; inline;
begin Result := SIMD_STATIC_VecI32x4Add(a, b); end;

function VecI32x4Sub(const a, b: TVecI32x4): TVecI32x4; inline;
begin Result := SIMD_STATIC_VecI32x4Sub(a, b); end;

function VecI32x4Mul(const a, b: TVecI32x4): TVecI32x4; inline;
begin Result := SIMD_STATIC_VecI32x4Mul(a, b); end;

function VecI32x4Min(const a, b: TVecI32x4): TVecI32x4; inline;
begin Result := SIMD_STATIC_VecI32x4Min(a, b); end;

function VecI32x4Max(const a, b: TVecI32x4): TVecI32x4; inline;
begin Result := SIMD_STATIC_VecI32x4Max(a, b); end;

function VecI32x4CmpEq(const a, b: TVecI32x4): TMask4; inline;
begin Result := SIMD_STATIC_VecI32x4CmpEq(a, b); end;

// === I32x8 Operations (256-bit) ===

function VecI32x8Extract(const a: TVecI32x8; index: Integer): Int32; inline;
begin Result := SIMD_STATIC_VecI32x8Extract(a, index); end;

function VecI32x8Insert(const a: TVecI32x8; value: Int32; index: Integer): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Insert(a, value, index); end;

function VecI32x8Add(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Add(a, b); end;

function VecI32x8Sub(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Sub(a, b); end;

function VecI32x8Mul(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Mul(a, b); end;

function VecI32x8And(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8And(a, b); end;

function VecI32x8Or(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Or(a, b); end;

function VecI32x8Xor(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Xor(a, b); end;

function VecI32x8Not(const a: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Not(a); end;

function VecI32x8AndNot(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8AndNot(a, b); end;

function VecI32x8ShiftLeft(const a: TVecI32x8; count: Integer): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8ShiftLeft(a, count); end;

function VecI32x8ShiftRight(const a: TVecI32x8; count: Integer): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8ShiftRight(a, count); end;

function VecI32x8ShiftRightArith(const a: TVecI32x8; count: Integer): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8ShiftRightArith(a, count); end;

function VecI32x8CmpEq(const a, b: TVecI32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecI32x8CmpEq(a, b); end;

function VecI32x8CmpLt(const a, b: TVecI32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecI32x8CmpLt(a, b); end;

function VecI32x8CmpGt(const a, b: TVecI32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecI32x8CmpGt(a, b); end;

function VecI32x8CmpLe(const a, b: TVecI32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecI32x8CmpLe(a, b); end;

function VecI32x8CmpGe(const a, b: TVecI32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecI32x8CmpGe(a, b); end;

function VecI32x8CmpNe(const a, b: TVecI32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecI32x8CmpNe(a, b); end;

function VecI32x8Min(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Min(a, b); end;

function VecI32x8Max(const a, b: TVecI32x8): TVecI32x8; inline;
begin Result := SIMD_STATIC_VecI32x8Max(a, b); end;

// === I64x2 Operations ===

function VecI64x2Add(const a, b: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2Add(a, b); end;

function VecI64x2Sub(const a, b: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2Sub(a, b); end;

function VecI64x2And(const a, b: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2And(a, b); end;

function VecI64x2Or(const a, b: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2Or(a, b); end;

function VecI64x2Xor(const a, b: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2Xor(a, b); end;

function VecI64x2Not(const a: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2Not(a); end;

function VecI64x2AndNot(const a, b: TVecI64x2): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2AndNot(a, b); end;

function VecI64x2CmpEq(const a, b: TVecI64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecI64x2CmpEq(a, b); end;

function VecI64x2CmpNe(const a, b: TVecI64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecI64x2CmpNe(a, b); end;

function VecI64x2CmpGt(const a, b: TVecI64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecI64x2CmpGt(a, b); end;

function VecI64x2CmpLt(const a, b: TVecI64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecI64x2CmpLt(a, b); end;

function VecI64x2CmpGe(const a, b: TVecI64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecI64x2CmpGe(a, b); end;

function VecI64x2CmpLe(const a, b: TVecI64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecI64x2CmpLe(a, b); end;

function VecI64x2Extract(const a: TVecI64x2; index: Integer): Int64; inline;
begin Result := SIMD_STATIC_VecI64x2Extract(a, index); end;

function VecI64x2Insert(const a: TVecI64x2; value: Int64; index: Integer): TVecI64x2; inline;
begin Result := SIMD_STATIC_VecI64x2Insert(a, value, index); end;

// === U64x2 Operations ===

function VecU64x2Add(const a, b: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2Add(a, b); end;

function VecU64x2Sub(const a, b: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2Sub(a, b); end;

function VecU64x2And(const a, b: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2And(a, b); end;

function VecU64x2Or(const a, b: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2Or(a, b); end;

function VecU64x2Xor(const a, b: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2Xor(a, b); end;

function VecU64x2Not(const a: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2Not(a); end;

function VecU64x2AndNot(const a, b: TVecU64x2): TVecU64x2; inline;
begin Result := SIMD_STATIC_VecU64x2AndNot(a, b); end;

function VecU64x2CmpEq(const a, b: TVecU64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecU64x2CmpEq(a, b); end;

function VecU64x2CmpLt(const a, b: TVecU64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecU64x2CmpLt(a, b); end;

function VecU64x2CmpGt(const a, b: TVecU64x2): TMask2; inline;
begin Result := SIMD_STATIC_VecU64x2CmpGt(a, b); end;

// === F32x8 Operations (256-bit) ===

function VecF32x8Add(const a, b: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Add(a, b); end;

function VecF32x8Sub(const a, b: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Sub(a, b); end;

function VecF32x8Mul(const a, b: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Mul(a, b); end;

function VecF32x8Div(const a, b: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Div(a, b); end;

function VecF32x8Abs(const a: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Abs(a); end;

function VecF32x8Sqrt(const a: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Sqrt(a); end;

function VecF32x8Min(const a, b: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Min(a, b); end;

function VecF32x8Max(const a, b: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Max(a, b); end;

function VecF32x8Fma(const a, b, c: TVecF32x8): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Fma(a, b, c); end;

function VecF32x8Dot(const a, b: TVecF32x8): Single; inline;
begin Result := SIMD_STATIC_VecF32x8Dot(a, b); end;

function VecF32x8Splat(value: Single): TVecF32x8; inline;
begin Result := SIMD_STATIC_VecF32x8Splat(value); end;

function VecF32x8CmpEq(const a, b: TVecF32x8): TMask8; inline;
begin Result := SIMD_STATIC_VecF32x8CmpEq(a, b); end;

// === F64x4 Operations (256-bit) ===

function VecF64x4Add(const a, b: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Add(a, b); end;

function VecF64x4Sub(const a, b: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Sub(a, b); end;

function VecF64x4Mul(const a, b: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Mul(a, b); end;

function VecF64x4Div(const a, b: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Div(a, b); end;

function VecF64x4Abs(const a: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Abs(a); end;

function VecF64x4Sqrt(const a: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Sqrt(a); end;

function VecF64x4Min(const a, b: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Min(a, b); end;

function VecF64x4Max(const a, b: TVecF64x4): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Max(a, b); end;

function VecF64x4Dot(const a, b: TVecF64x4): Double; inline;
begin Result := SIMD_STATIC_VecF64x4Dot(a, b); end;

function VecF64x4Splat(value: Double): TVecF64x4; inline;
begin Result := SIMD_STATIC_VecF64x4Splat(value); end;

// === Memory Operations ===

function MemEqual(a, b: Pointer; len: SizeUInt): LongBool; inline;
begin Result := SIMD_STATIC_MemEqual(a, b, len); end;

function MemFindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt; inline;
begin Result := SIMD_STATIC_MemFindByte(p, len, value); end;

procedure MemCopy(src, dst: Pointer; len: SizeUInt); inline;
begin SIMD_STATIC_MemCopy(src, dst, len); end;

procedure MemSet(dst: Pointer; len: SizeUInt; value: Byte); inline;
begin SIMD_STATIC_MemSet(dst, len, value); end;

// === Text Operations ===

function Utf8Validate(p: Pointer; len: SizeUInt): Boolean; inline;
begin Result := SIMD_STATIC_Utf8Validate(p, len); end;

function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean; inline;
begin Result := SIMD_STATIC_AsciiIEqual(a, b, len); end;

procedure ToLowerAscii(p: Pointer; len: SizeUInt); inline;
begin SIMD_STATIC_ToLowerAscii(p, len); end;

procedure ToUpperAscii(p: Pointer; len: SizeUInt); inline;
begin SIMD_STATIC_ToUpperAscii(p, len); end;

// === Batch Array Operations - F32 ===

procedure ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAddF32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArraySubF32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayMulF32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayDivF32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayMinF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayMinF32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayMaxF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayMaxF32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAbsF32(aSrc, aDst, aCount); end;

procedure ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayNegF32(aSrc, aDst, aCount); end;

procedure ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArraySqrtF32(aSrc, aDst, aCount); end;

procedure ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
begin SIMD_STATIC_ArrayClampF32(aSrc, aDst, aCount, aMin, aMax); end;

procedure ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayFmaF32(aA, aB, aC, aDst, aCount); end;

procedure ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAxpyF32(aAlpha, aX, aY, aDst, aCount); end;

procedure ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
begin SIMD_STATIC_ArrayAddScalarF32(aSrc, aDst, aCount, aScalar); end;

procedure ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
begin SIMD_STATIC_ArrayMulScalarF32(aSrc, aDst, aCount, aScalar); end;

function ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin Result := SIMD_STATIC_ReduceSumF32(aSrc, aCount); end;

function ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
begin Result := SIMD_STATIC_ReduceDotF32(aSrc1, aSrc2, aCount); end;

// === Batch Array Operations - F64 ===

procedure ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAddF64(aSrc1, aSrc2, aDst, aCount); end;

procedure ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArraySubF64(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArrayMulF64(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArrayDivF64(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAbsF64(aSrc, aDst, aCount); end;

procedure ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArrayNegF64(aSrc, aDst, aCount); end;

procedure ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
begin SIMD_STATIC_ArraySqrtF64(aSrc, aDst, aCount); end;

procedure ArrayClampF64(aSrc, aDst: PDouble; aCount: SizeUInt; aMin, aMax: Double);
begin SIMD_STATIC_ArrayClampF64(aSrc, aDst, aCount, aMin, aMax); end;

procedure ArrayAddScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
begin SIMD_STATIC_ArrayAddScalarF64(aSrc, aDst, aCount, aScalar); end;

procedure ArrayMulScalarF64(aSrc, aDst: PDouble; aCount: SizeUInt; aScalar: Double);
begin SIMD_STATIC_ArrayMulScalarF64(aSrc, aDst, aCount, aScalar); end;

function ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin Result := SIMD_STATIC_ReduceSumF64(aSrc, aCount); end;

function ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
begin Result := SIMD_STATIC_ReduceDotF64(aSrc1, aSrc2, aCount); end;

// === Batch Array Operations - Integer ===

procedure ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAddI32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArraySubI32(aSrc1, aSrc2, aDst, aCount); end;

// === Batch Array Operations - U32 ===

procedure ArrayAddU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAddU32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArraySubU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArraySubU32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayMulU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArrayMulU32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayAndU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArrayAndU32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayOrU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArrayOrU32(aSrc1, aSrc2, aDst, aCount); end;

procedure ArrayXorU32(aSrc1, aSrc2, aDst: PUInt32; aCount: SizeUInt);
begin SIMD_STATIC_ArrayXorU32(aSrc1, aSrc2, aDst, aCount); end;

// === Memory Operations ===

function MemEqual(a, b: Pointer; len: SizeUInt): LongBool;
begin Result := SIMD_STATIC_MemEqual(a, b, len); end;

function MemFindByte(a: Pointer; aValue: Byte; aLen: SizeUInt): Pointer;
begin Result := SIMD_STATIC_MemFindByte(a, aValue, aLen); end;

function SumBytes(p: Pointer; len: SizeUInt): UInt64;
begin Result := SIMD_STATIC_SumBytes(p, len); end;

function CountByte(p: Pointer; len: SizeUInt; value: Byte): SizeUInt;
begin Result := SIMD_STATIC_CountByte(p, len, value); end;

// === Reduce Operations - Min/Max ===

function ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin Result := SIMD_STATIC_ReduceMinF32(aSrc, aCount); end;

function ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin Result := SIMD_STATIC_ReduceMaxF32(aSrc, aCount); end;

function ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin Result := SIMD_STATIC_ReduceMinF64(aSrc, aCount); end;

function ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
begin Result := SIMD_STATIC_ReduceMaxF64(aSrc, aCount); end;

{$ENDIF} // SIMD_STATIC_BACKEND
