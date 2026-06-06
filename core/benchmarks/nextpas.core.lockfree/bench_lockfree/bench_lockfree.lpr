program bench_lockfree;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.atomic,
  nextpas.core.time.base,
  nextpas.core.lockfree.spsc,
  nextpas.core.lockfree.mpmc,
  nextpas.core.thread.channel,
  nextpas.core.platform.info,
  nextpas.core.platform.thread;

type
  TIntSpsc = specialize TSpscQueue<Integer>;
  TIntMpmc = specialize TMpmcQueue<Integer>;
  TIntChannel = specialize TChannel<Integer>;

const
  OPS = 1000000;

function BenchmarkPlatformName: string;
begin
  Result := OSName + ' ' + CPUName;
end;

procedure PrintBenchmarkEnvelope;
begin
  WriteLn('Platform: ', BenchmarkPlatformName);
  WriteLn('Compiler flags: -MObjFPC -Sh -O2');
  WriteLn('Input size: OPS=1000000; capacity=1024; scenarios=SPSC 1P+1C, MPMC 2P+2C, mutex channel baseline, Try* 1T');
  WriteLn('Baselines: nextpas.core.thread.channel mutex channel; compare_rust/main.rs external Rust source (not auto-run)');
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
  LStart: TInstant;
  LNs: Int64;
begin
  GSpsc := TIntSpsc.Create(1024);
  LCount := 0;
  LStart := TInstant.Now;
  platform_thread_create(LHandle, @SpscProducer, nil);
  while LCount < OPS do
  begin
    if GSpsc.DequeueWait(LV) then
      Inc(LCount);
  end;
  platform_thread_join(LHandle, LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  SPSC 1M ops          %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GSpsc.Free;
end;

{ MPMC benchmark: 2P + 2C }

var
  GMpmc: TIntMpmc;
  GMpmcDone: Int32;

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
begin
  Result := nil;
  while GMpmc.DequeueWait(LV) do
    InterlockedIncrement(GMpmcDone);
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
  GMpmcDone := 0;
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
  WriteLn(Format('  MPMC 2P+2C 1M ops    %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  GMpmc.Free;
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
  LStart: TInstant;
  LNs: Int64;
begin
  GMutexCh := TIntChannel.Create(1024);
  LCount := 0;
  LStart := TInstant.Now;
  platform_thread_create(LHandle, @MutexProducer, nil);
  while LCount < OPS do
  begin
    if GMutexCh.TryReceive(LV) then
      Inc(LCount);
  end;
  platform_thread_join(LHandle, LRetVal);
  LNs := LStart.Elapsed.AsNanoseconds;
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
  LStart: TInstant;
  LNs: Int64;
begin
  LQ := TIntSpsc.Create(1024);
  LStart := TInstant.Now;
  for LI := 1 to OPS do
  begin
    LQ.TryEnqueue(LI);
    LQ.TryDequeue(LV);
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
  WriteLn(Format('  SPSC Try* 1T 1M      %8.2f ms  %6.1f M ops/sec  %5.1f ns/op',
    [LNs / 1000000.0, OPS / (LNs / 1000000000.0) / 1000000.0, LNs / Double(OPS)]));
  LQ.Free;
end;

procedure BenchMpmcSingleThread;
var
  LQ: TIntMpmc;
  LI: Integer;
  LV: Integer;
  LStart: TInstant;
  LNs: Int64;
begin
  LQ := TIntMpmc.Create(1024);
  LStart := TInstant.Now;
  for LI := 1 to OPS do
  begin
    LQ.TryEnqueue(LI);
    LQ.TryDequeue(LV);
  end;
  LNs := LStart.Elapsed.AsNanoseconds;
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
  BenchMutexChannel;
  WriteLn;
  WriteLn('  --- Single-thread (pure Try* hot path) ---');
  BenchSpscSingleThread;
  BenchMpmcSingleThread;
  WriteLn;
  WriteLn('Done.');
end.
