program test_thread_cache;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.cache.thread;

var
  T: TTestSuite;

{ Simple backing store: pre-allocated blocks for refill/flush. }
const
  BACKING_BLOCK_SIZE = 256;
  BACKING_POOL_SIZE = 128;

var
  GPools: array[0..MEM_SIZECLASS_COUNT - 1] of array[0..BACKING_POOL_SIZE - 1] of Byte;
  GAllocCount: array[0..MEM_SIZECLASS_COUNT - 1] of Word;
  GFreeCount: array[0..MEM_SIZECLASS_COUNT - 1] of Word;

function MockRefill(AIndex: Int32; ACount: Word; ABlocks: PPointer): Word;
var
  I: Word;
begin
  Result := 0;
  for I := 0 to ACount - 1 do
  begin
    if GAllocCount[AIndex] >= BACKING_POOL_SIZE then
      Break;
    PPointer(PByte(@GPools[AIndex]) + GAllocCount[AIndex] * BACKING_BLOCK_SIZE)^ := nil;
    ABlocks^ := @GPools[AIndex][GAllocCount[AIndex] * BACKING_BLOCK_SIZE];
    Inc(ABlocks);
    Inc(GAllocCount[AIndex]);
    Inc(Result);
  end;
end;

procedure MockFlush(AIndex: Int32; ACount: Word; ABlocks: PPointer);
var
  I: Word;
begin
  for I := 0 to ACount - 1 do
  begin
    Inc(GFreeCount[AIndex]);
    Inc(ABlocks);
  end;
end;

procedure ResetMocks;
var
  I: Int32;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    GAllocCount[I] := 0;
    GFreeCount[I] := 0;
  end;
end;

{ --- Tests --- }

procedure TestInit;
var
  LCache: TThreadCache;
  I: Int32;
begin
  ThreadCacheInit(LCache);
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
  begin
    Check(ThreadCacheCount(LCache, I) = 0, 'class ' + IntToStr(I) + ' empty');
  end;
  WriteLn('PASS: init');
end;

procedure TestAllocFromEmpty;
var
  LCache: TThreadCache;
begin
  ThreadCacheInit(LCache);
  Check(ThreadCacheAlloc(LCache, 0) = nil, 'alloc from empty returns nil');
  WriteLn('PASS: alloc from empty');
end;

procedure TestRefillAndAlloc;
var
  LCache: TThreadCache;
  LPtr: Pointer;
begin
  ResetMocks;
  ThreadCacheInit(LCache);
  ThreadCacheRefill(LCache, 0, @MockRefill);
  Check(ThreadCacheCount(LCache, 0) = CACHE_ADAPTIVE_BATCH_SMALL, 'count = batch after refill');
  LPtr := ThreadCacheAlloc(LCache, 0);
  Check(LPtr <> nil, 'alloc after refill non-nil');
  Check(ThreadCacheCount(LCache, 0) = CACHE_ADAPTIVE_BATCH_SMALL - 1, 'count decreased');
  WriteLn('PASS: refill and alloc');
end;

procedure TestFreeAndFlush;
var
  LCache: TThreadCache;
  LBlocks: array[0..3] of Pointer;
  I: Integer;
begin
  ResetMocks;
  ThreadCacheInit(LCache);
  { Refill some blocks. }
  ThreadCacheRefill(LCache, 0, @MockRefill);
  { Alloc all. }
  for I := 0 to CACHE_ADAPTIVE_BATCH_SMALL - 1 do
    LBlocks[0] := ThreadCacheAlloc(LCache, 0);
  Check(ThreadCacheCount(LCache, 0) = 0, 'empty after alloc all');
  { Now refill again and alloc one to free. }
  ThreadCacheRefill(LCache, 0, @MockRefill);
  LBlocks[0] := ThreadCacheAlloc(LCache, 0);
  Check(ThreadCacheFree(LCache, 0, LBlocks[0]), 'free succeeds');
  Check(ThreadCacheCount(LCache, 0) = CACHE_ADAPTIVE_BATCH_SMALL, 'count after free');
  { Flush. }
  GFreeCount[0] := 0;
  ThreadCacheFlush(LCache, 0, @MockFlush);
  Check(GFreeCount[0] > 0, 'flush called');
  WriteLn('PASS: free and flush');
end;

procedure TestFlushTrigger;
var
  LCache: TThreadCache;
  I: Integer;
  LBlock: Pointer;
begin
  ResetMocks;
  ThreadCacheInit(LCache);
  { Fill the cache to CACHE_MAX_LIST_SIZE via refill + alloc cycle. }
  for I := 1 to CACHE_MAX_LIST_SIZE + 1 do
  begin
    if ThreadCacheCount(LCache, 0) = 0 then
      ThreadCacheRefill(LCache, 0, @MockRefill);
    LBlock := ThreadCacheAlloc(LCache, 0);
    if LBlock = nil then
      Break;
    ThreadCacheFree(LCache, 0, LBlock);
  end;
  { Try one more free — should fail (cache full). }
  ThreadCacheRefill(LCache, 0, @MockRefill);
  LBlock := ThreadCacheAlloc(LCache, 0);
  if LBlock <> nil then
  begin
    { Fill up. }
    for I := 1 to CACHE_MAX_LIST_SIZE do
    begin
      if ThreadCacheCount(LCache, 0) >= CACHE_MAX_LIST_SIZE then
        Break;
      ThreadCacheRefill(LCache, 0, @MockRefill);
      LBlock := ThreadCacheAlloc(LCache, 0);
      if LBlock <> nil then
        ThreadCacheFree(LCache, 0, LBlock);
    end;
    { Now the next free should fail. }
    ThreadCacheRefill(LCache, 0, @MockRefill);
    LBlock := ThreadCacheAlloc(LCache, 0);
    if LBlock <> nil then
      Check(not ThreadCacheFree(LCache, 0, LBlock), 'free fails when cache full');
  end;
  WriteLn('PASS: flush trigger');
end;

procedure TestMultipleSizeClasses;
var
  LCache: TThreadCache;
  LPtr0, LPtr1: Pointer;
begin
  ResetMocks;
  ThreadCacheInit(LCache);
  ThreadCacheRefill(LCache, 0, @MockRefill);
  ThreadCacheRefill(LCache, 5, @MockRefill);
  LPtr0 := ThreadCacheAlloc(LCache, 0);
  LPtr1 := ThreadCacheAlloc(LCache, 5);
  Check(LPtr0 <> nil, 'class 0 alloc non-nil');
  Check(LPtr1 <> nil, 'class 5 alloc non-nil');
  Check(LPtr0 <> LPtr1, 'different classes return different blocks');
  WriteLn('PASS: multiple size classes');
end;

procedure TestInvalidIndex;
var
  LCache: TThreadCache;
begin
  ThreadCacheInit(LCache);
  Check(ThreadCacheAlloc(LCache, -1) = nil, 'alloc -1 returns nil');
  Check(ThreadCacheAlloc(LCache, MEM_SIZECLASS_COUNT) = nil, 'alloc OOB returns nil');
  Check(not ThreadCacheFree(LCache, -1, nil), 'free -1 returns false');
  WriteLn('PASS: invalid index');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('thread_cache');

  T.Test('init', @TestInit);
  T.Test('alloc_from_empty', @TestAllocFromEmpty);
  T.Test('refill_and_alloc', @TestRefillAndAlloc);
  T.Test('free_and_flush', @TestFreeAndFlush);
  T.Test('flush_trigger', @TestFlushTrigger);
  T.Test('multiple_size_classes', @TestMultipleSizeClasses);
  T.Test('invalid_index', @TestInvalidIndex);

  T.Run;
  T.Summary;
end.
