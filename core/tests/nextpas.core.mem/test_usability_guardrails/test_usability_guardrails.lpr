program test_usability_guardrails;
{**
 * Usability guardrails (F1–F7):
 *   - Dual-track: DefaultHeap ≠ DefaultAllocator path (real surface checks)
 *   - NEXTPAS_MEM_DEBUG does not observe process GetMem traffic (gap visible)
 *   - HEAP_SAFETY routes process path + injects tracking/sentinel
 *   - FreeMemOf / TryFreeMemOf sized same-heap path
 *   - ARENA_STRICT dual mode for arena FreeMem
 *   - FormatAllocErrorMsg contract helpers
 *   - Preferred sized FreeMem / ReallocMem process path
 *   - Dual-track same-heap free round-trip (S5 ownership)
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.platform.env,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.error,
  nextpas.core.mem,
  nextpas.core.mem.default,
  nextpas.core.mem.debug_wrap,
  nextpas.core.mem.allocator.rtl,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.allocator.tracking;

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

procedure SetHeapDebugEnv(const AValue: AnsiString);
begin
  if AValue = '' then
    platform_env_unset(PAnsiChar(MEM_HEAP_DEBUG_ENV))
  else
    platform_env_set(PAnsiChar(MEM_HEAP_DEBUG_ENV), PAnsiChar(AValue));
end;

procedure SetHeapSafetyEnv(const AValue: AnsiString);
begin
  if AValue = '' then
    platform_env_unset(PAnsiChar(MEM_HEAP_SAFETY_ENV))
  else
    platform_env_set(PAnsiChar(MEM_HEAP_SAFETY_ENV), PAnsiChar(AValue));
end;

procedure SetArenaStrictEnv(const AValue: AnsiString);
begin
  if AValue = '' then
    platform_env_unset(PAnsiChar(MEM_ARENA_STRICT_ENV))
  else
    platform_env_set(PAnsiChar(MEM_ARENA_STRICT_ENV), PAnsiChar(AValue));
end;

procedure RebuildDebug(const AValue: AnsiString);
begin
  ResetDebugWrapForTests;
  SetMemDebugEnv(AValue);
  SetHeapDebugEnv('');
  SetHeapSafetyEnv('');
  SetArenaStrictEnv('');
end;

procedure TestDualTrackIdentity;
var
  LHeap: TGrowingAllocator;
  LAlloc: IAllocator;
begin
  RebuildDebug('');
  LHeap := DefaultHeap;
  LAlloc := DefaultAllocator;
  Check(LHeap <> nil, 'DefaultHeap non-nil');
  Check(LAlloc <> nil, 'DefaultAllocator non-nil');
  Check(LHeap = DefaultGrowingAllocator, 'DefaultHeap alias');
  Check(LAlloc = GetGrowingIAllocator, 'no DEBUG → DefaultAllocator is Growing IAllocator');
  Check(LAlloc <> GetRtlAllocator, 'DefaultAllocator is not RTL (S5)');
  { Dual-track surfaces: concrete Growing vs IAllocator (same heap, different call shape). }
  Check(LHeap is TGrowingAllocator, 'DefaultHeap concrete Growing type');
  Check((LAlloc as TObject) is TGrowingIAllocator,
    'DefaultAllocator bare root is Growing IAllocator plug-in');
end;

procedure TestDebugDoesNotTrackProcessGetMem;
var
  LTrack: TTrackingAllocator;
  LAlloc: IAllocator;
  LPtr: Pointer;
  LPlugin: Pointer;
  LBefore, LAfter: SizeInt;
  LMem: TMemStats;
  LLine: string;
begin
  RebuildDebug('tracking,stats');
  LAlloc := DefaultAllocator;
  Check(LAlloc <> GetGrowingIAllocator, 'DEBUG wraps DefaultAllocator');
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking layer present');
  Check(not IsMemHeapDebugEnabled, 'HEAP_DEBUG default off');

  LBefore := LTrack.ActiveAllocCount;

  { Hot path — must NOT increment DEBUG tracking (HEAP_DEBUG off). }
  LPtr := GetMem(64);
  Check(LPtr <> nil, 'process GetMem');
  LAfter := LTrack.ActiveAllocCount;
  Check(LAfter = LBefore, 'GetMem does not touch DEBUG tracking');
  FreeMem(LPtr, 64);
  Check(LTrack.ActiveAllocCount = LBefore, 'FreeMem process still no track');

  { F1: coverage gap must be explicit. }
  GetMemStats(LMem);
  Check(LMem.DebugEnabled, 'DEBUG wrap enabled');
  Check(not LMem.HeapDebugEnabled, 'process route off');
  Check(LMem.DebugCoverageGap, 'DebugCoverageGap true when DEBUG-only');
  Check(MemDebugCoverageGap(LMem), 'MemDebugCoverageGap helper');
  LLine := FormatMemStats(LMem);
  Check(Pos('debug_coverage_gap=y', LLine) > 0, 'FormatMemStats gap=y');
  Check(Pos('debug_process=n', LLine) > 0, 'FormatMemStats process=n');
  Check(Pos('WARN=debug_coverage_gap', LLine) > 0, 'FormatMemStats WARN on gap');

  { Plugin path — MUST be visible to tracking. }
  LPlugin := LAlloc.GetMem(32);
  Check(LPlugin <> nil, 'DefaultAllocator.GetMem');
  Check(LTrack.ActiveAllocCount = LBefore + 1, 'plugin alloc tracked');
  LAlloc.FreeMem(LPlugin);
  Check(LTrack.ActiveAllocCount = LBefore, 'plugin free untracked');
end;

procedure TestHeapDebugOptInTracksProcessGetMem;
var
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
  LMem: TMemStats;
  LLine: string;
begin
  RebuildDebug('tracking,stats');
  SetHeapDebugEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapDebugEnabled, 'HEAP_DEBUG on');
  Check(DefaultAllocator <> nil, 'wrap');
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking');

  LPtr := GetMem(64);
  Check(LPtr <> nil, 'process GetMem');
  Check(LTrack.ActiveAllocCount = 1, 'opt-in tracks process GetMem');
  GetMemStats(LMem);
  Check(LMem.HeapDebugEnabled and (LMem.DebugActiveAllocs = 1), 'MemStats agrees');
  Check(not LMem.DebugCoverageGap, 'no gap when HEAP_DEBUG on');
  Check(LMem.DebugObservesProcess, 'debug_process true');
  LLine := FormatMemStats(LMem);
  Check(Pos('debug_coverage_gap=n', LLine) > 0, 'gap=n under HEAP_DEBUG');
  Check(Pos('debug_process=y', LLine) > 0, 'process=y under HEAP_DEBUG');
  FreeMem(LPtr, 64);
  Check(LTrack.ActiveAllocCount = 0, 'opt-in free clears');
  RebuildDebug('');
end;

procedure TestHeapSafetyOptInTracksProcessGetMem;
{ F3: NEXTPAS_MEM_HEAP_SAFETY alone routes process GetMem and injects tracking. }
var
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
  LMem: TMemStats;
begin
  RebuildDebug('');
  SetHeapSafetyEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapSafetyEnabled, 'HEAP_SAFETY on');
  Check(IsMemHeapDebugEnabled, 'SAFETY implies process route (IsMemHeapDebugEnabled)');
  Check(not IsMemArenaStrictEnabled, 'ARENA_STRICT independent default off');

  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'SAFETY injects tracking');
  LPtr := GetMem(48);
  Check(LPtr <> nil, 'process GetMem under SAFETY');
  Check(LTrack.ActiveAllocCount = 1, 'SAFETY tracks process GetMem');
  GetMemStats(LMem);
  Check(LMem.HeapSafetyEnabled, 'stats.HeapSafetyEnabled');
  Check(LMem.HeapDebugEnabled, 'process route flag');
  Check(LMem.DebugEnabled, 'wrap built');
  Check(not LMem.DebugCoverageGap, 'no gap under SAFETY');
  FreeMem(LPtr, 48);
  Check(LTrack.ActiveAllocCount = 0, 'SAFETY free clears');
  RebuildDebug('');
end;

procedure TestGetMemStatsDebugFieldsOnlyForPlugin;
var
  LMem: TMemStats;
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  RebuildDebug('tracking,stats');
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'plugin');

  LPtr := GetMem(128);
  Check(LPtr <> nil, 'hot GetMem');
  GetMemStats(LMem);
  Check(LMem.DebugEnabled, 'DEBUG config enabled');
  Check(LMem.DebugActiveAllocs = 0, 'hot path not in DebugActiveAllocs');
  FreeMem(LPtr, 128);

  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'plugin GetMem');
  GetMemStats(LMem);
  Check(LMem.DebugActiveAllocs >= 1, 'plugin alloc in DebugActiveAllocs');
  LAlloc.FreeMem(LPtr);
end;

procedure TestProcessSizedFreePreferred;
var
  LPtr: Pointer;
  LSz: SizeUInt;
  LBefore, LAfter: TMemStats;
begin
  RebuildDebug('');
  GetMemStats(LBefore);
  LPtr := GetMem(96);
  Check(LPtr <> nil, 'GetMem 96');
  PInteger(LPtr)^ := 123;
  Check(PInteger(LPtr)^ = 123, 'write');
  Check(TryBlockSize(LPtr, LSz), 'owned before sized free');
  FreeMem(LPtr, 96);
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes <= LBefore.LiveBytes + 96,
    'sized FreeMem does not leak net live_bytes beyond prior');

  LPtr := GetMem(48);
  Check(LPtr <> nil, 'GetMem 48');
  LPtr := ReallocMem(LPtr, 48, 192);
  Check(LPtr <> nil, 'sized ReallocMem');
  FreeMem(LPtr, 192);
  GetMemStats(LAfter);
  Check(LAfter.FreeSlots >= LBefore.FreeSlots, 'free slots restored after sized free cycle');
end;

procedure TestProcessTryBlockSize;
var
  LPtr: Pointer;
  LSz: SizeUInt;
  LBefore, LAfter: TMemStats;
begin
  RebuildDebug('');
  Check(not TryBlockSize(nil, LSz), 'nil → False');
  Check(LSz = 0, 'nil size zero');

  GetMemStats(LBefore);
  LPtr := GetMem(96);
  Check(LPtr <> nil, 'GetMem 96');
  Check(TryBlockSize(LPtr, LSz), 'owned block');
  Check(LSz >= 96, 'size-class >= request');
  FreeMem(LPtr, LSz);
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes <= LBefore.LiveBytes + LSz,
    'sized free after TryBlockSize balances live_bytes');
end;

procedure TestFreeMemOfSizedSameHeap;
{ F2: FreeMemOf prefers DefaultHeap sized free when DEBUG route is off. }
var
  LPlugin: IAllocator;
  LPtr: Pointer;
  LSz: SizeUInt;
  LBefore, LAfter: TMemStats;
begin
  RebuildDebug('');
  LPlugin := DefaultAllocator;
  GetMemStats(LBefore);
  LPtr := LPlugin.GetMem(80);
  Check(LPtr <> nil, 'plugin alloc');
  Check(TryBlockSize(LPtr, LSz), 'same-heap size-class');
  Check(LSz >= 80, 'class >= 80');
  FreeMemOf(LPlugin, LPtr, LSz);
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes <= LBefore.LiveBytes + LSz, 'FreeMemOf balances live_bytes');

  LPtr := LPlugin.GetMem(64);
  Check(LPtr <> nil, 'plugin alloc 2');
  Check(TryFreeMemOf(LPlugin, LPtr, 64), 'TryFreeMemOf');
  Check(not TryFreeMemOf(LPlugin, nil, 64), 'TryFreeMemOf nil → False');
  Check(not TryFreeMemOf(nil, Pointer(PtrUInt(1)), 16), 'nil alloc + foreign → False');
end;

procedure TestTryFreeMemOfNilAllocatorOwned;
{ U1: TryFreeMemOf(nil, owned) frees; foreign still False (fail-closed).
  Under HEAP_DEBUG sized gate is off — still frees via process FreeMem. }
var
  LPtr: Pointer;
  LSz: SizeUInt;
  LBefore, LAfter: TMemStats;
begin
  RebuildDebug('');
  LPtr := GetMem(48);
  Check(LPtr <> nil, 'process alloc');
  Check(TryBlockSize(LPtr, LSz), 'owned size-class');
  GetMemStats(LBefore);
  Check(TryFreeMemOf(nil, LPtr, LSz), 'nil alloc + owned → free True');
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes <= LBefore.LiveBytes, 'live_bytes not increased after free');
  Check(not TryFreeMemOf(nil, Pointer(PtrUInt(1)), 16), 'foreign still False');

  { HEAP_DEBUG: FreeMemOfAllowsSizedHeapFree=False; process FreeMem still tracks. }
  RebuildDebug('');
  SetHeapDebugEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapDebugEnabled, 'HEAP_DEBUG on');
  LPtr := GetMem(32);
  Check(LPtr <> nil, 'process alloc under HEAP_DEBUG');
  Check(TryFreeMemOf(nil, LPtr, 32), 'nil alloc frees under HEAP_DEBUG');
  RebuildDebug('');
end;

procedure TestFreeMemOfUnderPluginDebugTracksFree;
{ FreeMemOf must not bypass tracking Free when NEXTPAS_MEM_DEBUG is on
  (HEAP_DEBUG still off). Sized DefaultHeap free would leave ActiveAllocCount stale. }
var
  LPlugin: IAllocator;
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
  LSz: SizeUInt;
  LBefore: SizeInt;
begin
  RebuildDebug('tracking,stats');
  Check(not IsMemHeapDebugEnabled, 'HEAP_DEBUG off');
  LPlugin := DefaultAllocator;
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking wrap');
  LBefore := LTrack.ActiveAllocCount;

  LPtr := LPlugin.GetMem(80);
  Check(LPtr <> nil, 'plugin alloc under DEBUG');
  Check(LTrack.ActiveAllocCount = LBefore + 1, 'alloc tracked');
  Check(TryBlockSize(LPtr, LSz), 'same-heap size-class');
  FreeMemOf(LPlugin, LPtr, LSz);
  Check(LTrack.ActiveAllocCount = LBefore, 'FreeMemOf clears tracking (no stale active)');

  LPtr := LPlugin.GetMem(64);
  Check(LPtr <> nil, 'plugin alloc 2');
  Check(TryFreeMemOf(LPlugin, LPtr, 64), 'TryFreeMemOf under DEBUG');
  Check(LTrack.ActiveAllocCount = LBefore, 'TryFreeMemOf clears tracking');
  RebuildDebug('');
end;

procedure TestReallocMemOfSizedSameHeap;
{ R3: ReallocMemOf prefers DefaultHeap sized realloc when wrap off. }
var
  LPlugin: IAllocator;
  LPtr, LNew: Pointer;
  LSz: SizeUInt;
  LBefore, LAfter: TMemStats;
begin
  RebuildDebug('');
  LPlugin := DefaultAllocator;
  GetMemStats(LBefore);
  LPtr := LPlugin.GetMem(64);
  Check(LPtr <> nil, 'plugin alloc');
  Check(TryBlockSize(LPtr, LSz), 'size-class');
  LNew := ReallocMemOf(LPlugin, LPtr, LSz, 128);
  Check(LNew <> nil, 'ReallocMemOf grow');
  Check(TryBlockSize(LNew, LSz), 'still size-class');
  Check(LSz >= 128, 'class >= 128');
  Check(TryReallocMemOf(LPlugin, LNew, LSz, 64, LPtr), 'TryReallocMemOf shrink');
  Check(LPtr <> nil, 'shrink ptr');
  FreeMemOf(LPlugin, LPtr, 64);
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes <= LBefore.LiveBytes + 256, 'realloc round-trip live_bytes');
end;

procedure TestReallocMemOfUnderPluginDebugTracks;
{ R3: under DEBUG wrap, ReallocMemOf must not bypass tracking. }
var
  LPlugin: IAllocator;
  LTrack: TTrackingAllocator;
  LPtr, LNew: Pointer;
  LBefore: SizeInt;
begin
  RebuildDebug('tracking,stats');
  LPlugin := DefaultAllocator;
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking');
  LBefore := LTrack.ActiveAllocCount;
  LPtr := LPlugin.GetMem(48);
  Check(LPtr <> nil, 'alloc');
  Check(LTrack.ActiveAllocCount = LBefore + 1, 'tracked');
  LNew := ReallocMemOf(LPlugin, LPtr, 48, 96);
  Check(LNew <> nil, 'realloc under DEBUG');
  Check(LTrack.ActiveAllocCount = LBefore + 1, 'still one active after realloc');
  FreeMemOf(LPlugin, LNew, 96);
  Check(LTrack.ActiveAllocCount = LBefore, 'free clears tracking');
  RebuildDebug('');
end;

procedure TestTryReallocMemOfNilAllocatorGetMem;
{ S1: TryReallocMemOf must mirror ReallocMemOf — nil allocator + nil ptr
  + size>0 falls back to process GetMem (no extra reject). }
var
  LPtr, LTry: Pointer;
  LOk: Boolean;
begin
  RebuildDebug('');
  LPtr := ReallocMemOf(nil, nil, 0, 64);
  Check(LPtr <> nil, 'ReallocMemOf(nil,nil) → GetMem');
  FreeMem(LPtr, 64);

  LOk := TryReallocMemOf(nil, nil, 0, 64, LTry);
  Check(LOk, 'TryReallocMemOf(nil,nil) success');
  Check(LTry <> nil, 'TryReallocMemOf out ptr');
  FreeMem(LTry, 64);

  LOk := TryReallocMemOf(nil, nil, 0, 0, LTry);
  Check(LOk, 'TryReallocMemOf size=0 → True');
  Check(LTry = nil, 'size=0 → nil ptr');
end;

procedure TestDefaultAllocatorNotHotHeapType;
var
  LHeap: TGrowingAllocator;
  LPtrHeap, LPtrPlug, LCross, LReuse: Pointer;
  LSz: SizeUInt;
begin
  RebuildDebug('');
  LHeap := DefaultHeap;
  Check(LHeap is TGrowingAllocator, 'hot heap concrete type');
  LPtrHeap := LHeap.GetMem(16);
  LPtrPlug := DefaultAllocator.GetMem(16);
  Check(LPtrHeap <> nil, 'heap alloc');
  Check(LPtrPlug <> nil, 'plugin alloc');
  LHeap.FreeMem(LPtrHeap, 16);
  DefaultAllocator.FreeMem(LPtrPlug);

  { S5: same process heap — plugin alloc freeable via DefaultHeap sized free.
    After free, a new same-class alloc must succeed (freelist/span reuse). }
  LCross := DefaultAllocator.GetMem(32);
  Check(LCross <> nil, 'plugin for cross-free');
  Check(TryBlockSize(LCross, LSz), 'cross block visible to DefaultHeap');
  LHeap.FreeMem(LCross, LSz);
  LReuse := LHeap.GetMem(32);
  Check(LReuse <> nil, 'same-heap free enables subsequent GetMem');
  PInteger(LReuse)^ := 7;
  Check(PInteger(LReuse)^ = 7, 'reused block writable');
  LHeap.FreeMem(LReuse, 32);
end;

procedure TestDualTrackSameHeapRoundTrip;
var
  LHeap: TGrowingAllocator;
  LPlugin: IAllocator;
  LPtr: Pointer;
  LSz: SizeUInt;
  LBefore, LAfter: TMemStats;
begin
  { One heap, two surfaces: ownership is interchangeable (S5).
    Call-style still differs: hot prefers FreeMem(ptr,size); plugin is IAllocator. }
  RebuildDebug('');
  LHeap := DefaultHeap;
  LPlugin := DefaultAllocator;
  Check(LHeap <> nil, 'hot');
  Check(LPlugin <> nil, 'plugin');
  Check(LPlugin = GetGrowingIAllocator, 'no DEBUG → bare Growing IAllocator');

  GetMemStats(LBefore);
  { Hot → plugin free }
  LPtr := LHeap.GetMem(64);
  Check(LPtr <> nil, 'hot alloc');
  LPlugin.FreeMem(LPtr);

  { Plugin → hot sized free (recover size-class) }
  LPtr := LPlugin.GetMem(80);
  Check(LPtr <> nil, 'plugin alloc');
  Check(TryBlockSize(LPtr, LSz), 'plugin block on DefaultHeap');
  Check(LSz >= 80, 'size-class');
  FreeMem(LPtr, LSz);

  { Process GetMem → DefaultHeap FreeMem(size) — preferred hot surface }
  LPtr := GetMem(48);
  Check(LPtr <> nil, 'process GetMem');
  FreeMem(LPtr, 48);
  GetMemStats(LAfter);
  Check(LAfter.LiveBytes <= LBefore.LiveBytes + 256,
    'dual-track round-trip balances live_bytes');
end;

procedure TestFormatMemStats;
var
  LPtr: Pointer;
  LLine: string;
  LStats: TMemStats;
begin
  RebuildDebug('');
  LPtr := GetMem(128);
  Check(LPtr <> nil, 'alloc for stats');
  LLine := FormatMemStats;
  Check(Pos('live_bytes=', LLine) > 0, 'live_bytes field');
  Check(Pos('free_slots=', LLine) > 0, 'free_slots field');
  Check(Pos('heap_debug=', LLine) > 0, 'heap_debug field');
  Check(Pos('heap_debug=n', LLine) > 0, 'HEAP_DEBUG off default');
  Check(Pos('heap_safety=n', LLine) > 0, 'heap_safety off default');
  Check(Pos('arena_strict=n', LLine) > 0, 'arena_strict off default');
  Check(Pos('debug=n', LLine) > 0, 'DEBUG wrap off default');
  Check(Pos('debug_process=n', LLine) > 0, 'debug_process default n');
  Check(Pos('debug_coverage_gap=n', LLine) > 0, 'gap default n');
  Check(Pos('debug_active_allocs=', LLine) = 0, 'no plugin counters when DEBUG off');
  GetMemStats(LStats);
  Check(FormatMemStats(LStats) = LLine, 'overload consistent');
  Check(not LStats.HeapSafetyEnabled, 'stats HeapSafetyEnabled false');
  Check(not LStats.ArenaStrictEnabled, 'stats ArenaStrictEnabled false');
  FreeMem(LPtr, 128);
end;

procedure TestFormatMemStatsSafetyAndArenaFlags;
{ R1/R2: FormatMemStats exposes heap_safety and arena_strict when env on. }
var
  LLine: string;
  LStats: TMemStats;
begin
  RebuildDebug('');
  SetHeapSafetyEnv('1');
  SetArenaStrictEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapSafetyEnabled, 'SAFETY on');
  Check(IsMemArenaStrictEnabled, 'ARENA_STRICT on');
  GetMemStats(LStats);
  Check(LStats.HeapSafetyEnabled, 'stats safety');
  Check(LStats.ArenaStrictEnabled, 'stats arena_strict');
  LLine := FormatMemStats(LStats);
  Check(Pos('heap_safety=y', LLine) > 0, 'heap_safety=y');
  Check(Pos('arena_strict=y', LLine) > 0, 'arena_strict=y');
  Check(Pos('heap_debug=y', LLine) > 0, 'SAFETY implies process route flag');
  RebuildDebug('');
end;

procedure TestFormatMemDebugProfile;
{ R4: one-line env profile without retention counters. }
var
  LProf: string;
  LStats: TMemStats;
begin
  RebuildDebug('tracking,stats');
  GetMemStats(LStats);
  LProf := FormatMemDebugProfile(LStats);
  Check(Pos('live_bytes=', LProf) = 0, 'profile has no live_bytes');
  Check(Pos('heap_debug=n', LProf) > 0, 'profile heap_debug');
  Check(Pos('heap_safety=n', LProf) > 0, 'profile heap_safety');
  Check(Pos('arena_strict=n', LProf) > 0, 'profile arena_strict');
  Check(Pos('debug=y', LProf) > 0, 'profile debug');
  Check(Pos('debug_coverage_gap=y', LProf) > 0, 'profile gap');
  Check(Pos('WARN=debug_coverage_gap', LProf) > 0, 'profile WARN on gap');
  Check(FormatMemDebugProfile = LProf, 'profile overload');
  RebuildDebug('');
end;

procedure TestFormatMemStatsPluginTrack;
{ Plugin-only DEBUG: DefaultAllocator traffic appears in FormatMemStats;
  process GetMem stays off the wrap (heap_debug=n, debug_coverage_gap=y). }
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LLine: string;
begin
  RebuildDebug('tracking,stats');
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'plugin');
  Check(not IsMemHeapDebugEnabled, 'HEAP_DEBUG still off');

  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'plugin alloc');
  LLine := FormatMemStats;
  Check(Pos('heap_debug=n', LLine) > 0, 'plugin track: heap_debug=n');
  Check(Pos('debug=y', LLine) > 0, 'plugin track: debug=y');
  Check(Pos('debug_coverage_gap=y', LLine) > 0, 'plugin track: gap=y');
  Check(Pos('WARN=debug_coverage_gap', LLine) > 0, 'plugin track: WARN on gap');
  Check(Pos('debug_process=n', LLine) > 0, 'plugin track: process=n');
  Check(Pos('debug_active_allocs=1', LLine) > 0, 'plugin live allocs');
  Check(Pos('debug_allocs=', LLine) > 0, 'plugin lifetime allocs');
  Check(Pos('debug_frees=', LLine) > 0, 'plugin lifetime frees');
  LAlloc.FreeMem(LPtr);

  LLine := FormatMemStats;
  Check(Pos('debug_active_allocs=0', LLine) > 0, 'plugin free clears active');
  RebuildDebug('');
end;

procedure TestFormatMemStatsHeapDebugProcessTrack;
{ HEAP_DEBUG + tracking: process GetMem joins DefaultAllocator wrap and
  shows in FormatMemStats (doctor mem-process-stats path). }
var
  LPtr: Pointer;
  LLine: string;
begin
  RebuildDebug('tracking,stats');
  SetHeapDebugEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapDebugEnabled, 'HEAP_DEBUG on');

  LPtr := GetMem(96);
  Check(LPtr <> nil, 'process GetMem under HEAP_DEBUG');
  LLine := FormatMemStats;
  Check(Pos('heap_debug=y', LLine) > 0, 'heap_debug=y under HEAP_DEBUG');
  Check(Pos('debug=y', LLine) > 0, 'debug wrap live');
  Check(Pos('debug_process=y', LLine) > 0, 'debug_process=y');
  Check(Pos('debug_coverage_gap=n', LLine) > 0, 'gap=n when process observed');
  Check(Pos('debug_active_allocs=1', LLine) > 0, 'process alloc on plugin track');
  FreeMem(LPtr, 96);

  LLine := FormatMemStats;
  Check(Pos('debug_active_allocs=0', LLine) > 0, 'process free clears active');
  RebuildDebug('');
end;

procedure TestHeapDebugAloneNoPluginCounters;
{ HEAP_DEBUG alone routes process GetMem through bare DefaultAllocator;
  FormatMemStats flips heap_debug=y but does not invent debug_active_* fields. }
var
  LLine: string;
  LPtr: Pointer;
begin
  RebuildDebug('');
  SetHeapDebugEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapDebugEnabled, 'HEAP_DEBUG alone on');
  Check(DefaultAllocator = GetGrowingIAllocator, 'no DEBUG tokens → bare Growing IA');

  LPtr := GetMem(32);
  Check(LPtr <> nil, 'process GetMem');
  LLine := FormatMemStats;
  Check(Pos('heap_debug=y', LLine) > 0, 'heap_debug alone');
  Check(Pos('debug=n', LLine) > 0, 'no DEBUG wrap');
  Check(Pos('debug_coverage_gap=n', LLine) > 0, 'no gap without DEBUG wrap');
  Check(Pos('debug_active_allocs=', LLine) = 0, 'no plugin counters without DEBUG');
  FreeMem(LPtr);
  RebuildDebug('');
end;

procedure TestTryGetMemAndTryFreeMem;
var
  LPtr, LNew: Pointer;
  LArena: IArena;
  LScratch: Pointer;
begin
  RebuildDebug('');
  Check(TryGetMem(96, LPtr), 'TryGetMem');
  Check(LPtr <> nil, 'ptr');
  Check(TryFreeMem(LPtr), 'TryFreeMem recovers size-class');
  Check(not TryFreeMem(nil), 'nil free false');
  Check(not TryFreeMem(Pointer(PtrUInt(1))), 'foreign free false');

  Check(TryAllocMem(64, LPtr), 'TryAllocMem');
  Check(TryReallocMem(LPtr, 64, 128, LNew), 'TryReallocMem sized');
  Check(LNew <> nil, 'realloc ptr');
  FreeMem(LNew, 128);

  LArena := CreateDefaultArena(4096);
  Check(TryArenaAlloc(LArena, 256, LScratch), 'TryArenaAlloc');
  Check(LScratch <> nil, 'arena scratch');
  Check(not TryArenaAlloc(nil, 16, LScratch), 'nil arena false');
end;

procedure TestFormatAllocErrorMsg;
var
  LMsg: string;
begin
  LMsg := FormatAllocErrorMsg('TLocalArenaAllocator', 'FreeMem',
    'arena block; use Reset (ARENA_STRICT)');
  Check(IsWellFormedAllocErrorMsg(LMsg), 'well-formed Type.Method: reason');
  Check(Pos('TLocalArenaAllocator.FreeMem: ', LMsg) = 1, 'stem prefix');
  Check(not IsWellFormedAllocErrorMsg(''), 'empty not well-formed');
  Check(not IsWellFormedAllocErrorMsg('no-colon'), 'missing colon');
  Check(not IsWellFormedAllocErrorMsg('NoDot: reason'), 'missing type.method dot');
end;

procedure TestAllocZeroedAllocArrayNilAllocator;
{ T3: nil IAllocator resolves to process default heap (S5). }
var
  LPtr: Pointer;
  LSz: SizeUInt;
begin
  RebuildDebug('');
  LPtr := AllocZeroed(nil, 32);
  Check(LPtr <> nil, 'AllocZeroed(nil) non-nil');
  Check(PByte(LPtr)^ = 0, 'zeroed first byte');
  Check(TryBlockSize(LPtr, LSz), 'same-heap size-class');
  FreeMem(LPtr, LSz);

  LPtr := AllocArray(nil, 4, 8);
  Check(LPtr <> nil, 'AllocArray(nil) non-nil');
  Check(TryBlockSize(LPtr, LSz), 'array on DefaultHeap');
  FreeMem(LPtr, LSz);
end;

procedure TestAllocArrayOverflowIsInvalidLayout;
{ T2: count*elemSize overflow is programming error, not EOutOfMemory. }
var
  LRaised: Boolean;
  LCode: TAllocError;
  LMsg: string;
  LCount: SizeUInt;
  LElem: SizeUInt;
begin
  LRaised := False;
  LCode := aeNone;
  LMsg := '';
  { Runtime locals: avoid FPC compile-time fold of (High div 2)+1 overflow. }
  LCount := High(SizeUInt);
  LElem := 2;
  try
    AllocArray(DefaultAllocator, LCount, LElem);
    Check(False, 'overflow must raise');
  except
    on E: EAllocError do
    begin
      LRaised := True;
      LCode := E.Error;
      LMsg := E.Message;
    end;
  end;
  Check(LRaised, 'raised EAllocError');
  Check(LCode = aeInvalidLayout, 'aeInvalidLayout not OOM');
  Check(Pos('AllocArray.AllocArray:', LMsg) > 0, 'FormatAllocErrorMsg stem in message');
  Check(Pos('[Invalid layout]', LMsg) > 0, 'BuildAllocMsg code bracket label');
end;

procedure TestTryAllocErrorCode;
{ R-CO-01: extract TAllocError from EAllocError and mem EOutOfMemory. }
var
  LCode: TAllocError;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    raise EAllocError.Create(aeDoubleFree,
      FormatAllocErrorMsg('TestTryAllocErrorCode', 'Raise', 'synthetic double free'));
  except
    on E: Exception do
    begin
      LRaised := True;
      Check(TryAllocErrorCode(E, LCode), 'EAllocError yields code');
      Check(LCode = aeDoubleFree, 'double free code');
    end;
  end;
  Check(LRaised, 'EAllocError raised');

  LRaised := False;
  try
    raise EOutOfMemory.Create(aeOutOfMemory,
      FormatAllocErrorMsg('TestTryAllocErrorCode', 'Raise', 'synthetic OOM'));
  except
    on E: Exception do
    begin
      LRaised := True;
      Check(TryAllocErrorCode(E, LCode), 'EOutOfMemory yields code');
      Check(LCode = aeOutOfMemory, 'OOM code');
    end;
  end;
  Check(LRaised, 'EOutOfMemory raised');
  Check(not TryAllocErrorCode(nil, LCode), 'nil exception false');
end;

procedure TestArenaReallocUsesFormatAllocErrorMsg;
{ T1: Arena ReallocMem raise path uses well-formed stem (via FormatAllocErrorMsg). }
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
  LMsg: string;
begin
  RebuildDebug('');
  LAlloc := CreateArenaAllocator(4096);
  LPtr := LAlloc.GetMem(16);
  Check(LPtr <> nil, 'arena alloc');
  LRaised := False;
  LMsg := '';
  try
    LAlloc.ReallocMem(LPtr, 32);
    Check(False, 'arena realloc must raise');
  except
    on E: EAllocError do
    begin
      LRaised := True;
      LMsg := E.Message;
      Check(E.Error = aeReallocNotSupported, 'aeReallocNotSupported');
    end;
  end;
  Check(LRaised, 'realloc raised');
  Check(Pos('TLocalArenaAllocator.ReallocMem:', LMsg) > 0, 'well-formed ReallocMem stem');
end;

procedure TestArenaStrictFreeMem;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
begin
  { Default: FreeMem(non-nil) is silent no-op. }
  RebuildDebug('');
  LAlloc := CreateArenaAllocator(4096);
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'arena alloc default');
  LAlloc.FreeMem(LPtr);
  LAlloc.FreeMem(nil);
  Check(not IsMemArenaStrictEnabled, 'strict default off');

  { Strict on: FreeMem(non-nil) raises EAllocError. }
  SetArenaStrictEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemArenaStrictEnabled, 'ARENA_STRICT on');
  LAlloc := CreateArenaAllocator(4096);
  LPtr := LAlloc.GetMem(32);
  Check(LPtr <> nil, 'arena alloc strict');
  LRaised := False;
  try
    LAlloc.FreeMem(LPtr);
  except
    on E: EAllocError do
    begin
      LRaised := True;
      Check(E.Error = aeInvalidPointer, 'strict FreeMem → aeInvalidPointer');
      Check(Pos('TLocalArenaAllocator.FreeMem:', E.Message) > 0,
        'strict message uses Type.Method stem');
    end;
  end;
  Check(LRaised, 'strict FreeMem(non-nil) raised');
  LAlloc.FreeMem(nil); { nil remains no-op even under strict }
  RebuildDebug('');
end;

begin
  RebuildDebug('');

  T := TTestSuite.Create('nextpas.core.mem.usability_guardrails');
  T.Test('dual-track identity', @TestDualTrackIdentity);
  T.Test('DEBUG does not track process GetMem', @TestDebugDoesNotTrackProcessGetMem);
  T.Test('HEAP_DEBUG opt-in tracks process GetMem', @TestHeapDebugOptInTracksProcessGetMem);
  T.Test('HEAP_SAFETY opt-in tracks process GetMem', @TestHeapSafetyOptInTracksProcessGetMem);
  T.Test('GetMemStats Debug* is plugin-only', @TestGetMemStatsDebugFieldsOnlyForPlugin);
  T.Test('process sized FreeMem/ReallocMem', @TestProcessSizedFreePreferred);
  T.Test('process TryBlockSize facade', @TestProcessTryBlockSize);
  T.Test('FreeMemOf sized same-heap', @TestFreeMemOfSizedSameHeap);
  T.Test('TryFreeMemOf nil allocator owned', @TestTryFreeMemOfNilAllocatorOwned);
  T.Test('FreeMemOf under plugin DEBUG tracks free', @TestFreeMemOfUnderPluginDebugTracksFree);
  T.Test('ReallocMemOf sized same-heap', @TestReallocMemOfSizedSameHeap);
  T.Test('ReallocMemOf under plugin DEBUG tracks', @TestReallocMemOfUnderPluginDebugTracks);
  T.Test('TryReallocMemOf nil-allocator GetMem', @TestTryReallocMemOfNilAllocatorGetMem);
  T.Test('DefaultAllocator not hot heap type', @TestDefaultAllocatorNotHotHeapType);
  T.Test('dual-track same-heap round-trip', @TestDualTrackSameHeapRoundTrip);
  T.Test('FormatMemStats one-line snapshot', @TestFormatMemStats);
  T.Test('FormatMemStats SAFETY/ARENA flags', @TestFormatMemStatsSafetyAndArenaFlags);
  T.Test('FormatMemDebugProfile flags-only', @TestFormatMemDebugProfile);
  T.Test('FormatMemStats plugin track counters', @TestFormatMemStatsPluginTrack);
  T.Test('FormatMemStats HEAP_DEBUG process track', @TestFormatMemStatsHeapDebugProcessTrack);
  T.Test('HEAP_DEBUG alone no plugin counters', @TestHeapDebugAloneNoPluginCounters);
  T.Test('TryGetMem/TryFreeMem ERROR-POLICY forms', @TestTryGetMemAndTryFreeMem);
  T.Test('FormatAllocErrorMsg helpers', @TestFormatAllocErrorMsg);
  T.Test('AllocZeroed/AllocArray nil allocator', @TestAllocZeroedAllocArrayNilAllocator);
  T.Test('AllocArray overflow InvalidLayout', @TestAllocArrayOverflowIsInvalidLayout);
  T.Test('TryAllocErrorCode EAllocError and OOM', @TestTryAllocErrorCode);
  T.Test('Arena Realloc FormatAllocErrorMsg', @TestArenaReallocUsesFormatAllocErrorMsg);
  T.Test('Arena FreeMem strict dual-mode', @TestArenaStrictFreeMem);

  LRunPassed := T.Run;
  T.Summary;
  RebuildDebug('');
  if not LRunPassed then
    Halt(1);
end.
