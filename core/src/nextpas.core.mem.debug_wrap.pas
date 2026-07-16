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
 * NEXTPAS_MEM_HEAP_DEBUG is explicitly enabled (slow opt-in; routes process
 * GetMem/FreeMem/… through DefaultAllocator so wraps can observe them).
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

type
  {** Snapshot of parsed DEBUG wrap intent and build state. }
  TMemDebugWrapConfig = record
    EnvRaw: AnsiString;
    Enabled: Boolean;
    WantFail: Boolean;
    WantStats: Boolean;
    WantTracking: Boolean;
    WantSentinel: Boolean;
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

{** True when NEXTPAS_MEM_HEAP_DEBUG is truthy (lazy parse + cache).
    Process GetMem/FreeMem must check this; DefaultHeap never does. }
function IsMemHeapDebugEnabled: Boolean;

{** Pure parse for HEAP_DEBUG env values (1/true/yes/on). }
function ParseMemHeapDebugEnv(const AEnv: AnsiString): Boolean;

{** Drop singleton so next ResolveDefaultAllocator rebuilds from current env.
    Also clears HEAP_DEBUG cache. Test-only; not for production hot paths. }
procedure ResetDebugWrapForTests;

{** Parse env string into flags (pure; no side effects). }
procedure ParseMemDebugEnv(const AEnv: AnsiString; out AConfig: TMemDebugWrapConfig);

implementation

uses
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
  { HEAP_DEBUG cache: 0 unread, 1 off, 2 on }
  HEAP_DEBUG_UNREAD = 0;
  HEAP_DEBUG_OFF = 1;
  HEAP_DEBUG_ON = 2;

var
  GState: SizeUInt;
  GRoot: IAllocator;
  GConfig: TMemDebugWrapConfig;
  GTracking: TTrackingAllocator;
  GStats: TStatsAllocator;
  GHeapDebugState: SizeUInt;

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
  AConfig.IgnoredTokens := 0;
  AConfig.Built := False;
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
  LPrev: SizeUInt;
  LEnv: AnsiString;
  LCfg: TMemDebugWrapConfig;
begin
  LPrev := AtomicCmpExchange(GState, STATE_BUILDING, STATE_IDLE);
  if LPrev = STATE_READY then
    Exit;
  if LPrev = STATE_BUILDING then
  begin
    while AtomicCmpExchange(GState, STATE_READY, STATE_READY) <> STATE_READY do
      ThreadSwitch;
    Exit;
  end;
  { We own the build (transition idle → building). }
  LEnv := platform_env_get_str(MEM_DEBUG_ENV);
  ParseMemDebugEnv(LEnv, LCfg);
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
  AtomicExchange(GState, STATE_READY);
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
  { Trim spaces/tabs }
  LTok := AEnv;
  while (Length(LTok) > 0) and ((LTok[1] = ' ') or (LTok[1] = #9)) do
    Delete(LTok, 1, 1);
  while (Length(LTok) > 0) and
    ((LTok[Length(LTok)] = ' ') or (LTok[Length(LTok)] = #9)) do
    Delete(LTok, Length(LTok), 1);
  if LTok = '' then
    Exit(False);
  { Lowercase ASCII for compare }
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

function IsMemHeapDebugEnabled: Boolean;
var
  LPrev: SizeUInt;
  LEnv: AnsiString;
  LOn: Boolean;
  LNew: SizeUInt;
begin
  LPrev := AtomicCmpExchange(GHeapDebugState, HEAP_DEBUG_UNREAD, HEAP_DEBUG_UNREAD);
  if LPrev = HEAP_DEBUG_ON then
    Exit(True);
  if LPrev = HEAP_DEBUG_OFF then
    Exit(False);
  { Unread or racing: parse env and publish. }
  LEnv := platform_env_get_str(MEM_HEAP_DEBUG_ENV);
  LOn := ParseMemHeapDebugEnv(LEnv);
  if LOn then
    LNew := HEAP_DEBUG_ON
  else
    LNew := HEAP_DEBUG_OFF;
  AtomicCmpExchange(GHeapDebugState, LNew, HEAP_DEBUG_UNREAD);
  { If another thread published first, re-read. }
  Result := AtomicCmpExchange(GHeapDebugState, 0, 0) = HEAP_DEBUG_ON;
end;

procedure ResetDebugWrapForTests;
begin
  { Drop refs so wrappers can finalize; next EnsureBuilt rebuilds. }
  GRoot := nil;
  GTracking := nil;
  GStats := nil;
  ClearConfig(GConfig);
  AtomicExchange(GState, STATE_IDLE);
  AtomicExchange(GHeapDebugState, HEAP_DEBUG_UNREAD);
end;

initialization
  GState := STATE_IDLE;
  GRoot := nil;
  GTracking := nil;
  GStats := nil;
  GHeapDebugState := HEAP_DEBUG_UNREAD;
  ClearConfig(GConfig);

finalization
  GRoot := nil;
  GTracking := nil;
  GStats := nil;
  ClearConfig(GConfig);
  GHeapDebugState := HEAP_DEBUG_UNREAD;

end.
