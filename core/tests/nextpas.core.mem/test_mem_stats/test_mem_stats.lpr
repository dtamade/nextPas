program test_mem_stats;
{$mode ObjFPC}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.stats;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- TAllocSnapshot tests --- }

procedure TestSnapshotInitiallyZero;
var
  LStats: TAllocStatsAllocator;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    LSnap := LStats.Snapshot;
    Check(LSnap.TotalAllocs = 0, 'initial TotalAllocs=0');
    Check(LSnap.TotalFrees = 0, 'initial TotalFrees=0');
    Check(LSnap.ActiveAllocs = 0, 'initial ActiveAllocs=0');
    Check(LSnap.PeakAllocs = 0, 'initial PeakAllocs=0');
    Check(LSnap.TotalBytesAllocated = 0, 'initial TotalBytesAllocated=0');
  finally
    LStats.Free;
  end;
end;

procedure TestSnapshotTracksAlloc;
var
  LStats: TAllocStatsAllocator;
  LPtr: Pointer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LStats.GetMem(1024);
    try
      LSnap := LStats.Snapshot;
      Check(LSnap.TotalAllocs = 1, 'TotalAllocs=1 after alloc');
      Check(LSnap.ActiveAllocs = 1, 'ActiveAllocs=1 after alloc');
      Check(LSnap.PeakAllocs = 1, 'PeakAllocs=1');
      Check(LSnap.TotalBytesAllocated >= 1024, 'TotalBytesAllocated >= 1024');
    finally
      LStats.FreeMem(LPtr);
    end;

    LSnap := LStats.Snapshot;
    Check(LSnap.TotalAllocs = 1, 'TotalAllocs still 1');
    Check(LSnap.TotalFrees = 1, 'TotalFrees=1 after free');
    Check(LSnap.ActiveAllocs = 0, 'ActiveAllocs=0 after free');
    Check(LSnap.PeakAllocs = 1, 'PeakAllocs still 1');
  finally
    LStats.Free;
  end;
end;

procedure TestSnapshotPeakTracking;
var
  LStats: TAllocStatsAllocator;
  LPtrs: array[0..9] of Pointer;
  LI: Integer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    // 分配 10 个块
    for LI := 0 to 9 do
      LPtrs[LI] := LStats.GetMem(256);

    LSnap := LStats.Snapshot;
    Check(LSnap.ActiveAllocs = 10, 'ActiveAllocs=10');
    Check(LSnap.PeakAllocs = 10, 'PeakAllocs=10');

    // 释放 5 个
    for LI := 0 to 4 do
      LStats.FreeMem(LPtrs[LI]);

    LSnap := LStats.Snapshot;
    Check(LSnap.ActiveAllocs = 5, 'ActiveAllocs=5 after partial free');
    Check(LSnap.PeakAllocs = 10, 'PeakAllocs still 10');

    // 释放剩余
    for LI := 5 to 9 do
      LStats.FreeMem(LPtrs[LI]);

    LSnap := LStats.Snapshot;
    Check(LSnap.ActiveAllocs = 0, 'ActiveAllocs=0 after all free');
    Check(LSnap.PeakAllocs = 10, 'PeakAllocs still 10');
  finally
    LStats.Free;
  end;
end;

procedure TestSnapshotRealloc;
var
  LStats: TAllocStatsAllocator;
  LPtr: Pointer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LStats.GetMem(512);
    try
      LSnap := LStats.Snapshot;
      Check(LSnap.ActiveAllocs = 1, 'ActiveAllocs=1');
      Check(LSnap.TotalAllocs = 1, 'TotalAllocs=1');

      // Realloc 到更大
      LPtr := LStats.ReallocMem(LPtr, 2048);
      LSnap := LStats.Snapshot;
      Check(LSnap.TotalAllocs = 2, 'TotalAllocs=2 after realloc');
      Check(LSnap.TotalFrees = 1, 'TotalFrees=1 after realloc');
      Check(LSnap.ActiveAllocs = 1, 'ActiveAllocs=1 after realloc');
    finally
      LStats.FreeMem(LPtr);
    end;
  finally
    LStats.Free;
  end;
end;

procedure TestSnapshotAllocMem;
var
  LStats: TAllocStatsAllocator;
  LPtr: Pointer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LStats.AllocMem(1024);
    try
      LSnap := LStats.Snapshot;
      Check(LSnap.TotalAllocs = 1, 'TotalAllocs=1');
      Check(LSnap.TotalBytesAllocated >= 1024, 'TotalBytesAllocated >= 1024');
    finally
      LStats.FreeMem(LPtr);
    end;
  finally
    LStats.Free;
  end;
end;

{ --- TAllocHistogram tests --- }

procedure TestHistogramDisabled;
var
  LStats: TAllocStatsAllocator;
  LHisto: TAllocHistogram;
  LPtr: Pointer;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator, False);
  try
    LPtr := LStats.GetMem(1024);
    LHisto := LStats.Histogram;
    Check(LHisto.TotalCount = 0, 'histogram disabled: TotalCount=0');
    LStats.FreeMem(LPtr);
  finally
    LStats.Free;
  end;
end;

procedure TestHistogramBuckets;
var
  LStats: TAllocStatsAllocator;
  LPtrs: array[0..4] of Pointer;
  LHisto: TAllocHistogram;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator, True);
  try
    // 分配不同大小
    LPtrs[0] := LStats.GetMem(8);      // bucket 0: 0-16B
    LPtrs[1] := LStats.GetMem(32);     // bucket 1: 17-64B
    LPtrs[2] := LStats.GetMem(512);    // bucket 3: 257B-1KB
    LPtrs[3] := LStats.GetMem(8192);   // bucket 5: 4KB-16KB
    LPtrs[4] := LStats.GetMem(131072); // bucket 7: 64KB-256KB

    LHisto := LStats.Histogram;
    Check(LHisto.TotalCount = 5, 'TotalCount=5');
    Check(LHisto.Buckets[0] = 1, 'bucket 0 (0-16B) = 1');
    Check(LHisto.Buckets[1] = 1, 'bucket 1 (17-64B) = 1');
    Check(LHisto.Buckets[3] = 1, 'bucket 3 (257B-1KB) = 1');
    Check(LHisto.Buckets[5] = 1, 'bucket 5 (4KB-16KB) = 1');
    Check(LHisto.Buckets[7] = 1, 'bucket 7 (64KB-256KB) = 1');

    // 清理
    LStats.FreeMem(LPtrs[0]);
    LStats.FreeMem(LPtrs[1]);
    LStats.FreeMem(LPtrs[2]);
    LStats.FreeMem(LPtrs[3]);
    LStats.FreeMem(LPtrs[4]);
  finally
    LStats.Free;
  end;
end;

procedure TestHistogramMeanSize;
var
  LStats: TAllocStatsAllocator;
  LHisto: TAllocHistogram;
  LPtrs: array[0..2] of Pointer;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator, True);
  try
    LPtrs[0] := LStats.GetMem(100);
    LPtrs[1] := LStats.GetMem(200);
    LPtrs[2] := LStats.GetMem(300);

    LHisto := LStats.Histogram;
    Check(LHisto.MeanSize = 200.0, 'MeanSize = (100+200+300)/3 = 200');

    LStats.FreeMem(LPtrs[0]);
    LStats.FreeMem(LPtrs[1]);
    LStats.FreeMem(LPtrs[2]);
  finally
    LStats.Free;
  end;
end;

procedure TestHistogramPercentile;
var
  LStats: TAllocStatsAllocator;
  LHisto: TAllocHistogram;
  LPtrs: array[0..10] of Pointer;
  LI: Integer;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator, True);
  try
    // 10 个小分配 + 1 个大分配
    for LI := 0 to 9 do
      LPtrs[LI] := LStats.GetMem(16);
    LPtrs[10] := LStats.GetMem(65536);

    LHisto := LStats.Histogram;
    // 50th percentile: Trunc(50*11/100)=5, 第5个在 bucket[0]=16B
    CheckEqual(Int64(16), Int64(LHisto.Percentile(50)), 'P50 = 16B');
    // 90th percentile: Trunc(90*11/100)=9, 第9个在 bucket[0]=16B
    CheckEqual(Int64(16), Int64(LHisto.Percentile(90)), 'P90 = 16B');
    // 99th percentile: Trunc(99*11/100)=10, 第10个仍在 bucket[0]=16B
    CheckEqual(Int64(16), Int64(LHisto.Percentile(99)), 'P99 = 16B');

    // 释放所有分配
    for LI := 0 to 10 do
      LStats.FreeMem(LPtrs[LI]);
  finally
    LStats.Free;
  end;
end;

{ --- ResetStats test --- }

procedure TestResetStats;
var
  LStats: TAllocStatsAllocator;
  LPtr: Pointer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator, True);
  try
    LPtr := LStats.GetMem(1024);
    try
      LSnap := LStats.Snapshot;
      Check(LSnap.TotalAllocs = 1, 'before reset: TotalAllocs=1');

      LStats.ResetStats;
      LSnap := LStats.Snapshot;
      Check(LSnap.TotalAllocs = 0, 'after reset: TotalAllocs=0');
      Check(LSnap.TotalFrees = 0, 'after reset: TotalFrees=0');
    finally
      LStats.FreeMem(LPtr);
    end;
  finally
    LStats.Free;
  end;
end;

procedure TestResetStatsPreservesActiveAllocations;
var
  LStats: TAllocStatsAllocator;
  LPtr: Pointer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator, True);
  LPtr := nil;
  try
    LPtr := LStats.GetMem(128);
    LStats.ResetStats;

    LSnap := LStats.Snapshot;
    Check(LSnap.TotalAllocs = 0, 'reset clears TotalAllocs');
    Check(LSnap.TotalFrees = 0, 'reset clears TotalFrees');
    Check(LSnap.ActiveAllocs = 1, 'reset preserves ActiveAllocs');
    Check(LSnap.PeakAllocs = 1, 'reset keeps PeakAllocs consistent with active allocations');
    Check(LSnap.TotalBytesAllocated = 0, 'reset clears TotalBytesAllocated');

    LStats.FreeMem(LPtr);
    LPtr := nil;
    LSnap := LStats.Snapshot;
    Check(LSnap.TotalFrees = 1, 'free after reset updates TotalFrees');
    Check(LSnap.ActiveAllocs = 0, 'free after reset returns ActiveAllocs to zero');
  finally
    if LPtr <> nil then
      LStats.FreeMem(LPtr);
    LStats.Free;
  end;
end;

{ --- Snapshot computed properties --- }

procedure TestSnapshotAllocationRate;
var
  LStats: TAllocStatsAllocator;
  LPtr: Pointer;
  LSnap: TAllocSnapshot;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    LPtr := LStats.GetMem(100);
    LStats.FreeMem(LStats.GetMem(100));  // alloc + free
    LStats.FreeMem(LPtr);

    LSnap := LStats.Snapshot;
    // 2 allocs, 2 frees → rate = 2/4 = 0.5
    Check(Abs(LSnap.AllocationRate - 0.5) < 0.01, 'AllocationRate ~ 0.5');
  finally
    LStats.Free;
  end;
end;

{ --- Traits forwarding --- }

procedure TestTraitsForwards;
var
  LStats: TAllocStatsAllocator;
  LTraits: TAllocatorTraits;
begin
  LStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    LTraits := LStats.Traits;
    // RTL allocator traits
    Check(LTraits.SupportsRealloc, 'RTL supports realloc');
  finally
    LStats.Free;
  end;
end;

{ --- Multi-thread test --- }

var
  GStats: TAllocStatsAllocator;

function WorkerThread(Data: Pointer): Pointer; cdecl;
var
  LJ: Integer;
  LPtr: Pointer;
begin
  for LJ := 0 to 999 do
  begin
    LPtr := GStats.GetMem(64);
    if LPtr <> nil then
      GStats.FreeMem(LPtr);
  end;
  Result := nil;
end;

procedure TestConcurrentAlloc;
var
  LThreads: array[0..3] of TPlatformThreadRecord;
  LI: Integer;
  LSnap: TAllocSnapshot;
begin
  GStats := TAllocStatsAllocator.Create(GetRtlAllocator);
  try
    // 启动 4 个线程
    for LI := 0 to 3 do
      Check(platform_thread_spawn(LThreads[LI], @WorkerThread, nil) = 0,
        'spawn stats worker');

    // 等待完成
    for LI := 0 to 3 do
      Check(platform_thread_wait(LThreads[LI]) = 0, 'join stats worker');

    LSnap := GStats.Snapshot;
    Check(LSnap.TotalAllocs = 4000, 'TotalAllocs=4000 (4 threads * 1000)');
    Check(LSnap.TotalFrees = 4000, 'TotalFrees=4000');
    Check(LSnap.ActiveAllocs = 0, 'ActiveAllocs=0 after all free');
    Check(LSnap.PeakAllocs <= 4, 'PeakAllocs <= 4 (concurrent)');
  finally
    GStats.Free;
    GStats := nil;
  end;
end;

{ --- TAllocStatsCollector tests --- }

procedure TestCollectorInitiallyEmpty;
var
  LCollector: TAllocStatsCollector;
begin
  LCollector := TAllocStatsCollector.Create;
  try
    Check(LCollector.Count = 0, 'collector initially empty');
  finally
    LCollector.Free;
  end;
end;

procedure TestCollectorRegisterUnregister;
var
  LCollector: TAllocStatsCollector;
  LStats: TAllocStatsAllocator;
begin
  LCollector := TAllocStatsCollector.Create;
  try
    LStats := TAllocStatsAllocator.Create(GetRtlAllocator, False, LCollector);
    Check(LCollector.Count = 1, 'count=1 after register');
    LStats.Free;
    Check(LCollector.Count = 0, 'count=0 after unregister');
  finally
    LCollector.Free;
  end;
end;

procedure TestCollectorAggregates;
var
  LCollector: TAllocStatsCollector;
  LStats1, LStats2: TAllocStatsAllocator;
  LPtr1, LPtr2, LPtr3: Pointer;
  LSnap: TAllocSnapshot;
begin
  LCollector := TAllocStatsCollector.Create;
  try
    LStats1 := TAllocStatsAllocator.Create(GetRtlAllocator, False, LCollector);
    LStats2 := TAllocStatsAllocator.Create(GetRtlAllocator, False, LCollector);
    try
      LPtr1 := LStats1.GetMem(100);
      LPtr2 := LStats2.GetMem(200);
      LPtr3 := LStats1.GetMem(300);

      LSnap := LCollector.Collect;
      Check(LSnap.TotalAllocs = 3, 'collector: TotalAllocs=3');
      Check(LSnap.ActiveAllocs = 3, 'collector: ActiveAllocs=3');

      LStats1.FreeMem(LPtr1);
      LStats2.FreeMem(LPtr2);
      LStats1.FreeMem(LPtr3);

      LSnap := LCollector.Collect;
      Check(LSnap.TotalFrees = 3, 'collector: TotalFrees=3');
      Check(LSnap.ActiveAllocs = 0, 'collector: ActiveAllocs=0');

      LStats2.Free;
      LStats1.Free;
    except
      LStats2.Free;
      LStats1.Free;
      raise;
    end;
  finally
    LCollector.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.stats');

  T.Test('snapshot initially zero', @TestSnapshotInitiallyZero);
  T.Test('snapshot tracks alloc', @TestSnapshotTracksAlloc);
  T.Test('snapshot peak tracking', @TestSnapshotPeakTracking);
  T.Test('snapshot realloc', @TestSnapshotRealloc);
  T.Test('snapshot alloc_mem', @TestSnapshotAllocMem);
  T.Test('histogram disabled', @TestHistogramDisabled);
  T.Test('histogram buckets', @TestHistogramBuckets);
  T.Test('histogram mean size', @TestHistogramMeanSize);
  T.Test('histogram percentile', @TestHistogramPercentile);
  T.Test('reset stats', @TestResetStats);
  T.Test('reset stats preserves active allocations', @TestResetStatsPreservesActiveAllocations);
  T.Test('snapshot allocation rate', @TestSnapshotAllocationRate);
  T.Test('traits forwards', @TestTraitsForwards);
  T.Test('concurrent alloc', @TestConcurrentAlloc);
  T.Test('collector initially empty', @TestCollectorInitiallyEmpty);
  T.Test('collector register/unregister', @TestCollectorRegisterUnregister);
  T.Test('collector aggregates', @TestCollectorAggregates);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
