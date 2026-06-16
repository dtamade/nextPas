program fft_bench;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  Math, Unix, BaseUnix,
  nextpas.core.text.conv,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.signal;

const
  WARMUP = 5;
  ITERS = 20;

function GetTimeUs: Int64;
var
  LTs: TTimeVal;
begin
  fpgettimeofday(@LTs, nil);
  Result := Int64(LTs.tv_sec) * 1000000 + LTs.tv_usec;
end;

function MedianOf(const ATimes: array of Int64; ACount: Integer): Double;
var
  LI, LJ: Integer;
  LTmp: Int64;
  LSorted: array[0..63] of Int64;
begin
  for LI := 0 to ACount - 1 do LSorted[LI] := ATimes[LI];
  for LI := 0 to ACount - 2 do
    for LJ := LI + 1 to ACount - 1 do
      if LSorted[LJ] < LSorted[LI] then
      begin LTmp := LSorted[LI]; LSorted[LI] := LSorted[LJ]; LSorted[LJ] := LTmp; end;
  Result := LSorted[ACount div 2];
end;

procedure BenchFft(AN: SizeUInt);
var
  LData: PSimdComplexF32;
  LI: Integer;
  LJ: SizeUInt;
  LT0: Int64;
  LTimes: array[0..63] of Int64;
  LMedianUs: Double;
begin
  LData := PSimdComplexF32(SimdAlloc(AN * SizeOf(TSimdComplexF32)));
  for LI := 0 to AN - 1 do
  begin
    LData[LI].Re := Sin(2 * Pi * 7 * LI / AN);
    LData[LI].Im := 0;
  end;

  for LI := 0 to WARMUP - 1 do
    FftRadix2F32(LData, AN, sfdForward);

  for LI := 0 to ITERS - 1 do
  begin
    for LJ := 0 to AN - 1 do
    begin
      LData[LJ].Re := Sin(2 * Pi * 7 * LJ / AN);
      LData[LJ].Im := 0;
    end;
    LT0 := GetTimeUs;
    FftRadix2F32(LData, AN, sfdForward);
    LTimes[LI] := GetTimeUs - LT0;
  end;

  LMedianUs := MedianOf(LTimes, ITERS);
  WriteLn(Format('  N=%6d  %8.1f us  (5*N*log2(N) = %.0f MFLOP => %.2f GFLOPS)',
    [AN, LMedianUs,
     5.0 * AN * Ln(AN) / Ln(2) / 1e6,
     5.0 * AN * Ln(AN) / Ln(2) / (LMedianUs * 1000)]));

  SimdFree(LData);
end;

procedure BenchFftPlan(AN: SizeUInt);
var
  LData: PSimdComplexF32;
  LPlan: TSimdFftPlanF32;
  LI: Integer;
  LJ: SizeUInt;
  LT0: Int64;
  LTimes: array[0..63] of Int64;
  LMedianUs: Double;
begin
  LData := PSimdComplexF32(SimdAlloc(AN * SizeOf(TSimdComplexF32)));
  LPlan := TSimdFftPlanF32.Create(AN);

  for LJ := 0 to AN - 1 do
  begin
    LData[LJ].Re := Sin(2 * Pi * 7 * LJ / AN);
    LData[LJ].Im := 0;
  end;

  for LI := 0 to WARMUP - 1 do
    LPlan.Execute(LData, sfdForward);

  for LI := 0 to ITERS - 1 do
  begin
    for LJ := 0 to AN - 1 do
    begin
      LData[LJ].Re := Sin(2 * Pi * 7 * LJ / AN);
      LData[LJ].Im := 0;
    end;
    LT0 := GetTimeUs;
    LPlan.Execute(LData, sfdForward);
    LTimes[LI] := GetTimeUs - LT0;
  end;

  LMedianUs := MedianOf(LTimes, ITERS);
  WriteLn(Format('  N=%6d  %8.1f us  (5*N*log2(N) = %.0f MFLOP => %.2f GFLOPS)',
    [AN, LMedianUs,
     5.0 * AN * Ln(AN) / Ln(2) / 1e6,
     5.0 * AN * Ln(AN) / Ln(2) / (LMedianUs * 1000)]));

  LPlan.Free;
  SimdFree(LData);
end;

begin
  WriteLn('=== FFT Benchmark (FftRadix2F32) ===');
  WriteLn;
  BenchFft(256);
  BenchFft(1024);
  BenchFft(4096);
  BenchFft(16384);
  BenchFft(65536);
  BenchFft(262144);

  WriteLn;
  WriteLn('=== FFT Plan Benchmark (TSimdFftPlanF32) ===');
  WriteLn;
  BenchFftPlan(256);
  BenchFftPlan(1024);
  BenchFftPlan(4096);
  BenchFftPlan(16384);
  BenchFftPlan(65536);
  BenchFftPlan(262144);
end.
