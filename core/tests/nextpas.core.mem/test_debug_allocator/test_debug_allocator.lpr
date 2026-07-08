program test_debug_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.debug_alloc;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TDebugAllocator;
  LPtr: Pointer;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetMemWithSource;
var
  LAlloc: TDebugAllocator;
  LPtr: Pointer;
  LSource: TAllocSource;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
  try
    LPtr := LAlloc.GetMemWithSource(64, 'test.pas', 42);
    Check(LPtr <> nil, 'allocated');

    Check(LAlloc.GetSource(LPtr, LSource), 'source found');
    Check(LSource.FileName = 'test.pas', 'file name');
    Check(LSource.LineNum = 42, 'line number');
    Check(LSource.AllocSize = 64, 'alloc size');

    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TDebugAllocator;
  LStats: TDebugAllocStats;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(64);

    LStats := LAlloc.GetStats;
    Check(LStats.TotalAllocs >= 2, 'total allocs');
    Check(LStats.ActiveAllocs >= 2, 'active allocs');
    Check(LStats.PeakAllocs >= 2, 'peak allocs');
    Check(LStats.TotalBytes >= 96, 'total bytes');
    Check(LStats.ActiveBytes >= 96, 'active bytes');
    Check(LStats.TrackedCount >= 2, 'tracked');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReportLeaks;
var
  LAlloc: TDebugAllocator;
  LReport: string;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
  try
    LAlloc.GetMem(64);
    LReport := LAlloc.ReportLeaks;
    Check(Pos('block', LReport) > 0, 'has block info');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TDebugAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
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

procedure TestTraits;
var
  LAlloc: TDebugAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ZeroInitialized, 'not zero-init');
    Check(not LTraits.ThreadSafe, 'not thread-safe');
    Check(LTraits.SupportsRealloc, 'supports realloc');
  finally
    LAlloc.Free;
  end;
end;

procedure TestGetSourceNotFound;
var
  LAlloc: TDebugAllocator;
  LSource: TAllocSource;
begin
  LAlloc := TDebugAllocator.Create(GetRtlAllocator);
  try
    Check(not LAlloc.GetSource(nil, LSource), 'nil not found');
    Check(not LAlloc.GetSource(Pointer($1234), LSource), 'bad ptr not found');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_debug_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('GetMemWithSource', @TestGetMemWithSource);
  T.Test('Stats', @TestStats);
  T.Test('ReportLeaks', @TestReportLeaks);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Traits', @TestTraits);
  T.Test('GetSourceNotFound', @TestGetSourceNotFound);
  T.Run;
  T.Summary;
end.
