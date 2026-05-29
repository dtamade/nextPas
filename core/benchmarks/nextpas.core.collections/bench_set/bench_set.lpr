program bench_set;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.hashset,
  nextpas.core.collections.tree_set,
  nextpas.core.collections.btree;

type
  TIntHashSet = specialize THashSet<Integer>;
  TIntTreeSet = specialize TTreeSet<Integer>;
  TIntBTreeSet = specialize TBTreeSet<Integer>;

const
  N = 100000;

var
  B: TBenchRunner;
  GHashSet: TIntHashSet;
  GTreeSet: TIntTreeSet;
  GBTreeSet: TIntBTreeSet;
  GSink: Int64;
  i: Integer;

procedure BenchHashSetAdd(aIters: Int64);
var
  LS: TIntHashSet;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LS := TIntHashSet.Create;
    for j := 0 to N - 1 do
      LS.Add(j);
    LS.Free;
  end;
end;

procedure BenchHashSetContainsHit(aIters: Int64);
var
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
    for j := 0 to N - 1 do
      if GHashSet.Contains(j) then Inc(GSink);
end;

procedure BenchHashSetContainsMiss(aIters: Int64);
var
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
    for j := N to N + N - 1 do
      if GHashSet.Contains(j) then Inc(GSink);
end;

procedure BenchTreeSetAdd(aIters: Int64);
var
  LS: TIntTreeSet;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LS := TIntTreeSet.Create;
    for j := 0 to N - 1 do
      LS.Add(j);
    LS.Free;
  end;
end;

procedure BenchTreeSetContains(aIters: Int64);
var
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
    for j := 0 to N - 1 do
      if GTreeSet.Contains(j) then Inc(GSink);
end;

function CmpInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

procedure BenchBTreeSetAdd(aIters: Int64);
var
  LS: TIntBTreeSet;
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
  begin
    LS := TIntBTreeSet.Create(@CmpInt);
    for j := 0 to N - 1 do
      LS.Add(j);
    LS.Free;
  end;
end;

procedure BenchBTreeSetContains(aIters: Int64);
var
  it: Int64;
  j: Integer;
begin
  for it := 1 to aIters do
    for j := 0 to N - 1 do
      if GBTreeSet.Contains(j) then Inc(GSink);
end;

begin
  GHashSet := TIntHashSet.Create;
  for i := 0 to N - 1 do
    GHashSet.Add(i);
  GTreeSet := TIntTreeSet.Create;
  for i := 0 to N - 1 do
    GTreeSet.Add(i);
  GBTreeSet := TIntBTreeSet.Create(@CmpInt);
  for i := 0 to N - 1 do
    GBTreeSet.Add(i);

  WriteLn('=== nextPas Set Benchmark (N=', N, ') ===');
  WriteLn;
  B := TBenchRunner.Create;
  try
    B.Run('HashSet.Add/N=100000', @BenchHashSetAdd);
    B.Run('HashSet.Contains(hit)/N=100000', @BenchHashSetContainsHit);
    B.Run('HashSet.Contains(miss)/N=100000', @BenchHashSetContainsMiss);
    B.Run('TreeSet.Add/N=100000', @BenchTreeSetAdd);
    B.Run('TreeSet.Contains/N=100000', @BenchTreeSetContains);
    B.Run('BTreeSet.Add/N=100000', @BenchBTreeSetAdd);
    B.Run('BTreeSet.Contains/N=100000', @BenchBTreeSetContains);
    B.Summary;
  finally
    B.Free;
  end;
  GHashSet.Free;
  GTreeSet.Free;
  GBTreeSet.Free;
  if GSink = -1 then WriteLn(GSink);
end.
