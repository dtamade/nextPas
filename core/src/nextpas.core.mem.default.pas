unit nextpas.core.mem.default;
{**
 * Default dual-track (STDLIB-QUALITY-PLAN §4.2 D1 + M2-5 DEBUG wrap)
 *
 *   DefaultHeap      — hot path: TGrowingAllocator singleton (direct calls)
 *   DefaultAllocator — IAllocator plug-in surface (Growing IAllocator root,
 *                      optional NEXTPAS_MEM_DEBUG wraps). Same heap as DefaultHeap.
 *
 * Framework hot paths must use DefaultHeap / process GetMem wrappers, not
 * IAllocator virtual dispatch. IAllocator remains for composers, diagnostics,
 * collections injection, and external backends (GetRtlAllocator still available).
 *
 * NEXTPAS_MEM_DEBUG wraps only DefaultAllocator (see mem.debug_wrap).
 * NEXTPAS_MEM_HEAP_DEBUG / HEAP_SAFETY (opt-in) route process GetMem via
 * DefaultAllocator. FormatMemStats exposes debug_coverage_gap when DEBUG is
 * on but process traffic is not routed (false-negative guard).
 * GetMemStats (M3-2) snapshots DefaultHeap + optional DEBUG wrap counters.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.growing,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.stats,
  nextpas.core.mem.debug_wrap;

type
  {** Process memory snapshot (Go runtime.MemStats-shaped, nextPas dual-track).
   *
   *  Primary numbers come from DefaultHeap (Growing retention / scavenge).
   *  Debug* fields are filled only when NEXTPAS_MEM_DEBUG built a wrap chain;
   *  they never affect DefaultHeap accounting unless HEAP_DEBUG also routes
   *  process GetMem into the wrap chain. }
  TMemStats = record
    { --- DefaultHeap / Growing (always) --- }
    LiveSpans: Int32;
    IdleSpans: Int32;
    DecommittedSpans: Int32;
    FreeSlots: SizeUInt;
    LiveBytes: SizeUInt;
    ReleasedSpans: UInt64;
    ReleasedBytes: UInt64;
    DecommitEvents: UInt64;
    DecommittedBytes: UInt64;
    OpCounter: UInt64;
    { --- Optional DEBUG wrap on DefaultAllocator --- }
    DebugEnabled: Boolean;
    DebugTracking: Boolean;
    DebugStats: Boolean;
    DebugActiveAllocs: SizeInt;
    DebugActiveBytes: SizeUInt;
    DebugAllocCount: UInt64;
    DebugFreeCount: UInt64;
    { --- Process path opt-in --- }
    HeapDebugEnabled: Boolean;
    {** DEBUG wrap sees process GetMem (DebugEnabled and HeapDebugEnabled). }
    DebugObservesProcess: Boolean;
    {** DEBUG on but process GetMem not routed — leak false-negative risk. }
    DebugCoverageGap: Boolean;
    {** NEXTPAS_MEM_HEAP_SAFETY truthy (dev double-free profile). }
    HeapSafetyEnabled: Boolean;
  end;

{** IAllocator plug-in default (Growing IAllocator, or DEBUG wrap chain).
    Same process heap as DefaultHeap; still not the zero-vtable hot path. }
function DefaultAllocator: IAllocator;

{** Process hot-path heap: Growing singleton (concrete type, no interface). }
function DefaultHeap: TGrowingAllocator; inline;

{** Alias of DefaultHeap for discoverability. }
function DefaultGrowingAllocator: TGrowingAllocator; inline;

{** Process-level MemStats: DefaultHeap + optional DEBUG wrap counters. }
procedure GetMemStats(out AStats: TMemStats);
function GetMemStats: TMemStats;

{** One-line human snapshot for logs/tests (not a hot path).
 *  Always: live_bytes/…/heap_debug/debug/debug_process/debug_coverage_gap.
 *  When NEXTPAS_MEM_DEBUG built a wrap: also debug_active_* and debug_allocs/frees. }
function FormatMemStats(const AStats: TMemStats): string;
function FormatMemStats: string;

{** Pure: DebugEnabled and not HeapDebugEnabled (process-heap false-negative). }
function MemDebugCoverageGap(const AStats: TMemStats): Boolean; inline;

{ Re-export DEBUG wrap test/obs APIs from mem.debug_wrap. }
function GetDebugWrapConfig: TMemDebugWrapConfig; inline;
function GetDebugWrapTracking: TTrackingAllocator; inline;
function GetDebugWrapStats: TStatsAllocator; inline;
{** True when HEAP_DEBUG or HEAP_SAFETY routes process GetMem → DefaultAllocator. }
function IsMemHeapDebugEnabled: Boolean; inline;
function IsMemHeapSafetyEnabled: Boolean; inline;
function IsMemArenaStrictEnabled: Boolean; inline;
procedure ResetDebugWrapForTests; inline;

implementation

uses
  nextpas.core.base;

function DefaultAllocator: IAllocator;
begin
  Result := ResolveDefaultAllocator;
end;

function DefaultHeap: TGrowingAllocator;
begin
  Result := nextpas.core.mem.allocator.growing.DefaultGrowingAllocator;
end;

function DefaultGrowingAllocator: TGrowingAllocator;
begin
  Result := DefaultHeap;
end;

procedure GetMemStats(out AStats: TMemStats);
var
  LHeap: TGrowingAllocator;
  LHeapStats: TGrowingHeapStats;
  LCfg: TMemDebugWrapConfig;
  LTrack: TTrackingAllocator;
  LStats: TStatsAllocator;
  LAllocStats: TAllocatorStats;
begin
  FillChar(AStats, SizeOf(AStats), 0);

  LHeap := DefaultHeap;
  if LHeap <> nil then
  begin
    LHeap.GetHeapStats(LHeapStats);
    AStats.LiveSpans := LHeapStats.LiveSpans;
    AStats.IdleSpans := LHeapStats.IdleSpans;
    AStats.DecommittedSpans := LHeapStats.DecommittedSpans;
    AStats.FreeSlots := LHeapStats.FreeSlots;
    AStats.LiveBytes := LHeapStats.LiveBytes;
    AStats.ReleasedSpans := LHeapStats.ReleasedSpans;
    AStats.ReleasedBytes := LHeapStats.ReleasedBytes;
    AStats.DecommitEvents := LHeapStats.DecommitEvents;
    AStats.DecommittedBytes := LHeapStats.DecommittedBytes;
    AStats.OpCounter := LHeapStats.OpCounter;
  end;

  { GetDebugWrapConfig EnsureBuilt: first GetMemStats may parse env and
    materialize the DEBUG singleton (cold). Hot path never calls GetMemStats. }
  LCfg := GetDebugWrapConfig;
  AStats.DebugEnabled := LCfg.Enabled and LCfg.Built;
  AStats.DebugTracking := LCfg.WantTracking;
  AStats.DebugStats := LCfg.WantStats;
  AStats.HeapDebugEnabled := IsMemHeapDebugEnabled;
  AStats.HeapSafetyEnabled := IsMemHeapSafetyEnabled;
  AStats.DebugObservesProcess := AStats.DebugEnabled and AStats.HeapDebugEnabled;
  AStats.DebugCoverageGap := AStats.DebugEnabled and (not AStats.HeapDebugEnabled);

  if AStats.DebugEnabled then
  begin
    LTrack := GetDebugWrapTracking;
    if LTrack <> nil then
    begin
      AStats.DebugActiveAllocs := LTrack.ActiveAllocCount;
      AStats.DebugActiveBytes := LTrack.ActiveAllocBytes;
    end;
    LStats := GetDebugWrapStats;
    if LStats <> nil then
    begin
      LAllocStats := LStats.GetStats;
      AStats.DebugAllocCount := LAllocStats.AllocCount;
      AStats.DebugFreeCount := LAllocStats.FreeCount;
    end;
  end;
end;

function GetMemStats: TMemStats;
begin
  GetMemStats(Result);
end;

function FormatMemStatsYN(const AValue: Boolean): string; inline;
begin
  if AValue then
    Result := 'y'
  else
    Result := 'n';
end;

function MemDebugCoverageGap(const AStats: TMemStats): Boolean;
begin
  Result := AStats.DebugEnabled and (not AStats.HeapDebugEnabled);
end;

function FormatMemStats(const AStats: TMemStats): string;
begin
  { Compact single-line snapshot (L0: base IntToStr only).
    debug_process / debug_coverage_gap make DEBUG-only false-negatives visible.
    Plugin counters appear only when DEBUG wrap is built. }
  Result :=
    'live_bytes=' + IntToStr(Int64(AStats.LiveBytes)) +
    ' free_slots=' + IntToStr(Int64(AStats.FreeSlots)) +
    ' live_spans=' + IntToStr(Int64(AStats.LiveSpans)) +
    ' idle_spans=' + IntToStr(Int64(AStats.IdleSpans)) +
    ' released_bytes=' + IntToStr(Int64(AStats.ReleasedBytes)) +
    ' heap_debug=' + FormatMemStatsYN(AStats.HeapDebugEnabled) +
    ' debug=' + FormatMemStatsYN(AStats.DebugEnabled) +
    ' debug_process=' + FormatMemStatsYN(AStats.DebugObservesProcess) +
    ' debug_coverage_gap=' + FormatMemStatsYN(AStats.DebugCoverageGap);
  if AStats.DebugEnabled then
    Result := Result +
      ' debug_active_allocs=' + IntToStr(Int64(AStats.DebugActiveAllocs)) +
      ' debug_active_bytes=' + IntToStr(Int64(AStats.DebugActiveBytes)) +
      ' debug_allocs=' + IntToStr(Int64(AStats.DebugAllocCount)) +
      ' debug_frees=' + IntToStr(Int64(AStats.DebugFreeCount));
end;

function FormatMemStats: string;
var
  LStats: TMemStats;
begin
  GetMemStats(LStats);
  Result := FormatMemStats(LStats);
end;

function GetDebugWrapConfig: TMemDebugWrapConfig;
begin
  Result := nextpas.core.mem.debug_wrap.GetDebugWrapConfig;
end;

function GetDebugWrapTracking: TTrackingAllocator;
begin
  Result := nextpas.core.mem.debug_wrap.GetDebugWrapTracking;
end;

function GetDebugWrapStats: TStatsAllocator;
begin
  Result := nextpas.core.mem.debug_wrap.GetDebugWrapStats;
end;

function IsMemHeapDebugEnabled: Boolean;
begin
  Result := nextpas.core.mem.debug_wrap.IsMemHeapDebugEnabled;
end;

function IsMemHeapSafetyEnabled: Boolean;
begin
  Result := nextpas.core.mem.debug_wrap.IsMemHeapSafetyEnabled;
end;

function IsMemArenaStrictEnabled: Boolean;
begin
  Result := nextpas.core.mem.debug_wrap.IsMemArenaStrictEnabled;
end;

procedure ResetDebugWrapForTests;
begin
  nextpas.core.mem.debug_wrap.ResetDebugWrapForTests;
end;

end.
