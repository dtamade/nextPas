program test_tui_widget_linechart;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
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

procedure TestLineChartRenderEmpty;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
begin
  LChart := TLineChart.New([]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LChart.Render(TRect.Make(0, 0, 20, 10), LBuffer);
    Check(True, 'Empty linechart renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestLineChartRenderWithBlock;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
  LSeries: array[0..0] of TDataSeries;
begin
  LSeries[0] := TDataSeries.Create('S', [1.0, 2.0, 3.0]);
  LChart := TLineChart.New(LSeries).WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LChart.Render(TRect.Make(0, 0, 20, 10), LBuffer);
    Check(True, 'Linechart with block renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestLineChartRenderEmptyArea;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
begin
  LChart := TLineChart.New([TDataSeries.Create('S', [1.0])]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    LChart.Render(TRect.Make(0, 0, 0, 0), LBuffer);
    Check(True, 'Empty area does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestLineChartSinglePoint;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
begin
  LChart := TLineChart.New([TDataSeries.Create('S', [42.0])]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    LChart.Render(TRect.Make(0, 0, 10, 5), LBuffer);
    Check(True, 'Single data point renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestLineChartRenderSmallArea;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
begin
  LChart := TLineChart.New([TDataSeries.Create('S', [1.0, 2.0])]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    LChart.Render(TRect.Make(0, 0, 5, 2), LBuffer);
    Check(True, 'Small area does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestLineChartMultipleSeries;
var
  LChart: ILineChart;
  LBuffer: TBuffer;
  LSeries: array[0..1] of TDataSeries;
begin
  LSeries[0] := TDataSeries.Create('A', [1.0, 2.0, 3.0]);
  LSeries[1] := TDataSeries.Create('B', [3.0, 2.0, 1.0]);
  LChart := TLineChart.New(LSeries);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LChart.Render(TRect.Make(0, 0, 20, 10), LBuffer);
    Check(True, 'Multiple series render');
  finally
    LBuffer.Free;
  end;
end;

procedure TestDataSeriesEmpty;
var
  LSeries: TDataSeries;
begin
  LSeries := TDataSeries.Create('Empty', []);
  Check(LSeries.Name = 'Empty', 'Name should be Empty');
  Check(Length(LSeries.Data) = 0, 'Data length should be 0');
end;

{ PH33 P3：数据更新面——SetSeries 原地替换系列集（图例名变化可观测） }
procedure TestLineChartSetSeries;
var LC: ILineChart; LBuf: TBuffer; LArea: TRect; LAll: AnsiString; I: Integer;
begin
  LArea := TRect.Make(0, 0, 40, 10);
  LC := TLineChart.New([TDataSeries.Create('old-name', [1.0, 2.0])]);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LC.SetSeries([TDataSeries.Create('fresh-series', [2.0, 1.0]),
      TDataSeries.Create('second-one', [1.5, 2.5])]);
    LC.Render(LArea, LBuf);
    LAll := '';
    for I := 0 to 9 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('fresh-series', LAll) > 0, 'legend shows new series name');
    Check(Pos('second-one', LAll) > 0, 'legend shows second series');
    Check(Pos('old-name', LAll) = 0, 'old series gone');
  finally LBuf.Free; end;
end;

procedure TestLineChartWithSeriesChaining;
var LC: ILineChart;
begin
  LC := TLineChart.New([TDataSeries.Create('a', [1.0])])
    .WithSeries([TDataSeries.Create('x', [2.0]), TDataSeries.Create('y', [3.0])]);
  Check(LC <> nil, 'WithSeries chains and returns interface');
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
  T.Test('render empty', @TestLineChartRenderEmpty);
  T.Test('render with block', @TestLineChartRenderWithBlock);
  T.Test('render empty area', @TestLineChartRenderEmptyArea);
  T.Test('single data point', @TestLineChartSinglePoint);
  T.Test('render small area', @TestLineChartRenderSmallArea);
  T.Test('multiple series', @TestLineChartMultipleSeries);
  T.Test('TDataSeries empty', @TestDataSeriesEmpty);
  T.Test('SetSeries in-place update (PH33 P3)', @TestLineChartSetSeries);
  T.Test('WithSeries chaining (PH33 P3)', @TestLineChartWithSeriesChaining);
  if not T.Run then Halt(1);
end.
