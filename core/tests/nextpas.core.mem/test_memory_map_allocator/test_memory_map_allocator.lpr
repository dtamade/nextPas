program test_memory_map_allocator;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.mmap;

type
  TExceptionProc = procedure;

var
  T: TTestRunner;
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
      CheckEqual(Int64(Ord(AExpected)), Int64(Ord(E.Error)), AName + ': error code');
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
  CheckEqual(True, LAllocator.Traits.ZeroInitialized, 'AllocMem should promise zeroing');

  LPtr := LAllocator.AllocMem(64);
  try
    Check(LPtr <> nil, 'AllocMem should allocate');
    for LIndex := 0 to 63 do
      CheckEqual(Int64(0), Int64(PByte(LPtr)[LIndex]), 'AllocMem should zero each byte');
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
    CheckEqual(Int64($6B), Int64(PByte(LPtr)^), 'reallocation should preserve prefix');
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

begin
  T := TTestRunner.Create('nextpas.core.mem.memory_map_allocator');
  T.Run('anonymous traits and zeroing', @TestAnonymousAllocatorTraitsAndZeroing);
  T.Run('realloc preserves prefix', @TestReallocPreservesPrefix);
  T.Run('multiple blocks do not alias and can reuse', @TestMultipleBlocksDoNotAliasAndCanReuse);
  T.Run('invalid and double free', @TestInvalidAndDoubleFree);
  T.Run('capacity exhaustion returns nil', @TestCapacityExhaustionReturnsNil);
  T.Summary;
end.
