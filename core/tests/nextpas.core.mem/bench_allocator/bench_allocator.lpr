program bench_allocator;

{$I nextpas.core.settings.inc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

uses
  cthreads,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.allocator.growing,
  nextpas.core.platform.time;

var
  GAlloc: TGrowingAllocator;

{ --- Benchmark functions --- }

{ Pattern 1: Single-size alloc/free (64B). Go malloctest small. }
procedure BenchSmall64(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := GAlloc.GetMem(64);
  if ACtx <> nil then
    ACtx.SetBytes(64);
  GAlloc.FreeMem(LPtr, 64);
end;

{ Pattern 2: Medium alloc/free (1024B). }
procedure BenchMedium1K(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := GAlloc.GetMem(1024);
  if ACtx <> nil then
    ACtx.SetBytes(1024);
  GAlloc.FreeMem(LPtr, 1024);
end;

{ Pattern 3: Large alloc/free (16KB). }
procedure BenchLarge16K(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := GAlloc.GetMem(16384);
  if ACtx <> nil then
    ACtx.SetBytes(16384);
  GAlloc.FreeMem(LPtr, 16384);
end;

{ Pattern 4: Huge alloc/free (128KB — bypasses size classes). }
procedure BenchHuge128K(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := GAlloc.GetMem(131072);
  if ACtx <> nil then
    ACtx.SetBytes(131072);
  GAlloc.FreeMem(LPtr, 131072);
end;

{ Pattern 5: Mixed sizes (simulates real workload).
  Matches Go malloctest mixed pattern. }
procedure BenchMixed(const ACtx: IBenchContext);
var
  LSizes: array[0..7] of SizeUInt;
  LPtrs: array[0..7] of Pointer;
  I: Integer;
begin
  LSizes[0] := 16;   LSizes[1] := 64;   LSizes[2] := 256;
  LSizes[3] := 1024; LSizes[4] := 4096; LSizes[5] := 8192;
  LSizes[6] := 32768; LSizes[7] := 131072;
  for I := 0 to 7 do
    LPtrs[I] := GAlloc.GetMem(LSizes[I]);
  if ACtx <> nil then
    ACtx.SetBytes(16 + 64 + 256 + 1024 + 4096 + 8192 + 32768 + 131072);
  for I := 7 downto 0 do
    GAlloc.FreeMem(LPtrs[I], LSizes[I]);
end;

{ Pattern 6: Batch alloc then batch free (mimalloc sh6bench style).
  Allocates N blocks, then frees them all. }
const
  BATCH_SIZE = 64;

procedure BenchBatch64(const ACtx: IBenchContext);
var
  LPtrs: array[0..BATCH_SIZE - 1] of Pointer;
  I: Integer;
begin
  for I := 0 to BATCH_SIZE - 1 do
    LPtrs[I] := GAlloc.GetMem(128);
  if ACtx <> nil then
    ACtx.SetBytes(BATCH_SIZE * 128);
  for I := 0 to BATCH_SIZE - 1 do
    GAlloc.FreeMem(LPtrs[I], 128);
end;

{ Pattern 7: System allocator baseline (64B) for comparison. }
procedure BenchSystemSmall64(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  System.GetMem(LPtr, 64);
  if ACtx <> nil then
    ACtx.SetBytes(64);
  System.FreeMem(LPtr);
end;

{ Pattern 8: System allocator baseline (1024B). }
procedure BenchSystemMedium1K(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  System.GetMem(LPtr, 1024);
  if ACtx <> nil then
    ACtx.SetBytes(1024);
  System.FreeMem(LPtr);
end;

{ --- Concurrent benchmark (manual timing, bypasses framework) --- }
{ The bench framework measures per-call latency. For concurrent we need
  per-alloc+free latency across threads, so we time manually. }

const
  CONCURRENT_THREADS = 4;
  CONCURRENT_BATCH = 64;
  CONCURRENT_ITERS = 10000;  { batches per thread }

type
  PConcurrentWorker = ^TConcurrentWorker;
  TConcurrentWorker = record
    Alloc: TGrowingAllocator;
    AllocSize: SizeUInt;
    Iters: Integer;
  end;

function ConcurrentWorkerFunc(Parameter: Pointer): PtrInt;
var
  LWorker: PConcurrentWorker;
  LPtrs: array[0..CONCURRENT_BATCH - 1] of Pointer;
  J, I: Integer;
begin
  LWorker := PConcurrentWorker(Parameter);
  for J := 1 to LWorker^.Iters do
  begin
    for I := 0 to CONCURRENT_BATCH - 1 do
      LPtrs[I] := LWorker^.Alloc.GetMem(LWorker^.AllocSize);
    for I := 0 to CONCURRENT_BATCH - 1 do
      LWorker^.Alloc.FreeMem(LPtrs[I], LWorker^.AllocSize);
  end;
  Result := 0;
end;

procedure RunConcurrentManual(const AName: string; ASize: SizeUInt);
var
  LWorkers: array[0..CONCURRENT_THREADS - 1] of TConcurrentWorker;
  LThreads: array[0..CONCURRENT_THREADS - 1] of TThreadID;
  LStartNs, LEndNs, LTotalOps: UInt64;
  LElapsedNs: Double;
  I: Integer;
begin
  for I := 0 to CONCURRENT_THREADS - 1 do
  begin
    LWorkers[I].Alloc := GAlloc;
    LWorkers[I].AllocSize := ASize;
    LWorkers[I].Iters := CONCURRENT_ITERS;
  end;
  LStartNs := platform_monotonic_ns;
  for I := 0 to CONCURRENT_THREADS - 1 do
    LThreads[I] := BeginThread(@ConcurrentWorkerFunc, @LWorkers[I]);
  for I := 0 to CONCURRENT_THREADS - 1 do
    WaitForThreadTerminate(LThreads[I], 0);
  LEndNs := platform_monotonic_ns;
  LTotalOps := UInt64(CONCURRENT_THREADS) * CONCURRENT_BATCH * CONCURRENT_ITERS;
  LElapsedNs := LEndNs - LStartNs;
  WriteLn(AName: 30,
    '  ns/op=', Round(LElapsedNs / LTotalOps): 8,
    '  Mops/s=', FormatFloat('0.00', LTotalOps / (LElapsedNs / 1e9) / 1e6): 8,
    '  total_ops=', LTotalOps: 10,
    '  iters=', CONCURRENT_ITERS: 6);
end;

{ --- Main --- }

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  I: Integer;
begin
  GAlloc := TGrowingAllocator.Create;
  try
    LSuite := TBenchSuite.Create('allocator')
      .SetMinDuration(TDuration.FromMilliseconds(100))
      .SetMaxIterations(100000)
      .SetMinSamples(5)
      .SetWarmupIters(1000);

    { GrowingAllocator benchmarks. }
    LSuite.Add('growing/small_64B', @BenchSmall64);
    LSuite.Add('growing/medium_1KB', @BenchMedium1K);
    LSuite.Add('growing/large_16KB', @BenchLarge16K);
    LSuite.Add('growing/huge_128KB', @BenchHuge128K);
    LSuite.Add('growing/mixed_8sizes', @BenchMixed);
    LSuite.Add('growing/batch_64x128B', @BenchBatch64);

    { System allocator baselines. }
    LSuite.Add('system/small_64B', @BenchSystemSmall64);
    LSuite.Add('system/medium_1KB', @BenchSystemMedium1K);

    LResults := LSuite.Run;

    { Print single-threaded results. }
    WriteLn;
    WriteLn('=== Allocator Benchmark Results ===');
    WriteLn;
    begin
      LAll := LResults.GetAll;
      for I := 0 to Length(LAll) - 1 do
      begin
        WriteLn(LAll[I].Name: 30,
          '  ns/op=', Round(LAll[I].NsPerOp): 8,
          '  Mops/s=', FormatFloat('0.00', LAll[I].OpsPerSec / 1e6): 8,
          '  B/op=', LAll[I].BytesPerOp: 6,
          '  iters=', LAll[I].Iterations: 8);
      end;
    end;

    { Concurrent benchmarks (manual timing). }
    WriteLn;
    WriteLn('--- Concurrent (4 threads, per-alloc+free) ---');
    RunConcurrentManual('concurrent/4T_64B', 64);
    RunConcurrentManual('concurrent/4T_1KB', 1024);

    WriteLn;
    WriteLn('Done.');
  finally
    GAlloc.Free;
  end;
end.
