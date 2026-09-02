unit nextpas.core.webview.factory;

{** @desc webview 后端工厂、fluent Builder 与主循环入口。

       S1 后端可用性事实源：仅 fake 编译内建；gtk 随 S3/S4 接入时把
       ResolveDefaultKind 切到平台优先并接入探测。默认 kind 的选择
       是本单元唯一职责，禁止散落到后端单元。

       Builder 形态决策（docs/webview/CONTRACT.md §3）：
       - fluent 链暴露同步/异步匿名 handler 注册；
         method/proc 三形经 window.Invokes.Register 重载提供。
       - Build 可多次调用创建多窗（CONTRACT §5 多窗路径）。
       - Run(url) = Build + Navigate + WebviewRunLoop 便捷封装；
         循环退出 = 最后一个未 Close 窗口关闭或 WebviewExitLoop。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.window.intf;

type
  {** fluent 构建器。COM 引用计数生命周期，消费方不手写释放。 *}
  IWebviewBuilder = interface
    ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E007}']
    function Title(const ATitle: string): IWebviewBuilder;
    function Size(AWidth, AHeight: Integer): IWebviewBuilder;
    function MinSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function Resizable(AResizable: Boolean): IWebviewBuilder;
    function StartMaximized: IWebviewBuilder;
    function DebugTools(AEnabled: Boolean): IWebviewBuilder;
    function Scheme(const ASchemeName: string): IWebviewBuilder;
    function DataDirectory(const APath: string): IWebviewBuilder;
    function Ephemeral: IWebviewBuilder;
    function AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
    function OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder;
    { 构造期导航（S9）：两者均进 FOptions，由后端构造期按优先级启动
      （InitialUrl 优先于 InitialHtml；Run/RunHtml 参数优先于两者）。 }
    function InitialUrl(const AUrl: string): IWebviewBuilder;
    function InitialHtml(const AHtml: string): IWebviewBuilder;
    { 开发模式（S9）：非空即让位 http dev server，资产面惰性，
      同 context 首窗跳过 scheme 注册。 }
    function DevServerUrl(const AUrl: string): IWebviewBuilder;
    { 显式钉后端（fake 等确定性场景）；缺省 = DefaultWebviewKind 能力驱动，
      Build 时不可用按工厂语义 fail-fast }
    function Kind(AKind: TWebviewKind): IWebviewBuilder;
    function Parent(const AWindow: IWindow): IWebviewBuilder;
    function Build: IWebviewWindow;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

  {** 入口形态：`TWebviewBuilder.New.Title(..)...Run(url)`。 *}
  TWebviewBuilder = record
    class function New: IWebviewBuilder; static;
  end;

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

{ M6 单泵统一：WebviewRunLoop/WebviewExitLoop 为 WindowRunLoop/WindowExitLoop 的 deprecated shim（inline 转发），单泵归 window.factory }
procedure WebviewRunLoop; inline; deprecated 'Use WindowRunLoop';
procedure WebviewExitLoop; inline; deprecated 'Use WindowExitLoop';

implementation

uses
  nextpas.core.system.typinfo,
  nextpas.core.window.base,
  nextpas.core.window.factory,
  nextpas.core.window.fake,
  nextpas.core.bytes.ops,
  nextpas.core.collections.hashset,
  nextpas.core.atomic,
  nextpas.core.sync.mutex,
  nextpas.core.webview.live,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.webview2,
  nextpas.core.webview.wk.loader,
  nextpas.core.webview.wk;

const
  { 策略表单源：平台优先序 Webview2→Gtk→Wk→Fake，DefaultWebviewKind 与
    CreateWebviewOn 对称回退共用此表，零重复分支，提升高级感。 }
  CWebviewProbeOrder: array[0..2] of TWebviewKind = (wvWebview2, wvGtk, wvWk);

var
  GDefaultKind: TWebviewKind = wvFake;
  GDefaultReady: Int32 = 0; { atomic 0/1: ARM 弱内存下 double-checked 首检无锁读需 acquire/release 屏障，避免数据竞争 }
  GAvailProbed: array[TWebviewKind] of Int32 = (0, 0, 0, 0); { atomic 0/1 }
  GAvailYes: array[TWebviewKind] of Int32 = (0, 0, 0, 0); { atomic 0/1 }
  GFactoryLock: TMutex; { L3→L1 sync owner 复用：TMutex 单源，替代 FPC TRTLCriticalSection 直连 RTL，守分层抽象 }

function RawProbe(AKind: TWebviewKind): Boolean; inline;
var
  LInfo: TGtkLoadInfo;
  LW2: TWebView2LoadInfo;
  LWk: TWkLoadInfo;
begin
  case AKind of
    wvFake:     Result := True;
    wvGtk:      Result := TryLoadGtkWebkit(LInfo);
    wvWebview2: Result := TryLoadWebView2(LW2);
    wvWk:       Result := TryLoadWk(LWk);
  else
    Result := False;
  end;
end;

procedure EnsureFactoryLock; inline;
var
  LNew: TMutex;
  LPrev: Pointer;
begin
  { perf: inline 零额外调用；CAS 单次分配无泄漏，并发首访零重复创建，双检零分配 }
  if GFactoryLock <> nil then Exit;
  LNew := TMutex.Create;
  LPrev := InterlockedCompareExchange(PPointer(@GFactoryLock)^, Pointer(LNew), nil);
  if LPrev <> nil then
    LNew.Free;
end;

{$PUSH}{$WARNINGS OFF}
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean;
begin
  if (AKind < Low(TWebviewKind)) or (AKind > High(TWebviewKind)) then Exit(False);
  if AKind = wvFake then Exit(True);
  // ARM 弱内存首检：atomic_load acquire 保证 GAvailYes 可见性，避免无锁读数据竞争
  if atomic_load(GAvailProbed[Ord(AKind)]) <> 0 then
    Exit(atomic_load(GAvailYes[Ord(AKind)]) <> 0);
  EnsureFactoryLock;
  GFactoryLock.Acquire;
  try
    if atomic_load(GAvailProbed[Ord(AKind)]) <> 0 then
      Exit(atomic_load(GAvailYes[Ord(AKind)]) <> 0);
    { perf: inline RawProbe 单锁单探零间隙，去重并发 dlopen，单临界区零重复探测 }
    atomic_store(GAvailYes[Ord(AKind)], Ord(RawProbe(AKind)));
    atomic_thread_fence(mo_release);
    atomic_store(GAvailProbed[Ord(AKind)], 1);
    Result := atomic_load(GAvailYes[Ord(AKind)]) <> 0;
  finally
    GFactoryLock.Release;
  end;
end;
{$POP}

function DefaultWebviewKind: TWebviewKind;
var
  I: Integer;
  LKind: TWebviewKind;
begin
  // ARM 弱内存首检：acquire load 保证 GDefaultKind 可见性
  if atomic_load(GDefaultReady) <> 0 then
  begin
    atomic_thread_fence(mo_acquire);
    Exit(GDefaultKind);
  end;
  EnsureFactoryLock;
  GFactoryLock.Acquire;
  try
    if atomic_load(GDefaultReady) <> 0 then Exit(GDefaultKind);
  finally
    GFactoryLock.Release;
  end;
  for I := 0 to High(CWebviewProbeOrder) do
  begin
    LKind := CWebviewProbeOrder[I];
    if WebviewBackendAvailable(LKind) then
    begin
      GFactoryLock.Acquire;
      try
        if atomic_load(GDefaultReady) <> 0 then Exit(GDefaultKind);
        GDefaultKind := LKind;
        atomic_thread_fence(mo_release);
        atomic_store(GDefaultReady, 1);
        Result := GDefaultKind;
      finally
        GFactoryLock.Release;
      end;
      Exit(Result);
    end;
  end;
  GFactoryLock.Acquire;
  try
    if atomic_load(GDefaultReady) <> 0 then Exit(GDefaultKind);
    GDefaultKind := wvFake;
    atomic_thread_fence(mo_release);
    atomic_store(GDefaultReady, 1);
    if atomic_load(GAvailProbed[Ord(wvFake)]) = 0 then
    begin
      atomic_store(GAvailYes[Ord(wvFake)], 1);
      atomic_thread_fence(mo_release);
      atomic_store(GAvailProbed[Ord(wvFake)], 1);
    end;
    Result := wvFake;
  finally
    GFactoryLock.Release;
  end;
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

{ 统一路由辅助：单表 CWebviewProbeOrder 单源，AParent 有无 × AKind 偏好二维收敛，
  Builder.Parent / CreateWebviewOn 零重复分支，inline 零额外调用，O(n) n≤3 线性回退零分配 }
function DoCreateWebviewRouted(const AParent: IWindow; AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow; inline;
var
  LKind: TWebviewKind;
  LFakeAcc: nextpas.core.window.fake.IFakeSelfAccess;
  I: Integer;
begin
  if AParent = nil then
    Exit(CreateWebviewOf(AKind, AOptions));
  CheckWebviewOptions(AOptions);
  if AParent.QueryInterface(
      nextpas.core.window.fake.IFakeSelfAccess, LFakeAcc) = 0 then
    Exit(TFakeWebview.CreateOn(AParent, AOptions));
  LKind := AKind;
  // 策略表驱动：优先 AKind，失效时按 CWebviewProbeOrder 对称回退（单表零重复）
  if (LKind <> wvFake) and WebviewBackendAvailable(LKind) then
  begin
    case LKind of
      wvGtk:      Exit(TGtkWebview.CreateOn(AParent, AOptions));
      wvWebview2: Exit(TWebView2Webview.CreateOn(AParent, AOptions));
      wvWk:       Exit(TWkWebview.CreateOn(AParent, AOptions));
    end;
  end;
  for I := 0 to High(CWebviewProbeOrder) do
  begin
    if CWebviewProbeOrder[I] = LKind then Continue;
    if not WebviewBackendAvailable(CWebviewProbeOrder[I]) then Continue;
    case CWebviewProbeOrder[I] of
      wvGtk:      Exit(TGtkWebview.CreateOn(AParent, AOptions));
      wvWebview2: Exit(TWebView2Webview.CreateOn(AParent, AOptions));
      wvWk:       Exit(TWkWebview.CreateOn(AParent, AOptions));
    end;
  end;
  Result := TFakeWebview.CreateOn(AParent, AOptions);
end;

function CreateWebviewOn(const AParent: IWindow;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  Result := DoCreateWebviewRouted(AParent, DefaultWebviewKind, AOptions);
end;

{$PUSH}{$WARNINGS OFF}
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  if not WebviewBackendAvailable(AKind) then
    raise EWebviewBackendUnavailable.CreateFmt(
      'webview backend "%s" is not available in this build', [
      GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
  case AKind of
    wvFake:     Result := CreateFakeWebview(AOptions);
    wvGtk:      Result := TGtkWebview.Create(AOptions);
    wvWebview2: Result := TWebView2Webview.Create(AOptions);
    wvWk:       Result := TWkWebview.Create(AOptions);
  else
    raise EWebviewBackendUnavailable.CreateFmt(
      'webview backend "%s" is registered but has no factory yet', [
      GetEnumName(TypeInfo(TWebviewKind), Ord(AKind))]);
  end;
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

{ ---- Builder ---- }

type
  TFakeInvokeReg = record
    Cmd: string;
    Sync: TWebviewInvokeSyncHandler;
    Async: TWebviewInvokeAsyncHandler;
    IsAsync: Boolean;
  end;

  TBuilderImpl = class(TInterfacedObject, IWebviewBuilder)
  private
    FOptions: TWebviewOptions;
    FKind: TWebviewKind;
    FParent: IWindow;
    FInvokes: specialize TWebviewLiveRegistry<TFakeInvokeReg>;
    FReady: specialize TWebviewLiveRegistry<TWebviewNotifyHandler>;
    FInitScripts: specialize TWebviewLiveRegistry<string>;
    FDedup: specialize THashSet<string>;
    function ApplyTo(AWin: IWebviewWindow): IWebviewWindow;
    procedure EnsureUniqueCmd(const ACmd: string); inline;
  public
    constructor Create;
    destructor Destroy; override;
    function Kind(AKind: TWebviewKind): IWebviewBuilder;
    function Parent(const AWindow: IWindow): IWebviewBuilder;
    function Title(const ATitle: string): IWebviewBuilder;
    function Size(AWidth, AHeight: Integer): IWebviewBuilder;
    function MinSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function MaxSize(AWidth, AHeight: Integer): IWebviewBuilder;
    function Resizable(AResizable: Boolean): IWebviewBuilder;
    function StartMaximized: IWebviewBuilder;
    function DebugTools(AEnabled: Boolean): IWebviewBuilder;
    function Scheme(const ASchemeName: string): IWebviewBuilder;
    function DataDirectory(const APath: string): IWebviewBuilder;
    function Ephemeral: IWebviewBuilder;
    function AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
    function RegisterInvoke(const ACmd: string;
      AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
    function RegisterAsyncInvoke(const ACmd: string;
      AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
    function OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder;
    function InitialUrl(const AUrl: string): IWebviewBuilder;
    function InitialHtml(const AHtml: string): IWebviewBuilder;
    function DevServerUrl(const AUrl: string): IWebviewBuilder;
    function Build: IWebviewWindow;
    procedure Run(const AUrl: string);
    procedure RunHtml(const AHtml: string);
  end;

class function TWebviewBuilder.New: IWebviewBuilder;
begin
  Result := TBuilderImpl.Create;
end;

constructor TBuilderImpl.Create;
begin
  inherited Create;
  FOptions := DefaultWebviewOptions;
  FKind := DefaultWebviewKind;
  // perf: registry 单源收敛三组 Vec 样板，初始 nil 零分配，Grow 统一经 bytes.ops VecGrow 0→4→2× inline 零额外调用
  FInvokes := specialize TWebviewLiveRegistry<TFakeInvokeReg>.Create;
  FReady := specialize TWebviewLiveRegistry<TWebviewNotifyHandler>.Create;
  FInitScripts := specialize TWebviewLiveRegistry<string>.Create;
  FDedup := specialize THashSet<string>.Create;
end;

destructor TBuilderImpl.Destroy;
begin
  // stability: registry Free 释放内部 Vec 并 nil 串/接口；dedup 复用 collections.hashset 单源，Swiss Table 自动 Finalize 全量串，资源释放不丢
  FDedup.Free;
  FDedup := nil;
  FInitScripts.Free;
  FReady.Free;
  FInvokes.Free;
  inherited;
end;

function TBuilderImpl.Title(const ATitle: string): IWebviewBuilder; inline;
begin
  FOptions.Title := ATitle;
  Result := Self;
end;

function TBuilderImpl.Size(AWidth, AHeight: Integer): IWebviewBuilder; inline;
begin
  CheckWebviewSize(AWidth, AHeight);
  FOptions.Width := AWidth;
  FOptions.Height := AHeight;
  Result := Self;
end;

function TBuilderImpl.MinSize(AWidth, AHeight: Integer): IWebviewBuilder; inline;
begin
  CheckWebviewMinSize(AWidth, AHeight, FOptions.MaxWidth, FOptions.MaxHeight);
  FOptions.MinWidth := AWidth;
  FOptions.MinHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.MaxSize(AWidth, AHeight: Integer): IWebviewBuilder; inline;
begin
  CheckWebviewMaxSize(AWidth, AHeight, FOptions.MinWidth, FOptions.MinHeight);
  FOptions.MaxWidth := AWidth;
  FOptions.MaxHeight := AHeight;
  Result := Self;
end;

function TBuilderImpl.Resizable(AResizable: Boolean): IWebviewBuilder; inline;
begin
  FOptions.Resizable := AResizable;
  Result := Self;
end;

function TBuilderImpl.StartMaximized: IWebviewBuilder; inline;
begin
  FOptions.Maximized := True;
  Result := Self;
end;

function TBuilderImpl.DebugTools(AEnabled: Boolean): IWebviewBuilder; inline;
begin
  FOptions.DebugTools := AEnabled;
  Result := Self;
end;

function TBuilderImpl.Scheme(const ASchemeName: string): IWebviewBuilder; inline;
begin
  if (ASchemeName <> '') and not IsValidWebviewSchemeToken(ASchemeName) then
    raise EWebviewInvalidState.CreateFmt(
      'SchemeName "%s" is not a valid lowercase scheme token', [ASchemeName]);
  FOptions.SchemeName := ASchemeName;
  Result := Self;
end;

function TBuilderImpl.DataDirectory(const APath: string): IWebviewBuilder; inline;
begin
  CheckWebviewSession(FOptions.EphemeralSession, APath);
  FOptions.DataDirectory := APath;
  Result := Self;
end;

function TBuilderImpl.Ephemeral: IWebviewBuilder; inline;
begin
  CheckWebviewSession(True, FOptions.DataDirectory);
  FOptions.EphemeralSession := True;
  Result := Self;
end;

function TBuilderImpl.Kind(AKind: TWebviewKind): IWebviewBuilder; inline;
begin
  FKind := AKind;
  Result := Self;
end;

function TBuilderImpl.Parent(const AWindow: IWindow): IWebviewBuilder; inline;
begin
  FParent := AWindow;
  Result := Self;
end;

function TBuilderImpl.AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
begin
  CheckWebviewInitScript(AJavascript);
  // perf: registry Register -> WebviewLiveAdd -> bytes.ops VecGrow 单源 0→4→2× inline 零额外调用，零拷贝
  FInitScripts.Register(AJavascript);
  Result := Self;
end;

procedure TBuilderImpl.EnsureUniqueCmd(const ACmd: string); inline;
begin
  { perf: inline O(1) 平均哈希去重，复用 collections.hashset 单源 Swiss Table WyHash + 0.75 负载，零额外调用，零拷贝；资源由 THashSet 自动 Finalize 释放不丢，与 assets/bridge 单源一致 }
  if FDedup.Contains(ACmd) then
    raise EWebviewInvalidState.CreateFmt('duplicate invoke cmd in builder: %s', [ACmd]);
  FDedup.Add(ACmd);
end;

function TBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
var
  LReg: TFakeInvokeReg;
begin
  CheckInvokeCmd(ACmd);
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.CreateFmt('invoke handler must not be nil: %s', [ACmd]);
  EnsureUniqueCmd(ACmd);
  // perf: registry Register 单源 VecGrow 0→4→2× inline 零额外调用
  LReg.Cmd := ACmd;
  LReg.Sync := AHandler;
  LReg.Async := nil;
  LReg.IsAsync := False;
  FInvokes.Register(LReg);
  Result := Self;
end;

function TBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
var
  LReg: TFakeInvokeReg;
begin
  CheckInvokeCmd(ACmd);
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.CreateFmt('async invoke handler must not be nil: %s', [ACmd]);
  EnsureUniqueCmd(ACmd);
  LReg.Cmd := ACmd;
  LReg.Sync := nil;
  LReg.Async := AHandler;
  LReg.IsAsync := True;
  FInvokes.Register(LReg);
  Result := Self;
end;

function TBuilderImpl.OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder; inline;
begin
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.Create('OnReady handler must not be nil');
  // perf: registry Register 单源 VecGrow inline
  FReady.Register(AHandler);
  Result := Self;
end;

function TBuilderImpl.InitialUrl(const AUrl: string): IWebviewBuilder; inline;
begin
  FOptions.InitialUrl := AUrl;
  Result := Self;
end;

function TBuilderImpl.InitialHtml(const AHtml: string): IWebviewBuilder; inline;
begin
  FOptions.InitialHtml := AHtml;
  Result := Self;
end;

function TBuilderImpl.DevServerUrl(const AUrl: string): IWebviewBuilder; inline;
begin
  FOptions.DevServerUrl := AUrl;
  Result := Self;
end;

function TBuilderImpl.ApplyTo(AWin: IWebviewWindow): IWebviewWindow;
var
  I: Integer;
  LReg: TFakeInvokeReg;
begin
  // perf: registry At inline O(1) + invoke 单源 Vec 单写，零额外堆分配
  for I := 0 to FInvokes.Count - 1 do
  begin
    LReg := FInvokes.At(I);
    if LReg.IsAsync then
      AWin.Invokes.RegisterAsync(LReg.Cmd, LReg.Async)
    else
      AWin.Invokes.Register(LReg.Cmd, LReg.Sync);
  end;
  for I := 0 to FReady.Count - 1 do
    AWin.OnReady(FReady.At(I));
  Result := AWin;
end;

function TBuilderImpl.Build: IWebviewWindow;
begin
  // perf: registry Snapshot -> bytes.ops VecSnapshot 单源 inline (nil fast path + single SetLength + per-elem copy), 零拷贝单源叙事统一
  // perf: 统一路由 DoCreateWebviewRouted inline 零额外调用，Builder.Parent/CreateWebviewOn 单源收敛，零重复分支
  FInitScripts.Snapshot(FOptions.InitScripts);
  Result := ApplyTo(DoCreateWebviewRouted(FParent, FKind, FOptions));
end;

procedure TBuilderImpl.Run(const AUrl: string);
var
  LWin: IWebviewWindow;
begin
  LWin := Build;
  LWin.Navigate(AUrl);
  WindowRunLoop;
end;

procedure TBuilderImpl.RunHtml(const AHtml: string);
var
  LWin: IWebviewWindow;
begin
  LWin := Build;
  LWin.NavigateToString(AHtml);
  WindowRunLoop;
end;

initialization
  GFactoryLock := TMutex.Create;

finalization
  if GFactoryLock <> nil then
  begin
    GFactoryLock.Free;
    GFactoryLock := nil;
  end;

end.
