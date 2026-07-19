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

procedure TestBackendMoveToOrigin;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 8, 4));
  try
    LBackend.MoveTo(3, 2);
    LBackend.MoveTo(0, 0);
    CheckEqual(0, LBackend.CursorX, 'back to origin x');
    CheckEqual(0, LBackend.CursorY, 'back to origin y');
  finally
    LBackend.Free;
  end;
end;

procedure TestBackendHideThenResetShowsCursor;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 8, 4));
  try
    LBackend.HideCursor;
    Check(not LBackend.CursorVisible, 'hidden');
    LBackend.ResetState;
    Check(LBackend.CursorVisible, 'reset shows');
  finally
    LBackend.Free;
  end;
end;

procedure TestBackendBufferArea;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 12, 7));
  try
    CheckEqual(12, LBackend.Buffer.Area.Width, 'buffer width');
    CheckEqual(7, LBackend.Buffer.Area.Height, 'buffer height');
  finally
    LBackend.Free;
  end;
end;

procedure TestBackendEnterTwiceIdempotent;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 8, 4));
  try
    LBackend.EnterAlternate;
    LBackend.EnterAlternate;
    Check(LBackend.OnAlternate, 'still alternate');
  finally
    LBackend.Free;
  end;
end;

procedure TestBackendFlushAfterMove;
var
  LBackend: TTestBackend;
begin
  LBackend := TTestBackend.Create(TRect.Make(0, 0, 8, 4));
  try
    LBackend.MoveTo(1, 1);
    Check(LBackend.Flush, 'flush ok');
    CheckEqual(1, LBackend.CursorX, 'cursor kept after flush');
  finally
    LBackend.Free;
  end;
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
  T.Test('MoveTo origin', @TestBackendMoveToOrigin);
  T.Test('Hide then Reset shows cursor', @TestBackendHideThenResetShowsCursor);
  T.Test('Buffer area', @TestBackendBufferArea);
  T.Test('EnterAlternate twice', @TestBackendEnterTwiceIdempotent);
  T.Test('Flush after move', @TestBackendFlushAfterMove);
  if not T.Run then Halt(1);
end.
