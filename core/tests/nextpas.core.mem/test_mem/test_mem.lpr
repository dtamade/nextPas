program test_mem;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.mem;

var
  T: TTestSuite;

{ E1: 验证 facade re-export 的类型可访问且可实例化 }

procedure TestDefaultAllocatorNotNil;
var
  LAlloc: TAllocator;
begin
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'DefaultAllocator should not be nil');
  Check(DefaultAllocator = LAlloc, 'DefaultAllocator should be singleton');
end;

procedure TestAllocatorBasicOps;
var
  LAlloc: TAllocator;
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
  Check(LAlloc.MemSize(nil) = 0, 'MemSize(nil) should return 0');
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
  LTracker: TAllocator;
  LPtr: Pointer;
begin
  LTracker := TTrackingAllocator.Create(DefaultAllocator);
  LPtr := LTracker.GetMem(64);
  Check(LPtr <> nil, 'TrackingAllocator.GetMem should succeed');
  LTracker.FreeMem(LPtr);
  { LTracker 引用计数自动释放 }
end;

{ 验证 TGrowingAllocator 可通过 facade 访问 }
procedure TestGrowingAllocatorAccessible;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'TGrowingAllocator.GetMem should succeed');
    LAlloc.FreeMem(LPtr, 128);
  finally
    LAlloc.Free;
  end;
end;

{ 验证 IFixedSlabPool + MakeFixedSlabPool 可通过 facade 访问 }
procedure TestFixedSlabPoolAccessible;
var
  LPool: IFixedSlabPool;
  LPtr: Pointer;
  LOk: Boolean;
begin
  LPool := MakeFixedSlabPool(512);
  Check(LPool <> nil, 'MakeFixedSlabPool should return non-nil');
  LOk := LPool.Acquire(LPtr);
  Check(LOk, 'IFixedSlabPool.Acquire should succeed');
  Check(LPtr <> nil, 'Acquire should return non-nil');
  LPool.Release(LPtr);
end;

{ 验证 TPoolAllocator 可通过 facade 访问 }
procedure TestPoolAllocatorAccessible;
var
  LAlloc: TAllocator;
  LPtr: Pointer;
begin
  LAlloc := MakePoolAllocator(64, 50);
  Check(LAlloc <> nil, 'MakePoolAllocator should return non-nil');
  LPtr := LAlloc.GetMem(32);
  Check(LPtr <> nil, 'PoolAllocator.GetMem should succeed');
  LAlloc.FreeMem(LPtr);
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
  T.Test('GrowingAllocator accessible', @TestGrowingAllocatorAccessible);
  T.Test('FixedSlabPool accessible', @TestFixedSlabPoolAccessible);
  T.Test('PoolAllocator accessible', @TestPoolAllocatorAccessible);
  T.Run;

  T.Summary;
end.
