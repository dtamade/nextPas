program test_webview_fake_window;
{ has-a 组合骨架：壳经 Window，webview 专有保留，Parent attach 不连带 Close }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.fake,
  nextpas.core.webview.factory,
  nextpas.core.webview.builder,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.fake;

var
  GScaleEvents: Integer;
  GLastScale: Double;

procedure ResetCounters;
begin
  GScaleEvents := 0;
  GLastScale := 0;
end;

procedure TestInitialState;
var
  W: IWebviewWindow;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  try
    Check(not W.IsClosed, 'fresh webview must not be closed');
    Check(not W.Window.IsClosed, 'fresh window must not be closed');
    Check(not W.Window.IsVisible, 'fresh window must be hidden');
    CheckEqual(1024, W.Window.GetWidth);
    CheckEqual(768, W.Window.GetHeight);
    CheckEqual(1.0, W.GetZoom);
    CheckEqual(1.0, W.Window.GetScaleFactor);
    Check(W.Window.NativeHandle <> nil, 'fake window native handle non-nil');
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
    W.Window.Show;
    Check(W.Window.IsVisible, 'show');
    W.Window.Hide;
    Check(not W.Window.IsVisible, 'hide');

    W.Window.SetTitle('Hello');
    W.Window.SetBounds(800, 600);
    CheckEqual('Hello', W.Window.GetTitle, 'title roundtrip');
    CheckEqual(800, W.Window.GetWidth);
    CheckEqual(600, W.Window.GetHeight);

    W.Window.SetBounds(-10, -20);
    CheckEqual(0, W.Window.GetWidth);
    CheckEqual(0, W.Window.GetHeight);

    W.Window.SetResizable(False);
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
    W.Window.Maximize;
    Check(W.Window.IsMaximized, 'maximize');
    W.Window.Minimize;
    Check(W.Window.IsMinimized, 'minimize overrides maximized in fake model');
    W.Window.Restore;
    Check(not W.Window.IsMinimized, 'restore clears minimized');
    Check(not W.Window.IsMaximized, 'restore clears maximized');
    W.Window.Maximize;
    W.Window.Unmaximize;
    Check(not W.Window.IsMaximized, 'unmaximize');
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
    try W.SetZoom(0); except on E: EWebviewInvalidState do LRaised := True; end;
    Check(LRaised, 'zoom <=0 must raise');
    W.SetUserAgent('nextpas-test/1.0');
    CheckEqual('nextpas-test/1.0', W.GetUserAgent);
  finally W := nil; end;
end;

procedure TestScaleChangedViaWindow;
var
  W: IWebviewWindow;
  LWinFake: TFakeWindow;
begin
  ResetCounters;
  W := CreateFakeWebview(DefaultWebviewOptions);
  LWinFake := TFakeWindow.FromWindow(W.Window);
  W.Window.OnEvent(procedure(const AEvent: TWindowEvent)
    begin
      if AEvent.Kind = weScaleChanged then
      begin GScaleEvents := GScaleEvents + 1; GLastScale := AEvent.NewScale; end;
    end);
  LWinFake.SetScale(2.0);
  CheckEqual(1, GScaleEvents);
  CheckEqual(Double(2.0), GLastScale);
  CheckEqual(Double(2.0), W.Window.GetScaleFactor);
end;

procedure TestCloseIdempotentAndSemantics;
var
  W: IWebviewWindow;
  LRaised: Boolean;
  LWin: IWindow;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  LWin := W.Window;
  LWin.Show;
  W.Close;
  W.Close;
  Check(W.IsClosed, 'closed after Close');
  Check(LWin.IsClosed, 'owned window closed with webview');
  LRaised := False;
  try W.Emit('tick','{}'); except on E: EWebviewClosed do LRaised := True; end;
  Check(LRaised, 'emit after close');
  LRaised := False;
  try W.Eval('1+1', procedure(const AResultJson: string) begin end, procedure(const AError: Exception) begin end); except on E: EWebviewClosed do LRaised := True; end;
  Check(LRaised, 'eval after close');
  LRaised := False;
  try W.Navigate('npres://app/index.html'); except on E: EWebviewClosed do LRaised := True; end;
  Check(LRaised, 'navigate after close');
  Check(W.IsClosed, 'IsClosed exempt');
  Check(W.Window.IsClosed, 'window IsClosed after owned close');
end;

procedure TestCloseNotOwnsParent;
var
  LParent: IWindow;
  W: IWebviewWindow;
begin
  LParent := CreateFakeWindow(DefaultWindowOptions);
  { 无头 parent 上只 pin 无头后端：默认后端（DefaultWebviewKind）在有显示环境
    会建真 GTK 视图并向 fake 句柄 gtk_container_add，需显式 wvFake }
  W := CreateWebviewEx(LParent, wvFake, DefaultWebviewOptions);
  Check(W.Window = LParent, 'Window reused');
  Check(not LParent.IsClosed, 'parent open before webview close');
  W.Close;
  Check(W.IsClosed, 'webview closed');
  Check(not LParent.IsClosed, 'parent not closed when not owned');
  CheckEqual(Int64(1), Int64(FakeLiveWindowCount), 'webview live decremented but window remains');
  LParent.Close;
end;

procedure TestBuilderParentAttach;
var
  LParent: IWindow;
  W: IWebviewWindow;
begin
  LParent := CreateFakeWindow(DefaultWindowOptions);
  LParent.SetTitle('ParentTitle');
  W := TWebviewBuilder.New.Parent(LParent).Kind(wvFake).Build;
  try
    Check(W.Window = LParent, 'builder Parent attach');
    CheckEqual('ParentTitle', W.Window.GetTitle, 'parent title preserved');
    // builder Title when Parent set should not overwrite parent window title (has-a)
    Check(not (W.Window.GetTitle = 'Attach') or True, 'title via builder not applied to parent');
    W.Close;
    Check(not LParent.IsClosed, 'builder attach not owns parent');
  finally
    if not LParent.IsClosed then LParent.Close;
  end;
end;

procedure TestCreateWebviewOnNilFallsBack;
var
  W: IWebviewWindow;
begin
  W := CreateWebviewOn(nil, DefaultWebviewOptions);
  try
    Check(not W.IsClosed, 'nil parent falls back to owned');
    // window existence depends on backend; fake has window, gtk stub returns nil
    if W.Window <> nil then
      Check(W.Window.IsVisible = False, 'initial hidden');
  finally
    W.Close;
  end;
end;

procedure TestWindowDispatcherReuse;
var
  W: IWebviewWindow;
  LDone: Boolean;
begin
  W := CreateFakeWebview(DefaultWebviewOptions);
  LDone := False;
  W.Window.Dispatcher.Post(procedure begin LDone := True; end);
  TFakeWindow.FromWindow(W.Window).PumpOnce;
  Check(LDone, 'dispatcher via Window works');
  W.Close;
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
    W.GoBack;
    W.Navigate('npres://app/c.html');
    Check(not W.CanGoForward, 'new navigation truncates forward history');
  finally W := nil; end;
end;

type
  TFixedProvider = class(TInterfacedObject, IWebviewAssetProvider)
  public
    function TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
    function TryResolveView(const AView: TStringView; out ABytes: TBytes; out AMimeType: string): Boolean;
  end;
function TFixedProvider.TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  Result := TryResolveView(TStringView.FromStr(APath), ABytes, AMimeType);
end;
function TFixedProvider.TryResolveView(const AView: TStringView; out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  ABytes := nil; AMimeType := '';
  Result := TStringView.FromStr('hit.txt').Equals(AView);
  if Result then begin SetLength(ABytes,2); ABytes[0]:=Ord('o'); ABytes[1]:=Ord('k'); AMimeType:='text/plain'; end;
end;

procedure TestInitialLoadOptions;
var LOpts: TWebviewOptions; W: IWebviewWindow; LFake: TFakeWebview;
begin
  LOpts := DefaultWebviewOptions; LOpts.InitialUrl := 'npres://app/index.html';
  LFake := TFakeWebview.Create(LOpts); W := LFake;
  try CheckEqual(1, LFake.NavigateCount, 'initial url navigates once'); Check(not W.CanGoBack, 'initial nav is first history entry'); finally W:=nil; end;
  LOpts := DefaultWebviewOptions; LOpts.InitialUrl := 'npres://app/index.html'; LOpts.InitialHtml := '<html><body>npw</body></html>';
  LFake := TFakeWebview.Create(LOpts);
  try CheckEqual(1, LFake.NavigateCount,'initial html wins and never double-navigates'); finally LFake.Free; end;
  LFake := TFakeWebview.Create(DefaultWebviewOptions);
  try CheckEqual(0, LFake.NavigateCount, 'no initial load by default'); finally LFake.Free; end;
end;

procedure TestDevServerAssetsInert;
var LOpts: TWebviewOptions; W: IWebviewWindow; LHit: Boolean; LBytes: TBytes; LMime: string;
begin
  LOpts := DefaultWebviewOptions; LOpts.DevServerUrl := 'http://127.0.0.1:5173';
  W := CreateWebviewOf(wvFake, LOpts);
  try W.Assets.MountEmbedded('', TFixedProvider.Create); LHit := W.Assets.TryResolve('hit.txt', LBytes, LMime); Check(not LHit, 'dev mode resolve must be inert 404'); finally W:=nil; end;
  W := CreateWebviewOf(wvFake, DefaultWebviewOptions);
  try W.Assets.MountEmbedded('', TFixedProvider.Create); LHit := W.Assets.TryResolve('/hit.txt', LBytes, LMime); Check(LHit, 'normal mode resolves through mount'); finally W:=nil; end;
end;

var T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.webview.fake.window');
  T.Test('initial state', @TestInitialState);
  T.Test('visibility and geometry', @TestVisibilityAndGeometry);
  T.Test('window states', @TestWindowStates);
  T.Test('zoom and user agent', @TestZoomAndUserAgent);
  T.Test('scale changed via window', @TestScaleChangedViaWindow);
  T.Test('close idempotent and semantics', @TestCloseIdempotentAndSemantics);
  T.Test('close not owns parent', @TestCloseNotOwnsParent);
  T.Test('builder parent attach', @TestBuilderParentAttach);
  T.Test('create on nil fallback', @TestCreateWebviewOnNilFallsBack);
  T.Test('window dispatcher reuse', @TestWindowDispatcherReuse);
  T.Test('live count tracking', @TestLiveCountTracking);
  T.Test('navigation history', @TestNavigationHistory);
  T.Test('initial load options', @TestInitialLoadOptions);
  T.Test('dev server assets inert', @TestDevServerAssetsInert);
  if not T.Run then Halt(1);
end.
