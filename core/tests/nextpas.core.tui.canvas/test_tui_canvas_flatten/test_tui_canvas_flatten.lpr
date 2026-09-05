program test_tui_canvas_flatten;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.clipboard,
  nextpas.core.tui.canvas.flatten,
  nextpas.core.test;

procedure AssertCellEq(const AName: string; D: TCanvasDoc; ALayer, AX, AY: Integer;
  const ACell: TCanvasCell);
begin
  Check(CanvasCellEquals(D.GetCell(ALayer, AX, AY), ACell), AName);
end;

procedure TestMergeOrderAndHidden;
var
  D, M: TCanvasDoc;
  CA, CB: TCanvasCell;
begin
  CA := CanvasMakeCell(65, TUI_RED, TUI_BLACK);    { 'A' 底层 }
  CB := CanvasMakeCell(66, TUI_GREEN, TUI_BLACK);  { 'B' 顶层覆盖 }
  D := TCanvasDoc.Create(8, 6);
  try
    D.SetCell(0, 2, 2, CA);
    D.NewLayer('top');
    D.SetCell(1, 2, 2, CB);
    D.SetCell(1, 3, 3, CB);
    D.NewLayer('hidden');
    D.SetLayerVisible(2, False);
    D.SetCell(2, 2, 2, CanvasMakeCell(74, TUI_GREEN, TUI_BLACK)); { 'J' 隐藏 }
    M := CanvasFlattenVisible(D);
    try
      Check((M.Width = 8) and (M.Height = 6), 'merge dims');
      AssertCellEq('top covers bottom', M, 0, 2, 2, CB);
      AssertCellEq('top carried', M, 0, 3, 3, CB);
      AssertCellEq('bottom kept where top empty', M, 0, 2, 2, CB);
      Check(M.GetCell(0, 2, 2).Ch <> 74, 'hidden excluded');
      Check(M.GetCell(0, 5, 5).Ch = 0, 'empty spot clean');
    finally
      M.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestViewportSubRect;
var
  D, M: TCanvasDoc;
  CA: TCanvasCell;
begin
  CA := CanvasMakeCell(65, TUI_RED, TUI_BLACK);
  D := TCanvasDoc.Create(8, 6);
  try
    D.SetCell(0, 3, 2, CA);
    M := CanvasFlattenViewport(D, TRect.Make(2, 1, 4, 3), 0);
    try
      Check((M.Width = 4) and (M.Height = 3), 'crop dims');
      AssertCellEq('crop maps origin', M, 0, 1, 1, CA);
      Check(M.GetCell(0, 0, 0).Ch = 0, 'crop empty origin');
    finally
      M.Free;
    end;
  finally
    D.Free;
  end;
end;

procedure TestReject;
var
  D, M: TCanvasDoc;
begin
  D := TCanvasDoc.Create(8, 6);
  try
    M := CanvasFlattenViewport(nil, TRect.Make(0, 0, 4, 4), -1);
    Check(M = nil, 'nil doc nil');
    M := CanvasFlattenViewport(D, TRect.Make(0, 0, 0, 0), -1);
    Check(M = nil, 'empty rect nil');
    M := CanvasFlattenViewport(D, TRect.Make(0, 0, 4, 4), 7);
    Check(M = nil, 'oob layer nil');
    M := CanvasFlattenVisible(nil);
    Check(M = nil, 'visible nil nil');
  finally
    D.Free;
  end;
end;

procedure TestNormalizeRect;
var
  X0, Y0, X1, Y1: Integer;
begin
  NormalizeRect(6, 5, 2, 1, X0, Y0, X1, Y1);
  Check((X0 = 2) and (Y0 = 1) and (X1 = 6) and (Y1 = 5), 'reversed normalized');
  NormalizeRect(2, 1, 6, 5, X0, Y0, X1, Y1);
  Check((X0 = 2) and (Y0 = 1) and (X1 = 6) and (Y1 = 5), 'ordered kept');
  Check(CanvasCellVisible(CanvasMakeCell(65, TUI_RED, TUI_BLACK)), 'glyph visible');
  Check(not CanvasCellVisible(CANVAS_CELL_EMPTY), 'empty invisible');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.flatten');
  T.Test('merge order and hidden', @TestMergeOrderAndHidden);
  T.Test('viewport sub rect', @TestViewportSubRect);
  T.Test('reject', @TestReject);
  T.Test('normalize rect', @TestNormalizeRect);
  if not T.Run then Halt(1);
end.
