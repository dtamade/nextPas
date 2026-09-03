program test_bench_memtrack;

{$I nextpas.core.settings.inc}

uses
  {$ifdef unix}
  nextpas.core.thread.init,
  {$endif}
  nextpas.core.math.scalar,
  nextpas.core.platform.thread,
  nextpas.core.bench.memtrack,
  nextpas.core.bench.parallel,
  nextpas.core.test;

var
  GParallelTracker: TMemoryTracker;

{ === TMemoryTracker Tests === }

procedure Test_Create;
var
  LTracker: TMemoryTracker;
begin
  LTracker := TMemoryTracker.Create(True);
  Check(LTracker.IsEnabled = True, 'Enabled by default');
  Check(LTracker.GetStats.AllocCount = 0, 'Initial AllocCount = 0');
  Check(LTracker.GetStats.FreeCount = 0, 'Initial FreeCount = 0');
  Check(LTracker.GetStats.AllocBytes = 0, 'Initial AllocBytes = 0');
  Check(LTracker.GetStats.FreeBytes = 0, 'Initial FreeBytes = 0');
  Check(LTracker.GetStats.PeakAllocs = 0, 'Initial PeakAllocs = 0');
  Check(LTracker.GetStats.PeakBytes = 0, 'Initial PeakBytes = 0');
  Check(LTracker.GetStats.CurrentAllocs = 0, 'Initial CurrentAllocs = 0');
  Check(LTracker.GetStats.CurrentBytes = 0, 'Initial CurrentBytes = 0');
end;

procedure Test_Create_Disabled;
var
  LTracker: TMemoryTracker;
begin
  LTracker := TMemoryTracker.Create(False);
  Check(LTracker.IsEnabled = False, 'Disabled when specified');
end;

procedure Test_RecordAlloc;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 1, 'AllocCount = 1');
  Check(LStats.AllocBytes = 100, 'AllocBytes = 100');
  Check(LStats.CurrentAllocs = 1, 'CurrentAllocs = 1');
  Check(LStats.CurrentBytes = 100, 'CurrentBytes = 100');
  Check(LStats.PeakAllocs = 1, 'PeakAllocs = 1');
  Check(LStats.PeakBytes = 100, 'PeakBytes = 100');

  LTracker.RecordAlloc(200);
  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 2, 'AllocCount = 2');
  Check(LStats.AllocBytes = 300, 'AllocBytes = 300');
  Check(LStats.CurrentAllocs = 2, 'CurrentAllocs = 2');
  Check(LStats.CurrentBytes = 300, 'CurrentBytes = 300');
  Check(LStats.PeakAllocs = 2, 'PeakAllocs = 2');
  Check(LStats.PeakBytes = 300, 'PeakBytes = 300');
end;

procedure Test_RecordFree;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.RecordFree(100);

  LStats := LTracker.GetStats;
  Check(LStats.FreeCount = 1, 'FreeCount = 1');
  Check(LStats.FreeBytes = 100, 'FreeBytes = 100');
  Check(LStats.CurrentAllocs = 1, 'CurrentAllocs = 1');
  Check(LStats.CurrentBytes = 200, 'CurrentBytes = 200');
  Check(LStats.PeakAllocs = 2, 'PeakAllocs = 2');
  Check(LStats.PeakBytes = 300, 'PeakBytes = 300');
end;

procedure Test_Peak;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  LTracker := TMemoryTracker.Create(True);

  // Alloc 100 -> Current: 1 alloc, 100 bytes, Peak: 1 alloc, 100 bytes
  LTracker.RecordAlloc(100);
  // Alloc 200 -> Current: 2 allocs, 300 bytes, Peak: 2 allocs, 300 bytes
  LTracker.RecordAlloc(200);
  // Free 100 -> Current: 1 alloc, 200 bytes, Peak: 2 allocs, 300 bytes
  LTracker.RecordFree(100);
  // Alloc 300 -> Current: 2 allocs, 500 bytes, Peak: 2 allocs, 500 bytes
  LTracker.RecordAlloc(300);

  LStats := LTracker.GetStats;
  Check(LStats.PeakAllocs = 2, 'PeakAllocs = 2');
  Check(LStats.PeakBytes = 500, 'PeakBytes = 500');
  Check(LStats.CurrentAllocs = 2, 'CurrentAllocs = 2');
  Check(LStats.CurrentBytes = 500, 'CurrentBytes = 500');
end;

procedure Test_Reset;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.Reset;

  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 0, 'AllocCount = 0');
  Check(LStats.FreeCount = 0, 'FreeCount = 0');
  Check(LStats.AllocBytes = 0, 'AllocBytes = 0');
  Check(LStats.FreeBytes = 0, 'FreeBytes = 0');
  Check(LStats.PeakAllocs = 0, 'PeakAllocs = 0');
  Check(LStats.PeakBytes = 0, 'PeakBytes = 0');
  Check(LStats.CurrentAllocs = 0, 'CurrentAllocs = 0');
  Check(LStats.CurrentBytes = 0, 'CurrentBytes = 0');
end;

procedure Test_Disabled;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  LTracker := TMemoryTracker.Create(False);

  LTracker.RecordAlloc(100);
  LTracker.RecordFree(50);

  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = 0, 'AllocCount = 0 (disabled)');
  Check(LStats.FreeCount = 0, 'FreeCount = 0 (disabled)');
  Check(LStats.AllocBytes = 0, 'AllocBytes = 0 (disabled)');
  Check(LStats.FreeBytes = 0, 'FreeBytes = 0 (disabled)');
end;

procedure Test_BytesPerOp;
var
  LTracker: TMemoryTracker;
begin
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);

  Check(Abs(LTracker.BytesPerOp(1) - 300) < 0.01, 'BytesPerOp(1) = 300');
  Check(Abs(LTracker.BytesPerOp(2) - 150) < 0.01, 'BytesPerOp(2) = 150');
  Check(Abs(LTracker.BytesPerOp(0) - 0) < 0.01, 'BytesPerOp(0) = 0');
end;

procedure Test_AllocsPerOp;
var
  LTracker: TMemoryTracker;
begin
  LTracker := TMemoryTracker.Create(True);

  LTracker.RecordAlloc(100);
  LTracker.RecordAlloc(200);
  LTracker.RecordAlloc(300);

  Check(Abs(LTracker.AllocsPerOp(1) - 3) < 0.01, 'AllocsPerOp(1) = 3');
  Check(Abs(LTracker.AllocsPerOp(3) - 1) < 0.01, 'AllocsPerOp(3) = 1');
  Check(Abs(LTracker.AllocsPerOp(0) - 0) < 0.01, 'AllocsPerOp(0) = 0');
end;

procedure ParallelRecordAlloc(AThreadId: Integer; AIterations: Int64);
var
  LIteration: Int64;
begin
  for LIteration := 1 to AIterations do
    GParallelTracker.RecordAlloc(1);
end;

procedure ParallelRecordFree(AThreadId: Integer; AIterations: Int64);
var
  LIteration: Int64;
begin
  for LIteration := 1 to AIterations do
    GParallelTracker.RecordFree(1);
end;

type
  PMemoryTracker = ^TMemoryTracker;

  PAllocCtx = ^TAllocCtx;
  TAllocCtx = record
    Tracker: PMemoryTracker;
    BlockPtr: PPointer;
    Count: Integer;
    BlockSize: Integer;
  end;

function AllocProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PAllocCtx;
  I: Integer;
begin
  LCtx := PAllocCtx(AArg);
  for I := 0 to LCtx^.Count - 1 do
  begin
    LCtx^.BlockPtr[I] := GetMem(LCtx^.BlockSize);
    LCtx^.Tracker^.RecordAlloc(LCtx^.BlockSize);
  end;
  Result := nil;
end;

procedure ParallelAllocBlocks(ATracker: PMemoryTracker;
  ABlocks: array of Pointer; AThreadCount, AAllocsPerThread, ABlockSize: Integer);
var
  LRecs: array of TPlatformThreadRecord;
  LCtxs: array of PAllocCtx;
  LThread: Integer;
begin
  SetLength(LRecs, AThreadCount);
  SetLength(LCtxs, AThreadCount);
  for LThread := 0 to AThreadCount - 1 do
  begin
    New(LCtxs[LThread]);
    LCtxs[LThread]^.Tracker := ATracker;
    LCtxs[LThread]^.BlockPtr := PPointer(ABlocks[LThread]);
    LCtxs[LThread]^.Count := AAllocsPerThread;
    LCtxs[LThread]^.BlockSize := ABlockSize;
    Check(platform_thread_spawn(LRecs[LThread], @AllocProc, LCtxs[LThread]) = 0,
      'spawn alloc thread');
  end;

  for LThread := 0 to AThreadCount - 1 do
  begin
    Check(platform_thread_wait(LRecs[LThread]) = 0, 'join alloc thread');
    Dispose(LCtxs[LThread]);
  end;
end;

procedure TestMultiThreadPeakTracking;
const
  THREAD_COUNT = 4;
  ALLOCS_PER_THREAD = 100;
  BLOCK_SIZE = 1024;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
  LBlocks: array[0..3] of array of Pointer;
  LArgs: array[0..3] of Pointer;
  LThread, LAlloc: Integer;
begin
  LTracker := TMemoryTracker.Create(True);
  LTracker.Reset;

  // Allocate storage for thread blocks
  for LThread := 0 to THREAD_COUNT - 1 do
  begin
    SetLength(LBlocks[LThread], ALLOCS_PER_THREAD);
    LArgs[LThread] := @LBlocks[LThread][0];
  end;

  // Spawn 4 threads, each allocating 100 blocks of 1024 bytes
  ParallelAllocBlocks(@LTracker, LArgs, THREAD_COUNT, ALLOCS_PER_THREAD, BLOCK_SIZE);

  // Verify totals after all allocs
  LStats := LTracker.GetStats;
  Check(LStats.AllocCount = THREAD_COUNT * ALLOCS_PER_THREAD, 'AllocCount = 400');
  Check(LStats.AllocBytes = THREAD_COUNT * ALLOCS_PER_THREAD * BLOCK_SIZE, 'AllocBytes = 400*1024');

  // Free all blocks from main thread
  for LThread := 0 to THREAD_COUNT - 1 do
    for LAlloc := 0 to ALLOCS_PER_THREAD - 1 do
    begin
      FreeMem(LBlocks[LThread][LAlloc]);
      LTracker.RecordFree(BLOCK_SIZE);
    end;

  LStats := LTracker.GetStats;

  // Key invariant: Peak was captured and is not underestimated
  Check(LStats.PeakAllocs >= LStats.CurrentAllocs,
    'PeakAllocs >= CurrentAllocs (peak captured)');
  Check(LStats.PeakAllocs > 0, 'PeakAllocs > 0');
  Check(LStats.PeakBytes > 0, 'PeakBytes > 0');
  Check(LStats.CurrentAllocs = 0, 'CurrentAllocs = 0 after freeing all');
  Check(LStats.CurrentBytes = 0, 'CurrentBytes = 0 after freeing all');
end;

procedure Test_ParallelThreadSafety;
const
  THREAD_COUNT = 8;
  ITERS_PER_THREAD = 200000;
var
  LBench: TParallelBenchmark;
  LStats: TMemoryStats;
begin
  GParallelTracker := TMemoryTracker.Create(True);

  LBench := TParallelBenchmark.Create(@ParallelRecordAlloc, THREAD_COUNT,
    ITERS_PER_THREAD, 0);
  LBench.Execute;
  { TG-22: all threads have joined at this point (Execute blocks on WaitFor),
    so stats are fully visible }
  LStats := GParallelTracker.GetStats;
  Check(LStats.AllocCount = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel AllocCount exact');
  Check(LStats.AllocBytes = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel AllocBytes exact');
  Check(LStats.CurrentAllocs = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel CurrentAllocs exact');
  Check(LStats.CurrentBytes = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel CurrentBytes exact');

  LBench := TParallelBenchmark.Create(@ParallelRecordFree, THREAD_COUNT,
    ITERS_PER_THREAD, 0);
  LBench.Execute;
  { TG-22: all threads have joined; free stats are now fully visible }
  LStats := GParallelTracker.GetStats;
  Check(LStats.FreeCount = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel FreeCount exact');
  Check(LStats.FreeBytes = THREAD_COUNT * ITERS_PER_THREAD, 'Parallel FreeBytes exact');
  Check(LStats.CurrentAllocs = 0, 'Parallel CurrentAllocs returns to 0');
  Check(LStats.CurrentBytes = 0, 'Parallel CurrentBytes returns to 0');
end;

{ === TG-01: GlobalMemoryTracker API Tests === }

procedure Test_GlobalMemoryTracking_EnableDisable;
var
  LStatsBefore, LStatsAfter: TMemoryStats;
  LPtr: Pointer;
  LAllocCountBeforeDisable: Int64;
begin
  // Disable first to ensure clean state
  DisableGlobalMemoryTracking;
  ResetGlobalMemoryTracker;

  // Enable tracking
  EnableGlobalMemoryTracking;

  // Perform a known allocation
  LPtr := GetMem(256);
  LStatsBefore := GetGlobalMemoryStats;
  Check(LStatsBefore.AllocCount > 0, 'GetGlobalMemoryStats shows AllocCount > 0 after alloc');
  Check(LStatsBefore.AllocBytes >= 256, 'GetGlobalMemoryStats shows AllocBytes >= 256');

  FreeMem(LPtr);
  LAllocCountBeforeDisable := GetGlobalMemoryStats.AllocCount;

  // Disable tracking
  DisableGlobalMemoryTracking;

  // After disabling, further allocations should not be tracked
  LPtr := GetMem(512);
  LStatsAfter := GetGlobalMemoryStats;
  Check(LStatsAfter.AllocCount = LAllocCountBeforeDisable,
    'Disabled tracking: alloc count frozen after disable');
  FreeMem(LPtr);
end;

procedure Test_GlobalMemoryTracker_Reset;
var
  LStats: TMemoryStats;
  LPtr: Pointer;
begin
  EnableGlobalMemoryTracking;
  LPtr := GetMem(128);

  ResetGlobalMemoryTracker;
  LStats := GetGlobalMemoryStats;
  Check(LStats.AllocCount = 0, 'ResetGlobalMemoryTracker resets AllocCount to 0');
  Check(LStats.FreeCount = 0, 'ResetGlobalMemoryTracker resets FreeCount to 0');
  Check(LStats.AllocBytes = 0, 'ResetGlobalMemoryTracker resets AllocBytes to 0');
  Check(LStats.FreeBytes = 0, 'ResetGlobalMemoryTracker resets FreeBytes to 0');
  Check(LStats.PeakAllocs = 0, 'ResetGlobalMemoryTracker resets PeakAllocs to 0');
  Check(LStats.PeakBytes = 0, 'ResetGlobalMemoryTracker resets PeakBytes to 0');

  DisableGlobalMemoryTracking;
  FreeMem(LPtr);
end;

procedure Test_GetGlobalMemoryStats;
var
  LStats: TMemoryStats;
begin
  ResetGlobalMemoryTracker;
  EnableGlobalMemoryTracking;

  // Get stats - should have reasonable structure
  LStats := GetGlobalMemoryStats;
  // After reset+enable, current allocs should be >= 0 (may have internal allocs)
  Check(LStats.AllocCount >= 0, 'GetGlobalMemoryStats: AllocCount >= 0');
  Check(LStats.FreeCount >= 0, 'GetGlobalMemoryStats: FreeCount >= 0');
  Check(LStats.PeakAllocs >= 0, 'GetGlobalMemoryStats: PeakAllocs >= 0');
  Check(LStats.PeakBytes >= 0, 'GetGlobalMemoryStats: PeakBytes >= 0');

  DisableGlobalMemoryTracking;
end;

procedure Test_ReAllocMem_Tracking;
var
  LPtr: Pointer;
  LNilPtr: Pointer;
  LStatsBeforeRealloc, LStatsAfterRealloc: TMemoryStats;
begin
  DisableGlobalMemoryTracking;
  ResetGlobalMemoryTracker;
  EnableGlobalMemoryTracking;

  // Initial alloc
  LPtr := GetMem(128);
  Check(LPtr <> nil, 'Initial GetMem(128) returns non-nil');

  LStatsBeforeRealloc := GetGlobalMemoryStats;
  Check(LStatsBeforeRealloc.AllocCount >= 1, 'Before realloc: AllocCount >= 1');
  Check(LStatsBeforeRealloc.AllocBytes >= 128, 'Before realloc: AllocBytes >= 128');

  // ReAlloc to larger size
  LPtr := ReAllocMem(LPtr, 512);
  Check(LPtr <> nil, 'ReAllocMem(128 -> 512) returns non-nil');

  LStatsAfterRealloc := GetGlobalMemoryStats;
  // ReAllocMem should record a free (old size) and an alloc (new size)
  Check(LStatsAfterRealloc.AllocCount > LStatsBeforeRealloc.AllocCount,
    'ReAllocMem increments AllocCount');
  Check(LStatsAfterRealloc.FreeCount > LStatsBeforeRealloc.FreeCount,
    'ReAllocMem increments FreeCount (old block freed)');
  Check(LStatsAfterRealloc.AllocBytes >= LStatsBeforeRealloc.AllocBytes + 512,
    'ReAllocMem accounts for new allocation bytes');

  // ReAlloc to smaller size
  LPtr := ReAllocMem(LPtr, 64);
  Check(LPtr <> nil, 'ReAllocMem(512 -> 64) returns non-nil');

  // ReAlloc nil (should behave like GetMem)
  LNilPtr := nil;
  LNilPtr := ReAllocMem(LNilPtr, 256);
  Check(LNilPtr <> nil, 'ReAllocMem(nil, 256) returns non-nil (acts as alloc)');
  FreeMem(LNilPtr);

  FreeMem(LPtr);

  DisableGlobalMemoryTracking;
end;

procedure Test_GlobalMemoryTracker_Singleton;
var LTracker1, LTracker2: TMemoryTracker;
begin
  LTracker1 := GlobalMemoryTracker;
  LTracker2 := GlobalMemoryTracker;
  Check(LTracker1.IsEnabled = LTracker2.IsEnabled, 'GlobalMemoryTracker returns consistent state');
end;

procedure Test_RecordFree_ClampNonNegative;
var
  LTracker: TMemoryTracker;
  LStats: TMemoryStats;
begin
  { F-08: free without matching alloc must not drive Current* negative }
  LTracker := TMemoryTracker.Create(True);
  LTracker.RecordFree(64);
  LStats := LTracker.GetStats;
  Check(LStats.CurrentAllocs >= 0, 'RecordFree clamp: CurrentAllocs >= 0');
  Check(LStats.CurrentBytes >= 0, 'RecordFree clamp: CurrentBytes >= 0');
  Check(LStats.FreeCount = 1, 'RecordFree clamp: FreeCount counted');
end;

procedure Test_TryEnableGlobalMemoryTracking;
var
  LOk: Boolean;
begin
  DisableGlobalMemoryTracking;
  LOk := TryEnableGlobalMemoryTracking;
  {$ifdef HEAPTRC_ACTIVE}
  Check(not LOk, 'TryEnable under heaptrc returns False');
  {$else}
  Check(LOk, 'TryEnable succeeds without heaptrc');
  Check(IsGlobalMemoryTrackingEnabled, 'tracking enabled after Try');
  {$endif}
  DisableGlobalMemoryTracking;
end;

var
  T: TTestSuite;
  LRunPassed: Boolean;
begin
  T := TTestSuite.Create('nextpas.core.bench.memtrack');

  T.Test('Create', @Test_Create);
  T.Test('Create_Disabled', @Test_Create_Disabled);
  T.Test('RecordAlloc', @Test_RecordAlloc);
  T.Test('RecordFree', @Test_RecordFree);
  T.Test('Peak', @Test_Peak);
  T.Test('Reset', @Test_Reset);
  T.Test('Disabled', @Test_Disabled);
  T.Test('BytesPerOp', @Test_BytesPerOp);
  T.Test('AllocsPerOp', @Test_AllocsPerOp);
  T.Test('ParallelThreadSafety', @Test_ParallelThreadSafety);
  T.Test('MultiThreadPeakTracking', @TestMultiThreadPeakTracking);
  T.Test('GlobalMemoryTracking_EnableDisable', @Test_GlobalMemoryTracking_EnableDisable);
  T.Test('GlobalMemoryTracker_Reset', @Test_GlobalMemoryTracker_Reset);
  T.Test('GetGlobalMemoryStats', @Test_GetGlobalMemoryStats);
  T.Test('ReAllocMem_Tracking', @Test_ReAllocMem_Tracking);
  T.Test('GlobalMemoryTracker_Singleton', @Test_GlobalMemoryTracker_Singleton);
  T.Test('RecordFree_ClampNonNegative', @Test_RecordFree_ClampNonNegative);
  T.Test('TryEnableGlobalMemoryTracking', @Test_TryEnableGlobalMemoryTracking);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
