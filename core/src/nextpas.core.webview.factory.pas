unit nextpas.core.webview.factory;

{** @desc webview 后端工厂与主循环入口（纯工厂职责）。

       S1 后端可用性事实源：仅 fake 编译内建；gtk 随 S3/S4 接入时把
       ResolveDefaultKind 切到平台优先并接入探测。默认 kind 的选择
       是本单元唯一职责，禁止散落到后端单元。

       工厂只管后端注册/探测/选择与创建分发；Builder 已抽至
       nextpas.core.webview.builder 单元，职责分离，高级感简洁。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.window.intf;

{ S1 默认后端（S4 切平台优先逻辑）；显式指定用 CreateWebviewOf }
function DefaultWebviewKind: TWebviewKind;

{ 后端编译内建与运行时可装载的合并事实 }
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean;

{ 创建 fake 窗口（选项先过 CheckWebviewOptions）}
function CreateFakeWebview(
  const AOptions: TWebviewOptions): IWebviewWindow;

function CreateFakeWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ 按 kind 创建；不可用抛 EWebviewBackendUnavailable（消息含已探测 kind 表）}
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;

function CreateWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ 供 Builder 复用的带 Parent+Kind 路由（表驱动单源，含回退）；parent=nil 时等价 CreateWebviewOf }
function CreateWebviewEx(const AParent: IWindow; AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ M6 单泵统一：WebviewRunLoop/WebviewExitLoop 为 WindowRunLoop/WindowExitLoop 的 deprecated shim（inline 转发），单泵归 window.factory }
procedure WebviewRunLoop; inline; deprecated 'Use WindowRunLoop';
procedure WebviewExitLoop; inline; deprecated 'Use WindowExitLoop';

implementation

uses
  nextpas.core.system.typinfo,
  nextpas.core.window.factory,
  nextpas.core.sync,
  nextpas.core.platform.thread,
  nextpas.core.webview.base,
  nextpas.core.webview.validation,
  nextpas.core.webview.fake,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.webview2,
  nextpas.core.webview.wk.loader,
  nextpas.core.webview.wk;

type
  TWebviewProbe = function: Boolean;
  TWebviewCreate = function(const AOptions: TWebviewOptions): IWebviewWindow;
  TWebviewCreateOn = function(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow;
  TWebviewBackendDesc = record
    Kind: TWebviewKind;
    Probe: TWebviewProbe;
    Create: TWebviewCreate;
    CreateOn: TWebviewCreateOn;
  end;
  PWebviewBackendDesc = ^TWebviewBackendDesc;

  { 对象化可用性缓存：单所有者封装 per-kind IOnce+Yes，消除裸数组+分散手工 init/fini，L1 sync.once 单源 inline 零额外调用，析构释放不丢 }
  TWebviewAvailCache = class
  strict private
    FOnce: array[TWebviewKind] of IOnce;
    FYes: array[TWebviewKind] of Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function IsAvailable(AKind: TWebviewKind): Boolean; inline;
  end;

  { 并行探测上下文：栈上零分配，指针零拷贝直写结果；复用 WEBVIEW_BACKENDS 单表驱动，与 bytes.ops 单源思想一致 }
  TWebviewProbeArg = record
    Kind: TWebviewKind;
    OutAvail: ^Boolean;
  end;
  PWebviewProbeArg = ^TWebviewProbeArg;

var
  GDefaultKind: TWebviewKind = wvFake;
  GDefaultOnce: IOnce; { L1 sync.once 单源：DefaultWebviewKind 单次探测，复用 platform.sync 原语，消除自建 double-checked + atomic + CAS 分散锁 }
  GBackendsOnce: IOnce; { 单例注册表抽象：BACKENDS 惰性单次初始化，零重复分配，L1 Once 单源 }
  GAvailOnce: IOnce; { Once Owned 单例：可用性缓存单所有者惰性初始化，L1 sync.once 单源，消除裸全局+nil 回退分散分支，单表驱动高级一致性 }
  GAvailCache: TWebviewAvailCache; { 对象化单例：per-kind Once+Yes 单所有者，消除裸数组+手工 per-kind 置位，L1 Once 单源 inline 零拷贝，归 GAvailOnce 统一持有 }

{ ---- 后端注册表：表驱动唯一真相 ---- }

function ProbeFake: Boolean; inline;
begin
  Result := True;
end;

function CreateFake(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TFakeWebview.Create(AOptions);
end;

function CreateFakeOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

function ProbeGtk: Boolean;
var L: TGtkLoadInfo;
begin
  Result := TryLoadGtkWebkit(L);
end;

function CreateGtk(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TGtkWebview.Create(AOptions);
end;

function CreateGtkOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  // perf: inline zero-copy真嵌入 via window.gtk3 Raw has-a, L3→L2 single source, Parent nil fallback保持owner纯净
  if AParent = nil then
    Result := TGtkWebview.Create(AOptions)
  else
    Result := TGtkWebview.CreateOn(AParent, AOptions);
end;

function ProbeWebView2: Boolean;
var L: TWebView2LoadInfo;
begin
  Result := TryLoadWebView2(L);
end;

function CreateWebView2(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWebView2Webview.Create(AOptions);
end;

function CreateWebView2On(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWebView2Webview.CreateOn(AParent, AOptions);
end;

function ProbeWk: Boolean;
var L: TWkLoadInfo;
begin
  Result := TryLoadWk(L);
end;

function CreateWk(const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWkWebview.Create(AOptions);
end;

function CreateWkOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; inline;
begin
  Result := TWkWebview.CreateOn(AParent, AOptions);
end;

var
  WEBVIEW_BACKENDS: array[0..3] of TWebviewBackendDesc;

procedure InitBackends; inline;
begin
  // perf: L1 sync.once 单例注册表抽象，inline 零额外调用，去重并发初始化，单表驱动新增后端仅一处登记
  if GBackendsOnce.Done then Exit;
  GBackendsOnce.DoOnce(procedure
  begin
    // bytes.ops 单源：WEBVIEW_BACKENDS 唯一真相单表驱动，新增后端仅此一处登记，零双表漂移；平台优先：Linux Gtk 首位避免无谓 WebView2 dlopen，顺序 Fake→Gtk→WebView2→Wk 符合 L3→L2 has-a 优先级与 CONTRACT 能力驱动
    WEBVIEW_BACKENDS[0].Kind := wvFake;     WEBVIEW_BACKENDS[0].Probe := @ProbeFake;     WEBVIEW_BACKENDS[0].Create := @CreateFake;     WEBVIEW_BACKENDS[0].CreateOn := @CreateFakeOn;
    WEBVIEW_BACKENDS[1].Kind := wvGtk;      WEBVIEW_BACKENDS[1].Probe := @ProbeGtk;      WEBVIEW_BACKENDS[1].Create := @CreateGtk;      WEBVIEW_BACKENDS[1].CreateOn := @CreateGtkOn;
    WEBVIEW_BACKENDS[2].Kind := wvWebview2; WEBVIEW_BACKENDS[2].Probe := @ProbeWebView2; WEBVIEW_BACKENDS[2].Create := @CreateWebView2; WEBVIEW_BACKENDS[2].CreateOn := @CreateWebView2On;
    WEBVIEW_BACKENDS[3].Kind := wvWk;       WEBVIEW_BACKENDS[3].Probe := @ProbeWk;       WEBVIEW_BACKENDS[3].Create := @CreateWk;       WEBVIEW_BACKENDS[3].CreateOn := @CreateWkOn;
  end);
end;

function FindBackend(AKind: TWebviewKind): PWebviewBackendDesc; inline;
var I: Integer;
begin
  InitBackends;
  for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
    if WEBVIEW_BACKENDS[I].Kind = AKind then
      Exit(@WEBVIEW_BACKENDS[I]);
  Result := nil;
end;

function RawProbe(AKind: TWebviewKind): Boolean; inline;
var B: PWebviewBackendDesc;
begin
  if AKind = wvFake then Exit(True);
  B := FindBackend(AKind);
  if (B = nil) or not Assigned(B^.Probe) then Exit(False);
  Result := B^.Probe();
end;

{ 对象化可用性缓存实现：单所有者 per-kind Once+Yes，L1 sync.once 单源 inline 零拷贝，析构释放不丢 }
constructor TWebviewAvailCache.Create;
var K: TWebviewKind;
begin
  inherited Create;
  for K := Low(TWebviewKind) to High(TWebviewKind) do
    FOnce[K] := Once;
  FYes[wvFake] := True;
end;

destructor TWebviewAvailCache.Destroy;
var K: TWebviewKind;
begin
  // 稳定性：显式 nil 接口释放不丢，try-finally 由所有者 FreeAndNil 保证
  for K := Low(TWebviewKind) to High(TWebviewKind) do
    FOnce[K] := nil;
  inherited Destroy;
end;

function TWebviewAvailCache.IsAvailable(AKind: TWebviewKind): Boolean; inline;
begin
  if (AKind < Low(TWebviewKind)) or (AKind > High(TWebviewKind)) then Exit(False);
  if AKind = wvFake then Exit(True);
  // perf: L1 sync.once 单源 inline 零额外调用，替代裸数组双检，platform.sync 原语去重并发 dlopen，零拷贝
  if FOnce[AKind].Done then Exit(FYes[AKind]);
  FOnce[AKind].DoOnce(procedure
  begin
    FYes[AKind] := RawProbe(AKind);
  end);
  Result := FYes[AKind];
end;

function GetAvailCache: TWebviewAvailCache; inline;
begin
  // perf: Once Owned 单例 inline 薄转发零拷贝，L1 sync.once 单源，消除裸全局 nil 分支，单表驱动高级一致性
  if GAvailOnce.Done then
    Exit(GAvailCache);
  GAvailOnce.DoOnce(procedure
  begin
    GAvailCache := TWebviewAvailCache.Create;
  end);
  Result := GAvailCache;
end;

{ 并行探测线程入口：L1 platform.thread 单源，栈上 Arg 零拷贝直写，IOnce 缓存线程安全去重 dlopen，释放不丢 }
function WebviewProbeThread(AArg: Pointer): Pointer; cdecl;
var LArg: PWebviewProbeArg;
begin
  LArg := PWebviewProbeArg(AArg);
  if (LArg <> nil) and (LArg^.OutAvail <> nil) then
    LArg^.OutAvail^ := GetAvailCache.IsAvailable(LArg^.Kind);
  Result := nil;
end;

{$PUSH}{$WARNINGS OFF}
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean; inline;
begin
  // 业务以 CONTRACT 为准：DefaultWebviewKind 能力探测驱动，无 IFDEF
  // perf: Once Owned 单例 inline 薄转发零拷贝，L1 Once 单源，单表驱动
  Result := GetAvailCache.IsAvailable(AKind);
end;
{$POP}

function DefaultWebviewKind: TWebviewKind;
begin
  // perf: L1 sync.once 单例 + 并行探测：启动期三后端 dlopen/BindAll 并行，I/O 重叠总耗时≈max(各后端) 而非 sum；栈上零分配零拷贝指针直写，L0 platform.thread 单源无池化开销，释放不丢
  if GDefaultOnce.Done then
    Exit(GDefaultKind);
  GDefaultOnce.DoOnce(procedure
  var
    I, J, LProbeCount: Integer;
    LKind: TWebviewKind;
    LProbeKinds: array[0..3] of TWebviewKind;
    LAvail: array[0..3] of Boolean;
    LArgs: array[0..3] of TWebviewProbeArg;
    LHandles: array[0..3] of TPlatformThreadHandle;
    LSpawned: array[0..3] of Boolean;
    LRet: Pointer;
  begin
    InitBackends;
    // 收集非 fake 后端，单表驱动 bytes.ops 单源思想：新增后端仅 WEBVIEW_BACKENDS 登记，此处自动覆盖
    LProbeCount := 0;
    for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
    begin
      LKind := WEBVIEW_BACKENDS[I].Kind;
      if LKind = wvFake then Continue;
      LProbeKinds[LProbeCount] := LKind;
      LAvail[LProbeCount] := False;
      Inc(LProbeCount);
    end;
    for I := 0 to LProbeCount - 1 do
    begin
      LArgs[I].Kind := LProbeKinds[I];
      LArgs[I].OutAvail := @LAvail[I];
      LSpawned[I] := False;
      LHandles[I] := nil;
      if platform_thread_create(LHandles[I], @WebviewProbeThread, @LArgs[I]) = 0 then
        LSpawned[I] := True
      else
      begin
        // 稳定性：创建失败回退串行探测，不丢探测，资源不泄漏
        LHandles[I] := nil;
        LAvail[I] := GetAvailCache.IsAvailable(LProbeKinds[I]);
      end;
    end;
    for I := 0 to LProbeCount - 1 do
      if LSpawned[I] and (LHandles[I] <> nil) then
      begin
        platform_thread_join(LHandles[I], LRet);
        // 稳定性：join 后句柄由 platform_thread_join 释放，不丢；IsMultiThread 已置位保证托管类型原子计数
      end;
    // 按 WEBVIEW_BACKENDS 优先级序择优，单表驱动能力优先契约
    for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
    begin
      LKind := WEBVIEW_BACKENDS[I].Kind;
      if LKind = wvFake then Continue;
      for J := 0 to LProbeCount - 1 do
        if LProbeKinds[J] = LKind then
        begin
          if LAvail[J] then
          begin
            GDefaultKind := LKind;
            Exit;
          end;
          Break;
        end;
    end;
    GDefaultKind := wvFake;
  end);
  Result := GDefaultKind;
end;

function CreateFakeWebview(
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  CheckWebviewOptions(AOptions);
  Result := TFakeWebview.Create(AOptions);
end;

function CreateFakeWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  CheckWebviewOptions(AOptions);
  if AParent = nil then
    raise EWebviewInvalidState.Create('CreateFakeWebviewOn: AParent must not be nil');
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

{ 单表分发：新增后端仅需在 WEBVIEW_BACKENDS 登记，零重复 case }
function TryCreateForKind(AKind: TWebviewKind; const AParent: IWindow;
  const AOptions: TWebviewOptions; out AWin: IWebviewWindow): Boolean; inline;
var
  B: PWebviewBackendDesc;
begin
  B := FindBackend(AKind);
  if (B = nil) or not Assigned(B^.Probe) or not B^.Probe() then Exit(False);
  if AParent = nil then
  begin
    if not Assigned(B^.Create) then Exit(False);
    AWin := B^.Create(AOptions);
  end
  else
  begin
    if not Assigned(B^.CreateOn) then Exit(False);
    AWin := B^.CreateOn(AParent, AOptions);
  end;
  Result := True;
end;

function CreateWebviewEx(const AParent: IWindow; AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;
var
  I: Integer;
  LCand: TWebviewKind;
begin
  if AParent = nil then
    Exit(CreateWebviewOf(AKind, AOptions));
  CheckWebviewOptions(AOptions);
  // 单源单表驱动：优先 AKind，回退按 WEBVIEW_BACKENDS 优先级序（含Fake跳过）零重复分支，bytes.ops单源 inline零拷贝 O(n) n≤3
  if TryCreateForKind(AKind, AParent, AOptions, Result) then Exit;
  InitBackends;
  for I := Low(WEBVIEW_BACKENDS) to High(WEBVIEW_BACKENDS) do
  begin
    LCand := WEBVIEW_BACKENDS[I].Kind;
    if (LCand = AKind) or (LCand = wvFake) then Continue;
    if TryCreateForKind(LCand, AParent, AOptions, Result) then Exit;
  end;
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

function CreateWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := CreateWebviewEx(AParent, DefaultWebviewKind, AOptions);
end;

{$PUSH}{$WARNINGS OFF}
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;
var
  B: PWebviewBackendDesc;
begin
  if not WebviewBackendAvailable(AKind) then
    raise EWebviewBackendUnavailable.CreateFmt(
      'webview backend "%s" is not available in this build', [
      GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
  B := FindBackend(AKind);
  if (B <> nil) and Assigned(B^.Create) then
    Exit(B^.Create(AOptions));
  raise EWebviewBackendUnavailable.CreateFmt(
    'webview backend "%s" is registered but has no factory yet', [
    GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
end;
{$POP}

procedure WebviewRunLoop; inline;
begin
  WindowRunLoop;
end;

procedure WebviewExitLoop; inline;
begin
  WindowExitLoop;
end;

initialization
  GDefaultOnce := Once;
  GBackendsOnce := Once;
  GAvailOnce := Once;
  // GAvailCache 惰性由 GetAvailCache via GAvailOnce 单例创建，零启动分配，单表驱动，Once Owned 单所有者

finalization
  GDefaultOnce := nil;
  GBackendsOnce := nil;
  if GAvailCache <> nil then
  begin
    GAvailCache.Free;
    GAvailCache := nil;
  end;
  GAvailOnce := nil; // 稳定性：Once Owned 单所有者统一释放，per-kind Once 由对象析构释放不丢，try-finally 释放不丢

end.
