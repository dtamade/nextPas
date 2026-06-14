unit nextpas.core.tui.widget.linechart;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses nextpas.core.text.width, nextpas.core.text.utf8, nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.modifier, nextpas.core.tui.style, nextpas.core.tui.cell, nextpas.core.tui.buffer, nextpas.core.tui.widget.block, nextpas.core.tui.borders, nextpas.core.tui.widget.canvas, nextpas.core.tui.widget.intf, nextpas.core.text.conv;

type
  TDataSeries = record
    Name: AnsiString;
    Data: array of Double;
    Style: TStyle;
    class function Create(const AName: AnsiString; const AData: array of Double): TDataSeries; static;
    function WithStyle(const S: TStyle): TDataSeries;
  end;

  ILineChart = interface(IWidget)
    ['{D6E7F8A9-B0C1-2345-DEFA-678901234567}']
    function WithYRange(AMin, AMax: Double): ILineChart;
    function WithShowAxes(V: Boolean): ILineChart;
    function WithShowLegend(V: Boolean): ILineChart;
    function WithStyle(const S: TStyle): ILineChart;
    function WithAxisStyle(const S: TStyle): ILineChart;
    function WithBlock(ABlock: IBlock): ILineChart;
  end;

  TLineChart = class(TInterfacedObject, IWidget, ILineChart)
  private
    FSeries: array of TDataSeries;
    FMinY, FMaxY: Double;
    FShowAxes: Boolean;
    FShowLegend: Boolean;
    FStyle: TStyle;
    FAxisStyle: TStyle;
    FBlock: IBlock;
  public
    class function New(const ASeries: array of TDataSeries): ILineChart; static;

    function WithYRange(AMin, AMax: Double): ILineChart;
    function WithShowAxes(V: Boolean): ILineChart;
    function WithShowLegend(V: Boolean): ILineChart;
    function WithStyle(const S: TStyle): ILineChart;
    function WithAxisStyle(const S: TStyle): ILineChart;
    function WithBlock(ABlock: IBlock): ILineChart;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

{ TDataSeries }

class function TDataSeries.Create(const AName: AnsiString; const AData: array of Double): TDataSeries;
var I: Integer;
begin
  Result.Name := AName;
  SetLength(Result.Data, Length(AData));
  for I := 0 to High(AData) do Result.Data[I] := AData[I];
  Result.Style := TStyle.Default;
end;

function TDataSeries.WithStyle(const S: TStyle): TDataSeries;
begin Result := Self; Result.Style := S; end;

{ TLineChart }

class function TLineChart.New(const ASeries: array of TDataSeries): ILineChart;
var LSelf: TLineChart; I: Integer;
begin
  LSelf := TLineChart.Create;
  SetLength(LSelf.FSeries, Length(ASeries));
  for I := 0 to High(ASeries) do LSelf.FSeries[I] := ASeries[I];
  LSelf.FMinY := 0.0; LSelf.FMaxY := 0.0;
  LSelf.FShowAxes := True; LSelf.FShowLegend := True;
  LSelf.FStyle := TStyle.Default;
  LSelf.FAxisStyle := TStyle.Default;
  LSelf.FBlock := nil;
  Result := LSelf;
end;

function TLineChart.WithYRange(AMin, AMax: Double): ILineChart;
begin FMinY := AMin; FMaxY := AMax; Result := Self; end;

function TLineChart.WithShowAxes(V: Boolean): ILineChart;
begin FShowAxes := V; Result := Self; end;

function TLineChart.WithShowLegend(V: Boolean): ILineChart;
begin FShowLegend := V; Result := Self; end;

function TLineChart.WithStyle(const S: TStyle): ILineChart;
begin FStyle := S; Result := Self; end;

function TLineChart.WithAxisStyle(const S: TStyle): ILineChart;
begin FAxisStyle := S; Result := Self; end;

function TLineChart.WithBlock(ABlock: IBlock): ILineChart;
begin FBlock := ABlock; Result := Self; end;

procedure TLineChart.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Inner, ChartArea: TRect;
  SI, I, DataLen: Integer;
  ActualMin, ActualMax, Val, Range: Double;
  LCanvas: ICanvas;
  CellW, CellH: Integer;
  PrevX, PrevY, CurX, CurY: Integer;
  YAxisWidth, XAxisHeight, LegendHeight: Integer;
  MaxLabelStr, MinLabelStr: AnsiString;
  LegendX: Integer;
begin
  if AArea.IsEmpty then Exit;

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  ActualMin := FMinY; ActualMax := FMaxY;
  if (ActualMin = 0.0) and (ActualMax = 0.0) then
  begin
    ActualMin := 1.0E308; ActualMax := -1.0E308;
    for SI := 0 to High(FSeries) do
    begin
      DataLen := Length(FSeries[SI].Data);
      for I := 0 to DataLen - 1 do
      begin
        Val := FSeries[SI].Data[I];
        if Val < ActualMin then ActualMin := Val;
        if Val > ActualMax then ActualMax := Val;
      end;
    end;
    if ActualMin > ActualMax then begin ActualMin := 0.0; ActualMax := 1.0; end;
  end;
  Range := ActualMax - ActualMin;
  if Range <= 0.0 then Range := 1.0;

  YAxisWidth := 0; XAxisHeight := 0; LegendHeight := 0;
  if FShowAxes then begin YAxisWidth := 5; XAxisHeight := 1; end;
  if FShowLegend then LegendHeight := 1;

  ChartArea.X := Inner.X + YAxisWidth;
  ChartArea.Y := Inner.Y + LegendHeight;
  ChartArea.Width := Inner.Width - YAxisWidth;
  ChartArea.Height := Inner.Height - LegendHeight - XAxisHeight;
  if (ChartArea.Width <= 0) or (ChartArea.Height <= 0) then Exit;

  CellW := ChartArea.Width; CellH := ChartArea.Height;

  if FShowAxes then
  begin
    for I := 0 to CellH - 1 do
      ABuffer.SetStringN(ChartArea.X - 1, ChartArea.Y + I, #$E2#$94#$82, 1, FAxisStyle);
    for I := 0 to CellW - 1 do
      ABuffer.SetStringN(ChartArea.X + I, ChartArea.Y + CellH, #$E2#$94#$80, 1, FAxisStyle);
    ABuffer.SetStringN(ChartArea.X - 1, ChartArea.Y + CellH, #$E2#$94#$94, 1, FAxisStyle);
    MaxLabelStr := IntToStr(Trunc(ActualMax + 0.5));
    MinLabelStr := IntToStr(Trunc(ActualMin + 0.5));
    if Length(MaxLabelStr) <= YAxisWidth - 1 then
      ABuffer.SetStringN(Inner.X, ChartArea.Y, MaxLabelStr, YAxisWidth - 1, FAxisStyle);
    if Length(MinLabelStr) <= YAxisWidth - 1 then
      ABuffer.SetStringN(Inner.X, ChartArea.Y + CellH - 1, MinLabelStr, YAxisWidth - 1, FAxisStyle);
  end;

  if FShowLegend then
  begin
    LegendX := Inner.X;
    for SI := 0 to High(FSeries) do
    begin
      if LegendX >= Inner.X + Inner.Width then Break;
      ABuffer.SetStringN(LegendX, Inner.Y, FSeries[SI].Name,
        Integer(StringDisplayWidth(FSeries[SI].Name)), FSeries[SI].Style);
      Inc(LegendX, Integer(StringDisplayWidth(FSeries[SI].Name) + 2));
    end;
  end;

  for SI := 0 to High(FSeries) do
  begin
    DataLen := Length(FSeries[SI].Data);
    if DataLen = 0 then Continue;
    LCanvas := TCanvas.New(CellW, CellH).WithStyle(FSeries[SI].Style);

    Val := FSeries[SI].Data[0];
    if Val < ActualMin then Val := ActualMin;
    if Val > ActualMax then Val := ActualMax;
    PrevX := 0;
    PrevY := LCanvas.Height - 1 - Trunc(((Val - ActualMin) / Range) * (LCanvas.Height - 1) + 0.5);
    if PrevY < 0 then PrevY := 0;
    if PrevY >= LCanvas.Height then PrevY := LCanvas.Height - 1;

    if DataLen = 1 then
      LCanvas.SetDot(PrevX, PrevY)
    else
      for I := 1 to DataLen - 1 do
      begin
        Val := FSeries[SI].Data[I];
        if Val < ActualMin then Val := ActualMin;
        if Val > ActualMax then Val := ActualMax;
        if LCanvas.Width > 1 then CurX := (I * (LCanvas.Width - 1)) div (DataLen - 1)
        else CurX := 0;
        CurY := LCanvas.Height - 1 - Trunc(((Val - ActualMin) / Range) * (LCanvas.Height - 1) + 0.5);
        if CurY < 0 then CurY := 0;
        if CurY >= LCanvas.Height then CurY := LCanvas.Height - 1;
        LCanvas.DrawLine(PrevX, PrevY, CurX, CurY);
        PrevX := CurX; PrevY := CurY;
      end;

    LCanvas.Render(ChartArea, ABuffer);
  end;
end;

end.
