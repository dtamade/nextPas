{ nextpas - test: cascade allocator }

{$I nextpas.core.settings.inc}

program test_cascade;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.cascade;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TCascadeAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator]);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'alloc');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestZeroReturnsNil;
var
  LAlloc: TCascadeAllocator;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator]);
  try
    Check(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocators;
var
  LAlloc: TCascadeAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator, DefaultAllocator]);
  try
    LPtr1 := LAlloc.GetMem(64);
    Check(LPtr1 <> nil, 'alloc #1');
    LPtr2 := LAlloc.GetMem(64);
    Check(LPtr2 <> nil, 'alloc #2');
    LAlloc.FreeMem(LPtr1);
    LAlloc.FreeMem(LPtr2);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TCascadeAllocator;
  LStats: TCascadeStats;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator]);
  try
    LAlloc.GetMem(64);
    LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    Check(LStats.AllocAttempts = 2, 'attempts = 2');
    Check(LStats.AllocatorHits[0] = 2, 'hits[0] = 2');
    Check(LStats.AllocatorCount = 1, 'count = 1');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocatorCount;
var
  LAlloc: TCascadeAllocator;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator, DefaultAllocator, DefaultAllocator]);
  try
    Check(LAlloc.AllocatorCount = 3, 'count = 3');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFreeReleasesMemory;
var
  LAlloc: TCascadeAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator]);
  try
    LPtr := LAlloc.GetMem(256);
    Check(LPtr <> nil, 'alloc');
    LAlloc.FreeMem(LPtr);
    LPtr := LAlloc.GetMem(256);
    Check(LPtr <> nil, 're-alloc after free');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMem;
var
  LAlloc: TCascadeAllocator;
  LPtr: Pointer;
  I: Integer;
begin
  LAlloc := TCascadeAllocator.Create([DefaultAllocator]);
  try
    LPtr := LAlloc.AllocMem(64);
    Check(LPtr <> nil, 'allocmem');
    for I := 0 to 63 do
      Check(PByte(LPtr)[I] = 0, 'zero init');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_cascade');
  T.Test('basic_alloc', @TestBasicAlloc);
  T.Test('zero_returns_nil', @TestZeroReturnsNil);
  T.Test('multiple_allocators', @TestMultipleAllocators);
  T.Test('stats', @TestStats);
  T.Test('allocator_count', @TestAllocatorCount);
  T.Test('free_releases_memory', @TestFreeReleasesMemory);
  T.Test('alloc_mem', @TestAllocMem);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
