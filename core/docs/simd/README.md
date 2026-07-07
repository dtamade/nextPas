# nextpas.core.simd 模块

> 最后更新: 2026-07-06

## 概述

`nextpas.core.simd` 是 nextPas 框架的 SIMD 加速模块，为内存、文本、向量、矩阵等操作提供硬件加速。

### 设计目标

- **跨平台**: 支持 x86_64 (SSE2/AVX2/AVX-512)、AArch64 (NEON)、RISC-V (RVV)
- **高性能**: 手写汇编微内核，零开销 Backend Adapters
- **兼容性**: 标量回退确保任何平台可运行
- **易用性**: 统一 API，自动选择最优后端

### 当前状态

- **Backend Adapters**: ✅ 真正 SIMD 汇编实现
- **Intrinsics 层**: ⚠️ FP 算术是标量回退，整数/Load/Store 是真正 SIMD
- **分派器层**: ⚠️ FPC 编译器限制，无法内联函数指针

## 快速入门

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

## 文档索引

| 文档 | 内容 |
|------|------|
| [architecture.md](architecture.md) | 架构设计（分层、组件、依赖） |
| [api.md](api.md) | 公开 API 参考 |
| [backends.md](backends.md) | 后端实现详解 |
| [intrinsics.md](intrinsics.md) | Intrinsics 层详解 |
| [dispatch.md](dispatch.md) | 分派器层详解 |
| [platforms.md](platforms.md) | 平台支持 |
| [roadmap.md](roadmap.md) | 路线图 |
| [plan.md](plan.md) | 实施计划 |
| [progress.md](progress.md) | 进度跟踪 |
| [methodology.md](methodology.md) | 工作方法论 |
| [maintenance.md](maintenance.md) | 维护指南 |

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│  用户代码                                                    │
├─────────────────────────────────────────────────────────────┤
│  L4: 门面 (nextpas.core.simd)                               │
│  VecF32x4Add, MemEqual, Utf8Validate, ...                   │
├─────────────────────────────────────────────────────────────┤
│  L3: 高级算法 (algorithms, signal, image, nn, linalg)       │
│  批量操作、FFT、图像处理、神经网络、矩阵乘法                │
├─────────────────────────────────────────────────────────────┤
│  L2: Backend Adapters (sse2, avx2, avx512, neon, scalar)    │
│  手写汇编，零开销                                            │
├─────────────────────────────────────────────────────────────┤
│  L1: 分派器 (dispatch + dataplane)                          │
│  运行时后端选择，atomic_load + 函数指针                      │
├─────────────────────────────────────────────────────────────┤
│  L0: 类型定义 (base) + Intrinsics (intrinsics.*)            │
│  TM128, TVecF32x4, TMask4, raw ISA 接口                     │
└─────────────────────────────────────────────────────────────┘
```

## 使用场景

### 1. 向量运算

```pascal
uses nextpas.core.simd;

var
  A, B: TVecF32x4;
  Dot: Single;
begin
  A := VecF32x4Make(1.0, 2.0, 3.0, 4.0);
  B := VecF32x4Make(5.0, 6.0, 7.0, 8.0);
  Dot := VecF32x4Dot(A, B);  // 70.0
end;
```

### 2. 内存操作

```pascal
uses nextpas.core.simd;

var
  A, B: array[0..15] of Byte;
begin
  FillChar(A, 16, $AA);
  FillChar(B, 16, $AA);
  if MemEqual(@A, @B, 16) then
    WriteLn('Equal');
end;
```

### 3. 文本操作

```pascal
uses nextpas.core.simd;

var
  S: AnsiString;
begin
  S := 'Hello, World!';
  if Utf8Validate(@S[1], Length(S)) then
    WriteLn('Valid UTF-8');
end;
```

## 依赖关系

```
nextpas.core.simd
├── nextpas.core.simd.base          # 类型定义
├── nextpas.core.simd.dispatch      # 分派器
├── nextpas.core.simd.dataplane     # 数据面
├── nextpas.core.simd.cpuinfo       # CPU 检测
├── nextpas.core.simd.scalar        # 标量回退
├── nextpas.core.simd.sse2          # SSE2 后端
├── nextpas.core.simd.avx2          # AVX2 后端
├── nextpas.core.simd.avx512        # AVX-512 后端
├── nextpas.core.simd.neon          # NEON 后端
└── nextpas.core.simd.intrinsics.*  # Raw ISA 接口
```

## 构建与测试

```bash
# 运行所有 SIMD 测试
make -C core/tests/nextpas.core.simd clean test

# 运行特定测试
make -C core/tests/nextpas.core.simd/test_dispatch clean test

# 运行基准测试
make -C core/tests/nextpas.core.simd/bench_dispatch_overhead clean test
```
