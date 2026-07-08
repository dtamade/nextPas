{ nextpas - test: stats allocator }

{$I nextpas.core.settings.inc}

program test_stats_alloc;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.stats;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TStatsAllocator;
  LPtr: Pointer;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Assert(LPtr <> nil, 'alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroReturnsNil;
var
  LAlloc: TStatsAllocator;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    Assert(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocStats;
var
  LAlloc: TStatsAllocator;
  LStats: TAllocatorStats;
  LPtr: Pointer;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(100);
    LStats := LAlloc.GetStats;
    Assert(LStats.AllocCount = 1, 'alloc count = 1');
    Assert(LStats.ActiveBytes = 100, 'active = 100');
    Assert(LStats.PeakBytes = 100, 'peak = 100');
    Assert(LStats.ActiveAllocs = 1, 'active allocs = 1');
    Assert(LStats.MinAllocSize = 100, 'min = 100');
    Assert(LStats.MaxAllocSize = 100, 'max = 100');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LAlloc: TStatsAllocator;
  LStats: TAllocatorStats;
  LPtrs: array[0..2] of Pointer;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    LPtrs[0] := LAlloc.GetMem(50);
    LPtrs[1] := LAlloc.GetMem(100);
    LPtrs[2] := LAlloc.GetMem(200);
    LStats := LAlloc.GetStats;
    Assert(LStats.AllocCount = 3, 'alloc count = 3');
    Assert(LStats.ActiveBytes = 350, 'active = 350');
    Assert(LStats.PeakBytes = 350, 'peak = 350');
    Assert(LStats.MinAllocSize = 50, 'min = 50');
    Assert(LStats.MaxAllocSize = 200, 'max = 200');
    LAlloc.FreeMem(LPtrs[0]);
    LAlloc.FreeMem(LPtrs[1]);
    LAlloc.FreeMem(LPtrs[2]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestPeakTracking;
var
  LAlloc: TStatsAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LAlloc.GetMem(300);
    LPtr2 := LAlloc.GetMem(200);
    Assert(LAlloc.PeakBytes = 500, 'peak = 500');
    LAlloc.FreeMem(LPtr2);
    Assert(LAlloc.ActiveBytes = 300, 'active = 300');
    Assert(LAlloc.PeakBytes = 500, 'peak unchanged');
    LAlloc.FreeMem(LPtr1);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReset;
var
  LAlloc: TStatsAllocator;
  LStats: TAllocatorStats;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    LAlloc.GetMem(100);
    LStats := LAlloc.GetStats;
    Assert(LStats.AllocCount = 1, 'before reset');

    LAlloc.Reset;
    LStats := LAlloc.GetStats;
    Assert(LStats.AllocCount = 0, 'after reset');
    Assert(LStats.ActiveBytes = 0, 'active = 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeStats;
var
  LAlloc: TStatsAllocator;
  LStats: TAllocatorStats;
  LPtr: Pointer;
begin
  LAlloc := TStatsAllocator.Create(DefaultAllocator);
  try
    LPtr := LAlloc.GetMem(100);
    LAlloc.FreeMem(LPtr);
    LStats := LAlloc.GetStats;
    Assert(LStats.FreeCount = 1, 'free count = 1');
    Assert(LStats.ActiveBytes = 0, 'active = 0');
    Assert(LStats.TotalBytesFreed = 100, 'freed = 100');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_stats_alloc');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('alloc_stats', @TestAllocStats);
  T.Test('multiple_allocs', @TestMultipleAllocs);
  T.Test('peak_tracking', @TestPeakTracking);
  T.Test('reset', @TestReset);
  T.Test('free_stats', @TestFreeStats);
  T.Run;
  T.Summary;
end.
