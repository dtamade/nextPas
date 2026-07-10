program test_aligned_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.aligned;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAlloc;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'allocated');
    Check(SizeUInt(LPtr) mod 64 = 0, '64-byte aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignment128;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 128);
  try
    LPtr := LAlloc.GetMem(64);
    Check(LPtr <> nil, 'allocated');
    Check(SizeUInt(LPtr) mod 128 = 0, '128-byte aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignment256;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 256);
  try
    LPtr := LAlloc.GetMem(16);
    Check(LPtr <> nil, 'allocated');
    Check(SizeUInt(LPtr) mod 256 = 0, '256-byte aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAlloc;
var
  LAlloc: TAlignedAllocator;
  LPtrs: array[0..3] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(32);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
      Check(SizeUInt(LPtrs[LIdx]) mod 64 = 0, 'aligned ' + IntToStr(LIdx));
    end;
    for LIdx := 0 to 3 do
      LAlloc.FreeMem(LPtrs[LIdx]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
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
  LAlloc: TAlignedAllocator;
  LStats: TAlignedStats;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(64);
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 2, 'allocs');
    Check(LStats.ActiveAllocs >= 2, 'active');
    Check(LStats.Alignment = 64, 'alignment');

    LAlloc.FreeMem(nil); // no-op
    LStats := LAlloc.GetStats;
    Check(LStats.FreeCount >= 0, 'frees');
  finally
    LAlloc.Free;
  end;
end;

procedure TestRealloc;
var
  LAlloc: TAlignedAllocator;
  LPtr, LNewPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    LPtr := LAlloc.GetMem(32);
    PByte(LPtr)^ := $EF;
    Check(SizeUInt(LPtr) mod 64 = 0, 'orig aligned');

    LNewPtr := LAlloc.ReallocMem(LPtr, 128);
    Check(LNewPtr <> nil, 'realloc ok');
    Check(SizeUInt(LNewPtr) mod 64 = 0, 'new aligned');
    Check(PByte(LNewPtr)^ = $EF, 'data preserved');
    LAlloc.FreeMem(LNewPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_aligned_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('Alignment128', @TestAlignment128);
  T.Test('Alignment256', @TestAlignment256);
  T.Test('MultipleAlloc', @TestMultipleAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Stats', @TestStats);
  T.Test('Realloc', @TestRealloc);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
