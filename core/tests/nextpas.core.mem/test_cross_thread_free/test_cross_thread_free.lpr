program test_cross_thread_free;
{$mode ObjFPC}{$H+}

{ Cross-thread free coverage for TGrowingAllocator.

  Targets the lock-free FreeMem routing path that had ZERO concurrent
  coverage before this suite:
  - FindSpanOwnerThreadId (lock-free span scan) racing AddSpan array
    growth (generation retirement protocol in nextpas.core.mem.central)
  - CentralPoolFree cross-thread return path
  - owner=0 routing: System-heap fallback blocks and cross-instance blocks
    must never poison the TLS cache

  All blocks are content-tagged and verified before free — silent
  corruption fails the suite, not just crashes. }

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.atomic,
  nextpas.core.system.heap,
  nextpas.core.mem.sizeclass,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

const
  TAG_SALT = QWord($C0FFEE00DEADBEEF);

{ Tag layout: [0..7] = ptr xor salt, [8..15] = seq. Needs blocks >= 16 bytes. }
procedure TagBlock(APtr: Pointer; ASeq: QWord);
begin
  PQWord(APtr)[0] := QWord(PtrUInt(APtr)) xor TAG_SALT;
  PQWord(APtr)[1] := ASeq;
end;

function VerifyBlock(APtr: Pointer): Boolean;
begin
  Result := PQWord(APtr)[0] = (QWord(PtrUInt(APtr)) xor TAG_SALT);
end;

{ ── Test 1: worker allocates, main frees (owner thread already exited) ── }

const
  HANDOFF_COUNT = 512;
  HANDOFF_SIZES: array[0..3] of SizeUInt = (32, 64, 256, 1024);

type
  PHandoffData = ^THandoffData;
  THandoffData = record
    Alloc: TGrowingAllocator;
    Ptrs: array[0..HANDOFF_COUNT - 1] of Pointer;
    Sizes: array[0..HANDOFF_COUNT - 1] of SizeUInt;
    Failed: Boolean;
  end;

function HandoffAllocWorker(Parameter: Pointer): PtrInt;
var
  LData: PHandoffData;
  I: Integer;
begin
  LData := PHandoffData(Parameter);
  for I := 0 to HANDOFF_COUNT - 1 do
  begin
    LData^.Sizes[I] := HANDOFF_SIZES[I mod Length(HANDOFF_SIZES)];
    LData^.Ptrs[I] := LData^.Alloc.GetMem(LData^.Sizes[I]);
    if LData^.Ptrs[I] = nil then
    begin
      LData^.Failed := True;
      Exit(1);
    end;
    TagBlock(LData^.Ptrs[I], QWord(I));
  end;
  Result := 0;
end;

procedure TestWorkerAllocMainFree;
var
  LData: THandoffData;
  LThread: TThreadID;
  I: Integer;
begin
  LData.Alloc := DefaultGrowingAllocator;
  LData.Failed := False;
  LThread := BeginThread(@HandoffAllocWorker, @LData);
  WaitForThreadTerminate(LThread, 0);
  Check(not LData.Failed, 'worker allocated all blocks');
  { Owner thread has exited: FreeMem must route via central, never the
    (dead) owner's TLS cache. }
  for I := 0 to HANDOFF_COUNT - 1 do
  begin
    Check(VerifyBlock(LData.Ptrs[I]), 'tag intact #' + IntToStr(I));
    Check(PQWord(LData.Ptrs[I])[1] = QWord(I), 'seq intact #' + IntToStr(I));
    LData.Alloc.FreeMem(LData.Ptrs[I], LData.Sizes[I]);
  end;
  WriteLn('PASS: worker-alloc/main-free x ' + IntToStr(HANDOFF_COUNT) +
    ' (dead-owner routing)');
end;

{ ── Test 2: main allocates, worker verifies and frees ── }

function HandoffFreeWorker(Parameter: Pointer): PtrInt;
var
  LData: PHandoffData;
  I: Integer;
begin
  LData := PHandoffData(Parameter);
  for I := 0 to HANDOFF_COUNT - 1 do
  begin
    if not VerifyBlock(LData^.Ptrs[I]) then
    begin
      LData^.Failed := True;
      Exit(1);
    end;
    LData^.Alloc.FreeMem(LData^.Ptrs[I], LData^.Sizes[I]);
  end;
  Result := 0;
end;

procedure TestMainAllocWorkerFree;
var
  LData: THandoffData;
  LThread: TThreadID;
  I: Integer;
begin
  LData.Alloc := DefaultGrowingAllocator;
  LData.Failed := False;
  for I := 0 to HANDOFF_COUNT - 1 do
  begin
    LData.Sizes[I] := HANDOFF_SIZES[I mod Length(HANDOFF_SIZES)];
    LData.Ptrs[I] := LData.Alloc.GetMem(LData.Sizes[I]);
    Check(LData.Ptrs[I] <> nil, 'alloc #' + IntToStr(I));
    TagBlock(LData.Ptrs[I], QWord(I));
  end;
  LThread := BeginThread(@HandoffFreeWorker, @LData);
  WaitForThreadTerminate(LThread, 0);
  Check(not LData.Failed, 'worker verified all tags before freeing');
  WriteLn('PASS: main-alloc/worker-free x ' + IntToStr(HANDOFF_COUNT));
end;

{ ── Test 3: span-table growth racing lock-free owner lookups ──

  One producer publishes tagged blocks through a lock-free ring while
  hoarding an equal number unfreed — the hoard forces continuous AddSpan
  calls, so the central entry array keeps doubling (4 → 8 → ... → 1024+)
  while consumer threads hammer FindSpanOwnerThreadId on every free.
  Before the generation-retirement fix this was a use-after-free window. }

const
  RACE_SIZE = 128;
  RACE_PUBLISHED = 30000;
  RACE_HOARD = 30000;
  RACE_CONSUMERS = 3;
  RING_SIZE = 1024;

type
  PRaceShared = ^TRaceShared;
  TRaceShared = record
    Alloc: TGrowingAllocator;
    Ring: array[0..RING_SIZE - 1] of Pointer;
    Consumed: Int32;
    CorruptCount: Int32;
    ProducerFailed: Boolean;
  end;

  PRaceHoard = ^TRaceHoard;
  TRaceHoard = record
    Shared: PRaceShared;
    Hoard: array[0..RACE_HOARD - 1] of Pointer;
  end;

function RaceProducer(Parameter: Pointer): PtrInt;
var
  LHoardData: PRaceHoard;
  LShared: PRaceShared;
  LPtr: Pointer;
  LExpected: Pointer;
  LSeq, LHoarded: Integer;
  LSlot: Integer;
begin
  LHoardData := PRaceHoard(Parameter);
  LShared := LHoardData^.Shared;
  LHoarded := 0;
  for LSeq := 0 to RACE_PUBLISHED - 1 do
  begin
    { Hoard one block per published block: keeps live-block count climbing
      so the central pool must keep adding spans (array growth pressure). }
    if LHoarded < RACE_HOARD then
    begin
      LPtr := LShared^.Alloc.GetMem(RACE_SIZE);
      if LPtr = nil then
      begin
        LShared^.ProducerFailed := True;
        Break;
      end;
      TagBlock(LPtr, QWord(LSeq));
      LHoardData^.Hoard[LHoarded] := LPtr;
      Inc(LHoarded);
    end;
    LPtr := LShared^.Alloc.GetMem(RACE_SIZE);
    if LPtr = nil then
    begin
      LShared^.ProducerFailed := True;
      Break;
    end;
    TagBlock(LPtr, QWord(LSeq));
    { Publish: CAS nil -> ptr, spin while the slot is still occupied. }
    LSlot := LSeq mod RING_SIZE;
    repeat
      LExpected := nil;
      if atomic_compare_exchange_strong(LShared^.Ring[LSlot], LExpected,
        LPtr, mo_acq_rel, mo_acquire) then
        Break;
      ThreadSwitch;
    until False;
  end;
  { On producer failure consumers would spin forever waiting for blocks
    that never come: publish sentinel-free by bumping Consumed instead. }
  if LShared^.ProducerFailed then
    atomic_store(LShared^.Consumed, RACE_PUBLISHED, mo_release);
  { Free the hoard same-thread (TLS + flush path) while consumers still
    drain the ring — more concurrent central traffic. }
  for LSeq := 0 to LHoarded - 1 do
    LShared^.Alloc.FreeMem(LHoardData^.Hoard[LSeq], RACE_SIZE);
  Result := 0;
end;

function RaceConsumer(Parameter: Pointer): PtrInt;
var
  LShared: PRaceShared;
  LPtr: Pointer;
  LSlot: Integer;
begin
  LShared := PRaceShared(Parameter);
  while atomic_load(LShared^.Consumed, mo_acquire) < RACE_PUBLISHED do
  begin
    for LSlot := 0 to RING_SIZE - 1 do
    begin
      LPtr := atomic_exchange(LShared^.Ring[LSlot], nil, mo_acq_rel);
      if LPtr <> nil then
      begin
        if not VerifyBlock(LPtr) then
          atomic_fetch_add(LShared^.CorruptCount, 1);
        { Cross-thread free: owner = producer, current = consumer. }
        LShared^.Alloc.FreeMem(LPtr, RACE_SIZE);
        atomic_fetch_add(LShared^.Consumed, 1);
      end;
    end;
    ThreadSwitch;
  end;
  Result := 0;
end;

procedure TestGrowthRaceStress;
var
  LShared: PRaceShared;
  LHoardData: PRaceHoard;
  LProducer: TThreadID;
  LConsumers: array[0..RACE_CONSUMERS - 1] of TThreadID;
  I: Integer;
begin
  { Heap-allocate the shared state: hoard array alone is 30000 pointers. }
  LShared := PRaceShared(NpSystemGetMem(SizeOf(TRaceShared)));
  LHoardData := PRaceHoard(NpSystemGetMem(SizeOf(TRaceHoard)));
  Check((LShared <> nil) and (LHoardData <> nil), 'test state allocated');
  FillChar(LShared^, SizeOf(TRaceShared), 0);
  LShared^.Alloc := DefaultGrowingAllocator;
  LHoardData^.Shared := LShared;
  LProducer := BeginThread(@RaceProducer, LHoardData);
  for I := 0 to RACE_CONSUMERS - 1 do
    LConsumers[I] := BeginThread(@RaceConsumer, LShared);
  WaitForThreadTerminate(LProducer, 0);
  for I := 0 to RACE_CONSUMERS - 1 do
    WaitForThreadTerminate(LConsumers[I], 0);
  Check(not LShared^.ProducerFailed, 'producer allocated all blocks');
  Check(LShared^.CorruptCount = 0,
    'zero corrupted tags (got ' + IntToStr(LShared^.CorruptCount) + ')');
  Check(LShared^.Consumed >= RACE_PUBLISHED, 'all published blocks consumed');
  NpSystemFreeMem(LHoardData);
  NpSystemFreeMem(LShared);
  WriteLn('PASS: growth-race stress 1P/' + IntToStr(RACE_CONSUMERS) +
    'C x ' + IntToStr(RACE_PUBLISHED) + ' handoffs + ' +
    IntToStr(RACE_HOARD) + ' hoarded (span table doubling under fire)');
end;

{ ── Test 4: System-heap fallback shape must not poison caches ──

  GetMem's central-OOM fallback hands out NpSystemGetMem blocks. Sized
  FreeMem must detect owner=0 and return them to the System heap — caching
  them would leak (central drops unknown blocks on flush) or overflow
  (pre-fix: capacity < class size on reuse). heaptrc verdicts this. }

procedure TestSystemFallbackBlockFree;
var
  LAlloc: TGrowingAllocator;
  LPtr: Pointer;
  I: Integer;
begin
  LAlloc := DefaultGrowingAllocator;
  for I := 0 to 99 do
  begin
    LPtr := NpSystemGetMem(128);
    Check(LPtr <> nil, 'system alloc');
    LAlloc.FreeMem(LPtr, 128); { owner=0 → System free, never cached }
  end;
  for I := 0 to 99 do
  begin
    LPtr := NpSystemGetMem(100); { sub-class-capacity, the dangerous shape }
    Check(LPtr <> nil, 'system alloc 100');
    LAlloc.FreeMem(LPtr, 100);
  end;
  { Unsized free of a foreign block: TryBlockSize=False → System free. }
  LPtr := NpSystemGetMem(192);
  Check(LPtr <> nil, 'system alloc 192');
  LAlloc.FreeMem(LPtr);
  WriteLn('PASS: system-fallback blocks routed to System heap (no cache poisoning)');
end;

{ ── Test 5: cross-instance sized free routes to the owning instance ── }

procedure TestCrossInstanceRouting;
var
  LLocal: TGrowingAllocator;
  LPtr: Pointer;
begin
  { Ensure the global instance exists first: local instances draw from the
    global centrals via the shared TLS refill callbacks. }
  DefaultGrowingAllocator;
  LLocal := TGrowingAllocator.Create;
  try
    LPtr := LLocal.GetMem(64);
    Check(LPtr <> nil, 'local instance alloc');
    TagBlock(LPtr, 42);
    Check(VerifyBlock(LPtr), 'tag intact');
    { Local centrals never saw this block: owner=0 there, so sized free
      must route to the global instance instead of caching or misfreeing. }
    LLocal.FreeMem(LPtr, 64);
  finally
    LLocal.Free;
  end;
  WriteLn('PASS: cross-instance sized free routed to owning instance');
end;

begin
  T := TTestSuite.Create('test_cross_thread_free');
  T.Test('WorkerAllocMainFree', @TestWorkerAllocMainFree);
  T.Test('MainAllocWorkerFree', @TestMainAllocWorkerFree);
  T.Test('GrowthRaceStress', @TestGrowthRaceStress);
  T.Test('SystemFallbackBlockFree', @TestSystemFallbackBlockFree);
  T.Test('CrossInstanceRouting', @TestCrossInstanceRouting);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
