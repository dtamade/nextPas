{$mode objfpc}{$H+}
program bench_sort_sizes;
uses
  np_sort_utils, nextpas.core.time.base,
  nextpas.core.text.conv;


var
  BestNsPerOp: Int64;

procedure BenchSort(N, Iters: Integer);
var
  GData, LArr: array of Int32;
  I, J: Integer;
  T0, T1: TInstant;
  ElapsedNs: Int64;
begin
  SetLength(GData, N);
  SetLength(LArr, N);
  for I := 0 to N - 1 do
    GData[I] := (I * 48271) mod 1000000;

  { Warmup }
  for I := 1 to 3 do
  begin
    Move(GData[0], LArr[0], N * SizeOf(Int32));
    IntroSortInt32(LArr);
  end;

  BestNsPerOp := High(Int64);
  for J := 1 to 5 do
  begin
    T0 := TInstant.Now;
    for I := 1 to Iters do
    begin
      Move(GData[0], LArr[0], N * SizeOf(Int32));
      IntroSortInt32(LArr);
    end;
    T1 := TInstant.Now;
    ElapsedNs := T1.DurationSince(T0).AsNanoseconds;
    if ElapsedNs div Iters < BestNsPerOp then
      BestNsPerOp := ElapsedNs div Iters;
  end;
  WriteLn(Format('  N=%6d  iters=%4d  best=%10d ns/op  (%.1f us/op)',
    [N, Iters, BestNsPerOp, BestNsPerOp / 1000]));
end;

begin
  WriteLn('=== Sort/Int32 Block Partition Benchmark ===');
  BenchSort(1000, 10000);
  BenchSort(10000, 1000);
  BenchSort(100000, 100);
  BenchSort(1000000, 10);
end.
