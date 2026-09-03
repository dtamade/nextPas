program test_concurrent_wrappers;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.blockpool.concurrent,
  nextpas.core.mem.arena.concurrent,
  nextpas.core.mem.mutex,
  nextpas.core.mem.rwlock,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.slab.concurrent,
  nextpas.core.platform.thread;

const
  THREAD_COUNT = 8;
  ITERATION_COUNT = 32;
  NEGATIVE_ITERATION_COUNT = 256;
  STRESS_ITERATION_COUNT = 128;

type
  PPoolWorkerData = ^TPoolWorkerData;
  TPoolWorkerData = record
    Pool: TFixedPoolConcurrent;
    StartFlag: PLongInt;
    Failure: string;
  end;

  PSlabWorkerData = ^TSlabWorkerData;
  TSlabWorkerData = record
    Pool: TSlabPoolConcurrent;
    StartFlag: PLongInt;
    Failure: string;
  end;

  PFixedPoolNegativeWorkerData = ^TFixedPoolNegativeWorkerData;
  TFixedPoolNegativeWorkerData = record
    Pool: TFixedPoolConcurrent;
    StartFlag: PLongInt;
    Failure: string;
  end;

  { Stress test: Reset vs Alloc contention }
  PArenaAllocStressWorkerData = ^TArenaAllocStressWorkerData;
  TArenaAllocStressWorkerData = record
    Arena: TArenaConcurrent;
    StartFlag: PLongInt;
    AllocCount: Integer;
    Failure: string;
  end;

  PArenaResetStressWorkerData = ^TArenaResetStressWorkerData;
  TArenaResetStressWorkerData = record
    Arena: TArenaConcurrent;
    StartFlag: PLongInt;
    ResetCount: Integer;
    Failure: string;
  end;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure WaitForStartFlag(AStartFlag: PLongInt); inline;
begin
  while AStartFlag^ = 0 do
    platform_thread_yield;
end;

function PoolWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PPoolWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PPoolWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      if not LData^.Pool.Acquire(LPtr) then
        raise Exception.Create('TFixedPoolConcurrent.Acquire returned false');
      if LPtr = nil then
        raise Exception.Create('TFixedPoolConcurrent.Acquire returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LData^.Pool.Release(LPtr);
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function SlabWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PSlabWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PSlabWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 1 to ITERATION_COUNT do
    begin
      LPtr := LData^.Pool.GetMem(16 + (LIndex mod 32));
      if LPtr = nil then
        raise Exception.Create('TSlabPoolConcurrent.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LData^.Pool.FreeMem(LPtr);
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function FixedPoolNegativeWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PFixedPoolNegativeWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
  LLocal: Byte;
begin
  LData := PFixedPoolNegativeWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to NEGATIVE_ITERATION_COUNT - 1 do
    begin
      if not LData^.Pool.Acquire(LPtr) then
        raise Exception.Create('negative worker Acquire returned false');
      if LPtr = nil then
        raise Exception.Create('negative worker Acquire returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      LData^.Pool.Release(LPtr);

      try
        LData^.Pool.Release(@LLocal);
        raise Exception.Create('external pointer Release should fail');
      except
        on E: EAllocError do
        begin
          if E.Error <> aeInvalidPointer then
            raise Exception.Create('external pointer Release returned wrong error');
        end;
      end;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

{ TArenaAllocStressWorker }
function ArenaAllocStressWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PArenaAllocStressWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PArenaAllocStressWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to STRESS_ITERATION_COUNT - 1 do
    begin
      LPtr := LData^.Arena.Alloc(32);
      if LPtr <> nil then
      begin
        PByte(LPtr)^ := Byte(LIndex);
        Inc(LData^.AllocCount);
      end;
      { Reset may have happened — either Alloc succeeds or returns nil, both are valid }
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

{ TArenaResetStressWorker }
function ArenaResetStressWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PArenaResetStressWorkerData;
  LIndex: Integer;
begin
  LData := PArenaResetStressWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to STRESS_ITERATION_COUNT div 4 - 1 do
    begin
      LData^.Arena.Reset;
      Inc(LData^.ResetCount);
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestBlockPoolConcurrentWrapper;
var
  LPool: TBlockPoolConcurrent;
  LPtr: Pointer;
begin
  LPool := TBlockPoolConcurrent.Create(32, 4);
  try
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'Acquire should return a block');
    Check(LPool.BlockSize = 32, 'block size stays visible');
    Check(LPool.InUse = 1, 'in-use count increments');
    LPool.Release(LPtr);
    Check(LPool.InUse = 0, 'release decrements in-use count');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestArenaConcurrentWrapper;
var
  LArena: TArenaConcurrent;
  LPtr: Pointer;
begin
  LArena := TArenaConcurrent.Create(256);
  try
    LPtr := LArena.AllocAligned(32, 8);
    Check(LPtr <> nil, 'AllocAligned should succeed');
    Check(Int64(0) = Int64(PtrUInt(LPtr) mod 8), 'AllocAligned should honor alignment');
    Check(LArena.UsedSize >= 32, 'arena usage should grow');
    LArena.Reset;
    Check(LArena.UsedSize = 0, 'reset should rewind usage');
  finally
    LArena.Free;
  end;
end;

procedure TestFixedPoolConcurrentContention;
var
  LPool: TFixedPoolConcurrent;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TPoolWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TFixedPoolConcurrent.Create(64, THREAD_COUNT);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @PoolWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'fixed-pool worker should not fail');
    Check(LPool.AllocatedCount = 0, 'all blocks should be released');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestFixedPoolConcurrentRejectsInvalidReleaseAfterContention;
var
  LPool: TFixedPoolConcurrent;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TFixedPoolNegativeWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LPtr: Pointer;
  LFailure: string;
begin
  LPool := TFixedPoolConcurrent.Create(64, THREAD_COUNT);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @FixedPoolNegativeWorkerProc,
        @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    LFailure := '';
    for LIndex := 0 to High(LThreads) do
    begin
      if (LFailure = '') and (LThreadData[LIndex].Failure <> '') then
        LFailure := LThreadData[LIndex].Failure;
    end;

    Check(LFailure = '', 'fixed-pool negative worker should not fail: ' + LFailure);
    Check(LPool.AllocatedCount = 0, 'negative stress should release all blocks');
    Check(LPool.Acquire(LPtr), 'pool should remain usable after invalid release exceptions');
    LPool.Release(LPtr);
    try
      LPool.Release(LPtr);
      Fail('fixed-pool double Release should fail after contention');
    except
      on E: EAllocError do
        Check(Int64(Ord(aeDoubleFree)) = Int64(Ord(E.Error)), 'fixed-pool double Release error code after contention');
    end;
    Check(LPool.AllocatedCount = 0, 'post-exception release should leave pool empty');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestSlabPoolConcurrentContention;
var
  LPool: TSlabPoolConcurrent;
  LThreads: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LThreadData: array[0..THREAD_COUNT - 1] of TSlabWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TSlabPoolConcurrent.Create(4096);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreadData[LIndex].Pool := LPool;
      LThreadData[LIndex].StartFlag := @LStartFlag;
      LThreadData[LIndex].Failure := '';
      platform_thread_spawn(LThreads[LIndex], @SlabWorkerProc, @LThreadData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      platform_thread_wait(LThreads[LIndex]);

    for LIndex := 0 to High(LThreads) do
      Check(LThreadData[LIndex].Failure = '', 'slab worker should not fail');
    Check(LPool.Stats.FallbackAllocCount = 0, 'small contention path should stay in slab fast path');
  finally
    TObject(LPool).Free;
  end;
end;

{**
 * R-03: Reset vs Alloc contention stress test.
 *
 * Exercises the lock ordering correctness: Alloc threads and a Reset thread
 * race against each other. No double-lock, no ABA, no crash.
 *
 * R-03: Reset vs Alloc 并发竞争压力测试。
 * 验证锁顺序正确性：Alloc 线程与 Reset 线程竞争，不发生死锁/ABA/崩溃。
 *}
procedure TestArenaResetVsAllocContention;
const
  ALLOC_THREADS = 4;
  RESET_THREADS = 1;
  STRESS_ALLOC_SIZE = 32;
  STRESS_ARENA_SIZE = 128 * 1024; { 128KB — enough for all allocs between resets }
var
  LArena: TArenaConcurrent;
  LAllocWorkers: array[0..ALLOC_THREADS - 1] of TPlatformThreadRecord;
  LAllocWorkerData: array[0..ALLOC_THREADS - 1] of TArenaAllocStressWorkerData;
  LResetWorkers: array[0..RESET_THREADS - 1] of TPlatformThreadRecord;
  LResetWorkerData: array[0..RESET_THREADS - 1] of TArenaResetStressWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LTotalAllocs: Integer;
  LTotalResets: Integer;
  LFailure: string;
begin
  LArena := TArenaConcurrent.Create(STRESS_ARENA_SIZE);
  try
    LStartFlag := 0;

    for LIndex := 0 to High(LAllocWorkers) do
    begin
      LAllocWorkerData[LIndex].Arena := LArena;
      LAllocWorkerData[LIndex].StartFlag := @LStartFlag;
      LAllocWorkerData[LIndex].AllocCount := 0;
      LAllocWorkerData[LIndex].Failure := '';
      platform_thread_spawn(LAllocWorkers[LIndex], @ArenaAllocStressWorkerProc,
        @LAllocWorkerData[LIndex]);
    end;

    for LIndex := 0 to High(LResetWorkers) do
    begin
      LResetWorkerData[LIndex].Arena := LArena;
      LResetWorkerData[LIndex].StartFlag := @LStartFlag;
      LResetWorkerData[LIndex].ResetCount := 0;
      LResetWorkerData[LIndex].Failure := '';
      platform_thread_spawn(LResetWorkers[LIndex], @ArenaResetStressWorkerProc,
        @LResetWorkerData[LIndex]);
    end;

    LStartFlag := 1;

    for LIndex := 0 to High(LAllocWorkers) do
      platform_thread_wait(LAllocWorkers[LIndex]);
    for LIndex := 0 to High(LResetWorkers) do
      platform_thread_wait(LResetWorkers[LIndex]);

    LTotalAllocs := 0;
    LFailure := '';
    for LIndex := 0 to High(LAllocWorkers) do
    begin
      if (LFailure = '') and (LAllocWorkerData[LIndex].Failure <> '') then
        LFailure := 'alloc worker ' + IntToStr(LIndex) + ': ' + LAllocWorkerData[LIndex].Failure;
      LTotalAllocs := LTotalAllocs + LAllocWorkerData[LIndex].AllocCount;
    end;

    LTotalResets := 0;
    for LIndex := 0 to High(LResetWorkers) do
    begin
      if (LFailure = '') and (LResetWorkerData[LIndex].Failure <> '') then
        LFailure := 'reset worker ' + IntToStr(LIndex) + ': ' + LResetWorkerData[LIndex].Failure;
      LTotalResets := LTotalResets + LResetWorkerData[LIndex].ResetCount;
    end;

    Check(LFailure = '', 'Reset vs Alloc contention should not crash: ' + LFailure);
    Check(LTotalAllocs > 0, 'alloc workers should have completed some allocations: ' + IntToStr(LTotalAllocs));
    Check(LTotalResets > 0, 'reset worker should have completed some resets: ' + IntToStr(LTotalResets));

    { Arena should still be usable after contention — reset to get clean state }
    LArena.Reset;
    Check(LArena.Alloc(64) <> nil, 'arena should remain usable after Reset vs Alloc contention');
    Check(LArena.UsedSize > 0, 'arena should track usage after contention');
  finally
    LArena.Free;
  end;
end;

{**
 * Arena mark/save stress test: SaveMark/RestoreToMark under concurrent Alloc.
 *
 * 验证 SaveMark/RestoreToMark 在并发 Alloc 下的正确性。
 *}
procedure TestArenaMarkVsAllocContention;
const
  ALLOC_THREADS = 4;
  STRESS_ARENA_SIZE = 128 * 1024;
var
  LArena: TArenaConcurrent;
  LAllocWorkers: array[0..ALLOC_THREADS - 1] of TPlatformThreadRecord;
  LAllocWorkerData: array[0..ALLOC_THREADS - 1] of TArenaAllocStressWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LMark: TArenaMark;
  LFailure: string;
begin
  LArena := TArenaConcurrent.Create(STRESS_ARENA_SIZE);
  try
    LStartFlag := 0;

    for LIndex := 0 to High(LAllocWorkers) do
    begin
      LAllocWorkerData[LIndex].Arena := LArena;
      LAllocWorkerData[LIndex].StartFlag := @LStartFlag;
      LAllocWorkerData[LIndex].AllocCount := 0;
      LAllocWorkerData[LIndex].Failure := '';
      platform_thread_spawn(LAllocWorkers[LIndex], @ArenaAllocStressWorkerProc,
        @LAllocWorkerData[LIndex]);
    end;

    LStartFlag := 1;

    { Let alloc workers run a bit, then save mark and restore }
    platform_thread_sleep_ns(1000000);
    LMark := LArena.SaveMark;
    LArena.RestoreToMark(LMark);

    for LIndex := 0 to High(LAllocWorkers) do
      platform_thread_wait(LAllocWorkers[LIndex]);

    LFailure := '';
    for LIndex := 0 to High(LAllocWorkers) do
    begin
      if (LFailure = '') and (LAllocWorkerData[LIndex].Failure <> '') then
        LFailure := 'alloc worker ' + IntToStr(LIndex) + ': ' + LAllocWorkerData[LIndex].Failure;
    end;

    Check(LFailure = '', 'mark vs alloc contention should not crash: ' + LFailure);
    LArena.Reset;
    Check(LArena.Alloc(64) <> nil, 'arena should remain usable after mark contention');
  finally
    LArena.Free;
  end;
end;

{**
 * T-01: Direct TMemMutex unit test.
 * T-01: TMemMutex 直接单元测试。
 *}
procedure TestMemMutexDirect;
var
  LMutex: TMemMutex;
  LHitError: Boolean;
begin
  { TMemMutex 是 record，栈上变量不会自动初始化 — 必须先清零 }
  FillChar(LMutex, SizeOf(LMutex), 0);

  { Basic init/acquire/release/done cycle }
  LMutex.Init;
  LMutex.Acquire;
  LMutex.Release;
  LMutex.Done;

  { Double init is a no-op }
  LMutex.Init;
  LMutex.Init;
  LMutex.Acquire;
  LMutex.Release;
  LMutex.Done;
  LMutex.Done;

  { Re-init after Done should still work }
  LMutex.Init;
  LMutex.Acquire;
  LMutex.Release;
  LMutex.Done;

  { Acquire on uninitialized (zeroed) mutex should raise }
  FillChar(LMutex, SizeOf(LMutex), 0);
  LHitError := False;
  try
    LMutex.Acquire;
  except
    on E: Exception do
      LHitError := True;
  end;
  Check(LHitError, 'Acquire on uninitialized mutex should raise');

  { Release on uninitialized (zeroed) mutex should raise }
  LHitError := False;
  try
    LMutex.Release;
  except
    on E: Exception do
      LHitError := True;
  end;
  Check(LHitError, 'Release on uninitialized mutex should raise');

  { Done on uninitialized (zeroed) mutex is a no-op }
  LMutex.Done;
end;

procedure TestMemRwLockDirect;
var
  LRwLock: TMemRwLock;
  LHitError: Boolean;
begin
  { TMemRwLock 是 record，栈上变量不会自动初始化 — 必须先清零 }
  FillChar(LRwLock, SizeOf(LRwLock), 0);

  { Basic init/read/write/release/done cycle }
  LRwLock.Init;
  LRwLock.AcquireRead;
  LRwLock.ReleaseRead;
  LRwLock.AcquireWrite;
  LRwLock.ReleaseWrite;
  LRwLock.Done;

  { Double init is a no-op and double Done stays safe }
  LRwLock.Init;
  LRwLock.Init;
  LRwLock.AcquireRead;
  LRwLock.ReleaseRead;
  LRwLock.AcquireWrite;
  LRwLock.ReleaseWrite;
  LRwLock.Done;
  LRwLock.Done;

  { Re-init after Done should still work }
  LRwLock.Init;
  LRwLock.AcquireWrite;
  LRwLock.ReleaseWrite;
  LRwLock.Done;

  { AcquireRead on uninitialized rwlock should raise }
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LHitError := False;
  try
    LRwLock.AcquireRead;
  except
    on E: Exception do
      LHitError := True;
  end;
  Check(LHitError, 'AcquireRead on uninitialized rwlock should raise');

  { ReleaseRead on uninitialized rwlock should raise }
  LHitError := False;
  try
    LRwLock.ReleaseRead;
  except
    on E: Exception do
      LHitError := True;
  end;
  Check(LHitError, 'ReleaseRead on uninitialized rwlock should raise');

  { AcquireWrite on uninitialized rwlock should raise }
  LHitError := False;
  try
    LRwLock.AcquireWrite;
  except
    on E: Exception do
      LHitError := True;
  end;
  Check(LHitError, 'AcquireWrite on uninitialized rwlock should raise');

  { ReleaseWrite on uninitialized rwlock should raise }
  LHitError := False;
  try
    LRwLock.ReleaseWrite;
  except
    on E: Exception do
      LHitError := True;
  end;
  Check(LHitError, 'ReleaseWrite on uninitialized rwlock should raise');

  { Done on uninitialized rwlock is a no-op }
  LRwLock.Done;
end;

{**
 * T-03: High-contention mutex stress test.
 * Multiple threads hammer a shared counter protected by TMemMutex.
 * T-03: 高竞争 mutex 压力测试。多线程竞争共享计数器。
 *}
type
  PMemMutex = ^TMemMutex;

  PMutexCounterWorkerData = ^TMutexCounterWorkerData;
  TMutexCounterWorkerData = record
    Mutex: PMemMutex;
    Counter: PInt64;
    StartFlag: PLongInt;
    Failure: string;
  end;

function MutexCounterWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PMutexCounterWorkerData;
  LIndex: Integer;
begin
  LData := PMutexCounterWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to STRESS_ITERATION_COUNT - 1 do
    begin
      LData^.Mutex^.Acquire;
      Inc(LData^.Counter^);
      LData^.Mutex^.Release;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestMemMutexHighContention;
const
  MUTEX_THREADS = 8;
var
  LMutex: TMemMutex;
  LCounter: Int64;
  LWorkers: array[0..MUTEX_THREADS - 1] of TPlatformThreadRecord;
  LWorkerData: array[0..MUTEX_THREADS - 1] of TMutexCounterWorkerData;
  LStartFlag: LongInt;
  LIndex: Integer;
  LFailure: string;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  LCounter := 0;
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LWorkers) do
    begin
      LWorkerData[LIndex].Mutex := @LMutex;
      LWorkerData[LIndex].Counter := @LCounter;
      LWorkerData[LIndex].StartFlag := @LStartFlag;
      LWorkerData[LIndex].Failure := '';
      platform_thread_spawn(LWorkers[LIndex], @MutexCounterWorkerProc,
        @LWorkerData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LWorkers) do
      platform_thread_wait(LWorkers[LIndex]);

    LFailure := '';
    for LIndex := 0 to High(LWorkers) do
    begin
      if (LFailure = '') and (LWorkerData[LIndex].Failure <> '') then
        LFailure := 'worker ' + IntToStr(LIndex) + ': ' + LWorkerData[LIndex].Failure;
    end;

    Check(LFailure = '', 'mutex contention should not fail: ' + LFailure);
    Check(Int64(MUTEX_THREADS * STRESS_ITERATION_COUNT) = LCounter, 'mutex-protected counter should be exact');
  finally
    LMutex.Done;
  end;
end;

{**
 * B4-3: Multiple mark/restore cycles under concurrent Alloc.
 *
 * 多次 SaveMark/RestoreToMark 循环 + 并发 Alloc，验证正确性。
 *}
function B4ArenaAllocWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PArenaAllocStressWorkerData;
  LIndex: Integer;
  LPtr: Pointer;
begin
  LData := PArenaAllocStressWorkerData(AArg);
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to 63 do
    begin
      LPtr := LData^.Arena.Alloc(32);
      if LPtr <> nil then
      begin
        PByte(LPtr)^ := Byte(LIndex);
        Inc(LData^.AllocCount);
      end;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestArenaConcurrentMultipleMarkRestore;
const
  ALLOC_THREADS = 4;
  MARK_CYCLES = 4;
  STRESS_ARENA_SIZE = 64 * 1024;
var
  LArena: TArenaConcurrent;
  LAllocWorkers: array[0..ALLOC_THREADS - 1] of TPlatformThreadRecord;
  LAllocWorkerData: array[0..ALLOC_THREADS - 1] of TArenaAllocStressWorkerData;
  LStartFlag: LongInt;
  LIndex, LCycle: Integer;
  LMark: TArenaMark;
  LFailure: string;
begin
  LArena := TArenaConcurrent.Create(STRESS_ARENA_SIZE);
  try
    for LCycle := 0 to MARK_CYCLES - 1 do
    begin
      LStartFlag := 0;

      for LIndex := 0 to High(LAllocWorkers) do
      begin
        LAllocWorkerData[LIndex].Arena := LArena;
        LAllocWorkerData[LIndex].StartFlag := @LStartFlag;
        LAllocWorkerData[LIndex].AllocCount := 0;
        LAllocWorkerData[LIndex].Failure := '';
        platform_thread_spawn(LAllocWorkers[LIndex], @B4ArenaAllocWorkerProc,
          @LAllocWorkerData[LIndex]);
      end;

      LStartFlag := 1;

      { Let alloc workers run briefly, then mark and restore }
      platform_thread_sleep_ns(100000);
      LMark := LArena.SaveMark;
      LArena.RestoreToMark(LMark);

      for LIndex := 0 to High(LAllocWorkers) do
        platform_thread_wait(LAllocWorkers[LIndex]);

      LFailure := '';
      for LIndex := 0 to High(LAllocWorkers) do
      begin
        if (LFailure = '') and (LAllocWorkerData[LIndex].Failure <> '') then
          LFailure := 'cycle ' + IntToStr(LCycle) + ' worker ' + IntToStr(LIndex) + ': ' + LAllocWorkerData[LIndex].Failure;
      end;

      Check(LFailure = '', 'mark/restore cycle should not crash: ' + LFailure);

      { Arena should be usable after each cycle }
      LArena.Reset;
    end;

    { Final usability check }
    Check(LArena.Alloc(64) <> nil, 'arena should remain usable after all mark/restore cycles');
  finally
    LArena.Free;
  end;
end;

{ T-04: Recursive acquire on ERRORCHECK mutex should raise }
procedure TestMutexRecursiveAcquire;
var
  LMutex: TMemMutex;
  LCaught: Boolean;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  try
    LMutex.Acquire;
    { Second Acquire on same thread should fail (ERRORCHECK mutex) }
    LCaught := False;
    try
      LMutex.Acquire;
    except
      on E: Exception do
        LCaught := True;
    end;
    Check(LCaught, 'recursive Acquire on ERRORCHECK mutex must raise');
    LMutex.Release;
  finally
    LMutex.Done;
  end;
end;

{ T-04: Release without matching Acquire should raise }
procedure TestMutexReleaseWithoutLock;
var
  LMutex: TMemMutex;
  LCaught: Boolean;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  try
    LCaught := False;
    try
      LMutex.Release;
    except
      on E: Exception do
        LCaught := True;
    end;
    Check(LCaught, 'Release without Acquire must raise');
  finally
    LMutex.Done;
  end;
end;

{ T-04: Multiple concurrent readers can hold read lock simultaneously }
type
  PRwLockReaderData = ^TRwLockReaderData;
  TRwLockReaderData = record
    RwLock: ^TMemRwLock;
    Counter: PInt64;
    StartFlag: PLongInt;
    Failure: string;
  end;

function RwLockReaderProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PRwLockReaderData;
  LRwLock: ^TMemRwLock;
  LIndex: Integer;
begin
  LData := PRwLockReaderData(AArg);
  LRwLock := LData^.RwLock;
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to 63 do
    begin
      LRwLock^.AcquireRead;
      Inc(LData^.Counter^);
      LRwLock^.ReleaseRead;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestRwLockMultipleReaders;
const
  READER_COUNT = 4;
var
  LRwLock: TMemRwLock;
  LReaders: array[0..READER_COUNT - 1] of TPlatformThreadRecord;
  LReaderData: array[0..READER_COUNT - 1] of TRwLockReaderData;
  LStartFlag: LongInt;
  LCounter: Int64;
  LIndex: Integer;
  LFailure: string;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LCounter := 0;
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LReaders) do
    begin
      LReaderData[LIndex].RwLock := @LRwLock;
      LReaderData[LIndex].Counter := @LCounter;
      LReaderData[LIndex].StartFlag := @LStartFlag;
      LReaderData[LIndex].Failure := '';
      platform_thread_spawn(LReaders[LIndex], @RwLockReaderProc,
        @LReaderData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LReaders) do
      platform_thread_wait(LReaders[LIndex]);

    LFailure := '';
    for LIndex := 0 to High(LReaders) do
    begin
      if (LFailure = '') and (LReaderData[LIndex].Failure <> '') then
        LFailure := 'reader ' + IntToStr(LIndex) + ': ' + LReaderData[LIndex].Failure;
    end;
    Check(LFailure = '', 'concurrent readers should not fail: ' + LFailure);
    Check(LCounter > 0, 'readers should have completed iterations');
  finally
    LRwLock.Done;
  end;
end;

{ D-2d: RwLock write contention — multiple writers on shared counter }
type
  PRwLockWriterData = ^TRwLockWriterData;
  TRwLockWriterData = record
    RwLock: ^TMemRwLock;
    Counter: PInt64;
    StartFlag: PLongInt;
    Failure: string;
  end;

function RwLockWriterProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PRwLockWriterData;
  LRwLock: ^TMemRwLock;
  LIndex: Integer;
begin
  LData := PRwLockWriterData(AArg);
  LRwLock := LData^.RwLock;
  WaitForStartFlag(LData^.StartFlag);

  try
    for LIndex := 0 to STRESS_ITERATION_COUNT - 1 do
    begin
      LRwLock^.AcquireWrite;
      Inc(LData^.Counter^);
      LRwLock^.ReleaseWrite;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestRwLockWriteContention;
const
  WRITER_COUNT = 8;
var
  LRwLock: TMemRwLock;
  LWriters: array[0..WRITER_COUNT - 1] of TPlatformThreadRecord;
  LWriterData: array[0..WRITER_COUNT - 1] of TRwLockWriterData;
  LStartFlag: LongInt;
  LCounter: Int64;
  LIndex: Integer;
  LFailure: string;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LCounter := 0;
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LWriters) do
    begin
      LWriterData[LIndex].RwLock := @LRwLock;
      LWriterData[LIndex].Counter := @LCounter;
      LWriterData[LIndex].StartFlag := @LStartFlag;
      LWriterData[LIndex].Failure := '';
      platform_thread_spawn(LWriters[LIndex], @RwLockWriterProc,
        @LWriterData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LWriters) do
      platform_thread_wait(LWriters[LIndex]);

    LFailure := '';
    for LIndex := 0 to High(LWriters) do
    begin
      if (LFailure = '') and (LWriterData[LIndex].Failure <> '') then
        LFailure := 'writer ' + IntToStr(LIndex) + ': ' + LWriterData[LIndex].Failure;
    end;
    Check(LFailure = '', 'rwlock write contention should not fail: ' + LFailure);
    Check(Int64(WRITER_COUNT * STRESS_ITERATION_COUNT) = LCounter, 'rwlock-protected counter should be exact');
  finally
    LRwLock.Done;
  end;
end;

{ Mixed reader+writer contention: readers verify monotonic counter }
type
  PRwLockMixedReaderData = ^TRwLockMixedReaderData;
  TRwLockMixedReaderData = record
    RwLock: ^TMemRwLock;
    Counter: PInt64;
    StartFlag: PLongInt;
    MaxSeen: Int64;
    Failure: string;
  end;

  PRwLockMixedWriterData = ^TRwLockMixedWriterData;
  TRwLockMixedWriterData = record
    RwLock: ^TMemRwLock;
    Counter: PInt64;
    StartFlag: PLongInt;
    Failure: string;
  end;

function MixedReaderProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PRwLockMixedReaderData;
  LRwLock: ^TMemRwLock;
  LI: Integer;
  LVal: Int64;
begin
  LData := PRwLockMixedReaderData(AArg);
  LRwLock := LData^.RwLock;
  LData^.MaxSeen := 0;
  WaitForStartFlag(LData^.StartFlag);
  try
    for LI := 0 to STRESS_ITERATION_COUNT - 1 do
    begin
      LRwLock^.AcquireRead;
      LVal := LData^.Counter^;
      LRwLock^.ReleaseRead;
      if LVal < 0 then
      begin
        LData^.Failure := 'negative counter read: ' + IntToStr(LVal);
        Break;
      end;
      if LVal > LData^.MaxSeen then
        LData^.MaxSeen := LVal;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

function MixedWriterProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PRwLockMixedWriterData;
  LRwLock: ^TMemRwLock;
  LI: Integer;
begin
  LData := PRwLockMixedWriterData(AArg);
  LRwLock := LData^.RwLock;
  WaitForStartFlag(LData^.StartFlag);
  try
    for LI := 0 to STRESS_ITERATION_COUNT - 1 do
    begin
      LRwLock^.AcquireWrite;
      Inc(LData^.Counter^);
      LRwLock^.ReleaseWrite;
    end;
  except
    on E: Exception do
      LData^.Failure := E.Message;
  end;
  Result := nil;
end;

procedure TestRwLockMixedReaderWriterContention;
const
  READER_COUNT = 4;
  WRITER_COUNT = 4;
var
  LRwLock: TMemRwLock;
  LReaders: array[0..READER_COUNT - 1] of TPlatformThreadRecord;
  LWriters: array[0..WRITER_COUNT - 1] of TPlatformThreadRecord;
  LReaderData: array[0..READER_COUNT - 1] of TRwLockMixedReaderData;
  LWriterData: array[0..WRITER_COUNT - 1] of TRwLockMixedWriterData;
  LStartFlag: LongInt;
  LCounter: Int64;
  LIndex: Integer;
  LFailure: string;
begin
  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LCounter := 0;
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LReaders) do
    begin
      LReaderData[LIndex].RwLock := @LRwLock;
      LReaderData[LIndex].Counter := @LCounter;
      LReaderData[LIndex].StartFlag := @LStartFlag;
      LReaderData[LIndex].Failure := '';
      platform_thread_spawn(LReaders[LIndex], @MixedReaderProc,
        @LReaderData[LIndex]);
    end;
    for LIndex := 0 to High(LWriters) do
    begin
      LWriterData[LIndex].RwLock := @LRwLock;
      LWriterData[LIndex].Counter := @LCounter;
      LWriterData[LIndex].StartFlag := @LStartFlag;
      LWriterData[LIndex].Failure := '';
      platform_thread_spawn(LWriters[LIndex], @MixedWriterProc,
        @LWriterData[LIndex]);
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LReaders) do
      platform_thread_wait(LReaders[LIndex]);
    for LIndex := 0 to High(LWriters) do
      platform_thread_wait(LWriters[LIndex]);

    LFailure := '';
    for LIndex := 0 to High(LReaders) do
      if (LFailure = '') and (LReaderData[LIndex].Failure <> '') then
        LFailure := 'reader ' + IntToStr(LIndex) + ': ' + LReaderData[LIndex].Failure;
    for LIndex := 0 to High(LWriters) do
      if (LFailure = '') and (LWriterData[LIndex].Failure <> '') then
        LFailure := 'writer ' + IntToStr(LIndex) + ': ' + LWriterData[LIndex].Failure;
    Check(LFailure = '', 'mixed rwlock contention should not fail: ' + LFailure);
    Check(LCounter = Int64(WRITER_COUNT * STRESS_ITERATION_COUNT),
      'writer counter should be exact');
  finally
    LRwLock.Done;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.concurrent_wrappers');
  T.Test('T-01 mutex direct', @TestMemMutexDirect);
  T.Test('T-02 rwlock direct', @TestMemRwLockDirect);
  T.Test('T-03 mutex high contention', @TestMemMutexHighContention);
  T.Test('blockpool wrapper basics', @TestBlockPoolConcurrentWrapper);
  T.Test('arena wrapper basics', @TestArenaConcurrentWrapper);
  T.Test('fixed-pool wrapper contention', @TestFixedPoolConcurrentContention);
  T.Test('fixed-pool wrapper rejects invalid release after contention', @TestFixedPoolConcurrentRejectsInvalidReleaseAfterContention);
  T.Test('slab wrapper contention', @TestSlabPoolConcurrentContention);
  T.Test('R-03 Reset vs Alloc contention', @TestArenaResetVsAllocContention);
  T.Test('R-03 mark vs alloc contention', @TestArenaMarkVsAllocContention);
  T.Test('B4-3 multiple mark/restore cycles', @TestArenaConcurrentMultipleMarkRestore);
  T.Test('T-04 mutex recursive acquire raises', @TestMutexRecursiveAcquire);
  T.Test('T-04 mutex release without lock raises', @TestMutexReleaseWithoutLock);
  T.Test('T-04 rwlock multiple readers', @TestRwLockMultipleReaders);
  T.Test('D-2d rwlock write contention', @TestRwLockWriteContention);
  T.Test('D-2e rwlock mixed reader+writer contention', @TestRwLockMixedReaderWriterContention);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
