program bench_lockfree;
{**
 * Q5 matched + micro benches for nextpas.core.lockfree.
 *
 * Matched suite (compare with compare_go / compare_rust under same OPS/CAPACITY):
 *   C1 — TLockFreeChannel 1P+1C
 *   C2 — TLockFreeChannel 2P+2C
 *   C1s — TLockFreeChannelSpsc 1P+1C
 *   M1/M2 — TMpscQueue 1P+1C / 2P+1C (unbounded)
 *   W1/W2 — TWorkStealingPool 1S+1T / 2S+2T (4 workers, bounded deques)
 *   J1/J2 — TLockFreeForkJoinPool 1F+1W / 2F+2W (4 workers, bounded deques)
 * Micro (single-thread Try*; do NOT compare to multi-thread Go/Rust):
 *   SPSC/MPMC/Seg/SPMC TryDequeue, SPSC/MPSC TryEnqueue+TryDequeue pair,
 *   Channel 1T TrySendReceive, Pool 1T Submit+Steal pair,
 *   ForkJoin 1T Fork+PopOrSteal pair, EBR Retire
 *
 * B40: both suites use TBenchSuite (Quiet + short config for micro;
 * matched uses MaxIterations/MinSamples=1 so multi-thread OPS runs once per entry).
 *}
{$I nextpas.core.settings.inc}
uses
  nextpas.core.thread.init,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.atomic, nextpas.core.lockfree,
  nextpas.core.lockfree.ebr, nextpas.core.lockfree.spsc, nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.segqueue, nextpas.core.lockfree.spmc,
  nextpas.core.lockfree.channel, nextpas.core.lockfree.channel.spsc,
  nextpas.core.lockfree.mpsc, nextpas.core.lockfree.workstealing,
  nextpas.core.lockfree.forkjoin,
  nextpas.core.platform.thread, nextpas.core.platform.time, nextpas.core.platform.info,
  nextpas.core.fs,
  nextpas.core.exception;

const
  OPS = 1000000;
  CAPACITY = 1024;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntSegQueue = specialize TSegQueue<Integer>;
  TIntSpmc = specialize TSpmcQueue<Integer>;
  TIntChannel = specialize TLockFreeChannel<Integer>;
  TIntChannelSpsc = specialize TLockFreeChannelSpsc<Integer>;
  TIntMpsc = specialize TMpscQueue<Integer>;

var
  GSpsc: TIntSpsc;
  GMpmc: TIntMpmc;
  GSeg: TIntSegQueue;
  GSpmc: TIntSpmc;
  GChannel: TIntChannel;
  GChannelSpsc: TIntChannelSpsc;
  GBenchSink: Int64;
  GEbrDomain: TEbrDomain;

  GMpsc: TIntMpsc;
  GPool: TWorkStealingPool;
  GJPool: TLockFreeForkJoinPool;

  { Matched multi-thread state }
  GMatchCh: TIntChannel;
  GMatchChSpsc: TIntChannelSpsc;
  GMatchMpsc: TIntMpsc;
  GMatchPool: TWorkStealingPool;
  GMatchJPool: TLockFreeForkJoinPool;
  GMatchSum: Int64;

procedure SimpleReclaim(const AData: Pointer; const AUserData: Pointer);
begin
  FreeMem(AData);
end;

procedure BenchSpscTryDequeue(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GSpsc.TryDequeue(LV) then
    GBenchSink := GBenchSink + LV;
end;

{ Registered after SPSC/TryDequeue, which drains GSpsc — so every iteration
  here is a successful enqueue+dequeue pair (steady state ~0..1 items). }
procedure BenchSpscTryPair(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GSpsc.TryEnqueue(42) then
    if GSpsc.TryDequeue(LV) then
      GBenchSink := GBenchSink + LV;
end;

procedure BenchMpmcTryDequeue(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GMpmc.TryDequeue(LV) then
    GBenchSink := GBenchSink + LV;
end;

procedure BenchSegTryDequeue(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GSeg.TryDequeue(LV) then
    GBenchSink := GBenchSink + LV;
end;

procedure BenchSpmcTryDequeue(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GSpmc.TryDequeue(LV) then
    GBenchSink := GBenchSink + LV;
end;

{ MPSC is unbounded (no pre-fill): every iteration is a successful
  enqueue+dequeue pair from empty (steady state ~0..1 items). }
procedure BenchMpscTryPair(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GMpsc.TryEnqueue(42) then
    if GMpsc.TryDequeue(LV) then
      GBenchSink := GBenchSink + LV;
end;

procedure PoolDummyTask(AData: Pointer);
begin
end;

{ Pool pair from empty: every iteration is one Submit + one Steal (bounded
  deques never fill at steady state ~0..1 tasks). }
procedure BenchPoolSubmitStealPair(const ACtx: IBenchContext);
var
  LTask: TWorkStealingTask;
  LData: Pointer;
begin
  if GPool.Submit(@PoolDummyTask, Pointer(PtrUInt(42))) then
    if GPool.Steal(LTask, LData) = wsStolen then
      GBenchSink := GBenchSink + PtrUInt(LData);
end;

procedure ForkJoinDummyTask(AUserData: Pointer);
begin
end;

{ ForkJoin pair from empty: one Fork + one local PopOrSteal per iteration. }
procedure BenchForkJoinPair(const ACtx: IBenchContext);
var
  LTask: TForkJoinTask;
begin
  LTask.Proc := @ForkJoinDummyTask;
  LTask.UserData := Pointer(PtrUInt(42));
  if GJPool.Fork(LTask) = fjOk then
    if GJPool.PopOrSteal(0, LTask) then
      GBenchSink := GBenchSink + PtrUInt(LTask.UserData);
end;

procedure BenchEbrRetire(const ACtx: IBenchContext);
var
  LP: Pointer;
begin
  GetMem(LP, 64);
  GEbrDomain.Retire(LP, @SimpleReclaim);
end;

procedure BenchChannelTrySendReceive(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GChannel.TrySend(42) then
    if GChannel.TryReceive(LV) then
      GBenchSink := GBenchSink + LV;
end;

procedure BenchChannelSpscTrySendReceive(const ACtx: IBenchContext);
var
  LV: Integer;
begin
  if GChannelSpsc.TrySend(42) then
    if GChannelSpsc.TryReceive(LV) then
      GBenchSink := GBenchSink + LV;
end;

function MatchProducer(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  for LI := 1 to LCount do
    GMatchCh.Send(LI);
end;

function MatchConsumer(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
  LV: Integer;
  LLocal: Int64;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  LLocal := 0;
  for LI := 1 to LCount do
  begin
    if GMatchCh.Receive(LV) then
      LLocal := LLocal + LV;
  end;
  InterlockedExchangeAdd64(GMatchSum, LLocal);
end;

function MatchProducerSpsc(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  for LI := 1 to LCount do
    GMatchChSpsc.Send(LI);
end;

function MatchConsumerSpsc(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
  LV: Integer;
  LLocal: Int64;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  LLocal := 0;
  for LI := 1 to LCount do
    if GMatchChSpsc.Receive(LV) then
      LLocal := LLocal + LV;
  InterlockedExchangeAdd64(GMatchSum, LLocal);
end;

function MatchProducerMpsc(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  for LI := 1 to LCount do
    GMatchMpsc.Enqueue(LI);
end;

function MatchConsumerMpsc(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
  LV: Integer;
  LLocal: Int64;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  LLocal := 0;
  for LI := 1 to LCount do
    if GMatchMpsc.DequeueWait(LV) then
      LLocal := LLocal + LV;
  InterlockedExchangeAdd64(GMatchSum, LLocal);
end;

function MatchSubmitterPool(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  for LI := 1 to LCount do
    while not GMatchPool.Submit(@PoolDummyTask, Pointer(PtrUInt(LI))) do
      CpuPause; { bounded deques: spin until a stealer drains capacity }
end;

function MatchStealerPool(AArg: Pointer): Pointer; cdecl;
var
  LCount: Integer;
  LGot: Integer;
  LTask: TWorkStealingTask;
  LData: Pointer;
  LLocal: Int64;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  LGot := 0;
  LLocal := 0;
  while LGot < LCount do
  begin
    if GMatchPool.Steal(LTask, LData) = wsStolen then
    begin
      LLocal := LLocal + Int64(PtrUInt(LData));
      Inc(LGot);
    end
    else
      CpuPause;
  end;
  InterlockedExchangeAdd64(GMatchSum, LLocal);
end;

function MatchForkerFj(AArg: Pointer): Pointer; cdecl;
var
  LI, LCount: Integer;
  LTask: TForkJoinTask;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg));
  LTask.Proc := @ForkJoinDummyTask;
  for LI := 1 to LCount do
  begin
    LTask.UserData := Pointer(PtrUInt(LI));
    while GMatchJPool.Fork(LTask) <> fjOk do
      CpuPause; { bounded deques: spin until a worker drains capacity }
  end;
end;

{ AArg packs (workerId shl 32) or count — PopOrSteal needs a worker identity. }
function MatchWorkerFj(AArg: Pointer): Pointer; cdecl;
var
  LCount, LGot: Integer;
  LWorkerId: Int32;
  LTask: TForkJoinTask;
  LLocal: Int64;
begin
  Result := nil;
  LCount := Integer(PtrUInt(AArg) and $FFFFFFFF);
  LWorkerId := Int32(PtrUInt(AArg) shr 32);
  LGot := 0;
  LLocal := 0;
  while LGot < LCount do
  begin
    if GMatchJPool.PopOrSteal(LWorkerId, LTask) then
    begin
      LLocal := LLocal + Int64(PtrUInt(LTask.UserData));
      Inc(LGot);
    end
    else
      CpuPause;
  end;
  InterlockedExchangeAdd64(GMatchSum, LLocal);
end;

{ Fixed 4 workers: Fork round-robins across deques, each worker thread pops
  its own deque first then steals from the others. }
procedure RunMatchedForkJoinOnce(const AForkers, AWorkers: Integer);
var
  LForkers: array[0..7] of TPlatformThreadHandle;
  LWorkers: array[0..7] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LOpsPerF, LOpsPerW: Integer;
begin
  if (AForkers < 1) or (AWorkers < 1) or (AForkers > 8) or (AWorkers > 4) then
    raise EInvalidOperationError.Create('RunMatchedForkJoinOnce: bad forker/worker count');
  if (OPS mod AForkers <> 0) or (OPS mod AWorkers <> 0) then
    raise EInvalidOperationError.Create('RunMatchedForkJoinOnce: OPS must divide thread counts');

  LOpsPerF := OPS div AForkers;
  LOpsPerW := OPS div AWorkers;
  GMatchJPool := TLockFreeForkJoinPool.Create(4);
  GMatchSum := 0;
  try
    for LI := 0 to AWorkers - 1 do
      if platform_thread_create(LWorkers[LI], @MatchWorkerFj,
        Pointer((PtrUInt(LI) shl 32) or PtrUInt(LOpsPerW))) <> 0 then
        raise EInvalidOperationError.Create('forkjoin worker create failed');
    for LI := 0 to AForkers - 1 do
      if platform_thread_create(LForkers[LI], @MatchForkerFj, Pointer(PtrUInt(LOpsPerF))) <> 0 then
        raise EInvalidOperationError.Create('forkjoin forker create failed');
    for LI := 0 to AForkers - 1 do
      platform_thread_join(LForkers[LI], LRet);
    for LI := 0 to AWorkers - 1 do
      platform_thread_join(LWorkers[LI], LRet);
    GBenchSink := GBenchSink + GMatchSum;
  finally
    GMatchJPool.Close;
    GMatchJPool.Free;
    GMatchJPool := nil;
  end;
end;

{ Fixed 4 workers (4 bounded deques): Submit round-robins across them,
  Steal scans from a rotating start index. }
procedure RunMatchedPoolOnce(const ASubmitters, AStealers: Integer);
var
  LSubmitters: array[0..7] of TPlatformThreadHandle;
  LStealers: array[0..7] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LOpsPerS, LOpsPerT: Integer;
begin
  if (ASubmitters < 1) or (AStealers < 1) or (ASubmitters > 8) or (AStealers > 8) then
    raise EInvalidOperationError.Create('RunMatchedPoolOnce: bad submitter/stealer count');
  if (OPS mod ASubmitters <> 0) or (OPS mod AStealers <> 0) then
    raise EInvalidOperationError.Create('RunMatchedPoolOnce: OPS must divide thread counts');

  LOpsPerS := OPS div ASubmitters;
  LOpsPerT := OPS div AStealers;
  GMatchPool := TWorkStealingPool.Create(4);
  GMatchSum := 0;
  try
    for LI := 0 to AStealers - 1 do
      if platform_thread_create(LStealers[LI], @MatchStealerPool, Pointer(PtrUInt(LOpsPerT))) <> 0 then
        raise EInvalidOperationError.Create('pool stealer create failed');
    for LI := 0 to ASubmitters - 1 do
      if platform_thread_create(LSubmitters[LI], @MatchSubmitterPool, Pointer(PtrUInt(LOpsPerS))) <> 0 then
        raise EInvalidOperationError.Create('pool submitter create failed');
    for LI := 0 to ASubmitters - 1 do
      platform_thread_join(LSubmitters[LI], LRet);
    for LI := 0 to AStealers - 1 do
      platform_thread_join(LStealers[LI], LRet);
    GBenchSink := GBenchSink + GMatchSum;
  finally
    GMatchPool.Close;
    GMatchPool.Free;
    GMatchPool := nil;
  end;
end;

{ Single consumer only — TMpscQueue is strictly single-consumer.
  Unbounded: producers never block; consumer blocks via DequeueWait. }
procedure RunMatchedMpscOnce(const AProducers: Integer);
var
  LProducers: array[0..7] of TPlatformThreadHandle;
  LConsumer: TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LOpsPerP: Integer;
begin
  if (AProducers < 1) or (AProducers > 8) then
    raise EInvalidOperationError.Create('RunMatchedMpscOnce: bad producer count');
  if OPS mod AProducers <> 0 then
    raise EInvalidOperationError.Create('RunMatchedMpscOnce: OPS must divide producer count');

  LOpsPerP := OPS div AProducers;
  GMatchMpsc := TIntMpsc.Create;
  GMatchSum := 0;
  try
    if platform_thread_create(LConsumer, @MatchConsumerMpsc, Pointer(PtrUInt(OPS))) <> 0 then
      raise EInvalidOperationError.Create('mpsc consumer create failed');
    for LI := 0 to AProducers - 1 do
      if platform_thread_create(LProducers[LI], @MatchProducerMpsc, Pointer(PtrUInt(LOpsPerP))) <> 0 then
        raise EInvalidOperationError.Create('mpsc producer create failed');
    for LI := 0 to AProducers - 1 do
      platform_thread_join(LProducers[LI], LRet);
    platform_thread_join(LConsumer, LRet);
    GBenchSink := GBenchSink + GMatchSum;
  finally
    GMatchMpsc.Close;
    GMatchMpsc.Free;
    GMatchMpsc := nil;
  end;
end;

{ 1P1C only — TLockFreeChannelSpsc is strictly single producer/consumer. }
procedure RunMatchedChannelSpscOnce;
var
  LProducer, LConsumer: TPlatformThreadHandle;
  LRet: Pointer;
begin
  GMatchChSpsc := TIntChannelSpsc.Create(CAPACITY);
  GMatchSum := 0;
  try
    if platform_thread_create(LConsumer, @MatchConsumerSpsc, Pointer(PtrUInt(OPS))) <> 0 then
      raise EInvalidOperationError.Create('spsc consumer create failed');
    if platform_thread_create(LProducer, @MatchProducerSpsc, Pointer(PtrUInt(OPS))) <> 0 then
      raise EInvalidOperationError.Create('spsc producer create failed');
    platform_thread_join(LProducer, LRet);
    platform_thread_join(LConsumer, LRet);
    GBenchSink := GBenchSink + GMatchSum;
  finally
    GMatchChSpsc.Close;
    GMatchChSpsc.Free;
    GMatchChSpsc := nil;
  end;
end;

procedure RunMatchedChannelOnce(const AProducers, AConsumers: Integer);
var
  LProducers: array[0..7] of TPlatformThreadHandle;
  LConsumers: array[0..7] of TPlatformThreadHandle;
  LI: Integer;
  LRet: Pointer;
  LOpsPerP, LOpsPerC: Integer;
begin
  if (AProducers < 1) or (AConsumers < 1) or (AProducers > 8) or (AConsumers > 8) then
    raise EInvalidOperationError.Create('RunMatchedChannelOnce: bad producer/consumer count');
  if (OPS mod AProducers <> 0) or (OPS mod AConsumers <> 0) then
    raise EInvalidOperationError.Create('RunMatchedChannelOnce: OPS must divide producer/consumer counts');

  LOpsPerP := OPS div AProducers;
  LOpsPerC := OPS div AConsumers;
  GMatchCh := TIntChannel.Create(CAPACITY);
  GMatchSum := 0;
  try
    for LI := 0 to AConsumers - 1 do
      if platform_thread_create(LConsumers[LI], @MatchConsumer, Pointer(PtrUInt(LOpsPerC))) <> 0 then
        raise EInvalidOperationError.Create('consumer create failed');
    for LI := 0 to AProducers - 1 do
      if platform_thread_create(LProducers[LI], @MatchProducer, Pointer(PtrUInt(LOpsPerP))) <> 0 then
        raise EInvalidOperationError.Create('producer create failed');
    for LI := 0 to AProducers - 1 do
      platform_thread_join(LProducers[LI], LRet);
    for LI := 0 to AConsumers - 1 do
      platform_thread_join(LConsumers[LI], LRet);
    GBenchSink := GBenchSink + GMatchSum;
  finally
    GMatchCh.Close;
    GMatchCh.Free;
    GMatchCh := nil;
  end;
end;

procedure BenchMatchedC1(const ACtx: IBenchContext);
begin
  RunMatchedChannelOnce(1, 1);
  ACtx.SetBytes(OPS * SizeOf(Integer));
end;

procedure BenchMatchedC2(const ACtx: IBenchContext);
begin
  RunMatchedChannelOnce(2, 2);
  ACtx.SetBytes(OPS * SizeOf(Integer));
end;

procedure BenchMatchedC1Spsc(const ACtx: IBenchContext);
begin
  RunMatchedChannelSpscOnce;
  ACtx.SetBytes(OPS * SizeOf(Integer));
end;

procedure BenchMatchedM1Mpsc(const ACtx: IBenchContext);
begin
  RunMatchedMpscOnce(1);
  ACtx.SetBytes(OPS * SizeOf(Integer));
end;

procedure BenchMatchedM2Mpsc(const ACtx: IBenchContext);
begin
  RunMatchedMpscOnce(2);
  ACtx.SetBytes(OPS * SizeOf(Integer));
end;

procedure BenchMatchedW1Pool(const ACtx: IBenchContext);
begin
  RunMatchedPoolOnce(1, 1);
  ACtx.SetBytes(OPS * SizeOf(Pointer));
end;

procedure BenchMatchedW2Pool(const ACtx: IBenchContext);
begin
  RunMatchedPoolOnce(2, 2);
  ACtx.SetBytes(OPS * SizeOf(Pointer));
end;

procedure BenchMatchedJ1ForkJoin(const ACtx: IBenchContext);
begin
  RunMatchedForkJoinOnce(1, 1);
  ACtx.SetBytes(OPS * SizeOf(Pointer));
end;

procedure BenchMatchedJ2ForkJoin(const ACtx: IBenchContext);
begin
  RunMatchedForkJoinOnce(2, 2);
  ACtx.SetBytes(OPS * SizeOf(Pointer));
end;

procedure RunMatchedSuite;
var
  LResults: IBenchResults;
begin
  WriteLn('=== Q5 matched suite (multi-thread; compare with Go/Rust) ===');
  WriteLn('Scenario C1: TLockFreeChannel 1P+1C  OPS=', OPS, ' CAP=', CAPACITY);
  WriteLn('Scenario C2: TLockFreeChannel 2P+2C  OPS=', OPS, ' CAP=', CAPACITY);
  WriteLn('Scenario C1s: TLockFreeChannelSpsc 1P+1C  OPS=', OPS, ' CAP=', CAPACITY);
  WriteLn('Scenario M1: TMpscQueue 1P+1C  OPS=', OPS, ' (unbounded)');
  WriteLn('Scenario M2: TMpscQueue 2P+1C  OPS=', OPS, ' (unbounded)');
  WriteLn('Scenario W1: TWorkStealingPool 1S+1T  OPS=', OPS, ' (4 workers, bounded deques)');
  WriteLn('Scenario W2: TWorkStealingPool 2S+2T  OPS=', OPS, ' (4 workers, bounded deques)');
  WriteLn('Scenario J1: TLockFreeForkJoinPool 1F+1W  OPS=', OPS, ' (4 workers, bounded deques)');
  WriteLn('Scenario J2: TLockFreeForkJoinPool 2F+2W  OPS=', OPS, ' (4 workers, bounded deques)');
  WriteLn('Note: Go uses buffered chan; Rust C1 uses std::sync::mpsc (unbounded).');
  WriteLn('      Absolute Mops only valid with full bench-envelope.md fields.');
  WriteLn;
  { One multi-thread sample per entry — avoid re-running 1M-op scenarios. }
  LResults := TBenchSuite.Create('lockfree-matched')
    .SetQuiet(True)
    .SetWarmupIters(0)
    .SetMinSamples(1)
    .SetMaxIterations(1)
    .SetMinDuration(TDuration.FromMicroseconds(1))
    .Add('lockfree/matched/C1_1P1C', @BenchMatchedC1)
    .Add('lockfree/matched/C2_2P2C', @BenchMatchedC2)
    .Add('lockfree/matched/C1s_ChannelSpsc_1P1C', @BenchMatchedC1Spsc)
    .Add('lockfree/matched/M1_Mpsc_1P1C', @BenchMatchedM1Mpsc)
    .Add('lockfree/matched/M2_Mpsc_2P1C', @BenchMatchedM2Mpsc)
    .Add('lockfree/matched/W1_Pool_1S1T', @BenchMatchedW1Pool)
    .Add('lockfree/matched/W2_Pool_2S2T', @BenchMatchedW2Pool)
    .Add('lockfree/matched/J1_ForkJoin_1F1W', @BenchMatchedJ1ForkJoin)
    .Add('lockfree/matched/J2_ForkJoin_2F2W', @BenchMatchedJ2ForkJoin)
    .Run;
  WriteLn(LResults.PrintToConsole);
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-lockfree-matched.json');
  WriteLn;
end;

procedure RunMicroSuite;
var
  LResults: IBenchResults;
  LI: Integer;
begin
  WriteLn('=== Micro suite (single-thread Try*; NOT matched to multi-thread Go/Rust) ===');
  WriteLn('Input size: capacity=', CAPACITY, '; framework-timed Try* loops');
  WriteLn;
  GSpsc := TIntSpsc.Create(CAPACITY);
  GMpmc := TIntMpmc.Create(CAPACITY);
  GSeg := TIntSegQueue.Create;
  GSpmc := TIntSpmc.Create(CAPACITY);
  GChannel := TIntChannel.Create(CAPACITY);
  GChannelSpsc := TIntChannelSpsc.Create(CAPACITY);
  GMpsc := TIntMpsc.Create;
  GPool := TWorkStealingPool.Create(1);
  GJPool := TLockFreeForkJoinPool.Create(1);
  GEbrDomain := TEbrDomain.Create;
  try
    for LI := 1 to CAPACITY do
    begin
      GSpsc.TryEnqueue(LI);
      GMpmc.TryEnqueue(LI);
      GSeg.TryEnqueue(LI);
      GSpmc.TryEnqueue(LI);
    end;
    LResults := TBenchSuite.Create('lockfree-micro')
      .SetQuiet(True)
      .SetMinDuration(TDuration.FromMilliseconds(50))
      .SetMinSamples(5)
      .Add('lockfree/micro/SPSC/TryDequeue', @BenchSpscTryDequeue)
      .Add('lockfree/micro/SPSC/TryEnqueueDequeuePair', @BenchSpscTryPair)
      .Add('lockfree/micro/MPMC/TryDequeue', @BenchMpmcTryDequeue)
      .Add('lockfree/micro/SegQueue/TryDequeue', @BenchSegTryDequeue)
      .Add('lockfree/micro/SPMC/TryDequeue', @BenchSpmcTryDequeue)
      .Add('lockfree/micro/MPSC/TryEnqueueDequeuePair', @BenchMpscTryPair)
      .Add('lockfree/micro/Pool/SubmitStealPair', @BenchPoolSubmitStealPair)
      .Add('lockfree/micro/ForkJoin/ForkPopPair', @BenchForkJoinPair)
      .Add('lockfree/micro/EBR/Retire', @BenchEbrRetire)
      .Add('lockfree/micro/Channel/TrySendReceive', @BenchChannelTrySendReceive)
      .Add('lockfree/micro/ChannelSpsc/TrySendReceive', @BenchChannelSpscTrySendReceive)
      .Run;
    WriteLn(LResults.PrintToConsole);
    ForceDirectories('build');
    LResults.SaveToJSON('build/bench-lockfree-micro.json');
  finally
    GEbrDomain.Free;
    GJPool.Close;
    GJPool.Free;
    GPool.Close;
    GPool.Free;
    GMpsc.Free;
    GSpsc.Free;
    GMpmc.Free;
    GSeg.Free;
    GSpmc.Free;
    GChannel.Free;
    GChannelSpsc.Free;
  end;
  WriteLn;
end;

var
  LMode: string;
begin
  WriteLn('Platform: ', OSName, '/', CPUName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  { Source-contract pins (test_lockfree): exact evidence fields. }
  WriteLn('Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T');
  WriteLn('Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)');
  WriteLn('build suite: Q5 matched C1/C2 + optional micro');
  WriteLn;
  GBenchSink := 0;

  LMode := 'all';
  if ParamCount >= 1 then
    LMode := LowerCase(ParamStr(1));

  if (LMode = 'matched') or (LMode = 'all') or (LMode = 'c1c2') then
    RunMatchedSuite;
  if (LMode = 'micro') or (LMode = 'all') then
    RunMicroSuite;

  WriteLn('Sink: ', GBenchSink);
  WriteLn('Done.');
end.
