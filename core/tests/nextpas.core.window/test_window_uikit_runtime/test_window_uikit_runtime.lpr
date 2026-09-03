program test_window_uikit_runtime;
{ UIKit runtime smoke: 探测式；非 iOS 时 SKIP，REQUIRED 时强制失败。 heaptrc 0。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.uikit, nextpas.core.exception, nextpas.core.os.env;

procedure Skip(const AMsg: string);
begin
  WriteLn('SKIP: ', AMsg);
  if GetEnvironmentVariable('NEXTPAS_WINDOW_UIKIT_REQUIRED')='1' then
    raise Exception.Create('REQUIRED but skipped: '+AMsg);
end;

procedure TestProbe;
begin
  if not WindowUIKitIsAvailable then
  begin
    Skip('UIKit not available (not iOS host or libUIKit missing)');
    Exit;
  end;
  Check(True, 'uikit probed available');
end;

procedure TestAttachRequiresParent;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  LOptions.ParentHandle := nil;
  if not WindowUIKitIsAvailable then
  begin
    try
      CreateWindowOf(wkUIKit, LOptions);
      Check(False, 'uikit unavailable should fail fast');
    except
      on E: EWindowBackendUnavailable do Check(True, 'uikit unavailable honest');
      on E: EWindowUnsupported do Check(False, 'should be BackendUnavailable not Unsupported when unavailable');
    end;
    Exit;
  end;
  try
    CreateWindowOf(wkUIKit, LOptions);
    Check(False, 'uikit without ParentHandle must raise Unsupported');
  except
    on E: EWindowUnsupported do Check(True, 'uikit requires ParentHandle');
    on E: Exception do Check(False, 'wrong exception: '+E.ClassName);
  end;
end;

procedure TestSmoke;
var
  W: IWindow;
  LDummy: Pointer;
begin
  if not WindowUIKitIsAvailable then
  begin
    Skip('skip smoke - no uikit');
    Exit;
  end;
  LDummy := Pointer($BEEF0001);
  try
    W := TWindowBuilder.New.Kind(wkUIKit).Parent(TWindowNativeHandle(LDummy)).Build;
  except
    on E: Exception do
    begin
      Skip('uikit create failed: '+E.Message);
      Exit;
    end;
  end;
  try
    Check(not W.IsClosed, 'uikit window open');
    Check(W.NativeHandle = TWindowNativeHandle(LDummy), 'native handle equals UIWindow*');
    W.SetTitle('uikit-smoke');
    CheckEqual('uikit-smoke', W.GetTitle);
    W.SetBounds(999, 999);
    Check(W.GetWidth = DefaultWindowOptions.Size.Width, 'width read-only after SetBounds');
    W.Show; Check(W.IsVisible, 'visible after Show');
    W.Hide; Check(not W.IsVisible, 'hidden after Hide');
    W.GetDispatcher.Post(procedure begin end);
    Check(True, 'dispatcher post ok');
    W.Close; Check(W.IsClosed, 'closed'); Check(W.NativeHandle=nil, 'handle nil after close');
    W.Close; Check(True, 'close idempotent');
  finally
    if (W<>nil) and not W.IsClosed then W.Close;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.uikit_runtime');
  T.Test('probe', @TestProbe);
  T.Test('attach requires parent', @TestAttachRequiresParent);
  T.Test('smoke', @TestSmoke);
  if not T.Run then Halt(1);
  WriteLn('uikit-runtime: done');
end.
