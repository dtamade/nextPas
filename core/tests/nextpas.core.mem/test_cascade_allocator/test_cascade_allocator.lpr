program test_cascade_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.cascade;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TCascadeAllocator;
  LPtr: Pointer;
begin
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator]);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAllocators;
var
  LAlloc: TCascadeAllocator;
  LPtr: Pointer;
begin
  // Create cascade with same allocator (simulating multiple backends)
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator, GetRtlAllocator]);
  try
    Check(LAlloc.AllocatorCount = 2, 'two allocators');
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TCascadeAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator]);
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

procedure TestFreeNil;
var
  LAlloc: TCascadeAllocator;
begin
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator]);
  try
    LAlloc.FreeMem(nil);
    Check(True, 'no crash on nil free');
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TCascadeAllocator;
  LStats: TCascadeStats;
begin
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator, GetRtlAllocator]);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(64);

    LStats := LAlloc.GetStats;
    Check(LStats.AllocAttempts >= 2, 'attempts');
    Check(LStats.AllocatorCount = 2, 'count');
    // First allocator should have gotten both allocations
    Check(LStats.AllocatorHits[0] >= 2, 'first allocator hits');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TCascadeAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator]);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $CC;

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(PByte(LNewPtr)^ = $CC, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestManyAllocs;
var
  LAlloc: TCascadeAllocator;
  LPtrs: array[0..7] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TCascadeAllocator.Create([GetRtlAllocator]);
  try
    for LIdx := 0 to 7 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(32);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;
    for LIdx := 0 to 7 do
      LAlloc.FreeMem(LPtrs[LIdx]);
    Check(True, 'all freed');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_cascade_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('MultipleAllocators', @TestMultipleAllocators);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('FreeNil', @TestFreeNil);
  T.Test('Stats', @TestStats);
  T.Test('Realloc', @TestRealloc);
  T.Test('ManyAllocs', @TestManyAllocs);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
