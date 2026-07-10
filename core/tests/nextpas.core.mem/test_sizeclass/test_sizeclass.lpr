program test_sizeclass;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.sizeclass;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ --- SizeClassIndex tests --- }

procedure TestMinSize;
var
  LIdx: Int32;
begin
  LIdx := SizeClassIndex(1);
  Check(LIdx = 0, 'size 1 -> index 0 (rounded to 16B)');
  LIdx := SizeClassIndex(16);
  Check(LIdx = 0, 'size 16 -> index 0');
  WriteLn('PASS: min size');
end;

procedure TestBand0;
var
  LIdx: Int32;
begin
  { 16B-256B, 16B step: indices 0..15 }
  LIdx := SizeClassIndex(16);
  Check(LIdx = 0, '16 -> 0');
  LIdx := SizeClassIndex(32);
  Check(LIdx = 1, '32 -> 1');
  LIdx := SizeClassIndex(100);
  Check(LIdx = 6, '100 -> 6 (rounds up to 112)');
  LIdx := SizeClassIndex(256);
  Check(LIdx = 15, '256 -> 15');
  WriteLn('PASS: band 0');
end;

procedure TestBand1;
var
  LIdx: Int32;
begin
  { 256B-1KB, 64B step: indices 16..28 }
  LIdx := SizeClassIndex(257);
  Check(LIdx = 17, '257 -> 17 (rounds to 320)');
  LIdx := SizeClassIndex(320);
  Check(LIdx = 17, '320 -> 17');
  LIdx := SizeClassIndex(512);
  Check(LIdx = 20, '512 -> 20');
  LIdx := SizeClassIndex(1024);
  Check(LIdx = 28, '1024 -> 28');
  WriteLn('PASS: band 1');
end;

procedure TestBand2;
var
  LIdx: Int32;
begin
  { 1KB-4KB, 256B step: indices 29..41 }
  LIdx := SizeClassIndex(1025);
  Check(LIdx = 30, '1025 -> 30 (class=1280)');
  LIdx := SizeClassIndex(2048);
  Check(LIdx = 33, '2048 -> 33');
  LIdx := SizeClassIndex(4096);
  Check(LIdx = 41, '4096 -> 41');
  WriteLn('PASS: band 2');
end;

procedure TestBand3;
var
  LIdx: Int32;
begin
  { 4KB-8KB, 1KB step: indices 42..46 }
  LIdx := SizeClassIndex(4097);
  Check(LIdx = 43, '4097 -> 43 (class=5120)');
  LIdx := SizeClassIndex(8192);
  Check(LIdx = 46, '8192 -> 46 (class=8192)');
  WriteLn('PASS: band 3');
end;

procedure TestBand4;
var
  LIdx: Int32;
begin
  { 8KB-16KB, 2KB step: indices 47..51 }
  LIdx := SizeClassIndex(8193);
  Check(LIdx = 48, '8193 -> 48 (class=10240)');
  LIdx := SizeClassIndex(16384);
  Check(LIdx = 51, '16384 -> 51 (class=16384)');
  WriteLn('PASS: band 4');
end;

procedure TestBand5;
var
  LIdx: Int32;
begin
  { 16KB-53KB, 4KB step: indices 52..61 }
  LIdx := SizeClassIndex(16385);
  Check(LIdx = 53, '16385 -> 53 (class=20480)');
  LIdx := SizeClassIndex(32768);
  Check(LIdx = 56, '32768 -> 56 (class=32768)');
  LIdx := SizeClassIndex(53248);
  Check(LIdx = 61, '53248 -> 61 (band 5 last)');
  WriteLn('PASS: band 5');
end;

procedure TestBand6;
var
  LIdx: Int32;
begin
  { 53KB-65KB, 2KB step: indices 62..68.
    Note: 53248 = BAND5_MAX = BAND6_MIN, so 53248 maps to index 61 (band 5).
    Band 6 first unique size = 55296 (index 63). }
  LIdx := SizeClassIndex(55296);
  Check(LIdx = 63, '55296 -> 63 (class=55296)');
  LIdx := SizeClassIndex(65536);
  Check(LIdx = 68, '65536 -> 68 (last class)');
  WriteLn('PASS: band 6');
end;

procedure TestOversized;
begin
  Check(SizeClassIndex(65537) = -1, '65537 -> -1 (mmap)');
  Check(SizeClassIndex(1024 * 1024) = -1, '1MB -> -1 (mmap)');
  Check(SizeClassIndex(High(SizeUInt)) = -1, 'max -> -1 (mmap)');
  WriteLn('PASS: oversized');
end;

{ --- SizeClassSize tests --- }

procedure TestSizeClassSizeTable;
var
  I: Int32;
  LPrev, LCur: SizeUInt;
begin
  { Table must be monotonically non-decreasing (band boundaries share value 256). }
  LPrev := 0;
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    LCur := SizeClassSize(I);
    Check(LCur >= LPrev, 'sizeclass[' + IntToStr(I) + '] monotonic');
    LPrev := LCur;
  end;
  { First entry = 16, last entry = 65536. }
  Check(SizeClassSize(0) = 16, 'first = 16');
  Check(SizeClassSize(MEM_SIZECLASS_COUNT - 1) = 65536, 'last = 65536');
  WriteLn('PASS: sizeclass table monotonic');
end;

procedure TestSizeClassSizeBoundary;
begin
  Check(SizeClassSize(-1) = 0, 'invalid index -1 -> 0');
  Check(SizeClassSize(MEM_SIZECLASS_COUNT) = 0, 'invalid index 58 -> 0');
  WriteLn('PASS: sizeclass boundary');
end;

{ --- Round-trip: index → size >= original --- }

procedure TestRoundTrip;
var
  LSize: SizeUInt;
  LIdx: Int32;
  LClassSize: SizeUInt;
  LFailures: SizeUInt;
begin
  { Every size from 1 to 1024 should round-trip: index → class size >= original. }
  LFailures := 0;
  for LSize := 1 to 1024 do
  begin
    LIdx := SizeClassIndex(LSize);
    if LIdx < 0 then
    begin
      Inc(LFailures);
      Continue;
    end;
    LClassSize := SizeClassSize(LIdx);
    if LClassSize < LSize then
      Inc(LFailures);
  end;
  Check(LFailures = 0, 'round-trip 1..1024: ' + IntToStr(LFailures) + ' failures');
  WriteLn('PASS: round-trip 1..1024');
end;

procedure TestRoundTripLarge;
var
  LSize: SizeUInt;
  LIdx: Int32;
  LClassSize: SizeUInt;
  LFailures: SizeUInt;
begin
  { Spot-check larger sizes at band boundaries. }
  LFailures := 0;
  LSize := 1024;
  while LSize <= 65536 do
  begin
    LIdx := SizeClassIndex(LSize);
    if LIdx < 0 then
    begin
      Inc(LFailures);
      Break;
    end;
    LClassSize := SizeClassSize(LIdx);
    if LClassSize < LSize then
      Inc(LFailures);
    LSize := LSize + 256;
  end;
  Check(LFailures = 0, 'round-trip large: ' + IntToStr(LFailures) + ' failures');
  WriteLn('PASS: round-trip large');
end;

{ --- Fragmentation analysis --- }

procedure TestFragmentation;
var
  I: Int32;
  LSize, LClassSize: SizeUInt;
  LWaste, LMaxWaste: Double;
begin
  { Internal fragmentation = (class_size - requested) / requested.
    Worst case per class = largest size that maps to this class = SizeClasses[I-1]+1.
    Band 0 worst: (32-17)/17 = 88% (tiny allocs, expected).
    Band 1+ worst: (320-257)/257 = 24.5%. Accept ≤ 35%. }
  { Start from band 1 (index 16) to check 256B+ fragmentation. }
  LMaxWaste := 0;
  for I := 16 to MEM_SIZECLASS_COUNT - 1 do
  begin
    { Worst case: one byte above previous class. }
    LSize := SizeClasses[I - 1] + 1;
    LClassSize := SizeClasses[I];
    if LSize > LClassSize then
      Continue; { Band boundary overlap (256 in both bands), skip. }
    LWaste := (Double(LClassSize) - Double(LSize)) / Double(LSize) * 100.0;
    if LWaste > LMaxWaste then
      LMaxWaste := LWaste;
  end;
  { Band 1+ worst case: 257B → 320B = 24.5% waste. Accept ≤ 35%. }
  Check(LMaxWaste <= 35.0, 'band 1+ max fragmentation: ' + IntToStr(Trunc(LMaxWaste)) + '%');
  WriteLn('PASS: fragmentation band 1+ ≤ 35%');
end;

{ --- IsSizeClassable --- }

procedure TestIsSizeClassable;
begin
  Check(IsSizeClassable(16), '16 is sizeclassable');
  Check(IsSizeClassable(65536), '65536 is sizeclassable');
  Check(not IsSizeClassable(65537), '65537 is not sizeclassable');
  WriteLn('PASS: IsSizeClassable');
end;

{ --- Go 68-class comparison --- }

procedure TestGoComparison;
{ Go's size classes (subset for comparison):
  8, 16, 24, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240, 256
  Our band 0: 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240, 256
  Go has 8B class (we don't). We match 16B-256B exactly. }
begin
  Check(SizeClassIndex(8) = 0, '8B rounds to 16B (index 0)');
  Check(SizeClassSize(0) = 16, 'our smallest class = 16B');
  { Go 16B class → our 16B class: exact match. }
  Check(SizeClassIndex(16) = 0, '16B exact match with Go');
  { Go 256B class → our 256B class: exact match. }
  Check(SizeClassIndex(256) = 15, '256B exact match with Go');
  WriteLn('PASS: Go comparison');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('sizeclass');

  T.Test('min_size', @TestMinSize);
  T.Test('band_0', @TestBand0);
  T.Test('band_1', @TestBand1);
  T.Test('band_2', @TestBand2);
  T.Test('band_3', @TestBand3);
  T.Test('band_4', @TestBand4);
  T.Test('band_5', @TestBand5);
  T.Test('band_6', @TestBand6);
  T.Test('oversized', @TestOversized);
  T.Test('sizeclass_table', @TestSizeClassSizeTable);
  T.Test('sizeclass_boundary', @TestSizeClassSizeBoundary);
  T.Test('round_trip_small', @TestRoundTrip);
  T.Test('round_trip_large', @TestRoundTripLarge);
  T.Test('fragmentation', @TestFragmentation);
  T.Test('is_sizeclassable', @TestIsSizeClassable);
  T.Test('go_comparison', @TestGoComparison);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
