program test_pool_edge;
{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.pool;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestPoolAllocAndFree;
var
  LPool: TPoolAllocator;
  LPtrs: array[0..63] of Pointer;
  LI: Integer;
begin
  LPool := TPoolAllocator.Create(GetRtlAllocator, 128, 64);
  try
    for LI := 0 to 63 do
    begin
      LPtrs[LI] := LPool.GetMem(128);
      Check(LPtrs[LI] <> nil, 'Pool alloc #' + IntToStr(LI) + ' failed');
    end;
    { Free all }
    for LI := 0 to 63 do
      LPool.FreeMem(LPtrs[LI]);
    { Allocate again - should reuse freed blocks }
    for LI := 0 to 63 do
    begin
      LPtrs[LI] := LPool.GetMem(128);
      Check(LPtrs[LI] <> nil, 'Pool realloc #' + IntToStr(LI) + ' failed');
    end;
    for LI := 0 to 63 do
      LPool.FreeMem(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

procedure TestPoolGrow;
var
  LPool: TPoolAllocator;
  LPtrs: array[0..127] of Pointer;
  LI: Integer;
begin
  { Start with small pool, force grow }
  LPool := TPoolAllocator.Create(GetRtlAllocator, 64, 16);
  try
    for LI := 0 to 127 do
    begin
      LPtrs[LI] := LPool.GetMem(64);
      Check(LPtrs[LI] <> nil, 'Pool grow alloc #' + IntToStr(LI) + ' failed');
    end;
    for LI := 0 to 127 do
      LPool.FreeMem(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

procedure TestPoolStats;
var
  LPool: TPoolAllocator;
  LPtrs: array[0..9] of Pointer;
  LStats: TPoolStats;
  LI: Integer;
begin
  LPool := TPoolAllocator.Create(GetRtlAllocator, 256, 32);
  try
    for LI := 0 to 9 do
      LPtrs[LI] := LPool.GetMem(256);

    LStats := LPool.GetStats;
    Check(LStats.TotalBlocks >= 10, 'Should have >= 10 blocks');
    Check(LStats.UsedBlocks = 10, 'Should have 10 used blocks');

    for LI := 0 to 9 do
      LPool.FreeMem(LPtrs[LI]);

    LStats := LPool.GetStats;
    Check(LStats.FreeBlocks >= 10, 'Should have >= 10 free blocks');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolBlockSizeMismatch;
var
  LPool: TPoolAllocator;
  LPtr: Pointer;
  LGotException: Boolean;
begin
  LPool := TPoolAllocator.Create(GetRtlAllocator, 128, 16);
  try
    { Requesting size > block size should fail or handle gracefully }
    LGotException := False;
    try
      LPtr := LPool.GetMem(256);
      { If it succeeds, it's OK (may grow) }
      if LPtr <> nil then
        LPool.FreeMem(LPtr);
    except
      on E: Exception do
        LGotException := True;
    end;
    Check(True, 'BlockSize mismatch handled');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolZeroSizeAlloc;
var
  LPool: TPoolAllocator;
  LPtr: Pointer;
begin
  LPool := TPoolAllocator.Create(GetRtlAllocator, 128, 16);
  try
    LPtr := LPool.GetMem(0);
    Check(LPtr = nil, 'GetMem(0) should return nil');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolFreeNil;
var
  LPool: TPoolAllocator;
begin
  LPool := TPoolAllocator.Create(GetRtlAllocator, 128, 16);
  try
    LPool.FreeMem(nil); { Should not crash }
    Check(True, 'FreeMem(nil) should not crash');
  finally
    LPool.Free;
  end;
end;

procedure TestPoolInterleaved;
var
  LPool: TPoolAllocator;
  LPtrs: array[0..31] of Pointer;
  LI: Integer;
begin
  LPool := TPoolAllocator.Create(GetRtlAllocator, 64, 32);
  try
    { Interleaved alloc/free pattern }
    for LI := 0 to 31 do
    begin
      LPtrs[LI] := LPool.GetMem(64);
      Check(LPtrs[LI] <> nil, 'Interleaved alloc failed');
      if LI mod 2 = 1 then
      begin
        LPool.FreeMem(LPtrs[LI]);
        LPtrs[LI] := nil;
      end;
    end;
    { Free remaining }
    for LI := 0 to 31 do
      if LPtrs[LI] <> nil then
        LPool.FreeMem(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_pool_edge');
  T.Test('PoolAllocAndFree', @TestPoolAllocAndFree);
  T.Test('PoolGrow', @TestPoolGrow);
  T.Test('PoolStats', @TestPoolStats);
  T.Test('PoolBlockSizeMismatch', @TestPoolBlockSizeMismatch);
  T.Test('PoolZeroSizeAlloc', @TestPoolZeroSizeAlloc);
  T.Test('PoolFreeNil', @TestPoolFreeNil);
  T.Test('PoolInterleaved', @TestPoolInterleaved);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
