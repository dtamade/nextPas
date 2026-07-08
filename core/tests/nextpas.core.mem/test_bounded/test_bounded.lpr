{ nextpas - test: bounded allocator }

{$I nextpas.core.settings.inc}

program test_bounded;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.bounded;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 65536);
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
  LAlloc: TBoundedAllocator;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 65536);
  try
    Assert(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestExceedsLimit;
var
  LAlloc: TBoundedAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 100);
  try
    LPtr1 := LAlloc.GetMem(64);
    Assert(LPtr1 <> nil, 'first alloc succeeds');
    LPtr2 := LAlloc.GetMem(64);
    Assert(LPtr2 = nil, 'second alloc exceeds limit');
    LAlloc.FreeMem(LPtr1);
  finally
    LAlloc.Free;
  end;
end;

procedure TestExactLimit;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 64);
  try
    LPtr := LAlloc.GetMem(64);
    Assert(LPtr <> nil, 'exact limit succeeds');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TBoundedAllocator;
  LStats: TBoundedStats;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 1000);
  try
    LAlloc.GetMem(100);
    LAlloc.GetMem(200);
    LStats := LAlloc.GetStats;
    Assert(LStats.AllocCount = 2, 'alloc count = 2');
    Assert(LStats.ActiveBytes = 300, 'active = 300');
    Assert(LStats.PeakBytes = 300, 'peak = 300');
    Assert(LStats.LimitBytes = 1000, 'limit = 1000');
  finally
    LAlloc.Free;
  end;
end;

procedure TestSetLimit;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 65536);
  try
    LPtr := LAlloc.GetMem(100);
    Assert(LPtr <> nil, 'alloc before limit change');
    LAlloc.FreeMem(LPtr);

    LAlloc.SetLimit(50);
    LPtr := LAlloc.GetMem(100);
    Assert(LPtr = nil, 'alloc rejected after limit decrease');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPeakTracking;
var
  LAlloc: TBoundedAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(DefaultAllocator, 1000);
  try
    LPtr1 := LAlloc.GetMem(300);
    LPtr2 := LAlloc.GetMem(200);
    Assert(LAlloc.PeakBytes = 500, 'peak = 500');
    LAlloc.FreeMem(LPtr2);
    Assert(LAlloc.ActiveBytes = 300, 'active = 300 after free');
    Assert(LAlloc.PeakBytes = 500, 'peak unchanged');
    LAlloc.FreeMem(LPtr1);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_bounded');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('exceeds_limit', @TestExceedsLimit);
  T.Test('exact_limit', @TestExactLimit);
  T.Test('stats', @TestStats);
  T.Test('set_limit', @TestSetLimit);
  T.Test('peak_tracking', @TestPeakTracking);
  T.Run;
  T.Summary;
end.
