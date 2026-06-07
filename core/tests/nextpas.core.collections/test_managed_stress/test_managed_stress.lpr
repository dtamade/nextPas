program test_managed_stress;

{$mode objfpc}{$H+}

uses
  SysUtils,
  leak_tracker,
  nextpas.core.collections.base,
  nextpas.core.collections.vec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.collections.btree,
  nextpas.core.collections.lrucache,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.linkedhashmap;

var
  GPass: Integer;

procedure Pass(const AName: string);
begin
  WriteLn('  PASS: ', AName);
  Inc(GPass);
end;

procedure TestVecPushClear;
type TVecT = specialize TVec<ITracked>;
var V: TVecT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  V := TVecT.Create;
  try
    for i := 1 to 1000 do begin t := MakeTracked(i); V.Push(t); t := nil; end;
    V.Clear;
  finally V.Free; end;
  SnapAssert(Snap, 'Vec push 1000 + clear');
  Pass('Vec push 1000 + clear');
end;

procedure TestVecPopAll;
type TVecT = specialize TVec<ITracked>;
var V: TVecT; i: Integer; Snap: TLeakSnapshot; t, tmp: ITracked;
begin
  Snap := SnapTake;
  V := TVecT.Create;
  try
    for i := 1 to 100 do begin t := MakeTracked(i); V.Push(t); t := nil; end;
    for i := 1 to 100 do begin tmp := V.Pop; tmp := nil; end;
  finally V.Free; end;
  SnapAssert(Snap, 'Vec push 100 + pop all');
  Pass('Vec push 100 + pop all');
end;

procedure TestVecDequePushPopClear;
type TDequeT = specialize TVecDeque<ITracked>;
var D: TDequeT; i: Integer; Snap: TLeakSnapshot; t, tmp: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    for i := 1 to 100 do begin t := MakeTracked(i); D.PushBack(t); t := nil; end;
    for i := 1 to 50 do begin tmp := D.PopFront; tmp := nil; end;
    D.Clear;
  finally D.Free; end;
  SnapAssert(Snap, 'VecDeque push 100 pop 50 clear');
  Pass('VecDeque push/pop/clear');
end;

procedure TestVecDequeWrapResize;
type TDequeT = specialize TVecDeque<ITracked>;
var D: TDequeT; i: Integer; Snap: TLeakSnapshot; t, tmp: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    for i := 1 to 64 do begin t := MakeTracked(i); D.PushBack(t); t := nil; end;
    for i := 1 to 48 do begin tmp := D.PopFront; tmp := nil; end;
    for i := 65 to 200 do begin t := MakeTracked(i); D.PushBack(t); t := nil; end;
    D.Clear;
  finally D.Free; end;
  SnapAssert(Snap, 'VecDeque wrap + resize');
  Pass('VecDeque wrap + resize');
end;

procedure TestVecDequeManagedTryPopPointerOwnsRefsAndSyncsTail;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, outItem, backItem: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(1); D.PushBack(t); t := nil;
    t := MakeTracked(2); D.PushBack(t); t := nil;
    t := MakeTracked(3); D.PushBack(t); t := nil;

    if not D.TryPop(@outItem, 1) then
    begin
      WriteLn('FAIL: VecDeque managed TryPop(pointer) returned false');
      Halt(1);
    end;

    if (outItem = nil) or (outItem.GetId <> 3) then
    begin
      WriteLn('FAIL: VecDeque managed TryPop(pointer) returned wrong item');
      Halt(1);
    end;

    t := MakeTracked(4);
    D.PushBack(t);
    t := nil;

    backItem := D.Back;
    if (backItem = nil) or (backItem.GetId <> 4) then
    begin
      WriteLn('FAIL: VecDeque PushBack after TryPop(pointer) did not sync tail');
      Halt(1);
    end;
    backItem := nil;

    outItem := nil;
    D.Clear;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed TryPop(pointer) owns refs and syncs tail');
  Pass('VecDeque managed TryPop(pointer) owns refs and syncs tail');
end;

procedure TestVecDequeManagedTryPopArrayOwnsRefsAndSyncsTail;
type
  TDequeT = specialize TVecDeque<ITracked>;
  TTrackedArray = specialize TGenericArray<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, backItem: ITracked;
  outItems: TTrackedArray;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(10); D.PushBack(t); t := nil;
    t := MakeTracked(11); D.PushBack(t); t := nil;
    t := MakeTracked(12); D.PushBack(t); t := nil;
    t := MakeTracked(13); D.PushBack(t); t := nil;

    if not D.TryPop(outItems, 2) then
    begin
      WriteLn('FAIL: VecDeque managed TryPop(array) returned false');
      Halt(1);
    end;

    if (Length(outItems) <> 2) or
       (outItems[0] = nil) or (outItems[0].GetId <> 12) or
       (outItems[1] = nil) or (outItems[1].GetId <> 13) then
    begin
      WriteLn('FAIL: VecDeque managed TryPop(array) returned wrong items');
      Halt(1);
    end;

    t := MakeTracked(14);
    D.PushBack(t);
    t := nil;

    backItem := D.Back;
    if (backItem = nil) or (backItem.GetId <> 14) then
    begin
      WriteLn('FAIL: VecDeque PushBack after TryPop(array) did not sync tail');
      Halt(1);
    end;
    backItem := nil;

    outItems := nil;
    D.Clear;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed TryPop(array) owns refs and syncs tail');
  Pass('VecDeque managed TryPop(array) owns refs and syncs tail');
end;

procedure TestVecDequeManagedTryPopElementOwnsRefsAndSyncsTail;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, outItem, backItem: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(20); D.PushBack(t); t := nil;
    t := MakeTracked(21); D.PushBack(t); t := nil;
    t := MakeTracked(22); D.PushBack(t); t := nil;

    if not D.TryPop(outItem) then
    begin
      WriteLn('FAIL: VecDeque managed TryPop(element) returned false');
      Halt(1);
    end;

    if (outItem = nil) or (outItem.GetId <> 22) then
    begin
      WriteLn('FAIL: VecDeque managed TryPop(element) returned wrong item');
      Halt(1);
    end;

    t := MakeTracked(23);
    D.PushBack(t);
    t := nil;

    backItem := D.Back;
    if (backItem = nil) or (backItem.GetId <> 23) then
    begin
      WriteLn('FAIL: VecDeque PushBack after TryPop(element) did not sync tail');
      Halt(1);
    end;
    backItem := nil;

    outItem := nil;
    D.Clear;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed TryPop(element) owns refs and syncs tail');
  Pass('VecDeque managed TryPop(element) owns refs and syncs tail');
end;

procedure TestHashMapRehash;
type TMapT = specialize THashMap<Int32, ITracked>;
var M: TMapT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  M := TMapT.Create;
  try
    for i := 1 to 200 do begin t := MakeTracked(i); M.Add(i, t); t := nil; end;
    M.Clear;
  finally M.Free; end;
  SnapAssert(Snap, 'HashMap put 200 (rehash) + clear');
  Pass('HashMap rehash stress');
end;

procedure TestHashMapOverwrite;
type TMapT = specialize THashMap<Int32, ITracked>;
var M: TMapT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  M := TMapT.Create;
  try
    for i := 1 to 100 do begin t := MakeTracked(i); M.Add(i, t); t := nil; end;
    for i := 1 to 100 do begin t := MakeTracked(i+1000); M.AddOrAssign(i, t); t := nil; end;
    M.Clear;
  finally M.Free; end;
  SnapAssert(Snap, 'HashMap overwrite 100');
  Pass('HashMap overwrite stress');
end;

function TrackedHash(const AKey: ITracked): UInt32;
var Id: UInt32;
begin
  if AKey = nil then
    Exit(0);
  Id := UInt32(AKey.GetId);
  Id := (Id xor (Id shr 16)) * UInt32($7feb352d);
  Id := (Id xor (Id shr 15)) * UInt32($846ca68b);
  Result := Id xor (Id shr 16);
end;

function TrackedEquals(const L, R: ITracked): Boolean;
begin
  if L = nil then
    Exit(R = nil);
  if R = nil then
    Exit(False);
  Result := L.GetId = R.GetId;
end;

function KeepTrackedOddKeys(const AKey: ITracked; const AValue: ITracked): Boolean;
begin
  Result := (AKey.GetId mod 2) = 1;
end;

var
  GSwissDrainVisits: Int32;

procedure CountSwissDrainVisit(const AKey: ITracked; const AValue: ITracked);
begin
  Inc(GSwissDrainVisits);
end;

procedure TestSwissTableManagedKeyValueLifecycle;
type TSwissT = specialize TSwissTable<ITracked, ITracked>;
var
  M: TSwissT;
  Snap: TLeakSnapshot;
  i: Integer;
  k, v: ITracked;
begin
  Snap := SnapTake;
  M := TSwissT.Create(0, @TrackedHash, @TrackedEquals);
  try
    for i := 1 to 512 do
    begin
      k := MakeTracked(i);
      v := MakeTracked(i + 10000);
      M.Put(k, v);
      k := nil;
      v := nil;
    end;

    for i := 1 to 512 do
    begin
      k := MakeTracked(i);
      v := MakeTracked(i + 20000);
      M.AddOrAssign(k, v);
      k := nil;
      v := nil;
    end;

    for i := 1 to 128 do
    begin
      k := MakeTracked(i * 2);
      M.Remove(k);
      k := nil;
    end;

    M.Retain(@KeepTrackedOddKeys);
    M.ShrinkToFit;
    GSwissDrainVisits := 0;
    M.Drain(@CountSwissDrainVisit);
    if GSwissDrainVisits <> 256 then
    begin
      WriteLn('FAIL: SwissTable drain visit count expected=256 actual=', GSwissDrainVisits);
      Halt(1);
    end;

    for i := 1 to 64 do
    begin
      k := MakeTracked(i);
      v := MakeTracked(i + 30000);
      M.Put(k, v);
      k := nil;
      v := nil;
    end;
    M.Clear;
  finally
    M.Free;
  end;
  SnapAssert(Snap, 'SwissTable managed key/value lifecycle');
  Pass('SwissTable managed key/value lifecycle');
end;

function BTreeCmpInt(const A, B: Int32; aData: Pointer): SizeInt;
begin
  if A < B then Result := -1 else if A > B then Result := 1 else Result := 0;
end;

procedure TestBTreeRemoveMerge;
type TBTreeT = specialize TBTreeMap<Int32, ITracked>;
var B: TBTreeT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  B := TBTreeT.Create(@BTreeCmpInt);
  try
    for i := 1 to 500 do begin t := MakeTracked(i); B.Put(i, t); t := nil; end;
    for i := 1 to 250 do B.Remove(i * 2);
    B.Clear;
  finally B.Free; end;
  SnapAssert(Snap, 'BTree put 500 remove 250 + clear');
  Pass('BTree remove/merge stress');
end;

procedure TestLruCacheEvict;
type TLruT = specialize TLruCache<Int32, ITracked>;
var C: TLruT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  C := TLruT.Create(50);
  try
    for i := 1 to 200 do begin t := MakeTracked(i); C.Put(i, t); t := nil; end;
    C.Clear;
  finally C.Free; end;
  SnapAssert(Snap, 'LruCache put 200 (cap=50) + clear');
  Pass('LruCache evict stress');
end;

procedure TestSkipListRemove;
type TSkipT = specialize TSkipList<Int32, ITracked>;
var S: TSkipT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  S := TSkipT.Create;
  try
    for i := 1 to 100 do begin t := MakeTracked(i); S.Put(i, t); t := nil; end;
    for i := 1 to 50 do S.Remove(i);
    S.Clear;
  finally S.Free; end;
  SnapAssert(Snap, 'SkipList put 100 remove 50 + clear');
  Pass('SkipList remove stress');
end;

procedure TestCircularBufferOverwrite;
type TCBufT = specialize TCircularBuffer<ITracked>;
var B: TCBufT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  B := TCBufT.Create(50, True);
  try
    for i := 1 to 200 do begin t := MakeTracked(i); B.Push(t); t := nil; end;
    B.Clear;
  finally B.Free; end;
  SnapAssert(Snap, 'CircularBuffer push 200 (cap=50) + clear');
  Pass('CircularBuffer overwrite stress');
end;

procedure TestLinkedHashMapClear;
type TLHMapT = specialize TLinkedHashMap<Int32, ITracked>;
var M: TLHMapT; i: Integer; Snap: TLeakSnapshot; t: ITracked;
begin
  Snap := SnapTake;
  M := TLHMapT.Create;
  try
    for i := 1 to 100 do begin t := MakeTracked(i); M.Put(i, t); t := nil; end;
    M.Clear;
  finally M.Free; end;
  SnapAssert(Snap, 'LinkedHashMap put 100 + clear');
  Pass('LinkedHashMap clear stress');
end;

begin
  GPass := 0;
  WriteLn('=== Managed Type Stress Tests ===');
  TestVecPushClear;
  TestVecPopAll;
  TestVecDequePushPopClear;
  TestVecDequeWrapResize;
  TestVecDequeManagedTryPopPointerOwnsRefsAndSyncsTail;
  TestVecDequeManagedTryPopArrayOwnsRefsAndSyncsTail;
  TestVecDequeManagedTryPopElementOwnsRefsAndSyncsTail;
  TestHashMapRehash;
  TestHashMapOverwrite;
  TestSwissTableManagedKeyValueLifecycle;
  TestBTreeRemoveMerge;
  TestLruCacheEvict;
  TestSkipListRemove;
  TestCircularBufferOverwrite;
  TestLinkedHashMapClear;
  WriteLn(Format('--- %d passed ---', [GPass]));
  WriteLn('ALL PASS');
end.
