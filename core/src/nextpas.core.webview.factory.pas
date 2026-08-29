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
  nextpas.core.platform.thread,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake;

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

{ 按 kind 创建；不可用抛 EWebviewBackendUnavailable（消息含已探测 kind 表）}
function CreateWebviewOf(AKind: TWebviewKind;
  const AOptions: TWebviewOptions): IWebviewWindow;

{ 阻塞直到所有窗口关闭或 WebviewExitLoop；gtk 活跃窗口存在时进入
  GTK 主循环（最后窗口 destroy 触发 quit 返回），否则 fake 泵循环 }
procedure WebviewRunLoop;

{ 从任意线程请求退出 RunLoop（幂等）}
procedure WebviewExitLoop;

implementation

uses
  TypInfo,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.gtk,
  nextpas.core.webview.gtk.win,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.webview2,
  nextpas.core.webview.webview2.win,
  nextpas.core.webview.wk.loader,
  nextpas.core.webview.wk;

var
  GExitRequested: Boolean = False;

function DefaultWebviewKind: TWebviewKind;
begin
  { S18：能力驱动平台优先——wvWebview2（Windows/wine）优先于 wvGtk，
    非对应平台探测自然失败，无 IFDEF；S25 加入 wvWk（Darwin 桩）。 }
  if WebviewBackendAvailable(wvWebview2) then
    Result := wvWebview2
  else if WebviewBackendAvailable(wvGtk) then
    Result := wvGtk
  else if WebviewBackendAvailable(wvWk) then
    Result := wvWk
  else
    Result := wvFake;
end;

{$PUSH}{$WARNINGS OFF}
function WebviewBackendAvailable(AKind: TWebviewKind): Boolean;
var
  LInfo: TGtkLoadInfo;
  LW2: TWebView2LoadInfo;
  LWk: TWkLoadInfo;
begin
  case AKind of
    wvFake:      Result := True;
    wvGtk:       Result := TryLoadGtkWebkit(LInfo);   // 幂等缓存（S3 接入）
    wvWebview2:  Result := TryLoadWebView2(LW2);      // W2 探测（wine 亦经 platform.dl）
    wvWk:        Result := TryLoadWk(LWk);            // W3 桩（Darwin 预留）
  else
    Result := False;
  end;
end;
{$POP}

function CreateFakeWebview(
  const AOptions: TWebviewOptions): IWebviewWindow;
begin
  CheckWebviewOptions(AOptions);
  Result := TFakeWebview.Create(AOptions);
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

procedure WebviewRunLoop;
begin
  GExitRequested := False;
  while not GExitRequested do
  begin
    if GtkLiveWindowCount > 0 then
      WinShellRunMainLoop   { 阻塞至 gtk 侧全部关闭/退出请求 }
    else if WebView2LiveWindowCount > 0 then
      Win32ShellRunMainLoop { Win32 消息泵（wine 真窗口可交互）}
    else if WkLiveWindowCount > 0 then
      begin
        // Wk 桩：无 NSRunLoop 阻塞，短睡让出 CPU 等待 Close（Darwin 真实现接 NSApplication run）
        platform_thread_sleep_ms(10);
      end
    else if FakeLiveWindowCount > 0 then
      FakePumpAll
    else
      Break;
    if (GtkLiveWindowCount = 0) and (WebView2LiveWindowCount = 0) and (WkLiveWindowCount = 0) and (FakeLiveWindowCount = 0) then
      Break;
    platform_thread_yield;
  end;
end;

procedure WebviewExitLoop;
begin
  GExitRequested := True;
  { 阻塞式主循环期间标志位不可轮询——同步触发 quit }
  if GtkLiveWindowCount > 0 then
    WinShellQuitMainLoop;
  if WebView2LiveWindowCount > 0 then
    Win32ShellQuitMainLoop;
  // Wk 桩无需显式 quit（Darwin 真实现为 NSApplication stop），仅置标志位即可
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
    FInvokes: array of TFakeInvokeReg;
    FInvokesCount: Integer;
    FReady: array of TWebviewNotifyHandler;
    FReadyCount: Integer;
    FInitScripts: array of string;
    FInitScriptsCount: Integer;
    function ApplyTo(AWin: IWebviewWindow): IWebviewWindow;
    procedure EnsureUniqueCmd(const ACmd: string);
    procedure GrowInvokes; inline;
    procedure GrowReady; inline;
    procedure GrowInitScripts; inline;
  public
    constructor Create;
    function Kind(AKind: TWebviewKind): IWebviewBuilder;
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

procedure TBuilderImpl.GrowInitScripts; inline;
begin
  Assert(FInitScriptsCount >= 0, 'GrowInitScripts count');
  SetLength(FInitScripts, WebviewGrowCapacity(Length(FInitScripts)));
end;

function TBuilderImpl.AddInitScript(const AJavascript: string): IWebviewBuilder; inline;
begin
  CheckWebviewInitScript(AJavascript);
  if FInitScriptsCount = Length(FInitScripts) then GrowInitScripts;
  FInitScripts[FInitScriptsCount] := AJavascript;
  Inc(FInitScriptsCount);
  Result := Self;
end;

procedure TBuilderImpl.GrowInvokes; inline;
begin
  Assert(FInvokesCount >= 0, 'GrowInvokes count');
  SetLength(FInvokes, WebviewGrowCapacity(Length(FInvokes)));
end;

procedure TBuilderImpl.GrowReady; inline;
begin
  Assert(FReadyCount >= 0, 'GrowReady count');
  SetLength(FReady, WebviewGrowCapacity(Length(FReady)));
end;

procedure TBuilderImpl.EnsureUniqueCmd(const ACmd: string);
var I: Integer;
begin
  for I := 0 to FInvokesCount - 1 do
    if FInvokes[I].Cmd = ACmd then
      raise EWebviewInvalidState.CreateFmt('duplicate invoke cmd in builder: %s', [ACmd]);
end;

function TBuilderImpl.RegisterInvoke(const ACmd: string;
  AHandler: TWebviewInvokeSyncHandler): IWebviewBuilder;
begin
  CheckInvokeCmd(ACmd);
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.CreateFmt('invoke handler must not be nil: %s', [ACmd]);
  EnsureUniqueCmd(ACmd);
  if FInvokesCount = Length(FInvokes) then GrowInvokes;
  FInvokes[FInvokesCount].Cmd := ACmd;
  FInvokes[FInvokesCount].Sync := AHandler;
  FInvokes[FInvokesCount].IsAsync := False;
  Inc(FInvokesCount);
  Result := Self;
end;

function TBuilderImpl.RegisterAsyncInvoke(const ACmd: string;
  AHandler: TWebviewInvokeAsyncHandler): IWebviewBuilder;
begin
  CheckInvokeCmd(ACmd);
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.CreateFmt('async invoke handler must not be nil: %s', [ACmd]);
  EnsureUniqueCmd(ACmd);
  if FInvokesCount = Length(FInvokes) then GrowInvokes;
  FInvokes[FInvokesCount].Cmd := ACmd;
  FInvokes[FInvokesCount].Async := AHandler;
  FInvokes[FInvokesCount].IsAsync := True;
  Inc(FInvokesCount);
  Result := Self;
end;

function TBuilderImpl.OnReady(AHandler: TWebviewNotifyHandler): IWebviewBuilder; inline;
begin
  if not Assigned(AHandler) then
    raise EWebviewInvalidState.Create('OnReady handler must not be nil');
  if FReadyCount = Length(FReady) then GrowReady;
  FReady[FReadyCount] := AHandler;
  Inc(FReadyCount);
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
begin
  for I := 0 to FInvokesCount - 1 do
  begin
    if FInvokes[I].IsAsync then
      AWin.Invokes.RegisterAsync(FInvokes[I].Cmd, FInvokes[I].Async)
    else
      AWin.Invokes.Register(FInvokes[I].Cmd, FInvokes[I].Sync);
  end;
  for I := 0 to FReadyCount - 1 do
    AWin.OnReady(FReady[I]);
  Result := AWin;
end;

function TBuilderImpl.Build: IWebviewWindow;
var I: Integer;
begin
  if FInitScriptsCount > 0 then
  begin
    SetLength(FOptions.InitScripts, FInitScriptsCount);
    for I := 0 to FInitScriptsCount - 1 do
      FOptions.InitScripts[I] := FInitScripts[I];
  end
  else
    FOptions.InitScripts := nil;
  Result := ApplyTo(CreateWebviewOf(FKind, FOptions));
end;

procedure TBuilderImpl.Run(const AUrl: string);
var
  LWin: IWebviewWindow;
begin
  LWin := Build;
  LWin.Navigate(AUrl);
  WebviewRunLoop;
end;

procedure TBuilderImpl.RunHtml(const AHtml: string);
var
  LWin: IWebviewWindow;
begin
  LWin := Build;
  LWin.NavigateToString(AHtml);
  WebviewRunLoop;
end;

initialization

finalization

end.
