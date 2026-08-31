program test_tui_canvas_edit;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.edit,
  nextpas.core.test;

var
  T: TTestSuite;

function RedCell: TCanvasCell;
begin
  Result := CanvasMakeCell(Ord('R'), TUI_RED, TUI_BLACK);
end;

function GreenCell: TCanvasCell;
begin
  Result := CanvasMakeCell(Ord('G'), TUI_GREEN, TUI_BLACK);
end;

procedure TestBuilderCollects;
var
  LD: TCanvasDoc;
  LB: TCanvasEditBuilder;
  LOp: TCanvasEditOp;
begin
  LD := TCanvasDoc.Create(8, 8);
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    LB.SetPixel(1, 2, RedCell);
    LB.SetPixel(3, 4, GreenCell);
    CheckEqual(Int64(2), Int64(LB.Count), 'builder count');
    Check(not LB.Empty, 'builder not empty');
    LOp := LB.ToOp;
    CheckEqual(Int64(2), Int64(LOp.Count), 'op delta count');
    CheckEqual(Int64(0), Int64(LOp.Layer), 'op layer');
    CheckEqual(Int64(1), Int64(LOp.Deltas[0].X), 'delta0 x');
    CheckEqual(Int64(2), Int64(LOp.Deltas[0].Y), 'delta0 y');
    Check(CanvasCellEquals(LOp.Deltas[0].New, RedCell), 'delta0 new');
    Check(CanvasCellEquals(LOp.Deltas[0].Old, CANVAS_CELL_EMPTY), 'delta0 old empty');
    Check(CanvasCellEquals(LOp.Deltas[1].New, GreenCell), 'delta1 new');
    Check(CanvasCellEquals(LD.GetCell(0, 1, 2), RedCell), 'builder wrote doc');
  finally
    LB.Free;
    LD.Free;
  end;
end;

procedure TestBuilderIgnores;
var
  LD: TCanvasDoc;
  LB: TCanvasEditBuilder;
begin
  LD := TCanvasDoc.Create(4, 4);
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    LB.SetPixel(1, 1, RedCell);
    LB.SetPixel(1, 1, RedCell);   { 与旧值相同 → 忽略 }
    LB.SetPixel(9, 9, RedCell);   { 越界 → 忽略 }
    LB.SetPixel(-1, 0, RedCell);  { 负坐标 → 忽略 }
    CheckEqual(Int64(1), Int64(LB.Count), 'dedup + bounds ignored');
    LB.Clear;
    CheckEqual(Int64(0), Int64(LB.Count), 'clear resets count');
    Check(LB.Empty, 'clear -> empty');
  finally
    LB.Free;
    LD.Free;
  end;
end;

procedure TestApplyAndInverse;
var
  LD, LD2: TCanvasDoc;
  LB: TCanvasEditBuilder;
  LOp: TCanvasEditOp;
begin
  LD := TCanvasDoc.Create(8, 8);
  LB := TCanvasEditBuilder.Create(LD, 0);
  LD2 := TCanvasDoc.Create(8, 8);
  try
    LB.SetPixel(2, 3, RedCell);
    LB.SetPixel(5, 6, GreenCell);
    LOp := LB.ToOp;

    CanvasApplyOp(LD2, LOp);
    Check(CanvasCellEquals(LD2.GetCell(0, 2, 3), RedCell), 'apply writes new');
    Check(CanvasCellEquals(LD2.GetCell(0, 5, 6), GreenCell), 'apply writes both');

    CanvasApplyOpInverse(LD2, LOp);
    Check(CanvasCellEquals(LD2.GetCell(0, 2, 3), CANVAS_CELL_EMPTY), 'inverse restores old');
    Check(CanvasCellEquals(LD2.GetCell(0, 5, 6), CANVAS_CELL_EMPTY), 'inverse restores both');
  finally
    LD2.Free;
    LB.Free;
    LD.Free;
  end;
end;

procedure TestSameCellTwice;
var
  LD: TCanvasDoc;
  LB: TCanvasEditBuilder;
  LOp: TCanvasEditOp;
begin
  LD := TCanvasDoc.Create(4, 4);
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    LB.SetPixel(1, 1, RedCell);
    LB.SetPixel(1, 1, GreenCell);
    CheckEqual(Int64(2), Int64(LB.Count), 'two deltas same cell');
    LOp := LB.ToOp;
    { 逆序应用: 先写 delta[1].Old(Red), 再写 delta[0].Old(EMPTY) → 起点 }
    CanvasApplyOpInverse(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 1, 1), CANVAS_CELL_EMPTY), 'inverse lands on start');
    { 正序应用: 先写 delta[0].New(Red), 再写 delta[1].New(Green) → 终点 }
    CanvasApplyOp(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 1, 1), GreenCell), 'apply lands on end');
    CanvasApplyOpInverse(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 1, 1), CANVAS_CELL_EMPTY), 'inverse again lands on start');
  finally
    LB.Free;
    LD.Free;
  end;
end;

procedure TestUndoRedo;
var
  LD: TCanvasDoc;
  LU: TCanvasUndoLog;
  LOp: TCanvasEditOp;
  LB: TCanvasEditBuilder;
begin
  LD := TCanvasDoc.Create(8, 8);
  LU := TCanvasUndoLog.Create;
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    LB.SetPixel(0, 0, RedCell);
    LU.Push(LB.ToOp);
    LB.Clear;
    LB.SetPixel(1, 1, GreenCell);
    LU.Push(LB.ToOp);
    CheckEqual(Int64(2), Int64(LU.UndoCount), 'two undo entries');
    Check(not LU.CanRedo, 'no redo after pushes');

    LOp := LU.Undo;
    CheckEqual(Int64(1), Int64(LU.UndoCount), 'undo popped one');
    Check(LU.CanRedo, 'redo available after undo');
    CanvasApplyOpInverse(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 1, 1), CANVAS_CELL_EMPTY), 'undo reverted second stroke');
    Check(CanvasCellEquals(LD.GetCell(0, 0, 0), RedCell), 'first stroke intact');

    LOp := LU.Undo;
    CanvasApplyOpInverse(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 0, 0), CANVAS_CELL_EMPTY), 'undo reverted first stroke');
    Check(not LU.CanUndo, 'no undo left');

    LOp := LU.Redo;
    CanvasApplyOp(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 0, 0), RedCell), 'redo restored first stroke');
    LOp := LU.Redo;
    CanvasApplyOp(LD, LOp);
    Check(CanvasCellEquals(LD.GetCell(0, 1, 1), GreenCell), 'redo restored second stroke');
    Check(not LU.CanRedo, 'redo exhausted');
  finally
    LB.Free;
    LU.Free;
    LD.Free;
  end;
end;

procedure TestUndoLogOverflow;
var
  LU: TCanvasUndoLog;
  LB: TCanvasEditBuilder;
  LD: TCanvasDoc;
  LOp: TCanvasEditOp;
  I: Integer;
begin
  LD := TCanvasDoc.Create(4, 4);
  LU := TCanvasUndoLog.Create(2);
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    for I := 1 to 3 do
    begin
      LB.Clear;
      LB.SetPixel(0, 0, CanvasMakeCell(LongWord(I), TUI_WHITE, TUI_BLACK));
      LU.Push(LB.ToOp);
    end;
    CheckEqual(Int64(2), Int64(LU.UndoCount), 'overflow drops oldest');
    LOp := LU.Undo;
    CheckEqual(Int64(3), Int64(LOp.Deltas[0].New.Ch), 'oldest surviving op is #3');
    LOp := LU.Undo;
    CheckEqual(Int64(2), Int64(LOp.Deltas[0].New.Ch), 'second undo gets #2');
    Check(not LU.CanUndo, 'overflow stack exhausted');
  finally
    LB.Free;
    LU.Free;
    LD.Free;
  end;
end;

procedure TestPushEmptyIgnored;
var
  LU: TCanvasUndoLog;
  LOp: TCanvasEditOp;
begin
  LU := TCanvasUndoLog.Create;
  try
    LU.Push(Default(TCanvasEditOp));
    Check(not LU.CanUndo, 'empty op not pushed');
  finally
    LU.Free;
  end;
end;

procedure TestPushClearsRedo;
var
  LD: TCanvasDoc;
  LU: TCanvasUndoLog;
  LB: TCanvasEditBuilder;
  LOp: TCanvasEditOp;
begin
  LD := TCanvasDoc.Create(4, 4);
  LU := TCanvasUndoLog.Create;
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    LB.SetPixel(0, 0, RedCell);
    LU.Push(LB.ToOp);
    LB.Clear;
    LB.SetPixel(1, 1, GreenCell);
    LU.Push(LB.ToOp);
    LU.Undo;
    Check(LU.CanRedo, 'redo available');
    LB.Clear;
    LB.SetPixel(2, 2, RedCell);
    LU.Push(LB.ToOp);
    Check(not LU.CanRedo, 'new push clears redo');
    CheckEqual(Int64(2), Int64(LU.UndoCount), 'undo count after branch');
  finally
    LB.Free;
    LU.Free;
    LD.Free;
  end;
end;

procedure TestBuilderLayerIsolation;
var
  LD: TCanvasDoc;
  LB: TCanvasEditBuilder;
begin
  LD := TCanvasDoc.Create(4, 4);
  LD.NewLayer('L2');
  LB := TCanvasEditBuilder.Create(LD, 1);
  try
    LB.SetPixel(0, 0, RedCell);
    Check(CanvasCellEquals(LD.GetCell(1, 0, 0), RedCell), 'builder writes bound layer');
    Check(LD.GetCell(0, 0, 0).Ch = 0, 'other layer untouched');
  finally
    LB.Free;
    LD.Free;
  end;
end;

procedure TestClear;
var
  LU: TCanvasUndoLog;
  LD: TCanvasDoc;
  LB: TCanvasEditBuilder;
begin
  LD := TCanvasDoc.Create(4, 4);
  LU := TCanvasUndoLog.Create;
  LB := TCanvasEditBuilder.Create(LD, 0);
  try
    LB.SetPixel(0, 0, RedCell);
    LU.Push(LB.ToOp);
    CheckEqual(Int64(1), Int64(LU.UndoCount), 'push before clear');
    LU.Clear;
    CheckEqual(Int64(0), Int64(LU.UndoCount), 'clear empties undo');
    CheckEqual(Int64(0), Int64(LU.RedoCount), 'clear empties redo');
  finally
    LB.Free;
    LU.Free;
    LD.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.edit');
  T.Test('builder collects deltas', @TestBuilderCollects);
  T.Test('builder ignores dedup and bounds', @TestBuilderIgnores);
  T.Test('apply and inverse', @TestApplyAndInverse);
  T.Test('same cell twice', @TestSameCellTwice);
  T.Test('undo/redo', @TestUndoRedo);
  T.Test('undo log overflow', @TestUndoLogOverflow);
  T.Test('empty op ignored', @TestPushEmptyIgnored);
  T.Test('push clears redo', @TestPushClearsRedo);
  T.Test('builder layer isolation', @TestBuilderLayerIsolation);
  T.Test('clear', @TestClear);
  if not T.Run then Halt(1);
end.