program test_webview_factory;
{ 工厂与 Builder 门禁：后端可用性事实（探测驱动）、不可用后端
  fail-fast（ecNotFound）、选项校验接线、缺省 kind 能力驱动冒烟、
  fluent 链全字段应用（Kind(wvFake) 钉确定性语义）、Build 多窗、
  RunLoop/ExitLoop 语义、Emit 早于 ready 静默丢弃。
  builder/工厂出窗一律显式 Close 收口——活跃窗泄漏会令
  WebviewRunLoop 进入 gtk_main 死等（S4 实锤坑）。heaptrc 0 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.webview.gtk.loader,
  nextpas.core.webview.webview2.loader,
  nextpas.core.webview.factory,
  nextpas.core.window.base;

type
  { 总命中 provider：用于验开发模式惰性覆盖——正常模式会命中，
    dev 模式必须仍 404 }
  TAlwaysHitProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TAlwaysHitProvider.TryResolve(const APath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  ABytes := TBytes.Create(1);
  ABytes[0] := 42;
  AMimeType := 'text/plain';
  Result := True;
end;

function GtkProbeUsable: Boolean;
var
  LInfo: TGtkLoadInfo;
begin
  Result := TryLoadGtkWebkit(LInfo);
end;

function Wv2ProbeUsable: Boolean;
var
  LInfo: TWebView2LoadInfo;
begin
  Result := TryLoadWebView2(LInfo);
end;

procedure TestBackendAvailabilityFacts;
begin
  Check(WebviewBackendAvailable(wvFake), 'fake always available');
  { S3 起 gtk 按探测结果可用（幂等缓存）；与 loader 直探保持一致 }
  CheckEqual(GtkProbeUsable(), WebviewBackendAvailable(wvGtk),
    'gtk availability matches loader probe');
  CheckEqual(Wv2ProbeUsable(), WebviewBackendAvailable(wvWebview2),
    'webview2 availability matches loader probe');
  Check(not WebviewBackendAvailable(wvWk), 'wk lands in W3');
  { S18：默认 kind 能力驱动——wvWebview2 优先于 wvGtk，否则回落 wvFake }
  if Wv2ProbeUsable() then
    CheckEqual(Ord(wvWebview2), Ord(DefaultWebviewKind), 'default = webview2 when probed')
  else if GtkProbeUsable() then
    CheckEqual(Ord(wvGtk), Ord(DefaultWebviewKind), 'default = gtk when probed')
  else
    CheckEqual(Ord(wvFake), Ord(DefaultWebviewKind), 'default falls back to fake');
end;

procedure TestUnavailableBackendFailsFast;
var
  LRaised: Boolean;
  LQuick: IWebviewWindow;
begin
  if GtkProbeUsable() then
  begin
    { 可用环境：构造+立即 Close，验证工厂路径本身（不留活跃窗口——
      泄漏会让 RunLoop 进入真实 gtk_main 死等，S3 曾实锤此坑） }
    LQuick := CreateWebviewOf(wvGtk, DefaultWebviewOptions);
    try
      LQuick.Close;
    finally
      LQuick := nil;
    end;
    Check(True, '');
    Exit;
  end;
  LRaised := False;
  try
    CreateWebviewOf(wvGtk, DefaultWebviewOptions);
  except
    on E: EWebviewBackendUnavailable do
    begin
      LRaised := True;
      CheckEqual(Ord(ecNotFound), Ord(E.Category));
    end;
  end;
  Check(LRaised, 'unavailable backend must fail fast');
end;

procedure TestCreateValidatesOptions;
var
  LOptions: TWebviewOptions;
  LRaised: Boolean;
begin
  LOptions := DefaultWebviewOptions;
  LOptions.EphemeralSession := True;
  LOptions.DataDirectory := '/tmp/x';
  LRaised := False;
  try
    CreateFakeWebview(LOptions);
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'create must validate options');
end;

procedure TestBuilderAppliesAllFields;
var
  W: IWebviewWindow;
begin
  { 构造期字段经 fake 行为面校验：几何与标题直接断言，可缩放等由
    options→CreateFakeWebview 路径在
    fake_window gate 覆盖。Kind(wvFake) 钉确定性后端——缺省 kind 在
    探测到 WebKitGTK 的机器上是 wvGtk，几何断言只对 fake 语义成立。
    此处锁 fluent 链不丢字段。 }
  W := TWebviewBuilder.New
    .Kind(wvFake)
    .Title('Factory')
    .Size(1200, 800)
    .MinSize(400, 300)
    .MaxSize(2000, 1500)
    .Resizable(False)
    .DebugTools(True)
    .Scheme('appres')
    .AddInitScript('window.__booted = true;')
    .Build;
  try
    CheckEqual(1200, W.Window.GetWidth);
    CheckEqual(800, W.Window.GetHeight);
    CheckEqual('Factory', W.Window.GetTitle, 'builder applies title');
    Check(not W.IsClosed, 'built window is open');
  finally
    if (W <> nil) and not W.IsClosed then
      W.Close;
  end;
end;

procedure TestBuilderEphemeralConflictRaisesAtBuild;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TWebviewBuilder.New
      .DataDirectory('/tmp/profile')
      .Ephemeral
      .Build;
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'build must surface option conflicts');
end;

procedure TestBuilderBuildTwiceTwoWindows;
var
  WA, WB: IWebviewWindow;
begin
  WA := TWebviewBuilder.New.Kind(wvFake).Build;
  WB := TWebviewBuilder.New.Kind(wvFake).Build;
  try
    Check(WA <> WB, 'two distinct windows');
    Check(FakeLiveWindowCount >= 2, 'both tracked');
  finally
    { 显式收口：gtk 等真后端接口引用释放不等于窗口关闭 }
    if (WA <> nil) and not WA.IsClosed then WA.Close;
    if (WB <> nil) and not WB.IsClosed then WB.Close;
  end;
end;

procedure TestBuilderInvokeAndReady;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
  LReadies: Integer;
begin
  LReadies := 0;
  W := TWebviewBuilder.New
    .Kind(wvFake)
    .RegisterInvoke('ping',
      function(const APayloadJson: string): string
      begin
        Result := '"pong"';
      end)
    .OnReady(procedure
      begin
        LReadies := LReadies + 1;
      end)
    .Build;
  LFake := TFakeWebview.FromWindow(W);
  try
    CheckEqual(0, LReadies, 'no ready before navigation');
    W.Navigate('npres://app/index.html');
    CheckEqual(1, LReadies, 'ready fires once per navigation');
    LFake.DeliverInvoke('ping', '{}');
    CheckEqual('"pong"', LFake.LastOutcome.ResultJson);
    W.Navigate('npres://app/second.html');
    CheckEqual(2, LReadies, 'ready per navigation');
  finally
    if not W.IsClosed then
      W.Close;
    W := nil;
  end;
end;

procedure TestEmitDroppedBeforeReady;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.Emit('tick', '{"n":1}');
    CheckEqual(0, LFake.EmitCount, 'dropped before ready');
    CheckEqual(1, LFake.DroppedEmitCount, 'drop counted');

    LFake.SimulateBridgeReady;
    W.Emit('tick', '{"n":2}');
    CheckEqual(1, LFake.EmitCount, 'delivered after ready');
    CheckEqual('tick', LFake.LastEmitEvent);
    CheckEqual('{"n":2}', LFake.LastEmitPayloadJson);
  finally
    W := nil;
  end;
end;

procedure TestBuilderInitialNavigation;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  { InitialUrl 构造期导航：Build 时即完成一次 Navigate（fake 计次 1） }
  W := TWebviewBuilder.New
    .Kind(wvFake)
    .InitialUrl('npres://app/initial.html')
    .Build;
  LFake := TFakeWebview.FromWindow(W);
  try
    CheckEqual(1, LFake.NavigateCount, 'initial url triggers one navigate on create');
    Check(W.CanGoBack = False, 'initial nav history at start');
    { 再次显式导航应累积 }
    W.Navigate('npres://app/second.html');
    CheckEqual(2, LFake.NavigateCount, 'second navigate increments');
    Check(W.CanGoBack, 'history after second nav');
  finally
    if not W.IsClosed then W.Close;
    W := nil;
  end;

  { CONTRACT §2.2：InitialUrl 优先级高于 InitialHtml——两者同设时
    以 Url 为准（与 gtk/fake 实现一致）。 }
  W := TWebviewBuilder.New
    .Kind(wvFake)
    .InitialUrl('npres://app/should-win.html')
    .InitialHtml('<html>hello</html>')
    .Build;
  LFake := TFakeWebview.FromWindow(W);
  try
    CheckEqual(1, LFake.NavigateCount, 'initial url wins over html');
  finally
    if not W.IsClosed then W.Close;
    W := nil;
  end;

  W := TWebviewBuilder.New
    .Kind(wvFake)
    .InitialHtml('<html>only-html</html>')
    .Build;
  LFake := TFakeWebview.FromWindow(W);
  try
    CheckEqual(1, LFake.NavigateCount, 'initial html alone triggers navigate');
  finally
    if not W.IsClosed then W.Close;
    W := nil;
  end;
end;

procedure TestBuilderDevServerInert;
var
  W: IWebviewWindow;
  LBytes: TBytes;
  LMime: string;
begin
  { DevServerUrl 开发模式：资产面惰性——挂载 no-op、解析一律 404 }
  W := TWebviewBuilder.New
    .Kind(wvFake)
    .DevServerUrl('http://127.0.0.1:5173')
    .Build;
  try
    W.Assets.MountEmbedded('', TAlwaysHitProvider.Create);
    Check(not W.Assets.TryResolve('hello.txt', LBytes, LMime),
      'dev mode resolve must be inert 404');
    Check(not W.Assets.TryResolve('app/hello.txt', LBytes, LMime),
      'dev mode any path is inert');
  finally
    if not W.IsClosed then W.Close;
    W := nil;
  end;
end;

procedure TestDefaultKindFollowsProbe;
var
  W: IWebviewWindow;
  LIsFake: Boolean;
begin
  { S4：缺省 kind 能力驱动——探测到 WebKitGTK 即真后端，否则回落 fake。
    FromWindow 只认 fake 实例，其异常与否即判别器。出窗必须显式收口：
    真后端窗口泄漏会让末尾 RunLoop 用例进入 gtk_main 死等 }
  W := TWebviewBuilder.New.Build;
  try
    LIsFake := False;
    try
      TFakeWebview.FromWindow(W);
      LIsFake := True;
    except
      on E: EWebviewInvalidState do ;
    end;
    if GtkProbeUsable() then
      Check(not LIsFake, 'probed env builds real backend by default')
    else
      Check(LIsFake, 'unprobed env falls back to fake');
    Check(not W.IsClosed, 'default-built window is open');
  finally
    if (W <> nil) and not W.IsClosed then
      W.Close;
  end;
end;

procedure TestBuilderDuplicateAndNilGuards;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TWebviewBuilder.New
      .Kind(wvFake)
      .RegisterInvoke('dup.cmd', function(const APayloadJson: string): string begin Result:='{}'; end)
      .RegisterInvoke('dup.cmd', function(const APayloadJson: string): string begin Result:='{}'; end)
      .Build;
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'duplicate cmd in builder must raise');

  LRaised := False;
  try
    TWebviewBuilder.New.Kind(wvFake).RegisterInvoke('ok.cmd', TWebviewInvokeSyncHandler(nil)).Build;
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'nil sync handler must raise');

  LRaised := False;
  try
    TWebviewBuilder.New.Kind(wvFake).OnReady(TWebviewNotifyHandler(nil)).Build;
  except
    on E: EWebviewInvalidState do LRaised := True;
  end;
  Check(LRaised, 'nil OnReady must raise');
end;

procedure TestRunLoopExitPaths;
var
  W: IWebviewWindow;
begin
  { 无窗口时立即返回 — 单泵已归 window.factory，WebviewRunLoop 为 deprecated shim 透传 WindowRunLoop }
  WebviewRunLoop;

  { ExitLoop 打断泵循环 — Dispatcher 已复用 IWindow.Dispatcher 单队列 }
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.Window.Show;
    W.Window.Dispatcher.Post(procedure
      begin
        WebviewExitLoop;
      end);
    WebviewRunLoop;   { 泵到 ExitLoop 即返回，不会死循环 }
    Check(True, 'runloop returned via exit loop');
    W.Close;
  finally
    W := nil;
  end;

  { 全部窗口关闭后自然退出 — 窗口事件已收敛至 Window.OnEvent(weClosed) }
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.Window.Show;
    W.Window.OnEvent(procedure(const AEvent: TWindowEvent) begin end);
    W.Window.Dispatcher.Post(procedure
      begin
        { 模拟用户关窗动作发生在泵内 }
      end);
    W.Close;
    WebviewRunLoop;   { 无未关闭窗口 → 立即返回 }
    Check(True, 'runloop returned after windows closed');
  finally
    W := nil;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.factory');
  T.Test('backend availability facts', @TestBackendAvailabilityFacts);
  T.Test('unavailable backend fails fast', @TestUnavailableBackendFailsFast);
  T.Test('default kind follows probe', @TestDefaultKindFollowsProbe);
  T.Test('create validates options', @TestCreateValidatesOptions);
  T.Test('builder applies all fields', @TestBuilderAppliesAllFields);
  T.Test('builder ephemeral conflict raises at build',
    @TestBuilderEphemeralConflictRaisesAtBuild);
  T.Test('builder build twice two windows', @TestBuilderBuildTwiceTwoWindows);
  T.Test('builder invoke and ready', @TestBuilderInvokeAndReady);
  T.Test('emit dropped before ready', @TestEmitDroppedBeforeReady);
  T.Test('builder initial navigation', @TestBuilderInitialNavigation);
  T.Test('builder dev server inert', @TestBuilderDevServerInert);
  T.Test('builder duplicate and nil guards', @TestBuilderDuplicateAndNilGuards);
  T.Test('run loop exit paths', @TestRunLoopExitPaths);
  if not T.Run then Halt(1);
end.
