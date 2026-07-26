program test_mt_fuzz;
{$mode ObjFPC}{$H+}

{ Multi-threaded randomized fuzz over the growing allocator.

  The directed concurrency suites (test_cross_thread_free, test_concurrent)
  cover interleavings we DESIGNED for. This suite covers the ones we did
  not: N symmetric threads each run a random mix of alloc / free-own /
  cross-thread handoff / free-foreign / Scavenge, so span refill, TLS
  flush, inbox drain, scavenger kill/revive and lock-free owner lookups
  collide in unplanned orders.

  Every block is content-tagged and verified before free — silent
  corruption fails the suite. Per-thread fixed seeds keep runs
  reproducible. heaptrc verdicts leaks. }

uses
  nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.atomic,
  nextpas.core.system.heap,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

const
  FUZZ_THREADS = 4;
  FUZZ_OPS = 30000;          { per thread }
  MAX_LIVE = 192;            { per-thread live slots }
  EXCHANGE_SIZE = 256;       { shared cross-thread handoff slots }
  HANDOFF_SIZE = 128;        { fixed size for exchanged blocks (sized free) }
  BASE_SEED = UInt32(20260726);
  TAG_SALT = QWord($C0FFEE00DEADBEEF);
  { Local alloc sizes span the small bands; all >= 16 for the tag. }
  FUZZ_SIZES: array[0..7] of SizeUInt = (16, 24, 32, 48, 64, 128, 256, 1024);

procedure TagBlock(APtr: Pointer);
begin
  PQWord(APtr)[0] := QWord(PtrUInt(APtr)) xor TAG_SALT;
end;

function VerifyBlock(APtr: Pointer): Boolean;
begin
  Result := PQWord(APtr)[0] = (QWord(PtrUInt(APtr)) xor TAG_SALT);
end;

type
  PFuzzShared = ^TFuzzShared;
  TFuzzShared = record
    Alloc: TGrowingAllocator;
    Exchange: array[0..EXCHANGE_SIZE - 1] of Pointer;
    CorruptCount: Int32;
    AllocFailCount: Int32;
  end;

  PFuzzWorkerCtx = ^TFuzzWorkerCtx;
  TFuzzWorkerCtx = record
    Shared: PFuzzShared;
    Seed: UInt32;
  end;

  TLiveBlock = record
    Ptr: Pointer;
    Size: SizeUInt;
  end;

function FuzzWorker(Parameter: Pointer): PtrInt;
var
  LCtx: PFuzzWorkerCtx;
  LShared: PFuzzShared;
  LRng: UInt32;
  LLive: array[0..MAX_LIVE - 1] of TLiveBlock;
  LLiveCount: Integer;
  LOpNo, LOp, LIdx: Integer;
  LSize: SizeUInt;
  LPtr, LExpected: Pointer;

  function RngNext: UInt32;
  begin
    LRng := LRng * 1103515245 + 12345;
    Result := LRng;
  end;

  procedure FreeLiveAt(AIdx: Integer);
  begin
    if not VerifyBlock(LLive[AIdx].Ptr) then
      atomic_fetch_add(LShared^.CorruptCount, 1);
    LShared^.Alloc.FreeMem(LLive[AIdx].Ptr, LLive[AIdx].Size);
    LLive[AIdx] := LLive[LLiveCount - 1];
    Dec(LLiveCount);
  end;

begin
  LCtx := PFuzzWorkerCtx(Parameter);
  LShared := LCtx^.Shared;
  LRng := LCtx^.Seed;
  LLiveCount := 0;
  for LOpNo := 1 to FUZZ_OPS do
  begin
    LOp := Integer(RngNext mod 100);
    if LOp < 45 then
    begin
      { Alloc a random small-band size into the live set. }
      if LLiveCount = MAX_LIVE then
        FreeLiveAt(Integer(RngNext mod UInt32(LLiveCount)));
      LSize := FUZZ_SIZES[RngNext mod UInt32(Length(FUZZ_SIZES))];
      LPtr := LShared^.Alloc.GetMem(LSize);
      if LPtr = nil then
        atomic_fetch_add(LShared^.AllocFailCount, 1)
      else
      begin
        TagBlock(LPtr);
        LLive[LLiveCount].Ptr := LPtr;
        LLive[LLiveCount].Size := LSize;
        Inc(LLiveCount);
      end;
    end
    else if LOp < 70 then
    begin
      { Free a random own block (verify first). }
      if LLiveCount > 0 then
        FreeLiveAt(Integer(RngNext mod UInt32(LLiveCount)));
    end
    else if LOp < 84 then
    begin
      { Publish a fresh block into the exchange for a foreign thread.
        Slot occupied → free locally instead of spinning (no cross-thread
        wait dependencies, so workers can never deadlock each other). }
      LPtr := LShared^.Alloc.GetMem(HANDOFF_SIZE);
      if LPtr = nil then
        atomic_fetch_add(LShared^.AllocFailCount, 1)
      else
      begin
        TagBlock(LPtr);
        LIdx := Integer(RngNext mod UInt32(EXCHANGE_SIZE));
        LExpected := nil;
        if not atomic_compare_exchange_strong(LShared^.Exchange[LIdx],
          LExpected, LPtr, mo_acq_rel, mo_acquire) then
        begin
          if not VerifyBlock(LPtr) then
            atomic_fetch_add(LShared^.CorruptCount, 1);
          LShared^.Alloc.FreeMem(LPtr, HANDOFF_SIZE);
        end;
      end;
    end
    else if LOp < 98 then
    begin
      { Take a foreign block from the exchange and free it cross-thread. }
      LIdx := Integer(RngNext mod UInt32(EXCHANGE_SIZE));
      LPtr := atomic_exchange(LShared^.Exchange[LIdx], nil, mo_acq_rel);
      if LPtr <> nil then
      begin
        if not VerifyBlock(LPtr) then
          atomic_fetch_add(LShared^.CorruptCount, 1);
        LShared^.Alloc.FreeMem(LPtr, HANDOFF_SIZE);
      end;
    end
    else
      { Scavenge: TLS flush + span decommit/hard-release + slot revival
        churn, concurrent with every other thread's traffic. }
      LShared^.Alloc.Scavenge;
  end;
  { Drain own live set (verify + free). }
  while LLiveCount > 0 do
    FreeLiveAt(LLiveCount - 1);
  Result := 0;
end;

procedure TestMtFuzz;
var
  LShared: PFuzzShared;
  LCtx: array[0..FUZZ_THREADS - 1] of TFuzzWorkerCtx;
  LThreads: array[0..FUZZ_THREADS - 1] of TThreadID;
  I: Integer;
  LPtr: Pointer;
  LLeftover: Integer;
begin
  LShared := PFuzzShared(NpSystemGetMem(SizeOf(TFuzzShared)));
  Check(LShared <> nil, 'test state allocated');
  FillChar(LShared^, SizeOf(TFuzzShared), 0);
  LShared^.Alloc := DefaultGrowingAllocator;
  for I := 0 to FUZZ_THREADS - 1 do
  begin
    LCtx[I].Shared := LShared;
    LCtx[I].Seed := BASE_SEED + UInt32(I);
    LThreads[I] := BeginThread(@FuzzWorker, @LCtx[I]);
  end;
  for I := 0 to FUZZ_THREADS - 1 do
    WaitForThreadTerminate(LThreads[I], 0);
  { Workers are gone: drain leftover exchanged blocks on the main thread
    (another cross-thread free — the publisher threads are dead). }
  LLeftover := 0;
  for I := 0 to EXCHANGE_SIZE - 1 do
  begin
    LPtr := atomic_exchange(LShared^.Exchange[I], nil, mo_acq_rel);
    if LPtr <> nil then
    begin
      if not VerifyBlock(LPtr) then
        atomic_fetch_add(LShared^.CorruptCount, 1);
      LShared^.Alloc.FreeMem(LPtr, HANDOFF_SIZE);
      Inc(LLeftover);
    end;
  end;
  Check(LShared^.CorruptCount = 0,
    'zero corrupted tags (got ' + IntToStr(LShared^.CorruptCount) + ')');
  Check(LShared^.AllocFailCount = 0,
    'zero alloc failures (got ' + IntToStr(LShared^.AllocFailCount) + ')');
  NpSystemFreeMem(LShared);
  WriteLn('PASS: mt fuzz ' + IntToStr(FUZZ_THREADS) + ' threads x ' +
    IntToStr(FUZZ_OPS) + ' ops (leftover handoffs drained: ' +
    IntToStr(LLeftover) + ')');
end;

begin
  T := TTestSuite.Create('test_mt_fuzz');
  T.Test('MtFuzz', @TestMtFuzz);
  LRunPassed := T.Run;
  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
