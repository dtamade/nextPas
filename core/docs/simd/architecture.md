# nextpas.core.simd 架构设计

> 最后更新: 2026-08-31
> 公共 API 符号数以 `check_public_api_test_coverage.py` 为准（当前 720 covered）。

## 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│  用户代码                                                    │
├─────────────────────────────────────────────────────────────┤
│  L4: 门面 (nextpas.core.simd)                               │
│  VecF32x4Add, MemEqual, Utf8Validate, ...                   │
│  公共 API：见 coverage 工具（~720 symbols）                    │
├─────────────────────────────────────────────────────────────┤
│  L3: 高级算法                                                │
│  algorithms.pas (批量操作、数组运算)                         │
│  signal.pas (FFT、滤波、卷积)                                │
│  image.pas (图像处理)                                        │
│  nn.pas (神经网络)                                           │
│  linalg.pas (矩阵乘法 GEMM)                                 │
├─────────────────────────────────────────────────────────────┤
│  L2: Backend Adapters                                        │
│  sse2.pas (x86_64 SSE2) - 5000 行手写汇编                   │
│  avx2.pas (x86_64 AVX2) - 3000 行手写汇编                   │
│  avx512.pas (x86_64 AVX-512) - 手写汇编                     │
│  neon.pas (AArch64 NEON) - 手写汇编                          │
│  scalar.pas (标量回退) - 5000 行纯 Pascal                    │
├─────────────────────────────────────────────────────────────┤
│  L1: 分派器                                                  │
│  dispatch.pas (控制面: 后端注册、优先级、切换)               │
│  dataplane.pas (数据面: 不可变快照指针)                      │
├─────────────────────────────────────────────────────────────┤
│  L0: 类型定义 + Intrinsics                                   │
│  base.pas (TVecF32x4, TMask4, TM128, ...)                   │
│  intrinsics.sse2.pas (SSE2 raw ISA)                     │
│  intrinsics.avx2.pas (AVX2 raw ISA)                         │
│  intrinsics.neon.pas (NEON raw ISA)                          │
└─────────────────────────────────────────────────────────────┘
```

## 各层职责

### L0: 类型定义 + Intrinsics

**类型定义** (`base.pas`):
- TVecF32x4, TVecF64x2, TVecI32x4, ... (128-bit 向量)
- TVecF32x8, TVecF64x4, TVecI32x8, ... (256-bit 向量)
- TVecF32x16, TVecF64x8, TVecI32x16, ... (512-bit 向量)
- TMask4, TMask8, TMask16, ... (掩码类型)

**Intrinsics** (`intrinsics.*.pas`):
- Raw ISA 接口 (TM128 类型)
- Load/Store: 真正 SIMD 汇编
- Set/Zero: 真正 SIMD 汇编
- 整数算术: 真正 SIMD 汇编
- FP 算术: 标量回退 (处理特殊值)

### L1: 分派器

**控制面** (`dispatch.pas`):
- 后端注册
- 优先级排序
- 强制选择
- 锁保护，不频繁调用

**数据面** (`dataplane.pas`):
- 不可变快照指针
- atomic_load，无锁
- 热路径使用

### L2: Backend Adapters

**职责**:
- 手写汇编实现
- 注册到分派器
- 提供真正 SIMD 加速

**后端继承链**:
```
Scalar → SSE2 → SSE3 → SSSE3 → SSE4.1 → SSE4.2 → AVX2 → AVX-512
```

### L3: 高级算法

**algorithms.pas**:
- 批量操作 (ArrayAddF32, ArrayMulF32, ...)
- 数组运算 (ArrayDotF32, ArrayNormF32, ...)

**signal.pas**:
- FFT (快速傅里叶变换)
- 滤波 (FIR, IIR)
- 卷积

**image.pas**:
- 像素操作
- 图像变换

**nn.pas**:
- 激活函数 (Sigmoid, ReLU, ...)
- 卷积层
- 归一化层

**linalg.pas**:
- 矩阵乘法 (GEMM)
- 矩阵分解

### L4: 门面

**职责**:
- 统一 API 入口
- 自动选择最优后端
- 向后兼容

## 依赖关系

```
用户代码
    ↓
L4: nextpas.core.simd (门面)
    ↓
L3: algorithms, signal, image, nn, linalg
    ↓
L2: sse2, avx2, avx512, neon, scalar
    ↓
L1: dispatch, dataplane
    ↓
L0: base, intrinsics.*
```

## 关键设计决策

### 1. 分派器设计

**设计**: 运行时 dispatch 函数指针表
**优点**: 支持动态后端切换，兼容性好
**缺点**: FPC 编译器无法内联函数指针，~15-20 cycles 开销
**未来**: nextpas 编译器可以优化（内联函数指针、去虚拟化）

### 2. Intrinsics 层设计

**设计**: Raw ISA 接口，FP 算术标量回退
**优点**: 处理特殊值 (NaN, Inf, -0.0)，确保 IEEE 754 一致性
**缺点**: FP 算术不是真正 SIMD
**未来**: 可以在 Backend Adapters 中直接实现真正 SIMD

### 3. Backend Adapters 设计

**设计**: 手写汇编，注册到分派器
**优点**: 真正 SIMD 加速，零开销
**缺点**: 需要为每个平台编写汇编
**未来**: 扩展到更多平台 (RISC-V V, LoongArch LASX)

## 性能特征

| 操作 | 分派器开销 | Backend 开销 | 总开销 |
|------|-----------|-------------|--------|
| VecF32x4Add | ~15-20 cycles | ~1 cycle | ~16-21 cycles |
| MemEqual | ~15-20 cycles | ~1 cycle/16B | ~16-21 cycles |
| Utf8Validate | ~15-20 cycles | ~1 cycle/16B | ~16-21 cycles |

**优化方向**:
1. 编译期快速路径 (`{$IFDEF HAS_AVX2}` 直接调用)
2. nextpas 编译器优化（内联函数指针）
3. 批量操作摊薄分派器开销
