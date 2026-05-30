program test_managed_stress;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

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
  GPass, GFail: Integer;

procedure Pass(const AName: string);
begin
  WriteLn('  PASS: ', AName);
  Inc(GPass);
end;

// === Vec ===

procedure TestVecPushClear;
type TVecT = specialize TVec<TTracked>;
var V: TVecT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  V := TVecT.Create;
  try
    for i := 1 to 1000 do
      V.Push(MakeTracked(i));
    V.Clear;
  finally
    V.Free;
  end;
  Snap.AssertZero('Vec push 1000 + clear');
  Pass('Vec push 1000 + clear');
end;

procedure TestVecRetain;
type TVecT = specialize TVec<TTracked>;
var V: TVecT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  V := TVecT.Create;
  try
    for i := 1 to 100 do
      V.Push(MakeTracked(i));
    V.Clear;
  finally
    V.Free;
  end;
  Snap.AssertZero('Vec push 100 + clear');
  Pass('Vec push 100 + clear');
end;

// === VecDeque ===

procedure TestVecDequePushPopClear;
type TDequeT = specialize TVecDeque<TTracked>;
var D: TDequeT; i: Integer; Snap: TLeakSnapshot; tmp: TTracked;
begin
  Snap.Take;
  D := TDequeT.Create;
  try
    for i := 1 to 100 do
      D.PushBack(MakeTracked(i));
    for i := 1 to 50 do
      tmp := D.PopFront;
    D.Clear;
  finally
    D.Free;
  end;
  Snap.AssertZero('VecDeque push 100 pop 50 clear');
  Pass('VecDeque push/pop/clear');
end;

procedure TestVecDequeWrapResize;
type TDequeT = specialize TVecDeque<TTracked>;
var D: TDequeT; i: Integer; Snap: TLeakSnapshot; tmp: TTracked;
begin
  Snap.Take;
  D := TDequeT.Create;
  try
    for i := 1 to 64 do
      D.PushBack(MakeTracked(i));
    for i := 1 to 48 do
      tmp := D.PopFront;
    for i := 65 to 200 do
      D.PushBack(MakeTracked(i));
    D.Clear;
  finally
    D.Free;
  end;
  Snap.AssertZero('VecDeque wrap + resize');
  Pass('VecDeque wrap + resize');
end;

// === HashMap ===

procedure TestHashMapRehash;
type TMapT = specialize THashMap<Int32, TTracked>;
var M: TMapT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  M := TMapT.Create;
  try
    for i := 1 to 200 do
      M.Add(i, MakeTracked(i));
    M.Clear;
  finally
    M.Free;
  end;
  Snap.AssertZero('HashMap put 200 (rehash) + clear');
  Pass('HashMap rehash stress');
end;

// === BTree ===

function BTreeCmpInt(const A, B: Int32; aData: Pointer): SizeInt;
begin
  if A < B then Result := -1
  else if A > B then Result := 1
  else Result := 0;
end;

procedure TestBTreeRemoveMerge;
type TBTreeT = specialize TBTreeMap<Int32, TTracked>;
var B: TBTreeT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  B := TBTreeT.Create(@BTreeCmpInt);
  try
    for i := 1 to 500 do
      B.Put(i, MakeTracked(i));
    for i := 1 to 250 do
      B.Remove(i * 2);
    B.Clear;
  finally
    B.Free;
  end;
  Snap.AssertZero('BTree put 500 remove 250 (merge) + clear');
  Pass('BTree remove/merge stress');
end;

// === LruCache ===

procedure TestLruCacheEvict;
type TLruT = specialize TLruCache<Int32, TTracked>;
var C: TLruT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  C := TLruT.Create(50);
  try
    for i := 1 to 200 do
      C.Put(i, MakeTracked(i));
    C.Clear;
  finally
    C.Free;
  end;
  Snap.AssertZero('LruCache put 200 (cap=50 evict) + clear');
  Pass('LruCache evict stress');
end;

// === SkipList ===

procedure TestSkipListRemove;
type TSkipT = specialize TSkipList<Int32, TTracked>;
var S: TSkipT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  S := TSkipT.Create;
  try
    for i := 1 to 100 do
      S.Put(i, MakeTracked(i));
    for i := 1 to 50 do
      S.Remove(i);
    S.Clear;
  finally
    S.Free;
  end;
  Snap.AssertZero('SkipList put 100 remove 50 + clear');
  Pass('SkipList remove stress');
end;

// === CircularBuffer ===

procedure TestCircularBufferOverwrite;
type TCBufT = specialize TCircularBuffer<TTracked>;
var B: TCBufT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  B := TCBufT.Create(50, True);
  try
    for i := 1 to 200 do
      B.Push(MakeTracked(i));
    B.Clear;
  finally
    B.Free;
  end;
  Snap.AssertZero('CircularBuffer push 200 (cap=50 overwrite) + clear');
  Pass('CircularBuffer overwrite stress');
end;

// === LinkedHashMap ===

procedure TestLinkedHashMapClear;
type TLHMapT = specialize TLinkedHashMap<Int32, TTracked>;
var M: TLHMapT; i: Integer; Snap: TLeakSnapshot;
begin
  Snap.Take;
  M := TLHMapT.Create;
  try
    for i := 1 to 100 do
      M.Put(i, MakeTracked(i));
    M.Clear;
  finally
    M.Free;
  end;
  Snap.AssertZero('LinkedHashMap put 100 + clear');
  Pass('LinkedHashMap clear stress');
end;

begin
  GPass := 0; GFail := 0;
  WriteLn('=== Managed Type Stress Tests ===');

  TestVecPushClear;
  TestVecRetain;
  TestVecDequePushPopClear;
  TestVecDequeWrapResize;
  TestHashMapRehash;
  TestBTreeRemoveMerge;
  TestLruCacheEvict;
  TestSkipListRemove;
  TestCircularBufferOverwrite;
  TestLinkedHashMapClear;

  WriteLn(Format('--- %d passed, %d failed ---', [GPass, GFail]));
  if GFail = 0 then WriteLn('ALL PASS');
end.
