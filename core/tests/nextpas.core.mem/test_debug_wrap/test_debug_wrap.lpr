program test_debug_wrap;
{**
 * M2-5: NEXTPAS_MEM_DEBUG wrap chain for DefaultAllocator.
 * DefaultHeap must stay bare Growing regardless of env.
 * NEXTPAS_MEM_HEAP_DEBUG opt-in routes process GetMem through DefaultAllocator.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.test,
  nextpas.core.platform.env,
  nextpas.core.mem,
  nextpas.core.mem.intf,
  nextpas.core.mem.error,
  nextpas.core.mem.default,
  nextpas.core.mem.debug_wrap,
  nextpas.core.mem.allocator.foundation,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.stats,
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

procedure SetHeapDebugEnv(const AValue: AnsiString);
begin
  if AValue = '' then
    platform_env_unset(PAnsiChar(MEM_HEAP_DEBUG_ENV))
  else
    platform_env_set(PAnsiChar(MEM_HEAP_DEBUG_ENV), PAnsiChar(AValue));
end;

procedure RebuildWithEnv(const AValue: AnsiString);
begin
  ResetDebugWrapForTests;
  SetMemDebugEnv(AValue);
  SetHeapDebugEnv('');
end;

{ --- pure parse --- }

procedure TestParseEmpty;
var
  LCfg: TMemDebugWrapConfig;
begin
  ParseMemDebugEnv('', LCfg);
  Check(not LCfg.Enabled, 'empty env → disabled');
  Check(not LCfg.WantFail, 'no fail');
  Check(not LCfg.WantStats, 'no stats');
  Check(not LCfg.WantTracking, 'no tracking');
  Check(not LCfg.WantSentinel, 'no sentinel');
  Check(LCfg.IgnoredTokens = 0, 'no ignored');
end;

procedure TestParseAliasesAndOrderIgnored;
var
  LCfg: TMemDebugWrapConfig;
begin
  ParseMemDebugEnv('LEAK,stats;sentinel oom', LCfg);
  Check(LCfg.Enabled, 'enabled');
  Check(LCfg.WantTracking, 'leak ≡ tracking');
  Check(LCfg.WantStats, 'stats');
  Check(LCfg.WantSentinel, 'sentinel');
  Check(LCfg.WantFail, 'oom ≡ fail');
  Check(LCfg.IgnoredTokens = 0, 'all known');
end;

procedure TestParseUnknownOnly;
var
  LCfg: TMemDebugWrapConfig;
begin
  ParseMemDebugEnv('bogus,notatoken', LCfg);
  Check(not LCfg.Enabled, 'unknown-only → disabled wrap');
  Check(LCfg.IgnoredTokens = 2, 'two ignored');
end;

procedure TestParseWhitespaceOnly;
var
  LCfg: TMemDebugWrapConfig;
begin
  ParseMemDebugEnv('   '#9'  ', LCfg);
  Check(not LCfg.Enabled, 'whitespace-only → disabled wrap');
  Check(not LCfg.WantFail, 'no fail');
  Check(not LCfg.WantStats, 'no stats');
  Check(not LCfg.WantTracking, 'no tracking');
  Check(not LCfg.WantSentinel, 'no sentinel');
  Check(LCfg.IgnoredTokens = 0, 'no tokens parsed');
end;

procedure TestParseSeparatorsOnly;
var
  LCfg: TMemDebugWrapConfig;
begin
  ParseMemDebugEnv(',,; ;,', LCfg);
  Check(not LCfg.Enabled, 'separators-only → disabled wrap');
  Check(LCfg.IgnoredTokens = 0, 'no tokens');
end;

procedure TestParseMixedUnknown;
var
  LCfg: TMemDebugWrapConfig;
begin
  ParseMemDebugEnv('tracking,xyz,stats', LCfg);
  Check(LCfg.Enabled, 'known tokens still enable');
  Check(LCfg.WantTracking, 'tracking kept');
  Check(LCfg.WantStats, 'stats kept');
  Check(LCfg.IgnoredTokens = 1, 'xyz ignored');
end;

{ --- resolve / identity --- }

procedure TestNoEnvIsGrowingRoot;
var
  LAlloc: IAllocator;
  LCfg: TMemDebugWrapConfig;
begin
  RebuildWithEnv('');
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'DefaultAllocator non-nil');
  Check(LAlloc = GetGrowingIAllocator, 'no env → Growing IAllocator identity');
  Check(LAlloc <> GetRtlAllocator, 'not bare RTL (S5)');
  LCfg := GetDebugWrapConfig;
  Check(LCfg.Built, 'config built');
  Check(not LCfg.Enabled, 'not enabled');
  Check(GetDebugWrapTracking = nil, 'no tracking layer');
  Check(GetDebugWrapStats = nil, 'no stats layer');
  Check(DefaultAllocator = LAlloc, 'singleton stable');
end;

procedure TestTrackingWrapDetectsLeak;
var
  LAlloc: IAllocator;
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
  LCfg: TMemDebugWrapConfig;
begin
  RebuildWithEnv('tracking');
  LAlloc := DefaultAllocator;
  Check(LAlloc <> nil, 'wrapped non-nil');
  Check(LAlloc <> GetGrowingIAllocator, 'not bare Growing root when wrapped');
  LCfg := GetDebugWrapConfig;
  Check(LCfg.Enabled and LCfg.WantTracking, 'tracking config');
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking layer present');

  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'GetMem');
  Check(LTrack.ActiveAllocCount = 1, 'live after alloc');
  Check(LTrack.HasLeaks, 'unfreed is leak');
  LAlloc.FreeMem(LPtr);
  Check(LTrack.ActiveAllocCount = 0, 'cleared after free');
  Check(not LTrack.HasLeaks, 'no leak after free');
end;

procedure TestLeakAlias;
var
  LCfg: TMemDebugWrapConfig;
begin
  RebuildWithEnv('leak');
  Check(DefaultAllocator <> nil, 'alloc');
  LCfg := GetDebugWrapConfig;
  Check(LCfg.WantTracking, 'leak → tracking');
  Check(GetDebugWrapTracking <> nil, 'tracking object');
end;

procedure TestStatsWrapCounts;
var
  LAlloc: IAllocator;
  LStats: TStatsAllocator;
  S: TAllocatorStats;
  LPtr: Pointer;
begin
  RebuildWithEnv('stats');
  LAlloc := DefaultAllocator;
  LStats := GetDebugWrapStats;
  Check(LStats <> nil, 'stats layer');
  LPtr := LAlloc.GetMem(32);
  Check(LPtr <> nil, 'GetMem');
  LAlloc.FreeMem(LPtr);
  S := LStats.GetStats;
  Check(S.AllocCount >= 1, 'alloc counted');
  Check(S.FreeCount >= 1, 'free counted');
end;

procedure TestSentinelViaDefault;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
  LRaised: Boolean;
  LCfg: TMemDebugWrapConfig;
begin
  RebuildWithEnv('sentinel');
  LAlloc := DefaultAllocator;
  LCfg := GetDebugWrapConfig;
  Check(LCfg.WantSentinel, 'sentinel on');
  Check(LAlloc <> GetGrowingIAllocator, 'wrapped');

  { Clean path through wrap (overflow/double-free details: test_sentinel). }
  LPtr := LAlloc.GetMem(64);
  Check(LPtr <> nil, 'GetMem');
  FillChar(LPtr^, 64, $AB);
  LAlloc.FreeMem(LPtr);

  LPtr := LAlloc.GetMem(32);
  Check(LPtr <> nil, 'second GetMem');
  LAlloc.FreeMem(LPtr);
  LRaised := False;
  try
    LAlloc.FreeMem(LPtr);
  except
    on E: EAllocError do
      LRaised := True;
  end;
  Check(LRaised, 'double-free detected through DefaultAllocator sentinel wrap');
end;

procedure TestCombinedChainOrder;
var
  LAlloc: IAllocator;
  LCfg: TMemDebugWrapConfig;
  LPtr: Pointer;
  LTrack: TTrackingAllocator;
  LStats: TStatsAllocator;
begin
  { User order reversed; build must still be stats → tracking → sentinel → Growing. }
  RebuildWithEnv('stats,tracking,sentinel');
  LAlloc := DefaultAllocator;
  LCfg := GetDebugWrapConfig;
  Check(LCfg.WantStats and LCfg.WantTracking and LCfg.WantSentinel, 'all flags');
  LTrack := GetDebugWrapTracking;
  LStats := GetDebugWrapStats;
  Check(LTrack <> nil, 'tracking present');
  Check(LStats <> nil, 'stats present');

  LPtr := LAlloc.GetMem(48);
  Check(LPtr <> nil, 'GetMem through chain');
  Check(LTrack.ActiveAllocCount = 1, 'tracking sees live');
  Check(LStats.GetStats.AllocCount >= 1, 'stats sees alloc');
  LAlloc.FreeMem(LPtr);
  Check(LTrack.ActiveAllocCount = 0, 'tracking free');
end;

procedure TestUnknownTokenNoCrash;
var
  LAlloc: IAllocator;
  LPtr: Pointer;
begin
  RebuildWithEnv('not_a_real_token');
  LAlloc := DefaultAllocator;
  Check(LAlloc = GetGrowingIAllocator, 'unknown-only falls back to Growing root');
  LPtr := LAlloc.GetMem(16);
  Check(LPtr <> nil, 'still allocates');
  LAlloc.FreeMem(LPtr);
end;

procedure TestDefaultHeapUnwrappedUnderDebugEnv;
var
  LHeap: TGrowingAllocator;
  LPtr: Pointer;
  LAlloc: IAllocator;
begin
  RebuildWithEnv('tracking,sentinel,stats');
  LAlloc := DefaultAllocator;
  Check(LAlloc <> GetGrowingIAllocator, 'plugin path wrapped');

  LHeap := DefaultHeap;
  Check(LHeap <> nil, 'DefaultHeap present');
  Check(LHeap = DefaultGrowingAllocator, 'alias');
  { Hot path must allocate without going through wrap layers. }
  LPtr := LHeap.GetMem(128);
  Check(LPtr <> nil, 'DefaultHeap.GetMem');
  LHeap.FreeMem(LPtr, 128);

  LPtr := GetMem(64);
  Check(LPtr <> nil, 'process GetMem');
  FreeMem(LPtr, 64);

  { Tracking layer must not see DefaultHeap traffic. }
  if GetDebugWrapTracking <> nil then
    Check(GetDebugWrapTracking.ActiveAllocCount = 0,
      'DefaultHeap traffic not tracked on DEBUG wrap');
end;

procedure TestSingletonAfterRebuild;
var
  A, B: IAllocator;
begin
  RebuildWithEnv('stats');
  A := DefaultAllocator;
  B := DefaultAllocator;
  Check(A = B, 'same root after build');
  Check(GetDebugWrapStats <> nil, 'stats held');
end;

procedure TestParseHeapDebugEnv;
begin
  Check(not ParseMemHeapDebugEnv(''), 'empty off');
  Check(not ParseMemHeapDebugEnv('0'), '0 off');
  Check(not ParseMemHeapDebugEnv('false'), 'false off');
  Check(not ParseMemHeapDebugEnv('no'), 'no off');
  Check(not ParseMemHeapDebugEnv('off'), 'off off');
  Check(ParseMemHeapDebugEnv('1'), '1 on');
  Check(ParseMemHeapDebugEnv('true'), 'true on');
  Check(ParseMemHeapDebugEnv('YES'), 'YES on');
  Check(ParseMemHeapDebugEnv(' On '), 'On trimmed on');
end;

procedure TestHeapDebugOffProcessGetMemNotTracked;
var
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
  LBefore: SizeInt;
begin
  RebuildWithEnv('tracking,stats');
  SetHeapDebugEnv('');
  ResetDebugWrapForTests;
  Check(not IsMemHeapDebugEnabled, 'HEAP_DEBUG default off');
  Check(DefaultAllocator <> nil, 'build wrap');
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking');
  LBefore := LTrack.ActiveAllocCount;
  LPtr := GetMem(64);
  Check(LPtr <> nil, 'process GetMem');
  Check(LTrack.ActiveAllocCount = LBefore, 'process path not tracked when HEAP_DEBUG off');
  FreeMem(LPtr, 64);
end;

procedure TestHeapDebugOnProcessGetMemTracked;
var
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
  LMem: TMemStats;
begin
  RebuildWithEnv('tracking,stats');
  SetHeapDebugEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapDebugEnabled, 'HEAP_DEBUG on');
  Check(DefaultAllocator <> nil, 'wrap built');
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking layer');

  LPtr := GetMem(96);
  Check(LPtr <> nil, 'process GetMem under HEAP_DEBUG');
  Check(LTrack.ActiveAllocCount = 1, 'process GetMem tracked');
  GetMemStats(LMem);
  Check(LMem.HeapDebugEnabled, 'MemStats.HeapDebugEnabled');
  Check(LMem.DebugActiveAllocs = 1, 'MemStats sees process alloc');
  FreeMem(LPtr, 96);
  Check(LTrack.ActiveAllocCount = 0, 'process FreeMem untracks');

  LPtr := AllocMem(32);
  Check(LPtr <> nil, 'AllocMem tracked path');
  Check(LTrack.ActiveAllocCount = 1, 'AllocMem tracked');
  FreeMem(LPtr);
  Check(LTrack.ActiveAllocCount = 0, 'FreeMem(ptr) untracks');
end;

procedure TestHeapDebugDoesNotWrapDefaultHeap;
var
  LHeap: TGrowingAllocator;
  LTrack: TTrackingAllocator;
  LPtr: Pointer;
begin
  RebuildWithEnv('tracking');
  SetHeapDebugEnv('1');
  ResetDebugWrapForTests;
  Check(IsMemHeapDebugEnabled, 'HEAP_DEBUG on');
  Check(DefaultAllocator <> nil, 'wrap');
  LTrack := GetDebugWrapTracking;
  Check(LTrack <> nil, 'tracking');
  LHeap := DefaultHeap;
  LPtr := LHeap.GetMem(64);
  Check(LPtr <> nil, 'DefaultHeap.GetMem');
  Check(LTrack.ActiveAllocCount = 0, 'DefaultHeap still not tracked');
  LHeap.FreeMem(LPtr, 64);
end;

begin
  { Isolate suite from ambient NEXTPAS_MEM_DEBUG / HEAP_DEBUG. }
  RebuildWithEnv('');

  T := TTestSuite.Create('nextpas.core.mem.debug_wrap');
  T.Test('parse empty', @TestParseEmpty);
  T.Test('parse aliases', @TestParseAliasesAndOrderIgnored);
  T.Test('parse unknown only', @TestParseUnknownOnly);
  T.Test('parse whitespace only', @TestParseWhitespaceOnly);
  T.Test('parse separators only', @TestParseSeparatorsOnly);
  T.Test('parse mixed unknown', @TestParseMixedUnknown);
  T.Test('no env is Growing root', @TestNoEnvIsGrowingRoot);
  T.Test('tracking detects leak', @TestTrackingWrapDetectsLeak);
  T.Test('leak alias', @TestLeakAlias);
  T.Test('stats counts', @TestStatsWrapCounts);
  T.Test('sentinel via DefaultAllocator', @TestSentinelViaDefault);
  T.Test('combined chain', @TestCombinedChainOrder);
  T.Test('unknown token no crash', @TestUnknownTokenNoCrash);
  T.Test('DefaultHeap unwrapped under DEBUG env', @TestDefaultHeapUnwrappedUnderDebugEnv);
  T.Test('singleton after rebuild', @TestSingletonAfterRebuild);
  T.Test('parse HEAP_DEBUG env', @TestParseHeapDebugEnv);
  T.Test('HEAP_DEBUG off process not tracked', @TestHeapDebugOffProcessGetMemNotTracked);
  T.Test('HEAP_DEBUG on process tracked', @TestHeapDebugOnProcessGetMemTracked);
  T.Test('HEAP_DEBUG leaves DefaultHeap bare', @TestHeapDebugDoesNotWrapDefaultHeap);

  LRunPassed := T.Run;
  T.Summary;
  RebuildWithEnv('');
  if not LRunPassed then
    Halt(1);
end.
