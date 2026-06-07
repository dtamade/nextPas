program test_tui_buffer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.testing;

var
  T: TTestRunner;

{ 快照辅助：断言 buffer 各行内容（glyph 串）等于期望行数组 }
procedure AssertRows(ABuf: TBuffer; const AExpected: array of AnsiString;
  const AMsg: string);
var
  LLines: TBufferLines;
  LY: Integer;
begin
  LLines := ABuf.AsLines;
  CheckEqual(Int64(System.Length(AExpected)), Int64(System.Length(LLines)),
    AMsg + ' row count');
  for LY := 0 to System.Length(AExpected) - 1 do
    CheckEqual(AExpected[LY], LLines[LY], AMsg + ' row ' + IntToStr(LY));
end;

procedure TestCreateEmpty;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    CheckEqual(Int64(4), Int64(LBuf.Width), 'width 4');
    CheckEqual(Int64(2), Int64(LBuf.Height), 'height 2');
    CheckEqual(Int64(8), Int64(LBuf.Length_), 'length 8');
    { Reset 后 glyph len=0（dirty 哨兵），AsLines 渲染为空格 }
    AssertRows(LBuf, ['    ', '    '], 'empty buffer');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetString;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    LBuf.SetString(0, 0, 'Hi', StyleDefault);
    AssertRows(LBuf, ['Hi   '], 'set string Hi');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringClip;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LWritten := LBuf.SetString(0, 0, 'HelloWorld', StyleDefault);
    CheckEqual(Int64(3), Int64(LWritten), 'clipped to 3 cols');
    AssertRows(LBuf, ['Hel'], 'clipped string');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringLeftClipConsumesHiddenColumns;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(2, 0, 4, 1));
  try
    LWritten := LBuf.SetString(0, 0, 'ABCDE', StyleDefault);
    CheckEqual(Int64(3), Int64(LWritten), 'left clipped visible columns');
    AssertRows(LBuf, ['CDE '], 'left clipped string');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringLeftClipConsumesHiddenWideGlyph;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(2, 0, 4, 1));
  try
    LWritten := LBuf.SetString(0, 0, #$E4#$B8#$AD + 'ABC', StyleDefault);
    CheckEqual(Int64(3), Int64(LWritten), 'left clipped wide glyph leaves visible suffix columns');
    AssertRows(LBuf, ['ABC '], 'left clipped wide glyph');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringOffset;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LBuf.SetString(2, 0, 'ab', StyleDefault);
    AssertRows(LBuf, ['  ab  '], 'offset write');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringNWideClip;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LWritten := LBuf.SetStringN(0, 0, #$E4#$B8#$AD + 'B', 1, StyleDefault);
    CheckEqual(Int64(0), Int64(LWritten), 'max width smaller than grapheme width writes nothing');
    AssertRows(LBuf, ['      '], 'set stringN leaves row unchanged on wide clip');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringP;
var
  LBuf: TBuffer;
  LStr: AnsiString;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    LStr := 'Pas';
    LBuf.SetStringP(1, 0, PAnsiChar(LStr), Length(LStr), MaxInt, StyleDefault);
    AssertRows(LBuf, [' Pas '], 'set stringP');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringLeftClipPreservesVisibleColumns;
var
  LBuf: TBuffer;
  LLead, LTail, LNext: PCell;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LWritten := LBuf.SetString(-1, 0, 'A' + #$E4#$B8#$AD + 'B', StyleDefault);
    CheckEqual(Int64(3), Int64(LWritten), 'left clip writes visible display columns');

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    LNext := LBuf.CellAt(2, 0);
    CheckEqual(Int64(2), Int64(LLead^.Width), 'visible wide glyph starts at left edge');
    CheckEqual(#$E4#$B8#$AD, CellGlyphAsString(LLead^), 'visible wide glyph is preserved');
    CheckEqual(Int64(0), Int64(LTail^.Width), 'wide glyph tail is skip sentinel');
    Check(LTail^.Skip, 'wide glyph tail remains skipped');
    CheckEqual('B', CellGlyphAsString(LNext^), 'following glyph stays aligned');
    AssertRows(LBuf, [#$E4#$B8#$AD + 'B '], 'set string left clip visible columns');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringPLeftClipPreservesVisibleColumns;
var
  LBuf: TBuffer;
  LStr: AnsiString;
  LLead, LTail, LNext: PCell;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LStr := 'A' + #$E4#$B8#$AD + 'B';
    LWritten := LBuf.SetStringP(-1, 0, PAnsiChar(LStr), Length(LStr), MaxInt, StyleDefault);
    CheckEqual(Int64(3), Int64(LWritten), 'set stringP left clip writes visible display columns');

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    LNext := LBuf.CellAt(2, 0);
    CheckEqual(Int64(2), Int64(LLead^.Width), 'set stringP visible wide glyph starts at left edge');
    CheckEqual(#$E4#$B8#$AD, CellGlyphAsString(LLead^), 'set stringP visible wide glyph is preserved');
    CheckEqual(Int64(0), Int64(LTail^.Width), 'set stringP wide glyph tail is skip sentinel');
    Check(LTail^.Skip, 'set stringP wide glyph tail remains skipped');
    CheckEqual('B', CellGlyphAsString(LNext^), 'set stringP following glyph stays aligned');
    AssertRows(LBuf, [#$E4#$B8#$AD + 'B '], 'set stringP left clip visible columns');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringNLeftClipKeepsMaxWidthVisible;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LWritten := LBuf.SetStringN(-1, 0, 'ABCD', 1, StyleDefault);
    CheckEqual(Int64(1), Int64(LWritten),
      'left clipped source column does not consume max visible width');
    AssertRows(LBuf, ['B   '], 'set stringN left clip max visible width');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringLeftClipClearsPartialWideTail;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LBuf.FillRect(TRect.Make(0, 0, 4, 1), '#', StyleDefault);
    LWritten := LBuf.SetString(-1, 0, #$E4#$B8#$AD + 'A', StyleDefault);
    CheckEqual(Int64(2), Int64(LWritten),
      'partial clipped wide glyph tail consumes one visible column');
    AssertRows(LBuf, [' A##'], 'set string left clip clears partial wide tail');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringPLeftClipClearsPartialWideTail;
var
  LBuf: TBuffer;
  LStr: AnsiString;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LBuf.FillRect(TRect.Make(0, 0, 4, 1), '#', StyleDefault);
    LStr := #$E4#$B8#$AD + 'A';
    LWritten := LBuf.SetStringP(-1, 0, PAnsiChar(LStr), Length(LStr),
      MaxInt, StyleDefault);
    CheckEqual(Int64(2), Int64(LWritten),
      'set stringP partial clipped wide glyph tail consumes one visible column');
    AssertRows(LBuf, [' A##'], 'set stringP left clip clears partial wide tail');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringPLeftClipConsumesHiddenColumns;
var
  LBuf: TBuffer;
  LStr: AnsiString;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(2, 0, 4, 1));
  try
    LStr := 'ABCDE';
    LWritten := LBuf.SetStringP(0, 0, PAnsiChar(LStr), Length(LStr),
      MaxInt, StyleDefault);
    CheckEqual(Int64(3), Int64(LWritten),
      'set stringP left clipped visible columns');
    AssertRows(LBuf, ['CDE '], 'set stringP left clipped string');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringNLeftClipPartialWideTailConsumesMaxWidth;
var
  LBuf: TBuffer;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LBuf.FillRect(TRect.Make(0, 0, 4, 1), '#', StyleDefault);
    LWritten := LBuf.SetStringN(-1, 0, #$E4#$B8#$AD + 'A', 1, StyleDefault);
    CheckEqual(Int64(1), Int64(LWritten),
      'partial clipped wide glyph tail consumes max visible width');
    AssertRows(LBuf, [' ###'], 'set stringN left clip partial wide max width');
  finally
    LBuf.Free;
  end;
end;

procedure TestCellAt;
var
  LBuf: TBuffer;
  LCP: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 3));
  try
    LCP := LBuf.CellAt(1, 1);
    Check(LCP <> nil, 'in-bounds non-nil');
    Check(LBuf.CellAt(-1, 0) = nil, 'left oob nil');
    Check(LBuf.CellAt(3, 0) = nil, 'right oob nil');
    Check(LBuf.CellAt(0, 3) = nil, 'bottom oob nil');
  finally
    LBuf.Free;
  end;
end;

procedure TestCJKWidth;
var
  LBuf: TBuffer;
  LCP: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    { '中' width 2 -> occupies cells 0,1; cell1 is skip sentinel }
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LCP := LBuf.CellAt(0, 0);
    CheckEqual(Int64(2), Int64(LCP^.Width), 'leading cell width 2');
    LCP := LBuf.CellAt(1, 0);
    CheckEqual(Int64(0), Int64(LCP^.Width), 'trailing cell width 0');
    Check(LCP^.Skip, 'trailing cell skip');
    { RowAsString skips width-0 sentinel, so '中' + 4 trailing spaces }
    AssertRows(LBuf, [#$E4#$B8#$AD + '    '], 'CJK row');
  finally
    LBuf.Free;
  end;
end;

procedure TestFillRect;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    LBuf.FillRect(TRect.Make(1, 1, 2, 1), '#', StyleDefault);
    AssertRows(LBuf, ['    ', ' ## ', '    '], 'fill rect');
  finally
    LBuf.Free;
  end;
end;

procedure TestFillRectOverwritesWideGlyphTailWithNarrow;
var
  LBuf: TBuffer;
  LLead, LTail: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LBuf.FillRect(TRect.Make(1, 0, 1, 1), '#', StyleDefault);

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LLead^.Width), 'fill rect clears stale wide lead');
    Check(not LLead^.Skip, 'fill rect clears stale lead skip state');
    CheckEqual(' ', CellGlyphAsString(LLead^), 'fill rect resets stale lead to blank');
    CheckEqual(Int64(1), Int64(LTail^.Width), 'fill rect tail becomes regular narrow cell');
    Check(not LTail^.Skip, 'fill rect tail is not a skip sentinel');
    CheckEqual('#', CellGlyphAsString(LTail^), 'fill rect writes replacement glyph');
    AssertRows(LBuf, [' #    '], 'fill rect overwrite wide tail with narrow');
  finally
    LBuf.Free;
  end;
end;

procedure TestClearRectClearsWideGlyphTailOverlap;
var
  LBuf: TBuffer;
  LLead, LTail: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LBuf.ClearRect(TRect.Make(1, 0, 1, 1));

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LLead^.Width), 'clear rect clears stale wide lead');
    Check(not LLead^.Skip, 'clear rect clears stale lead skip state');
    CheckEqual(' ', CellGlyphAsString(LLead^), 'clear rect resets stale lead to blank');
    CheckEqual(Int64(1), Int64(LTail^.Width), 'clear rect tail becomes regular blank cell');
    Check(not LTail^.Skip, 'clear rect tail is not a skip sentinel');
    CheckEqual(' ', CellGlyphAsString(LTail^), 'clear rect clears tail glyph');
    AssertRows(LBuf, ['      '], 'clear rect clears wide tail overlap');
  finally
    LBuf.Free;
  end;
end;

procedure TestDiffSameSize;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LPrev.SetString(0, 0, 'aaa', StyleDefault);
    LCurr.SetString(0, 0, 'aba', StyleDefault);
    LPrev.Diff(LCurr, LPatches);
    { 只有中间 cell 变化 }
    CheckEqual(Int64(1), Int64(System.Length(LPatches)), 'one patch');
    CheckEqual(Int64(1), Int64(LPatches[0].X), 'patch at x=1');
    CheckEqual(Int64(0), Int64(LPatches[0].Y), 'patch at y=0');
  finally
    LPrev.Free;
    LCurr.Free;
  end;
end;

procedure TestDiffInto;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LCount: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    LPrev.SetString(0, 0, 'test', StyleDefault);
    LCurr.SetString(0, 0, 'test', StyleDefault);
    LCurr.SetString(0, 1, 'XY', StyleDefault);
    LCount := LPrev.DiffInto(LCurr, LPatches);
    CheckEqual(Int64(2), Int64(LCount), 'two changed cells row 1');
  finally
    LPrev.Free;
    LCurr.Free;
  end;
end;

procedure TestDiffSameSizeAreaOriginChangeRedrawsAtNextOrigin;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LCount: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(5, 2, 3, 1));
  try
    LPrev.SetString(0, 0, 'abc', StyleDefault);
    LCurr.SetString(5, 2, 'abc', StyleDefault);

    LPrev.Diff(LCurr, LPatches);
    CheckEqual(Int64(3), Int64(System.Length(LPatches)),
      'area origin change redraws all cells');
    CheckEqual(Int64(5), Int64(LPatches[0].X), 'diff patch 0 x uses next origin');
    CheckEqual(Int64(2), Int64(LPatches[0].Y), 'diff patch 0 y uses next origin');
    CheckEqual(Int64(6), Int64(LPatches[1].X), 'diff patch 1 x uses next origin');
    CheckEqual(Int64(2), Int64(LPatches[1].Y), 'diff patch 1 y uses next origin');
    CheckEqual(Int64(7), Int64(LPatches[2].X), 'diff patch 2 x uses next origin');
    CheckEqual(Int64(2), Int64(LPatches[2].Y), 'diff patch 2 y uses next origin');

    LCount := LPrev.DiffInto(LCurr, LPatches);
    CheckEqual(Int64(3), Int64(LCount),
      'diff into area origin change redraws all cells');
    CheckEqual(Int64(5), Int64(LPatches[0].X), 'diff into patch 0 x uses next origin');
    CheckEqual(Int64(2), Int64(LPatches[0].Y), 'diff into patch 0 y uses next origin');
    CheckEqual(Int64(6), Int64(LPatches[1].X), 'diff into patch 1 x uses next origin');
    CheckEqual(Int64(2), Int64(LPatches[1].Y), 'diff into patch 1 y uses next origin');
    CheckEqual(Int64(7), Int64(LPatches[2].X), 'diff into patch 2 x uses next origin');
    CheckEqual(Int64(2), Int64(LPatches[2].Y), 'diff into patch 2 y uses next origin');
  finally
    LPrev.Free;
    LCurr.Free;
  end;
end;

procedure AssertSingleWideGlyphPatch(const APatches: TDiffEntries; ACount: Integer;
  const AContext: string);
begin
  CheckEqual(Int64(1), Int64(ACount), AContext + ' patch count');
  if ACount <= 0 then Exit;

  CheckEqual(Int64(0), Int64(APatches[0].X), AContext + ' patch x');
  CheckEqual(Int64(0), Int64(APatches[0].Y), AContext + ' patch y');
  CheckEqual(Int64(2), Int64(APatches[0].Cell.Width), AContext + ' patch width');
  Check(not APatches[0].Cell.Skip, AContext + ' patch is not skip sentinel');
  CheckEqual(#$E4#$B8#$AD, CellGlyphAsString(APatches[0].Cell), AContext + ' patch glyph');
end;

procedure TestDiffFullRedrawSkipsWideGlyphTail;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LCount: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    LCurr.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);

    LPrev.Diff(LCurr, LPatches);
    AssertSingleWideGlyphPatch(LPatches, System.Length(LPatches), 'diff full redraw');

    SetLength(LPatches, 0);
    LCount := LPrev.DiffInto(LCurr, LPatches);
    AssertSingleWideGlyphPatch(LPatches, LCount, 'diffinto full redraw');
  finally
    LPrev.Free;
    LCurr.Free;
  end;
end;

procedure TestResize;
var
  LBuf: TBuffer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 2));
  try
    LBuf.SetString(0, 0, 'ab', StyleDefault);
    LBuf.Resize(TRect.Make(0, 0, 5, 3));
    CheckEqual(Int64(5), Int64(LBuf.Width), 'resized width 5');
    CheckEqual(Int64(3), Int64(LBuf.Height), 'resized height 3');
    { 重叠区保留 'ab' }
    AssertRows(LBuf, ['ab   ', '     ', '     '], 'resized keeps overlap');
  finally
    LBuf.Free;
  end;
end;

procedure TestResizeDropsWideLeadClippedAtRightEdge;
var
  LPrev, LBuf: TBuffer;
  LCell: PCell;
  LPatches: TDiffEntries;
  LI: Integer;
begin
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LBuf.SetString(0, 0, 'A' + #$E4#$B8#$AD + 'B', StyleDefault);
    LBuf.Resize(TRect.Make(0, 0, 2, 1));

    LCell := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LCell^.Width), 'right-clipped wide lead becomes regular cell');
    Check(not LCell^.Skip, 'right-clipped wide lead is not a skip sentinel');
    CheckEqual(' ', CellGlyphAsString(LCell^), 'right-clipped wide lead is blank');
    AssertRows(LBuf, ['A '], 'resize clips incomplete wide glyph at right edge');

    LPrev.Diff(LBuf, LPatches);
    for LI := 0 to System.Length(LPatches) - 1 do
      Check(not ((LPatches[LI].X = 1) and (LPatches[LI].Cell.Width = 2)),
        'resize diff does not emit clipped width-2 cell at right edge');
  finally
    LPrev.Free;
    LBuf.Free;
  end;
end;

procedure TestResizeDropsOrphanWideTailAtLeftEdge;
var
  LBuf: TBuffer;
  LCell: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD + 'AB', StyleDefault);
    LBuf.Resize(TRect.Make(1, 0, 3, 1));

    LCell := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LCell^.Width), 'left-clipped wide tail becomes regular cell');
    Check(not LCell^.Skip, 'left-clipped wide tail is not a skip sentinel');
    CheckEqual(' ', CellGlyphAsString(LCell^), 'left-clipped wide tail is blank');
    AssertRows(LBuf, [' AB'], 'resize clips orphan wide tail at left edge');
  finally
    LBuf.Free;
  end;
end;

procedure TestStyleApplied;
var
  LBuf: TBuffer;
  LCP: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LBuf.SetString(0, 0, 'x', StyleDefault.WithFg(TUI_RED).WithModifier([mbBold]));
    LCP := LBuf.CellAt(0, 0);
    Check(ColorEquals(LCP^.Fg, TUI_RED), 'fg red applied');
    Check(mbBold in LCP^.Modifier, 'bold applied');
  finally
    LBuf.Free;
  end;
end;

procedure TestCombiningMark;
var LBuf: TBuffer; LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LWritten := LBuf.SetString(0, 0, 'e' + #$CC#$81 + 'x', TStyle.Default);
    Check(LWritten = 2, 'e+combining+x = 2 cols written');
  finally LBuf.Free; end;
end;

procedure TestZWJEmoji;
var LBuf: TBuffer; LWritten: Integer; S: AnsiString;
begin
  S := #$F0#$9F#$91#$A8 + #$E2#$80#$8D + #$F0#$9F#$91#$A9 + 'A';
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LWritten := LBuf.SetString(0, 0, S, TStyle.Default);
    Check(LWritten = 3, 'ZWJ emoji(2) + A(1) = 3 cols');
  finally LBuf.Free; end;
end;

procedure TestFamilyEmoji;
var LBuf: TBuffer; LWritten: Integer; S: AnsiString;
begin
  S := #$F0#$9F#$91#$A8 + #$E2#$80#$8D +
       #$F0#$9F#$91#$A9 + #$E2#$80#$8D +
       #$F0#$9F#$91#$A7 + #$E2#$80#$8D +
       #$F0#$9F#$91#$A6 + 'B';
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LWritten := LBuf.SetString(0, 0, S, TStyle.Default);
    Check(LWritten = 3, 'family emoji(2) + B(1) = 3 cols');
  finally LBuf.Free; end;
end;

procedure TestSkinToneEmoji;
var LBuf: TBuffer; LWritten: Integer; S: AnsiString;
begin
  S := #$F0#$9F#$91#$8D + #$F0#$9F#$8F#$BD + 'C';
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LWritten := LBuf.SetString(0, 0, S, TStyle.Default);
    Check(LWritten = 3, 'skin tone emoji(2) + C(1) = 3 cols');
  finally LBuf.Free; end;
end;

procedure TestKeycapEmoji;
var LBuf: TBuffer; LWritten: Integer; S: AnsiString;
begin
  S := '1' + #$EF#$B8#$8F + #$E2#$83#$A3 + 'D';
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LWritten := LBuf.SetString(0, 0, S, TStyle.Default);
    Check(LWritten = 3, 'keycap emoji(2) + D(1) = 3 cols');
  finally LBuf.Free; end;
end;

procedure TestOverwriteWideGlyphLeadWithNarrow;
var
  LBuf: TBuffer;
  LLead, LTail: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LBuf.SetString(0, 0, 'A', StyleDefault);

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LLead^.Width), 'narrow overwrite leaves width 1 at lead cell');
    CheckEqual('A', CellGlyphAsString(LLead^), 'lead cell now holds A');
    CheckEqual(Int64(1), Int64(LTail^.Width), 'former tail restored to width 1 empty cell');
    Check(not LTail^.Skip, 'former tail no longer skip sentinel');
    CheckEqual(' ', CellGlyphAsString(LTail^), 'former tail reset to blank');
    AssertRows(LBuf, ['A     '], 'overwrite wide lead with narrow');
  finally
    LBuf.Free;
  end;
end;

procedure TestOverwriteWideGlyphTailWithNarrow;
var
  LBuf: TBuffer;
  LLead, LTail: PCell;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LBuf.SetString(1, 0, 'A', StyleDefault);

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LLead^.Width), 'overwriting tail clears stale wide lead');
    Check(not LLead^.Skip, 'cleared lead is not skip sentinel');
    CheckEqual(' ', CellGlyphAsString(LLead^), 'cleared lead reset to blank');
    CheckEqual(Int64(1), Int64(LTail^.Width), 'tail overwrite becomes regular narrow cell');
    CheckEqual('A', CellGlyphAsString(LTail^), 'tail cell now holds A');
    AssertRows(LBuf, [' A    '], 'overwrite wide tail with narrow');
  finally
    LBuf.Free;
  end;
end;

procedure TestSetStringPOverwriteWideTailWithNarrow;
var
  LBuf: TBuffer;
  LLead, LTail: PCell;
  LStr: AnsiString;
  LWritten: Integer;
begin
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LStr := 'A';
    LWritten := LBuf.SetStringP(1, 0, PAnsiChar(LStr), Length(LStr), MaxInt, StyleDefault);

    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    CheckEqual(Int64(1), Int64(LWritten), 'set stringP wrote one narrow column');
    CheckEqual(' ', CellGlyphAsString(LLead^), 'set stringP cleared stale wide lead');
    Check(not LLead^.Skip, 'set stringP cleared stale skip state on lead');
    CheckEqual('A', CellGlyphAsString(LTail^), 'set stringP wrote A into tail cell');
    AssertRows(LBuf, [' A    '], 'set stringP overwrite wide tail with narrow');
  finally
    LBuf.Free;
  end;
end;

procedure TestOverwriteWidthOneGraphemeClearsGlyphTailForDiff;
var
  LFresh, LReused: TBuffer;
  LFreshCell, LReusedCell: PCell;
  LPatches: TDiffEntries;
begin
  LFresh := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LReused := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LFresh.SetString(0, 0, 'A', StyleDefault);
    LReused.SetString(0, 0, 'e' + #$CC#$81, StyleDefault);
    LReused.SetString(0, 0, 'A', StyleDefault);

    AssertRows(LFresh, ['A  '], 'fresh ascii row');
    AssertRows(LReused, ['A  '], 'reused grapheme overwritten with ascii row');
    LFreshCell := LFresh.CellAt(0, 0);
    LReusedCell := LReused.CellAt(0, 0);
    Check(CellEquals(LFreshCell^, LReusedCell^),
      'reused width-1 grapheme cell canonicalizes to fresh ascii cell');
    LFresh.Diff(LReused, LPatches);
    CheckEqual(Int64(0), Int64(System.Length(LPatches)),
      'canonical glyph tail produces no diff patch');
  finally
    LFresh.Free;
    LReused.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.buffer');
  T.Run('create empty', @TestCreateEmpty);
  T.Run('set string', @TestSetString);
  T.Run('set string clip', @TestSetStringClip);
  T.Run('set string left clip consumes hidden columns', @TestSetStringLeftClipConsumesHiddenColumns);
  T.Run('set string left clip consumes hidden wide glyph', @TestSetStringLeftClipConsumesHiddenWideGlyph);
  T.Run('set string offset', @TestSetStringOffset);
  T.Run('set stringN wide clip', @TestSetStringNWideClip);
  T.Run('set stringP', @TestSetStringP);
  T.Run('set string left clip preserves visible columns',
    @TestSetStringLeftClipPreservesVisibleColumns);
  T.Run('set stringP left clip preserves visible columns',
    @TestSetStringPLeftClipPreservesVisibleColumns);
  T.Run('set stringN left clip keeps max width visible',
    @TestSetStringNLeftClipKeepsMaxWidthVisible);
  T.Run('set string left clip clears partial wide tail',
    @TestSetStringLeftClipClearsPartialWideTail);
  T.Run('set stringP left clip clears partial wide tail',
    @TestSetStringPLeftClipClearsPartialWideTail);
  T.Run('set stringN left clip partial wide tail consumes max width',
    @TestSetStringNLeftClipPartialWideTailConsumesMaxWidth);
  T.Run('set stringP left clip consumes hidden columns',
    @TestSetStringPLeftClipConsumesHiddenColumns);
  T.Run('cell at bounds', @TestCellAt);
  T.Run('cjk width', @TestCJKWidth);
  T.Run('fill rect', @TestFillRect);
  T.Run('fill rect overwrite wide tail with narrow', @TestFillRectOverwritesWideGlyphTailWithNarrow);
  T.Run('clear rect clears wide tail overlap', @TestClearRectClearsWideGlyphTailOverlap);
  T.Run('diff same size', @TestDiffSameSize);
  T.Run('diff into', @TestDiffInto);
  T.Run('diff same size area origin change redraws at next origin',
    @TestDiffSameSizeAreaOriginChangeRedrawsAtNextOrigin);
  T.Run('diff full redraw skips wide tail', @TestDiffFullRedrawSkipsWideGlyphTail);
  T.Run('resize', @TestResize);
  T.Run('resize drops wide lead clipped at right edge', @TestResizeDropsWideLeadClippedAtRightEdge);
  T.Run('resize drops orphan wide tail at left edge', @TestResizeDropsOrphanWideTailAtLeftEdge);
  T.Run('style applied', @TestStyleApplied);
  T.Run('combining mark grapheme', @TestCombiningMark);
  T.Run('zwj emoji grapheme', @TestZWJEmoji);
  T.Run('family emoji grapheme', @TestFamilyEmoji);
  T.Run('skin tone emoji grapheme', @TestSkinToneEmoji);
  T.Run('keycap emoji grapheme', @TestKeycapEmoji);
  T.Run('overwrite wide lead with narrow', @TestOverwriteWideGlyphLeadWithNarrow);
  T.Run('overwrite wide tail with narrow', @TestOverwriteWideGlyphTailWithNarrow);
  T.Run('set stringP overwrite wide tail with narrow', @TestSetStringPOverwriteWideTailWithNarrow);
  T.Run('overwrite width-1 grapheme clears glyph tail for diff', @TestOverwriteWidthOneGraphemeClearsGlyphTailForDiff);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
