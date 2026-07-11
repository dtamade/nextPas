program test_fail_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.fail;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestNoFailure;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  // FailAt=0 means never fail
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 0);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestFailAtN;
var
  LAlloc: TFailAllocator;
  LPtr1, LPtr2, LPtr4: Pointer;
begin
  // Fail on 3rd allocation
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 3);
  try
    LPtr1 := LAlloc.GetMem(32);
    Check(LPtr1 <> nil, '1st ok');

    LPtr2 := LAlloc.GetMem(32);
    Check(LPtr2 <> nil, '2nd ok');

    LPtr4 := LAlloc.GetMem(32);
    Check(LPtr4 = nil, '3rd fails');

    // After failing, should succeed again
    LPtr4 := LAlloc.GetMem(32);
    Check(LPtr4 <> nil, '4th ok');
    LAlloc.FreeMem(LPtr4);
    LAlloc.FreeMem(LPtr2);
    LAlloc.FreeMem(LPtr1);
  finally
    LAlloc.Free;
  end;
end;

procedure TestFailOnFirst;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 1);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr = nil, '1st fails');

    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, '2nd ok');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TFailAllocator;
  LPtr1, LPtr2, LPtr3: Pointer;
  LStats: TFailStats;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 2);
  try
    LPtr1 := LAlloc.GetMem(32);  // ok
    LPtr2 := LAlloc.GetMem(32);  // fails
    LPtr3 := LAlloc.GetMem(32);  // ok

    LStats := LAlloc.GetStats;
    Check(LStats.TotalAttempts >= 3, 'attempts');
    Check(LStats.FailuresInjected >= 1, 'failures');
    Check(LStats.SuccessfulAllocs >= 2, 'successes');
    LAlloc.FreeMem(LPtr3);
    LAlloc.FreeMem(LPtr2);
    LAlloc.FreeMem(LPtr1);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSetFailAt;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 0);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'no fail initially');
    LAlloc.FreeMem(LPtr);

    // SetFailAt resets counter; fail on next allocation
    LAlloc.SetFailAt(1);
    LPtr := LAlloc.GetMem(32);
    Check(LPtr = nil, 'fails after set');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemFail;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 1);
  try
    LPtr := LAlloc.AllocMem(32);
    Check(LPtr = nil, 'AllocMem also fails');

    LPtr := LAlloc.AllocMem(32);
    Check(LPtr <> nil, '2nd AllocMem ok');
    // Should be zeroed
    Check(PByte(LPtr)^ = 0, 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestReallocFail;
var
  LAlloc: TFailAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 2);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'initial ok');

    // This realloc should be the 2nd attempt and fail
    LNewPtr := LAlloc.ReallocMem(LPtr, 64);
    Check(LNewPtr = nil, 'realloc failed');

    // Original still valid
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_fail_allocator');
  T.Test('NoFailure', @TestNoFailure);
  T.Test('FailAtN', @TestFailAtN);
  T.Test('FailOnFirst', @TestFailOnFirst);
  T.Test('Stats', @TestStats);
  T.Test('SetFailAt', @TestSetFailAt);
  T.Test('AllocMemFail', @TestAllocMemFail);
  T.Test('ReallocFail', @TestReallocFail);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
