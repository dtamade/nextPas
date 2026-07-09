program test_thread_cache;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.allocator.thread_cache,
  nextpas.core.mem.error;

var
  T: TTestSuite;

procedure TestCreateAndDestroy;
var
  LCache: TThreadCacheAllocator;
begin
  LCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try
    Check(LCache <> nil, 'cache should be created');
  finally
    LCache.Free;
  end;
end;

procedure TestSmallObjectAlloc;
var
  LCache: TThreadCacheAllocator;
  LPtr1, LPtr2: Pointer;
begin
  LCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try
    LPtr1 := LCache.GetMem(32);
    Check(LPtr1 <> nil, 'first alloc should succeed');

    LPtr2 := LCache.GetMem(32);
    Check(LPtr2 <> nil, 'second alloc should succeed');
    Check(LPtr2 <> LPtr1, 'pointers should differ');

    LCache.FreeMem(LPtr1);
    LCache.FreeMem(LPtr2);
  finally
    LCache.Free;
  end;
end;

procedure TestLargeObjectAlloc;
var
  LCache: TThreadCacheAllocator;
  LPtr: Pointer;
begin
  LCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try
    { 2048 > max size class (1024) }
    LPtr := LCache.GetMem(2048);
    Check(LPtr <> nil, 'large alloc should succeed');

    LCache.FreeMem(LPtr);
  finally
    LCache.Free;
  end;
end;

procedure TestCacheHit;
var
  LCache: TThreadCacheAllocator;
  LPtrs: array[0..15] of Pointer;
  LI: Integer;
  LStats: TThreadCacheStats;
begin
  LCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try
    { Allocate and free to fill cache }
    for LI := 0 to 15 do
    begin
      LPtrs[LI] := LCache.GetMem(64);
      Check(LPtrs[LI] <> nil, 'alloc should succeed');
    end;

    for LI := 0 to 15 do
      LCache.FreeMem(LPtrs[LI]);

    { Next alloc should hit cache }
    LPtrs[0] := LCache.GetMem(64);
    Check(LPtrs[0] <> nil, 'alloc after fill should succeed');

    LStats := LCache.GetStats;
    Check(LStats.CacheHits > 0, 'should have cache hits');

    LCache.FreeMem(LPtrs[0]);
  finally
    LCache.Free;
  end;
end;

procedure TestAllocMemZeroInit;
var
  LCache: TThreadCacheAllocator;
  LPtr: Pointer;
  LI: Integer;
  LAllZero: Boolean;
begin
  LCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try
    LPtr := LCache.AllocMem(32);
    Check(LPtr <> nil, 'AllocMem should succeed');

    LAllZero := True;
    for LI := 0 to 31 do
    begin
      if PByte(PtrUInt(LPtr) + PtrUInt(LI))^ <> 0 then
      begin
        LAllZero := False;
        Break;
      end;
    end;
    Check(LAllZero, 'AllocMem should zero-initialize');

    LCache.FreeMem(LPtr);
  finally
    LCache.Free;
  end;
end;

procedure TestStats;
var
  LCache: TThreadCacheAllocator;
  LStats: TThreadCacheStats;
begin
  LCache := TThreadCacheAllocator.Create(DefaultAllocator);
  try
    LCache.GetMem(32);
    LCache.GetMem(64);

    LStats := LCache.GetStats;
    Check(LStats.BatchFetches > 0, 'should have batch fetches');
  finally
    LCache.Free;
  end;
end;

procedure TestNilInner;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TThreadCacheAllocator.Create(nil).Free;
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'nil inner should raise');
end;

begin
  T := TTestSuite.Create('test_thread_cache');
  T.Test('create_and_destroy', @TestCreateAndDestroy);
  T.Test('small_object_alloc', @TestSmallObjectAlloc);
  T.Test('large_object_alloc', @TestLargeObjectAlloc);
  T.Test('cache_hit', @TestCacheHit);
  T.Test('alloc_mem_zero_init', @TestAllocMemZeroInit);
  T.Test('stats', @TestStats);
  T.Test('nil_inner', @TestNilInner);
  T.Run;
  T.Summary;
end.
