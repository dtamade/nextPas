program test_managed_stress;

{$mode objfpc}{$H+}

uses
  SysUtils,
  leak_tracker,
  nextpas.core.collections.vec,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.hashmap,
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
  TestHashMapRehash;
  TestHashMapOverwrite;
  TestBTreeRemoveMerge;
  TestLruCacheEvict;
  TestSkipListRemove;
  TestCircularBufferOverwrite;
  TestLinkedHashMapClear;
  WriteLn(Format('--- %d passed ---', [GPass]));
  WriteLn('ALL PASS');
end.
