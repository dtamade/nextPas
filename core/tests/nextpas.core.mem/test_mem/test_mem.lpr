program test_mem;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.mem;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ E1: 验证 facade re-export 的类型可访问且可实例化 }

procedure TestDefaultAllocatorNotNil;
var
  LAlloc: IAllocator;
begin
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'DefaultAllocator should not be nil');
  Check(DefaultAllocator = LAlloc, 'DefaultAllocator should be singleton');
end;

procedure TestAllocatorBasicOps;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LIntPtr: PInteger;
begin
  LAlloc := DefaultAllocator;

  LPtr := LAlloc.GetMem(1024);
  Check(LPtr <> nil, 'GetMem should return non-nil');

  LIntPtr := PInteger(LPtr);
  LIntPtr^ := 42;
  Check(LIntPtr^ = 42, 'Should read back written value');

  LPtr := LAlloc.ReallocMem(LPtr, 2048);
  Check(LPtr <> nil, 'ReallocMem should return non-nil');
  LIntPtr := PInteger(LPtr);
  Check(LIntPtr^ = 42, 'Value should survive reallocation');

  LAlloc.FreeMem(LPtr);
end;

procedure TestAllocZeroedAndArray;
var
  LPtr: Pointer;
begin
  LPtr := AllocZeroed(DefaultAllocator, 64);
  Check(LPtr <> nil, 'AllocZeroed should return non-nil');
  DefaultAllocator.FreeMem(LPtr);

  LPtr := AllocArray(DefaultAllocator, 10, 8);
  Check(LPtr <> nil, 'AllocArray should return non-nil');
  DefaultAllocator.FreeMem(LPtr);

  Check(AllocArray(DefaultAllocator, 0, 8) = nil, 'AllocArray(count=0) should return nil');
end;

{ 验证 Mutex/RwLock 类型可通过 facade 访问 }
procedure TestMutexRwLockAccessible;
var
  LMutex: TMemMutex;
  LRwLock: TMemRwLock;
begin
  FillChar(LMutex, SizeOf(LMutex), 0);
  LMutex.Init;
  LMutex.Acquire;
  LMutex.Release;
  LMutex.Done;

  FillChar(LRwLock, SizeOf(LRwLock), 0);
  LRwLock.Init;
  LRwLock.AcquireRead;
  LRwLock.ReleaseRead;
  LRwLock.AcquireWrite;
  LRwLock.ReleaseWrite;
  LRwLock.Done;
end;

{ 验证 Arena 类型可通过 facade 访问 }
procedure TestArenaTypesAccessible;
var
  LLocalArena: TLocalArena;
  LPtr: Pointer;
begin
  LLocalArena := TLocalArena.Create(4096);
  try
    LPtr := LLocalArena.Alloc(64);
    Check(LPtr <> nil, 'TLocalArena.Alloc should succeed');
    Check(LLocalArena.UsedSize >= 64, 'UsedSize should track allocation');
    LLocalArena.Reset;
    Check(LLocalArena.UsedSize = 0, 'Reset should clear usage');
  finally
    LLocalArena.Free;
  end;
end;

{ 验证 Pool 类型可通过 facade 访问 }
procedure TestPoolTypesAccessible;
var
  LFixedPool: TFixedPool;
  LPtr: Pointer;
begin
  LFixedPool := TFixedPool.Create(32, 4);
  try
    Check(LFixedPool.Acquire(LPtr), 'TFixedPool.Acquire should succeed');
    Check(LPtr <> nil, 'Acquire should return non-nil');
    LFixedPool.Release(LPtr);
    Check(LFixedPool.AllocatedCount = 0, 'All blocks released');
  finally
    TObject(LFixedPool).Free;
  end;
end;

{ 验证 SlabPool 类型可通过 facade 访问 }
procedure TestSlabPoolAccessible;
var
  LSlab: TSlabPool;
  LPtr: Pointer;
begin
  LSlab := TSlabPool.Create(4096);
  try
    LPtr := LSlab.GetMem(32);
    Check(LPtr <> nil, 'TSlabPool.GetMem should succeed');
    LSlab.FreeMem(LPtr);
  finally
    TObject(LSlab).Free;
  end;
end;

{ 验证 IMemoryPool 接口可通过 facade 访问 }
procedure TestIMemoryPoolAccessible;
var
  LPool: IMemoryPool;
begin
  LPool := TSlabPool.Create(4096) as IMemoryPool;
  Check(LPool <> nil, 'IMemoryPool should be accessible via facade');
  { LPool 引用计数自动释放 }
end;

{ 验证 RingBuffer 类型可通过 facade 访问 }
procedure TestRingBufferAccessible;
var
  LRing: TRingBuffer;
begin
  LRing := TRingBuffer.Create(64, 1);
  try
    Check(LRing.Capacity = 64, 'TRingBuffer.Capacity should match');
  finally
    LRing.Free;
  end;
end;

{ 验证 BlockPoolConcurrent 可通过 facade 访问 }
procedure TestBlockPoolConcurrentAccessible;
var
  LPool: TBlockPoolConcurrent;
  LPtr: Pointer;
begin
  LPool := TBlockPoolConcurrent.Create(32, 4);
  try
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'TBlockPoolConcurrent.Acquire should succeed');
    LPool.Release(LPtr);
  finally
    TObject(LPool).Free;
  end;
end;

{ 验证 SecureZeroMemory 可通过 facade 调用 }
procedure TestSecureZeroAccessible;
var
  LBuf: array[0..15] of Byte;
begin
  FillChar(LBuf, SizeOf(LBuf), $FF);
  SecureZeroMemory(@LBuf, SizeOf(LBuf));
  Check(LBuf[0] = 0, 'SecureZeroMemory should zero buffer');
end;

{ 验证 TrackingAllocator 可通过 facade 访问 }
procedure TestTrackingAllocatorAccessible;
var
  LTracker: IAllocator;
  LPtr: Pointer;
begin
  LTracker := TTrackingAllocator.Create(DefaultAllocator);
  LPtr := LTracker.GetMem(64);
  Check(LPtr <> nil, 'TrackingAllocator.GetMem should succeed');
  LTracker.FreeMem(LPtr);
  { LTracker 引用计数自动释放 }
end;

{ 验证新增 facade 导出的分配器类型可访问 }
procedure TestNewExportsAccessible;
var
  LBump: TBumpAllocator;
  LCascade: TCascadeAllocator;
  LBitmap: TBitmapAllocator;
  LBatch: TBatchAllocator;
  LSentinel: TSentinelAllocator;
  LGuard: TGuardAllocator;
  LLeakReport: TLeakReportAllocator;
  LLogging: TLoggingAllocator;
  LDebug: TDebugAllocator;
  LWatermark: TWatermarkAllocator;
  LSampling: TSamplingAllocator;
  LPrefix: TPrefixAllocator;
  LPrediction: TPredictionAllocator;
  LReplay: TReplayAllocator;
  LNuma: TNumaAllocator;
begin
  { 只验证类型可访问，不测试功能（各分配器有专属测试） }
  LBump := TBumpAllocator.Create(DefaultAllocator, 4096);
  try
    Check(LBump <> nil, 'TBumpAllocator accessible');
  finally
    LBump.Free;
  end;

  LCascade := TCascadeAllocator.Create([DefaultAllocator]);
  try
    Check(LCascade <> nil, 'TCascadeAllocator accessible');
  finally
    LCascade.Free;
  end;

  LBitmap := TBitmapAllocator.Create(DefaultAllocator, 64, 16);
  try
    Check(LBitmap <> nil, 'TBitmapAllocator accessible');
  finally
    LBitmap.Free;
  end;

  LBatch := TBatchAllocator.Create(DefaultAllocator);
  try
    Check(LBatch <> nil, 'TBatchAllocator accessible');
  finally
    LBatch.Free;
  end;

  LSentinel := TSentinelAllocator.Create(DefaultAllocator);
  try
    Check(LSentinel <> nil, 'TSentinelAllocator accessible');
  finally
    LSentinel.Free;
  end;

  LGuard := TGuardAllocator.Create;
  try
    Check(LGuard <> nil, 'TGuardAllocator accessible');
  finally
    LGuard.Free;
  end;

  LLeakReport := TLeakReportAllocator.Create(DefaultAllocator);
  try
    Check(LLeakReport <> nil, 'TLeakReportAllocator accessible');
  finally
    LLeakReport.Free;
  end;

  LLogging := TLoggingAllocator.Create(DefaultAllocator);
  try
    Check(LLogging <> nil, 'TLoggingAllocator accessible');
  finally
    LLogging.Free;
  end;

  LDebug := TDebugAllocator.Create(DefaultAllocator);
  try
    Check(LDebug <> nil, 'TDebugAllocator accessible');
  finally
    LDebug.Free;
  end;

  LWatermark := TWatermarkAllocator.Create(DefaultAllocator);
  try
    Check(LWatermark <> nil, 'TWatermarkAllocator accessible');
  finally
    LWatermark.Free;
  end;

  LSampling := TSamplingAllocator.Create(DefaultAllocator);
  try
    Check(LSampling <> nil, 'TSamplingAllocator accessible');
  finally
    LSampling.Free;
  end;

  LPrefix := TPrefixAllocator.Create(DefaultAllocator);
  try
    Check(LPrefix <> nil, 'TPrefixAllocator accessible');
  finally
    LPrefix.Free;
  end;

  LPrediction := TPredictionAllocator.Create(DefaultAllocator);
  try
    Check(LPrediction <> nil, 'TPredictionAllocator accessible');
  finally
    LPrediction.Free;
  end;

  LReplay := TReplayAllocator.Create(DefaultAllocator);
  try
    Check(LReplay <> nil, 'TReplayAllocator accessible');
  finally
    LReplay.Free;
  end;

  LNuma := TNumaAllocator.Create(DefaultAllocator);
  try
    Check(LNuma <> nil, 'TNumaAllocator accessible');
  finally
    LNuma.Free;
  end;
end;

procedure TestAllAllocatorExportsAccessible;
var
  LAligned: TAlignedAllocator;
  LBounded: TBoundedAllocator;
  LCoalesce: TCoalesceAllocator;
  LCounting: TCountingAllocator;
  LCow: TCowAllocator;
  LCrt: TCrtAllocator;
  LDual: TDualAllocator;
  LFail: TFailAllocator;
  LFreelist: TFreelistAllocator;
  LGroup: TGroupAllocator;
  LHotswap: THotswapAllocator;
  LPage: TPageAllocator;
  LPool: TPoolAllocator;
  LPool2: TPool2Allocator;
  LRtl: TRtlAllocator;
  LScoped: TScopedAllocator;
  LSizeClass: TSizeClassAllocator;
  LSlab: TSlabAllocator;
  LSliding: TSlidingAllocator;
  LStack: TStackAllocator;
  LStats: TStatsAllocator;
  LThreadCache: TThreadCacheAllocator;
  LThreadSafe: TThreadSafeAllocator;
  LZeroed: TZeroedAllocator;
  LArena2: TArena2Allocator;
  LArenaGroup: TArenaGroupAllocator;
begin
  { 验证所有新增的分配器类型可访问 }
  LAligned := TAlignedAllocator.Create(DefaultAllocator, 16);
  try Check(LAligned <> nil, 'TAlignedAllocator accessible'); finally LAligned.Free; end;

  LBounded := TBoundedAllocator.Create(DefaultAllocator, 1024);
  try Check(LBounded <> nil, 'TBoundedAllocator accessible'); finally LBounded.Free; end;

  LCoalesce := TCoalesceAllocator.Create(DefaultAllocator);
  try Check(LCoalesce <> nil, 'TCoalesceAllocator accessible'); finally LCoalesce.Free; end;

  LCounting := TCountingAllocator.Create(DefaultAllocator);
  try Check(LCounting <> nil, 'TCountingAllocator accessible'); finally LCounting.Free; end;

  LCow := TCowAllocator.Create(DefaultAllocator);
  try Check(LCow <> nil, 'TCowAllocator accessible'); finally LCow.Free; end;

  LCrt := TCrtAllocator.Create;
  try Check(LCrt <> nil, 'TCrtAllocator accessible'); finally LCrt.Free; end;

  LDual := TDualAllocator.Create(DefaultAllocator, DefaultAllocator);
  try Check(LDual <> nil, 'TDualAllocator accessible'); finally LDual.Free; end;

  LFail := TFailAllocator.Create(DefaultAllocator, 0);
  try Check(LFail <> nil, 'TFailAllocator accessible'); finally LFail.Free; end;

  LFreelist := TFreelistAllocator.Create(DefaultAllocator);
  try Check(LFreelist <> nil, 'TFreelistAllocator accessible'); finally LFreelist.Free; end;

  LGroup := TGroupAllocator.Create(DefaultAllocator);
  try Check(LGroup <> nil, 'TGroupAllocator accessible'); finally LGroup.Free; end;

  LHotswap := THotswapAllocator.Create(DefaultAllocator);
  try Check(LHotswap <> nil, 'THotswapAllocator accessible'); finally LHotswap.Free; end;

  LPage := TPageAllocator.Create(DefaultAllocator);
  try Check(LPage <> nil, 'TPageAllocator accessible'); finally LPage.Free; end;

  LPool := TPoolAllocator.Create(DefaultAllocator, 64, 16);
  try Check(LPool <> nil, 'TPoolAllocator accessible'); finally LPool.Free; end;

  LPool2 := TPool2Allocator.Create(DefaultAllocator, 64);
  try Check(LPool2 <> nil, 'TPool2Allocator accessible'); finally LPool2.Free; end;

  LRtl := TRtlAllocator.Create;
  try Check(LRtl <> nil, 'TRtlAllocator accessible'); finally LRtl.Free; end;

  LScoped := TScopedAllocator.Create(DefaultAllocator);
  try Check(LScoped <> nil, 'TScopedAllocator accessible'); finally LScoped.Free; end;

  LSizeClass := TSizeClassAllocator.Create(DefaultAllocator);
  try Check(LSizeClass <> nil, 'TSizeClassAllocator accessible'); finally LSizeClass.Free; end;

  LSlab := TSlabAllocator.Create(DefaultAllocator);
  try Check(LSlab <> nil, 'TSlabAllocator accessible'); finally LSlab.Free; end;

  LSliding := TSlidingAllocator.Create(DefaultAllocator, 1024);
  try Check(LSliding <> nil, 'TSlidingAllocator accessible'); finally LSliding.Free; end;

  LStack := TStackAllocator.Create(DefaultAllocator, 4096);
  try Check(LStack <> nil, 'TStackAllocator accessible'); finally LStack.Free; end;

  LStats := TStatsAllocator.Create(DefaultAllocator);
  try Check(LStats <> nil, 'TStatsAllocator accessible'); finally LStats.Free; end;

  LThreadCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try Check(LThreadCache <> nil, 'TThreadCacheAllocator accessible'); finally LThreadCache.Free; end;

  LThreadSafe := TThreadSafeAllocator.Create(DefaultAllocator);
  try Check(LThreadSafe <> nil, 'TThreadSafeAllocator accessible'); finally LThreadSafe.Free; end;

  LZeroed := TZeroedAllocator.Create(DefaultAllocator);
  try Check(LZeroed <> nil, 'TZeroedAllocator accessible'); finally LZeroed.Free; end;

  LArena2 := TArena2Allocator.Create(DefaultAllocator, 4096);
  try Check(LArena2 <> nil, 'TArena2Allocator accessible'); finally LArena2.Free; end;

  LArenaGroup := TArenaGroupAllocator.Create(DefaultAllocator);
  try Check(LArenaGroup <> nil, 'TArenaGroupAllocator accessible'); finally LArenaGroup.Free; end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.facade');
  T.Test('DefaultAllocator not nil', @TestDefaultAllocatorNotNil);
  T.Test('Allocator basic ops', @TestAllocatorBasicOps);
  T.Test('AllocZeroed and AllocArray', @TestAllocZeroedAndArray);
  T.Test('Mutex/RwLock accessible', @TestMutexRwLockAccessible);
  T.Test('Arena types accessible', @TestArenaTypesAccessible);
  T.Test('Pool types accessible', @TestPoolTypesAccessible);
  T.Test('SlabPool accessible', @TestSlabPoolAccessible);
  T.Test('IMemoryPool accessible', @TestIMemoryPoolAccessible);
  T.Test('RingBuffer accessible', @TestRingBufferAccessible);
  T.Test('BlockPoolConcurrent accessible', @TestBlockPoolConcurrentAccessible);
  T.Test('SecureZero accessible', @TestSecureZeroAccessible);
  T.Test('TrackingAllocator accessible', @TestTrackingAllocatorAccessible);
  T.Test('New exports accessible', @TestNewExportsAccessible);
  T.Test('All allocator exports accessible', @TestAllAllocatorExportsAccessible);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
