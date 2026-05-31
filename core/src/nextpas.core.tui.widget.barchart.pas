unit nextpas.core.tui.widget.barchart;

// Vertical bar chart widget with Unicode block character precision.
//
// Each bar is BarWidth cells wide with BarGap cells between bars.
// Bars grow upward from the bottom of the area. Sub-cell precision
// uses Unicode lower block characters (U+2581..U+2588) for the
// fractional row at the top of each bar.
//
// Optional labels (1 row at bottom) and values (1 row at top).

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
  nextpas.core.tui.borders;

type
  TBarData = record
    Label_: AnsiString;
    Value: Double;
    Style: TStyle;
    class function Make(const ALabel: AnsiString; AValue: Double): TBarData; static;
    function WithStyle(const S: TStyle): TBarData;
  end;

  TBarChart = record
    Bars: array of TBarData;
    MaxVal: Double;
    BarWidth: Integer;
    BarGap: Integer;
    ShowValues: Boolean;
    ShowLabels: Boolean;
    Style: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Create(const ABars: array of TBarData): TBarChart; static;
    function WithMax(M: Double): TBarChart;
    function WithBarWidth(W: Integer): TBarChart;
    function WithBarGap(G: Integer): TBarChart;
    function WithShowValues(V: Boolean): TBarChart;
    function WithShowLabels(L: Boolean): TBarChart;
    function WithStyle(const S: TStyle): TBarChart;
    function WithBlock(ABlock: IBlock): TBarChart;
    procedure Render(const Area: TRect; ABuf: TBuffer);
  end;

implementation

// Unicode lower block characters for sub-cell vertical precision.
// LOWER_EIGHTHS[1] = lower 1/8, ..., LOWER_EIGHTHS[8] = full block.
const
  LOWER_EIGHTHS: array[1..8] of AnsiString = (
    #$E2#$96#$81,   // U+2581 LOWER ONE EIGHTH BLOCK
    #$E2#$96#$82,   // U+2582 LOWER ONE QUARTER BLOCK
    #$E2#$96#$83,   // U+2583 LOWER THREE EIGHTHS BLOCK
    #$E2#$96#$84,   // U+2584 LOWER HALF BLOCK
    #$E2#$96#$85,   // U+2585 LOWER FIVE EIGHTHS BLOCK
    #$E2#$96#$86,   // U+2586 LOWER THREE QUARTERS BLOCK
    #$E2#$96#$87,   // U+2587 LOWER SEVEN EIGHTHS BLOCK
    #$E2#$96#$88    // U+2588 FULL BLOCK
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

class function TBarChart.Create(const ABars: array of TBarData): TBarChart;
var
  I: Integer;
begin
  SetLength(Result.Bars, Length(ABars));
  for I := 0 to High(ABars) do
    Result.Bars[I] := ABars[I];
  Result.MaxVal := 0.0;
  Result.BarWidth := 3;
  Result.BarGap := 1;
  Result.ShowValues := True;
  Result.ShowLabels := True;
  Result.Style := TStyle.Default;
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TBarChart.WithMax(M: Double): TBarChart;
begin
  Result := Self;
  Result.MaxVal := M;
end;

function TBarChart.WithBarWidth(W: Integer): TBarChart;
begin
  Result := Self;
  if W < 1 then W := 1;
  Result.BarWidth := W;
end;

function TBarChart.WithBarGap(G: Integer): TBarChart;
begin
  Result := Self;
  if G < 0 then G := 0;
  Result.BarGap := G;
end;

function TBarChart.WithShowValues(V: Boolean): TBarChart;
begin
  Result := Self;
  Result.ShowValues := V;
end;

function TBarChart.WithShowLabels(L: Boolean): TBarChart;
begin
  Result := Self;
  Result.ShowLabels := L;
end;

function TBarChart.WithStyle(const S: TStyle): TBarChart;
begin
  Result := Self;
  Result.Style := S;
end;

function TBarChart.WithBlock(ABlock: IBlock): TBarChart;
begin
  Result := Self;
  Result.HasBlock := True;
  Result.Block := ABlock;
end;

procedure TBarChart.Render(const Area: TRect; ABuf: TBuffer);
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
  if Area.IsEmpty then Exit;
  N := Length(Bars);
  if N = 0 then Exit;

  // Handle block
  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if Inner.IsEmpty then Exit;

  // Determine actual max value
  ActualMax := MaxVal;
  if ActualMax <= 0.0 then
  begin
    ActualMax := 0.0;
    for I := 0 to N - 1 do
      if Bars[I].Value > ActualMax then
        ActualMax := Bars[I].Value;
  end;
  if ActualMax <= 0.0 then
    ActualMax := 1.0;

  // Calculate vertical layout
  BarAreaTop := Inner.Y;
  BarAreaBottom := Inner.Y + Inner.Height - 1;

  if ShowValues then
    Inc(BarAreaTop);  // reserve top row for values
  if ShowLabels then
    Dec(BarAreaBottom);  // reserve bottom row for labels

  BarAreaHeight := BarAreaBottom - BarAreaTop + 1;
  if BarAreaHeight <= 0 then Exit;

  // Render each bar
  for I := 0 to N - 1 do
  begin
    // Calculate horizontal position of this bar
    BarX := Inner.X + I * (BarWidth + BarGap);
    if BarX >= Inner.X + Inner.Width then Break;

    // Determine bar style
    Sty := Bars[I].Style;

    // Calculate bar height in eighths
    Ratio := Bars[I].Value / ActualMax;
    if Ratio < 0.0 then Ratio := 0.0;
    if Ratio > 1.0 then Ratio := 1.0;
    FilledEighths := Trunc(Ratio * BarAreaHeight * 8 + 0.5);
    FullRows := FilledEighths div 8;
    FracEighths := FilledEighths mod 8;

    // Draw full block rows (from bottom up)
    for Row := 0 to FullRows - 1 do
    begin
      DrawY := BarAreaBottom - Row;
      if DrawY < BarAreaTop then Break;
      for Col := 0 to BarWidth - 1 do
      begin
        DrawX := BarX + Col;
        if DrawX >= Inner.X + Inner.Width then Break;
        ABuf.SetStringN(DrawX, DrawY, LOWER_EIGHTHS[8], 1, Sty);
      end;
    end;

    // Draw fractional row
    if (FracEighths > 0) and (FullRows < BarAreaHeight) then
    begin
      DrawY := BarAreaBottom - FullRows;
      if DrawY >= BarAreaTop then
      begin
        for Col := 0 to BarWidth - 1 do
        begin
          DrawX := BarX + Col;
          if DrawX >= Inner.X + Inner.Width then Break;
          ABuf.SetStringN(DrawX, DrawY, LOWER_EIGHTHS[FracEighths], 1, Sty);
        end;
      end;
    end;

    // Draw value above bar
    if ShowValues then
    begin
      ValStr := IntToStr(Trunc(Bars[I].Value + 0.5));
      ValX := BarX + (BarWidth - Length(ValStr)) div 2;
      if ValX < BarX then ValX := BarX;
      if ValX >= Inner.X + Inner.Width then Continue;
      ABuf.SetStringN(ValX, Inner.Y, ValStr, BarWidth, Style);
    end;

    // Draw label below bar
    if ShowLabels then
    begin
      LabelStr := Bars[I].Label_;
      LabelX := BarX + (BarWidth - Length(LabelStr)) div 2;
      if LabelX < BarX then LabelX := BarX;
      if LabelX >= Inner.X + Inner.Width then Continue;
      ABuf.SetStringN(LabelX, Inner.Y + Inner.Height - 1, LabelStr, BarWidth, Style);
    end;
  end;
end;

end.
