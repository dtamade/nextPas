program test_slab_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.slab;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TSlabAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'allocated 32B');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSmallObjectRouting;
var
  LAlloc: TSlabAllocator;
  LPtr8, LPtr16, LPtr64: Pointer;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LPtr8 := LAlloc.GetMem(8);
    LPtr16 := LAlloc.GetMem(16);
    LPtr64 := LAlloc.GetMem(64);
    Check(LPtr8 <> nil, '8B allocated');
    Check(LPtr16 <> nil, '16B allocated');
    Check(LPtr64 <> nil, '64B allocated');

    Check(LAlloc.IsSmallObject(LPtr8), '8B is small');
    Check(LAlloc.IsSmallObject(LPtr16), '16B is small');
    Check(LAlloc.IsSmallObject(LPtr64), '64B is small');

    LAlloc.FreeMem(LPtr8);
    LAlloc.FreeMem(LPtr16);
    LAlloc.FreeMem(LPtr64);
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeObjectRouting;
var
  LAlloc: TSlabAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(2048);
    Check(LPtr <> nil, 'large allocated');
    // Note: IsSmallObject reads header memory — undefined for large objects
    // We just verify the allocation succeeded and can be freed
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TSlabAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.AllocMem(32);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 31 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeListRecycle;
var
  LAlloc: TSlabAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LPtr1 := LAlloc.GetMem(32);
    Check(LPtr1 <> nil, 'first alloc');
    LAlloc.FreeMem(LPtr1);

    LPtr2 := LAlloc.GetMem(32);
    Check(LPtr2 <> nil, 'recycled alloc');
    // Should reuse the same slot (freelist LIFO)
    Check(LPtr1 = LPtr2, 'same slot reused');
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TSlabAllocator;
  LStats: TSlabStats;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(32);     // small
    LAlloc.GetMem(64);     // small
    LAlloc.GetMem(2048);   // large

    LStats := LAlloc.GetStats;
    Check(LStats.SmallAllocCount >= 2, 'small allocs');
    Check(LStats.LargeAllocCount >= 1, 'large allocs');
    Check(LStats.SlabPageCount >= 1, 'slab pages');
    Check(LStats.FreeObjectCount >= 0, 'free objects');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocGrow;
var
  LAlloc: TSlabAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TSlabAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(16);
    Check(LPtr <> nil, 'initial alloc');

    // Write pattern
    PByte(LPtr)^ := $AB;

    // Realloc to larger size
    LNewPtr := LAlloc.ReallocMem(LPtr, 64);
    Check(LNewPtr <> nil, 'realloc succeeded');
    Check(PByte(LNewPtr)^ = $AB, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_slab_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('SmallObjectRouting', @TestSmallObjectRouting);
  T.Test('LargeObjectRouting', @TestLargeObjectRouting);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('FreeListRecycle', @TestFreeListRecycle);
  T.Test('Stats', @TestStats);
  T.Test('ReallocGrow', @TestReallocGrow);
  T.Run;
  T.Summary;
end.
