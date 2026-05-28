program test_lrucache;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.lrucache.intf;

type
  IIntCache = specialize ILruCache<Integer, string>;

var
  T: TTestRunner;

procedure TestPutAndGet;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Put(3, 'three');
  CheckEqual(Int64(3), Int64(LC.GetSize), 'size after 3 puts');
  Check(LC.Get(1, LVal), 'get key 1');
  CheckEqual('one', LVal, 'value for key 1');
  Check(LC.Get(2, LVal), 'get key 2');
  CheckEqual('two', LVal, 'value for key 2');
end;

procedure TestGetMiss;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  Check(not LC.Get(99, LVal), 'get missing key returns false');
end;

procedure TestEvictionOnCapacity;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(3);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Put(3, 'three');
  LC.Put(4, 'four');
  CheckEqual(Int64(3), Int64(LC.GetSize), 'size stays at max');
  Check(not LC.Get(1, LVal), 'LRU key 1 evicted');
  Check(LC.Get(2, LVal), 'key 2 still present');
  Check(LC.Get(4, LVal), 'key 4 present');
end;

procedure TestGetPromotesToMRU;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(3);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Put(3, 'three');
  LC.Get(1, LVal);
  LC.Put(4, 'four');
  Check(LC.Get(1, LVal), 'key 1 promoted by Get, not evicted');
  Check(not LC.Get(2, LVal), 'key 2 is now LRU, evicted');
end;

procedure TestPutOverwrite;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  LC.Put(1, 'ONE');
  CheckEqual(Int64(1), Int64(LC.GetSize), 'overwrite does not increase size');
  Check(LC.Get(1, LVal), 'get overwritten key');
  CheckEqual('ONE', LVal, 'value updated');
end;

procedure TestHitMissStats;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Get(1, LVal);
  LC.Get(1, LVal);
  LC.Get(99, LVal);
  CheckEqual(Int64(2), Int64(LC.GetHitCount), 'hit count');
  CheckEqual(Int64(1), Int64(LC.GetMissCount), 'miss count');
end;

procedure TestPeekDoesNotPromote;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(3);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Put(3, 'three');
  Check(LC.Peek(1, LVal), 'peek key 1');
  CheckEqual('one', LVal, 'peek value');
  LC.Put(4, 'four');
  Check(not LC.Get(1, LVal), 'key 1 evicted despite peek (peek does not promote)');
end;

procedure TestRemove;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  Check(LC.Remove(1), 'remove existing key');
  Check(not LC.Remove(1), 'remove already removed');
  CheckEqual(Int64(1), Int64(LC.GetSize), 'size after remove');
  Check(not LC.Get(1, LVal), 'removed key not found');
end;

procedure TestContains;
var
  LC: IIntCache;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  Check(LC.Contains(1), 'contains existing');
  Check(not LC.Contains(99), 'not contains missing');
end;

procedure TestClear;
var
  LC: IIntCache;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Clear;
  CheckEqual(Int64(0), Int64(LC.GetSize), 'size after clear');
  Check(not LC.Contains(1), 'cleared key gone');
end;

procedure TestEvictExplicit;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(4);
  LC.Put(1, 'one');
  LC.Put(2, 'two');
  LC.Put(3, 'three');
  Check(LC.Evict, 'evict returns true');
  CheckEqual(Int64(2), Int64(LC.GetSize), 'size after evict');
  Check(not LC.Get(1, LVal), 'LRU key 1 evicted');
end;

procedure TestEvictLeastRecent;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(5);
  LC.Put(1, 'a');
  LC.Put(2, 'b');
  LC.Put(3, 'c');
  LC.Put(4, 'd');
  LC.Put(5, 'e');
  CheckEqual(Int64(3), Int64(LC.EvictLeastRecent(3)), 'evicted 3');
  CheckEqual(Int64(2), Int64(LC.GetSize), 'size after batch evict');
  Check(not LC.Get(1, LVal), 'key 1 evicted');
  Check(not LC.Get(3, LVal), 'key 3 evicted');
  Check(LC.Get(4, LVal), 'key 4 remains');
  Check(LC.Get(5, LVal), 'key 5 remains');
end;

procedure TestSetMaxSize;
var
  LC: IIntCache;
  LVal: string;
begin
  LC := specialize MakeLruCache<Integer, string>(5);
  LC.Put(1, 'a');
  LC.Put(2, 'b');
  LC.Put(3, 'c');
  LC.Put(4, 'd');
  LC.Put(5, 'e');
  LC.SetMaxSize(3);
  CheckEqual(Int64(3), Int64(LC.GetMaxSize), 'max size updated');
  CheckEqual(Int64(3), Int64(LC.GetSize), 'size trimmed to new max');
  Check(not LC.Get(1, LVal), 'oldest evicted after shrink');
  Check(not LC.Get(2, LVal), 'second oldest evicted');
  Check(LC.Get(3, LVal), 'key 3 remains');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.lrucache');
  T.Run('Put and Get', @TestPutAndGet);
  T.Run('Get miss', @TestGetMiss);
  T.Run('Eviction on capacity', @TestEvictionOnCapacity);
  T.Run('Get promotes to MRU', @TestGetPromotesToMRU);
  T.Run('Put overwrite', @TestPutOverwrite);
  T.Run('Hit/Miss stats', @TestHitMissStats);
  T.Run('Peek does not promote', @TestPeekDoesNotPromote);
  T.Run('Remove', @TestRemove);
  T.Run('Contains', @TestContains);
  T.Run('Clear', @TestClear);
  T.Run('Evict explicit', @TestEvictExplicit);
  T.Run('EvictLeastRecent', @TestEvictLeastRecent);
  T.Run('SetMaxSize shrinks', @TestSetMaxSize);
  T.Summary;
end.
