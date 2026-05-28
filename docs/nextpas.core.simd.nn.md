# nextpas.core.simd.nn — 神经网络推理层

> 47 个函数，覆盖从编码器到解码器的完整推理链路。
> 关键操作已 SIMD 优化（Conv2D 39x, ChannelSoftmax 24x, Sigmoid 35x）。

## 激活函数 (12)

```pascal
procedure SigmoidF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure TanhF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SiLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure GeluApproxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure LeakyReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single = 0.01);
procedure PReLUF32(aSrc, aAlpha, aDst: PSingle; aCount: SizeUInt);
procedure HardSigmoidF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure HardSwishF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ELUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single = 1.0);
procedure SELUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SoftplusF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure LogSoftmaxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
```

## 归一化 (6)

```pascal
procedure LayerNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aFeatureCount: SizeUInt; aEpsilon: Single = 1e-5);
procedure BatchNormF32(aX: PSingle; aBatchSize, aFeatures: SizeUInt;
  aMean, aVariance, aGamma, aBeta: PSingle; aEpsilon: Single; aDst: PSingle);
procedure BatchNorm2DInferF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt;
  aGamma, aBeta, aMean, aVar: PSingle; aEpsilon: Single);
procedure RMSNormF32(aX, aGamma, aDst: PSingle;
  aFeatureCount: SizeUInt; aEpsilon: Single = 1e-5);
procedure GroupNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aFeatureCount, aNumGroups: SizeUInt; aEpsilon: Single = 1e-5);
procedure InstanceNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aChannels, aChannelSize: SizeUInt; aEpsilon: Single = 1e-5);
```

## 卷积 (10)

```pascal
// 1D
procedure Conv1DF32(aInput, aKernel, aOutput: PSingle;
  aInputLen, aKernelLen, aOutputLen: SizeUInt);
procedure Conv1DStridedF32(aInput, aKernel, aOutput: PSingle;
  aInputLen, aKernelLen, aStride, aOutputLen: SizeUInt);

// 2D — 标准卷积（im2col+GEMM 优化，K>=16 时自动启用）
procedure Conv2DF32(aInput, aKernel, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW: SizeUInt);
procedure Conv2DStridedF32(aInput, aKernel, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
procedure Conv2DBiasF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
procedure Conv2DBiasReLUF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
procedure Conv2DMultiChannelF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
procedure Conv2DSameF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
procedure DepthwiseConv2DF32(aInput, aKernel, aBias, aOutput: PSingle;
  aChannels, aInputH, aInputW, aKernelH, aKernelW: SizeUInt);
procedure TransposeConv2DF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters, aStride: SizeUInt);
```

## 池化 (6)

```pascal
procedure MaxPool1DF32(aInput, aOutput: PSingle; aInputLen, aKernelSize, aStride: SizeUInt);
procedure AvgPool1DF32(aInput, aOutput: PSingle; aInputLen, aKernelSize, aStride: SizeUInt);
procedure AdaptiveAvgPool1DF32(aInput, aOutput: PSingle; aInputLen, aOutputLen: SizeUInt);
procedure MaxPool2DF32(aInput, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
procedure AvgPool2DF32(aInput, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
procedure GlobalAvgPool2DF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
```

## 上采样与通道操作 (6)

```pascal
procedure UpsampleNearest2DF32(aInput, aOutput: PSingle;
  aChannels, aInputH, aInputW, aScaleH, aScaleW: SizeUInt);
procedure UpsampleBilinear2DF32(aInput, aOutput: PSingle;
  aChannels, aInputH, aInputW, aOutputH, aOutputW: SizeUInt);
procedure ChannelConcatF32(aA, aB, aOutput: PSingle;
  aChannelsA, aChannelsB, aHeight, aWidth: SizeUInt);
procedure ResidualAddF32(aInput, aResidual, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
procedure ChannelArgMaxF32(aInput: PSingle; aOutput: PInt32;
  aChannels, aHeight, aWidth: SizeUInt);
procedure ChannelSoftmaxF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
```

## 其他 (7)

```pascal
procedure SoftmaxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure BatchSoftmaxF32(aSrc, aDst: PSingle; aBatchSize, aClassCount: SizeUInt);
procedure LinearLayerF32(aInput, aWeight, aBias, aOutput: PSingle;
  aBatchSize, aInputDim, aOutputDim: SizeUInt);
procedure EmbeddingLookupF32(aTable: PSingle; aIndices: PInt32; aDst: PSingle;
  aEmbedDim, aNumIndices: SizeUInt);
function CrossEntropyLossF32(aLogits: PSingle; aTargets: PInt32;
  aBatchSize, aClassCount: SizeUInt): Single;
procedure DropoutF32(aSrc, aDst: PSingle; aCount: SizeUInt; aDropRate: Single; aSeed: UInt32);
procedure ClipGradF32(aGrad: PSingle; aCount: SizeUInt; aMaxNorm: Single);
```

## 性能特征

| 操作 | 优化策略 | Scalar→AVX2 加速 |
|------|----------|-----------------|
| Conv2DMultiChannelF32 | im2col + ReduceDotF32(len=C*KH*KW) | 4.5x |
| DepthwiseConv2DF32 | 行向量化 ArrayAxpyF32(len=OutputW) | 6.7x |
| ChannelSoftmaxF32 | 平面向量化 ArrayExpF32(len=H*W) | 20x |
| SigmoidF32 | ArrayExpF32 dispatch | 35x |
| BatchNorm2DInferF32 | ArrayLinearF32 per channel | 内存带宽瓶颈 |
| ResidualAddF32 | ArrayAddF32 dispatch | 内存带宽瓶颈 |

## 数据布局

所有 2D 操作使用 **CHW** (Channel-Height-Width) 布局：
- Input: `[Channels, Height, Width]`
- Kernel: `[NumFilters, InputChannels, KernelH, KernelW]`
- Output: `[NumFilters, OutputH, OutputW]`

## 使用示例

```pascal
uses nextpas.core.simd.nn, nextpas.core.simd.alloc;

var X, Y: PSingle;
begin
  X := SimdAlloc(64 * 56 * 56 * SizeOf(Single));
  Y := SimdAlloc(64 * 56 * 56 * SizeOf(Single));

  // Conv → BN → Activation
  Conv2DMultiChannelF32(X, Weights, Bias, Y, 64, 56, 56, 3, 3, 64);
  BatchNorm2DInferF32(Y, Y, 64, 54, 54, Gamma, Beta, Mean, Var, 1e-5);
  SigmoidF32(Y, Y, 64 * 54 * 54);

  // Decoder: Upsample → Concat → Conv
  UpsampleNearest2DF32(Y, X, 64, 27, 27, 2, 2);
  ChannelConcatF32(X, SkipConn, Y, 64, 64, 54, 54);
  Conv2DMultiChannelF32(Y, DecWeights, DecBias, X, 128, 54, 54, 3, 3, 64);

  // Output: Softmax → ArgMax
  ChannelSoftmaxF32(X, Y, 21, 52, 52);
  ChannelArgMaxF32(Y, ClassMap, 21, 52, 52);

  SimdFree(X); SimdFree(Y);
end;
```