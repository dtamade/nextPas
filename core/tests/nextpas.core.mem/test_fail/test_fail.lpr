{ nextpas - test: fail allocator }

{$I nextpas.core.settings.inc}

program test_fail;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.fail;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 0);
  try
    LPtr := LAlloc.GetMem(64);
    Assert(LPtr <> nil, 'alloc succeeds');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestFailOnNth;
var
  LAlloc: TFailAllocator;
  LPtr1, LPtr2, LPtr3: Pointer;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 2);
  try
    LPtr1 := LAlloc.GetMem(64);
    Assert(LPtr1 <> nil, 'first alloc succeeds');
    LPtr2 := LAlloc.GetMem(64);
    Assert(LPtr2 = nil, 'second alloc fails');
    LPtr3 := LAlloc.GetMem(64);
    Assert(LPtr3 <> nil, 'third alloc succeeds');
    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr3);
  finally
    LAlloc.Free;
  end;
end;

procedure TestFailAt1;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 1);
  try
    LPtr := LAlloc.GetMem(64);
    Assert(LPtr = nil, 'first alloc fails');
  finally
    LAlloc.Free;
  end;
end;

procedure TestNoFailureWhenZero;
var
  LAlloc: TFailAllocator;
  LPtrs: array[0..9] of Pointer;
  I: Integer;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 0);
  try
    for I := 0 to 9 do
    begin
      LPtrs[I] := LAlloc.GetMem(64);
      Assert(LPtrs[I] <> nil, 'alloc #' + IntToStr(I));
    end;
    for I := 0 to 9 do
      LAlloc.FreeMem(LPtrs[I]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TFailAllocator;
  LStats: TFailStats;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 2);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    Assert(LStats.TotalAttempts = 3, 'total attempts = 3');
    Assert(LStats.FailuresInjected = 1, 'failures = 1');
    Assert(LStats.SuccessfulAllocs = 2, 'success = 2');
  finally
    LAlloc.Free;
  end;
end;

procedure TestSetFailAt;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 0);
  try
    LPtr := LAlloc.GetMem(64);
    Assert(LPtr <> nil, 'alloc before set');
    LAlloc.FreeMem(LPtr);

    LAlloc.SetFailAt(1);
    LPtr := LAlloc.GetMem(64);
    Assert(LPtr = nil, 'alloc fails after set');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(DefaultAllocator, 2);
  try
    LPtr := LAlloc.AllocMem(64);
    Assert(LPtr <> nil, 'first allocmem succeeds');
    LPtr := LAlloc.AllocMem(64);
    Assert(LPtr = nil, 'second allocmem fails');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_fail');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('fail_on_nth', @TestFailOnNth);
  T.Test('fail_at_1', @TestFailAt1);
  T.Test('no_failure_when_zero', @TestNoFailureWhenZero);
  T.Test('stats', @TestStats);
  T.Test('set_fail_at', @TestSetFailAt);
  T.Test('alloc_mem', @TestAllocMem);
  T.Run;
  T.Summary;
end.
