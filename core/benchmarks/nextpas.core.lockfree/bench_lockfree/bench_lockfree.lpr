program bench_lockfree;
{**
 * Q5 matched + micro benches for nextpas.core.lockfree.
 *
 * Matched suite (compare with compare_go / compare_rust under same OPS/CAPACITY):
 *   C1 — TLockFreeChannel 1P+1C
 *   C2 — TLockFreeChannel 2P+2C
 * Micro (single-thread Try*; do NOT compare to multi-thread Go/Rust):
 *   SPSC/MPMC/Seg/SPMC TryDequeue, Channel 1T TrySendReceive, EBR Retire
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

var
  GSpsc: TIntSpsc;
  GMpmc: TIntMpmc;
  GSeg: TIntSegQueue;
  GSpmc: TIntSpmc;
  GChannel: TIntChannel;
  GChannelSpsc: TIntChannelSpsc;
  GBenchSink: Int64;
  GEbrDomain: TEbrDomain;

  { Matched multi-thread state }
  GMatchCh: TIntChannel;
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

procedure RunMatchedSuite;
var
  LResults: IBenchResults;
begin
  WriteLn('=== Q5 matched suite (multi-thread; compare with Go/Rust) ===');
  WriteLn('Scenario C1: TLockFreeChannel 1P+1C  OPS=', OPS, ' CAP=', CAPACITY);
  WriteLn('Scenario C2: TLockFreeChannel 2P+2C  OPS=', OPS, ' CAP=', CAPACITY);
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
      .Add('lockfree/micro/MPMC/TryDequeue', @BenchMpmcTryDequeue)
      .Add('lockfree/micro/SegQueue/TryDequeue', @BenchSegTryDequeue)
      .Add('lockfree/micro/SPMC/TryDequeue', @BenchSpmcTryDequeue)
      .Add('lockfree/micro/EBR/Retire', @BenchEbrRetire)
      .Add('lockfree/micro/Channel/TrySendReceive', @BenchChannelTrySendReceive)
      .Add('lockfree/micro/ChannelSpsc/TrySendReceive', @BenchChannelSpscTrySendReceive)
      .Run;
    WriteLn(LResults.PrintToConsole);
    ForceDirectories('build');
    LResults.SaveToJSON('build/bench-lockfree-micro.json');
  finally
    GEbrDomain.Free;
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
