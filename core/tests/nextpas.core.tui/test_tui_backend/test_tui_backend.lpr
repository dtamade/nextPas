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
  nextpas.core.tui.ansi,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.backend.test,
  nextpas.core.platform.console,
  nextpas.core.platform.posix.ffi,
  nextpas.core.test;

var
  T: TTestSuite;

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
    CheckEqual(#27'[?1049h'#27'[?7l'#27'[?1000h'#27'[?1006h', PendingString(LBE),
      'enter alternate: alt + wrap off + click tracking');
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
    CheckEqual(#27'[?1049h'#27'[?7l'#27'[?1007h', PendingString(LBE),
      'enter alternate: alt + wrap off + alternate scroll');
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
    CheckEqual(#27'[0m'#27'[?1002l'#27'[?1006l'#27'[?1007l'#27'[?7h'#27'[?1049l',
      PendingString(LBE),
      'leave alternate: disable modes + wrap on before leave alt');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendKittyKeyboardPushDefaultFlags;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.PushKittyKeyboard;
    CheckEqual(#27'[=5;1u', PendingString(LBE),
      'kitty keyboard push emits CSI = flags;1 u with default flags=5');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendKittyKeyboardPushCustomFlags;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.PushKittyKeyboard(1);
    CheckEqual(#27'[=1;1u', PendingString(LBE),
      'kitty keyboard push accepts custom flags');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendKittyKeyboardPop;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.PopKittyKeyboard;
    CheckEqual(#27'[<u', PendingString(LBE),
      'kitty keyboard pop emits CSI < u');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendKittyKeyboardQuery;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.QueryKittyKeyboard;
    CheckEqual(#27'[?u', PendingString(LBE),
      'kitty keyboard query emits CSI ? u');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendKittyKeyboardPushPopIndependentOfMouse;
var
  LBE: TAnsiBackend;
  LStr: AnsiString;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.EnterAlternate(amMouseNone, False);
    LBE.PushKittyKeyboard;
    LStr := PendingString(LBE);
    Check(Pos(#27'[?1049h', LStr) > 0, 'alt screen still present');
    Check(Pos(#27'[=5;1u', LStr) > 0, 'kitty push after alt screen');
    Check(Pos(#27'[?1000h', LStr) = 0, 'no mouse tracking when amMouseNone');
    LBE.DiscardPending;
    LBE.PopKittyKeyboard;
    CheckEqual(#27'[<u', PendingString(LBE), 'pop is a single sequence');
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

procedure TestAnsiBackendDrawPatchesAppliesUnderlineColor;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := StyledCell('A',
      StyleDefault.WithUnderline(TUI_BLUE).WithModifier([mbUnderlined]));
    LPatches[1].X := 1;
    LPatches[1].Y := 0;
    LPatches[1].Cell := StyledCell('B',
      StyleDefault.WithUnderline(ResetColor).WithModifier([mbUnderlined]));

    LBE.DrawPatchesN(LPatches, 2);
    CheckEqual(#27'[1;1H'#27'[0m'#27'[58;5;4m'#27'[4mA' +
      #27'[0m'#27'[4mB', PendingString(LBE),
      'underline color is emitted and reset by sgr reset before default color cell');
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


procedure TestAnsiBackendFocusReportingEnableDisable;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.EnableFocusReporting;
    Check(Pos(#27'[?1004h', PendingString(LBE)) > 0, 'enable 1004h');
    LBE.DiscardPending;
    LBE.DisableFocusReporting;
    CheckEqual(#27'[?1004l', PendingString(LBE), 'disable 1004l');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendBracketedPasteEnableDisable;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.EnableBracketedPaste;
    CheckEqual(#27'[?2004h', PendingString(LBE), 'enable 2004h');
    LBE.DiscardPending;
    LBE.DisableBracketedPaste;
    CheckEqual(#27'[?2004l', PendingString(LBE), 'disable 2004l');
  finally
    LBE.Free;
  end;
end;

procedure TestAnsiBackendSynchronizedUpdateBeginEnd;
var
  LBE: TAnsiBackend;
begin
  LBE := TAnsiBackend.Create(TEST_STDOUT_FD);
  try
    LBE.BeginSynchronizedUpdate;
    CheckEqual(#27'[?2026h', PendingString(LBE), 'begin 2026h');
    LBE.DiscardPending;
    LBE.EndSynchronizedUpdate;
    CheckEqual(#27'[?2026l', PendingString(LBE), 'end 2026l');
  finally
    LBE.Free;
  end;
end;


{ === OSC 8 超链接（刀 21）=== }

function EmptyLinkSpan: TTuiLinkSpan;
begin
  Result := Default(TTuiLinkSpan);
end;

procedure TestOsc8OpenNoId;
var
  LB: TStringBuilder;
begin
  LB.InitWith(64, nil);
  try
    AnsiOsc8Open(LB, 'https://example.com/x');
    CheckEqual(#27']8;;https://example.com/x'#7, LB.ToString,
      'open without id');
  finally
    LB.Done;
  end;
end;

procedure TestOsc8OpenWithId;
var
  LB: TStringBuilder;
begin
  LB.InitWith(64, nil);
  try
    AnsiOsc8Open(LB, 'https://example.com/x', 7);
    CheckEqual(#27']8;id=7;https://example.com/x'#7, LB.ToString,
      'open with id');
  finally
    LB.Done;
  end;
end;

procedure TestOsc8OpenStripsControlChars;
var
  LB: TStringBuilder;
begin
  LB.InitWith(64, nil);
  try
    AnsiOsc8Open(LB, 'https://a.b/'#27']8;evil'#7#10'x');
    CheckEqual(#27']8;;https://a.b/]8;evilx'#7, LB.ToString,
      'control chars stripped (no early terminate / inject)');
  finally
    LB.Done;
  end;
end;

procedure TestOsc8Close;
var
  LB: TStringBuilder;
begin
  LB.InitWith(64, nil);
  try
    AnsiOsc8Close(LB);
    CheckEqual(#27']8;;'#7, LB.ToString, 'close sequence');
  finally
    LB.Done;
  end;
end;

{ 链接区 [0..3) 被开/关包裹，非链接区不包 }
procedure TestOsc8DrawPatchesWrapsLinkSpan;
var
  LBE: TAnsiBackend;
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LLinks: array[0..0] of TTuiLinkSpan;
  LOut: AnsiString;
begin
  LBE := TAnsiBackend.Create(-1);
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LPrev.SetString(0, 0, '      ', StyleDefault);
    LCurr.SetString(0, 0, 'A B C ', StyleDefault);
    LPrev.Diff(LCurr, LPatches);

    LLinks[0] := EmptyLinkSpan;
    LLinks[0].Y := 0;
    LLinks[0].ColStart := 0;
    LLinks[0].ColEnd := 3;   { 覆盖 'A B' }
    LLinks[0].Url := 'file:///tmp/x.txt';
    LBE.SetLinkOverlay(LLinks);
    LBE.DrawPatches(LPatches);
    LOut := PendingString(LBE);

    Check(Pos(#27']8;;file:///tmp/x.txt'#7, LOut) > 0, 'open emitted');
    Check(Pos('B'#27']8;;'#7, LOut) > 0, 'close right after linked text B');
  finally
    LBE.Free; LPrev.Free; LCurr.Free;
  end;
end;

{ 同一行两段不同链接：切换处关→开；id 透传 }
procedure TestOsc8DrawPatchesLinkSwitch;
var
  LBE: TAnsiBackend;
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LLinks: array[0..1] of TTuiLinkSpan;
  LOut: AnsiString;
begin
  LBE := TAnsiBackend.Create(-1);
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LPrev.SetString(0, 0, '          ', StyleDefault);
    LCurr.SetString(0, 0, 'ABCDEFGHIJ', StyleDefault);
    LPrev.Diff(LCurr, LPatches);

    LLinks[0] := EmptyLinkSpan;
    LLinks[0].Y := 0;
    LLinks[0].ColStart := 0;
    LLinks[0].ColEnd := 3;   { ABC }
    LLinks[0].Url := 'https://one.example';
    LLinks[0].Id := 1;
    LLinks[1] := EmptyLinkSpan;
    LLinks[1].Y := 0;
    LLinks[1].ColStart := 5;
    LLinks[1].ColEnd := 8;   { FGH }
    LLinks[1].Url := 'https://two.example';
    LBE.SetLinkOverlay(LLinks);
    LBE.DrawPatches(LPatches);
    LOut := PendingString(LBE);

    Check(Pos(#27']8;id=1;https://one.example'#7, LOut) > 0,
      'first link open with id');
    Check(Pos('C'#27']8;;'#7'D', LOut) > 0, 'first link closes after C');
    Check(Pos(#27']8;;https://two.example'#7, LOut) > 0,
      'second link open');
    Check(Pos('H'#27']8;;'#7'I', LOut) > 0, 'second link closes after H');
  finally
    LBE.Free; LPrev.Free; LCurr.Free;
  end;
end;

{ 无 overlay：不产生任何 OSC 8 序列 }
procedure TestOsc8DrawPatchesNoOverlayNoWrap;
var
  LBE: TAnsiBackend;
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LOut: AnsiString;
begin
  LBE := TAnsiBackend.Create(-1);
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LPrev.SetString(0, 0, '    ', StyleDefault);
    LCurr.SetString(0, 0, 'TEST', StyleDefault);
    LPrev.Diff(LCurr, LPatches);
    { 未调 SetLinkOverlay：backend 保持空 overlay }
    LBE.DrawPatches(LPatches);
    LOut := PendingString(LBE);
    Check(Pos(#27']8', LOut) = 0, 'no osc8 without overlay');
  finally
    LBE.Free; LPrev.Free; LCurr.Free;
  end;
end;

{ 补丁流结束（行尾有未闭合链接）→ 显式关序列收尾 }
procedure TestOsc8DrawPatchesClosesAtEnd;
var
  LBE: TAnsiBackend;
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LLinks: array[0..0] of TTuiLinkSpan;
  LOut: AnsiString;
begin
  LBE := TAnsiBackend.Create(-1);
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LPrev.SetString(0, 0, '    ', StyleDefault);
    LCurr.SetString(0, 0, 'ABC ', StyleDefault);
    LPrev.Diff(LCurr, LPatches);

    LLinks[0] := EmptyLinkSpan;
    LLinks[0].Y := 0;
    LLinks[0].ColStart := 0;
    LLinks[0].ColEnd := 3;   { 链接覆盖 ABC，补丁流在行尾结束 }
    LLinks[0].Url := 'https://end.example';
    LBE.SetLinkOverlay(LLinks);
    LBE.DrawPatches(LPatches);
    LOut := PendingString(LBE);

    Check(Pos('C'#27']8;;'#7, LOut) > 0, 'trailing link closed at patch end');
  finally
    LBE.Free; LPrev.Free; LCurr.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.backend');
  T.Test('test backend draw patches', @TestTestBackendDrawPatches);
  T.Test('test backend cursor', @TestTestBackendCursor);
  T.Test('test backend alternate', @TestTestBackendAlternate);
  T.Test('test backend wide glyph cursor parity',
    @TestTestBackendWideGlyphCursorParity);
  T.Test('ansi backend flush', @TestAnsiBackendFlush);
  T.Test('ansi backend flush failure retains pending output',
    @TestAnsiBackendFlushFailureRetainsPendingOutput);
  T.Test('ansi backend draw patches output', @TestAnsiBackendDrawPatchesOutput);
  T.Test('ansi backend enter alternate click tracking',
    @TestAnsiBackendEnterAlternateClickTracking);
  T.Test('ansi backend enter alternate scroll only',
    @TestAnsiBackendEnterAlternateScrollOnly);
  T.Test('ansi backend leave alternate disables modes before leaving',
    @TestAnsiBackendLeaveAlternateDisablesModesBeforeLeaving);
  T.Test('ansi backend kitty keyboard push default flags',
    @TestAnsiBackendKittyKeyboardPushDefaultFlags);
  T.Test('ansi backend kitty keyboard push custom flags',
    @TestAnsiBackendKittyKeyboardPushCustomFlags);
  T.Test('ansi backend kitty keyboard pop',
    @TestAnsiBackendKittyKeyboardPop);
  T.Test('ansi backend kitty keyboard query',
    @TestAnsiBackendKittyKeyboardQuery);
  T.Test('ansi backend kitty keyboard push pop independent of mouse',
    @TestAnsiBackendKittyKeyboardPushPopIndependentOfMouse);
  T.Test('ansi backend draw patches reuses cursor and style',
    @TestAnsiBackendDrawPatchesReusesCursorAndStyleForAdjacentCells);
  T.Test('ansi backend draw patches resets style for default cell',
    @TestAnsiBackendDrawPatchesResetsStyleForDefaultCell);
  T.Test('ansi backend draw patches reapplies style on change',
    @TestAnsiBackendDrawPatchesReappliesStyleOnStyleChange);
  T.Test('ansi backend draw patches applies underline color',
    @TestAnsiBackendDrawPatchesAppliesUnderlineColor);
  T.Test('ansi backend draw patches wide glyph advances cursor',
    @TestAnsiBackendDrawPatchesWideGlyphAdvancesCursor);
  T.Test('ansi backend focus reporting enable disable',
    @TestAnsiBackendFocusReportingEnableDisable);
  T.Test('ansi backend bracketed paste enable disable',
    @TestAnsiBackendBracketedPasteEnableDisable);
  T.Test('ansi backend synchronized update begin end',
    @TestAnsiBackendSynchronizedUpdateBeginEnd);
  T.Test('osc8 open no id', @TestOsc8OpenNoId);
  T.Test('osc8 open with id', @TestOsc8OpenWithId);
  T.Test('osc8 open strips control chars', @TestOsc8OpenStripsControlChars);
  T.Test('osc8 close', @TestOsc8Close);
  T.Test('osc8 draw patches wraps link span', @TestOsc8DrawPatchesWrapsLinkSpan);
  T.Test('osc8 draw patches link switch closes/reopens',
    @TestOsc8DrawPatchesLinkSwitch);
  T.Test('osc8 draw patches no overlay no wrap', @TestOsc8DrawPatchesNoOverlayNoWrap);
  T.Test('osc8 draw patches clears link at patch end',
    @TestOsc8DrawPatchesClosesAtEnd);
  if not T.Run then Halt(1);
end.
