program test_oom;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.exception,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.growable,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool.fixed.growable,
  nextpas.core.mem.ring_buffer,
  nextpas.core.mem.stack_pool,
  nextpas.core.platform.memory,
  nextpas.core.platform.mmap;

type
  TExceptionProc = procedure;

  TFailAllocator = class(nextpas.core.mem.allocator.TAllocator)
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  end;

var
  T: TTestRunner;
  GFailVirtualReserve: Boolean = False;
  GFailVirtualCommit: Boolean = False;
  GFailVirtualMmap: Boolean = False;

function TFailAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

function TFailAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

function TFailAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := nil;
end;

procedure TFailAllocator.DoFreeMem(aDst: Pointer);
begin
end;

function NewFailAllocator: nextpas.core.mem.allocator.IAllocator;
begin
  Result := TFailAllocator.Create as nextpas.core.mem.allocator.IAllocator;
end;

procedure ResetVirtualArenaHooks;
begin
  GFailVirtualReserve := False;
  GFailVirtualCommit := False;
  GFailVirtualMmap := False;
  VirtualArenaTestResetHooks;
end;

function TestVirtualReserve(ASize: SizeUInt): Pointer;
begin
  if GFailVirtualReserve then
    Exit(nil);
  Result := platform_virtual_reserve(ASize);
end;

function TestVirtualCommit(APtr: Pointer; ASize: SizeUInt): Boolean;
begin
  if GFailVirtualCommit then
    Exit(False);
  Result := platform_virtual_commit(APtr, ASize);
end;

function TestVirtualMmapAnonymous(ASize: UInt64; AAccess: TPlatformMapAccess;
  AFlags: TPlatformMapFlags; out AMap: TPlatformMappedFile): Int32;
begin
  if GFailVirtualMmap then
  begin
    FillChar(AMap, SizeOf(AMap), 0);
    Exit(-1);
  end;
  Result := platform_mmap_create_anonymous(ASize, AAccess, AFlags, AMap);
end;

procedure CheckRaisesCanonicalOutOfMemory(aProc: TExceptionProc; const aName: string);
var
  LCaughtOom: Boolean;
  LCaughtAlloc: Boolean;
begin
  LCaughtOom := False;
  LCaughtAlloc := False;

  try
    aProc;
  except
    on E: EOutOfMemoryError do
      LCaughtOom := True;
    on E: EAllocError do
      LCaughtAlloc := True;
  end;

  Check(LCaughtOom, aName + ' raises canonical OOM');
  Check(not LCaughtAlloc, aName + ' is not caught by non-OOM EAllocError');
end;

procedure CheckRaisesAllocError(aProc: TExceptionProc; aExpected: TAllocError; const aName: string);
var
  LCaughtExpected: Boolean;
  LCaughtOom: Boolean;
begin
  LCaughtExpected := False;
  LCaughtOom := False;

  try
    aProc;
  except
    on E: EOutOfMemoryError do
      LCaughtOom := True;
    on E: EAllocError do
      LCaughtExpected := E.Error = aExpected;
  end;

  Check(LCaughtExpected, aName + ' raises expected allocation error');
  Check(not LCaughtOom, aName + ' is not canonical OOM');
end;

procedure RaiseMemOutOfMemory;
begin
  raise nextpas.core.mem.error.EOutOfMemory.Create(aeOutOfMemory, 'alloc result');
end;

procedure RaiseBlockPoolTotalSizeOverflow;
var
  LPool: TBlockPool;
begin
  LPool := nil;
  try
    LPool := TBlockPool.Create((High(SizeUInt) div 2) + 1, 2);
  finally
    LPool.Free;
  end;
end;

{ TFixedArena 已删除，此测试不再适用 }
{procedure RaiseBlockPoolArenaAllocationOverflow;
var
  LArena: TLocalArena;
begin
  LArena := nil;
  try
    LArena := TLocalArena.Create(High(SizeUInt));
  finally
    LArena.Free;
  end;
end;}

procedure RaiseGrowingBlockPoolAllocatorOom;
var
  LConfig: TGrowingBlockPoolConfig;
  LPool: TGrowingBlockPool;
begin
  LConfig := TGrowingBlockPoolConfig.Default(16, 1);
  LConfig.Allocator := NewFailAllocator;
  LPool := nil;
  try
    LPool := TGrowingBlockPool.Create(LConfig);
  finally
    LPool.Free;
  end;
end;

procedure RaiseGrowingArenaAllocatorOom;
var
  LArena: TChunkedArena;
begin
  LArena := nil;
  try
    { TChunkedArena uses GetMem by default }
    LArena := TChunkedArena.Create(16);
  finally
    LArena.Free;
  end;
end;

procedure RaiseFixedPoolAllocatorOom;
var
  LPool: TFixedPool;
begin
  LPool := nil;
  try
    LPool := TFixedPool.Create(16, 1, 16, NewFailAllocator);
  finally
    LPool.Free;
  end;
end;

procedure RaiseGrowingFixedPoolAllocatorOom;
var
  LConfig: TGrowingFixedPoolConfig;
  LPool: TGrowingFixedPool;
begin
  FillChar(LConfig, SizeOf(LConfig), 0);
  LConfig.BlockSize := 16;
  LConfig.InitialCapacity := 1;
  LConfig.GrowthKind := gkGeometric;
  LConfig.GrowthFactor := 2.0;
  LConfig.Allocator := NewFailAllocator;

  LPool := nil;
  try
    LPool := TGrowingFixedPool.Create(LConfig);
  finally
    LPool.Free;
  end;
end;

procedure RaiseRingBufferAllocatorOom;
var
  LRing: TRingBuffer;
begin
  LRing := nil;
  try
    LRing := TRingBuffer.Create(1, 1, NewFailAllocator);
  finally
    LRing.Free;
  end;
end;

procedure RaiseStackPoolAllocatorOom;
var
  LPool: TStackPool;
begin
  LPool := nil;
  try
    LPool := TStackPool.Create(1, NewFailAllocator);
  finally
    LPool.Free;
  end;
end;

procedure TestMemOutOfMemoryUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseMemOutOfMemory, 'EOutOfMemory.Create');
end;

procedure TestBlockPoolOverflowContracts;
begin
  CheckRaisesAllocError(@RaiseBlockPoolTotalSizeOverflow, aeInvalidLayout, 'TBlockPool.Create layout overflow');
  { TFixedArena 已删除，此测试不再适用 }
  {CheckRaisesCanonicalOutOfMemory(@RaiseBlockPoolArenaAllocationOverflow, 'TArena.Create allocation overflow');}
end;

procedure TestGrowableMemOomUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseGrowingBlockPoolAllocatorOom, 'TGrowingBlockPool.Create');
  { TChunkedArena now uses GetMem directly, custom allocator OOM test removed }
  CheckRaisesCanonicalOutOfMemory(@RaiseGrowingFixedPoolAllocatorOom, 'TGrowingFixedPool.Create');
end;

procedure TestAllocatorBackedMemOomUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseFixedPoolAllocatorOom, 'TFixedPool.Create');
  CheckRaisesCanonicalOutOfMemory(@RaiseRingBufferAllocatorOom, 'TRingBuffer.Create');
  CheckRaisesCanonicalOutOfMemory(@RaiseStackPoolAllocatorOom, 'TStackPool.Create');
end;

procedure RaiseVirtualArenaReserveFailure;
var
  LArena: TVirtualArena;
begin
  FillChar(LArena, SizeOf(LArena), 0);
  ResetVirtualArenaHooks;
  VirtualArenaTestSetReserveHook(@TestVirtualReserve);
  GFailVirtualReserve := True;
  try
    TVirtualArena_Init(LArena);
  finally
    ResetVirtualArenaHooks;
  end;
end;

procedure TestVirtualArenaReserveFailureUsesCanonicalRoot;
begin
  CheckRaisesCanonicalOutOfMemory(@RaiseVirtualArenaReserveFailure,
    'TVirtualArena_Init reserve failure');
end;

procedure TestVirtualArenaCommitFailureReturnsNil;
var
  LArena: TVirtualArena;
begin
  FillChar(LArena, SizeOf(LArena), 0);
  TVirtualArena_Init(LArena);
  try
    ResetVirtualArenaHooks;
    VirtualArenaTestSetCommitHook(@TestVirtualCommit);
    GFailVirtualCommit := True;
    Check(LArena.Alloc(32) = nil, 'Alloc should return nil when front commit fails');
    Check(LArena.AllocNoPointer(32) = nil, 'AllocNoPointer should return nil when back commit fails');
  finally
    ResetVirtualArenaHooks;
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestVirtualArenaLargeObjectMmapFailureReturnsNil;
var
  LArena: TVirtualArena;
begin
  FillChar(LArena, SizeOf(LArena), 0);
  TVirtualArena_Init(LArena);
  try
    ResetVirtualArenaHooks;
    VirtualArenaTestSetMmapHook(@TestVirtualMmapAnonymous);
    GFailVirtualMmap := True;
    Check(LArena.Alloc(ARENA_LARGE_THRESHOLD) = nil,
      'Alloc should return nil when large-object mmap fails');
    Check(LArena.AllocNoPointer(ARENA_LARGE_THRESHOLD) = nil,
      'AllocNoPointer should return nil when large-object mmap fails');
    Check(LArena.AllocAligned(ARENA_LARGE_THRESHOLD, 64) = nil,
      'AllocAligned should return nil when large-object mmap fails');
  finally
    ResetVirtualArenaHooks;
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestNonOomAllocErrorRemainsEAllocError;
var
  LCaughtAlloc: Boolean;
begin
  LCaughtAlloc := False;
  try
    raise EAllocError.Create(aeInvalidLayout, 'invalid layout');
  except
    on E: EAllocError do
      LCaughtAlloc := True;
  end;

  Check(LCaughtAlloc, 'non-OOM allocation errors remain EAllocError');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.oom');
  T.Run('mem OOM uses canonical root', @TestMemOutOfMemoryUsesCanonicalRoot);
  T.Run('blockpool overflow contracts', @TestBlockPoolOverflowContracts);
  T.Run('growable mem OOM uses canonical root', @TestGrowableMemOomUsesCanonicalRoot);
  T.Run('allocator-backed mem OOM uses canonical root', @TestAllocatorBackedMemOomUsesCanonicalRoot);
  T.Run('virtual arena reserve failure uses canonical root',
    @TestVirtualArenaReserveFailureUsesCanonicalRoot);
  T.Run('virtual arena commit failure returns nil',
    @TestVirtualArenaCommitFailureReturnsNil);
  T.Run('virtual arena large-object mmap failure returns nil',
    @TestVirtualArenaLargeObjectMmapFailureReturnsNil);
  T.Run('non-OOM allocation error remains EAllocError', @TestNonOomAllocErrorRemainsEAllocError);
  T.Summary;
end.
