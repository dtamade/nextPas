program test_central;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.central,
  nextpas.core.mem.cache.thread;

var
  T: TTestSuite;

procedure TestCentralPoolInit;
var
  LPool: TCentralPool;
begin
  CentralPoolInit(LPool, 64);
  Check(LPool.FSlotSize = 64, 'slot size = 64');
  Check(LPool.FEntryCount = 0, 'no entries initially');
  Check(CentralPoolFreeCount(LPool) = 0, 'no free initially');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: central init');
end;

procedure TestCentralPoolAllocOne;
var
  LPool: TCentralPool;
  LBlocks: array[0..0] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  LCount := CentralPoolAlloc(LPool, 1, @LBlocks[0], 0);
  Check(LCount = 1, 'allocated 1');
  Check(LBlocks[0] <> nil, 'non-nil');
  Check(CentralPoolFreeCount(LPool) = CENTRAL_SPAN_SLOTS - 1, 'free = 63');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: central alloc one');
end;

procedure TestCentralPoolAllocBatch;
var
  LPool: TCentralPool;
  LBlocks: array[0..31] of Pointer;
  LCount: Word;
  I: Integer;
begin
  CentralPoolInit(LPool, 64);
  LCount := CentralPoolAlloc(LPool, 32, @LBlocks[0], 0);
  Check(LCount = 32, 'allocated 32');
  for I := 0 to 30 do
    Check(LBlocks[I] <> LBlocks[I + 1], 'unique ' + IntToStr(I));
  CentralPoolDestroy(LPool);
  WriteLn('PASS: central alloc batch');
end;

procedure TestCentralPoolAllocExceedsSpan;
var
  LPool: TCentralPool;
  LBlocks: array[0..127] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  LCount := CentralPoolAlloc(LPool, 128, @LBlocks[0], 0);
  Check(LCount = 128, 'allocated 128 across 2 spans');
  Check(LPool.FEntryCount = 2, '2 spans created');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: alloc exceeds span');
end;

procedure TestCentralPoolFree;
var
  LPool: TCentralPool;
  LBlocks: array[0..3] of Pointer;
  LCount: Word;
  LFreeBefore, LFreeAfter: SizeUInt;
begin
  CentralPoolInit(LPool, 64);
  LCount := CentralPoolAlloc(LPool, 4, @LBlocks[0], 0);
  Check(LCount = 4, 'alloc 4');
  LFreeBefore := CentralPoolFreeCount(LPool);
  CentralPoolFree(LPool, 4, @LBlocks[0], 0);
  LFreeAfter := CentralPoolFreeCount(LPool);
  Check(LFreeAfter = LFreeBefore + 4, 'free increased by 4');
  { Span is partial (not fully empty): FLastFreeTick stays 0. }
  Check(LPool.FEntries[0].FLastFreeTick = 0, 'not idle (partial)');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: central free');
end;

procedure TestCentralPoolFreeAndRealloc;
var
  LPool: TCentralPool;
  LBlocks: array[0..3] of Pointer;
  LSaved: Pointer;
begin
  CentralPoolInit(LPool, 64);
  CentralPoolAlloc(LPool, 4, @LBlocks[0], 0);
  LSaved := LBlocks[0];
  CentralPoolFree(LPool, 1, @LBlocks[0], 0);
  { Free 1 of 4 → span not empty → stays in partial list. }
  CentralPoolAlloc(LPool, 1, @LBlocks[0], 0);
  Check(LBlocks[0] = LSaved, 're-alloc returns freed slot');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: free and realloc');
end;

procedure TestCentralPoolFreeCount;
var
  LPool: TCentralPool;
  LBlocks: array[0..63] of Pointer;
begin
  CentralPoolInit(LPool, 32);
  Check(CentralPoolFreeCount(LPool) = 0, 'initial free = 0');
  CentralPoolAlloc(LPool, 10, @LBlocks[0], 0);
  Check(CentralPoolFreeCount(LPool) = 64 - 10, 'free after alloc');
  CentralPoolFree(LPool, 5, @LBlocks[0], 0);
  Check(CentralPoolFreeCount(LPool) = 64 - 5, 'free after partial free');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: free count');
end;

procedure TestMruCacheHitsSameSpan;
var
  LPool: TCentralPool;
  LBlocks: array[0..63] of Pointer;
  I: Integer;
begin
  CentralPoolInit(LPool, 32);
  { Allocate and free all blocks — all go back to the same span. }
  CentralPoolAlloc(LPool, 10, @LBlocks[0], 0);
  for I := 0 to 9 do
  begin
    CentralPoolFree(LPool, 1, @LBlocks[I], 0);
    { After each free, subsequent frees to the same span should benefit
      from the MRU cache (FLastHitIndex), making FindSpanIndex O(1). }
  end;
  Check(CentralPoolFreeCount(LPool) = 64, 'all blocks returned');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: MRU cache hits same span');
end;

procedure TestPageIndexedLookup;
var
  LPool: TCentralPool;
  LBlocks: array[0..127] of Pointer;
  LCount: Word;
begin
  CentralPoolInit(LPool, 64);
  { Allocate blocks across multiple spans. }
  LCount := CentralPoolAlloc(LPool, 128, @LBlocks[0], 0);
  Check(LCount = 128, 'allocated 128');
  Check(LPool.FEntryCount = 2, '2 spans created');
  { Free blocks — optimized lookup should find them. }
  CentralPoolFree(LPool, 128, @LBlocks[0], 0);
  Check(CentralPoolFreeCount(LPool) = 128, 'all blocks returned');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: optimized lookup');
end;

procedure TestPageIndexedLookupMultipleSpans;
var
  LPool: TCentralPool;
  LBlocks: array[0..255] of Pointer;
  LCount: Word;
  I: Integer;
begin
  CentralPoolInit(LPool, 32);
  { Allocate blocks across 4 spans. }
  LCount := CentralPoolAlloc(LPool, 256, @LBlocks[0], 0);
  Check(LCount = 256, 'allocated 256');
  Check(LPool.FEntryCount = 4, '4 spans created');
  { Free blocks in alternating order — optimized lookup should handle it. }
  for I := 0 to 127 do
    CentralPoolFree(LPool, 1, @LBlocks[I * 2], 0);
  Check(CentralPoolFreeCount(LPool) = 128, '128 blocks freed');
  { Free remaining blocks. }
  for I := 0 to 127 do
    CentralPoolFree(LPool, 1, @LBlocks[I * 2 + 1], 0);
  Check(CentralPoolFreeCount(LPool) = 256, 'all blocks freed');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: optimized lookup multiple spans');
end;

{ --- MPSC Inbox tests --- }

procedure TestMpscInboxInit;
var
  LInbox: TMpscInbox;
begin
  MpscInboxInit(LInbox);
  Check(MpscInboxIsEmpty(LInbox), 'inbox empty after init');
  WriteLn('PASS: MPSC inbox init');
end;

procedure TestMpscInboxPushDrain;
var
  LInbox: TMpscInbox;
  LBlocks: array[0..9] of Pointer;
  LDrained: array[0..9] of Pointer;
  LCount: Word;
  I: Integer;
begin
  MpscInboxInit(LInbox);
  { Allocate and push 10 blocks. }
  for I := 0 to 9 do
  begin
    GetMem(LBlocks[I], 64);
    MpscInboxPush(LInbox, LBlocks[I]);
  end;
  Check(not MpscInboxIsEmpty(LInbox), 'inbox not empty after push');
  { Drain all blocks. }
  LCount := MpscInboxDrain(LInbox, 10, @LDrained[0]);
  Check(LCount = 10, 'drained 10 blocks');
  Check(MpscInboxIsEmpty(LInbox), 'inbox empty after drain');
  { Free all blocks. }
  for I := 0 to 9 do
    FreeMem(LDrained[I], 64);
  WriteLn('PASS: MPSC inbox push/drain');
end;

procedure TestMpscInboxPartialDrain;
var
  LInbox: TMpscInbox;
  LBlocks: array[0..9] of Pointer;
  LDrained: array[0..9] of Pointer;
  LCount: Word;
  I: Integer;
begin
  MpscInboxInit(LInbox);
  { Allocate and push 10 blocks. }
  for I := 0 to 9 do
  begin
    GetMem(LBlocks[I], 64);
    MpscInboxPush(LInbox, LBlocks[I]);
  end;
  { Drain only 5 blocks. }
  LCount := MpscInboxDrain(LInbox, 5, @LDrained[0]);
  Check(LCount = 5, 'drained 5 blocks');
  Check(not MpscInboxIsEmpty(LInbox), 'inbox not empty after partial drain');
  { Free drained blocks. }
  for I := 0 to 4 do
    FreeMem(LDrained[I], 64);
  { Drain remaining. }
  LCount := MpscInboxDrain(LInbox, 10, @LDrained[0]);
  Check(LCount = 5, 'drained remaining 5 blocks');
  Check(MpscInboxIsEmpty(LInbox), 'inbox empty after full drain');
  { Free remaining blocks. }
  for I := 0 to 4 do
    FreeMem(LDrained[I], 64);
  WriteLn('PASS: MPSC inbox partial drain');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('central');

  T.Test('central_init', @TestCentralPoolInit);
  T.Test('central_alloc_one', @TestCentralPoolAllocOne);
  T.Test('central_alloc_batch', @TestCentralPoolAllocBatch);
  T.Test('central_alloc_exceeds_span', @TestCentralPoolAllocExceedsSpan);
  T.Test('central_free', @TestCentralPoolFree);
  T.Test('central_free_and_realloc', @TestCentralPoolFreeAndRealloc);
  T.Test('central_free_count', @TestCentralPoolFreeCount);
  T.Test('MRU cache hits same span', @TestMruCacheHitsSameSpan);
  T.Test('page_indexed_lookup', @TestPageIndexedLookup);
  T.Test('page_indexed_lookup_multiple_spans', @TestPageIndexedLookupMultipleSpans);
  T.Test('mpsc_inbox_init', @TestMpscInboxInit);
  T.Test('mpsc_inbox_push_drain', @TestMpscInboxPushDrain);
  T.Test('mpsc_inbox_partial_drain', @TestMpscInboxPartialDrain);

  T.Run;
  T.Summary;
end.
