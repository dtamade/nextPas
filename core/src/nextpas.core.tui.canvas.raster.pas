unit nextpas.core.tui.canvas.raster;

{**
 * @desc 字符像素光栅化纯函数集（不依赖文档模型，通过回调输出像素点）。
 *
 * 直线采用 Bresenham 算法，从起点到终点按序逐点回调（同一格不会重复
 * 出现），适合画刷拖动插值。矩形与椭圆先做边界归一化（坐标可任意顺序）。
 * 椭圆采用逐行区间法：描边与填充同源，视觉一致、代码单路径。
 *
 * 调用方负责裁剪与写入：回调内可用 TCanvasDoc.CellPtr 直接命中写入。
 *
 * @note 区域坐标按 Integer 范围假设 |X1-X0|、|Y1-Y0| ≤ 2^20；
 *       椭圆内部以 Int64 做平方运算，避免中间量溢出。
 *}

{$I nextpas.core.settings.inc}

interface

type
  { 逐点回调。回调实现方负责裁剪与写入。 }
  TRasterPointProc = procedure(AX, AY: Integer) of object;

  { 直线：Bresenham，含两端点，按路径顺序逐点回调。 }
  procedure RasterLine(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
  { 矩形边线（坐标归一化，不含重复角点）。 }
  procedure RasterRectOutline(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
  { 实心矩形（坐标归一化）。 }
  procedure RasterRectFill(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
  { 椭圆边线（边界框内逐行左右端点）。 }
  procedure RasterEllipseOutline(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
  { 实心椭圆（边界框内逐行填充）。 }
  procedure RasterEllipseFill(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);

implementation

procedure SwapInt(var A, B: Integer);
var
  T: Integer;
begin
  T := A; A := B; B := T;
end;

procedure RasterLine(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
var
  DX, DY, SX, SY, Err, E2: Integer;
begin
  DX := Abs(X1 - X0);
  DY := -Abs(Y1 - Y0);
  if X0 < X1 then SX := 1 else SX := -1;
  if Y0 < Y1 then SY := 1 else SY := -1;
  Err := DX + DY;
  while True do
  begin
    OnPoint(X0, Y0);
    if (X0 = X1) and (Y0 = Y1) then
      Break;
    E2 := 2 * Err;
    if E2 >= DY then
    begin
      Err := Err + DY;
      X0 := X0 + SX;
    end;
    if E2 <= DX then
    begin
      Err := Err + DX;
      Y0 := Y0 + SY;
    end;
  end;
end;

procedure RasterRectOutline(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
var
  X, Y: Integer;
begin
  if X0 > X1 then SwapInt(X0, X1);
  if Y0 > Y1 then SwapInt(Y0, Y1);
  if Y0 = Y1 then
  begin
    { 退化：单行，每格只画一次 }
    for X := X0 to X1 do
      OnPoint(X, Y0);
    Exit;
  end;
  if X0 = X1 then
  begin
    { 退化：单列 }
    for Y := Y0 to Y1 do
      OnPoint(X0, Y);
    Exit;
  end;
  for X := X0 to X1 do
  begin
    OnPoint(X, Y0);
    OnPoint(X, Y1);
  end;
  for Y := Y0 + 1 to Y1 - 1 do
  begin
    OnPoint(X0, Y);
    OnPoint(X1, Y);
  end;
end;

procedure RasterRectFill(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
var
  X, Y: Integer;
begin
  if X0 > X1 then SwapInt(X0, X1);
  if Y0 > Y1 then SwapInt(Y0, Y1);
  for Y := Y0 to Y1 do
    for X := X0 to X1 do
      OnPoint(X, Y);
end;

{ 椭圆逐行区间：dy ∈ [-ry, ry]，dx = round(rx*sqrt(1-(dy/ry)^2)) }
procedure EllipseRows(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc; AFilled: Boolean);
var
  RX, RY, CX, CY: Integer;
  Y, DY: Integer;
  DX: Integer;
  T: Double;
  X: Integer;
begin
  if X0 > X1 then SwapInt(X0, X1);
  if Y0 > Y1 then SwapInt(Y0, Y1);
  RX := (X1 - X0) div 2;
  RY := (Y1 - Y0) div 2;
  CX := X0 + RX;
  CY := Y0 + RY;

  if (RX = 0) and (RY = 0) then
  begin
    OnPoint(CX, CY);
    Exit;
  end;
  if RX = 0 then
  begin
    for Y := Y0 to Y1 do
      OnPoint(CX, Y);
    Exit;
  end;
  if RY = 0 then
  begin
    for X := X0 to X1 do
      OnPoint(X, CY);
    Exit;
  end;

  for Y := Y0 to Y1 do
  begin
    DY := Y - CY;
    T := 1.0 - (Int64(DY) * Int64(DY)) / (Int64(RY) * Int64(RY));
    if T < 0.0 then
      T := 0.0;
    DX := Round(RX * Sqrt(T));
    if DX < 0 then DX := 0;
    if DX > RX then DX := RX;
    if AFilled then
    begin
      for X := CX - DX to CX + DX do
        OnPoint(X, Y);
    end
    else
    begin
      OnPoint(CX - DX, Y);
      if DX > 0 then
        OnPoint(CX + DX, Y);
    end;
  end;
end;

procedure RasterEllipseOutline(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
begin
  EllipseRows(X0, Y0, X1, Y1, OnPoint, False);
end;

procedure RasterEllipseFill(X0, Y0, X1, Y1: Integer; const OnPoint: TRasterPointProc);
begin
  EllipseRows(X0, Y0, X1, Y1, OnPoint, True);
end;

end.