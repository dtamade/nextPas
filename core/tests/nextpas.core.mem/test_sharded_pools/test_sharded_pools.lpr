program test_sharded_pools;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.pool.slab.sharded,
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

var
  T: TTestRunner;
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
      CheckEqual(Int64(Ord(AExpected)), Int64(Ord(E.Error)), AName + ': error code');
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
    CheckEqual(Int64(THREAD_COUNT - 1), Int64(GBlockPool.InUse),
      'duplicate release should not decrement in-use count');
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
  LHit: Boolean;
begin
  LConfig := TShardedBlockPoolConfig.Default(64, 4, 1);
  LConfig.ThreadCacheCapacity := 8;
  LHit := False;
  try
    TShardedBlockPool.Create(LConfig);
  except
    on E: EAllocError do
      LHit := True;
  end;
  Check(LHit, 'ThreadCacheCapacity > 0 should be rejected');
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
      CheckEqual(Int64(64), Int64(LPool.MemSizeOf(LPtr)), 'exact pointer should report slab chunk size');
      Check(not LPool.Owns(LPtr + 1), 'sharded pool should not own interior pointer diagnostically');
      CheckEqual(Int64(0), Int64(LPool.MemSizeOf(LPtr + 1)), 'interior pointer should not report chunk size');
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
    CheckEqual(Int64(64), Int64(GSlabPool.MemSizeOf(GSlabPtr)), 'invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorShardedSlabPointer, aeInvalidPointer, 'interior ReallocMem');
    Check(GSlabPool.Owns(GSlabPtr), 'invalid ReallocMem should not release exact pointer');
    CheckEqual(Int64(64), Int64(GSlabPool.MemSizeOf(GSlabPtr)), 'invalid ReallocMem should preserve exact pointer size');

    GSlabPool.FreeMem(GSlabPtr);
  finally
    GSlabPtr := nil;
    TObject(GSlabPool).Free;
    GSlabPool := nil;
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
    CheckEqual(Int64(0), Int64(LPool.MemSizeOf(LPtr)),
      'remote slab FreeMem should clear size diagnostics immediately');
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

begin
  T := TTestRunner.Create('nextpas.core.mem.sharded_pools');
  T.Run('sharded blockpool contention', @TestShardedBlockPoolContention);
  T.Run('sharded blockpool rejects duplicate remote release', @TestShardedBlockPoolRejectsDuplicateRemoteRelease);
  T.Run('sharded blockpool thread-cache config rejects duplicate release', @TestShardedBlockPoolThreadCacheConfigRejectsDuplicateRelease);
  T.Run('sharded slab contention', @TestShardedSlabPoolContention);
  T.Run('sharded slab ownership diagnostics reject interior pointer', @TestShardedSlabOwnershipDiagnosticsRejectInteriorPointer);
  T.Run('sharded slab release and realloc reject interior pointer', @TestShardedSlabReleaseAndReallocRejectInteriorPointer);
  T.Run('sharded slab remote release clears diagnostics', @TestShardedSlabRemoteReleaseClearsDiagnostics);
  T.Summary;
end.
