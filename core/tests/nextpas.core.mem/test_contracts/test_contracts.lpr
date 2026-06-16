program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.compat,
  nextpas.core.mem.intf,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.mimalloc,
  nextpas.core.mem.alloc,
  nextpas.core.mem.error,
  nextpas.core.mem.layout,
  nextpas.core.mem.adapter,
  nextpas.core.mem.aligned;

const
  MEM_ALIGNED_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.aligned.pas';
  MEM_ALIGNED_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.aligned.pas';
  MEM_COMPAT_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.compat.pas';
  MEM_COMPAT_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.compat.pas';
  MEM_INTERFACES_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.interfaces.pas';
  MEM_INTERFACES_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.interfaces.pas';
  MEM_ADAPTERS_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.adapters.pas';
  MEM_ADAPTERS_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.adapters.pas';
  MEM_POOL_ADAPTER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.pool.adapter.pas';
  MEM_POOL_ADAPTER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.pool.adapter.pas';
  MEM_MEM_POOL_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.mem_pool.pas';
  MEM_MEM_POOL_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.mem_pool.pas';
  MEM_STATS_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.stats.pas';
  MEM_STATS_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.stats.pas';

type
  TByteArray = array[0..5] of Byte;
  TWordArray = array[0..3] of Word;
  TDWordArray = array[0..2] of UInt32;
  TQWordArray = array[0..1] of UInt64;

  TRecordingAlloc = class(TInterfacedObject, IAlloc)
  public
    AllocCalls: Integer;
    ReallocCalls: Integer;
    DeallocCalls: Integer;
    LastAllocLayout: TMemLayout;
    LastReallocOldLayout: TMemLayout;
    LastReallocNewLayout: TMemLayout;
    LastDeallocLayout: TMemLayout;

    function Alloc(const aLayout: TMemLayout): TAllocResult;
    function AllocZeroed(const aLayout: TMemLayout): TAllocResult;
    procedure Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
    function Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
    function Caps: TAllocCaps;
  end;

var
  T: TTestRunner;
  GGetMemCalls: Integer = 0;
  GAllocMemCalls: Integer = 0;
  GReallocMemCalls: Integer = 0;
  GFreeMemCalls: Integer = 0;

function ReadSourceText(const APath: string): string;
var
  LFile: Text;
  LLine: string;
begin
  Result := '';
  Assign(LFile, APath);
  Reset(LFile);
  try
    while not Eof(LFile) do
    begin
      ReadLn(LFile, LLine);
      Result := Result + LowerCase(LLine) + #10;
    end;
  finally
    Close(LFile);
  end;
end;

function ResolveSourcePath(const APathFromTest, APathFromRoot: string): string;
begin
  if FileExists(APathFromTest) then
    Exit(APathFromTest);
  if FileExists(APathFromRoot) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckNotContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure ResetAllocatorCounters;
begin
  GGetMemCalls := 0;
  GAllocMemCalls := 0;
  GReallocMemCalls := 0;
  GFreeMemCalls := 0;
end;

function TRecordingAlloc.Alloc(const aLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  Inc(AllocCalls);
  LastAllocLayout := aLayout;
  if not aLayout.IsValid then
    Exit(TAllocResult.Err(aeInvalidLayout));
  if aLayout.IsZeroSized then
    Exit(TAllocResult.Ok(nil));

  LPtr := System.GetMem(aLayout.Size);
  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TRecordingAlloc.AllocZeroed(const aLayout: TMemLayout): TAllocResult;
begin
  Result := Alloc(aLayout);
  if Result.IsOk and (Result.Ptr <> nil) then
    FillChar(Result.Ptr^, aLayout.Size, 0);
end;

procedure TRecordingAlloc.Dealloc(aPtr: Pointer; const aLayout: TMemLayout);
begin
  Inc(DeallocCalls);
  LastDeallocLayout := aLayout;
  if (aPtr <> nil) and (aLayout.Size > 0) then
    System.FreeMem(aPtr);
end;

function TRecordingAlloc.Realloc(aPtr: Pointer; const aOldLayout, aNewLayout: TMemLayout): TAllocResult;
var
  LPtr: Pointer;
begin
  Inc(ReallocCalls);
  LastReallocOldLayout := aOldLayout;
  LastReallocNewLayout := aNewLayout;
  if aPtr = nil then
    Exit(Alloc(aNewLayout));
  if aNewLayout.IsZeroSized then
  begin
    Dealloc(aPtr, aOldLayout);
    Exit(TAllocResult.Ok(nil));
  end;

  LPtr := System.ReallocMem(aPtr, aNewLayout.Size);
  if LPtr = nil then
    Result := TAllocResult.Err(aeOutOfMemory)
  else
    Result := TAllocResult.Ok(LPtr);
end;

function TRecordingAlloc.Caps: TAllocCaps;
begin
  Result := TAllocCaps.Create(False, True, False, True, True, 256);
end;

function CallbackGetMem(aSize: SizeUInt): Pointer;
begin
  Inc(GGetMemCalls);
  Result := System.GetMem(aSize);
end;

function CallbackAllocMem(aSize: SizeUInt): Pointer;
begin
  Inc(GAllocMemCalls);
  Result := System.AllocMem(aSize);
end;

function CallbackReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Inc(GReallocMemCalls);
  Result := System.ReallocMem(aDst, aSize);
end;

procedure CallbackFreeMem(aDst: Pointer);
begin
  Inc(GFreeMemCalls);
  System.FreeMem(aDst);
end;

procedure TestCallbackAllocatorCompatibilityMethods;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  ResetAllocatorCounters;
  LAllocator := CreateCallbackAllocator(
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem);

  Check(LAllocator <> nil, 'callback allocator should be created');
  Check(LAllocator.GetMem(0) = nil, 'GetMem(0) should return nil');
  Check(LAllocator.AllocMem(0) = nil, 'AllocMem(0) should return nil');

  LPtr := LAllocator.ReallocMem(nil, 16);
  Check(LPtr <> nil, 'ReallocMem(nil, size) should allocate');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'ReallocMem(nil, size) should route through GetMem');
  CheckEqual(Int64(0), Int64(GReallocMemCalls), 'ReallocMem(nil, size) should not call realloc callback');

  PByte(LPtr)^ := $5A;
  LPtr := LAllocator.ReallocMem(LPtr, 32);
  Check(LPtr <> nil, 'ReallocMem(existing, size) should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'ReallocMem(existing, size) should call realloc callback');
  CheckEqual(Int64($5A), Int64(PByte(LPtr)^), 'ReallocMem should preserve the existing prefix');

  LPtr := LAllocator.ReallocMem(LPtr, 0);
  Check(LPtr = nil, 'ReallocMem(existing, 0) should free and return nil');
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'ReallocMem(existing, 0) should call free callback');

  LAllocator.FreeMem(nil);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'FreeMem(nil) should be a no-op');
end;

procedure TestCallbackAllocatorSupportsAllocateInterface;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
  LPtr: Pointer;
begin
  ResetAllocatorCounters;
  LAllocator := CreateCallbackAllocator(
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem) as nextpas.core.mem.intf.IAllocator;

  LPtr := LAllocator.Allocate(24);
  Check(LPtr <> nil, 'Allocate should delegate to the compatibility allocator');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'Allocate should route through GetMem');

  PByte(LPtr)^ := $33;
  LPtr := LAllocator.Reallocate(LPtr, 48);
  Check(LPtr <> nil, 'Reallocate should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'Reallocate should route through ReallocMem');
  CheckEqual(Int64($33), Int64(PByte(LPtr)^), 'Reallocate should preserve the prefix');

  LAllocator.Deallocate(LPtr);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'Deallocate should route through FreeMem');
end;

procedure TestRtlAllocatorZeroInitTraitsAndAlignedAlloc;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LTraits: nextpas.core.mem.allocator.base.TAllocatorTraits;
  LPtr: Pointer;
  I: Integer;
begin
  LAllocator := GetRtlAllocator;
  Check(LAllocator <> nil, 'RTL allocator should exist');

  LTraits := LAllocator.Traits;
  CheckEqual(True, LTraits.ZeroInitialized, 'RTL AllocMem should be zero initialized');
  CheckEqual(False, LTraits.SupportsAligned, 'RTL allocator should report non-native aligned support');
  CheckEqual(False, LTraits.HasMemSize, 'RTL allocator should not expose MemSize');

  LPtr := LAllocator.AllocMem(32);
  try
    for I := 0 to 31 do
      CheckEqual(Int64(0), Int64(PByte(LPtr)[I]), 'AllocMem should zero initialize each byte');
  finally
    LAllocator.FreeMem(LPtr);
  end;

  LPtr := LAllocator.AllocAligned(64, 32);
  try
    Check(LPtr <> nil, 'AllocAligned should return a pointer');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 32), 'AllocAligned should honor the requested alignment');
  finally
    LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestRtlAllocatorAlignedAllocRejectsSizeOverflow;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator;
  LPtr := LAllocator.AllocAligned(High(SizeUInt), SizeOf(Pointer));
  try
    Check(LPtr = nil, 'AllocAligned should reject size calculations that overflow SizeUInt');
  finally
    if LPtr <> nil then
      LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestAlignedCompatShimSmoke;
var
  LPtr: Pointer;
begin
  LPtr := nextpas.core.mem.aligned.AllocAligned(64, 32);
  try
    Check(LPtr <> nil, 'aligned compat shim should allocate');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 32),
      'aligned compat shim should honor requested alignment');
    PByte(LPtr)^ := $4D;
    CheckEqual(Int64($4D), Int64(PByte(LPtr)^),
      'aligned compat shim should return writable memory');
  finally
    nextpas.core.mem.aligned.FreeAligned(LPtr);
  end;
end;

procedure TestAlignedCompatShimDelegatesToCanonicalAllocator;
var
  LSource: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_ALIGNED_SOURCE_PATH_FROM_TEST,
    MEM_ALIGNED_SOURCE_PATH_FROM_ROOT));
  CheckContains(LSource, '{$warning ''nextpas.core.mem.aligned is deprecated',
    'aligned compat shim should publish a deprecation warning');
  CheckContains(LSource,
    'deprecated ''use nextpas.core.mem.default.defaultallocator.allocaligned instead''',
    'aligned compat alloc surface should be deprecated');
  CheckContains(LSource,
    'deprecated ''use nextpas.core.mem.default.defaultallocator.freealigned instead''',
    'aligned compat free surface should be deprecated');
  CheckContains(LSource, 'nextpas.core.mem.default',
    'aligned compat shim should depend on the canonical default allocator');
  CheckContains(LSource, 'nextpas.core.mem.intf',
    'aligned compat shim should reference the canonical allocator contract');
  CheckContains(LSource, 'lallocator := nextpas.core.mem.default.defaultallocator;',
    'aligned compat shim should obtain the canonical allocator');
  CheckContains(LSource, 'result := lallocator.allocaligned(asize, aalignment);',
    'aligned compat alloc should delegate to the canonical allocator');
  CheckContains(LSource, 'lallocator.freealigned(aptr);',
    'aligned compat free should delegate to the canonical allocator');
  CheckNotContains(LSource, '_aligned_malloc',
    'aligned compat shim should not own a windows allocation path');
  CheckNotContains(LSource, 'posix_memalign',
    'aligned compat shim should not own a unix allocation path');
  CheckNotContains(LSource, 'libc_free',
    'aligned compat shim should not own a unix free path');
  CheckNotContains(LSource, 'sysgetmem',
    'aligned compat shim should not own a raw rtl fallback path');
  CheckNotContains(LSource, 'sysfreemem',
    'aligned compat shim should not own a raw rtl free path');
end;

procedure TestMemCompatFacadeExportsLegacyPoolSurface;
var
  LPool: nextpas.core.mem.compat.TMemPool;
  LCompatPool: nextpas.core.mem.compat.IMemPool;
  LPtr: Pointer;
begin
  LPool := nextpas.core.mem.compat.TMemPool.Create(32, 2);
  try
    LCompatPool := nextpas.core.mem.compat.TMemPoolAdapter.Create(LPool);
    LPtr := LCompatPool.Alloc;
    try
      Check(LPtr <> nil, 'mem.compat should export the legacy mem-pool adapter surface');
      Check(nextpas.core.mem.compat.WrapAsBlockPool(LCompatPool) <> nil,
        'mem.compat should export pool bridge helpers');
    finally
      LCompatPool.Free(LPtr);
    end;
  finally
    LPool.Free;
  end;
end;

procedure TestMemCompatFacadeSourceContracts;
var
  LCompatSource: string;
  LInterfacesSource: string;
  LAdaptersSource: string;
  LPoolAdapterSource: string;
  LMemPoolSource: string;
  LStatsSource: string;
begin
  LCompatSource := ReadSourceText(ResolveSourcePath(
    MEM_COMPAT_SOURCE_PATH_FROM_TEST,
    MEM_COMPAT_SOURCE_PATH_FROM_ROOT));
  CheckContains(LCompatSource, 'compatibility layer',
    'mem.compat should document that it is a compatibility layer');
  CheckContains(LCompatSource, 'new code',
    'mem.compat should tell new code to stay on canonical units');
  CheckContains(LCompatSource, 'nextpas.core.mem.intf',
    'mem.compat should depend on the canonical allocator contract');
  CheckContains(LCompatSource, 'nextpas.core.mem.pool.fixed',
    'mem.compat should depend on the canonical fixed-pool implementation');
  CheckContains(LCompatSource, 'nextpas.core.mem.stack_pool',
    'mem.compat should depend on the canonical stack-pool implementation');
  CheckContains(LCompatSource, 'nextpas.core.mem.pool.slab',
    'mem.compat should depend on the canonical slab-pool implementation');
  CheckContains(LCompatSource, 'nextpas.core.mem.blockpool',
    'mem.compat should depend on the canonical block-pool contract');
  CheckNotContains(LCompatSource, 'nextpas.core.mem.interfaces',
    'mem.compat must not depend on the deprecated interfaces shim');
  CheckNotContains(LCompatSource, 'nextpas.core.mem.adapters',
    'mem.compat must not depend on the deprecated adapters shim');
  CheckNotContains(LCompatSource, 'nextpas.core.mem.pool.adapter',
    'mem.compat must not depend on the deprecated pool adapter shim');
  CheckNotContains(LCompatSource, 'nextpas.core.mem.mem_pool',
    'mem.compat must not depend on the deprecated mem_pool shim');

  LInterfacesSource := ReadSourceText(ResolveSourcePath(
    MEM_INTERFACES_SOURCE_PATH_FROM_TEST,
    MEM_INTERFACES_SOURCE_PATH_FROM_ROOT));
  CheckContains(LInterfacesSource, '{$warning ''nextpas.core.mem.interfaces is deprecated',
    'mem.interfaces should publish a deprecation warning');
  CheckContains(LInterfacesSource, 'nextpas.core.mem.compat',
    'mem.interfaces should forward to mem.compat');

  LAdaptersSource := ReadSourceText(ResolveSourcePath(
    MEM_ADAPTERS_SOURCE_PATH_FROM_TEST,
    MEM_ADAPTERS_SOURCE_PATH_FROM_ROOT));
  CheckContains(LAdaptersSource, '{$warning ''nextpas.core.mem.adapters is deprecated',
    'mem.adapters should publish a deprecation warning');
  CheckContains(LAdaptersSource, 'nextpas.core.mem.compat',
    'mem.adapters should forward to mem.compat');

  LPoolAdapterSource := ReadSourceText(ResolveSourcePath(
    MEM_POOL_ADAPTER_SOURCE_PATH_FROM_TEST,
    MEM_POOL_ADAPTER_SOURCE_PATH_FROM_ROOT));
  CheckContains(LPoolAdapterSource, '{$warning ''nextpas.core.mem.pool.adapter is deprecated',
    'mem.pool.adapter should publish a deprecation warning');
  CheckContains(LPoolAdapterSource, 'nextpas.core.mem.compat',
    'mem.pool.adapter should forward to mem.compat');

  LMemPoolSource := ReadSourceText(ResolveSourcePath(
    MEM_MEM_POOL_SOURCE_PATH_FROM_TEST,
    MEM_MEM_POOL_SOURCE_PATH_FROM_ROOT));
  CheckContains(LMemPoolSource, '{$warning ''nextpas.core.mem.mem_pool is deprecated',
    'mem.mem_pool should publish a deprecation warning');
  CheckContains(LMemPoolSource, 'nextpas.core.mem.compat',
    'mem.mem_pool should forward to mem.compat');

  LStatsSource := ReadSourceText(ResolveSourcePath(
    MEM_STATS_SOURCE_PATH_FROM_TEST,
    MEM_STATS_SOURCE_PATH_FROM_ROOT));
  CheckNotContains(LStatsSource, 'nextpas.core.mem.mem_pool',
    'mem.stats should not depend on the deprecated mem.mem_pool shim');
  CheckContains(LStatsSource, 'nextpas.core.mem.pool.fixed',
    'mem.stats should use the canonical fixed-pool implementation');
end;

procedure TestCanonicalAllocatorSurface;
var
  LAllocator: nextpas.core.mem.intf.IAllocator;
  LTraits: nextpas.core.mem.intf.TAllocatorTraits;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator as nextpas.core.mem.intf.IAllocator;
  LTraits := LAllocator.Traits;
  Check(LTraits.ThreadSafe, 'canonical allocator exposes traits');

  LPtr := LAllocator.GetMem(16);
  try
    Check(LPtr <> nil, 'canonical allocator exposes GetMem');
    PByte(LPtr)^ := $4A;
    LPtr := LAllocator.ReallocMem(LPtr, 32);
    Check(LPtr <> nil, 'canonical allocator exposes ReallocMem');
    CheckEqual(Int64($4A), Int64(PByte(LPtr)^), 'canonical ReallocMem preserves prefix');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;

procedure TestAllocatorAliasesAreCanonical;
var
  LCanonical: nextpas.core.mem.intf.IAllocator;
  LFacade: nextpas.core.mem.allocator.IAllocator;
begin
  LFacade := GetRtlAllocator;
  LCanonical := LFacade as nextpas.core.mem.intf.IAllocator;
  Check(LCanonical <> nil, 'allocator facade alias should be canonical');
  Check(LCanonical = LFacade, 'facade and canonical allocator interfaces should resolve to the same interface identity');
end;

procedure TestAllocatorAdapterRoundTrip;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LAlloc: IAlloc;
  LRoundTrip: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAllocator := GetRtlAllocator;
  LAlloc := WrapAsAlloc(LAllocator);
  Check(LAlloc <> nil, 'WrapAsAlloc should return an adapter');

  LRoundTrip := WrapAsAllocator(LAlloc);
  Check(LRoundTrip <> nil, 'WrapAsAllocator should return an adapter');

  LPtr := LRoundTrip.GetMem(24);
  try
    Check(LPtr <> nil, 'adapter round trip should allocate');
    PByte(LPtr)^ := $27;
    LPtr := LRoundTrip.ReallocMem(LPtr, 48);
    Check(LPtr <> nil, 'adapter round trip should reallocate');
    CheckEqual(Int64($27), Int64(PByte(LPtr)^), 'adapter round trip should preserve data');
  finally
    LRoundTrip.FreeMem(LPtr);
  end;
end;

procedure TestAllocatorToAllocAdapterRejectsUnsupportedAlignment;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LAlloc: IAlloc;
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LAllocator := GetRtlAllocator;
  LAlloc := WrapAsAlloc(LAllocator);
  Check(LAlloc <> nil, 'WrapAsAlloc should return an adapter');

  LLayout := TMemLayout.Create(64, MEM_CACHE_LINE_SIZE);
  CheckEqual(False, LAlloc.Caps.SupportsLayout(LLayout),
    'wrapped RTL allocator caps should reject cache-line alignment');

  LResult := LAlloc.Alloc(LLayout);
  if LResult.IsOk and (LResult.Ptr <> nil) then
    LAllocator.FreeAligned(LResult.Ptr);
  Check(LResult.IsErr, 'adapter Alloc should reject unsupported alignment');
  CheckEqual(Int64(Ord(aeAlignmentNotSupported)), Int64(Ord(LResult.Error)),
    'adapter Alloc unsupported alignment error');

  LResult := LAlloc.AllocZeroed(LLayout);
  if LResult.IsOk and (LResult.Ptr <> nil) then
    LAllocator.FreeAligned(LResult.Ptr);
  Check(LResult.IsErr, 'adapter AllocZeroed should reject unsupported alignment');
  CheckEqual(Int64(Ord(aeAlignmentNotSupported)), Int64(Ord(LResult.Error)),
    'adapter AllocZeroed unsupported alignment error');

  LResult := LAlloc.Realloc(nil, TMemLayout.Empty, LLayout);
  if LResult.IsOk and (LResult.Ptr <> nil) then
    LAllocator.FreeAligned(LResult.Ptr);
  Check(LResult.IsErr, 'adapter Realloc(nil) should reject unsupported alignment');
  CheckEqual(Int64(Ord(aeAlignmentNotSupported)), Int64(Ord(LResult.Error)),
    'adapter Realloc(nil) unsupported alignment error');
end;

procedure TestAllocatorToAllocAdapterRejectsInvalidOldLayout;
var
  LRecording: TRecordingAlloc;
  LAlloc: IAlloc;
  LPtr: Pointer;
  LOldLayout: TMemLayout;
  LNewLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LRecording := TRecordingAlloc.Create;
  LAlloc := WrapAsAlloc(WrapAsAllocator(LRecording as IAlloc));
  Check(LAlloc <> nil, 'round-trip adapter should return an IAlloc');

  LNewLayout := TMemLayout.Create(32, MEM_DEFAULT_ALIGN);
  LResult := LAlloc.Alloc(LNewLayout);
  Check(LResult.IsOk and (LResult.Ptr <> nil), 'round-trip adapter should allocate');
  LPtr := LResult.Ptr;

  FillChar(LOldLayout, SizeOf(LOldLayout), 0);
  CheckEqual(False, LOldLayout.IsValid, 'test old layout should be invalid');

  LResult := LAlloc.Realloc(LPtr, LOldLayout, TMemLayout.Create(64, MEM_DEFAULT_ALIGN));
  Check(LResult.IsErr, 'adapter Realloc should reject invalid old layout');
  CheckEqual(Int64(Ord(aeInvalidLayout)), Int64(Ord(LResult.Error)),
    'adapter Realloc invalid old layout error');
  CheckEqual(Int64(0), Int64(LRecording.ReallocCalls),
    'invalid old layout must not reach wrapped allocator Realloc');
  CheckEqual(Int64(0), Int64(LRecording.DeallocCalls),
    'invalid old layout must not release the old block');

  LAlloc.Dealloc(LPtr, LNewLayout);
end;

procedure TestAllocatorAdapterAlignedRoundTrip;
var
  LAlloc: IAlloc;
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
begin
  LAlloc := GetAlignedAlloc;
  LAllocator := WrapAsAllocator(LAlloc);
  Check(LAllocator <> nil, 'aligned IAlloc should adapt to IAllocator');

  LPtr := LAllocator.AllocAligned(64, 64);
  try
    Check(LPtr <> nil, 'aligned adapter should allocate');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 64), 'aligned adapter should honor alignment');
    PByte(LPtr)^ := $42;

    LPtr := LAllocator.ReallocMem(LPtr, 128);
    Check(LPtr <> nil, 'aligned adapter should reallocate through tracked layout');
    CheckEqual(Int64(0), Int64(PtrUInt(LPtr) mod 64), 'aligned adapter realloc should preserve alignment');
    CheckEqual(Int64($42), Int64(PByte(LPtr)^), 'aligned adapter realloc should preserve prefix');
  finally
    LAllocator.FreeAligned(LPtr);
  end;
end;

procedure TestAlignedAllocRejectsBackingSizeOverflow;
var
  LAlloc: IAlloc;
  LLayout: TMemLayout;
  LResult: TAllocResult;
begin
  LAlloc := GetAlignedAlloc;
  LLayout := TMemLayout.Create(High(SizeUInt), 64);
  LResult := LAlloc.Alloc(LLayout);
  try
    Check(LResult.IsErr, 'aligned IAlloc should reject backing size calculations that overflow SizeUInt');
  finally
    if LResult.IsOk and (LResult.Ptr <> nil) then
      LAlloc.Dealloc(LResult.Ptr, LLayout);
  end;
end;

procedure TestAllocToAllocatorAdapterTracksLayoutsAndRejectsUntrackedPointers;
var
  LRecording: TRecordingAlloc;
  LAlloc: IAlloc;
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
  LForeignByte: Byte;
begin
  LRecording := TRecordingAlloc.Create;
  LAlloc := LRecording as IAlloc;
  LAllocator := WrapAsAllocator(LAlloc);

  LPtr := LAllocator.AllocAligned(96, 64);
  try
    Check(LPtr <> nil, 'tracked adapter allocation should succeed');
    CheckEqual(Int64(96), Int64(LRecording.LastAllocLayout.Size),
      'tracked adapter allocation should pass requested size');
    CheckEqual(Int64(64), Int64(LRecording.LastAllocLayout.Align),
      'tracked adapter allocation should pass requested alignment');

    LPtr := LAllocator.ReallocMem(LPtr, 160);
    Check(LPtr <> nil, 'tracked adapter realloc should succeed');
    CheckEqual(Int64(1), Int64(LRecording.ReallocCalls),
      'tracked adapter realloc should forward once');
    CheckEqual(Int64(96), Int64(LRecording.LastReallocOldLayout.Size),
      'tracked adapter realloc should preserve old size');
    CheckEqual(Int64(64), Int64(LRecording.LastReallocOldLayout.Align),
      'tracked adapter realloc should preserve old alignment');
    CheckEqual(Int64(160), Int64(LRecording.LastReallocNewLayout.Size),
      'tracked adapter realloc should pass new size');
    CheckEqual(Int64(64), Int64(LRecording.LastReallocNewLayout.Align),
      'tracked adapter realloc should preserve new alignment');

    try
      LAllocator.FreeMem(@LForeignByte);
      Fail('untracked pointer FreeMem should raise');
    except
      on E: EAllocError do
        CheckEqual(Int64(Ord(aeInvalidPointer)), Int64(Ord(E.Error)),
          'untracked pointer FreeMem error code');
    end;
    CheckEqual(Int64(0), Int64(LRecording.DeallocCalls),
      'untracked pointer must not be forwarded to IAlloc.Dealloc');

    try
      LAllocator.ReallocMem(@LForeignByte, 16);
      Fail('untracked pointer ReallocMem should raise');
    except
      on E: EAllocError do
        CheckEqual(Int64(Ord(aeInvalidPointer)), Int64(Ord(E.Error)),
          'untracked pointer ReallocMem error code');
    end;
    CheckEqual(Int64(1), Int64(LRecording.ReallocCalls),
      'untracked pointer must not be forwarded to IAlloc.Realloc');
  finally
    if LPtr <> nil then
      LAllocator.FreeMem(LPtr);
  end;

  CheckEqual(Int64(1), Int64(LRecording.DeallocCalls),
    'tracked adapter free should forward exactly once');
  CheckEqual(Int64(160), Int64(LRecording.LastDeallocLayout.Size),
    'tracked adapter free should pass tracked final size');
  CheckEqual(Int64(64), Int64(LRecording.LastDeallocLayout.Align),
    'tracked adapter free should pass tracked final alignment');
end;

procedure TestMimallocUsableSizeCapabilityFallback;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LTraits: nextpas.core.mem.allocator.base.TAllocatorTraits;
  LPtr: Pointer;
  LSize: SizeUInt;
  LHasSurface: Boolean;
begin
  LAllocator := nextpas.core.mem.allocator.mimalloc.GetMimallocAllocator;
  Check(LAllocator <> nil, 'mimalloc allocator object should be creatable without eager loading');

  LTraits := LAllocator.Traits;
  LHasSurface := nextpas.core.mem.allocator.mimalloc.MimallocUsableSizeAvailable;
  CheckEqual(LHasSurface, LTraits.HasMemSize, 'mimalloc HasMemSize should match mi_malloc_usable_size availability');

  LSize := 123;
  CheckEqual(False, nextpas.core.mem.allocator.mimalloc.TryGetMimallocUsableSize(nil, LSize),
    'nil is not a usable-size query target');
  CheckEqual(Int64(0), Int64(LSize), 'failed usable-size queries should clear the output size');

  if LTraits.HasMemSize then
  begin
    LPtr := LAllocator.GetMem(33);
    try
      Check(LPtr <> nil, 'mimalloc allocation should succeed when usable-size surface is available');
      Check(nextpas.core.mem.allocator.mimalloc.TryGetMimallocUsableSize(LPtr, LSize),
        'usable-size query should succeed for mimalloc-owned blocks when symbol is available');
      Check(LSize >= 33, 'mimalloc usable size should cover the requested allocation size');
    finally
      LAllocator.FreeMem(LPtr);
    end;
  end
  else
  begin
    LPtr := nil;
    try
      try
        LPtr := LAllocator.GetMem(33);
      except
        on E: Exception do
          LPtr := nil;
      end;

      if LPtr <> nil then
      begin
        CheckEqual(False, nextpas.core.mem.allocator.mimalloc.TryGetMimallocUsableSize(LPtr, LSize),
          'fallback should not query usable size when the optional symbol is unavailable');
        CheckEqual(Int64(0), Int64(LSize), 'fallback usable-size query should return size 0');
      end;
    finally
      if LPtr <> nil then
        LAllocator.FreeMem(LPtr);
    end;
  end;
end;

procedure TestMemUtilsNoOpAndOverlapContract;
var
  LBytes: TByteArray;
begin
  Copy(nil, nil, 0);
  CopyNonOverlap(nil, nil, 0);
  Fill8(nil, 0, $7F);
  Zero(nil, 0);

  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;
  LBytes[4] := 5;
  LBytes[5] := 6;

  CheckEqual(False, IsOverlap(nil, 0, @LBytes[0], 4), 'nil block should not overlap');
  CheckEqual(False, IsOverlap(@LBytes[0], 2, @LBytes[2], 2), 'adjacent ranges should not overlap');
  CheckEqual(True, IsOverlap(@LBytes[0], 3, @LBytes[2], 3), 'intersecting ranges should overlap');
end;

procedure TestMemUtilsCopyUncheckedHandlesOverlap;
var
  LBytes: TByteArray;
begin
  LBytes[0] := 1;
  LBytes[1] := 2;
  LBytes[2] := 3;
  LBytes[3] := 4;
  LBytes[4] := 5;
  LBytes[5] := 6;

  CopyUnChecked(@LBytes[0], @LBytes[1], 5);

  CheckEqual(Int64(1), Int64(LBytes[0]), 'copy overlap index 0');
  CheckEqual(Int64(1), Int64(LBytes[1]), 'copy overlap index 1');
  CheckEqual(Int64(2), Int64(LBytes[2]), 'copy overlap index 2');
  CheckEqual(Int64(3), Int64(LBytes[3]), 'copy overlap index 3');
  CheckEqual(Int64(4), Int64(LBytes[4]), 'copy overlap index 4');
  CheckEqual(Int64(5), Int64(LBytes[5]), 'copy overlap index 5');
end;

procedure TestMemUtilsFillAndZeroHelpers;
var
  LBytes: TByteArray;
  LWords: TWordArray;
  LDWords: TDWordArray;
  LQWords: TQWordArray;
  I: Integer;
begin
  Fill8(@LBytes[0], Length(LBytes), $AB);
  for I := Low(LBytes) to High(LBytes) do
    CheckEqual(Int64($AB), Int64(LBytes[I]), 'Fill8 should write the requested byte');

  Fill16(@LWords[0], Length(LWords), $1234);
  for I := Low(LWords) to High(LWords) do
    CheckEqual(Int64($1234), Int64(LWords[I]), 'Fill16 should write the requested word');

  Fill32(@LDWords[0], Length(LDWords), $89ABCDEF);
  for I := Low(LDWords) to High(LDWords) do
    CheckEqual(Int64($89ABCDEF), Int64(LDWords[I]), 'Fill32 should write the requested dword');

  Fill64(@LQWords[0], Length(LQWords), $0123456789ABCDEF);
  for I := Low(LQWords) to High(LQWords) do
    CheckEqual(Int64($0123456789ABCDEF), Int64(LQWords[I]), 'Fill64 should write the requested qword');

  Zero(@LBytes[0], Length(LBytes));
  for I := Low(LBytes) to High(LBytes) do
    CheckEqual(Int64(0), Int64(LBytes[I]), 'Zero should clear each byte');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.contracts');
  T.Run('callback allocator compatibility methods', @TestCallbackAllocatorCompatibilityMethods);
  T.Run('callback allocator supports allocate interface', @TestCallbackAllocatorSupportsAllocateInterface);
  T.Run('rtl allocator zero init traits and aligned alloc', @TestRtlAllocatorZeroInitTraitsAndAlignedAlloc);
  T.Run('rtl allocator aligned alloc rejects size overflow', @TestRtlAllocatorAlignedAllocRejectsSizeOverflow);
  T.Run('aligned compat shim smoke', @TestAlignedCompatShimSmoke);
  T.Run('aligned compat shim delegates to canonical allocator',
    @TestAlignedCompatShimDelegatesToCanonicalAllocator);
  T.Run('mem.compat exports legacy pool surface', @TestMemCompatFacadeExportsLegacyPoolSurface);
  T.Run('mem.compat source contracts', @TestMemCompatFacadeSourceContracts);
  T.Run('canonical allocator surface', @TestCanonicalAllocatorSurface);
  T.Run('allocator aliases are canonical', @TestAllocatorAliasesAreCanonical);
  T.Run('allocator adapter round trip', @TestAllocatorAdapterRoundTrip);
  T.Run('allocator-to-alloc adapter rejects unsupported alignment', @TestAllocatorToAllocAdapterRejectsUnsupportedAlignment);
  T.Run('allocator-to-alloc adapter rejects invalid old layout', @TestAllocatorToAllocAdapterRejectsInvalidOldLayout);
  T.Run('allocator adapter aligned round trip', @TestAllocatorAdapterAlignedRoundTrip);
  T.Run('aligned alloc rejects backing size overflow', @TestAlignedAllocRejectsBackingSizeOverflow);
  T.Run('alloc adapter tracks layouts and rejects untracked pointers', @TestAllocToAllocatorAdapterTracksLayoutsAndRejectsUntrackedPointers);
  T.Run('mimalloc usable-size capability fallback', @TestMimallocUsableSizeCapabilityFallback);
  T.Run('mem.utils no-op and overlap contract', @TestMemUtilsNoOpAndOverlapContract);
  T.Run('mem.utils copy unchecked handles overlap', @TestMemUtilsCopyUncheckedHandlesOverlap);
  T.Run('mem.utils fill and zero helpers', @TestMemUtilsFillAndZeroHelpers);
  T.Summary;
end.
