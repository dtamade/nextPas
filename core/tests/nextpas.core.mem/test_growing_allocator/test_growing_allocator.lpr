program test_growing_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestSmallAlloc;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'small alloc 64B returns non-nil');
    LAlloc.FreeMem(LPtr, 64);
    WriteLn('PASS: small alloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.GetMem(128 * 1024);
    Check(LPtr <> nil, 'large alloc 128KB returns non-nil');
    LAlloc.FreeMem(LPtr, 128 * 1024);
    WriteLn('PASS: large alloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TGrowingAllocator;
  LPtr: PByte;
  I: Integer;
  LZero: Boolean;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := PByte(LAlloc.AllocMem(256));
    Check(LPtr <> nil, 'AllocMem returns non-nil');
    LZero := True;
    for I := 0 to 255 do
    begin
      if LPtr[I] <> 0 then
      begin
        LZero := False;
        Break;
      end;
    end;
    Check(LZero, 'AllocMem is zeroed');
    LAlloc.FreeMem(LPtr, 256);
    WriteLn('PASS: alloc mem zeroed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleSizes;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..9] of Pointer;
  LSizes: array[0..9] of SizeUInt;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LSizes[0] := 16;
    LSizes[1] := 32;
    LSizes[2] := 64;
    LSizes[3] := 128;
    LSizes[4] := 256;
    LSizes[5] := 512;
    LSizes[6] := 1024;
    LSizes[7] := 4096;
    LSizes[8] := 16384;
    LSizes[9] := 131072;
    for I := 0 to 9 do
    begin
      LPtrs[I] := LAlloc.GetMem(LSizes[I]);
      Check(LPtrs[I] <> nil, 'alloc ' + IntToStr(LSizes[I]) + 'B');
    end;
    { All should be distinct. }
    for I := 0 to 8 do
      Check(LPtrs[I] <> LPtrs[I + 1], 'distinct ' + IntToStr(I));
    for I := 0 to 9 do
      LAlloc.FreeMem(LPtrs[I], LSIZES[I]);
    WriteLn('PASS: multiple sizes');
  finally
    LAlloc.Free;
  end;
end;

procedure TestCacheHit;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..63] of Pointer;
  LPtr: Pointer;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    { Fill the cache by allocating a batch, then free all. }
    for I := 0 to 63 do
      LPtrs[I] := LAlloc.GetMem(64);
    for I := 0 to 63 do
      LAlloc.FreeMem(LPtrs[I], 64);
    { Now the cache is full. Next alloc should return a cached block. }
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'cache hit: should return non-nil');
    LAlloc.FreeMem(LPtr, 64);
    WriteLn('PASS: cache hit');
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroSize;
var
  LAlloc: TGrowingAllocator;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    Check(LAlloc.GetMem(0) = nil, 'zero size returns nil');
    WriteLn('PASS: zero size');
  finally
    LAlloc.Free;
  end;
end;

procedure TestDefaultAllocator;
var
  LPtr: Pointer;
begin
  LPtr := DefaultGrowingAllocator.GetMem(128);
  Check(LPtr <> nil, 'default allocator works');
  DefaultGrowingAllocator.FreeMem(LPtr, 128);
  WriteLn('PASS: default allocator');
end;

{ --- ReallocMem tests --- }

procedure TestReallocSameClass;
var
  LAlloc: TGrowingAllocator;
  LPtr, LPtr2: PByte;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := PByte(LAlloc.GetMem(50));
    Check(LPtr <> nil, 'initial alloc');
    for I := 0 to 49 do
      LPtr[I] := Byte(I);
    { Realloc to 60B — same size class (band 0, class 3 covers 49-64B). }
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 50, 60));
    Check(LPtr2 <> nil, 'realloc returns non-nil');
    Check(LPtr2 = LPtr, 'same class → zero-copy (same pointer)');
    for I := 0 to 49 do
      Check(LPtr2[I] = Byte(I), 'data[' + IntToStr(I) + '] preserved');
    LAlloc.FreeMem(LPtr2, 60);
    WriteLn('PASS: realloc same class (zero-copy)');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocDiffClass;
var
  LAlloc: TGrowingAllocator;
  LPtr, LPtr2: PByte;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := PByte(LAlloc.GetMem(64));
    for I := 0 to 63 do
      LPtr[I] := Byte(I + 1);
    { Realloc to 2KB — different class (band 0 → band 2). }
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 64, 2048));
    Check(LPtr2 <> nil, 'realloc diff class returns non-nil');
    { Verify data preserved (first 64 bytes). }
    for I := 0 to 63 do
      Check(LPtr2[I] = Byte(I + 1), 'diff class data[' + IntToStr(I) + '] preserved');
    LAlloc.FreeMem(LPtr2, 2048);
    WriteLn('PASS: realloc diff class (copy)');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocNil;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    { Realloc(nil, 0, 128) should behave like GetMem(128). }
    LPtr := LAlloc.ReallocMem(nil, 0, 128);
    Check(LPtr <> nil, 'realloc nil acts as alloc');
    LAlloc.FreeMem(LPtr, 128);
    WriteLn('PASS: realloc nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocToZero;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'initial alloc');
    { Realloc(Ptr, 128, 0) should free and return nil. }
    Check(LAlloc.ReallocMem(LPtr, 128, 0) = nil, 'realloc to zero frees');
    WriteLn('PASS: realloc to zero');
  finally
    LAlloc.Free;
  end;
end;

{ --- BatchGetMem/BatchFreeMem tests --- }

procedure TestBatchGetMem;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..63] of Pointer;
  LCount: Word;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LCount := LAlloc.BatchGetMem(128, 64, @LPtrs[0]);
    Check(LCount = 64, 'batch get 64 blocks');
    { All should be distinct. }
    for I := 0 to 62 do
      Check(LPtrs[I] <> LPtrs[I + 1], 'block ' + IntToStr(I) + ' distinct');
    LAlloc.BatchFreeMem(128, 64, @LPtrs[0]);
    WriteLn('PASS: batch get/free 64 blocks');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocShrink;
var
  LAlloc: TGrowingAllocator;
  LPtr, LPtr2: PByte;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := PByte(LAlloc.GetMem(256));
    for I := 0 to 255 do
      LPtr[I] := Byte(I);
    { Shrink to 64B — smaller size class. }
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 256, 64));
    Check(LPtr2 <> nil, 'realloc shrink returns non-nil');
    for I := 0 to 63 do
      Check(LPtr2[I] = Byte(I), 'shrink data[' + IntToStr(I) + '] preserved');
    LAlloc.FreeMem(LPtr2, 64);
    WriteLn('PASS: realloc shrink (256→64)');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocGrowAcrossBands;
var
  LAlloc: TGrowingAllocator;
  LPtr, LPtr2: PByte;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    LPtr := PByte(LAlloc.GetMem(64));
    for I := 0 to 63 do
      LPtr[I] := Byte(I + 1);
    { Grow 64→4096 (band 0→band 2). }
    LPtr2 := PByte(LAlloc.ReallocMem(LPtr, 64, 4096));
    Check(LPtr2 <> nil, 'realloc 64→4096 returns non-nil');
    for I := 0 to 63 do
      Check(LPtr2[I] = Byte(I + 1), 'grow1 data[' + IntToStr(I) + ']');
    { Grow 4096→131072 (band 2→band 5). }
    LPtr := PByte(LAlloc.ReallocMem(LPtr2, 4096, 131072));
    Check(LPtr <> nil, 'realloc 4096→131072 returns non-nil');
    for I := 0 to 63 do
      Check(LPtr[I] = Byte(I + 1), 'grow2 data[' + IntToStr(I) + ']');
    LAlloc.FreeMem(LPtr, 131072);
    WriteLn('PASS: realloc grow across bands (64→4K→128K)');
  finally
    LAlloc.Free;
  end;
end;

procedure TestBatchGetMemZero;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..0] of Pointer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    Check(LAlloc.BatchGetMem(0, 1, @LPtrs[0]) = 0, 'zero size returns 0');
    Check(LAlloc.BatchGetMem(64, 0, @LPtrs[0]) = 0, 'zero count returns 0');
    WriteLn('PASS: batch get zero');
  finally
    LAlloc.Free;
  end;
end;

procedure CleanupDefaultAllocator;
begin
  ResetDefaultGrowingAllocator;
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('growing_allocator');

  T.Test('small_alloc', @TestSmallAlloc);
  T.Test('large_alloc', @TestLargeAlloc);
  T.Test('alloc_mem_zeroed', @TestAllocMem);
  T.Test('multiple_sizes', @TestMultipleSizes);
  T.Test('cache_hit', @TestCacheHit);
  T.Test('zero_size', @TestZeroSize);
  T.Test('default_allocator', @TestDefaultAllocator);
  T.Test('realloc_same_class', @TestReallocSameClass);
  T.Test('realloc_diff_class', @TestReallocDiffClass);
  T.Test('realloc_nil', @TestReallocNil);
  T.Test('realloc_to_zero', @TestReallocToZero);
  T.Test('batch_get_free', @TestBatchGetMem);
  T.Test('batch_get_zero', @TestBatchGetMemZero);
  T.Test('realloc_shrink', @TestReallocShrink);
  T.Test('realloc_grow_bands', @TestReallocGrowAcrossBands);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
  CleanupDefaultAllocator;
end.
