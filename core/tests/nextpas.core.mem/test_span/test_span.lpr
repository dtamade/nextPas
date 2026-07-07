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

{ === Multi-level span tests === }

procedure TestSpanLevel2Init;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS, 'level2 free count = ' + IntToStr(SPAN_LEVEL2_SLOTS));
  Check(LSpan.FSummaryBitmap = High(UInt64), 'summary bitmap all set');
  Check(SpanLevel2HasFree(LSpan), 'level2 has free');
  WriteLn('PASS: level2 init');
end;

procedure TestSpanLevel2Alloc;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
  LPtr: Pointer;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  LPtr := SpanLevel2Alloc(LSpan);
  Check(LPtr <> nil, 'level2 alloc returns non-nil');
  Check(LPtr = @LBuf[0], 'first alloc = base');
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS - 1, 'free count decreased');
  WriteLn('PASS: level2 alloc');
end;

procedure TestSpanLevel2AllocAll;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
  I: Integer;
  LPtr: Pointer;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  for I := 0 to SPAN_LEVEL2_SLOTS - 1 do
  begin
    LPtr := SpanLevel2Alloc(LSpan);
    Check(LPtr <> nil, 'level2 alloc #' + IntToStr(I) + ' non-nil');
  end;
  Check(LSpan.FFreeCount = 0, 'level2 full');
  Check(not SpanLevel2HasFree(LSpan), 'no free after full');
  { Next alloc should return nil. }
  Check(SpanLevel2Alloc(LSpan) = nil, 'alloc when full returns nil');
  WriteLn('PASS: level2 alloc all');
end;

procedure TestSpanLevel2Free;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
  LPtr1, LPtr2: Pointer;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  LPtr1 := SpanLevel2Alloc(LSpan);
  LPtr2 := SpanLevel2Alloc(LSpan);
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS - 2, 'free count after 2 allocs');
  SpanLevel2Free(LSpan, LPtr1);
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS - 1, 'free count after 1 free');
  { Alloc again should return the freed slot. }
  Check(SpanLevel2Alloc(LSpan) = LPtr1, 're-alloc returns freed slot');
  WriteLn('PASS: level2 free');
end;

procedure TestSpanLevel2FreeAll;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
  LPtrs: array[0..SPAN_LEVEL2_SLOTS - 1] of Pointer;
  I: Integer;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  for I := 0 to SPAN_LEVEL2_SLOTS - 1 do
    LPtrs[I] := SpanLevel2Alloc(LSpan);
  Check(LSpan.FFreeCount = 0, 'level2 full');
  for I := 0 to SPAN_LEVEL2_SLOTS - 1 do
    SpanLevel2Free(LSpan, LPtrs[I]);
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS, 'level2 all freed');
  Check(SpanLevel2HasFree(LSpan), 'level2 has free after free all');
  WriteLn('PASS: level2 free all');
end;

procedure TestSpanLevel2DoubleFree;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
  LPtr: Pointer;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  LPtr := SpanLevel2Alloc(LSpan);
  SpanLevel2Free(LSpan, LPtr);
  { Double-free should return False. }
  Check(not SpanLevel2Free(LSpan, LPtr), 'double-free returns False');
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS, 'free count unchanged after double-free');
  WriteLn('PASS: level2 double-free detection');
end;

procedure TestSpanLevel2OutOfBounds;
var
  LSpan: TSpanLevel2;
  LBuf: array[0..SPAN_LEVEL2_SLOTS * 64 - 1] of Byte;
begin
  SpanLevel2Init(LSpan, @LBuf[0], 64);
  { Out-of-bounds pointer should return False. }
  Check(not SpanLevel2Free(LSpan, Pointer(PtrUInt($DEADBEEF))), 'out-of-bounds ptr returns False');
  Check(LSpan.FFreeCount = SPAN_LEVEL2_SLOTS, 'free count unchanged after bad ptr');
  WriteLn('PASS: level2 out-of-bounds detection');
end;

procedure TestSpanLevel3Init;
var
  LSpan: TSpanLevel3;
  LBuf: array[0..1024 * 1024 - 1] of Byte; { 1MB buffer for test }
begin
  { Use small slot size to fit in 1MB buffer. }
  SpanLevel3Init(LSpan, @LBuf[0], 4);
  Check(LSpan.FFreeCount = SPAN_LEVEL3_SLOTS, 'level3 free count = ' + IntToStr(SPAN_LEVEL3_SLOTS));
  Check(LSpan.FSummaryBitmap = High(UInt64), 'summary bitmap all set');
  Check(SpanLevel3HasFree(LSpan), 'level3 has free');
  WriteLn('PASS: level3 init');
end;

procedure TestSpanLevel3Alloc;
var
  LSpan: TSpanLevel3;
  LBuf: array[0..1024 * 1024 - 1] of Byte; { 1MB buffer for test }
  LPtr: Pointer;
begin
  { Use small slot size to fit in 1MB buffer. }
  SpanLevel3Init(LSpan, @LBuf[0], 4);
  LPtr := SpanLevel3Alloc(LSpan);
  Check(LPtr <> nil, 'level3 alloc returns non-nil');
  Check(LPtr = @LBuf[0], 'first alloc = base');
  Check(LSpan.FFreeCount = SPAN_LEVEL3_SLOTS - 1, 'free count decreased');
  WriteLn('PASS: level3 alloc');
end;

procedure TestSpanLevel3SmallAlloc;
{ Test allocating a few slots from level3 (not all 262144). }
var
  LSpan: TSpanLevel3;
  LBuf: array[0..1024 * 1024 - 1] of Byte; { 1MB buffer for test }
  LPtrs: array[0..9] of Pointer;
  I: Integer;
begin
  { Use small slot size to fit in 1MB buffer. }
  SpanLevel3Init(LSpan, @LBuf[0], 4);
  for I := 0 to 9 do
  begin
    LPtrs[I] := SpanLevel3Alloc(LSpan);
    Check(LPtrs[I] <> nil, 'level3 alloc #' + IntToStr(I) + ' non-nil');
  end;
  Check(LSpan.FFreeCount = SPAN_LEVEL3_SLOTS - 10, 'free count after 10 allocs');
  { Free all. }
  for I := 0 to 9 do
    Check(SpanLevel3Free(LSpan, LPtrs[I]), 'level3 free #' + IntToStr(I));
  Check(LSpan.FFreeCount = SPAN_LEVEL3_SLOTS, 'level3 all freed');
  WriteLn('PASS: level3 small alloc');
end;

procedure TestSpanLevel3DoubleFree;
var
  LSpan: TSpanLevel3;
  LBuf: array[0..1024 * 1024 - 1] of Byte;
  LPtr: Pointer;
begin
  SpanLevel3Init(LSpan, @LBuf[0], 4);
  LPtr := SpanLevel3Alloc(LSpan);
  SpanLevel3Free(LSpan, LPtr);
  { Double-free should return False. }
  Check(not SpanLevel3Free(LSpan, LPtr), 'double-free returns False');
  Check(LSpan.FFreeCount = SPAN_LEVEL3_SLOTS, 'free count unchanged after double-free');
  WriteLn('PASS: level3 double-free detection');
end;

procedure TestSpanLevel3OutOfBounds;
var
  LSpan: TSpanLevel3;
  LBuf: array[0..1024 * 1024 - 1] of Byte;
begin
  SpanLevel3Init(LSpan, @LBuf[0], 4);
  { Out-of-bounds pointer should return False. }
  Check(not SpanLevel3Free(LSpan, Pointer(PtrUInt($DEADBEEF))), 'out-of-bounds ptr returns False');
  Check(LSpan.FFreeCount = SPAN_LEVEL3_SLOTS, 'free count unchanged after bad ptr');
  WriteLn('PASS: level3 out-of-bounds detection');
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

  { Multi-level span tests }
  T.Test('level2_init', @TestSpanLevel2Init);
  T.Test('level2_alloc', @TestSpanLevel2Alloc);
  T.Test('level2_alloc_all', @TestSpanLevel2AllocAll);
  T.Test('level2_free', @TestSpanLevel2Free);
  T.Test('level2_free_all', @TestSpanLevel2FreeAll);
  T.Test('level2_double_free', @TestSpanLevel2DoubleFree);
  T.Test('level2_out_of_bounds', @TestSpanLevel2OutOfBounds);
  T.Test('level3_init', @TestSpanLevel3Init);
  T.Test('level3_alloc', @TestSpanLevel3Alloc);
  T.Test('level3_small_alloc', @TestSpanLevel3SmallAlloc);
  T.Test('level3_double_free', @TestSpanLevel3DoubleFree);
  T.Test('level3_out_of_bounds', @TestSpanLevel3OutOfBounds);

  T.Run;
  T.Summary;
end.
