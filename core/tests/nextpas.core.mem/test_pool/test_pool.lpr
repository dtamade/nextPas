program test_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.pool,
  nextpas.core.mem.error;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestCreateAndDestroy;
var
  LPool: TPoolAllocator;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 64);
  try
    Check(LPool.BlockSize = 64, 'block size should be 64');
    Check(LPool.TotalBlockCount > 0, 'should have initial blocks');
    Check(LPool.FreeBlockCount > 0, 'should have free blocks');
  finally
    LPool.Free;
  end;
end;

procedure TestAllocAndFree;
var
  LPool: TPoolAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 128);
  try
    LPtr1 := LPool.GetMem(128);
    Check(LPtr1 <> nil, 'first alloc should succeed');
    LPtr2 := LPool.GetMem(128);
    Check(LPtr2 <> nil, 'second alloc should succeed');
    Check(LPtr1 <> LPtr2, 'pointers should be different');
    Check(LPool.FreeBlockCount < LPool.TotalBlockCount, 'free blocks should decrease');

    LPool.FreeMem(LPtr1);
    LPool.FreeMem(LPtr2);
    Check(LPool.FreeBlockCount = LPool.TotalBlockCount, 'all blocks should be free');
  finally
    LPool.Free;
  end;
end;

procedure TestAllocMemZeroInitialized;
var
  LPool: TPoolAllocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 64);
  try
    LPtr := LPool.AllocMem(64);
    Check(LPtr <> nil, 'AllocMem should succeed');

    LAllZero := True;
    for LI := 0 to 63 do
    begin
      if PByte(PtrUInt(LPtr) + PtrUInt(LI))^ <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    end;
    Check(LAllZero, 'AllocMem should zero-initialize');

    LPool.FreeMem(LPtr);
  finally
    LPool.Free;
  end;
end;

procedure TestGrowPool;
var
  LPool: TPoolAllocator;
  LPtrs: array[0..511] of Pointer;
  LI: Integer;
  LStats: TPoolStats;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 32, 16);
  try
    Check(LPool.TotalBlockCount >= 16, 'initial should have >= 16 blocks');
    LStats := LPool.GetStats;
    Check(LStats.GrowCount >= 1, 'should have at least 1 grow');

    for LI := 0 to 511 do
    begin
      LPtrs[LI] := LPool.GetMem(32);
      Check(LPtrs[LI] <> nil, 'alloc should succeed at index ' + IntToStr(LI));
    end;

    LStats := LPool.GetStats;
    Check(LStats.GrowCount > 1, 'should have grown multiple times');
    Check(LStats.AllocCount = 512, 'alloc count should be 512');

    for LI := 0 to 511 do
      LPool.FreeMem(LPtrs[LI]);
  finally
    LPool.Free;
  end;
end;

{ 超限请求走 inner fallback 的三重回归：
  ① 指针须保留 inner 分配器对齐（旧实现返回 base+1 错位指针）
  ② 路由不得依赖块内容/块外字节（旧实现读 [-1] magic,mmap 基址会段错误）
  ③ AllocMem 须整块清零（旧实现只清 FBlockSize 前缀） }
procedure TestFallbackLargeBlocks;
var
  LPool: TPoolAllocator;
  LPtr, LZeroPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
  LStats: TPoolStats;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 64);
  try
    LPtr := LPool.GetMem(256);
    Check(LPtr <> nil, 'fallback alloc should succeed');
    Check(PtrUInt(LPtr) and $F = 0, 'fallback pointer should stay 16-aligned');
    FillChar(LPtr^, 256, $A7);
    LPool.FreeMem(LPtr);

    LZeroPtr := LPool.AllocMem(256);
    Check(LZeroPtr <> nil, 'fallback AllocMem should succeed');
    LAllZero := True;
    for LI := 0 to 255 do
      if PByte(LZeroPtr)[LI] <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    Check(LAllZero, 'fallback AllocMem should zero the whole block');
    LPool.FreeMem(LZeroPtr);

    LStats := LPool.GetStats;
    Check(LStats.AllocCount = 2, 'fallback allocs counted');
    Check(LStats.FreeCount = 2, 'fallback frees counted');
    Check(LStats.FreeBlocks = LStats.TotalBlocks, 'pool blocks untouched');
  finally
    LPool.Free;
  end;
end;

procedure TestFixedSizeNoRealloc;
var
  LPool: TPoolAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 64);
  try
    LPtr := LPool.GetMem(64);
    Check(LPtr <> nil, 'alloc should succeed');

    LRaised := False;
    try
      LPool.ReallocMem(LPtr, 128);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(LRaised, 'ReallocMem should raise for fixed-size pool');

    LPool.FreeMem(LPtr);
  finally
    LPool.Free;
  end;
end;

procedure TestStats;
var
  LPool: TPoolAllocator;
  LStats: TPoolStats;
  LPtr1, LPtr2: Pointer;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 64, 32);
  try
    LPtr1 := LPool.GetMem(64);
    LPtr2 := LPool.GetMem(64);

    LStats := LPool.GetStats;
    Check(LStats.BlockSize = 64, 'block size should be 64');
    Check(LStats.UsedBlocks = 2, 'used blocks should be 2');
    Check(LStats.FreeBlocks = LStats.TotalBlocks - 2, 'free = total - used');
    Check(LStats.AllocCount = 2, 'alloc count should be 2');

    LPool.FreeMem(LPtr1);
    LPool.FreeMem(LPtr2);
  finally
    LPool.Free;
  end;
end;

procedure TestInvalidParams;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TPoolAllocator.Create(nil, 64).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');

  LRaised := False;
  try
    TPoolAllocator.Create(DefaultAllocator, 4).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'too small block size should raise');
end;

procedure TestTraits;
var
  LPool: TPoolAllocator;
  LTraits: TAllocatorTraits;
begin
  LPool := TPoolAllocator.Create(DefaultAllocator, 64);
  try
    LTraits := LPool.Traits;
    Check(not LTraits.SupportsRealloc, 'pool should not support realloc');
    Check(not LTraits.ThreadSafe, 'pool is not thread-safe by default');
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('test_pool');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('alloc_and_free', @TestAllocAndFree);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInitialized);
  T.Test('grow_pool', @TestGrowPool);
  T.Test('fallback_large_blocks', @TestFallbackLargeBlocks);
  T.Test('fixed_size_no_realloc', @TestFixedSizeNoRealloc);
  T.Test('stats', @TestStats);
  T.Test('invalid_params', @TestInvalidParams);
  T.Test('traits', @TestTraits);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
