program bench_misc;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.bench,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.trie,
  nextpas.core.collections.treemap,
  nextpas.core.collections.smallvec,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.multimap,
  nextpas.core.collections.multiset;

type
  TIntSkipList = specialize TSkipList<Integer, Integer>;
  TIntTreeMap = specialize TTreeMap<Integer, Integer>;
  TStrTrie = specialize TTrie<Integer>;
  TSmallVec8 = specialize TSmallVec<Integer, 8>;
  TIntCB = specialize TCircularBuffer<Integer>;
  TIntMultiMap = specialize TMultiMap<Integer, Integer>;
  TIntMultiSet = specialize TMultiSet<Integer>;

const
  N = 10000;

var
  B: TBenchRunner;
  GSink: Int64;

function CmpInt(const A, B: Integer; aData: Pointer): SizeInt;
begin
  Result := SizeInt(A) - SizeInt(B);
end;

procedure BenchSkipListPut(aIters: Int64);
var LS: TIntSkipList; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    LS := TIntSkipList.Create;
    for i := 0 to N - 1 do LS.Put(i, i);
    LS.Free;
  end;
end;

procedure BenchSkipListGet(aIters: Int64);
var LS: TIntSkipList; it: Int64; i, v: Integer;
begin
  LS := TIntSkipList.Create;
  for i := 0 to N - 1 do LS.Put(i, i);
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if LS.TryGetValue(i, v) then GSink := GSink + v;
  LS.Free;
end;

procedure BenchTreeMapPut(aIters: Int64);
var LM: TIntTreeMap; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TIntTreeMap.Create(nil, @CmpInt);
    for i := 0 to N - 1 do LM.Put(i, i);
    LM.Free;
  end;
end;

procedure BenchTreeMapGet(aIters: Int64);
var LM: TIntTreeMap; it: Int64; i, v: Integer;
begin
  LM := TIntTreeMap.Create(nil, @CmpInt);
  for i := 0 to N - 1 do LM.Put(i, i);
  for it := 1 to aIters do
    for i := 0 to N - 1 do
      if LM.TryGetValue(i, v) then GSink := GSink + v;
  LM.Free;
end;

procedure BenchTriePut(aIters: Int64);
var LT: TStrTrie; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    LT := TStrTrie.Create;
    for i := 0 to N - 1 do LT.Put('key' + IntToStr(i), i);
    LT.Free;
  end;
end;

procedure BenchSmallVecPush(aIters: Int64);
var SV: TSmallVec8; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    SV.Init;
    for i := 0 to N - 1 do SV.Push(i);
    SV.Done;
  end;
end;

procedure BenchCircularBufferPush(aIters: Int64);
var CB: TIntCB; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    CB := TIntCB.Create(N);
    for i := 0 to N - 1 do CB.Push(i);
    CB.Free;
  end;
end;

procedure BenchMultiMapAdd(aIters: Int64);
var LM: TIntMultiMap; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    LM := TIntMultiMap.Create;
    for i := 0 to N - 1 do LM.Add(i mod 100, i);
    LM.Free;
  end;
end;

procedure BenchMultiSetAdd(aIters: Int64);
var LS: TIntMultiSet; it: Int64; i: Integer;
begin
  for it := 1 to aIters do
  begin
    LS := TIntMultiSet.Create;
    for i := 0 to N - 1 do LS.Add(i mod 100);
    LS.Free;
  end;
end;

begin
  WriteLn('=== Misc Containers Benchmark (N=', N, ') ===');
  WriteLn;
  B := TBenchRunner.Create;
  try
    B.Run('SkipList.Put/N=10000', @BenchSkipListPut);
    B.Run('SkipList.Get/N=10000', @BenchSkipListGet);
    B.Run('TreeMap.Put/N=10000', @BenchTreeMapPut);
    B.Run('TreeMap.Get/N=10000', @BenchTreeMapGet);
    B.Run('Trie.Put(string)/N=10000', @BenchTriePut);
    B.Run('SmallVec.Push/N=10000', @BenchSmallVecPush);
    B.Run('CircularBuffer.Push/N=10000', @BenchCircularBufferPush);
    B.Run('MultiMap.Add/N=10000', @BenchMultiMapAdd);
    B.Run('MultiSet.Add/N=10000', @BenchMultiSetAdd);
    B.Summary;
  finally
    B.Free;
  end;
  if GSink = -1 then WriteLn(GSink);
end.
