program test_window_factory;
{ 工厂与 Builder 门禁：后端可用性事实（探测驱动）、不可用后端
  fail-fast（ecNotFound）、ParentHandle 诚实失败、选项校验接线、
  默认 kind 能力驱动冒烟、fluent 链全字段应用（Kind(wkFake) 钉确定性语义）、
  Build 多窗、RunLoop/ExitLoop 语义。heaptrc 0 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  TypInfo,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.fake,
  nextpas.core.window.factory,
  nextpas.core.window.gtk3,
  nextpas.core.gtk3.loader,
  nextpas.core.window.sdl2,
  nextpas.core.window.sdl2.loader,
  nextpas.core.window.win32,
  nextpas.core.window.win32.loader,
  nextpas.core.window.cocoa,
  nextpas.core.window.cocoa.loader,
  nextpas.core.window.wasm,
  nextpas.core.window.wasm.loader,
  nextpas.core.window.android,
  nextpas.core.window.android.loader,
  nextpas.core.window.uikit,
  nextpas.core.window.uikit.loader;

procedure TestBackendAvailabilityFacts;
var
  LGtkAvail, LSdl2Avail, LWin32Avail, LCocoaAvail, LWasmAvail, LAndroidAvail, LUIKitAvail: Boolean;
begin
  Check(WindowBackendAvailable(wkFake), 'fake always available');
  LGtkAvail := WindowBackendAvailable(wkGtk);
  Check(LGtkAvail = WindowGtk3IsAvailable, 'gtk availability matches loader probe');
  LSdl2Avail := WindowBackendAvailable(wkSdl2);
  Check(LSdl2Avail = WindowSdl2IsAvailable, 'sdl2 availability matches loader probe');
  LWin32Avail := WindowBackendAvailable(wkWin32);
  Check(LWin32Avail = WindowWin32IsAvailable, 'win32 availability matches loader probe');
  LCocoaAvail := WindowBackendAvailable(wkCocoa);
  Check(LCocoaAvail = WindowCocoaIsAvailable, 'cocoa availability matches loader probe');
  LWasmAvail := WindowBackendAvailable(wkWasm);
  Check(LWasmAvail = WindowWasmIsAvailable, 'wasm availability matches loader probe');
  LAndroidAvail := WindowBackendAvailable(wkAndroid);
  Check(LAndroidAvail = WindowAndroidIsAvailable, 'android availability matches loader probe');
  LUIKitAvail := WindowBackendAvailable(wkUIKit);
  Check(LUIKitAvail = WindowUIKitIsAvailable, 'uikit availability matches loader probe');
  // Default kind priority: win32 > cocoa > gtk > sdl2 > fake (wasm between but not available on Linux)
  if LWin32Avail then
    CheckEqual(Ord(wkWin32), Ord(DefaultWindowKind), 'default = win32 when probed')
  else if LCocoaAvail then
    CheckEqual(Ord(wkCocoa), Ord(DefaultWindowKind), 'default = cocoa when probed')
  else if LGtkAvail then
    CheckEqual(Ord(wkGtk), Ord(DefaultWindowKind), 'default = gtk when gtk probed')
  else if LSdl2Avail then
    CheckEqual(Ord(wkSdl2), Ord(DefaultWindowKind), 'default = sdl2 when gtk absent but sdl2 probed')
  else
    CheckEqual(Ord(wkFake), Ord(DefaultWindowKind), 'default = fake when none probed');
  Check(Ord(wkWasm) < Ord(wkFake), 'wasm before fake');
end;

procedure TestUnavailableBackendFailsFast;
var
  LRaised: Boolean;
  W: IWindow;
begin
  if WindowBackendAvailable(wkGtk) then
  begin
    // gtk available: creating should succeed (environment has display or at least loader)
    // If no display, creation may still raise NotInitialized; treat both as "available" path
    try
      W := CreateWindowOf(wkGtk, DefaultWindowOptions);
      Check(not W.IsClosed, 'gtk available: create succeeds');
      W.Close;
    except
      on E: EWindowNotInitialized do
        Check(True, 'gtk available but no display — honst NotInitialized');
      on E: EWindowBackendUnavailable do
        Check(False, 'gtk available should not raise BackendUnavailable');
    end;
  end
  else
  begin
    LRaised := False;
    try
      CreateWindowOf(wkGtk, DefaultWindowOptions);
    except
      on E: EWindowBackendUnavailable do
      begin
        LRaised := True;
        CheckEqual(Ord(ecNotFound), Ord(E.Category));
        CheckContains(E.Message, 'wkGtk');
      end;
    end;
    Check(LRaised, 'unavailable backend must fail fast with ecNotFound');
  end;

  if WindowBackendAvailable(wkSdl2) then
  begin
    try
      W := CreateWindowOf(wkSdl2, DefaultWindowOptions);
      Check(not W.IsClosed, 'sdl2 available: create succeeds');
      W.Close;
    except
      on E: EWindowNotInitialized do
        Check(True, 'sdl2 available but no display — honest NotInitialized');
      on E: EWindowBackendUnavailable do
        Check(False, 'sdl2 available should not raise BackendUnavailable');
    end;
  end
  else
  begin
    LRaised := False;
    try
      CreateWindowOf(wkSdl2, DefaultWindowOptions);
    except
      on E: EWindowBackendUnavailable do
      begin
        LRaised := True;
        CheckEqual(Ord(ecNotFound), Ord(E.Category));
        CheckContains(E.Message, 'wkSdl2');
      end;
    end;
    Check(LRaised, 'sdl2 unavailable fail fast');
  end;
end;

procedure TestCreateValidatesOptions;
var
  LOptions: TWindowOptions;
  LRaised: Boolean;
begin
  LOptions := DefaultWindowOptions;
  LOptions.Size.Width := -1;
  LRaised := False;
  try
    CreateFakeWindow(LOptions);
  except
    on E: EWindowInvalidState do LRaised := True;
  end;
  Check(LRaised, 'create must validate options - negative width');

  LOptions := DefaultWindowOptions;
  LOptions.Constraints.MinWidth := 800;
  LOptions.Constraints.MaxWidth := 400;
  LRaised := False;
  try
    CreateFakeWindow(LOptions);
  except
    on E: EWindowInvalidState do LRaised := True;
  end;
  Check(LRaised, 'create must validate max < min');
end;

procedure TestParentHandleUnsupportedForDesktop;
var
  LOptions: TWindowOptions;
  LRaised: Boolean;
begin
  LOptions := DefaultWindowOptions;
  LOptions.ParentHandle := TWindowNativeHandle(Pointer($1234));
  { fake 接受 }
  try
    CreateFakeWindow(LOptions).Close;
    Check(True, 'fake accepts parentHandle');
  except
    on E: Exception do Check(False, 'fake should accept parentHandle: ' + E.Message);
  end;

  { desktop kinds 直接抛 EWindowUnsupported（若可用），否则 BackendUnavailable 亦算诚实 }
  LRaised := False;
  try
    CreateWindowOf(wkGtk, LOptions);
  except
    on E: EWindowUnsupported do LRaised := True;
    on E: EWindowBackendUnavailable do LRaised := True;
    on E: EWindowNotInitialized do LRaised := True; // gtk available but no display — still honest
  end;
  Check(LRaised, 'desktop parentHandle must fail (unsupported or unavailable or no display)');
end;

procedure TestBuilderAppliesAllFields;
var
  W: IWindow;
begin
  W := TWindowBuilder.New
    .Kind(wkFake)
    .Title('Factory')
    .Size(1200, 800)
    .MinSize(400, 300)
    .MaxSize(2000, 1500)
    .Resizable(False)
    .StartMaximized(True)
    .Build;
  try
    CheckEqual(Int64(1200), Int64(W.GetWidth));
    CheckEqual(Int64(800), Int64(W.GetHeight));
    CheckEqual('Factory', W.GetTitle, 'builder applies title');
    Check(W.IsMaximized, 'builder startMaximized');
    Check(not W.IsClosed, 'built window is open');
    Check(W.NativeHandle <> nil, 'handle non-nil');
  finally
    if (W <> nil) and not W.IsClosed then W.Close;
  end;

  { Options 整体覆盖 }
  W := TWindowBuilder.New
    .Options(DefaultWindowOptions)
    .Kind(wkFake)
    .Title('Overridden')
    .Build;
  try
    CheckEqual('Overridden', W.GetTitle);
  finally
    if not W.IsClosed then W.Close;
  end;
end;

procedure TestBuilderParentHandle;
var
  W: IWindow;
  LFake: TFakeWindow;
begin
  W := TWindowBuilder.New
    .Kind(wkFake)
    .Parent(TWindowNativeHandle(Pointer($BEEF)))
    .Build;
  LFake := TFakeWindow.FromWindow(W);
  try
    CheckEqual(Pointer($BEEF), Pointer(LFake.StoredParentHandle));
  finally
    W.Close;
  end;
end;

procedure TestBuilderBuildTwiceTwoWindows;
var
  WA, WB: IWindow;
begin
  WA := TWindowBuilder.New.Kind(wkFake).Build;
  WB := TWindowBuilder.New.Kind(wkFake).Build;
  try
    Check(WA <> WB, 'two distinct windows');
    Check(FakeLiveWindowCount >= 2, 'both tracked');
    Check(WA.NativeHandle <> WB.NativeHandle, 'handles distinct');
  finally
    if (WA <> nil) and not WA.IsClosed then WA.Close;
    if (WB <> nil) and not WB.IsClosed then WB.Close;
  end;
end;

procedure TestBuilderDefaultKind;
var
  W: IWindow;
  LFake: TFakeWindow;
  LIsFake: Boolean;
begin
  if not WindowBackendAvailable(wkGtk) then
  begin
    W := TWindowBuilder.New.Build;
    try
      LIsFake := False;
      try
        LFake := TFakeWindow.FromWindow(W);
        LIsFake := True;
      except
        on E: EWindowInvalidState do ;
      end;
      Check(LIsFake, 'default kind without gtk is fake');
      Check(not W.IsClosed, 'default-built window is open');
    finally
      if (W <> nil) and not W.IsClosed then W.Close;
    end;
  end
  else
  begin
    // gtk available: default should be gtk; if no display, may raise NotInitialized — skip strict check
    try
      W := TWindowBuilder.New.Build;
      try
        Check(not W.IsClosed, 'default-built gtk window is open');
      finally
        if not W.IsClosed then W.Close;
      end;
    except
      on E: EWindowNotInitialized do
        Check(True, 'gtk default but no display — honest NotInitialized');
    end;
  end;
end;

procedure TestFactoryCreateWindowOfFake;
var
  W: IWindow;
begin
  W := CreateWindowOf(wkFake, DefaultWindowOptions);
  try
    Check(not W.IsClosed, 'factory fake window open');
    CheckEqual(Int64(1024), Int64(W.GetWidth));
  finally
    W.Close;
  end;
end;

procedure TestRunLoopExitPaths;
var
  W, W2: IWindow;
begin
  { 无窗口时立即返回 }
  WindowRunLoop;
  Check(True, 'runloop with no windows returns immediately');

  { ExitLoop 打断泵循环：live window 存在时靠 ExitLoop 退出 }
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.Show;
    W.GetDispatcher.Post(procedure
      begin
        WindowExitLoop;
      end);
    WindowRunLoop;
    Check(True, 'runloop returned via exit loop');
    Check(not W.IsClosed, 'exit loop does not auto-close window');
    W.Close;
  finally
    W := nil;
  end;

  { 全部窗口关闭后自然退出 }
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.Show;
    W.Close;
    WindowRunLoop;
    Check(True, 'runloop returned after windows closed');
  finally
    W := nil;
  end;

  { 多窗：全部关闭后退出，不依赖 ExitLoop }
  W := CreateFakeWindow(DefaultWindowOptions);
  W2 := CreateFakeWindow(DefaultWindowOptions);
  try
    W.Show; W2.Show;
    W.Close; W2.Close;
    WindowRunLoop;
    Check(True, 'runloop returned after multi windows closed');
  finally
    if (W <> nil) and not W.IsClosed then W.Close;
    if (W2 <> nil) and not W2.IsClosed then W2.Close;
    W := nil; W2 := nil;
  end;
end;

procedure TestFactoryOptionsConflictRaisesAtBuild;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TWindowBuilder.New
      .Size(-5, 100)
      .Build;
  except
    on E: EWindowInvalidState do LRaised := True;
  end;
  Check(LRaised, 'builder build must surface option conflicts - negative size');

  LRaised := False;
  try
    TWindowBuilder.New
      .MinSize(800, 600)
      .MaxSize(400, 300)
      .Build;
  except
    on E: EWindowInvalidState do LRaised := True;
  end;
  Check(LRaised, 'builder build must reject max < min');
end;

procedure TestWasmParentHandleIsAttachFriendly;
var
  LOptions: TWindowOptions;
begin
  LOptions := DefaultWindowOptions;
  LOptions.ParentHandle := TWindowNativeHandle(Pointer($CAFE));
  if not WindowBackendAvailable(wkWasm) then
  begin
    try
      CreateWindowOf(wkWasm, LOptions);
      Check(False, 'wasm unavailable should fail fast');
    except
      on E: EWindowBackendUnavailable do
        CheckContains(E.Message, 'wkWasm')
      else
        Check(False, 'wasm with parent must not raise Unsupported');
    end;
  end
  else
  begin
    try
      CreateWindowOf(wkWasm, LOptions).Close;
      Check(True, 'wasm attach with parent succeeds when available');
    except
      on E: Exception do Check(False, 'wasm with parent should succeed when available: '+E.Message);
    end;
  end;
  { fake 亦为 attach 友好（契约预演）}
  try
    CreateFakeWindow(LOptions).Close;
  except
    on E: Exception do Check(False, 'fake with parent must not fail: ' + E.Message);
  end;
end;

procedure TestAttachRequiresParentHandle;
var
  LOptions: TWindowOptions;
  LRaised: Boolean;
begin
  LOptions := DefaultWindowOptions;
  LOptions.ParentHandle := nil;
  // Android attach requires ParentHandle
  if not WindowBackendAvailable(wkAndroid) then
  begin
    try CreateWindowOf(wkAndroid, LOptions); Check(False, 'android unavailable fail'); except on E:EWindowBackendUnavailable do Check(True,'android unavailable honest'); end;
  end
  else
  begin
    LRaised:=False;
    try CreateWindowOf(wkAndroid, LOptions); except on E:EWindowUnsupported do LRaised:=True; end;
    Check(LRaised, 'android attach without parent must raise Unsupported');
  end;
  // UIKit attach requires ParentHandle
  if not WindowBackendAvailable(wkUIKit) then
  begin
    try CreateWindowOf(wkUIKit, LOptions); Check(False, 'uikit unavailable fail'); except on E:EWindowBackendUnavailable do Check(True,'uikit unavailable honest'); end;
  end
  else
  begin
    LRaised:=False;
    try CreateWindowOf(wkUIKit, LOptions); except on E:EWindowUnsupported do LRaised:=True; end;
    Check(LRaised, 'uikit attach without parent must raise Unsupported');
  end;
end;

var
  T: TTestSuite;
  LOk: Boolean;
begin
  T := TTestSuite.Create('nextpas.core.window.factory');
  T.Test('backend availability facts', @TestBackendAvailabilityFacts);
  T.Test('unavailable backend fails fast', @TestUnavailableBackendFailsFast);
  T.Test('create validates options', @TestCreateValidatesOptions);
  T.Test('parent handle unsupported for desktop', @TestParentHandleUnsupportedForDesktop);
  T.Test('builder applies all fields', @TestBuilderAppliesAllFields);
  T.Test('builder parent handle', @TestBuilderParentHandle);
  T.Test('builder build twice two windows', @TestBuilderBuildTwiceTwoWindows);
  T.Test('builder default kind', @TestBuilderDefaultKind);
  T.Test('factory create window of fake', @TestFactoryCreateWindowOfFake);
  T.Test('run loop exit paths', @TestRunLoopExitPaths);
  T.Test('factory options conflict raises at build', @TestFactoryOptionsConflictRaisesAtBuild);
  T.Test('wasm parent handle is attach friendly', @TestWasmParentHandleIsAttachFriendly);
  T.Test('attach requires parent handle', @TestAttachRequiresParentHandle);
  LOk := T.Run;
  UnloadGtk3;
  UnloadWindowSdl2;
  UnloadWindowWin32;
  UnloadWindowCocoa;
  UnloadWindowWasm;
  UnloadWindowAndroid;
  UnloadWindowUIKit;
  if not LOk then Halt(1);
end.
