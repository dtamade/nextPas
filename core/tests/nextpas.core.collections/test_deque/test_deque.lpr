program test_deque;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque,
  nextpas.core.collections.vecdeque;

type
  IIntDeque = specialize IDeque<Integer>;
  IIntVecDeque = specialize IVecDeque<Integer>;
  TIntDeque = specialize TArrayDeque<Integer>;
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
  LD.Remove(1);
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
  T.Summary;
end.
