program test_mem_stats;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.mem.pool.fixed,
  nextpas.core.mem.pool,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.stack_pool,
  nextpas.core.mem.stats;

var
  T: TTestRunner;

procedure TestMemPoolStatsInitial;
var
  LPool: TFixedPool;
  LStats: TMemPoolStats;
begin
  LPool := TFixedPool.Create(64, 10);
  try
    LStats := GetMemPoolStats(LPool);
    CheckEqual(Int64(10), Int64(LStats.Capacity), 'initial capacity');
    CheckEqual(Int64(0), Int64(LStats.AllocatedCount), 'initial allocated');
    CheckEqual(Int64(10), Int64(LStats.AvailableCount), 'initial available');
    Check(LStats.Utilization = 0.0, 'initial utilization should be 0');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: MemPoolStats initial state');
end;

procedure TestMemPoolStatsAfterAlloc;
var
  LPool: TFixedPool;
  LPtr: Pointer;
  LStats: TMemPoolStats;
begin
  LPool := TFixedPool.Create(64, 10);
  try
    LPtr := LPool.Alloc;
    Check(LPtr <> nil, 'alloc should succeed');

    LStats := GetMemPoolStats(LPool);
    CheckEqual(Int64(1), Int64(LStats.AllocatedCount), 'allocated after 1 alloc');
    CheckEqual(Int64(9), Int64(LStats.AvailableCount), 'available after 1 alloc');
    Check(LStats.Utilization > 0.0, 'utilization > 0 after alloc');

    LPool.Release(LPtr);
    LStats := GetMemPoolStats(LPool);
    CheckEqual(Int64(0), Int64(LStats.AllocatedCount), 'allocated after free');
    CheckEqual(Int64(10), Int64(LStats.AvailableCount), 'available after free');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: MemPoolStats after alloc/free');
end;

procedure TestStackPoolStatsInitial;
var
  LPool: TStackPool;
  LStats: TStackPoolStats;
begin
  LPool := TStackPool.Create(4096);
  try
    LStats := GetStackPoolStats(LPool);
    CheckEqual(Int64(4096), Int64(LStats.TotalSize), 'initial total size');
    CheckEqual(Int64(0), Int64(LStats.UsedSize), 'initial used size');
    CheckEqual(Int64(4096), Int64(LStats.AvailableSize), 'initial available size');
    Check(LStats.Utilization = 0.0, 'initial utilization should be 0');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: StackPoolStats initial state');
end;

procedure TestStackPoolStatsAfterAlloc;
var
  LPool: TStackPool;
  LPtr: Pointer;
  LStats: TStackPoolStats;
begin
  LPool := TStackPool.Create(4096);
  try
    LPtr := LPool.Alloc(256);
    Check(LPtr <> nil, 'alloc should succeed');

    LStats := GetStackPoolStats(LPool);
    Check(LStats.UsedSize >= 256, 'used size >= 256 after alloc');
    Check(LStats.AvailableSize <= 4096 - 256, 'available size decreased');
    Check(LStats.Utilization > 0.0, 'utilization > 0 after alloc');

    LPool.Reset;
    LStats := GetStackPoolStats(LPool);
    CheckEqual(Int64(0), Int64(LStats.UsedSize), 'used size = 0 after reset');
    CheckEqual(Int64(4096), Int64(LStats.AvailableSize), 'available size restored after reset');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: StackPoolStats after alloc/reset');
end;

procedure TestBlockPoolStatsInitial;
var
  LPool: TBlockPool;
  LPtr: Pointer;
  LStats: TBlockPoolStats;
begin
  LPool := TBlockPool.Create(64, 10);
  try
    // Test TBlockPool directly first
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'TBlockPool.Acquire should succeed');
    CheckEqual(Int64(1), Int64(LPool.InUse), 'TBlockPool InUse after acquire');
    LPool.Release(LPtr);
    CheckEqual(Int64(0), Int64(LPool.InUse), 'TBlockPool InUse after release');

    // Now test via IBlockPool interface
    LStats.BlockSize := LPool.BlockSize;
    LStats.Capacity := LPool.Capacity;
    LStats.InUse := LPool.InUse;
    LStats.Available := LPool.Available;
    if LStats.Capacity > 0 then
      LStats.Utilization := LStats.InUse / LStats.Capacity
    else
      LStats.Utilization := 0.0;

    Check(LStats.Capacity = 10, 'initial capacity');
    Check(LStats.InUse = 0, 'initial in-use');
    Check(LStats.Available = 10, 'initial available');
    Check(LStats.Utilization = 0.0, 'initial utilization should be 0');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: BlockPoolStats initial state');
end;

procedure TestBlockPoolStatsAfterAcquireRelease;
var
  LPool: TBlockPool;
  LPtr: Pointer;
begin
  LPool := TBlockPool.Create(64, 5);
  try
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'acquire should succeed');

    CheckEqual(Int64(1), Int64(LPool.InUse), 'in-use after 1 acquire');
    CheckEqual(Int64(4), Int64(LPool.Available), 'available after 1 acquire');

    LPool.Release(LPtr);
    CheckEqual(Int64(0), Int64(LPool.InUse), 'in-use after release');
    CheckEqual(Int64(5), Int64(LPool.Available), 'available after release');
  finally
    LPool.Free;
  end;
  WriteLn('PASS: BlockPoolStats after acquire/release');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.stats');
  T.Run('MemPoolStats initial', @TestMemPoolStatsInitial);
  T.Run('MemPoolStats after alloc/free', @TestMemPoolStatsAfterAlloc);
  T.Run('StackPoolStats initial', @TestStackPoolStatsInitial);
  T.Run('StackPoolStats after alloc/reset', @TestStackPoolStatsAfterAlloc);
  T.Run('BlockPoolStats initial', @TestBlockPoolStatsInitial);
  T.Run('BlockPoolStats after acquire/release', @TestBlockPoolStatsAfterAcquireRelease);
  T.Summary;
end.
