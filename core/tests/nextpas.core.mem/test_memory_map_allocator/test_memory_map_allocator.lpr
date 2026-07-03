program test_memory_map_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.mmap;

type
  TExceptionProc = procedure;

var
  T: TTestSuite;
  GAllocator: IAllocator = nil;
  GPtr: Pointer = nil;
  GForeignPtr: Pointer = nil;
  GStackByte: Byte = 0;

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

procedure RaiseDoubleFree;
begin
  GAllocator.FreeMem(GPtr);
end;

procedure RaiseForeignPointerFree;
begin
  GAllocator.FreeMem(GForeignPtr);
end;

procedure RaiseInteriorPointerFree;
begin
  GAllocator.FreeMem(PByte(GPtr) + 1);
end;

function RangesOverlap(APtrA: Pointer; ASizeA: SizeUInt; APtrB: Pointer; ASizeB: SizeUInt): Boolean;
var
  LA, LB: PtrUInt;
begin
  LA := PtrUInt(APtrA);
  LB := PtrUInt(APtrB);
  Result := (LA < LB + ASizeB) and (LB < LA + ASizeA);
end;

procedure TestAnonymousAllocatorTraitsAndZeroing;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
  LIndex: Integer;
begin
  LAllocator := CreateAnonymousMemoryMapAllocator(4096);
  Check(LAllocator <> nil, 'anonymous memory-map allocator should be created');
  Check(LAllocator.Traits.ThreadSafe, 'memory-map allocator should serialize access');
  Check(True = LAllocator.Traits.ZeroInitialized, 'AllocMem should promise zeroing');

  LPtr := LAllocator.AllocMem(64);
  try
    Check(LPtr <> nil, 'AllocMem should allocate');
    for LIndex := 0 to 63 do
      Check(Int64(0) = Int64(PByte(LPtr)[LIndex]), 'AllocMem should zero each byte');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;

procedure TestReallocPreservesPrefix;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
begin
  LAllocator := CreateAnonymousMemoryMapAllocator(4096);
  LPtr := LAllocator.GetMem(32);
  Check(LPtr <> nil, 'initial allocation');
  PByte(LPtr)^ := $6B;

  LPtr := LAllocator.ReallocMem(LPtr, 96);
  try
    Check(LPtr <> nil, 'reallocation should succeed');
    Check(Int64($6B) = Int64(PByte(LPtr)^), 'reallocation should preserve prefix');
  finally
    LAllocator.FreeMem(LPtr);
  end;
end;

procedure TestMultipleBlocksDoNotAliasAndCanReuse;
var
  LAllocator: IAllocator;
  LFirst: Pointer;
  LSecond: Pointer;
  LReused: Pointer;
begin
  LAllocator := CreateAnonymousMemoryMapAllocator(4096);
  LFirst := LAllocator.GetMem(128);
  LSecond := LAllocator.GetMem(128);
  LReused := nil;
  try
    Check((LFirst <> nil) and (LSecond <> nil), 'two allocations should succeed');
    Check(not RangesOverlap(LFirst, 128, LSecond, 128), 'separate allocations should not overlap');
    LAllocator.FreeMem(LFirst);
    LFirst := nil;
    LReused := LAllocator.GetMem(64);
    Check(LReused <> nil, 'freed memory should be reusable');
  finally
    if LFirst <> nil then
      LAllocator.FreeMem(LFirst);
    if LReused <> nil then
      LAllocator.FreeMem(LReused);
    if LSecond <> nil then
      LAllocator.FreeMem(LSecond);
  end;
end;

procedure TestInvalidAndDoubleFree;
begin
  GAllocator := CreateAnonymousMemoryMapAllocator(4096);
  try
    GPtr := GAllocator.GetMem(64);
    Check(GPtr <> nil, 'allocation for invalid-free tests');
    GAllocator.FreeMem(GPtr);
    CheckRaisesAllocError(@RaiseDoubleFree, aeDoubleFree, 'double free');

    GForeignPtr := @GStackByte;
    CheckRaisesAllocError(@RaiseForeignPointerFree, aeInvalidPointer, 'foreign pointer');

    GPtr := GAllocator.GetMem(64);
    Check(GPtr <> nil, 'allocation for interior pointer test');
    CheckRaisesAllocError(@RaiseInteriorPointerFree, aeInvalidPointer, 'interior pointer');
    GAllocator.FreeMem(GPtr);
  finally
    GAllocator := nil;
    GPtr := nil;
    GForeignPtr := nil;
  end;
end;

procedure TestCapacityExhaustionReturnsNil;
var
  LAllocator: IAllocator;
  LPtr: Pointer;
begin
  LAllocator := CreateAnonymousMemoryMapAllocator(512);
  LPtr := LAllocator.GetMem(4096);
  Check(LPtr = nil, 'oversized request should fail without falling back to heap');
end;

procedure TestCoalescingMergesAdjacentBlocks;
var
  LAllocator: IAllocator;
  LA, LB, LC, LD: Pointer;
  LX: Pointer;
begin
  LAllocator := CreateAnonymousMemoryMapAllocator(128 * 1024);
  try
    { Allocate 4 consecutive blocks. }
    LA := LAllocator.GetMem(128);
    LB := LAllocator.GetMem(128);
    LC := LAllocator.GetMem(128);
    LD := LAllocator.GetMem(128);
    Check(LA <> nil, 'coalesce: A should allocate');
    Check(LB <> nil, 'coalesce: B should allocate');
    Check(LC <> nil, 'coalesce: C should allocate');
    Check(LD <> nil, 'coalesce: D should allocate');

    { Free B and D (non-adjacent free blocks). }
    LAllocator.FreeMem(LB);
    LAllocator.FreeMem(LD);
    LB := nil;
    LD := nil;

    { Free A — adjacent to freed B; must merge into one large free block. }
    LAllocator.FreeMem(LA);
    LA := nil;

    { Allocate 200 bytes: larger than one original block, fits in merged A+B. }
    LX := LAllocator.GetMem(200);
    Check(LX <> nil, 'coalesce: merged A+B should satisfy 200-byte alloc');

    { Release everything. After coalescing, the entire region should merge. }
    LAllocator.FreeMem(LX);
    LAllocator.FreeMem(LC);
    LX := nil;
    LC := nil;

    { 400 bytes spans multiple original blocks — only possible if coalescing works. }
    LX := LAllocator.GetMem(400);
    Check(LX <> nil, 'coalesce: fully coalesced region should satisfy 400-byte alloc');
    LAllocator.FreeMem(LX);
  finally
    LAllocator := nil;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.memory_map_allocator');
  T.Test('anonymous traits and zeroing', @TestAnonymousAllocatorTraitsAndZeroing);
  T.Test('realloc preserves prefix', @TestReallocPreservesPrefix);
  T.Test('multiple blocks do not alias and can reuse', @TestMultipleBlocksDoNotAliasAndCanReuse);
  T.Test('invalid and double free', @TestInvalidAndDoubleFree);
  T.Test('capacity exhaustion returns nil', @TestCapacityExhaustionReturnsNil);
  T.Test('coalescing merges adjacent free blocks', @TestCoalescingMergesAdjacentBlocks);
  T.Run;

  T.Summary;
end.
