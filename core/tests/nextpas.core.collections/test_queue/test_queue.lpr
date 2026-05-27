program test_queue;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.collections,
  nextpas.core.collections.queue.intf;

type
  IIntQueue = specialize IQueue<Integer>;
  IIntDeque = specialize IDeque<Integer>;

var
  T: TTestRunner;

procedure TestQueueUnitExportsQueueContracts;
var
  LQueue: IIntQueue;
  LDeque: IIntDeque;
begin
  LQueue := specialize MakeQueue<Integer>;
  LQueue.Push(1);
  LQueue.Push(2);
  CheckEqual(Int64(2), Int64(LQueue.Count), 'queue count');
  CheckEqual(Int64(1), Int64(LQueue.Pop), 'queue pop 1');
  CheckEqual(Int64(2), Int64(LQueue.Pop), 'queue pop 2');

  LDeque := specialize MakeDeque<Integer>;
  LDeque.PushBack(10);
  LDeque.PushFront(5);
  CheckEqual(Int64(5), Int64(LDeque.PopFront), 'deque front');
  CheckEqual(Int64(10), Int64(LDeque.PopBack), 'deque back');
end;

begin
  T := TTestRunner.Create('nextpas.core.collections.queue');
  T.Run('queue unit exports queue contracts', @TestQueueUnitExportsQueueContracts);
  T.Summary;
end.
