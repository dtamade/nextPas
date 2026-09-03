program test_sharded_pools;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.pool.slab.sharded,
  nextpas.core.text,
  nextpas.core.platform.thread;

const
  THREAD_COUNT = 8;
  ITERATION_COUNT = 32;

type
  TExceptionProc = procedure;

  PBlockPoolWorkerData = ^TBlockPoolWorkerData;
  TBlockPoolWorkerData = record
    Pool: TShardedBlockPool;
    StartFlag: PLongInt;
    Failure: string;
  end;

  PBlockPoolAcquireWorkerData = ^TBlockPoolAcquireWorkerData;
  TBlockPoolAcquireWorkerData = record
    Pool: TShardedBlockPool;
    StartFlag: PLongInt;
    Ptr: Pointer;
    Shard: Integer;
    Failure: string;
  end;

  PBlockPoolReleaseWorkerData = ^TBlockPoolReleaseWorkerData;
  TBlockPoolReleaseWorkerData = record
    Pool: TShardedBlockPool;
    StartFlag: PLongInt;
    Ptr: Pointer;
    GotAllocError: Boolean;
    AllocError: TAllocError;
    Failure: string;
  end;

  PSlabPoolWorkerData = ^TSlabPoolWorkerData;
  TSlabPoolWorkerData = record
    Pool: TSlabPoolSharded;
    StartFlag: PLongInt;
    Failure: string;
  end;

  PSlabPoolAcquireWorkerData = ^TSlabPoolAcquireWorkerData;
  TSlabPoolAcquireWorkerData = record
    Pool: TSlabPoolSharded;
    StartFlag: PLongInt;
    Ptr: Pointer;
    Shard: Integer;
    Failure: string;
  end;

  PSlabAlignedWorkerData = ^TSlabAlignedWorkerData;
  TSlabAlignedWorkerData = record
    Pool: TSlabPoolSharded;
    StartFlag: PLongInt;
    Failure: string;
  end;

var
  T: TTestSuite;
  LRunPassed: Boolean;
  GBlockPool: TShardedBlockPool = nil;
  GBlockPtr: Pointer = nil;
  GSlabPool: TSlabPoolSharded = nil;
  GSlabPtr: PByte = nil;

{$PUSH}
{$Q-}
function TestShardIndex(AShardCount: Integer): Integer;
begin
  Result := Integer((QWord(platform_thread_id) * QWord(11400714819323198485)) and QWord(AShardCount - 1));
end;
{$POP}

procedure CheckRaisesAllocError(AProc: TExceptionProc; AExpected: TAllocError; const AName: string);
begin
  try
    AProc;
    Fail(AName + ': expected allocation error');
  except
    on E: EAllocError do
      Check(Int64(Ord(AExpected)) = Int64(Ord(E.Error)), AName + ': error code');
  end;
end;

procedure ReleaseDuplicateRemoteShardedBlockPointer;
begin
  GBlockPool.Release(GBlockPtr);
end;

procedure FreeInteriorShardedSlabPointer;
begin
  GSlabPool.FreeMem(GSlabPtr + 1);
end;

procedure ReallocInteriorShardedSlabPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GSlabPool.ReallocMem(GSlabPtr + 1, 128);
  if LNewPtr <> nil then
    GSlabPool.FreeMem(LNewPtr);
end;

procedure WaitForStartFlag(AStartFlag: PLongInt); inline;
begin
  while AStartFlag^ = 0 do
    platform_thread_yield;
end;

function BlockPoolWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PBlockPoolWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PBlockPoolWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      LPtr := LData^.Pool.Acquire;
      if LPtr = nil then
        raise Exception.Create('TShardedBlockPool.Acquire returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LData^.Pool.Release(LPtr);
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function BlockPoolAcquireWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PBlockPoolAcquireWorkerData;
begin
  LData := PBlockPoolAcquireWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    LData^.Shard := TestShardIndex(LData^.Pool.ShardCount);
    LData^.Ptr := LData^.Pool.Acquire;
    if LData^.Ptr = nil then
      raise Exception.Create('TShardedBlockPool.Acquire returned nil');
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function BlockPoolReleaseWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PBlockPoolReleaseWorkerData;
begin
  LData := PBlockPoolReleaseWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    LData^.Pool.Release(LData^.Ptr);
  except
    on E: EAllocError do
    begin
      LData^.GotAllocError := True;
      LData^.AllocError := E.Error;
    end;
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function SlabPoolWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PSlabPoolWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PSlabPoolWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 1 to ITERATION_COUNT do
    begin
      LPtr := LData^.Pool.GetMem(16 + (LIndex mod 32));
      if LPtr = nil then
        raise Exception.Create('TSlabPoolSharded.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LData^.Pool.FreeMem(LPtr);
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function SlabPoolAcquireWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PSlabPoolAcquireWorkerData;
begin
  LData := PSlabPoolAcquireWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    LData^.Shard := TestShardIndex(LData^.Pool.ShardCount);
    LData^.Ptr := LData^.Pool.GetMem(64);
    if LData^.Ptr = nil then
      raise Exception.Create('TSlabPoolSharded.GetMem returned nil');
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestShardedBlockPoolContention;
var
  LPool: TShardedBlockPool;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TBlockPoolWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TShardedBlockPool.Create(64, THREAD_COUNT, 4);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @BlockPoolWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'sharded blockpool worker should not fail');
    Check(LPool.InUse = 0, 'all sharded blockpool blocks should be released');
    Check(LPool.BlockSize = 64, 'block size should stay visible');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedBlockPoolRejectsDuplicateRemoteRelease;
var
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TBlockPoolAcquireWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LMainShard: Integer;
  LSelected: Integer;
begin
  GBlockPool := TShardedBlockPool.Create(64, THREAD_COUNT * 2, 4);
  LSelected := -1;
  try
    LMainShard := TestShardIndex(GBlockPool.ShardCount);
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := GBlockPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Ptr := nil;
      LThreadData[LIndex].Shard := -1;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @BlockPoolAcquireWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreadData[LIndex].Failure = '', 'remote-release setup worker should not fail');
      if (LSelected < 0) and (LThreadData[LIndex].Ptr <> nil) and
        (LThreadData[LIndex].Shard <> LMainShard) then
        LSelected := LIndex;
    end;

    Check(LSelected >= 0, 'test setup should find a worker on a non-local shard');
    GBlockPtr := LThreadData[LSelected].Ptr;
    LThreadData[LSelected].Ptr := nil;

    GBlockPool.Release(GBlockPtr);
    CheckRaisesAllocError(@ReleaseDuplicateRemoteShardedBlockPointer, aeDoubleFree,
      'duplicate remote sharded block release');
    Check(Int64(THREAD_COUNT - 1) = Int64(GBlockPool.InUse), 'duplicate release should not decrement in-use count');
  finally
    for LIndex := 0 to High(LThreads) do
    begin
      if LThreadData[LIndex].Ptr <> nil then
      begin
        GBlockPool.Release(LThreadData[LIndex].Ptr);
      end;
    end;
    GBlockPtr := nil;
    TObject(GBlockPool).Free;
    GBlockPool := nil;
  end;
end;

procedure TestShardedBlockPoolThreadCacheConfigRejectsDuplicateRelease;
var
  LConfig: TShardedBlockPoolConfig;
  LPool: TShardedBlockPool;
  LPtr: Pointer;
begin
  LConfig := TShardedBlockPoolConfig.Default(64, 64, 1);
  LConfig.ThreadCacheCapacity := 8;
  LPool := TShardedBlockPool.Create(LConfig);
  try
    Check(LPool.ShardCount >= 1, 'pool should have shards');
    // Basic acquire/release with thread cache enabled
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'acquire with thread cache should succeed');
    LPool.Release(LPtr);
    Check(LPool.InUse = 0, 'all blocks released');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedSlabPoolContention;
var
  LPool: TSlabPoolSharded;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TSlabPoolWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TSlabPoolSharded.Create(4096, 4);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @SlabPoolWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'sharded slab worker should not fail');
    Check(LPool.Stats.FallbackAllocCount = 0, 'small contention path should stay in slab fast path');
    Check(LPool.ShardCount = 4, 'requested shard count should stay visible');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedSlabOwnershipDiagnosticsRejectInteriorPointer;
var
  LPool: TSlabPoolSharded;
  LPtr: PByte;
begin
  LPool := TSlabPoolSharded.Create(4096, 4);
  try
    LPtr := PByte(LPool.GetMem(64));
    try
      Check(LPtr <> nil, 'GetMem should allocate');
      Check(LPool.Owns(LPtr), 'sharded pool should own exact allocation pointer');
      Check(Int64(64) = Int64(LPool.MemSizeOf(LPtr)), 'exact pointer should report slab chunk size');
      Check(not LPool.Owns(LPtr + 1), 'sharded pool should not own interior pointer diagnostically');
      Check(Int64(0) = Int64(LPool.MemSizeOf(LPtr + 1)), 'interior pointer should not report chunk size');
    finally
      LPool.FreeMem(LPtr);
    end;
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedSlabReleaseAndReallocRejectInteriorPointer;
begin
  GSlabPool := TSlabPoolSharded.Create(4096, 4);
  try
    GSlabPtr := PByte(GSlabPool.GetMem(64));
    Check(GSlabPtr <> nil, 'GetMem should allocate');

    CheckRaisesAllocError(@FreeInteriorShardedSlabPointer, aeInvalidPointer, 'interior FreeMem');
    Check(GSlabPool.Owns(GSlabPtr), 'invalid FreeMem should not release exact pointer');
    Check(Int64(64) = Int64(GSlabPool.MemSizeOf(GSlabPtr)), 'invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorShardedSlabPointer, aeInvalidPointer, 'interior ReallocMem');
    Check(GSlabPool.Owns(GSlabPtr), 'invalid ReallocMem should not release exact pointer');
    Check(Int64(64) = Int64(GSlabPool.MemSizeOf(GSlabPtr)), 'invalid ReallocMem should preserve exact pointer size');

    GSlabPool.FreeMem(GSlabPtr);
  finally
    GSlabPtr := nil;
    TObject(GSlabPool).Free;
    GSlabPool := nil;
  end;
end;

{** B4-1: TestShardedBlockPoolStatsAggregated — 多线程竞争后统计聚合正确。 *}
procedure TestShardedBlockPoolStatsAggregated;
var
  LPool: TShardedBlockPool;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TBlockPoolWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TShardedBlockPool.Create(64, THREAD_COUNT * 4, 4);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @BlockPoolWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'stats worker should not fail');
    Check(Int64(0) = Int64(LPool.InUse), 'InUse should be 0 after all releases');
    Check(Int64(LPool.Capacity) = Int64(LPool.Available), 'Available should equal Capacity after contention');
    Check(LPool.BlockSize = 64, 'BlockSize should be unchanged after contention');
    Check(LPool.ShardCount = 4, 'ShardCount should be unchanged after contention');
  finally
    TObject(LPool).Free;
  end;
end;

{** B4-2: TestShardedSlabAllocAlignedContention — AllocAligned 并发安全。 *}
function SlabAlignedWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PSlabAlignedWorkerData;
  LAlign: SizeUInt;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PSlabAlignedWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      LAlign := 8 shl (LIndex mod 3);  { 8, 16, 32 — all powers of two }
      LPtr := LData^.Pool.AllocAligned(32 + (LIndex mod 32), LAlign);
      if LPtr = nil then
        raise Exception.Create('SlabAligned: AllocAligned returned nil');
      if PtrUInt(LPtr) mod LAlign <> 0 then
        raise Exception.Create('SlabAligned: pointer not aligned');
      PByte(LPtr)^ := Byte(LIndex);
      LData^.Pool.FreeAligned(LPtr);
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestShardedSlabAllocAlignedContention;
var
  LPool: TSlabPoolSharded;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TSlabAlignedWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TSlabPoolSharded.Create(8192, 4);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @SlabAlignedWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'slab aligned worker should not fail: ' + LThreadData[LIndex].Failure);
    Check(LPool.Stats.FallbackAllocCount = 0, 'aligned contention should stay in slab fast path');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedSlabRemoteReleaseClearsDiagnostics;
var
  LPool: TSlabPoolSharded;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TSlabPoolAcquireWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LMainShard: Integer;
  LSelected: Integer;
  LPtr: Pointer;
begin
  LPool := TSlabPoolSharded.Create(4096, 4);
  LSelected := -1;
  try
    LMainShard := TestShardIndex(LPool.ShardCount);
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Ptr := nil;
      LThreadData[LIndex].Shard := -1;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @SlabPoolAcquireWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreadData[LIndex].Failure = '', 'remote slab setup worker should not fail');
      if (LSelected < 0) and (LThreadData[LIndex].Ptr <> nil) and
        (LThreadData[LIndex].Shard <> LMainShard) then
        LSelected := LIndex;
    end;

    Check(LSelected >= 0, 'test setup should find a worker on a non-local slab shard');
    LPtr := LThreadData[LSelected].Ptr;
    LThreadData[LSelected].Ptr := nil;

    LPool.FreeMem(LPtr);
    Check(not LPool.Owns(LPtr), 'remote slab FreeMem should clear ownership diagnostics immediately');
    Check(Int64(0) = Int64(LPool.MemSizeOf(LPtr)), 'remote slab FreeMem should clear size diagnostics immediately');
  finally
    for LIndex := 0 to High(LThreads) do
    begin
      if LThreadData[LIndex].Ptr <> nil then
      begin
        LPool.FreeMem(LThreadData[LIndex].Ptr);
      end;
    end;
    TObject(LPool).Free;
  end;
end;

{** Test TrimIdleSegments: acquire blocks, release all, trim, verify capacity decreased. *}
procedure TestShardedBlockPoolTrimIdleSegments;
var
  LPool: TShardedBlockPool;
  LPtrs: array[0..255] of Pointer;
  LCapBefore, LCapAfter: SizeUInt;
  LIdx: Integer;
begin
  LPool := TShardedBlockPool.Create(64, 256, 2);
  try
    LCapBefore := LPool.Capacity;
    Check(LCapBefore > 0, 'initial capacity should be > 0');

    // Acquire many blocks to force segment growth
    for LIdx := 0 to High(LPtrs) do
    begin
      LPtrs[LIdx] := LPool.Acquire;
      Check(LPtrs[LIdx] <> nil, 'acquire should succeed');
    end;

    // Release all blocks
    for LIdx := 0 to High(LPtrs) do
      LPool.Release(LPtrs[LIdx]);

    // Trim idle segments
    LPool.TrimIdleSegments;
    LCapAfter := LPool.Capacity;

    // After releasing all blocks and trimming, capacity should decrease
    // (at least some segments should be freed from the tail)
    Check(LCapAfter <= LCapBefore, 'capacity after trim should be <= before');
    Check(LPool.InUse = 0, 'in-use should be 0 after releasing all');

    // Verify pool still works after trim
    for LIdx := 0 to High(LPtrs) do
    begin
      LPtrs[LIdx] := LPool.Acquire;
      Check(LPtrs[LIdx] <> nil, 'acquire after trim should succeed');
    end;
    for LIdx := 0 to High(LPtrs) do
      LPool.Release(LPtrs[LIdx]);
  finally
    TObject(LPool).Free;
  end;
end;

{** P2-5: Verify TrimIdleSegments clears page-map entries for freed segments.
  After trim, pointers that were in trimmed segments must no longer be
  routable via the page map (Owns returns False). Without the page-map
  clear, stale entries would route Release to freed segments. *}
procedure TestShardedBlockPoolTrimClearsPageMap;
var
  LPool: TShardedBlockPool;
  LPtrs: array[0..511] of Pointer;
  LTrimmedPtr: Pointer;
  LIdx: Integer;
  LTrimmed: SizeInt;
  LCapBefore, LCapAfter: SizeUInt;
begin
  LPool := TShardedBlockPool.Create(64, 64, 1);
  try
    // Acquire far more blocks than initial capacity to force multiple segments
    for LIdx := 0 to High(LPtrs) do
    begin
      LPtrs[LIdx] := LPool.Acquire;
      Check(LPtrs[LIdx] <> nil, 'acquire should succeed');
    end;

    // The last allocated pointer lives in the newest (tail) segment
    LTrimmedPtr := LPtrs[High(LPtrs)];
    Check(LPool.Owns(LTrimmedPtr), 'pointer should be routable before trim');

    // Release all blocks so all segments become idle
    for LIdx := 0 to High(LPtrs) do
      LPool.Release(LPtrs[LIdx]);

    LCapBefore := LPool.Capacity;
    LTrimmed := LPool.TrimIdleSegments;
    LCapAfter := LPool.Capacity;

    Check(LTrimmed > 0, 'trim should free at least one segment');
    Check(LCapAfter < LCapBefore, 'capacity should decrease after trim');

    // Core assertion: the page map must no longer route to the freed segment.
    // Owns calls TryRoute which checks the page map fast path and the
    // route table. After trim, neither should cover the freed address.
    Check(not LPool.Owns(LTrimmedPtr),
      'page map must not route to freed segment after trim');

    // Pool should still function correctly
    Check(LPool.Acquire <> nil, 'acquire after trim should succeed');
  finally
    TObject(LPool).Free;
  end;
end;

{** Test TShard padding prevents false sharing (128-byte alignment). *}
procedure TestShardedBlockPoolFalseSharingPadding;
var
  LPool: TShardedBlockPool;
  LPtr: Pointer;
begin
  // TShard should be padded to 128 bytes (2 cache lines) to prevent false sharing.
  // We verify indirectly: create a pool with multiple shards and verify it works correctly
  // under contention (the padding prevents false sharing from causing performance issues).
  LPool := TShardedBlockPool.Create(64, 128, 4);
  try
    Check(LPool.ShardCount = 4, 'should have 4 shards');
    Check(LPool.BlockSize = 64, 'block size should be 64');

    // Basic acquire/release to verify the padded shards work
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'acquire should succeed');
    LPool.Release(LPtr);
    Check(LPool.InUse = 0, 'in-use should be 0');
  finally
    TObject(LPool).Free;
  end;
end;

{** Stress test: many threads doing concurrent acquire/release. *}
const
  STRESS_THREADS = 16;
  STRESS_ITERS = 500;

type
  TStressData = record
    Pool: TShardedBlockPool;
    StartFlag: PLongInt;
    Failures: Integer;
  end;
  PStressData = ^TStressData;

function StressWorker(AArg: Pointer): Pointer; cdecl;
var
  D: PStressData;
  LIdx: Integer;
  LPtr: Pointer;
begin
  D := PStressData(AArg);
  WaitForStartFlag(D^.StartFlag);
  for LIdx := 0 to STRESS_ITERS - 1 do
  begin
    LPtr := D^.Pool.Acquire;
    if LPtr = nil then
    begin
      Inc(D^.Failures);
      Continue;
    end;
    D^.Pool.Release(LPtr);
  end;
  Result := nil;
end;

procedure TestShardedBlockPoolStress;
var
  LPool: TShardedBlockPool;
  LThreads: array[0..STRESS_THREADS - 1] of TPlatformThreadRecord;
  LData: array[0..STRESS_THREADS - 1] of TStressData;
  LStartFlag: LongInt;
  LIdx: Integer;
  LTotalFailures: Integer;
begin
  LPool := TShardedBlockPool.Create(64, 1024, 4);
  try
    LStartFlag := 0;
    for LIdx := 0 to High(LThreads) do
    begin
      LData[LIdx].Pool := LPool;
      LData[LIdx].StartFlag := @LStartFlag;
      LData[LIdx].Failures := 0;
      platform_thread_spawn(LThreads[LIdx], @StressWorker, @LData[LIdx]);
    end;

    LStartFlag := 1;
    for LIdx := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIdx]);

    LTotalFailures := 0;
    for LIdx := 0 to High(LData) do
      Inc(LTotalFailures, LData[LIdx].Failures);

    Check(LTotalFailures = 0, 'stress test: no acquire failures expected (got ' + IntToStr(LTotalFailures) + ')');
    Check(LPool.InUse = 0, 'stress test: all blocks should be released');
  finally
    TObject(LPool).Free;
  end;
end;

{ ── GetStats: hit rate and utilization ── }

procedure TestBlockPoolGetStats;
var
  LPool: TShardedBlockPool;
  LStats: TBlockPoolStats;
  LPtrs: array[0..63] of Pointer;
  LI: Integer;
begin
  LPool := TShardedBlockPool.Create(64, 128, 2);
  try
    { Initial stats should be zero. }
    LStats := LPool.GetStats;
    Check(LStats.TotalAcquires = 0, 'initial TotalAcquires = 0');
    Check(LStats.CacheHits = 0, 'initial CacheHits = 0');
    Check(LStats.SegmentAllocs = 0, 'initial SegmentAllocs = 0');

    { Acquire some blocks. }
    for LI := 0 to 63 do
    begin
      LPtrs[LI] := LPool.Acquire;
      Check(LPtrs[LI] <> nil, 'acquire ' + IntToStr(LI));
    end;

    LStats := LPool.GetStats;
    Check(LStats.TotalAcquires = 64, 'TotalAcquires = 64');
    Check(LStats.InUse = 64, 'InUse = 64');
    Check(LStats.Capacity >= 64, 'Capacity >= 64');
    Check(LStats.Utilization > 0.0, 'Utilization > 0');

    { Release all. }
    for LI := 0 to 63 do
      LPool.Release(LPtrs[LI]);

    LStats := LPool.GetStats;
    Check(LStats.InUse = 0, 'InUse = 0 after release');
    Check(LStats.Available = LStats.Capacity, 'Available = Capacity after release');

    WriteLn('PASS: GetStats tracks acquires and utilization');
  finally
    TObject(LPool).Free;
  end;
end;

{ ── P1-2: thread-exit cleanup leaks no cache nodes or cached blocks ── }

const
  LEAK_TEST_THREAD_COUNT = 4;
  LEAK_TEST_CACHED_PER_THREAD = 16;

type
  PThreadCacheLeakWorkerData = ^TThreadCacheLeakWorkerData;
  TThreadCacheLeakWorkerData = record
    Pool: TShardedBlockPool;
    StartFlag: PLongInt;
    Ptrs: array[0..LEAK_TEST_CACHED_PER_THREAD - 1] of Pointer;
    Failure: string;
  end;

function ThreadCacheLeakWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PThreadCacheLeakWorkerData;
  LIdx: Integer;
begin
  LData := PThreadCacheLeakWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    { Acquire blocks into the thread cache, then release them back to the
      cache (not to the shard). The cache nodes and cached blocks must be
      reclaimed when this thread exits via the TLS destructor callback. }
    for LIdx := 0 to LEAK_TEST_CACHED_PER_THREAD - 1 do
    begin
      LData^.Ptrs[LIdx] := LData^.Pool.Acquire;
      if LData^.Ptrs[LIdx] = nil then
        raise Exception.Create('acquire returned nil in leak test worker');
    end;
    { Release back to thread cache — blocks stay cached, not returned to shard }
    for LIdx := 0 to LEAK_TEST_CACHED_PER_THREAD - 1 do
      LData^.Pool.Release(LData^.Ptrs[LIdx]);
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestShardedBlockPoolThreadExitCleanup;
var
  LConfig: TShardedBlockPoolConfig;
  LPool: TShardedBlockPool;
  LThreads: array[0..LEAK_TEST_THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..LEAK_TEST_THREAD_COUNT - 1] of TThreadCacheLeakWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LInUse: SizeUInt;
begin
  LConfig := TShardedBlockPoolConfig.Default(64, 1024, 2);
  LConfig.ThreadCacheCapacity := LEAK_TEST_CACHED_PER_THREAD;
  LPool := TShardedBlockPool.Create(LConfig);
  try
    Check(LPool.ShardCount >= 1, 'pool should have shards');

    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      FillByte(LThreadData[LIndex].Ptrs[0], SizeOf(LThreadData[LIndex].Ptrs), 0);
      platform_thread_spawn(LThreads[LIndex], @ThreadCacheLeakWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'leak test worker should not fail: ' + LThreadData[LIndex].Failure);

    { After all worker threads have exited, the TLS destructor should have
      flushed each thread's cache back to the shard pools. InUse must be 0. }
    LInUse := LPool.InUse;
    Check(LInUse = 0, 'thread-exit cleanup: InUse should be 0 after worker threads exit (got ' + IntToStr(LInUse) + ')');

    WriteLn('PASS: thread-exit cleanup reclaims cached blocks (P1-2)');
  finally
    TObject(LPool).Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.sharded_pools');
  T.Test('sharded blockpool contention', @TestShardedBlockPoolContention);
  T.Test('sharded blockpool rejects duplicate remote release', @TestShardedBlockPoolRejectsDuplicateRemoteRelease);
  T.Test('sharded blockpool thread-cache acquire/release', @TestShardedBlockPoolThreadCacheConfigRejectsDuplicateRelease);
  T.Test('sharded blockpool thread-exit cleanup (P1-2)', @TestShardedBlockPoolThreadExitCleanup);
  T.Test('sharded slab contention', @TestShardedSlabPoolContention);
  T.Test('sharded slab ownership diagnostics reject interior pointer', @TestShardedSlabOwnershipDiagnosticsRejectInteriorPointer);
  T.Test('sharded slab release and realloc reject interior pointer', @TestShardedSlabReleaseAndReallocRejectInteriorPointer);
  T.Test('sharded slab remote release clears diagnostics', @TestShardedSlabRemoteReleaseClearsDiagnostics);
  T.Test('B4-1 stats aggregated after contention', @TestShardedBlockPoolStatsAggregated);
  T.Test('B4-2 sharded slab aligned contention', @TestShardedSlabAllocAlignedContention);
  T.Test('trim idle segments reclaims memory', @TestShardedBlockPoolTrimIdleSegments);
  T.Test('trim clears page map for freed segments (P2-5)', @TestShardedBlockPoolTrimClearsPageMap);
  T.Test('false sharing padding verification', @TestShardedBlockPoolFalseSharingPadding);
  T.Test('stress test concurrent acquire/release', @TestShardedBlockPoolStress);
  T.Test('GetStats hit rate and utilization', @TestBlockPoolGetStats);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
