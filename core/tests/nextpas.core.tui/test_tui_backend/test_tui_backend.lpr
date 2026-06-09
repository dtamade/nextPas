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

const
  TEST_STDOUT_FD = 1;

function PendingString(ABackend: TAnsiBackend): AnsiString;
var
  LLen: Integer;
begin
  LLen := ABackend.PendingLength;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(ABackend.PendingBytes^, Result[1], LLen);
end;

function StyledCell(ACh: AnsiChar; const AStyle: TStyle): TCell;
begin
  CellReset(Result);
  CellSetSymbolAscii(Result, ACh);
  CellApplyStyle(Result, AStyle);
end;

function WideCell(const ABytes: array of Byte; AWidth: Byte;
  const AStyle: TStyle): TCell;
begin
  CellReset(Result);
  CellSetSymbolBytes(Result, ABytes[0], Length(ABytes), AWidth);
  CellApplyStyle(Result, AStyle);
end;

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

procedure TestTestBackendWideGlyphCursorParity;
var
  LBE: TTestBackend;
  LPatches: TDiffEntries;
  LCell: TCell;
  LBytes: array[0..2] of Byte;
begin
  LBE := TTestBackend.Create(TRect.Make(0, 0, 4, 1));
  try
    SetLength(LPatches, 1);
    LBytes[0] := $E4;
    LBytes[1] := $B8;
    LBytes[2] := $AD;
    CellReset(LCell);
    CellSetSymbolBytes(LCell, LBytes, 3, 2);
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := LCell;

    LBE.DrawPatches(LPatches);

    CheckEqual(Int64(2), Int64(LBE.CursorX),
      'wide glyph advances cursor by its display width');
    CheckEqual(Int64(0), Int64(LBE.CursorY), 'wide glyph keeps row');
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

procedure TestAnsiBackendFlushFailureRetainsPendingOutput;
var
  LBE: TAnsiBackend;
  LBefore: AnsiString;
  LBeforeLen: Integer;
begin
  LBE := TAnsiBackend.Create(-1);
  try
    LBE.HideCursor;
    LBefore := PendingString(LBE);
    LBeforeLen := LBE.PendingLength;
    Check(LBeforeLen > 0, 'pending after hide cursor');
    Check(not LBE.Flush, 'flush fails for invalid fd');
    CheckEqual(Int64(LBeforeLen), Int64(LBE.PendingLength),
      'pending length retained after failed flush');
    CheckEqual(LBefore, PendingString(LBE),
      'pending bytes retained after failed flush');
  finally
    LBE.Free;
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

procedure TestAnsiBackendEnterAlternateClickTracking;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.EnterAlternate(amMouseClick, False);
    CheckEqual(#27'[?1049h'#27'[?1000h'#27'[?1006h', PendingString(LBE),
      'enter alternate enables alt screen before click tracking');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendEnterAlternateScrollOnly;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.EnterAlternate(amMouseNone, True);
    CheckEqual(#27'[?1049h'#27'[?1007h', PendingString(LBE),
      'enter alternate can enable alternate scroll without mouse tracking');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendLeaveAlternateDisablesModesBeforeLeaving;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.LeaveAlternate(amMouseDrag, True);
    CheckEqual(#27'[0m'#27'[?1002l'#27'[?1006l'#27'[?1007l'#27'[?1049l',
      PendingString(LBE),
      'leave alternate resets sgr and disables drag/scroll before leaving alt screen');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendDrawPatchesReusesCursorAndStyleForAdjacentCells;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := StyledCell('A', StyleDefault.WithFg(TUI_RED));
    LPatches[1].X := 1;
    LPatches[1].Y := 0;
    LPatches[1].Cell := StyledCell('B', StyleDefault.WithFg(TUI_RED));

    LBE.DrawPatchesN(LPatches, 2);
    CheckEqual(#27'[1;1H'#27'[0m'#27'[31mAB', PendingString(LBE),
      'adjacent same-style cells reuse cursor and style state');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendDrawPatchesResetsStyleForDefaultCell;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := StyledCell('A', StyleDefault.WithFg(TUI_RED));
    LPatches[1].X := 1;
    LPatches[1].Y := 0;
    LPatches[1].Cell := StyledCell('B', StyleDefault);

    LBE.DrawPatchesN(LPatches, 2);
    CheckEqual(#27'[1;1H'#27'[0m'#27'[31mA'#27'[0mB', PendingString(LBE),
      'style reset prevents color bleed into default cell');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendDrawPatchesReappliesStyleOnStyleChange;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := StyledCell('A', StyleDefault.WithFg(TUI_RED));
    LPatches[1].X := 1;
    LPatches[1].Y := 0;
    LPatches[1].Cell := StyledCell('B', StyleDefault.WithFg(TUI_BLUE));

    LBE.DrawPatchesN(LPatches, 2);
    CheckEqual(#27'[1;1H'#27'[0m'#27'[31mA'#27'[0m'#27'[34mB',
      PendingString(LBE),
      'style change resets and reapplies sgr without extra cursor move');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendDrawPatchesWideGlyphAdvancesCursor;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := WideCell([$E4, $B8, $AD], 2, StyleDefault);
    LPatches[1].X := 2;
    LPatches[1].Y := 0;
    LPatches[1].Cell := StyledCell('!', StyleDefault);

    LBE.DrawPatchesN(LPatches, 2);
    CheckEqual(#27'[1;1H'#27'[0m'#$E4#$B8#$AD'!', PendingString(LBE),
      'wide glyph advances cursor without redundant move');
  finally
    LBE.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.backend');
  T.Run('test backend draw patches', @TestTestBackendDrawPatches);
  T.Run('test backend cursor', @TestTestBackendCursor);
  T.Run('test backend alternate', @TestTestBackendAlternate);
  T.Run('test backend wide glyph cursor parity',
    @TestTestBackendWideGlyphCursorParity);
  T.Run('ansi backend flush', @TestAnsiBackendFlush);
  T.Run('ansi backend flush failure retains pending output',
    @TestAnsiBackendFlushFailureRetainsPendingOutput);
  T.Run('ansi backend draw patches output', @TestAnsiBackendDrawPatchesOutput);
  T.Run('ansi backend enter alternate click tracking',
    @TestAnsiBackendEnterAlternateClickTracking);
  T.Run('ansi backend enter alternate scroll only',
    @TestAnsiBackendEnterAlternateScrollOnly);
  T.Run('ansi backend leave alternate disables modes before leaving',
    @TestAnsiBackendLeaveAlternateDisablesModesBeforeLeaving);
  T.Run('ansi backend draw patches reuses cursor and style',
    @TestAnsiBackendDrawPatchesReusesCursorAndStyleForAdjacentCells);
  T.Run('ansi backend draw patches resets style for default cell',
    @TestAnsiBackendDrawPatchesResetsStyleForDefaultCell);
  T.Run('ansi backend draw patches reapplies style on change',
    @TestAnsiBackendDrawPatchesReappliesStyleOnStyleChange);
  T.Run('ansi backend draw patches wide glyph advances cursor',
    @TestAnsiBackendDrawPatchesWideGlyphAdvancesCursor);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
