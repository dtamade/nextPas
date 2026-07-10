program test_alignment_guarantee;
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

function IsAligned(APtr: Pointer; AAlign: SizeUInt): Boolean;
begin
  Result := (PtrUInt(APtr) mod AAlign) = 0;
end;

procedure TestDefaultAlignment;
var
  LAlloc: IAllocator;
  LPtrs: array[0..99] of Pointer;
  LI: Integer;
begin
  LAlloc := GetRtlAllocator;
  for LI := 0 to 99 do
  begin
    LPtrs[LI] := LAlloc.GetMem(32 + SizeUInt(LI));
    Check(LPtrs[LI] <> nil, 'Alloc #' + IntToStr(LI) + ' failed');
    Check(IsAligned(LPtrs[LI], 16), 'Default alloc should be 16-byte aligned');
  end;
  for LI := 0 to 99 do
    LAlloc.FreeMem(LPtrs[LI]);
end;

procedure TestAligned32;
var
  LAlloc: TAlignedAllocator;
  LPtrs: array[0..49] of Pointer;
  LI: Integer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 32);
  try
    for LI := 0 to 49 do
    begin
      LPtrs[LI] := LAlloc.GetMem(64);
      Check(LPtrs[LI] <> nil, 'Alloc #' + IntToStr(LI) + ' failed');
      Check(IsAligned(LPtrs[LI], 32), 'Should be 32-byte aligned');
    end;
    for LI := 0 to 49 do
      LAlloc.FreeMem(LPtrs[LI]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAligned64;
var
  LAlloc: TAlignedAllocator;
  LPtrs: array[0..49] of Pointer;
  LI: Integer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    for LI := 0 to 49 do
    begin
      LPtrs[LI] := LAlloc.GetMem(128);
      Check(LPtrs[LI] <> nil, 'Alloc #' + IntToStr(LI) + ' failed');
      Check(IsAligned(LPtrs[LI], 64), 'Should be 64-byte aligned');
    end;
    for LI := 0 to 49 do
      LAlloc.FreeMem(LPtrs[LI]);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAligned4096;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 4096);
  try
    LPtr := LAlloc.GetMem(4096);
    Check(LPtr <> nil, 'Page-aligned alloc should succeed');
    Check(IsAligned(LPtr, 4096), 'Should be page-aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignedAllocMemZeroed;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    LPtr := LAlloc.AllocMem(256);
    Check(LPtr <> nil, 'AllocMem should succeed');
    Check(IsAligned(LPtr, 64), 'AllocMem should be aligned');
    for LI := 0 to 255 do
      Check(PByte(LPtr)[LI] = 0, 'AllocMem should be zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignedSmallAlloc;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 128);
  try
    { Very small alloc should still be aligned }
    LPtr := LAlloc.GetMem(1);
    Check(LPtr <> nil, 'Small alloc should succeed');
    Check(IsAligned(LPtr, 128), 'Small alloc should still be 128-byte aligned');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestAlignedStats;
var
  LAlloc: TAlignedAllocator;
  LPtr: Pointer;
  LStats: TAlignedStats;
begin
  LAlloc := TAlignedAllocator.Create(GetRtlAllocator, 64);
  try
    LPtr := LAlloc.GetMem(128);
    Check(LPtr <> nil, 'Alloc should succeed');
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount > 0, 'Should track alloc count');
    Check(LStats.Alignment = 64, 'Should report alignment');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_alignment_guarantee');
  T.Test('DefaultAlignment', @TestDefaultAlignment);
  T.Test('Aligned32', @TestAligned32);
  T.Test('Aligned64', @TestAligned64);
  T.Test('Aligned4096', @TestAligned4096);
  T.Test('AlignedAllocMemZeroed', @TestAlignedAllocMemZeroed);
  T.Test('AlignedSmallAlloc', @TestAlignedSmallAlloc);
  T.Test('AlignedStats', @TestAlignedStats);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
