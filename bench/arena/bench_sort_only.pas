{$mode objfpc}{$H+}
program bench_sort_only;
uses
  np_sort_utils, nextpas.core.time.base,
  nextpas.core.text.conv;


const
  SORT_N = 10000;
  ITERS = 1000;

var
  GData, LArr: array[0..SORT_N-1] of Int32;
  I, J: Integer;
  T0, T1: TInstant;
  ElapsedNs, BestNsPerOp: Int64;
begin
  { Init random data }
  for I := 0 to SORT_N - 1 do
    GData[I] := (I * 48271) mod 1000000;

  { Warmup }
  for I := 1 to 10 do
  begin
    Move(GData[0], LArr[0], SORT_N * SizeOf(Int32));
    IntroSortInt32(LArr);
  end;

  { Benchmark }
  BestNsPerOp := High(Int64);
  for J := 1 to 5 do
  begin
    T0 := TInstant.Now;
    for I := 1 to ITERS do
    begin
      Move(GData[0], LArr[0], SORT_N * SizeOf(Int32));
      IntroSortInt32(LArr);
    end;
    T1 := TInstant.Now;
    ElapsedNs := T1.DurationSince(T0).AsNanoseconds;
    if ElapsedNs div ITERS < BestNsPerOp then
      BestNsPerOp := ElapsedNs div ITERS;
  end;

  WriteLn(Format('Sort/Int32  N=%d  best=%d ns/op  (%.1f us/op)',
    [SORT_N, BestNsPerOp, BestNsPerOp / 1000]));
end.
