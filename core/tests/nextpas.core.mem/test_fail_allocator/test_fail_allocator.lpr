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
  LPtr: Pointer;
begin
  // Fail on 3rd allocation
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 3);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, '1st ok');

    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, '2nd ok');

    LPtr := LAlloc.GetMem(32);
    Check(LPtr = nil, '3rd fails');

    // After failing, should succeed again
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, '4th ok');
    LAlloc.FreeMem(LPtr);
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
  LStats: TFailStats;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator, 2);
  try
    LAlloc.GetMem(32);  // ok
    LAlloc.GetMem(32);  // fails
    LAlloc.GetMem(32);  // ok

    LStats := LAlloc.GetStats;
    Check(LStats.TotalAttempts >= 3, 'attempts');
    Check(LStats.FailuresInjected >= 1, 'failures');
    Check(LStats.SuccessfulAllocs >= 2, 'successes');
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

    // FailAt is cumulative attempt counter; after 1 attempt, fail on next
    LAlloc.SetFailAt(2);
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
