# nextpas.core.simd 后端实现详解

> 最后更新: 2026-08-31

## 概述

Backend Adapters 是 SIMD 模块的核心，提供真正的手写汇编实现。每个后端注册到分派器，由门面自动选择最优后端。

## 后端列表

| 后端 | 平台 | 向量宽度 | 状态 |
|------|------|----------|------|
| Scalar | 全平台 | N/A | ✅ 稳定 |
| SSE2 | x86_64 | 128-bit | ✅ 稳定 |
| SSE3 | x86_64 | 128-bit | ✅ 稳定 |
| SSSE3 | x86_64 | 128-bit | ✅ 稳定 |
| SSE4.1 | x86_64 | 128-bit | ✅ 稳定 |
| SSE4.2 | x86_64 | 128-bit | ✅ 稳定 |
| AVX2 | x86_64 | 256-bit | ✅ 稳定 |
| AVX-512 | x86_64 | 512-bit | ✅ 稳定 |
| NEON | AArch64 | 128-bit | ⚠️ 需 opt-in |
| RISC-V V | RISC-V | 可变 | ⚠️ 实验性 |

## 后端继承链

```
Scalar → SSE2 → SSE3 → SSSE3 → SSE4.1 → SSE4.2 → AVX2 → AVX-512
```

每个后端通过 `CloneDispatchTable` 继承上一级的实现，只覆盖它能加速的操作。

## SSE2 后端

**文件**: `nextpas.core.simd.sse2.pas`
**代码量**: ~5000 行手写汇编
**覆盖**: 全 F32 + F64 batch 操作

### 实现示例

```pascal
function SSE2AddF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  movups xmm0, [a]     // 加载 a
  movups xmm1, [b]     // 加载 b
  addps xmm0, xmm1     // 4 个 float 并行加法
  movups [Result], xmm0 // 存储结果
end;
```

### 覆盖的操作

- **算术**: Add, Sub, Mul, Div, Sqrt, Min, Max
- **比较**: CmpEq, CmpLt, CmpLe, CmpGt, CmpGe, CmpNe
- **归约**: ReduceAdd, ReduceMin, ReduceMax
- **内存**: Load, Store, LoadAligned, StoreAligned
- **构造**: Splat, Make, Zero

## AVX2 后端

**文件**: `nextpas.core.simd.avx2.pas`
**代码量**: ~3000 行手写汇编
**覆盖**: 全 F32 + F64 batch 操作

### 实现示例

```pascal
function AVX2AddF32x8(const a, b: TVecF32x8): TVecF32x8; assembler; nostackframe;
asm
  vmovups ymm0, [a]     // 加载 a (256-bit)
  vmovups ymm1, [b]     // 加载 b (256-bit)
  vaddps ymm0, ymm0, ymm1 // 8 个 float 并行加法
  vmovups [Result], ymm0  // 存储结果
end;
```

### 相比 SSE2 的优势

- **宽度**: 256-bit vs 128-bit (2x)
- **吞吐**: 8 floats/cycle vs 4 floats/cycle
- **指令**: VEX 编码，更少的 mov 指令

## AVX-512 后端

**文件**: `nextpas.core.simd.avx512.pas`
**覆盖**: 231 slots, 100% F32 native ZMM

### 实现示例

```pascal
function AVX512AddF32x16(const a, b: TVecF32x16): TVecF32x16; assembler; nostackframe;
asm
  vmovups zmm0, [a]     // 加载 a (512-bit)
  vmovups zmm1, [b]     // 加载 b (512-bit)
  vaddps zmm0, zmm0, zmm1 // 16 个 float 并行加法
  vmovups [Result], zmm0  // 存储结果
end;
```

### 注意事项

- **对齐**: 512-bit 操作需要 64-byte 对齐
- **FPC 限制**: `RECORDMIN=32` 不能保证 64-byte 对齐
- **解决方案**: 使用 `SimdAlloc(..., sa64)` 或 `AlignedAlloc`

## NEON 后端

**文件**: `nextpas.core.simd.neon.pas`
**覆盖**: 558 slots, 全 F32 + F64 batch 操作

### 实现示例

```pascal
function NEONAddF32x4(const a, b: TVecF32x4): TVecF32x4; assembler; nostackframe;
asm
  ldr q0, [a]           // 加载 a (128-bit)
  ldr q1, [b]           // 加载 b (128-bit)
  add v0.4s, v0.4s, v1.4s // 4 个 float 并行加法
  str q0, [Result]       // 存储结果
end;
```

### Opt-in 条件

NEON 后端需要满足以下条件才能启用：
1. AArch64 目标
2. FPC 3.3.1+
3. 无 `SIMD_VECTOR_ASM_DISABLED`
4. `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM`
5. `NEXTPAS_SIMD_ENABLE_NEON_ASM`
6. `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY`

## Scalar 后端

**文件**: `nextpas.core.simd.scalar.pas`
**代码量**: ~5000 行纯 Pascal
**覆盖**: 全部操作

### 实现示例

```pascal
function ScalarAddF32x4(const a, b: TVecF32x4): TVecF32x4;
begin
  Result.f[0] := a.f[0] + b.f[0];
  Result.f[1] := a.f[1] + b.f[1];
  Result.f[2] := a.f[2] + b.f[2];
  Result.f[3] := a.f[3] + b.f[3];
end;
```

### 用途

- **回退**: 无 SIMD 硬件时使用
- **测试**: 作为参考实现
- **调试**: 验证 SIMD 实现的正确性

## 后端注册

每个后端在 `initialization` 段自动注册：

```pascal
initialization
  RegisterSSE2Backend;
  RegisterAVX2Backend;
  RegisterAVX512Backend;
  RegisterNEONBackend;
  RegisterScalarBackend;
```

## 后端选择

运行时根据 CPU 能力选择最优后端：

```pascal
var
  Backend: TSimdBackend;
begin
  Backend := GetBestDispatchableBackend;
  // 自动选择: AVX-512 > AVX2 > SSE4.2 > ... > SSE2 > Scalar
end;
```

## 性能对比

| 操作 | Scalar | SSE2 | AVX2 | AVX-512 |
|------|--------|------|------|---------|
| AddF32x4 | 4 cycles | 1 cycle | 1 cycle | 1 cycle |
| AddF32x8 | 8 cycles | 2 cycles | 1 cycle | 1 cycle |
| AddF32x16 | 16 cycles | 4 cycles | 2 cycles | 1 cycle |
| MemEqual (16B) | 16 cycles | 1 cycle | 1 cycle | 1 cycle |
| Utf8Validate (16B) | 16 cycles | 1 cycle | 1 cycle | 1 cycle |

**注意**: 实际性能取决于 CPU 微架构、缓存、流水线等因素。
