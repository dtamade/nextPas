program test_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections;

var
  T: TTestRunner;

function CompareInt(const A, B: Integer): SizeInt;
begin
  if A < B then
    Exit(-1);
  if A > B then
    Exit(1);
  Result := 0;
end;

procedure TestFacadeFactoriesReturnPublicInterfaces;
var
  LSkipValue: string;
  LTrieValue: Integer;
begin
  with specialize MakeVec<Integer> do
  begin
    Push(10);
    CheckEqual(Int64(1), Int64(Count), 'vec count');
    CheckEqual(Int64(10), Int64(Get(0)), 'vec value');
  end;

  with specialize MakeHashMap<Integer, Integer> do
  begin
    Put(1, 100);
    CheckEqual(Int64(100), Int64(Get(1)), 'map value');
  end;

  with specialize MakeHashSet<Integer> do
  begin
    Check(Add(7), 'set add');
    Check(Contains(7), 'set contains');
  end;

  with specialize MakeDeque<Integer> do
  begin
    PushBack(1);
    PushFront(0);
    CheckEqual(Int64(2), Int64(Count), 'deque count');
    CheckEqual(Int64(0), Int64(PopFront), 'deque front');
    CheckEqual(Int64(1), Int64(PopBack), 'deque back');
  end;

  with specialize MakeSkipList<Integer, string>(@CompareInt) do
  begin
    Check(Add(1, 'one'), 'skiplist add');
    Check(not Add(1, 'uno'), 'skiplist duplicate add');
    Put(1, 'uno');
    Check(TryGetValue(1, LSkipValue), 'skiplist try get');
    CheckEqual('uno', LSkipValue, 'skiplist value');
    CheckEqual('uno', Get(1), 'skiplist checked get');
  end;

  with specialize MakeTrie<Integer> do
  begin
    Check(Add('one', 1), 'trie add');
    Check(not Add('one', 11), 'trie duplicate add');
    Put('one', 11);
    Check(TryGetValue('one', LTrieValue), 'trie try get');
    CheckEqual(Int64(11), Int64(LTrieValue), 'trie value');
    CheckEqual(Int64(11), Int64(Get('one')), 'trie checked get');
  end;
end;

procedure TestFacadeExportsGrowthStrategies;
var
  LStrategy: IGrowthStrategy;
begin
  LStrategy := FactorGrow(1.5);
  Check(LStrategy <> nil, 'FactorGrow should return a growth strategy');
  Check(LStrategy.GetGrowSize(0, 12) >= 12, 'FactorGrow should satisfy required size');

  LStrategy := DoublingGrow;
  CheckEqual(Int64(8), Int64(LStrategy.GetGrowSize(4, 5)), 'DoublingGrow should double capacity');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.facade');
  T.Run('facade factories return public interfaces', @TestFacadeFactoriesReturnPublicInterfaces);
  T.Run('facade exports growth strategies', @TestFacadeExportsGrowthStrategies);
  T.Summary;
end.
