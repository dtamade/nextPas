program bench_lrucache;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.lrucache;

type
  TIntCache = specialize TLruCache<Integer, Integer>;

const
  N = 10000;
  CAP = 1000;

var
  LResults: IBenchResults;
  GCache: TIntCache;
  GSink: Int64;
  i: Integer;

procedure BenchPut(aIters: Int64);
var
  LC: TIntCache;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LC := TIntCache.Create(CAP);
    for j := 0 to N - 1 do
      LC.Put(j, j);
    LC.Free;
  end;
end;

procedure BenchGetHit(aIters: Int64);
var
  it: Int64;
  j, LVal: Integer;
begin
  for it := 1 to aIters do
    for j := 0 to CAP - 1 do
      if GCache.Get(j, LVal) then
        GSink := GSink + LVal;
end;

procedure BenchGetMiss(aIters: Int64);
var
  it: Int64;
  j, LVal: Integer;
begin
  for it := 1 to aIters do
    for j := CAP to CAP + CAP - 1 do
      if GCache.Get(j, LVal) then
        GSink := GSink + LVal;
end;

procedure BenchEviction(aIters: Int64);
var
  LC: TIntCache;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LC := TIntCache.Create(CAP);
    for j := 0 to N - 1 do
      LC.Put(j, j);
    for j := 0 to N - 1 do
      LC.Put(j + N, j);
    LC.Free;
  end;
end;

begin
  GCache := TIntCache.Create(CAP);
  for i := 0 to CAP - 1 do
    GCache.Put(i, i);

  WriteLn('=== nextPas TLruCache<Integer,Integer> Benchmark (Cap=', CAP, ', N=', N, ') ===');
  WriteLn;
  LResults := TBenchSuite.Create('LruCache.Put (fill+evict)')
    .AddLoop('LruCache.Put (fill+evict)/N=10000', @BenchPut)
    .AddLoop('LruCache.Get(hit)/N=1000', @BenchGetHit)
    .AddLoop('LruCache.Get(miss)/N=1000', @BenchGetMiss)
    .AddLoop('LruCache.Eviction pressure/N=20000', @BenchEviction)
    .Run;
  WriteLn(LResults.PrintToConsole);
  GCache.Free;
  if GSink = -1 then WriteLn(GSink);
end.
