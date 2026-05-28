# SIMD Pipeline Quickstart

## 概述

`TSimdF32Pipeline` 是 nextpas.core.simd 的计算图优化器。它让你用链式 API 表达 SIMD 计算，自动进行 pattern fusion 优化，然后降到高性能 dispatch slot 执行。

```pascal
uses nextpas.core.simd.pipeline;

// 基本用法: Linear + ReLU (自动 fusion 为单 pass fused kernel)
TSimdF32Pipeline.From(Src, Count)
  .Linear(Scale, Bias)
  .ReLU
  .Into(Dst);

// 多输入: alpha*X + Y (自动 fusion 为 Axpy)
TSimdF32Pipeline.From(X, Count)
  .MulScalar(Alpha)
  .Add(Y)
  .Into(Dst);

// Reduction: transform then reduce
var Sum: Single;
Sum := TSimdF32Pipeline.From(Src, Count)
  .MulScalar(2.0)
  .ReduceSum;
```

## 可用操作 (26 个)

| 类别 | 操作 | 说明 |
|------|------|------|
| 标量运算 | `MulScalar(v)` | x * v |
| | `AddScalar(v)` | x + v |
| | `SubScalar(v)` | x - v |
| | `DivScalar(v)` | x / v |
| | `Linear(s, b)` | x * s + b |
| 激活函数 | `ReLU` | max(x, 0) |
| | `LeakyReLU(α)` | x >= 0 ? x : α*x |
| | `Sigmoid` | 1/(1+exp(-x)) |
| | `SiLU` | x * sigmoid(x) |
| | `Tanh` | tanh(x) |
| | `Clamp(min, max)` | clamp(x, min, max) |
| 数学函数 | `Exp` / `Log` / `Sqrt` | 超越函数 |
| | `Sin` / `Cos` | 三角函数 |
| | `Abs` / `Neg` / `Rcp` | 基本运算 |
| | `Square` / `Pow(n)` | 幂运算 |
| | `Min(v)` / `Max(v)` | 标量限幅 |
| 多输入 | `Add(arr)` / `Sub(arr)` / `Mul(arr)` / `Div_(arr)` | element-wise |
| | `Fma(mul, add)` | x * mul + add |
| Reduction | `ReduceSum` / `ReduceMax` / `ReduceMin` | 归约 |
| | `ReduceMean` / `ReduceNorm` | 均值 / L2 范数 |
| | `ReduceDot(other)` | 点积 |

## Fusion 规则 (18 个)

Pipeline 在执行时自动应用以下优化（迭代直到不动点）：

| Pattern | Fused 结果 | 性能收益 |
|---------|-----------|---------|
| `MulScalar(1)` | 删除 | 消除无效操作 |
| `AddScalar(0)` | 删除 | 消除无效操作 |
| `Linear(1, 0)` | 删除 | 消除恒等变换 |
| `Neg + Neg` | 删除 | 双重否定消除 |
| `MulScalar + AddScalar` | `Linear` | 2 pass → 1 pass |
| `AddScalar + MulScalar` | `Linear` | 2 pass → 1 pass |
| `Neg + MulScalar(a)` | `MulScalar(-a)` | 2 pass → 1 pass |
| `Neg + AddScalar(b)` | `Linear(-1, b)` | 2 pass → 1 pass |
| `MulScalar + MulScalar` | `MulScalar` | 2 pass → 1 pass |
| `AddScalar + AddScalar` | `AddScalar` | 2 pass → 1 pass |
| `Linear + Linear` | `Linear` (affine 合并) | 2 pass → 1 pass |
| `Linear + ReLU` | `LinearReLU` (fused kernel) | 2 pass → 1 pass |
| `MulScalar + ReLU` | `LinearReLU(a, 0)` | 2 pass → 1 pass |
| `AddScalar + ReLU` | `LinearReLU(1, b)` | 2 pass → 1 pass |
| `Mul(arr) + Add(arr)` | `FmaFused` (ArrayFmaF32) | 2 pass → 1 pass |
| `Sub(arr) + Abs` | `AbsDiff` | 2 pass → 1 pass |
| `MulScalar + Add(arr)` | `Axpy` | 2 pass → 1 pass |
| `Clamp + Clamp` | `Clamp` (区间交集) | 2 pass → 1 pass |

## 性能数据 (AVX2)

| Pattern | L1 (16KB) | L2 (256KB) | Memory (16MB) |
|---------|-----------|------------|---------------|
| Linear+ReLU fused | **2.54x** | **1.99x** | **1.45x** |
| Axpy fused | **1.61x** | **1.74x** | **1.73x** |
| AbsDiff fused | **1.63x** | **1.75x** | **1.63x** |
| Chained Affine 3→1 | **2.33x** | **2.54x** | **2.87x** |

## 实际应用示例

### NN 推理: 全连接层 + 激活

```pascal
// 传统写法 (3 pass):
ArrayMulScalarF32(Input, Tmp, N, Weight);
ArrayAddScalarF32(Tmp, Tmp, N, Bias);
ArrayReLUF32(Tmp, Output, N);

// Pipeline 写法 (自动 fusion 为 1 pass):
TSimdF32Pipeline.From(Input, N)
  .Linear(Weight, Bias)
  .ReLU
  .Into(Output);
```

### 图像处理: 归一化 + 限幅

```pascal
TSimdF32Pipeline.From(Pixels, N)
  .Linear(1.0 / 255.0, 0)  // normalize to [0,1]
  .Clamp(0, 1)              // safety clamp
  .Into(NormPixels);
```

### 信号处理: 加权差分

```pascal
// |signal - reference| (AbsDiff fusion)
TSimdF32Pipeline.From(Signal, N)
  .Sub(Reference)
  .Abs
  .Into(Diff);
```

### 信号生成: 正弦波

```pascal
// 生成 440Hz 正弦波 (MulScalar+MulScalar 自动合并)
var Indices: TSimdF32Array;
Indices := TSimdF32Array.Ramp(SampleCount, 0, 1);
TSimdF32Pipeline.From(Indices.Data, SampleCount)
  .MulScalar(2 * Pi * 440 / SampleRate)
  .Sin
  .MulScalar(Amplitude)
  .Into(Output);
Indices.Free;
```

### 统计: transform + reduce

```pascal
// 计算 sum(x^2)
var Energy: Single;
Energy := TSimdF32Pipeline.From(Samples, N)
  .Square
  .ReduceSum;
```

## 运行 Benchmark

```bash
fpc -O3 -Fi./src -Fu./src -FE/tmp tests/nextpas.core.simd/nextpas.core.simd.pipeline_bench.pas
./tmp/nextpas.core.simd.pipeline_bench
```

## 设计原则

1. **零分配**: Pipeline 是栈上 record，不需要 heap 分配
2. **透明优化**: Fusion 在 `Into/Eval` 时自动执行，用户无需手动调用
3. **降到 dispatch**: Fused patterns 降到正式 SIMD dispatch slot，自动利用 SSE2/AVX2/AVX-512
4. **后端无关**: 新后端注册后，Pipeline 自动获得加速

## 编译缓存 (TSimdF32Plan)

对于反复执行相同变换的场景（如 NN 推理），可以编译 Pipeline 为 Plan：

```pascal
var Plan: TSimdF32Plan;

// 编译一次
Plan := TSimdF32Pipeline.From(nil, 0)
  .Linear(Scale, Bias)
  .ReLU
  .Compile;

// 反复执行（跳过 Optimize 开销）
Plan.Execute(Src, Dst, Count);
Plan.Execute(Src2, Dst2, Count2);  // 不同大小也可以
```
