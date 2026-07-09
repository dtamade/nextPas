program test_bounded_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.bounded;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestLimitEnforced;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 128);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'first alloc ok');

    LPtr := LAlloc.GetMem(128);
    Check(LPtr = nil, 'over limit rejected');
  finally
    LAlloc.Free;
  end;
end;

procedure TestActiveBytes;
var
  LAlloc: TBoundedAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LAlloc.ActiveBytes = 64, '64 active');

    LPtr2 := LAlloc.GetMem(32);
    Check(LAlloc.ActiveBytes = 96, '96 active');

    LAlloc.FreeMem(LPtr1);
    Check(LAlloc.ActiveBytes = 32, '32 after free');

    LAlloc.FreeMem(LPtr2);
    Check(LAlloc.ActiveBytes = 0, '0 after all free');
  finally
    LAlloc.Free;
  end;
end;

procedure TestPeakBytes;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr := LAlloc.GetMem(100);
    Check(LAlloc.PeakBytes = 100, 'peak 100');

    LAlloc.FreeMem(LPtr);
    // Peak should still be 100
    Check(LAlloc.PeakBytes = 100, 'peak stays 100');

    LPtr := LAlloc.GetMem(200);
    Check(LAlloc.PeakBytes = 200, 'peak 200');
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
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 256);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(32);
    LAlloc.GetMem(512); // rejected

    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 2, 'allocs');
    Check(LStats.RejectedCount >= 1, 'rejected');
    Check(LStats.ActiveBytes >= 96, 'active');
    Check(LStats.LimitBytes = 256, 'limit');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSetLimit;
var
  LAlloc: TBoundedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBoundedAllocator.Create(GetRtlAllocator, 1024);
  try
    LPtr := LAlloc.GetMem(256);
    Check(LPtr <> nil, 'before limit change');
    LAlloc.FreeMem(LPtr);

    // Reduce limit
    LAlloc.SetLimit(64);
    LPtr := LAlloc.GetMem(128);
    Check(LPtr = nil, 'rejected after limit change');

    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'ok within new limit');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_bounded_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('LimitEnforced', @TestLimitEnforced);
  T.Test('ActiveBytes', @TestActiveBytes);
  T.Test('PeakBytes', @TestPeakBytes);
  T.Test('Stats', @TestStats);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('SetLimit', @TestSetLimit);
  T.Run;
  T.Summary;
end.
