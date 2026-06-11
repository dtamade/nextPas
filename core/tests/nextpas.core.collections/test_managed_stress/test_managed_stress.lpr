program test_managed_stress;

{$mode objfpc}{$H+}

uses
  SysUtils,
  leak_tracker,
  nextpas.core.collections.base,
  nextpas.core.collections.vec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.smallvec,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.hashmap.swiss,
  nextpas.core.collections.btree,
  nextpas.core.collections.lrucache,
  nextpas.core.collections.skiplist,
  nextpas.core.collections.circularbuffer,
  nextpas.core.collections.linkedhashmap,
  nextpas.core.collections.priorityqueue,
  nextpas.core.collections.iterators;

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

procedure TestSmallVecManagedInlineClearReleasesSlots;
type TSmallVecT = specialize TSmallVec<ITracked, 4>;
var
  SV: TSmallVecT;
  i: Integer;
  Snap: TLeakSnapshot;
  t: ITracked;
begin
  Snap := SnapTake;
  SV.Init;
  for i := 1 to 4 do
  begin
    t := MakeTracked(i);
    SV.Push(t);
    t := nil;
  end;

  SV.Clear;
  SnapAssert(Snap, 'SmallVec managed inline clear');

  SV.Done;
  SnapAssert(Snap, 'SmallVec managed inline clear + done');
  Pass('SmallVec managed inline clear releases slots');
end;

procedure TestSmallVecManagedInlinePopReleasesSlot;
type TSmallVecT = specialize TSmallVec<ITracked, 4>;
var
  SV: TSmallVecT;
  Snap: TLeakSnapshot;
  t, popped: ITracked;
begin
  Snap := SnapTake;
  SV.Init;
  t := MakeTracked(10);
  SV.Push(t);
  t := nil;

  if not SV.Pop(popped) then
  begin
    WriteLn('FAIL: SmallVec managed Pop returned false');
    Halt(1);
  end;

  if (popped = nil) or (popped.GetId <> 10) then
  begin
    WriteLn('FAIL: SmallVec managed Pop returned wrong item');
    Halt(1);
  end;

  popped := nil;
  SnapAssert(Snap, 'SmallVec managed inline pop');

  SV.Done;
  SnapAssert(Snap, 'SmallVec managed inline pop + done');
  Pass('SmallVec managed inline pop releases slot');
end;

procedure TestSmallVecManagedSpillDoneReleasesInlineCopies;
type TSmallVecT = specialize TSmallVec<ITracked, 2>;
var
  SV: TSmallVecT;
  i: Integer;
  Snap: TLeakSnapshot;
  t: ITracked;
begin
  Snap := SnapTake;
  SV.Init;
  for i := 1 to 3 do
  begin
    t := MakeTracked(20 + i);
    SV.Push(t);
    t := nil;
  end;

  if SV.IsInline then
  begin
    WriteLn('FAIL: SmallVec managed spill did not switch to heap');
    Halt(1);
  end;

  SV.Done;
  SnapAssert(Snap, 'SmallVec managed spill + done');
  Pass('SmallVec managed spill done releases inline copies');
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

function KeepTrackedOddId(const AValue: ITracked; aData: Pointer): Boolean;
begin
  Result := (AValue <> nil) and ((AValue.GetId mod 2) <> 0);
end;

procedure TestVecDequeManagedResizeAndRetainReleaseSlots;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  i: Integer;
  Snap: TLeakSnapshot;
  t, kept0, kept1: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    for i := 1 to 5 do
    begin
      t := MakeTracked(i);
      D.PushBack(t);
      t := nil;
    end;

    D.Resize(2);
    if GTrackedAlive <> Snap + 2 then
    begin
      WriteLn('FAIL: VecDeque managed Resize shrink should release discarded refs');
      Halt(1);
    end;

    D.Resize(4);
    if GTrackedAlive <> Snap + 2 then
    begin
      WriteLn('FAIL: VecDeque managed Resize grow should default-initialize new slots');
      Halt(1);
    end;
    if (D.Get(2) <> nil) or (D.Get(3) <> nil) then
    begin
      WriteLn('FAIL: VecDeque managed Resize grow exposed non-default slots');
      Halt(1);
    end;

    t := MakeTracked(6);
    D.Put(2, t);
    t := nil;
    t := MakeTracked(7);
    D.Put(3, t);
    t := nil;

    D.Retain(@KeepTrackedOddId, nil);
    if GTrackedAlive <> Snap + 2 then
    begin
      WriteLn('FAIL: VecDeque managed Retain should release filtered refs');
      Halt(1);
    end;
    kept0 := D.Get(0);
    kept1 := D.Get(1);
    if (D.Count <> 2) or (kept0.GetId <> 1) or (kept1.GetId <> 7) then
    begin
      WriteLn('FAIL: VecDeque managed Retain kept unexpected items');
      Halt(1);
    end;
    kept0 := nil;
    kept1 := nil;

    D.Clear;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed Resize/Retain releases slots');
  Pass('VecDeque managed Resize/Retain releases slots');
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

procedure TestVecDequeManagedPointerReadOwnsRefsAfterClear;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, outItem: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(30); D.PushBack(t); t := nil;
    t := MakeTracked(31); D.PushBack(t); t := nil;

    D.Read(1, @outItem, 1);

    if (outItem = nil) or (outItem.GetId <> 31) then
    begin
      WriteLn('FAIL: VecDeque managed Read(pointer) returned wrong item');
      Halt(1);
    end;

    D.Clear;

    if (outItem = nil) or (outItem.GetId <> 31) then
    begin
      WriteLn('FAIL: VecDeque managed Read(pointer) output did not own ref after clear');
      Halt(1);
    end;

    outItem := nil;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed Read(pointer) owns refs after clear');
  Pass('VecDeque managed Read(pointer) owns refs after clear');
end;

procedure TestVecDequeManagedWritePointerReleasesOverwrittenRef;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  oldItem: ITracked;

  procedure WriteReplacement;
  var
    newItem: ITracked;
  begin
    newItem := MakeTracked(36);
    D.WriteExact(0, @newItem, 1);

    if GTrackedAlive <> Snap + 1 then
    begin
      WriteLn('FAIL: VecDeque managed WriteExact(pointer) did not release overwritten ref');
      Halt(1);
    end;

    newItem := nil;
  end;

begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    oldItem := MakeTracked(35);
    D.PushBack(oldItem);
    oldItem := nil;

    WriteReplacement;
    if GTrackedAlive <> Snap + 1 then
    begin
      WriteLn('FAIL: VecDeque managed WriteExact(pointer) output did not own ref after local clear');
      Halt(1);
    end;

    D.Clear;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed WriteExact(pointer) releases overwritten ref');
  Pass('VecDeque managed WriteExact(pointer) releases overwritten ref');
end;

procedure TestVecDequeManagedTryPeekCopyOwnsRefsAfterClear;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, outItem: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(40); D.PushBack(t); t := nil;
    t := MakeTracked(41); D.PushBack(t); t := nil;

    if not D.TryPeekCopy(@outItem, 1) then
    begin
      WriteLn('FAIL: VecDeque managed TryPeekCopy(pointer) returned false');
      Halt(1);
    end;

    if (outItem = nil) or (outItem.GetId <> 41) then
    begin
      WriteLn('FAIL: VecDeque managed TryPeekCopy(pointer) returned wrong item');
      Halt(1);
    end;

    D.Clear;

    if (outItem = nil) or (outItem.GetId <> 41) then
    begin
      WriteLn('FAIL: VecDeque managed TryPeekCopy(pointer) output did not own ref after clear');
      Halt(1);
    end;

    outItem := nil;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed TryPeekCopy(pointer) owns refs after clear');
  Pass('VecDeque managed TryPeekCopy(pointer) owns refs after clear');
end;

procedure TestVecDequeManagedRemoveCopyAtOwnsRefsAfterClear;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, outItem: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(50); D.PushBack(t); t := nil;
    t := MakeTracked(51); D.PushBack(t); t := nil;
    t := MakeTracked(52); D.PushBack(t); t := nil;

    D.RemoveCopyAt(1, @outItem);

    if (outItem = nil) or (outItem.GetId <> 51) then
    begin
      WriteLn('FAIL: VecDeque managed RemoveCopyAt(pointer) returned wrong item');
      Halt(1);
    end;

    D.Clear;

    if (outItem = nil) or (outItem.GetId <> 51) then
    begin
      WriteLn('FAIL: VecDeque managed RemoveCopyAt(pointer) output did not own ref after clear');
      Halt(1);
    end;

    outItem := nil;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed RemoveCopyAt(pointer) owns refs after clear');
  Pass('VecDeque managed RemoveCopyAt(pointer) owns refs after clear');
end;

procedure TestVecDequeManagedSwapRemoveCopyAtOwnsRefsAfterClear;
type TDequeT = specialize TVecDeque<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, outItem: ITracked;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    t := MakeTracked(60); D.PushBack(t); t := nil;
    t := MakeTracked(61); D.PushBack(t); t := nil;
    t := MakeTracked(62); D.PushBack(t); t := nil;

    D.SwapRemoveCopyAt(1, @outItem);

    if (outItem = nil) or (outItem.GetId <> 61) then
    begin
      WriteLn('FAIL: VecDeque managed SwapRemoveCopyAt(pointer) returned wrong item');
      Halt(1);
    end;

    D.Clear;

    if (outItem = nil) or (outItem.GetId <> 61) then
    begin
      WriteLn('FAIL: VecDeque managed SwapRemoveCopyAt(pointer) output did not own ref after clear');
      Halt(1);
    end;

    outItem := nil;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed SwapRemoveCopyAt(pointer) owns refs after clear');
  Pass('VecDeque managed SwapRemoveCopyAt(pointer) owns refs after clear');
end;

procedure TestVecDequeManagedToArrayOwnsRefsAfterClear;
type
  TDequeT = specialize TVecDeque<ITracked>;
  TTrackedArray = specialize TGenericArray<ITracked>;
var
  D: TDequeT;
  Snap: TLeakSnapshot;
  t, tmp: ITracked;
  Items: TTrackedArray;
  i: Integer;
begin
  Snap := SnapTake;
  D := TDequeT.Create;
  try
    for i := 1 to 64 do
    begin
      t := MakeTracked(700 + i);
      D.PushBack(t);
      t := nil;
    end;
    for i := 1 to 48 do
    begin
      tmp := D.PopFront;
      tmp := nil;
    end;
    for i := 65 to 80 do
    begin
      t := MakeTracked(700 + i);
      D.PushBack(t);
      t := nil;
    end;

    Items := D.ToArray;
    if Length(Items) <> 32 then
    begin
      WriteLn('FAIL: VecDeque managed ToArray length expected=32 actual=',
        Length(Items));
      Halt(1);
    end;

    D.Clear;

    if GTrackedAlive <> Snap + Length(Items) then
    begin
      WriteLn('FAIL: VecDeque managed ToArray output did not own refs after clear');
      Halt(1);
    end;

    if (Items[0] = nil) or (Items[0].GetId <> 749) or
       (Items[15] = nil) or (Items[15].GetId <> 764) or
       (Items[16] = nil) or (Items[16].GetId <> 765) or
       (Items[31] = nil) or (Items[31].GetId <> 780) then
    begin
      WriteLn('FAIL: VecDeque managed ToArray returned wrong wrapped order');
      Halt(1);
    end;

    Items := nil;
  finally
    D.Free;
  end;
  SnapAssert(Snap, 'VecDeque managed ToArray owns refs after clear');
  Pass('VecDeque managed ToArray owns refs after clear');
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

function CompareTrackedAsc(const A, B: ITracked; aData: Pointer): SizeInt;
begin
  if A.GetId < B.GetId then
    Result := -1
  else if A.GetId > B.GetId then
    Result := 1
  else
    Result := 0;
end;

procedure TestPriorityQueueManagedToArrayOwnsRefsAfterClear;
type
  TPQT = specialize TPriorityQueue<ITracked>;
  TTrackedArray = specialize TGenericArray<ITracked>;
var
  Q: TPQT;
  Snap: TLeakSnapshot;
  t: ITracked;
  Items: TTrackedArray;
begin
  Snap := SnapTake;
  Q := TPQT.Create(@CompareTrackedAsc);
  try
    t := MakeTracked(810); Q.Push(t); t := nil;
    t := MakeTracked(811); Q.Push(t); t := nil;
    t := MakeTracked(812); Q.Push(t); t := nil;

    Items := Q.ToArray;
    if Length(Items) <> 3 then
    begin
      WriteLn('FAIL: PriorityQueue managed ToArray length expected=3 actual=',
        Length(Items));
      Halt(1);
    end;

    Q.Clear;

    if (Items[0] = nil) or (Items[0].GetId <> 810) then
    begin
      WriteLn('FAIL: PriorityQueue managed ToArray output did not own refs after clear');
      Halt(1);
    end;

    Items := nil;
  finally
    Q.Free;
  end;
  SnapAssert(Snap, 'PriorityQueue managed ToArray owns refs after clear');
  Pass('PriorityQueue managed ToArray owns refs after clear');
end;

function MapIntToTracked(const AValue: Integer; aData: Pointer): ITracked;
begin
  Result := MakeTracked(AValue);
end;

procedure TestMapIterManagedReinitReleasesCurrent;
type
  TIntVec = specialize TVec<Integer>;
  TTrackedMapIter = specialize TMapIter<Integer, ITracked>;
var
  V: TIntVec;
  Iter: TTrackedMapIter;
  Snap: TLeakSnapshot;
  Current: ITracked;
begin
  Snap := SnapTake;
  V := TIntVec.Create;
  try
    V.Push(1);
    Iter.Init(V.Iter, @MapIntToTracked, nil);
    if not Iter.MoveNext then
    begin
      WriteLn('FAIL: MapIter should yield first item');
      Halt(1);
    end;

    Current := Iter.Current;
    if Current.GetId <> 1 then
    begin
      WriteLn('FAIL: MapIter returned unexpected id');
      Halt(1);
    end;
    Current := nil;

    Iter.Init(V.Iter, @MapIntToTracked, nil);
  finally
    V.Free;
  end;
  SnapAssert(Snap, 'MapIter managed reinit releases current');
  Pass('MapIter managed reinit releases current');
end;

procedure TestChainIterManagedReinitReleasesCurrent;
type
  TTrackedVec = specialize TVec<ITracked>;
  TTrackedChainIter = specialize TChainIter<ITracked>;
var
  First, Second: TTrackedVec;
  Iter: TTrackedChainIter;
  Snap: TLeakSnapshot;
  Current, Tracked: ITracked;
begin
  Snap := SnapTake;
  First := TTrackedVec.Create;
  Second := TTrackedVec.Create;
  try
    Tracked := MakeTracked(21);
    First.Push(Tracked);
    Tracked := nil;

    Iter.Init(First.Iter, Second.Iter);
    if not Iter.MoveNext then
    begin
      WriteLn('FAIL: ChainIter should yield first item');
      Halt(1);
    end;

    Current := Iter.Current;
    if Current.GetId <> 21 then
    begin
      WriteLn('FAIL: ChainIter returned unexpected id');
      Halt(1);
    end;
    Current := nil;

    First.Clear;
    Iter.Init(First.Iter, Second.Iter);
  finally
    Second.Free;
    First.Free;
  end;
  SnapAssert(Snap, 'ChainIter managed reinit releases current');
  Pass('ChainIter managed reinit releases current');
end;

begin
  GPass := 0;
  WriteLn('=== Managed Type Stress Tests ===');
  TestVecPushClear;
  TestVecPopAll;
  TestSmallVecManagedInlineClearReleasesSlots;
  TestSmallVecManagedInlinePopReleasesSlot;
  TestSmallVecManagedSpillDoneReleasesInlineCopies;
  TestVecDequePushPopClear;
  TestVecDequeWrapResize;
  TestVecDequeManagedResizeAndRetainReleaseSlots;
  TestVecDequeManagedTryPopPointerOwnsRefsAndSyncsTail;
  TestVecDequeManagedTryPopArrayOwnsRefsAndSyncsTail;
  TestVecDequeManagedTryPopElementOwnsRefsAndSyncsTail;
  TestVecDequeManagedPointerReadOwnsRefsAfterClear;
  TestVecDequeManagedWritePointerReleasesOverwrittenRef;
  TestVecDequeManagedTryPeekCopyOwnsRefsAfterClear;
  TestVecDequeManagedRemoveCopyAtOwnsRefsAfterClear;
  TestVecDequeManagedSwapRemoveCopyAtOwnsRefsAfterClear;
  TestVecDequeManagedToArrayOwnsRefsAfterClear;
  TestHashMapRehash;
  TestHashMapOverwrite;
  TestSwissTableManagedKeyValueLifecycle;
  TestBTreeRemoveMerge;
  TestLruCacheEvict;
  TestSkipListRemove;
  TestCircularBufferOverwrite;
  TestLinkedHashMapClear;
  TestPriorityQueueManagedToArrayOwnsRefsAfterClear;
  TestMapIterManagedReinitReleasesCurrent;
  TestChainIterManagedReinitReleasesCurrent;
  WriteLn(Format('--- %d passed ---', [GPass]));
  WriteLn('ALL PASS');
end.
