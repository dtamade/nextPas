program bench_sort;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
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
  B: TBenchRunner;

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

procedure ReloadAndSort(aData: PInteger; aIters: Int64);
var
  it: Int64;
begin
  for it := 1 to aIters do
  begin
    GVec.WriteUnchecked(0, aData, N);
    GVec.Sort;
  end;
end;

procedure BenchRandom(aIters: Int64);
begin
  ReloadAndSort(@GRandomData[0], aIters);
end;

procedure BenchSorted(aIters: Int64);
begin
  ReloadAndSort(@GSortedData[0], aIters);
end;

procedure BenchReversed(aIters: Int64);
begin
  ReloadAndSort(@GReversedData[0], aIters);
end;

procedure BenchAllSame(aIters: Int64);
begin
  ReloadAndSort(@GAllSameData[0], aIters);
end;

begin
  InitData;
  GVec := TIntVec.Create(N);
  GVec.Resize(N);
  try
    WriteLn('=== nextPas Vec.Sort Benchmark (N=', N, ') ===');
    WriteLn;
    B := TBenchRunner.Create;
    try
      B.Run('Vec.Sort/random', @BenchRandom);
      B.Run('Vec.Sort/sorted', @BenchSorted);
      B.Run('Vec.Sort/reversed', @BenchReversed);
      B.Run('Vec.Sort/all-same', @BenchAllSame);
      B.Summary;
    finally
      B.Free;
    end;
  finally
    GVec.Free;
  end;
end.
