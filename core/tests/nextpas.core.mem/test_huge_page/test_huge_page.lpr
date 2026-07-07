program test_huge_page;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.huge_page,
  nextpas.core.mem.error;

procedure TestCreateAndDestroy;
var
  LHuge: THugePageAllocator;
begin
  LHuge := THugePageAllocator.Create(DefaultAllocator);
  try
    Check(LHuge.Inner <> nil, 'Inner should not be nil');
    Check(LHuge.PageSize = hps2MB, 'default page size should be 2MB');
    Check(LHuge.Threshold = 2 * 1024 * 1024, 'default threshold should be 2MB');
  finally
    LHuge.Free;
  end;
end;

procedure TestCustomThreshold;
var
  LHuge: THugePageAllocator;
begin
  LHuge := THugePageAllocator.Create(DefaultAllocator, hps2MB, 4 * 1024 * 1024);
  try
    Check(LHuge.Threshold = 4 * 1024 * 1024, 'threshold should be 4MB');
  finally
    LHuge.Free;
  end;
end;

procedure TestSmallAllocFallback;
var
  LHuge: THugePageAllocator;
  LPtr: Pointer;
  LStats: THugePageStats;
begin
  LHuge := THugePageAllocator.Create(DefaultAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LPtr := LHuge.GetMem(1024);
    Check(LPtr <> nil, 'small alloc should succeed');
    LHuge.FreeMem(LPtr);

    LStats := LHuge.GetStats;
    Check(LStats.HugePageCount = 0, 'no huge pages for small alloc');
  finally
    LHuge.Free;
  end;
end;

procedure TestLargeAllocMayUseHugePage;
var
  LHuge: THugePageAllocator;
  LPtr: Pointer;
  LStats: THugePageStats;
begin
  LHuge := THugePageAllocator.Create(DefaultAllocator, hps2MB, 1024);
  try
    LPtr := LHuge.GetMem(4096);
    Check(LPtr <> nil, 'large alloc should succeed');

    LStats := LHuge.GetStats;
    Check((LStats.HugePageCount > 0) or (LStats.Fallbacks > 0),
      'should attempt huge page or fallback');

    LHuge.FreeMem(LPtr);
  finally
    LHuge.Free;
  end;
end;

procedure TestStats;
var
  LHuge: THugePageAllocator;
  LStats: THugePageStats;
begin
  LHuge := THugePageAllocator.Create(DefaultAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LStats := LHuge.GetStats;
    Check(LStats.Allocated = 0, 'initial allocated should be 0');
    Check(LStats.Fallbacks = 0, 'initial fallbacks should be 0');
    Check(LStats.HugePageCount = 0, 'initial huge page count should be 0');
  finally
    LHuge.Free;
  end;
end;

procedure TestTraits;
var
  LHuge: THugePageAllocator;
  LTraits: TAllocatorTraits;
begin
  LHuge := THugePageAllocator.Create(DefaultAllocator);
  try
    LTraits := LHuge.Traits;
    Check(LTraits.ThreadSafe, 'should be thread-safe');
  finally
    LHuge.Free;
  end;
end;

procedure TestNilInnerRaises;
var
  LHuge: THugePageAllocator;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    LHuge := THugePageAllocator.Create(nil);
    LHuge.Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'should raise exception for nil inner');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('test_huge_page');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('custom_threshold', @TestCustomThreshold);
  T.Test('small_alloc_fallback', @TestSmallAllocFallback);
  T.Test('large_alloc_may_use_huge_page', @TestLargeAllocMayUseHugePage);
  T.Test('stats', @TestStats);
  T.Test('traits', @TestTraits);
  T.Test('nil_inner_raises', @TestNilInnerRaises);
  T.Run;
  T.Summary;
end.
