program bench_vecdeque;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.vecdeque;

type
  TIntDeque = specialize TVecDeque<Integer>;

const
  N = 100000;

var
  B: TBenchRunner;
  GDeque: TIntDeque;
  GSink: Int64;
  i: Integer;

procedure BenchPushBack(aIters: Int64);
var
  LD: TIntDeque;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LD := TIntDeque.Create;
    for j := 0 to N - 1 do
      LD.PushBack(j);
    LD.Free;
  end;
end;

procedure BenchPushFront(aIters: Int64);
var
  LD: TIntDeque;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LD := TIntDeque.Create;
    for j := 0 to N - 1 do
      LD.PushFront(j);
    LD.Free;
  end;
end;

procedure BenchPopFront(aIters: Int64);
var
  LD: TIntDeque;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LD := TIntDeque.Create;
    LD.Reserve(N);
    for j := 0 to N - 1 do
      LD.PushBack(j);
    for j := 0 to N - 1 do
      GSink := GSink + LD.PopFront;
    LD.Free;
  end;
end;

procedure BenchPopBack(aIters: Int64);
var
  LD: TIntDeque;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LD := TIntDeque.Create;
    LD.Reserve(N);
    for j := 0 to N - 1 do
      LD.PushBack(j);
    for j := 0 to N - 1 do
      GSink := GSink + LD.PopBack;
    LD.Free;
  end;
end;

procedure BenchGet(aIters: Int64);
var
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
    for j := 0 to N - 1 do
      GSink := GSink + GDeque.Get(j);
end;

procedure BenchQueuePattern(aIters: Int64);
var
  LD: TIntDeque;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LD := TIntDeque.Create;
    LD.Reserve(1024);
    for j := 0 to N - 1 do
    begin
      LD.PushBack(j);
      if LD.Count > 512 then
        GSink := GSink + LD.PopFront;
    end;
    LD.Free;
  end;
end;

begin
  GDeque := TIntDeque.Create;
  GDeque.Reserve(N);
  for i := 0 to N - 1 do
    GDeque.PushBack(i);

  WriteLn('=== nextPas TVecDeque<Integer> Benchmark (N=', N, ') ===');
  WriteLn;
  B := TBenchRunner.Create;
  try
    B.Run('VecDeque.PushBack/N=100000', @BenchPushBack);
    B.Run('VecDeque.PushFront/N=100000', @BenchPushFront);
    B.Run('VecDeque.PopFront/N=100000', @BenchPopFront);
    B.Run('VecDeque.PopBack/N=100000', @BenchPopBack);
    B.Run('VecDeque.Get/N=100000', @BenchGet);
    B.Run('VecDeque.Queue(push+pop)/N=100000', @BenchQueuePattern);
    B.Summary;
  finally
    B.Free;
  end;
  GDeque.Free;
  if GSink = -1 then WriteLn(GSink);
end.
