program test_tui_integration;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.focus,
  nextpas.core.tui.keybind,
  nextpas.core.tui.app.screen,
  nextpas.core.test;

type
  TTestScreen = class(TScreen)
  public
    RenderCount: Integer;
    EventCount: Integer;
    LastEvent: TEvent;
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure TTestScreen.Render(const Area: TRect; Buf: TBuffer);
begin
  Inc(RenderCount);
end;

procedure TTestScreen.HandleEvent(const Ev: TEvent);
begin
  Inc(EventCount);
  LastEvent := Ev;
end;

function MakeScreen: TTestScreen;
begin
  Result := TTestScreen.Create;
  Result.RenderCount := 0;
  Result.EventCount := 0;
end;

var
  T: TTestSuite;

{ ---- FocusManager + KeybindManager integration ---- }

procedure TestFocusKeybindTabCycle;
var
  LFocus: TFocusManager;
  LKeybind: TKeybindManager;
  LId1, LId2, LId3: TFocusId;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  LFocus := TFocusManager.Create;
  LKeybind := TKeybindManager.Create;
  LId1 := LFocus.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LFocus.Register(TRect.Make(0, 2, 10, 1));
  LId3 := LFocus.Register(TRect.Make(0, 4, 10, 1));

  LKeybind.BindKey(kmNormal, kcTab, nil, 'Next');
  LKeybind.BindKey(kmNormal, kcBackTab, nil, 'Prev');

  // Tab forward
  LKey.Code := kcTab; LKey.Modifiers := []; LKey.Ch := 0;
  LHandled := LFocus.HandleKey(LKey);
  Check(LHandled, 'Tab handled');
  Check(LFocus.FocusedId = LId2, 'Tab moves to LId2');

  // Tab again
  LHandled := LFocus.HandleKey(LKey);
  Check(LFocus.FocusedId = LId3, 'Tab moves to LId3');

  // Shift+Tab backward
  LKey.Code := kcTab; LKey.Modifiers := [kmShift];
  LHandled := LFocus.HandleKey(LKey);
  Check(LHandled, 'Shift+Tab handled');
  Check(LFocus.FocusedId = LId2, 'Shift+Tab moves to LId2');

  LFocus.Free;
  LKeybind.Free;
end;

procedure TestFocusKeybindArrowNav;
var
  LFocus: TFocusManager;
  LId1, LId2: TFocusId;
begin
  LFocus := TFocusManager.Create;
  LId1 := LFocus.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LFocus.Register(TRect.Make(15, 0, 10, 1));

  // Navigate right (arrow keys use Navigate directly, not HandleKey)
  LFocus.Navigate(fnRight);
  Check(LFocus.FocusedId = LId2, 'Right arrow moves to LId2');

  // Navigate left
  LFocus.Navigate(fnLeft);
  Check(LFocus.FocusedId = LId1, 'Left arrow moves to LId1');

  LFocus.Free;
end;

procedure TestFocusSpatialNavigation;
var
  LFocus: TFocusManager;
  LTl, LTr, LBl, LBr: TFocusId;
begin
  LFocus := TFocusManager.Create;
  // 2x2 grid
  LTl := LFocus.Register(TRect.Make(0, 0, 10, 1));  // top-left
  LTr := LFocus.Register(TRect.Make(15, 0, 10, 1));  // top-right
  LBl := LFocus.Register(TRect.Make(0, 5, 10, 1));   // bottom-left
  LBr := LFocus.Register(TRect.Make(15, 5, 10, 1));  // bottom-right

  // From top-left, go down -> bottom-left
  LFocus.Navigate(fnDown);
  Check(LFocus.FocusedId = LBl, 'Down from TL -> BL');

  // From bottom-left, go right -> bottom-right
  LFocus.Navigate(fnRight);
  Check(LFocus.FocusedId = LBr, 'Right from BL -> BR');

  // From bottom-right, go up -> top-right
  LFocus.Navigate(fnUp);
  Check(LFocus.FocusedId = LTr, 'Up from BR -> TR');

  // From top-right, go left -> top-left
  LFocus.Navigate(fnLeft);
  Check(LFocus.FocusedId = LTl, 'Left from TR -> TL');

  LFocus.Free;
end;

{ ---- ScreenStack integration ---- }

procedure TestScreenStackRender;
var
  LStack: TScreenStack;
  LS1, LS2: TTestScreen;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeScreen;
  LS2 := MakeScreen;
  LArea := TRect.Make(0, 0, 10, 5);
  LBuf := TBuffer.CreateEmpty(LArea);

  LStack.Push(LS1);
  LStack.Render(LArea, LBuf);
  Check(LS1.RenderCount = 1, 'S1 rendered once');

  LStack.Push(LS2);
  LStack.Render(LArea, LBuf);
  Check(LS2.RenderCount = 1, 'S2 rendered');
  Check(LS1.RenderCount = 1, 'S1 not rendered again');

  LBuf.Free;
  LStack.Free;
end;

procedure TestScreenStackHandleEvent;
var
  LStack: TScreenStack;
  LS1, LS2: TTestScreen;
  LEv: TEvent;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeScreen;
  LS2 := MakeScreen;
  LEv := KeyCharEvent(Ord('a'), []);

  LStack.Push(LS1);
  LStack.HandleEvent(LEv);
  Check(LS1.EventCount = 1, 'S1 got event');

  LStack.Push(LS2);
  LStack.HandleEvent(LEv);
  Check(LS2.EventCount = 1, 'S2 got event');
  Check(LS1.EventCount = 1, 'S1 did not get event again');

  LStack.Free;
end;

procedure TestScreenStackLifecycle;
var
  LStack: TScreenStack;
  LS1, LS2: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeScreen;
  LS2 := MakeScreen;

  LStack.Push(LS1);
  Check(LStack.Count = 1, 'Count 1');
  Check(LStack.Top = LS1, 'Top is S1');

  LStack.Push(LS2);
  Check(LStack.Count = 2, 'Count 2');
  Check(LStack.Top = LS2, 'Top is S2');

  LStack.Pop.Free;
  Check(LStack.Count = 1, 'Count 1 after pop');
  Check(LStack.Top = LS1, 'Top is S1 after pop');

  LStack.Pop.Free;
  Check(LStack.IsEmpty, 'Empty after second pop');

  LStack.Free;
end;

procedure TestScreenStackReplaceLifecycle;
var
  LStack: TScreenStack;
  LS1, LS2, LS3: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeScreen;
  LS2 := MakeScreen;
  LS3 := MakeScreen;

  LStack.Push(LS1);
  LStack.Push(LS2);
  Check(LStack.Count = 2, 'Count 2');

  LStack.Replace(LS3);
  Check(LStack.Count = 2, 'Count still 2 after replace');
  Check(LStack.Top = LS3, 'Top is S3');

  LStack.Free;
end;

procedure TestScreenStackSharedState;
var
  LStack: TScreenStack;
  LScreen: TTestScreen;
  LState: TObject;
begin
  LStack := TScreenStack.Create;
  LScreen := MakeScreen;
  LState := TObject.Create;

  LStack.SharedStateObject := LState;
  LStack.Push(LScreen);
  Check(LScreen.SharedStateObject = LState, 'Screen sees shared state');

  LStack.SharedStateObject := nil;
  LStack.Free;
  LState.Free;
end;


procedure TestScreenStackCountAfterPushPop;
var
  LStack: TScreenStack;
  LScreen, LPopped: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LScreen := MakeScreen;
  try
    Check(LStack.Count = 0, 'starts empty');
    LStack.Push(LScreen);
    Check(LStack.Count = 1, 'one after push');
    LPopped := TTestScreen(LStack.Pop);
    Check(LStack.Count = 0, 'empty after pop');
    Check(LPopped = LScreen, 'pop returns same screen');
    LPopped.Free;
  finally
    LStack.Free;
  end;
end;

procedure TestFocusRegisterMultipleIdsDistinct;
var
  LFocus: TFocusManager;
  A, B: TFocusId;
begin
  LFocus := TFocusManager.Create;
  try
    A := LFocus.Register(TRect.Make(0, 0, 4, 1));
    B := LFocus.Register(TRect.Make(0, 2, 4, 1));
    Check(A <> B, 'ids distinct');
  finally
    LFocus.Free;
  end;
end;

procedure TestFocusBeginFrameIdempotent;
var
  LFocus: TFocusManager;
begin
  LFocus := TFocusManager.Create;
  try
    LFocus.BeginFrame;
    LFocus.BeginFrame;
    LFocus.Register(TRect.Make(0, 0, 1, 1));
    Check(LFocus.FocusedId <> 0, 'has focus after register');
  finally
    LFocus.Free;
  end;
end;

procedure TestScreenStackSharedStateNilDefault;
var
  LStack: TScreenStack;
begin
  LStack := TScreenStack.Create;
  try
    Check(LStack.SharedStateObject = nil, 'default shared nil');
  finally
    LStack.Free;
  end;
end;


begin
  T := TTestSuite.Create('tui_integration');
  { Focus + Keybind }
  T.Test('Focus+Keybind Tab cycle', @TestFocusKeybindTabCycle);
  T.Test('Focus+Keybind arrow nav', @TestFocusKeybindArrowNav);
  T.Test('Focus spatial navigation', @TestFocusSpatialNavigation);
  { ScreenStack }
  T.Test('ScreenStack render delegation', @TestScreenStackRender);
  T.Test('ScreenStack event delegation', @TestScreenStackHandleEvent);
  T.Test('ScreenStack lifecycle push/pop', @TestScreenStackLifecycle);
  T.Test('ScreenStack replace lifecycle', @TestScreenStackReplaceLifecycle);
  T.Test('ScreenStack shared state', @TestScreenStackSharedState);
    T.Test('ScreenStack count push/pop', @TestScreenStackCountAfterPushPop);
  T.Test('Focus register ids distinct', @TestFocusRegisterMultipleIdsDistinct);
  T.Test('Focus BeginFrame then register', @TestFocusBeginFrameIdempotent);
  T.Test('ScreenStack shared nil default', @TestScreenStackSharedStateNilDefault);
if not T.Run then Halt(1);
end.
