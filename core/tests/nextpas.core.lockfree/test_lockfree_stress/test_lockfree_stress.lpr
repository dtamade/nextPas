program test_lockfree_stress;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.atomic,
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

procedure JoinStartedThread(const AHandle: TPlatformThreadHandle; var AStarted: Boolean; const AMessage: string);
var
  LRetVal: Pointer;
begin
  if not AStarted then
    Exit;
  JoinThread(AHandle, LRetVal, AMessage);
  AStarted := False;
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

{ ============================================================ }
{ TEST 1: MPMC Saturation Contention                           }
{ 8P + 8C, capacity=16, 80K messages, exactly-once delivery    }
{ ============================================================ }

const
  MPMC_SAT_PRODUCERS = 8;
  MPMC_SAT_CONSUMERS = 8;
  MPMC_SAT_PER_PRODUCER = 10000;
  MPMC_SAT_TOTAL = MPMC_SAT_PRODUCERS * MPMC_SAT_PER_PRODUCER;
  MPMC_SAT_CAPACITY = 16;

var
  GMpmcSatQ: TIntMpmc;
  GMpmcSatConsumed: array[0..MPMC_SAT_TOTAL - 1] of Int32;
  GMpmcSatConsumeCount: Int64;

function MpmcSatProducer(AArg: Pointer): Pointer; cdecl;
var
  LBase, LI: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * MPMC_SAT_PER_PRODUCER;
  for LI := 0 to MPMC_SAT_PER_PRODUCER - 1 do
    GMpmcSatQ.EnqueueWait(LBase + LI);
end;

function MpmcSatConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GMpmcSatQ.DequeueWait(LV) do
  begin
    AtomicFetchAdd32(GMpmcSatConsumed[LV], 1, moRelaxed);
    AtomicFetchAdd64(GMpmcSatConsumeCount, 1, moRelaxed);
  end;
end;

procedure TestMpmcSaturation;
var
  LProducers: array[0..MPMC_SAT_PRODUCERS - 1] of TPlatformThreadHandle;
  LConsumers: array[0..MPMC_SAT_CONSUMERS - 1] of TPlatformThreadHandle;
  LI: Integer;
  LDups, LMissing: Integer;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  GMpmcSatQ := TIntMpmc.Create(MPMC_SAT_CAPACITY);
  GMpmcSatConsumeCount := 0;
  LProducerCount := 0;
  LConsumerCount := 0;
  for LI := 0 to MPMC_SAT_TOTAL - 1 do
    GMpmcSatConsumed[LI] := 0;
  try
    for LI := 0 to MPMC_SAT_CONSUMERS - 1 do
    begin
      StartThread(LConsumers[LI], @MpmcSatConsumer, nil, 'MPMC saturation consumer thread');
      Inc(LConsumerCount);
    end;
    for LI := 0 to MPMC_SAT_PRODUCERS - 1 do
    begin
      StartThread(LProducers[LI], @MpmcSatProducer, Pointer(PtrInt(LI)), 'MPMC saturation producer thread');
      Inc(LProducerCount);
    end;

    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');

    { All producers done; wait briefly then close to signal consumers }
    platform_thread_sleep_ns(5000000);
    GMpmcSatQ.Close;

    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');

    { Verify exactly-once delivery }
    CheckEqual(Int64(MPMC_SAT_TOTAL), GMpmcSatConsumeCount, 'total consumed = 80000');
    LDups := 0;
    LMissing := 0;
    for LI := 0 to MPMC_SAT_TOTAL - 1 do
    begin
      if AtomicLoad32(GMpmcSatConsumed[LI], moRelaxed) = 0 then
        Inc(LMissing)
      else if AtomicLoad32(GMpmcSatConsumed[LI], moRelaxed) > 1 then
        Inc(LDups);
    end;
    CheckEqual(Int64(0), Int64(LMissing), 'no missing messages');
    CheckEqual(Int64(0), Int64(LDups), 'no duplicate messages');
  finally
    GMpmcSatQ.Close;
    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');
    GMpmcSatQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 1B: MPMC Single-Slot Contention                         }
{ 2P + 2C, capacity=1, exactly-once delivery                   }
{ ============================================================ }

const
  MPMC_SINGLE_SLOT_PRODUCERS = 2;
  MPMC_SINGLE_SLOT_CONSUMERS = 2;
  MPMC_SINGLE_SLOT_PER_PRODUCER = 2000;
  MPMC_SINGLE_SLOT_TOTAL = MPMC_SINGLE_SLOT_PRODUCERS * MPMC_SINGLE_SLOT_PER_PRODUCER;

var
  GMpmcSingleSlotQ: TIntMpmc;
  GMpmcSingleSlotConsumed: array[0..MPMC_SINGLE_SLOT_TOTAL - 1] of Int32;
  GMpmcSingleSlotConsumeCount: Int64;
  GMpmcSingleSlotOutOfRangeCount: Int64;

function MpmcSingleSlotProducer(AArg: Pointer): Pointer; cdecl;
var
  LBase, LI: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * MPMC_SINGLE_SLOT_PER_PRODUCER;
  for LI := 0 to MPMC_SINGLE_SLOT_PER_PRODUCER - 1 do
    GMpmcSingleSlotQ.EnqueueWait(LBase + LI);
end;

function MpmcSingleSlotConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GMpmcSingleSlotQ.DequeueWait(LV) do
  begin
    if (LV >= 0) and (LV < MPMC_SINGLE_SLOT_TOTAL) then
      AtomicFetchAdd32(GMpmcSingleSlotConsumed[LV], 1, moRelaxed)
    else
      AtomicFetchAdd64(GMpmcSingleSlotOutOfRangeCount, 1, moRelaxed);
    AtomicFetchAdd64(GMpmcSingleSlotConsumeCount, 1, moRelaxed);
  end;
end;

procedure TestMpmcSingleSlotContention;
var
  LProducers: array[0..MPMC_SINGLE_SLOT_PRODUCERS - 1] of TPlatformThreadHandle;
  LConsumers: array[0..MPMC_SINGLE_SLOT_CONSUMERS - 1] of TPlatformThreadHandle;
  LI: Integer;
  LDups, LMissing: Integer;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  GMpmcSingleSlotQ := TIntMpmc.Create(1);
  GMpmcSingleSlotConsumeCount := 0;
  GMpmcSingleSlotOutOfRangeCount := 0;
  LProducerCount := 0;
  LConsumerCount := 0;
  for LI := 0 to MPMC_SINGLE_SLOT_TOTAL - 1 do
    GMpmcSingleSlotConsumed[LI] := 0;
  try
    for LI := 0 to MPMC_SINGLE_SLOT_CONSUMERS - 1 do
    begin
      StartThread(LConsumers[LI], @MpmcSingleSlotConsumer, nil, 'MPMC single-slot consumer thread');
      Inc(LConsumerCount);
    end;
    for LI := 0 to MPMC_SINGLE_SLOT_PRODUCERS - 1 do
    begin
      StartThread(LProducers[LI], @MpmcSingleSlotProducer, Pointer(PtrInt(LI)), 'MPMC single-slot producer thread');
      Inc(LProducerCount);
    end;

    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    GMpmcSingleSlotQ.Close;
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');

    CheckEqual(Int64(MPMC_SINGLE_SLOT_TOTAL), GMpmcSingleSlotConsumeCount,
      'single-slot contention total consumed');
    CheckEqual(Int64(0), GMpmcSingleSlotOutOfRangeCount,
      'single-slot contention no out-of-range messages');
    LDups := 0;
    LMissing := 0;
    for LI := 0 to MPMC_SINGLE_SLOT_TOTAL - 1 do
    begin
      if AtomicLoad32(GMpmcSingleSlotConsumed[LI], moRelaxed) = 0 then
        Inc(LMissing)
      else if AtomicLoad32(GMpmcSingleSlotConsumed[LI], moRelaxed) > 1 then
        Inc(LDups);
    end;
    CheckEqual(Int64(0), Int64(LMissing), 'single-slot contention no missing messages');
    CheckEqual(Int64(0), Int64(LDups), 'single-slot contention no duplicate messages');
  finally
    GMpmcSingleSlotQ.Close;
    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');
    GMpmcSingleSlotQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 2: Stack ABA Stress                                     }
{ 4 threads, capacity=4, 100K unique push+pop cycles each      }
{ Verify: exactly-once ownership, empty stack, no leak          }
{ ============================================================ }

const
  STACK_ABA_THREADS = 4;
  STACK_ABA_OPS = 100000;
  STACK_ABA_TOTAL = STACK_ABA_THREADS * STACK_ABA_OPS;

var
  GStackABA: TIntStack;
  GStackABASeen: array[0..STACK_ABA_TOTAL - 1] of Int32;
  GStackABAOutOfRange: Int64;
  GStackABAPushOk: Int64;
  GStackABAPopOk: Int64;

function StackABAWorker(AArg: Pointer): Pointer; cdecl;
var
  LBase, LI, LV: Integer;
  LPushed, LPopped: Int64;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * STACK_ABA_OPS;
  LPushed := 0;
  LPopped := 0;
  for LI := 0 to STACK_ABA_OPS - 1 do
  begin
    { Push - spin if full (only 4 slots!) }
    while not GStackABA.TryPush(LBase + LI) do
      CpuPause;
    Inc(LPushed);
    { Pop - spin if empty }
    while not GStackABA.TryPop(LV) do
      CpuPause;
    if (LV >= 0) and (LV < STACK_ABA_TOTAL) then
      AtomicFetchAdd32(GStackABASeen[LV], 1, moRelaxed)
    else
      AtomicFetchAdd64(GStackABAOutOfRange, 1, moRelaxed);
    Inc(LPopped);
  end;
  AtomicFetchAdd64(GStackABAPushOk, LPushed, moRelaxed);
  AtomicFetchAdd64(GStackABAPopOk, LPopped, moRelaxed);
end;

procedure TestStackABA;
var
  LHandles: array[0..STACK_ABA_THREADS - 1] of TPlatformThreadHandle;
  LI: Integer;
  LHandleCount: Integer;
  LDups: Integer;
  LMissing: Integer;
begin
  GStackABA := TIntStack.Create(4);
  GStackABAOutOfRange := 0;
  GStackABAPushOk := 0;
  GStackABAPopOk := 0;
  LHandleCount := 0;
  for LI := 0 to STACK_ABA_TOTAL - 1 do
    GStackABASeen[LI] := 0;
  try
    for LI := 0 to STACK_ABA_THREADS - 1 do
    begin
      StartThread(LHandles[LI], @StackABAWorker, Pointer(PtrInt(LI)), 'stack ABA worker thread');
      Inc(LHandleCount);
    end;
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');

    CheckEqual(Int64(STACK_ABA_THREADS) * STACK_ABA_OPS, GStackABAPushOk, 'all pushes succeeded');
    CheckEqual(Int64(STACK_ABA_THREADS) * STACK_ABA_OPS, GStackABAPopOk, 'all pops succeeded');
    CheckEqual(Int64(0), GStackABAOutOfRange, 'stack ABA no out-of-range tokens');
    LDups := 0;
    LMissing := 0;
    for LI := 0 to STACK_ABA_TOTAL - 1 do
    begin
      if AtomicLoad32(GStackABASeen[LI], moRelaxed) = 0 then
        Inc(LMissing)
      else if AtomicLoad32(GStackABASeen[LI], moRelaxed) > 1 then
        Inc(LDups);
    end;
    CheckEqual(Int64(0), Int64(LMissing), 'stack ABA no missing tokens');
    CheckEqual(Int64(0), Int64(LDups), 'stack ABA no duplicate tokens');
    Check(GStackABA.IsEmpty, 'stack empty after ABA stress');
  finally
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');
    GStackABA.Free;
  end;
end;

{ ============================================================ }
{ TEST 3: MPSC High-Frequency Close Race                       }
{ 4 producers enqueue continuously                             }
{ 1 consumer closes at random moment                           }
{ Verify: clean shutdown, no hang, no leak                     }
{ ============================================================ }

const
  MPSC_CLOSE_PRODUCERS = 4;

var
  GMpscCloseQ: TIntMpsc;
  GMpscCloseSent: array[0..MPSC_CLOSE_PRODUCERS - 1] of Int64;
  GMpscCloseReceived: Int64;

function MpscCloseProducer(AArg: Pointer): Pointer; cdecl;
var
  LIdx, LCount: Integer;
begin
  Result := nil;
  LIdx := Integer(PtrUInt(AArg));
  LCount := 0;
  while not GMpscCloseQ.IsClosed do
  begin
    GMpscCloseQ.Enqueue(LIdx * 1000000 + LCount);
    Inc(LCount);
    if LCount and $FF = 0 then
      CpuPause;
  end;
  AtomicStore64(GMpscCloseSent[LIdx], Int64(LCount), moRelease);
end;

procedure TestMpscCloseRace;
var
  LHandles: array[0..MPSC_CLOSE_PRODUCERS - 1] of TPlatformThreadHandle;
  LI, LV: Integer;
  LTotalSent, LTotalRecv: Int64;
  LHandleCount: Integer;
begin
  GMpscCloseQ := TIntMpsc.Create;
  GMpscCloseReceived := 0;
  LHandleCount := 0;
  for LI := 0 to MPSC_CLOSE_PRODUCERS - 1 do
    GMpscCloseSent[LI] := 0;
  try
    for LI := 0 to MPSC_CLOSE_PRODUCERS - 1 do
    begin
      StartThread(LHandles[LI], @MpscCloseProducer, Pointer(PtrInt(LI)), 'MPSC close producer thread');
      Inc(LHandleCount);
    end;

    { Let producers run ~10ms then close }
    platform_thread_sleep_ns(10000000);
    GMpscCloseQ.Close;

    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');

    { Drain remaining }
    LTotalRecv := 0;
    while GMpscCloseQ.TryDequeue(LV) do
      Inc(LTotalRecv);

    LTotalSent := 0;
    for LI := 0 to MPSC_CLOSE_PRODUCERS - 1 do
      Inc(LTotalSent, AtomicLoad64(GMpscCloseSent[LI], moAcquire));

    Check(LTotalSent > 0, 'producers sent messages before close');
    Check(LTotalRecv <= LTotalSent, 'received <= sent');
    Check(GMpscCloseQ.IsEmpty, 'queue drained after close');
  finally
    GMpscCloseQ.Close;
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');
    while GMpscCloseQ.TryDequeue(LV) do;
    GMpscCloseQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 4: Chase-Lev Extreme Steal Contention                   }
{ 1 owner pushes 200K items, 7 thieves steal concurrently      }
{ Verify: all values consumed exactly once                     }
{ ============================================================ }

const
  DEQUE_STEAL_TOTAL = 200000;
  DEQUE_STEAL_THIEVES = 7;
  DEQUE_STEAL_CAPACITY = 256;

var
  GDequeStealD: TIntDeque;
  GDequeStealDone: Int32;
  GDequeStealBitmap: array[0..DEQUE_STEAL_TOTAL - 1] of Int32;
  GDequeStealThiefCount: Int64;

function DequeStealThief(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LCount: Int64;
begin
  Result := nil;
  LCount := 0;
  while AtomicLoad32(GDequeStealDone, moAcquire) = 0 do
  begin
    if GDequeStealD.TrySteal(LV) then
    begin
      AtomicFetchAdd32(GDequeStealBitmap[LV], 1, moRelaxed);
      Inc(LCount);
    end
    else
      CpuPause;
  end;
  { Final drain after owner signals done }
  while GDequeStealD.TrySteal(LV) do
  begin
    AtomicFetchAdd32(GDequeStealBitmap[LV], 1, moRelaxed);
    Inc(LCount);
  end;
  AtomicFetchAdd64(GDequeStealThiefCount, LCount, moRelaxed);
end;

procedure TestDequeExtremeSteal;
var
  LThieves: array[0..DEQUE_STEAL_THIEVES - 1] of TPlatformThreadHandle;
  LI, LV: Integer;
  LOwnerPop: Int64;
  LDups, LMissing: Integer;
  LThiefCount: Integer;
begin
  GDequeStealD := TIntDeque.Create(DEQUE_STEAL_CAPACITY);
  GDequeStealDone := 0;
  GDequeStealThiefCount := 0;
  LOwnerPop := 0;
  LThiefCount := 0;
  for LI := 0 to DEQUE_STEAL_TOTAL - 1 do
    GDequeStealBitmap[LI] := 0;
  try
    for LI := 0 to DEQUE_STEAL_THIEVES - 1 do
    begin
      StartThread(LThieves[LI], @DequeStealThief, Pointer(PtrInt(LI)), 'deque steal thief thread');
      Inc(LThiefCount);
    end;

    { Owner: push all items, pop when full to make room }
    for LI := 0 to DEQUE_STEAL_TOTAL - 1 do
    begin
      while not GDequeStealD.TryPush(LI) do
      begin
        if GDequeStealD.TryPop(LV) then
        begin
          AtomicFetchAdd32(GDequeStealBitmap[LV], 1, moRelaxed);
          Inc(LOwnerPop);
        end;
      end;
    end;

    { Owner drains remaining }
    while GDequeStealD.TryPop(LV) do
    begin
      AtomicFetchAdd32(GDequeStealBitmap[LV], 1, moRelaxed);
      Inc(LOwnerPop);
    end;

    { Signal thieves to stop }
    AtomicStore32(GDequeStealDone, 1, moRelease);
    JoinStartedThreads(LThieves, LThiefCount, 'deque steal thief thread');

    { Verify exactly-once }
    LDups := 0;
    LMissing := 0;
    for LI := 0 to DEQUE_STEAL_TOTAL - 1 do
    begin
      if AtomicLoad32(GDequeStealBitmap[LI], moRelaxed) = 0 then
        Inc(LMissing)
      else if AtomicLoad32(GDequeStealBitmap[LI], moRelaxed) > 1 then
        Inc(LDups);
    end;
    CheckEqual(Int64(0), Int64(LMissing), 'deque no missing');
    CheckEqual(Int64(0), Int64(LDups), 'deque no duplicates');
    CheckEqual(Int64(DEQUE_STEAL_TOTAL), LOwnerPop + GDequeStealThiefCount, 'total = pushed');
  finally
    AtomicStore32(GDequeStealDone, 1, moRelease);
    JoinStartedThreads(LThieves, LThiefCount, 'deque steal thief thread');
    GDequeStealD.Free;
  end;
end;

{ ============================================================ }
{ TEST 5: SPSC Full + Close Race                               }
{ Producer fills at max speed, consumer closes when full        }
{ Verify: no deadlock, both threads exit cleanly               }
{ ============================================================ }

const
  SPSC_CLOSE_CAPACITY = 32;
  SPSC_CLOSE_SEND_TARGET = 100000;

var
  GSpscCloseQ: TIntSpsc;
  GSpscCloseSent: Int64;
  GSpscCloseRecv: Int64;

function SpscCloseProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  LI := 0;
  while LI < SPSC_CLOSE_SEND_TARGET do
  begin
    if GSpscCloseQ.IsClosed then
      Break;
    if GSpscCloseQ.TryEnqueue(LI) then
      Inc(LI)
    else
    begin
      { Use timeout to avoid deadlock if consumer closes }
      if not GSpscCloseQ.EnqueueTimeout(LI, 1000000) then
      begin
        if GSpscCloseQ.IsClosed then
          Break;
      end
      else
        Inc(LI);
    end;
  end;
  AtomicStore64(GSpscCloseSent, Int64(LI), moRelease);
end;

function SpscCloseConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LCount: Int64;
begin
  Result := nil;
  LCount := 0;
  { Consume some items then close abruptly while queue is likely full }
  while LCount < 1000 do
  begin
    if GSpscCloseQ.DequeueTimeout(LV, 1000000) then
      Inc(LCount)
    else if GSpscCloseQ.IsClosed then
      Break;
  end;
  { Close while producer is likely blocked on full queue }
  GSpscCloseQ.Close;
  { Drain remaining }
  while GSpscCloseQ.TryDequeue(LV) do
    Inc(LCount);
  AtomicStore64(GSpscCloseRecv, LCount, moRelease);
end;

procedure TestSpscFullClose;
var
  LProd, LCons: TPlatformThreadHandle;
  LProducerStarted: Boolean;
  LConsumerStarted: Boolean;
begin
  GSpscCloseQ := TIntSpsc.Create(SPSC_CLOSE_CAPACITY);
  GSpscCloseSent := 0;
  GSpscCloseRecv := 0;
  LProducerStarted := False;
  LConsumerStarted := False;
  try
    StartThread(LCons, @SpscCloseConsumer, nil, 'SPSC close consumer thread');
    LConsumerStarted := True;
    StartThread(LProd, @SpscCloseProducer, nil, 'SPSC close producer thread');
    LProducerStarted := True;

    JoinStartedThread(LProd, LProducerStarted, 'SPSC close producer thread');
    JoinStartedThread(LCons, LConsumerStarted, 'SPSC close consumer thread');

    { Key invariant: no deadlock (we reached here), received <= sent }
    Check(GSpscCloseRecv > 0, 'consumer received items');
    Check(GSpscCloseRecv <= GSpscCloseSent, 'recv <= sent');
    Check(GSpscCloseQ.IsClosed, 'queue is closed');
  finally
    GSpscCloseQ.Close;
    JoinStartedThread(LProd, LProducerStarted, 'SPSC close producer thread');
    JoinStartedThread(LCons, LConsumerStarted, 'SPSC close consumer thread');
    GSpscCloseQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 6: MPMC Rapid Create/Close Cycles                       }
{ 50 rounds of create-blast-close to catch init/teardown races }
{ ============================================================ }

const
  MPMC_CYCLE_ROUNDS = 50;
  MPMC_CYCLE_PRODUCERS = 4;
  MPMC_CYCLE_PER_PRODUCER = 500;
  MPMC_CYCLE_CAPACITY = 8;

var
  GMpmcCycleQ: TIntMpmc;
  GMpmcCycleSum: Int64;

function MpmcCycleProducer(AArg: Pointer): Pointer; cdecl;
var
  LBase, LI: Integer;
begin
  Result := nil;
  LBase := Integer(PtrUInt(AArg)) * MPMC_CYCLE_PER_PRODUCER + 1;
  for LI := LBase to LBase + MPMC_CYCLE_PER_PRODUCER - 1 do
    GMpmcCycleQ.EnqueueWait(LI);
end;

function MpmcCycleConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LSum: Int64;
begin
  Result := nil;
  LSum := 0;
  while GMpmcCycleQ.DequeueWait(LV) do
    Inc(LSum, Int64(LV));
  AtomicFetchAdd64(GMpmcCycleSum, LSum, moRelaxed);
end;

procedure TestMpmcRapidCycles;
var
  LProducers: array[0..MPMC_CYCLE_PRODUCERS - 1] of TPlatformThreadHandle;
  LConsumers: array[0..1] of TPlatformThreadHandle;
  LRound, LI: Integer;
  LExpected: Int64;
  LTotal: Integer;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  for LRound := 0 to MPMC_CYCLE_ROUNDS - 1 do
  begin
    GMpmcCycleQ := TIntMpmc.Create(MPMC_CYCLE_CAPACITY);
    GMpmcCycleSum := 0;
    LProducerCount := 0;
    LConsumerCount := 0;
    try
      for LI := 0 to 1 do
      begin
        StartThread(LConsumers[LI], @MpmcCycleConsumer, nil, 'MPMC cycle consumer thread');
        Inc(LConsumerCount);
      end;
      for LI := 0 to MPMC_CYCLE_PRODUCERS - 1 do
      begin
        StartThread(LProducers[LI], @MpmcCycleProducer, Pointer(PtrInt(LI)), 'MPMC cycle producer thread');
        Inc(LProducerCount);
      end;

      JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
      platform_thread_sleep_ns(1000000);
      GMpmcCycleQ.Close;
      JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');

      LTotal := MPMC_CYCLE_PRODUCERS * MPMC_CYCLE_PER_PRODUCER;
      LExpected := Int64(LTotal) * (LTotal + 1) div 2;
      CheckEqual(LExpected, GMpmcCycleSum, 'cycle ' + IntToStr(LRound));
    finally
      GMpmcCycleQ.Close;
      JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
      JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');
      GMpmcCycleQ.Free;
    end;
  end;
end;

{ ============================================================ }
{ TEST 6B: MPMC Close Races Active Producers                   }
{ Close while producers are live; consumed must match accepted  }
{ ============================================================ }

const
  MPMC_CLOSE_RACE_PRODUCERS = 6;
  MPMC_CLOSE_RACE_CONSUMERS = 4;
  MPMC_CLOSE_RACE_CAPACITY = 4;
  MPMC_CLOSE_RACE_MAX_VALUES = 65536;

var
  GMpmcCloseRaceQ: TIntMpmc;
  GMpmcCloseRaceStart: Int32;
  GMpmcCloseRaceStarted: Int32;
  GMpmcCloseRaceDone: Int32;
  GMpmcCloseRaceNextValue: Int64;
  GMpmcCloseRacePublished: Int64;
  GMpmcCloseRaceConsumed: Int64;
  GMpmcCloseRaceOutOfRange: Int64;
  GMpmcCloseRaceConsumedMap: array[0..MPMC_CLOSE_RACE_MAX_VALUES - 1] of Int32;

function MpmcCloseRaceProducer(AArg: Pointer): Pointer; cdecl;
var
  LValue: Integer;
begin
  Result := nil;
  AtomicFetchAdd32(GMpmcCloseRaceStarted, 1, moAcqRel);
  while AtomicLoad32(GMpmcCloseRaceStart, moAcquire) = 0 do
    CpuPause;

  while True do
  begin
    LValue := Integer(AtomicFetchAdd64(GMpmcCloseRaceNextValue, 1, moRelaxed));
    if LValue >= MPMC_CLOSE_RACE_MAX_VALUES then
      Break;
    if GMpmcCloseRaceQ.TryEnqueue(LValue) then
      AtomicFetchAdd64(GMpmcCloseRacePublished, 1, moRelease)
    else if GMpmcCloseRaceQ.IsClosed then
      Break
    else
      CpuPause;
  end;
  AtomicFetchAdd32(GMpmcCloseRaceDone, 1, moAcqRel);
end;

function MpmcCloseRaceConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GMpmcCloseRaceQ.DequeueWait(LV) do
  begin
    if (LV >= 0) and (LV < MPMC_CLOSE_RACE_MAX_VALUES) then
      AtomicFetchAdd32(GMpmcCloseRaceConsumedMap[LV], 1, moRelaxed)
    else
      AtomicFetchAdd64(GMpmcCloseRaceOutOfRange, 1, moRelaxed);
    AtomicFetchAdd64(GMpmcCloseRaceConsumed, 1, moRelease);
  end;
end;

function MpmcCloseRaceTimeoutConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
begin
  Result := nil;
  while GMpmcCloseRaceQ.DequeueTimeout(LV, 1000000000) do
  begin
    if (LV >= 0) and (LV < MPMC_CLOSE_RACE_MAX_VALUES) then
      AtomicFetchAdd32(GMpmcCloseRaceConsumedMap[LV], 1, moRelaxed)
    else
      AtomicFetchAdd64(GMpmcCloseRaceOutOfRange, 1, moRelaxed);
    AtomicFetchAdd64(GMpmcCloseRaceConsumed, 1, moRelease);
  end;
end;

procedure TestMpmcCloseRacesActiveProducers;
var
  LProducers: array[0..MPMC_CLOSE_RACE_PRODUCERS - 1] of TPlatformThreadHandle;
  LConsumers: array[0..MPMC_CLOSE_RACE_CONSUMERS - 1] of TPlatformThreadHandle;
  LI, LDuplicates: Integer;
  LV: Integer;
  LLeftover: Int64;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  GMpmcCloseRaceQ := TIntMpmc.Create(MPMC_CLOSE_RACE_CAPACITY);
  LProducerCount := 0;
  LConsumerCount := 0;
  try
    AtomicStore32(GMpmcCloseRaceStart, 0, moRelease);
    AtomicStore32(GMpmcCloseRaceStarted, 0, moRelease);
    AtomicStore32(GMpmcCloseRaceDone, 0, moRelease);
    AtomicStore64(GMpmcCloseRaceNextValue, 0, moRelease);
    AtomicStore64(GMpmcCloseRacePublished, 0, moRelease);
    AtomicStore64(GMpmcCloseRaceConsumed, 0, moRelease);
    AtomicStore64(GMpmcCloseRaceOutOfRange, 0, moRelease);
    for LI := 0 to MPMC_CLOSE_RACE_MAX_VALUES - 1 do
      AtomicStore32(GMpmcCloseRaceConsumedMap[LI], 0, moRelaxed);

    for LI := 0 to MPMC_CLOSE_RACE_CONSUMERS - 1 do
    begin
      StartThread(LConsumers[LI], @MpmcCloseRaceConsumer, nil, 'MPMC close-race consumer thread');
      Inc(LConsumerCount);
    end;
    for LI := 0 to MPMC_CLOSE_RACE_PRODUCERS - 1 do
    begin
      StartThread(LProducers[LI], @MpmcCloseRaceProducer, Pointer(PtrInt(LI)), 'MPMC close-race producer thread');
      Inc(LProducerCount);
    end;

    for LI := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcCloseRaceStarted, moAcquire) = MPMC_CLOSE_RACE_PRODUCERS then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(MPMC_CLOSE_RACE_PRODUCERS),
      Int64(AtomicLoad32(GMpmcCloseRaceStarted, moAcquire)),
      'MPMC close race producers must all start before release');

    AtomicStore32(GMpmcCloseRaceStart, 1, moRelease);
    for LI := 1 to 1000 do
    begin
      if AtomicLoad64(GMpmcCloseRacePublished, moAcquire) >= MPMC_CLOSE_RACE_CAPACITY then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    Check(AtomicLoad64(GMpmcCloseRacePublished, moAcquire) > 0,
      'MPMC close race must publish at least one item before close');
    Check(AtomicLoad32(GMpmcCloseRaceDone, moAcquire) < MPMC_CLOSE_RACE_PRODUCERS,
      'MPMC close race must close while producers are still live');

    GMpmcCloseRaceQ.Close;

    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');

    LLeftover := 0;
    while GMpmcCloseRaceQ.TryDequeue(LV) do
      Inc(LLeftover);

    LDuplicates := 0;
    for LI := 0 to MPMC_CLOSE_RACE_MAX_VALUES - 1 do
    begin
      if AtomicLoad32(GMpmcCloseRaceConsumedMap[LI], moRelaxed) > 1 then
        Inc(LDuplicates);
    end;

    CheckEqual(Int64(0), GMpmcCloseRaceOutOfRange,
      'close race no out-of-range messages');
    CheckEqual(Int64(0), Int64(LDuplicates),
      'close race no duplicate messages');
    CheckEqual(GMpmcCloseRacePublished, GMpmcCloseRaceConsumed,
      'close race consumed all accepted enqueue operations');
    CheckEqual(Int64(0), LLeftover,
      'close race leaves no drainable items after consumers exit');
  finally
    AtomicStore32(GMpmcCloseRaceStart, 1, moRelease);
    GMpmcCloseRaceQ.Close;
    JoinStartedThreads(LProducers, LProducerCount, 'producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'consumer thread');
    GMpmcCloseRaceQ.Free;
  end;
end;

procedure TestMpmcCloseRacesActiveProducersTimeout;
var
  LProducers: array[0..MPMC_CLOSE_RACE_PRODUCERS - 1] of TPlatformThreadHandle;
  LConsumers: array[0..MPMC_CLOSE_RACE_CONSUMERS - 1] of TPlatformThreadHandle;
  LI, LDuplicates: Integer;
  LV: Integer;
  LLeftover: Int64;
  LProducerCount: Integer;
  LConsumerCount: Integer;
begin
  GMpmcCloseRaceQ := TIntMpmc.Create(MPMC_CLOSE_RACE_CAPACITY);
  LProducerCount := 0;
  LConsumerCount := 0;
  try
    AtomicStore32(GMpmcCloseRaceStart, 0, moRelease);
    AtomicStore32(GMpmcCloseRaceStarted, 0, moRelease);
    AtomicStore32(GMpmcCloseRaceDone, 0, moRelease);
    AtomicStore64(GMpmcCloseRaceNextValue, 0, moRelease);
    AtomicStore64(GMpmcCloseRacePublished, 0, moRelease);
    AtomicStore64(GMpmcCloseRaceConsumed, 0, moRelease);
    AtomicStore64(GMpmcCloseRaceOutOfRange, 0, moRelease);
    for LI := 0 to MPMC_CLOSE_RACE_MAX_VALUES - 1 do
      AtomicStore32(GMpmcCloseRaceConsumedMap[LI], 0, moRelaxed);

    for LI := 0 to MPMC_CLOSE_RACE_CONSUMERS - 1 do
    begin
      StartThread(LConsumers[LI], @MpmcCloseRaceTimeoutConsumer, nil, 'MPMC close-race timeout consumer thread');
      Inc(LConsumerCount);
    end;
    for LI := 0 to MPMC_CLOSE_RACE_PRODUCERS - 1 do
    begin
      StartThread(LProducers[LI], @MpmcCloseRaceProducer, Pointer(PtrInt(LI)), 'MPMC close-race timeout producer thread');
      Inc(LProducerCount);
    end;

    for LI := 1 to 1000 do
    begin
      if AtomicLoad32(GMpmcCloseRaceStarted, moAcquire) = MPMC_CLOSE_RACE_PRODUCERS then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(MPMC_CLOSE_RACE_PRODUCERS),
      Int64(AtomicLoad32(GMpmcCloseRaceStarted, moAcquire)),
      'MPMC close race timeout producers must all start before release');

    AtomicStore32(GMpmcCloseRaceStart, 1, moRelease);
    for LI := 1 to 1000 do
    begin
      if AtomicLoad64(GMpmcCloseRacePublished, moAcquire) >= MPMC_CLOSE_RACE_CAPACITY then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    Check(AtomicLoad64(GMpmcCloseRacePublished, moAcquire) > 0,
      'MPMC close race timeout must publish at least one item before close');
    Check(AtomicLoad32(GMpmcCloseRaceDone, moAcquire) < MPMC_CLOSE_RACE_PRODUCERS,
      'MPMC close race timeout must close while producers are still live');

    GMpmcCloseRaceQ.Close;

    JoinStartedThreads(LProducers, LProducerCount, 'timeout producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'timeout consumer thread');

    LLeftover := 0;
    while GMpmcCloseRaceQ.TryDequeue(LV) do
      Inc(LLeftover);

    LDuplicates := 0;
    for LI := 0 to MPMC_CLOSE_RACE_MAX_VALUES - 1 do
    begin
      if AtomicLoad32(GMpmcCloseRaceConsumedMap[LI], moRelaxed) > 1 then
        Inc(LDuplicates);
    end;

    CheckEqual(Int64(0), GMpmcCloseRaceOutOfRange,
      'close race timeout no out-of-range messages');
    CheckEqual(Int64(0), Int64(LDuplicates),
      'close race timeout no duplicate messages');
    CheckEqual(GMpmcCloseRacePublished, GMpmcCloseRaceConsumed,
      'close race timeout consumed all accepted enqueue operations');
    CheckEqual(Int64(0), LLeftover,
      'close race timeout leaves no drainable items after consumers exit');
  finally
    AtomicStore32(GMpmcCloseRaceStart, 1, moRelease);
    GMpmcCloseRaceQ.Close;
    JoinStartedThreads(LProducers, LProducerCount, 'timeout producer thread');
    JoinStartedThreads(LConsumers, LConsumerCount, 'timeout consumer thread');
    GMpmcCloseRaceQ.Free;
  end;
end;

{ ============================================================ }
{ TEST 7: Stack Capacity Exhaustion + Recovery                 }
{ 4 threads hammer a capacity-8 stack with push/pop            }
{ Verify: no corruption, stack drains to empty                 }
{ ============================================================ }

const
  STACK_EXHAUST_CAP = 8;
  STACK_EXHAUST_THREADS = 4;
  STACK_EXHAUST_ROUNDS = 50000;

var
  GStackExhaust: TIntStack;
  GStackExhaustPushOk: Int64;
  GStackExhaustPopOk: Int64;

function StackExhaustWorker(AArg: Pointer): Pointer; cdecl;
var
  LI, LV: Integer;
  LPush, LPop: Int64;
begin
  Result := nil;
  LPush := 0;
  LPop := 0;
  for LI := 1 to STACK_EXHAUST_ROUNDS do
  begin
    if GStackExhaust.TryPush(LI) then
      Inc(LPush);
    if GStackExhaust.TryPop(LV) then
      Inc(LPop);
  end;
  AtomicFetchAdd64(GStackExhaustPushOk, LPush, moRelaxed);
  AtomicFetchAdd64(GStackExhaustPopOk, LPop, moRelaxed);
end;

procedure TestStackExhaustion;
var
  LHandles: array[0..STACK_EXHAUST_THREADS - 1] of TPlatformThreadHandle;
  LI, LV: Integer;
  LRemaining: Int64;
  LHandleCount: Integer;
begin
  GStackExhaust := TIntStack.Create(STACK_EXHAUST_CAP);
  GStackExhaustPushOk := 0;
  GStackExhaustPopOk := 0;
  LHandleCount := 0;
  try
    for LI := 0 to STACK_EXHAUST_THREADS - 1 do
    begin
      StartThread(LHandles[LI], @StackExhaustWorker, Pointer(PtrInt(LI)), 'stack exhaustion worker thread');
      Inc(LHandleCount);
    end;
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');

    { Drain any remaining }
    LRemaining := 0;
    while GStackExhaust.TryPop(LV) do
      Inc(LRemaining);

    { pushes = pops + remaining }
    CheckEqual(GStackExhaustPushOk, GStackExhaustPopOk + LRemaining, 'push = pop + remaining');
    Check(GStackExhaust.IsEmpty, 'stack empty after drain');
  finally
    JoinStartedThreads(LHandles, LHandleCount, 'worker thread');
    GStackExhaust.Free;
  end;
end;

{ ============================================================ }
{ Main                                                         }
{ ============================================================ }

begin
  T := TTestRunner.Create('nextpas.core.lockfree.stress');
  T.Run('MPMC 8P+8C saturation (cap=16, 80K msgs)', @TestMpmcSaturation);
  T.Run('MPMC single-slot 2P+2C exactly-once', @TestMpmcSingleSlotContention);
  T.Run('Stack ABA stress (4T, cap=4, 100K cycles)', @TestStackABA);
  T.Run('MPSC close race (4P + random close)', @TestMpscCloseRace);
  T.Run('Deque extreme steal (1 owner + 7 thieves, 200K)', @TestDequeExtremeSteal);
  T.Run('SPSC full + close race', @TestSpscFullClose);
  T.Run('MPMC rapid create/close cycles (50 rounds)', @TestMpmcRapidCycles);
  T.Run('MPMC close races active producers', @TestMpmcCloseRacesActiveProducers);
  T.Run('MPMC close races active producers timeout', @TestMpmcCloseRacesActiveProducersTimeout);
  T.Run('Stack exhaustion + recovery (4T, cap=8)', @TestStackExhaustion);
  T.Summary;
end.
