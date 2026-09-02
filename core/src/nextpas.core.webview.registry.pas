unit nextpas.core.webview.registry;

{** @desc webview 后端探测注册表（探测职责单源）。
       Probe 单表与 factory 创建分发分离；探测有无/默认 kind 由本
       单元提供，工厂仅负责 Create/CreateOn。热点路径复用快照，
       未命中落 loader 双检锁缓存。
       依赖：L3 loaders (gtk/webview2/wk) + base；不触 window/
       bridge/factory。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base;

{ 后端可用性（编译内建 + 运行时装载合并，快照复用）。 }
function WebviewProbeAvailable(AKind: TWebviewKind): Boolean; inline;

{ 能力驱动默认 kind（探测优先，快照复用）。 }
function WebviewDefaultKind: TWebviewKind; inline;

{ 原始探测（无快照，供测试/诊断）。 }
function WebviewRawProbe(AKind: TWebviewKind): Boolean; inline;

implementation

uses
  nextpas.core.atomic,
  nextpas.core.sync,
  nextpas.core.sync.mutex,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.wk.loader;

type
  TWebviewProbe = function: Boolean;

{ 探测函数：薄转发 loader 已缓存探针 }

function ProbeFake: Boolean; inline;
begin
  Result := True;
end;

function ProbeGtk: Boolean; inline;
var L: TGtkLoadInfo;
begin
  Result := TryLoadGtkWebkit(L);
end;

function ProbeWebView2: Boolean; inline;
var L: TWebView2LoadInfo;
begin
  Result := TryLoadWebView2(L);
end;

function ProbeWk: Boolean; inline;
var L: TWkLoadInfo;
begin
  Result := TryLoadWk(L);
end;

type
  TWebviewProbeDesc = record
    Kind: TWebviewKind;
    Probe: TWebviewProbe;
  end;

const
  WEBVIEW_PROBES: array[0..3] of TWebviewProbeDesc = (
    (Kind: wvFake; Probe: @ProbeFake),
    (Kind: wvGtk; Probe: @ProbeGtk),
    (Kind: wvWebview2; Probe: @ProbeWebView2),
    (Kind: wvWk; Probe: @ProbeWk)
  );

{ 快照缓存（进程级，依赖 loader 幂等） }

type
  { 显式哨兵 }
  TProbeSnap = (psUnknown, psFalse, psTrue);

const
  REG_DEFAULT_UNKNOWN = 0; { 0 unknown, else Ord(TWebviewKind)+1 }

var
  GProbeSnapshot: array[TWebviewKind] of Int32 = (0, 0, 0, 0); { Ord(TProbeSnap)，原子可见性 }
  GDefaultSnapshot: Int32 = 0; { REG_DEFAULT_UNKNOWN else Ord(kind)+1，原子 }
  GRegistryLock: TMutex; { L1 sync 互斥，保护快照 }
  GRegistryOnce: IOnce; { L1 sync.once，锁惰性创建 }

procedure EnsureRegistryLock; inline;
var
  LNew: TMutex;
  LExpected: Pointer;
begin
  if atomic_load(PPointer(@GRegistryLock)^, mo_acquire) <> nil then Exit;
  if GRegistryOnce = nil then
  begin
    LNew := TMutex.Create;
    LExpected := nil;
    if not atomic_compare_exchange_strong(PPointer(@GRegistryLock)^, LExpected, Pointer(LNew), mo_acq_rel, mo_acquire) then
      LNew.Free;
    Exit;
  end;
  GRegistryOnce.DoOnce(procedure
  begin
    if GRegistryLock = nil then
      GRegistryLock := TMutex.Create;
  end);
end;

function FindProbe(AKind: TWebviewKind): TWebviewProbe; inline;
var I: Integer;
begin
  for I := Low(WEBVIEW_PROBES) to High(WEBVIEW_PROBES) do
    if WEBVIEW_PROBES[I].Kind = AKind then
      Exit(WEBVIEW_PROBES[I].Probe);
  Result := nil;
end;

function WebviewRawProbe(AKind: TWebviewKind): Boolean; inline;
var P: TWebviewProbe;
begin
  if AKind = wvFake then Exit(True);
  P := FindProbe(AKind);
  if not Assigned(P) then Exit(False);
  Result := P();
end;

function WebviewProbeAvailable(AKind: TWebviewKind): Boolean; inline;
var LSnap: Int32;
begin
  if (AKind < Low(TWebviewKind)) or (AKind > High(TWebviewKind)) then Exit(False);
  if AKind = wvFake then Exit(True);
  // 快照命中直接返回；未命中单次探测落 loader 缓存
  LSnap := atomic_load(GProbeSnapshot[AKind], mo_acquire);
  if LSnap <> Ord(psUnknown) then Exit(LSnap = Ord(psTrue));
  EnsureRegistryLock;
  GRegistryLock.Acquire;
  try
    LSnap := atomic_load(GProbeSnapshot[AKind], mo_acquire);
    if LSnap <> Ord(psUnknown) then Exit(LSnap = Ord(psTrue));
    Result := WebviewRawProbe(AKind);
    if Result then LSnap := Ord(psTrue) else LSnap := Ord(psFalse);
    atomic_store(GProbeSnapshot[AKind], LSnap, mo_release);
  finally
    GRegistryLock.Release;
  end;
end;

function WebviewDefaultKind: TWebviewKind; inline;
var
  LSnap: Int32;
  I: Integer;
  LKind: TWebviewKind;
  LProbeSnap: Int32;
  LAvail: Boolean;
begin
  // 快照命中直接返回
  LSnap := atomic_load(GDefaultSnapshot, mo_acquire);
  if LSnap <> REG_DEFAULT_UNKNOWN then Exit(TWebviewKind(LSnap - 1));
  EnsureRegistryLock;
  GRegistryLock.Acquire;
  try
    LSnap := atomic_load(GDefaultSnapshot, mo_acquire);
    if LSnap <> REG_DEFAULT_UNKNOWN then Exit(TWebviewKind(LSnap - 1));
    for I := Low(WEBVIEW_PROBES) to High(WEBVIEW_PROBES) do
    begin
      LKind := WEBVIEW_PROBES[I].Kind;
      if LKind = wvFake then Continue;
      // 锁内直探，避免重入同一 mutex 死锁
      LProbeSnap := atomic_load(GProbeSnapshot[LKind], mo_acquire);
      if LProbeSnap <> Ord(psUnknown) then
      begin
        if LProbeSnap = Ord(psTrue) then
        begin
          atomic_store(GDefaultSnapshot, Ord(LKind) + 1, mo_release);
          Exit(LKind);
        end;
        Continue;
      end;
      LAvail := WebviewRawProbe(LKind);
      if LAvail then LProbeSnap := Ord(psTrue) else LProbeSnap := Ord(psFalse);
      atomic_store(GProbeSnapshot[LKind], LProbeSnap, mo_release);
      if LAvail then
      begin
        atomic_store(GDefaultSnapshot, Ord(LKind) + 1, mo_release);
        Exit(LKind);
      end;
    end;
    atomic_store(GDefaultSnapshot, Ord(wvFake) + 1, mo_release);
    Result := wvFake;
  finally
    GRegistryLock.Release;
  end;
end;

initialization
  GRegistryOnce := Once;
  EnsureRegistryLock;

finalization
  if GRegistryLock <> nil then
  begin
    GRegistryLock.Free;
    GRegistryLock := nil;
  end;
  GRegistryOnce := nil;

end.
