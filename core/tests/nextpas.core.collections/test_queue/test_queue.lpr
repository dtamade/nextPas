program test_queue;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.queue.intf;

type
  IIntQueue = specialize IQueue<Integer>;

var
  T: TTestRunner;

procedure TestPushPop;
var
  LQ: IIntQueue;
begin
  LQ := specialize MakeQueue<Integer>;
  LQ.Push(1);
  LQ.Push(2);
  LQ.Push(3);
  CheckEqual(Int64(3), Int64(LQ.Count), 'count');
  CheckEqual(Int64(1), Int64(LQ.Pop), 'FIFO pop 1');
  CheckEqual(Int64(2), Int64(LQ.Pop), 'FIFO pop 2');
  CheckEqual(Int64(3), Int64(LQ.Pop), 'FIFO pop 3');
end;

procedure TestPeek;
var
  LQ: IIntQueue;
  LVal: Integer;
begin
  LQ := specialize MakeQueue<Integer>;
  LQ.Push(42);
  CheckEqual(Int64(42), Int64(LQ.Peek), 'peek');
  CheckEqual(Int64(1), Int64(LQ.Count), 'peek does not remove');
  Check(LQ.TryPeek(LVal), 'try peek');
  CheckEqual(Int64(42), Int64(LVal), 'try peek value');
end;

procedure TestTryPeekEmpty;
var
  LQ: IIntQueue;
  LVal: Integer;
begin
  LQ := specialize MakeQueue<Integer>;
  Check(not LQ.TryPeek(LVal), 'try peek on empty');
end;

procedure TestPopOutBoolean;
var
  LQ: IIntQueue;
  LVal: Integer;
begin
  LQ := specialize MakeQueue<Integer>;
  Check(not LQ.Pop(LVal), 'pop(out) on empty');
  LQ.Push(7);
  Check(LQ.Pop(LVal), 'pop(out) on non-empty');
  CheckEqual(Int64(7), Int64(LVal), 'popped value');
end;

procedure TestPushArray;
var
  LQ: IIntQueue;
begin
  LQ := specialize MakeQueue<Integer>;
  LQ.Push([10, 20, 30]);
  CheckEqual(Int64(3), Int64(LQ.Count), 'count after array push');
  CheckEqual(Int64(10), Int64(LQ.Pop), 'first');
  CheckEqual(Int64(20), Int64(LQ.Pop), 'second');
  CheckEqual(Int64(30), Int64(LQ.Pop), 'third');
end;

procedure TestIsEmpty;
var
  LQ: IIntQueue;
begin
  LQ := specialize MakeQueue<Integer>;
  Check(LQ.IsEmpty, 'initially empty');
  LQ.Push(1);
  Check(not LQ.IsEmpty, 'not empty');
  LQ.Pop;
  Check(LQ.IsEmpty, 'empty after pop');
end;

procedure TestClear;
var
  LQ: IIntQueue;
begin
  LQ := specialize MakeQueue<Integer>;
  LQ.Push(1);
  LQ.Push(2);
  LQ.Clear;
  Check(LQ.IsEmpty, 'empty after clear');
  CheckEqual(Int64(0), Int64(LQ.Count), 'count 0');
end;

procedure TestManyElements;
var
  LQ: IIntQueue;
  I: Integer;
begin
  LQ := specialize MakeQueue<Integer>;
  for I := 1 to 100 do
    LQ.Push(I);
  CheckEqual(Int64(100), Int64(LQ.Count), 'count 100');
  for I := 1 to 100 do
    CheckEqual(Int64(I), Int64(LQ.Pop), 'FIFO order ' + IntToStr(I));
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.queue');
  T.Run('Push/Pop FIFO', @TestPushPop);
  T.Run('Peek', @TestPeek);
  T.Run('TryPeek empty', @TestTryPeekEmpty);
  T.Run('Pop(out) boolean', @TestPopOutBoolean);
  T.Run('Push array', @TestPushArray);
  T.Run('IsEmpty', @TestIsEmpty);
  T.Run('Clear', @TestClear);
  T.Run('Many elements (100)', @TestManyElements);
  T.Summary;
end.
