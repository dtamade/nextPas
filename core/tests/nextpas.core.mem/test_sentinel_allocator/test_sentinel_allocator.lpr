program test_sentinel_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.sentinel;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 0);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestQuarantine;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 16);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'allocated');

    LAlloc.FreeMem(LPtr);
    // Should be in quarantine, not yet freed
    Check(LAlloc.QuarantineCount >= 1, 'in quarantine');

    LAlloc.DrainQuarantine;
    Check(LAlloc.QuarantineCount = 0, 'drained');
  finally
    LAlloc.Free;
  end;
end;

procedure TestNoQuarantine;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
begin
  // QuarantineDepth=0 means immediate free
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 0);
  try
    LPtr := LAlloc.GetMem(32);
    LAlloc.FreeMem(LPtr);
    Check(LAlloc.QuarantineCount = 0, 'no quarantine');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TSentinelAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 0);
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

procedure TestMultipleAllocs;
var
  LAlloc: TSentinelAllocator;
  LPtrs: array[0..3] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 32);
  try
    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(32);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;
    for LIdx := 0 to 3 do
      LAlloc.FreeMem(LPtrs[LIdx]);
    Check(LAlloc.QuarantineCount >= 4, '4 in quarantine');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TSentinelAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 0);
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

procedure TestTraits;
var
  LAlloc: TSentinelAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TSentinelAllocator.Create(GetRtlAllocator, 16);
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ThreadSafe, 'thread-safe (delegated from RTL)');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_sentinel_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('Quarantine', @TestQuarantine);
  T.Test('NoQuarantine', @TestNoQuarantine);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('MultipleAllocs', @TestMultipleAllocs);
  T.Test('Realloc', @TestRealloc);
  T.Test('Traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
