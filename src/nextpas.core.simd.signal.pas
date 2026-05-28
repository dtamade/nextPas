unit nextpas.core.simd.signal;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.simd.alloc;

type
  TSimdComplexF32 = record
    Re, Im: Single;
  end;
  PSimdComplexF32 = ^TSimdComplexF32;

  TSimdFftDirection = (sfdForward, sfdInverse);

procedure FftRadix2F32(aData: PSimdComplexF32; aCount: SizeUInt; aDirection: TSimdFftDirection);
procedure Convolve1DF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aKernel: PSingle; aKernelCount: SizeUInt; aDst: PSingle);

procedure HannWindowF32(aDst: PSingle; aCount: SizeUInt);
procedure HammingWindowF32(aDst: PSingle; aCount: SizeUInt);
procedure BlackmanWindowF32(aDst: PSingle; aCount: SizeUInt);


procedure RealFftF32(aInput: PSingle; aOutput: PSimdComplexF32; aCount: SizeUInt);
procedure FirFilterF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aCoeffs: PSingle; aCoeffCount: SizeUInt; aDst: PSingle);
procedure ResampleLinearF32(aSrc: PSingle; aSrcCount: SizeUInt;
  aDst: PSingle; aDstCount: SizeUInt);
procedure CrossCorrelationF32(aX, aY: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
procedure AutoCorrelationF32(aX: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
function EnergyF32(aSrc: PSingle; aCount: SizeUInt): Single;
function RmsF32(aSrc: PSingle; aCount: SizeUInt): Single;
function ZeroCrossingRateF32(aSrc: PSingle; aCount: SizeUInt): Single;
procedure PowerSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
procedure MagnitudeSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
procedure PowerToDecibelF32(aSrc, aDst: PSingle; aCount: SizeUInt; aRefPower: Single = 1.0);
procedure PreEmphasisF32(aSrc, aDst: PSingle; aCount: SizeUInt; aCoeff: Single = 0.97);

implementation

uses
  Math, nextpas.core.simd;

procedure FftRadix2F32(aData: PSimdComplexF32; aCount: SizeUInt; aDirection: TSimdFftDirection);
var
  i, j, k, m, mh: SizeUInt;
  LAngle, LWr, LWi, LTr, LTi, LUr, LUi: Single;
  LSign: Single;
  LTemp: TSimdComplexF32;
begin
  if aCount <= 1 then Exit;

  if aDirection = sfdForward then LSign := -1.0 else LSign := 1.0;

  // Bit-reversal permutation
  j := 0;
  for i := 0 to aCount - 2 do
  begin
    if i < j then
    begin
      LTemp := aData[i];
      aData[i] := aData[j];
      aData[j] := LTemp;
    end;
    k := aCount shr 1;
    while (k >= 1) and (k <= j) do
    begin
      j := j - k;
      k := k shr 1;
    end;
    j := j + k;
  end;

  // Cooley-Tukey butterfly
  m := 2;
  while m <= aCount do
  begin
    mh := m shr 1;
    LAngle := LSign * Pi / mh;
    LWr := Cos(LAngle);
    LWi := Sin(LAngle);

    LUr := 1.0;
    LUi := 0.0;
    for j := 0 to mh - 1 do
    begin
      i := j;
      while i < aCount do
      begin
        k := i + mh;
        LTr := LUr * aData[k].Re - LUi * aData[k].Im;
        LTi := LUr * aData[k].Im + LUi * aData[k].Re;
        aData[k].Re := aData[i].Re - LTr;
        aData[k].Im := aData[i].Im - LTi;
        aData[i].Re := aData[i].Re + LTr;
        aData[i].Im := aData[i].Im + LTi;
        i := i + m;
      end;
      LTr := LUr * LWr - LUi * LWi;
      LUi := LUr * LWi + LUi * LWr;
      LUr := LTr;
    end;
    m := m shl 1;
  end;

  // Normalize for inverse
  if aDirection = sfdInverse then
  begin
    for i := 0 to aCount - 1 do
    begin
      aData[i].Re := aData[i].Re / aCount;
      aData[i].Im := aData[i].Im / aCount;
    end;
  end;
end;

procedure Convolve1DF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aKernel: PSingle; aKernelCount: SizeUInt; aDst: PSingle);
var
  i, j: SizeUInt;
  LSum: Single;
  LHalf: SizeUInt;
begin
  if (aSignalCount = 0) or (aKernelCount = 0) then Exit;
  LHalf := aKernelCount div 2;

  for i := 0 to aSignalCount - 1 do
  begin
    if (i >= LHalf) and (i + aKernelCount - LHalf <= aSignalCount) then
      aDst[i] := ReduceDotF32(@aSignal[i - LHalf], aKernel, aKernelCount)
    else
    begin
      LSum := 0;
      for j := 0 to aKernelCount - 1 do
      begin
        if (i + j >= LHalf) and (i + j - LHalf < aSignalCount) then
          LSum := LSum + aSignal[i + j - LHalf] * aKernel[j];
      end;
      aDst[i] := LSum;
    end;
  end;
end;

procedure HannWindowF32(aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LScale: Single;
begin
  if aCount <= 1 then begin if aCount = 1 then aDst[0] := 1.0; Exit; end;
  LScale := 2.0 * Pi / (aCount - 1);
  // Fill with indices scaled by 2*pi/(N-1)
  for i := 0 to aCount - 1 do
    aDst[i] := i * LScale;
  // SIMD cos
  ArrayCosF32(aDst, aDst, aCount);
  // dst = 0.5 * (1 - cos) = 0.5 - 0.5*cos = Linear(-0.5, 0.5)
  ArrayLinearF32(aDst, aDst, aCount, -0.5, 0.5);
end;

procedure HammingWindowF32(aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LScale: Single;
begin
  if aCount <= 1 then begin if aCount = 1 then aDst[0] := 1.0; Exit; end;
  LScale := 2.0 * Pi / (aCount - 1);
  for i := 0 to aCount - 1 do
    aDst[i] := i * LScale;
  ArrayCosF32(aDst, aDst, aCount);
  // dst = 0.54 - 0.46*cos = Linear(-0.46, 0.54)
  ArrayLinearF32(aDst, aDst, aCount, -0.46, 0.54);
end;

procedure BlackmanWindowF32(aDst: PSingle; aCount: SizeUInt);
var
  i: SizeUInt;
  LScale: Single;
  LTmp: PSingle;
begin
  if aCount <= 1 then begin if aCount = 1 then aDst[0] := 1.0; Exit; end;
  LScale := 2.0 * Pi / (aCount - 1);
  for i := 0 to aCount - 1 do
    aDst[i] := i * LScale;
  LTmp := PSingle(SimdAlloc(aCount * SizeOf(Single)));
  ArrayMulScalarF32(aDst, LTmp, aCount, 2.0);
  ArrayCosF32(aDst, aDst, aCount);
  ArrayCosF32(LTmp, LTmp, aCount);
  ArrayLinearF32(aDst, aDst, aCount, -0.5, 0.42);
  ArrayAxpyF32(0.08, LTmp, aDst, aDst, aCount);
  SimdFree(LTmp);
  aDst[0] := 0.0;
  aDst[aCount - 1] := 0.0;
end;


procedure RealFftF32(aInput: PSingle; aOutput: PSimdComplexF32; aCount: SizeUInt);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
  begin
    aOutput[i].Re := aInput[i];
    aOutput[i].Im := 0;
  end;
  FftRadix2F32(aOutput, aCount, sfdForward);
end;

procedure FirFilterF32(aSignal: PSingle; aSignalCount: SizeUInt;
  aCoeffs: PSingle; aCoeffCount: SizeUInt; aDst: PSingle);
var
  i, k: SizeUInt;
  LSum: Single;
  LRevCoeffs: PSingle;
begin
  if (aSignalCount = 0) or (aCoeffCount = 0) then Exit;
  LRevCoeffs := PSingle(SimdAlloc(aCoeffCount * SizeOf(Single)));
  for k := 0 to aCoeffCount - 1 do
    LRevCoeffs[k] := aCoeffs[aCoeffCount - 1 - k];
  for i := 0 to aSignalCount - 1 do
  begin
    if i >= aCoeffCount - 1 then
      aDst[i] := ReduceDotF32(@aSignal[i - aCoeffCount + 1], LRevCoeffs, aCoeffCount)
    else
    begin
      LSum := 0;
      for k := 0 to i do
        LSum := LSum + aSignal[i - k] * aCoeffs[k];
      aDst[i] := LSum;
    end;
  end;
  SimdFree(LRevCoeffs);
end;

procedure ResampleLinearF32(aSrc: PSingle; aSrcCount: SizeUInt;
  aDst: PSingle; aDstCount: SizeUInt);
var
  i: SizeUInt;
  LPos, LFrac: Single;
  LIdx: SizeUInt;
begin
  if (aSrcCount <= 1) or (aDstCount = 0) then Exit;
  if aDstCount = 1 then begin aDst[0] := aSrc[0]; Exit; end;
  for i := 0 to aDstCount - 1 do
  begin
    LPos := i * (aSrcCount - 1) / (aDstCount - 1);
    LIdx := Trunc(LPos);
    LFrac := LPos - LIdx;
    if LIdx >= aSrcCount - 1 then
      aDst[i] := aSrc[aSrcCount - 1]
    else
      aDst[i] := aSrc[LIdx] * (1 - LFrac) + aSrc[LIdx + 1] * LFrac;
  end;
end;

procedure CrossCorrelationF32(aX, aY: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
var
  lag, LEffectiveLag: SizeUInt;
begin
  if (aCount = 0) or (aMaxLag = 0) then Exit;
  if aMaxLag > aCount then LEffectiveLag := aCount else LEffectiveLag := aMaxLag;
  for lag := 0 to LEffectiveLag - 1 do
    aDst[lag] := ReduceDotF32(@aX[0], @aY[lag], aCount - lag);
end;

procedure AutoCorrelationF32(aX: PSingle; aCount: SizeUInt;
  aDst: PSingle; aMaxLag: SizeUInt);
begin
  CrossCorrelationF32(aX, aX, aCount, aDst, aMaxLag);
end;

function EnergyF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  Result := ReduceDotF32(aSrc, aSrc, aCount);
end;

function RmsF32(aSrc: PSingle; aCount: SizeUInt): Single;
begin
  if aCount = 0 then Exit(0);
  Result := System.Sqrt(EnergyF32(aSrc, aCount) / aCount);
end;

function ZeroCrossingRateF32(aSrc: PSingle; aCount: SizeUInt): Single;
var
  i: SizeUInt;
  LCrossings: SizeUInt;
begin
  if aCount <= 1 then Exit(0);
  LCrossings := 0;
  for i := 1 to aCount - 1 do
    if (aSrc[i-1] >= 0) <> (aSrc[i] >= 0) then
      Inc(LCrossings);
  Result := LCrossings / (aCount - 1);
end;

procedure PowerSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
var i: SizeUInt;
begin
  if aCount = 0 then Exit;
  for i := 0 to aCount - 1 do
    aDst[i] := aComplex[i].Re * aComplex[i].Re + aComplex[i].Im * aComplex[i].Im;
end;

procedure MagnitudeSpectrumF32(aComplex: PSimdComplexF32; aCount: SizeUInt; aDst: PSingle);
begin
  if aCount = 0 then Exit;
  PowerSpectrumF32(aComplex, aCount, aDst);
  ArraySqrtF32(aDst, aDst, aCount);
end;

procedure PowerToDecibelF32(aSrc, aDst: PSingle; aCount: SizeUInt; aRefPower: Single);
var LScale: Single;
begin
  if aCount = 0 then Exit;
  if aRefPower <= 0 then aRefPower := 1.0;
  ArrayClampF32(aSrc, aDst, aCount, 1e-10, 3.4028235e38);
  ArrayLogF32(aDst, aDst, aCount);
  LScale := 10.0 / Ln(10.0);
  if aRefPower <> 1.0 then
    ArrayAddScalarF32(aDst, aDst, aCount, -Ln(aRefPower));
  ArrayMulScalarF32(aDst, aDst, aCount, LScale);
end;

procedure PreEmphasisF32(aSrc, aDst: PSingle; aCount: SizeUInt; aCoeff: Single);
var LTmp: PSingle;
begin
  if aCount = 0 then Exit;
  aDst[0] := aSrc[0];
  if aCount <= 1 then Exit;
  LTmp := PSingle(SimdAlloc((aCount - 1) * SizeOf(Single)));
  ArrayMulScalarF32(aSrc, LTmp, aCount - 1, aCoeff);
  ArraySubF32(@aSrc[1], LTmp, @aDst[1], aCount - 1);
  SimdFree(LTmp);
end;

end.
