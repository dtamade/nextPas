program test_stats_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.stats;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TStatsAllocator;
  LPtr: Pointer;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestTrackAllocations;
var
  LAlloc: TStatsAllocator;
  LStats: TAllocatorStats;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);

    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 2, 'allocs');
    Check(LStats.ActiveBytes >= 192, 'active bytes');
    Check(LStats.PeakBytes >= 192, 'peak bytes');
    Check(LStats.ActiveAllocs >= 2, 'active allocs');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPeakTracking;
var
  LAlloc: TStatsAllocator;
  LPtr: Pointer;
  LStats: TAllocatorStats;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(100);
    LStats := LAlloc.GetStats;
    Check(LStats.PeakBytes >= 100, 'peak 100');

    LAlloc.FreeMem(LPtr);
    LStats := LAlloc.GetStats;
    Check(LStats.PeakBytes >= 100, 'peak stays 100');
    Check(LStats.ActiveBytes = 0, 'active 0');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TStatsAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
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

procedure TestMinMaxSize;
var
  LAlloc: TStatsAllocator;
  LStats: TAllocatorStats;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(64);
    LAlloc.GetMem(16);

    LStats := LAlloc.GetStats;
    Check(LStats.MinAllocSize <= 16, 'min size');
    Check(LStats.MaxAllocSize >= 64, 'max size');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReset;
var
  LAlloc: TStatsAllocator;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);
    Check(LAlloc.ActiveBytes > 0, 'before reset');

    LAlloc.Reset;
    Check(LAlloc.ActiveBytes = 0, 'after reset');
    Check(LAlloc.PeakBytes = 0, 'peak reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TStatsAllocator;
  LPtr, LNewPtr: Pointer;
  LStats: TAllocatorStats;
begin
  LAlloc := TStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $AB;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $AB, 'data preserved');

    LStats := LAlloc.GetStats;
    Check(LStats.ReallocCount >= 1, 'realloc tracked');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_stats_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('TrackAllocations', @TestTrackAllocations);
  T.Test('PeakTracking', @TestPeakTracking);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('MinMaxSize', @TestMinMaxSize);
  T.Test('Reset', @TestReset);
  T.Test('Realloc', @TestRealloc);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
