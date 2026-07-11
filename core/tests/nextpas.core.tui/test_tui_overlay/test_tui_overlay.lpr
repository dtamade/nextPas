program test_tui_overlay;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.overlay,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCreateClear;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 2));
  try
    Check(RectEquals(LOv.Area, TRect.Make(0, 0, 4, 2)), 'area set');
    Check(LOv.Dirty, 'dirty after create (Clear sets it)');
    LOv.ClearDirty;
    Check(not LOv.Dirty, 'clear dirty');
  finally
    LOv.Free;
  end;
end;

procedure TestMergeTransparent;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'base', StyleDefault);
    LDest.SetString(0, 0, 'base', StyleDefault);
    { 空 overlay -> merge 不改变 dest }
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('base', LLines[0], 'empty overlay transparent');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestMergeOverwrite;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'aaaa', StyleDefault);
    LDest.SetString(0, 0, 'aaaa', StyleDefault);
    { overlay 在位置 1,2 写 'XY' }
    LOv.SetString(1, 0, 'XY', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('aXYa', LLines[0], 'overlay overwrites marked cells');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetCell;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LCell: TCell;
  LLines: TBufferLines;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 1));
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    CellReset(LCell);
    CellSetSymbolAscii(LCell, 'Z');
    LOv.SetCell(2, 0, LCell);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('  Z', LLines[0], 'set cell merged');
  finally
    LOv.Free; LBase.Free; LDest.Free;
  end;
end;

procedure TestClearResetsMarks;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'aaaa', StyleDefault);
    LDest.SetString(0, 0, 'aaaa', StyleDefault);
    LOv.SetString(0, 0, 'XX', StyleDefault);
    LOv.Clear;  { 清空后 merge 应透明 }
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('aaaa', LLines[0], 'clear makes transparent again');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetStyle;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'base', StyleDefault);
    LDest.SetString(0, 0, 'base', StyleDefault);
    LOv.SetStyle(TRect.Make(0, 0, 2, 1), StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    Check(Length(LLines) > 0, 'has lines');
    Check(Length(LLines[0]) >= 2, 'at least 2 chars');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestResize;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 2));
  try
    Check(RectEquals(LOv.Area, TRect.Make(0, 0, 4, 2)), 'initial area');
    LOv.Resize(TRect.Make(0, 0, 8, 4));
    Check(RectEquals(LOv.Area, TRect.Make(0, 0, 8, 4)), 'resized area');
    Check(LOv.Dirty, 'dirty after resize');
  finally
    LOv.Free;
  end;
end;

procedure TestSetCellOutOfBounds;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 2));
  try
    LOv.SetCell(-1, 0, CELL_EMPTY); // Should silently ignore
    LOv.SetCell(4, 0, CELL_EMPTY);  // Out of bounds right
    LOv.SetCell(0, 2, CELL_EMPTY);  // Out of bounds bottom
    Check(True, 'out of bounds SetCell does not crash');
  finally
    LOv.Free;
  end;
end;

procedure TestSetStringEmpty;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LOv.ClearDirty;
    LOv.SetString(0, 0, '', StyleDefault); // Should silently ignore
    // SetString with empty string exits early — does NOT dirty
    Check(not LOv.Dirty, 'empty string does not dirty');
  finally
    LOv.Free;
  end;
end;

procedure TestMergeNoMarks;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'test', StyleDefault);
    LDest.SetString(0, 0, 'test', StyleDefault);
    // Don't write anything to overlay
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('test', LLines[0], 'no marks = base preserved');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetCellThenClear;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 1));
  try
    LBase.SetString(0, 0, 'abc', StyleDefault);
    LDest.SetString(0, 0, 'abc', StyleDefault);
    LOv.SetString(0, 0, 'XY', StyleDefault);
    LOv.Clear;
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('abc', LLines[0], 'clear then merge = base');
  finally
    LOv.Free; LBase.Free; LDest.Free;
  end;
end;

procedure TestDirtyFlag;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 1));
  try
    LOv.ClearDirty;
    Check(not LOv.Dirty, 'cleared');
    LOv.SetString(0, 0, 'x', StyleDefault);
    Check(LOv.Dirty, 'dirty after write');
  finally
    LOv.Free;
  end;
end;

{ === Deepened tests === }

procedure TestSetStringMultiRow;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 3));
  try
    LBase.SetString(0, 0, 'aaaa', StyleDefault);
    LBase.SetString(0, 1, 'bbbb', StyleDefault);
    LBase.SetString(0, 2, 'cccc', StyleDefault);
    LDest.SetString(0, 0, 'aaaa', StyleDefault);
    LDest.SetString(0, 1, 'bbbb', StyleDefault);
    LDest.SetString(0, 2, 'cccc', StyleDefault);
    LOv.SetString(0, 0, 'XX', StyleDefault);
    LOv.SetString(2, 2, 'YY', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('XXaa', LLines[0], 'row 0 overlay');
    CheckEqual('bbbb', LLines[1], 'row 1 untouched');
    CheckEqual('ccYY', LLines[2], 'row 2 overlay');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetStringClippedRight;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'aaaa', StyleDefault);
    LDest.SetString(0, 0, 'aaaa', StyleDefault);
    // Write 6 chars into 4-wide area → clips at right edge
    LOv.SetString(0, 0, '123456', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('1234', LLines[0], 'clips at right edge');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetStringOutOfBoundsY;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 2));
  try
    LOv.ClearDirty;
    LOv.SetString(0, -1, 'x', StyleDefault);
    Check(not LOv.Dirty, 'negative Y ignored');
    LOv.SetString(0, 2, 'x', StyleDefault);
    Check(not LOv.Dirty, 'Y >= height ignored');
  finally
    LOv.Free;
  end;
end;

procedure TestSetStringOutOfBoundsX;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LOv.ClearDirty;
    LOv.SetString(5, 0, 'x', StyleDefault);
    Check(not LOv.Dirty, 'X >= width ignored');
  finally
    LOv.Free;
  end;
end;

procedure TestSetStringClipLeft;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LOv.ClearDirty;
    // Very negative AX — SetString clips to FArea.X; no crash
    LOv.SetString(-100, 0, 'XY', StyleDefault);
    Check(True, 'negative AX does not crash');
  finally
    LOv.Free;
  end;
end;

procedure TestMergeIntoOffsetArea;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(2, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'abcdef', StyleDefault);
    LDest.SetString(0, 0, 'abcdef', StyleDefault);
    LOv.SetString(2, 0, 'XY', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('abXYef', LLines[0], 'offset overlay merges at correct position');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestMergeIntoMultiRow;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 3));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 3));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 3));
  try
    LBase.SetString(0, 0, 'abc', StyleDefault);
    LBase.SetString(0, 1, 'def', StyleDefault);
    LBase.SetString(0, 2, 'ghi', StyleDefault);
    LDest.SetString(0, 0, 'abc', StyleDefault);
    LDest.SetString(0, 1, 'def', StyleDefault);
    LDest.SetString(0, 2, 'ghi', StyleDefault);
    LOv.SetString(1, 0, 'X', StyleDefault);
    LOv.SetString(0, 2, 'YZ', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('aXc', LLines[0], 'row 0');
    CheckEqual('def', LLines[1], 'row 1 untouched');
    CheckEqual('YZi', LLines[2], 'row 2');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetStyleMarksUnmarkedCells;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'base', StyleDefault);
    LDest.SetString(0, 0, 'base', StyleDefault);
    // SetStyle on cells that haven't been written yet → marks them
    LOv.SetStyle(TRect.Make(0, 0, 2, 1), StyleDefault);
    // Now those cells are marked with styled empty cells
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    // The marked cells should overwrite base with styled spaces
    Check(Length(LLines[0]) = 4, 'length preserved');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

procedure TestSetStylePartialOverlap;
var
  LOv: TOverlayBuffer;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 2));
  try
    // Style rect partially outside overlay area
    LOv.SetStyle(TRect.Make(2, 1, 10, 5), StyleDefault);
    Check(LOv.Dirty, 'dirty after partial overlap style');
  finally
    LOv.Free;
  end;
end;

procedure TestResizeClearsContent;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LLines: TBufferLines;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LOv.SetString(0, 0, 'XY', StyleDefault);
    LOv.Resize(TRect.Make(0, 0, 4, 1));
    // After resize, overlay should be clear
    LBase.SetString(0, 0, 'base', StyleDefault);
    LDest.SetString(0, 0, 'base', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('base', LLines[0], 'resize clears overlay content');
  finally
    LOv.Free; LBase.Free; LDest.Free;
  end;
end;

procedure TestSetCellAtBoundary;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LCell: TCell;
  LLines: TBufferLines;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 3, 2));
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 2));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 2));
  try
    LBase.SetString(0, 0, 'abc', StyleDefault);
    LBase.SetString(0, 1, 'def', StyleDefault);
    LDest.SetString(0, 0, 'abc', StyleDefault);
    LDest.SetString(0, 1, 'def', StyleDefault);
    CellReset(LCell);
    CellSetSymbolAscii(LCell, 'Z');
    LOv.SetCell(2, 1, LCell); // bottom-right corner
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('abc', LLines[0], 'row 0 untouched');
    CheckEqual('deZ', LLines[1], 'boundary cell set');
  finally
    LOv.Free; LBase.Free; LDest.Free;
  end;
end;

procedure TestMultipleSetCellThenMerge;
var
  LOv: TOverlayBuffer;
  LBase, LDest: TBuffer;
  LCell: TCell;
  LLines: TBufferLines;
begin
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 5, 1));
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    LBase.SetString(0, 0, 'abcde', StyleDefault);
    LDest.SetString(0, 0, 'abcde', StyleDefault);
    CellReset(LCell);
    CellSetSymbolAscii(LCell, '1');
    LOv.SetCell(0, 0, LCell);
    CellSetSymbolAscii(LCell, '2');
    LOv.SetCell(2, 0, LCell);
    CellSetSymbolAscii(LCell, '3');
    LOv.SetCell(4, 0, LCell);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('1b2d3', LLines[0], 'odd positions overwritten');
  finally
    LOv.Free; LBase.Free; LDest.Free;
  end;
end;

procedure TestSetStringOverwritesPreviousMarks;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
begin
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'base', StyleDefault);
    LDest.SetString(0, 0, 'base', StyleDefault);
    LOv.SetString(0, 0, 'AB', StyleDefault);
    LOv.SetString(1, 0, 'XY', StyleDefault); // Overwrites B at pos 1
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    CheckEqual('AXYe', LLines[0], 'second write overwrites first');
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.overlay');
  T.Test('create and clear', @TestCreateClear);
  T.Test('merge transparent', @TestMergeTransparent);
  T.Test('merge overwrite', @TestMergeOverwrite);
  T.Test('set cell', @TestSetCell);
  T.Test('clear resets marks', @TestClearResetsMarks);
  T.Test('dirty flag', @TestDirtyFlag);
  T.Test('set style', @TestSetStyle);
  T.Test('resize', @TestResize);
  T.Test('set cell out of bounds', @TestSetCellOutOfBounds);
  T.Test('set string empty', @TestSetStringEmpty);
  T.Test('merge no marks', @TestMergeNoMarks);
  T.Test('set cell then clear', @TestSetCellThenClear);
  T.Test('set string multi row', @TestSetStringMultiRow);
  T.Test('set string clips right', @TestSetStringClippedRight);
  T.Test('set string out of bounds Y', @TestSetStringOutOfBoundsY);
  T.Test('set string out of bounds X', @TestSetStringOutOfBoundsX);
  T.Test('set string clips left', @TestSetStringClipLeft);
  T.Test('merge into offset area', @TestMergeIntoOffsetArea);
  T.Test('merge into multi row', @TestMergeIntoMultiRow);
  T.Test('set style marks unmarked', @TestSetStyleMarksUnmarkedCells);
  T.Test('set style partial overlap', @TestSetStylePartialOverlap);
  T.Test('resize clears content', @TestResizeClearsContent);
  T.Test('set cell at boundary', @TestSetCellAtBoundary);
  T.Test('multiple set cell then merge', @TestMultipleSetCellThenMerge);
  T.Test('set string overwrites previous', @TestSetStringOverwritesPreviousMarks);
  if not T.Run then Halt(1);
end.
