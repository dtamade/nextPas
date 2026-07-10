program test_lockfree_timeoutqueue;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.lockfree.timeoutqueue,
  nextpas.core.lockfree,
  nextpas.core.test,
  nextpas.core.time.sleep;

type
  TIntTimeoutQueue = specialize TTimeoutQueueImpl<Integer>;

procedure TestTimeoutQueueBasic;
var
  LQueue: TIntTimeoutQueue;
begin
  LQueue := TIntTimeoutQueue.Create(8, 1000000000); // 1 second timeout
  try
    Check(not LQueue.IsClosed, 'Should not be closed');
    Check(LQueue.IsEmpty, 'Should be empty');
    CheckEqual(Int64(0), LQueue.GetCount, 'Count should be 0');
    CheckEqual(Int64(8), LQueue.GetCapacity, 'Capacity should be 8');
    CheckEqual(Int64(1000000000), LQueue.GetTimeoutNs, 'Timeout should be 1s');
  finally
    LQueue.Free;
  end;
end;

procedure TestTimeoutQueueEnqueueDequeue;
var
  LQueue: TIntTimeoutQueue;
  LValue: Integer;
  LResult: TLockFreeTimeoutQueueResult;
begin
  LQueue := TIntTimeoutQueue.Create(8, 1000000000); // 1s timeout
  try
    Check(LQueue.TryEnqueue(42), 'Should enqueue');
    Check(not LQueue.IsEmpty, 'Should not be empty');
    CheckEqual(Int64(1), LQueue.GetCount, 'Count should be 1');

    LResult := LQueue.TryDequeue(LValue);
    Check(tqDequeued = LResult, 'Should dequeue');
    CheckEqual(42, LValue, 'Value should be 42');
    Check(LQueue.IsEmpty, 'Should be empty');
  finally
    LQueue.Free;
  end;
end;

procedure TestTimeoutQueueEmpty;
var
  LQueue: TIntTimeoutQueue;
  LValue: Integer;
  LResult: TLockFreeTimeoutQueueResult;
begin
  LQueue := TIntTimeoutQueue.Create(8, 1000000000);
  try
    LResult := LQueue.TryDequeue(LValue);
    Check(tqEmpty = LResult, 'Should be empty');
  finally
    LQueue.Free;
  end;
end;

procedure TestTimeoutQueueFIFO;
var
  LQueue: TIntTimeoutQueue;
  LValue: Integer;
begin
  LQueue := TIntTimeoutQueue.Create(8, 1000000000);
  try
    LQueue.TryEnqueue(1);
    LQueue.TryEnqueue(2);
    LQueue.TryEnqueue(3);

    LQueue.TryDequeue(LValue);
    CheckEqual(1, LValue, 'First should be 1');
    LQueue.TryDequeue(LValue);
    CheckEqual(2, LValue, 'Second should be 2');
    LQueue.TryDequeue(LValue);
    CheckEqual(3, LValue, 'Third should be 3');
  finally
    LQueue.Free;
  end;
end;

procedure TestTimeoutQueueSkipsExpiredHead;
var
  LQueue: TIntTimeoutQueue;
  LValue: Integer;
  LResult: TLockFreeTimeoutQueueResult;
begin
  LQueue := TIntTimeoutQueue.Create(8, 1000000); // 1ms timeout
  try
    Check(LQueue.TryEnqueue(1), 'Should enqueue expired candidate');
    SleepMs(5);
    Check(LQueue.TryEnqueue(2), 'Should enqueue fresh value');

    LResult := LQueue.TryDequeue(LValue);
    Check(tqDequeued = LResult, 'Should dequeue after skipping expired head');
    CheckEqual(2, LValue, 'Expired head should be skipped');
    Check(LQueue.IsEmpty, 'Queue should be empty after draining fresh value');
  finally
    LQueue.Free;
  end;
end;

procedure TestTimeoutQueueClose;
var
  LQueue: TIntTimeoutQueue;
  LValue: Integer;
  LResult: TLockFreeTimeoutQueueResult;
begin
  LQueue := TIntTimeoutQueue.Create(8, 1000000000);
  try
    LQueue.TryEnqueue(42);
    LQueue.Close;
    Check(LQueue.IsClosed, 'Should be closed');

    // Can still dequeue existing
    LResult := LQueue.TryDequeue(LValue);
    Check(tqDequeued = LResult, 'Should dequeue existing');
    CheckEqual(42, LValue);

    // Cannot enqueue
    Check(not LQueue.TryEnqueue(100), 'Should not enqueue');

    // Empty returns closed
    LResult := LQueue.TryDequeue(LValue);
    Check(tqClosed = LResult, 'Should return closed');
  finally
    LQueue.Free;
  end;
end;

begin
  WriteLn('=== test_lockfree_timeoutqueue ===');
  WriteLn;

  TestTimeoutQueueBasic;
  WriteLn('  + Basic state');

  TestTimeoutQueueEnqueueDequeue;
  WriteLn('  + Enqueue/Dequeue');

  TestTimeoutQueueEmpty;
  WriteLn('  + Empty');

  TestTimeoutQueueFIFO;
  WriteLn('  + FIFO order');

  TestTimeoutQueueSkipsExpiredHead;
  WriteLn('  + Expired head skip');

  TestTimeoutQueueClose;
  WriteLn('  + Close semantics');

  WriteLn;
  WriteLn('All timeout queue tests passed!');
end.
