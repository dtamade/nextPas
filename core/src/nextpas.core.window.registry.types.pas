unit nextpas.core.window.registry.types;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.impl;

type
  TBackendProbe = function: Boolean;
  TBackendCreate = function(const AOptions: TWindowOptions): IWindow;
  TBackendLive = function: Integer;
  TBackendRun = procedure;
  TBackendQuit = procedure;
  TBackendPump = function: Boolean;

  TBackendDesc = record
    Kind: TWindowKind;
    Probe: TBackendProbe;
    Create: TBackendCreate;
    Live: TBackendLive;
    Run: TBackendRun;
    Quit: TBackendQuit;
    Pump: TBackendPump;
    Sonames: string;
  end;
  PBackendDesc = ^TBackendDesc;

  // Registry state — single source for Backends/ProbeCache/DesktopSet/Priority
  // 冷热分离：ProbeCache/Valid 与 DesktopInited 采用 Int32 原子可见性（0/1），热路径 atomic_load acquire 零拷贝无锁，冷路径互斥+atomic_store release 单次发布，消双重延迟初始化上 platform_mutex_lock 混用；容量单源 bytes.ops 0→32→2×
  TWindowRegistry = record
  public
    Backends: array of TBackendDesc;
    Count: Int32;
    Inited: Int32;
    ProbeCache: array[TWindowKind] of Int32; // 0=false 1=true, atomic release/acquire
    ProbeValid: array[TWindowKind] of Int32; // 0=miss 1=valid, atomic
    DesktopSet: set of TWindowKind;
    DesktopInited: Int32; // 0=not inited 1=inited, atomic
    PriorityMap: array[TWindowKind] of Integer;
    PriorityInited: Boolean;
    PumpLastIdx: Int32;
    procedure EnsureDesktopLocked; inline;
    procedure EnsurePriorityLocked; inline;
    function IsDesktopLocked(AKind: TWindowKind): Boolean; inline;
    function PriorityOf(AKind: TWindowKind): Integer; inline;
    procedure EnsureCapacity; inline;
  end;

const
  CBackendOrder: array[0..10] of TWindowKind = (
    wkWin32, wkCocoa, wkAndroid, wkUIKit, wkWasm, wkGtk4, wkGtk3, wkGtk2, wkQt, wkSdl2, wkFake);
  CBackendCount = High(CBackendOrder) - Low(CBackendOrder) + 1;
  CGtkFallbackStart = 5;
  CGtkFallbackCount = 3;
  CDesktopCount = 7;

type
  TAssertBackendOrderLen = array[0..Ord(CBackendCount = Ord(High(TWindowKind)) - Ord(Low(TWindowKind)) + 1)-1] of Byte;
  TAssertDesktopLen = array[0..Ord(CDesktopCount = 7)-1] of Byte;

function IsGtkFamilyKind(AKind: TWindowKind): Boolean; inline;

implementation

function IsGtkFamilyKind(AKind: TWindowKind): Boolean; inline;
begin
  Result := AKind in [wkGtk4, wkGtk3, wkGtk2];
end;

procedure TWindowRegistry.EnsureDesktopLocked; inline;
var I: Integer; LKind: TWindowKind;
begin
  if DesktopInited <> 0 then Exit;
  DesktopSet := [];
  for I := Low(CBackendOrder) to High(CBackendOrder) do
  begin
    LKind := CBackendOrder[I];
    if LKind in [wkAndroid, wkUIKit, wkWasm, wkFake] then Continue;
    Include(DesktopSet, LKind);
  end;
  DesktopInited := 1;
end;

procedure TWindowRegistry.EnsurePriorityLocked; inline;
var I: Integer;
begin
  if PriorityInited then Exit;
  for I := Ord(Low(TWindowKind)) to Ord(High(TWindowKind)) do PriorityMap[TWindowKind(I)] := CBackendCount;
  for I := Low(CBackendOrder) to High(CBackendOrder) do PriorityMap[CBackendOrder[I]] := I;
  PriorityInited := True;
end;

function TWindowRegistry.IsDesktopLocked(AKind: TWindowKind): Boolean; inline;
begin
  Result := AKind in DesktopSet;
end;

function TWindowRegistry.PriorityOf(AKind: TWindowKind): Integer; inline;
begin
  Result := PriorityMap[AKind];
end;

procedure TWindowRegistry.EnsureCapacity; inline;
begin
  if Count < Length(Backends) then Exit;
  if Length(Backends) = 0 then SetLength(Backends, WindowGrowCapacity(0))
  else SetLength(Backends, WindowGrowCapacity(Length(Backends)));
end;

end.
