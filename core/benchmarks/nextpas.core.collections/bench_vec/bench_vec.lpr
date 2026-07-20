program bench_vec;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.collections.vec;

type
  TIntVec = specialize TVec<Integer>;

const
  N = 100000;

var
  LResults: IBenchResults;
  GVec: TIntVec;
  GSink: Int64;

procedure BenchPush(aIters: Int64);
var
  LV: TIntVec;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LV := TIntVec.Create(N);
    for i := 0 to N - 1 do
      LV.Push(i);
    LV.Free;
  end;
end;

procedure BenchPushPrealloc(aIters: Int64);
var
  LV: TIntVec;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LV := TIntVec.Create(N);
    LV.Reserve(N);
    for i := 0 to N - 1 do
      LV.Push(i);
    LV.Free;
  end;
end;

procedure BenchPop(aIters: Int64);
var
  LV: TIntVec;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LV := TIntVec.Create(N);
    LV.Resize(N);
    for i := 0 to N - 1 do
      LV.Pop;
    LV.Free;
  end;
end;

procedure BenchGet(aIters: Int64);
var
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      GSink := GSink + GVec[i];
end;

procedure BenchGetPtr(aIters: Int64);
var
  it: Int64;
  i: Integer;
  LP: PInteger;
  LSum: Int64;
begin
  LP := GVec.GetMemory;
  for it := 1 to aIters do
  begin
    LSum := 0;
    for i := 0 to N - 1 do
      LSum := LSum + LP[i];
    GSink := GSink + LSum;
  end;
end;

procedure BenchInsertMiddle(aIters: Int64);
var
  LV: TIntVec;
  it: Int64;
  i: Integer;
const
  M = 1000;
begin
  for it := 1 to aIters do
  begin
    LV := TIntVec.Create(M);
    for i := 0 to M - 1 do
      LV.Insert(LV.Count div 2, i);
    LV.Free;
  end;
end;

procedure BenchDeleteMiddle(aIters: Int64);
var
  LV: TIntVec;
  it: Int64;
  i: Integer;
const
  M = 1000;
begin
  for it := 1 to aIters do
  begin
    LV := TIntVec.Create(M);
    LV.Resize(M);
    for i := 0 to M - 1 do
      LV.Delete(LV.Count div 2);
    LV.Free;
  end;
end;

procedure BenchContains(aIters: Int64);
var
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
    for i := 0 to 9 do
      if GVec.Contains(N - 1 - i) then
        Inc(GSink);
end;

procedure BenchIterate(aIters: Int64);
var
  it: Int64;
  i: Integer;
  LSum: Int64;
begin
  for it := 1 to aIters do
  begin
    LSum := 0;
    for i := 0 to N - 1 do
      LSum := LSum + GVec.Get(i);
    GSink := GSink + LSum;
  end;
end;

begin
  GVec := TIntVec.Create(N);
  GVec.Resize(N);

  WriteLn('=== nextPas TVec<Integer> Benchmark (N=', N, ') ===');
  WriteLn;
  LResults := TBenchSuite.Create('Vec.Push')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .AddLoop('Vec.Push/N=100000', @BenchPush)
    .AddLoop('Vec.Push+Reserve/N=100000', @BenchPushPrealloc)
    .AddLoop('Vec.Pop/N=100000', @BenchPop)
    .AddLoop('Vec.Get/N=100000', @BenchGet)
    .AddLoop('Vec.Get(Memory ptr)/N=100000', @BenchGetPtr)
    .AddLoop('Vec.Iterate/N=100000', @BenchIterate)
    .AddLoop('Vec.Insert(mid)/N=1000', @BenchInsertMiddle)
    .AddLoop('Vec.Delete(mid)/N=1000', @BenchDeleteMiddle)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-vec.json');
  GVec.Free;
  if GSink = -1 then WriteLn(GSink);
end.