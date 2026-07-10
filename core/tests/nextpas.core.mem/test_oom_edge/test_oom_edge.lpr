program test_oom_edge;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.bounded,
  nextpas.core.mem.allocator.counting,
  nextpas.core.mem.allocator.fail;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBoundedReturnsNil;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 256);
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'First alloc should succeed');
    LPtr := LAlloc.GetMem(200);
    Check(LPtr = nil, 'Exceeding limit should return nil');
    LAlloc.FreeMem(LPtr); { Free nil is no-op }
  finally
    LAlloc.Free;
  end;
end;

procedure TestBoundedTracksPeak;
var
  LAlloc: TBoundedAllocator;
  LPtr1, LPtr2: Pointer;
  LStats: TBoundedStats;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr1 := LAlloc.GetMem(256);
    LPtr2 := LAlloc.GetMem(256);
    LStats := LAlloc.GetStats;
    Check(LStats.ActiveBytes = 512, 'ActiveBytes should be 512');
    Check(LStats.PeakBytes = 512, 'PeakBytes should be 512');

    LAlloc.FreeMem(LPtr1);
    LStats := LAlloc.GetStats;
    Check(LStats.ActiveBytes = 256, 'ActiveBytes should be 256 after free');
    Check(LStats.PeakBytes = 512, 'PeakBytes should remain 512');

    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBoundedExactLimit;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 128);
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'Exact limit alloc should succeed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestCountingTracksAllocs;
var
  LAlloc: TCountingAllocator;
  LPtrs: array[0..9] of Pointer;
  LI: Integer;
begin
  LAlloc := TCountingAllocator.Create(GetRtlAllocator);
  try
    for LI := 0 to 9 do
      LPtrs[LI] := LAlloc.GetMem(64);

    Check(LAlloc.ActiveCount = 10, 'ActiveCount should be 10');

    for LI := 0 to 4 do
      LAlloc.FreeMem(LPtrs[LI]);

    Check(LAlloc.ActiveCount = 5, 'ActiveCount should be 5 after partial free');

    for LI := 5 to 9 do
      LAlloc.FreeMem(LPtrs[LI]);

    Check(LAlloc.ActiveCount = 0, 'ActiveCount should be 0 after all freed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFailAllocatorAtN;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
  LGotException: Boolean;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator);
  try
    LAlloc.FailAt := 3;
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'Alloc 1 should succeed');
    LAlloc.FreeMem(LPtr);

    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'Alloc 2 should succeed');
    LAlloc.FreeMem(LPtr);

    LGotException := False;
    try
      LPtr := LAlloc.GetMem(64);
      if LPtr = nil then
        LGotException := True
      else
        LAlloc.FreeMem(LPtr);
    except
      on E: Exception do
        LGotException := True;
    end;
    Check(LGotException, 'Alloc 3 should fail');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFailAllocatorReset;
var
  LAlloc: TFailAllocator;
  LPtr: Pointer;
begin
  LAlloc := TFailAllocator.Create(GetRtlAllocator);
  try
    LAlloc.FailAt := 2;
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'Alloc 1 should succeed');
    LAlloc.FreeMem(LPtr);

    try
      LPtr := LAlloc.GetMem(64);
      if LPtr <> nil then
        LAlloc.FreeMem(LPtr);
    except
    end;

    { Set new fail point and try again }
    LAlloc.FailAt := 4; { Next attempt is #3, will succeed; #4 will fail }
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'Alloc after SetFailAt should succeed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestBoundedSetLimit;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr := LAlloc.GetMem(512);
    Check(LPtr <> nil, 'Alloc within limit should succeed');
    LAlloc.FreeMem(LPtr);

    { Reduce limit }
    LAlloc.SetLimit(256);
    LPtr := LAlloc.GetMem(512);
    Check(LPtr = nil, 'Alloc exceeding new limit should fail');

    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'Alloc within new limit should succeed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_oom_edge');
  T.Test('BoundedReturnsNil', @TestBoundedReturnsNil);
  T.Test('BoundedTracksPeak', @TestBoundedTracksPeak);
  T.Test('BoundedExactLimit', @TestBoundedExactLimit);
  T.Test('CountingTracksAllocs', @TestCountingTracksAllocs);
  T.Test('FailAllocatorAtN', @TestFailAllocatorAtN);
  T.Test('FailAllocatorReset', @TestFailAllocatorReset);
  T.Test('BoundedSetLimit', @TestBoundedSetLimit);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
