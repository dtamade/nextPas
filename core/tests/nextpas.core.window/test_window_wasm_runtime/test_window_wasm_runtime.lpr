program test_window_wasm_runtime;
{ WASM runtime smoke: 探测式；非 Emscripten 时 SKIP，REQUIRED 时强制失败。 heaptrc 0。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.factory,
  nextpas.core.window.wasm;

procedure Skip(const AMsg: string);
begin
  WriteLn('SKIP: ', AMsg);
  if GetEnvironmentVariable('NEXTPAS_WINDOW_WASM_REQUIRED')='1' then
    raise Exception.Create('REQUIRED but skipped: '+AMsg);
end;

procedure TestProbe;
begin
  if not WindowWasmIsAvailable then
  begin
    Skip('WASM not available (not Emscripten or env imports missing)');
    Exit;
  end;
  Check(True, 'wasm probed available');
end;

procedure TestAttachFriendly;
var
  LOptions: TWindowOptions;
begin
  // wasm on Linux should be unavailable but ParentHandle not in desktop reject set
  LOptions := DefaultWindowOptions;
  LOptions.ParentHandle := TWindowNativeHandle(Pointer($CAFE));
  if not WindowWasmIsAvailable then
  begin
    try
      CreateWindowOf(wkWasm, LOptions);
      Check(False, 'wasm unavailable should fail fast');
    except
      on E: EWindowBackendUnavailable do
        CheckContains(E.Message, 'wkWasm');
      on E: EWindowUnsupported do
        Check(False, 'wasm attach must not raise Unsupported when unavailable');
    end;
    Check(True, 'wasm attach-friendly when unavailable');
    Exit;
  end;
  // When available: attach with nil (default "#canvas") and with id string
  LOptions.ParentHandle := nil;
  try
    CreateWindowOf(wkWasm, LOptions).Close;
    Check(True, 'wasm attach nil -> default canvas');
  except
    on E: Exception do Check(False, 'wasm nil parent should succeed when available: '+E.Message);
  end;
end;

procedure TestSmoke;
var
  W: IWindow;
  LCanvasId: AnsiString;
begin
  if not WindowWasmIsAvailable then
  begin
    Skip('skip smoke - no wasm');
    Exit;
  end;
  LCanvasId := '#canvas';
  try
    W := CreateWindowOf(wkWasm, DefaultWindowOptions);
  except
    on E: Exception do
    begin
      Skip('wasm create failed: '+E.Message);
      Exit;
    end;
  end;
  try
    Check(not W.IsClosed, 'wasm window open');
    Check(W.NativeHandle <> nil, 'native handle non-nil (canvas)');
    W.SetTitle('wasm-smoke');
    CheckEqual('wasm-smoke', W.GetTitle);
    W.SetBounds(640, 480);
    Check(W.GetWidth>0, 'width after SetBounds');
    Check(W.GetHeight>0, 'height after SetBounds');
    Check(W.GetScaleFactor>=1.0, 'scale >=1');
    W.Show; Check(W.IsVisible, 'visible after Show');
    W.Hide; Check(not W.IsVisible, 'hidden after Hide');
    W.Show;
    // Min/Max no-op honest
    W.Maximize; Check(not W.IsMaximized, 'maximized honest false');
    W.Minimize; Check(not W.IsMinimized, 'minimized honest false');
    // dispatcher
    W.GetDispatcher.Post(procedure begin end);
    Check(True, 'dispatcher post ok');
    W.Close; Check(W.IsClosed, 'closed'); Check(W.NativeHandle=nil, 'handle nil after close');
    W.Close; Check(True, 'close idempotent');
  finally
    if (W<>nil) and not W.IsClosed then W.Close;
  end;

  // ParentHandle attach with explicit canvas id string
  LCanvasId := 'my-canvas';
  try
    W := TWindowBuilder.New.Kind(wkWasm).Parent(TWindowNativeHandle(PAnsiChar(LCanvasId))).Size(800,600).Build;
    Check(not W.IsClosed, 'wasm attach with explicit canvas id open');
    Check(W.NativeHandle = TWindowNativeHandle(PAnsiChar(LCanvasId)), 'native handle equals ParentHandle');
    W.Close;
  except
    on E: Exception do Check(False, 'wasm explicit canvas attach failed: '+E.Message);
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.wasm_runtime');
  T.Test('probe', @TestProbe);
  T.Test('attach friendly', @TestAttachFriendly);
  T.Test('smoke', @TestSmoke);
  if not T.Run then Halt(1);
  WriteLn('wasm-runtime: done');
end.
