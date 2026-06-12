program test_mapped_slab_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.mapped_slab_pool,
  nextpas.core.platform.files;

type
  TExceptionProc = procedure;

var
  T: TTestRunner;
  GPool: TMappedSlabPool = nil;
  GManager: TMappedSlabPoolManager = nil;
  GOtherPool: TMappedSlabPool = nil;
  GPtr: Pointer = nil;
  GExternalPtr: Pointer = nil;
  GStackByte: Byte = 0;

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

procedure RaiseDoubleFree;
begin
  GPool.FreeBlock(GPtr);
end;

procedure RaiseExternalPointerFree;
begin
  GPool.FreeBlock(GExternalPtr);
end;

procedure RaiseMisalignedPointerFree;
begin
  GPool.FreeBlock(PByte(GPtr) + 1);
end;

procedure RaiseHeaderPointerFree;
begin
  GPool.FreeBlock(GPool.BaseAddress);
end;

procedure RaiseCrossPoolFree;
begin
  GOtherPool.FreeBlock(GPtr);
end;

procedure RaiseStalePointerFree;
begin
  GPool.FreeBlock(GPtr);
end;

procedure RaiseManagerExternalPointerFree;
begin
  GManager.FreeAny(@GStackByte);
end;

procedure RaiseManagerStoredPointerFree;
begin
  GManager.FreeAny(GExternalPtr);
end;

function RangesOverlap(APtrA: Pointer; ASizeA: SizeUInt; APtrB: Pointer; ASizeB: SizeUInt): Boolean;
var
  LA, LB: PtrUInt;
begin
  LA := PtrUInt(APtrA);
  LB := PtrUInt(APtrB);
  Result := (LA < LB + ASizeB) and (LB < LA + ASizeA);
end;

function MappedSlabPoolTestPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas_mapped_slab_pool_' + IntToStr(GetProcessID) + '.dat';
end;

function MappedSlabPoolSharedName: string;
begin
  Result := 'nextpas_mapped_slab_pool_' + IntToStr(GetProcessID);
end;

procedure RemoveMappedSlabPoolTestFile(const APath: string);
begin
  if APath <> '' then
    platform_file_unlink(PAnsiChar(APath));
end;

procedure CheckMappedSlabPoolTestFileRemoved(const APath: string);
begin
  if APath <> '' then
    Check(platform_file_unlink(PAnsiChar(APath)) = 0, 'remove file-backed pool test file');
end;

procedure TestCreateAnonymous;
var
  LAllocs, LFrees, LFailed: UInt64;
  LUsedPages, LTotalPages: UInt32;
begin
  GPool := TMappedSlabPool.Create;
  try
    Check(GPool.CreateAnonymous(4096, 4096, 256), 'create anonymous pool');
    Check(GPool.IsValid, 'pool should be valid');
    GPool.GetStats(LAllocs, LFrees, LFailed, LUsedPages, LTotalPages);
    CheckEqual(Int64(0), Int64(LAllocs), 'initial alloc count');
    CheckEqual(Int64(0), Int64(LFrees), 'initial free count');
    CheckEqual(Int64(1), Int64(LTotalPages), 'total pages');
  finally
    GPool.Free;
    GPool := nil;
  end;
end;

procedure TestFileBackedCreateOpenUsesExistingMapping;
var
  LPath: string;
  LCreator: TMappedSlabPool;
  LOpener: TMappedSlabPool;
  LRecreator: TMappedSlabPool;
  LPtr: Pointer;
  LAllocs: UInt64;
  LFrees: UInt64;
  LFailed: UInt64;
  LUsedPages: UInt32;
  LTotalPages: UInt32;
begin
  LPath := MappedSlabPoolTestPath;
  LCreator := nil;
  LOpener := nil;
  LRecreator := nil;
  RemoveMappedSlabPoolTestFile(LPath);
  try
    LCreator := TMappedSlabPool.Create;
    Check(LCreator.CreateFile(LPath, 4096, 4096, 256), 'create file-backed pool');
    Check(LCreator.IsCreator, 'first CreateFile creates backing file');
    LPtr := LCreator.Alloc(64);
    Check(LPtr <> nil, 'file-backed allocation');
    LCreator.FreeBlock(LPtr);
    Check(LCreator.Flush, 'flush file-backed pool');
    FreeAndNil(LCreator);

    LOpener := TMappedSlabPool.Create;
    Check(LOpener.OpenFile(LPath), 'OpenFile opens existing backing file');
    Check(not LOpener.IsCreator, 'OpenFile attaches as non-creator');
    LOpener.GetStats(LAllocs, LFrees, LFailed, LUsedPages, LTotalPages);
    CheckEqual(Int64(1), Int64(LAllocs), 'allocation count persisted after OpenFile');
    CheckEqual(Int64(1), Int64(LFrees), 'free count persisted after OpenFile');
    FreeAndNil(LOpener);

    LRecreator := TMappedSlabPool.Create;
    Check(LRecreator.CreateFile(LPath, 4096, 4096, 256), 'CreateFile opens existing backing file');
    Check(not LRecreator.IsCreator, 'second CreateFile must not recreate existing file');
    FreeAndNil(LRecreator);

    LRecreator := TMappedSlabPool.Create;
    Check(LRecreator.CreateFile(LPath, 0, 0, 0),
      'CreateFile existing backing uses persisted header instead of caller shape');
    Check(not LRecreator.IsCreator, 'existing CreateFile with invalid caller shape still attaches');
  finally
    LRecreator.Free;
    LOpener.Free;
    LCreator.Free;
    CheckMappedSlabPoolTestFileRemoved(LPath);
  end;
end;

procedure TestCreateSharedExistingUsesPersistedHeader;
var
  LName: string;
  LCreator: TMappedSlabPool;
  LAttacher: TMappedSlabPool;
begin
  LName := MappedSlabPoolSharedName;
  LCreator := nil;
  LAttacher := nil;
  try
    LCreator := TMappedSlabPool.Create;
    Check(LCreator.CreateShared(LName, 4096, 4096, 256),
      'create shared slab pool');
    Check(LCreator.IsCreator, 'first CreateShared creates shared backing');

    LAttacher := TMappedSlabPool.Create;
    Check(LAttacher.CreateShared(LName, 0, 0, 0),
      'CreateShared existing backing uses persisted header instead of caller shape');
    Check(not LAttacher.IsCreator, 'existing CreateShared attaches as non-creator');
  finally
    LAttacher.Free;
    LCreator.Free;
  end;
end;

procedure TestOpenFileRejectsTruncatedBackingFile;
var
  LPath: string;
  LCreator: TMappedSlabPool;
  LOpener: TMappedSlabPool;
begin
  LPath := MappedSlabPoolTestPath;
  LCreator := nil;
  LOpener := nil;
  RemoveMappedSlabPoolTestFile(LPath);
  try
    LCreator := TMappedSlabPool.Create;
    Check(LCreator.CreateFile(LPath, 4096, 4096, 256),
      'create file-backed slab pool for truncation test');
    FreeAndNil(LCreator);

    CheckEqual(Int64(0), Int64(platform_file_truncate_path(PAnsiChar(LPath), 1024)),
      'truncate backing file below mapped slab pool layout size');

    LOpener := TMappedSlabPool.Create;
    Check(not LOpener.OpenFile(LPath), 'OpenFile rejects a truncated mapped slab pool backing file');
    Check(not LOpener.IsValid, 'failed OpenFile must not leave a valid mapped slab pool');
  finally
    LOpener.Free;
    LCreator.Free;
    CheckMappedSlabPoolTestFileRemoved(LPath);
  end;
end;

procedure TestCreateRejectsInvalidHeaderShape;
begin
  GPool := TMappedSlabPool.Create;
  try
    Check(not GPool.CreateAnonymous(4096, 4096, 0),
      'CreateAnonymous rejects zero max size class');
    Check(not GPool.IsValid, 'failed CreateAnonymous must not leave a valid pool');
  finally
    GPool.Free;
    GPool := nil;
  end;
end;

procedure TestFreeReusesSameSizeBlock;
var
  LP1, LP2: Pointer;
  LAllocs, LFrees, LFailed: UInt64;
  LUsedPages, LTotalPages: UInt32;
begin
  GPool := TMappedSlabPool.Create;
  try
    Check(GPool.CreateAnonymous(4096, 4096, 256), 'create anonymous pool');
    LP1 := GPool.Alloc(64);
    Check(LP1 <> nil, 'first allocation');
    GPool.FreeBlock(LP1);
    LP2 := GPool.Alloc(64);
    Check(LP2 = LP1, 'free should make same-size block reusable');
    GPool.GetStats(LAllocs, LFrees, LFailed, LUsedPages, LTotalPages);
    CheckEqual(Int64(2), Int64(LAllocs), 'alloc count after reuse');
    CheckEqual(Int64(1), Int64(LFrees), 'free count after reuse');
    CheckEqual(Int64(0), Int64(LFailed), 'failed count after reuse');
  finally
    GPool.Free;
    GPool := nil;
  end;
end;

procedure TestMixedSizeAllocationsDoNotOverlap;
var
  LP1, LP2, LP3: Pointer;
begin
  GPool := TMappedSlabPool.Create;
  try
    Check(GPool.CreateAnonymous(16384, 4096, 2048), 'create anonymous pool');
    LP1 := GPool.Alloc(1024);
    LP2 := GPool.Alloc(2048);
    LP3 := GPool.Alloc(2048);
    Check((LP1 <> nil) and (LP2 <> nil) and (LP3 <> nil), 'mixed allocations should succeed');
    Check(not RangesOverlap(LP1, 1024, LP2, 2048), '1024-byte block must not overlap first 2048-byte block');
    Check(not RangesOverlap(LP1, 1024, LP3, 2048), '1024-byte block must not overlap second 2048-byte block');
    Check(not RangesOverlap(LP2, 2048, LP3, 2048), '2048-byte blocks must not overlap');
  finally
    GPool.Free;
    GPool := nil;
  end;
end;

procedure TestInvalidAndDoubleFree;
begin
  GPool := TMappedSlabPool.Create;
  try
    Check(GPool.CreateAnonymous(4096, 4096, 256), 'create anonymous pool');
    GPtr := GPool.Alloc(64);
    Check(GPtr <> nil, 'allocation');
    GPool.FreeBlock(GPtr);
    CheckRaisesAllocError(@RaiseDoubleFree, aeDoubleFree, 'double free');

    GExternalPtr := @GStackByte;
    CheckRaisesAllocError(@RaiseExternalPointerFree, aeInvalidPointer, 'stack pointer');

    GPtr := GPool.Alloc(64);
    Check(GPtr <> nil, 'second allocation');
    CheckRaisesAllocError(@RaiseMisalignedPointerFree, aeInvalidPointer, 'misaligned pointer');
    CheckRaisesAllocError(@RaiseHeaderPointerFree, aeInvalidPointer, 'header pointer');
    GPool.FreeBlock(GPtr);
  finally
    GPool.Free;
    GPool := nil;
    GPtr := nil;
    GExternalPtr := nil;
  end;
end;

procedure TestCrossPoolFree;
begin
  GPool := TMappedSlabPool.Create;
  GOtherPool := TMappedSlabPool.Create;
  try
    Check(GPool.CreateAnonymous(4096, 4096, 256), 'create pool A');
    Check(GOtherPool.CreateAnonymous(4096, 4096, 256), 'create pool B');
    GPtr := GPool.Alloc(64);
    Check(GPtr <> nil, 'allocation from pool A');
    CheckRaisesAllocError(@RaiseCrossPoolFree, aeInvalidPointer, 'cross-pool free');
    GPool.FreeBlock(GPtr);
  finally
    GOtherPool.Free;
    GOtherPool := nil;
    GPool.Free;
    GPool := nil;
    GPtr := nil;
  end;
end;

procedure TestResetInvalidatesOldPointers;
begin
  GPool := TMappedSlabPool.Create;
  try
    Check(GPool.CreateAnonymous(4096, 4096, 256), 'create anonymous pool');
    GPtr := GPool.Alloc(64);
    Check(GPtr <> nil, 'allocation');
    GPool.Reset;
    CheckRaisesAllocError(@RaiseStalePointerFree, aeInvalidPointer, 'stale pointer after reset');
  finally
    GPool.Free;
    GPool := nil;
    GPtr := nil;
  end;
end;

procedure TestManagerAllocAnyLargeFallback;
var
  LManager: TMappedSlabPoolManager;
  LSmall: Pointer;
  LLarge: Pointer;
  LLeakedLarge: Pointer;
begin
  LManager := TMappedSlabPoolManager.Create(mspAnonymous);
  try
    GManager := LManager;
    LSmall := LManager.AllocAny(64);
    Check(LSmall <> nil, 'manager should allocate small slab-backed block');
    PByte(LSmall)^ := $5A;
    LManager.FreeAny(LSmall);

    LLarge := LManager.AllocAny(4096);
    Check(LLarge <> nil, 'manager should allocate size-class overflow through large fallback');
    PByte(LLarge)^ := $A5;
    LManager.FreeAny(LLarge);
    GExternalPtr := LLarge;
    CheckRaisesAllocError(@RaiseManagerStoredPointerFree, aeInvalidPointer,
      'manager fallback double free');

    CheckRaisesAllocError(@RaiseManagerExternalPointerFree, aeInvalidPointer,
      'manager external pointer');

    LLeakedLarge := LManager.AllocAny(4096);
    Check(LLeakedLarge <> nil, 'manager should own unfreed fallback until destroy');
    PByte(LLeakedLarge)^ := $3C;
  finally
    GManager := nil;
    GExternalPtr := nil;
    LManager.Free;
  end;
end;

procedure TestManagerAllocAnySpillsAfterFirstPoolFull;
const
  ALLOCATION_SIZE = 2048;
  FIRST_POOL_2048_BLOCKS = 256;
  SPILL_ALLOCATION_COUNT = FIRST_POOL_2048_BLOCKS + 1;
var
  LManager: TMappedSlabPoolManager;
  LBlocks: array[0..SPILL_ALLOCATION_COUNT - 1] of Pointer;
  LIndex: Integer;
  LAllocs: UInt64;
  LFrees: UInt64;
  LFailed: UInt64;
  LUsedMemory: UInt64;
  LTotalMemory: UInt64;
begin
  FillChar(LBlocks, SizeOf(LBlocks), 0);
  LManager := TMappedSlabPoolManager.Create(mspAnonymous);
  try
    for LIndex := 0 to FIRST_POOL_2048_BLOCKS - 1 do
    begin
      LBlocks[LIndex] := LManager.AllocAny(ALLOCATION_SIZE);
      Check(LBlocks[LIndex] <> nil,
        'manager fills first 2048-byte mapped slab pool #' + IntToStr(LIndex + 1));
    end;

    LBlocks[FIRST_POOL_2048_BLOCKS] := LManager.AllocAny(ALLOCATION_SIZE);
    Check(LBlocks[FIRST_POOL_2048_BLOCKS] <> nil,
      'manager should spill 2048-byte allocation to a later mapped slab pool');

    LManager.GetTotalStats(LAllocs, LFrees, LFailed, LUsedMemory, LTotalMemory);
    CheckEqual(Int64(SPILL_ALLOCATION_COUNT), Int64(LAllocs),
      'manager spill should count successful allocations only');
    CheckEqual(Int64(0), Int64(LFailed),
      'manager spill should not expose internal pool probes as failed allocations');
  finally
    for LIndex := 0 to High(LBlocks) do
      if LBlocks[LIndex] <> nil then
        LManager.FreeAny(LBlocks[LIndex]);
    LManager.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.mapped_slab_pool');
  T.Run('create anonymous', @TestCreateAnonymous);
  T.Run('file-backed create/open uses existing mapping', @TestFileBackedCreateOpenUsesExistingMapping);
  T.Run('shared create/open uses existing mapping', @TestCreateSharedExistingUsesPersistedHeader);
  T.Run('OpenFile rejects truncated backing file', @TestOpenFileRejectsTruncatedBackingFile);
  T.Run('create rejects invalid header shape', @TestCreateRejectsInvalidHeaderShape);
  T.Run('free reuses same-size block', @TestFreeReusesSameSizeBlock);
  T.Run('mixed-size allocations do not overlap', @TestMixedSizeAllocationsDoNotOverlap);
  T.Run('invalid and double free', @TestInvalidAndDoubleFree);
  T.Run('cross-pool free', @TestCrossPoolFree);
  T.Run('reset invalidates old pointers', @TestResetInvalidatesOldPointers);
  T.Run('manager AllocAny large fallback', @TestManagerAllocAnyLargeFallback);
  T.Run('manager AllocAny spills after first pool full', @TestManagerAllocAnySpillsAfterFirstPoolFull);
  T.Summary;
end.
