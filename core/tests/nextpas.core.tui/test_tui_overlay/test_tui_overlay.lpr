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
  if not T.Run then Halt(1);
end.
