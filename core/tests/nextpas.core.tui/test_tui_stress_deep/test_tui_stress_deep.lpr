program test_tui_stress_deep;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,  { 必须第一：链接 tui.task（线程前置契约，见 CONTRACT §4） }
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.focus,
  nextpas.core.tui.keybind,
  nextpas.core.tui.event,
  nextpas.core.tui.anim,
  nextpas.core.tui.animator,
  nextpas.core.tui.task,
  nextpas.core.tui.loading,
  nextpas.core.tui.frame_budget,
  nextpas.core.test;

var
  T: TTestSuite;

{ ---- FocusManager stress ---- }

procedure TestFocusManagerStressRegister;
var
  LMgr: TFocusManager;
  I: Integer;
begin
  LMgr := TFocusManager.Create;
  for I := 0 to 999 do
    LMgr.Register(TRect.Make(I mod 20, I div 20, 5, 1));
  Check(LMgr.EntryCount = 1000, 'Should register 1000 entries');
  LMgr.Free;
end;

procedure TestFocusManagerStressNavigate;
var
  LMgr: TFocusManager;
  I: Integer;
begin
  LMgr := TFocusManager.Create;
  for I := 0 to 49 do
    LMgr.Register(TRect.Make(I * 2, 0, 1, 1));
  for I := 0 to 999 do
    LMgr.Navigate(fnNext);
  Check(LMgr.FocusedId > 0, 'Focus should survive 1000 navigations');
  LMgr.Free;
end;

procedure TestFocusManagerStressBeginFrame;
var
  LMgr: TFocusManager;
  I: Integer;
begin
  LMgr := TFocusManager.Create;
  for I := 0 to 99 do
  begin
    LMgr.Register(TRect.Make(0, 0, 10, 1));
    LMgr.BeginFrame;
  end;
  Check(LMgr.EntryCount = 0, 'Should clear on each BeginFrame');
  LMgr.Free;
end;

{ ---- KeybindManager stress ---- }

procedure TestKeybindManagerStressBind;
var
  LMgr: TKeybindManager;
  I: Integer;
begin
  LMgr := TKeybindManager.Create;
  for I := 0 to 999 do
    LMgr.BindChar(kmNormal, Chr(I mod 94 + 33), nil, 'test');
  Check(LMgr.BindingCount = 1000, 'Should bind 1000 keys');
  LMgr.Free;
end;

procedure TestKeybindManagerStressHandleKey;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  I: Integer;
begin
  LMgr := TKeybindManager.Create;
  for I := 0 to 99 do
    LMgr.BindChar(kmNormal, Chr(I mod 94 + 33), nil, 'test');
  LKey.Code := kcChar;
  LKey.Modifiers := [];
  for I := 0 to 9999 do
  begin
    LKey.Ch := Ord(Chr(I mod 94 + 33));
    LMgr.HandleKey(LKey);
  end;
  Check(True, 'Should survive 10000 HandleKey calls');
  LMgr.Free;
end;

{ ---- Animator stress ---- }

procedure TestAnimatorStressStartCancel;
var
  LAnim: TAnimator;
  LTargets: array[0..63] of Double;
  LIds: array[0..63] of Integer;
  I: Integer;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  for I := 0 to 63 do
  begin
    LTargets[I] := 0;
    LIds[I] := LAnim.Start(@LTargets[I], 0, 100, 1000, @EaseLinear);
  end;
  Check(LAnim.RunningCount = 64, 'Should have 64 running');
  for I := 0 to 63 do
    LAnim.Cancel(LIds[I]);
  Check(not LAnim.AnyRunning, 'All should be cancelled');
end;

procedure TestAnimatorStressTick;
var
  LAnim: TAnimator;
  LTargets: array[0..9] of Double;
  I, J: Integer;
begin
  FillChar(LAnim, SizeOf(LAnim), 0);
  for I := 0 to 9 do
  begin
    LTargets[I] := 0;
    LAnim.Start(@LTargets[I], 0, 100, 100, @EaseLinear);
  end;
  for J := 0 to 999 do
    LAnim.Tick(QWord(J));
  for I := 0 to 9 do
    Check(LTargets[I] = 100, 'Target should reach end');
end;

{ ---- LoadingGroup stress ---- }

procedure TestLoadingGroupStressStart;
var
  LGroup: TLoadingGroup;
  I: Integer;
begin
  LGroup := TLoadingGroup.Empty;
  for I := 0 to 15 do
    LGroup.Start(I, TTaskId(I + 1), QWord(I * 100));
  Check(LGroup.Count = 16, 'Should fill all 16 slots');
  Check(LGroup.AnyLoading, 'Should be loading');
  Check(not LGroup.AllDone, 'Should not be all done');
end;

{ ---- FrameBudget stress ---- }

procedure TestFrameBudgetStressFrames;
var
  LBudget: TFrameBudget;
  I: Integer;
begin
  LBudget := TFrameBudget.Create(16.0);
  for I := 0 to 999 do
  begin
    LBudget.BeginFrame;
    LBudget.EndFrame;
  end;
  Check(LBudget.Stats.FrameCount = 1000, 'Should track 1000 frames');
end;

{ ---- Transition stress ---- }

procedure TestTransitionStressAdvance;
var
  LTrans: TTransition;
begin
  LTrans := TTransition.Create(0, 1000, 10000);
  while not LTrans.Done do
    LTrans.Advance(1);
  Check(LTrans.Value = 1000, 'Should reach end');
end;

procedure TestTransitionStressReset;
var
  LTrans: TTransition;
  I: Integer;
begin
  LTrans := TTransition.Create(0, 100, 1000);
  for I := 0 to 999 do
  begin
    LTrans.Advance(500);
    LTrans.Reset;
  end;
  Check(LTrans.ElapsedMs = 0, 'Should be reset');
  Check(LTrans.Value = 0, 'Value should be 0');
end;

procedure TestFocusManagerStressUnregisterAll;
var
  LFocus: TFocusManager;
  I: Integer;
begin
  LFocus := TFocusManager.Create;
  try
    for I := 0 to 63 do
      LFocus.Register(TRect.Make(0, I, 4, 1));
    CheckEqual(64, LFocus.EntryCount, 'registered 64');
    LFocus.BeginFrame;
    CheckEqual(0, LFocus.EntryCount, 'BeginFrame clears entries');
  finally
    LFocus.Free;
  end;
end;

begin
  T := TTestSuite.Create('tui_stress_deep');
  T.Test('FocusManager stress register 1000', @TestFocusManagerStressRegister);
  T.Test('FocusManager stress navigate 1000', @TestFocusManagerStressNavigate);
  T.Test('FocusManager stress BeginFrame', @TestFocusManagerStressBeginFrame);
  T.Test('KeybindManager stress bind 1000', @TestKeybindManagerStressBind);
  T.Test('KeybindManager stress HandleKey 10000', @TestKeybindManagerStressHandleKey);
  T.Test('Animator stress start/cancel 64', @TestAnimatorStressStartCancel);
  T.Test('Animator stress tick 1000', @TestAnimatorStressTick);
  T.Test('LoadingGroup stress start 16', @TestLoadingGroupStressStart);
  T.Test('FrameBudget stress 1000 frames', @TestFrameBudgetStressFrames);
  T.Test('Transition stress advance', @TestTransitionStressAdvance);
  T.Test('Transition stress reset 1000', @TestTransitionStressReset);
  T.Test('FocusManager stress BeginFrame clears', @TestFocusManagerStressUnregisterAll);
  if not T.Run then Halt(1);
end.
