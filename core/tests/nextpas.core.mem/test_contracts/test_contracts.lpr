program test_contracts;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.mem.intf,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.mimalloc,
  nextpas.core.platform.mmap;

const
  MEM_BASE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.base.pas';
  MEM_BASE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.base.pas';
  MEM_ARENA_CONCURRENT_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.arena.concurrent.pas';
  MEM_ARENA_CONCURRENT_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.arena.concurrent.pas';
  MEM_ARENA_CHUNKED_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.arena.chunked.pas';
  MEM_ARENA_CHUNKED_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.arena.chunked.pas';
  MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.arena.virtual.pas';
  MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.arena.virtual.pas';
  MEM_ARENA_GROWABLE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.arena.growable.pas';
  MEM_ARENA_GROWABLE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.arena.growable.pas';
  MEM_ALLOCATOR_CALLBACK_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.allocator.callback.pas';
  MEM_ALLOCATOR_CALLBACK_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.allocator.callback.pas';
  MEM_ALIGNED_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.aligned.pas';
  MEM_ALIGNED_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.aligned.pas';
  MEM_ALLOCATOR_INSTRUMENTATION_SOURCE_PATH_FROM_TEST =
    '../../../src/nextpas.core.mem.allocator.instrumentation.pas';
  MEM_ALLOCATOR_INSTRUMENTATION_SOURCE_PATH_FROM_ROOT =
    'core/src/nextpas.core.mem.allocator.instrumentation.pas';
  MEM_ALLOCATOR_NUMA_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.allocator.numa.pas';
  MEM_ALLOCATOR_NUMA_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.allocator.numa.pas';
  MEM_BLOCKPOOL_GROWABLE_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.blockpool.growable.pas';
  MEM_BLOCKPOOL_GROWABLE_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.blockpool.growable.pas';
  MEM_ADAPTERS_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.adapters.pas';
  MEM_ADAPTERS_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.adapters.pas';
  MEM_ERROR_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.error.pas';
  MEM_ERROR_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.error.pas';
  MEM_ALLOC_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.alloc.pas';
  MEM_ALLOC_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.alloc.pas';
  MEM_ADAPTER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.adapter.pas';
  MEM_ADAPTER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.adapter.pas';
  MEM_INTERFACES_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.interfaces.pas';
  MEM_INTERFACES_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.interfaces.pas';
  MEM_POOL_ADAPTER_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.pool.adapter.pas';
  MEM_POOL_ADAPTER_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.pool.adapter.pas';
  MEM_LAYOUT_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.layout.pas';
  MEM_LAYOUT_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.layout.pas';
  MEM_MANAGER_MIMALLOC_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.manager.mimalloc.pas';
  MEM_MANAGER_MIMALLOC_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.manager.mimalloc.pas';
  MEM_MIMALLOC_BINDING_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.mimalloc.binding.pas';
  MEM_MIMALLOC_BINDING_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.mimalloc.binding.pas';
  MEM_MUTEX_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.mutex.pas';
  MEM_MUTEX_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.mutex.pas';
  MEM_RWLOCK_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.rwlock.pas';
  MEM_RWLOCK_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.rwlock.pas';
  MEM_STACK_SCOPE_HELPERS_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.stack_scope_helpers.pas';
  MEM_STACK_SCOPE_HELPERS_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.stack_scope_helpers.pas';
  MEM_STATS_SOURCE_PATH_FROM_TEST = '../../../src/nextpas.core.mem.stats.pas';
  MEM_STATS_SOURCE_PATH_FROM_ROOT = 'core/src/nextpas.core.mem.stats.pas';

type
  TByteArray = array[0..5] of Byte;
  TWordArray = array[0..3] of Word;
  TDWordArray = array[0..2] of UInt32;
  TQWordArray = array[0..1] of UInt64;

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
  if FileExistsByStat(PAnsiChar(APathFromTest)) then
    Exit(APathFromTest);
  if FileExistsByStat(PAnsiChar(APathFromRoot)) then
    Exit(APathFromRoot);
  Result := APathFromTest;
end;

function SourceExists(const APathFromTest, APathFromRoot: string): Boolean;
begin
  Result := FileExistsByStat(PAnsiChar(APathFromTest)) or FileExistsByStat(PAnsiChar(APathFromRoot));
end;

function ExtractSourceSection(const ASource, AStartToken, AEndToken: string): string;
var
  LStartPos: SizeInt;
  LEndPos: SizeInt;
begin
  Result := '';
  LStartPos := Pos(LowerCase(AStartToken), ASource);
  if LStartPos = 0 then
    Exit;
  LEndPos := Pos(LowerCase(AEndToken), ASource);
  if (LEndPos = 0) or (LEndPos <= LStartPos) then
    LEndPos := Length(ASource) + 1;
  Result := System.Copy(ASource, LStartPos, LEndPos - LStartPos);
end;

procedure CheckContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) > 0, AMessage + ': ' + AToken);
end;

procedure CheckNotContains(const ASource, AToken, AMessage: string);
begin
  Check(Pos(LowerCase(AToken), ASource) = 0, AMessage + ': ' + AToken);
end;

procedure CheckContainsAtomicCAS(const ASource: string; const AMessage: string);
begin
  Check((Pos('interlockedcompareexchange', ASource) > 0) or
    (Pos('atomic_compare_exchange', ASource) > 0),
    AMessage);
end;

procedure CheckContainsAtomicAdd64(const ASource: string; const AMessage: string);
begin
  Check((Pos('interlockedexchangeadd64', ASource) > 0) or
    (Pos('atomic_fetch_add_64', ASource) > 0),
    AMessage);
end;

procedure CheckContainsAtomicCAS64(const ASource: string; const AMessage: string);
begin
  Check((Pos('interlockedcompareexchange64', ASource) > 0) or
    (Pos('atomic_compare_exchange_strong_64', ASource) > 0) or
    (Pos('atomic_compare_exchange_64', ASource) > 0),
    AMessage);
end;

procedure ResetAllocatorCounters;
begin
  GGetMemCalls := 0;
  GAllocMemCalls := 0;
  GReallocMemCalls := 0;
  GFreeMemCalls := 0;
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

procedure TestCallbackAllocatorSupportsCanonicalInterface;
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

  LPtr := LAllocator.GetMem(24);
  Check(LPtr <> nil, 'GetMem should delegate to the compatibility allocator');
  CheckEqual(Int64(1), Int64(GGetMemCalls), 'GetMem should route through GetMem');

  PByte(LPtr)^ := $33;
  LPtr := LAllocator.ReallocMem(LPtr, 48);
  Check(LPtr <> nil, 'ReallocMem should return a pointer');
  CheckEqual(Int64(1), Int64(GReallocMemCalls), 'ReallocMem should route through ReallocMem');
  CheckEqual(Int64($33), Int64(PByte(LPtr)^), 'ReallocMem should preserve the prefix');

  LAllocator.FreeMem(LPtr);
  CheckEqual(Int64(1), Int64(GFreeMemCalls), 'FreeMem should route through FreeMem');
end;

procedure ExpectNilCallbackRejected(const AName: string;
  AGetMem: TGetMemCallback;
  AAllocMem: TAllocMemCallback;
  AReallocMem: TReallocMemCallback;
  AFreeMem: TFreeMemCallback);
var
  LRaised: Boolean;
  LAllocator: nextpas.core.mem.allocator.IAllocator;
begin
  LRaised := False;
  LAllocator := nil;
  try
    LAllocator := CreateCallbackAllocator(AGetMem, AAllocMem, AReallocMem, AFreeMem);
  except
    on E: nextpas.core.base.EArgumentNil do
      LRaised := True;
    on E: Exception do
      Fail(AName + ': expected EArgumentNil, got ' + E.ClassName + ': ' + E.Message);
  end;

  Check(LRaised, AName + ': nil callback should be rejected');
  Check(LAllocator = nil, AName + ': allocator should not be created');
end;

procedure TestCallbackAllocatorRejectsNilCallbacksAtRuntime;
begin
  ExpectNilCallbackRejected('nil GetMem callback',
    nil,
    @CallbackAllocMem,
    @CallbackReallocMem,
    @CallbackFreeMem);
  ExpectNilCallbackRejected('nil AllocMem callback',
    @CallbackGetMem,
    nil,
    @CallbackReallocMem,
    @CallbackFreeMem);
  ExpectNilCallbackRejected('nil ReallocMem callback',
    @CallbackGetMem,
    @CallbackAllocMem,
    nil,
    @CallbackFreeMem);
  ExpectNilCallbackRejected('nil FreeMem callback',
    @CallbackGetMem,
    @CallbackAllocMem,
    @CallbackReallocMem,
    nil);
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

procedure TestChunkedArenaAndGrowableBlockPoolUseCanonicalAllocatorContract;
var
  LArenaSource: string;
  LBlockPoolSource: string;
begin
  LArenaSource := ReadSourceText(ResolveSourcePath(
    MEM_ARENA_CHUNKED_SOURCE_PATH_FROM_TEST,
    MEM_ARENA_CHUNKED_SOURCE_PATH_FROM_ROOT));
  CheckContains(LArenaSource, 'nextpas.core.mem.intf',
    'chunked arena should depend on the canonical allocator contract');
  CheckNotContains(LArenaSource, 'nextpas.core.mem.alloc',
    'chunked arena should not depend on the removed legacy allocator contract');
  CheckNotContains(LArenaSource, 'nextpas.core.mem.layout',
    'chunked arena should not depend on the removed layout unit');
  CheckContains(LArenaSource, 'allocator: iallocator',
    'chunked arena config should expose iallocator');
  CheckContains(LArenaSource, 'fallocator: iallocator',
    'chunked arena field should store iallocator');
  CheckContains(LArenaSource, 'function alloc(asize: sizeuint): pointer;',
    'chunked arena should expose explicit-size allocation');
  CheckContains(LArenaSource, 'function allocaligned(asize, aalignment: sizeuint): pointer;',
    'chunked arena should expose explicit aligned allocation');
  CheckContains(LArenaSource, 'lraw := fallocator.getmem(lallocsize);',
    'chunked arena should allocate segments via iallocator.getmem');
  CheckContains(LArenaSource, 'fallocator.freemem(lraw)',
    'chunked arena should release segments via iallocator.freemem');

  LBlockPoolSource := ReadSourceText(ResolveSourcePath(
    MEM_BLOCKPOOL_GROWABLE_SOURCE_PATH_FROM_TEST,
    MEM_BLOCKPOOL_GROWABLE_SOURCE_PATH_FROM_ROOT));
  CheckContains(LBlockPoolSource, 'nextpas.core.mem.intf',
    'growable block pool should depend on the canonical allocator contract');
  CheckNotContains(LBlockPoolSource, 'nextpas.core.mem.alloc',
    'growable block pool should not depend on the removed legacy allocator contract');
  CheckNotContains(LBlockPoolSource, 'nextpas.core.mem.layout',
    'growable block pool should not depend on the removed layout unit');
  CheckContains(LBlockPoolSource, 'allocator: iallocator',
    'growable block pool config should expose iallocator');
  CheckContains(LBlockPoolSource, 'fallocator: iallocator',
    'growable block pool field should store iallocator');
  CheckContains(LBlockPoolSource, 'lraw := fallocator.getmem(lallocsize);',
    'growable block pool should allocate segments via iallocator.getmem');
  CheckContains(LBlockPoolSource, 'fallocator.freemem(lraw)',
    'growable block pool should release segments via iallocator.freemem');
end;

procedure TestArenaUnitsUseExplicitArenaApi;
var
  LConcurrentSource: string;
begin
  LConcurrentSource := ReadSourceText(ResolveSourcePath(
    MEM_ARENA_CONCURRENT_SOURCE_PATH_FROM_TEST,
    MEM_ARENA_CONCURRENT_SOURCE_PATH_FROM_ROOT));
  CheckContains(LConcurrentSource, 'function alloc(asize: sizeuint): pointer;',
    'concurrent arena wrapper should expose explicit-size allocation');
  CheckContains(LConcurrentSource, 'function allocaligned(asize, aalignment: sizeuint): pointer;',
    'concurrent arena wrapper should expose explicit aligned allocation');
  CheckContains(LConcurrentSource, 'function alloczeroed(asize: sizeuint): pointer;',
    'concurrent arena wrapper should expose explicit zeroed allocation');
  CheckNotContains(LConcurrentSource, 'nextpas.core.mem.layout',
    'concurrent arena wrapper should not depend on the removed layout unit');
end;

procedure TestCallbackAllocatorRejectsNilCallbacksWithoutContractGuard;
var
  LSource: string;
  LSection: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_ALLOCATOR_CALLBACK_SOURCE_PATH_FROM_TEST,
    MEM_ALLOCATOR_CALLBACK_SOURCE_PATH_FROM_ROOT));
  LSection := ExtractSourceSection(LSource,
    'constructor tcallbackallocator.init',
    'fgetmemcallback     := agetmem;');
  Check(LSection <> '', 'callback allocator constructor section should be readable');
  CheckContains(LSection, 'raise eargumentnil.create',
    'callback allocator should reject nil callbacks');
  CheckNotContains(LSection, '{$ifdef nextpas_core_contracts}',
    'callback allocator nil-check should not depend on contract define');
  CheckNotContains(LSection, '{$endif}',
    'callback allocator nil-check should not be wrapped by conditional compilation');
end;

procedure TestMimallocManagerUsesInstallationLock;
var
  LSource: string;
  LInstallSection: string;
  LUninstallSection: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_MANAGER_MIMALLOC_SOURCE_PATH_FROM_TEST,
    MEM_MANAGER_MIMALLOC_SOURCE_PATH_FROM_ROOT));
  CheckContains(LSource, 'gmanagerlock: tmemmutex;',
    'mimalloc manager should define a manager lock');
  CheckContains(LSource, 'initialization',
    'mimalloc manager should initialize the manager lock');
  CheckContains(LSource, 'gmanagerlock.init;',
    'mimalloc manager should initialize the manager lock');
  CheckContains(LSource, 'finalization',
    'mimalloc manager should finalize the manager lock');
  CheckContains(LSource, 'gmanagerlock.done;',
    'mimalloc manager should finalize the manager lock');

  LInstallSection := ExtractSourceSection(LSource,
    'procedure installmimallocmemorymanager;' + #10 + 'begin',
    'procedure uninstallmimallocmemorymanager;');
  Check(LInstallSection <> '', 'mimalloc manager install section should be readable');
  CheckContains(LInstallSection, 'gmanagerlock.acquire;',
    'mimalloc manager install should acquire the manager lock');
  CheckContains(LInstallSection, 'gmanagerlock.release;',
    'mimalloc manager install should release the manager lock');

  LUninstallSection := ExtractSourceSection(LSource,
    'procedure uninstallmimallocmemorymanager;' + #10 + 'begin',
    'function ismimallocmemorymanagerinstalled: boolean;');
  Check(LUninstallSection <> '', 'mimalloc manager uninstall section should be readable');
  CheckContains(LUninstallSection, 'gmanagerlock.acquire;',
    'mimalloc manager uninstall should acquire the manager lock');
  CheckContains(LUninstallSection, 'gmanagerlock.release;',
    'mimalloc manager uninstall should release the manager lock');
end;

procedure TestVirtualArenaAllocNoPointerGuardsAgainstBackUnderflow;
var
  LSource: string;
  LSection: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_TEST,
    MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_ROOT));
  LSection := ExtractSourceSection(LSource,
    'function tvirtualarena.allocnopointer(asize: sizeuint): pointer;',
    'function tvirtualarena.allocaligned');
  Check(LSection <> '', 'virtual arena AllocNoPointer section should be readable');
  CheckContains(LSection, 'if ptruint(asize) > (ptruint(fbackptr) - ptruint(fbackbase)) then',
    'AllocNoPointer should guard against back-pointer underflow with remaining back capacity');
  CheckNotContains(LSection, 'if ptruint(asize) > ptruint(fbackptr) then',
    'AllocNoPointer should not compare requested size against the absolute back pointer');
end;

procedure TestLegacyAllocatorFilesRemoved;
begin
  Check(not SourceExists(MEM_ARENA_GROWABLE_SOURCE_PATH_FROM_TEST, MEM_ARENA_GROWABLE_SOURCE_PATH_FROM_ROOT),
    'mem.arena.growable should be removed');
  Check(not SourceExists(MEM_ALLOC_SOURCE_PATH_FROM_TEST, MEM_ALLOC_SOURCE_PATH_FROM_ROOT),
    'mem.alloc should be removed');
  Check(not SourceExists(MEM_ADAPTER_SOURCE_PATH_FROM_TEST, MEM_ADAPTER_SOURCE_PATH_FROM_ROOT),
    'mem.adapter should be removed');
  Check(not SourceExists(MEM_POOL_ADAPTER_SOURCE_PATH_FROM_TEST, MEM_POOL_ADAPTER_SOURCE_PATH_FROM_ROOT),
    'mem.pool.adapter should be removed');
  Check(not SourceExists(MEM_LAYOUT_SOURCE_PATH_FROM_TEST, MEM_LAYOUT_SOURCE_PATH_FROM_ROOT),
    'mem.layout should be removed');
  Check(not SourceExists(MEM_MIMALLOC_BINDING_SOURCE_PATH_FROM_TEST, MEM_MIMALLOC_BINDING_SOURCE_PATH_FROM_ROOT),
    'mem.mimalloc.binding should be removed');
end;

procedure TestZeroConsumerCompatibilityUnitsRemoved;
begin
  Check(not SourceExists(MEM_ALIGNED_SOURCE_PATH_FROM_TEST, MEM_ALIGNED_SOURCE_PATH_FROM_ROOT),
    'mem.aligned should be removed');
  Check(not SourceExists(MEM_ALLOCATOR_INSTRUMENTATION_SOURCE_PATH_FROM_TEST,
    MEM_ALLOCATOR_INSTRUMENTATION_SOURCE_PATH_FROM_ROOT),
    'mem.allocator.instrumentation should be removed');
  Check(not SourceExists(MEM_ALLOCATOR_NUMA_SOURCE_PATH_FROM_TEST, MEM_ALLOCATOR_NUMA_SOURCE_PATH_FROM_ROOT),
    'mem.allocator.numa should be removed');
  Check(not SourceExists(MEM_STATS_SOURCE_PATH_FROM_TEST, MEM_STATS_SOURCE_PATH_FROM_ROOT),
    'mem.stats should be removed');
  Check(not SourceExists(MEM_ADAPTERS_SOURCE_PATH_FROM_TEST, MEM_ADAPTERS_SOURCE_PATH_FROM_ROOT),
    'mem.adapters should be removed');
  Check(not SourceExists(MEM_INTERFACES_SOURCE_PATH_FROM_TEST, MEM_INTERFACES_SOURCE_PATH_FROM_ROOT),
    'mem.interfaces should be removed');
  Check(not SourceExists(MEM_STACK_SCOPE_HELPERS_SOURCE_PATH_FROM_TEST,
    MEM_STACK_SCOPE_HELPERS_SOURCE_PATH_FROM_ROOT),
    'mem.stack_scope_helpers should be removed');
  Check(SourceExists(MEM_MANAGER_MIMALLOC_SOURCE_PATH_FROM_TEST, MEM_MANAGER_MIMALLOC_SOURCE_PATH_FROM_ROOT),
    'mem.manager.mimalloc should remain available');
end;

procedure TestBaseOwnsMemConstantsAndErrorDropsAllocResult;
var
  LBaseSource: string;
  LErrorSource: string;
begin
  LBaseSource := ReadSourceText(ResolveSourcePath(
    MEM_BASE_SOURCE_PATH_FROM_TEST,
    MEM_BASE_SOURCE_PATH_FROM_ROOT));
  CheckContains(LBaseSource, 'mem_default_align',
    'mem.base should own MEM_DEFAULT_ALIGN');
  CheckContains(LBaseSource, 'mem_cache_line_size',
    'mem.base should own MEM_CACHE_LINE_SIZE');
  CheckContains(LBaseSource, 'mem_page_size',
    'mem.base should own MEM_PAGE_SIZE');

  LErrorSource := ReadSourceText(ResolveSourcePath(
    MEM_ERROR_SOURCE_PATH_FROM_TEST,
    MEM_ERROR_SOURCE_PATH_FROM_ROOT));
  CheckNotContains(LErrorSource, 'tallocresult',
    'mem.error should drop TAllocResult');
  CheckNotContains(LErrorSource, 'expectptr',
    'mem.error should drop TAllocResult.ExpectPtr');
end;

procedure TestMemLockWrappersUseAtomicInitState;
var
  LMutexSource: string;
  LMutexInitSection: string;
  LMutexDoneSection: string;
  LRwLockSource: string;
  LRwLockInitSection: string;
  LRwLockDoneSection: string;
begin
  LMutexSource := ReadSourceText(ResolveSourcePath(
    MEM_MUTEX_SOURCE_PATH_FROM_TEST,
    MEM_MUTEX_SOURCE_PATH_FROM_ROOT));
  CheckNotContains(LMutexSource, 'finitialized: boolean;',
    'mem.mutex should not use a Boolean initialization flag');
  LMutexInitSection := ExtractSourceSection(LMutexSource,
    'procedure tmemmutex.init;',
    'procedure tmemmutex.done;');
  Check(LMutexInitSection <> '', 'mem.mutex init section should be readable');
  CheckContainsAtomicCAS(LMutexInitSection,
    'mem.mutex Init should use an atomic once-only state transition');
  LMutexDoneSection := ExtractSourceSection(LMutexSource,
    'procedure tmemmutex.done;',
    'procedure tmemmutex.acquire;');
  Check(LMutexDoneSection <> '', 'mem.mutex done section should be readable');
  CheckContainsAtomicCAS(LMutexDoneSection,
    'mem.mutex Done should use an atomic state transition');

  LRwLockSource := ReadSourceText(ResolveSourcePath(
    MEM_RWLOCK_SOURCE_PATH_FROM_TEST,
    MEM_RWLOCK_SOURCE_PATH_FROM_ROOT));
  CheckNotContains(LRwLockSource, 'finitialized: boolean;',
    'mem.rwlock should not use a Boolean initialization flag');
  LRwLockInitSection := ExtractSourceSection(LRwLockSource,
    'procedure tmemrwlock.init;',
    'procedure tmemrwlock.done;');
  Check(LRwLockInitSection <> '', 'mem.rwlock init section should be readable');
  CheckContainsAtomicCAS(LRwLockInitSection,
    'mem.rwlock Init should use an atomic once-only state transition');
  LRwLockDoneSection := ExtractSourceSection(LRwLockSource,
    'procedure tmemrwlock.done;',
    'procedure tmemrwlock.acquireread;');
  Check(LRwLockDoneSection <> '', 'mem.rwlock done section should be readable');
  CheckContainsAtomicCAS(LRwLockDoneSection,
    'mem.rwlock Done should use an atomic state transition');
end;

procedure TestVirtualArenaDocumentsLargeObjectMarkSemantics;
var
  LSource: string;
  LInterfaceSection: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_TEST,
    MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_ROOT));
  LInterfaceSection := ExtractSourceSection(LSource,
    'function savemark: tarenamark;',
    'procedure reset;');
  Check(LInterfaceSection <> '', 'virtual arena SaveMark/RestoreToMark section should be readable');
  CheckContains(LInterfaceSection, 'large objects',
    'virtual arena SaveMark/RestoreToMark should document large-object persistence');
  CheckContains(LInterfaceSection, 'not rewound',
    'virtual arena SaveMark/RestoreToMark should explain that large objects are not rewound');
end;

procedure TestVirtualArenaExposesFailureReasonAndAtomicMappedCounter;
var
  LSource: string;
  LAllocSection: string;
begin
  LSource := ReadSourceText(ResolveSourcePath(
    MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_TEST,
    MEM_ARENA_VIRTUAL_SOURCE_PATH_FROM_ROOT));
  CheckContains(LSource, 'tvirtualarenaallocfailure = (',
    'virtual arena should define a typed allocation failure classification');
  CheckContains(LSource, 'function lastallocfailure: tvirtualarenaallocfailure;',
    'virtual arena should expose the last allocation failure reason');
  CheckContains(LSource, 'vaafcapacityexhausted',
    'virtual arena failure classification should expose capacity exhaustion');
  CheckContains(LSource, 'vaaffrontcommitfailed',
    'virtual arena failure classification should expose front commit failure');
  CheckContains(LSource, 'vaafbackcommitfailed',
    'virtual arena failure classification should expose back commit failure');
  CheckContains(LSource, 'vaaflargeobjectmapfailed',
    'virtual arena failure classification should expose large-object mmap failure');

  LAllocSection := ExtractSourceSection(LSource,
    'function tvirtualarena.alloc(asize: sizeuint): pointer;',
    'function tvirtualarena.allocnopointer');
  Check(LAllocSection <> '', 'virtual arena Alloc section should be readable');
  CheckContains(LAllocSection, 'flastallocfailure := vaafcapacityexhausted;',
    'virtual arena Alloc should classify capacity exhaustion');
  CheckContains(LAllocSection, 'flastallocfailure := vaaffrontcommitfailed;',
    'virtual arena Alloc should classify front commit failure');
  CheckContains(LAllocSection, 'flastallocfailure := vaaflargeobjectmapfailed;',
    'virtual arena Alloc should classify large-object mmap failure');

  CheckNotContains(LSource, 'inc(garenatotalmapped',
    'virtual arena leak counter should not use plain Inc');
  CheckNotContains(LSource, 'dec(garenatotalmapped',
    'virtual arena leak counter should not use plain Dec');
  CheckContainsAtomicAdd64(LSource,
    'virtual arena leak counter should use an atomic 64-bit add');
  CheckContainsAtomicCAS64(LSource,
    'virtual arena leak counter should use an atomic 64-bit compare-and-swap for bounded subtract');
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

procedure TestMimallocUsableSizeCapabilityFallback;
var
  LAllocator: nextpas.core.mem.allocator.IAllocator;
  LPtr: Pointer;
  LSize: SizeUInt;
begin
  if not nextpas.core.mem.allocator.mimalloc.TryGetMimallocAllocator(LAllocator) then
  begin
    LAllocator := GetRtlAllocator;
    LSize := 0;
    LPtr := nil;
    try
      try
        LPtr := LAllocator.GetMem(33);
      except
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
  T.Run('callback allocator supports canonical interface', @TestCallbackAllocatorSupportsCanonicalInterface);
  T.Run('callback allocator rejects nil callbacks at runtime',
    @TestCallbackAllocatorRejectsNilCallbacksAtRuntime);
  T.Run('rtl allocator zero init traits and aligned alloc', @TestRtlAllocatorZeroInitTraitsAndAlignedAlloc);
  T.Run('rtl allocator aligned alloc rejects size overflow', @TestRtlAllocatorAlignedAllocRejectsSizeOverflow);
  T.Run('chunked arena and growable block pool use canonical allocator contract',
    @TestChunkedArenaAndGrowableBlockPoolUseCanonicalAllocatorContract);
  T.Run('arena units use explicit arena api', @TestArenaUnitsUseExplicitArenaApi);
  T.Run('callback allocator rejects nil callbacks without contract guard',
    @TestCallbackAllocatorRejectsNilCallbacksWithoutContractGuard);
  T.Run('mimalloc manager uses installation lock', @TestMimallocManagerUsesInstallationLock);
  T.Run('virtual arena AllocNoPointer guards against back underflow',
    @TestVirtualArenaAllocNoPointerGuardsAgainstBackUnderflow);
  T.Run('legacy allocator files removed', @TestLegacyAllocatorFilesRemoved);
  T.Run('zero-consumer compatibility units removed', @TestZeroConsumerCompatibilityUnitsRemoved);
  T.Run('mem.base owns constants and mem.error drops alloc result',
    @TestBaseOwnsMemConstantsAndErrorDropsAllocResult);
  T.Run('mem lock wrappers use atomic init state',
    @TestMemLockWrappersUseAtomicInitState);
  T.Run('virtual arena documents large-object mark semantics',
    @TestVirtualArenaDocumentsLargeObjectMarkSemantics);
  T.Run('virtual arena exposes failure reason and atomic mapped counter',
    @TestVirtualArenaExposesFailureReasonAndAtomicMappedCounter);
  T.Run('canonical allocator surface', @TestCanonicalAllocatorSurface);
  T.Run('allocator aliases are canonical', @TestAllocatorAliasesAreCanonical);
  T.Run('mimalloc usable-size capability fallback', @TestMimallocUsableSizeCapabilityFallback);
  T.Run('mem.utils no-op and overlap contract', @TestMemUtilsNoOpAndOverlapContract);
  T.Run('mem.utils copy unchecked handles overlap', @TestMemUtilsCopyUncheckedHandlesOverlap);
  T.Run('mem.utils fill and zero helpers', @TestMemUtilsFillAndZeroHelpers);
  T.Summary;
end.
