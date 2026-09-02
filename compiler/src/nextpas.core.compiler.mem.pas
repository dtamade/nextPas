unit nextpas.core.compiler.mem;
{**
 * @desc Compiler unit-scoped memory helpers backed by nextpas.core.mem.
 *
 * Product wire for stage0 / compiler modules that currently use rtl
 * TBumpArena. Prefer VirtualArena for large AST / IR churn (grows via
 * mmap, Reset at unit boundary). Do not FreeMem arena blocks.
 *
 * Fine-grained mem units only — not the mem facade — so compiler graph
 * stays free of overload collisions.
 *
 * Long-lived process state: CompilerProcessHeap / CompilerProcessAllocator.
 *
 * Location: tooling layer (compiler), not core/src. Registry layer=tooling.
 * Core/src flat constraint: this unit is owned by compiler package; core
 * consumers use only via compiler search path, not via core/src re-export.
 * Single source: bytes.ops remains the sole bytes concat/copy source.
 * Inline/zero-copy: process heap accessors are inline, arena alloc is
 * zero-copy Move, resource release via EndScope/Reset not lost.
}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.arena.intf,
  nextpas.core.mem.arena.virtual,
  nextpas.core.mem.allocator.growing;

type
  IArena = nextpas.core.mem.arena.intf.IArena;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TGrowingAllocator = nextpas.core.mem.allocator.growing.TGrowingAllocator;
  TVirtualArena = nextpas.core.mem.arena.virtual.TVirtualArena;

  {** Unit-compile scope over VirtualArena (pair BeginScope/EndScope).
   *  Prefer this over bare CompilerInitUnitArena for new compiler code.
   *  Do not FreeMem arena blocks — Reset or EndScope bulk-reclaims. }
  TCompilerUnitScope = record
  private
    FArena: TVirtualArena;
    FActive: Boolean;
  public
    procedure BeginScope(AAlignment: SizeUInt = 0);
    procedure EndScope;
    procedure Reset;
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocNoPointer(ASize: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    {** Boolean form of Alloc (resource failure = False + nil). }
    function TryAlloc(ASize: SizeUInt; out APtr: Pointer): Boolean;
    function TotalUsed: SizeUInt;
    function PeakUsed: SizeUInt;
    function Active: Boolean;
    {** One-line ops snapshot (not hot path). Keys: active/peak/used. }
    function FormatStats: string;
  end;

  {** Compilation-session scope: one VirtualArena for the whole build session.
   *  Pair BeginSession/EndSession. Between units call Reset (or UnitBegin
   *  which is Reset + optional peak accounting). Prefer over nesting many
   *  TCompilerUnitScope when session lifetime owns all unit scratch.
   *  Do not FreeMem arena blocks. }
  TCompilerSessionScope = record
  private
    FArena: TVirtualArena;
    FActive: Boolean;
    FUnitCount: SizeUInt;
    FSessionPeak: SizeUInt;
  public
    procedure BeginSession(AAlignment: SizeUInt = 0);
    procedure EndSession;
    {** Start next unit: Reset scratch; bump unit count. }
    procedure UnitBegin;
    {** End unit: track peak; leave arena for next UnitBegin/Reset. }
    procedure UnitEnd;
    procedure Reset;
    function Alloc(ASize: SizeUInt): Pointer;
    function AllocNoPointer(ASize: SizeUInt): Pointer;
    function AllocZeroed(ASize: SizeUInt): Pointer;
    function TryAlloc(ASize: SizeUInt; out APtr: Pointer): Boolean;
    function TotalUsed: SizeUInt;
    function PeakUsed: SizeUInt;
    function SessionPeak: SizeUInt;
    function UnitCount: SizeUInt;
    function Active: Boolean;
    {** One-line ops snapshot (not hot path). Keys: active/units/peak/used.
     *  peak = SessionPeak (max unit PeakUsed across UnitEnd). }
    function FormatStats: string;
  end;

{** Init a unit-scoped VirtualArena (compiler AST / IR). Pair with Release. }
procedure CompilerInitUnitArena(out AArena: TVirtualArena;
  AAlignment: SizeUInt = 0);

{** Release unit arena (after final unit Reset or at process end). }
procedure CompilerReleaseUnitArena(var AArena: TVirtualArena);

{** IAllocator over VirtualArena (FreeMem no-op; call Reset for bulk reclaim). }
function CompilerCreateUnitAllocator(AAlignment: SizeUInt = 0): IAllocator;

{** IArena adapter over VirtualArena (polymorphic unit scope). }
function CompilerCreateUnitArenaAdapter(AAlignment: SizeUInt = 0): IArena;

{** Process hot-path heap for long-lived compiler state. }
function CompilerProcessHeap: TGrowingAllocator; inline;

{** Process IAllocator plug-in surface. }
function CompilerProcessAllocator: IAllocator; inline;

{** Discoverable aliases for scope FormatStats (ops/debug; not hot). }
function CompilerFormatUnitStats(const AScope: TCompilerUnitScope): string; inline;
function CompilerFormatSessionStats(const ASession: TCompilerSessionScope): string; inline;

implementation

uses
  nextpas.core.mem.allocator.arena,
  nextpas.core.mem.default,
  nextpas.core.mem.base;

{ TCompilerUnitScope }

procedure TCompilerUnitScope.BeginScope(AAlignment: SizeUInt);
begin
  if FActive then
    EndScope;
  CompilerInitUnitArena(FArena, AAlignment);
  FActive := True;
end;

procedure TCompilerUnitScope.EndScope;
begin
  if not FActive then
    Exit;
  CompilerReleaseUnitArena(FArena);
  FActive := False;
end;

procedure TCompilerUnitScope.Reset;
begin
  if FActive then
    FArena.Reset;
end;

function TCompilerUnitScope.Alloc(ASize: SizeUInt): Pointer;
begin
  if not FActive then
    Exit(nil);
  Result := FArena.Alloc(ASize);
end;

function TCompilerUnitScope.AllocNoPointer(ASize: SizeUInt): Pointer;
begin
  if not FActive then
    Exit(nil);
  Result := FArena.AllocNoPointer(ASize);
end;

function TCompilerUnitScope.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  if not FActive then
    Exit(nil);
  Result := FArena.AllocZeroed(ASize);
end;

function TCompilerUnitScope.TryAlloc(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := Alloc(ASize);
  Result := APtr <> nil;
end;

function TCompilerUnitScope.TotalUsed: SizeUInt;
begin
  if not FActive then
    Exit(0);
  Result := FArena.TotalUsed;
end;

function TCompilerUnitScope.PeakUsed: SizeUInt;
begin
  if not FActive then
    Exit(0);
  Result := FArena.PeakUsed;
end;

function TCompilerUnitScope.Active: Boolean;
begin
  Result := FActive;
end;

function TCompilerUnitScope.FormatStats: string;
var
  LActive: string;
begin
  if FActive then
    LActive := '1'
  else
    LActive := '0';
  Result :=
    'mem unit: active=' + LActive +
    ' peak=' + IntToStr(Int64(PeakUsed)) +
    ' used=' + IntToStr(Int64(TotalUsed));
end;

{ TCompilerSessionScope }

procedure TCompilerSessionScope.BeginSession(AAlignment: SizeUInt);
begin
  if FActive then
    EndSession;
  CompilerInitUnitArena(FArena, AAlignment);
  FActive := True;
  FUnitCount := 0;
  FSessionPeak := 0;
end;

procedure TCompilerSessionScope.EndSession;
begin
  if not FActive then
    Exit;
  CompilerReleaseUnitArena(FArena);
  FActive := False;
  FUnitCount := 0;
  FSessionPeak := 0;
end;

procedure TCompilerSessionScope.UnitBegin;
begin
  if not FActive then
    Exit;
  FArena.Reset;
  Inc(FUnitCount);
end;

procedure TCompilerSessionScope.UnitEnd;
var
  LUsed: SizeUInt;
begin
  if not FActive then
    Exit;
  LUsed := FArena.PeakUsed;
  if LUsed > FSessionPeak then
    FSessionPeak := LUsed;
end;

procedure TCompilerSessionScope.Reset;
begin
  if FActive then
    FArena.Reset;
end;

function TCompilerSessionScope.Alloc(ASize: SizeUInt): Pointer;
begin
  if not FActive then
    Exit(nil);
  Result := FArena.Alloc(ASize);
end;

function TCompilerSessionScope.AllocNoPointer(ASize: SizeUInt): Pointer;
begin
  if not FActive then
    Exit(nil);
  Result := FArena.AllocNoPointer(ASize);
end;

function TCompilerSessionScope.AllocZeroed(ASize: SizeUInt): Pointer;
begin
  if not FActive then
    Exit(nil);
  Result := FArena.AllocZeroed(ASize);
end;

function TCompilerSessionScope.TryAlloc(ASize: SizeUInt; out APtr: Pointer): Boolean;
begin
  APtr := Alloc(ASize);
  Result := APtr <> nil;
end;

function TCompilerSessionScope.TotalUsed: SizeUInt;
begin
  if not FActive then
    Exit(0);
  Result := FArena.TotalUsed;
end;

function TCompilerSessionScope.PeakUsed: SizeUInt;
begin
  if not FActive then
    Exit(0);
  Result := FArena.PeakUsed;
end;

function TCompilerSessionScope.SessionPeak: SizeUInt;
begin
  Result := FSessionPeak;
end;

function TCompilerSessionScope.UnitCount: SizeUInt;
begin
  Result := FUnitCount;
end;

function TCompilerSessionScope.Active: Boolean;
begin
  Result := FActive;
end;

function TCompilerSessionScope.FormatStats: string;
var
  LActive: string;
begin
  if FActive then
    LActive := '1'
  else
    LActive := '0';
  Result :=
    'mem session: active=' + LActive +
    ' units=' + IntToStr(Int64(UnitCount)) +
    ' peak=' + IntToStr(Int64(SessionPeak)) +
    ' used=' + IntToStr(Int64(TotalUsed));
end;

procedure CompilerInitUnitArena(out AArena: TVirtualArena; AAlignment: SizeUInt);
begin
  if AAlignment = 0 then
    AAlignment := DEFAULT_ALIGNMENT;
  TVirtualArena_Init(AArena, AAlignment);
end;

procedure CompilerReleaseUnitArena(var AArena: TVirtualArena);
begin
  TVirtualArena_Release(AArena);
end;

function CompilerCreateUnitAllocator(AAlignment: SizeUInt): IAllocator;
begin
  if AAlignment = 0 then
    Result := TVirtualArenaAllocator.Create
  else
    Result := TVirtualArenaAllocator.Create(AAlignment);
end;

function CompilerCreateUnitArenaAdapter(AAlignment: SizeUInt): IArena;
begin
  if AAlignment = 0 then
    Result := TVirtualArenaAdapter.Create
  else
    Result := TVirtualArenaAdapter.Create(AAlignment);
end;

function CompilerProcessHeap: TGrowingAllocator;
begin
  Result := DefaultHeap;
end;

function CompilerProcessAllocator: IAllocator;
begin
  Result := DefaultAllocator;
end;

function CompilerFormatUnitStats(const AScope: TCompilerUnitScope): string;
begin
  Result := AScope.FormatStats;
end;

function CompilerFormatSessionStats(const ASession: TCompilerSessionScope): string;
begin
  Result := ASession.FormatStats;
end;

end.
