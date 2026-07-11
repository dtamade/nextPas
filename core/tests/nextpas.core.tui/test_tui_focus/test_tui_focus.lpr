program test_tui_focus;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.focus,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFocusManagerCreate;
var
  LMgr: TFocusManager;
begin
  LMgr := TFocusManager.Create;
  Check(LMgr.EntryCount = 0, 'New manager should have 0 entries');
  Check(LMgr.FocusedId = FOCUS_NONE, 'New manager should have FOCUS_NONE');
  LMgr.Free;
end;

procedure TestFocusManagerRegister;
var
  LMgr: TFocusManager;
  LId: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId := LMgr.Register(TRect.Make(0, 0, 10, 1));
  Check(LId > 0, 'Register should return non-zero id');
  Check(LMgr.EntryCount = 1, 'EntryCount should be 1');
  Check(LMgr.FocusedId = LId, 'First registered should be focused');
  LMgr.Free;
end;

procedure TestFocusManagerRegisterMultiple;
var
  LMgr: TFocusManager;
  LId1, LId2, LId3: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  LId3 := LMgr.Register(TRect.Make(0, 4, 10, 1));
  Check(LMgr.EntryCount = 3, 'EntryCount should be 3');
  Check(LMgr.FocusedId = LId1, 'First registered should remain focused');
  Check(LId1 <> LId2, 'Ids should be unique');
  Check(LId2 <> LId3, 'Ids should be unique');
  LMgr.Free;
end;

procedure TestFocusManagerIsFocused;
var
  LMgr: TFocusManager;
  LId1, LId2: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  Check(LMgr.IsFocused(LId1), 'First should be focused');
  Check(not LMgr.IsFocused(LId2), 'Second should not be focused');
  LMgr.Free;
end;

procedure TestFocusManagerFocusOn;
var
  LMgr: TFocusManager;
  LId1, LId2: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  LMgr.FocusOn(LId2);
  Check(LMgr.FocusedId = LId2, 'Should focus on LId2');
  Check(LMgr.IsFocused(LId2), 'LId2 should be focused');
  Check(not LMgr.IsFocused(LId1), 'LId1 should not be focused');
  LMgr.Free;
end;

procedure TestFocusManagerFocusOnInvalid;
var
  LMgr: TFocusManager;
  LId: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LMgr.FocusOn(999);
  Check(LMgr.FocusedId = LId, 'Focus should not change for invalid id');
  LMgr.Free;
end;

procedure TestFocusManagerNavigateNext;
var
  LMgr: TFocusManager;
  LId1, LId2, LId3: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  LId3 := LMgr.Register(TRect.Make(0, 4, 10, 1));
  LMgr.Navigate(fnNext);
  Check(LMgr.FocusedId = LId2, 'Navigate next should go to LId2');
  LMgr.Navigate(fnNext);
  Check(LMgr.FocusedId = LId3, 'Navigate next should go to LId3');
  LMgr.Navigate(fnNext);
  Check(LMgr.FocusedId = LId1, 'Navigate next should wrap to LId1');
  LMgr.Free;
end;

procedure TestFocusManagerNavigatePrev;
var
  LMgr: TFocusManager;
  LId1, LId2, LId3: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  LId3 := LMgr.Register(TRect.Make(0, 4, 10, 1));
  LMgr.Navigate(fnPrev);
  Check(LMgr.FocusedId = LId3, 'Navigate prev from first should wrap to last');
  LMgr.Free;
end;

procedure TestFocusManagerBeginFrame;
var
  LMgr: TFocusManager;
  LId1: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  Check(LMgr.EntryCount = 1, 'Should have 1 entry');
  LMgr.BeginFrame;
  Check(LMgr.EntryCount = 0, 'BeginFrame should clear entries');
  LMgr.Free;
end;

procedure TestFocusManagerResetSession;
var
  LMgr: TFocusManager;
begin
  LMgr := TFocusManager.Create;
  LMgr.Register(TRect.Make(0, 0, 10, 1));
  LMgr.Register(TRect.Make(0, 2, 10, 1));
  LMgr.ResetSession;
  Check(LMgr.EntryCount = 0, 'ResetSession should clear entries');
  Check(LMgr.FocusedId = FOCUS_NONE, 'ResetSession should reset focus');
  LMgr.Free;
end;

procedure TestFocusManagerFocusedArea;
var
  LMgr: TFocusManager;
  LId: TFocusId;
  LArea: TRect;
begin
  LMgr := TFocusManager.Create;
  LId := LMgr.Register(TRect.Make(5, 10, 20, 3));
  LArea := LMgr.FocusedArea;
  Check(LArea.X = 5, 'Area X should be 5');
  Check(LArea.Y = 10, 'Area Y should be 10');
  Check(LArea.Width = 20, 'Area Width should be 20');
  Check(LArea.Height = 3, 'Area Height should be 3');
  LMgr.Free;
end;

procedure TestFocusManagerHandleKeyTab;
var
  LMgr: TFocusManager;
  LId1, LId2: TFocusId;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  LKey.Code := kcTab;
  LKey.Ch := 0;
  LKey.Modifiers := [];
  LHandled := LMgr.HandleKey(LKey);
  Check(LHandled, 'Tab should be handled');
  Check(LMgr.FocusedId = LId2, 'Tab should move to next');
  LMgr.Free;
end;

procedure TestFocusManagerHandleKeyShiftTab;
var
  LMgr: TFocusManager;
  LId1, LId2: TFocusId;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 2, 10, 1));
  LMgr.FocusOn(LId2);
  LKey.Code := kcTab;
  LKey.Ch := 0;
  LKey.Modifiers := [kmShift];
  LHandled := LMgr.HandleKey(LKey);
  Check(LHandled, 'Shift+Tab should be handled');
  Check(LMgr.FocusedId = LId1, 'Shift+Tab should move to prev');
  LMgr.Free;
end;

procedure TestFocusManagerHandleKeyOther;
var
  LMgr: TFocusManager;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  LMgr := TFocusManager.Create;
  LMgr.Register(TRect.Make(0, 0, 10, 1));
  LKey.Code := kcChar;
  LKey.Ch := Ord('a');
  LKey.Modifiers := [];
  LHandled := LMgr.HandleKey(LKey);
  Check(not LHandled, 'Non-tab key should not be handled');
  LMgr.Free;
end;

procedure TestFocusManagerNavigateDown;
var
  LMgr: TFocusManager;
  LId1, LId2: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(0, 5, 10, 1));
  LMgr.Navigate(fnDown);
  Check(LMgr.FocusedId = LId2, 'Navigate down should go to lower entry');
  LMgr.Free;
end;

procedure TestFocusManagerNavigateRight;
var
  LMgr: TFocusManager;
  LId1, LId2: TFocusId;
begin
  LMgr := TFocusManager.Create;
  LId1 := LMgr.Register(TRect.Make(0, 0, 10, 1));
  LId2 := LMgr.Register(TRect.Make(15, 0, 10, 1));
  LMgr.Navigate(fnRight);
  Check(LMgr.FocusedId = LId2, 'Navigate right should go to right entry');
  LMgr.Free;
end;

begin
  T := TTestSuite.Create('tui_focus');
  T.Test('TFocusManager.Create', @TestFocusManagerCreate);
  T.Test('TFocusManager.Register', @TestFocusManagerRegister);
  T.Test('TFocusManager.Register multiple', @TestFocusManagerRegisterMultiple);
  T.Test('TFocusManager.IsFocused', @TestFocusManagerIsFocused);
  T.Test('TFocusManager.FocusOn', @TestFocusManagerFocusOn);
  T.Test('TFocusManager.FocusOn invalid id', @TestFocusManagerFocusOnInvalid);
  T.Test('TFocusManager.Navigate next', @TestFocusManagerNavigateNext);
  T.Test('TFocusManager.Navigate prev', @TestFocusManagerNavigatePrev);
  T.Test('TFocusManager.BeginFrame', @TestFocusManagerBeginFrame);
  T.Test('TFocusManager.ResetSession', @TestFocusManagerResetSession);
  T.Test('TFocusManager.FocusedArea', @TestFocusManagerFocusedArea);
  T.Test('TFocusManager.HandleKey Tab', @TestFocusManagerHandleKeyTab);
  T.Test('TFocusManager.HandleKey Shift+Tab', @TestFocusManagerHandleKeyShiftTab);
  T.Test('TFocusManager.HandleKey other', @TestFocusManagerHandleKeyOther);
  T.Test('TFocusManager.Navigate down', @TestFocusManagerNavigateDown);
  T.Test('TFocusManager.Navigate right', @TestFocusManagerNavigateRight);
  if not T.Run then Halt(1);
end.
