program test_tui_keybind;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.event,
  nextpas.core.tui.keybind,
  nextpas.core.test;

var
  T: TTestSuite;
  GActionCalled: Boolean;

procedure DummyAction;
begin
  GActionCalled := True;
end;

procedure TestKeybindManagerCreate;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  Check(LMgr.BindingCount = 0, 'New manager should have 0 bindings');
  Check(LMgr.Mode = kmNormal, 'Default mode should be kmNormal');
  LMgr.Free;
end;

procedure TestKeybindManagerSetMode;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  LMgr.SetMode(kmInsert);
  Check(LMgr.Mode = kmInsert, 'Mode should be kmInsert');
  LMgr.SetMode(kmVisual);
  Check(LMgr.Mode = kmVisual, 'Mode should be kmVisual');
  LMgr.SetMode(kmCommand);
  Check(LMgr.Mode = kmCommand, 'Mode should be kmCommand');
  LMgr.Free;
end;

procedure TestKeybindManagerBindChar;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  LMgr.BindChar(kmNormal, 'q', @DummyAction, 'Quit');
  Check(LMgr.BindingCount = 1, 'Should have 1 binding');
  Check(LMgr.GetBinding(0).Mode = kmNormal, 'Binding mode should be kmNormal');
  Check(LMgr.GetBinding(0).Code = kcChar, 'Binding code should be kcChar');
  Check(LMgr.GetBinding(0).Ch = Ord('q'), 'Binding char should be q');
  Check(LMgr.GetBinding(0).Description = 'Quit', 'Description should be Quit');
  LMgr.Free;
end;

procedure TestKeybindManagerBindCtrl;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  LMgr.BindCtrl(kmNormal, 'c', @DummyAction, 'Copy');
  Check(LMgr.BindingCount = 1, 'Should have 1 binding');
  Check(LMgr.GetBinding(0).Modifiers = [kmCtrl], 'Should have Ctrl modifier');
  LMgr.Free;
end;

procedure TestKeybindManagerBindAlt;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  LMgr.BindAlt(kmNormal, 'x', @DummyAction, 'Cut');
  Check(LMgr.BindingCount = 1, 'Should have 1 binding');
  Check(LMgr.GetBinding(0).Modifiers = [kmAlt], 'Should have Alt modifier');
  LMgr.Free;
end;

procedure TestKeybindManagerBindKey;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  LMgr.BindKey(kmNormal, kcEnter, @DummyAction, 'Confirm');
  Check(LMgr.BindingCount = 1, 'Should have 1 binding');
  Check(LMgr.GetBinding(0).Code = kcEnter, 'Binding code should be kcEnter');
  Check(LMgr.GetBinding(0).Ch = 0, 'Char should be 0 for non-char keys');
  LMgr.Free;
end;

procedure TestKeybindManagerBindMultiple;
var
  LMgr: TKeybindManager;
begin
  LMgr := TKeybindManager.Create;
  LMgr.BindChar(kmNormal, 'q', @DummyAction, 'Quit');
  LMgr.BindChar(kmNormal, 'w', @DummyAction, 'Write');
  LMgr.BindKey(kmNormal, kcEsc, @DummyAction, 'Escape');
  Check(LMgr.BindingCount = 3, 'Should have 3 bindings');
  LMgr.Free;
end;

procedure TestKeybindManagerHandleKeyMatch;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  GActionCalled := False;
  LMgr := TKeybindManager.Create;
  LMgr.BindChar(kmNormal, 'q', @DummyAction, 'Quit');
  LKey.Code := kcChar;
  LKey.Ch := Ord('q');
  LKey.Modifiers := [];
  LHandled := LMgr.HandleKey(LKey);
  Check(LHandled, 'Should handle q key');
  Check(GActionCalled, 'Action should be called');
  LMgr.Free;
end;

procedure TestKeybindManagerHandleKeyNoMatch;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  GActionCalled := False;
  LMgr := TKeybindManager.Create;
  LMgr.BindChar(kmNormal, 'q', @DummyAction, 'Quit');
  LKey.Code := kcChar;
  LKey.Ch := Ord('x');
  LKey.Modifiers := [];
  LHandled := LMgr.HandleKey(LKey);
  Check(not LHandled, 'Should not handle x key');
  Check(not GActionCalled, 'Action should not be called');
  LMgr.Free;
end;

procedure TestKeybindManagerHandleKeyModeMismatch;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  GActionCalled := False;
  LMgr := TKeybindManager.Create;
  LMgr.BindChar(kmNormal, 'q', @DummyAction, 'Quit');
  LMgr.SetMode(kmInsert);
  LKey.Code := kcChar;
  LKey.Ch := Ord('q');
  LKey.Modifiers := [];
  LHandled := LMgr.HandleKey(LKey);
  Check(not LHandled, 'Should not handle in wrong mode');
  Check(not GActionCalled, 'Action should not be called');
  LMgr.Free;
end;

procedure TestKeybindManagerHandleKeyCtrl;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  GActionCalled := False;
  LMgr := TKeybindManager.Create;
  LMgr.BindCtrl(kmNormal, 'c', @DummyAction, 'Copy');
  LKey.Code := kcChar;
  LKey.Ch := Ord('c');
  LKey.Modifiers := [kmCtrl];
  LHandled := LMgr.HandleKey(LKey);
  Check(LHandled, 'Should handle Ctrl+C');
  Check(GActionCalled, 'Action should be called');
  LMgr.Free;
end;

procedure TestKeybindManagerHandleKeyEnter;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  LHandled: Boolean;
begin
  GActionCalled := False;
  LMgr := TKeybindManager.Create;
  LMgr.BindKey(kmNormal, kcEnter, @DummyAction, 'Confirm');
  LKey.Code := kcEnter;
  LKey.Ch := 0;
  LKey.Modifiers := [];
  LHandled := LMgr.HandleKey(LKey);
  Check(LHandled, 'Should handle Enter');
  Check(GActionCalled, 'Action should be called');
  LMgr.Free;
end;

procedure TestKeybindManagerHelpText;
var
  LMgr: TKeybindManager;
  LHelp: AnsiString;
begin
  LMgr := TKeybindManager.Create;
  LMgr.BindChar(kmNormal, 'q', @DummyAction, 'Quit');
  LMgr.BindKey(kmNormal, kcEnter, @DummyAction, 'Confirm');
  LHelp := LMgr.HelpText;
  Check(Length(LHelp) > 0, 'Help text should not be empty');
  LMgr.Free;
end;

begin
  T := TTestSuite.Create('tui_keybind');
  T.Test('TKeybindManager.Create', @TestKeybindManagerCreate);
  T.Test('TKeybindManager.SetMode', @TestKeybindManagerSetMode);
  T.Test('TKeybindManager.BindChar', @TestKeybindManagerBindChar);
  T.Test('TKeybindManager.BindCtrl', @TestKeybindManagerBindCtrl);
  T.Test('TKeybindManager.BindAlt', @TestKeybindManagerBindAlt);
  T.Test('TKeybindManager.BindKey', @TestKeybindManagerBindKey);
  T.Test('TKeybindManager.BindMultiple', @TestKeybindManagerBindMultiple);
  T.Test('TKeybindManager.HandleKey match', @TestKeybindManagerHandleKeyMatch);
  T.Test('TKeybindManager.HandleKey no match', @TestKeybindManagerHandleKeyNoMatch);
  T.Test('TKeybindManager.HandleKey mode mismatch', @TestKeybindManagerHandleKeyModeMismatch);
  T.Test('TKeybindManager.HandleKey Ctrl', @TestKeybindManagerHandleKeyCtrl);
  T.Test('TKeybindManager.HandleKey Enter', @TestKeybindManagerHandleKeyEnter);
  T.Test('TKeybindManager.HelpText', @TestKeybindManagerHelpText);
  if not T.Run then Halt(1);
end.
