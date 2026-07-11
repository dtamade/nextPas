# nextpas.core.simd API 参考

> 最后更新: 2026-07-11

## 概述

本文档提供 SIMD 模块的公开 API 参考，包括向量操作、内存操作、文本操作、统计操作等。

## 向量操作

### 128-bit 浮点向量 (TVecF32x4)

#### 算术操作

```pascal
function VecF32x4Add(const A, B: TVecF32x4): TVecF32x4; inline;
function VecF32x4Sub(const A, B: TVecF32x4): TVecF32x4; inline;
function VecF32x4Mul(const A, B: TVecF32x4): TVecF32x4; inline;
function VecF32x4Div(const A, B: TVecF32x4): TVecF32x4; inline;
function VecF32x4Fma(const A, B, C: TVecF32x4): TVecF32x4; inline;
```

#### 一元操作

```pascal
function VecF32x4Abs(const A: TVecF32x4): TVecF32x4; inline;
function VecF32x4Neg(const A: TVecF32x4): TVecF32x4; inline;
function VecF32x4Sqrt(const A: TVecF32x4): TVecF32x4; inline;
function VecF32x4Rcp(const A: TVecF32x4): TVecF32x4; inline;
function VecF32x4Rsqrt(const A: TVecF32x4): TVecF32x4; inline;
```

#### 比较操作

```pascal
function VecF32x4CmpEq(const A, B: TVecF32x4): TMask4; inline;
function VecF32x4CmpLt(const A, B: TVecF32x4): TMask4; inline;
function VecF32x4CmpLe(const A, B: TVecF32x4): TMask4; inline;
function VecF32x4CmpGt(const A, B: TVecF32x4): TMask4; inline;
function VecF32x4CmpGe(const A, B: TVecF32x4): TMask4; inline;
function VecF32x4CmpNe(const A, B: TVecF32x4): TMask4; inline;
```

#### 归约操作

```pascal
function VecF32x4ReduceAdd(const A: TVecF32x4): Single; inline;
function VecF32x4ReduceMin(const A: TVecF32x4): Single; inline;
function VecF32x4ReduceMax(const A: TVecF32x4): Single; inline;
function VecF32x4ReduceMul(const A: TVecF32x4): Single; inline;
```

#### 几何操作

```pascal
function VecF32x4Dot(const A, B: TVecF32x4): Single; inline;
function VecF32x3Dot(const A, B: TVecF32x4): Single; inline;
function VecF32x3Cross(const A, B: TVecF32x4): TVecF32x4; inline;
function VecF32x4Length(const A: TVecF32x4): Single; inline;
function VecF32x3Length(const A: TVecF32x4): Single; inline;
function VecF32x4Normalize(const A: TVecF32x4): TVecF32x4; inline;
function VecF32x3Normalize(const A: TVecF32x4): TVecF32x4; inline;
```

#### 内存操作

```pascal
function VecF32x4Load(P: PSingle): TVecF32x4; inline;
function VecF32x4LoadAligned(P: PSingle): TVecF32x4; inline;
procedure VecF32x4Store(P: PSingle; const A: TVecF32x4); inline;
procedure VecF32x4StoreAligned(P: PSingle; const A: TVecF32x4); inline;
```

#### 构造操作

```pascal
function VecF32x4Splat(Value: Single): TVecF32x4; inline;
function VecF32x4Make(X, Y, Z, W: Single): TVecF32x4; inline;
function VecF32x4Zero: TVecF32x4; inline;
```

#### 操作操作

```pascal
function VecF32x4Select(const Mask: TMask4; const A, B: TVecF32x4): TVecF32x4; inline;
function VecF32x4Extract(const A: TVecF32x4; Index: Integer): Single; inline;
function VecF32x4Insert(const A: TVecF32x4; Value: Single; Index: Integer): TVecF32x4; inline;
function VecF32x4Shuffle(const A: TVecF32x4; Imm8: Byte): TVecF32x4; inline;
function VecF32x4Shuffle2(const A, B: TVecF32x4; Imm8: Byte): TVecF32x4; inline;
function VecF32x4Blend(const A, B: TVecF32x4; Mask: Byte): TVecF32x4; inline;
```

#### 转换操作

```pascal
function VecF32x4IntoBits(const A: TVecF32x4): TVecI32x4; inline;
function VecI32x4FromBitsF32(const A: TVecI32x4): TVecF32x4; inline;
function VecI32x4CastToF32x4(const A: TVecI32x4): TVecF32x4; inline;
function VecF32x4CastToI32x4(const A: TVecF32x4): TVecI32x4; inline;
```

#### Gather/Scatter 操作

```pascal
function VecF32x4Gather(Base: PSingle; const Indices: TVecI32x4): TVecF32x4; inline;
function VecI32x4Gather(Base: PInt32; const Indices: TVecI32x4): TVecI32x4; inline;
procedure VecF32x4Scatter(Base: PSingle; const Indices: TVecI32x4; const Values: TVecF32x4); inline;
procedure VecI32x4Scatter(Base: PInt32; const Indices: TVecI32x4; const Values: TVecI32x4); inline;
```

### 256-bit 浮点向量 (TVecF32x8)

#### 算术操作

```pascal
function VecF32x8Add(const A, B: TVecF32x8): TVecF32x8; inline;
function VecF32x8Sub(const A, B: TVecF32x8): TVecF32x8; inline;
function VecF32x8Mul(const A, B: TVecF32x8): TVecF32x8; inline;
function VecF32x8Div(const A, B: TVecF32x8): TVecF32x8; inline;
```

#### 归约操作

```pascal
function VecF32x8ReduceAdd(const A: TVecF32x8): Single; inline;
function VecF32x8ReduceMin(const A: TVecF32x8): Single; inline;
function VecF32x8ReduceMax(const A: TVecF32x8): Single; inline;
```

### 512-bit 浮点向量 (TVecF32x16)

#### 算术操作

```pascal
function VecF32x16Add(const A, B: TVecF32x16): TVecF32x16; inline;
function VecF32x16Sub(const A, B: TVecF32x16): TVecF32x16; inline;
function VecF32x16Mul(const A, B: TVecF32x16): TVecF32x16; inline;
function VecF32x16Div(const A, B: TVecF32x16): TVecF32x16; inline;
```

#### 归约操作

```pascal
function VecF32x16ReduceAdd(const A: TVecF32x16): Single; inline;
function VecF32x16ReduceMin(const A: TVecF32x16): Single; inline;
function VecF32x16ReduceMax(const A: TVecF32x16): Single; inline;
```

## 内存操作

```pascal
function MemEqual(A, B: Pointer; Len: SizeUInt): LongBool; inline;
procedure MemCopy(Src, Dst: Pointer; Len: SizeUInt); inline;
procedure MemSet(Dst: Pointer; Len: SizeUInt; Value: Byte); inline;
function BytesIndexOf(AHaystack: PByte; AHaystackLen: SizeUInt;
                      ANeedle: PByte; ANeedleLen: SizeUInt): PtrInt; inline;
```

## 文本操作

```pascal
function Utf8Validate(P: PByte; Len: SizeUInt): Boolean; inline;
function AsciiIEqual(A, B: PByte; Len: SizeUInt): Boolean; inline;
procedure ToLowerAscii(P: PByte; Len: SizeUInt); inline;
procedure ToUpperAscii(P: PByte; Len: SizeUInt); inline;
```

## 统计操作

```pascal
function SumBytes(P: PByte; Len: SizeUInt): UInt64; inline;
function CountByte(P: PByte; Len: SizeUInt; Value: Byte): SizeUInt; inline;
procedure MinMaxBytes(P: PByte; Len: SizeUInt; out MinVal, MaxVal: Byte); inline;
```

## 掩码操作

### 16 字节掩码 (TMask16)

```pascal
function Vec16CmpEq(AData: PByte; AValue: Byte): TMask16; inline;
function Vec16CmpLtU(AData: PByte; AThreshold: Byte): TMask16; inline;
function Vec16CmpGtU(AData: PByte; AThreshold: Byte): TMask16; inline;
function Vec16CmpRange(AData: PByte; ALo, AHi: Byte): TMask16; inline;
function Vec16Ctz(AMask: TMask16): Int32; inline;
function Vec16FirstSet(AMask: TMask16): Int32; inline;
function Vec16Popcnt(AMask: TMask16): Int32; inline;
```

### 32 字节掩码 (TMask32)

```pascal
function Vec32CmpEq(AData: PByte; AValue: Byte): TMask32; inline;
function Vec32CmpLtU(AData: PByte; AThreshold: Byte): TMask32; inline;
function Vec32CmpGtU(AData: PByte; AThreshold: Byte): TMask32; inline;
function Vec32CmpRange(AData: PByte; ALo, AHi: Byte): TMask32; inline;
function Vec32Ctz(AMask: TMask32): Int32; inline;
function Vec32FirstSet(AMask: TMask32): Int32; inline;
function Vec32Popcnt(AMask: TMask32): Int32; inline;
```

## 数组操作

### F32 数组操作

```pascal
procedure ArrayAddF32(A, B, C: PSingle; Count: SizeUInt);
procedure ArraySubF32(A, B, C: PSingle; Count: SizeUInt);
procedure ArrayMulF32(A, B, C: PSingle; Count: SizeUInt);
procedure ArrayDivF32(A, B, C: PSingle; Count: SizeUInt);
procedure ArrayFmaF32(A, B, C: PSingle; Count: SizeUInt);
procedure ArrayDotF32(A, B: PSingle; Count: SizeUInt; out Result: Single);
procedure ArrayNormF32(A: PSingle; Count: SizeUInt; out Result: Single);
```

### F64 数组操作

```pascal
procedure ArrayAddF64(A, B, C: PDouble; Count: SizeUInt);
procedure ArraySubF64(A, B, C: PDouble; Count: SizeUInt);
procedure ArrayMulF64(A, B, C: PDouble; Count: SizeUInt);
procedure ArrayDivF64(A, B, C: PDouble; Count: SizeUInt);
procedure ArrayAbsF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayNegF64(A, B: PDouble; Count: SizeUInt);
procedure ArraySqrtF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayClampF64(A, B: PDouble; Count: SizeUInt; Min, Max: Double);
procedure ArrayFmaF64(A, B, C, D: PDouble; Count: SizeUInt);
procedure ArrayMinF64(A, B, C: PDouble; Count: SizeUInt);
procedure ArrayMaxF64(A, B, C: PDouble; Count: SizeUInt);
```

### F64 超越函数

```pascal
procedure ArraySinF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayCosF64(A, B: PDouble; Count: SizeUInt);
procedure ArraySinCosF64(A, SinB, CosB: PDouble; Count: SizeUInt);
procedure ArrayExpF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayLogF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayLog2F64(A, B: PDouble; Count: SizeUInt);
procedure ArrayLog10F64(A, B: PDouble; Count: SizeUInt);
procedure ArrayCeilF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayFloorF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayRoundF64(A, B: PDouble; Count: SizeUInt);
procedure ArrayTruncF64(A, B: PDouble; Count: SizeUInt);
```

### F64 扩展批量操作

```pascal
procedure ArrayAxpyF64(Alpha: Double; X, Y, Dst: PDouble; Count: SizeUInt);
procedure ArrayRcpF64(Src, Dst: PDouble; Count: SizeUInt);
procedure ArrayRsqrtF64(Src, Dst: PDouble; Count: SizeUInt);
procedure ArrayTanF64(Src, Dst: PDouble; Count: SizeUInt);
procedure ArraySignF64(Src, Dst: PDouble; Count: SizeUInt);
procedure ArrayFractF64(Src, Dst: PDouble; Count: SizeUInt);
procedure ArrayModF64(Src, Dst: PDouble; Count: SizeUInt; Divisor: Double);
procedure ArrayPowF64(Src, Dst: PDouble; Count: SizeUInt; Exponent: Double);
procedure ArrayLerpF64(Start, End_, Dst: PDouble; Count: SizeUInt; T: Double);
procedure ArrayReLUF64(Src, Dst: PDouble; Count: SizeUInt);
procedure ArrayAbsDiffF64(Src1, Src2, Dst: PDouble; Count: SizeUInt);
procedure ArrayNormF64(Src, Dst: PDouble; Count: SizeUInt; Mean, InvStd: Double);
procedure ArrayLinearReLUF64(Src, Dst: PDouble; Count: SizeUInt; Scale, Bias: Double);
procedure ArrayStepF64(Edge, Src, Dst: PDouble; Count: SizeUInt);
procedure ArraySmoothstepF64(Edge0, Edge1, Src, Dst: PDouble; Count: SizeUInt);
procedure ArrayAtan2F64(Y, X, Dst: PDouble; Count: SizeUInt);
procedure ArrayHypotF64(X, Y, Dst: PDouble; Count: SizeUInt);
```

### I32 数组操作

```pascal
procedure ArrayAddI32(A, B, C: PInt32; Count: SizeUInt);
procedure ArraySubI32(A, B, C: PInt32; Count: SizeUInt);
procedure ArrayMulI16(A, B, C: PInt16; Count: SizeUInt);
procedure ArrayPackSatI32toI16(A: PInt32; B: PInt16; Count: SizeUInt);
```

## 运行时控制

```pascal
function GetActiveBackend: TSimdBackend;
procedure SetActiveBackend(Backend: TSimdBackend);
function TrySetActiveBackend(Backend: TSimdBackend): Boolean;
procedure ResetToAutomaticBackend;
function GetBestDispatchableBackend: TSimdBackend;
function GetDispatchableBackends: TSimdBackendArray;
function IsBackendDispatchable(Backend: TSimdBackend): Boolean;
```

## CPU 信息

```pascal
function GetCPUInfo: TCpuInfo;
function HasSSE2: Boolean;
function HasAVX2: Boolean;
function HasAVX512: Boolean;
function HasNEON: Boolean;
```

## 类型定义

### 向量类型

```pascal
type
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
```

### 掩码类型

```pascal
type
  TMask4 = type Byte;    // 4 位掩码
  TMask8 = type Byte;    // 8 位掩码
  TMask16 = type Word;   // 16 位掩码
  TMask32 = type DWord;  // 32 位掩码
```

### 后端类型

```pascal
type
  TSimdBackend = (
    sbScalar,
    sbSSE2, sbSSE3, sbSSSE3, sbSSE41, sbSSE42,
    sbAVX2, sbAVX512,
    sbNEON,
    sbRISCVV
  );
```
