program test_app_factory;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.base,
  nextpas.core.text.view,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.factory,
  nextpas.core.webview.fake,
  nextpas.core.app.base,
  nextpas.core.app.intf,
  nextpas.core.app.factory;

type
  THitProvider = class(TInterfacedObject, IWebviewAssetProvider)
    function TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
    function TryResolveView(const AView: TStringView; out ABytes: TBytes; out AMimeType: string): Boolean;
  end;

function THitProvider.TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  Result := TryResolveView(TStringView.FromStr(APath), ABytes, AMimeType);
end;
function THitProvider.TryResolveView(const AView: TStringView; out ABytes: TBytes; out AMimeType: string): Boolean;
begin
  ABytes := TBytes.Create(1);
  ABytes[0] := 42;
  AMimeType := 'text/plain';
  Result := True;
end;

procedure TestAppBackendFacts;
begin
  Check(AppBackendAvailable(wvFake), 'fake available');
  CheckEqual(Ord(DefaultAppKind), Ord(nextpas.core.webview.factory.DefaultWebviewKind), 'default kind mirrors webview');
end;

procedure TestAppBuildAndClose;
var
  A: IApp;
  W: IWebviewWindow;
begin
  A := TAppBuilder.New.Kind(wvFake).Title('T').Size(800, 600).Build;
  W := A.MainWindow;
  Check(W <> nil, 'main window exists');
  Check(not W.IsClosed, 'open');
  CheckEqual(1, A.WindowCount);
  Check(not A.IsClosed, 'app not closed');
  Check(A.GetWindow(0) = W, 'GetWindow 0 is main');
  A.Close;
  Check(W.IsClosed, 'window closed via app');
  CheckEqual(0, A.WindowCount);
  Check(A.IsClosed, 'app closed');
  A.Close; // idempotent
  Check(A.IsClosed, 'second close idempotent');
end;

procedure TestAppInvokeViaBuilder;
var
  A: IApp;
  LFake: TFakeWebview;
begin
  A := TAppBuilder.New.Kind(wvFake)
    .RegisterInvoke('ping', function(const P: string): string begin Result:='"pong"'; end)
    .Build;
  LFake := TFakeWebview.FromWindow(A.MainWindow);
  LFake.SimulateBridgeReady;
  LFake.DeliverInvoke('ping', '{}');
  CheckEqual('"pong"', LFake.LastOutcome.ResultJson);
  A.Close;
end;

procedure TestAppMultiWindowAddRemove;
var
  A: IApp;
  W2, W3: IWebviewWindow;
begin
  A := TAppBuilder.New.Kind(wvFake).Build;
  CheckEqual(1, A.WindowCount, 'starts 1');
  W2 := A.NewWindowBuilder.Title('Second').Build;
  A.AddWindow(W2);
  CheckEqual(2, A.WindowCount, 'after AddWindow 2');
  Check(A.GetWindow(1) = W2, 'GetWindow 1 is W2');
  W3 := A.NewWindow.Title('Third').Build;
  A.AddWindow(W3);
  CheckEqual(3, A.WindowCount, 'after second add 3');
  // close one via window itself, app auto-removes via OnWindowClosed hook (fake fires via Close)
  W2.Close;
  CheckEqual(2, A.WindowCount, 'auto-remove after close');
  Check(not A.IsClosed, 'still has windows');
  A.Close;
  CheckEqual(0, A.WindowCount, 'all closed');
  Check(A.IsClosed, 'app closed after all');
end;

procedure TestAppMountViaBuilder;
var
  A: IApp;
  LBytes: TBytes;
  LMime: string;
begin
  A := TAppBuilder.New.Kind(wvFake)
    .MountEmbedded('', THitProvider.Create)
    .Build;
  Check(A.MainWindow.Assets.TryResolve('any.txt', LBytes, LMime), 'mount via builder hits');
  CheckEqual('text/plain', LMime);
  A.Close;
end;

procedure TestAppOptionsValidation;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TAppBuilder.New.Kind(wvFake).DataDirectory('/tmp/p').Ephemeral.Build;
  except
    on E: EWebviewInvalidState do LRaised := True;
    on E: EAppInvalidState do LRaised := True;
  end;
  Check(LRaised, 'ephemeral conflict raises');
  LRaised := False;
  try
    TAppBuilder.New.MountEmbedded('', nil).Build;
  except
    on E: EAppInvalidState do LRaised := True;
  end;
  Check(LRaised, 'nil provider raises');
  LRaised := False;
  try
    TAppBuilder.New.MountDirectory('', '').Build;
  except
    on E: EAppInvalidState do LRaised := True;
  end;
  Check(LRaised, 'empty root raises');
end;

procedure TestAppGetWindowBounds;
var
  A: IApp;
  LRaised: Boolean;
begin
  A := TAppBuilder.New.Kind(wvFake).Build;
  LRaised := False;
  try
    A.GetWindow(5);
  except
    on E: EAppInvalidState do LRaised := True;
  end;
  Check(LRaised, 'oob must raise');
  A.Close;
end;

procedure TestAppAutoRemoveWeakAndSnapshot;
var
  A: IApp;
  W2, W3: IWebviewWindow;
  Arr: TAppWindows;
begin
  A := TAppBuilder.New.Kind(wvFake).Build;
  W2 := A.NewWindowBuilder.Build; A.AddWindow(W2);
  W3 := A.NewWindowBuilder.Build; A.AddWindow(W3);
  CheckEqual(3, A.WindowCount, '3 alive');
  Arr := A.GetWindows; CheckEqual(3, Length(Arr), 'snapshot 3');
  W2.Close; // auto weak remove
  CheckEqual(2, A.WindowCount, 'after close 2');
  Arr := A.GetWindows; CheckEqual(2, Length(Arr), 'snapshot 2');
  Check(Arr[0]=A.MainWindow, 'snapshot 0 main');
  Check(Arr[1]=W3, 'snapshot 1 is W3 (W2 removed)');
  // GetWindow now compacted: index 1 should be W3 after removal
  Check(A.GetWindow(1)=W3, 'GetWindow compacted');
  A.Close;
  CheckEqual(0, A.WindowCount, 'all closed 0');
end;

procedure TestAppOnWindowClosed;
var
  A: IApp;
  W2: IWebviewWindow;
  Fired: Integer;
  LastWin: IWebviewWindow;
begin
  Fired:=0; LastWin:=nil;
  A := TAppBuilder.New.Kind(wvFake).Build;
  A.OnWindowClosed(procedure(const AW: IWebviewWindow) begin Inc(Fired); LastWin:=AW; end);
  W2 := A.NewWindowBuilder.Build; A.AddWindow(W2);
  CheckEqual(0, Fired, 'no fire yet');
  W2.Close;
  CheckEqual(1, Fired, 'fired once');
  Check(LastWin=W2, 'payload is closed window');
  // main close also fires
  A.MainWindow.Close;
  CheckEqual(2, Fired, 'second fire for main');
  CheckEqual(0, A.WindowCount, 'count 0');
end;

procedure TestAppTryGetWindow;
var
  A: IApp;
  W: IWebviewWindow;
  Ok: Boolean;
begin
  A := TAppBuilder.New.Kind(wvFake).Build;
  Ok := A.TryGetWindow(0, W);
  Check(Ok, 'TryGet 0 ok');
  Check(W = A.MainWindow, 'TryGet 0 is main');
  Ok := A.TryGetWindow(5, W);
  Check(not Ok, 'TryGet oob false');
  Check(W = nil, 'TryGet oob nil');
  A.Close;
  Ok := A.TryGetWindow(0, W);
  Check(not Ok, 'TryGet after close false');
end;

procedure TestAppNewWindowKindInherit;
var
  A: IApp;
  W2: IWebviewWindow;
  LFake: TFakeWebview;
begin
  A := TAppBuilder.New.Kind(wvFake).Build;
  W2 := A.NewWindowBuilder.Build;
  // inherit wvFake, so FromWindow should succeed (fake)
  LFake := TFakeWebview.FromWindow(W2);
  Check(LFake <> nil, 'inherited kind is fake');
  A.AddWindow(W2);
  CheckEqual(2, A.WindowCount);
  W2.Close;
  CheckEqual(1, A.WindowCount);
  A.Close;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.app.factory');
  T.Test('backend facts', @TestAppBackendFacts);
  T.Test('build and close', @TestAppBuildAndClose);
  T.Test('invoke via builder', @TestAppInvokeViaBuilder);
  T.Test('multi window add/remove', @TestAppMultiWindowAddRemove);
  T.Test('mount via builder', @TestAppMountViaBuilder);
  T.Test('options validation', @TestAppOptionsValidation);
  T.Test('getwindow bounds', @TestAppGetWindowBounds);
  T.Test('auto remove weak and snapshot', @TestAppAutoRemoveWeakAndSnapshot);
  T.Test('app onwindowclosed', @TestAppOnWindowClosed);
  T.Test('trygetwindow', @TestAppTryGetWindow);
  T.Test('new window kind inherit', @TestAppNewWindowKindInherit);
  if not T.Run then Halt(1);
end.
