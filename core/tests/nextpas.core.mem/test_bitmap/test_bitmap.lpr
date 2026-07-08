{ nextpas - test: bitmap allocator }

{$I nextpas.core.settings.inc}

program test_bitmap;

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.bitmap;

procedure Test_BasicAlloc;
var
  LAlloc: TBitmapAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 128);
  try
    LPtr1 := LAlloc.GetMem(32);
    Check(LPtr1 <> nil, 'alloc 32B');
    LPtr2 := LAlloc.GetMem(64);
    Check(LPtr2 <> nil, 'alloc 64B');
    Check(LPtr1 <> LPtr2, 'different pointers');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_ZeroReturnsNil;
var
  LAlloc: TBitmapAllocator;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 128);
  try
    Check(LAlloc.GetMem(0) = nil, 'zero alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_ExceedSlotReturnsNil;
var
  LAlloc: TBitmapAllocator;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 128);
  try
    Check(LAlloc.GetMem(128) = nil, 'oversized alloc returns nil');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_FreeAndReuse;
var
  LAlloc: TBitmapAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 128);
  try
    LPtr1 := LAlloc.GetMem(32);
    Check(LPtr1 <> nil, 'alloc');
    LAlloc.FreeMem(LPtr1);
    LPtr2 := LAlloc.GetMem(32);
    Check(LPtr2 <> nil, 'reuse freed slot');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_ExhaustSlots;
var
  LAlloc: TBitmapAllocator;
  LPtrs: array[0..31] of Pointer;
  I: Integer;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 32);
  try
    for I := 0 to 31 do
    begin
      LPtrs[I] := LAlloc.GetMem(32);
      Check(LPtrs[I] <> nil, 'slot ' + IntToStr(I));
    end;
    Check(LAlloc.GetMem(32) = nil, 'all slots exhausted');
  finally
    for I := 0 to 31 do
      LAlloc.FreeMem(LPtrs[I]);
    LAlloc.Free;
  end;
end;

procedure Test_Stats;
var
  LAlloc: TBitmapAllocator;
  LStats: TBitmapStats;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 128);
  try
    LAlloc.GetMem(32);
    LAlloc.GetMem(32);
    LStats := LAlloc.GetStats;
    Check(LStats.AllocCount = 2, 'alloc count = 2');
    Check(LStats.UsedSlots = 2, 'used = 2');
    Check(LStats.FreeSlots = 126, 'free = 126');
    Check(LStats.SlotSize = 64, 'slot size = 64');
  finally
    LAlloc.Free;
  end;
end;

procedure Test_UsedSlotsTracking;
var
  LAlloc: TBitmapAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LAlloc := TBitmapAllocator.Create(DefaultAllocator, 64, 128);
  try
    Check(LAlloc.UsedSlots = 0, 'initially 0');
    LPtr1 := LAlloc.GetMem(32);
    Check(LAlloc.UsedSlots = 1, 'used = 1');
    LPtr2 := LAlloc.GetMem(32);
    Check(LAlloc.UsedSlots = 2, 'used = 2');
    LAlloc.FreeMem(LPtr1);
    Check(LAlloc.UsedSlots = 1, 'used = 1 after free');
    LAlloc.FreeMem(LPtr2);
    Check(LAlloc.UsedSlots = 0, 'used = 0 after both free');
  finally
    LAlloc.Free;
  end;
end;

var T: TTestSuite;
begin
  T := TTestSuite.Create('test_bitmap');
  T.Test('basic_alloc', @Test_BasicAlloc);
  T.Test('zero_returns_nil', @Test_ZeroReturnsNil);
  T.Test('exceed_slot_returns_nil', @Test_ExceedSlotReturnsNil);
  T.Test('free_and_reuse', @Test_FreeAndReuse);
  T.Test('exhaust_slots', @Test_ExhaustSlots);
  T.Test('stats', @Test_Stats);
  T.Test('used_slots_tracking', @Test_UsedSlotsTracking);
  T.Run;
  T.Summary;
end.
