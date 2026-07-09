program test_bump_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.bump;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TBumpAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    // Bump allocator doesn't free individual allocations
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAlloc;
var
  LAlloc: TBumpAllocator;
  LPtrs: array[0..3] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(64);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;
    // All pointers should be different
    Check(LPtrs[0] <> LPtrs[1], 'distinct 0-1');
    Check(LPtrs[2] <> LPtrs[3], 'distinct 2-3');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TBumpAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReset;
var
  LAlloc: TBumpAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LPtr1 <> nil, 'before reset');

    LAlloc.Reset;

    LPtr2 := LAlloc.GetMem(64);
    Check(LPtr2 <> nil, 'after reset');
    // After reset, should reuse same memory region
    Check(LPtr1 = LPtr2, 'same address reused');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGrowRegion;
var
  LAlloc: TBumpAllocator;
  LPtr: Pointer;
begin
  // Small region to force growth
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    Check(LAlloc.RegionCount = 0, 'initial no region');

    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'first alloc');
    Check(LAlloc.RegionCount >= 1, 'has region');

    // Allocate more than region size to force growth
    LPtr := LAlloc.GetMem(8192);
    Check(LPtr <> nil, 'large alloc');
    Check(LAlloc.RegionCount >= 2, 'grew region');
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TBumpAllocator;
  LStats: TBumpStats;
begin
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);

    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 2, 'allocs');
    Check(LStats.TotalAllocated >= 192, 'total bytes');
    Check(LStats.RegionCount >= 1, 'regions');
    Check(LStats.RegionSize = 4096, 'region size');
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TBumpAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBumpAllocator.Create(GetRtlAllocator, 4096);
  try
    // Allocate larger than default region
    LPtr := LAlloc.GetMem(16384);
    Check(LPtr <> nil, 'large alloc succeeded');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_bump_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('MultipleAlloc', @TestMultipleAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Reset', @TestReset);
  T.Test('GrowRegion', @TestGrowRegion);
  T.Test('Stats', @TestStats);
  T.Test('LargeAlloc', @TestLargeAlloc);
  T.Run;
  T.Summary;
end.
