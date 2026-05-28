program bench_hashmap;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.hashmap;

type
  TIntMap = specialize THashMap<Integer, Integer>;

const
  N = 100000;

var
  B: TBenchRunner;
  GMap: TIntMap;
  GSink: Int64;
  i: Integer;

procedure BenchPut(aIters: Int64);
var
  LM: TIntMap;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TIntMap.Create;
    for i := 0 to N - 1 do
      LM.Put(i, i);
    LM.Free;
  end;
end;

procedure BenchPutPrealloc(aIters: Int64);
var
  LM: TIntMap;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TIntMap.Create(N);
    for i := 0 to N - 1 do
      LM.Put(i, i);
    LM.Free;
  end;
end;

procedure BenchGetHit(aIters: Int64);
var
  it: Int64;
  i: Integer;
  LVal: Integer;
begin
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if GMap.TryGetValue(i, LVal) then
        GSink := GSink + LVal;
end;

procedure BenchGetMiss(aIters: Int64);
var
  it: Int64;
  i: Integer;
  LVal: Integer;
begin
  for it := 1 to aIters do
    for i := N to N + N - 1 do
      if GMap.TryGetValue(i, LVal) then
        GSink := GSink + LVal;
end;

procedure BenchContainsKey(aIters: Int64);
var
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if GMap.ContainsKey(i) then
        Inc(GSink);
end;

procedure BenchRemove(aIters: Int64);
var
  LM: TIntMap;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TIntMap.Create(N);
    for i := 0 to N - 1 do
      LM.Put(i, i);
    for i := 0 to N - 1 do
      LM.Remove(i);
    LM.Free;
  end;
end;

begin
  GMap := TIntMap.Create(N);
  for i := 0 to N - 1 do
    GMap.Put(i, i);

  WriteLn('=== nextPas THashMap<Integer,Integer> Benchmark (N=', N, ') ===');
  WriteLn;
  B := TBenchRunner.Create;
  try
    B.Run('HashMap.Put/N=100000', @BenchPut);
    B.Run('HashMap.Put+prealloc/N=100000', @BenchPutPrealloc);
    B.Run('HashMap.Get(hit)/N=100000', @BenchGetHit);
    B.Run('HashMap.Get(miss)/N=100000', @BenchGetMiss);
    B.Run('HashMap.ContainsKey/N=100000', @BenchContainsKey);
    B.Run('HashMap.Remove/N=100000', @BenchRemove);
    B.Summary;
  finally
    B.Free;
  end;
  GMap.Free;
  if GSink = -1 then WriteLn(GSink);
end.
