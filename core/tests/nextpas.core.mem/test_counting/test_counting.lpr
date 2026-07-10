program test_counting;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.intf,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.counting;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- 基础生命周期 Basic lifecycle --- }

procedure TestCreateDestroy;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      Check(LAlloc <> nil, 'created');
      Check(LAlloc.ActiveCount = 0, 'initial active=0');
      Check(LAlloc.PeakActiveCount = 0, 'initial peak=0');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMemIncrementsCount;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LP := LAlloc.GetMem(64);
      Check(LP <> nil, 'GetMem returned pointer');
      Check(LAlloc.ActiveCount = 1, 'active=1 after GetMem');
      Check(LAlloc.PeakActiveCount = 1, 'peak=1');
      LAlloc.FreeMem(LP);
      Check(LAlloc.ActiveCount = 0, 'active=0 after FreeMem');
      Check(LAlloc.PeakActiveCount = 1, 'peak stays 1');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestMultipleAllocations;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LP1, LP2, LP3: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LP1 := LAlloc.GetMem(32);
      LP2 := LAlloc.GetMem(64);
      LP3 := LAlloc.GetMem(128);
      Check(LAlloc.ActiveCount = 3, 'active=3');
      Check(LAlloc.PeakActiveCount = 3, 'peak=3');

      LAlloc.FreeMem(LP2);
      Check(LAlloc.ActiveCount = 2, 'active=2 after free');
      Check(LAlloc.PeakActiveCount = 3, 'peak stays 3');

      LAlloc.FreeMem(LP1);
      LAlloc.FreeMem(LP3);
      Check(LAlloc.ActiveCount = 0, 'active=0 after all freed');
      Check(LAlloc.PeakActiveCount = 3, 'peak stays 3');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestAllocMemIncrementsCount;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LP := LAlloc.AllocMem(64);
      Check(LP <> nil, 'AllocMem returned pointer');
      Check(LAlloc.ActiveCount = 1, 'active=1');
      LAlloc.FreeMem(LP);
      Check(LAlloc.ActiveCount = 0, 'active=0');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestReallocMemUpdatesCount;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LP: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LP := LAlloc.GetMem(32);
      Check(LAlloc.ActiveCount = 1, 'active=1');

      LP := LAlloc.ReallocMem(LP, 128);
      Check(LP <> nil, 'ReallocMem returned pointer');
      Check(LAlloc.ActiveCount = 1, 'active stays 1 after realloc');

      LAlloc.FreeMem(LP);
      Check(LAlloc.ActiveCount = 0, 'active=0');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestGetMemZeroReturnsNil;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      Check(LAlloc.GetMem(0) <> nil, 'GetMem(0) returns non-nil from RTL');
      Check(LAlloc.ActiveCount = 1, 'active=1 (RTL returns non-nil for 0)');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestFreeMemNilNoOp;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LAlloc.FreeMem(nil);
      Check(LAlloc.ActiveCount = 0, 'active stays 0 after FreeMem(nil)');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestPeakTracking;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LP1, LP2: Pointer;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LP1 := LAlloc.GetMem(32);
      LP2 := LAlloc.GetMem(64);
      Check(LAlloc.PeakActiveCount = 2, 'peak=2');

      LAlloc.FreeMem(LP1);
      Check(LAlloc.ActiveCount = 1, 'active=1');
      Check(LAlloc.PeakActiveCount = 2, 'peak stays 2');

      LP1 := LAlloc.GetMem(16);
      Check(LAlloc.ActiveCount = 2, 'active=2');
      Check(LAlloc.PeakActiveCount = 2, 'peak stays 2');

      LAlloc.FreeMem(LP1);
      LAlloc.FreeMem(LP2);
      Check(LAlloc.ActiveCount = 0, 'active=0');
      Check(LAlloc.PeakActiveCount = 2, 'peak stays 2');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestStatsRecord;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LP: Pointer;
  LStats: TCountingStats;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LP := LAlloc.GetMem(64);
      LStats := LAlloc.GetStats;
      Check(LStats.ActiveCount = 1, 'stats active=1');
      Check(LStats.PeakActiveCount = 1, 'stats peak=1');
      Check(LStats.AllocCount >= 1, 'stats total alloc >= 1');
      LAlloc.FreeMem(LP);
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

procedure TestTraits;
var
  LInner: IAllocator;
  LAlloc: TCountingAllocator;
  LTraits: TAllocatorTraits;
begin
  LInner := DefaultAllocator;
  try
    LAlloc := TCountingAllocator.Create(LInner);
    try
      LTraits := LAlloc.Traits;
      Check(LTraits.ThreadSafe = False, 'not thread-safe by default');
      Check(LTraits.SupportsRealloc = True, 'supports realloc');
    finally
      LAlloc.Free;
    end;
  finally
    
  end;
end;

{ --- 注册 Register --- }

begin
  T := TTestSuite.Create('test_counting');
  T.Test('create_destroy', @TestCreateDestroy);
  T.Test('getmem_increments_count', @TestGetMemIncrementsCount);
  T.Test('multiple_allocations', @TestMultipleAllocations);
  T.Test('allocmem_increments_count', @TestAllocMemIncrementsCount);
  T.Test('reallocmem_updates_count', @TestReallocMemUpdatesCount);
  T.Test('getmem_zero_returns_nil', @TestGetMemZeroReturnsNil);
  T.Test('freemem_nil_noop', @TestFreeMemNilNoOp);
  T.Test('peak_tracking', @TestPeakTracking);
  T.Test('stats_record', @TestStatsRecord);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
