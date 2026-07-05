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

{ NEW-023: 64 slot 全部分配/释放 + double-free 检测 + SpanFree 返回值 }
procedure TestSpanBitmapStress;
var
  LSpan: TSpan;
  LBuf: array[0..65535] of Byte;
  LPtrs: array[0..63] of Pointer;
  I: Integer;
begin
  { 分配所有 64 个 slot }
  SpanInit(LSpan, @LBuf[0], 1024, SPAN_MAX_SLOTS);
  for I := 0 to 63 do
  begin
    LPtrs[I] := SpanAlloc(LSpan);
    Check(LPtrs[I] <> nil, 'alloc #' + IntToStr(I) + ' non-nil');
  end;
  Check(LSpan.FFreeCount = 0, 'all 64 slots used');
  Check(not SpanHasFree(LSpan), 'no free after full alloc');
  Check(SpanAlloc(LSpan) = nil, 'alloc when full returns nil');

  { 释放所有 64 个 slot }
  for I := 0 to 63 do
    Check(SpanFree(LSpan, LPtrs[I]), 'free #' + IntToStr(I) + ' returns True');
  Check(LSpan.FFreeCount = 64, 'all 64 slots free');
  Check(SpanIsEmpty(LSpan), 'empty after free all');

  { double-free 检测: 再次释放 slot[0] 应返回 False }
  Check(not SpanFree(LSpan, LPtrs[0]), 'double-free returns False');
  Check(LSpan.FFreeCount = 64, 'free count unchanged after double-free');

  { 越界指针: 释放 span 范围外的指针应返回 False }
  Check(not SpanFree(LSpan, Pointer(PtrUInt($DEADBEEF))), 'out-of-range ptr returns False');
  Check(LSpan.FFreeCount = 64, 'free count unchanged after bad ptr');

  WriteLn('PASS: bitmap stress (64 alloc/free + double-free + oob)');
end;

{ NEW-023: 交错分配释放压力测试 }
procedure TestSpanInterleavedAllocFree;
var
  LSpan: TSpan;
  LBuf: array[0..65535] of Byte;
  LPtrs: array[0..63] of Pointer;
  I: Integer;
begin
  SpanInit(LSpan, @LBuf[0], 1024, 64);

  { 分配所有 }
  for I := 0 to 63 do
    LPtrs[I] := SpanAlloc(LSpan);

  { 交错释放：释放偶数 slot }
  for I := 0 to 63 do
    if I mod 2 = 0 then
      Check(SpanFree(LSpan, LPtrs[I]), 'free even #' + IntToStr(I));
  Check(LSpan.FFreeCount = 32, '32 slots freed (even)');

  { 重新分配应拿到偶数 slot 中的一个 }
  for I := 0 to 31 do
  begin
    LPtrs[I * 2] := SpanAlloc(LSpan);
    Check(LPtrs[I * 2] <> nil, 're-alloc even #' + IntToStr(I));
  end;
  Check(LSpan.FFreeCount = 0, 'full again');

  { 全部释放 }
  for I := 0 to 63 do
    SpanFree(LSpan, LPtrs[I]);
  Check(SpanIsEmpty(LSpan), 'empty after interleaved test');

  WriteLn('PASS: interleaved alloc/free stress');
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
  T.Test('bitmap_stress_64 (NEW-023)', @TestSpanBitmapStress);
  T.Test('interleaved_alloc_free (NEW-023)', @TestSpanInterleavedAllocFree);

  T.Run;
  T.Summary;
end.
