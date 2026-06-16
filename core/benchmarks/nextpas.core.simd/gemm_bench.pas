program gemm_bench;

{$I nextpas.core.settings.inc}
{$I nextpas.core.simd.settings.inc}

uses
  SysUtils, Unix, BaseUnix,
  nextpas.core.simd,
  nextpas.core.simd.alloc,
  nextpas.core.simd.linalg,
  nextpas.core.simd.linalg.gemm;

const
  WARMUP = 3;
  ITERS = 10;
  REPS = 3;

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
  LSorted: array[0..31] of Int64;
begin
  for LI := 0 to ACount - 1 do LSorted[LI] := ATimes[LI];
  for LI := 0 to ACount - 2 do
    for LJ := LI + 1 to ACount - 1 do
      if LSorted[LJ] < LSorted[LI] then
      begin LTmp := LSorted[LI]; LSorted[LI] := LSorted[LJ]; LSorted[LJ] := LTmp; end;
  Result := LSorted[ACount div 2];
end;

procedure BenchGemm(AM, AN, AK: SizeUInt; const ALabel: string);
var
  LA, LB, LC: PSingle;
  LI, LR: Integer;
  LT0: Int64;
  LTimes: array[0..31] of Int64;
  LMedianUs, LFlops, LGflops: Double;
begin
  LA := PSingle(SimdAlloc(AM * AK * SizeOf(Single)));
  LB := PSingle(SimdAlloc(AK * AN * SizeOf(Single)));
  LC := PSingle(SimdAlloc(AM * AN * SizeOf(Single)));

  for LI := 0 to AM * AK - 1 do LA[LI] := (LI mod 7) * 0.1 - 0.3;
  for LI := 0 to AK * AN - 1 do LB[LI] := (LI mod 11) * 0.1 - 0.5;

  // Warmup
  for LI := 0 to WARMUP - 1 do
    GemmBlockedF32(LA, LB, LC, AM, AN, AK, AK, AN, AN);

  // Timed runs
  for LI := 0 to ITERS - 1 do
  begin
    LT0 := GetTimeUs;
    for LR := 0 to REPS - 1 do
      GemmBlockedF32(LA, LB, LC, AM, AN, AK, AK, AN, AN);
    LTimes[LI] := GetTimeUs - LT0;
  end;

  LMedianUs := MedianOf(LTimes, ITERS) / REPS;
  LFlops := 2.0 * AM * AN * AK;
  if LMedianUs > 0 then
    LGflops := LFlops / (LMedianUs * 1000.0)
  else
    LGflops := 0;

  WriteLn(Format('  %-24s %8.0f us  %6.2f GFLOPS  (%.0f MFLOP)',
    [ALabel, LMedianUs, LGflops, LFlops / 1e6]));

  SimdFree(LC);
  SimdFree(LB);
  SimdFree(LA);
end;

procedure BenchGemmMatrix(AM, AN, AK: SizeUInt; const ALabel: string);
var
  LA, LB, LC: TSimdF32Matrix;
  LI, LR: Integer;
  LT0: Int64;
  LTimes: array[0..31] of Int64;
  LMedianUs, LFlops, LGflops: Double;
begin
  LA := TSimdF32Matrix.Create(AM, AK);
  LB := TSimdF32Matrix.Create(AK, AN);
  for LI := 0 to AM * AK - 1 do LA.Data[LI] := (LI mod 7) * 0.1 - 0.3;
  for LI := 0 to AK * AN - 1 do LB.Data[LI] := (LI mod 11) * 0.1 - 0.5;

  LC := TSimdF32Matrix.Zeros(AM, AN);

  // Warmup
  for LI := 0 to WARMUP - 1 do
    GemmF32(1.0, LA, LB, 0.0, LC);

  // Timed runs
  for LI := 0 to ITERS - 1 do
  begin
    LT0 := GetTimeUs;
    for LR := 0 to REPS - 1 do
      GemmF32(1.0, LA, LB, 0.0, LC);
    LTimes[LI] := GetTimeUs - LT0;
  end;

  LMedianUs := MedianOf(LTimes, ITERS) / REPS;
  LFlops := 2.0 * AM * AN * AK;
  if LMedianUs > 0 then
    LGflops := LFlops / (LMedianUs * 1000.0)
  else
    LGflops := 0;

  WriteLn(Format('  %-24s %8.0f us  %6.2f GFLOPS  (%.0f MFLOP)',
    [ALabel, LMedianUs, LGflops, LFlops / 1e6]));

  LC.Free;
  LB.Free;
  LA.Free;
end;

begin
  WriteLn('=== GEMM Benchmark (GemmBlockedF32) ===');
  WriteLn;
  BenchGemm(64, 64, 64, '64x64x64');
  BenchGemm(128, 128, 128, '128x128x128');
  BenchGemm(256, 256, 256, '256x256x256');
  BenchGemm(512, 512, 512, '512x512x512');
  BenchGemm(1024, 1024, 1024, '1024x1024x1024');

  WriteLn;
  WriteLn('=== GEMM Benchmark (GemmF32 Matrix API) ===');
  WriteLn;
  BenchGemmMatrix(64, 64, 64, '64x64x64');
  BenchGemmMatrix(128, 128, 128, '128x128x128');
  BenchGemmMatrix(256, 256, 256, '256x256x256');
  BenchGemmMatrix(512, 512, 512, '512x512x512');
  BenchGemmMatrix(1024, 1024, 1024, '1024x1024x1024');

  WriteLn;
  WriteLn('=== Non-square sizes ===');
  WriteLn;
  BenchGemm(64, 2916, 576, 'Conv2D-like 64x2916x576');
  BenchGemm(6, 16, 256, 'Micro 6x16x256');
  BenchGemm(72, 96, 256, 'Panel 72x96x256');
end.