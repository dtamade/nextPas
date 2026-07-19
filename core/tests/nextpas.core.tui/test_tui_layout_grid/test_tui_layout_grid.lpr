program test_tui_layout_grid;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.grid,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestUniformGrid;
var
  LG: TGridResult;
begin
  { 2x2 均匀网格，区域 20x10 }
  LG := Grid(TRect.Make(0, 0, 20, 10), 2, 2);
  CheckEqual(Int64(2), Int64(LG.Rows), 'rows 2');
  CheckEqual(Int64(2), Int64(LG.Cols), 'cols 2');
  CheckEqual(Int64(10), Int64(LG.Cell(0, 0).Width), 'cell width 10');
  CheckEqual(Int64(5), Int64(LG.Cell(0, 0).Height), 'cell height 5');
  { (1,1) 在右下 }
  CheckEqual(Int64(10), Int64(LG.Cell(1, 1).X), 'cell(1,1) x=10');
  CheckEqual(Int64(5), Int64(LG.Cell(1, 1).Y), 'cell(1,1) y=5');
end;

procedure TestConstraintGrid;
var
  LG: TGridResult;
begin
  { 行：Length 3 + Min 0；列：50% + 50%，区域 20x10 }
  LG := Grid(TRect.Make(0, 0, 20, 10),
    [LengthConstraint(3), MinConstraint(0)],
    [PercentageConstraint(50), PercentageConstraint(50)]);
  CheckEqual(Int64(3), Int64(LG.Cell(0, 0).Height), 'row 0 height 3');
  CheckEqual(Int64(7), Int64(LG.Cell(1, 0).Height), 'row 1 height 7');
  CheckEqual(Int64(10), Int64(LG.Cell(0, 0).Width), 'col 0 width 10');
  CheckEqual(Int64(10), Int64(LG.Cell(0, 1).Width), 'col 1 width 10');
end;

procedure TestOutOfBounds;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 10, 10), 2, 2);
  Check(LG.Cell(5, 5).IsEmpty, 'oob cell empty');
  Check(LG.Cell(-1, 0).IsEmpty, 'negative oob empty');
end;

procedure TestEmptyGrid;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 10, 10), [], []);
  CheckEqual(Int64(0), Int64(LG.Rows), 'empty rows');
  CheckEqual(Int64(0), Int64(LG.Cols), 'empty cols');
end;

procedure Test1x1Grid;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 20, 10), 1, 1);
  CheckEqual(Int64(1), Int64(LG.Rows), '1 row');
  CheckEqual(Int64(1), Int64(LG.Cols), '1 col');
  CheckEqual(Int64(20), Int64(LG.Cell(0, 0).Width), 'full width');
  CheckEqual(Int64(10), Int64(LG.Cell(0, 0).Height), 'full height');
  CheckEqual(Int64(0), Int64(LG.Cell(0, 0).X), 'origin x');
  CheckEqual(Int64(0), Int64(LG.Cell(0, 0).Y), 'origin y');
end;

procedure Test3x3Grid;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 30, 9), 3, 3);
  CheckEqual(Int64(3), Int64(LG.Rows), '3 rows');
  CheckEqual(Int64(3), Int64(LG.Cols), '3 cols');
  CheckEqual(Int64(10), Int64(LG.Cell(0, 0).Width), 'cell width 10');
  CheckEqual(Int64(3), Int64(LG.Cell(0, 0).Height), 'cell height 3');
  { Bottom-right cell }
  CheckEqual(Int64(20), Int64(LG.Cell(2, 2).X), 'cell(2,2) x');
  CheckEqual(Int64(6), Int64(LG.Cell(2, 2).Y), 'cell(2,2) y');
end;

procedure TestGridEmptyArea;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 0, 0), [], []);
  CheckEqual(Int64(0), Int64(LG.Rows), 'empty area empty constraints rows');
  CheckEqual(Int64(0), Int64(LG.Cols), 'empty area empty constraints cols');
end;


procedure TestGridAreaConservation;
var
  LG: TGridResult;
  LArea: TRect;
  R, C, Sum: Integer;
begin
  LArea := TRect.Make(0, 0, 20, 12);
  LG := Grid(LArea, 3, 4);
  Sum := 0;
  for R := 0 to 2 do
    for C := 0 to 3 do
      Inc(Sum, LG.Cell(R, C).Width * LG.Cell(R, C).Height);
  CheckEqual(Int64(LArea.Width * LArea.Height), Int64(Sum), 'area conserved');
end;

procedure TestGridZeroRows;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 10, 10), 0, 3);
  CheckEqual(Int64(0), Int64(LG.Rows), 'zero rows');
end;

procedure TestGridZeroCols;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 10, 10), 3, 0);
  CheckEqual(Int64(0), Int64(LG.Cols), 'zero cols');
end;

procedure TestGridCellOutOfBoundsEmpty;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 10, 10), 2, 2);
  Check(LG.Cell(5, 5).IsEmpty or (LG.Cell(5, 5).Width = 0),
    'oob cell empty or zero');
end;

procedure TestGrid2x1VerticalSplit;
var
  LG: TGridResult;
begin
  LG := Grid(TRect.Make(0, 0, 10, 10), 2, 1);
  CheckEqual(Int64(2), Int64(LG.Rows), '2 rows');
  CheckEqual(Int64(1), Int64(LG.Cols), '1 col');
  CheckEqual(Int64(0), Int64(LG.Cell(0, 0).Y), 'top at 0');
  Check(LG.Cell(1, 0).Y > 0, 'bottom below top');
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.layout.grid');
  T.Test('uniform grid', @TestUniformGrid);
  T.Test('constraint grid', @TestConstraintGrid);
  T.Test('out of bounds', @TestOutOfBounds);
  T.Test('empty grid', @TestEmptyGrid);
  T.Test('1x1 grid', @Test1x1Grid);
  T.Test('3x3 grid', @Test3x3Grid);
  T.Test('empty area grid', @TestGridEmptyArea);
    T.Test('area conservation', @TestGridAreaConservation);
  T.Test('zero rows', @TestGridZeroRows);
  T.Test('zero cols', @TestGridZeroCols);
  T.Test('cell out of bounds empty', @TestGridCellOutOfBoundsEmpty);
  T.Test('2x1 vertical split', @TestGrid2x1VerticalSplit);
if not T.Run then Halt(1);
end.
