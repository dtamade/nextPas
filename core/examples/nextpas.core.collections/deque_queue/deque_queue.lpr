{**
 * VecDeque dual-end + Queue factory (FIFO) cookbook.
 *}
program deque_queue;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.collections,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.queue.intf;

procedure Fail(const AMessage: string);
begin
  WriteLn('collections-deque-queue-status=fail');
  WriteLn('error=', AMessage);
  Halt(1);
end;

procedure Require(const ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

var
  D: specialize IDeque<Integer>;
  Q: specialize IQueue<Integer>;
begin
  WriteLn('collections-deque-queue=ready');

  D := specialize MakeVecDeque<Integer>;
  D.PushBack(1);
  D.PushFront(0);
  D.PushBack(2);
  Require(D.Front = 0, 'deque front');
  Require(D.Back = 2, 'deque back');
  Require(D.PopFront = 0, 'deque pop front');
  Require(D.PopBack = 2, 'deque pop back');
  WriteLn('deque-mid=', D.Front);

  Q := specialize MakeQueue<Integer>;
  Q.Push(10);
  Q.Push(20);
  Require(Q.Pop = 10, 'queue fifo first');
  Require(Q.Pop = 20, 'queue fifo second');
  Require(Q.IsEmpty, 'queue empty');
  WriteLn('queue-empty=', Ord(Q.IsEmpty));

  WriteLn('collections-deque-queue-status=ok');
end.
