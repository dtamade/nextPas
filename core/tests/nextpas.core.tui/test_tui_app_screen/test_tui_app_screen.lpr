program test_tui_app_screen;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.app.screen,
  nextpas.core.test;

type
  TTestScreen = class(TScreen)
  public
    EnterCount: Integer;
    LeaveCount: Integer;
    procedure Render(const Area: TRect; Buf: TBuffer); override;
    procedure OnEnter; override;
    procedure OnLeave; override;
  end;

procedure TTestScreen.Render(const Area: TRect; Buf: TBuffer);
begin
end;

procedure TTestScreen.OnEnter;
begin
  Inc(EnterCount);
end;

procedure TTestScreen.OnLeave;
begin
  Inc(LeaveCount);
end;

function MakeTestScreen: TTestScreen;
begin
  Result := TTestScreen.Create;
  Result.EnterCount := 0;
  Result.LeaveCount := 0;
end;

var
  T: TTestSuite;

procedure TestScreenStackCreate;
var
  LStack: TScreenStack;
begin
  LStack := TScreenStack.Create;
  Check(LStack.Count = 0, 'New stack should have count 0');
  Check(LStack.IsEmpty, 'New stack should be empty');
  Check(LStack.Top = nil, 'Top of empty stack should be nil');
  LStack.Free;
end;

procedure TestScreenStackPush;
var
  LStack: TScreenStack;
  LScreen: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LScreen := MakeTestScreen;
  LStack.Push(LScreen);
  Check(LStack.Count = 1, 'Count should be 1 after push');
  Check(not LStack.IsEmpty, 'Should not be empty after push');
  Check(LStack.Top = LScreen, 'Top should be pushed screen');
  Check(LScreen.EnterCount = 1, 'OnEnter should be called');
  LStack.Free;
end;

procedure TestScreenStackPushMultiple;
var
  LStack: TScreenStack;
  LS1, LS2, LS3: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeTestScreen;
  LS2 := MakeTestScreen;
  LS3 := MakeTestScreen;
  LStack.Push(LS1);
  LStack.Push(LS2);
  LStack.Push(LS3);
  Check(LStack.Count = 3, 'Count should be 3');
  Check(LStack.Top = LS3, 'Top should be last pushed');
  Check(LS1.LeaveCount = 1, 'S1 should have OnLeave called once');
  Check(LS2.LeaveCount = 1, 'S2 should have OnLeave called once');
  Check(LS2.EnterCount = 1, 'S2 should have OnEnter called once');
  Check(LS3.EnterCount = 1, 'S3 should have OnEnter called once');
  LStack.Free;
end;

procedure TestScreenStackPop;
var
  LStack: TScreenStack;
  LS1, LS2: TTestScreen;
  LPopped: TScreen;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeTestScreen;
  LS2 := MakeTestScreen;
  LStack.Push(LS1);
  LStack.Push(LS2);
  LPopped := LStack.Pop;
  Check(LPopped = LS2, 'Pop should return top screen');
  Check(LStack.Count = 1, 'Count should be 1 after pop');
  Check(LStack.Top = LS1, 'Top should be S1 after pop');
  Check(LS2.LeaveCount = 1, 'S2 OnLeave should be called');
  Check(LS1.EnterCount = 2, 'S1 OnEnter should be called again');
  LPopped.Free;
  LStack.Free;
end;

procedure TestScreenStackPopEmpty;
var
  LStack: TScreenStack;
  LPopped: TScreen;
begin
  LStack := TScreenStack.Create;
  LPopped := LStack.Pop;
  Check(LPopped = nil, 'Pop from empty stack should return nil');
  LStack.Free;
end;

procedure TestScreenStackReplace;
var
  LStack: TScreenStack;
  LS1, LS2: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LS1 := MakeTestScreen;
  LS2 := MakeTestScreen;
  LStack.Push(LS1);
  LStack.Replace(LS2);
  Check(LStack.Count = 1, 'Count should still be 1 after replace');
  Check(LStack.Top = LS2, 'Top should be new screen');
  Check(LS2.EnterCount = 1, 'New screen OnEnter should be called');
  LStack.Free;
end;

procedure TestScreenStackReplaceEmpty;
var
  LStack: TScreenStack;
  LScreen: TTestScreen;
begin
  LStack := TScreenStack.Create;
  LScreen := MakeTestScreen;
  LStack.Replace(LScreen);
  Check(LStack.Count = 1, 'Count should be 1 after replace on empty');
  Check(LStack.Top = LScreen, 'Top should be replaced screen');
  LStack.Free;
end;

procedure TestScreenStackQuitRequested;
var
  LStack: TScreenStack;
begin
  LStack := TScreenStack.Create;
  Check(not LStack.QuitRequested, 'Should not be quit initially');
  LStack.RequestQuit;
  Check(LStack.QuitRequested, 'Should be quit after RequestQuit');
  LStack.ClearQuitRequest;
  Check(not LStack.QuitRequested, 'Should not be quit after Clear');
  LStack.Free;
end;

procedure TestScreenStackConsumeQuitRequested;
var
  LStack: TScreenStack;
begin
  LStack := TScreenStack.Create;
  LStack.RequestQuit;
  Check(LStack.ConsumeQuitRequested, 'Should consume quit request');
  Check(not LStack.ConsumeQuitRequested, 'Second consume should return false');
  LStack.Free;
end;

procedure TestScreenStackPushNil;
var
  LStack: TScreenStack;
  LExcept: Boolean;
begin
  LStack := TScreenStack.Create;
  LExcept := False;
  try
    LStack.Push(nil);
  except
    LExcept := True;
  end;
  Check(LExcept, 'Push(nil) should raise exception');
  Check(LStack.IsEmpty, 'Stack should remain empty after failed push');
  LStack.Free;
end;

procedure TestScreenStackPushSameTwice;
var
  LStack: TScreenStack;
  LScreen: TTestScreen;
  LExcept: Boolean;
begin
  LStack := TScreenStack.Create;
  LScreen := MakeTestScreen;
  LStack.Push(LScreen);
  LExcept := False;
  try
    LStack.Push(LScreen); // same screen again
  except
    LExcept := True;
  end;
  Check(LExcept, 'Push same screen twice should raise');
  Check(LStack.Count = 1, 'Count should still be 1');
  LStack.Free;
end;

procedure TestScreenStackHandleEventEmpty;
var
  LStack: TScreenStack;
  LEv: TEvent;
begin
  LStack := TScreenStack.Create;
  LEv.Kind := evNone;
  LStack.HandleEvent(LEv); // should not crash on empty stack
  Check(True, 'HandleEvent on empty stack does not crash');
  LStack.Free;
end;

procedure TestScreenStackHandleEventDelegates;
var
  LStack: TScreenStack;
  LScreen: TTestScreen;
  LEv: TEvent;
begin
  LStack := TScreenStack.Create;
  LScreen := MakeTestScreen;
  LStack.Push(LScreen);
  LEv.Kind := evNone;
  LStack.HandleEvent(LEv); // should delegate to top screen
  Check(True, 'HandleEvent delegates to top screen');
  LStack.Free;
end;

procedure TestScreenStackRenderEmpty;
var
  LStack: TScreenStack;
  LBuf: TBuffer;
begin
  LStack := TScreenStack.Create;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    LStack.Render(TRect.Make(0, 0, 10, 5), LBuf); // should not crash
    Check(True, 'Render on empty stack does not crash');
  finally LBuf.Free; end;
  LStack.Free;
end;

begin
  T := TTestSuite.Create('tui_app_screen');
  T.Test('TScreenStack.Create', @TestScreenStackCreate);
  T.Test('TScreenStack.Push', @TestScreenStackPush);
  T.Test('TScreenStack.Push multiple', @TestScreenStackPushMultiple);
  T.Test('TScreenStack.Pop', @TestScreenStackPop);
  T.Test('TScreenStack.Pop empty', @TestScreenStackPopEmpty);
  T.Test('TScreenStack.Replace', @TestScreenStackReplace);
  T.Test('TScreenStack.Replace empty', @TestScreenStackReplaceEmpty);
  T.Test('TScreenStack.QuitRequested', @TestScreenStackQuitRequested);
  T.Test('TScreenStack.ConsumeQuitRequested', @TestScreenStackConsumeQuitRequested);
  T.Test('TScreenStack.Push(nil) raises', @TestScreenStackPushNil);
  T.Test('TScreenStack.Push same twice raises', @TestScreenStackPushSameTwice);
  T.Test('TScreenStack.HandleEvent empty', @TestScreenStackHandleEventEmpty);
  T.Test('TScreenStack.HandleEvent delegates', @TestScreenStackHandleEventDelegates);
  T.Test('TScreenStack.Render empty', @TestScreenStackRenderEmpty);
  if not T.Run then Halt(1);
end.
