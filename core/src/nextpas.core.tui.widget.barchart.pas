unit nextpas.core.tui.widget.barchart;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf;

type
  TBarData = record
    Label_: AnsiString;
    Value: Double;
    Style: TStyle;
    class function Make(const ALabel: AnsiString; AValue: Double): TBarData; static;
    function WithStyle(const S: TStyle): TBarData;
  end;

  IBarChart = interface(IWidget)
    ['{D4E5F6A7-B8C9-0123-DEFA-456789012345}']
    function WithMax(M: Double): IBarChart;
    function WithBarWidth(W: Integer): IBarChart;
    function WithBarGap(G: Integer): IBarChart;
    function WithShowValues(V: Boolean): IBarChart;
    function WithShowLabels(L: Boolean): IBarChart;
    function WithStyle(const S: TStyle): IBarChart;
    function WithBlock(ABlock: IBlock): IBarChart;
  end;

  TBarChart = class(TInterfacedObject, IWidget, IBarChart)
  private
    FBars: array of TBarData;
    FMaxVal: Double;
    FBarWidth: Integer;
    FBarGap: Integer;
    FShowValues: Boolean;
    FShowLabels: Boolean;
    FStyle: TStyle;
    FBlock: IBlock;
  public
    class function New(const ABars: array of TBarData): IBarChart; static;

    function WithMax(M: Double): IBarChart;
    function WithBarWidth(W: Integer): IBarChart;
    function WithBarGap(G: Integer): IBarChart;
    function WithShowValues(V: Boolean): IBarChart;
    function WithShowLabels(L: Boolean): IBarChart;
    function WithStyle(const S: TStyle): IBarChart;
    function WithBlock(ABlock: IBlock): IBarChart;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

implementation

const
  LOWER_EIGHTHS: array[1..8] of AnsiString = (
    #$E2#$96#$81,
    #$E2#$96#$82,
    #$E2#$96#$83,
    #$E2#$96#$84,
    #$E2#$96#$85,
    #$E2#$96#$86,
    #$E2#$96#$87,
    #$E2#$96#$88
  );

{ TBarData }

class function TBarData.Make(const ALabel: AnsiString; AValue: Double): TBarData;
begin
  Result.Label_ := ALabel;
  Result.Value := AValue;
  Result.Style := TStyle.Default;
end;

function TBarData.WithStyle(const S: TStyle): TBarData;
begin
  Result := Self;
  Result.Style := S;
end;

{ TBarChart }

class function TBarChart.New(const ABars: array of TBarData): IBarChart;
var
  LSelf: TBarChart;
  I: Integer;
begin
  LSelf := TBarChart.Create;
  SetLength(LSelf.FBars, Length(ABars));
  for I := 0 to High(ABars) do
    LSelf.FBars[I] := ABars[I];
  LSelf.FMaxVal := 0.0;
  LSelf.FBarWidth := 3;
  LSelf.FBarGap := 1;
  LSelf.FShowValues := True;
  LSelf.FShowLabels := True;
  LSelf.FStyle := TStyle.Default;
  LSelf.FBlock := nil;
  Result := LSelf;
end;

function TBarChart.WithMax(M: Double): IBarChart;
begin
  FMaxVal := M;
  Result := Self;
end;

function TBarChart.WithBarWidth(W: Integer): IBarChart;
begin
  if W < 1 then W := 1;
  FBarWidth := W;
  Result := Self;
end;

function TBarChart.WithBarGap(G: Integer): IBarChart;
begin
  if G < 0 then G := 0;
  FBarGap := G;
  Result := Self;
end;

function TBarChart.WithShowValues(V: Boolean): IBarChart;
begin
  FShowValues := V;
  Result := Self;
end;

function TBarChart.WithShowLabels(L: Boolean): IBarChart;
begin
  FShowLabels := L;
  Result := Self;
end;

function TBarChart.WithStyle(const S: TStyle): IBarChart;
begin
  FStyle := S;
  Result := Self;
end;

function TBarChart.WithBlock(ABlock: IBlock): IBarChart;
begin
  FBlock := ABlock;
  Result := Self;
end;

procedure TBarChart.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Inner: TRect;
  N: Integer;
  ActualMax: Double;
  I, Col, Row: Integer;
  BarAreaTop, BarAreaBottom, BarAreaHeight: Integer;
  BarX: Integer;
  Ratio: Double;
  FilledEighths, FullRows, FracEighths: Integer;
  DrawX, DrawY: Integer;
  ValStr: AnsiString;
  LabelStr: AnsiString;
  LabelX, ValX: Integer;
  Sty: TStyle;
begin
  if AArea.IsEmpty then Exit;
  N := Length(FBars);
  if N = 0 then Exit;

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if Inner.IsEmpty then Exit;

  ActualMax := FMaxVal;
  if ActualMax <= 0.0 then
  begin
    ActualMax := 0.0;
    for I := 0 to N - 1 do
      if FBars[I].Value > ActualMax then
        ActualMax := FBars[I].Value;
  end;
  if ActualMax <= 0.0 then
    ActualMax := 1.0;

  BarAreaTop := Inner.Y;
  BarAreaBottom := Inner.Y + Inner.Height - 1;

  if FShowValues then
    Inc(BarAreaTop);
  if FShowLabels then
    Dec(BarAreaBottom);

  BarAreaHeight := BarAreaBottom - BarAreaTop + 1;
  if BarAreaHeight <= 0 then Exit;

  for I := 0 to N - 1 do
  begin
    BarX := Inner.X + I * (FBarWidth + FBarGap);
    if BarX >= Inner.X + Inner.Width then Break;

    Sty := FBars[I].Style;

    Ratio := FBars[I].Value / ActualMax;
    if Ratio < 0.0 then Ratio := 0.0;
    if Ratio > 1.0 then Ratio := 1.0;
    FilledEighths := Trunc(Ratio * BarAreaHeight * 8 + 0.5);
    FullRows := FilledEighths div 8;
    FracEighths := FilledEighths mod 8;

    for Row := 0 to FullRows - 1 do
    begin
      DrawY := BarAreaBottom - Row;
      if DrawY < BarAreaTop then Break;
      for Col := 0 to FBarWidth - 1 do
      begin
        DrawX := BarX + Col;
        if DrawX >= Inner.X + Inner.Width then Break;
        ABuffer.SetStringN(DrawX, DrawY, LOWER_EIGHTHS[8], 1, Sty);
      end;
    end;

    if (FracEighths > 0) and (FullRows < BarAreaHeight) then
    begin
      DrawY := BarAreaBottom - FullRows;
      if DrawY >= BarAreaTop then
      begin
        for Col := 0 to FBarWidth - 1 do
        begin
          DrawX := BarX + Col;
          if DrawX >= Inner.X + Inner.Width then Break;
          ABuffer.SetStringN(DrawX, DrawY, LOWER_EIGHTHS[FracEighths], 1, Sty);
        end;
      end;
    end;

    if FShowValues then
    begin
      ValStr := IntToStr(Trunc(FBars[I].Value + 0.5));
      ValX := BarX + (FBarWidth - Length(ValStr)) div 2;
      if ValX < BarX then ValX := BarX;
      if ValX >= Inner.X + Inner.Width then Continue;
      ABuffer.SetStringN(ValX, Inner.Y, ValStr, FBarWidth, FStyle);
    end;

    if FShowLabels then
    begin
      LabelStr := FBars[I].Label_;
      LabelX := BarX + (FBarWidth - Length(LabelStr)) div 2;
      if LabelX < BarX then LabelX := BarX;
      if LabelX >= Inner.X + Inner.Width then Continue;
      ABuffer.SetStringN(LabelX, Inner.Y + Inner.Height - 1, LabelStr, FBarWidth, FStyle);
    end;
  end;
end;

end.
