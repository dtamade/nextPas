{$mode objfpc}{$H+}
program dedup_bench;

uses
  SysUtils, Classes, nextpas.core.base,
  nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.collections.arr.sort,
  nextpas.core.collections.hashmap.swiss.i32i32;

const
  N100K = 100000;
  N1M = 1000000;

var
  GData100K: array[0..N100K - 1] of Int32;
  GData1M: array[0..N1M - 1] of Int32;
  GOut: array[0..N1M - 1] of Int32;

procedure GenData;
var
  I: Integer;
begin
  { 50% unique: odd indices unique, even indices duplicate of previous }
  for I := 0 to N100K - 1 do
    GData100K[I] := Int32(I div 2);
  for I := 0 to N1M - 1 do
    GData1M[I] := Int32(I div 2);
end;

{ --- Sort + Dedup (our approach: SortI32 + scan) --- }
procedure SortDedup_100K(const ACtx: IBenchContext);
var
  I, K, N: Integer;
  Prev, Cur: Int32;
begin
  N := N100K;
  Move(GData100K[0], GOut[0], N * SizeOf(Int32));
  SortI32(@GOut[0], N);
  K := 0;
  Prev := GOut[0] - 1; { sentinel }
  for I := 0 to N - 1 do
  begin
    Cur := GOut[I];
    if Cur <> Prev then
    begin
      GOut[K] := Cur;
      Inc(K);
      Prev := Cur;
    end;
  end;
end;

procedure SortDedup_1M(const ACtx: IBenchContext);
var
  I, K, N: Integer;
  Prev, Cur: Int32;
begin
  N := N1M;
  Move(GData1M[0], GOut[0], N * SizeOf(Int32));
  SortI32(@GOut[0], N);
  K := 0;
  Prev := GOut[0] - 1;
  for I := 0 to N - 1 do
  begin
    Cur := GOut[I];
    if Cur <> Prev then
    begin
      GOut[K] := Cur;
      Inc(K);
      Prev := Cur;
    end;
  end;
end;

{ --- Hash-based dedup (SwissTable) --- }
procedure SwissDedup_100K(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LV: Integer;
begin
  LMap := TSwissTableI32I32.Create(N100K);
  try
    for I := 0 to N100K - 1 do
      LMap.Put(GData100K[I], 0);
  finally
    LMap.Free;
  end;
end;

procedure SwissDedup_1M(const ACtx: IBenchContext);
var
  LMap: TSwissTableI32I32;
  I, LV: Integer;
begin
  LMap := TSwissTableI32I32.Create(N1M);
  try
    for I := 0 to N1M - 1 do
      LMap.Put(GData1M[I], 0);
  finally
    LMap.Free;
  end;
end;

var
  LSuite: TBenchSuite;
  LResults: IBenchResults;
begin
  GenData;

  WriteLn('=== nextPas dedup_bench (', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%}, ') ===');
  WriteLn;

  LSuite := TBenchSuite.Create('Dedup');
  LSuite.SetMinDuration(TDuration.FromMilliseconds(200)).SetMaxIterations(1000).SetMinSamples(6).SetWarmupIters(3);
  LSuite.Add('SortDedup/100K', @SortDedup_100K);
  LSuite.Add('SortDedup/1M', @SortDedup_1M);
  LSuite.Add('SwissDedup/100K', @SwissDedup_100K);
  LSuite.Add('SwissDedup/1M', @SwissDedup_1M);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
  WriteLn;
end.
