program test_arena_compiler;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.arena.compiler,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.intf,
  nextpas.core.mem.base;

var
  T: TTestRunner;

{ --- TArena record tests --- }

procedure TestAllocBasic;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'basic alloc should return non-nil');
    Check(SizeUInt(LP) mod DEFAULT_ALIGNMENT = 0, 'should be aligned to DEFAULT_ALIGNMENT');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocZeroSize;
var
  LArena: TArena;
begin
  TArena_Init(LArena);
  try
    Check(LArena.Alloc(0) = nil, 'zero-size alloc should return nil');
    Check(LArena.TotalUsed = 0, 'zero-size alloc should not affect TotalUsed');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocAligned16;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.AllocAligned(32, 16);
    Check(LP <> nil, '16-byte aligned alloc');
    Check(SizeUInt(LP) mod 16 = 0, 'pointer should be 16-byte aligned');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocAligned32;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.AllocAligned(48, 32);
    Check(LP <> nil, '32-byte aligned alloc');
    Check(SizeUInt(LP) mod 32 = 0, 'pointer should be 32-byte aligned');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocAligned64;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.AllocAligned(100, 64);
    Check(LP <> nil, '64-byte aligned alloc');
    Check(SizeUInt(LP) mod 64 = 0, 'pointer should be 64-byte aligned');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocAligned256;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.AllocAligned(200, 256);
    Check(LP <> nil, '256-byte aligned alloc');
    Check(SizeUInt(LP) mod 256 = 0, 'pointer should be 256-byte aligned');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocAligned4096;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.AllocAligned(4096, 4096);
    Check(LP <> nil, '4096-byte aligned alloc');
    Check(SizeUInt(LP) mod 4096 = 0, 'pointer should be page-aligned');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocZeroed;
var
  LArena: TArena;
  LP: PByte;
  I: Integer;
begin
  TArena_Init(LArena);
  try
    LP := PByte(LArena.AllocZeroed(128));
    Check(LP <> nil, 'zeroed alloc should succeed');
    for I := 0 to 127 do
      Check(LP[I] = 0, 'byte ' + IntToStr(I) + ' should be zero');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestChunkGrowth;
var
  LArena: TArena;
  LP: Pointer;
  LTotal: SizeUInt;
  I: Integer;
begin
  TArena_Init(LArena);
  try
    { 分配多次超过初始 chunk 大小，触发新 chunk }
    for I := 0 to 99 do
    begin
      LP := LArena.Alloc(1024);
      Check(LP <> nil, 'alloc #' + IntToStr(I) + ' should succeed');
    end;
    LTotal := LArena.TotalAllocated;
    Check(LTotal > ARENA_INITIAL_CHUNK_SIZE, 'should have allocated more than one chunk');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestLargeAlloc;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    { 大于等于 ARENA_LARGE_THRESHOLD 应直接 mmap }
    LP := LArena.Alloc(ARENA_LARGE_THRESHOLD);
    Check(LP <> nil, 'large alloc should succeed');
    Check(LArena.AllocCount = 1, 'should count as 1 allocation');
    Check(LArena.TotalUsed >= ARENA_LARGE_THRESHOLD, 'TotalUsed should reflect large alloc');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestSaveRestoreMark;
var
  LArena: TArena;
  LMark1, LMark2, LMark3: TArenaMark;
  LUsed1, LUsed2, LUsed3: SizeUInt;
begin
  TArena_Init(LArena);
  try
    LArena.Alloc(100);
    LUsed1 := LArena.TotalUsed;
    LMark1 := LArena.SaveMark;

    LArena.Alloc(200);
    LUsed2 := LArena.TotalUsed;
    LMark2 := LArena.SaveMark;

    LArena.Alloc(300);
    LUsed3 := LArena.TotalUsed;
    LMark3 := LArena.SaveMark;

    Check(LUsed3 > LUsed2, 'used should grow');

    { 恢复到 mark3 之前 }
    LArena.RestoreToMark(LMark2);
    Check(LArena.TotalUsed = LUsed2, 'restored to mark2');

    { 恢复到 mark2 之前 }
    LArena.RestoreToMark(LMark1);
    Check(LArena.TotalUsed = LUsed1, 'restored to mark1');

    { 恢复后仍可分配 }
    Check(LArena.Alloc(50) <> nil, 'can alloc after restore');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestReset;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    LP := LArena.Alloc(256);
    Check(LP <> nil, 'alloc before reset');
    Check(LArena.TotalUsed > 0, 'used before reset');

    LArena.Reset;
    Check(LArena.TotalUsed = 0, 'TotalUsed should be 0 after reset');

    LP := LArena.Alloc(256);
    Check(LP <> nil, 'can alloc after reset');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestRelease;
var
  LArena: TArena;
  LAllocBefore, LAllocAfter: SizeUInt;
begin
  TArena_Init(LArena);
  LArena.Alloc(1024);
  LArena.Alloc(2048);
  LAllocBefore := LArena.TotalAllocated;
  Check(LAllocBefore > 0, 'should have allocated memory');

  LArena.Release;
  LAllocAfter := LArena.TotalAllocated;
  Check(LAllocAfter = 0, 'TotalAllocated should be 0 after release');
  Check(LArena.TotalUsed = 0, 'TotalUsed should be 0 after release');
end;

procedure TestPeakUsed;
var
  LArena: TArena;
begin
  TArena_Init(LArena);
  try
    LArena.Alloc(100);
    LArena.Alloc(200);
    Check(LArena.PeakUsed >= 300, 'PeakUsed should be at least 300');

    { PeakUsed 不应因 Reset 而减少 }
    LArena.Reset;
    Check(LArena.PeakUsed >= 300, 'PeakUsed should persist after reset');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAllocCount;
var
  LArena: TArena;
begin
  TArena_Init(LArena);
  try
    Check(LArena.AllocCount = 0, 'initial AllocCount should be 0');
    LArena.Alloc(64);
    Check(LArena.AllocCount = 1, 'AllocCount after first alloc');
    LArena.Alloc(128);
    Check(LArena.AllocCount = 2, 'AllocCount after second alloc');
    LArena.AllocZeroed(256);
    Check(LArena.AllocCount = 3, 'AllocCount after AllocZeroed');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestOverflowProtection;
var
  LArena: TArena;
  LP: Pointer;
begin
  TArena_Init(LArena);
  try
    { 极大 size 应返回 nil 而非 crash }
    LP := LArena.Alloc(High(SizeUInt));
    Check(LP = nil, 'extremely large alloc should return nil');
    { Arena 应仍可用 }
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'arena should still work after failed large alloc');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestMultipleArenas;
var
  LArena1, LArena2: TArena;
  LP1, LP2: Pointer;
begin
  TArena_Init(LArena1);
  TArena_Init(LArena2);
  try
    LP1 := LArena1.Alloc(128);
    LP2 := LArena2.Alloc(128);
    Check(LP1 <> nil, 'arena1 alloc');
    Check(LP2 <> nil, 'arena2 alloc');
    Check(LArena1.TotalUsed = 128, 'arena1 used');
    Check(LArena2.TotalUsed = 128, 'arena2 used');

    LArena1.Reset;
    Check(LArena1.TotalUsed = 0, 'arena1 reset');
    Check(LArena2.TotalUsed = 128, 'arena2 unaffected');
  finally
    TArena_Release(LArena1);
    TArena_Release(LArena2);
  end;
end;

procedure TestMultipleSmallAllocs;
var
  LArena: TArena;
  LP: Pointer;
  I: Integer;
begin
  TArena_Init(LArena);
  try
    for I := 0 to 9999 do
    begin
      LP := LArena.Alloc(16);
      Check(LP <> nil, 'small alloc #' + IntToStr(I));
    end;
    Check(LArena.AllocCount = 10000, 'should have 10000 allocs');
    Check(LArena.TotalUsed = 160000, 'should have used 160000 bytes');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestMarkAcrossChunks;
var
  LArena: TArena;
  LMark: TArenaMark;
  I: Integer;
begin
  TArena_Init(LArena);
  try
    { 填满第一个 chunk }
    for I := 0 to 63 do
      LArena.Alloc(1024);
    LMark := LArena.SaveMark;
    { 在第二个 chunk 中分配 }
    for I := 0 to 9 do
      LArena.Alloc(1024);
    Check(LArena.TotalUsed > SizeUInt(64 * 1024), 'should have crossed chunk boundary');
    { 恢复到 mark 位置 }
    LArena.RestoreToMark(LMark);
    { 可以重新分配 }
    Check(LArena.Alloc(512) <> nil, 'can alloc after cross-chunk restore');
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestAlignedInSuccession;
var
  LArena: TArena;
  LP: Pointer;
  I: Integer;
begin
  TArena_Init(LArena);
  try
    for I := 0 to 99 do
    begin
      LP := LArena.AllocAligned(48, 64);
      Check(LP <> nil, 'aligned alloc #' + IntToStr(I));
      Check(SizeUInt(LP) mod 64 = 0, 'alignment #' + IntToStr(I));
    end;
  finally
    TArena_Release(LArena);
  end;
end;

procedure TestLargeThenSmall;
var
  LArena: TArena;
  LPLarge, LPSmall: Pointer;
begin
  TArena_Init(LArena);
  try
    LPLarge := LArena.Alloc(ARENA_LARGE_THRESHOLD + 1000);
    Check(LPLarge <> nil, 'large alloc should succeed');
    LPSmall := LArena.Alloc(32);
    Check(LPSmall <> nil, 'small alloc after large should succeed');
    Check(LArena.AllocCount = 2, 'should count both');
  finally
    TArena_Release(LArena);
  end;
end;

{ --- TArenaAllocator tests --- }

procedure TestArenaAllocatorInterface;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  LAlloc := TArenaAllocator.Create;
  LP := LAlloc.GetMem(128);
  Check(LP <> nil, 'IAllocator.GetMem should work');
  Check(LAlloc.Traits.ThreadSafe = False, 'should not be thread-safe');
  Check(LAlloc.Traits.SupportsAligned = True, 'should support aligned');
  Check(LAlloc.Traits.HasMemSize = False, 'should not have MemSize');
end;

procedure TestArenaAllocatorReset;
var
  LAlloc: TArenaAllocator;
  LP: Pointer;
begin
  LAlloc := TArenaAllocator.Create;
  try
    LP := LAlloc.GetMem(256);
    Check(LP <> nil, 'alloc before reset');
    Check(LAlloc.Arena.TotalUsed > 0, 'used before reset');

    LAlloc.Reset;
    Check(LAlloc.Arena.TotalUsed = 0, 'used should be 0 after reset');

    LP := LAlloc.GetMem(256);
    Check(LP <> nil, 'alloc after reset');
  finally
    LAlloc.Free;
  end;
end;

procedure TestArenaAllocatorTraits;
var
  LAlloc: TArenaAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TArenaAllocator.Create;
  try
    LTraits := LAlloc.Traits;
    Check(LTraits.ZeroInitialized = False, 'ZeroInitialized should be False');
    Check(LTraits.ThreadSafe = False, 'ThreadSafe should be False');
    Check(LTraits.HasMemSize = False, 'HasMemSize should be False');
    Check(LTraits.SupportsAligned = True, 'SupportsAligned should be True');
  finally
    LAlloc.Free;
  end;
end;

procedure TestArenaAllocatorFreeIsNop;
var
  LAlloc: IAllocator;
  LP1, LP2: Pointer;
begin
  LAlloc := TArenaAllocator.Create;
  LP1 := LAlloc.GetMem(64);
  Check(LP1 <> nil, 'first alloc');
  LAlloc.FreeMem(LP1);
  { FreeMem is no-op for arena, should not crash }
  LP2 := LAlloc.GetMem(64);
  Check(LP2 <> nil, 'alloc after FreeMem should still work');
end;

procedure TestArenaAllocatorAllocMem;
var
  LAlloc: IAllocator;
  LP: PByte;
  I: Integer;
begin
  LAlloc := TArenaAllocator.Create;
  LP := PByte(LAlloc.AllocMem(64));
  Check(LP <> nil, 'AllocMem should succeed');
  for I := 0 to 63 do
    Check(LP[I] = 0, 'AllocMem byte ' + IntToStr(I) + ' should be zero');
end;

procedure TestArenaAllocatorRealloc;
var
  LAlloc: IAllocator;
  LP, LP2: PInteger;
begin
  LAlloc := TArenaAllocator.Create;
  LP := PInteger(LAlloc.GetMem(4));
  Check(LP <> nil, 'initial alloc');
  LP^ := 42;

  LP2 := PInteger(LAlloc.ReallocMem(LP, 8));
  Check(LP2 <> nil, 'realloc should succeed');
  Check(LP2^ = 42, 'data should be preserved after realloc');
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena.compiler');

  { TArena record tests }
  T.Run('alloc_basic', @TestAllocBasic);
  T.Run('alloc_zero_size', @TestAllocZeroSize);
  T.Run('alloc_aligned_16', @TestAllocAligned16);
  T.Run('alloc_aligned_32', @TestAllocAligned32);
  T.Run('alloc_aligned_64', @TestAllocAligned64);
  T.Run('alloc_aligned_256', @TestAllocAligned256);
  T.Run('alloc_aligned_4096', @TestAllocAligned4096);
  T.Run('alloc_zeroed', @TestAllocZeroed);
  T.Run('chunk_growth', @TestChunkGrowth);
  T.Run('large_alloc', @TestLargeAlloc);
  T.Run('save_restore_mark', @TestSaveRestoreMark);
  T.Run('reset', @TestReset);
  T.Run('release', @TestRelease);
  T.Run('peak_used', @TestPeakUsed);
  T.Run('alloc_count', @TestAllocCount);
  T.Run('overflow_protection', @TestOverflowProtection);
  T.Run('multiple_arenas', @TestMultipleArenas);
  T.Run('multiple_small_allocs', @TestMultipleSmallAllocs);
  T.Run('mark_across_chunks', @TestMarkAcrossChunks);
  T.Run('aligned_in_succession', @TestAlignedInSuccession);
  T.Run('large_then_small', @TestLargeThenSmall);

  { TArenaAllocator tests }
  T.Run('arena_allocator_interface', @TestArenaAllocatorInterface);
  T.Run('arena_allocator_reset', @TestArenaAllocatorReset);
  T.Run('arena_allocator_traits', @TestArenaAllocatorTraits);
  T.Run('arena_allocator_free_is_nop', @TestArenaAllocatorFreeIsNop);
  T.Run('arena_allocator_alloc_mem', @TestArenaAllocatorAllocMem);
  T.Run('arena_allocator_realloc', @TestArenaAllocatorRealloc);

  T.Summary;
end.
