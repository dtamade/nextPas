{ nextpas - test: batch allocator }

{$I nextpas.core.settings.inc}

program test_batch;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.batch;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TBatchAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchAlloc;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..9] of Pointer;
  LCount: Integer;
  I: Integer;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LCount := LAlloc.BatchAlloc(64, 10, LBlocks);
    Check(LCount = 10, 'batch alloc 10 blocks');
    for I := 0 to 9 do
      Check(LBlocks[I] <> nil, 'block #' + IntToStr(I));
    LAlloc.BatchFree(LBlocks, LCount);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchAllocPartial;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..2] of Pointer;
  LCount: Integer;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LCount := LAlloc.BatchAlloc(64, 3, LBlocks);
    Check(LCount = 3, 'batch alloc 3 blocks');
    LAlloc.BatchFree(LBlocks, LCount);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchFree;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..4] of Pointer;
  LStats: TBatchStats;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LAlloc.BatchAlloc(64, 5, LBlocks);
    LStats := LAlloc.GetStats;
    Check(LStats.BatchAllocCount = 1, 'batch alloc count = 1');
    Check(LStats.TotalBlocksAllocated = 5, 'total alloc = 5');

    LAlloc.BatchFree(LBlocks, 5);
    LStats := LAlloc.GetStats;
    Check(LStats.BatchFreeCount = 1, 'batch free count = 1');
    Check(LStats.TotalBlocksFreed = 5, 'total free = 5');
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TBatchAllocator;
  LStats: TBatchStats;
  LPtr: Pointer;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    Check(LStats.SingleAllocCount = 1, 'single alloc = 1');
    Check(LStats.TotalBlocksAllocated = 1, 'total = 1');
    LAlloc.FreeMem(LPtr);
    LStats := LAlloc.GetStats;
    Check(LStats.SingleFreeCount = 1, 'single free = 1');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMixedBatchAndSingle;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..2] of Pointer;
  LPtr: Pointer;
  LStats: TBatchStats;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    LAlloc.BatchAlloc(64, 3, LBlocks);

    LStats := LAlloc.GetStats;
    Check(LStats.SingleAllocCount = 1, 'single = 1');
    Check(LStats.BatchAllocCount = 1, 'batch = 1');
    Check(LStats.TotalBlocksAllocated = 4, 'total = 4');

    LAlloc.FreeMem(LPtr);
    LAlloc.BatchFree(LBlocks, 3);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchAllocZeroSize;
var
  LAlloc: TBatchAllocator;
  LBlocks: array[0..2] of Pointer;
  LCount: Integer;
  I: Integer;
begin
  LAlloc := TBatchAllocator.Create(DefaultAllocator);
  try
    LCount := LAlloc.BatchAlloc(0, 3, LBlocks);
    Check(LCount = 3, 'zero size batch succeeds');
    for I := 0 to 2 do
      Check(LBlocks[I] = nil, 'zero size returns nil');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_batch');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('batch_alloc', @TestBatchAlloc);
  T.Test('batch_alloc_partial', @TestBatchAllocPartial);
  T.Test('batch_free', @TestBatchFree);
  T.Test('stats', @TestStats);
  T.Test('mixed_batch_and_single', @TestMixedBatchAndSingle);
  T.Test('batch_alloc_zero_size', @TestBatchAllocZeroSize);
  T.Run;
  T.Summary;
end.
