program test_tui_backend;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.builder,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.backend.test,
  nextpas.core.platform.console,
  nextpas.core.platform.posix.ffi,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === TTestBackend 测试 === }

procedure TestTestBackendDrawPatches;
var
  LBE: TTestBackend;
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LLines: TBufferLines;
begin
  LBE := TTestBackend.Create(TRect.Make(0, 0, 4, 1));
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LPrev.SetString(0, 0, '    ', StyleDefault);
    LCurr.SetString(0, 0, 'Hi  ', StyleDefault);
    LPrev.Diff(LCurr, LPatches);
    LBE.DrawPatches(LPatches);
    LLines := LBE.Buffer.AsLines;
    CheckEqual('Hi  ', LLines[0], 'test backend renders patches');
  finally
    LBE.Free; LPrev.Free; LCurr.Free;
  end;
end;

procedure TestTestBackendCursor;
var
  LBE: TTestBackend;
begin
  LBE := TTestBackend.Create(TRect.Make(0, 0, 10, 5));
  try
    Check(LBE.CursorVisible, 'initially visible');
    LBE.HideCursor;
    Check(not LBE.CursorVisible, 'hidden');
    LBE.ShowCursor;
    Check(LBE.CursorVisible, 'shown again');
    LBE.MoveTo(3, 2);
    CheckEqual(Int64(3), Int64(LBE.CursorX), 'cursor x');
    CheckEqual(Int64(2), Int64(LBE.CursorY), 'cursor y');
  finally
    LBE.Free;
  end;
end;

procedure TestTestBackendAlternate;
var
  LBE: TTestBackend;
begin
  LBE := TTestBackend.Create(TRect.Make(0, 0, 5, 5));
  try
    Check(not LBE.OnAlternate, 'not alt initially');
    LBE.EnterAlternate;
    Check(LBE.OnAlternate, 'entered alt');
    LBE.LeaveAlternate;
    Check(not LBE.OnAlternate, 'left alt');
  finally
    LBE.Free;
  end;
end;

{ === TAnsiBackend 测试（用 pipe 验证 flush 输出）=== }

procedure TestAnsiBackendFlush;
var
  LBE: TAnsiBackend;
  LFds: array[0..1] of Int32;
  LBuf: array[0..255] of Byte;
  LRead: Int32;
begin
  if pipe(@LFds[0]) <> 0 then begin Fail('pipe failed'); Exit; end;
  LBE := TAnsiBackend.Create(LFds[1]);
  try
    LBE.HideCursor;
    Check(LBE.PendingLength > 0, 'pending after hide cursor');
    Check(LBE.Flush, 'flush succeeds');
    CheckEqual(Int64(0), Int64(LBE.PendingLength), 'pending cleared after flush');
    { 从读端验证字节 }
    LRead := platform_console_read(LFds[0], @LBuf[0], 256);
    Check(LRead > 0, 'bytes flushed to pipe');
  finally
    LBE.Free;
    close(LFds[0]);
    close(LFds[1]);
  end;
end;

procedure TestAnsiBackendDrawPatchesOutput;
var
  LBE: TAnsiBackend;
  LFds: array[0..1] of Int32;
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LBuf: array[0..1023] of Byte;
  LRead: Int32;
  LStr: AnsiString;
begin
  if pipe(@LFds[0]) <> 0 then begin Fail('pipe failed'); Exit; end;
  LBE := TAnsiBackend.Create(LFds[1]);
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LPrev.SetString(0, 0, '   ', StyleDefault);
    LCurr.SetString(0, 0, 'A  ', StyleDefault.WithFg(TUI_RED));
    LPrev.Diff(LCurr, LPatches);
    LBE.DrawPatches(LPatches);
    LBE.Flush;
    LRead := platform_console_read(LFds[0], @LBuf[0], 1024);
    Check(LRead > 0, 'output produced');
    SetLength(LStr, LRead);
    Move(LBuf[0], LStr[1], LRead);
    { 应包含 MoveTo + SGR + 'A' }
    Check(Pos('A', LStr) > 0, 'contains glyph A');
    Check(Pos(#27'[', LStr) > 0, 'contains CSI');
  finally
    LBE.Free; LPrev.Free; LCurr.Free;
    close(LFds[0]); close(LFds[1]);
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.backend');
  T.Run('test backend draw patches', @TestTestBackendDrawPatches);
  T.Run('test backend cursor', @TestTestBackendCursor);
  T.Run('test backend alternate', @TestTestBackendAlternate);
  T.Run('ansi backend flush', @TestAnsiBackendFlush);
  T.Run('ansi backend draw patches output', @TestAnsiBackendDrawPatchesOutput);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
