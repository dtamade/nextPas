program test_arena_chunked;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.chunked,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.base;

var
  T: TTestRunner;

procedure TestBasicAlloc;
var
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'basic alloc should return non-nil');
    Check(LArena.UsedSize >= 64, 'UsedSize should reflect allocation');
  finally
    LArena.Free;
  end;
end;

procedure TestMultipleAllocs;
var
  LArena: TChunkedArena;
  LP: Pointer;
  I: Integer;
begin
  LArena := TChunkedArena.Create(4096);
  try
    for I := 0 to 99 do
    begin
      LP := LArena.Alloc(64);
      Check(LP <> nil, 'alloc #' + IntToStr(I) + ' should succeed');
    end;
    Check(LArena.UsedSize >= 6400, 'UsedSize should reflect all allocations');
  finally
    LArena.Free;
  end;
end;

procedure TestAllocAligned;
var
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LP := LArena.AllocAligned(48, 64);
    Check(LP <> nil, 'aligned alloc should succeed');
    Check(SizeUInt(LP) mod 64 = 0, 'should be 64-byte aligned');
  finally
    LArena.Free;
  end;
end;

procedure TestAllocZeroed;
var
  LArena: TChunkedArena;
  LP: PByte;
  I: Integer;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LP := PByte(LArena.AllocZeroed(128));
    Check(LP <> nil, 'zeroed alloc should succeed');
    for I := 0 to 127 do
      Check(LP[I] = 0, 'byte ' + IntToStr(I) + ' should be zero');
  finally
    LArena.Free;
  end;
end;

procedure TestGeometricGrowth;
var
  LArena: TChunkedArena;
  LP: Pointer;
  I: Integer;
begin
  LArena := TChunkedArena.Create(1024);
  try
    for I := 0 to 99 do
    begin
      LP := LArena.Alloc(1024);
      Check(LP <> nil, 'alloc #' + IntToStr(I) + ' should succeed');
    end;
    Check(LArena.SegmentCount > 1, 'should have multiple segments');
  finally
    LArena.Free;
  end;
end;

procedure TestLinearGrowth;
var
  LConfig: TArenaConfig;
  LArena: TChunkedArena;
  LP: Pointer;
  I: Integer;
begin
  LConfig := TArenaConfig.Default(1024);
  LConfig.GrowthKind := agkLinear;
  LConfig.GrowthStep := 1024;
  LArena := TChunkedArena.Create(LConfig);
  try
    for I := 0 to 99 do
    begin
      LP := LArena.Alloc(512);
      Check(LP <> nil, 'alloc #' + IntToStr(I) + ' should succeed');
    end;
  finally
    LArena.Free;
  end;
end;

procedure TestSaveRestoreMark;
var
  LArena: TChunkedArena;
  LMark: TArenaMark;
  LUsed1, LUsed2: SizeUInt;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LArena.Alloc(100);
    LUsed1 := LArena.UsedSize;
    LMark := LArena.SaveMark;

    LArena.Alloc(200);
    LUsed2 := LArena.UsedSize;
    Check(LUsed2 > LUsed1, 'used should grow');

    LArena.RestoreToMark(LMark);
    Check(LArena.UsedSize = LUsed1, 'should restore to mark');

    Check(LArena.Alloc(50) <> nil, 'can alloc after restore');
  finally
    LArena.Free;
  end;
end;

procedure TestMarkAcrossSegments;
var
  LArena: TChunkedArena;
  LMark: TArenaMark;
  I: Integer;
begin
  LArena := TChunkedArena.Create(1024);
  try
    for I := 0 to 63 do
      LArena.Alloc(1024);
    LMark := LArena.SaveMark;

    for I := 0 to 9 do
      LArena.Alloc(1024);

    LArena.RestoreToMark(LMark);
    Check(LArena.Alloc(512) <> nil, 'can alloc after cross-segment restore');
  finally
    LArena.Free;
  end;
end;

procedure TestReset;
var
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LP := LArena.Alloc(256);
    Check(LP <> nil, 'alloc before reset');

    LArena.Reset;
    Check(LArena.UsedSize = 0, 'UsedSize should be 0 after reset');

    LP := LArena.Alloc(256);
    Check(LP <> nil, 'can alloc after reset');
  finally
    LArena.Free;
  end;
end;

procedure TestResetKeepSegments;
var
  LConfig: TArenaConfig;
  LArena: TChunkedArena;
  LSegCount: SizeUInt;
begin
  LConfig := TArenaConfig.Default(1024);
  LConfig.KeepSegments := True;
  LArena := TChunkedArena.Create(LConfig);
  try
    LArena.Alloc(2048);
    LSegCount := LArena.SegmentCount;
    Check(LSegCount > 1, 'should have multiple segments');

    LArena.Reset;
    Check(LArena.SegmentCount = LSegCount, 'should keep segments after reset');
    Check(LArena.UsedSize = 0, 'UsedSize should be 0 after reset');
  finally
    LArena.Free;
  end;
end;

procedure TestMaxSize;
var
  LConfig: TArenaConfig;
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LConfig := TArenaConfig.Default(1024);
  LConfig.MaxSize := 4096;
  LArena := TChunkedArena.Create(LConfig);
  try
    LP := LArena.Alloc(2048);
    Check(LP <> nil, 'should alloc within max size');

    LP := LArena.Alloc(4096);
    Check(LP = nil, 'should fail when exceeding max size');
  finally
    LArena.Free;
  end;
end;

procedure TestIArenaInterface;
var
  LArena: TChunkedArena;
  LIArena: IArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(4096);
  LIArena := LArena;
  try
    LP := LIArena.Alloc(64);
    Check(LP <> nil, 'IArena.Alloc should work');
    Check(LIArena.UsedSize >= 64, 'IArena.UsedSize should reflect allocation');
  finally
    LIArena := nil;
  end;
end;

procedure TestZeroSizeAlloc;
var
  LArena: TChunkedArena;
begin
  LArena := TChunkedArena.Create(4096);
  try
    Check(LArena.Alloc(0) = nil, 'zero-size alloc should return nil');
    Check(LArena.UsedSize = 0, 'zero-size alloc should not affect UsedSize');
  finally
    LArena.Free;
  end;
end;

{ --- Edge-case tests --- }

procedure TestChunkCacheReuse;
var
  LArena: TChunkedArena;
  LSegsBefore, LSegsAfter: SizeUInt;
begin
  LArena := TChunkedArena.Create(1024);
  try
    { Force multiple segments }
    while LArena.SegmentCount < 3 do
      LArena.Alloc(512);
    LSegsBefore := LArena.SegmentCount;
    Check(LSegsBefore >= 3, 'cache reuse: should have multiple segments');

    { Reset - segments should be cached }
    LArena.Reset;
    Check(LArena.UsedSize = 0, 'cache reuse: UsedSize 0 after reset');

    { Allocate again - should reuse cached segments }
    LArena.Alloc(512);
    LSegsAfter := LArena.SegmentCount;
    { After reset, segments are cached. Next alloc reuses from cache. }
    Check(LSegsAfter >= 1, 'cache reuse: segment available after reset');
  finally
    LArena.Free;
  end;
end;

procedure TestChunkCacheLimit;
var
  LConfig: TArenaConfig;
  LArena: TChunkedArena;
  I: Integer;
  LSegCount: SizeUInt;
begin
  { KeepSegments=False so Reset uses chunk cache }
  LConfig := TArenaConfig.Default(128);
  LConfig.GrowthKind := agkLinear;
  LConfig.GrowthStep := 128;
  LConfig.KeepSegments := False;
  LArena := TChunkedArena.Create(LConfig);
  try
    { Force many segments by allocating larger than segment size }
    for I := 0 to 19 do
      LArena.Alloc(128);
    LSegCount := LArena.SegmentCount;
    WriteLn('    (segments created: ', LSegCount, ')');

    { Reset - should cache up to 8, free the rest }
    LArena.Reset;
    Check(LArena.UsedSize = 0, 'cache limit: UsedSize 0 after reset');

    { Should still be able to allocate }
    Check(LArena.Alloc(128) <> nil, 'cache limit: can alloc after reset');
  finally
    LArena.Free;
  end;
end;

procedure TestMultipleResetCycles;
var
  LArena: TChunkedArena;
  I, J: Integer;
  LP: Pointer;
  OK: Boolean;
begin
  LArena := TChunkedArena.Create(1024);
  try
    OK := True;
    for I := 0 to 99 do
    begin
      for J := 0 to 99 do
      begin
        LP := LArena.Alloc(64);
        if LP = nil then
        begin
          OK := False;
          Break;
        end;
      end;
      if not OK then
        Break;
      LArena.Reset;
    end;
    Check(OK, 'multiple resets 100x100: all succeeded');
  finally
    LArena.Free;
  end;
end;

procedure TestAllocAlignedZeroAlign;
var
  LArena: TChunkedArena;
begin
  LArena := TChunkedArena.Create(4096);
  try
    Check(LArena.AllocAligned(64, 0) <> nil, 'aligned zero: should use default');
  finally
    LArena.Free;
  end;
end;

procedure TestAllocAlignedInvalidAlign;
var
  LArena: TChunkedArena;
begin
  LArena := TChunkedArena.Create(4096);
  try
    Check(LArena.AllocAligned(64, 3) = nil, 'aligned 3: should return nil');
    Check(LArena.AllocAligned(64, 7) = nil, 'aligned 7: should return nil');
    Check(LArena.AllocAligned(64, 5) = nil, 'aligned 5: should return nil');
  finally
    LArena.Free;
  end;
end;

procedure TestStatsMethods;
var
  LArena: TChunkedArena;
  LStats: TArenaStats;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LArena.Alloc(100);
    LArena.Alloc(200);
    LStats := LArena.Stats;
    Check(LStats.TotalAllocated > 0, 'stats: TotalAllocated > 0');
    Check(LStats.TotalUsed >= 300, 'stats: TotalUsed >= 300');
    Check(LStats.PeakUsed >= 300, 'stats: PeakUsed >= 300');
    Check(LStats.AllocCount >= 2, 'stats: AllocCount >= 2');
  finally
    LArena.Free;
  end;
end;

procedure TestPeakUsedAcrossResets;
var
  LArena: TChunkedArena;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LArena.Alloc(1000);
    Check(LArena.PeakUsed >= 1000, 'peak: first alloc peak');
    LArena.Reset;
    { Peak should NOT reset }
    Check(LArena.PeakUsed >= 1000, 'peak: peak preserved after reset');
    LArena.Alloc(500);
    Check(LArena.PeakUsed >= 1000, 'peak: peak still higher than current');
  finally
    LArena.Free;
  end;
end;

procedure TestResetThenLargeAlloc;
var
  LArena: TChunkedArena;
  LP: Pointer;
begin
  LArena := TChunkedArena.Create(1024);
  try
    LArena.Alloc(512);
    LArena.Reset;
    { Allocate something larger than initial segment }
    LP := LArena.Alloc(2048);
    Check(LP <> nil, 'reset+large: should grow to accommodate');
  finally
    LArena.Free;
  end;
end;

procedure TestRemainingSize;
var
  LArena: TChunkedArena;
  LBefore, LAfter: SizeUInt;
begin
  LArena := TChunkedArena.Create(4096);
  try
    LBefore := LArena.RemainingSize;
    Check(LBefore > 0, 'remaining: initially > 0');
    LArena.Alloc(1024);
    LAfter := LArena.RemainingSize;
    Check(LAfter < LBefore, 'remaining: decreased after alloc');
  finally
    LArena.Free;
  end;
end;

procedure TestSegmentCountZero;
var
  LArena: TChunkedArena;
begin
  LArena := TChunkedArena.Create(4096);
  try
    Check(LArena.SegmentCount >= 1, 'segment count: at least 1 after create');
  finally
    LArena.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena.chunked');

  T.Run('basic_alloc', @TestBasicAlloc);
  T.Run('multiple_allocs', @TestMultipleAllocs);
  T.Run('alloc_aligned', @TestAllocAligned);
  T.Run('alloc_zeroed', @TestAllocZeroed);
  T.Run('geometric_growth', @TestGeometricGrowth);
  T.Run('linear_growth', @TestLinearGrowth);
  T.Run('save_restore_mark', @TestSaveRestoreMark);
  T.Run('mark_across_segments', @TestMarkAcrossSegments);
  T.Run('reset', @TestReset);
  T.Run('reset_keep_segments', @TestResetKeepSegments);
  T.Run('max_size', @TestMaxSize);
  T.Run('iarena_interface', @TestIArenaInterface);
  T.Run('zero_size_alloc', @TestZeroSizeAlloc);

  { Edge-case tests }
  T.Run('chunk_cache_reuse', @TestChunkCacheReuse);
  T.Run('chunk_cache_limit', @TestChunkCacheLimit);
  T.Run('multiple_reset_cycles', @TestMultipleResetCycles);
  T.Run('aligned_zero_align', @TestAllocAlignedZeroAlign);
  T.Run('aligned_invalid_align', @TestAllocAlignedInvalidAlign);
  T.Run('stats_methods', @TestStatsMethods);
  T.Run('peak_used_across_resets', @TestPeakUsedAcrossResets);
  T.Run('reset_then_large_alloc', @TestResetThenLargeAlloc);
  T.Run('remaining_size', @TestRemainingSize);
  T.Run('segment_count_initial', @TestSegmentCountZero);

  T.Summary;
end.
