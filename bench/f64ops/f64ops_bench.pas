program f64ops_bench;
{$mode ObjFPC}{$H+}
uses
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.intf;

const
  N = 10000;
  ITERS = 10000;

var
  GA, GB, GC: array[0..N-1] of Double;
  GSink: Double;

procedure InitData;
var
  I: Integer;
begin
  for I := 0 to N - 1 do
  begin
    GA[I] := I * 0.001 + 0.5;
    GB[I] := (N - I) * 0.001 + 0.3;
    GC[I] := 0;
  end;
end;

{ === Track 1: EuclideanDist — sqrt(sum((a-b)^2)) === }

procedure BenchEuclideanDist(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum, Diff: Double;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
    begin
      Diff := GA[I] - GB[I];
      Sum += Diff * Diff;
    end;
  GSink := Sqrt(Sum);
  ACtx.SetBytes(ITERS * N * 2 * SizeOf(Double));
end;

{ === Track 2: WeightedSum — sum(a[i] * b[i]) + accumulate a+b into c === }

procedure BenchWeightedSum(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum: Double;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
    begin
      GC[I] := GA[I] + GB[I];
      Sum += GA[I] * GB[I];
    end;
  GSink := Sum + GC[0];
  ACtx.SetBytes(ITERS * N * 2 * SizeOf(Double));
end;

{ === Track 3: ClampNormalize — clamp + normalize to [0,1] === }

procedure BenchClampNormalize(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Lo, Hi, Range, Sum: Double;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
  begin
    Lo := GA[0]; Hi := GA[0];
    for I := 1 to N - 1 do
    begin
      if GA[I] < Lo then Lo := GA[I];
      if GA[I] > Hi then Hi := GA[I];
    end;
    Range := Hi - Lo;
    if Range = 0 then Range := 1;
    for I := 0 to N - 1 do
    begin
      GC[I] := (GA[I] - Lo) / Range;
      Sum += GC[I];
    end;
  end;
  GSink := Sum;
  ACtx.SetBytes(ITERS * N * SizeOf(Double));
end;

{ === Track 4: SimdDot — fused multiply-add (a*b + c) accumulate === }

procedure BenchFMAccum(const ACtx: IBenchContext);
var
  Iter, I: Integer;
  Sum: Double;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
      Sum += GA[I] * GB[I] + GC[I];
  GSink := Sum;
  ACtx.SetBytes(ITERS * N * 3 * SizeOf(Double));
end;

{ === Track 5: VecScaleAdd — c[i] = a[i]*s + b[i] (DAXPY) === }

procedure BenchDAXPY(const ACtx: IBenchContext);
const
  ALPHA = 2.71828;
var
  Iter, I: Integer;
  Sum: Double;
begin
  Sum := 0;
  for Iter := 1 to ITERS do
    for I := 0 to N - 1 do
    begin
      GC[I] := ALPHA * GA[I] + GB[I];
      Sum += GC[I];
    end;
  GSink := Sum;
  ACtx.SetBytes(ITERS * N * 2 * SizeOf(Double));
end;

var
  LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('f64ops');
  LSuite.Add('EuclideanDist',  @BenchEuclideanDist);
  LSuite.Add('WeightedSum',    @BenchWeightedSum);
  LSuite.Add('ClampNormalize', @BenchClampNormalize);
  LSuite.Add('FMAccum',        @BenchFMAccum);
  LSuite.Add('DAXPY',          @BenchDAXPY);
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200));
  LSuite.SetMaxIterations(1000);
  LSuite.SetMinSamples(6);
  LSuite.SetWarmupIters(3);
  LSuite.Run.ToBenchStat;
end.
