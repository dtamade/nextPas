unit nextpas.core.simd.nn;


{$I nextpas.core.settings.inc}

interface

procedure SigmoidF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SoftmaxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure LayerNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aFeatureCount: SizeUInt; aEpsilon: Single = 1e-5);
procedure SiLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure GeluApproxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure LeakyReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single = 0.01);
procedure PReLUF32(aSrc, aAlpha, aDst: PSingle; aCount: SizeUInt);
procedure TanhF32(aSrc, aDst: PSingle; aCount: SizeUInt);


procedure BatchNormF32(aX: PSingle; aBatchSize, aFeatures: SizeUInt;
  aMean, aVariance, aGamma, aBeta: PSingle; aEpsilon: Single; aDst: PSingle);
procedure LinearLayerF32(aInput, aWeight, aBias, aOutput: PSingle;
  aBatchSize, aInputDim, aOutputDim: SizeUInt);
procedure Conv1DF32(aInput, aKernel, aOutput: PSingle;
  aInputLen, aKernelLen, aOutputLen: SizeUInt);
procedure Conv1DStridedF32(aInput, aKernel, aOutput: PSingle;
  aInputLen, aKernelLen, aStride: SizeUInt; aOutputLen: SizeUInt);
procedure DropoutF32(aSrc, aDst: PSingle; aCount: SizeUInt; aDropRate: Single; aSeed: UInt32);
procedure ClipGradF32(aGrad: PSingle; aCount: SizeUInt; aMaxNorm: Single);

procedure MaxPool1DF32(aInput, aOutput: PSingle; aInputLen, aKernelSize, aStride: SizeUInt);
procedure AvgPool1DF32(aInput, aOutput: PSingle; aInputLen, aKernelSize, aStride: SizeUInt);

procedure HardSigmoidF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure HardSwishF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure ELUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single = 1.0);
procedure LogSoftmaxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure SoftplusF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure RMSNormF32(aX, aGamma, aDst: PSingle; aFeatureCount: SizeUInt; aEpsilon: Single = 1e-5);
procedure SELUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
procedure GroupNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aFeatureCount, aNumGroups: SizeUInt; aEpsilon: Single = 1e-5);
procedure InstanceNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aChannels, aChannelSize: SizeUInt; aEpsilon: Single = 1e-5);
procedure EmbeddingLookupF32(aTable: PSingle; aIndices: PInt32; aDst: PSingle;
  aEmbedDim, aNumIndices: SizeUInt);
procedure BatchSoftmaxF32(aSrc, aDst: PSingle; aBatchSize, aClassCount: SizeUInt);
procedure AdaptiveAvgPool1DF32(aInput, aOutput: PSingle; aInputLen, aOutputLen: SizeUInt);
function CrossEntropyLossF32(aLogits: PSingle; aTargets: PInt32;
  aBatchSize, aClassCount: SizeUInt): Single;

procedure Conv2DF32(aInput, aKernel, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW: SizeUInt);
procedure Conv2DStridedF32(aInput, aKernel, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
procedure MaxPool2DF32(aInput, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
procedure AvgPool2DF32(aInput, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);

procedure Conv2DBiasF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
procedure Conv2DBiasReLUF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
procedure Conv2DMultiChannelF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);

procedure GlobalAvgPool2DF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
procedure BatchNorm2DInferF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt;
  aGamma, aBeta, aMean, aVar: PSingle; aEpsilon: Single);
procedure DepthwiseConv2DF32(aInput, aKernel, aBias, aOutput: PSingle;
  aChannels, aInputH, aInputW, aKernelH, aKernelW: SizeUInt);

procedure Conv2DSameF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);

procedure UpsampleNearest2DF32(aInput, aOutput: PSingle;
  aChannels, aInputH, aInputW, aScaleH, aScaleW: SizeUInt);
procedure ChannelConcatF32(aA, aB, aOutput: PSingle;
  aChannelsA, aChannelsB, aHeight, aWidth: SizeUInt);
procedure ResidualAddF32(aInput, aResidual, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
procedure UpsampleBilinear2DF32(aInput, aOutput: PSingle;
  aChannels, aInputH, aInputW, aOutputH, aOutputW: SizeUInt);
procedure TransposeConv2DF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters, aStride: SizeUInt);

procedure ChannelArgMaxF32(aInput: PSingle; aOutput: PInt32;
  aChannels, aHeight, aWidth: SizeUInt);
procedure ChannelSoftmaxF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);

implementation

uses
  nextpas.core.simd,
  nextpas.core.simd.alloc;

procedure SigmoidF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  if aCount = 0 then Exit;
  ArrayNegF32(aSrc, aDst, aCount);
  ArrayExpF32(aDst, aDst, aCount);
  ArrayAddScalarF32(aDst, aDst, aCount, 1.0);
  ArrayRcpF32(aDst, aDst, aCount);
end;

procedure SoftmaxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LMax, LSum: Single;
begin
  if aCount = 0 then Exit;
  // Step 1: find max for numerical stability
  LMax := ReduceMaxF32(aSrc, aCount);
  // Step 2: dst = src - max
  ArrayAddScalarF32(aSrc, aDst, aCount, -LMax);
  // Step 3: dst = exp(dst)
  ArrayExpF32(aDst, aDst, aCount);
  // Step 4: sum = reduce_sum(dst)
  LSum := ReduceSumF32(aDst, aCount);
  // Step 5: dst = dst / sum
  if LSum <> 0 then
    ArrayMulScalarF32(aDst, aDst, aCount, 1.0 / LSum);
end;

procedure LayerNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aFeatureCount: SizeUInt; aEpsilon: Single);
var
  LMean, LVar, LInvStd: Single;
begin
  if aFeatureCount = 0 then Exit;
  LMean := ReduceSumF32(aX, aFeatureCount) / aFeatureCount;
  LVar := ReduceDotF32(aX, aX, aFeatureCount) / aFeatureCount - LMean * LMean;
  if LVar < 0 then LVar := 0;
  LInvStd := 1.0 / System.Sqrt(LVar + aEpsilon);
  ArrayNormF32(aX, aDst, aFeatureCount, LMean, LInvStd);
  if (aGamma <> nil) and (aBeta <> nil) then
    ArrayFmaF32(aDst, aGamma, aBeta, aDst, aFeatureCount)
  else if aGamma <> nil then
    ArrayMulF32(aDst, aGamma, aDst, aFeatureCount);
end;

procedure SiLUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  if aSrc <> aDst then
  begin
    SigmoidF32(aSrc, aDst, aCount);
    ArrayMulF32(aSrc, aDst, aDst, aCount);
  end
  else
  begin
    LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
    SigmoidF32(aSrc, LTmp, aCount);
    ArrayMulF32(aSrc, LTmp, aDst, aCount);
    SimdFree(LTmp);
  end;
end;

procedure GeluApproxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var
  LTmp: PSingle;
  LNeedFree: Boolean;
begin
  if aCount = 0 then Exit;
  if aSrc <> aDst then
  begin
    LTmp := aDst;
    LNeedFree := False;
  end
  else
  begin
    LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
    LNeedFree := True;
  end;
  ArrayMulScalarF32(aSrc, LTmp, aCount, 1.702);
  SigmoidF32(LTmp, LTmp, aCount);
  ArrayMulF32(aSrc, LTmp, aDst, aCount);
  if LNeedFree then SimdFree(LTmp);
end;

procedure LeakyReLUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  if aAlpha <= 1.0 then
  begin
    if aSrc <> aDst then
    begin
      ArrayMulScalarF32(aSrc, aDst, aCount, aAlpha);
      ArrayMaxF32(aSrc, aDst, aDst, aCount);
    end
    else
    begin
      LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
      ArrayMulScalarF32(aSrc, LTmp, aCount, aAlpha);
      ArrayMaxF32(aSrc, LTmp, aDst, aCount);
      SimdFree(LTmp);
    end;
  end
  else
  begin
    LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
    ArrayClampF32(aSrc, LTmp, aCount, -3.4028235e38, 0);
    ArrayMulScalarF32(LTmp, LTmp, aCount, aAlpha);
    ArrayReLUF32(aSrc, aDst, aCount);
    ArrayAddF32(aDst, LTmp, aDst, aCount);
    SimdFree(LTmp);
  end;
end;

procedure PReLUF32(aSrc, aAlpha, aDst: PSingle; aCount: SizeUInt);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  ArrayClampF32(aSrc, LTmp, aCount, -3.4028235e38, 0);
  ArrayMulF32(LTmp, aAlpha, LTmp, aCount);
  ArrayReLUF32(aSrc, aDst, aCount);
  ArrayAddF32(aDst, LTmp, aDst, aCount);
  SimdFree(LTmp);
end;

procedure TanhF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  ArrayClampF32(aSrc, aDst, aCount, -44, 44);
  ArrayMulScalarF32(aDst, aDst, aCount, 2.0);
  ArrayExpF32(aDst, aDst, aCount);
  ArrayAddScalarF32(aDst, LTmp, aCount, -1.0);
  ArrayAddScalarF32(aDst, aDst, aCount, 1.0);
  ArrayDivF32(LTmp, aDst, aDst, aCount);
  SimdFree(LTmp);
end;


procedure BatchNormF32(aX: PSingle; aBatchSize, aFeatures: SizeUInt;
  aMean, aVariance, aGamma, aBeta: PSingle; aEpsilon: Single; aDst: PSingle);
var
  b, f: SizeUInt;
  LScale, LBias: PSingle;
  LInvStd: Single;
begin
  if (aBatchSize = 0) or (aFeatures = 0) then Exit;
  if aFeatures >= 8 then
  begin
    LScale := PSingle(SimdAlloc(aFeatures * SizeOf(Single)));
    LBias := PSingle(SimdAlloc(aFeatures * SizeOf(Single)));
    for f := 0 to aFeatures - 1 do
    begin
      LInvStd := 1.0 / System.Sqrt(aVariance[f] + aEpsilon);
      LScale[f] := LInvStd * aGamma[f];
      LBias[f] := aBeta[f] - aMean[f] * LScale[f];
    end;
    for b := 0 to aBatchSize - 1 do
      ArrayFmaF32(@aX[b * aFeatures], LScale, LBias, @aDst[b * aFeatures], aFeatures);
    SimdFree(LScale);
    SimdFree(LBias);
  end
  else
  begin
    for f := 0 to aFeatures - 1 do
    begin
      LInvStd := 1.0 / System.Sqrt(aVariance[f] + aEpsilon);
      for b := 0 to aBatchSize - 1 do
        aDst[b * aFeatures + f] := (aX[b * aFeatures + f] - aMean[f]) * LInvStd * aGamma[f] + aBeta[f];
    end;
  end;
end;

procedure LinearLayerF32(aInput, aWeight, aBias, aOutput: PSingle;
  aBatchSize, aInputDim, aOutputDim: SizeUInt);
var
  b, o: SizeUInt;
begin
  if (aBatchSize = 0) or (aInputDim = 0) or (aOutputDim = 0) then Exit;
  for b := 0 to aBatchSize - 1 do
  begin
    for o := 0 to aOutputDim - 1 do
      aOutput[b * aOutputDim + o] := ReduceDotF32(@aInput[b * aInputDim], @aWeight[o * aInputDim], aInputDim);
    if aBias <> nil then
      ArrayAddF32(@aOutput[b * aOutputDim], aBias, @aOutput[b * aOutputDim], aOutputDim);
  end;
end;

procedure Conv1DF32(aInput, aKernel, aOutput: PSingle;
  aInputLen, aKernelLen, aOutputLen: SizeUInt);
var
  i, k: SizeUInt;
  LSum: Single;
begin
  if (aOutputLen = 0) or (aKernelLen = 0) or (aInputLen = 0) then Exit;
  for i := 0 to aOutputLen - 1 do
  begin
    if i + aKernelLen <= aInputLen then
      aOutput[i] := ReduceDotF32(@aInput[i], aKernel, aKernelLen)
    else
    begin
      LSum := 0;
      for k := 0 to aKernelLen - 1 do
        if i + k < aInputLen then
          LSum := LSum + aInput[i + k] * aKernel[k];
      aOutput[i] := LSum;
    end;
  end;
end;

procedure Conv1DStridedF32(aInput, aKernel, aOutput: PSingle;
  aInputLen, aKernelLen, aStride: SizeUInt; aOutputLen: SizeUInt);
var
  i, k, pos: SizeUInt;
  LSum: Single;
begin
  if (aOutputLen = 0) or (aKernelLen = 0) or (aInputLen = 0) or (aStride = 0) then Exit;
  for i := 0 to aOutputLen - 1 do
  begin
    pos := i * aStride;
    if pos + aKernelLen <= aInputLen then
      aOutput[i] := ReduceDotF32(@aInput[pos], aKernel, aKernelLen)
    else
    begin
      LSum := 0;
      for k := 0 to aKernelLen - 1 do
        if pos + k < aInputLen then
          LSum := LSum + aInput[pos + k] * aKernel[k];
      aOutput[i] := LSum;
    end;
  end;
end;

procedure DropoutF32(aSrc, aDst: PSingle; aCount: SizeUInt; aDropRate: Single; aSeed: UInt32);
var
  i: SizeUInt;
  LState: UInt32;
  LScale: Single;
begin
  if aCount = 0 then Exit;
  if aDropRate >= 1.0 then
  begin
    FillChar(aDst^, aCount * SizeOf(Single), 0);
    Exit;
  end;
  if aDropRate <= 0.0 then
  begin
    Move(aSrc^, aDst^, aCount * SizeOf(Single));
    Exit;
  end;
  LState := aSeed;
  if LState = 0 then LState := 2463534242;
  LScale := 1.0 / (1.0 - aDropRate);
  for i := 0 to aCount - 1 do
  begin
    // xorshift32
    LState := LState xor (LState shl 13);
    LState := LState xor (LState shr 17);
    LState := LState xor (LState shl 5);
    if (LState / $FFFFFFFF) < aDropRate then
      aDst[i] := 0
    else
      aDst[i] := aSrc[i] * LScale;
  end;
end;

procedure ClipGradF32(aGrad: PSingle; aCount: SizeUInt; aMaxNorm: Single);
var
  LNorm: Single;
  LScale: Single;
begin
  if aCount = 0 then Exit;
  LNorm := System.Sqrt(ReduceDotF32(aGrad, aGrad, aCount));
  if LNorm > aMaxNorm then
  begin
    LScale := aMaxNorm / LNorm;
    ArrayMulScalarF32(aGrad, aGrad, aCount, LScale);
  end;
end;

procedure MaxPool1DF32(aInput, aOutput: PSingle; aInputLen, aKernelSize, aStride: SizeUInt);
var
  i, oIdx: SizeUInt;
  LRemain: SizeUInt;
begin
  if (aInputLen = 0) or (aKernelSize = 0) or (aStride = 0) then Exit;
  oIdx := 0;
  i := 0;
  while i + aKernelSize <= aInputLen do
  begin
    aOutput[oIdx] := ReduceMaxF32(@aInput[i], aKernelSize);
    Inc(oIdx);
    Inc(i, aStride);
  end;
end;

procedure AvgPool1DF32(aInput, aOutput: PSingle; aInputLen, aKernelSize, aStride: SizeUInt);
var
  i, oIdx: SizeUInt;
  LInvK: Single;
begin
  if (aInputLen = 0) or (aKernelSize = 0) or (aStride = 0) then Exit;
  LInvK := 1.0 / aKernelSize;
  oIdx := 0;
  i := 0;
  while i + aKernelSize <= aInputLen do
  begin
    aOutput[oIdx] := ReduceSumF32(@aInput[i], aKernelSize) * LInvK;
    Inc(oIdx);
    Inc(i, aStride);
  end;
end;

procedure HardSigmoidF32(aSrc, aDst: PSingle; aCount: SizeUInt);
begin
  if aCount = 0 then Exit;
  ArrayLinearF32(aSrc, aDst, aCount, 1.0/6.0, 0.5);
  ArrayClampF32(aDst, aDst, aCount, 0, 1);
end;

procedure HardSwishF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  if aSrc <> aDst then
  begin
    HardSigmoidF32(aSrc, aDst, aCount);
    ArrayMulF32(aSrc, aDst, aDst, aCount);
  end
  else
  begin
    LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
    HardSigmoidF32(aSrc, LTmp, aCount);
    ArrayMulF32(aSrc, LTmp, aDst, aCount);
    SimdFree(LTmp);
  end;
end;

procedure ELUF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single);
var LNeg: PSingle;
begin
  if aCount = 0 then Exit;
  LNeg := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  ArrayClampF32(aSrc, LNeg, aCount, -3.4028235e38, 0);
  ArrayExpF32(LNeg, LNeg, aCount);
  ArrayLinearF32(LNeg, LNeg, aCount, aAlpha, -aAlpha);
  ArrayReLUF32(aSrc, aDst, aCount);
  ArrayAddF32(aDst, LNeg, aDst, aCount);
  SimdFree(LNeg);
end;

procedure LogSoftmaxF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LMax, LLogSum: Single;
    LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  LMax := ReduceMaxF32(aSrc, aCount);
  if aSrc <> aDst then
  begin
    ArrayAddScalarF32(aSrc, aDst, aCount, -LMax);
    ArrayExpF32(aDst, aDst, aCount);
    LLogSum := Ln(ReduceSumF32(aDst, aCount));
    ArrayAddScalarF32(aSrc, aDst, aCount, -LMax - LLogSum);
  end
  else
  begin
    LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
    ArrayAddScalarF32(aSrc, LTmp, aCount, -LMax);
    ArrayExpF32(LTmp, LTmp, aCount);
    LLogSum := Ln(ReduceSumF32(LTmp, aCount));
    ArrayAddScalarF32(aSrc, aDst, aCount, -LMax - LLogSum);
    SimdFree(LTmp);
  end;
end;

procedure SoftplusF32(aSrc, aDst: PSingle; aCount: SizeUInt);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  ArrayAbsF32(aSrc, LTmp, aCount);
  ArrayNegF32(LTmp, LTmp, aCount);
  ArrayExpF32(LTmp, LTmp, aCount);
  ArrayAddScalarF32(LTmp, LTmp, aCount, 1.0);
  ArrayLogF32(LTmp, LTmp, aCount);
  ArrayReLUF32(aSrc, aDst, aCount);
  ArrayAddF32(aDst, LTmp, aDst, aCount);
  SimdFree(LTmp);
end;

procedure RMSNormF32(aX, aGamma, aDst: PSingle; aFeatureCount: SizeUInt; aEpsilon: Single);
var LInvRMS: Single;
begin
  if aFeatureCount = 0 then Exit;
  LInvRMS := 1.0 / System.Sqrt(
    ReduceDotF32(aX, aX, aFeatureCount) / aFeatureCount + aEpsilon);
  ArrayMulScalarF32(aX, aDst, aFeatureCount, LInvRMS);
  if aGamma <> nil then
    ArrayMulF32(aDst, aGamma, aDst, aFeatureCount);
end;

procedure SELUF32(aSrc, aDst: PSingle; aCount: SizeUInt);
const
  SELU_LAMBDA: Single = 1.0507009873554804934193349852946;
  SELU_ALPHA: Single = 1.6732632423543772848170429916717;
begin
  if aCount = 0 then Exit;
  ELUF32(aSrc, aDst, aCount, SELU_ALPHA);
  ArrayMulScalarF32(aDst, aDst, aCount, SELU_LAMBDA);
end;

procedure GroupNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aFeatureCount, aNumGroups: SizeUInt; aEpsilon: Single);
var
  g, LGroupSize: SizeUInt;
  LMean, LVar, LInvStd: Single;
begin
  if (aFeatureCount = 0) or (aNumGroups = 0) then Exit;
  LGroupSize := aFeatureCount div aNumGroups;
  if (LGroupSize = 0) or (LGroupSize * aNumGroups <> aFeatureCount) then Exit;
  for g := 0 to aNumGroups - 1 do
  begin
    LMean := ReduceSumF32(@aX[g * LGroupSize], LGroupSize) / LGroupSize;
    LVar := ReduceDotF32(@aX[g * LGroupSize], @aX[g * LGroupSize], LGroupSize) / LGroupSize - LMean * LMean;
    if LVar < 0 then LVar := 0;
    LInvStd := 1.0 / System.Sqrt(LVar + aEpsilon);
    ArrayNormF32(@aX[g * LGroupSize], @aDst[g * LGroupSize], LGroupSize, LMean, LInvStd);
  end;
  if (aGamma <> nil) and (aBeta <> nil) then
    ArrayFmaF32(aDst, aGamma, aBeta, aDst, aFeatureCount)
  else if aGamma <> nil then
    ArrayMulF32(aDst, aGamma, aDst, aFeatureCount);
end;

procedure InstanceNormF32(aX, aGamma, aBeta, aDst: PSingle;
  aChannels, aChannelSize: SizeUInt; aEpsilon: Single);
begin
  GroupNormF32(aX, aGamma, aBeta, aDst, aChannels * aChannelSize, aChannels, aEpsilon);
end;

procedure EmbeddingLookupF32(aTable: PSingle; aIndices: PInt32; aDst: PSingle;
  aEmbedDim, aNumIndices: SizeUInt);
var i: SizeUInt;
begin
  if (aNumIndices = 0) or (aEmbedDim = 0) then Exit;
  for i := 0 to aNumIndices - 1 do
    Move(aTable[aIndices[i] * aEmbedDim], aDst[i * aEmbedDim], aEmbedDim * SizeOf(Single));
end;

procedure BatchSoftmaxF32(aSrc, aDst: PSingle; aBatchSize, aClassCount: SizeUInt);
var b: SizeUInt;
begin
  if (aBatchSize = 0) or (aClassCount = 0) then Exit;
  for b := 0 to aBatchSize - 1 do
    SoftmaxF32(@aSrc[b * aClassCount], @aDst[b * aClassCount], aClassCount);
end;

procedure AdaptiveAvgPool1DF32(aInput, aOutput: PSingle; aInputLen, aOutputLen: SizeUInt);
var
  i, LStart, LEnd, LSize: SizeUInt;
begin
  if (aInputLen = 0) or (aOutputLen = 0) then Exit;
  for i := 0 to aOutputLen - 1 do
  begin
    LStart := (i * aInputLen) div aOutputLen;
    LEnd := ((i + 1) * aInputLen) div aOutputLen;
    LSize := LEnd - LStart;
    if LSize > 0 then
      aOutput[i] := ReduceSumF32(@aInput[LStart], LSize) / LSize
    else
      aOutput[i] := aInput[LStart];
  end;
end;

function CrossEntropyLossF32(aLogits: PSingle; aTargets: PInt32;
  aBatchSize, aClassCount: SizeUInt): Single;
var
  b: SizeUInt;
  LLogSoftmax: PSingle;
  LSum: Single;
begin
  if (aBatchSize = 0) or (aClassCount = 0) then Exit(0);
  LLogSoftmax := PSingle(SimdAlloc(aClassCount * SizeOf(Single)));
  LSum := 0;
  for b := 0 to aBatchSize - 1 do
  begin
    LogSoftmaxF32(@aLogits[b * aClassCount], LLogSoftmax, aClassCount);
    LSum := LSum - LLogSoftmax[aTargets[b]];
  end;
  SimdFree(LLogSoftmax);
  Result := LSum / aBatchSize;
end;

procedure Conv2DF32(aInput, aKernel, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW: SizeUInt);
var
  oy, ox, ky: SizeUInt;
  LOutputH, LOutputW: SizeUInt;
  LSum: Single;
  LInputRow, LKernelRow: PSingle;
begin
  if (aInputH = 0) or (aInputW = 0) or (aKernelH = 0) or (aKernelW = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := aInputH - aKernelH + 1;
  LOutputW := aInputW - aKernelW + 1;
  for oy := 0 to LOutputH - 1 do
    for ox := 0 to LOutputW - 1 do
    begin
      LSum := 0;
      for ky := 0 to aKernelH - 1 do
      begin
        LInputRow := @aInput[(oy + ky) * aInputW + ox];
        LKernelRow := @aKernel[ky * aKernelW];
        LSum := LSum + ReduceDotF32(LInputRow, LKernelRow, aKernelW);
      end;
      aOutput[oy * LOutputW + ox] := LSum;
    end;
end;

procedure Conv2DStridedF32(aInput, aKernel, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
var
  oy, ox, ky: SizeUInt;
  LOutputH, LOutputW: SizeUInt;
  LSum: Single;
  LInputRow, LKernelRow: PSingle;
  iy, ix: SizeUInt;
begin
  if (aInputH = 0) or (aInputW = 0) or (aKernelH = 0) or (aKernelW = 0) then Exit;
  if (aStrideH = 0) or (aStrideW = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := (aInputH - aKernelH) div aStrideH + 1;
  LOutputW := (aInputW - aKernelW) div aStrideW + 1;
  for oy := 0 to LOutputH - 1 do
  begin
    iy := oy * aStrideH;
    for ox := 0 to LOutputW - 1 do
    begin
      ix := ox * aStrideW;
      LSum := 0;
      for ky := 0 to aKernelH - 1 do
      begin
        LInputRow := @aInput[(iy + ky) * aInputW + ix];
        LKernelRow := @aKernel[ky * aKernelW];
        LSum := LSum + ReduceDotF32(LInputRow, LKernelRow, aKernelW);
      end;
      aOutput[oy * LOutputW + ox] := LSum;
    end;
  end;
end;

procedure MaxPool2DF32(aInput, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
var
  oy, ox, ky, kx: SizeUInt;
  LOutputH, LOutputW: SizeUInt;
  iy, ix: SizeUInt;
  LMax, LRowMax: Single;
begin
  if (aInputH = 0) or (aInputW = 0) or (aKernelH = 0) or (aKernelW = 0) then Exit;
  if (aStrideH = 0) or (aStrideW = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := (aInputH - aKernelH) div aStrideH + 1;
  LOutputW := (aInputW - aKernelW) div aStrideW + 1;
  if aKernelW >= 8 then
  begin
    for oy := 0 to LOutputH - 1 do
    begin
      iy := oy * aStrideH;
      for ox := 0 to LOutputW - 1 do
      begin
        ix := ox * aStrideW;
        LMax := ReduceMaxF32(@aInput[iy * aInputW + ix], aKernelW);
        for ky := 1 to aKernelH - 1 do
        begin
          LRowMax := ReduceMaxF32(@aInput[(iy + ky) * aInputW + ix], aKernelW);
          if LRowMax > LMax then LMax := LRowMax;
        end;
        aOutput[oy * LOutputW + ox] := LMax;
      end;
    end;
  end
  else
  begin
    for oy := 0 to LOutputH - 1 do
    begin
      iy := oy * aStrideH;
      for ox := 0 to LOutputW - 1 do
      begin
        ix := ox * aStrideW;
        LMax := aInput[iy * aInputW + ix];
        for ky := 0 to aKernelH - 1 do
          for kx := 0 to aKernelW - 1 do
          begin
            LRowMax := aInput[(iy + ky) * aInputW + (ix + kx)];
            if LRowMax > LMax then LMax := LRowMax;
          end;
        aOutput[oy * LOutputW + ox] := LMax;
      end;
    end;
  end;
end;

procedure AvgPool2DF32(aInput, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aStrideH, aStrideW: SizeUInt);
var
  oy, ox, ky: SizeUInt;
  LOutputH, LOutputW: SizeUInt;
  iy, ix: SizeUInt;
  LSum: Single;
  LInvK: Single;
begin
  if (aInputH = 0) or (aInputW = 0) or (aKernelH = 0) or (aKernelW = 0) then Exit;
  if (aStrideH = 0) or (aStrideW = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := (aInputH - aKernelH) div aStrideH + 1;
  LOutputW := (aInputW - aKernelW) div aStrideW + 1;
  LInvK := 1.0 / (aKernelH * aKernelW);
  for oy := 0 to LOutputH - 1 do
  begin
    iy := oy * aStrideH;
    for ox := 0 to LOutputW - 1 do
    begin
      ix := ox * aStrideW;
      LSum := 0;
      for ky := 0 to aKernelH - 1 do
        LSum := LSum + ReduceSumF32(@aInput[(iy + ky) * aInputW + ix], aKernelW);
      aOutput[oy * LOutputW + ox] := LSum * LInvK;
    end;
  end;
end;

procedure Conv2DBiasF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
var
  f, oy, ox, ky: SizeUInt;
  LOutputH, LOutputW, LKernelSize: SizeUInt;
  LSum: Single;
  LInputRow, LKernelRow: PSingle;
begin
  if (aInputH = 0) or (aInputW = 0) or (aKernelH = 0) or (aKernelW = 0) then Exit;
  if (aNumFilters = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := aInputH - aKernelH + 1;
  LOutputW := aInputW - aKernelW + 1;
  LKernelSize := aKernelH * aKernelW;
  for f := 0 to aNumFilters - 1 do
  begin
    for oy := 0 to LOutputH - 1 do
      for ox := 0 to LOutputW - 1 do
      begin
        LSum := 0;
        for ky := 0 to aKernelH - 1 do
        begin
          LInputRow := @aInput[(oy + ky) * aInputW + ox];
          LKernelRow := @aKernel[f * LKernelSize + ky * aKernelW];
          LSum := LSum + ReduceDotF32(LInputRow, LKernelRow, aKernelW);
        end;
        if aBias <> nil then
          LSum := LSum + aBias[f];
        aOutput[f * LOutputH * LOutputW + oy * LOutputW + ox] := LSum;
      end;
  end;
end;

procedure Conv2DBiasReLUF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
var
  LOutputH, LOutputW, LTotal: SizeUInt;
begin
  Conv2DBiasF32(aInput, aKernel, aBias, aOutput,
    aInputH, aInputW, aKernelH, aKernelW, aNumFilters);
  if (aInputH < aKernelH) or (aInputW < aKernelW) then Exit;
  LOutputH := aInputH - aKernelH + 1;
  LOutputW := aInputW - aKernelW + 1;
  LTotal := aNumFilters * LOutputH * LOutputW;
  if LTotal > 0 then
    ArrayReLUF32(aOutput, aOutput, LTotal);
end;

// === GEMM 6×16 微内核 (AVX2 FMA) ===
// C[6,16] += A[6,K] × B_packed[K,16]
// RDI=A, RSI=B_packed, RDX=C, RCX=K, R8=A_stride(bytes), R9=C_stride(bytes)
procedure GemmMicro6x16(aA, aB, aC: PSingle; aK, aAStride, aCStride: SizeUInt); assembler; nostackframe;
asm
  // 清零 12 个累加器
  vxorps ymm0, ymm0, ymm0
  vxorps ymm1, ymm1, ymm1
  vxorps ymm2, ymm2, ymm2
  vxorps ymm3, ymm3, ymm3
  vxorps ymm4, ymm4, ymm4
  vxorps ymm5, ymm5, ymm5
  vxorps ymm6, ymm6, ymm6
  vxorps ymm7, ymm7, ymm7
  vxorps ymm8, ymm8, ymm8
  vxorps ymm9, ymm9, ymm9
  vxorps ymm10, ymm10, ymm10
  vxorps ymm11, ymm11, ymm11

  // 计算 A 行指针: row0=RDI, row1=RDI+R8, row2=RDI+2*R8, ...
  mov rax, rdi          // A_row0
  lea r10, [rdi + r8]   // A_row1
  lea r11, [r10 + r8]   // A_row2
  push rbx
  lea rbx, [r11 + r8]   // A_row3
  push r12
  lea r12, [rbx + r8]   // A_row4
  push r13
  lea r13, [r12 + r8]   // A_row5

  xor r14d, r14d        // k = 0 (但 r14 是 callee-saved)
  push r14
  push r15

  // K 循环
  test rcx, rcx
  jz @store

@k_loop:
  // 加载 B_packed[k, 0..15]
  vmovups ymm12, [rsi]
  vmovups ymm13, [rsi + 32]

  // Row 0
  vbroadcastss ymm14, dword [rax]
  vfmadd231ps ymm0, ymm14, ymm12
  vfmadd231ps ymm1, ymm14, ymm13
  // Row 1
  vbroadcastss ymm14, dword [r10]
  vfmadd231ps ymm2, ymm14, ymm12
  vfmadd231ps ymm3, ymm14, ymm13
  // Row 2
  vbroadcastss ymm14, dword [r11]
  vfmadd231ps ymm4, ymm14, ymm12
  vfmadd231ps ymm5, ymm14, ymm13
  // Row 3
  vbroadcastss ymm14, dword [rbx]
  vfmadd231ps ymm6, ymm14, ymm12
  vfmadd231ps ymm7, ymm14, ymm13
  // Row 4
  vbroadcastss ymm14, dword [r12]
  vfmadd231ps ymm8, ymm14, ymm12
  vfmadd231ps ymm9, ymm14, ymm13
  // Row 5
  vbroadcastss ymm14, dword [r13]
  vfmadd231ps ymm10, ymm14, ymm12
  vfmadd231ps ymm11, ymm14, ymm13

  // 前进 k
  add rax, 4
  add r10, 4
  add r11, 4
  add rbx, 4
  add r12, 4
  add r13, 4
  add rsi, 64           // B_packed stride = 16 * 4

  dec rcx
  jnz @k_loop

@store:
  // 存储 C[6, 16]
  vmovups [rdx], ymm0
  vmovups [rdx + 32], ymm1
  add rdx, r9
  vmovups [rdx], ymm2
  vmovups [rdx + 32], ymm3
  add rdx, r9
  vmovups [rdx], ymm4
  vmovups [rdx + 32], ymm5
  add rdx, r9
  vmovups [rdx], ymm6
  vmovups [rdx + 32], ymm7
  add rdx, r9
  vmovups [rdx], ymm8
  vmovups [rdx + 32], ymm9
  add rdx, r9
  vmovups [rdx], ymm10
  vmovups [rdx + 32], ymm11

  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  vzeroupper
end;

procedure GemmTiled6x16F32(aA, aB, aC: PSingle; aM, aN, aK: SizeUInt);
const
  MR = 6;
  NR = 16;
var
  LBPacked: PSingle;
  m, n, k, col: SizeUInt;
  LAStride, LCStride: SizeUInt;
begin
  LAStride := aK * SizeOf(Single);
  LCStride := aN * SizeOf(Single);
  LBPacked := PSingle(SimdAlloc(aK * NR * SizeOf(Single)));

  n := 0;
  while n + NR <= aN do
  begin
    // Pack B panel: Im2col[n..n+15, 0..K-1] → B_packed[K, 16]
    for k := 0 to aK - 1 do
      for col := 0 to NR - 1 do
        LBPacked[k * NR + col] := aB[(n + col) * aK + k];

    // Process MR rows at a time
    m := 0;
    while m + MR <= aM do
    begin
      GemmMicro6x16(@aA[m * aK], LBPacked, @aC[m * aN + n], aK, LAStride, LCStride);
      Inc(m, MR);
    end;
    // M remainder
    while m < aM do
    begin
      for col := 0 to NR - 1 do
        aC[m * aN + n + col] := ReduceDotF32(@aA[m * aK], @aB[(n + col) * aK], aK);
      Inc(m);
    end;

    Inc(n, NR);
  end;

  // N remainder
  while n < aN do
  begin
    for m := 0 to aM - 1 do
      aC[m * aN + n] := ReduceDotF32(@aA[m * aK], @aB[n * aK], aK);
    Inc(n);
  end;

  SimdFree(LBPacked);
end;

procedure Conv2DMultiChannelF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
var
  f, c, oy, ox, ky, hw: SizeUInt;
  LOutputH, LOutputW, LKernelSize, LChannelSize, LK, LHW: SizeUInt;
  LSum: Single;
  LInputRow, LKernelRow: PSingle;
  LIm2col: PSingle;
begin
  if (aInputC = 0) or (aInputH = 0) or (aInputW = 0) then Exit;
  if (aKernelH = 0) or (aKernelW = 0) or (aNumFilters = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := aInputH - aKernelH + 1;
  LOutputW := aInputW - aKernelW + 1;
  LKernelSize := aKernelH * aKernelW;
  LChannelSize := aInputH * aInputW;
  LK := aInputC * LKernelSize;
  LHW := LOutputH * LOutputW;

  if LK >= 16 then
  begin
    LIm2col := PSingle(SimdAlloc(LHW * LK * SizeOf(Single)));
    hw := 0;
    for oy := 0 to LOutputH - 1 do
      for ox := 0 to LOutputW - 1 do
      begin
        for c := 0 to aInputC - 1 do
          for ky := 0 to aKernelH - 1 do
            Move(aInput[c * LChannelSize + (oy + ky) * aInputW + ox],
                 LIm2col[hw * LK + c * LKernelSize + ky * aKernelW],
                 aKernelW * SizeOf(Single));
        Inc(hw);
      end;

    // GEMM: Output[F, HW] = Kernel[F, K] × Im2col[HW, K]^T
    GemmTiled6x16F32(aKernel, LIm2col, aOutput, aNumFilters, LHW, LK);
    if aBias <> nil then
      for f := 0 to aNumFilters - 1 do
        ArrayAddScalarF32(@aOutput[f * LHW], @aOutput[f * LHW], LHW, aBias[f]);

    SimdFree(LIm2col);
  end
  else
  begin
    for f := 0 to aNumFilters - 1 do
      for oy := 0 to LOutputH - 1 do
        for ox := 0 to LOutputW - 1 do
        begin
          LSum := 0;
          for c := 0 to aInputC - 1 do
            for ky := 0 to aKernelH - 1 do
            begin
              LInputRow := @aInput[c * LChannelSize + (oy + ky) * aInputW + ox];
              LKernelRow := @aKernel[f * aInputC * LKernelSize + c * LKernelSize + ky * aKernelW];
              LSum := LSum + ReduceDotF32(LInputRow, LKernelRow, aKernelW);
            end;
          if aBias <> nil then
            LSum := LSum + aBias[f];
          aOutput[f * LHW + oy * LOutputW + ox] := LSum;
        end;
  end;
end;

procedure GlobalAvgPool2DF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
var
  c: SizeUInt;
  LSpatialSize: SizeUInt;
  LInvSize: Single;
begin
  if (aChannels = 0) or (aHeight = 0) or (aWidth = 0) then Exit;
  LSpatialSize := aHeight * aWidth;
  LInvSize := 1.0 / LSpatialSize;
  for c := 0 to aChannels - 1 do
    aOutput[c] := ReduceSumF32(@aInput[c * LSpatialSize], LSpatialSize) * LInvSize;
end;

procedure BatchNorm2DInferF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt;
  aGamma, aBeta, aMean, aVar: PSingle; aEpsilon: Single);
var
  c: SizeUInt;
  LSpatialSize: SizeUInt;
  LScale, LBias: Single;
begin
  if (aChannels = 0) or (aHeight = 0) or (aWidth = 0) then Exit;
  LSpatialSize := aHeight * aWidth;
  for c := 0 to aChannels - 1 do
  begin
    LScale := aGamma[c] / System.Sqrt(aVar[c] + aEpsilon);
    LBias := aBeta[c] - aMean[c] * LScale;
    ArrayLinearF32(@aInput[c * LSpatialSize], @aOutput[c * LSpatialSize],
      LSpatialSize, LScale, LBias);
  end;
end;

procedure DepthwiseConv2DF32(aInput, aKernel, aBias, aOutput: PSingle;
  aChannels, aInputH, aInputW, aKernelH, aKernelW: SizeUInt);
var
  c, oy, ox, ky, kx: SizeUInt;
  LOutputH, LOutputW, LKernelSize, LSpatialIn, LSpatialOut: SizeUInt;
  LSum: Single;
  LOutRow, LInRow: PSingle;
  LWeight: Single;
begin
  if (aChannels = 0) or (aInputH = 0) or (aInputW = 0) then Exit;
  if (aKernelH = 0) or (aKernelW = 0) then Exit;
  if (aKernelH > aInputH) or (aKernelW > aInputW) then Exit;
  LOutputH := aInputH - aKernelH + 1;
  LOutputW := aInputW - aKernelW + 1;
  LKernelSize := aKernelH * aKernelW;
  LSpatialIn := aInputH * aInputW;
  LSpatialOut := LOutputH * LOutputW;

  if LOutputW >= 8 then
  begin
    for c := 0 to aChannels - 1 do
      for oy := 0 to LOutputH - 1 do
      begin
        LOutRow := @aOutput[c * LSpatialOut + oy * LOutputW];
        FillChar(LOutRow^, LOutputW * SizeOf(Single), 0);
        for ky := 0 to aKernelH - 1 do
          for kx := 0 to aKernelW - 1 do
          begin
            LWeight := aKernel[c * LKernelSize + ky * aKernelW + kx];
            LInRow := @aInput[c * LSpatialIn + (oy + ky) * aInputW + kx];
            ArrayAxpyF32(LWeight, LInRow, LOutRow, LOutRow, LOutputW);
          end;
        if aBias <> nil then
          ArrayAddScalarF32(LOutRow, LOutRow, LOutputW, aBias[c]);
      end;
  end
  else
  begin
    for c := 0 to aChannels - 1 do
      for oy := 0 to LOutputH - 1 do
        for ox := 0 to LOutputW - 1 do
        begin
          LSum := 0;
          for ky := 0 to aKernelH - 1 do
            LSum := LSum + ReduceDotF32(
              @aInput[c * LSpatialIn + (oy + ky) * aInputW + ox],
              @aKernel[c * LKernelSize + ky * aKernelW],
              aKernelW);
          if aBias <> nil then
            LSum := LSum + aBias[c];
          aOutput[c * LSpatialOut + oy * LOutputW + ox] := LSum;
        end;
  end;
end;

procedure Conv2DSameF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters: SizeUInt);
var
  LPadH, LPadW, LPaddedH, LPaddedW: SizeUInt;
  LPadded: PSingle;
  c, y, x: SizeUInt;
  LPaddedChannelSize, LInputChannelSize: SizeUInt;
begin
  if (aInputC = 0) or (aInputH = 0) or (aInputW = 0) then Exit;
  if (aKernelH = 0) or (aKernelW = 0) or (aNumFilters = 0) then Exit;
  LPadH := (aKernelH - 1) div 2;
  LPadW := (aKernelW - 1) div 2;
  LPaddedH := aInputH + aKernelH - 1;
  LPaddedW := aInputW + aKernelW - 1;
  LPaddedChannelSize := LPaddedH * LPaddedW;
  LInputChannelSize := aInputH * aInputW;

  LPadded := PSingle(SimdAlloc(aInputC * LPaddedChannelSize * SizeOf(Single)));
  FillChar(LPadded^, aInputC * LPaddedChannelSize * SizeOf(Single), 0);

  for c := 0 to aInputC - 1 do
    for y := 0 to aInputH - 1 do
      Move(aInput[c * LInputChannelSize + y * aInputW],
           LPadded[c * LPaddedChannelSize + (y + LPadH) * LPaddedW + LPadW],
           aInputW * SizeOf(Single));

  Conv2DMultiChannelF32(LPadded, aKernel, aBias, aOutput,
    aInputC, LPaddedH, LPaddedW, aKernelH, aKernelW, aNumFilters);

  SimdFree(LPadded);
end;

procedure UpsampleNearest2DF32(aInput, aOutput: PSingle;
  aChannels, aInputH, aInputW, aScaleH, aScaleW: SizeUInt);
var
  c, oy, ox: SizeUInt;
  LOutputW, LOutputH, LInputPlane, LOutputPlane: SizeUInt;
  LSrcRow, LDstRow: PSingle;
  sy: SizeUInt;
begin
  if (aChannels = 0) or (aInputH = 0) or (aInputW = 0) then Exit;
  if (aScaleH = 0) or (aScaleW = 0) then Exit;
  LOutputH := aInputH * aScaleH;
  LOutputW := aInputW * aScaleW;
  LInputPlane := aInputH * aInputW;
  LOutputPlane := LOutputH * LOutputW;

  for c := 0 to aChannels - 1 do
    for oy := 0 to LOutputH - 1 do
    begin
      sy := oy div aScaleH;
      LSrcRow := @aInput[c * LInputPlane + sy * aInputW];
      LDstRow := @aOutput[c * LOutputPlane + oy * LOutputW];
      if aScaleW = 1 then
        Move(LSrcRow^, LDstRow^, aInputW * SizeOf(Single))
      else
        for ox := 0 to LOutputW - 1 do
          LDstRow[ox] := LSrcRow[ox div aScaleW];
    end;
end;

procedure ChannelConcatF32(aA, aB, aOutput: PSingle;
  aChannelsA, aChannelsB, aHeight, aWidth: SizeUInt);
var
  LPlaneSize, LSizeA, LSizeB: SizeUInt;
begin
  if (aHeight = 0) or (aWidth = 0) then Exit;
  LPlaneSize := aHeight * aWidth;
  LSizeA := aChannelsA * LPlaneSize * SizeOf(Single);
  LSizeB := aChannelsB * LPlaneSize * SizeOf(Single);
  Move(aA^, aOutput^, LSizeA);
  Move(aB^, aOutput[aChannelsA * LPlaneSize], LSizeB);
end;

procedure ResidualAddF32(aInput, aResidual, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
var
  LTotal: SizeUInt;
begin
  LTotal := aChannels * aHeight * aWidth;
  if LTotal = 0 then Exit;
  ArrayAddF32(aInput, aResidual, aOutput, LTotal);
end;

procedure UpsampleBilinear2DF32(aInput, aOutput: PSingle;
  aChannels, aInputH, aInputW, aOutputH, aOutputW: SizeUInt);
var
  c, oy, ox: SizeUInt;
  LInPlane, LOutPlane: SizeUInt;
  LSrcY, LSrcX: Single;
  LY0, LY1, LX0, LX1: SizeUInt;
  LWY, LWX: Single;
  LV00, LV01, LV10, LV11: Single;
  LBase: PSingle;
begin
  if (aChannels = 0) or (aInputH = 0) or (aInputW = 0) then Exit;
  if (aOutputH = 0) or (aOutputW = 0) then Exit;
  LInPlane := aInputH * aInputW;
  LOutPlane := aOutputH * aOutputW;

  for c := 0 to aChannels - 1 do
  begin
    LBase := @aInput[c * LInPlane];
    for oy := 0 to aOutputH - 1 do
    begin
      if aOutputH > 1 then
        LSrcY := oy * (aInputH - 1) / (aOutputH - 1)
      else
        LSrcY := 0;
      LY0 := Trunc(LSrcY);
      LY1 := LY0 + 1;
      if LY1 >= aInputH then LY1 := aInputH - 1;
      LWY := LSrcY - LY0;

      for ox := 0 to aOutputW - 1 do
      begin
        if aOutputW > 1 then
          LSrcX := ox * (aInputW - 1) / (aOutputW - 1)
        else
          LSrcX := 0;
        LX0 := Trunc(LSrcX);
        LX1 := LX0 + 1;
        if LX1 >= aInputW then LX1 := aInputW - 1;
        LWX := LSrcX - LX0;

        LV00 := LBase[LY0 * aInputW + LX0];
        LV01 := LBase[LY0 * aInputW + LX1];
        LV10 := LBase[LY1 * aInputW + LX0];
        LV11 := LBase[LY1 * aInputW + LX1];

        aOutput[c * LOutPlane + oy * aOutputW + ox] :=
          (1 - LWY) * ((1 - LWX) * LV00 + LWX * LV01) +
          LWY * ((1 - LWX) * LV10 + LWX * LV11);
      end;
    end;
  end;
end;

procedure TransposeConv2DF32(aInput, aKernel, aBias, aOutput: PSingle;
  aInputC, aInputH, aInputW, aKernelH, aKernelW, aNumFilters, aStride: SizeUInt);
var
  f, c, iy, ix, ky, kx: SizeUInt;
  LOutputH, LOutputW, LOutPlane, LInPlane, LKernelPlane: SizeUInt;
  LVal: Single;
  LOy, LOx: SizeUInt;
begin
  if (aInputC = 0) or (aInputH = 0) or (aInputW = 0) then Exit;
  if (aKernelH = 0) or (aKernelW = 0) or (aNumFilters = 0) then Exit;
  if aStride = 0 then Exit;

  LOutputH := (aInputH - 1) * aStride + aKernelH;
  LOutputW := (aInputW - 1) * aStride + aKernelW;
  LOutPlane := LOutputH * LOutputW;
  LInPlane := aInputH * aInputW;
  LKernelPlane := aKernelH * aKernelW;

  FillChar(aOutput^, aNumFilters * LOutPlane * SizeOf(Single), 0);

  for f := 0 to aNumFilters - 1 do
  begin
    for c := 0 to aInputC - 1 do
      for iy := 0 to aInputH - 1 do
        for ix := 0 to aInputW - 1 do
        begin
          LVal := aInput[c * LInPlane + iy * aInputW + ix];
          for ky := 0 to aKernelH - 1 do
          begin
            LOy := iy * aStride + ky;
            for kx := 0 to aKernelW - 1 do
            begin
              LOx := ix * aStride + kx;
              aOutput[f * LOutPlane + LOy * LOutputW + LOx] :=
                aOutput[f * LOutPlane + LOy * LOutputW + LOx] +
                LVal * aKernel[f * aInputC * LKernelPlane + c * LKernelPlane + ky * aKernelW + kx];
            end;
          end;
        end;
    if aBias <> nil then
      ArrayAddScalarF32(@aOutput[f * LOutPlane], @aOutput[f * LOutPlane], LOutPlane, aBias[f]);
  end;
end;

procedure ChannelArgMaxF32(aInput: PSingle; aOutput: PInt32;
  aChannels, aHeight, aWidth: SizeUInt);
var
  LPlane, pos, c: SizeUInt;
  LBestIdx: Int32;
  LBestVal, LVal: Single;
begin
  if (aChannels = 0) or (aHeight = 0) or (aWidth = 0) then Exit;
  LPlane := aHeight * aWidth;
  for pos := 0 to LPlane - 1 do
  begin
    LBestVal := aInput[pos];
    LBestIdx := 0;
    for c := 1 to aChannels - 1 do
    begin
      LVal := aInput[c * LPlane + pos];
      if LVal > LBestVal then
      begin
        LBestVal := LVal;
        LBestIdx := Int32(c);
      end;
    end;
    aOutput[pos] := LBestIdx;
  end;
end;

procedure ChannelSoftmaxF32(aInput, aOutput: PSingle;
  aChannels, aHeight, aWidth: SizeUInt);
var
  LPlane, c: SizeUInt;
  LMaxPlane, LSumPlane: PSingle;
begin
  if (aChannels = 0) or (aHeight = 0) or (aWidth = 0) then Exit;
  LPlane := aHeight * aWidth;

  LMaxPlane := PSingle(SimdAlloc(LPlane * SizeOf(Single)));
  LSumPlane := PSingle(SimdAlloc(LPlane * SizeOf(Single)));

  Move(aInput^, LMaxPlane^, LPlane * SizeOf(Single));
  for c := 1 to aChannels - 1 do
    ArrayMaxF32(@aInput[c * LPlane], LMaxPlane, LMaxPlane, LPlane);

  FillChar(LSumPlane^, LPlane * SizeOf(Single), 0);
  for c := 0 to aChannels - 1 do
  begin
    ArraySubF32(@aInput[c * LPlane], LMaxPlane, @aOutput[c * LPlane], LPlane);
    ArrayExpF32(@aOutput[c * LPlane], @aOutput[c * LPlane], LPlane);
    ArrayAddF32(@aOutput[c * LPlane], LSumPlane, LSumPlane, LPlane);
  end;

  for c := 0 to aChannels - 1 do
    ArrayDivF32(@aOutput[c * LPlane], LSumPlane, @aOutput[c * LPlane], LPlane);

  SimdFree(LMaxPlane);
  SimdFree(LSumPlane);
end;

end.
