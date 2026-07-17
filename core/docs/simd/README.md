# nextpas.core.simd 模块

> 最后更新: 2026-07-17
> **开发主线**: [roadmap.md](roadmap.md)（Phase 20+）。当前活动清单: [plan.md](plan.md)。

## 概述

`nextpas.core.simd` 是 nextPas 框架的 SIMD 加速模块，为内存、文本、向量、矩阵等操作提供硬件加速。

### 设计目标

- **跨平台**: 支持 x86_64 (SSE2/AVX2/AVX-512)、AArch64 (NEON)、RISC-V (RVV)
- **高性能**: 手写汇编微内核，零开销 Backend Adapters
- **兼容性**: 标量回退确保任何平台可运行
- **易用性**: 统一 API，自动选择最优后端
- **所有权诚实**: 无 dead wrapper；未实现槽继承 scalar baseline 并契约锁定

### 当前状态

- **Backend Adapters**: ✅ x86 SSE2…AVX-512 与 NEON 真 SIMD 汇编；RVV 实验；scalar 全覆盖回退
- **批量 / 超越函数**: ✅ x86 上 F32/F64 `Array*` 批量与超越函数深覆盖（Phase 13–18）；NEON BatchF32 代表 7 叶；RVV Batch* **故意 scalar**（S24a）
- **Intrinsics 层**: ✅ 主路径真实 ISA；实验性 ISA 可能 stub
- **分派器层**: ✅ 嵌套表 `CoreVectors` / `Batch*` / `Memory` / `Mask`（Phase 19）；Public ABI 字段名保持 flat
- **Mask**: ✅ NEON 绑定 portable `SharedMask*` + `scMaskedOps`（Wave B）
- **NEON Memory**: ✅ **15/15** 自有（Phase 22：Copy/Fill/DiffRange + Reverse/BytesIndexOf/Utf8Validate 真 asm 叶，仅 ASM opt-in 绑定）
- **NEON Batch\***: ⚠️ Phase 23a/23b 已接管 F32 Add/Sub/Mul/Min/Max/Abs/Neg；其余 Batch 槽仍 scalar
- **RVV Memory/Batch**: ✅ **故意 0 叶 scalar**（S24a 契约锁定；真叶等 S24b 硬件）
- **cpuinfo**: ✅ 主路径稳定
- **活动阶段**: Phase 20–23b + M-C1 + S24a + **S25a** 已收口；**Goal CURRENT=S25b**（见 [math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)）
- **验证基线 (2026-07-17)**:
  - `make focused FOCUS=core/tests/nextpas.core.simd` → **1740+ passed**
  - `neon-optin-focused` → **1740+ passed**
  - `make -C core/tests/nextpas.core.math clean test` → **exit 0**（M-C1: 305 tests, MATH_API_SURFACE 70/0）
  - `make hygiene` → pass
  - `api-coverage-contract` → **OK**（720/720 covered，missing=0 / thin=0，strict-thin）
  - **S25a hotspots**（Xeon E5-2696 v4, FPC 3.3.1 `-O3`, AVX2, VectorAsm=True；主指标 **vsTrue**）:
    - ArrayAddF32 @1024 → **4.51x**（目标 6x+，接近）
    - ArrayAddF64 @1024 → **6.36x**（达标）
    - ArrayMulF32 @16KB → **4.12x**（达标；旧 ~2.5x 为 vsLib）
    - MemEqual @4KB → **43.98x**（达标）
  - 方法与复现命令 → [performance-methodology.md](performance-methodology.md)

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

### 主线（先读）

| 文档 | 内容 |
|------|------|
| **[roadmap.md](roadmap.md)** | **开发路线图（权威）**：现状、Phase 20+、验收、优先级 |
| **[plan.md](plan.md)** | 当前阶段任务清单（薄指针） |
| [methodology.md](methodology.md) | 协作与验证纪律 |
| [performance-methodology.md](performance-methodology.md) | **S25a** 基准方法（vsTrue/vsLib）与热点数字 |

### 稳定参考

| 文档 | 内容 |
|------|------|
| [architecture.md](architecture.md) | 架构设计（分层、组件、依赖） |
| [api.md](api.md) | 公开 API 参考 |
| [backends.md](backends.md) | 后端实现详解 |
| [intrinsics.md](intrinsics.md) | Intrinsics 层详解 |
| [dispatch.md](dispatch.md) | 分派器层详解 |
| [platforms.md](platforms.md) | 平台支持 |
| [maintenance.md](maintenance.md) | 维护指南 |
| [design/dispatch-table-modularization.md](design/dispatch-table-modularization.md) | Phase 19 + Wave B 设计 |

### 历史存档（勿当主线）

| 文档 | 内容 |
|------|------|
| [plans/](plans/) | 历史专项计划 |
| `PHASE11_DEEPENING_PLAN.md` / `SIMD_DEEPENING_PLAN.md` / `SIMD_TODO_CLEANUP_PLAN.md` / `file-merge-plan.md` | 已完成或过期实施草稿 |

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

# S25a 热点复测（TrueScalar vs ScalarLib vs Dispatch）
make -C core/benchmarks/nextpas.core.simd/bench_hotspots clean run
```
