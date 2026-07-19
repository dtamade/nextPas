program bench_lockfree;
{**
 * Q5 matched + micro benches for nextpas.core.lockfree.
 *
 * Matched suite (compare with compare_go / compare_rust under same OPS/CAPACITY):
 *   C1 — TLockFreeChannel 1P+1C
 *   C2 — TLockFreeChannel 2P+2C
 * Micro (single-thread Try*; do NOT compare to multi-thread Go/Rust):
 *   SPSC/MPMC/Seg/SPMC TryDequeue, Channel 1T TrySendReceive, EBR Retire
 *}
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.thread.init,
  nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.atomic, nextpas.core.lockfree,
  nextpas.core.lockfree.ebr, nextpas.core.lockfree.spsc, nextpas.core.lockfree.mpmc,
  nextpas.core.lockfree.segqueue, nextpas.core.lockfree.spmc,
  nextpas.core.lockfree.channel, nextpas.core.lockfree.channel.spsc,
  nextpas.core.platform.thread, nextpas.core.platform.time, nextpas.core.platform.info;

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

procedure PrintTimed(const AName: string; const AElapsedNs: QWord; const AOperations: Int64);
var
  LMs, LMops, LNsPerOp: Double;
begin
  if AElapsedNs = 0 then
  begin
    WriteLn(Format('  %-34s %8s  %6s  %5s', [AName, 'n/a', 'n/a', 'n/a']));
    Exit;
  end;
  LMs := Double(AElapsedNs) / 1.0e6;
  LMops := (Double(AOperations) / (Double(AElapsedNs) / 1.0e9)) / 1.0e6;
  LNsPerOp := Double(AElapsedNs) / Double(AOperations);
  WriteLn(Format('  %-34s %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [AName, LMs, LMops, LNsPerOp]));
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

procedure RunMatchedChannel(const AName: string; const AProducers, AConsumers: Integer);
var
  LProducers: array[0..7] of TPlatformThreadHandle;
  LConsumers: array[0..7] of TPlatformThreadHandle;
  LI: Integer;
  LStart, LEnd: QWord;
  LRet: Pointer;
  LOpsPerP, LOpsPerC: Integer;
begin
  if (AProducers < 1) or (AConsumers < 1) or (AProducers > 8) or (AConsumers > 8) then
    raise Exception.Create('RunMatchedChannel: bad producer/consumer count');
  if (OPS mod AProducers <> 0) or (OPS mod AConsumers <> 0) then
    raise Exception.Create('RunMatchedChannel: OPS must divide producer/consumer counts');

  LOpsPerP := OPS div AProducers;
  LOpsPerC := OPS div AConsumers;
  GMatchCh := TIntChannel.Create(CAPACITY);
  GMatchSum := 0;
  try
    LStart := platform_monotonic_ns;
    for LI := 0 to AConsumers - 1 do
      if platform_thread_create(LConsumers[LI], @MatchConsumer, Pointer(PtrUInt(LOpsPerC))) <> 0 then
        raise Exception.Create('consumer create failed');
    for LI := 0 to AProducers - 1 do
      if platform_thread_create(LProducers[LI], @MatchProducer, Pointer(PtrUInt(LOpsPerP))) <> 0 then
        raise Exception.Create('producer create failed');
    for LI := 0 to AProducers - 1 do
      platform_thread_join(LProducers[LI], LRet);
    for LI := 0 to AConsumers - 1 do
      platform_thread_join(LConsumers[LI], LRet);
    LEnd := platform_monotonic_ns;
    PrintTimed(AName, LEnd - LStart, OPS);
    GBenchSink := GBenchSink + GMatchSum;
  finally
    GMatchCh.Close;
    GMatchCh.Free;
    GMatchCh := nil;
  end;
end;

procedure RunMatchedSuite;
begin
  WriteLn('=== Q5 matched suite (multi-thread; compare with Go/Rust) ===');
  WriteLn('Scenario C1: TLockFreeChannel 1P+1C  OPS=', OPS, ' CAP=', CAPACITY);
  WriteLn('Scenario C2: TLockFreeChannel 2P+2C  OPS=', OPS, ' CAP=', CAPACITY);
  WriteLn('Note: Go uses buffered chan; Rust C1 uses std::sync::mpsc (unbounded).');
  WriteLn('      Absolute Mops only valid with full bench-envelope.md fields.');
  WriteLn;
  RunMatchedChannel('C1 TLockFreeChannel 1P+1C', 1, 1);
  RunMatchedChannel('C2 TLockFreeChannel 2P+2C', 2, 2);
  WriteLn;
end;

procedure RunMicroSuite;
var
  LSuite: IBenchSuite;
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
    LSuite := TBenchSuite.Create('lockfree-micro');
    LSuite.Add('SPSC/TryDequeue', @BenchSpscTryDequeue)
      .Add('MPMC/TryDequeue', @BenchMpmcTryDequeue)
      .Add('SegQueue/TryDequeue', @BenchSegTryDequeue)
      .Add('SPMC/TryDequeue', @BenchSpmcTryDequeue)
      .Add('EBR/Retire', @BenchEbrRetire)
      .Add('Channel/TrySendReceive 1T', @BenchChannelTrySendReceive)
      .Add('ChannelSpsc/TrySendReceive 1T', @BenchChannelSpscTrySendReceive);
    WriteLn(LSuite.Run.PrintToConsole);
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
