program test_slab_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.slab;

var
  T: TTestRunner;

procedure TestCreateStatsAndTraits;
var
  LPool: TSlabPool;
  LStats: TSlabPoolStats;
  LPerf: TSlabPerfCounters;
  LTraits: TAllocatorTraits;
begin
  LPool := TSlabPool.Create(4096);
  try
    LStats := LPool.Stats;
    CheckEqual(Int64(1), Int64(LStats.SegmentCount), 'initial segment count');
    Check(LStats.TotalCapacity >= 4096, 'initial capacity should cover requested bytes');
    CheckEqual(Int64(0), Int64(LStats.TotalUsed), 'initial used bytes');
    CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount), 'initial fallback count');

    LTraits := LPool.Traits;
    CheckEqual(True, LTraits.ZeroInitialized, 'AllocMem should promise zero initialization');
    CheckEqual(False, LTraits.ThreadSafe, 'plain slab pool should not claim thread safety');
    CheckEqual(True, LTraits.HasMemSize, 'slab pool should expose mem size');
    CheckEqual(False, LTraits.SupportsAligned, 'slab pool should not claim generic aligned support');

    LPerf := LPool.GetPerfCounters;
    CheckEqual(Int64(0), Int64(LPerf.AllocCalls), 'initial alloc calls');
    CheckEqual(Int64(0), Int64(LPerf.FreeCalls), 'initial free calls');
    CheckEqual(Int64(0), Int64(LPerf.AllocTime), 'L0 slab pool should not sample alloc time directly');
    CheckEqual(Int64(0), Int64(LPerf.FreeTime), 'L0 slab pool should not sample free time directly');
  finally
    LPool.Free;
  end;
end;

procedure TestAllocFreeAndPerfCounters;
var
  LPool: TSlabPool;
  LPtr: Pointer;
  LStats: TSlabPoolStats;
  LPerf: TSlabPerfCounters;
begin
  LPool := TSlabPool.Create(4096);
  try
    LPtr := LPool.GetMem(64);
    Check(LPtr <> nil, 'GetMem should allocate');
    Check(LPool.Owns(LPtr), 'pool should own allocated pointer');
    CheckEqual(Int64(64), Int64(LPool.MemSizeOf(LPtr)), 'MemSizeOf should report slab chunk size');

    LPerf := LPool.GetPerfCounters;
    CheckEqual(Int64(1), Int64(LPerf.AllocCalls), 'alloc calls after one allocation');
    CheckEqual(Int64(0), Int64(LPerf.FreeCalls), 'free calls before release');
    CheckEqual(Int64(0), Int64(LPerf.AllocTime), 'alloc time remains zero without L1 timing dependency');

    LStats := LPool.Stats;
    Check(LStats.TotalUsed >= 64, 'used bytes should grow after allocation');

    LPool.FreeMem(LPtr);
    LPerf := LPool.GetPerfCounters;
    CheckEqual(Int64(1), Int64(LPerf.AllocCalls), 'alloc calls should stay stable after free');
    CheckEqual(Int64(1), Int64(LPerf.FreeCalls), 'free calls after release');
    CheckEqual(Int64(0), Int64(LPerf.FreeTime), 'free time remains zero without L1 timing dependency');

    LStats := LPool.Stats;
    CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount), 'slab path should not create fallback allocation');
  finally
    LPool.Free;
  end;
end;

procedure TestAllocAlignedFallsBackAndTracksStats;
var
  LPool: TSlabPool;
  LPtr: Pointer;
  LSize: SizeUInt;
  LAlign: SizeUInt;
  LStats: TSlabPoolStats;
begin
  LPool := TSlabPool.Create(4096);
  try
    LPtr := LPool.AllocAligned(96, 256);
    try
      Check(LPtr <> nil, 'AllocAligned should succeed via fallback path');
      Check((PtrUInt(LPtr) mod 256) = 0, 'AllocAligned should honor requested alignment');
      Check(LPool.TryGetFallbackAllocInfo(LPtr, LSize, LAlign), 'aligned fallback should be tracked');
      CheckEqual(Int64(96), Int64(LSize), 'tracked fallback size');
      CheckEqual(Int64(256), Int64(LAlign), 'tracked fallback alignment');

      LStats := LPool.Stats;
      CheckEqual(Int64(1), Int64(LStats.FallbackAllocCount), 'fallback allocation count');
      CheckEqual(Int64(96), Int64(LStats.FallbackBytes), 'fallback byte count');
    finally
      LPool.FreeAligned(LPtr);
    end;

    LStats := LPool.Stats;
    CheckEqual(Int64(0), Int64(LStats.FallbackAllocCount), 'fallback allocation count after free');
    CheckEqual(Int64(0), Int64(LStats.FallbackBytes), 'fallback byte count after free');
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.slab_pool');
  T.Run('create stats and traits', @TestCreateStatsAndTraits);
  T.Run('alloc free and perf counters', @TestAllocFreeAndPerfCounters);
  T.Run('aligned fallback tracking', @TestAllocAlignedFallsBackAndTracksStats);
  T.Summary;
end.
