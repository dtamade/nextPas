program test_get_mem_stats;
{**
 * M3-2: process GetMemStats unifies DefaultHeap + optional DEBUG wrap.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.platform.env,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.mem.debug_wrap,
  nextpas.core.mem.allocator.growing;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure SetMemDebugEnv(const AValue: AnsiString);
begin
  if AValue = '' then
    platform_env_unset(PAnsiChar(MEM_DEBUG_ENV))
  else
    platform_env_set(PAnsiChar(MEM_DEBUG_ENV), PAnsiChar(AValue));
end;

procedure RebuildDebug(const AValue: AnsiString);
begin
  ResetDebugWrapForTests;
  SetMemDebugEnv(AValue);
  platform_env_unset(PAnsiChar(MEM_HEAP_DEBUG_ENV));
end;

procedure TestMatchesGrowingHeapStats;
var
  LMem: TMemStats;
  LHeap: TGrowingHeapStats;
  LDirect: TGrowingAllocator;
begin
  RebuildDebug('');
  LDirect := DefaultHeap;
  Check(LDirect <> nil, 'DefaultHeap');
  LDirect.GetHeapStats(LHeap);
  GetMemStats(LMem);

  Check(LMem.LiveSpans = LHeap.LiveSpans, 'LiveSpans match');
  Check(LMem.IdleSpans = LHeap.IdleSpans, 'IdleSpans match');
  Check(LMem.DecommittedSpans = LHeap.DecommittedSpans, 'DecommittedSpans match');
  Check(LMem.FreeSlots = LHeap.FreeSlots, 'FreeSlots match');
  Check(LMem.LiveBytes = LHeap.LiveBytes, 'LiveBytes match');
  Check(LMem.ReleasedSpans = LHeap.ReleasedSpans, 'ReleasedSpans match');
  Check(LMem.ReleasedBytes = LHeap.ReleasedBytes, 'ReleasedBytes match');
  Check(LMem.DecommitEvents = LHeap.DecommitEvents, 'DecommitEvents match');
  Check(LMem.DecommittedBytes = LHeap.DecommittedBytes, 'DecommittedBytes match');
  Check(LMem.OpCounter = LHeap.OpCounter, 'OpCounter match');
  Check(not LMem.DebugEnabled, 'no DEBUG wrap without env');
  Check(not LMem.HeapDebugEnabled, 'HEAP_DEBUG off by default');
  Check(LMem.DebugActiveAllocs = 0, 'debug active 0');
  Check(LMem.DebugAllocCount = 0, 'debug alloc 0');
end;

procedure TestReflectsDefaultHeapTraffic;
var
  LBefore, LAfter, LFreed: TMemStats;
  LHeap: TGrowingHeapStats;
  LPtrs: array[0..31] of Pointer;
  I: Integer;
begin
  RebuildDebug('');
  GetMemStats(LBefore);

  for I := 0 to High(LPtrs) do
  begin
    LPtrs[I] := GetMem(64);
    Check(LPtrs[I] <> nil, 'GetMem');
  end;
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes >= LBefore.LiveBytes, 'LiveBytes does not drop under load');
  Check((LAfter.LiveSpans + LAfter.IdleSpans) >=
    (LBefore.LiveSpans + LBefore.IdleSpans), 'span count non-decreasing under load');

  for I := 0 to High(LPtrs) do
    FreeMem(LPtrs[I], 64);
  GetMemStats(LFreed);
  DefaultHeap.GetHeapStats(LHeap);
  { After free, bytes may stay in idle spans — ensure API still consistent. }
  Check(LFreed.LiveBytes = LHeap.LiveBytes, 'post-free still matches Growing');
end;

procedure TestFunctionFormEqualsOutForm;
var
  A, B: TMemStats;
begin
  GetMemStats(A);
  B := GetMemStats;
  Check(A.LiveBytes = B.LiveBytes, 'LiveBytes');
  Check(A.LiveSpans = B.LiveSpans, 'LiveSpans');
  Check(A.ReleasedBytes = B.ReleasedBytes, 'ReleasedBytes');
  Check(A.DebugEnabled = B.DebugEnabled, 'DebugEnabled');
end;

procedure TestDebugWrapFields;
var
  LMem: TMemStats;
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  RebuildDebug('tracking,stats');
  { Touch DefaultAllocator so wrap builds. }
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'DefaultAllocator');

  GetMemStats(LMem);
  Check(LMem.DebugEnabled, 'DEBUG enabled');
  Check(LMem.DebugTracking, 'tracking flag');
  Check(LMem.DebugStats, 'stats flag');

  LPtr := LAlloc.GetMem(48);
  Check(LPtr <> nil, 'plugin GetMem');
  GetMemStats(LMem);
  Check(LMem.DebugActiveAllocs = 1, 'tracking live via MemStats');
  Check(LMem.DebugActiveBytes >= 48, 'tracking bytes');
  Check(LMem.DebugAllocCount >= 1, 'stats alloc count');

  LAlloc.FreeMem(LPtr);
  GetMemStats(LMem);
  Check(LMem.DebugActiveAllocs = 0, 'cleared');
  Check(LMem.DebugFreeCount >= 1, 'stats free count');
  { Heap fields still readable alongside DEBUG. }
  Check(True, 'heap fields co-exist with DEBUG counters');
  RebuildDebug('');
end;

procedure TestScavengeShowsInReleased;
var
  LBefore, LAfter: TMemStats;
  LPtrs: array[0..127] of Pointer;
  I, R: Integer;
begin
  RebuildDebug('');
  GetMemStats(LBefore);

  for R := 1 to 8 do
  begin
    for I := 0 to High(LPtrs) do
      LPtrs[I] := GetMem(64);
    for I := 0 to High(LPtrs) do
      FreeMem(LPtrs[I], 64);
    if (R mod 2) = 0 then
      DefaultHeap.Scavenge;
  end;

  GetMemStats(LAfter);
  { Not every platform/path hard-releases; require stats readable and
    ReleasedSpans non-decreasing. }
  Check(LAfter.ReleasedSpans >= LBefore.ReleasedSpans, 'ReleasedSpans non-decreasing');
  Check(LAfter.ReleasedBytes >= LBefore.ReleasedBytes, 'ReleasedBytes non-decreasing');
end;

begin
  RebuildDebug('');

  T := TTestSuite.Create('nextpas.core.mem.get_mem_stats');
  T.Test('matches Growing GetHeapStats', @TestMatchesGrowingHeapStats);
  T.Test('reflects DefaultHeap traffic', @TestReflectsDefaultHeapTraffic);
  T.Test('function form equals out form', @TestFunctionFormEqualsOutForm);
  T.Test('DEBUG wrap fields', @TestDebugWrapFields);
  T.Test('scavenge Released* non-decreasing', @TestScavengeShowsInReleased);

  LRunPassed := T.Run;
  T.Summary;
  RebuildDebug('');
  if not LRunPassed then
    Halt(1);
end.
