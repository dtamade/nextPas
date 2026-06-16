program test_mapped_slab_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.mapped_slab_pool;

type
  TExceptionProc = procedure;

var
  T: TTestRunner;
  GPool: TMappedSlabAllocator = nil;
  GOtherPool: TMappedSlabAllocator = nil;
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

function RangesOverlap(APtrA: Pointer; ASizeA: SizeUInt; APtrB: Pointer; ASizeB: SizeUInt): Boolean;
var
  LA, LB: PtrUInt;
begin
  LA := PtrUInt(APtrA);
  LB := PtrUInt(APtrB);
  Result := (LA < LB + ASizeB) and (LB < LA + ASizeA);
end;

procedure TestCreateAnonymous;
var
  LAllocs, LFrees, LFailed: UInt64;
  LUsedPages, LTotalPages: UInt32;
begin
  GPool := TMappedSlabAllocator.CreateAnonymous(4096, 4096, 256);
  try
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

procedure TestFreeReusesSameSizeBlock;
var
  LP1, LP2: Pointer;
  LAllocs, LFrees, LFailed: UInt64;
  LUsedPages, LTotalPages: UInt32;
begin
  GPool := TMappedSlabAllocator.CreateAnonymous(4096, 4096, 256);
  try
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
  GPool := TMappedSlabAllocator.CreateAnonymous(16384, 4096, 2048);
  try
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
  GPool := TMappedSlabAllocator.CreateAnonymous(4096, 4096, 256);
  try
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
  GPool := TMappedSlabAllocator.CreateAnonymous(4096, 4096, 256);
  GOtherPool := TMappedSlabAllocator.CreateAnonymous(4096, 4096, 256);
  try
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
  GPool := TMappedSlabAllocator.CreateAnonymous(4096, 4096, 256);
  try
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

begin
  T := TTestRunner.Create('nextpas.core.mem.mapped_slab_pool');
  T.Run('create anonymous', @TestCreateAnonymous);
  T.Run('free reuses same-size block', @TestFreeReusesSameSizeBlock);
  T.Run('mixed-size allocations do not overlap', @TestMixedSizeAllocationsDoNotOverlap);
  T.Run('invalid and double free', @TestInvalidAndDoubleFree);
  T.Run('cross-pool free', @TestCrossPoolFree);
  T.Run('reset invalidates old pointers', @TestResetInvalidatesOldPointers);
  T.Summary;
end.
