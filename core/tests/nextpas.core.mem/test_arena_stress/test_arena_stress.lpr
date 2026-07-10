program test_arena_stress;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.arena;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestManySmallAllocs;
var
  LAlloc: TVirtualArenaAllocator;
  LPtrs: array[0..999] of Pointer;
  LI: Integer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    for LI := 0 to 999 do
    begin
      LPtrs[LI] := LAlloc.GetMem(64);
      Check(LPtrs[LI] <> nil, 'Alloc #' + IntToStr(LI) + ' failed');
    end;
    { All pointers should be from the same arena }
    LAlloc.Reset;
    { Can allocate again after reset }
    for LI := 0 to 999 do
    begin
      LPtrs[LI] := LAlloc.GetMem(64);
      Check(LPtrs[LI] <> nil, 'Realloc after reset #' + IntToStr(LI) + ' failed');
    end;
  finally
    LAlloc.Free;
  end;
end;

procedure TestResetReclaim;
var
  LAlloc: TVirtualArenaAllocator;
  LPtr: Pointer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    LPtr := LAlloc.GetMem(4096);
    Check(LPtr <> nil, 'Alloc should succeed');

    LAlloc.Reset;
    { After reset, can allocate again }
    LPtr := LAlloc.GetMem(4096);
    Check(LPtr <> nil, 'Alloc after reset should succeed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMixedSizes;
var
  LAlloc: TVirtualArenaAllocator;
  LPtrs: array[0..99] of Pointer;
  LSizes: array[0..99] of SizeUInt;
  LI: Integer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    for LI := 0 to 99 do
    begin
      LSizes[LI] := 16 + SizeUInt(LI) * 8;
      LPtrs[LI] := LAlloc.GetMem(LSizes[LI]);
      Check(LPtrs[LI] <> nil, 'Mixed alloc #' + IntToStr(LI) + ' failed');
    end;
    { Verify data integrity }
    for LI := 0 to 99 do
      FillChar(LPtrs[LI]^, LSizes[LI], Byte(LI));
    for LI := 0 to 99 do
      Check(PByte(LPtrs[LI])^ = Byte(LI), 'Data corruption at index ' + IntToStr(LI));
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleResets;
var
  LAlloc: TVirtualArenaAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    for LI := 1 to 100 do
    begin
      LAlloc.GetMem(1024);
      LAlloc.Reset;
      { Verify arena is reusable after reset }
      LPtr := LAlloc.GetMem(64);
      Check(LPtr <> nil, 'Arena reusable after reset #' + IntToStr(LI));
    end;
  finally
    LAlloc.Free;
  end;
end;

procedure TestLargeAlloc;
var
  LAlloc: TVirtualArenaAllocator;
  LPtr: Pointer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    LPtr := LAlloc.GetMem(1024 * 1024); { 1MB }
    Check(LPtr <> nil, '1MB alloc should succeed');
    FillChar(LPtr^, 1024 * 1024, $AA);
    Check(PByte(LPtr)^ = $AA, 'Large alloc data should be writable');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TVirtualArenaAllocator;
  LPtr: Pointer;
  LI: Integer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    LPtr := LAlloc.AllocMem(256);
    Check(LPtr <> nil, 'AllocMem should succeed');
    for LI := 0 to 255 do
      Check(PByte(LPtr)[LI] = 0, 'AllocMem should be zeroed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestFragmentation;
var
  LAlloc: TVirtualArenaAllocator;
  LPtrs: array[0..199] of Pointer;
  LI: Integer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  try
    { Allocate many different sizes to stress alignment }
    for LI := 0 to 199 do
    begin
      LPtrs[LI] := LAlloc.GetMem(32 + SizeUInt(LI mod 7) * 16);
      Check(LPtrs[LI] <> nil, 'Fragmentation alloc #' + IntToStr(LI) + ' failed');
    end;
    { Verify allocations succeeded }
    for LI := 0 to 199 do
      Check(LPtrs[LI] <> nil, 'Fragmentation alloc #' + IntToStr(LI) + ' succeeded');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_arena_stress');
  T.Test('ManySmallAllocs', @TestManySmallAllocs);
  T.Test('ResetReclaim', @TestResetReclaim);
  T.Test('MixedSizes', @TestMixedSizes);
  T.Test('MultipleResets', @TestMultipleResets);
  T.Test('LargeAlloc', @TestLargeAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Fragmentation', @TestFragmentation);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
