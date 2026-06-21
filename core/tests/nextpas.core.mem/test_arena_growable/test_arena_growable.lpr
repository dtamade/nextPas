program test_arena_growable;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
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

  T.Summary;
end.
