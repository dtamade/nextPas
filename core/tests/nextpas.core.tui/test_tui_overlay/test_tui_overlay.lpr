program test_tui_overlay;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.overlay,
  nextpas.core.testing;

var
  T: TTestRunner;

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
  T := TTestRunner.Create('nextpas.core.tui.overlay');
  T.Run('create and clear', @TestCreateClear);
  T.Run('merge transparent', @TestMergeTransparent);
  T.Run('merge overwrite', @TestMergeOverwrite);
  T.Run('set cell', @TestSetCell);
  T.Run('clear resets marks', @TestClearResetsMarks);
  T.Run('dirty flag', @TestDirtyFlag);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
