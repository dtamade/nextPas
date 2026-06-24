{
  bench_sort.lpr — nextPas Vec.Sort Benchmark
  Migrated from TBenchRunner to TBenchSuite fluent API.
  Demonstrates TBenchSuite + TBenchFunc usage as a reference implementation.
}
program bench_sort;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.collections.vec;

type
  TIntVec = specialize TVec<Integer>;

const
  N = 10000;

var
  GRandomData: array[0..N-1] of Integer;
  GSortedData: array[0..N-1] of Integer;
  GReversedData: array[0..N-1] of Integer;
  GAllSameData: array[0..N-1] of Integer;
  GVec: TIntVec;

procedure InitData;
var
  i: Integer;
begin
  RandSeed := 42;
  for i := 0 to N - 1 do
  begin
    GRandomData[i] := Random(1000000);
    GSortedData[i] := i;
    GReversedData[i] := N - 1 - i;
    GAllSameData[i] := 7;
  end;
end;

{ TBenchFunc: 每次调用执行一次操作，框架负责循环 }
procedure BenchSort_Random(const ACtx: IBenchContext);
begin
  GVec.WriteUnchecked(0, @GRandomData[0], N);
  GVec.Sort;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchSort_Sorted(const ACtx: IBenchContext);
begin
  GVec.WriteUnchecked(0, @GSortedData[0], N);
  GVec.Sort;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchSort_Reversed(const ACtx: IBenchContext);
begin
  GVec.WriteUnchecked(0, @GReversedData[0], N);
  GVec.Sort;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

procedure BenchSort_AllSame(const ACtx: IBenchContext);
begin
  GVec.WriteUnchecked(0, @GAllSameData[0], N);
  GVec.Sort;
  ACtx.SetBytes(N * SizeOf(Integer));
end;

var
  LResults: IBenchResults;
begin
  InitData;
  GVec := TIntVec.Create(N);
  GVec.Resize(N);
  try
    LResults := TBenchSuite.Create('Vec.Sort')
      .SetMinDuration(TDuration.FromMilliseconds(5))
      .SetMaxIterations(5000)
      .SetMinSamples(3)
      .SetWarmupIters(1)
      .Add('random/10000', @BenchSort_Random)
      .Add('sorted/10000', @BenchSort_Sorted)
      .Add('reversed/10000', @BenchSort_Reversed)
      .Add('all-same/10000', @BenchSort_AllSame)
      .Run;

    WriteLn(LResults.PrintToConsole);
    WriteLn;
    WriteLn(LResults.ToBenchstat);
  finally
    GVec.Free;
  end;
end.
