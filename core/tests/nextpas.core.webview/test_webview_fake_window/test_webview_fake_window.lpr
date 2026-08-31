program test_webview_fake_window;
{ fake 窗口状态机矩阵：可见性/几何/最大化最小化/zoom/UA/DPI、
  Close 幂等与 closed 后语义（仅 IsClosed/NativeHandle 豁免）、
  OnWindowClosed 恰好一次、live 计数联动。heaptrc 0 unfreed 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.webview.factory;

var
  GClosedEvents: Integer;
  GScaleEvents: Integer;
  GLastScale: Double;

procedure ResetCounters;
begin
  GClosedEvents := 0;
  GScaleEvents := 0;
  GLastScale := 0;
end;

procedure TestInitialState;
var
  W: IWebviewWindow;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    Check(not W.IsClosed, 'fresh window must not be closed');
    Check(not W.IsVisible, 'fresh window must be hidden');
    CheckEqual(1024, W.GetWidth);
    CheckEqual(768, W.GetHeight);
    CheckEqual(1.0, W.GetZoom);
    CheckEqual(1.0, W.GetScaleFactor);
    Check(W.NativeHandle = nil, 'fake native handle is nil (honest)');
  finally
    W := nil;
  end;
end;

procedure TestVisibilityAndGeometry;
var
  W: IWebviewWindow;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.Show;
    Check(W.IsVisible, 'show');
    W.Hide;
    Check(not W.IsVisible, 'hide');

    W.SetTitle('Hello');
    W.SetBounds(800, 600);
    CheckEqual('Hello', W.GetTitle, 'title roundtrip');
    CheckEqual(800, W.GetWidth);
    CheckEqual(600, W.GetHeight);

    { 负值夹取为 0 }
    W.SetBounds(-10, -20);
    CheckEqual(0, W.GetWidth);
    CheckEqual(0, W.GetHeight);

    W.SetResizable(False);
  finally
    W := nil;
  end;
end;

procedure TestWindowStates;
var
  W: IWebviewWindow;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.Maximize;
    Check(W.IsMaximized, 'maximize');
    W.Minimize;
    Check(W.IsMinimized, 'minimize overrides maximized in fake model');
    W.Restore;
    Check(not W.IsMinimized, 'restore clears minimized');
    Check(not W.IsMaximized, 'restore clears maximized');
    W.Maximize;
    W.Unmaximize;
    Check(not W.IsMaximized, 'unmaximize');
  finally
    W := nil;
  end;
end;

procedure TestZoomAndUserAgent;
var
  W: IWebviewWindow;
  LRaised: Boolean;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    W.SetZoom(1.5);
    CheckEqual(Double(1.5), W.GetZoom);

    LRaised := False;
    try
      W.SetZoom(0);
    except
      on E: EWebviewInvalidState do LRaised := True;
    end;
    Check(LRaised, 'zoom <= 0 must raise');

    W.SetUserAgent('nextpas-test/1.0');
    CheckEqual('nextpas-test/1.0', W.GetUserAgent);
  finally
    W := nil;
  end;
end;

procedure TestScaleChangedEvent;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  ResetCounters;
  { 类型化引用与接口引用并存：驱动面走类类型，契约面走接口。
    禁止 TFakeWebview(W) 式接口指针硬转（地址错位）。 }
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    W.OnScaleChanged(procedure(ANewScale: Double)
      begin
        GScaleEvents := GScaleEvents + 1;
        GLastScale := ANewScale;
      end);
    LFake.SetScale(2.0);
    CheckEqual(1, GScaleEvents);
    CheckEqual(Double(2.0), GLastScale);
    CheckEqual(Double(2.0), W.GetScaleFactor);
  finally
    W := nil;
  end;
end;

procedure TestCloseIdempotentAndSemantics;
var
  W: IWebviewWindow;
  LRaised: Boolean;
begin
  ResetCounters;
  W := CreateFakeWebview(DefaultWebviewOptions);
  W.Show;
  W.OnWindowClosed(procedure
    begin
      GClosedEvents := GClosedEvents + 1;
    end);

  W.Close;
  W.Close;   { 幂等：第二次不抛不重发事件 }
  Check(W.IsClosed, 'closed after Close');
  CheckEqual(1, GClosedEvents);

  { closed 后除 IsClosed/NativeHandle 外全部抛 EWebviewClosed }
  LRaised := False;
  try
    W.Show;
  except
    on E: EWebviewClosed do LRaised := True;
  end;
  Check(LRaised, 'show after close');

  LRaised := False;
  try
    W.Emit('tick', '{}');
  except
    on E: EWebviewClosed do LRaised := True;
  end;
  Check(LRaised, 'emit after close');

  LRaised := False;
  try
    W.Eval('1+1',
      procedure(const AResultJson: string) begin end,
      procedure(const AError: Exception) begin end);
  except
    on E: EWebviewClosed do LRaised := True;
  end;
  Check(LRaised, 'eval after close');

  LRaised := False;
  try
    W.Navigate('npres://app/index.html');
  except
    on E: EWebviewClosed do LRaised := True;
  end;
  Check(LRaised, 'navigate after close');

  LRaised := False;
  try
    W.SetTitle('x');
  except
    on E: EWebviewClosed do LRaised := True;
  end;
  Check(LRaised, 'set title after close');

  { 豁免面仍可用 }
  Check(W.NativeHandle = nil, 'native handle exempt from close guard');
end;

procedure TestLiveCountTracking;
var
  W: IWebviewWindow;
  LBefore: Integer;
begin
  LBefore := FakeLiveWindowCount;
  W := CreateFakeWebview(DefaultWebviewOptions);
  CheckEqual(Int64(LBefore + 1), Int64(FakeLiveWindowCount));
  W.Close;
  CheckEqual(Int64(LBefore), Int64(FakeLiveWindowCount));
end;

procedure TestNavigationHistory;
var
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  W := LFake;
  try
    Check(not W.CanGoBack, 'no history yet');
    W.Navigate('npres://app/a.html');
    W.Navigate('npres://app/b.html');
    CheckEqual(2, LFake.NavigateCount);
    Check(W.CanGoBack, 'two entries -> can go back');
    Check(not W.CanGoForward, 'at tail');
    Check(W.GoBack, 'go back');
    Check(W.CanGoForward, 'forward available after back');
    Check(not W.CanGoBack, 'at head');
    Check(not W.GoBack, 'go back at head returns false');
    Check(W.GoForward, 'go forward');
    Check(not W.GoForward, 'forward at tail returns false');

    { 新导航截断前进历史：回退后导航，前进应不可用 }
    W.GoBack;
    W.Navigate('npres://app/c.html');
    Check(not W.CanGoForward, 'new navigation truncates forward history');
  finally
    W := nil;
  end;
end;

type
  TFixedProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string;
      out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function TFixedProvider.TryResolve(const APath: string;
  out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  ABytes := nil;
  AMimeType := '';
  Result := APath = 'hit.txt';
  if Result then
  begin
    SetLength(ABytes, 2);
    ABytes[0] := Ord('o');
    ABytes[1] := Ord('k');
    AMimeType := 'text/plain';
  end;
end;

procedure TestInitialLoadOptions;
var
  LOpts: TWebviewOptions;
  W: IWebviewWindow;
  LFake: TFakeWebview;
begin
  { InitialUrl：构造即导航一次 }
  LOpts := DefaultWebviewOptions;
  LOpts.InitialUrl := 'npres://app/index.html';
  LFake := TFakeWebview.Create(LOpts);
  W := LFake;
  try
    CheckEqual(1, LFake.NavigateCount, 'initial url navigates once');
    Check(not W.CanGoBack, 'initial nav is first history entry');
  finally
    W := nil;   { 引用计数归零即析构，禁止再 Free }
  end;

  { InitialHtml 优先于 InitialUrl，且只导航一次不叠加 }
  LOpts := DefaultWebviewOptions;
  LOpts.InitialUrl := 'npres://app/index.html';
  LOpts.InitialHtml := '<html><body>npw</body></html>';
  LFake := TFakeWebview.Create(LOpts);
  try
    CheckEqual(1, LFake.NavigateCount,
      'initial html wins and never double-navigates');
  finally
    LFake.Free;
  end;

  { 都为空：不自动导航（现状语义回归钉死） }
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  try
    CheckEqual(0, LFake.NavigateCount, 'no initial load by default');
  finally
    LFake.Free;
  end;
end;

procedure TestDevServerAssetsInert;
var
  LOpts: TWebviewOptions;
  W: IWebviewWindow;
  LHit: Boolean;
  LBytes: TBytes;
  LMime: string;
begin
  { DevServerUrl 非空：挂载 no-op + 解析一律 404（§3.4 直连 http） }
  LOpts := DefaultWebviewOptions;
  LOpts.DevServerUrl := 'http://127.0.0.1:5173';
  W := CreateWebviewOf(wvFake, LOpts);
  try
    W.Assets.MountEmbedded('', TFixedProvider.Create);
    LHit := W.Assets.TryResolve('hit.txt', LBytes, LMime);
    Check(not LHit, 'dev mode resolve must be inert 404');
  finally
    W := nil;
  end;

  { 对照：非 dev 模式同一 provider 正常命中 }
  W := CreateWebviewOf(wvFake, DefaultWebviewOptions);
  try
    W.Assets.MountEmbedded('', TFixedProvider.Create);
    LHit := W.Assets.TryResolve('/hit.txt', LBytes, LMime);
    Check(LHit, 'normal mode resolves through mount');
  finally
    W := nil;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.fake.window');
  T.Test('initial state', @TestInitialState);
  T.Test('visibility and geometry', @TestVisibilityAndGeometry);
  T.Test('window states', @TestWindowStates);
  T.Test('zoom and user agent', @TestZoomAndUserAgent);
  T.Test('scale changed event', @TestScaleChangedEvent);
  T.Test('close idempotent and semantics', @TestCloseIdempotentAndSemantics);
  T.Test('live count tracking', @TestLiveCountTracking);
  T.Test('navigation history', @TestNavigationHistory);
  T.Test('initial load options', @TestInitialLoadOptions);
  T.Test('dev server assets inert', @TestDevServerAssetsInert);
  if not T.Run then Halt(1);
end.
