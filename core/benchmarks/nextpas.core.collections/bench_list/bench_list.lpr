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
  LResults: IBenchResults;
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
  LResults := TBenchSuite.Create('List.PushBack')
    .AddLoop('List.PushBack/N=100000', @BenchListPushBack)
    .AddLoop('List.PushFront/N=100000', @BenchListPushFront)
    .AddLoop('List.PopFront/N=100000', @BenchListPopFront)
    .AddLoop('ForwardList.PushFront/N=100000', @BenchFwdListPushFront)
    .Run;
  WriteLn(LResults.PrintToConsole);
  if GSink = -1 then WriteLn(GSink);
end.
