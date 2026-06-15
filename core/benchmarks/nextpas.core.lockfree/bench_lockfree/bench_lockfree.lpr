program bench_lockfree;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.atomic,
  nextpas.core.time.base,
  nextpas.core.lockfree,
  nextpas.core.lockfree.ebr,
  nextpas.core.lockfree.spsc,
  nextpas.core.lockfree.mpmc,
  nextpas.core.thread.channel,
  nextpas.core.platform.info,
  nextpas.core.platform.thread;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntSegQueue = specialize TSegQueue<Integer>;
  TIntSpmc = specialize TSpmcQueue<Integer>;
  TIntChannel = specialize TChannel<Integer>;

const
  OPS = 1000000;

var
  GBenchSink: Int64;

function BenchmarkPlatformName: string;
begin
  Result := OSName + ' ' + CPUName;
end;

procedure PrintBenchmarkEnvelope;
begin
  WriteLn('Platform: ', BenchmarkPlatformName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T');
  WriteLn('Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs, compare_go/main.go, and compare_cpp/main.cpp external sources (not auto-run)');
  WriteLn;
end;

{ SPSC benchmark: 1 producer + 1 consumer }

var
  GSpsc: TIntSpsc;

function SpscProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to OPS do
    GSpsc.EnqueueWait(LI);
end;

procedure BenchSpsc;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LV, LCount: Integer;
  LSink: Int64;
  LStart: TInstant;
  LNs: Int64;
begin
  GSpsc := TIntSpsc.Create(1024);
  LCount := 0;
  LSink := 0;
  LStart := TInstant.Now;
  platform_thread_create(LHandle, @SpscProducer, nil);
  while LCount < OPS do
  begin
    if GSpsc.DequeueWait(LV) then
    begin
      Inc(LCount);
      LSink := LSink + LV;
    end;
  end;
  platform_thread_join(LHandle, LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + LSink;
  WriteLn(Format('  SPSC 1M ops          %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GSpsc.Free;
end;

{ MPMC benchmark: 2P + 2C }

var
  GMpmc: TIntMpmc;
  GMpmcSink: Int64;

function MpmcProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to OPS div 2 do
    GMpmc.EnqueueWait(LI);
end;

function MpmcConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LSink: Int64;
begin
  Result := nil;
  LSink := 0;
  while GMpmc.DequeueWait(LV) do
  begin
    LSink := LSink + LV;
  end;
  AtomicFetchAdd64(GMpmcSink, LSink, moAcqRel);
end;

procedure BenchMpmc;
var
  LP: array[0..1] of TPlatformThreadHandle;
  LC: array[0..1] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI: Integer;
  LStart: TInstant;
  LNs: Int64;
begin
  GMpmc := TIntMpmc.Create(1024);
  GMpmcSink := 0;
  LStart := TInstant.Now;
  for LI := 0 to 1 do
    platform_thread_create(LC[LI], @MpmcConsumer, nil);
  for LI := 0 to 1 do
    platform_thread_create(LP[LI], @MpmcProducer, nil);
  for LI := 0 to 1 do
    platform_thread_join(LP[LI], LRetVal);
  GMpmc.Close;
  for LI := 0 to 1 do
    platform_thread_join(LC[LI], LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + AtomicLoad64(GMpmcSink, moAcquire);
  WriteLn(Format('  MPMC 2P+2C 1M ops    %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GMpmc.Free;
end;

{ SegQueue benchmark: 2P + 2C, unbounded }

var
  GSegQueue: TIntSegQueue;
  GSegQueueSink: Int64;

function SegQueueProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to OPS div 2 do
    GSegQueue.Enqueue(LI);
end;

var
  GSegQueueDone: Int32;

function SegQueueConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LSink: Int64;
begin
  Result := nil;
  LSink := 0;
  while AtomicLoad32(GSegQueueDone, moAcquire) = 0 do
  begin
    if GSegQueue.TryDequeue(LV) then
      LSink := LSink + LV
    else
      CpuPause;
  end;
  while GSegQueue.TryDequeue(LV) do
    LSink := LSink + LV;
  AtomicFetchAdd64(GSegQueueSink, LSink, moAcqRel);
end;

procedure BenchSegQueue;
var
  LP: array[0..1] of TPlatformThreadHandle;
  LC: array[0..1] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI: Integer;
  LStart: TInstant;
  LNs: Int64;
begin
  GSegQueue := TIntSegQueue.Create;
  GSegQueueSink := 0;
  GSegQueueDone := 0;
  LStart := TInstant.Now;
  for LI := 0 to 1 do
    platform_thread_create(LC[LI], @SegQueueConsumer, nil);
  for LI := 0 to 1 do
    platform_thread_create(LP[LI], @SegQueueProducer, nil);
  for LI := 0 to 1 do
    platform_thread_join(LP[LI], LRetVal);
  AtomicStore32(GSegQueueDone, 1, moRelease);
  for LI := 0 to 1 do
    platform_thread_join(LC[LI], LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + AtomicLoad64(GSegQueueSink, moAcquire);
  WriteLn(Format('  SegQueue 2P+2C 1M     %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GSegQueue.Free;
end;

{ SPMC benchmark: 1P + 2C }

var
  GSpmc: TIntSpmc;
  GSpmcSink: Int64;

var
  GSpmcDone: Int32;

function SpmcProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to OPS do
    GSpmc.EnqueueWait(LI);
end;

function SpmcConsumer(AArg: Pointer): Pointer; cdecl;
var
  LV: Integer;
  LSink: Int64;
begin
  Result := nil;
  LSink := 0;
  while AtomicLoad32(GSpmcDone, moAcquire) = 0 do
  begin
    if GSpmc.TryDequeue(LV) then
      LSink := LSink + LV
    else
      CpuPause;
  end;
  while GSpmc.TryDequeue(LV) do
    LSink := LSink + LV;
  AtomicFetchAdd64(GSpmcSink, LSink, moAcqRel);
end;

procedure BenchSpmc;
var
  LP: TPlatformThreadHandle;
  LC: array[0..1] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LI: Integer;
  LStart: TInstant;
  LNs: Int64;
begin
  GSpmc := TIntSpmc.Create(1024);
  GSpmcSink := 0;
  GSpmcDone := 0;
  LStart := TInstant.Now;
  for LI := 0 to 1 do
    platform_thread_create(LC[LI], @SpmcConsumer, nil);
  platform_thread_create(LP, @SpmcProducer, nil);
  platform_thread_join(LP, LRetVal);
  AtomicStore32(GSpmcDone, 1, moRelease);
  for LI := 0 to 1 do
    platform_thread_join(LC[LI], LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + AtomicLoad64(GSpmcSink, moAcquire);
  WriteLn(Format('  SPMC 1P+2C 1M ops    %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GSpmc.Free;
end;

{ EBR microbenchmark: retire + collect }

procedure BenchEbrRetireCollect;
const
  EBR_OPS = 100000;
var
  LEbr: TEbrDomain;
  LI: Integer;
  LPtr: Pointer;
  LStart: TInstant;
  LNs: Int64;
  LGuard: TEbrGuard;
begin
  LEbr := TEbrDomain.Create;
  LStart := TInstant.Now;
  for LI := 1 to EBR_OPS do
  begin
    LPtr := GetMem(64);
    LEbr.Retire(LPtr, nil);
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  EBR retire 100K       %8.2f ms  %6.1f K ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, EBR_OPS / (LNs / 1000000000.0) / 1000.0, LNs / Double(EBR_OPS)]));

  LStart := TInstant.Now;
  for LI := 1 to EBR_OPS div 100 do
    LEbr.Collect;
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  EBR collect 1K        %8.2f ms  %6.1f K ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, (EBR_OPS div 100) / (LNs / 1000000000.0) / 1000.0, LNs / Double(EBR_OPS div 100)]));

  LGuard := TEbrGuard.Acquire(LEbr);
  LStart := TInstant.Now;
  for LI := 1 to EBR_OPS do
  begin
    LGuard.Release;
    LGuard := TEbrGuard.Acquire(LEbr);
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + 1; // prevent elision
  WriteLn(Format('  EBR guard acquire 100K %8.2f ms  %6.1f K ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, EBR_OPS / (LNs / 1000000000.0) / 1000.0, LNs / Double(EBR_OPS)]));
  LGuard.Release;
  LEbr.Free;
end;

{ Mutex channel baseline: 1P + 1C }

var
  GMutexCh: TIntChannel;

function MutexProducer(AArg: Pointer): Pointer; cdecl;
var
  LI: Integer;
begin
  Result := nil;
  for LI := 1 to OPS do
    GMutexCh.Send(LI);
end;

procedure BenchMutexChannel;
var
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
  LV, LCount: Integer;
  LSink: Int64;
  LStart: TInstant;
  LNs: Int64;
begin
  GMutexCh := TIntChannel.Create(1024);
  LCount := 0;
  LSink := 0;
  LStart := TInstant.Now;
  platform_thread_create(LHandle, @MutexProducer, nil);
  while LCount < OPS do
  begin
    if GMutexCh.TryReceive(LV) then
    begin
      Inc(LCount);
      LSink := LSink + LV;
    end;
  end;
  platform_thread_join(LHandle, LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + LSink;
  WriteLn(Format('  Mutex Ch 1P+1C 1M    %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GMutexCh.Free;
end;

{ Single-thread throughput: pure Try* hot path, no contention }

procedure BenchSpscSingleThread;
var
  LQ: TIntSpsc;
  LI: Integer;
  LV: Integer;
  LSink: Int64;
  LStart: TInstant;
  LNs: Int64;
begin
  LQ := TIntSpsc.Create(1024);
  LSink := 0;
  LStart := TInstant.Now;
  for LI := 1 to OPS do
  begin
    LQ.TryEnqueue(LI);
    LQ.TryDequeue(LV);
    LSink := LSink + LV;
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + LSink;
  WriteLn(Format('  SPSC Try* 1T 1M      %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  LQ.Free;
end;

procedure BenchMpmcSingleThread;
var
  LQ: TIntMpmc;
  LI: Integer;
  LV: Integer;
  LSink: Int64;
  LStart: TInstant;
  LNs: Int64;
begin
  LQ := TIntMpmc.Create(1024);
  LSink := 0;
  LStart := TInstant.Now;
  for LI := 1 to OPS do
  begin
    LQ.TryEnqueue(LI);
    LQ.TryDequeue(LV);
    LSink := LSink + LV;
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  GBenchSink := GBenchSink + LSink;
  WriteLn(Format('  MPMC Try* 1T 1M      %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  LQ.Free;
end;

begin
  WriteLn('=== nextpas.core.lockfree benchmarks (1M ops) ===');
  PrintBenchmarkEnvelope;
  WriteLn('  --- Multi-thread (blocking wait) ---');
  BenchSpsc;
  BenchMpmc;
  BenchSegQueue;
  BenchSpmc;
  BenchMutexChannel;
  WriteLn;
  WriteLn('  --- Reclamation micro ---');
  BenchEbrRetireCollect;
  WriteLn;
  WriteLn('  --- Single-thread (pure Try* hot path) ---');
  BenchSpscSingleThread;
  BenchMpmcSingleThread;
  WriteLn;
  WriteLn('Sink: ', GBenchSink);
  WriteLn('Done.');
end.
