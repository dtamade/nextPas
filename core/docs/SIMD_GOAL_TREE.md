# SIMD 模块目标树（总控地图）

> 最后更新: 2026-05-28
> 总目标: 打造 FreePascal 领域最优秀的 SIMD 框架

## 总览

```
nextpas.core.simd
├── G1: 核心运算完备性 (dispatch)     [100%] ✅
├── G2: 神经网络推理层 (nn)           [100%] ✅
├── G3: 质量保障 (审计/测试/内存)     [100%] ✅
├── G4: 文档与可发现性               [100%] ✅
├── G5: 性能验证与基准               [100%] ✅
└── G6: 文本/内存 SIMD 加速          [100%] ✅
```

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
1. [G3.2] 审计修复 Wave 1 — Step 1-3 (测试bug + 死代码 + 过时文件)
2. [G3.3] HeapTrc 验证 nn 模块
3. [G3.2] 审计修复 Wave 1 — Step 4-7 (文档 + 补充测试)

>>> 下一阶段 <<<
4. [G4] 文档修复
5. [G3.2] 审计修复 Wave 2
6. [G5] nn benchmark

>>> 远期 <<<
7. [G1.5] Integer AVX-512 batch
8. [G5] 跨后端对比
```

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
