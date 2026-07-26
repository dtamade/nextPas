program test_scavenger;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.central,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

{ Allocate ACount blocks and free them all so the span is stamped idle at
  pool tick AFreeTick. CentralPoolFree advances FTick by 1 before stamping,
  so seed the clock one below the desired stamp. }
procedure AllocAndFreeAll(var APool: TCentralPool; ACount: Word;
  AFreeTick: UInt64);
var
  LBlocks: array of Pointer;
  LCount: Word;
begin
  SetLength(LBlocks, ACount);
  LCount := CentralPoolAlloc(APool, ACount, @LBlocks[0]);
  Check(LCount = ACount, 'alloc ' + IntToStr(ACount));
  APool.FTick := AFreeTick - 1;
  CentralPoolFree(APool, ACount, @LBlocks[0]);
end;

{ Test: recently idle spans are NOT released (below threshold). }
procedure TestScavengerSkipsRecent;
var
  LPool: TCentralPool;
  LReleased: Int32;
begin
  CentralPoolInit(LPool, 64);
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 100);
  Check(LPool.FEntries[0].FLastFreeTick = 100, 'tick = 100');
  LPool.FTick := 150;
  LReleased := ScavengeCentralPools(LPool, 1000);
  Check(LReleased = 0, 'no releases');
  Check(LPool.FEntries[0].FMemory <> nil, 'memory kept');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: scavenger skips recent');
end;

{ Test: old idle spans ARE released (above threshold). }
procedure TestScavengerReleasesOld;
var
  LPool: TCentralPool;
  LReleased: Int32;
begin
  CentralPoolInit(LPool, 64);
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 100);
  LPool.FTick := 200;
  LReleased := ScavengeCentralPools(LPool, 50);
  Check(LReleased = 1, 'released 1');
  Check(LPool.FEntries[0].FMemory = nil, 'memory released');
  Check(LPool.FEntries[0].FLastFreeTick = 0, 'tick cleared');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: scavenger releases old');
end;

{ Test: alloc after scavenge REVIVES the dead slot instead of appending
  a new entry (dead-slot chain keeps FEntryCount bounded). }
procedure TestAllocAfterScavenge;
var
  LPool: TCentralPool;
  LBlocks: array[0..0] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 100);
  LPool.FTick := 200;
  ScavengeCentralPools(LPool, 50);
  Check(LPool.FEntries[0].FMemory = nil, 'released');
  LCount := CentralPoolAlloc(LPool, 1, @LBlocks[0]);
  Check(LCount = 1, 'alloc 1');
  Check(LPool.FEntryCount = 1, 'slot revived, no append');
  Check(LPool.FEntries[0].FMemory <> nil, 'revived slot has memory');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: alloc after scavenge');
end;

{ Test: repeated release-revive cycles never grow the entry table.
  Before the dead-slot chain, every peak-idle cycle leaked one entry
  slot (append-only AddSpan) — unbounded FEntryCount in long-lived
  processes. }
procedure TestRevivalKeepsEntryCountBounded;
var
  LPool: TCentralPool;
  LRound: Int32;
  LReleased: Int32;
begin
  CentralPoolInit(LPool, 64);
  for LRound := 1 to 16 do
  begin
    AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, LPool.FTick + 10);
    LPool.FTick := LPool.FTick + 1000;
    LReleased := ScavengeCentralPools(LPool, 50);
    Check(LReleased = 1, 'round ' + IntToStr(LRound) + ' released');
  end;
  Check(LPool.FEntryCount = 1, 'entry count stays 1 after 16 cycles');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: revival keeps entry count bounded');
end;

{ Test: only old spans released, recent ones kept. }
procedure TestScavengerSelective;
var
  LPool: TCentralPool;
  LReleased: Int32;
  LKeep: array[0..CENTRAL_SPAN_SLOTS - 1] of Pointer;
  LOne: array[0..0] of Pointer;
begin
  CentralPoolInit(LPool, 64);
  { Fill and empty span 0 at tick 10. }
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 10);
  { Fill span 0 again (64 allocs) to exhaust it, don't free. }
  CentralPoolAlloc(LPool, CENTRAL_SPAN_SLOTS, @LKeep[0]);
  { Allocate 1 more → creates span 1 (span 0 is full). }
  CentralPoolAlloc(LPool, 1, @LOne[0]);
  Check(LPool.FEntryCount = 2, '2 entries');
  { Free the 64 from span 0 back at tick 150. }
  LPool.FTick := 149;
  CentralPoolFree(LPool, CENTRAL_SPAN_SLOTS, @LKeep[0]);
  { Free the 1 from span 1 at tick 250. }
  LPool.FTick := 249;
  CentralPoolFree(LPool, 1, @LOne[0]);
  { Span 0: tick=150. Span 1: tick=250. }
  Check(LPool.FEntries[0].FLastFreeTick = 150, 'span 0 tick=150');
  Check(LPool.FEntries[1].FLastFreeTick = 250, 'span 1 tick=250');
  { Scavenge at 300, threshold 100. Span 0 age=150 ≥ 100 → released.
    Span 1 age=50 < 100 → kept. }
  LPool.FTick := 300;
  LReleased := ScavengeCentralPools(LPool, 100);
  Check(LReleased = 1, 'released 1');
  Check(LPool.FEntries[0].FMemory = nil, 'span 0 released');
  Check(LPool.FEntries[1].FMemory <> nil, 'span 1 kept');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: scavenger selective release');
end;

{ Test: scavenge on empty pool is no-op. }
procedure TestScavengerEmpty;
var
  LPool: TCentralPool;
  LReleased: Int32;
begin
  CentralPoolInit(LPool, 64);
  LPool.FTick := 1000;
  LReleased := ScavengeCentralPools(LPool, 1);
  Check(LReleased = 0, 'nothing to release');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: scavenger empty');
end;

{ Test: alloc from span clears its idle tick. }
procedure TestReusedSpanClearsTick;
var
  LPool: TCentralPool;
  LBlocks: array[0..CENTRAL_SPAN_SLOTS - 1] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  LCount := CentralPoolAlloc(LPool, CENTRAL_SPAN_SLOTS, @LBlocks[0]);
  Check(LCount = 64, 'alloc 64');
  LPool.FTick := 199;
  CentralPoolFree(LPool, CENTRAL_SPAN_SLOTS, @LBlocks[0]);
  Check(LPool.FEntries[0].FLastFreeTick = 200, 'tick set');
  { Re-alloc from span — tick should clear. }
  LCount := CentralPoolAlloc(LPool, 1, @LBlocks[0]);
  Check(LCount = 1, 're-alloc 1');
  Check(LPool.FEntries[0].FLastFreeTick = 0, 'tick cleared');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: reused span clears tick');
end;

{ Test: non-fully-free span doesn't get tick. }
procedure TestPartialSpanNoTick;
var
  LPool: TCentralPool;
  LBlocks: array[0..3] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  LCount := CentralPoolAlloc(LPool, 4, @LBlocks[0]);
  Check(LCount = 4, 'alloc 4');
  { Free 1 — span still has 60 allocated (not empty). }
  CentralPoolFree(LPool, 1, @LBlocks[0]);
  Check(LPool.FEntries[0].FLastFreeTick = 0, 'no tick (partial)');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: partial span no tick');
end;

{ Test: lifetime Released* counters advance on hard release. }
procedure TestPoolStatsReleased;
var
  LPool: TCentralPool;
  LStats: TCentralPoolStats;
  LReleased: Int32;
  LBytes: SizeUInt;
begin
  CentralPoolInit(LPool, 64);
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 100);
  CentralPoolGetStats(LPool, LStats);
  Check(LStats.LiveSpans = 1, 'live 1 before scavenge');
  Check(LStats.IdleSpans = 1, 'idle 1');
  Check(LStats.LiveBytes > 0, 'live bytes > 0');
  Check(LStats.ReleasedSpans = 0, 'no release yet');
  LBytes := LStats.LiveBytes;
  LPool.FTick := 200;
  LReleased := ScavengeCentralPools(LPool, 50);
  Check(LReleased = 1, 'released 1');
  CentralPoolGetStats(LPool, LStats);
  Check(LStats.LiveSpans = 0, 'live 0 after');
  Check(LStats.LiveBytes = 0, 'live bytes 0');
  Check(LStats.ReleasedSpans = 1, 'lifetime released spans');
  Check(LStats.ReleasedBytes = LBytes, 'lifetime released bytes');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: pool stats released');
end;

{ Test: soft decommit when age in [DECOMMIT, IDLE).
  FLastFreeTick=0 means "not idle", so free at tick 1. }
procedure TestPoolStatsDecommit;
var
  LPool: TCentralPool;
  LStats: TCentralPoolStats;
  LReleased: Int32;
  LOp: UInt64;
begin
  CentralPoolInit(LPool, 64);
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 1);
  { age = SCAVENGER_DECOMMIT_THRESHOLD (>= soft, < hard) → decommit only. }
  LOp := 1 + SCAVENGER_DECOMMIT_THRESHOLD;
  LPool.FTick := LOp;
  LReleased := ScavengeCentralPools(LPool, SCAVENGER_IDLE_THRESHOLD);
  Check(LReleased = 0, 'no hard release');
  Check(LPool.FEntries[0].FMemory <> nil, 'virtual kept');
  Check(LPool.FEntries[0].FDecommitted, 'decommitted');
  CentralPoolGetStats(LPool, LStats);
  Check(LStats.DecommittedSpans = 1, 'live decommitted count');
  Check(LStats.DecommitEvents = 1, 'lifetime decommit events');
  Check(LStats.DecommittedBytes > 0, 'decommitted bytes');
  Check(LStats.ReleasedSpans = 0, 'still no hard release');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: pool stats decommit');
end;

{ Test: Growing.GetHeapStats + Scavenge on DefaultGrowingAllocator.
  TLS refill/flush is wired to the global singleton (DefaultHeap path). }
procedure TestGrowingHeapStats;
var
  LAlloc: TGrowingAllocator;
  LBefore, LAfter: TGrowingHeapStats;
  LPtrs: array[0..255] of Pointer;
  I: Integer;
  LReleased: Int32;
  LSize: SizeUInt;
  LBeforeReleased: UInt64;
begin
  LSize := 64;
  LAlloc := DefaultGrowingAllocator;
  Check(LAlloc <> nil, 'default growing present');

  for I := 0 to High(LPtrs) do
  begin
    LPtrs[I] := LAlloc.GetMem(LSize);
    Check(LPtrs[I] <> nil, 'alloc');
  end;
  for I := 0 to High(LPtrs) do
    LAlloc.FreeMem(LPtrs[I], LSize);

  LAlloc.GetHeapStats(LBefore);
  Check(LBefore.LiveSpans >= 1, 'live spans after free');
  Check(LBefore.LiveBytes > 0, 'live bytes after free');
  LBeforeReleased := LBefore.ReleasedSpans;

  { Force scavenge flushes TLS then hard-releases idle spans. }
  LReleased := LAlloc.Scavenge;
  Check(LReleased >= 1, 'scavenge released >= 1');
  LAlloc.GetHeapStats(LAfter);
  Check(LAfter.ReleasedSpans >= LBeforeReleased + 1, 'released spans++');
  Check(LAfter.ReleasedBytes > LBefore.ReleasedBytes, 'released bytes++');
  Check(LAfter.LiveBytes < LBefore.LiveBytes, 'live bytes decreased');
  WriteLn('PASS: growing heap stats');
end;

{ Regression: a single-block TLS flush must be safe. FlushToCentral used a
  Word loop bound of "count - 2"; with exactly 1 cached block that underflowed
  to 65535 and turned the chain-build loop into a 64Ki wild write over the
  stack. Repeated 1-block free + Scavenge exercises exactly that path. }
procedure TestSingleBlockFlushScavenge;
var
  LAlloc: TGrowingAllocator;
  LPtr, LPtr2: Pointer;
  LRound: Int32;
begin
  LAlloc := DefaultGrowingAllocator;
  Check(LAlloc <> nil, 'default growing present');
  for LRound := 1 to 8 do
  begin
    LPtr := LAlloc.GetMem(96);
    Check(LPtr <> nil, 'single-block alloc round ' + IntToStr(LRound));
    LAlloc.FreeMem(LPtr, 96);  { exactly one node in this class's TLS list }
    LAlloc.Scavenge;           { ThreadCacheFlushAll -> FlushToCentral(1) }
  end;
  { Heap must stay coherent after repeated single-block flushes. }
  LPtr := LAlloc.GetMem(96);
  LPtr2 := LAlloc.GetMem(96);
  Check((LPtr <> nil) and (LPtr2 <> nil) and (LPtr <> LPtr2),
    'coherent allocs after single-block scavenges');
  LAlloc.FreeMem(LPtr, 96);
  LAlloc.FreeMem(LPtr2, 96);
  LAlloc.Scavenge;
  WriteLn('PASS: single-block flush scavenge');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('scavenger');

  T.Test('scavenger_skip_recent', @TestScavengerSkipsRecent);
  T.Test('scavenger_release_old', @TestScavengerReleasesOld);
  T.Test('alloc_after_scavenge', @TestAllocAfterScavenge);
  T.Test('revival_bounded_entries', @TestRevivalKeepsEntryCountBounded);
  T.Test('scavenger_selective', @TestScavengerSelective);
  T.Test('scavenger_empty', @TestScavengerEmpty);
  T.Test('reused_span_clears_tick', @TestReusedSpanClearsTick);
  T.Test('partial_span_no_tick', @TestPartialSpanNoTick);
  T.Test('pool_stats_released', @TestPoolStatsReleased);
  T.Test('pool_stats_decommit', @TestPoolStatsDecommit);
  T.Test('growing_heap_stats', @TestGrowingHeapStats);
  T.Test('single_block_flush_scavenge', @TestSingleBlockFlushScavenge);

  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
