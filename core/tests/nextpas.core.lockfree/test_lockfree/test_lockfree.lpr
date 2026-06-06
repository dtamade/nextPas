program test_lockfree;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
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

function ReadUtf8TextFile(const APath: string): string;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
      LStream.ReadBuffer(Result[1], LStream.Size);
  finally
    LStream.Free;
  end;
end;

procedure CheckContains(const AText, AExpected, AMessage: string);
begin
  Check(Pos(AExpected, AText) > 0, AMessage + ': missing "' + AExpected + '"');
end;

function ExtractSection(const AText, AStartMarker, AEndMarker: string): string;
var
  LStartPos: SizeInt;
  LEndPos: SizeInt;
  LRelativeEndPos: SizeInt;
begin
  LStartPos := Pos(AStartMarker, AText);
  Check(LStartPos > 0, 'section start missing: ' + AStartMarker);

  LRelativeEndPos := Pos(AEndMarker,
    Copy(AText, LStartPos + Length(AStartMarker), MaxInt));
  if LRelativeEndPos > 0 then
    LEndPos := LStartPos + Length(AStartMarker) + LRelativeEndPos - 1
  else
    LEndPos := 0;
  Check(LEndPos > LStartPos, 'section end missing: ' + AEndMarker);

  Result := Copy(AText, LStartPos, LEndPos - LStartPos);
end;

function ExtractImplementationSection(const AText, AStartMarker, AEndMarker: string): string;
var
  LImplementationPos: SizeInt;
begin
  LImplementationPos := Pos('implementation', AText);
  Check(LImplementationPos > 0, 'implementation marker missing');
  Result := ExtractSection(
    Copy(AText, LImplementationPos, MaxInt),
    AStartMarker,
    AEndMarker
  );
end;

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
  LStart := Integer(PtrUInt(AArg));
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

function CapacityAboveMaxPowerOfTwo: PtrUInt;
var
  LMax: PtrUInt;
begin
  LMax := not PtrUInt(0);
  Result := (LMax - (LMax shr 1)) + 1;
end;

procedure TestCapacityOverflowReject;
var
  LCapacity: PtrUInt;
  LSpsc: TIntSpsc;
  LMpmc: TIntMpmc;
  LDeque: TIntDeque;
  LGot: Boolean;
begin
  LCapacity := CapacityAboveMaxPowerOfTwo;

  LGot := False;
  LSpsc := nil;
  try
    LSpsc := TIntSpsc.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  LSpsc.Free;
  Check(LGot, 'SPSC rejects capacity above maximum power-of-two');

  LGot := False;
  LMpmc := nil;
  try
    LMpmc := TIntMpmc.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  LMpmc.Free;
  Check(LGot, 'MPMC rejects capacity above maximum power-of-two');

  LGot := False;
  LDeque := nil;
  try
    LDeque := TIntDeque.Create(LCapacity);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  LDeque.Free;
  Check(LGot, 'deque rejects capacity above maximum power-of-two');
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
  LSt := TIntStack.Create(16);
  Check(LSt.IsEmpty, 'empty');
  Check(LSt.TryPush(10), 'push 1');
  Check(LSt.TryPush(20), 'push 2');
  Check(LSt.TryPush(30), 'push 3');
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
  LStart := Integer(PtrUInt(AArg));
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

{ Multi-thread stress tests }

const
  STRESS_OPS = 100000;

var
  GStressStack: specialize TLockFreeStack<Integer>;
  GStackPushCount: Int64;
  GStackPopCount: Int64;

function StackStressPusher(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to STRESS_OPS do
    while not GStressStack.TryPush(LI) do
      CpuPause;
  InterlockedExchangeAdd64(GStackPushCount, STRESS_OPS);
end;

function StackStressPopper(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LCount: Int64;
begin
  Result := nil;
  LCount := 0;
  while True do
  begin
    if GStressStack.TryPop(LV) then
      Inc(LCount)
    else if InterlockedCompareExchange64(GStackPushCount, 0, 0) >= STRESS_OPS * 4 then
    begin
      while GStressStack.TryPop(LV) do
        Inc(LCount);
      Break;
    end
    else
      CpuPause;
  end;
  InterlockedExchangeAdd64(GStackPopCount, LCount);
end;

procedure TestStackStress;
var
  LPushers: array[0..3] of TPlatformThreadHandle;
  LPoppers: array[0..3] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI: Integer;
begin
  GStressStack := specialize TLockFreeStack<Integer>.Create(4096);
  GStackPushCount := 0;
  GStackPopCount := 0;
  for LI := 0 to 3 do
    platform_thread_create(LPushers[LI], @StackStressPusher, nil);
  for LI := 0 to 3 do
    platform_thread_create(LPoppers[LI], @StackStressPopper, nil);
  for LI := 0 to 3 do
    platform_thread_join(LPushers[LI], LRetVal);
  for LI := 0 to 3 do
    platform_thread_join(LPoppers[LI], LRetVal);
  CheckEqual(Int64(STRESS_OPS * 4), GStackPopCount, 'stack 4P+4C all popped');
  GStressStack.Free;
end;

var
  GStressDeque: specialize TWorkStealingDeque<Integer>;
  GDequeStealCount: Int64;

function DequeThief(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LCount: Int64;
begin
  Result := nil;
  LCount := 0;
  while InterlockedCompareExchange64(GDequeStealCount, 0, 0) < STRESS_OPS do
  begin
    if GStressDeque.TrySteal(LV) then
      Inc(LCount);
  end;
  InterlockedExchangeAdd64(GDequeStealCount, LCount);
end;

procedure TestDequeOwnerThief;
var
  LThieves: array[0..2] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI, LV: Integer;
  LOwnerPop: Int64;
begin
  GStressDeque := specialize TWorkStealingDeque<Integer>.Create(1024);
  GDequeStealCount := 0;
  LOwnerPop := 0;
  for LI := 0 to 2 do
    platform_thread_create(LThieves[LI], @DequeThief, nil);
  for LI := 1 to STRESS_OPS do
  begin
    while not GStressDeque.TryPush(LI) do
    begin
      if GStressDeque.TryPop(LV) then
        Inc(LOwnerPop);
    end;
  end;
  while GStressDeque.TryPop(LV) do
    Inc(LOwnerPop);
  InterlockedExchangeAdd64(GDequeStealCount, STRESS_OPS);
  for LI := 0 to 2 do
    platform_thread_join(LThieves[LI], LRetVal);
  Check(LOwnerPop + GDequeStealCount - STRESS_OPS > 0, 'deque owner+thieves processed items');
  GStressDeque.Free;
end;

procedure TestManagedTypeReject;
type
  TStrSpsc = specialize TSpscQueue<AnsiString>;
var
  LGot: Boolean;
begin
  LGot := False;
  try
    TStrSpsc.Create(4);
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'managed type rejected');
end;

procedure TestLockFreeWaiterLifecycleSourceContract;
var
  LSource: string;
  LSpscSource: string;
  LMpmcSource: string;
  LMpscSource: string;
  LWaitDataSection: string;
  LWaitSpaceSection: string;
begin
  LSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.wait.pas');
  LSpscSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.spsc.pas');
  LMpmcSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.mpmc.pas');
  LMpscSource := ReadUtf8TextFile('../../../src/nextpas.core.lockfree.mpsc.pas');
  LWaitDataSection := ExtractImplementationSection(LSource,
    'procedure LockFreeWaitData(AEpoch: PInt32; AWaiters: PInt32;',
    'procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;');
  LWaitSpaceSection := ExtractImplementationSection(LSource,
    'procedure LockFreeWaitSpace(AEpoch: PInt32; AWaiters: PInt32;',
    'procedure LockFreeWakeAll(AEpoch: PInt32);');

  CheckContains(LWaitDataSection, 'const AObservedEpoch: Int32;',
    'LockFreeWaitData must sleep against the caller-observed epoch');
  CheckContains(LWaitDataSection, 'if AtomicLoad32(AEpoch^, moAcquire) <> AObservedEpoch then',
    'LockFreeWaitData must avoid sleeping after a missed notification');
  CheckContains(LWaitDataSection, 'AtomicFetchAdd32(AWaiters^, 1, moAcqRel);',
    'LockFreeWaitData must increment waiter count before sleeping');
  CheckContains(LWaitDataSection, 'try',
    'LockFreeWaitData must guard waiter count release with try/finally');
  CheckContains(LWaitDataSection, 'platform_wait_address32(AEpoch, AObservedEpoch, ATimeoutNs);',
    'LockFreeWaitData must wait only while the observed epoch is unchanged');
  CheckContains(LWaitDataSection, 'finally',
    'LockFreeWaitData must release waiter count in a finally block');
  CheckContains(LWaitDataSection, 'AtomicFetchSub32(AWaiters^, 1, moAcqRel);',
    'LockFreeWaitData must decrement waiter count after sleeping');

  CheckContains(LWaitSpaceSection, 'const AObservedEpoch: Int32;',
    'LockFreeWaitSpace must sleep against the caller-observed epoch');
  CheckContains(LWaitSpaceSection, 'if AtomicLoad32(AEpoch^, moAcquire) <> AObservedEpoch then',
    'LockFreeWaitSpace must avoid sleeping after a missed notification');
  CheckContains(LWaitSpaceSection, 'AtomicFetchAdd32(AWaiters^, 1, moAcqRel);',
    'LockFreeWaitSpace must increment waiter count before sleeping');
  CheckContains(LWaitSpaceSection, 'try',
    'LockFreeWaitSpace must guard waiter count release with try/finally');
  CheckContains(LWaitSpaceSection, 'platform_wait_address32(AEpoch, AObservedEpoch, ATimeoutNs);',
    'LockFreeWaitSpace must wait only while the observed epoch is unchanged');
  CheckContains(LWaitSpaceSection, 'finally',
    'LockFreeWaitSpace must release waiter count in a finally block');
  CheckContains(LWaitSpaceSection, 'AtomicFetchSub32(AWaiters^, 1, moAcqRel);',
    'LockFreeWaitSpace must decrement waiter count after sleeping');

  CheckContains(LSpscSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);',
    'SPSC blocking enqueue must pass the observed space epoch');
  CheckContains(LSpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);',
    'SPSC blocking dequeue must pass the observed data epoch');
  CheckContains(LSpscSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);',
    'SPSC timed enqueue must pass the observed space epoch');
  CheckContains(LSpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'SPSC timed dequeue must pass the observed data epoch');

  CheckContains(LMpmcSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, -1);',
    'MPMC blocking enqueue must pass the observed space epoch');
  CheckContains(LMpmcSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);',
    'MPMC blocking dequeue must pass the observed data epoch');
  CheckContains(LMpmcSource, 'LockFreeWaitSpace(@FSpaceEpoch, @FSpaceWaiters, LEpoch, LRemaining);',
    'MPMC timed enqueue must pass the observed space epoch');
  CheckContains(LMpmcSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'MPMC timed dequeue must pass the observed data epoch');

  CheckContains(LMpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, -1);',
    'MPSC blocking dequeue must pass the observed data epoch');
  CheckContains(LMpscSource, 'LockFreeWaitData(@FDataEpoch, @FDataWaiters, LEpoch, LRemaining);',
    'MPSC timed dequeue must pass the observed data epoch');
end;

begin
  T := TTestRunner.Create('nextpas.core.lockfree');
  T.Run('waiter lifecycle source contract', @TestLockFreeWaiterLifecycleSourceContract);
  if not T.AllPassed then
    T.Summary;

  T.Run('SPSC basic', @TestSpscBasic);
  T.Run('SPSC close', @TestSpscClose);
  T.Run('SPSC approx count', @TestSpscApproxCount);
  T.Run('SPSC blocking', @TestSpscBlocking);
  T.Run('SPSC timeout', @TestSpscTimeout);
  T.Run('MPMC basic', @TestMpmcBasic);
  T.Run('MPMC close', @TestMpmcClose);
  T.Run('MPMC 4P+4C contention', @TestMpmcContention);
  T.Run('Capacity zero reject', @TestCapacityZero);
  T.Run('Capacity overflow reject', @TestCapacityOverflowReject);
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
  T.Run('Stack 4P+4C stress', @TestStackStress);
  T.Run('Deque owner+thief stress', @TestDequeOwnerThief);
  T.Run('Managed type reject', @TestManagedTypeReject);

  T.Summary;
end.
