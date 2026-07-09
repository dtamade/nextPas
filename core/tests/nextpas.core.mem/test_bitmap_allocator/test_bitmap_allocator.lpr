program test_bitmap_allocator;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.bitmap;

var
  T: TTestSuite;

procedure TestBasicAlloc;
var
  LAlloc: TBitmapAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 128);
  try
    LPtr := LAlloc.GetMem(32);
    Check(LPtr <> nil, 'allocated');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestSlotSize;
var
  LAlloc: TBitmapAllocator;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 128);
  try
    CheckEqual(LAlloc.SlotSize, SizeUInt(64), 'slot size');
    CheckEqual(LAlloc.SlotCount, SizeUInt(128), 'slot count');
  finally
    LAlloc.Free;
  end;
end;

procedure TestMultipleAlloc;
var
  LAlloc: TBitmapAllocator;
  LPtrs: array[0..3] of Pointer;
  LIdx: Integer;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 128);
  try
    for LIdx := 0 to 3 do
    begin
      LPtrs[LIdx] := LAlloc.GetMem(32);
      Check(LPtrs[LIdx] <> nil, 'alloc ' + IntToStr(LIdx));
    end;

    CheckEqual(LAlloc.UsedSlots, SizeUInt(4), '4 used');

    for LIdx := 0 to 3 do
      LAlloc.FreeMem(LPtrs[LIdx]);

    CheckEqual(LAlloc.UsedSlots, SizeUInt(0), 'all freed');
  finally
    LAlloc.Free;
  end;
end;

procedure TestAllocMemZeroed;
var
  LAlloc: TBitmapAllocator;
  LPtr: Pointer;
  LIdx: Integer;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 128);
  try
    LPtr := LAlloc.AllocMem(32);
    Check(LPtr <> nil, 'allocated');
    for LIdx := 0 to 31 do
      CheckEqual(PByte(LPtr)[LIdx], Byte(0), 'zeroed');
    LAlloc.FreeMem(LPtr);
  finally
    LAlloc.Free;
  end;
end;

procedure TestStats;
var
  LAlloc: TBitmapAllocator;
  LPtr: Pointer;
  LStats: TBitmapStats;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 128);
  try
    LPtr := LAlloc.GetMem(32);
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount >= 1, 'alloc count');
    Check(LStats.UsedSlots = 1, 'used slots');
    Check(LStats.FreeSlots = 127, 'free slots');

    LAlloc.FreeMem(LPtr);
    LStats := LAlloc.GetStats;
    Check(LStats.FreeCount >= 1, 'free count');
  finally
    LAlloc.Free;
  end;
end;

procedure TestExhaustSlots;
var
  LAlloc: TBitmapAllocator;
  LIdx: Integer;
  LPtr: Pointer;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 32);
  try
    for LIdx := 0 to 31 do
    begin
      LPtr := LAlloc.GetMem(32);
      Check(LPtr <> nil, 'slot ' + IntToStr(LIdx));
    end;

    // All slots exhausted
    LPtr := LAlloc.GetMem(32);
    Check(LPtr = nil, 'exhausted');
  finally
    LAlloc.Free;
  end;
end;

procedure TestOversizedAlloc;
var
  LAlloc: TBitmapAllocator;
  LPtr: Pointer;
begin
  LAlloc := TBitmapAllocator.Create(GetRtlAllocator, 64, 128);
  try
    // Request larger than slot size
    LPtr := LAlloc.GetMem(128);
    Check(LPtr = nil, 'oversized returns nil');
  finally
    LAlloc.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_bitmap_allocator');
  T.Test('BasicAlloc', @TestBasicAlloc);
  T.Test('SlotSize', @TestSlotSize);
  T.Test('MultipleAlloc', @TestMultipleAlloc);
  T.Test('AllocMemZeroed', @TestAllocMemZeroed);
  T.Test('Stats', @TestStats);
  T.Test('ExhaustSlots', @TestExhaustSlots);
  T.Test('OversizedAlloc', @TestOversizedAlloc);
  T.Run;
  T.Summary;
end.
