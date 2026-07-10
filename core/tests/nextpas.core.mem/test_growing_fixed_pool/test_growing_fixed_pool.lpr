program test_growing_fixed_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.pool.fixed.growable;

var
  T: TTestSuite;
  LRunPassed: Boolean;

function MakeConfig(aBlockSize: SizeUInt = 64;
                    aInitialCapacity: SizeUInt = 4;
                    aGrowthKind: TGrowthKind = gkGeometric;
                    aGrowthFactor: Double = 2.0;
                    aGrowthStep: SizeUInt = 0;
                    aMaxCapacity: SizeUInt = 0): TGrowingFixedPoolConfig;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.BlockSize := aBlockSize;
  Result.InitialCapacity := aInitialCapacity;
  Result.GrowthKind := aGrowthKind;
  Result.GrowthFactor := aGrowthFactor;
  Result.GrowthStep := aGrowthStep;
  Result.MaxCapacity := aMaxCapacity;
end;

procedure TestCreateAndDestroy;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
begin
  LConfig := MakeConfig(64, 4);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    Check(LPool.TotalCapacity = 4, 'initial TotalCapacity=4');
    Check(LPool.AllocatedCount = 0, 'initial AllocatedCount=0');
    Check(LPool.ArenaCount = 1, 'initial ArenaCount=1');
    Check(LPool.FreeCount = 4, 'initial FreeCount=4');
    Check(LPool.BlockSize = 64, 'BlockSize=64');
  finally
    LPool.Free;
  end;
end;

procedure TestBasicAcquireRelease;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array[0..2] of Pointer;
  LI: Integer;
  LOk: Boolean;
begin
  LConfig := MakeConfig(64, 4);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    for LI := 0 to 2 do
    begin
      LOk := LPool.Acquire(LPtrs[LI]);
      Check(LOk, 'acquire ' + IntToStr(LI + 1) + ' succeeded');
      Check(LPtrs[LI] <> nil, 'acquire ' + IntToStr(LI + 1) + ' not nil');
    end;
    Check(LPool.AllocatedCount = 3, 'AllocatedCount=3 after 3 acquires');

    for LI := 0 to 2 do
      LPool.Release(LPtrs[LI]);
    Check(LPool.AllocatedCount = 0, 'AllocatedCount=0 after all released');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolGrowth;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array of Pointer;
  LI: Integer;
  LOk: Boolean;
  LCapBefore: SizeUInt;
begin
  LConfig := MakeConfig(64, 4, gkGeometric, 2.0);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    Check(LPool.ArenaCount = 1, 'starts with 1 arena');

    { fill initial capacity }
    SetLength(LPtrs, 4);
    for LI := 0 to 3 do
    begin
      LOk := LPool.Acquire(LPtrs[LI]);
      Check(LOk, 'fill ' + IntToStr(LI));
    end;
    Check(LPool.ArenaCount = 1, 'still 1 arena after filling initial');

    { trigger growth }
    LCapBefore := LPool.TotalCapacity;
    SetLength(LPtrs, 8);
    for LI := 4 to 7 do
    begin
      LOk := LPool.Acquire(LPtrs[LI]);
      Check(LOk, 'grow acquire ' + IntToStr(LI));
    end;
    Check(LPool.ArenaCount > 1, 'ArenaCount > 1 after growth (got ' + IntToStr(LPool.ArenaCount) + ')');
    Check(LPool.TotalCapacity > LCapBefore, 'TotalCapacity grew');

    { cleanup }
    for LI := 0 to High(LPtrs) do
      LPool.Release(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

procedure TestShrinkTo;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array[0..7] of Pointer;
  LI: Integer;
  LCapBefore, LFreed: SizeUInt;
begin
  LConfig := MakeConfig(64, 4, gkGeometric, 2.0);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    { acquire + release to trigger growth then free all }
    for LI := 0 to 7 do
      LPool.Acquire(LPtrs[LI]);
    for LI := 0 to 7 do
      LPool.Release(LPtrs[LI]);

    LCapBefore := LPool.TotalCapacity;
    Check(LPool.ArenaCount > 1, 'multiple arenas before shrink');
    Check(LPool.AllocatedCount = 0, 'all released');

    { shrink to minimum (0 means keep only allocated = 0) }
    LFreed := LPool.ShrinkTo(0);
    Check(LFreed > 0, 'freed some blocks (' + IntToStr(LFreed) + ')');
    Check(LPool.TotalCapacity < LCapBefore, 'TotalCapacity reduced');
    Check(LPool.AllocatedCount = 0, 'AllocatedCount still 0');
  finally
    LPool.Free;
  end;
end;

procedure TestReset;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array[0..7] of Pointer;
  LI: Integer;
  LOk: Boolean;
begin
  LConfig := MakeConfig(64, 4, gkGeometric, 2.0);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    { fill pool and trigger growth }
    for LI := 0 to 7 do
    begin
      LOk := LPool.Acquire(LPtrs[LI]);
      Check(LOk, 'acquire ' + IntToStr(LI));
    end;
    Check(LPool.AllocatedCount = 8, 'AllocatedCount=8');

    LPool.Reset;
    Check(LPool.AllocatedCount = 0, 'AllocatedCount=0 after reset');
    Check(LPool.FreeCount = LPool.TotalCapacity, 'FreeCount=TotalCapacity after reset');

    { can acquire again }
    LOk := LPool.Acquire(LPtrs[0]);
    Check(LOk, 'acquire after reset succeeded');
    Check(LPool.AllocatedCount = 1, 'AllocatedCount=1 after re-acquire');
    LPool.Release(LPtrs[0]);
  finally
    LPool.Free;
  end;
end;

procedure TestDoubleFreeDetection;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtr: Pointer;
  LCaught: Boolean;
begin
  LConfig := MakeConfig(64, 4);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    LPool.Acquire(LPtr);
    LPool.Release(LPtr);

    LCaught := False;
    try
      LPool.Release(LPtr);
    except
      on E: EGrowingFixedPoolDoubleFree do
        LCaught := True;
    end;
    Check(LCaught, 'double free must raise EGrowingFixedPoolDoubleFree');
  finally
    LPool.Free;
  end;
end;

procedure TestInvalidPointerRelease;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LCaught: Boolean;
  LExternal: Pointer;
begin
  LConfig := MakeConfig(64, 4);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    { allocate externally via GetMem }
    GetMem(LExternal, 64);
    try
      LCaught := False;
      try
        LPool.Release(LExternal);
      except
        on E: EGrowingFixedPoolInvalidPointer do
          LCaught := True;
      end;
      Check(LCaught, 'external pointer must raise EGrowingFixedPoolInvalidPointer');
    finally
      FreeMem(LExternal);
    end;
  finally
    LPool.Free;
  end;
end;

procedure TestAcquireN;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array[0..9] of Pointer;
  LN: Integer;
begin
  LConfig := MakeConfig(64, 4, gkGeometric, 2.0);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    LN := LPool.AcquireN(LPtrs, 10);
    Check(LN = 10, 'AcquireN returned 10 (got ' + IntToStr(LN) + ')');
    Check(LPool.AllocatedCount = 10, 'AllocatedCount=10 after AcquireN');

    LPool.ReleaseN(LPtrs, LN);
    Check(LPool.AllocatedCount = 0, 'AllocatedCount=0 after ReleaseN');
  finally
    LPool.Free;
  end;
end;

procedure TestReleaseN;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array[0..5] of Pointer;
  LI: Integer;
begin
  LConfig := MakeConfig(64, 8);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    for LI := 0 to 5 do
      LPool.Acquire(LPtrs[LI]);
    Check(LPool.AllocatedCount = 6, 'AllocatedCount=6');

    LPool.ReleaseN(LPtrs, 6);
    Check(LPool.AllocatedCount = 0, 'AllocatedCount=0 after ReleaseN(6)');
    Check(LPool.FreeCount = LPool.TotalCapacity, 'FreeCount=TotalCapacity');
  finally
    LPool.Free;
  end;
end;

procedure TestGeometricGrowth;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array of Pointer;
  LI: Integer;
  LOk: Boolean;
  LCap1, LCap2: SizeUInt;
begin
  LConfig := MakeConfig(64, 4, gkGeometric, 2.0);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    LCap1 := LPool.TotalCapacity;
    Check(LCap1 = 4, 'initial capacity=4');

    { fill initial and trigger first growth }
    SetLength(LPtrs, LCap1);
    for LI := 0 to Integer(LCap1) - 1 do
      LPool.Acquire(LPtrs[LI]);

    LOk := LPool.Acquire(LPtrs[High(LPtrs)]);  // dummy — just trigger growth
    if not LOk then
    begin
      SetLength(LPtrs, Length(LPtrs) + 1);
      LOk := LPool.Acquire(LPtrs[High(LPtrs)]);
    end;
    Check(LOk, 'growth acquire succeeded');

    LCap2 := LPool.TotalCapacity;
    Check(LCap2 > LCap1, 'geometric growth increased capacity (was ' +
          IntToStr(LCap1) + ', now ' + IntToStr(LCap2) + ')');

    { with factor 2.0, new capacity should be ~8 (4 * 2.0 = 8 total desired) }
    Check(LCap2 >= 8, 'geometric growth at least doubled (cap=' + IntToStr(LCap2) + ')');

    { cleanup }
    for LI := 0 to High(LPtrs) do
      LPool.Release(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

procedure TestLinearGrowth;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array of Pointer;
  LI: Integer;
  LOk: Boolean;
  LCap1, LCap2: SizeUInt;
begin
  LConfig := MakeConfig(64, 4, gkLinear, 1.0, 8);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    LCap1 := LPool.TotalCapacity;
    Check(LCap1 = 4, 'initial capacity=4');

    { fill initial capacity }
    SetLength(LPtrs, 4);
    for LI := 0 to 3 do
      LPool.Acquire(LPtrs[LI]);

    { trigger growth by acquiring one more }
    SetLength(LPtrs, 5);
    LOk := LPool.Acquire(LPtrs[4]);
    Check(LOk, 'linear growth acquire succeeded');

    LCap2 := LPool.TotalCapacity;
    Check(LCap2 = LCap1 + 8, 'linear growth added GrowthStep=8 (cap was ' +
          IntToStr(LCap1) + ', now ' + IntToStr(LCap2) + ')');

    { cleanup }
    for LI := 0 to High(LPtrs) do
      LPool.Release(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

procedure TestMaxCapacity;
var
  LPool: TGrowingFixedPool;
  LConfig: TGrowingFixedPoolConfig;
  LPtrs: array[0..7] of Pointer;
  LI: Integer;
  LOk: Boolean;
  LCount: Integer;
begin
  LConfig := MakeConfig(64, 4, gkGeometric, 2.0, 0, 8);
  LPool := TGrowingFixedPool.Create(LConfig);
  try
    LCount := 0;
    for LI := 0 to 7 do
    begin
      LOk := LPool.Acquire(LPtrs[LI]);
      if LOk then
        Inc(LCount)
      else
        Break;
    end;
    Check(LCount = 8, 'acquired exactly 8 (MaxCapacity)');
    Check(LPool.TotalCapacity = 8, 'TotalCapacity capped at MaxCapacity=8');

    { next acquire should fail }
    LOk := LPool.Acquire(LPtrs[0]);  // reuse index 0 since we won't release
    Check(not LOk, 'acquire beyond MaxCapacity fails');

    { release and cleanup }
    for LI := 0 to LCount - 1 do
      LPool.Release(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.pool.fixed.growable');
  T.Test('create and destroy', @TestCreateAndDestroy);
  T.Test('basic acquire/release', @TestBasicAcquireRelease);
  T.Test('pool growth', @TestPoolGrowth);
  T.Test('shrink to', @TestShrinkTo);
  T.Test('reset', @TestReset);
  T.Test('double free detection', @TestDoubleFreeDetection);
  T.Test('invalid pointer release', @TestInvalidPointerRelease);
  T.Test('AcquireN batch', @TestAcquireN);
  T.Test('ReleaseN batch', @TestReleaseN);
  T.Test('geometric growth strategy', @TestGeometricGrowth);
  T.Test('linear growth strategy', @TestLinearGrowth);
  T.Test('max capacity limit', @TestMaxCapacity);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
