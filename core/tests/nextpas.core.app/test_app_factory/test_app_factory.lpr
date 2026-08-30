program test_app_factory;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.base,
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
  end;

function THitProvider.TryResolve(const APath: string; out ABytes: TBytes; out AMimeType: string): Boolean;
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
  if not T.Run then Halt(1);
end.
