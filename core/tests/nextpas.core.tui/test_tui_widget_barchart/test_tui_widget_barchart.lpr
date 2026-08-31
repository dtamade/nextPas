program test_tui_widget_barchart;

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
  nextpas.core.tui.widget.barchart,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestBarDataMake;
var
  LData: TBarData;
begin
  LData := TBarData.Make('Label', 42.0);
  Check(LData.Label_ = 'Label', 'Label should be Label');
  Check(LData.Value = 42.0, 'Value should be 42.0');
end;

procedure TestBarDataWithStyle;
var
  LData: TBarData;
  LStyle: TStyle;
begin
  LData := TBarData.Make('Test', 10.0);
  LStyle.Fg := IndexedColor(1);
  LData := LData.WithStyle(LStyle);
  Check(LData.Label_ = 'Test', 'Label should still be Test');
  Check(LData.Value = 10.0, 'Value should still be 10.0');
end;

procedure TestBarChartNew;
var
  LChart: IBarChart;
  LBars: array[0..2] of TBarData;
begin
  LBars[0] := TBarData.Make('A', 10.0);
  LBars[1] := TBarData.Make('B', 20.0);
  LBars[2] := TBarData.Make('C', 30.0);
  LChart := TBarChart.New(LBars);
  Check(LChart <> nil, 'New barchart should not be nil');
end;

procedure TestBarChartNewEmpty;
var
  LChart: IBarChart;
begin
  LChart := TBarChart.New([]);
  Check(LChart <> nil, 'New empty barchart should not be nil');
end;

procedure TestBarChartWithMax;
var
  LChart: IBarChart;
begin
  LChart := TBarChart.New([]);
  LChart := LChart.WithMax(100.0);
  Check(LChart <> nil, 'WithMax should return barchart');
end;

procedure TestBarChartWithBarWidth;
var
  LChart: IBarChart;
begin
  LChart := TBarChart.New([]);
  LChart := LChart.WithBarWidth(5);
  Check(LChart <> nil, 'WithBarWidth should return barchart');
end;

procedure TestBarChartWithBarGap;
var
  LChart: IBarChart;
begin
  LChart := TBarChart.New([]);
  LChart := LChart.WithBarGap(2);
  Check(LChart <> nil, 'WithBarGap should return barchart');
end;

procedure TestBarChartWithShowValues;
var
  LChart: IBarChart;
begin
  LChart := TBarChart.New([]);
  LChart := LChart.WithShowValues(False);
  Check(LChart <> nil, 'WithShowValues should return barchart');
end;

procedure TestBarChartWithShowLabels;
var
  LChart: IBarChart;
begin
  LChart := TBarChart.New([]);
  LChart := LChart.WithShowLabels(False);
  Check(LChart <> nil, 'WithShowLabels should return barchart');
end;

procedure TestBarChartWithStyle;
var
  LChart: IBarChart;
  LStyle: TStyle;
begin
  LChart := TBarChart.New([]);
  LStyle.Fg := IndexedColor(1);
  LChart := LChart.WithStyle(LStyle);
  Check(LChart <> nil, 'WithStyle should return barchart');
end;

procedure TestBarChartWithBlock;
var
  LChart: IBarChart;
  LBlock: IBlock;
begin
  LChart := TBarChart.New([]);
  LBlock := TBlock.New;
  LChart := LChart.WithBlock(LBlock);
  Check(LChart <> nil, 'WithBlock should return barchart');
end;

procedure TestBarChartRender;
var
  LChart: IBarChart;
  LBuffer: TBuffer;
  LArea: TRect;
  LBars: array[0..1] of TBarData;
begin
  LBars[0] := TBarData.Make('A', 10.0);
  LBars[1] := TBarData.Make('B', 20.0);
  LChart := TBarChart.New(LBars);
  LArea := TRect.Make(0, 0, 20, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LChart.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestBarChartBuilderChaining;
var
  LChart: IBarChart;
  LStyle: TStyle;
  LBlock: IBlock;
begin
  LChart := TBarChart.New([]);
  LStyle.Fg := IndexedColor(1);
  LBlock := TBlock.New;
  LChart := LChart
    .WithMax(100.0)
    .WithBarWidth(5)
    .WithBarGap(2)
    .WithShowValues(True)
    .WithShowLabels(True)
    .WithStyle(LStyle)
    .WithBlock(LBlock);
  Check(LChart <> nil, 'Builder chaining should work');
end;

procedure TestBarChartRenderEmpty;
var
  LChart: IBarChart;
  LBuffer: TBuffer;
begin
  LChart := TBarChart.New([]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LChart.Render(TRect.Make(0, 0, 20, 10), LBuffer);
    Check(True, 'Empty barchart renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestBarChartRenderWithBlock;
var
  LChart: IBarChart;
  LBuffer: TBuffer;
  LBars: array[0..1] of TBarData;
begin
  LBars[0] := TBarData.Make('A', 10.0);
  LBars[1] := TBarData.Make('B', 20.0);
  LChart := TBarChart.New(LBars).WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    LChart.Render(TRect.Make(0, 0, 20, 10), LBuffer);
    Check(True, 'Barchart with block renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestBarChartRenderEmptyArea;
var
  LChart: IBarChart;
  LBuffer: TBuffer;
begin
  LChart := TBarChart.New([TBarData.Make('A', 10.0)]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    LChart.Render(TRect.Make(0, 0, 0, 0), LBuffer);
    Check(True, 'Empty area does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestBarChartRenderSmallArea;
var
  LChart: IBarChart;
  LBuffer: TBuffer;
begin
  LChart := TBarChart.New([TBarData.Make('A', 10.0)]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    LChart.Render(TRect.Make(0, 0, 5, 2), LBuffer);
    Check(True, 'Small area does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestBarChartRenderMultipleBars;
var
  LChart: IBarChart;
  LBuffer: TBuffer;
  LBars: array[0..4] of TBarData;
begin
  LBars[0] := TBarData.Make('A', 10.0);
  LBars[1] := TBarData.Make('B', 20.0);
  LBars[2] := TBarData.Make('C', 30.0);
  LBars[3] := TBarData.Make('D', 40.0);
  LBars[4] := TBarData.Make('E', 50.0);
  LChart := TBarChart.New(LBars);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    LChart.Render(TRect.Make(0, 0, 40, 10), LBuffer);
    Check(True, 'Multiple bars render');
  finally
    LBuffer.Free;
  end;
end;

procedure TestBarDataMakeZeroValue;
var
  LData: TBarData;
begin
  LData := TBarData.Make('Zero', 0.0);
  Check(LData.Label_ = 'Zero', 'Label should be Zero');
  Check(LData.Value = 0.0, 'Value should be 0.0');
end;

{ PH33 P3：数据更新面——SetBars 原地替换 + AddBar 追加（标签默认显示） }
procedure TestBarChartSetAddBars;
var LB: IBarChart; LBuf: TBuffer; LAll: AnsiString; I: Integer;
begin
  LB := TBarChart.New([TBarData.Make('zz-old', 9.0)]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 10));
  try
    LB.SetBars([TBarData.Make('aa', 5.0), TBarData.Make('bb', 3.0)]);
    LB.AddBar(TBarData.Make('cc', 1.0));
    LB.Render(TRect.Make(0, 0, 40, 10), LBuf);
    LAll := '';
    for I := 0 to 9 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('aa', LAll) > 0, 'replaced bar label visible');
    Check(Pos('cc', LAll) > 0, 'appended bar label visible');
    Check(Pos('zz-old', LAll) = 0, 'old bar gone');
  finally LBuf.Free; end;
end;

procedure TestBarChartWithBarsChaining;
var LB: IBarChart;
begin
  LB := TBarChart.New([TBarData.Make('a', 1.0)])
    .WithBars([TBarData.Make('x', 2.0), TBarData.Make('y', 4.0)]);
  Check(LB <> nil, 'WithBars chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.barchart');
  T.Test('TBarData.Make', @TestBarDataMake);
  T.Test('TBarData.WithStyle', @TestBarDataWithStyle);
  T.Test('TBarChart.New', @TestBarChartNew);
  T.Test('TBarChart.New empty', @TestBarChartNewEmpty);
  T.Test('TBarChart.WithMax', @TestBarChartWithMax);
  T.Test('TBarChart.WithBarWidth', @TestBarChartWithBarWidth);
  T.Test('TBarChart.WithBarGap', @TestBarChartWithBarGap);
  T.Test('TBarChart.WithShowValues', @TestBarChartWithShowValues);
  T.Test('TBarChart.WithShowLabels', @TestBarChartWithShowLabels);
  T.Test('TBarChart.WithStyle', @TestBarChartWithStyle);
  T.Test('TBarChart.WithBlock', @TestBarChartWithBlock);
  T.Test('TBarChart.Render', @TestBarChartRender);
  T.Test('TBarChart builder chaining', @TestBarChartBuilderChaining);
  T.Test('render empty', @TestBarChartRenderEmpty);
  T.Test('render with block', @TestBarChartRenderWithBlock);
  T.Test('render empty area', @TestBarChartRenderEmptyArea);
  T.Test('render small area', @TestBarChartRenderSmallArea);
  T.Test('render multiple bars', @TestBarChartRenderMultipleBars);
  T.Test('TBarData make zero value', @TestBarDataMakeZeroValue);
  T.Test('SetBars/AddBar update (PH33 P3)', @TestBarChartSetAddBars);
  T.Test('WithBars chaining (PH33 P3)', @TestBarChartWithBarsChaining);
  if not T.Run then Halt(1);
end.
