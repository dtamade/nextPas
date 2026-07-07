# nextpas.core.simd 平台支持

> 最后更新: 2026-07-06

## 支持的平台

| 平台 | 架构 | 后端 | 状态 |
|------|------|------|------|
| Linux | x86_64 | SSE2, AVX2, AVX-512 | ✅ 稳定 |
| Linux | AArch64 | NEON | ⚠️ 需 opt-in |
| Linux | RISC-V | RVV | ⚠️ 实验性 |
| macOS | x86_64 | SSE2, AVX2, AVX-512 | ✅ 稳定 |
| macOS | AArch64 | NEON | ⚠️ 需 opt-in |
| Windows | x86_64 | SSE2, AVX2, AVX-512 | ✅ 稳定 |
| Windows | AArch64 | NEON | ⚠️ 需 opt-in |

## x86_64 平台

### 后端列表

| 后端 | 向量宽度 | 指令集 | 状态 |
|------|----------|--------|------|
| SSE2 | 128-bit | SSE2 | ✅ 稳定 |
| SSE3 | 128-bit | SSE3 | ✅ 稳定 |
| SSSE3 | 128-bit | SSSE3 | ✅ 稳定 |
| SSE4.1 | 128-bit | SSE4.1 | ✅ 稳定 |
| SSE4.2 | 128-bit | SSE4.2 | ✅ 稳定 |
| AVX2 | 256-bit | AVX2 | ✅ 稳定 |
| AVX-512 | 512-bit | AVX-512 | ✅ 稳定 |

### CPU 能力检测

```pascal
uses nextpas.core.simd;

var
  Info: TCpuInfo;
begin
  Info := GetCPUInfo;
  if Info.HasAVX2 then
    WriteLn('AVX2 supported');
  if Info.HasAVX512 then
    WriteLn('AVX-512 supported');
end;
```

### 后端选择

```pascal
uses nextpas.core.simd;

var
  Backend: TSimdBackend;
begin
  Backend := GetBestDispatchableBackend;
  // 自动选择: AVX-512 > AVX2 > SSE4.2 > ... > SSE2 > Scalar
end;
```

## AArch64 平台

### NEON 后端

**状态**: ⚠️ 需 opt-in

**Opt-in 条件**:
1. AArch64 目标
2. FPC 3.3.1+
3. 无 `SIMD_VECTOR_ASM_DISABLED`
4. `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM`
5. `NEXTPAS_SIMD_ENABLE_NEON_ASM`
6. `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY`

**启用方式**:

```bash
# 编译时定义宏
fpc -dNEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM \
    -dNEXTPAS_SIMD_ENABLE_NEON_ASM \
    -dNEXTPAS_SIMD_NEON_ASM_COMPILER_READY \
    your_program.lpr
```

**注意事项**:
- AArch64 ABI: 小向量通过 GPR 传递，有 GPR-to-vector 开销
- FPC 3.2.2: 不支持 NEON 内联汇编
- 建议: 升级到 FPC 3.3.1+

### NEON 覆盖度

- 558 个槽位全部覆盖
- 全 F32 + F64 batch 操作
- 全整数 batch 操作

## RISC-V 平台

### RISC-V V 后端

**状态**: ⚠️ 实验性

**Opt-in 条件**:
1. RISC-V 目标
2. `SIMD_EXPERIMENTAL_RISCVV` 定义

**启用方式**:

```bash
# 编译时定义宏
fpc -dSIMD_EXPERIMENTAL_RISCVV your_program.lpr
```

**注意事项**:
- 实验性: 不稳定，可能有 bug
- 覆盖度: 部分操作
- 性能: 未优化

### RISC-V V 覆盖度

- 基本算术: Add, Sub, Mul, Div
- 比较操作: CmpEq, CmpLt, CmpLe
- 内存操作: Load, Store
- 标量回退: 其他操作

## 标量回退

**状态**: ✅ 稳定

**用途**:
- 无 SIMD 硬件时使用
- 测试参考实现
- 调试验证

**覆盖**: 全部操作

**性能**: 每次操作 1 个元素

## 跨平台编程

### 自动后端选择

```pascal
uses nextpas.core.simd;

var
  A, B, C: TVecF32x4;
begin
  A := VecF32x4Splat(1.0);
  B := VecF32x4Splat(2.0);
  C := VecF32x4Add(A, B);  // 自动选择最优后端
end;
```

### 平台特定代码

```pascal
uses nextpas.core.simd;

begin
  {$IFDEF CPUX86_64}
  // x86_64 特定代码
  if HasAVX2 then
    WriteLn('Using AVX2');
  {$ENDIF}
  
  {$IFDEF CPUAARCH64}
  // AArch64 特定代码
  WriteLn('Using NEON');
  {$ENDIF}
end;
```

### 编译期后端选择

```pascal
{$DEFINE SIMD_BACKEND_AVX2}

{$IFDEF SIMD_BACKEND_AVX2}
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := AVX2AddF32x4(a, b);
end;
{$ELSE}
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := GetSimdFacadeDispatchFastPath^.AddF32x4(a, b);
end;
{$ENDIF}
```

## 平台特定优化

### x86_64 优化

1. **AVX-512**: 512-bit 向量，16 个 float 并行
2. **FMA**: 融合乘加，减少指令数
3. **BMI2**: 位操作优化

### AArch64 优化

1. **NEON**: 128-bit 向量，4 个 float 并行
2. **SVE**: 可变长度向量 (未来)
3. **FP16**: 半精度浮点 (未来)

### RISC-V 优化

1. **RVV**: 可变长度向量
2. **Zvfh**: 半精度浮点 (未来)
3. **Zvbb**: 位操作 (未来)

## 测试验证

### 平台测试

```bash
# x86_64 测试
make -C core/tests/nextpas.core.simd clean test

# AArch64 测试 (需要 QEMU 或真机)
qemu-aarch64 ./test_simd

# RISC-V 测试 (需要 QEMU 或真机)
qemu-riscv64 ./test_simd
```

### 后端测试

```bash
# SSE2 测试
make -C core/tests/nextpas.core.simd/test_sse2 clean test

# AVX2 测试
make -C core/tests/nextpas.core.simd/test_avx2 clean test

# NEON 测试
make -C core/tests/nextpas.core.simd/test_neon clean test
```

### 性能测试

```bash
# 基准测试
make -C core/tests/nextpas.core.simd/bench_dispatch_overhead clean test

# 跨平台性能对比
./bench_simd --platform=x86_64
./bench_simd --platform=aarch64
./bench_simd --platform=riscv64
```

## 已知问题

### x86_64

1. **AVX-512 对齐**: FPC `RECORDMIN=32` 不能保证 64-byte 对齐
2. **分派器开销**: atomic_load + 函数指针，~15-20 cycles

### AArch64

1. **GPR-to-vector**: 小向量通过 GPR 传递，有开销
2. **FPC 限制**: FPC 3.2.2 不支持 NEON 内联汇编

### RISC-V

1. **实验性**: 不稳定，可能有 bug
2. **覆盖度**: 部分操作
3. **性能**: 未优化

## 未来计划

### 短期 (1-2 周)

1. 编译期快速路径
2. 批量操作优化

### 中期 (2-4 周)

1. Intrinsics FP 真正实现
2. IEEE 754 测试

### 长期 (1-2 月)

1. 静态调度
2. RISC-V V 完善
3. LoongArch LASX
4. WebAssembly SIMD
