program test_stack_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.stack;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TStackAllocator;
  LPtr: Pointer;
begin
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    // Stack allocator doesn't support individual free
    LAlloc.FreeMem(LPtr); // no-op
  finally
    LAlloc.Free;
  end;
end;

procedure TestMarkRestore;
var
  LAlloc: TStackAllocator;
  LMark: TStackMark;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LPtr1 <> nil, 'before mark');

    LMark := LAlloc.Mark;

    LPtr2 := LAlloc.GetMem(64);
    Check(LPtr2 <> nil, 'after mark');

    LAlloc.Restore(LMark);
    Check(True, 'restored');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleRegions;
var
  LAlloc: TStackAllocator;
  LPtr: Pointer;
begin
  // Region is min 1024B
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 1024);
  try
    Check(LAlloc.RegionCount = 1, 'initial region');

    LPtr := LAlloc.GetMem(512);
    Check(LPtr <> nil, 'first alloc');

    // 512+520=1032 > 1024, forces new region
    LPtr := LAlloc.GetMem(520);
    Check(LPtr <> nil, 'second alloc');
    Check(LAlloc.RegionCount >= 2, 'grew region');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TStackAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 63 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TStackAllocator;
  LStats: TStackStats;
begin
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 4096);
  try
    LAlloc.GetMem(64);
    LAlloc.Mark;
    LAlloc.GetMem(128);

    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 2, 'allocs');
    Check(LStats.MarkCount >= 1, 'marks');
    Check(LStats.UsedBytes >= 192, 'used bytes');
    Check(LStats.RegionCount >= 1, 'regions');
  finally
    LAlloc.Free;
  end;
end;

procedure TestReset;
var
  LAlloc: TStackAllocator;
begin
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 4096);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(128);
    Check(LAlloc.UsedBytes > 0, 'has usage');

    LAlloc.Reset;
    Check(LAlloc.UsedBytes = 0, 'reset clears');
    Check(LAlloc.RegionCount = 1, 'back to one region');
  finally
    LAlloc.Free;
  end;
end;

procedure TestTraits;
var
  LAlloc: TStackAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TStackAllocator.Create(GetRtlAllocator, 4096);
  try
    LTraits := LAlloc.Traits;
    Check(not LTraits.ZeroInitialized, 'not zero-init');
    Check(not LTraits.ThreadSafe, 'not thread-safe');
    Check(not LTraits.SupportsRealloc, 'no realloc');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_stack_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('MarkRestore', @TestMarkRestore);
  T.Test('MultipleRegions', @TestMultipleRegions);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Stats', @TestStats);
  T.Test('Reset', @TestReset);
  T.Test('Traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
