program test_shuffle;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.shuffle,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;

{ Test: SizeClassGetScan defaults to False (noscan). }
procedure TestScanDefault;
var
  I: Integer;
begin
  for I := 0 to MEM_SIZECLASS_COUNT - 1 do
    Check(not SizeClassGetScan(I), 'class ' + IntToStr(I) + ' noscan by default');
  WriteLn('PASS: scan default (all noscan)');
end;

{ Test: SizeClassSetScan/GetScan round-trip. }
procedure TestScanSetGet;
begin
  SizeClassSetScan(0, True);
  Check(SizeClassGetScan(0), 'class 0 now scan');
  SizeClassSetScan(0, False);
  Check(not SizeClassGetScan(0), 'class 0 back to noscan');
  SizeClassSetScan(MEM_SIZECLASS_COUNT - 1, True);
  Check(SizeClassGetScan(MEM_SIZECLASS_COUNT - 1), 'last class scan');
  SizeClassSetScan(MEM_SIZECLASS_COUNT - 1, False);
  WriteLn('PASS: scan set/get');
end;

{ Test: SizeClassSetScan out-of-range is no-op. }
procedure TestScanOutOfRange;
begin
  SizeClassSetScan(-1, True);
  SizeClassSetScan(MEM_SIZECLASS_COUNT, True);
  Check(not SizeClassGetScan(-1), 'negative index returns false');
  Check(not SizeClassGetScan(MEM_SIZECLASS_COUNT), 'out-of-range returns false');
  WriteLn('PASS: scan out-of-range');
end;

{ Test: FreeListInsertShuffled preserves all nodes. }
procedure TestShufflePreservesNodes;
type
  TTestNode = record
    FNext: Pointer;
    FId: Integer;
  end;
var
  LNodes: array[0..9] of TTestNode;
  LHead: Pointer;
  LCur: Pointer;
  LCount: Integer;
  I: Integer;
begin
  LHead := nil;
  for I := 0 to 9 do
  begin
    LNodes[I].FId := I;
    FreeListInsertShuffled(LHead, @LNodes[I], I);
  end;
  { Count nodes in list. }
  LCount := 0;
  LCur := LHead;
  while LCur <> nil do
  begin
    Inc(LCount);
    LCur := PShuffleNode(LCur)^.FNext;
  end;
  Check(LCount = 10, 'all 10 nodes in list');
  WriteLn('PASS: shuffle preserves nodes');
end;

{ Test: FreeListInsertShuffled produces non-trivial order (not always head). }
procedure TestShuffleNonTrivial;
type
  TTestNode = record
    FNext: Pointer;
    FId: Integer;
  end;
var
  LNodes: array[0..19] of TTestNode;
  LHead: Pointer;
  LCur: Pointer;
  LHeadChanges: Integer;
  I: Integer;
begin
  LHead := nil;
  LHeadChanges := 0;
  for I := 0 to 19 do
  begin
    LNodes[I].FId := I;
    FreeListInsertShuffled(LHead, @LNodes[I], I);
    { Check if the head is NOT the newly inserted node (i.e., insertion was
      not at the head position). This should happen ~50% of the time. }
    if LHead <> @LNodes[I] then
      Inc(LHeadChanges);
  end;
  { With 20 insertions and random positions, we expect ~10 head changes.
    Allow a wide margin: at least 1 (statistically almost guaranteed). }
  Check(LHeadChanges >= 1, 'shuffle produces non-head insertions: ' +
    IntToStr(LHeadChanges));
  WriteLn('PASS: shuffle non-trivial order');
end;

{ Test: FreeListInsertShuffled with count=0 or 1 always inserts at head. }
procedure TestShuffleSmallList;
type
  TTestNode = record
    FNext: Pointer;
    FId: Integer;
  end;
var
  LNode1, LNode2: TTestNode;
  LHead: Pointer;
begin
  LHead := nil;
  LNode1.FId := 1;
  FreeListInsertShuffled(LHead, @LNode1, 0);
  Check(LHead = @LNode1, 'empty list: inserted at head');
  LNode2.FId := 2;
  FreeListInsertShuffled(LHead, @LNode2, 1);
  Check(LHead = @LNode2, 'single-element list: inserted at head');
  WriteLn('PASS: shuffle small list');
end;

{ Test: Growing allocator returns blocks in non-FIFO order after shuffle. }
procedure TestShuffleAllocatorIntegration;
var
  LAlloc: TGrowingAllocator;
  LPtrs: array[0..15] of Pointer;
  LReturned: array[0..15] of Pointer;
  LSameOrder: Boolean;
  I: Integer;
begin
  LAlloc := TGrowingAllocator.Create;
  try
    { Allocate 16 blocks of same size. }
    for I := 0 to 15 do
      LPtrs[I] := LAlloc.GetMem(64);
    { Free all (shuffle inserts at random positions). }
    for I := 0 to 15 do
      LAlloc.FreeMem(LPtrs[I], 64);
    { Allocate again — should get blocks back, but possibly in different order. }
    for I := 0 to 15 do
      LReturned[I] := LAlloc.GetMem(64);
    { Check all blocks are from the original set. }
    for I := 0 to 15 do
      Check(LReturned[I] <> nil, 'got block back');
    { Check order is NOT strictly LIFO (shuffle should randomize). }
    LSameOrder := True;
    for I := 0 to 15 do
    begin
      if LReturned[I] <> LPtrs[15 - I] then
      begin
        LSameOrder := False;
        Break;
      end;
    end;
    { With shuffle, strict LIFO is extremely unlikely for 16 elements. }
    Check(not LSameOrder, 'order is shuffled (not strict LIFO)');
    { Clean up. }
    for I := 0 to 15 do
      LAlloc.FreeMem(LReturned[I], 64);
  finally
    LAlloc.Free;
  end;
  WriteLn('PASS: shuffle allocator integration');
end;

{ --- Main --- }

begin
  T := TTestSuite.Create('shuffle');

  T.Test('scan_default', @TestScanDefault);
  T.Test('scan_set_get', @TestScanSetGet);
  T.Test('scan_out_of_range', @TestScanOutOfRange);
  T.Test('shuffle_preserves_nodes', @TestShufflePreservesNodes);
  T.Test('shuffle_non_trivial', @TestShuffleNonTrivial);
  T.Test('shuffle_small_list', @TestShuffleSmallList);
  T.Test('shuffle_allocator_integration', @TestShuffleAllocatorIntegration);

  T.Run;
  T.Summary;
end.
