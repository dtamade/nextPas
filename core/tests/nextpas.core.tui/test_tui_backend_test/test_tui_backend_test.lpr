program test_tui_backend_test;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.backend.test,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestBackendCreate;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  Check(LBackend.Buffer <> nil, 'Buffer should be created');
  Check(LBackend.CursorVisible = True, 'Cursor should be visible initially');
  Check(LBackend.CursorX = 0, 'CursorX should be 0');
  Check(LBackend.CursorY = 0, 'CursorY should be 0');
  Check(LBackend.OnAlternate = False, 'Should not be on alternate');
  LBackend.Free;
end;

procedure TestBackendHideShowCursor;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  LBackend.HideCursor;
  Check(LBackend.CursorVisible = False, 'Cursor should be hidden');
  LBackend.ShowCursor;
  Check(LBackend.CursorVisible = True, 'Cursor should be visible');
  LBackend.Free;
end;

procedure TestBackendEnterLeaveAlternate;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  LBackend.EnterAlternate;
  Check(LBackend.OnAlternate = True, 'Should be on alternate');
  LBackend.LeaveAlternate;
  Check(LBackend.OnAlternate = False, 'Should not be on alternate');
  LBackend.Free;
end;

procedure TestBackendMoveTo;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  LBackend.MoveTo(5, 3);
  Check(LBackend.CursorX = 5, 'CursorX should be 5');
  Check(LBackend.CursorY = 3, 'CursorY should be 3');
  LBackend.Free;
end;

procedure TestBackendFlush;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  Check(LBackend.Flush = True, 'Flush should return True');
  LBackend.Free;
end;

procedure TestBackendClearScreen;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  LBackend.ClearScreen;
  Check(True, 'ClearScreen should not crash');
  LBackend.Free;
end;

procedure TestBackendResetState;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  LBackend.HideCursor;
  LBackend.EnterAlternate;
  LBackend.MoveTo(5, 3);
  LBackend.ResetState;
  Check(LBackend.CursorVisible = True, 'Cursor should be visible after reset');
  Check(LBackend.OnAlternate = False, 'Should not be on alternate after reset');
  Check(LBackend.CursorX = 0, 'CursorX should be 0 after reset');
  Check(LBackend.CursorY = 0, 'CursorY should be 0 after reset');
  LBackend.Free;
end;

begin
  T := TTestSuite.Create('tui_backend_test');
  T.Test('TTestBackend.Create', @TestBackendCreate);
  T.Test('TTestBackend.HideCursor/ShowCursor', @TestBackendHideShowCursor);
  T.Test('TTestBackend.EnterAlternate/LeaveAlternate', @TestBackendEnterLeaveAlternate);
  T.Test('TTestBackend.MoveTo', @TestBackendMoveTo);
  T.Test('TTestBackend.Flush', @TestBackendFlush);
  T.Test('TTestBackend.ClearScreen', @TestBackendClearScreen);
  T.Test('TTestBackend.ResetState', @TestBackendResetState);
  if not T.Run then Halt(1);
end.
