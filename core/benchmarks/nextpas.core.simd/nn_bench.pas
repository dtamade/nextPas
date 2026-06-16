program nn_bench;

{$mode objfpc}{$H+}
{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.base,
  nextpas.core.simd.runtime,
  nextpas.core.simd.nn;

const
  WARMUP = 3;
  ITERS = 10;
  REPS = 5;

function GetTimeMs: Int64;
begin
  Result := GetTickCount64;
end;

function MedianOf(const aTimes: array of Int64; aCount: Integer): Double;
var
  i, j: Integer;
  LTmp: Int64;
  LSorted: array[0..31] of Int64;
begin
  for i := 0 to aCount - 1 do LSorted[i] := aTimes[i];
  for i := 0 to aCount - 2 do
    for j := i + 1 to aCount - 1 do
      if LSorted[j] < LSorted[i] then
      begin LTmp := LSorted[i]; LSorted[i] := LSorted[j]; LSorted[j] := LTmp; end;
  Result := LSorted[aCount div 2];
end;

type
  TBenchResult = record
    Name: string;
    MedianMs: Double;
    ThroughputMB: Double;
  end;

var
  GResults: array[0..31] of TBenchResult;
  GCount: Integer = 0;

procedure Report(const aName: string; aMedianMs: Double; aBytes: SizeUInt);
begin
  if GCount > High(GResults) then Exit;
  GResults[GCount].Name := aName;
  GResults[GCount].MedianMs := aMedianMs;
  if aMedianMs > 0 then
    GResults[GCount].ThroughputMB := (aBytes / (1024*1024)) / (aMedianMs / 1000)
  else
    GResults[GCount].ThroughputMB := 0;
  Inc(GCount);
end;

var
  LInput, LKernel, LBias, LOutput, LGamma, LBeta, LMean, LVar: PSingle;
  LArgOut: PInt32;

procedure BenchConv2D;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP - 1 do
    Conv2DMultiChannelF32(LInput, LKernel, LBias, LOutput, 64, 56, 56, 3, 3, 64);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do
      Conv2DMultiChannelF32(LInput, LKernel, LBias, LOutput, 64, 56, 56, 3, 3, 64);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('Conv2D 64ch 56x56 k3', MedianOf(LTimes, ITERS) / REPS,
    64 * 56 * 56 * SizeOf(Single));
end;

procedure BenchDepthwiseConv2D;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP - 1 do
    DepthwiseConv2DF32(LInput, LKernel, LBias, LOutput, 128, 28, 28, 3, 3);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do
      DepthwiseConv2DF32(LInput, LKernel, LBias, LOutput, 128, 28, 28, 3, 3);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('DepthwiseConv2D 128ch 28x28 k3', MedianOf(LTimes, ITERS) / REPS,
    128 * 28 * 28 * SizeOf(Single));
end;

procedure BenchMaxPool2D;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
    c: SizeUInt;
begin
  for i := 0 to WARMUP - 1 do
    for c := 0 to 63 do
      MaxPool2DF32(@LInput[c * 56 * 56], @LOutput[c * 28 * 28], 56, 56, 2, 2, 2, 2);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do
      for c := 0 to 63 do
        MaxPool2DF32(@LInput[c * 56 * 56], @LOutput[c * 28 * 28], 56, 56, 2, 2, 2, 2);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('MaxPool2D 64ch 56x56 k2s2', MedianOf(LTimes, ITERS) / REPS,
    64 * 56 * 56 * SizeOf(Single));
end;

procedure BenchBatchNorm2D;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP - 1 do
    BatchNorm2DInferF32(LInput, LOutput, 64, 56, 56, LGamma, LBeta, LMean, LVar, 1e-5);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do
      BatchNorm2DInferF32(LInput, LOutput, 64, 56, 56, LGamma, LBeta, LMean, LVar, 1e-5);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('BatchNorm2D 64ch 56x56', MedianOf(LTimes, ITERS) / REPS,
    64 * 56 * 56 * SizeOf(Single));
end;

procedure BenchSigmoid;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
const N = 256 * 56 * 56;
begin
  for i := 0 to WARMUP - 1 do SigmoidF32(LInput, LOutput, N);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do SigmoidF32(LInput, LOutput, N);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('Sigmoid 802816 elem', MedianOf(LTimes, ITERS) / REPS, N * SizeOf(Single));
end;

procedure BenchUpsampleNearest;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP - 1 do
    UpsampleNearest2DF32(LInput, LOutput, 64, 28, 28, 2, 2);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do
      UpsampleNearest2DF32(LInput, LOutput, 64, 28, 28, 2, 2);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('UpsampleNearest 64ch 28→56', MedianOf(LTimes, ITERS) / REPS,
    64 * 56 * 56 * SizeOf(Single));
end;

procedure BenchChannelSoftmax;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
begin
  for i := 0 to WARMUP - 1 do
    ChannelSoftmaxF32(LInput, LOutput, 21, 56, 56);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do
      ChannelSoftmaxF32(LInput, LOutput, 21, 56, 56);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('ChannelSoftmax 21ch 56x56', MedianOf(LTimes, ITERS) / REPS,
    21 * 56 * 56 * SizeOf(Single));
end;

procedure BenchResidualAdd;
var i, r: Integer; t0: Int64; LTimes: array[0..31] of Int64;
const N = 64 * 56 * 56;
begin
  for i := 0 to WARMUP - 1 do ResidualAddF32(LInput, LInput, LOutput, 64, 56, 56);
  for i := 0 to ITERS - 1 do
  begin
    t0 := GetTimeMs;
    for r := 0 to REPS - 1 do ResidualAddF32(LInput, LInput, LOutput, 64, 56, 56);
    LTimes[i] := GetTimeMs - t0;
  end;
  Report('ResidualAdd 64ch 56x56', MedianOf(LTimes, ITERS) / REPS, N * SizeOf(Single));
end;

var
  i: Integer;
  LAllocSize: SizeUInt;
  b: Integer;
  LBackends: array[0..2] of TSimdBackend;
  LNames: array[0..2] of string;
  LTimes: array[0..2, 0..7] of Double;
begin
  LBackends[0] := sbScalar; LBackends[1] := sbSSE2; LBackends[2] := sbAVX2;
  LNames[0] := 'Scalar'; LNames[1] := 'SSE2'; LNames[2] := 'AVX2';

  WriteLn('=== nextpas.core.simd.nn Multi-Backend Benchmark ===');
  WriteLn;

  LAllocSize := 256 * 56 * 56 * SizeOf(Single);
  LInput := PSingle(SimdAlloc(LAllocSize));
  LOutput := PSingle(SimdAlloc(LAllocSize));
  LKernel := PSingle(SimdAlloc(64 * 64 * 9 * SizeOf(Single)));
  LBias := PSingle(SimdAlloc(256 * SizeOf(Single)));
  LGamma := PSingle(SimdAlloc(256 * SizeOf(Single)));
  LBeta := PSingle(SimdAlloc(256 * SizeOf(Single)));
  LMean := PSingle(SimdAlloc(256 * SizeOf(Single)));
  LVar := PSingle(SimdAlloc(256 * SizeOf(Single)));
  LArgOut := PInt32(SimdAlloc(56 * 56 * SizeOf(Int32)));

  for i := 0 to Integer(LAllocSize div SizeOf(Single)) - 1 do
    LInput[i] := (i mod 1000) * 0.001;
  for i := 0 to 64 * 64 * 9 - 1 do LKernel[i] := 0.01;
  for i := 0 to 255 do
  begin
    LBias[i] := 0;
    LGamma[i] := 1.0;
    LBeta[i] := 0;
    LMean[i] := 0;
    LVar[i] := 1.0;
  end;

  for b := 0 to 2 do
  begin
    if not TrySetCurrentBackend(LBackends[b]) then
    begin
      WriteLn('  [SKIP] ', LNames[b], ' not available');
      for i := 0 to 7 do LTimes[b, i] := -1;
      Continue;
    end;
    WriteLn('--- Backend: ', LNames[b], ' ---');
    GCount := 0;

    BenchConv2D;
    BenchDepthwiseConv2D;
    BenchMaxPool2D;
    BenchBatchNorm2D;
    BenchSigmoid;
    BenchUpsampleNearest;
    BenchChannelSoftmax;
    BenchResidualAdd;

    for i := 0 to GCount - 1 do
      LTimes[b, i] := GResults[i].MedianMs;

    for i := 0 to GCount - 1 do
      WriteLn(Format('  %-33s %8.2f ms', [GResults[i].Name, GResults[i].MedianMs]));
    WriteLn;
  end;

  ResetCurrentBackendSelection;

  WriteLn('=== Cross-Backend Comparison ===');
  WriteLn(Format('%-30s %10s %10s %10s %10s', ['Operation', 'Scalar', 'SSE2', 'AVX2', 'Speedup']));
  WriteLn(StringOfChar('-', 72));
  for i := 0 to 7 do
  begin
    if (LTimes[0, i] > 0) and (LTimes[2, i] > 0) then
      WriteLn(Format('%-30s %8.2fms %8.2fms %8.2fms %8.1fx', [
        GResults[i].Name, LTimes[0, i], LTimes[1, i], LTimes[2, i],
        LTimes[0, i] / LTimes[2, i]]))
    else if LTimes[2, i] >= 0 then
      WriteLn(Format('%-30s %8.2fms %8.2fms %8.2fms       -', [
        GResults[i].Name, LTimes[0, i], LTimes[1, i], LTimes[2, i]]));
  end;

  SimdFree(LInput);
  SimdFree(LOutput);
  SimdFree(LKernel);
  SimdFree(LBias);
  SimdFree(LGamma);
  SimdFree(LBeta);
  SimdFree(LMean);
  SimdFree(LVar);
  SimdFree(LArgOut);
end.
