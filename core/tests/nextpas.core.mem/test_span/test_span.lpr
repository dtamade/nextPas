program test_span;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.span;

var
  T: TTestSuite;

procedure TestSpanInit;
var
  LSpan: TSpan;
  LBuf: array[0..4095] of Byte;
begin
  SpanInit(LSpan, @LBuf[0], 64, 16);
  Check(LSpan.FSlotCount = 16, 'slot count = 16');
  Check(LSpan.FFreeCount = 16, 'all slots free');
  Check(LSpan.FSlotSize = 64, 'slot size = 64');
  Check(SpanIsEmpty(LSpan), 'span is empty');
  Check(SpanHasFree(LSpan), 'span has free');
  WriteLn('PASS: span init');
end;

procedure TestSpanAllocOne;
var
  LSpan: TSpan;
  LBuf: array[0..4095] of Byte;
  LPtr: Pointer;
begin
  SpanInit(LSpan, @LBuf[0], 64, 16);
  LPtr := SpanAlloc(LSpan);
  Check(LPtr <> nil, 'alloc returns non-nil');
  Check(LPtr = @LBuf[0], 'first alloc = base');
  Check(LSpan.FFreeCount = 15, 'free count = 15');
  Check(not SpanIsEmpty(LSpan), 'not empty after alloc');
  WriteLn('PASS: span alloc one');
end;

procedure TestSpanAllocAll;
var
  LSpan: TSpan;
  LBuf: array[0..4095] of Byte;
  I: Integer;
  LPtrs: array[0..15] of Pointer;
begin
  SpanInit(LSpan, @LBuf[0], 64, 16);
  for I := 0 to 15 do
  begin
    LPtrs[I] := SpanAlloc(LSpan);
    Check(LPtrs[I] <> nil, 'alloc ' + IntToStr(I) + ' non-nil');
  end;
  Check(LSpan.FFreeCount = 0, 'all slots used');
  Check(not SpanHasFree(LSpan), 'no free slots');
  { Next alloc should return nil. }
  Check(SpanAlloc(LSpan) = nil, 'alloc when full returns nil');
  WriteLn('PASS: span alloc all');
end;

procedure TestSpanFree;
var
  LSpan: TSpan;
  LBuf: array[0..4095] of Byte;
  LPtr1, LPtr2: Pointer;
begin
  SpanInit(LSpan, @LBuf[0], 64, 16);
  LPtr1 := SpanAlloc(LSpan);
  LPtr2 := SpanAlloc(LSpan);
  Check(LSpan.FFreeCount = 14, 'free = 14 after 2 allocs');
  SpanFree(LSpan, LPtr1);
  Check(LSpan.FFreeCount = 15, 'free = 15 after 1 free');
  Check(SpanHasFree(LSpan), 'has free');
  { Alloc again should return the freed slot. }
  Check(SpanAlloc(LSpan) = LPtr1, 're-alloc returns freed slot');
  WriteLn('PASS: span free');
end;

procedure TestSpanFreeAll;
var
  LSpan: TSpan;
  LBuf: array[0..4095] of Byte;
  LPtrs: array[0..15] of Pointer;
  I: Integer;
begin
  SpanInit(LSpan, @LBuf[0], 64, 16);
  for I := 0 to 15 do
    LPtrs[I] := SpanAlloc(LSpan);
  Check(LSpan.FFreeCount = 0, 'full');
  for I := 0 to 15 do
    SpanFree(LSpan, LPtrs[I]);
  Check(LSpan.FFreeCount = 16, 'all freed');
  Check(SpanIsEmpty(LSpan), 'empty after free all');
  WriteLn('PASS: span free all');
end;

procedure TestSpanDifferentSlotSizes;
var
  LSpan: TSpan;
  LBuf: array[0..8191] of Byte;
  LPtr1, LPtr2: Pointer;
begin
  { 32-byte slots in 8KB buffer = 256 slots, but capped at 64. }
  SpanInit(LSpan, @LBuf[0], 32, 64);
  Check(LSpan.FSlotCount = 64, 'capped at 64');
  LPtr1 := SpanAlloc(LSpan);
  LPtr2 := SpanAlloc(LSpan);
  Check(PByte(LPtr2) - PByte(LPtr1) = 32, 'slots are 32 bytes apart');
  WriteLn('PASS: different slot sizes');
end;

procedure TestSpanMaxSlots;
var
  LSpan: TSpan;
  LBuf: array[0..65535] of Byte;
begin
  SpanInit(LSpan, @LBuf[0], 1024, SPAN_MAX_SLOTS);
  Check(LSpan.FSlotCount = 64, 'max slots = 64');
  Check(LSpan.FFreeCount = 64, 'all free');
  WriteLn('PASS: max slots');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('span');

  T.Test('span_init', @TestSpanInit);
  T.Test('span_alloc_one', @TestSpanAllocOne);
  T.Test('span_alloc_all', @TestSpanAllocAll);
  T.Test('span_free', @TestSpanFree);
  T.Test('span_free_all', @TestSpanFreeAll);
  T.Test('different_slot_sizes', @TestSpanDifferentSlotSizes);
  T.Test('max_slots', @TestSpanMaxSlots);

  T.Run;
  T.Summary;
end.
