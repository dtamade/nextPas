unit nextpas.core.simd.stats;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

function WeightedSumF32(aValues, aWeights: PSingle; aCount: SizeUInt): Single;
function WeightedMeanF32(aValues, aWeights: PSingle; aCount: SizeUInt): Single;
function CovarianceF32(aX, aY: PSingle; aCount: SizeUInt; aSample: Boolean = True): Single;
function CorrelationF32(aX, aY: PSingle; aCount: SizeUInt): Single;
function VarianceF32(aX: PSingle; aCount: SizeUInt; aSample: Boolean = True): Single;
function StdDevF32(aX: PSingle; aCount: SizeUInt; aSample: Boolean = True): Single;

type
  TSimdF32OnlineStats = record
  private
    FCount: UInt64;
    FMean: Double;
    FM2: Double;
  public
    procedure Clear;
    procedure Add(aValue: Single);
    procedure AddBatch(aValues: PSingle; aCount: SizeUInt);
    procedure Merge(const aOther: TSimdF32OnlineStats);
    function GetMean: Double;
    function GetVariance: Double;
    function GetStdDev: Double;
    property Count: UInt64 read FCount;
  end;


function PercentileF32(aX: PSingle; aCount: SizeUInt; aP: Single): Single;
function MedianF32(aX: PSingle; aCount: SizeUInt): Single;
procedure HistogramF32(aX: PSingle; aCount: SizeUInt; aBins: PSingle; aCounts: PInt32; aBinCount: SizeUInt; aMin, aMax: Single);
function MovingAverageF32(aSrc, aDst: PSingle; aCount: SizeUInt; aWindowSize: SizeUInt): Boolean;
function ExponentialMovingAverageF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single): Boolean;
function MinMaxNormalizeF32(aSrc, aDst: PSingle; aCount: SizeUInt): Boolean;
function ZScoreNormalizeF32(aSrc, aDst: PSingle; aCount: SizeUInt): Boolean;
function CosineSimilarityF32(aX, aY: PSingle; aCount: SizeUInt): Single;

// === F64 Statistics ===
function VarianceF64(aX: PDouble; aCount: SizeUInt; aSample: Boolean = True): Double;
function StdDevF64(aX: PDouble; aCount: SizeUInt; aSample: Boolean = True): Double;
function CovarianceF64(aX, aY: PDouble; aCount: SizeUInt; aSample: Boolean = True): Double;
function CorrelationF64(aX, aY: PDouble; aCount: SizeUInt): Double;
function CosineSimilarityF64(aX, aY: PDouble; aCount: SizeUInt): Double;
function WeightedSumF64(aValues, aWeights: PDouble; aCount: SizeUInt): Double;
function WeightedMeanF64(aValues, aWeights: PDouble; aCount: SizeUInt): Double;
function MinMaxNormalizeF64(aSrc, aDst: PDouble; aCount: SizeUInt): Boolean;
function ZScoreNormalizeF64(aSrc, aDst: PDouble; aCount: SizeUInt): Boolean;

implementation

uses
  Math,
  nextpas.core.simd;

function WeightedSumF32(aValues, aWeights: PSingle; aCount: SizeUInt): Single;
begin
  Result := ReduceDotF32(aValues, aWeights, aCount);
end;

function WeightedMeanF32(aValues, aWeights: PSingle; aCount: SizeUInt): Single;
var LWeightSum: Single;
begin
  if aCount = 0 then Exit(0);
  LWeightSum := ReduceSumF32(aWeights, aCount);
  if LWeightSum = 0 then Exit(0);
  Result := ReduceDotF32(aValues, aWeights, aCount) / LWeightSum;
end;

function CovarianceF32(aX, aY: PSingle; aCount: SizeUInt; aSample: Boolean): Single;
var
  LMeanX, LMeanY, LDotXY: Single;
  LDiv: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LMeanX := ReduceSumF32(aX, aCount) / aCount;
  LMeanY := ReduceSumF32(aY, aCount) / aCount;
  LDotXY := ReduceDotF32(aX, aY, aCount);
  if aSample then LDiv := aCount - 1 else LDiv := aCount;
  Result := (LDotXY - aCount * LMeanX * LMeanY) / LDiv;
end;

function VarianceF32(aX: PSingle; aCount: SizeUInt; aSample: Boolean): Single;
var
  LMean, LDotXX: Single;
  LDiv: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LMean := ReduceSumF32(aX, aCount) / aCount;
  LDotXX := ReduceDotF32(aX, aX, aCount);
  if aSample then LDiv := aCount - 1 else LDiv := aCount;
  Result := (LDotXX - aCount * LMean * LMean) / LDiv;
  if Result < 0 then Result := 0;
end;

function StdDevF32(aX: PSingle; aCount: SizeUInt; aSample: Boolean): Single;
begin
  Result := System.Sqrt(VarianceF32(aX, aCount, aSample));
end;

function CorrelationF32(aX, aY: PSingle; aCount: SizeUInt): Single;
var
  LMeanX, LMeanY, LVarX, LVarY, LCov: Single;
  LDotXX, LDotYY, LDotXY: Single;
  LDiv: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LDiv := aCount - 1;
  LMeanX := ReduceSumF32(aX, aCount) / aCount;
  LMeanY := ReduceSumF32(aY, aCount) / aCount;
  LDotXX := ReduceDotF32(aX, aX, aCount);
  LDotYY := ReduceDotF32(aY, aY, aCount);
  LDotXY := ReduceDotF32(aX, aY, aCount);
  LVarX := (LDotXX - aCount * LMeanX * LMeanX) / LDiv;
  LVarY := (LDotYY - aCount * LMeanY * LMeanY) / LDiv;
  if LVarX < 0 then LVarX := 0;
  if LVarY < 0 then LVarY := 0;
  if (LVarX = 0) or (LVarY = 0) then Exit(0);
  LCov := (LDotXY - aCount * LMeanX * LMeanY) / LDiv;
  Result := LCov / (System.Sqrt(LVarX) * System.Sqrt(LVarY));
end;

// Welford's online algorithm
procedure TSimdF32OnlineStats.Clear;
begin
  FCount := 0; FMean := 0; FM2 := 0;
end;

procedure TSimdF32OnlineStats.Add(aValue: Single);
var LDelta, LDelta2: Double;
begin
  Inc(FCount);
  LDelta := aValue - FMean;
  FMean := FMean + LDelta / FCount;
  LDelta2 := aValue - FMean;
  FM2 := FM2 + LDelta * LDelta2;
end;

procedure TSimdF32OnlineStats.AddBatch(aValues: PSingle; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    Add(aValues[i]);
end;

procedure TSimdF32OnlineStats.Merge(const aOther: TSimdF32OnlineStats);
var LTotal: UInt64; LDelta: Double;
begin
  if aOther.FCount = 0 then Exit;
  if FCount = 0 then
  begin
    FCount := aOther.FCount;
    FMean := aOther.FMean;
    FM2 := aOther.FM2;
    Exit;
  end;
  LTotal := FCount + aOther.FCount;
  LDelta := aOther.FMean - FMean;
  FMean := FMean + LDelta * aOther.FCount / LTotal;
  FM2 := FM2 + aOther.FM2 + LDelta * LDelta * FCount * aOther.FCount / LTotal;
  FCount := LTotal;
end;

function TSimdF32OnlineStats.GetMean: Double;
begin
  Result := FMean;
end;

function TSimdF32OnlineStats.GetVariance: Double;
begin
  if FCount <= 1 then Exit(0);
  Result := FM2 / (FCount - 1);
end;

function TSimdF32OnlineStats.GetStdDev: Double;
begin
  Result := System.Sqrt(GetVariance);
end;


function PercentileF32(aX: PSingle; aCount: SizeUInt; aP: Single): Single;

  procedure QuickSort(arr: PSingle; lo, hi: Integer);
  var i, j, k: Integer; pivot, tmp, key: Single;
  begin
    if hi - lo < 16 then
    begin
      for i := lo + 1 to hi do
      begin
        key := arr[i]; k := i - 1;
        while (k >= lo) and (arr[k] > key) do begin arr[k+1] := arr[k]; Dec(k); end;
        arr[k+1] := key;
      end;
      Exit;
    end;
    pivot := arr[(lo + hi) div 2];
    i := lo; j := hi;
    while i <= j do
    begin
      while arr[i] < pivot do Inc(i);
      while arr[j] > pivot do Dec(j);
      if i <= j then
      begin
        tmp := arr[i]; arr[i] := arr[j]; arr[j] := tmp;
        Inc(i); Dec(j);
      end;
    end;
    if lo < j then QuickSort(arr, lo, j);
    if i < hi then QuickSort(arr, i, hi);
  end;

var
  LSorted: PSingle;
  LIdx: Single;
  LLow, LHigh: SizeUInt;
begin
  if aCount = 0 then Exit(0);
  if aCount = 1 then Exit(aX[0]);
  if aP <= 0 then aP := 0;
  if aP >= 100 then aP := 100;
  LSorted := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  Move(aX^, LSorted^, aCount * SizeOf(Single));
  QuickSort(LSorted, 0, Integer(aCount) - 1);
  LIdx := aP / 100.0 * (aCount - 1);
  LLow := Trunc(LIdx);
  LHigh := LLow + 1;
  if LHigh >= aCount then LHigh := aCount - 1;
  Result := LSorted[LLow] + (LIdx - LLow) * (LSorted[LHigh] - LSorted[LLow]);
  SimdFree(LSorted);
end;

function MedianF32(aX: PSingle; aCount: SizeUInt): Single;
begin
  Result := PercentileF32(aX, aCount, 50.0);
end;

procedure HistogramF32(aX: PSingle; aCount: SizeUInt; aBins: PSingle; aCounts: PInt32; aBinCount: SizeUInt; aMin, aMax: Single);
var
  i: SizeUInt;
  LBinWidth, LVal: Single;
  LBinIdx: Integer;
begin
  if (aBinCount = 0) or (aCount = 0) or (aMax <= aMin) then Exit;
  LBinWidth := (aMax - aMin) / aBinCount;
  // Set bin edges
  for i := 0 to aBinCount - 1 do
    aBins[i] := aMin + i * LBinWidth;
  // Clear counts
  FillChar(aCounts^, aBinCount * SizeOf(Int32), 0);
  // Count
  for i := 0 to aCount - 1 do
  begin
    LVal := aX[i];
    if (LVal >= aMin) and (LVal < aMax) then
    begin
      LBinIdx := Trunc((LVal - aMin) / LBinWidth);
      if LBinIdx >= Integer(aBinCount) then LBinIdx := Integer(aBinCount) - 1;
      Inc(aCounts[LBinIdx]);
    end
    else if LVal = aMax then
      Inc(aCounts[aBinCount - 1]);
  end;
end;

function MovingAverageF32(aSrc, aDst: PSingle; aCount: SizeUInt; aWindowSize: SizeUInt): Boolean;
var
  i: SizeUInt;
  LSum: Single;
begin
  if (aCount = 0) or (aWindowSize = 0) then Exit(False);
  LSum := 0;
  for i := 0 to aCount - 1 do
  begin
    LSum := LSum + aSrc[i];
    if i >= aWindowSize then
      LSum := LSum - aSrc[i - aWindowSize];
    if i >= aWindowSize - 1 then
      aDst[i] := LSum / aWindowSize
    else
      aDst[i] := LSum / (i + 1);
  end;
  Result := True;
end;

function ExponentialMovingAverageF32(aSrc, aDst: PSingle; aCount: SizeUInt; aAlpha: Single): Boolean;
var i: SizeUInt;
begin
  if aCount = 0 then Exit(False);
  aDst[0] := aSrc[0];
  for i := 1 to aCount - 1 do
    aDst[i] := aAlpha * aSrc[i] + (1.0 - aAlpha) * aDst[i-1];
  Result := True;
end;

function MinMaxNormalizeF32(aSrc, aDst: PSingle; aCount: SizeUInt): Boolean;
var
  LMin, LMax, LRange: Single;
begin
  if aCount = 0 then Exit(False);
  LMin := ReduceMinF32(aSrc, aCount);
  LMax := ReduceMaxF32(aSrc, aCount);
  LRange := LMax - LMin;
  if LRange = 0 then begin FillChar(aDst^, aCount * SizeOf(Single), 0); Exit(True); end;
  // dst = (src - min) / range = src * (1/range) + (-min/range)
  ArrayLinearF32(aSrc, aDst, aCount, 1.0 / LRange, -LMin / LRange);
  Result := True;
end;

function ZScoreNormalizeF32(aSrc, aDst: PSingle; aCount: SizeUInt): Boolean;
var
  LMean, LVar, LInvStd: Single;
begin
  if aCount <= 1 then Exit(False);
  LMean := ReduceSumF32(aSrc, aCount) / aCount;
  LVar := ReduceDotF32(aSrc, aSrc, aCount) / aCount - LMean * LMean;
  if LVar < 0 then LVar := 0;
  if LVar = 0 then begin FillChar(aDst^, aCount * SizeOf(Single), 0); Exit(True); end;
  LInvStd := 1.0 / System.Sqrt(LVar);
  ArrayNormF32(aSrc, aDst, aCount, LMean, LInvStd);
  Result := True;
end;

function CosineSimilarityF32(aX, aY: PSingle; aCount: SizeUInt): Single;
var LDot, LNormX2, LNormY2, LDenom: Single;
begin
  if aCount = 0 then Exit(0);
  LDot := ReduceDotF32(aX, aY, aCount);
  LNormX2 := ReduceDotF32(aX, aX, aCount);
  LNormY2 := ReduceDotF32(aY, aY, aCount);
  LDenom := System.Sqrt(LNormX2 * LNormY2);
  if LDenom = 0 then Exit(0);
  Result := LDot / LDenom;
end;

// ============================================================================
// F64 Statistics
// ============================================================================

function WeightedSumF64(aValues, aWeights: PDouble; aCount: SizeUInt): Double;
begin
  Result := ReduceDotF64(aValues, aWeights, aCount);
end;

function WeightedMeanF64(aValues, aWeights: PDouble; aCount: SizeUInt): Double;
var LWeightSum: Double;
begin
  if aCount = 0 then Exit(0);
  LWeightSum := ReduceSumF64(aWeights, aCount);
  if LWeightSum = 0 then Exit(0);
  Result := ReduceDotF64(aValues, aWeights, aCount) / LWeightSum;
end;

function VarianceF64(aX: PDouble; aCount: SizeUInt; aSample: Boolean): Double;
var
  LMean, LDotXX: Double;
  LDiv: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LMean := ReduceSumF64(aX, aCount) / aCount;
  LDotXX := ReduceDotF64(aX, aX, aCount);
  if aSample then LDiv := aCount - 1 else LDiv := aCount;
  Result := (LDotXX - aCount * LMean * LMean) / LDiv;
  if Result < 0 then Result := 0;
end;

function StdDevF64(aX: PDouble; aCount: SizeUInt; aSample: Boolean): Double;
begin
  Result := System.Sqrt(VarianceF64(aX, aCount, aSample));
end;

function CovarianceF64(aX, aY: PDouble; aCount: SizeUInt; aSample: Boolean): Double;
var
  LMeanX, LMeanY, LDotXY: Double;
  LDiv: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LMeanX := ReduceSumF64(aX, aCount) / aCount;
  LMeanY := ReduceSumF64(aY, aCount) / aCount;
  LDotXY := ReduceDotF64(aX, aY, aCount);
  if aSample then LDiv := aCount - 1 else LDiv := aCount;
  Result := (LDotXY - aCount * LMeanX * LMeanY) / LDiv;
end;

function CorrelationF64(aX, aY: PDouble; aCount: SizeUInt): Double;
var
  LMeanX, LMeanY, LVarX, LVarY, LCov: Double;
  LDotXX, LDotYY, LDotXY: Double;
  LDiv: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LDiv := aCount - 1;
  LMeanX := ReduceSumF64(aX, aCount) / aCount;
  LMeanY := ReduceSumF64(aY, aCount) / aCount;
  LDotXX := ReduceDotF64(aX, aX, aCount);
  LDotYY := ReduceDotF64(aY, aY, aCount);
  LDotXY := ReduceDotF64(aX, aY, aCount);
  LVarX := (LDotXX - aCount * LMeanX * LMeanX) / LDiv;
  LVarY := (LDotYY - aCount * LMeanY * LMeanY) / LDiv;
  if LVarX < 0 then LVarX := 0;
  if LVarY < 0 then LVarY := 0;
  if (LVarX = 0) or (LVarY = 0) then Exit(0);
  LCov := (LDotXY - aCount * LMeanX * LMeanY) / LDiv;
  Result := LCov / (System.Sqrt(LVarX) * System.Sqrt(LVarY));
end;

function CosineSimilarityF64(aX, aY: PDouble; aCount: SizeUInt): Double;
var LDot, LNormX, LNormY, LDenom: Double;
begin
  if aCount = 0 then Exit(0);
  LDot := ReduceDotF64(aX, aY, aCount);
  LNormX := System.Sqrt(ReduceDotF64(aX, aX, aCount));
  LNormY := System.Sqrt(ReduceDotF64(aY, aY, aCount));
  LDenom := LNormX * LNormY;
  if LDenom = 0 then Exit(0);
  Result := LDot / LDenom;
end;

function MinMaxNormalizeF64(aSrc, aDst: PDouble; aCount: SizeUInt): Boolean;
var
  LMin, LMax, LRange: Double;
begin
  if aCount = 0 then Exit(False);
  LMin := ReduceMinF64(aSrc, aCount);
  LMax := ReduceMaxF64(aSrc, aCount);
  LRange := LMax - LMin;
  if LRange = 0 then begin FillChar(aDst^, aCount * SizeOf(Double), 0); Exit(True); end;
  ArrayLinearF64(aSrc, aDst, aCount, 1.0 / LRange, -LMin / LRange);
  Result := True;
end;

function ZScoreNormalizeF64(aSrc, aDst: PDouble; aCount: SizeUInt): Boolean;
var
  LMean, LVar, LInvStd: Double;
begin
  if aCount <= 1 then Exit(False);
  LMean := ReduceSumF64(aSrc, aCount) / aCount;
  LVar := ReduceDotF64(aSrc, aSrc, aCount) / aCount - LMean * LMean;
  if LVar < 0 then LVar := 0;
  if LVar = 0 then begin FillChar(aDst^, aCount * SizeOf(Double), 0); Exit(True); end;
  LInvStd := 1.0 / System.Sqrt(LVar);
  ArrayLinearF64(aSrc, aDst, aCount, LInvStd, -LMean * LInvStd);
  Result := True;
end;

end.
