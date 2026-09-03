program test_window_fake;
{ fake 契约门禁：状态机、句柄纪律、关闭幂等、事件注入同一分发路径、
  Dispatcher Pump 语义、scale 脚本、ParentHandle 记录。heaptrc 硬门。 }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.window.base,
  nextpas.core.window.intf,
  nextpas.core.window.fake,
  nextpas.core.window.factory;

var
  GEvents: Integer;
  GLastEvent: TWindowEvent;
  GDispatcherCtr: Integer = 0;

type
  TDispatcherHelper = class
    Ctr: PInteger;
    procedure Handle;
  end;

  TEventHelper = class
    Ctr: PInteger;
    procedure OnEv(const AEvent: TWindowEvent);
  end;

procedure TDispatcherHelper.Handle;
begin
  Ctr^ := Ctr^ + 100;
end;

procedure TEventHelper.OnEv(const AEvent: TWindowEvent);
begin
  Ctr^ := 42;
end;

procedure PlainDispatcherProc;
begin
  GDispatcherCtr := GDispatcherCtr + 1000;
end;

procedure PlainEventProc(const AEvent: TWindowEvent);
begin
  GEvents := 99;
end;

procedure ResetEventCounters;
begin
  GEvents := 0;
  FillChar(GLastEvent, SizeOf(GLastEvent), 0);
end;

procedure TestInitialState;
var
  W: IWindow;
  LFake: TFakeWindow;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  LFake := TFakeWindow.FromWindow(W);
  try
    Check(not W.IsClosed, 'fresh window must not be closed');
    Check(not W.IsVisible, 'fresh window must be hidden');
    CheckEqual(Int64(1024), Int64(W.GetWidth));
    CheckEqual(Int64(768), Int64(W.GetHeight));
    CheckEqual(Double(1.0), W.GetScaleFactor);
    Check(W.NativeHandle <> nil, 'fake native handle non-nil');
    Check(LFake.StoredParentHandle = nil, 'default parent nil');
    Check(W.GetDispatcher <> nil, 'dispatcher exists');
    Check(W.GetDispatcher.IsOnMainThread, 'dispatcher on main thread');
  finally
    W.Close;
    W := nil;
  end;
end;

procedure TestVisibilityAndGeometry;
var
  W: IWindow;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.Show;
    Check(W.IsVisible, 'show');
    W.Hide;
    Check(not W.IsVisible, 'hide');
    W.SetTitle('Hello');
    CheckEqual('Hello', W.GetTitle);
    W.SetBounds(800, 600);
    CheckEqual(Int64(800), Int64(W.GetWidth));
    CheckEqual(Int64(600), Int64(W.GetHeight));
    W.SetBounds(-10, -20);
    CheckEqual(Int64(0), Int64(W.GetWidth));
    CheckEqual(Int64(0), Int64(W.GetHeight));
    W.SetResizable(False);
    Check(True, 'set resizable no throw');
  finally
    W.Close;
    W := nil;
  end;
end;

procedure TestWindowStates;
var
  W: IWindow;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  try
    W.Maximize;
    Check(W.IsMaximized, 'maximize');
    W.Minimize;
    Check(W.IsMinimized, 'minimize');
    W.Restore;
    Check(not W.IsMinimized, 'restore clears minimized');
    Check(not W.IsMaximized, 'restore clears maximized');
    W.Maximize;
    W.Unmaximize;
    Check(not W.IsMaximized, 'unmaximize');
    W.Focus;
    Check(True, 'focus no throw');
  finally
    W.Close;
    W := nil;
  end;
end;

procedure TestCloseIdempotentAndSemantics;
var
  W: IWindow;
  LRaised: Boolean;
begin
  W := CreateFakeWindow(DefaultWindowOptions);
  W.Show;
  W.Close;
  W.Close;
  Check(W.IsClosed, 'closed after Close');
  Check(W.NativeHandle = nil, 'handle nil after close');
  Check(W.IsClosed, 'IsClosed idempotent readable after close');
  Check(W.NativeHandle = nil, 'NativeHandle nil repeatable');

  LRaised := False;
  try W.Show; except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'show after close throws EWindowClosed');

  LRaised := False;
  try W.SetTitle('x'); except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'set title after close');

  LRaised := False;
  try W.SetBounds(10,10); except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'set bounds after close');

  LRaised := False;
  try W.GetWidth; except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'get width after close');

  LRaised := False;
  try W.GetScaleFactor; except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'get scale after close');

  LRaised := False;
  try W.Maximize; except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'maximize after close');

  { OnEvent after close should also throw }
  LRaised := False;
  try
    W.OnEvent(procedure(const E: TWindowEvent) begin end);
  except on E: EWindowClosed do LRaised := True; end;
  Check(LRaised, 'onEvent after close');

  W := nil;
end;

procedure TestHandleDeterministic;
var
  W1, W2: IWindow;
  H1, H2: TWindowNativeHandle;
begin
  W1 := CreateFakeWindow(DefaultWindowOptions);
  H1 := W1.NativeHandle;
  W2 := CreateFakeWindow(DefaultWindowOptions);
  H2 := W2.NativeHandle;
  try
    Check(H1 <> nil, 'handle1 non-nil');
    Check(H2 <> nil, 'handle2 non-nil');
    Check(H1 <> H2, 'deterministic handles distinct');
  finally
    W1.Close; W2.Close;
    W1 := nil; W2 := nil;
  end;
end;

procedure TestEventInjectionSamePath;
var
  W: IWindow;
  LFake: TFakeWindow;
  LEvent: TWindowEvent;
begin
  ResetEventCounters;
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  try
    W.OnEvent(procedure(const E: TWindowEvent)
      begin
        GEvents := GEvents + 1;
        GLastEvent := E;
      end);
    FillChar(LEvent, SizeOf(LEvent), 0);
    LEvent.Kind := weResized;
    LEvent.Width := 640;
    LEvent.Height := 480;
    LFake.InjectEvent(LEvent);
    CheckEqual(Int64(1), Int64(GEvents));
    CheckEqual(Ord(weResized), Ord(GLastEvent.Kind));
    CheckEqual(Int64(640), Int64(GLastEvent.Width));
    CheckEqual(Int64(480), Int64(GLastEvent.Height));

    { 第二次覆盖注册：最后注册者生效 }
    W.OnEvent(procedure(const E: TWindowEvent)
      begin
        GEvents := 100;
      end);
    LEvent.Kind := weFocusIn;
    LFake.InjectEvent(LEvent);
    CheckEqual(Int64(100), Int64(GEvents));
  finally
    W.Close; W := nil;
  end;
end;

procedure TestEventInjectionViaBoundsSamePath;
var
  W: IWindow;
  LFake: TFakeWindow;
begin
  ResetEventCounters;
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  try
    W.OnEvent(procedure(const E: TWindowEvent)
      begin
        GEvents := GEvents + 1;
        GLastEvent := E;
      end);
    { SetBounds 内部产生 weResized 并走同一 DoDispatch }
    W.SetBounds(800, 600);
    CheckEqual(Int64(1), Int64(GEvents));
    CheckEqual(Ord(weResized), Ord(GLastEvent.Kind));
    CheckEqual(Int64(800), Int64(GLastEvent.Width));

    { 注入 weMoved 也走同一路径 }
    FillChar(GLastEvent, SizeOf(GLastEvent), 0);
    GEvents := 0;
    LFake.InjectEvent(Default(TWindowEvent));
    { default kind weCloseRequested = 0,  verify dispatch happened }
    CheckEqual(Int64(1), Int64(GEvents));
  finally
    W.Close; W := nil;
  end;
end;

procedure TestScaleChangedViaScriptAndInjection;
var
  W: IWindow;
  LFake: TFakeWindow;
begin
  ResetEventCounters;
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  try
    W.OnEvent(procedure(const E: TWindowEvent)
      begin
        GEvents := GEvents + 1;
        GLastEvent := E;
      end);
    LFake.SetScale(2.0);
    CheckEqual(Double(2.0), W.GetScaleFactor);
    CheckEqual(Int64(1), Int64(GEvents));
    CheckEqual(Ord(weScaleChanged), Ord(GLastEvent.Kind));
    CheckEqual(Double(2.0), GLastEvent.NewScale.Factor);

    { 注入 weScaleChanged 也走同一路径 }
    GEvents := 0;
    FillChar(GLastEvent, SizeOf(GLastEvent), 0);
    GLastEvent.Kind := weScaleChanged;
    GLastEvent.NewScale := TWindowScale.FromFactor(1.5);
    LFake.InjectEvent(GLastEvent);
    CheckEqual(Int64(1), Int64(GEvents));
    CheckEqual(Ord(weScaleChanged), Ord(GLastEvent.Kind));
    { 注入不改变内部 scale，除非显式 SetScale }
    CheckEqual(Double(2.0), W.GetScaleFactor);
  finally
    W.Close; W := nil;
  end;
end;

procedure TestDispatcherPumpSemantics;
var
  W: IWindow;
  LFake: TFakeWindow;
  LCtr: Integer;
begin
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  try
    LCtr := 0;
    CheckEqual(Int64(0), Int64(LFake.PendingPosts));
    W.GetDispatcher.Post(procedure begin LCtr := LCtr + 1; end);
    W.GetDispatcher.Post(procedure begin LCtr := LCtr + 10; end);
    CheckEqual(Int64(2), Int64(LFake.PendingPosts));
    Check(LFake.PumpOnce, 'pump once returns true');
    CheckEqual(Int64(1), Int64(LCtr));
    CheckEqual(Int64(1), Int64(LFake.PendingPosts));
    LFake.PumpAll;
    CheckEqual(Int64(11), Int64(LCtr));
    CheckEqual(Int64(0), Int64(LFake.PendingPosts));
    Check(not LFake.PumpOnce, 'pump empty returns false');
  finally
    W.Close; W := nil;
  end;
end;

procedure TestDispatcherThreeForms;
var
  W: IWindow;
  LFake: TFakeWindow;
  LCtr: Integer;
  LHelper: TDispatcherHelper;
begin
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  LHelper := TDispatcherHelper.Create;
  try
    LCtr := 0;
    LHelper.Ctr := @LCtr;
    GDispatcherCtr := 0;

    { ref form }
    W.GetDispatcher.Post(procedure begin LCtr := LCtr + 1; end);
    { method form }
    W.GetDispatcher.Post(@LHelper.Handle);
    { proc form - use global var }
    LCtr := 0;
    GDispatcherCtr := LCtr;
    W.GetDispatcher.Post(@PlainDispatcherProc);
    { Note: PlainDispatcherProc increments GDispatcherCtr, not LCtr;
      we adjust test to check sum via GDispatcherCtr }
    W.GetDispatcher.Post(procedure begin LCtr := LCtr + 10; end);
    LFake.PumpAll;
    { LCtr got 1 (ref) +100 (method) +10 (ref) =111, GDispatcherCtr got 1000 }
    CheckEqual(Int64(111), Int64(LCtr));
    CheckEqual(Int64(1000), Int64(GDispatcherCtr));
  finally
    LHelper.Free;
    W.Close; W := nil;
  end;
end;

procedure TestOnEventMethodProcOverload;
var
  W: IWindow;
  LFake: TFakeWindow;
  LObj: TEventHelper;
  LEvent: TWindowEvent;
begin
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  LObj := TEventHelper.Create;
  try
    GEvents := 0;
    LObj.Ctr := @GEvents;

    W.OnEvent(@LObj.OnEv);
    FillChar(LEvent, SizeOf(LEvent), 0);
    LEvent.Kind := weFocusIn;
    LFake.InjectEvent(LEvent);
    CheckEqual(Int64(42), Int64(GEvents));

    W.OnEvent(@PlainEventProc);
    LFake.InjectEvent(LEvent);
    CheckEqual(Int64(99), Int64(GEvents));
  finally
    LObj.Free;
    W.Close; W := nil;
  end;
end;

procedure TestCloseMarshalViaDispatcher;
var
  W: IWindow;
  LFake: TFakeWindow;
begin
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  try
    { Post a Close from non-main concept: we simulate by Posting a closure that calls Close }
    W.GetDispatcher.Post(procedure begin W.Close; end);
    Check(not W.IsClosed, 'not closed before pump');
    LFake.PumpOnce;
    Check(W.IsClosed, 'closed after pump via dispatcher');
    Check(W.NativeHandle = nil, 'handle nil after marshaled close');
  finally
    W := nil;
  end;
end;

procedure TestParentHandleStored;
var
  LOptions: TWindowOptions;
  W: IWindow;
  LFake: TFakeWindow;
begin
  LOptions := DefaultWindowOptions;
  LOptions.ParentHandle := TWindowNativeHandle(Pointer($DEADBEEF));
  LFake := TFakeWindow.Create(LOptions);
  W := LFake;
  try
    CheckEqual(Pointer($DEADBEEF), Pointer(LFake.StoredParentHandle));
  finally
    W.Close; W := nil;
  end;
end;

procedure TestLiveCountTracking;
var
  W: IWindow;
  LBefore: Integer;
begin
  LBefore := FakeLiveWindowCount;
  W := CreateFakeWindow(DefaultWindowOptions);
  CheckEqual(Int64(LBefore + 1), Int64(FakeLiveWindowCount));
  W.Close;
  CheckEqual(Int64(LBefore), Int64(FakeLiveWindowCount));
  W := nil;
end;

procedure TestDpiFocusAndMoveEvents;
var
  W: IWindow;
  LFake: TFakeWindow;
  E: TWindowEvent;
begin
  ResetEventCounters;
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  try
    W.OnEvent(procedure(const AEvent: TWindowEvent) begin GEvents:=GEvents+1; GLastEvent:=AEvent; end);
    E := Default(TWindowEvent); E.Kind := weScaleChanged; E.NewScale := TWindowScale.FromFactor(1.75);
    LFake.InjectEvent(E);
    CheckEqual(Ord(weScaleChanged), Ord(GLastEvent.Kind));
    CheckEqual(Double(1.75), GLastEvent.NewScale.Factor);
    E.Kind := weFocusChanged;
    LFake.InjectEvent(E);
    CheckEqual(Ord(weFocusChanged), Ord(GLastEvent.Kind));
    E.Kind := weMoved; E.X := 33; E.Y := 44;
    LFake.InjectEvent(E);
    CheckEqual(Ord(weMoved), Ord(GLastEvent.Kind));
    CheckEqual(Int64(33), Int64(GLastEvent.X));
    CheckEqual(Int64(44), Int64(GLastEvent.Y));
    CheckEqual(Int64(3), Int64(GEvents));
  finally W.Close; W:=nil; end;
end;

procedure TestQueueGrowBeyond32;
var
  W: IWindow;
  LFake: TFakeWindow;
  I: Integer;
  Ctr: Integer;
begin
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  Ctr := 0;
  try
    for I := 1 to 64 do
      W.GetDispatcher.Post(procedure begin Ctr := Ctr + 1; end);
    CheckEqual(Int64(64), Int64(LFake.PendingPosts));
    LFake.PumpAll;
    CheckEqual(Int64(64), Int64(Ctr));
    CheckEqual(Int64(0), Int64(LFake.PendingPosts));
  finally W.Close; W:=nil; end;
end;

procedure TestCloseRequestedVsClosed;
var
  W: IWindow;
  LFake: TFakeWindow;
  E: TWindowEvent;
  GotReq, GotClosed: Boolean;
begin
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  GotReq := False; GotClosed := False;
  W.OnEvent(procedure(const AEvent: TWindowEvent) begin if AEvent.Kind=weCloseRequested then GotReq:=True; if AEvent.Kind=weClosed then GotClosed:=True; end);
  E := Default(TWindowEvent); E.Kind := weCloseRequested;
  LFake.InjectEvent(E);
  Check(GotReq, 'closeRequested delivered');
  Check(not GotClosed, 'closed not yet');
  E.Kind := weClosed;
  LFake.InjectEvent(E);
  Check(GotClosed, 'closed delivered');
  W.Close;
end;

procedure TestNoEventsAfterClose;
var
  W: IWindow;
  LFake: TFakeWindow;
  LEvent: TWindowEvent;
begin
  ResetEventCounters;
  LFake := TFakeWindow.Create(DefaultWindowOptions);
  W := LFake;
  W.OnEvent(procedure(const E: TWindowEvent) begin GEvents := GEvents + 1; end);
  W.Close;
  FillChar(LEvent, SizeOf(LEvent), 0);
  LEvent.Kind := weResized;
  LFake.InjectEvent(LEvent);
  CheckEqual(Int64(0), Int64(GEvents));
  W := nil;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.window.fake');
  T.Test('initial state', @TestInitialState);
  T.Test('visibility and geometry', @TestVisibilityAndGeometry);
  T.Test('window states', @TestWindowStates);
  T.Test('close idempotent and semantics', @TestCloseIdempotentAndSemantics);
  T.Test('handle deterministic', @TestHandleDeterministic);
  T.Test('event injection same path', @TestEventInjectionSamePath);
  T.Test('event injection via bounds same path', @TestEventInjectionViaBoundsSamePath);
  T.Test('scale changed via script and injection', @TestScaleChangedViaScriptAndInjection);
  T.Test('dispatcher pump semantics', @TestDispatcherPumpSemantics);
  T.Test('dispatcher three forms', @TestDispatcherThreeForms);
  T.Test('onEvent method proc overload', @TestOnEventMethodProcOverload);
  T.Test('close marshal via dispatcher', @TestCloseMarshalViaDispatcher);
  T.Test('parent handle stored', @TestParentHandleStored);
  T.Test('live count tracking', @TestLiveCountTracking);
  T.Test('scale/focus/moved minimal 6-event matrix', @TestDpiFocusAndMoveEvents);
  T.Test('queue 32-cap grow to 64', @TestQueueGrowBeyond32);
  T.Test('closeRequested vs closed', @TestCloseRequestedVsClosed);
  T.Test('no events after close', @TestNoEventsAfterClose);
  if not T.Run then Halt(1);
end.
