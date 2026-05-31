unit nextpas.core.tui.layout.grid;

{**
 * @desc 二维网格布局——基于 layout 约束对区域做行列双向切分。
 *
 * 先按行约束做垂直切分，再对每行按列约束做水平切分，得到 Rows×Cols 的
 * cell 矩阵。提供两个重载：显式行列约束，或等权 FillConstraint 的均匀
 * RowCount×ColCount 网格。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout;

type
  TGridResult = record
    Cells: array of array of TRect;
    Rows: Integer;
    Cols: Integer;
    function Cell(ARow, ACol: Integer): TRect; inline;
  end;

function Grid(const AArea: TRect;
  const ARowConstraints: array of TConstraint;
  const AColConstraints: array of TConstraint): TGridResult; overload;

function Grid(const AArea: TRect;
  ARowCount, AColCount: Integer): TGridResult; overload;

implementation

function TGridResult.Cell(ARow, ACol: Integer): TRect;
begin
  if (ARow >= 0) and (ARow < Rows) and (ACol >= 0) and (ACol < Cols) then
    Result := Cells[ARow][ACol]
  else
    Result := TRect.Make(0, 0, 0, 0);
end;

function Grid(const AArea: TRect;
  const ARowConstraints: array of TConstraint;
  const AColConstraints: array of TConstraint): TGridResult;
var
  LRowRects: TRectArray;
  LColRects: TRectArray;
  LR, LC, LNR, LNC: Integer;
begin
  LNR := System.Length(ARowConstraints);
  LNC := System.Length(AColConstraints);
  Result.Rows := LNR;
  Result.Cols := LNC;

  if (LNR = 0) or (LNC = 0) or AArea.IsEmpty then
  begin
    SetLength(Result.Cells, 0);
    Exit;
  end;

  { 按行切分 }
  LRowRects := VerticalSplit(AArea, ARowConstraints);

  SetLength(Result.Cells, LNR, LNC);

  for LR := 0 to LNR - 1 do
  begin
    { 每行按列切分 }
    LColRects := HorizontalSplit(LRowRects[LR], AColConstraints);
    for LC := 0 to LNC - 1 do
      Result.Cells[LR][LC] := LColRects[LC];
  end;
end;

function Grid(const AArea: TRect; ARowCount, AColCount: Integer): TGridResult;
var
  LRowCs, LColCs: array of TConstraint;
  LI: Integer;
begin
  SetLength(LRowCs, ARowCount);
  SetLength(LColCs, AColCount);
  for LI := 0 to ARowCount - 1 do
    LRowCs[LI] := FillConstraint(1);
  for LI := 0 to AColCount - 1 do
    LColCs[LI] := FillConstraint(1);
  Result := Grid(AArea, LRowCs, LColCs);
end;

end.
