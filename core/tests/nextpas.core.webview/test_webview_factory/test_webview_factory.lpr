program test_webview_factory;
{ 工厂与 Builder 门禁：后端可用性事实（fake 恒真/其余 False）、
  不可用后端 fail-fast（ecNotFound）、选项校验接线、默认 kind 冻结、
  fluent 链全字段应用、Build 多窗、RunLoop/ExitLoop 语义、
  Emit 早于 ready 静默丢弃。heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.webview.factory;

procedure TestBackendAvailabilityFacts;
begin
  Check(WebviewBackendAvailable(wvFake), 'fake always available');
  Check(not WebviewBackendAvailable(wvGtk), 'gtk lands in S3/S4');
  Check(not WebviewBackendAvailable(wvWebview2), 'webview2 lands in W2');
  Check(not WebviewBackendAvailable(wvWk), 'wk lands in W3');
  CheckEqual(Ord(wvFake), Ord(DefaultWebviewKind));
end;

procedure TestUnavailableBackendFailsFast;
var
  LRaised: Boolean;
begin
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
  { 接口面无 Title getter（只有 Set）；构造期字段经 fake 行为面校验：
    几何直接断言，标题/可缩放等由 options→CreateFakeWebview 路径在
    fake_window gate 覆盖。此处锁 fluent 链不丢字段。 }
  W := TWebviewBuilder.New
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
    CheckEqual(1200, W.GetWidth);
    CheckEqual(800, W.GetHeight);
    Check(not W.IsClosed, 'built window is open');
  finally
    W := nil;
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
  WA := TWebviewBuilder.New.Build;
  WB := TWebviewBuilder.New.Build;
  try
    Check(WA <> WB, 'two distinct windows');
    Check(FakeLiveWindowCount >= 2, 'both tracked');
  finally
    WA := nil;
    WB := nil;
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

procedure TestRunLoopExitPaths;
var
  W: IWebviewWindow;
begin
  { 无窗口时立即返回 }
  WebviewRunLoop;

  { ExitLoop 打断泵循环 }
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.Show;
    W.Dispatcher.Post(procedure
      begin
        WebviewExitLoop;
      end);
    WebviewRunLoop;   { 泵到 ExitLoop 即返回，不会死循环 }
    Check(True, 'runloop returned via exit loop');
    W.Close;
  finally
    W := nil;
  end;

  { 全部窗口关闭后自然退出 }
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.Show;
    W.OnWindowClosed(procedure begin end);
    W.Dispatcher.Post(procedure
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
  T.Test('create validates options', @TestCreateValidatesOptions);
  T.Test('builder applies all fields', @TestBuilderAppliesAllFields);
  T.Test('builder ephemeral conflict raises at build',
    @TestBuilderEphemeralConflictRaisesAtBuild);
  T.Test('builder build twice two windows', @TestBuilderBuildTwiceTwoWindows);
  T.Test('builder invoke and ready', @TestBuilderInvokeAndReady);
  T.Test('emit dropped before ready', @TestEmitDroppedBeforeReady);
  T.Test('run loop exit paths', @TestRunLoopExitPaths);
  if not T.Run then Halt(1);
end.
