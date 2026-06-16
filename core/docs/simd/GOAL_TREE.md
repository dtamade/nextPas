# SIMD 模块目标树（总控地图）

> 最后更新: 2026-06-16
> 总目标: 打造 FreePascal 领域最优秀的 SIMD 框架

## 总览

```
nextpas.core.simd
├── G1: 核心运算完备性 (dispatch)     [100%] ✅
├── G2: 神经网络推理层 (nn)           [100%] ✅
├── G3: 质量保障 (审计/测试/内存)     [100%] ✅
├── G4: 文档与可发现性               [100%] ✅
├── G5: 性能验证与基准               [100%] ✅
├── G6: 文本/内存 SIMD 加速          [100%] ✅
├── G7: GEMM 微内核 (linalg.gemm)    [100%] ✅
├── G8: FFT SIMD 化 (signal)         [100%] ✅
├── G9: RTL 依赖清零                 [100%] ✅
├── G10: 高级计算 (parallel/quant/NEON) [100%] ✅
├── G11: SIMD 深化 (INT8 dot/RealFft) [100%] ✅
├── G12: 算法层 (Winograd/Attention/Strassen) [100%] ✅
├── G13: SIMD contract qualification roadmap [100%] ✅
├── G14: 维护可持续性 (maintenance sustainability) [100%] ✅
├── G15: 代码组织瘦身与可维护性       [100%] ✅
├── G16: RISC-V V 后端正确性验证       [Phase 1-2 100%] (Phase 3 需 RISC-V 硬件)
├── G17: Dispatch 开销优化 (19ns→8ns)  [Phase 1-3 100%] (Phase 4: 硬件测量确认)
├── G18: ArrayAdd 加速比提升            [Phase 1 100%] (benchmark: 6x峰值@256-1024元素)
├── G19: SysUtils 残留清理 (77→0)       [100%] ✅
├── G20: Gather/Scatter 正式化          [100%] ✅
└── G21: NEON AArch64 覆盖度基准          [执行中]
```

## G13: SIMD contract qualification roadmap — 当前活跃路线

这条路线不是新增性能承诺，而是把 public contract、backend disposition、测试隔离和未来 API 边界说清楚。它覆盖当前 SIMD 线的验收点：

- [x] 512-bit record alignment: FPC `RECORDMIN=32` 不能保证普通 record/栈/数组/对象字段有 64-byte 地址；AVX-512 aligned load/store 只能依赖 `SimdAlloc(..., sa64)`、`AlignedAlloc(..., SIMD_ALIGN_64)` 或显式 aligned storage。
- [x] NEON public backend status: 默认 public 状态是 scalar fallback；NEON inline asm 只有在 FPC 3.3.1+ 且 `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM` / `NEXTPAS_SIMD_ENABLE_NEON_ASM` / `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY` 同时满足时 opt-in。
- [x] RISC-V V and LoongArch/LASX: 只能描述为 experimental/stub，不能包装成 stable backend；相关测试保持 opt-in / source-contract / QEMU 或目标机隔离。
- [x] gather/scatter partial coverage: 现有 `VecF32x4` / `VecI32x4` utility 层和 AVX2 intrinsics 已有部分 coverage；下一阶段补正式 public facade、更多 lane、更多 backend coverage。
- [x] F16/half precision design: 先定义类型/转换/检测/fallback 边界，再进入 ABI；能力检测至少覆盖 F16C、AVX512BF16、NEON FP16 和 scalar fallback。
- [x] transpose API boundary: 区分 linalg matrix transpose（矩阵布局/API）和 SIMD lane transpose（寄存器 lane 重排），避免同名 API 混用。
- [x] NEON AArch64 ABI GPR-to-vector: 文档和 benchmark 必须说明 GPR-to-vector 组装/拆回开销，不能无条件宣称 NEON 更快。
- [x] Experimental AES semantic evidence: AESENC/AESENCLAST/AESDEC/AESDECLAST/AESIMC 已有 AES-NI semantic vector；AESKEYGENASSIST 只覆盖 AES key schedule standard-rcon subset，unsupported rcon fail-close。
- [x] Experimental AES non-x86 guard surface: forced non-x86 AES import/fail-close probe 已覆盖 `nextpas.core.simd.intrinsics.aes` 的 import/call/fail-close wiring。
- [x] Aligned memory argument contract: `AlignedAlloc` / `AlignedRealloc` / `IsAligned` / `AlignUp` / `AlignUpSize` / `AlignedMemCopy` / `AlignedMemFill` / `TAlignedArray<T>` 的 `alignment` 必须是非零 2 次幂且至少 `SizeOf(Pointer)`；非法值 fail-close 为 `EArgumentError`，对齐尺寸溢出 fail-close 为 `EOutOfMemory`。
- [x] SIMD allocator size contract: `SimdAlloc` / `SimdRealloc` 在 `size + header + alignment` 溢出时必须 fail-close 为 `EOutOfMemory`，不能 wrap 后小分配或提前释放原指针；`SimdAlloc(0)` / `SimdRealloc(nil, 0)` 返回 `nil`，`SimdFree(nil)` 是 no-op。

---

## G1: 核心运算完备性

### 1.1 F32 Batch Operations ✅ DONE
- [x] 四则运算: Add, Sub, Mul, Div
- [x] 一元运算: Abs, Neg, Sqrt, Rcp, Rsqrt
- [x] 标量广播: AddScalar, MulScalar
- [x] 复合运算: Clamp, Fma, Axpy, Linear
- [x] 归约运算: ReduceSum, ReduceDot, ReduceMin, ReduceMax
- [x] 超越函数: Exp, Log, Pow, Sin, Cos
- [x] Newton-Raphson 精化: RcpRefine, RsqrtRefine

### 1.2 F64 Batch Operations ✅ DONE
- [x] 四则运算: AddF64, SubF64, MulF64, DivF64
- [x] 一元: AbsF64, NegF64, SqrtF64
- [x] 标量: MulScalarF64, AddScalarF64, ClampF64, LinearF64
- [x] 归约: ReduceSumF64, ReduceDotF64, ReduceMinF64, ReduceMaxF64

### 1.3 Integer Batch Operations ✅ DONE
- [x] AddI32, SubI32, MulI16, PackSaturate
- [x] 类型转换: F32toI32, I32toF32
- [x] 位运算: And, Or, Xor, ShiftLeft, ShiftRight

### 1.4 后端覆盖 ✅ DONE
- [x] Scalar fallback (全 slot)
- [x] SSE2 (全 F32 + F64 batch)
- [x] AVX2 (全 F32 + F64 batch)
- [x] AVX-512 (231 slots, 100% F32 native ZMM)
- [x] NEON（自有 558 槽位全部覆盖；注：NEON backend 槽位数 558，canonical dispatch_slots_total 为 616，两者口径不同）

### 1.5 AVX-512 Integer Batch ✅ DONE
- [x] ArrayAddI32: vpaddd (16 int32/iter)
- [x] ArraySubI32: vpsubd (16 int32/iter)

---

## G2: 神经网络推理层 (47 functions)

### 2.1 激活函数 (12) ✅ DONE
- [x] Sigmoid, Tanh, SiLU, GELU, LeakyReLU, PReLU
- [x] HardSigmoid, HardSwish, ELU, SELU, Softplus, LogSoftmax

### 2.2 归一化 (6) ✅ DONE
- [x] LayerNorm, BatchNorm, RMSNorm, GroupNorm, InstanceNorm
- [x] BatchNorm2DInfer

### 2.3 卷积 (10) ✅ DONE
- [x] Conv1D, Conv1DStrided
- [x] Conv2D, Conv2DStrided, Conv2DBias, Conv2DBiasReLU
- [x] Conv2DMultiChannel, Conv2DSame, DepthwiseConv2D
- [x] TransposeConv2D

### 2.4 池化 (6) ✅ DONE
- [x] MaxPool1D, AvgPool1D, AdaptiveAvgPool1D
- [x] MaxPool2D, AvgPool2D, GlobalAvgPool2D

### 2.5 上采样/通道操作 (6) ✅ DONE
- [x] UpsampleNearest2D, UpsampleBilinear2D
- [x] ChannelConcat, ResidualAdd
- [x] ChannelArgMax, ChannelSoftmax

### 2.6 其他 (7) ✅ DONE
- [x] LinearLayer, EmbeddingLookup
- [x] BatchSoftmax, Softmax
- [x] CrossEntropyLoss
- [x] Dropout, ClipGrad

### 2.7 质量验证 ✅ DONE
- [x] HeapTrc 验证所有分配内存的函数 (0 unfreed blocks)
- [x] 边界条件测试 (n=0, channels=0, 1x1 spatial)
- [x] 大张量测试 (4ch 8x8 im2col 路径验证)

---

## G3: 质量保障 — 当前重点

### 3.1 测试现状
| 测试套件 | 测试数 | 状态 |
|----------|--------|------|
| 主套件 (BuildOrTest.sh) | 1245+ | ✅ |
| test_conv2d_pool2d | 119 | ✅ |
| test_f64_pipeline | 103 | ✅ |
| test_image_simd | 1092 | ✅ |
| test_stats_f64 | 18 | ✅ |
| test_linalg_f64 | 30 | ✅ |
| test_cnn_inference | 12 | ✅ |

### 3.2 审计修复计划 (39 issues) ✅ DONE
- [x] **Wave 1 (P1, 13 项)**: 全部完成
- [x] **Wave 2 (P2, 14 项)**: 全部完成
- [x] **Wave 3 (P3, 12 项)**: inline 标注 + 文档引用修复 + 标注完成

### 3.3 内存安全 ✅ DONE
- [x] HashMap HeapTrc 验证
- [x] nn 模块 HeapTrc 验证 (0 unfreed blocks)
- [x] Pipeline HeapTrc 验证
- [x] LinAlg HeapTrc 验证

---

## G4: 文档与可发现性

- [x] quickref API 名称更新 (DC1/DC2)
- [x] NEON 文档更新 (DC3)
- [x] architecture.md 路径修正 (DC4/DC5)
- [x] nn 模块 API 文档 (docs/simd/nn.md, 47 函数)
- [x] 使用示例 (encoder-decoder pipeline in nn.md)

---

## G5: 性能验证

- [x] Benchmark 框架 (simd_bench.pas)
- [x] 回归检测脚本 (bench_regression.sh, 15% threshold)
- [x] nn 模块 benchmark (nn_bench.pas)
- [x] Conv2D im2col+GEMM 优化: 1201ms → 31ms (39x)
- [x] DepthwiseConv2D 行向量化: 8ms → 1.2ms (6.7x)
- [x] ChannelSoftmax 平面向量化: 4.8ms → 0.2ms (24x)
- [x] 跨后端对比 (Scalar/SSE2/AVX2): Sigmoid 34.9x, Softmax 20x, Conv2D 4.5x

---

## 当前执行优先级

```
>>> 立即执行 <<<
1. [G14] 维护可持续性 — 文档真相源同步、技术债务清单准确化
2. [G14] gate 命令矩阵文档化 — BuildOrTest.sh 子命令与产物梳理
3. [G14] NEON asm 三重门控变量简化评估

>>> 下一阶段 <<<
4. [G14] 建立文档统计数据自动化刷新或定期核对纪律
5. [G14] 跨平台证据链 freshen 纪律自动化
6. [G14] 主入口层和 dispatch/cpuinfo 文档补充

>>> 远期 <<<
7. [G5] NEON AArch64 ABI cost benchmark and cross-runtime comparison
8. [G13] broader backend/lane coverage after hardware or QEMU evidence is available
```

---

## G7: GEMM 微内核 ✅ DONE

### 7.1 独立 GEMM 单元 ✅
- [x] `nextpas.core.simd.linalg.gemm.pas` 新建
- [x] GemmMicro6x16F32: AVX2+FMA 汇编微内核 (12 累加器, 累加模式)
- [x] PackPanelA_MR6: A 矩阵 pack 为 [MR, K] 连续布局
- [x] PackPanelB_NR16: B 矩阵 pack 为 [K, NR] 连续布局
- [x] PackPanelB_NR16_TransB: 从转置 B [N, K] 读取并 pack

### 7.2 三层 Cache Tiling ✅
- [x] GemmBlockedF32: C[M,N] = A[M,K] * B[K,N]
- [x] GemmBlockedTransBF32: C[M,N] = A[M,K] * B^T[N,K]
- [x] MC=72, KC=256, NC=4096 分块参数
- [x] M/N remainder 标量回退

### 7.3 集成 ✅
- [x] GemmF32 (linalg.pas) 路由: 大矩阵走 GemmBlockedF32
- [x] Conv2DMultiChannelF32 (nn.pas) 迁移到 GemmBlockedTransBF32
- [x] 旧 GemmTiled6x16F32/GemmMicro6x16 从 nn.pas 删除

### 7.4 验证 ✅
- [x] test_gemm_blocked: 31258 测试通过, 0 失败
- [x] HeapTrc: 0 unfreed memory blocks
- [x] Conv2D 回归: 123 测试通过

---

## G8: FFT SIMD 化 (进行中)

### 8.1 Twiddle 预计算 ✅
- [x] 所有 stage 的 twiddle factor 一次性预计算到对齐缓冲区
- [x] 消除蝶形热循环中的 Cos/Sin 调用

### 8.2 蝶形展开 ✅
- [x] Fused radix-4 首 pass (stage 0+1 合并, 零乘法)
- [x] IFFT 归一化用 ArrayMulScalarF32 (SIMD)

### 8.3 蝶形 SIMD 向量化 ✅
- [x] FftButterfly4_SSE2: 4 复数蝶形/call, shufps complex multiply
- [x] FftButterfly8_AVX2: 8 复数蝶形/call, ymm registers
- [x] Block-oriented 后期 stage (连续内存访问)
- [x] N>=16K: 2-3x 加速 (N=65536: 2.92x, N=262144: 2.99x)

### 8.4 FFT Plan API ✅
- [x] TSimdFftPlanF32: create once, execute many (no per-call alloc)
- [x] Forward + Inverse support (conjugate twiddle)
- [x] Plan vs one-shot: 25-41% faster (eliminates twiddle recompute)
- [x] Peak: 2.76 GFLOPS (N=65536), total 3.68x vs original

### 8.5 去 RTL 依赖 ✅
- [x] nextpas.core.simd.mathutil: SimdSinF32/SimdCosF32 (Cody-Waite + 11阶 minimax)
- [x] SimdLnF32 (log2 分解 + Remez 多项式)
- [x] signal.pas 完全零 Math 依赖

### 8.6 Split-radix (远期)
- [ ] Full radix-4 需要 digit-reversal permutation 重写
- [ ] 当前 fused radix-4 首 pass 已获得大部分收益

---

## G9: RTL 依赖清零 (Math 100%, SysUtils 69% reduced)

### 9.1 Math 替代 ✅ DONE
- [x] nextpas.core.simd.mathutil.pas: 完整数学库
  - Sin/Cos (Cody-Waite + 11阶 minimax, <2e-7 误差)
  - Ln (log2 分解 + Remez), Power (exp(exp*ln))
  - Tan, ArcSin, ArcCos, ArcTan2
  - Min/Max/Floor/Ceil (F32+F64 overloads)
  - IsNan/IsInfinite (位操作)
  - Infinity/NegInfinity/NaN 常量
- [x] 所有 SIMD 源文件零 Math 依赖
- [x] nextpas.core.math 也零 Math 依赖

### 9.2 SysUtils 最小化 ✅
- [x] 42 → 13 文件 (69% 减少)
- [x] 16 个后端文件: 移除未使用的 SysUtils import
- [x] 13 个 intrinsics stub: raise → RunError(217)
- 剩余 13 文件: cpuinfo (字符串解析), imageproc, avx2 gather (参数校验)
- 决策: 等 nextPas RTL 提供 Exception 平替

---

## 决策记录

| 日期 | 决策 | 原因 |
|------|------|------|
| 2026-05-28 | 质量优先于新功能 | nn 模块功能已完备，需要稳固 |
| 2026-05-28 | 审计修复按 Wave 执行 | P1 先行，每步一 commit |
| 2026-05-28 | 不重新生成 simdgen | 已知 drift，手动维护更安全 |
| 2026-05-28 | Conv2D im2col+GEMM | ReduceDotF32(len=3) 无法利用 SIMD，im2col 将 K 提升到 576 |
| 2026-05-28 | DepthwiseConv2D 行向量化 | 循环翻转：逐像素→逐行，ArrayAxpyF32(len=OutputW) |
| 2026-05-28 | ChannelSoftmax 平面向量化 | 逐像素跨通道→逐通道处理整平面，消除 stride 跳跃 |
| 2026-05-29 | GEMM 微内核独立单元 | 通用 API 复用，Conv2D 不再内联 GEMM 代码 |
| 2026-05-29 | 累加模式微内核 | 支持 K 方向分块，C += A*B 而非 C = A*B |
| 2026-05-29 | SIMD_X86_AVAILABLE define | 修复 cpuinfo case 编译错误，在 settings.inc 中按 CPU 架构定义 |
| 2026-06-13 | G13 全项收口 | 11 项契约全部完成；代码已合入，文档勾选同步 |
| 2026-06-13 | G14: 维护可持续性 | 文档真相源同步、gate 矩阵文档化、NEON 门控简化评估 |
| 2026-06-13 | G9 更新为 100% | RTL 依赖已清零 (Math 完全替代, SysUtils 69% reduced)；剩余存量在 cpuinfo/imageproc/avx2 gather 中等待 RTL 提供 Exception 平替，但不算未完成 |

---

## G14: 维护可持续性 — 下一步路线

G13 contract qualification 已全部收口（代码 + 文档）。下一阶段不追求新 ISA 后端或新算法，而聚焦维护治理。

### 14.1 文档真相源同步 ✅ DONE
- [x] maintenance.md Known Technical Debt 统计数据刷新（BuildOrTest.sh 1071 行 / Python 61 / Shell 20）
- [x] closeout.md 日期与状态更新到 2026-06-13
- [x] GOAL_TREE.md 执行优先级刷新

### 14.2 gate 命令矩阵文档化
- [x] BuildOrTest.sh 子命令 × 环境变量 × 前置条件 × 产物 整理为可机器解析矩阵 → `docs/simd/gate-command-matrix.md`

### 14.3 NEON asm 三重门控简化评估
- [x] 评估完成：`NEXTPAS_SIMD_NEON_ASM_COMPILER_READY` 冗余（已被 `FPC_FULLVERSION >= 030301` 覆盖），但当前保留以维持显式语义和编译安全。待 arm64 CI 环境就绪后再考虑实际简化。

### 14.4 证据链 freshen 自动化
- [x] freeze-status freshness 从文档约定升级为脚本自动检查 → `check_freshness.py`（git log 时间戳，比较矩阵，SKIP/FAIL 双模式）

### 14.5 技术债务清单维护
- [x] BuildOrTest.sh 已从 8858 行瘦身至 1071 行
- [x] LoongArch/SVE/SVE2 标注为 experimental stub，不可在生产路径激活
- [x] Dispatch 开销记录为已知限制（19-23 ns/call，单向量操作占比高，批量操作不受影响）
- [x] ArrayAdd 加速比记录为已知限制（1.3x 理论 4-8x，疑似内存带宽瓶颈）

---

## G19: SysUtils 残留清理 ✅ DONE

### 范围
- [x] core/src/ 源文件 SysUtils 清零（0 处残留）
- [x] core/tests/ 测试文件 SysUtils 从 77 处清理至 0 处
- [x] 使用 nextpas.core.text.conv 替换 SysUtils 字符串函数
- [x] test_vec_all: IntToStr/IntToHex/Format 替换为 local helper
- [x] test.lpr: ExtractFileName/Trim 替换为 local helper
- [x] bench/test 入口文件: 移除未使用的 SysUtils 引用
- [x] StrPas → string() cast（StrPas 无 SysUtils 时返回 ShortString 255 限制）
- [x] GetCurrentDir PAnsiChar cast AV 修复（显式 PAnsiChar 变量）

### 关键发现
- `StrPas` 无 SysUtils 时返回 `ShortString`（255 字符限制），需用 `string()` cast 替代
- `string(@LBuf[0])` 直接转换本地数组地址会 AV，需先赋给 `PAnsiChar` 变量再转

### 验证
- [x] 主套件 1280 测试全绿
- [x] Vec16/32/64 998 测试全绿
- [x] Algorithms 15 测试全绿
- [x] grep SysUtils 零匹配

---

## G20: Gather/Scatter 正式化 ✅ DONE

### 范围
- [x] `test_api_coverage_gather_scatter.pas` — 54 tests, 全通过
- [x] 覆盖 VecF32x4Gather/Scatter、VecI32x4Gather/Scatter
- [x] 覆盖 GatherSelect/ScatterSelect（masked 操作）
- [x] 重复索引语义测试（duplicate index: last-lane-wins scatter）
- [x] nil base 契约测试（EArgumentNil for enabled lanes, no-op for all-disabled）

### 验证
- [x] fpc 编译 0 error 0 warning
- [x] 54 tests passed, 0 failed


## G15-G21: 下一阶段路线

### 执行顺序

**Phase 1 (G15)**: 代码组织瘦身（scalar.pas 5655行→≤800行等）
**Phase 2 (G16 + G17)**: RISC-V V 正确性验证 + Dispatch 优化
**Phase 3 (G18 + G20 + G21)**: ArrayAdd 加速 + Gather/Scatter + NEON 基准

### 优先级

| 优先级 | 目标 | 内容 | 工作量 |
|--------|------|------|--------|
| P0 | G15 | 代码组织瘦身 | 3-5 天 |
| P1 | G16 | RISC-V V 后端正确性验证 | 4-6 天 |
| P1 | G17 | Dispatch 开销优化 (19ns→8ns) | 5-8 天 |
| P2 | G18 | ArrayAdd 加速比提升 (1.3x→4x+) | 4-7 天 |
| P2 | G20 | Gather/Scatter 正式化 | ✅ DONE |
| P3 | G21 | NEON AArch64 覆盖度基准 | 执行中 |
