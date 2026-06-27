program test_scavenger;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.central;

var
  T: TTestSuite;

{ Allocate ACount blocks and free them all at AOpCounter. }
procedure AllocAndFreeAll(var APool: TCentralPool; ACount: Word;
  AOpCounter: UInt64);
var
  LBlocks: array of Pointer;
  LCount: Word;
begin
  SetLength(LBlocks, ACount);
  LCount := CentralPoolAlloc(APool, ACount, @LBlocks[0], 0);
  Check(LCount = ACount, 'alloc ' + IntToStr(ACount));
  CentralPoolFree(APool, ACount, @LBlocks[0], AOpCounter);
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
  LReleased := ScavengeCentralPools(LPool, 150, 1000);
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
  LReleased := ScavengeCentralPools(LPool, 200, 50);
  Check(LReleased = 1, 'released 1');
  Check(LPool.FEntries[0].FMemory = nil, 'memory released');
  Check(LPool.FEntries[0].FLastFreeTick = 0, 'tick cleared');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: scavenger releases old');
end;

{ Test: alloc creates new span after scavenge releases old one. }
procedure TestAllocAfterScavenge;
var
  LPool: TCentralPool;
  LBlocks: array[0..0] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  AllocAndFreeAll(LPool, CENTRAL_SPAN_SLOTS, 100);
  ScavengeCentralPools(LPool, 200, 50);
  Check(LPool.FEntries[0].FMemory = nil, 'released');
  LCount := CentralPoolAlloc(LPool, 1, @LBlocks[0], 0);
  Check(LCount = 1, 'alloc 1');
  Check(LPool.FEntryCount = 2, '2 entries');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: alloc after scavenge');
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
  CentralPoolAlloc(LPool, CENTRAL_SPAN_SLOTS, @LKeep[0], 0);
  { Allocate 1 more → creates span 1 (span 0 is full). }
  CentralPoolAlloc(LPool, 1, @LOne[0], 0);
  Check(LPool.FEntryCount = 2, '2 entries');
  { Free the 64 from span 0 back at tick 150. }
  CentralPoolFree(LPool, CENTRAL_SPAN_SLOTS, @LKeep[0], 150);
  { Free the 1 from span 1 at tick 250. }
  CentralPoolFree(LPool, 1, @LOne[0], 250);
  { Span 0: tick=150. Span 1: tick=250. }
  Check(LPool.FEntries[0].FLastFreeTick = 150, 'span 0 tick=150');
  Check(LPool.FEntries[1].FLastFreeTick = 250, 'span 1 tick=250');
  { Scavenge at 300, threshold 100. Span 0 age=150 ≥ 100 → released.
    Span 1 age=50 < 100 → kept. }
  LReleased := ScavengeCentralPools(LPool, 300, 100);
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
  LReleased := ScavengeCentralPools(LPool, 1000, 1);
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
  LCount := CentralPoolAlloc(LPool, CENTRAL_SPAN_SLOTS, @LBlocks[0], 0);
  Check(LCount = 64, 'alloc 64');
  CentralPoolFree(LPool, CENTRAL_SPAN_SLOTS, @LBlocks[0], 200);
  Check(LPool.FEntries[0].FLastFreeTick = 200, 'tick set');
  { Re-alloc from span — tick should clear. }
  LCount := CentralPoolAlloc(LPool, 1, @LBlocks[0], 0);
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
  LCount := CentralPoolAlloc(LPool, 4, @LBlocks[0], 0);
  Check(LCount = 4, 'alloc 4');
  { Free 1 — span still has 60 allocated (not empty). }
  CentralPoolFree(LPool, 1, @LBlocks[0], 100);
  Check(LPool.FEntries[0].FLastFreeTick = 0, 'no tick (partial)');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: partial span no tick');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('scavenger');

  T.Test('scavenger_skip_recent', @TestScavengerSkipsRecent);
  T.Test('scavenger_release_old', @TestScavengerReleasesOld);
  T.Test('alloc_after_scavenge', @TestAllocAfterScavenge);
  T.Test('scavenger_selective', @TestScavengerSelective);
  T.Test('scavenger_empty', @TestScavengerEmpty);
  T.Test('reused_span_clears_tick', @TestReusedSpanClearsTick);
  T.Test('partial_span_no_tick', @TestPartialSpanNoTick);

  T.Run;
  T.Summary;
end.
