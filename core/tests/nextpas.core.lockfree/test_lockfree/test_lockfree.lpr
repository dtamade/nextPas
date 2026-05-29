program test_lockfree;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.lockfree.spsc,
  nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.stack,
  nextpas.core.lockfree.mpsc,
  nextpas.core.lockfree.deque,
  nextpas.core.platform.thread;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntStack = specialize TLockFreeStack<Integer>;
  TIntMpsc = specialize TMpscQueue<Integer>;
  TIntDeque = specialize TWorkStealingDeque<Integer>;

var
  T: TTestRunner;

{ SPSC tests }

procedure TestSpscBasic;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(4);
  Check(LQ.TryEnqueue(10), 'enq 1');
  Check(LQ.TryEnqueue(20), 'enq 2');
  Check(LQ.TryEnqueue(30), 'enq 3');
  Check(LQ.TryEnqueue(40), 'enq 4');
  Check(not LQ.TryEnqueue(50), 'full');
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(10), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 3');
  CheckEqual(Int64(30), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 4');
  CheckEqual(Int64(40), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Free;
end;

procedure TestSpscClose;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(4);
  LQ.TryEnqueue(1);
  LQ.Close;
  Check(LQ.IsClosed, 'closed');
  Check(LQ.TryDequeue(LV), 'drain after close');
  CheckEqual(Int64(1), Int64(LV));
  Check(not LQ.DequeueWait(LV), 'dequeue wait returns false on closed');
  LQ.Free;
end;

procedure TestSpscApproxCount;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(8);
  CheckEqual(Int64(0), Int64(LQ.ApproxCount));
  LQ.TryEnqueue(1);
  LQ.TryEnqueue(2);
  LQ.TryEnqueue(3);
  CheckEqual(Int64(3), Int64(LQ.ApproxCount));
  LQ.TryDequeue(LV);
  CheckEqual(Int64(2), Int64(LQ.ApproxCount));
  LQ.Free;
end;

var
  GSpscQ: TIntSpsc;

function SpscProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to 1000 do
    GSpscQ.EnqueueWait(LI);
end;

procedure TestSpscBlocking;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LV, LSum: Integer;
begin
  GSpscQ := TIntSpsc.Create(16);
  LSum := 0;
  platform_thread_create(LHandle, @SpscProducer, nil);
  while True do
  begin
    if not GSpscQ.DequeueWait(LV) then
      Break;
    Inc(LSum, LV);
    if LSum >= 500500 then
      Break;
  end;
  platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(500500), Int64(LSum), '1+2+...+1000');
  GSpscQ.Free;
end;

procedure TestSpscTimeout;
var
  LQ: TIntSpsc;
  LV: Integer;
begin
  LQ := TIntSpsc.Create(4);
  Check(not LQ.DequeueTimeout(LV, 1000000), 'timeout 1ms on empty');
  Check(LQ.EnqueueTimeout(42, 1000000), 'enqueue immediate');
  Check(LQ.DequeueTimeout(LV, 1000000), 'dequeue immediate');
  CheckEqual(Int64(42), Int64(LV));
  LQ.Free;
end;

{ MPMC tests }

procedure TestMpmcBasic;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(4);
  Check(LQ.TryEnqueue(10), 'enq 1');
  Check(LQ.TryEnqueue(20), 'enq 2');
  Check(LQ.TryEnqueue(30), 'enq 3');
  Check(LQ.TryEnqueue(40), 'enq 4');
  Check(not LQ.TryEnqueue(50), 'full');
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(10), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 3');
  CheckEqual(Int64(30), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 4');
  CheckEqual(Int64(40), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Free;
end;

procedure TestMpmcClose;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(4);
  LQ.TryEnqueue(1);
  LQ.Close;
  Check(LQ.IsClosed, 'closed');
  Check(LQ.TryDequeue(LV), 'drain after close');
  CheckEqual(Int64(1), Int64(LV));
  Check(not LQ.DequeueWait(LV), 'dequeue wait false on closed');
  LQ.Free;
end;

var
  GMpmcQ: TIntMpmc;
  GMpmcSum: Int64;

function MpmcProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LStart: Integer;
begin
  Result := nil;
  LStart := Integer(PtrInt(AArg));
  for LI := LStart to LStart + 249 do
    GMpmcQ.EnqueueWait(LI);
end;

function MpmcConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GMpmcQ.DequeueWait(LV) do
    InterlockedExchangeAdd64(GMpmcSum, Int64(LV));
end;

procedure TestMpmcContention;
var
  LProducers: array[0..3] of TPlatformThreadHandle;
  LConsumers: array[0..3] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI: Integer;
  LExpected: Int64;
begin
  GMpmcQ := TIntMpmc.Create(64);
  GMpmcSum := 0;
  for LI := 0 to 3 do
    platform_thread_create(LConsumers[LI], @MpmcConsumer, nil);
  for LI := 0 to 3 do
    platform_thread_create(LProducers[LI], @MpmcProducer, Pointer(PtrInt(LI * 250 + 1)));
  for LI := 0 to 3 do
    platform_thread_join(LProducers[LI], LRetVal);
  platform_thread_sleep_ns(10000000);
  GMpmcQ.Close;
  for LI := 0 to 3 do
    platform_thread_join(LConsumers[LI], LRetVal);
  LExpected := Int64(1000) * 1001 div 2;
  CheckEqual(LExpected, GMpmcSum, '4P+4C sum');
  GMpmcQ.Free;
end;

procedure TestCapacityZero;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    TIntSpsc.Create(0);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'SPSC rejects 0');
  LGot := False;
  try
    TIntMpmc.Create(0);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'MPMC rejects 0');
end;

{ SPSC Batch }

procedure TestSpscBatch;
var
  LQ: TIntSpsc;
  LIn: array[0..3] of Integer;
  LOut: array[0..3] of Integer;
  LN: PtrUInt;
begin
  LQ := TIntSpsc.Create(8);
  LIn[0] := 10; LIn[1] := 20; LIn[2] := 30; LIn[3] := 40;
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(4), Int64(LN), 'batch enq 4');
  LN := LQ.DequeueBatch(LOut, 4);
  CheckEqual(Int64(4), Int64(LN), 'batch deq 4');
  CheckEqual(Int64(10), Int64(LOut[0]));
  CheckEqual(Int64(40), Int64(LOut[3]));
  LQ.Free;
end;

{ MPMC Timeout }

procedure TestMpmcTimeout;
var
  LQ: TIntMpmc;
  LV: Integer;
begin
  LQ := TIntMpmc.Create(2);
  LQ.TryEnqueue(1);
  LQ.TryEnqueue(2);
  Check(not LQ.EnqueueTimeout(3, 1000000), 'enq timeout on full');
  Check(LQ.DequeueTimeout(LV, 1000000), 'deq immediate');
  CheckEqual(Int64(1), Int64(LV));
  Check(LQ.EnqueueTimeout(3, 1000000), 'enq after space');
  LQ.Free;
end;

{ Stack }

procedure TestStackBasic;
var
  LSt: TIntStack;
  LV: Integer;
begin
  LSt := TIntStack.Create;
  Check(LSt.IsEmpty, 'empty');
  LSt.Push(10);
  LSt.Push(20);
  LSt.Push(30);
  Check(not LSt.IsEmpty, 'not empty');
  Check(LSt.TryPop(LV), 'pop 1');
  CheckEqual(Int64(30), Int64(LV), 'LIFO');
  Check(LSt.TryPop(LV), 'pop 2');
  CheckEqual(Int64(20), Int64(LV));
  Check(LSt.TryPop(LV), 'pop 3');
  CheckEqual(Int64(10), Int64(LV));
  Check(not LSt.TryPop(LV), 'empty after pops');
  LSt.Free;
end;

{ MPSC }

var
  GMpscQ: TIntMpsc;

function MpscProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LStart: Integer;
begin
  Result := nil;
  LStart := Integer(PtrInt(AArg));
  for LI := LStart to LStart + 99 do
    GMpscQ.Enqueue(LI);
end;

procedure TestMpscBasic;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  Check(not LQ.TryDequeue(LV), 'empty');
  LQ.Enqueue(42);
  LQ.Enqueue(77);
  Check(LQ.TryDequeue(LV), 'deq 1');
  CheckEqual(Int64(42), Int64(LV));
  Check(LQ.TryDequeue(LV), 'deq 2');
  CheckEqual(Int64(77), Int64(LV));
  Check(not LQ.TryDequeue(LV), 'empty again');
  LQ.Free;
end;

procedure TestMpscMultiProducer;
var
  LHandles: array[0..3] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI, LV: Integer;
  LSum: Int64;
begin
  GMpscQ := TIntMpsc.Create;
  for LI := 0 to 3 do
    platform_thread_create(LHandles[LI], @MpscProducer, Pointer(PtrInt(LI * 100 + 1)));
  for LI := 0 to 3 do
    platform_thread_join(LHandles[LI], LRetVal);
  LSum := 0;
  while GMpscQ.TryDequeue(LV) do
    Inc(LSum, Int64(LV));
  CheckEqual(Int64(80200), LSum, '4 producers sum');
  GMpscQ.Free;
end;

{ Work-stealing Deque }

procedure TestDequeBasic;
var
  LD: TIntDeque;
  LV: Integer;
begin
  LD := TIntDeque.Create(8);
  Check(LD.IsEmpty, 'empty');
  Check(LD.TryPush(10), 'push 1');
  Check(LD.TryPush(20), 'push 2');
  Check(LD.TryPush(30), 'push 3');
  CheckEqual(Int64(3), Int64(LD.ApproxCount), 'count 3');
  Check(LD.TryPop(LV), 'pop');
  CheckEqual(Int64(30), Int64(LV), 'LIFO pop');
  Check(LD.TrySteal(LV), 'steal');
  CheckEqual(Int64(10), Int64(LV), 'FIFO steal');
  Check(LD.TryPop(LV), 'pop last');
  CheckEqual(Int64(20), Int64(LV));
  Check(LD.IsEmpty, 'empty after all');
  LD.Free;
end;

{ Additional coverage tests }

procedure TestSpscCapacity;
var
  LQ: TIntSpsc;
begin
  LQ := TIntSpsc.Create(16);
  CheckEqual(Int64(16), Int64(LQ.Capacity), 'capacity');
  Check(LQ.IsEmpty, 'empty');
  Check(not LQ.IsFull, 'not full');
  LQ.TryEnqueue(1);
  Check(not LQ.IsEmpty, 'not empty');
  LQ.Free;
end;

procedure TestMpmcBatch;
var
  LQ: TIntMpmc;
  LIn: array[0..3] of Integer;
  LOut: array[0..3] of Integer;
  LN: PtrUInt;
begin
  LQ := TIntMpmc.Create(8);
  LIn[0] := 5; LIn[1] := 6; LIn[2] := 7; LIn[3] := 8;
  LN := LQ.EnqueueBatch(LIn);
  CheckEqual(Int64(4), Int64(LN), 'mpmc batch enq');
  LN := LQ.DequeueBatch(LOut, 4);
  CheckEqual(Int64(4), Int64(LN), 'mpmc batch deq');
  CheckEqual(Int64(5), Int64(LOut[0]));
  CheckEqual(Int64(8), Int64(LOut[3]));
  LQ.Free;
end;

procedure TestMpmcCapacity;
var
  LQ: TIntMpmc;
begin
  LQ := TIntMpmc.Create(8);
  CheckEqual(Int64(8), Int64(LQ.Capacity));
  Check(LQ.IsEmpty, 'empty');
  Check(not LQ.IsFull, 'not full');
  LQ.Free;
end;

var
  GMpscWaitQ: TIntMpsc;

function MpscWaitProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  platform_thread_sleep_ns(5000000);
  for LI := 1 to 5 do
    GMpscWaitQ.Enqueue(LI);
  GMpscWaitQ.Close;
end;

procedure TestMpscDequeueWait;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LV, LSum: Integer;
begin
  GMpscWaitQ := TIntMpsc.Create;
  LSum := 0;
  platform_thread_create(LHandle, @MpscWaitProducer, nil);
  while GMpscWaitQ.DequeueWait(LV) do
    Inc(LSum, LV);
  platform_thread_join(LHandle, LRetVal);
  CheckEqual(Int64(15), Int64(LSum), '1+2+3+4+5');
  GMpscWaitQ.Free;
end;

procedure TestMpscDequeueTimeout;
var
  LQ: TIntMpsc;
  LV: Integer;
begin
  LQ := TIntMpsc.Create;
  Check(not LQ.DequeueTimeout(LV, 1000000), 'timeout 1ms on empty');
  LQ.Enqueue(42);
  Check(LQ.DequeueTimeout(LV, 1000000), 'immediate');
  CheckEqual(Int64(42), Int64(LV));
  LQ.Free;
end;

procedure TestDequeCapacity;
var
  LD: TIntDeque;
begin
  LD := TIntDeque.Create(32);
  CheckEqual(Int64(32), Int64(LD.Capacity));
  LD.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.lockfree');
  T.Run('SPSC basic', @TestSpscBasic);
  T.Run('SPSC close', @TestSpscClose);
  T.Run('SPSC approx count', @TestSpscApproxCount);
  T.Run('SPSC blocking', @TestSpscBlocking);
  T.Run('SPSC timeout', @TestSpscTimeout);
  T.Run('MPMC basic', @TestMpmcBasic);
  T.Run('MPMC close', @TestMpmcClose);
  T.Run('MPMC 4P+4C contention', @TestMpmcContention);
  T.Run('Capacity zero reject', @TestCapacityZero);
  T.Run('SPSC batch', @TestSpscBatch);
  T.Run('MPMC timeout', @TestMpmcTimeout);
  T.Run('Stack basic', @TestStackBasic);
  T.Run('MPSC basic', @TestMpscBasic);
  T.Run('MPSC multi-producer', @TestMpscMultiProducer);
  T.Run('Deque basic', @TestDequeBasic);
  T.Run('SPSC capacity/empty/full', @TestSpscCapacity);
  T.Run('MPMC batch', @TestMpmcBatch);
  T.Run('MPMC capacity/empty/full', @TestMpmcCapacity);
  T.Run('MPSC dequeue wait', @TestMpscDequeueWait);
  T.Run('MPSC dequeue timeout', @TestMpscDequeueTimeout);
  T.Run('Deque capacity', @TestDequeCapacity);

  T.Summary;
end.
