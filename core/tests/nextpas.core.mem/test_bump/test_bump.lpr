{ nextpas - test: bump allocator }

{$I nextpas.core.settings.inc}

program test_bump;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.bump;

const
  TEST_REGION_SIZE = 4096;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TBumpAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBumpAllocator.Create(DefaultAllocator, TEST_REGION_SIZE);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LPtr1 <> nil, 'alloc 64B');
    LPtr2 := LAlloc.GetMem(64);
    Check(LPtr2 <> nil, 'alloc 64B #2');
    Check(LPtr1 <> LPtr2, 'different pointers');
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroReturnsNil;
var
  LAlloc: TBumpAllocator;
begin
  LAlloc := TBumpAllocator.Create(DefaultAllocator, TEST_REGION_SIZE);
  try
    Check(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestManyAllocations;
var
  LAlloc: TBumpAllocator;
  I: Integer;
  LPtrs: array[0..99] of Pointer;
begin
  LAlloc := TBumpAllocator.Create(DefaultAllocator, 1024);
  try
    for I := 0 to 99 do
    begin
      LPtrs[I] := LAlloc.GetMem(64);
      Check(LPtrs[I] <> nil, 'alloc #' + IntToStr(I));
    end;
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeIsNoOp;
var
  LAlloc: TBumpAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBumpAllocator.Create(DefaultAllocator, TEST_REGION_SIZE);
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'alloc');
    LAlloc.FreeMem(LPtr);
    { bump allocator does not free individual allocations }
  finally
    LAlloc.Free;
  end;
end;

procedure TestReset;
var
  LAlloc: TBumpAllocator;
  LPtr1, LPtr2: Pointer;
  LStats: TBumpStats;
begin
  LAlloc := TBumpAllocator.Create(DefaultAllocator, 1024);
  try
    LPtr1 := LAlloc.GetMem(512);
    Check(LPtr1 <> nil, 'alloc before reset');
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount = 1, 'count before reset');

    LAlloc.Reset;
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount = 0, 'count after reset = 0');

    LPtr2 := LAlloc.GetMem(512);
    Check(LPtr2 <> nil, 'alloc after reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TBumpAllocator;
  LStats: TBumpStats;
begin
  LAlloc := TBumpAllocator.Create(DefaultAllocator, 4096);
  try
    LAlloc.GetMem(100);
    LAlloc.GetMem(200);
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount = 2, 'alloc count = 2');
    Check(LStats.TotalAllocated >= 300, 'total >= 300');
    Check(LStats.RegionCount >= 1, 'region count >= 1');
    Check(LStats.RegionSize = 4096, 'region size = 4096');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRegionGrowth;
var
  LAlloc: TBumpAllocator;
  LStats: TBumpStats;
  I: Integer;
begin
  { Region size minimum is 4096; 64-byte allocs aligned to 64 → 4096/64 = 64 per region.
    Allocate 65 blocks to force growth to 2 regions. }
  LAlloc := TBumpAllocator.Create(DefaultAllocator, 4096);
  try
    for I := 0 to 64 do
      LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    Check(LStats.RegionCount >= 2, 'grew to multiple regions');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_bump');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('many_allocations', @TestManyAllocations);
  T.Test('free_is_noop', @TestFreeIsNoOp);
  T.Test('reset', @TestReset);
  T.Test('stats', @TestStats);
  T.Test('region_growth', @TestRegionGrowth);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
