program test_growing_block_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.blockpool,
  nextpas.core.mem.blockpool.growable;

var
  T: TTestSuite;

procedure TestCreateWithDefault;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    Check(LPool.BlockSize >= 64, 'blocksize >= 64');
    Check(LPool.Capacity >= 4, 'capacity >= initial 4');
    Check(LPool.Available >= 4, 'available >= 4');
    Check(LPool.InUse = 0, 'inuse=0 after create');
    Check(LPool.SegmentCount >= 1, 'at least 1 segment');
  finally
    LPool.Free;
  end;
end;

procedure TestBasicAcquireRelease;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LP1, LP2, LP3: Pointer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    Check(LPool.Available >= 4, 'initial available >= 4');
    Check(LPool.InUse = 0, 'initial inuse=0');

    LP1 := LPool.Acquire;
    Check(LP1 <> nil, 'acquire 1');
    Check(LPool.InUse = 1, 'inuse=1');

    LP2 := LPool.Acquire;
    Check(LP2 <> nil, 'acquire 2');
    Check(LP2 <> LP1, 'different pointers');
    Check(LPool.InUse = 2, 'inuse=2');

    LP3 := LPool.Acquire;
    Check(LP3 <> nil, 'acquire 3');
    Check(LPool.InUse = 3, 'inuse=3');

    LPool.Release(LP2);
    Check(LPool.InUse = 2, 'inuse=2 after release');

    LPool.Release(LP1);
    LPool.Release(LP3);
    Check(LPool.InUse = 0, 'inuse=0 after all released');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolGrowth;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LPtrs: array[0..15] of Pointer;
  LSegCountBefore, LSegCountAfter: SizeUInt;
  I: Integer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    LSegCountBefore := LPool.SegmentCount;

    // Exhaust initial capacity and trigger growth
    for I := 0 to 15 do
    begin
      LPtrs[I] := LPool.Acquire;
      Check(LPtrs[I] <> nil, 'acquire ' + IntToStr(I));
    end;

    LSegCountAfter := LPool.SegmentCount;
    Check(LSegCountAfter > LSegCountBefore, 'segment count grew: ' + IntToStr(Integer(LSegCountBefore)) + ' -> ' + IntToStr(Integer(LSegCountAfter)));
    Check(LPool.InUse = 16, 'inuse=16');
    Check(LPool.Capacity >= 16, 'capacity >= 16');

    for I := 0 to 15 do
      LPool.Release(LPtrs[I]);
    Check(LPool.InUse = 0, 'inuse=0 after all released');
  finally
    LPool.Free;
  end;
end;

procedure TestReset;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LPtrs: array[0..7] of Pointer;
  LCapAfterReset: SizeUInt;
  I: Integer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    for I := 0 to 7 do
    begin
      LPtrs[I] := LPool.Acquire;
      Check(LPtrs[I] <> nil, 'acquire ' + IntToStr(I));
    end;
    Check(LPool.InUse = 8, 'inuse=8');

    LPool.Reset;
    LCapAfterReset := LPool.Capacity;
    Check(LPool.InUse = 0, 'inuse=0 after reset');
    Check(LPool.Available = LCapAfterReset, 'all blocks available after reset');
    Check(LCapAfterReset >= 8, 'capacity preserved >= 8');
  finally
    LPool.Free;
  end;
end;

procedure TestShrinkTo;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LSegCountGrown, LSegCountShrunk: SizeUInt;
  LPtrs: array[0..15] of Pointer;
  I: Integer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LConfig.KeepSegments := False;
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    // Acquire enough to trigger growth
    for I := 0 to 15 do
    begin
      LPtrs[I] := LPool.Acquire;
      Check(LPtrs[I] <> nil, 'acquire ' + IntToStr(I));
    end;
    LSegCountGrown := LPool.SegmentCount;
    Check(LSegCountGrown > 1, 'multiple segments after growth');

    // Release all and reset with KeepSegments=False shrinks to 1 segment
    for I := 0 to 15 do
      LPool.Release(LPtrs[I]);
    LPool.Reset;

    LSegCountShrunk := LPool.SegmentCount;
    Check(LSegCountShrunk < LSegCountGrown, 'segments shrunk: ' + IntToStr(Integer(LSegCountGrown)) + ' -> ' + IntToStr(Integer(LSegCountShrunk)));
    Check(LSegCountShrunk >= 1, 'at least 1 segment remains');
    Check(LPool.InUse = 0, 'inuse=0 after shrink+reset');
  finally
    LPool.Free;
  end;
end;

procedure TestDoubleFreeDetection;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LP: Pointer;
  LCaught: Boolean;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    LP := LPool.Acquire;
    Check(LP <> nil, 'acquire');
    LPool.Release(LP);

    LCaught := False;
    try
      LPool.Release(LP);
    except
      LCaught := True;
    end;
    Check(LCaught, 'double free detected');
  finally
    LPool.Free;
  end;
end;

procedure TestInvalidPointerRelease;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LExternal: Pointer;
  LCaught: Boolean;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    // Allocate external memory not owned by pool
    GetMem(LExternal, 128);
    try
      LCaught := False;
      try
        LPool.Release(LExternal);
      except
        LCaught := True;
      end;
      Check(LCaught, 'invalid pointer release detected');
    finally
      FreeMem(LExternal);
    end;
  finally
    LPool.Free;
  end;
end;

procedure TestAcquireN;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LPtrs: array[0..7] of Pointer;
  LGot: Integer;
  I: Integer;
  LUnique: Boolean;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 8);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    FillChar(LPtrs, SizeOf(LPtrs), 0);
    LGot := LPool.AcquireN(LPtrs, 8);
    Check(LGot = 8, 'acquired 8 blocks: got=' + IntToStr(LGot));
    Check(LPool.InUse = 8, 'inuse=8');

    // Check all pointers are unique and non-nil
    LUnique := True;
    for I := 0 to 7 do
    begin
      Check(LPtrs[I] <> nil, 'ptr[' + IntToStr(I) + '] non-nil');
      if I > 0 then
        if LPtrs[I] = LPtrs[I - 1] then
          LUnique := False;
    end;
    Check(LUnique, 'all pointers unique');
  finally
    LPool.Free;
  end;
end;

procedure TestReleaseN;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LPtrs: array[0..7] of Pointer;
  LGot: Integer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 8);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    FillChar(LPtrs, SizeOf(LPtrs), 0);
    LGot := LPool.AcquireN(LPtrs, 8);
    Check(LGot = 8, 'acquired 8');
    Check(LPool.InUse = 8, 'inuse=8');

    LPool.ReleaseN(LPtrs, 8);
    Check(LPool.InUse = 0, 'inuse=0 after releaseN');
  finally
    LPool.Free;
  end;
end;

procedure TestIBlockPoolInterface;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LPoolIf: IBlockPool;
  LP1, LP2: Pointer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 4);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    LPoolIf := LPool as IBlockPool;

    Check(LPoolIf.BlockSize >= 64, 'IBlockPool.BlockSize');
    Check(LPoolIf.Capacity >= 4, 'IBlockPool.Capacity');
    Check(LPoolIf.InUse = 0, 'IBlockPool.InUse=0');

    LP1 := LPoolIf.Acquire;
    Check(LP1 <> nil, 'IBlockPool.Acquire');
    Check(LPoolIf.InUse = 1, 'IBlockPool.InUse=1');

    LP2 := LPoolIf.Acquire;
    Check(LP2 <> nil, 'IBlockPool.Acquire 2');
    Check(LPoolIf.InUse = 2, 'IBlockPool.InUse=2');

    LPoolIf.Release(LP1);
    LPoolIf.Release(LP2);
    Check(LPoolIf.InUse = 0, 'IBlockPool.InUse=0 after release');

    LPoolIf.Reset;
    Check(LPoolIf.InUse = 0, 'IBlockPool.InUse=0 after reset');
    Check(LPoolIf.Available = LPoolIf.Capacity, 'IBlockPool.Available=Capacity after reset');
  finally
    LPool := nil;
    LPoolIf := nil;
  end;
end;

procedure TestIBlockPoolBatchInterface;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LBatchIf: IBlockPoolBatch;
  LPtrs: array[0..7] of Pointer;
  LGot: Integer;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 8);
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    LBatchIf := LPool as IBlockPoolBatch;

    FillChar(LPtrs, SizeOf(LPtrs), 0);
    LGot := LBatchIf.AcquireN(LPtrs, 8);
    Check(LGot = 8, 'IBlockPoolBatch.AcquireN got 8');
    Check(LBatchIf.InUse = 8, 'IBlockPoolBatch.InUse=8');

    LBatchIf.ReleaseN(LPtrs, 8);
    Check(LBatchIf.InUse = 0, 'IBlockPoolBatch.InUse=0 after ReleaseN');
  finally
    LPool := nil;
    LBatchIf := nil;
  end;
end;

procedure TestAlignment;
var
  LPool: TGrowingBlockPool;
  LConfig: TGrowingBlockPoolConfig;
  LP: Pointer;
  LPtrs: array[0..7] of Pointer;
  I: Integer;
  LAligned: Boolean;
begin
  LConfig := TGrowingBlockPoolConfig.Default(64, 8);
  LConfig.Alignment := 64;
  LPool := TGrowingBlockPool.Create(LConfig);
  try
    Check(LPool.Alignment >= 64, 'alignment=64');

    // Acquire blocks and verify alignment
    LAligned := True;
    for I := 0 to 7 do
    begin
      LP := LPool.Acquire;
      Check(LP <> nil, 'acquire ' + IntToStr(I));
      if (PtrUInt(LP) and (LPool.Alignment - 1)) <> 0 then
        LAligned := False;
      LPtrs[I] := LP;
    end;
    Check(LAligned, 'all pointers aligned to 64');

    for I := 0 to 7 do
      LPool.Release(LPtrs[I]);
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.blockpool.growable');

  T.Test('TestCreateWithDefault', @TestCreateWithDefault);
  T.Test('TestBasicAcquireRelease', @TestBasicAcquireRelease);
  T.Test('TestPoolGrowth', @TestPoolGrowth);
  T.Test('TestReset', @TestReset);
  T.Test('TestShrinkTo', @TestShrinkTo);
  T.Test('TestDoubleFreeDetection', @TestDoubleFreeDetection);
  T.Test('TestInvalidPointerRelease', @TestInvalidPointerRelease);
  T.Test('TestAcquireN', @TestAcquireN);
  T.Test('TestReleaseN', @TestReleaseN);
  T.Test('TestIBlockPoolInterface', @TestIBlockPoolInterface);
  T.Test('TestIBlockPoolBatchInterface', @TestIBlockPoolBatchInterface);
  T.Test('TestAlignment', @TestAlignment);

  T.Run;
  T.Summary;
end.
