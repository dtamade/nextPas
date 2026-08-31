# nextpas.core.simd Intrinsics 层详解

> 最后更新: 2026-08-31

## 概述

Intrinsics 层是 raw ISA 接口层，提供 TM128 类型和底层 SIMD 操作。它为 Backend Adapters 提供基础，同时处理特殊值 (NaN, Inf, -0.0) 确保 IEEE 754 一致性。

## 文件结构

```
nextpas.core.simd.intrinsics.base.pas     # 基础类型 TM128
nextpas.core.simd.intrinsics.sse2.pas # SSE2 raw ISA
nextpas.core.simd.intrinsics.avx2.pas     # AVX2 raw ISA
nextpas.core.simd.intrinsics.avx512.pas   # AVX-512 raw ISA
nextpas.core.simd.intrinsics.neon.pas     # NEON raw ISA
nextpas.core.simd.intrinsics.rvv.pas      # RISC-V V raw ISA
```

## TM128 类型

```pascal
type
  TM128 = record
    case Integer of
      0: (m128i_i8: array[0..15] of Int8);
      1: (m128i_u8: array[0..15] of UInt8);
      2: (m128i_i16: array[0..7] of Int16);
      3: (m128i_u16: array[0..7] of UInt16);
      4: (m128i_i32: array[0..3] of Int32);
      5: (m128i_u32: array[0..3] of UInt32);
      6: (m128i_i64: array[0..1] of Int64);
      7: (m128i_u64: array[0..1] of UInt64);
      8: (m128_f32: array[0..3] of Single);
      9: (m128d_f64: array[0..1] of Double);
      10: (m128i_u128: UInt128);
  end;
```

## 操作分类

### 1. Load/Store 操作

**实现**: 真正 SIMD 汇编

```pascal
function simd_load_ps(const Ptr: Pointer): TM128; assembler; nostackframe;
asm
  movaps xmm0, [rdi]  // 真正的 SIMD 指令
end;

function simd_loadu_ps(const Ptr: Pointer): TM128; assembler; nostackframe;
asm
  movups xmm0, [rdi]  // 真正的 SIMD 指令
end;

procedure simd_store_ps(var Dest; constref Src: TM128); assembler; nostackframe;
asm
  movaps [rdi], xmm0  // 真正的 SIMD 指令
end;
```

### 2. Set/Zero 操作

**实现**: 真正 SIMD 汇编

```pascal
function simd_setzero_ps: TM128; assembler; nostackframe;
asm
  pxor xmm0, xmm0  // 真正的 SIMD 指令
end;

function simd_set1_ps(Value: Single): TM128; assembler; nostackframe;
asm
  shufps xmm0, xmm0, 0  // 真正的 SIMD 指令
end;
```

### 3. 整数算术

**实现**: 真正 SIMD 汇编

```pascal
function simd_add_epi32(constref a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu xmm0, [rdi]    // 加载 a
  movdqu xmm1, [rsi]    // 加载 b
  paddd xmm0, xmm1      // 真正的 SIMD 指令: 4 个 32-bit 整数并行加法
end;

function simd_sub_epi16(constref a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  psubw xmm0, xmm1      // 真正的 SIMD 指令: 8 个 16-bit 整数并行减法
end;

function simd_mullo_epi16(constref a, b: TM128): TM128; assembler; nostackframe;
asm
  movdqu xmm0, [rdi]
  movdqu xmm1, [rsi]
  pmullw xmm0, xmm1     // 真正的 SIMD 指令: 8 个 16-bit 整数并行乘法
end;
```

### 4. FP 算术

**实现**: 标量回退

```pascal
function simd_add_ps(constref a, b: TM128): TM128;
begin
  Result := BuildPackedSingleSpecialArithmetic(a, b, bakAdd);
end;

function BuildPackedSingleSpecialArithmetic(
  constref a, b: TM128;
  const aKind: TSimdBinaryArithmeticKind
): TM128; inline;
var
  LLane: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for LLane := 0 to 3 do  // 逐 lane 标量处理
    Result.m128i_u32[LLane] := SelectSingleSpecialArithmeticBits(
      a.m128i_u32[LLane],
      b.m128i_u32[LLane],
      a.m128_f32[LLane],
      b.m128_f32[LLane],
      aKind
    );
end;
```

## 为什么 FP 算术是标量回退

### 原因

1. **处理特殊值**: NaN, Inf, -0.0
2. **确保 IEEE 754 一致性**: 不同 CPU 的 NaN 传播行为不同
3. **避免硬件差异**: Intel/AMD/ARM 的 FP 行为不完全一致

### 特殊值处理

```pascal
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
  // NaN 传播
  if SimdIsNaN(aLeftValue) then
    Exit(aLeftBits);
  if SimdIsNaN(aRightValue) then
    Exit(aRightBits);

  // 特殊组合
  case aKind of
    bakAdd:
      if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) and
        (((aLeftBits xor aRightBits) and DWord($80000000)) <> 0) then
        Exit(CANONICAL_SINGLE_QNAN);  // Inf + (-Inf) = NaN
    bakSub:
      if SimdIsInfinite(aLeftValue) and SimdIsInfinite(aRightValue) and
        (((aLeftBits xor aRightBits) and DWord($80000000)) = 0) then
        Exit(CANONICAL_SINGLE_QNAN);  // Inf - Inf = NaN
    bakMul:
      if (SingleBitsIsZero(aLeftBits) and SimdIsInfinite(aRightValue)) or
        (SingleBitsIsZero(aRightBits) and SimdIsInfinite(aLeftValue)) then
        Exit(CANONICAL_SINGLE_QNAN);  // 0 * Inf = NaN
  end;

  // 正常计算
  case aKind of
    bakAdd: LResult := aLeftValue + aRightValue;
    bakSub: LResult := aLeftValue - aRightValue;
  else
    LResult := aLeftValue * aRightValue;
  end;
  Move(LResult, Result, SizeOf(Result));
end;
```

## 与 Backend Adapters 的关系

```
┌─────────────────────────────────────────────────────────────┐
│  门面 (simd.pas)                                            │
│  VecF32x4Add(a, b) → 分派器 → Backend Adapter              │
├─────────────────────────────────────────────────────────────┤
│  Backend Adapters (sse2.pas, avx2.pas)                      │
│  SSE2AddF32x4(a, b) → 使用 TM128 类型                      │
├─────────────────────────────────────────────────────────────┤
│  Intrinsics (intrinsics.sse2.pas)                       │
│  simd_add_ps(a, b) → 标量回退（处理特殊值）                 │
│  simd_load_ps(ptr) → 真正 SIMD 汇编                        │
│  simd_add_epi32(a, b) → 真正 SIMD 汇编                     │
├─────────────────────────────────────────────────────────────┤
│  类型定义 (base.pas)                                        │
│  TM128, TVecF32x4, TMask4                                   │
└─────────────────────────────────────────────────────────────┘
```

**关键点**:
- Backend Adapters 使用 TM128 类型，不直接使用 TVecF32x4
- Backend Adapters 调用 Intrinsics 层的 raw ISA 接口
- Intrinsics 层处理特殊值，确保 IEEE 754 一致性

## 与 signal.pas 的关系

**signal.pas 直接手写汇编，不使用 Intrinsics 层**:

```pascal
// signal.pas 中的 FFT 蝶形运算
procedure FftButterfly4_SSE2(AEven, AOdd, ATwRe, ATwIm: PSingle); assembler; nostackframe;
asm
  movups xmm0, [rsi]      // Load odd
  mulps xmm1, xmm6         // 真正的 SIMD 指令
  addps xmm1, xmm2         // 真正的 SIMD 指令
  subps xmm3, xmm2         // 真正的 SIMD 指令
end;
```

**为什么 signal.pas 可以用真正的 SIMD 指令**:
1. **特定场景**: FFT、滤波等算法对特殊值有明确的处理策略
2. **性能优先**: 这些场景需要零开销
3. **自行处理特殊值**: signal.pas 内部处理 NaN/Inf 等情况

## 当前状态

| 操作类型 | 实现方式 | 状态 |
|----------|----------|------|
| Load/Store | 真正 SIMD 汇编 | ✅ 完成 |
| Set/Zero | 真正 SIMD 汇编 | ✅ 完成 |
| 整数算术 | 真正 SIMD 汇编 | ✅ 完成 |
| FP 算术 | 标量回退 | ⚠️ 未真正实现 |

## 未来改进

1. **Backend Adapters 直接实现**: 在 sse2.pas、avx2.pas 中直接使用真正 SIMD 指令
2. **nextpas 编译器优化**: 优化标量回退的性能
3. **扩展平台**: RISC-V V、LoongArch LASX
