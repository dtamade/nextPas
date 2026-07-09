program test_huge_page_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.huge_page;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: THugePageAllocator;
  LPtr: Pointer;
begin
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSmallAllocFallback;
var
  LAlloc: THugePageAllocator;
  LPtr: Pointer;
begin
  // Small allocs should go through inner allocator
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LPtr := LAlloc.GetMem(1024);
    Check(LPtr <> nil, 'small alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAllocFallback;
var
  LAlloc: THugePageAllocator;
  LPtr: Pointer;
begin
  // Large alloc may use huge page or fallback
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LPtr := LAlloc.GetMem(4 * 1024 * 1024);
    Check(LPtr <> nil, 'large alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: THugePageAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 2 * 1024 * 1024);
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

procedure TestStats;
var
  LAlloc: THugePageAllocator;
  LStats: THugePageStats;
begin
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    // Small alloc goes directly to inner, no fallback tracking
    Check(LStats.FallbackBytes = 0, 'no fallback for small');
  finally
    LAlloc.Free;
  end;
end;

procedure TestThreshold;
var
  LAlloc: THugePageAllocator;
begin
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 4096);
  try
    Check(LAlloc.Threshold = 4096, 'threshold set');
    Check(LAlloc.PageSize = hps2MB, 'page size set');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: THugePageAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := THugePageAllocator.Create(GetRtlAllocator, hps2MB, 2 * 1024 * 1024);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ThreadSafe, 'RTL allocator is not thread-safe');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_huge_page_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('SmallAllocFallback', @TestSmallAllocFallback);
  T.Test('LargeAllocFallback', @TestLargeAllocFallback);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Stats', @TestStats);
  T.Test('Threshold', @TestThreshold);
  T.Test('Traits', @TestTraits);
  T.Run;
  T.Summary;
end.
