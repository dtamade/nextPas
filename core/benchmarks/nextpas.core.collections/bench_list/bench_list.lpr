program bench_list;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.list,
  nextpas.core.collections.forward_list;

type
  TIntList = specialize TList<Integer>;
  TIntFwdList = specialize TForwardList<Integer>;

const
  N = 100000;

var
  B: TBenchRunner;
  GSink: Int64;

procedure BenchListPushBack(aIters: Int64);
var
  LL: TIntList;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LL := TIntList.Create;
    for j := 0 to N - 1 do
      LL.PushBack(j);
    LL.Free;
  end;
end;

procedure BenchListPushFront(aIters: Int64);
var
  LL: TIntList;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LL := TIntList.Create;
    for j := 0 to N - 1 do
      LL.PushFront(j);
    LL.Free;
  end;
end;

procedure BenchListPopFront(aIters: Int64);
var
  LL: TIntList;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LL := TIntList.Create;
    for j := 0 to N - 1 do
      LL.PushBack(j);
    for j := 0 to N - 1 do
      GSink := GSink + LL.PopFront;
    LL.Free;
  end;
end;

procedure BenchFwdListPushFront(aIters: Int64);
var
  LL: TIntFwdList;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LL := TIntFwdList.Create;
    for j := 0 to N - 1 do
      LL.PushFront(j);
    LL.Free;
  end;
end;

begin
  WriteLn('=== nextPas List Benchmark (N=', N, ') ===');
  WriteLn;
  B := TBenchRunner.Create;
  try
    B.Run('List.PushBack/N=100000', @BenchListPushBack);
    B.Run('List.PushFront/N=100000', @BenchListPushFront);
    B.Run('List.PopFront/N=100000', @BenchListPopFront);
    B.Run('ForwardList.PushFront/N=100000', @BenchFwdListPushFront);
    B.Summary;
  finally
    B.Free;
  end;
  if GSink = -1 then WriteLn(GSink);
end.
