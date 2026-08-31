program test_tui_canvas_floodfill;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.floodfill,
  nextpas.core.text.conv,
  nextpas.core.test;

const
  CR = '#';
  CG = 'G';
  CB = 'B';
  CW = 'W';

{ 整个文档填成 ACell }
procedure FillAll(D: TCanvasDoc; ALayer: Integer; const ACell: TCanvasCell);
var
  X, Y: Integer;
begin
  for Y := 0 to D.Height - 1 do
    for X := 0 to D.Width - 1 do
      D.SetCell(ALayer, X, Y, ACell);
end;

{ 指定区域全部等于 ACell }
function RegionAll(D: TCanvasDoc; ALayer, X0, Y0, X1, Y1: Integer;
  const ACell: TCanvasCell): Boolean;
var
  X, Y: Integer;
begin
  for Y := Y0 to Y1 do
    for X := X0 to X1 do
      if not CanvasCellEquals(D.GetCell(ALayer, X, Y), ACell) then
        Exit(False);
  Result := True;
end;

procedure TestSmallBlock;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  Grid, FillGreen: TCanvasCell;
  N: Integer;
  Op: TCanvasEditOp;
begin
  Grid := CanvasMakeCell(Ord(CR), TUI_RED, TUI_BLACK);
  FillGreen := CanvasMakeCell(Ord(CG), TUI_GREEN, TUI_BLACK);

  D := TCanvasDoc.Create(3, 3);
  B := TCanvasEditBuilder.Create(D, 0);
  try
    FillAll(D, 0, Grid);
    N := CanvasFloodFill4(D, 0, 1, 1, FillGreen, B);
    CheckEqual(Int64(9), Int64(N), '3x3 fill count');
    Check(RegionAll(D, 0, 0, 0, 2, 2, FillGreen), '3x3 all changed');
    CheckEqual(Int64(9), Int64(B.Count), '3x3 builder count');
    Op := B.ToOp;
    CheckEqual(Int64(9), Int64(Op.Count), '3x3 op deltas');
    { 撤销回滚 = 原始红块, 确认增量记录完整 }
    CanvasApplyOpInverse(D, Op);
    Check(RegionAll(D, 0, 0, 0, 2, 2, Grid), '3x3 undo restores');
  finally
    B.Free;
    D.Free;
  end;
end;

procedure TestWallIsolation;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  Grid, FillGreen, FillBlue, FillBlack: TCanvasCell;
  N: Integer;
begin
  Grid := CanvasMakeCell(Ord(CR), TUI_RED, TUI_BLACK);
  FillGreen := CanvasMakeCell(Ord(CG), TUI_GREEN, TUI_BLACK);
  FillBlue := CanvasMakeCell(Ord(CB), TUI_BLUE, TUI_BLACK);
  FillBlack := CanvasMakeCell(Ord(CW), TUI_BLACK, TUI_BLACK);

  D := TCanvasDoc.Create(3, 3);
  B := TCanvasEditBuilder.Create(D, 0);
  try
    FillAll(D, 0, Grid);
    for N := 0 to 2 do
      D.SetCell(0, 1, N, FillBlack);     { 中列竖墙 }
    N := CanvasFloodFill4(D, 0, 0, 1, FillGreen, B);
    CheckEqual(Int64(3), Int64(N), 'wall left fill count');
    Check(RegionAll(D, 0, 0, 0, 0, 2, FillGreen), 'wall left region');
    Check(RegionAll(D, 0, 1, 0, 1, 2, FillBlack), 'wall stays');
    Check(RegionAll(D, 0, 2, 0, 2, 2, Grid), 'wall right untouched');
    N := CanvasFloodFill4(D, 0, 2, 1, FillBlue, B);
    CheckEqual(Int64(3), Int64(N), 'wall right fill count');
    Check(RegionAll(D, 0, 2, 0, 2, 2, FillBlue), 'wall right region');
    Check(RegionAll(D, 0, 0, 0, 0, 2, FillGreen), 'wall right keeps left');
    Check(RegionAll(D, 0, 1, 0, 1, 2, FillBlack), 'wall right keeps wall');
  finally
    B.Free;
    D.Free;
  end;
end;

procedure TestOobAndSameColor;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  Grid, FillGreen: TCanvasCell;
begin
  Grid := CanvasMakeCell(Ord(CR), TUI_RED, TUI_BLACK);
  FillGreen := CanvasMakeCell(Ord(CG), TUI_GREEN, TUI_BLACK);

  D := TCanvasDoc.Create(3, 3);
  B := TCanvasEditBuilder.Create(D, 0);
  try
    FillAll(D, 0, Grid);
    CheckEqual(Int64(0), Int64(CanvasFloodFill4(D, 0, -1, 0, FillGreen, B)),
      'oob seed -x');
    CheckEqual(Int64(0), Int64(CanvasFloodFill4(D, 0, 3, 1, FillGreen, B)),
      'oob seed +x');
    CheckEqual(Int64(0), Int64(CanvasFloodFill4(D, 0, 0, 3, FillGreen, B)),
      'oob seed +y');
    Check(RegionAll(D, 0, 0, 0, 2, 2, Grid), 'oob seed no change');
    CheckEqual(Int64(0), Int64(B.Count), 'oob seed no deltas');

    { 种子同色 → 0 且无改动 }
    CheckEqual(Int64(0), Int64(CanvasFloodFill4(D, 0, 1, 1, Grid, B)),
      'same-color count 0');
    Check(RegionAll(D, 0, 0, 0, 2, 2, Grid), 'same-color no change');
    CheckEqual(Int64(0), Int64(B.Count), 'same-color no deltas');
  finally
    B.Free;
    D.Free;
  end;
end;

procedure TestLargeArea;
var
  D: TCanvasDoc;
  B: TCanvasEditBuilder;
  Grid, FillGreen: TCanvasCell;
  N: Integer;
begin
  Grid := CanvasMakeCell(Ord(CR), TUI_RED, TUI_BLACK);
  FillGreen := CanvasMakeCell(Ord(CG), TUI_GREEN, TUI_BLACK);

  D := TCanvasDoc.Create(50, 50);
  B := TCanvasEditBuilder.Create(D, 0);
  try
    FillAll(D, 0, Grid);
    N := CanvasFloodFill4(D, 0, 25, 25, FillGreen, B);
    CheckEqual(Int64(2500), Int64(N), '50x50 count');
    Check(RegionAll(D, 0, 0, 0, 49, 49, FillGreen), '50x50 all changed');
    CheckEqual(Int64(2500), Int64(B.Count), '50x50 builder count');
  finally
    B.Free;
    D.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.floodfill');
  T.Test('3x3 block fill + undo', @TestSmallBlock);
  T.Test('wall isolation', @TestWallIsolation);
  T.Test('oob and same-color', @TestOobAndSameColor);
  T.Test('50x50 large area', @TestLargeArea);
  if not T.Run then Halt(1);
end.