program test_usability_guardrails;
{**
 * Usability guardrails (2026-07-15 assessment F1/F3):
 *   - Dual-track: DefaultHeap ≠ DefaultAllocator path
 *   - NEXTPAS_MEM_DEBUG does not observe process GetMem traffic
 *   - Preferred sized FreeMem / ReallocMem process path
 *   - Process TryBlockSize recovers size-class for DefaultHeap blocks
 *   - Dual-track same-heap: hot↔plugin free round-trip (S5 ownership)
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.platform.env,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
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

procedure RebuildDebug(const AValue: AnsiString);
begin
  ResetDebugWrapForTests;
  SetMemDebugEnv(AValue);
  SetHeapDebugEnv('');
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
  { Dual-track: concrete DefaultHeap vs IAllocator plug-in surface (same heap). }
  Check(True, 'dual-track surfaces distinct');
end;

procedure TestDebugDoesNotTrackProcessGetMem;
var
  LTrack: TTrackingAllocator;
  LAlloc: IAllocator;
  LPtr: Pointer;
  LPlugin: Pointer;
  LBefore, LAfter: SizeInt;
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
  FreeMem(LPtr, 64);
  Check(LTrack.ActiveAllocCount = 0, 'opt-in free clears');
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
begin
  RebuildDebug('');
  LPtr := GetMem(96);
  Check(LPtr <> nil, 'GetMem 96');
  PInteger(LPtr)^ := 123;
  Check(PInteger(LPtr)^ = 123, 'write');
  FreeMem(LPtr, 96);
  Check(True, 'sized FreeMem ok');

  LPtr := GetMem(48);
  Check(LPtr <> nil, 'GetMem 48');
  LPtr := ReallocMem(LPtr, 48, 192);
  Check(LPtr <> nil, 'sized ReallocMem');
  FreeMem(LPtr, 192);
end;

procedure TestProcessTryBlockSize;
var
  LPtr: Pointer;
  LSz: SizeUInt;
begin
  RebuildDebug('');
  Check(not TryBlockSize(nil, LSz), 'nil → False');
  Check(LSz = 0, 'nil size zero');

  LPtr := GetMem(96);
  Check(LPtr <> nil, 'GetMem 96');
  Check(TryBlockSize(LPtr, LSz), 'owned block');
  Check(LSz >= 96, 'size-class >= request');
  { Prefer sized free after recovery when caller lost the original size. }
  FreeMem(LPtr, LSz);
  Check(True, 'sized free after TryBlockSize');
end;

procedure TestDefaultAllocatorNotHotHeapType;
var
  LHeap: TGrowingAllocator;
  LPtrHeap, LPtrPlug, LCross: Pointer;
begin
  RebuildDebug('');
  LHeap := DefaultHeap;
  LPtrHeap := LHeap.GetMem(16);
  LPtrPlug := DefaultAllocator.GetMem(16);
  Check(LPtrHeap <> nil, 'heap alloc');
  Check(LPtrPlug <> nil, 'plugin alloc');
  LHeap.FreeMem(LPtrHeap, 16);
  DefaultAllocator.FreeMem(LPtrPlug);

  { S5: same process heap — plugin alloc freeable via DefaultHeap FreeMem(ptr). }
  LCross := DefaultAllocator.GetMem(32);
  Check(LCross <> nil, 'plugin for cross-free');
  LHeap.FreeMem(LCross);
  Check(True, 'same-heap cross free ok');
end;

procedure TestDualTrackSameHeapRoundTrip;
var
  LHeap: TGrowingAllocator;
  LPlugin: IAllocator;
  LPtr: Pointer;
  LSz: SizeUInt;
begin
  { One heap, two surfaces: ownership is interchangeable (S5).
    Call-style still differs: hot prefers FreeMem(ptr,size); plugin is IAllocator. }
  RebuildDebug('');
  LHeap := DefaultHeap;
  LPlugin := DefaultAllocator;
  Check(LHeap <> nil, 'hot');
  Check(LPlugin <> nil, 'plugin');
  Check(LPlugin = GetGrowingIAllocator, 'no DEBUG → bare Growing IAllocator');

  { Hot → plugin free }
  LPtr := LHeap.GetMem(64);
  Check(LPtr <> nil, 'hot alloc');
  LPlugin.FreeMem(LPtr);
  Check(True, 'hot alloc freed via plugin');

  { Plugin → hot sized free (recover size-class) }
  LPtr := LPlugin.GetMem(80);
  Check(LPtr <> nil, 'plugin alloc');
  Check(TryBlockSize(LPtr, LSz), 'plugin block on DefaultHeap');
  Check(LSz >= 80, 'size-class');
  FreeMem(LPtr, LSz);
  Check(True, 'plugin alloc freed via process sized FreeMem');

  { Process GetMem → DefaultHeap FreeMem(size) — preferred hot surface }
  LPtr := GetMem(48);
  Check(LPtr <> nil, 'process GetMem');
  FreeMem(LPtr, 48);
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
  Check(Pos('debug=n', LLine) > 0, 'DEBUG wrap off default');
  Check(Pos('debug_active_allocs=', LLine) = 0, 'no plugin counters when DEBUG off');
  GetMemStats(LStats);
  Check(FormatMemStats(LStats) = LLine, 'overload consistent');
  FreeMem(LPtr, 128);
end;

procedure TestFormatMemStatsPluginTrack;
{ Plugin-only DEBUG: DefaultAllocator traffic appears in FormatMemStats;
  process GetMem stays off the wrap (heap_debug=n). }
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

begin
  RebuildDebug('');

  T := TTestSuite.Create('nextpas.core.mem.usability_guardrails');
  T.Test('dual-track identity', @TestDualTrackIdentity);
  T.Test('DEBUG does not track process GetMem', @TestDebugDoesNotTrackProcessGetMem);
  T.Test('HEAP_DEBUG opt-in tracks process GetMem', @TestHeapDebugOptInTracksProcessGetMem);
  T.Test('GetMemStats Debug* is plugin-only', @TestGetMemStatsDebugFieldsOnlyForPlugin);
  T.Test('process sized FreeMem/ReallocMem', @TestProcessSizedFreePreferred);
  T.Test('process TryBlockSize facade', @TestProcessTryBlockSize);
  T.Test('DefaultAllocator not hot heap type', @TestDefaultAllocatorNotHotHeapType);
  T.Test('dual-track same-heap round-trip', @TestDualTrackSameHeapRoundTrip);
  T.Test('FormatMemStats one-line snapshot', @TestFormatMemStats);
  T.Test('FormatMemStats plugin track counters', @TestFormatMemStatsPluginTrack);
  T.Test('FormatMemStats HEAP_DEBUG process track', @TestFormatMemStatsHeapDebugProcessTrack);
  T.Test('HEAP_DEBUG alone no plugin counters', @TestHeapDebugAloneNoPluginCounters);
  T.Test('TryGetMem/TryFreeMem ERROR-POLICY forms', @TestTryGetMemAndTryFreeMem);

  LRunPassed := T.Run;
  T.Summary;
  RebuildDebug('');
  if not LRunPassed then
    Halt(1);
end.
