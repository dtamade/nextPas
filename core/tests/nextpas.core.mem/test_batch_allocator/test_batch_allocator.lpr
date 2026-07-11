program test_batch_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.batch;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TBatchAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'single alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchAlloc;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..7] of Pointer;
  LCount, LIdx: Integer;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  try
    LCount := LAlloc.BatchAlloc(64, 8, LBlocks);
    Check(LCount = 8, 'batch 8 blocks');
    for LIdx := 0 to 7 do
      Check(LBlocks[LIdx] <> nil, 'block ' + IntToStr(LIdx));
    LAlloc.BatchFree(LBlocks, LCount);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchAllocCapped;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..3] of Pointer;
  LCount: Integer;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  try
    // Request 8 but array only holds 4
    LCount := LAlloc.BatchAlloc(64, 8, LBlocks);
    Check(LCount = 4, 'capped to array size');
    LAlloc.BatchFree(LBlocks, LCount);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TBatchAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..3] of Pointer;
  LPtr: Pointer;
  LStats: TBatchStats;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  LPtr := nil;
  try
    LPtr := LAlloc.GetMem(32);
    LAlloc.BatchAlloc(64, 4, LBlocks);

    LStats := LAlloc.GetStats;
    Check(LStats.SingleAllocCount >= 1, 'single allocs');
    Check(LStats.BatchAllocCount >= 1, 'batch allocs');
    Check(LStats.TotalBlocksAllocated >= 5, 'total blocks');

    LAlloc.BatchFree(LBlocks, 4);

    LStats := LAlloc.GetStats;
    Check(LStats.TotalBlocksFreed >= 4, 'blocks freed');
  finally
    if LPtr <> nil then
      LAlloc.FreeMem(LPtr);
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TBatchAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $CD;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $CD, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestNilAllocator;
var
  LAlloc: TBatchAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBatchAllocator.Create(GetRtlAllocator);
  LPtr := nil;
  try
    // Zero-size allocation returns nil or valid pointer
    LPtr := LAlloc.GetMem(0);
    Check(True, 'no crash');
  finally
    if LPtr <> nil then
      LAlloc.FreeMem(LPtr);
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_batch_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('BatchAlloc', @TestBatchAlloc);
  T.Test('BatchAllocCapped', @TestBatchAllocCapped);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Stats', @TestStats);
  T.Test('Realloc', @TestRealloc);
  T.Test('NilAllocator', @TestNilAllocator);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
