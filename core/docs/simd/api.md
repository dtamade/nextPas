# nextpas.core.simd API 参考

> 最后更新: 2026-08-31

## 概述

本文档提供 SIMD 模块的公开 API 参考，包括向量操作、内存操作、文本操作、统计操作等。

Runtime 绑定语义：所有门面入口经 façade dispatch table 按当前 `active backend` 派发；backend 绑定由 runtime/control-plane（`nextpas.core.simd.runtime`）完成——`GetCurrentBackend` / `GetCurrentRuntimeSnapshot` 查询当前状态，`TrySetCurrentBackend` 显式指定，`ResetCurrentBackendSelection` 恢复自动选择；无可派发（dispatchable）SIMD backend 时保持 scalar fallback。

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

**语义契约（Gather/Scatter）**：

- 这些原语可经 public facade 调用，但 gather/scatter 家族目前 not part of the current stable public ABI wrapper（public ABI wrapper 只覆盖已冻结的核心原语面）。
- duplicate indices：gather 允许重复索引，各 lane 独立读取（重复 lane 取重复值）；scatter 遇重复索引时按 lane order 顺序写入，later lanes overwrite earlier writes；ScatterSelect 语义为 last enabled lane wins。
- Gather/scatter nil-base contract：`Base=nil` 且存在 enabled lane 时抛 `EArgumentNil`；GatherSelect 在 `Base=nil` 且全部 enable=0 时不读内存，returns `orVal`；ScatterSelect 在全部 enable=0 时为 no-op。
- 以上契约由 focused tests 钉住（`nextpas.core.simd.testcase.pas` 与 `test_api_coverage_gather_scatter.pas` 的 duplicate/nil-base 用例）。

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

公开 control-plane 推荐使用 `nextpas.core.simd.runtime` 的 canonical 入口：

```pascal
function GetCurrentBackend: TSimdBackend;
function GetCurrentRuntimeSnapshot: TSimdRuntimeSnapshot;
function GetDispatchableBackendList: TSimdBackendArray;
function GetBestDispatchableBackend: TSimdBackend;
function TrySetCurrentBackend(aBackend: TSimdBackend): Boolean;
procedure ResetCurrentBackendSelection;
```

`dispatch` 层入口保留给更低层维护与测试：

```pascal
function GetActiveBackend: TSimdBackend;
procedure SetActiveBackend(Backend: TSimdBackend);
function TrySetActiveBackend(Backend: TSimdBackend): Boolean;
procedure ResetToAutomaticBackend;
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
    sbNEON,      // AArch64 default scalar fallback；NEON asm opt-in 需显式启用
    sbRISCVV,    // EXPERIMENTAL opt-in；not a stable public backend
    sbLASX,      // EXPERIMENTAL；LoongArch LASX
    sbWASM,      // EXPERIMENTAL；WebAssembly SIMD128
    sbVSX,       // EXPERIMENTAL；POWER VSX
    sbMSA        // EXPERIMENTAL；MIPS MSA
  );
```

### 支持的后端

| Backend | 平台 | 状态 |
|---------|------|------|
| Scalar | 全平台 | 永远可用（scalar fallback 基线） |
| SSE2 / SSE3 / SSSE3 / SSE4.1 / SSE4.2 | x86_64 | 稳定 dispatchable 候选 |
| AVX2 | x86_64 | 稳定 dispatchable 候选 |
| AVX-512 | x86_64 | dispatchable 候选（受构建/验证范围限制） |
| NEON | AArch64 | default scalar fallback；仅在 NEON asm opt-in 后成为可派发候选 |
| RISC-V V | riscv64 | experimental；仅 opt-in（`SIMD_EXPERIMENTAL_RISCVV`）构建可派发 |
| LASX / WASM / VSX / MSA | LoongArch / WebAssembly / POWER / MIPS | experimental 隔离 stub，不在稳定面内 |

> `sbNEON` 的 dispatch / activation truth：默认 public 构建仍是 default scalar fallback，只有 NEON asm opt-in（FPC 3.3.1+ 且显式定义相应宏）后 NEON 才成为可派发候选。

## 公开 façade 边界

### Transpose 双路径边界

- 矩阵转置目前是两条彼此独立的 owner 路径：`TSimdF32Matrix.Transpose` / `TSimdF64Matrix.Transpose`（linalg 矩阵语义）与 SIMD lane transpose 原语 `VecF32x4Transpose`（`LaneTranspose` 语义，4x4 lane 重排）；两者各自由 focused tests 圈定边界，目前没有统一的 Transpose facade。

### F16/half 家族（future ABI boundary）

`TF16` / `THalf` 家族目前只规划 explicit conversion APIs（`F32 <-> F16`、`F32 <-> BF16`），而不是 implicit arithmetic（half 不会被当作可直接算术的数值类型）。硬件候选路径包括 `F16C`、`AVX-512 FP16`、`AVX512BF16` 与 `NEON FP16`；语义上必须先钉住 rounding、NaN payload、infinities、denormals、saturation 行为并配 focused tests，之后才可能跨过 future ABI boundary；在此之前 TF16/THalf 不进入 stable ABI，也 not part of the current stable public ABI wrapper。

### 对齐内存参数契约

- `AlignedAlloc` / `AlignedRealloc`：`alignment` 必须是非零 2 次幂且 ≥ `SizeOf(Pointer)`，否则抛 `EArgumentError`；分配失败抛 `EOutOfMemory`。
- `IsAligned` / `AlignUp` / `AlignUpSize`：对齐判定与向上取整工具，遵循同样的 2 次幂参数契约。
- `AlignedMemCopy` / `AlignedMemFill`：调用方保证指针满足声明的对齐；长度为 0 时安全返回。
- `TAlignedArray<T>`：以对齐分配为底座的泛型数组包装。
- 对齐常量：`SIMD_ALIGN_16` / `SIMD_ALIGN_32` / `SIMD_ALIGN_64`。
- `SimdAlloc` / `SimdRealloc`：内部按 size + header + alignment 预留空间（带溢出检查）；`saAuto` 按当前 active backend 的默认 profile 取对齐值（AVX-512=64B, AVX2=32B, 其余=16B）。
- `SimdFree(nil)` 是安全 no-op；`SimdFree` 只接受来自 `SimdAlloc`/`SimdRealloc` 且尚未释放过的指针。
