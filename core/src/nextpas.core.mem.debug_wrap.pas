unit nextpas.core.mem.debug_wrap;
{**
 * DEBUG wrap chain for DefaultAllocator (IAllocator plug-in surface).
 *
 * Env: NEXTPAS_MEM_DEBUG=<token>[,token...]
 * Tokens (fixed outer→inner build order; user order ignored):
 *   fail/oom, stats, tracking/leak, sentinel
 * Unknown tokens are ignored (counted in config).
 * Enabled only when ≥1 known token is present (whitespace/unknown-only = off).
 *
 * Default: does NOT wrap DefaultHeap. Process GetMem stays bare Growing unless
 * NEXTPAS_MEM_HEAP_DEBUG or NEXTPAS_MEM_HEAP_SAFETY is truthy (slow opt-in;
 * routes process GetMem/FreeMem/… through DefaultAllocator so wraps can observe).
 * HEAP_SAFETY also injects tracking+sentinel when DEBUG tokens are absent.
 * NEXTPAS_MEM_ARENA_STRICT: Arena IAllocator FreeMem(non-nil) raises.
 * DefaultAllocator root (no DEBUG) is Growing IAllocator (S5), not RTL.
 * See core/docs/mem/DEBUG-WRAP-DESIGN.md.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.tracking,
  nextpas.core.mem.allocator.stats;

const
  MEM_DEBUG_ENV = 'NEXTPAS_MEM_DEBUG';
  {** Explicit opt-in: process GetMem/FreeMem route via DefaultAllocator (slow). }
  MEM_HEAP_DEBUG_ENV = 'NEXTPAS_MEM_HEAP_DEBUG';
  {** Dev safety profile: process route + default tracking/sentinel if DEBUG empty. }
  MEM_HEAP_SAFETY_ENV = 'NEXTPAS_MEM_HEAP_SAFETY';
  {** Arena IAllocator FreeMem(non-nil) raises instead of silent no-op. }
  MEM_ARENA_STRICT_ENV = 'NEXTPAS_MEM_ARENA_STRICT';

type
  {** Snapshot of parsed DEBUG wrap intent and build state. }
  TMemDebugWrapConfig = record
    EnvRaw: AnsiString;
    Enabled: Boolean;
    WantFail: Boolean;
    WantStats: Boolean;
    WantTracking: Boolean;
    WantSentinel: Boolean;
    {** True when HEAP_SAFETY injected default tracking/sentinel. }
    SafetyProfile: Boolean;
    IgnoredTokens: Integer;
    Built: Boolean;
  end;

{** Resolve DefaultAllocator root: Growing IAllocator, or that under fixed DEBUG wraps. }
function ResolveDefaultAllocator: IAllocator;

{** Last parsed / built config (empty until first Resolve or after Reset). }
function GetDebugWrapConfig: TMemDebugWrapConfig;

{** Tracking layer if active (nil if not requested / not built). }
function GetDebugWrapTracking: TTrackingAllocator;

{** Stats layer if active (nil if not requested / not built). }
function GetDebugWrapStats: TStatsAllocator;

{** True when HEAP_DEBUG or HEAP_SAFETY is truthy (lazy parse + cache).
    Process GetMem/FreeMem must check this; DefaultHeap never does. }
function IsMemHeapDebugEnabled: Boolean;

{** True when NEXTPAS_MEM_HEAP_SAFETY is truthy (dev double-free profile). }
function IsMemHeapSafetyEnabled: Boolean;

{** True when NEXTPAS_MEM_ARENA_STRICT is truthy. }
function IsMemArenaStrictEnabled: Boolean;

{** Pure parse for HEAP_DEBUG / SAFETY / ARENA_STRICT truthy env values. }
function ParseMemHeapDebugEnv(const AEnv: AnsiString): Boolean;

{** Drop singleton so next ResolveDefaultAllocator rebuilds from current env.
    Also clears HEAP_DEBUG / SAFETY / ARENA_STRICT caches. Test-only. }
procedure ResetDebugWrapForTests;

{** Parse env string into flags (pure; no side effects). }
procedure ParseMemDebugEnv(const AEnv: AnsiString; out AConfig: TMemDebugWrapConfig);

implementation

uses
  nextpas.core.atomic,
  nextpas.core.platform.env,
  nextpas.core.mem.allocator.growing_ia,
  nextpas.core.mem.allocator.fail,
  nextpas.core.mem.allocator.sentinel;

const
  { Build state for one-shot init: 0 idle, 1 building, 2 ready. }
  STATE_IDLE = 0;
  STATE_BUILDING = 1;
  STATE_READY = 2;

const
  { Truthy-env cache: 0 unread, 1 off, 2 on }
  ENV_UNREAD = 0;
  ENV_OFF = 1;
  ENV_ON = 2;

var
  GState: SizeUInt;
  GRoot: IAllocator;
  GConfig: TMemDebugWrapConfig;
  GTracking: TTrackingAllocator;
  GStats: TStatsAllocator;
  GHeapDebugState: SizeUInt;
  { Combined HEAP_DEBUG|HEAP_SAFETY for process GetMem hot path (one load). }
  GProcessRouteState: SizeUInt;
  GHeapSafetyState: SizeUInt;
  GArenaStrictState: SizeUInt;

function AsciiTokenEq(const ATok, AExpected: AnsiString): Boolean;
var
  I, L: Integer;
  C1, C2: AnsiChar;
begin
  L := Length(ATok);
  if L <> Length(AExpected) then
    Exit(False);
  for I := 1 to L do
  begin
    C1 := ATok[I];
    C2 := AExpected[I];
    if (C1 >= 'A') and (C1 <= 'Z') then
      C1 := AnsiChar(Ord(C1) + 32);
    if (C2 >= 'A') and (C2 <= 'Z') then
      C2 := AnsiChar(Ord(C2) + 32);
    if C1 <> C2 then
      Exit(False);
  end;
  Result := True;
end;

procedure ApplyToken(const ATok: AnsiString; var AConfig: TMemDebugWrapConfig);
begin
  if ATok = '' then
    Exit;
  if AsciiTokenEq(ATok, 'fail') or AsciiTokenEq(ATok, 'oom') then
    AConfig.WantFail := True
  else if AsciiTokenEq(ATok, 'stats') then
    AConfig.WantStats := True
  else if AsciiTokenEq(ATok, 'tracking') or AsciiTokenEq(ATok, 'leak') then
    AConfig.WantTracking := True
  else if AsciiTokenEq(ATok, 'sentinel') then
    AConfig.WantSentinel := True
  else
    Inc(AConfig.IgnoredTokens);
end;

procedure ClearConfig(out AConfig: TMemDebugWrapConfig);
begin
  { Do not FillChar managed records (AnsiString EnvRaw). }
  AConfig.EnvRaw := '';
  AConfig.Enabled := False;
  AConfig.WantFail := False;
  AConfig.WantStats := False;
  AConfig.WantTracking := False;
  AConfig.WantSentinel := False;
  AConfig.SafetyProfile := False;
  AConfig.IgnoredTokens := 0;
  AConfig.Built := False;
end;

function ParseMemHeapDebugEnv(const AEnv: AnsiString): Boolean;
var
  L: Integer;
  LTok: AnsiString;
  I: Integer;
  C: AnsiChar;
begin
  L := Length(AEnv);
  if L = 0 then
    Exit(False);
  LTok := AEnv;
  while (Length(LTok) > 0) and ((LTok[1] = ' ') or (LTok[1] = #9)) do
    Delete(LTok, 1, 1);
  while (Length(LTok) > 0) and
    ((LTok[Length(LTok)] = ' ') or (LTok[Length(LTok)] = #9)) do
    Delete(LTok, Length(LTok), 1);
  if LTok = '' then
    Exit(False);
  for I := 1 to Length(LTok) do
  begin
    C := LTok[I];
    if (C >= 'A') and (C <= 'Z') then
      LTok[I] := AnsiChar(Ord(C) + 32);
  end;
  Result := AsciiTokenEq(LTok, '1') or AsciiTokenEq(LTok, 'true') or
    AsciiTokenEq(LTok, 'yes') or AsciiTokenEq(LTok, 'on') or
    AsciiTokenEq(LTok, 'y');
end;

function CachedTruthyEnv(var AState: SizeUInt; const AEnvName: AnsiString): Boolean;
var
  LPrev, LExpected: SizeUInt;
  LEnv: AnsiString;
  LOn: Boolean;
  LNew: SizeUInt;
begin
  { Hot path: plain load after first parse.
    Previous CAS-as-load (AtomicCmpExchange dummy) is a full barrier per call;
    process GetMem/FreeMem each check HEAP_DEBUG + HEAP_SAFETY → multi-barrier
    tax (~7× vs DefaultHeap direct on SC1 flat loop). Env flags are write-once
    after first parse; relaxed read is correct. }
  LPrev := AState;
  if LPrev = ENV_ON then
    Exit(True);
  if LPrev = ENV_OFF then
    Exit(False);
  { ENV_UNREAD: parse once, publish with CAS (first writer wins). }
  LEnv := platform_env_get_str(AEnvName);
  LOn := ParseMemHeapDebugEnv(LEnv);
  if LOn then
    LNew := ENV_ON
  else
    LNew := ENV_OFF;
  LExpected := ENV_UNREAD;
  atomic_compare_exchange_strong(AState, LExpected, LNew, mo_acq_rel, mo_acquire);
  Result := atomic_load(AState, mo_acquire) = ENV_ON;
end;

procedure ParseMemDebugEnv(const AEnv: AnsiString; out AConfig: TMemDebugWrapConfig);
var
  I, LStart, LLen: Integer;
  LTok: AnsiString;
  C: AnsiChar;
begin
  ClearConfig(AConfig);
  AConfig.EnvRaw := AEnv;
  LLen := Length(AEnv);
  if LLen = 0 then
    Exit;
  LStart := 1;
  for I := 1 to LLen + 1 do
  begin
    if I <= LLen then
      C := AEnv[I]
    else
      C := ',';
    if (C = ',') or (C = ';') or (C = ' ') or (C = #9) then
    begin
      if I > LStart then
      begin
        LTok := Copy(AEnv, LStart, I - LStart);
        ApplyToken(LTok, AConfig);
      end;
      LStart := I + 1;
    end;
  end;
  { Enabled only when at least one known token is present.
    Whitespace-only / unknown-only env → no wrap (Growing IAllocator identity). }
  AConfig.Enabled := AConfig.WantFail or AConfig.WantStats or
    AConfig.WantTracking or AConfig.WantSentinel;
end;

function BuildChain(const AConfig: TMemDebugWrapConfig): IAllocator;
var
  LInner: IAllocator;
  LSent: TSentinelAllocator;
  LTrack: TTrackingAllocator;
  LStats: TStatsAllocator;
  LFail: TFailAllocator;
begin
  GTracking := nil;
  GStats := nil;
  { S5: plugin root is Growing IAllocator (same heap as DefaultHeap). }
  LInner := GetGrowingIAllocator;

  { Innermost → outermost per DEBUG-WRAP-DESIGN §3. }
  if AConfig.WantSentinel then
  begin
    { Quarantine depth 0 keeps tests deterministic (no delayed free). }
    LSent := TSentinelAllocator.Create(LInner, 0);
    LInner := LSent;
  end;

  if AConfig.WantTracking then
  begin
    LTrack := TTrackingAllocator.Create(LInner);
    GTracking := LTrack;
    LInner := LTrack;
  end;

  if AConfig.WantStats then
  begin
    LStats := TStatsAllocator.Create(LInner);
    GStats := LStats;
    LInner := LStats;
  end;

  if AConfig.WantFail then
  begin
    { FailAt=0 means never fail by default; tests can SetFailAt later if held. }
    LFail := TFailAllocator.Create(LInner, 0);
    LInner := LFail;
  end;

  Result := LInner;
end;

procedure EnsureBuilt;
var
  LExpected: SizeUInt;
  LEnv: AnsiString;
  LCfg: TMemDebugWrapConfig;
begin
  LExpected := STATE_IDLE;
  if not atomic_compare_exchange_strong(GState, LExpected, STATE_BUILDING, mo_acq_rel, mo_acquire) then
  begin
    if LExpected = STATE_READY then
      Exit;
    { Another thread is building — wait until ready. }
    while atomic_load(GState, mo_acquire) <> STATE_READY do
      ThreadSwitch;
    Exit;
  end;
  { We own the build (transition idle → building). }
  LEnv := platform_env_get_str(MEM_DEBUG_ENV);
  ParseMemDebugEnv(LEnv, LCfg);
  { HEAP_SAFETY with no DEBUG tokens → inject tracking+sentinel for double-free. }
  if (not LCfg.Enabled) and CachedTruthyEnv(GHeapSafetyState, MEM_HEAP_SAFETY_ENV) then
  begin
    LCfg.WantTracking := True;
    LCfg.WantSentinel := True;
    LCfg.Enabled := True;
    LCfg.SafetyProfile := True;
  end;
  if LCfg.Enabled then
    GRoot := BuildChain(LCfg)
  else
  begin
    GRoot := GetGrowingIAllocator;
    GTracking := nil;
    GStats := nil;
  end;
  LCfg.Built := True;
  GConfig := LCfg;
  atomic_store(GState, STATE_READY, mo_release);
end;

function ResolveDefaultAllocator: IAllocator;
begin
  EnsureBuilt;
  Result := GRoot;
end;

function GetDebugWrapConfig: TMemDebugWrapConfig;
begin
  EnsureBuilt;
  Result := GConfig;
end;

function GetDebugWrapTracking: TTrackingAllocator;
begin
  EnsureBuilt;
  Result := GTracking;
end;

function GetDebugWrapStats: TStatsAllocator;
begin
  EnsureBuilt;
  Result := GStats;
end;

function IsMemHeapSafetyEnabled: Boolean;
begin
  Result := CachedTruthyEnv(GHeapSafetyState, MEM_HEAP_SAFETY_ENV);
end;

function IsMemArenaStrictEnabled: Boolean;
begin
  Result := CachedTruthyEnv(GArenaStrictState, MEM_ARENA_STRICT_ENV);
end;

function IsMemHeapDebugEnabled: Boolean;
var
  LPrev, LExpected: SizeUInt;
  LOn: Boolean;
  LNew: SizeUInt;
begin
  { Process path routes through DefaultAllocator when HEAP_DEBUG or HEAP_SAFETY
    is on. Single cached flag so GetMem/FreeMem pay one plain load, not two
    CAS/env probes. }
  LPrev := GProcessRouteState;
  if LPrev = ENV_ON then
    Exit(True);
  if LPrev = ENV_OFF then
    Exit(False);
  LOn := CachedTruthyEnv(GHeapDebugState, MEM_HEAP_DEBUG_ENV) or
    CachedTruthyEnv(GHeapSafetyState, MEM_HEAP_SAFETY_ENV);
  if LOn then
    LNew := ENV_ON
  else
    LNew := ENV_OFF;
  LExpected := ENV_UNREAD;
  atomic_compare_exchange_strong(GProcessRouteState, LExpected, LNew, mo_acq_rel, mo_acquire);
  Result := atomic_load(GProcessRouteState, mo_acquire) = ENV_ON;
end;

procedure ResetDebugWrapForTests;
begin
  { Drop refs so wrappers can finalize; next EnsureBuilt rebuilds. }
  GRoot := nil;
  GTracking := nil;
  GStats := nil;
  ClearConfig(GConfig);
  atomic_store(GState, STATE_IDLE, mo_release);
  atomic_store(GHeapDebugState, ENV_UNREAD, mo_release);
  atomic_store(GHeapSafetyState, ENV_UNREAD, mo_release);
  atomic_store(GArenaStrictState, ENV_UNREAD, mo_release);
  atomic_store(GProcessRouteState, ENV_UNREAD, mo_release);
end;

initialization
  GState := STATE_IDLE;
  GRoot := nil;
  GTracking := nil;
  GStats := nil;
  GHeapDebugState := ENV_UNREAD;
  GHeapSafetyState := ENV_UNREAD;
  GArenaStrictState := ENV_UNREAD;
  GProcessRouteState := ENV_UNREAD;
  ClearConfig(GConfig);

finalization
  GRoot := nil;
  GTracking := nil;
  GStats := nil;
  ClearConfig(GConfig);
  GHeapDebugState := ENV_UNREAD;
  GHeapSafetyState := ENV_UNREAD;
  GArenaStrictState := ENV_UNREAD;
  GProcessRouteState := ENV_UNREAD;

end.
