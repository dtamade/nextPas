program test_central;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.central;

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
  LCount := CentralPoolAlloc(LPool, 1, @LBlocks[0]);
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
  LCount := CentralPoolAlloc(LPool, 32, @LBlocks[0]);
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
  LCount := CentralPoolAlloc(LPool, 128, @LBlocks[0]);
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
  LCount := CentralPoolAlloc(LPool, 4, @LBlocks[0]);
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
  CentralPoolAlloc(LPool, 4, @LBlocks[0]);
  LSaved := LBlocks[0];
  CentralPoolFree(LPool, 1, @LBlocks[0], 0);
  { Free 1 of 4 → span not empty → stays in partial list. }
  CentralPoolAlloc(LPool, 1, @LBlocks[0]);
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
  CentralPoolAlloc(LPool, 10, @LBlocks[0]);
  Check(CentralPoolFreeCount(LPool) = 64 - 10, 'free after alloc');
  CentralPoolFree(LPool, 5, @LBlocks[0], 0);
  Check(CentralPoolFreeCount(LPool) = 64 - 5, 'free after partial free');
  CentralPoolDestroy(LPool);
  WriteLn('PASS: free count');
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

  T.Run;
  T.Summary;
end.
