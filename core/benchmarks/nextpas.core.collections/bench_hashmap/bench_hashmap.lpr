program bench_hashmap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.fs,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss.i32i32;

type
  TIntMap = specialize THashMap<Integer, Integer>;

const
  N = 100000;

var
  LResults: IBenchResults;
  GMap: TIntMap;
  GSwiss: TSwissTableI32I32;
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

procedure BenchSwissPut(aIters: Int64);
var
  LM: TSwissTableI32I32;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TSwissTableI32I32.Create;
    for i := 0 to N - 1 do
      LM.Put(i, i);
    LM.Free;
  end;
end;

procedure BenchSwissPutPrealloc(aIters: Int64);
var
  LM: TSwissTableI32I32;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TSwissTableI32I32.Create(N);
    for i := 0 to N - 1 do
      LM.PutNew(i, i);
    LM.Free;
  end;
end;

procedure BenchSwissGetHit(aIters: Int64);
var
  it: Int64;
  i: Integer;
  LVal: Int32;
begin
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if GSwiss.TryGetValue(i, LVal) then
        GSink := GSink + LVal;
end;

procedure BenchSwissGetMiss(aIters: Int64);
var
  it: Int64;
  i: Integer;
  LVal: Int32;
begin
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      GSwiss.TryGetValue(i + N, LVal);
end;

procedure BenchSwissRemove(aIters: Int64);
var
  LM: TSwissTableI32I32;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TSwissTableI32I32.Create(N);
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

  GSwiss := TSwissTableI32I32.Create(N);
  for i := 0 to N - 1 do
    GSwiss.Put(i, i);

  WriteLn('=== nextPas THashMap<Integer,Integer> Benchmark (N=', N, ') ===');
  WriteLn;
  LResults := TBenchSuite.Create('hashmap')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .AddLoop('HashMap/Put/N=100000', @BenchPut)
    .AddLoop('HashMap/PutPrealloc/N=100000', @BenchPutPrealloc)
    .AddLoop('HashMap/Get/hit/N=100000', @BenchGetHit)
    .AddLoop('HashMap/Get/miss/N=100000', @BenchGetMiss)
    .AddLoop('HashMap/ContainsKey/N=100000', @BenchContainsKey)
    .AddLoop('HashMap/Remove/N=100000', @BenchRemove)
    .AddLoop('SwissTable/Put/N=100000', @BenchSwissPut)
    .AddLoop('SwissTable/PutPrealloc/N=100000', @BenchSwissPutPrealloc)
    .AddLoop('SwissTable/Get/hit/N=100000', @BenchSwissGetHit)
    .AddLoop('SwissTable/Get/miss/N=100000', @BenchSwissGetMiss)
    .AddLoop('SwissTable/Remove/N=100000', @BenchSwissRemove)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-hashmap.json');
  GSwiss.Free;
  GMap.Free;
  if GSink = -1 then WriteLn(GSink);
end.
