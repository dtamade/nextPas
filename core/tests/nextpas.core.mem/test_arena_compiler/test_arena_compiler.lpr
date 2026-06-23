program test_arena_compiler;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.intf,
  nextpas.core.mem.base;

var
  T: TTestRunner;

{ --- TVirtualArena record tests --- }

procedure TestAllocBasic;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'basic alloc should return non-nil');
    Check(SizeUInt(LP) mod DEFAULT_ALIGNMENT = 0, 'should be aligned to DEFAULT_ALIGNMENT');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocZeroSize;
var
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    Check(LArena.Alloc(0) = nil, 'zero-size alloc should return nil');
    Check(LArena.TotalUsed = 0, 'zero-size alloc should not affect TotalUsed');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAligned16;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(32, 16);
    Check(LP <> nil, '16-byte aligned alloc');
    Check(SizeUInt(LP) mod 16 = 0, 'pointer should be 16-byte aligned');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAligned32;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(48, 32);
    Check(LP <> nil, '32-byte aligned alloc');
    Check(SizeUInt(LP) mod 32 = 0, 'pointer should be 32-byte aligned');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAligned64;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(100, 64);
    Check(LP <> nil, '64-byte aligned alloc');
    Check(SizeUInt(LP) mod 64 = 0, 'pointer should be 64-byte aligned');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAligned256;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(200, 256);
    Check(LP <> nil, '256-byte aligned alloc');
    Check(SizeUInt(LP) mod 256 = 0, 'pointer should be 256-byte aligned');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAligned4096;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(4096, 4096);
    Check(LP <> nil, '4096-byte aligned alloc');
    Check(SizeUInt(LP) mod 4096 = 0, 'pointer should be page-aligned');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocZeroed;
var
  LArena: TVirtualArena;
  LP: PByte;
  I: Integer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := PByte(LArena.AllocZeroed(128));
    Check(LP <> nil, 'zeroed alloc should succeed');
    for I := 0 to 127 do
      Check(LP[I] = 0, 'byte ' + IntToStr(I) + ' should be zero');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestLargeAlloc;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.Alloc(ARENA_LARGE_THRESHOLD);
    Check(LP <> nil, 'large alloc should succeed');
    Check(LArena.AllocCount = 1, 'should count as 1 allocation');
    Check(LArena.TotalUsed >= ARENA_LARGE_THRESHOLD, 'TotalUsed should reflect large alloc');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestSaveRestoreMark;
var
  LArena: TVirtualArena;
  LMark1, LMark2: TArenaMark;
  LUsed1, LUsed2: SizeUInt;
begin
  TVirtualArena_Init(LArena);
  try
    LArena.Alloc(100);
    LUsed1 := LArena.TotalUsed;
    LMark1 := LArena.SaveMark;

    LArena.Alloc(200);
    LUsed2 := LArena.TotalUsed;
    LMark2 := LArena.SaveMark;

    LArena.Alloc(300);

    { 恢复到 mark2 之前 }
    LArena.RestoreToMark(LMark1);
    Check(LArena.TotalUsed = LUsed1, 'restored to mark1');

    { 恢复后仍可分配 }
    Check(LArena.Alloc(50) <> nil, 'can alloc after restore');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestReset;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.Alloc(256);
    Check(LP <> nil, 'alloc before reset');
    Check(LArena.TotalUsed > 0, 'used before reset');

    LArena.Reset;
    Check(LArena.TotalUsed = 0, 'TotalUsed should be 0 after reset');

    LP := LArena.Alloc(256);
    Check(LP <> nil, 'can alloc after reset');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestRelease;
var
  LArena: TVirtualArena;
  LAllocBefore, LAllocAfter: SizeUInt;
begin
  TVirtualArena_Init(LArena);
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
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    LArena.Alloc(100);
    LArena.Alloc(200);
    Check(LArena.PeakUsed >= 300, 'PeakUsed should be at least 300');

    { PeakUsed 不应因 Reset 而减少 }
    LArena.Reset;
    Check(LArena.PeakUsed >= 300, 'PeakUsed should persist after reset');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocCount;
var
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    Check(LArena.AllocCount = 0, 'initial AllocCount should be 0');
    LArena.Alloc(64);
    Check(LArena.AllocCount = 1, 'AllocCount after first alloc');
    LArena.Alloc(128);
    Check(LArena.AllocCount = 2, 'AllocCount after second alloc');
    LArena.AllocZeroed(256);
    Check(LArena.AllocCount = 3, 'AllocCount after AllocZeroed');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestOverflowProtection;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.Alloc(High(SizeUInt));
    Check(LP = nil, 'extremely large alloc should return nil');
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'arena should still work after failed large alloc');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestMultipleArenas;
var
  LArena1, LArena2: TVirtualArena;
  LP1, LP2: Pointer;
begin
  TVirtualArena_Init(LArena1);
  TVirtualArena_Init(LArena2);
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
    TVirtualArena_Release(LArena1);
    TVirtualArena_Release(LArena2);
  end;
end;

procedure TestMultipleSmallAllocs;
var
  LArena: TVirtualArena;
  LP: Pointer;
  I: Integer;
begin
  TVirtualArena_Init(LArena);
  try
    for I := 0 to 9999 do
    begin
      LP := LArena.Alloc(16);
      Check(LP <> nil, 'small alloc #' + IntToStr(I));
    end;
    Check(LArena.AllocCount = 10000, 'should have 10000 allocs');
    Check(LArena.TotalUsed = 160000, 'should have used 160000 bytes');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAlignedInSuccession;
var
  LArena: TVirtualArena;
  LP: Pointer;
  I: Integer;
begin
  TVirtualArena_Init(LArena);
  try
    for I := 0 to 99 do
    begin
      LP := LArena.AllocAligned(48, 64);
      Check(LP <> nil, 'aligned alloc #' + IntToStr(I));
      Check(SizeUInt(LP) mod 64 = 0, 'alignment #' + IntToStr(I));
    end;
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestLargeThenSmall;
var
  LArena: TVirtualArena;
  LPLarge, LPSmall: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LPLarge := LArena.Alloc(ARENA_LARGE_THRESHOLD + 1000);
    Check(LPLarge <> nil, 'large alloc should succeed');
    LPSmall := LArena.Alloc(32);
    Check(LPSmall <> nil, 'small alloc after large should succeed');
    Check(LArena.AllocCount = 2, 'should count both');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

{ --- TVirtualArenaAllocator tests --- }

procedure TestArenaAllocatorInterface;
var
  LAlloc: IAllocator;
  LP: Pointer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
  LP := LAlloc.GetMem(128);
  Check(LP <> nil, 'IAllocator.GetMem should work');
  Check(LAlloc.Traits.ThreadSafe = False, 'should not be thread-safe');
  Check(LAlloc.Traits.SupportsAligned = True, 'should support aligned');
  Check(LAlloc.Traits.HasMemSize = False, 'should not have MemSize');
end;

procedure TestArenaAllocatorReset;
var
  LAlloc: TVirtualArenaAllocator;
  LP: Pointer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
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
  LAlloc: TVirtualArenaAllocator;
  LTraits: TAllocatorTraits;
begin
  LAlloc := TVirtualArenaAllocator.Create;
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
  LAlloc := TVirtualArenaAllocator.Create;
  LP1 := LAlloc.GetMem(64);
  Check(LP1 <> nil, 'first alloc');
  LAlloc.FreeMem(LP1);
  LP2 := LAlloc.GetMem(64);
  Check(LP2 <> nil, 'alloc after FreeMem should still work');
end;

procedure TestArenaAllocatorAllocMem;
var
  LAlloc: IAllocator;
  LP: PByte;
  I: Integer;
begin
  LAlloc := TVirtualArenaAllocator.Create;
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
  LAlloc := TVirtualArenaAllocator.Create;
  LP := PInteger(LAlloc.GetMem(4));
  Check(LP <> nil, 'initial alloc');
  LP^ := 42;

  LP2 := PInteger(LAlloc.ReallocMem(LP, 8));
  Check(LP2 <> nil, 'realloc should succeed');
  Check(LP2^ = 42, 'data should be preserved after realloc');
end;

{ --- Additional edge-case tests --- }

procedure TestDualDirectionBump;
var
  LArena: TVirtualArena;
  LP1, LP2, LP3, LP4: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    { Alloc (front) and AllocNoPointer (back) interleaved }
    LP1 := LArena.Alloc(64);
    Check(LP1 <> nil, 'dual: first front alloc');
    LP2 := LArena.AllocNoPointer(64);
    Check(LP2 <> nil, 'dual: first back alloc');
    LP3 := LArena.Alloc(128);
    Check(LP3 <> nil, 'dual: second front alloc');
    LP4 := LArena.AllocNoPointer(128);
    Check(LP4 <> nil, 'dual: second back alloc');
    { Front allocs should be lower address than back allocs }
    Check(PtrUInt(LP1) < PtrUInt(LP2), 'dual: front < back');
    Check(PtrUInt(LP3) < PtrUInt(LP4), 'dual: front2 < back2');
    { No overlap }
    Check(PtrUInt(LP3) + 128 <= PtrUInt(LP4), 'dual: no overlap');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestDualDirectionOverlap;
var
  LArena: TVirtualArena;
  LP1, LP2: Pointer;
  LOK: Boolean;
begin
  TVirtualArena_Init(LArena);
  try
    { Allocate from both sides until they meet/overlap }
    LOK := True;
    while True do
    begin
      LP1 := LArena.Alloc(4096);
      LP2 := LArena.AllocNoPointer(4096);
      if (LP1 = nil) or (LP2 = nil) then
        Break;
      if PtrUInt(LP1) >= PtrUInt(LP2) then
      begin
        LOK := False;
        Break;
      end;
    end;
    Check(LOK, 'dual overlap: front never exceeded back before exhaustion');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocNoPointerBasic;
var
  LArena: TVirtualArena;
  LP: PByte;
  I: Integer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := PByte(LArena.AllocNoPointer(256));
    Check(LP <> nil, 'nopointer basic: should succeed');
    { Write data to verify memory is accessible }
    for I := 0 to 255 do
      LP[I] := Byte(I);
    for I := 0 to 255 do
      if LP[I] <> Byte(I) then
      begin
        Check(False, 'nopointer basic: data mismatch at ' + IntToStr(I));
        Exit;
      end;
    Check(True, 'nopointer basic: data verified');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocNoPointerZeroSize;
var
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    Check(LArena.AllocNoPointer(0) = nil, 'nopointer zero: returns nil');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestCommitBoundary;
var
  LArena: TVirtualArena;
  LP: Pointer;
  LCount: Integer;
begin
  TVirtualArena_Init(LArena);
  try
    { Allocate enough to cross 2MB commit boundary }
    LCount := 0;
    while True do
    begin
      LP := LArena.Alloc(128);
      if LP = nil then
        Break;
      Inc(LCount);
      if LCount > 50000 then
        Break; { safety }
    end;
    Check(LCount > 100, 'commit boundary: allocated ' + IntToStr(LCount) + ' items');
    Check(LArena.TotalUsed > 0, 'commit boundary: TotalUsed > 0');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestLargeThresholdBoundary;
var
  LArena: TVirtualArena;
  LP1, LP2: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    { Just below threshold - should use front bump }
    LP1 := LArena.Alloc(ARENA_LARGE_THRESHOLD - 1);
    Check(LP1 <> nil, 'large threshold: just below should succeed');
    { At threshold - should use independent mmap }
    LP2 := LArena.Alloc(ARENA_LARGE_THRESHOLD);
    Check(LP2 <> nil, 'large threshold: at threshold should succeed');
    { Both should be valid }
    PByte(LP1)[0] := $AA;
    PByte(LP2)[0] := $BB;
    Check(PByte(LP1)[0] = $AA, 'large threshold: below data verified');
    Check(PByte(LP2)[0] = $BB, 'large threshold: at data verified');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestMultipleInitReleaseCycles;
var
  I: Integer;
  LArena: TVirtualArena;
  LP: Pointer;
  OK: Boolean;
begin
  OK := True;
  for I := 0 to 99 do
  begin
    TVirtualArena_Init(LArena);
    LP := LArena.Alloc(64);
    if LP = nil then
    begin
      OK := False;
      Break;
    end;
    PByte(LP)[0] := Byte(I);
    TVirtualArena_Release(LArena);
  end;
  Check(OK, 'init/release 100 cycles: no leak or failure');
end;

procedure TestResetAfterPartialUse;
var
  LArena: TVirtualArena;
  LP: Pointer;
  I: Integer;
begin
  TVirtualArena_Init(LArena);
  try
    { Use only a little }
    for I := 0 to 99 do
      LArena.Alloc(64);
    Check(LArena.TotalUsed > 0, 'partial use: TotalUsed > 0');
    { Reset }
    LArena.Reset;
    Check(LArena.TotalUsed = 0, 'partial reset: TotalUsed = 0');
    { Allocate again }
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'after partial reset: can allocate again');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestSaveMarkFrontBack;
var
  LArena: TVirtualArena;
  LMark: TArenaMark;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LArena.Alloc(64);
    LArena.AllocNoPointer(64);
    LMark := LArena.SaveMark;
    LArena.Alloc(64);
    LArena.AllocNoPointer(64);
    LArena.Alloc(64);
    Check(LArena.TotalUsed > LMark.TotalUsed, 'mark: used grew after mark');
    LArena.RestoreToMark(LMark);
    Check(LArena.TotalUsed = LMark.TotalUsed, 'mark: restored to mark TotalUsed');
    { Can allocate again from the mark point }
    LP := LArena.Alloc(64);
    Check(LP <> nil, 'mark: can allocate after restore');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestStatsMethods;
var
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    LArena.Alloc(100);
    LArena.Alloc(200);
    Check(LArena.TotalAllocated > 0, 'stats: TotalAllocated > 0');
    Check(LArena.TotalUsed >= 300, 'stats: TotalUsed >= 300');
    Check(LArena.PeakUsed >= 300, 'stats: PeakUsed >= 300');
    Check(LArena.AllocCount >= 2, 'stats: AllocCount >= 2');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAlignedZeroAlign;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(64, 0);
    Check(LP = nil, 'aligned zero align: returns nil');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocAlignedNonPowerOfTwo;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.AllocAligned(64, 3);
    Check(LP = nil, 'aligned non-power-of-2: returns nil');
    LP := LArena.AllocAligned(64, 7);
    Check(LP = nil, 'aligned 7: returns nil');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestLargeAllocZeroSize;
var
  LArena: TVirtualArena;
begin
  TVirtualArena_Init(LArena);
  try
    Check(LArena.Alloc(0) = nil, 'large alloc zero: returns nil');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestMultipleResets;
var
  LArena: TVirtualArena;
  LP: Pointer;
  I, J: Integer;
  OK: Boolean;
begin
  TVirtualArena_Init(LArena);
  try
    OK := True;
    for I := 0 to 99 do
    begin
      for J := 0 to 999 do
      begin
        LP := LArena.Alloc(64);
        if LP = nil then
        begin
          OK := False;
          Break;
        end;
        PByte(LP)[0] := Byte(J);
      end;
      if not OK then
        Break;
      LArena.Reset;
    end;
    Check(OK, 'multiple resets 100x1000: all succeeded');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestResetHard;
var
  LArena: TVirtualArena;
  LP: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    LP := LArena.Alloc(4096);
    Check(LP <> nil, 'reset hard: alloc before');
    PByte(LP)[0] := $42;
    Check(LArena.TotalUsed > 0, 'reset hard: used > 0');

    LArena.ResetHard;
    Check(LArena.TotalUsed = 0, 'reset hard: TotalUsed = 0');

    LP := LArena.Alloc(4096);
    Check(LP <> nil, 'reset hard: can alloc after');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

procedure TestAllocUnsafe;
var
  LArena: TVirtualArena;
  LP1, LP2: Pointer;
begin
  TVirtualArena_Init(LArena);
  try
    { Pre-commit pages via Alloc, then Reset for clean Unsafe test }
    LP1 := LArena.Alloc(4096);
    Check(LP1 <> nil, 'unsafe: pre-commit alloc');
    LArena.Reset;

    { Now pages are committed — AllocUnsafe is safe }
    LP1 := LArena.AllocUnsafe(64);
    LP2 := LArena.AllocUnsafe(128);
    Check(LP1 <> nil, 'unsafe: first alloc');
    Check(LP2 <> nil, 'unsafe: second alloc');
    Check(PtrUInt(LP2) >= PtrUInt(LP1) + 64, 'unsafe: sequential');
    { Write and read back to verify memory is accessible }
    PByte(LP1)[0] := $AA;
    PByte(LP2)[0] := $BB;
    Check(PByte(LP1)[0] = $AA, 'unsafe: data at LP1');
    Check(PByte(LP2)[0] = $BB, 'unsafe: data at LP2');
  finally
    TVirtualArena_Release(LArena);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena.virtual');

  { TVirtualArena record tests }
  T.Run('alloc_basic', @TestAllocBasic);
  T.Run('alloc_zero_size', @TestAllocZeroSize);
  T.Run('alloc_aligned_16', @TestAllocAligned16);
  T.Run('alloc_aligned_32', @TestAllocAligned32);
  T.Run('alloc_aligned_64', @TestAllocAligned64);
  T.Run('alloc_aligned_256', @TestAllocAligned256);
  T.Run('alloc_aligned_4096', @TestAllocAligned4096);
  T.Run('alloc_zeroed', @TestAllocZeroed);
  T.Run('large_alloc', @TestLargeAlloc);
  T.Run('save_restore_mark', @TestSaveRestoreMark);
  T.Run('reset', @TestReset);
  T.Run('release', @TestRelease);
  T.Run('peak_used', @TestPeakUsed);
  T.Run('alloc_count', @TestAllocCount);
  T.Run('overflow_protection', @TestOverflowProtection);
  T.Run('multiple_arenas', @TestMultipleArenas);
  T.Run('multiple_small_allocs', @TestMultipleSmallAllocs);
  T.Run('aligned_in_succession', @TestAlignedInSuccession);
  T.Run('large_then_small', @TestLargeThenSmall);

  { TVirtualArenaAllocator tests }
  T.Run('arena_allocator_interface', @TestArenaAllocatorInterface);
  T.Run('arena_allocator_reset', @TestArenaAllocatorReset);
  T.Run('arena_allocator_traits', @TestArenaAllocatorTraits);
  T.Run('arena_allocator_free_is_nop', @TestArenaAllocatorFreeIsNop);
  T.Run('arena_allocator_alloc_mem', @TestArenaAllocatorAllocMem);
  T.Run('arena_allocator_realloc', @TestArenaAllocatorRealloc);

  { Edge-case tests }
  T.Run('dual_direction_bump', @TestDualDirectionBump);
  T.Run('dual_direction_overlap', @TestDualDirectionOverlap);
  T.Run('nopointer_basic', @TestAllocNoPointerBasic);
  T.Run('nopointer_zero_size', @TestAllocNoPointerZeroSize);
  T.Run('commit_boundary', @TestCommitBoundary);
  T.Run('large_threshold_boundary', @TestLargeThresholdBoundary);
  T.Run('multiple_init_release_cycles', @TestMultipleInitReleaseCycles);
  T.Run('reset_after_partial_use', @TestResetAfterPartialUse);
  T.Run('save_mark_front_back', @TestSaveMarkFrontBack);
  T.Run('stats_methods', @TestStatsMethods);
  T.Run('aligned_zero_align', @TestAllocAlignedZeroAlign);
  T.Run('aligned_non_power_of_two', @TestAllocAlignedNonPowerOfTwo);
  T.Run('multiple_resets', @TestMultipleResets);
  T.Run('reset_hard', @TestResetHard);
  T.Run('alloc_unsafe', @TestAllocUnsafe);

  T.Summary;
end.
