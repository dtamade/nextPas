unit nextpas.core.tui.widget.linechart;

// Line chart widget with braille rendering, axes, and multiple series.
//
// Uses TCanvas internally for braille dot rendering. Supports:
//   - Multiple data series with individual styles
//   - Y axis with min/max labels (optional)
//   - X axis (optional)
//   - Legend row showing series names (optional)
//   - Auto-scaling or manual Y range

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  SysUtils,
  nextpas.core.text.width, nextpas.core.text.utf8,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.canvas,
  nextpas.core.tui.widget.intf;

type
  TDataSeries = record
    Name: AnsiString;
    Data: array of Double;
    Style: TStyle;
    class function Create(const AName: AnsiString; const AData: array of Double): TDataSeries; static;
    function WithStyle(const S: TStyle): TDataSeries;
  end;

  TLineChart = record
    Series: array of TDataSeries;
    MinY, MaxY: Double;
    ShowAxes: Boolean;
    ShowLegend: Boolean;
    Style: TStyle;
    AxisStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const ASeries: array of TDataSeries): TLineChart; static;
    function WithYRange(AMin, AMax: Double): TLineChart;
    function WithShowAxes(V: Boolean): TLineChart;
    function WithShowLegend(V: Boolean): TLineChart;
    function WithStyle(const S: TStyle): TLineChart;
    function WithAxisStyle(const S: TStyle): TLineChart;
    function WithBlock(const B: TBlock): TLineChart;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

{ TDataSeries }

class function TDataSeries.Create(const AName: AnsiString; const AData: array of Double): TDataSeries;
var
  I: Integer;
begin
  Result.Name := AName;
  SetLength(Result.Data, Length(AData));
  for I := 0 to High(AData) do
    Result.Data[I] := AData[I];
  Result.Style := TStyle.Default;
end;

function TDataSeries.WithStyle(const S: TStyle): TDataSeries;
begin
  Result := Self;
  Result.Style := S;
end;

{ TLineChart }

class function TLineChart.Create(const ASeries: array of TDataSeries): TLineChart;
var
  I: Integer;
begin
  SetLength(Result.Series, Length(ASeries));
  for I := 0 to High(ASeries) do
    Result.Series[I] := ASeries[I];
  Result.MinY := 0.0;
  Result.MaxY := 0.0;
  Result.ShowAxes := True;
  Result.ShowLegend := True;
  Result.Style := TStyle.Default;
  Result.AxisStyle := TStyle.Default;
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TLineChart.WithYRange(AMin, AMax: Double): TLineChart;
begin
  Result := Self;
  Result.MinY := AMin;
  Result.MaxY := AMax;
end;

function TLineChart.WithShowAxes(V: Boolean): TLineChart;
begin
  Result := Self;
  Result.ShowAxes := V;
end;

function TLineChart.WithShowLegend(V: Boolean): TLineChart;
begin
  Result := Self;
  Result.ShowLegend := V;
end;

function TLineChart.WithStyle(const S: TStyle): TLineChart;
begin
  Result := Self;
  Result.Style := S;
end;

function TLineChart.WithAxisStyle(const S: TStyle): TLineChart;
begin
  Result := Self;
  Result.AxisStyle := S;
end;

function TLineChart.WithBlock(const B: TBlock): TLineChart;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := B;
end;

procedure TLineChart.Render(const Area: TRect; ABuf: TBuffer);
var
  Inner: TRect;
  ChartArea: TRect;
  N, SI, I, DataLen: Integer;
  ActualMin, ActualMax, Val, Range: Double;
  Canvas: ICanvas;
  CellW, CellH: Integer;
  PrevX, PrevY, CurX, CurY: Integer;
  YAxisWidth, XAxisHeight, LegendHeight: Integer;
  MaxLabelStr, MinLabelStr: AnsiString;
  LegendX: Integer;
begin
  if Area.IsEmpty then Exit;

  // Handle block
  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  // Determine Y range across all series
  ActualMin := MinY;
  ActualMax := MaxY;
  if (ActualMin = 0.0) and (ActualMax = 0.0) then
  begin
    // Auto-scale: find global min/max
    ActualMin := 1.0E308;
    ActualMax := -1.0E308;
    for SI := 0 to High(Series) do
    begin
      DataLen := Length(Series[SI].Data);
      for I := 0 to DataLen - 1 do
      begin
        Val := Series[SI].Data[I];
        if Val < ActualMin then ActualMin := Val;
        if Val > ActualMax then ActualMax := Val;
      end;
    end;
    if ActualMin > ActualMax then
    begin
      ActualMin := 0.0;
      ActualMax := 1.0;
    end;
  end;
  Range := ActualMax - ActualMin;
  if Range <= 0.0 then
    Range := 1.0;

  // Calculate layout reservations
  YAxisWidth := 0;
  XAxisHeight := 0;
  LegendHeight := 0;

  if ShowAxes then
  begin
    YAxisWidth := 5;  // space for Y labels + axis line
    XAxisHeight := 1; // bottom row for X axis
  end;
  if ShowLegend then
    LegendHeight := 1;

  // Chart drawing area (in cells)
  ChartArea.X := Inner.X + YAxisWidth;
  ChartArea.Y := Inner.Y + LegendHeight;
  ChartArea.Width := Inner.Width - YAxisWidth;
  ChartArea.Height := Inner.Height - LegendHeight - XAxisHeight;

  if (ChartArea.Width <= 0) or (ChartArea.Height <= 0) then Exit;

  CellW := ChartArea.Width;
  CellH := ChartArea.Height;

  // Draw axes if enabled
  if ShowAxes then
  begin
    // Y axis: vertical line at left edge of chart area
    for I := 0 to CellH - 1 do
      ABuf.SetStringN(ChartArea.X - 1, ChartArea.Y + I, #$E2#$94#$82, 1, AxisStyle);

    // X axis: horizontal line at bottom of chart area
    for I := 0 to CellW - 1 do
      ABuf.SetStringN(ChartArea.X + I, ChartArea.Y + CellH, #$E2#$94#$80, 1, AxisStyle);

    // Corner
    ABuf.SetStringN(ChartArea.X - 1, ChartArea.Y + CellH, #$E2#$94#$94, 1, AxisStyle);

    // Y axis labels
    MaxLabelStr := IntToStr(Trunc(ActualMax + 0.5));
    MinLabelStr := IntToStr(Trunc(ActualMin + 0.5));
    if Length(MaxLabelStr) <= YAxisWidth - 1 then
      ABuf.SetStringN(Inner.X, ChartArea.Y, MaxLabelStr, YAxisWidth - 1, AxisStyle);
    if Length(MinLabelStr) <= YAxisWidth - 1 then
      ABuf.SetStringN(Inner.X, ChartArea.Y + CellH - 1, MinLabelStr, YAxisWidth - 1, AxisStyle);
  end;

  // Draw legend if enabled
  if ShowLegend then
  begin
    LegendX := Inner.X;
    for SI := 0 to High(Series) do
    begin
      if LegendX >= Inner.X + Inner.Width then Break;
      ABuf.SetStringN(LegendX, Inner.Y, Series[SI].Name, Integer(StringDisplayWidth(Series[SI].Name)), Series[SI].Style);
      Inc(LegendX, Integer(StringDisplayWidth(Series[SI].Name) + 2));
    end;
  end;

  // Render each series using a canvas
  for SI := 0 to High(Series) do
  begin
    DataLen := Length(Series[SI].Data);
    if DataLen = 0 then Continue;

    Canvas := TCanvas.New(CellW, CellH);
    Canvas := Canvas.WithStyle(Series[SI].Style);

    // Map data points to canvas dot coordinates and draw connected lines
    Val := Series[SI].Data[0];
    if Val < ActualMin then Val := ActualMin;
    if Val > ActualMax then Val := ActualMax;
    PrevX := 0;
    PrevY := Canvas.Height - 1 - Trunc(((Val - ActualMin) / Range) * (Canvas.Height - 1) + 0.5);
    if PrevY < 0 then PrevY := 0;
    if PrevY >= Canvas.Height then PrevY := Canvas.Height - 1;

    if DataLen = 1 then
      Canvas.SetDot(PrevX, PrevY)
    else
    begin
      for I := 1 to DataLen - 1 do
      begin
        Val := Series[SI].Data[I];
        if Val < ActualMin then Val := ActualMin;
        if Val > ActualMax then Val := ActualMax;

        if Canvas.Width > 1 then
          CurX := (I * (Canvas.Width - 1)) div (DataLen - 1)
        else
          CurX := 0;

        CurY := Canvas.Height - 1 - Trunc(((Val - ActualMin) / Range) * (Canvas.Height - 1) + 0.5);
        if CurY < 0 then CurY := 0;
        if CurY >= Canvas.Height then CurY := Canvas.Height - 1;

        Canvas.DrawLine(PrevX, PrevY, CurX, CurY);
        PrevX := CurX;
        PrevY := CurY;
      end;
    end;

    Canvas.Render(ChartArea, ABuf);
  end;
end;

end.
