program test_circularbuffer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.circularbuffer.intf;

type
  IIntBuf = specialize ICircularBuffer<Integer>;

var
  T: TTestRunner;

procedure TestPushAndPop;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(4);
  Check(LB.Push(1), 'push 1');
  Check(LB.Push(2), 'push 2');
  Check(LB.Push(3), 'push 3');
  CheckEqual(Int64(1), Int64(LB.Pop), 'pop FIFO');
  CheckEqual(Int64(2), Int64(LB.Pop), 'pop 2');
  CheckEqual(Int64(3), Int64(LB.Pop), 'pop 3');
end;

procedure TestFullRejectMode;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(2, False);
  Check(LB.Push(1), 'push 1');
  Check(LB.Push(2), 'push 2');
  Check(not LB.Push(3), 'push rejected when full');
  Check(LB.IsFull, 'is full');
  CheckEqual(Int64(0), Int64(LB.RemainingCapacity), 'remaining 0');
end;

procedure TestFullOverwriteMode;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(2, True);
  LB.Push(1);
  LB.Push(2);
  Check(LB.Push(3), 'push overwrites oldest');
  CheckEqual(Int64(2), Int64(LB.Pop), 'oldest (1) was overwritten, pop gives 2');
  CheckEqual(Int64(3), Int64(LB.Pop), 'pop gives 3');
end;

procedure TestPeek;
var
  LB: IIntBuf;
  LVal: Integer;
begin
  LB := specialize MakeCircularBuffer<Integer>(4);
  LB.Push(42);
  CheckEqual(Int64(42), Int64(LB.Peek), 'peek');
  CheckEqual(Int64(1), Int64(LB.GetCount), 'peek does not remove');
  Check(LB.TryPeek(LVal), 'try peek');
  CheckEqual(Int64(42), Int64(LVal), 'try peek value');
end;

procedure TestTryPopEmpty;
var
  LB: IIntBuf;
  LVal: Integer;
begin
  LB := specialize MakeCircularBuffer<Integer>(4);
  Check(not LB.TryPop(LVal), 'try pop on empty');
  LB.Push(7);
  Check(LB.TryPop(LVal), 'try pop on non-empty');
  CheckEqual(Int64(7), Int64(LVal), 'popped value');
end;

procedure TestCapacity;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(8);
  CheckEqual(Int64(8), Int64(LB.Capacity), 'capacity');
  CheckEqual(Int64(8), Int64(LB.RemainingCapacity), 'remaining when empty');
  LB.Push(1);
  LB.Push(2);
  CheckEqual(Int64(6), Int64(LB.RemainingCapacity), 'remaining after 2 pushes');
end;

procedure TestIsFullIsEmpty;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(2, False);
  Check(LB.IsEmpty, 'initially empty');
  Check(not LB.IsFull, 'not full');
  LB.Push(1);
  Check(not LB.IsEmpty, 'not empty');
  Check(not LB.IsFull, 'not full yet');
  LB.Push(2);
  Check(LB.IsFull, 'full');
  Check(not LB.IsEmpty, 'not empty when full');
end;

procedure TestOverwriteOldestProperty;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(4, False);
  Check(not LB.OverwriteOldest, 'initially reject mode');
  LB.OverwriteOldest := True;
  Check(LB.OverwriteOldest, 'switched to overwrite');
end;

procedure TestClear;
var
  LB: IIntBuf;
begin
  LB := specialize MakeCircularBuffer<Integer>(4);
  LB.Push(1);
  LB.Push(2);
  LB.Clear;
  Check(LB.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LB.GetCount), 'count 0');
end;

procedure TestWrapAround;
var
  LB: IIntBuf;
  I: Integer;
begin
  LB := specialize MakeCircularBuffer<Integer>(4, False);
  LB.Push(1); LB.Push(2); LB.Push(3); LB.Push(4);
  LB.Pop; LB.Pop;
  LB.Push(5); LB.Push(6);
  CheckEqual(Int64(3), Int64(LB.Pop), 'wrap: 3');
  CheckEqual(Int64(4), Int64(LB.Pop), 'wrap: 4');
  CheckEqual(Int64(5), Int64(LB.Pop), 'wrap: 5');
  CheckEqual(Int64(6), Int64(LB.Pop), 'wrap: 6');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.circularbuffer');
  T.Run('Push and Pop FIFO', @TestPushAndPop);
  T.Run('Full reject mode', @TestFullRejectMode);
  T.Run('Full overwrite mode', @TestFullOverwriteMode);
  T.Run('Peek', @TestPeek);
  T.Run('TryPop empty', @TestTryPopEmpty);
  T.Run('Capacity', @TestCapacity);
  T.Run('IsFull/IsEmpty', @TestIsFullIsEmpty);
  T.Run('OverwriteOldest property', @TestOverwriteOldestProperty);
  T.Run('Clear', @TestClear);
  T.Run('Wrap around', @TestWrapAround);
  T.Summary;
end.
