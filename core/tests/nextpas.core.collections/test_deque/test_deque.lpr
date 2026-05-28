program test_deque;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.base,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.vecdeque.intf,
  nextpas.core.collections.deque,
  nextpas.core.collections.vecdeque;

type
  IIntDeque = specialize IDeque<Integer>;
  IIntVecDeque = specialize IVecDeque<Integer>;
  TIntDeque = specialize TArrayDeque<Integer>;
  TIntVecDeque = specialize TVecDeque<Integer>;
  IStrDeque = specialize IDeque<string>;
  TStrDeque = specialize TArrayDeque<string>;

var
  T: TTestRunner;

procedure TestPushBackPopFront;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushBack(1);
  LD.PushBack(2);
  LD.PushBack(3);
  CheckEqual(Int64(3), Int64(LD.Count), 'count');
  CheckEqual(Int64(1), Int64(LD.PopFront), 'pop 1');
  CheckEqual(Int64(2), Int64(LD.PopFront), 'pop 2');
  CheckEqual(Int64(3), Int64(LD.PopFront), 'pop 3');
  Check(LD.IsEmpty, 'empty');
end;

procedure TestPushFrontPopBack;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushFront(1);
  LD.PushFront(2);
  LD.PushFront(3);
  CheckEqual(Int64(3), Int64(LD.Count), 'count');
  CheckEqual(Int64(1), Int64(LD.PopBack), 'pop 1');
  CheckEqual(Int64(2), Int64(LD.PopBack), 'pop 2');
  CheckEqual(Int64(3), Int64(LD.PopBack), 'pop 3');
  Check(LD.IsEmpty, 'empty');
end;

procedure TestFrontBack;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushBack(10);
  LD.PushBack(20);
  LD.PushBack(30);
  CheckEqual(Int64(10), Int64(LD.Front), 'front');
  CheckEqual(Int64(30), Int64(LD.Back), 'back');
end;

procedure TestRandomAccess;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushBack(100);
  LD.PushBack(200);
  LD.PushBack(300);
  CheckEqual(Int64(100), Int64(LD.Get(0)), 'item 0');
  CheckEqual(Int64(200), Int64(LD.Get(1)), 'item 1');
  CheckEqual(Int64(300), Int64(LD.Get(2)), 'item 2');
  LD.RemoveAt(1);
  LD.Insert(1, 999);
  CheckEqual(Int64(999), Int64(LD.Get(1)), 'replace item 1');
end;

procedure TestWrapAround;
var
  LD: IIntDeque;
  LI: Integer;
begin
  LD := TIntDeque.Create;
  LD.Reserve(8);
  for LI := 0 to 4 do
    LD.PushBack(LI);
  for LI := 0 to 2 do
    LD.PopFront;
  for LI := 10 to 16 do
    LD.PushBack(LI);
  CheckEqual(Int64(9), Int64(LD.Count), 'count after wrap');
  CheckEqual(Int64(3), Int64(LD.Get(0)), 'first after wrap');
  CheckEqual(Int64(4), Int64(LD.Get(1)), 'second after wrap');
  CheckEqual(Int64(10), Int64(LD.Get(2)), 'third after wrap');
end;

procedure TestGrow;
var
  LD: IIntDeque;
  LI: Integer;
begin
  LD := TIntDeque.Create;
  for LI := 0 to 99 do
  LD.PushBack(LI);
  CheckEqual(Int64(100), Int64(LD.Count), 'count 100');
  for LI := 0 to 99 do
    CheckEqual(Int64(LI), Int64(LD.Get(LI)), 'item ' + IntToStr(LI));
end;

procedure TestMixed;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushBack(2);
  LD.PushFront(1);
  LD.PushBack(3);
  LD.PushFront(0);
  CheckEqual(Int64(4), Int64(LD.Count), 'count');
  CheckEqual(Int64(0), Int64(LD.Get(0)), '0');
  CheckEqual(Int64(1), Int64(LD.Get(1)), '1');
  CheckEqual(Int64(2), Int64(LD.Get(2)), '2');
  CheckEqual(Int64(3), Int64(LD.Get(3)), '3');
end;

procedure TestClear;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushBack(1);
  LD.PushBack(2);
  LD.Clear;
  Check(LD.IsEmpty, 'empty after clear');
  LD.PushBack(99);
  CheckEqual(Int64(99), Int64(LD.Front), 'usable after clear');
end;

procedure TestString;
var
  LD: IStrDeque;
begin
  LD := TStrDeque.Create;
  LD.PushBack('hello');
  LD.PushFront('world');
  CheckEqual('world', LD.Get(0), 'str 0');
  CheckEqual('hello', LD.Get(1), 'str 1');
  CheckEqual('world', LD.PopFront, 'pop front str');
  CheckEqual('hello', LD.PopBack, 'pop back str');
end;

procedure TestReserve;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.Reserve(64);
  Check(LD.IsEmpty, 'still empty');
end;

procedure TestAutoFree;
var
  LD: IIntDeque;
begin
  LD := TIntDeque.Create;
  LD.PushBack(42);
  LD := nil;
  Check(True);
end;

procedure TestAppendFromZeroCountIsNoOp;
var
  LSrc: IIntVecDeque;
  LDst: IIntVecDeque;
begin
  LSrc := TIntDeque.Create as IIntVecDeque;
  LDst := TIntDeque.Create as IIntVecDeque;

  LSrc.PushBack(10);
  LDst.PushBack(1);

  LDst.AppendFrom(LSrc, LSrc.Count, 0);

  CheckEqual(Int64(1), Int64(LSrc.Count), 'source count unchanged');
  CheckEqual(Int64(1), Int64(LDst.Count), 'destination count unchanged');
  CheckEqual(Int64(1), Int64(LDst.Get(0)), 'destination contents unchanged');
end;

procedure TestLoadFromPointerNilFailureKeepsContents;
var
  LD: IIntVecDeque;
  LRaised: Boolean;
begin
  LD := TIntDeque.Create as IIntVecDeque;
  LD.PushBack(1);
  LD.PushBack(2);

  LRaised := False;
  try
    LD.LoadFromPointer(nil, 1);
  except
    on E: EArgumentNil do
      LRaised := True;
  end;

  Check(LRaised, 'nil source should raise EArgumentNil');
  CheckEqual(Int64(2), Int64(LD.Count), 'count preserved after failed load');
  CheckEqual(Int64(1), Int64(LD.Get(0)), 'first element preserved');
  CheckEqual(Int64(2), Int64(LD.Get(1)), 'second element preserved');
end;

procedure TestAppendFromSelfRangeCopiesSnapshot;
var
  LD: TIntVecDeque;
begin
  LD := TIntVecDeque.Create;
  try
    LD.PushBack(1);
    LD.PushBack(2);
    LD.PushBack(3);

    LD.AppendFrom(LD, 0, 2);

    CheckEqual(Int64(5), Int64(LD.Count), 'count after self append');
    CheckEqual(Int64(1), Int64(LD.Get(0)), 'item 0');
    CheckEqual(Int64(2), Int64(LD.Get(1)), 'item 1');
    CheckEqual(Int64(3), Int64(LD.Get(2)), 'item 2');
    CheckEqual(Int64(1), Int64(LD.Get(3)), 'copied item 0');
    CheckEqual(Int64(2), Int64(LD.Get(4)), 'copied item 1');
  finally
    LD.Free;
  end;
end;

procedure TestInsertFromSelfPointerCopiesSnapshot;
var
  LD: TIntVecDeque;
begin
  LD := TIntVecDeque.Create;
  try
    LD.PushBack(1);
    LD.PushBack(2);
    LD.PushBack(3);

    LD.InsertFrom(1, LD.GetPtr(0), 2);

    CheckEqual(Int64(5), Int64(LD.Count), 'count after self pointer insert');
    CheckEqual(Int64(1), Int64(LD.Get(0)), 'item 0');
    CheckEqual(Int64(1), Int64(LD.Get(1)), 'inserted item 0');
    CheckEqual(Int64(2), Int64(LD.Get(2)), 'inserted item 1');
    CheckEqual(Int64(2), Int64(LD.Get(3)), 'shifted item 1');
    CheckEqual(Int64(3), Int64(LD.Get(4)), 'shifted item 2');
  finally
    LD.Free;
  end;
end;

procedure TestAppendFromRangeOverflowRaises;
var
  LSrc: TIntVecDeque;
  LDst: TIntVecDeque;
  LRaised: Boolean;
begin
  LSrc := TIntVecDeque.Create;
  LDst := TIntVecDeque.Create;
  try
    LSrc.PushBack(1);
    LDst.PushBack(10);

    LRaised := False;
    try
      LDst.AppendFrom(LSrc, High(SizeUInt), 2);
    except
      on E: EOutOfRange do
        LRaised := True;
    end;

    Check(LRaised, 'overflowing source range should raise EOutOfRange');
    CheckEqual(Int64(1), Int64(LSrc.Count), 'source count preserved');
    CheckEqual(Int64(1), Int64(LDst.Count), 'destination count preserved');
    CheckEqual(Int64(10), Int64(LDst.Get(0)), 'destination contents preserved');
  finally
    LDst.Free;
    LSrc.Free;
  end;
end;

procedure TestInsertThenPushBackIntegrity;
var
  LD: TIntVecDeque;
begin
  LD := TIntVecDeque.Create;
  try
    LD.PushBack(10);
    LD.PushBack(20);
    LD.PushBack(30);
    LD.Insert(2, 25);
    CheckEqual(Int64(4), Int64(LD.Count), 'count after insert');
    CheckEqual(Int64(25), Int64(LD.Get(2)), 'inserted element');

    LD.PushBack(40);
    CheckEqual(Int64(5), Int64(LD.Count), 'count after pushback');
    CheckEqual(Int64(40), Int64(LD.Get(4)), 'pushback after insert');
    CheckEqual(Int64(30), Int64(LD.Get(3)), 'original tail preserved');
  finally
    LD.Free;
  end;
end;

procedure TestRemoveAtThenPushBackIntegrity;
var
  LD: TIntVecDeque;
begin
  LD := TIntVecDeque.Create;
  try
    LD.PushBack(10);
    LD.PushBack(20);
    LD.PushBack(30);
    LD.PushBack(40);
    LD.RemoveAt(2);
    CheckEqual(Int64(3), Int64(LD.Count), 'count after remove');
    CheckEqual(Int64(40), Int64(LD.Get(2)), 'shifted element');

    LD.PushBack(50);
    CheckEqual(Int64(4), Int64(LD.Count), 'count after pushback');
    CheckEqual(Int64(50), Int64(LD.Get(3)), 'pushback after remove');
  finally
    LD.Free;
  end;
end;

procedure TestSwapRemoveAtThenPushBack;
var
  LD: TIntVecDeque;
begin
  LD := TIntVecDeque.Create;
  try
    LD.PushBack(10);
    LD.PushBack(20);
    LD.PushBack(30);
    LD.PushBack(40);
    CheckEqual(Int64(20), Int64(LD.SwapRemoveAt(1)), 'swap removed value');
    CheckEqual(Int64(3), Int64(LD.Count), 'count after swap remove');

    LD.PushBack(50);
    CheckEqual(Int64(4), Int64(LD.Count), 'count after pushback');
    CheckEqual(Int64(50), Int64(LD.Get(3)), 'pushback lands correctly');
  finally
    LD.Free;
  end;
end;

procedure TestPushFrontPointerOrderMatchesArray;
var
  LD: TIntVecDeque;
  LSrc: array[0..2] of Integer;
begin
  LSrc[0] := 100;
  LSrc[1] := 200;
  LSrc[2] := 300;

  LD := TIntVecDeque.Create;
  try
    LD.PushBack(999);
    LD.PushFront(@LSrc[0], 3);
    CheckEqual(Int64(4), Int64(LD.Count), 'count');
    CheckEqual(Int64(100), Int64(LD.Get(0)), 'front[0] preserves order');
    CheckEqual(Int64(200), Int64(LD.Get(1)), 'front[1] preserves order');
    CheckEqual(Int64(300), Int64(LD.Get(2)), 'front[2] preserves order');
    CheckEqual(Int64(999), Int64(LD.Get(3)), 'original element at back');
  finally
    LD.Free;
  end;
end;

procedure TestMakeContiguousFullBuffer;
var
  LD: TIntVecDeque;
  I: Integer;
begin
  LD := TIntVecDeque.Create;
  try
    for I := 0 to 7 do
      LD.PushBack(I * 10);
    LD.PopFront;
    LD.PopFront;
    LD.PushBack(80);
    LD.PushBack(90);

    for I := 0 to Integer(LD.Count) - 1 do
      CheckEqual(Int64((I + 2) * 10), Int64(LD.Get(I)), 'element ' + IntToStr(I) + ' before contiguous');

    LD.Sort;

    for I := 0 to Integer(LD.Count) - 1 do
      CheckEqual(Int64((I + 2) * 10), Int64(LD.Get(I)), 'element ' + IntToStr(I) + ' after sort (contiguous)');
  finally
    LD.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.deque');
  T.Run('PushBack/PopFront (FIFO)', @TestPushBackPopFront);
  T.Run('PushFront/PopBack (LIFO)', @TestPushFrontPopBack);
  T.Run('Front/Back', @TestFrontBack);
  T.Run('Random access', @TestRandomAccess);
  T.Run('Wrap around', @TestWrapAround);
  T.Run('Grow (100 elements)', @TestGrow);
  T.Run('Mixed push front/back', @TestMixed);
  T.Run('Clear', @TestClear);
  T.Run('String type', @TestString);
  T.Run('Reserve', @TestReserve);
  T.Run('Auto free (interface)', @TestAutoFree);
  T.Run('AppendFrom zero count is no-op', @TestAppendFromZeroCountIsNoOp);
  T.Run('LoadFromPointer nil failure keeps contents', @TestLoadFromPointerNilFailureKeepsContents);
  T.Run('AppendFrom self range copies snapshot', @TestAppendFromSelfRangeCopiesSnapshot);
  T.Run('InsertFrom self pointer copies snapshot', @TestInsertFromSelfPointerCopiesSnapshot);
  T.Run('AppendFrom range overflow raises', @TestAppendFromRangeOverflowRaises);
  T.Run('Insert then PushBack integrity', @TestInsertThenPushBackIntegrity);
  T.Run('RemoveAt then PushBack integrity', @TestRemoveAtThenPushBackIntegrity);
  T.Run('SwapRemoveAt then PushBack', @TestSwapRemoveAtThenPushBack);
  T.Run('PushFront(Pointer) order matches array', @TestPushFrontPointerOrderMatchesArray);
  T.Run('MakeContiguous full buffer', @TestMakeContiguousFullBuffer);
  T.Summary;
end.
