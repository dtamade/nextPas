# SIMD 模块目标树（总控地图）

> 最后更新: 2026-06-06
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
├── G9: RTL 依赖清零                 [ 90%] ✅
├── G10: 高级计算 (parallel/quant/NEON) [100%] ✅
├── G11: SIMD 深化 (INT8 dot/RealFft) [100%] ✅
├── G12: 算法层 (Winograd/Attention/Strassen) [100%] ✅
└── G13: SIMD contract qualification roadmap [ACTIVE] 🚧
```

## G13: SIMD contract qualification roadmap — 当前活跃路线

这条路线不是新增性能承诺，而是把 public contract、backend disposition、测试隔离和未来 API 边界说清楚。它覆盖当前 SIMD 线的验收点：

- [x] 512-bit record alignment: FPC `RECORDMIN=32` 不能保证普通 record/栈/数组/对象字段有 64-byte 地址；AVX-512 aligned load/store 只能依赖 `SimdAlloc(..., sa64)`、`AlignedAlloc(..., SIMD_ALIGN_64)` 或显式 aligned storage。
- [ ] NEON public backend status: 默认 public 状态是 scalar fallback；NEON inline asm 只有在 FPC 3.3.1+ 且 `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM` / `NEXTPAS_SIMD_ENABLE_NEON_ASM` / `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY` 同时满足时 opt-in。
- [ ] RISC-V V and LoongArch/LASX: 只能描述为 experimental/stub，不能包装成 stable backend；相关测试保持 opt-in / source-contract / QEMU 或目标机隔离。
- [ ] gather/scatter partial coverage: 现有 `VecF32x4` / `VecI32x4` utility 层和 AVX2 intrinsics 已有部分 coverage；下一阶段补正式 public facade、更多 lane、更多 backend coverage。
- [ ] F16/half precision design: 先定义类型/转换/检测/fallback 边界，再进入 ABI；能力检测至少覆盖 F16C、AVX512BF16、NEON FP16 和 scalar fallback。
- [ ] transpose API boundary: 区分 linalg matrix transpose（矩阵布局/API）和 SIMD lane transpose（寄存器 lane 重排），避免同名 API 混用。
- [ ] NEON AArch64 ABI GPR-to-vector: 文档和 benchmark 必须说明 GPR-to-vector 组装/拆回开销，不能无条件宣称 NEON 更快。

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
- [x] NEON (558/558 dispatch 覆盖)

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
- [x] nn 模块 API 文档 (docs/nextpas.core.simd.nn.md, 47 函数)
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
1. [G13] SIMD contract qualification roadmap — public/backend/source contract
2. [G13] 512-bit alignment + non-x86 backend status + experimental isolation
3. [G13] F16 / gather-scatter / transpose API boundary design

>>> 下一阶段 <<<
4. [G13] public facade/API proposal with tests before ABI changes
5. [G3] focused source-contract and runtime gate maintenance
6. [G5] benchmark and cross-runtime comparison after contracts stabilize

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
