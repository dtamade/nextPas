program bench_priorityqueue;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.priorityqueue;

type
  TIntPQ = specialize TPriorityQueue<Integer>;
  TIntPQCompare = specialize TPriorityQueue<Integer>.TPQCompareFunc;

const
  N = 100000;

function CompareInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

var
  B: TBenchRunner;
  GSink: Int64;
  GRandomData: array[0..N-1] of Integer;

procedure InitData;
var
  i: Integer;
begin
  RandSeed := 42;
  for i := 0 to N - 1 do
    GRandomData[i] := Random(1000000);
end;

procedure BenchPush(aIters: Int64);
var
  LPQ: TIntPQ;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LPQ := TIntPQ.Create(TIntPQCompare(@CompareInt));
    for i := 0 to N - 1 do
      LPQ.Push(GRandomData[i]);
    LPQ.Free;
  end;
end;

procedure BenchPop(aIters: Int64);
var
  LPQ: TIntPQ;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LPQ := TIntPQ.Create(TIntPQCompare(@CompareInt));
    for i := 0 to N - 1 do
      LPQ.Push(GRandomData[i]);
    for i := 0 to N - 1 do
      GSink := GSink + LPQ.Pop;
    LPQ.Free;
  end;
end;

procedure BenchPushPop(aIters: Int64);
var
  LPQ: TIntPQ;
  it: Int64;
  i: Integer;
begin
  for it := 1 to aIters do
  begin
    LPQ := TIntPQ.Create(TIntPQCompare(@CompareInt));
    for i := 0 to N - 1 do
    begin
      LPQ.Push(GRandomData[i]);
      if LPQ.Count > 100 then
        GSink := GSink + LPQ.Pop;
    end;
    LPQ.Free;
  end;
end;

begin
  InitData;
  WriteLn('=== nextPas TPriorityQueue<Integer> Benchmark (N=', N, ') ===');
  WriteLn;
  B := TBenchRunner.Create;
  try
    B.Run('PQ.Push/N=100000', @BenchPush);
    B.Run('PQ.Pop/N=100000', @BenchPop);
    B.Run('PQ.PushPop interleaved/N=100000', @BenchPushPop);
    B.Summary;
  finally
    B.Free;
  end;
  if GSink = -1 then WriteLn(GSink);
end.
