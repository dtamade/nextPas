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

procedure CheckNotContains(const AText, AUnexpected, AMessage: string);
begin
  Check(Pos(AUnexpected, AText) = 0, AMessage + ': unexpected "' + AUnexpected + '"');
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

procedure TestLockFreeSourceContracts;
const
  LockFreeDocsReadmePath = '../../../docs/lockfree/README.md';
  SpscSourcePath = '../../../src/nextpas.core.lockfree.spsc.pas';
  MpmcSourcePath = '../../../src/nextpas.core.lockfree.mpmc.pas';
  StackSourcePath = '../../../src/nextpas.core.lockfree.stack.pas';
  MpscSourcePath = '../../../src/nextpas.core.lockfree.mpsc.pas';
  DequeSourcePath = '../../../src/nextpas.core.lockfree.deque.pas';
  WaitSourcePath = '../../../src/nextpas.core.lockfree.wait.pas';
  BenchSourcePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr';
  BenchRustComparePath = '../../../benchmarks/nextpas.core.lockfree/bench_lockfree/compare_rust/main.rs';
var
  LDocsReadme: string;
  LSpscSource: string;
  LMpmcSource: string;
  LStackSource: string;
  LMpscSource: string;
  LDequeSource: string;
  LWaitSource: string;
  LBenchSource: string;
  LRustCompareSource: string;
begin
  Check(FileExists(LockFreeDocsReadmePath),
    'lockfree README must exist as the module documentation entrypoint');
  Check(FileExists(BenchSourcePath),
    'lockfree benchmark source must exist as the benchmark entrypoint');
  Check(FileExists(BenchRustComparePath),
    'lockfree Rust comparison source must exist as an external baseline reference');

  LDocsReadme := ReadUtf8TextFile(LockFreeDocsReadmePath);
  LSpscSource := ReadUtf8TextFile(SpscSourcePath);
  LMpmcSource := ReadUtf8TextFile(MpmcSourcePath);
  LStackSource := ReadUtf8TextFile(StackSourcePath);
  LMpscSource := ReadUtf8TextFile(MpscSourcePath);
  LDequeSource := ReadUtf8TextFile(DequeSourcePath);
  LWaitSource := ReadUtf8TextFile(WaitSourcePath);
  LBenchSource := ReadUtf8TextFile(BenchSourcePath);
  LRustCompareSource := ReadUtf8TextFile(BenchRustComparePath);

  CheckContains(LDocsReadme, '# nextpas.core.lockfree',
    'lockfree README must use the module title');
  CheckContains(LDocsReadme, '`TSpscQueue<T>`',
    'lockfree README must document SPSC queue ownership');
  CheckContains(LDocsReadme, '`TMpmcQueue<T>`',
    'lockfree README must document MPMC queue ownership');
  CheckContains(LDocsReadme, '`TMpscQueue<T>`',
    'lockfree README must document MPSC queue ownership');
  CheckContains(LDocsReadme, '`TLockFreeStack<T>`',
    'lockfree README must document stack ownership');
  CheckContains(LDocsReadme, '`TWorkStealingDeque<T>`',
    'lockfree README must document deque ownership');
  CheckContains(LDocsReadme, 'Linearization points',
    'lockfree README must name linearization points');
  CheckContains(LDocsReadme, 'ABA',
    'lockfree README must document ABA boundaries');
  CheckContains(LDocsReadme, 'Memory reclamation',
    'lockfree README must document reclamation policy');
  CheckContains(LDocsReadme, 'Close/Destroy discipline',
    'lockfree README must document close and destroy discipline');
  CheckContains(LDocsReadme, 'Atomic dependency',
    'lockfree README must document dependency on atomic wait/notify');
  CheckContains(LDocsReadme,
    'Pointer-sized `atomic_load` / `atomic_store` / `atomic_exchange` for `TMpscQueue<T>` node links',
    'lockfree README must document pointer-sized MPSC node atomic dependency');
  CheckContains(LDocsReadme,
    'node pointers must not be widened through legacy `AtomicLoad64` / `AtomicStore64` / `AtomicExchange64` casts',
    'lockfree README must reject legacy 64-bit pointer casts for MPSC node links');
  CheckContains(LDocsReadme,
    'make -C core/tests/nextpas.core.lockfree/test_lockfree clean test',
    'lockfree README must list the focused lockfree gate');
  CheckContains(LDocsReadme,
    'make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test',
    'lockfree README must list the lockfree stress gate');
  CheckContains(LDocsReadme, 'source-contract',
    'lockfree README must distinguish source-contract coverage from runtime proof');
  CheckContains(LDocsReadme,
    'make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run',
    'lockfree README must list the focused benchmark command');
  CheckContains(LDocsReadme,
    'core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr',
    'lockfree README must point to the Pascal benchmark source');
  CheckContains(LDocsReadme, 'compare_rust/main.rs',
    'lockfree README must point to the external Rust comparison source');
  CheckContains(LDocsReadme, 'platform/compiler flags/input size/baseline',
    'lockfree README must name the benchmark evidence envelope');
  CheckNotContains(LDocsReadme, '当前模块还缺少正式 benchmark harness',
    'lockfree README must not say the benchmark harness is missing when it exists');

  CheckContains(LSpscSource, 'if IsManagedType(T) then',
    'SPSC queue must reject managed element types');
  CheckContains(LSpscSource, 'LockFreeNotifyData(@FDataEpoch, @FDataWaiters)',
    'SPSC queue must notify data waiters after publish');
  CheckContains(LSpscSource, 'LockFreeNotifySpace(@FSpaceEpoch, @FSpaceWaiters)',
    'SPSC queue must notify space waiters after consume');
  CheckContains(LMpmcSource, 'FSlots[LI].Sequence := Int64(LI)',
    'MPMC queue must initialize per-slot sequence numbers');
  CheckContains(LMpmcSource, 'AtomicStore64(FSlots[LIdx].Sequence, LPos + 1, moRelease)',
    'MPMC enqueue linearization must publish slot sequence with release ordering');
  CheckContains(LMpmcSource, 'AtomicStore64(FSlots[LIdx].Sequence, LPos + Int64(FCapacity), moRelease)',
    'MPMC dequeue must recycle slot sequence with release ordering');
  CheckContains(LStackSource, 'FFreeHead: Int64',
    'stack must keep a tagged free-list head');
  CheckContains(LStackSource, 'function PackTagIdx',
    'stack must keep tag/index packing helper for ABA resistance');
  CheckContains(LStackSource, 'FSlots[LIdx].Value := Default(T)',
    'stack pop must clear the slot before returning it to the free list');
  CheckContains(LMpscSource, 'Assert(FClosed <> 0',
    'MPSC destroy must keep the close-before-destroy debug guard');
  CheckContains(LMpscSource, 'Close must be called before Destroy',
    'MPSC destroy guard must document the producer-stop discipline');
  CheckContains(LMpscSource,
    'function AtomicLoadNode(var ANode: PNode; const AOrder: memory_order_t): PNode;',
    'MPSC queue must define a pointer-sized atomic node load helper');
  CheckContains(LMpscSource,
    'procedure AtomicStoreNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t);',
    'MPSC queue must define a pointer-sized atomic node store helper');
  CheckContains(LMpscSource,
    'function AtomicExchangeNode(var ANode: PNode; const AValue: PNode; const AOrder: memory_order_t): PNode;',
    'MPSC queue must define a pointer-sized atomic node exchange helper');
  CheckContains(LMpscSource, 'atomic_load(PPointer(@ANode)^, AOrder)',
    'MPSC node load helper must use pointer-sized atomic_load');
  CheckContains(LMpscSource, 'atomic_store(PPointer(@ANode)^, Pointer(AValue), AOrder)',
    'MPSC node store helper must use pointer-sized atomic_store');
  CheckContains(LMpscSource, 'atomic_exchange(PPointer(@ANode)^, Pointer(AValue), AOrder)',
    'MPSC node exchange helper must use pointer-sized atomic_exchange');
  CheckNotContains(LMpscSource, 'AtomicLoad64(Int64(PtrUInt(',
    'MPSC queue must not load pointer links through 64-bit pointer casts');
  CheckNotContains(LMpscSource, 'AtomicStore64(Int64(PtrUInt(',
    'MPSC queue must not store pointer links through 64-bit pointer casts');
  CheckNotContains(LMpscSource, 'AtomicExchange64(Int64(PtrUInt(',
    'MPSC queue must not exchange pointer links through 64-bit pointer casts');
  CheckContains(LDequeSource, 'AtomicCompareExchange64(FTop',
    'work-stealing deque must linearize steals through top CAS');
  CheckContains(LWaitSource, 'platform_wait_address32',
    'lockfree wait helper must use the atomic/platform wait-address seam');
  CheckContains(LWaitSource, 'AtomicFetchAdd32(AWaiters^, 1, moAcqRel)',
    'lockfree wait helper must register waiters before blocking');
  CheckContains(LWaitSource, 'AtomicFetchSub32(AWaiters^, 1, moAcqRel)',
    'lockfree wait helper must unregister waiters after blocking');
  CheckContains(LBenchSource, 'WriteLn(''Platform: '', BenchmarkPlatformName)',
    'lockfree benchmark must print the platform evidence field');
  CheckContains(LBenchSource, 'WriteLn(''Compiler flags: -MObjFPC -Sh -O2'')',
    'lockfree benchmark must print the compiler flags evidence field');
  CheckContains(LBenchSource, 'WriteLn(''Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T'')',
    'lockfree benchmark must print the input-size evidence field');
  CheckContains(LBenchSource, 'WriteLn(''Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs external Rust source (not auto-run)'')',
    'lockfree benchmark must print the baseline evidence field');
  CheckContains(LRustCompareSource, 'const N: usize = 1_000_000;',
    'Rust comparison source must use the same nominal operation count');
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
  T.Run('Stack 4P+4C stress', @TestStackStress);
  T.Run('Deque owner+thief stress', @TestDequeOwnerThief);
  T.Run('Managed type reject', @TestManagedTypeReject);
  T.Run('Source contracts', @TestLockFreeSourceContracts);

  T.Summary;
end.
