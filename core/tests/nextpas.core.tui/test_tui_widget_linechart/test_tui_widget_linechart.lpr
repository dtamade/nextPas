program test_tui_widget_linechart;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.linechart,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestDataSeriesCreate;
var
  LSeries: TDataSeries;
begin
  LSeries := TDataSeries.Create('Test', [1.0, 2.0, 3.0]);
  Check(LSeries.Name = 'Test', 'Name should be Test');
  Check(Length(LSeries.Data) = 3, 'Data length should be 3');
  Check(LSeries.Data[0] = 1.0, 'First data point should be 1.0');
  Check(LSeries.Data[1] = 2.0, 'Second data point should be 2.0');
  Check(LSeries.Data[2] = 3.0, 'Third data point should be 3.0');
end;

procedure TestDataSeriesWithStyle;
var
  LSeries: TDataSeries;
  LStyle: TStyle;
begin
  LSeries := TDataSeries.Create('Test', [1.0, 2.0]);
  LStyle.Fg := IndexedColor(1);
  LSeries := LSeries.WithStyle(LStyle);
  Check(LSeries.Name = 'Test', 'Name should still be Test');
end;

procedure TestLineChartNew;
var
  LChart: ILineChart;
  LSeries: array[0..0] of TDataSeries;
begin
  LSeries[0] := TDataSeries.Create('Series 1', [1.0, 2.0, 3.0]);
  LChart := TLineChart.New(LSeries);
  Check(LChart <> nil, 'New linechart should not be nil');
end;

procedure TestLineChartNewEmpty;
var
  LChart: ILineChart;
begin
  LChart := TLineChart.New([]);
  Check(LChart <> nil, 'New empty linechart should not be nil');
end;

procedure TestLineChartWithYRange;
var
  LChart: ILineChart;
begin
  LChart := TLineChart.New([]);
  LChart := LChart.WithYRange(0.0, 100.0);
  Check(LChart <> nil, 'WithYRange should return linechart');
end;

procedure TestLineChartWithShowAxes;
var
  LChart: ILineChart;
begin
  LChart := TLineChart.New([]);
  LChart := LChart.WithShowAxes(False);
  Check(LChart <> nil, 'WithShowAxes should return linechart');
end;

procedure TestLineChartWithShowLegend;
var
  LChart: ILineChart;
begin
  LChart := TLineChart.New([]);
  LChart := LChart.WithShowLegend(False);
  Check(LChart <> nil, 'WithShowLegend should return linechart');
end;

procedure TestLineChartWithStyle;
var
  LChart: ILineChart;
  LStyle: TStyle;
begin
  LChart := TLineChart.New([]);
  LStyle.Fg := IndexedColor(1);
  LChart := LChart.WithStyle(LStyle);
  Check(LChart <> nil, 'WithStyle should return linechart');
end;

procedure TestLineChartWithAxisStyle;
var
  LChart: ILineChart;
  LStyle: TStyle;
begin
  LChart := TLineChart.New([]);
  LStyle.Fg := IndexedColor(2);
  LChart := LChart.WithAxisStyle(LStyle);
  Check(LChart <> nil, 'WithAxisStyle should return linechart');
end;

procedure TestLineChartWithBlock;
var
  LChart: ILineChart;
  LBlock: IBlock;
begin
  LChart := TLineChart.New([]);
  LBlock := TBlock.New;
  LChart := LChart.WithBlock(LBlock);
  Check(LChart <> nil, 'WithBlock should return linechart');
end;

procedure TestLineChartRender;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
  LArea: TRect;
  LSeries: array[0..0] of TDataSeries;
begin
  LSeries[0] := TDataSeries.Create('Series 1', [1.0, 3.0, 2.0, 5.0, 4.0]);
  LChart := TLineChart.New(LSeries);
  LArea := TRect.Make(0, 0, 30, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LChart.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestLineChartBuilderChaining;
var
  LChart: ILineChart;
  LStyle: TStyle;
  LBlock: IBlock;
begin
  LChart := TLineChart.New([]);
  LStyle.Fg := IndexedColor(1);
  LBlock := TBlock.New;
  LChart := LChart
    .WithYRange(0.0, 100.0)
    .WithShowAxes(True)
    .WithShowLegend(True)
    .WithStyle(LStyle)
    .WithAxisStyle(LStyle)
    .WithBlock(LBlock);
  Check(LChart <> nil, 'Builder chaining should work');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.linechart');
  T.Test('TDataSeries.Create', @TestDataSeriesCreate);
  T.Test('TDataSeries.WithStyle', @TestDataSeriesWithStyle);
  T.Test('TLineChart.New', @TestLineChartNew);
  T.Test('TLineChart.New empty', @TestLineChartNewEmpty);
  T.Test('TLineChart.WithYRange', @TestLineChartWithYRange);
  T.Test('TLineChart.WithShowAxes', @TestLineChartWithShowAxes);
  T.Test('TLineChart.WithShowLegend', @TestLineChartWithShowLegend);
  T.Test('TLineChart.WithStyle', @TestLineChartWithStyle);
  T.Test('TLineChart.WithAxisStyle', @TestLineChartWithAxisStyle);
  T.Test('TLineChart.WithBlock', @TestLineChartWithBlock);
  T.Test('TLineChart.Render', @TestLineChartRender);
  T.Test('TLineChart builder chaining', @TestLineChartBuilderChaining);
  if not T.Run then Halt(1);
end.
