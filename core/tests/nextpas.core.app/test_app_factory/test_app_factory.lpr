program test_app_factory;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.webview.base,
  nextpas.core.webview.intf,
  nextpas.core.webview.factory,
  nextpas.core.webview.fake,
  nextpas.core.app.base,
  nextpas.core.app.intf,
  nextpas.core.app.factory;

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
  A.Close;
  Check(W.IsClosed, 'window closed via app');
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

procedure TestAppNewWindowBuilder;
var
  A: IApp;
  W2: IWebviewWindow;
begin
  A := TAppBuilder.New.Kind(wvFake).Build;
  W2 := A.NewWindowBuilder.Title('Second').Build;
  try
    Check(W2 <> nil, 'second window');
    Check(W2 <> A.MainWindow, 'distinct');
  finally
    if not W2.IsClosed then W2.Close;
    A.Close;
  end;
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
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.app.factory');
  T.Test('backend facts', @TestAppBackendFacts);
  T.Test('build and close', @TestAppBuildAndClose);
  T.Test('invoke via builder', @TestAppInvokeViaBuilder);
  T.Test('new window builder', @TestAppNewWindowBuilder);
  T.Test('options validation', @TestAppOptionsValidation);
  if not T.Run then Halt(1);
end.
