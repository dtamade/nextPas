program test_tui_canvas_raster;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.canvas.raster,
  nextpas.core.test;

type
  TPointCollector = record
    Xs, Ys: array of Integer;
    N: Integer;
    procedure OnPoint(AX, AY: Integer);
    procedure Reset;
    function Count: Integer;
    function Contains(AX, AY: Integer): Boolean;
    function MinX: Integer;
    function MaxX: Integer;
    function MinY: Integer;
    function MaxY: Integer;
  end;

procedure TPointCollector.OnPoint(AX, AY: Integer);
begin
  if N >= Length(Xs) then
  begin
    SetLength(Xs, N + 64);
    SetLength(Ys, N + 64);
  end;
  Xs[N] := AX;
  Ys[N] := AY;
  Inc(N);
end;

procedure TPointCollector.Reset;
begin
  N := 0;
end;

function TPointCollector.Count: Integer;
begin
  Result := N;
end;

function TPointCollector.Contains(AX, AY: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to N - 1 do
    if (Xs[I] = AX) and (Ys[I] = AY) then
      Exit(True);
  Result := False;
end;

function TPointCollector.MinX: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to N - 1 do
    if (I = 0) or (Xs[I] < Result) then
      Result := Xs[I];
end;

function TPointCollector.MaxX: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to N - 1 do
    if (I = 0) or (Xs[I] > Result) then
      Result := Xs[I];
end;

function TPointCollector.MinY: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to N - 1 do
    if (I = 0) or (Ys[I] < Result) then
      Result := Ys[I];
end;

function TPointCollector.MaxY: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to N - 1 do
    if (I = 0) or (Ys[I] > Result) then
      Result := Ys[I];
end;

var
  T: TTestSuite;
  C: TPointCollector;

{ 逐点唯一性: 同一格不得重复回调(直线序性质)。 }
function UniquePoints(AC: TPointCollector): Boolean;
var
  I, J: Integer;
begin
  for I := 0 to AC.N - 1 do
    for J := I + 1 to AC.N - 1 do
      if (AC.Xs[I] = AC.Xs[J]) and (AC.Ys[I] = AC.Ys[J]) then
        Exit(False);
  Result := True;
end;

procedure TestLineHorizontal;
begin
  C.Reset;
  RasterLine(1, 2, 6, 2, @C.OnPoint);
  CheckEqual(Int64(6), Int64(C.Count), 'horizontal len');
  Check(C.Contains(1, 2) and C.Contains(6, 2), 'horizontal endpoints');
  Check(UniquePoints(C), 'horizontal unique');
end;

procedure TestLineVertical;
begin
  C.Reset;
  RasterLine(4, 5, 4, 1, @C.OnPoint);
  CheckEqual(Int64(5), Int64(C.Count), 'vertical len');
  Check(C.Contains(4, 1) and C.Contains(4, 5), 'vertical endpoints both dirs');
  Check(C.MinY = 1, 'vertical ascending order');
end;

procedure TestLineDiagonal;
begin
  C.Reset;
  RasterLine(0, 0, 7, 7, @C.OnPoint);
  CheckEqual(Int64(8), Int64(C.Count), 'diagonal len');
  Check(C.Contains(0, 0) and C.Contains(7, 7), 'diagonal endpoints');
  Check(UniquePoints(C), 'diagonal unique');
end;

procedure TestLineNegativeDelta;
begin
  C.Reset;
  RasterLine(5, 3, 1, 1, @C.OnPoint);
  CheckEqual(Int64(5), Int64(C.Count), 'reverse diag len');
  Check(C.Contains(5, 3) and C.Contains(1, 1), 'reverse diag endpoints');
end;

procedure TestLineSteep;
begin
  C.Reset;
  RasterLine(0, 0, 1, 6, @C.OnPoint);
  CheckEqual(Int64(7), Int64(C.Count), 'steep len');
  Check(C.Contains(0, 0) and C.Contains(1, 6), 'steep endpoints');
end;

procedure TestLineSinglePoint;
begin
  C.Reset;
  RasterLine(3, 3, 3, 3, @C.OnPoint);
  CheckEqual(Int64(1), Int64(C.Count), 'single point len');
  Check(C.Contains(3, 3), 'single point');
end;

procedure TestRectOutline;
begin
  C.Reset;
  RasterRectOutline(1, 1, 4, 3, @C.OnPoint);
  { 4x3 矩形: 2*(4+3)-4 = 10 }
  CheckEqual(Int64(10), Int64(C.Count), 'outline count no dup corners');
  Check(C.Contains(1, 1) and C.Contains(4, 3), 'outline corners');
  Check(C.Contains(2, 3) and C.Contains(4, 2), 'outline edges');
  Check(not C.Contains(2, 2), 'outline interior untouched');
  Check(UniquePoints(C), 'outline unique');
end;

procedure TestRectOutlineReversed;
begin
  C.Reset;
  RasterRectOutline(4, 3, 1, 1, @C.OnPoint);
  CheckEqual(Int64(10), Int64(C.Count), 'reversed outline count');
  Check(C.Contains(1, 1) and C.Contains(4, 1), 'reversed normalized');
end;

procedure TestRectOutlineDegenerateRow;
begin
  C.Reset;
  RasterRectOutline(2, 2, 5, 2, @C.OnPoint);
  CheckEqual(Int64(4), Int64(C.Count), 'single row outline len');
  Check(C.Contains(2, 2) and C.Contains(5, 2), 'single row endpoints');
end;

procedure TestRectOutlineDegenerateCol;
begin
  C.Reset;
  RasterRectOutline(3, 0, 3, 4, @C.OnPoint);
  CheckEqual(Int64(5), Int64(C.Count), 'single col outline len');
  Check(C.Contains(3, 0) and C.Contains(3, 4), 'single col endpoints');
end;

procedure TestRectOutlineSinglePoint;
begin
  C.Reset;
  RasterRectOutline(2, 2, 2, 2, @C.OnPoint);
  CheckEqual(Int64(1), Int64(C.Count), 'point rect outline');
end;

procedure TestRectFill;
begin
  C.Reset;
  RasterRectFill(1, 1, 4, 3, @C.OnPoint);
  CheckEqual(Int64(12), Int64(C.Count), 'fill area');
  Check(C.Contains(2, 2), 'fill interior');
end;

procedure TestRectFillDegenerate;
begin
  C.Reset;
  RasterRectFill(2, 2, 2, 5, @C.OnPoint);
  CheckEqual(Int64(4), Int64(C.Count), 'fill single col');
end;

procedure TestEllipseCircle;
begin
  C.Reset;
  RasterEllipseOutline(0, 0, 8, 8, @C.OnPoint);
  { 半径 4 的圆: 每个 y 行左右两点(除极值行), 总点数偶数 }
  Check(C.Count >= 16, 'circle outline has points');
  CheckEqual(Int64(0), Int64(C.MinX), 'circle min x on bbox');
  CheckEqual(Int64(8), Int64(C.MaxX), 'circle max x on bbox');
  CheckEqual(Int64(0), Int64(C.MinY), 'circle min y on bbox');
  CheckEqual(Int64(8), Int64(C.MaxY), 'circle max y on bbox');
  Check(C.Contains(4, 0) and C.Contains(4, 8), 'circle top/bottom poles');
  Check(C.Contains(0, 4) and C.Contains(8, 4), 'circle left/right poles');
  Check(not (C.Count mod 2 = 1), 'circle outline even count');
end;

procedure TestEllipseDegeneratePoint;
begin
  C.Reset;
  RasterEllipseOutline(5, 5, 5, 5, @C.OnPoint);
  CheckEqual(Int64(1), Int64(C.Count), 'point ellipse');
end;

procedure TestEllipseDegenerateLine;
begin
  C.Reset;
  RasterEllipseOutline(2, 1, 2, 5, @C.OnPoint);
  CheckEqual(Int64(5), Int64(C.Count), 'vertical line ellipse');
end;

procedure TestEllipseDegenerateRow;
begin
  C.Reset;
  RasterEllipseOutline(1, 3, 7, 3, @C.OnPoint);
  CheckEqual(Int64(7), Int64(C.Count), 'horizontal row ellipse');
end;

procedure TestEllipseFill;
begin
  C.Reset;
  RasterEllipseFill(0, 0, 8, 8, @C.OnPoint);
  Check(C.Count >= 32, 'filled circle area');
  Check(C.Contains(4, 4), 'filled circle center');
  Check(C.MinX = 0, 'fill min x');
  Check(C.MaxX = 8, 'fill max x');
  Check(C.MinY = 0, 'fill min y');
  Check(C.MaxY = 8, 'fill max y');
end;

procedure TestEllipseFillWide;
begin
  C.Reset;
  RasterEllipseFill(0, 0, 16, 6, @C.OnPoint);
  Check(C.Count >= 40, 'wide ellipse area');
  Check(C.Contains(8, 3), 'wide ellipse center');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.raster');
  T.Test('line horizontal', @TestLineHorizontal);
  T.Test('line vertical', @TestLineVertical);
  T.Test('line diagonal', @TestLineDiagonal);
  T.Test('line negative delta', @TestLineNegativeDelta);
  T.Test('line single point', @TestLineSinglePoint);
  T.Test('rect outline', @TestRectOutline);
  T.Test('rect outline reversed', @TestRectOutlineReversed);
  T.Test('rect outline degenerate row', @TestRectOutlineDegenerateRow);
  T.Test('rect outline degenerate col', @TestRectOutlineDegenerateCol);
  T.Test('rect outline single point', @TestRectOutlineSinglePoint);
  T.Test('rect fill', @TestRectFill);
  T.Test('rect fill degenerate', @TestRectFillDegenerate);
  T.Test('ellipse circle', @TestEllipseCircle);
  T.Test('ellipse degenerate point', @TestEllipseDegeneratePoint);
  T.Test('ellipse degenerate line', @TestEllipseDegenerateLine);
  T.Test('ellipse degenerate row', @TestEllipseDegenerateRow);
  T.Test('ellipse fill', @TestEllipseFill);
  T.Test('ellipse fill wide', @TestEllipseFillWide);
  if not T.Run then Halt(1);
end.