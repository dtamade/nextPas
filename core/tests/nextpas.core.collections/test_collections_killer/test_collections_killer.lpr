program test_collections_killer;
{$I nextpas.core.settings.inc}
{$R+}{$Q+}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.vec,
  nextpas.core.collections.btree;

var
  T: TTestRunner;

{ === HashMap managed type tests === }

type
  TStrMap = specialize THashMap<String, String>;

procedure TestHashMapStringClearReuse;
var LMap: TStrMap; LI: Integer;
begin
  LMap := TStrMap.Create;
  try
    for LI := 1 to 100 do
      LMap.Put('key' + IntToStr(LI), 'val' + IntToStr(LI));
    LMap.Clear;
    for LI := 1 to 100 do
      LMap.Put('key' + IntToStr(LI), 'new' + IntToStr(LI));
    CheckEqual(Int64(100), Int64(LMap.GetCount));
    Check(LMap.Get('key50') = 'new50', 'reuse after clear');
  finally
    LMap.Free;
  end;
end;

procedure TestHashMapStringRehash;
var LMap: TStrMap; LI: Integer; LV: String;
begin
  LMap := TStrMap.Create;
  try
    for LI := 1 to 1000 do
      LMap.Put('k' + IntToStr(LI), 'v' + IntToStr(LI));
    for LI := 1 to 1000 do
    begin
      if not LMap.TryGetValue('k' + IntToStr(LI), LV) then
      begin
        Check(False, 'missing key after rehash at ' + IntToStr(LI));
        Exit;
      end;
      if LV <> 'v' + IntToStr(LI) then
      begin
        Check(False, 'wrong value after rehash at ' + IntToStr(LI));
        Exit;
      end;
    end;
    Check(True, '1000 string entries survive rehash');
  finally
    LMap.Free;
  end;
end;

procedure TestHashMapStringRemoveReinsert;
var LMap: TStrMap; LI: Integer;
begin
  LMap := TStrMap.Create;
  try
    for LI := 1 to 50 do
      LMap.Put('k' + IntToStr(LI), 'v' + IntToStr(LI));
    for LI := 1 to 25 do
      LMap.Remove('k' + IntToStr(LI));
    for LI := 1 to 25 do
      LMap.Put('k' + IntToStr(LI), 'new' + IntToStr(LI));
    CheckEqual(Int64(50), Int64(LMap.GetCount));
    Check(LMap.Get('k10') = 'new10', 'reinsert after remove');
  finally
    LMap.Free;
  end;
end;

{ === Vec empty collection tests === }

type
  TIntVec = specialize TVec<Integer>;

procedure TestVecEmptyFilter;
var LVec: TIntVec;
begin
  LVec := TIntVec.Create;
  try
    Check(LVec.GetCount = 0, 'empty vec count=0');
    Check(True, 'empty vec ok');
  finally
    LVec.Free;
  end;
end;

procedure TestVecEnsureCapacity;
var LVec: TIntVec;
begin
  LVec := TIntVec.Create(4);
  try
    LVec.EnsureCapacity(100);
    Check(LVec.GetCapacity >= 100, 'capacity >= 100 after EnsureCapacity');
  finally
    LVec.Free;
  end;
end;

{ === BTree Int32 key tests === }

type
  TIntBTree = specialize TBTreeMap<Int32, Int32>;

procedure TestBTreeInt32UpperBound;
var LTree: TIntBTree; LK, LV: Int32; LI: Integer;
begin
  LTree := TIntBTree.Create(nil);
  try
    for LI := 1 to 100 do
      LTree.Put(LI * 2, LI);
    Check(LTree.UpperBound(50, LK, LV), 'upper bound exists');
    Check(LK > 50, 'upper bound > 50');
  finally
    LTree.Free;
  end;
end;


begin
  T := TTestRunner.Create('nextpas.core.collections.killer');
  T.Run('HashMap string clear+reuse', @TestHashMapStringClearReuse);
  T.Run('HashMap string rehash 1000', @TestHashMapStringRehash);
  T.Run('HashMap string remove+reinsert', @TestHashMapStringRemoveReinsert);
  T.Run('Vec empty Any/All', @TestVecEmptyFilter);
  T.Run('Vec EnsureCapacity', @TestVecEnsureCapacity);
  T.Run('BTree Int32 UpperBound', @TestBTreeInt32UpperBound);
  T.Summary;
end.
