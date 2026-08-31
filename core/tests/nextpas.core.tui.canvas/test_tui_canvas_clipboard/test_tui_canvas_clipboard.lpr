program test_tui_canvas_clipboard;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.clipboard,
  nextpas.core.test;

procedure AssertCellEq(const AName: string; D: TCanvasDoc; ALayer, AX, AY: Integer;
  const ACell: TCanvasCell);
begin
  Check(CanvasCellEquals(D.GetCell(ALayer, AX, AY), ACell), AName);
end;

procedure TestEmptyAndReject;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  C: TCanvasClipboard;
begin
  C := TCanvasClipboard.Create;
  D := TCanvasDoc.Create(8, 6);
  B := TCanvasEditBuilder.Create(D, 0);
  try
    Check(C.Empty, 'empty initially');
    Check(not C.PasteAt(D, 0, 0, 0, B), 'paste empty false');
    CheckEqual(Int64(0), Int64(B.Count), 'paste empty no deltas');
    AssertCellEq('paste empty no write', D, 0, 0, 0, CANVAS_CELL_EMPTY);
  finally
    B.Free;
    D.Free;
    C.Free;
  end;
end;

procedure TestCopyPasteRoundtrip;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  Op: TCanvasEditOp;
  C: TCanvasClipboard;
  CA, CB, CC, CX, CY: TCanvasCell;
begin
  CA := CanvasMakeCell(65, TUI_RED, TUI_BLACK);       { 'A' }
  CB := CanvasMakeCell(66, TUI_GREEN, TUI_WHITE);     { 'B' }
  CC := CanvasMakeCell(67, TUI_BLUE, TUI_BLACK);      { 'C' }
  CX := CanvasMakeCell($2588, TUI_WHITE, TUI_BLUE);   { '█' }
  CY := CanvasMakeCell(89, TUI_YELLOW, TUI_RED);      { 'Y' }

  D := TCanvasDoc.Create(8, 6);
  B := TCanvasEditBuilder.Create(D, 0);
  C := TCanvasClipboard.Create;
  try
    D.SetCell(0, 1, 1, CA);
    D.SetCell(0, 2, 1, CB);
    D.SetCell(0, 1, 2, CC);
    D.SetCell(0, 7, 5, CX);                    { 粘贴区外参照, 不应被改动 }
    D.SetCell(0, 5, 1, CY);                    { 另一参照 }
    Check(C.CopyFrom(D, 0, 1, 1, 2, 2), 'copy rect ok');
    Check(not C.Empty, 'not empty after copy');
    Check((C.AnchorX = 1) and (C.AnchorY = 1), 'anchor x/y');

    B.Clear;
    Check(C.PasteAt(D, 0, 3, 3, B), 'paste ok');
    CheckEqual(Int64(3), Int64(B.Count), 'paste deltas 3');
    AssertCellEq('paste A', D, 0, 3, 3, CA);
    AssertCellEq('paste B', D, 0, 4, 3, CB);
    AssertCellEq('paste C', D, 0, 3, 4, CC);
    AssertCellEq('paste blank', D, 0, 4, 4, CANVAS_CELL_EMPTY);
    AssertCellEq('outside ref kept', D, 0, 7, 5, CX);
    AssertCellEq('outside ref2 kept', D, 0, 5, 1, CY);

    { 粘贴增量可经逆操作整体还原 }
    Op := B.ToOp;
    CanvasApplyOpInverse(D, Op);
    AssertCellEq('paste undo A', D, 0, 3, 3, CANVAS_CELL_EMPTY);
    AssertCellEq('paste undo B', D, 0, 4, 3, CANVAS_CELL_EMPTY);
    AssertCellEq('paste undo C', D, 0, 3, 4, CANVAS_CELL_EMPTY);
  finally
    B.Free;
    D.Free;
    C.Free;
  end;
end;

procedure TestEdgeClipping;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  C: TCanvasClipboard;
  CA, CB: TCanvasCell;
begin
  CA := CanvasMakeCell(65, TUI_RED, TUI_BLACK);
  CB := CanvasMakeCell(66, TUI_GREEN, TUI_WHITE);

  D := TCanvasDoc.Create(8, 6);
  B := TCanvasEditBuilder.Create(D, 0);
  C := TCanvasClipboard.Create;
  try
    D.SetCell(0, 1, 1, CA);
    D.SetCell(0, 2, 1, CB);
    D.SetCell(0, 1, 2, CanvasMakeCell(67, TUI_BLUE, TUI_BLACK));
    C.CopyFrom(D, 0, 1, 1, 2, 2);

    { 右缘: 仅 (7,5) 在界内 }
    B.Clear;
    Check(C.PasteAt(D, 0, 7, 5, B), 'paste edge true');
    CheckEqual(Int64(1), Int64(B.Count), 'paste edge clipped 1');
    AssertCellEq('edge clipped cell', D, 0, 7, 5, CA);

    { 底缘: 底行裁掉一格 }
    B.Clear;
    Check(C.PasteAt(D, 0, 0, 5, B), 'paste bottom true');
    CheckEqual(Int64(2), Int64(B.Count), 'paste bottom clipped 2');
    AssertCellEq('bottom A', D, 0, 0, 5, CA);
    AssertCellEq('bottom B', D, 0, 1, 5, CB);

    { 目标完全在文档外: 裁剪后无格可写, 不崩且无增量 }
    B.Clear;
    Check(C.PasteAt(D, 0, 100, 100, B), 'paste fob true');
    CheckEqual(Int64(0), Int64(B.Count), 'paste fob no deltas');
  finally
    B.Free;
    D.Free;
    C.Free;
  end;
end;

procedure TestRecopyAndPartial;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  C: TCanvasClipboard;
  CX, CY: TCanvasCell;
begin
  CX := CanvasMakeCell($2588, TUI_WHITE, TUI_BLUE);
  CY := CanvasMakeCell(89, TUI_YELLOW, TUI_RED);

  D := TCanvasDoc.Create(8, 6);
  B := TCanvasEditBuilder.Create(D, 0);
  C := TCanvasClipboard.Create;
  try
    { 二次 CopyFrom 覆盖旧快照 }
    D.SetCell(0, 5, 4, CX);
    D.SetCell(0, 6, 4, CY);
    Check(C.CopyFrom(D, 0, 5, 4, 6, 4), 'recopy ok');
    Check((C.AnchorX = 5) and (C.AnchorY = 4), 'recopy anchor');
    B.Clear;
    Check(C.PasteAt(D, 0, 0, 0, B), 'recopy paste ok');
    CheckEqual(Int64(2), Int64(B.Count), 'recopy deltas 2');
    AssertCellEq('recopy X', D, 0, 0, 0, CX);
    AssertCellEq('recopy Y', D, 0, 1, 0, CY);
    AssertCellEq('recopy no old', D, 0, 0, 1, CANVAS_CELL_EMPTY);
    AssertCellEq('recopy no old2', D, 0, 2, 0, CANVAS_CELL_EMPTY);

    { CopyFrom 全越界拒绝, 旧快照保留 }
    Check(not C.CopyFrom(D, 0, 20, 20, 21, 21), 'copy fob false');
    Check(not C.Empty, 'failed copy keeps data');
    Check((C.AnchorX = 5) and (C.AnchorY = 4), 'failed copy keeps anchor');

    { 部分越界复制: 取文档重叠区 }
    D.SetCell(0, 5, 4, CX);
    D.SetCell(0, 6, 4, CY);
    Check(C.CopyFrom(D, 0, -2, -2, 1, 1), 'copy partial oob ok');
    Check((C.AnchorX = -2) and (C.AnchorY = -2), 'partial anchor');
    B.Clear;
    Check(C.PasteAt(D, 0, 2, 2, B), 'partial paste ok');
    CheckEqual(Int64(2), Int64(B.Count), 'partial deltas 2');
    AssertCellEq('partial X', D, 0, 2, 2, CX);
    AssertCellEq('partial Y', D, 0, 3, 2, CY);
  finally
    B.Free;
    D.Free;
    C.Free;
  end;
end;

procedure TestLayerIsolation;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  C: TCanvasClipboard;
  CC, CX: TCanvasCell;
  I: Integer;
begin
  CC := CanvasMakeCell(67, TUI_BLUE, TUI_BLACK);
  CX := CanvasMakeCell($2588, TUI_WHITE, TUI_BLUE);

  D := TCanvasDoc.Create(8, 6);
  B := TCanvasEditBuilder.Create(D, 0);
  C := TCanvasClipboard.Create;
  try
    I := D.NewLayer('L2');
    CheckEqual(Int64(1), Int64(I), 'new layer idx');
    D.SetCell(1, 1, 1, CC);                     { 层1: (1,1)=C, (2,1)=空 }
    D.SetCell(0, 1, 1, CX);                     { 层0同坐标, 复制层1不得带上它 }
    Check(C.CopyFrom(D, 1, 1, 1, 2, 1), 'copy layer1 ok');
    B.Clear;
    Check(C.PasteAt(D, 0, 4, 0, B), 'paste layer1 to layer0');
    CheckEqual(Int64(1), Int64(B.Count), 'layer deltas 1');
    AssertCellEq('layer pasted CC', D, 0, 4, 0, CC);
    AssertCellEq('layer paste blank', D, 0, 5, 0, CANVAS_CELL_EMPTY);
    AssertCellEq('layer source intact', D, 1, 1, 1, CC);
    AssertCellEq('layer0 same cell intact', D, 0, 1, 1, CX);
  finally
    B.Free;
    D.Free;
    C.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.clipboard');
  T.Test('empty and reject', @TestEmptyAndReject);
  T.Test('copy paste roundtrip', @TestCopyPasteRoundtrip);
  T.Test('edge clipping', @TestEdgeClipping);
  T.Test('recopy and partial', @TestRecopyAndPartial);
  T.Test('layer isolation', @TestLayerIsolation);
  if not T.Run then Halt(1);
end.
