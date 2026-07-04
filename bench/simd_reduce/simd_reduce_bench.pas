{$mode objfpc}{$H+}
program simd_reduce_bench;

uses
  nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.simd.algorithms,
  nextpas.core.simd.arrays.typed;

const
  N4K = 4096;
  N64K = 65536;
  N1M = 1048576;

var
  GArr: array of Single;
  GArrD: array of Double;

procedure GenData;
var
  I: Integer;
begin
  SetLength(GArr, N1M);
  SetLength(GArrD, N1M);
  for I := 0 to N1M - 1 do
  begin
    GArr[I] := Single(I) * 0.001;
    GArrD[I] := Double(I) * 0.001;
  end;
end;

{ --- Single precision --- }

procedure SimdSum_F32_4K(const ACtx: IBenchContext);
var
  R: Single;
begin
  R := SimdReduceSum(@GArr[0], N4K);
  if R < 0 then WriteLn(R);
end;

procedure SimdSum_F32_64K(const ACtx: IBenchContext);
var
  R: Single;
begin
  R := SimdReduceSum(@GArr[0], N64K);
  if R < 0 then WriteLn(R);
end;

procedure SimdSum_F32_1M(const ACtx: IBenchContext);
var
  R: Single;
begin
  R := SimdReduceSum(@GArr[0], N1M);
  if R < 0 then WriteLn(R);
end;

{ --- Naive Single precision (no SIMD) --- }
function NaiveSumF32(APtr: PSingle; ACount: Integer): Single;
var
  I: Integer;
  S: Single;
begin
  S := 0;
  for I := 0 to ACount - 1 do
    S := S + APtr[I];
  Result := S;
end;

procedure NaiveSum_F32_4K(const ACtx: IBenchContext);
var
  R: Single;
begin
  R := NaiveSumF32(@GArr[0], N4K);
  if R < 0 then WriteLn(R);
end;

procedure NaiveSum_F32_64K(const ACtx: IBenchContext);
var
  R: Single;
begin
  R := NaiveSumF32(@GArr[0], N64K);
  if R < 0 then WriteLn(R);
end;

procedure NaiveSum_F32_1M(const ACtx: IBenchContext);
var
  R: Single;
begin
  R := NaiveSumF32(@GArr[0], N1M);
  if R < 0 then WriteLn(R);
end;

{ --- Double precision --- }
function NaiveSumF64(APtr: PDouble; ACount: Integer): Double;
var
  I: Integer;
  S: Double;
begin
  S := 0;
  for I := 0 to ACount - 1 do
    S := S + APtr[I];
  Result := S;
end;

procedure NaiveSum_F64_4K(const ACtx: IBenchContext);
var
  R: Double;
begin
  R := NaiveSumF64(@GArrD[0], N4K);
  if R < 0 then WriteLn(R);
end;

procedure NaiveSum_F64_64K(const ACtx: IBenchContext);
var
  R: Double;
begin
  R := NaiveSumF64(@GArrD[0], N64K);
  if R < 0 then WriteLn(R);
end;

procedure NaiveSum_F64_1M(const ACtx: IBenchContext);
var
  R: Double;
begin
  R := NaiveSumF64(@GArrD[0], N1M);
  if R < 0 then WriteLn(R);
end;

{ --- TSimdF32Array --- }
procedure SimdArraySum_1M(const ACtx: IBenchContext);
var
  LA: TSimdF32Array;
  R: Single;
begin
  LA := TSimdF32Array.Wrap(@GArr[0], N1M);
  R := LA.Sum;
  if R < 0 then WriteLn(R);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  GenData;

  WriteLn('=== nextPas simd_reduce_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  { Suite 1: F32 Sum }
  LSuite := TBenchSuite.Create('simd_reduce/f32');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(10000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Naive/4K', @NaiveSum_F32_4K);
  LSuite.Add('SIMD/4K', @SimdSum_F32_4K);
  LSuite.Add('Naive/64K', @NaiveSum_F32_64K);
  LSuite.Add('SIMD/64K', @SimdSum_F32_64K);
  LSuite.Add('Naive/1M', @NaiveSum_F32_1M);
  LSuite.Add('SIMD/1M', @SimdSum_F32_1M);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;

  { Suite 2: F64 Sum }
  LSuite := TBenchSuite.Create('simd_reduce/f64');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(10000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('Naive/4K', @NaiveSum_F64_4K);
  LSuite.Add('Naive/64K', @NaiveSum_F64_64K);
  LSuite.Add('Naive/1M', @NaiveSum_F64_1M);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;
end.
