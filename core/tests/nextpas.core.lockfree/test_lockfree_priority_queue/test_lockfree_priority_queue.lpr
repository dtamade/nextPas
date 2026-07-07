program test_lockfree_priority_queue;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.priority_queue,
  nextpas.core.platform.thread;

type
  TIntPQ = specialize TConcurrentPriorityQueue<Integer>;

var
  T: TTestSuite;

function StartThread(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc; AArg: Pointer; const AMessage: string): Int32;
begin
  Result := platform_thread_create(AHandle, AProc, AArg);
  CheckEqual(Int64(0), Int64(Result), AMessage + ': platform_thread_create must succeed');
end;

procedure JoinThread(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer; const AMessage: string);
var
  LResult: Int32;
begin
  LResult := platform_thread_join(AHandle, ARetVal);
  CheckEqual(Int64(0), Int64(LResult), AMessage + ': platform_thread_join must succeed');
end;

procedure JoinStartedThreads(const AHandles: array of TPlatformThreadHandle; var AStartedCount: Integer; const AMessage: string);
var
  LI: Integer;
  LRetVal: Pointer;
begin
  for LI := 0 to AStartedCount - 1 do
    JoinThread(AHandles[LI], LRetVal, AMessage);
  AStartedCount := 0;
end;

function IntCompare(const ALeft, ARight: Integer): Integer;
begin
  if ALeft < ARight then
    Result := -1
  else if ALeft > ARight then
    Result := 1
  else
    Result := 0;
end;

{ ============================================================ }
{ TEST 1: Basic enqueue and dequeue                              }
{ ============================================================ }

procedure TestPriorityQueueBasic;
var
  LPQ: TIntPQ;
  LVal: Integer;
begin
  LPQ := TIntPQ.Create(@IntCompare);
  try
    Check(LPQ.IsEmpty, 'empty after create');
    CheckEqual(PtrUInt(0), LPQ.Count, 'count = 0');

    LPQ.Enqueue(3);
    LPQ.Enqueue(1);
    LPQ.Enqueue(2);

    Check(not LPQ.IsEmpty, 'not empty after enqueue');
    CheckEqual(PtrUInt(3), LPQ.Count, 'count = 3');

    Check(LPQ.TryDequeue(LVal), 'dequeue 1');
    CheckEqual(Int64(1), Int64(LVal), 'min = 1');
    Check(LPQ.TryDequeue(LVal), 'dequeue 2');
    CheckEqual(Int64(2), Int64(LVal), 'next = 2');
    Check(LPQ.TryDequeue(LVal), 'dequeue 3');
    CheckEqual(Int64(3), Int64(LVal), 'next = 3');

    Check(not LPQ.TryDequeue(LVal), 'dequeue empty returns false');
    Check(LPQ.IsEmpty, 'empty after dequeue all');
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 2: Peek                                                   }
{ ============================================================ }

procedure TestPriorityQueuePeek;
var
  LPQ: TIntPQ;
  LVal: Integer;
begin
  LPQ := TIntPQ.Create(@IntCompare);
  try
    Check(not LPQ.TryPeek(LVal), 'peek empty returns false');

    LPQ.Enqueue(5);
    LPQ.Enqueue(3);
    LPQ.Enqueue(7);

    Check(LPQ.TryPeek(LVal), 'peek returns true');
    CheckEqual(Int64(3), Int64(LVal), 'peek = min = 3');
    CheckEqual(PtrUInt(3), LPQ.Count, 'peek does not remove');
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 3: Clear                                                  }
{ ============================================================ }

procedure TestPriorityQueueClear;
var
  LPQ: TIntPQ;
begin
  LPQ := TIntPQ.Create(@IntCompare);
  try
    LPQ.Enqueue(1);
    LPQ.Enqueue(2);
    LPQ.Enqueue(3);
    CheckEqual(PtrUInt(3), LPQ.Count, 'count before clear');

    LPQ.Clear;
    Check(LPQ.IsEmpty, 'empty after clear');
    CheckEqual(PtrUInt(0), LPQ.Count, 'count = 0 after clear');
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 4: Large batch enqueue/dequeue                            }
{ ============================================================ }

procedure TestPriorityQueueLargeBatch;
var
  LPQ: TIntPQ;
  LI, LVal, LPrev: Integer;
begin
  LPQ := TIntPQ.Create(@IntCompare, 16);
  try
    for LI := 1000 downto 1 do
      LPQ.Enqueue(LI);

    CheckEqual(PtrUInt(1000), LPQ.Count, 'count = 1000');

    LPrev := 0;
    for LI := 1 to 1000 do
    begin
      Check(LPQ.TryDequeue(LVal), 'dequeue ' + IntToStr(LI));
      Check(LVal > LPrev, 'sorted order: ' + IntToStr(LVal) + ' > ' + IntToStr(LPrev));
      LPrev := LVal;
    end;

    Check(LPQ.IsEmpty, 'empty after dequeue all');
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 5: Duplicate values                                       }
{ ============================================================ }

procedure TestPriorityQueueDuplicates;
var
  LPQ: TIntPQ;
  LVal: Integer;
begin
  LPQ := TIntPQ.Create(@IntCompare);
  try
    LPQ.Enqueue(5);
    LPQ.Enqueue(5);
    LPQ.Enqueue(5);
    LPQ.Enqueue(3);
    LPQ.Enqueue(3);

    CheckEqual(PtrUInt(5), LPQ.Count, 'count = 5');

    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(3), Int64(LVal), 'first = 3');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(3), Int64(LVal), 'second = 3');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(5), Int64(LVal), 'third = 5');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(5), Int64(LVal), 'fourth = 5');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(5), Int64(LVal), 'fifth = 5');
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 6: Auto-grow                                              }
{ ============================================================ }

procedure TestPriorityQueueAutoGrow;
var
  LPQ: TIntPQ;
  LI, LVal: Integer;
begin
  LPQ := TIntPQ.Create(@IntCompare, 2); // tiny initial capacity
  try
    for LI := 1 to 100 do
      LPQ.Enqueue(LI);

    CheckEqual(PtrUInt(100), LPQ.Count, 'count = 100');
    Check(LPQ.Capacity >= 100, 'capacity grew');

    for LI := 1 to 100 do
    begin
      Check(LPQ.TryDequeue(LVal), 'dequeue');
      CheckEqual(Int64(LI), Int64(LVal), 'sorted ' + IntToStr(LI));
    end;
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 7: Concurrent enqueue + dequeue                           }
{ ============================================================ }

const
  PQ_CONCURRENCY_PRODUCERS = 4;
  PQ_CONCURRENCY_CONSUMERS = 2;
  PQ_CONCURRENCY_PER_PRODUCER = 5000;
  PQ_CONCURRENCY_TOTAL = PQ_CONCURRENCY_PRODUCERS * PQ_CONCURRENCY_PER_PRODUCER;

var
  GPQ: TIntPQ;
  GPQConsumed: array[0..PQ_CONCURRENCY_TOTAL - 1] of Int32;
  GPQConsumeCount: Int64;

function PQProducer(AArg: Pointer): Pointer; cdecl;
var
  LBase, LI: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * PQ_CONCURRENCY_PER_PRODUCER;
  for LI := 0 to PQ_CONCURRENCY_PER_PRODUCER - 1 do
    GPQ.Enqueue(LBase + LI + 1);
end;

function PQConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while AtomicLoad64(GPQConsumeCount, moAcquire) < PQ_CONCURRENCY_TOTAL do
  begin
    if GPQ.TryDequeue(LV) then
    begin
      if (LV >= 1) and (LV <= PQ_CONCURRENCY_TOTAL) then
        AtomicFetchAdd32(GPQConsumed[LV - 1], 1, moRelaxed);
      AtomicFetchAdd64(GPQConsumeCount, 1, moRelaxed);
    end
    else
      CpuPause;
  end;
end;

procedure TestPriorityQueueConcurrent;
var
  LProducers: array[0..PQ_CONCURRENCY_PRODUCERS - 1] of TPlatformThreadHandle;
  LConsumers: array[0..PQ_CONCURRENCY_CONSUMERS - 1] of TPlatformThreadHandle;
  LI: Integer;
  LDups, LMissing: Integer;
  LProducerCount, LConsumerCount: Integer;
  LSeen: Int32;
begin
  GPQ := TIntPQ.Create(@IntCompare);
  GPQConsumeCount := 0;
  LProducerCount := 0;
  LConsumerCount := 0;
  for LI := 0 to PQ_CONCURRENCY_TOTAL - 1 do
    GPQConsumed[LI] := 0;
  try
    for LI := 0 to PQ_CONCURRENCY_CONSUMERS - 1 do
    begin
      StartThread(LConsumers[LI], @PQConsumer, nil, 'PQ consumer');
      Inc(LConsumerCount);
    end;
    for LI := 0 to PQ_CONCURRENCY_PRODUCERS - 1 do
    begin
      StartThread(LProducers[LI], @PQProducer, Pointer(PtrInt(LI)), 'PQ producer');
      Inc(LProducerCount);
    end;

    JoinStartedThreads(LProducers, LProducerCount, 'PQ producer');
    while AtomicLoad64(GPQConsumeCount, moAcquire) < PQ_CONCURRENCY_TOTAL do
      platform_thread_sleep_ns(1000000);
    JoinStartedThreads(LConsumers, LConsumerCount, 'PQ consumer');

    CheckEqual(Int64(PQ_CONCURRENCY_TOTAL), AtomicLoad64(GPQConsumeCount, moAcquire), 'consumed all');

    LDups := 0;
    LMissing := 0;
    for LI := 0 to PQ_CONCURRENCY_TOTAL - 1 do
    begin
      LSeen := AtomicLoad32(GPQConsumed[LI], moRelaxed);
      if LSeen = 0 then
        Inc(LMissing)
      else if LSeen > 1 then
        Inc(LDups);
    end;
    CheckEqual(Int64(0), Int64(LMissing), 'no missing');
    CheckEqual(Int64(0), Int64(LDups), 'no duplicates');
  finally
    JoinStartedThreads(LProducers, LProducerCount, 'PQ producer');
    JoinStartedThreads(LConsumers, LConsumerCount, 'PQ consumer');
    GPQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 8: Max-heap via reversed compare                         }
{ ============================================================ }

function IntCompareReversed(const ALeft, ARight: Integer): Integer;
begin
  if ALeft > ARight then
    Result := -1
  else if ALeft < ARight then
    Result := 1
  else
    Result := 0;
end;

procedure TestPriorityQueueMaxHeap;
var
  LPQ: TIntPQ;
  LVal: Integer;
begin
  LPQ := TIntPQ.Create(@IntCompareReversed);
  try
    LPQ.Enqueue(1);
    LPQ.Enqueue(3);
    LPQ.Enqueue(2);
    LPQ.Enqueue(5);
    LPQ.Enqueue(4);

    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(5), Int64(LVal), 'max = 5');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(4), Int64(LVal), 'next = 4');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(3), Int64(LVal), 'next = 3');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(2), Int64(LVal), 'next = 2');
    Check(LPQ.TryDequeue(LVal), 'dequeue');
    CheckEqual(Int64(1), Int64(LVal), 'min = 1');
  finally
    LPQ.Free;
  end;
end;

{ ============================================================ }
{ Main                                                           }
{ ============================================================ }

begin
  T := TTestSuite.Create('nextpas.core.lockfree.priority_queue');
  T.Test('Basic enqueue/dequeue (min-heap order)', @TestPriorityQueueBasic);
  T.Test('Peek without dequeue', @TestPriorityQueuePeek);
  T.Test('Clear', @TestPriorityQueueClear);
  T.Test('Large batch (1000 items, sorted output)', @TestPriorityQueueLargeBatch);
  T.Test('Duplicate values', @TestPriorityQueueDuplicates);
  T.Test('Auto-grow from capacity 2', @TestPriorityQueueAutoGrow);
  T.Test('Concurrent 4P+2C (20K items, exactly-once)', @TestPriorityQueueConcurrent);
  T.Test('Max-heap via reversed compare', @TestPriorityQueueMaxHeap);
  if not T.Run then Halt(1);
end.
