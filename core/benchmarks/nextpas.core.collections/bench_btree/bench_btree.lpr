program bench_btree;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.btree,
  nextpas.core.collections.treemap;

type
  TIntBTree = specialize TBTreeMap<Integer, Integer>;
  TIntTreeMap = specialize TTreeMap<Integer, Integer>;

const
  N = 10000;

var
  LResults: IBenchResults;
  GSink: Int64;

function CmpInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

procedure BenchBTreePut(aIters: Int64);
var M: TIntBTree; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    M := TIntBTree.Create(@CmpInt);
    for i := 0 to N - 1 do M.Put(i, i);
    M.Free;
  end;
end;

procedure BenchBTreeGet(aIters: Int64);
var M: TIntBTree; it: Int64; i, v: Integer;
begin
  M := TIntBTree.Create(@CmpInt);
  for i := 0 to N - 1 do M.Put(i, i);
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if M.TryGetValue(i, v) then Inc(GSink, v);
  M.Free;
end;

procedure BenchBTreeRemove(aIters: Int64);
var M: TIntBTree; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    M := TIntBTree.Create(@CmpInt);
    for i := 0 to N - 1 do M.Put(i, i);
    for i := 0 to N - 1 do M.Remove(i);
    M.Free;
  end;
end;

procedure BenchTreeMapPut(aIters: Int64);
var M: TIntTreeMap; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    M := TIntTreeMap.Create(nil, @CmpInt);
    for i := 0 to N - 1 do M.Put(i, i);
    M.Free;
  end;
end;

procedure BenchTreeMapGet(aIters: Int64);
var M: TIntTreeMap; it: Int64; i, v: Integer;
begin
  M := TIntTreeMap.Create(nil, @CmpInt);
  for i := 0 to N - 1 do M.Put(i, i);
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if M.TryGetValue(i, v) then Inc(GSink, v);
  M.Free;
end;

procedure BenchTreeMapRemove(aIters: Int64);
var M: TIntTreeMap; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    M := TIntTreeMap.Create(nil, @CmpInt);
    for i := 0 to N - 1 do M.Put(i, i);
    for i := 0 to N - 1 do M.Remove(i);
    M.Free;
  end;
end;

begin
  WriteLn('=== BTreeMap vs TreeMap (N=', N, ') ===');
  LResults := TBenchSuite.Create('BTreeMap')
    .AddLoop('BTreeMap.Put', @BenchBTreePut)
    .AddLoop('BTreeMap.Get', @BenchBTreeGet)
    .AddLoop('BTreeMap.Remove', @BenchBTreeRemove)
    .AddLoop('TreeMap.Put (RBTree)', @BenchTreeMapPut)
    .AddLoop('TreeMap.Get (RBTree)', @BenchTreeMapGet)
    .AddLoop('TreeMap.Remove (RBTree)', @BenchTreeMapRemove)
    .Run;
  WriteLn(LResults.PrintToConsole);
  if GSink < 0 then Write('');
end.
