unit nextpas.core.webview.registry;

{** @desc webview 后端探测注册表（独立探测职责单源）。

       S* 匠心修复：factory 原承载"后端探测 + 创建分发"双职责，
       WEBVIEW_BACKENDS 表内 Probe/Create 耦合；本单元抽离探测侧
       为独立注册模块候选单源（Probe 单表），与 factory 创建分发
       分离，守四件套与 L0-L3、复用 loader 双检锁已缓存 + bytes.ops
       单源思想。

       工厂只管创建分发（Create/CreateOn 单表）；探测有无/默认 kind
       统一走本单元薄转发，热点路径快照复用零重复 TryLoad* 双检锁。

       依赖：仅 L3 loaders (gtk/webview2/wk) + base；不触 window/
       bridge/factory 循环。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.webview.base;

{ 后端可用性（编译内建 + 运行时可装载合并事实，热点快照复用）。
  perf: inline + 零拷贝 view 思想 + 快照缓存数组 O(1) 命中零额外双检锁，
        未命中单次 Probe 落 loader 双检锁幂等缓存（atomic+mutex），零堆分配。 }
function WebviewProbeAvailable(AKind: TWebviewKind): Boolean; inline;

{ 能力驱动默认 kind（探测优先，热点快照复用）。
  perf: inline + 快照复用 GDefaultSnapshot，零重复 RawProbe/双检锁，零拷贝。 }
function WebviewDefaultKind: TWebviewKind; inline;

{ 原始探测（无快照，供测试/诊断对比）；inline 薄转发单表。 }
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

{ ---- 探测函数：单源薄转发 loader 双检锁已缓存探针（零堆分配） ---- }

function ProbeFake: Boolean; inline;
begin
  Result := True;
end;

function ProbeGtk: Boolean; inline;
var L: TGtkLoadInfo;
begin
  // perf: inline zero-copy thin-forward to loader TryLoadGtkWebkit (atomic acquire快路径 + mutex双检锁幂等缓存，零堆分配)
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

{ ---- 快照缓存：热点路径零重复双检锁（进程级稳定，loader 已幂等） ----
  匠心修复：ShortInt -1 魔数→显式枚举哨兵 + 原子可见性 + L1 sync Owner 单源锁 }

type
  { 显式 Option/枚举哨兵：消除 ShortInt -1 类型不诚实，零魔数漂移 }
  TProbeSnap = (psUnknown, psFalse, psTrue);

const
  REG_DEFAULT_UNKNOWN = 0; { 0 unknown, else Ord(TWebviewKind)+1 }

var
  GProbeSnapshot: array[TWebviewKind] of Int32 = (0, 0, 0, 0); { Ord(TProbeSnap) 原子，acquire/release 可见性 }
  GDefaultSnapshot: Int32 = 0; { REG_DEFAULT_UNKNOWN else Ord(kind)+1 原子 }
  GRegistryLock: TMutex; { L1 sync Owner 单源：首触并发零撕裂，替代裸全局变量竞态 }
  GRegistryOnce: IOnce; { L1 sync.once 单源：锁惰性创建零双分配 }

procedure EnsureRegistryLock; inline;
begin
  // perf: inline 零额外调用；Once 单源保护懒创建，热点双检锁零分配
  if GRegistryLock <> nil then Exit;
  if GRegistryOnce = nil then
  begin
    GRegistryLock := TMutex.Create;
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
  // perf: inline 快照 O(1) acquire 复用，命中零 Probe/零锁/零堆分配；未命中单次 RawProbe 落 loader 缓存（原子+mutex 双检锁）
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
  // perf: inline 快照复用 acquire，命中零循环零 Probe/零锁，零拷贝
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
      // 锁内直探，避免嵌套 WebviewProbeAvailable 重入同一 mutex 死锁；仍复用原子快照+RawProbe 单源
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
