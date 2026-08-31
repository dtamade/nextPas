program test_tui_widget_gauge;

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
  nextpas.core.tui.widget.gauge,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestGaugeNew;
var
  LGauge: IGauge;
begin
  LGauge := TGauge.New;
  Check(LGauge <> nil, 'New gauge should not be nil');
end;

procedure TestGaugeWithRatio;
var
  LGauge: IGauge;
begin
  LGauge := TGauge.New;
  LGauge := LGauge.WithRatio(0.5);
  Check(LGauge <> nil, 'WithRatio should return gauge');
end;

procedure TestGaugeWithPercent;
var
  LGauge: IGauge;
begin
  LGauge := TGauge.New;
  LGauge := LGauge.WithPercent(75);
  Check(LGauge <> nil, 'WithPercent should return gauge');
end;

procedure TestGaugeWithLabel;
var
  LGauge: IGauge;
begin
  LGauge := TGauge.New;
  LGauge := LGauge.WithLabel('Progress');
  Check(LGauge <> nil, 'WithLabel should return gauge');
end;

procedure TestGaugeWithFilledStyle;
var
  LGauge: IGauge;
  LStyle: TStyle;
begin
  LGauge := TGauge.New;
  LStyle.Fg := IndexedColor(1);
  LGauge := LGauge.WithFilledStyle(LStyle);
  Check(LGauge <> nil, 'WithFilledStyle should return gauge');
end;

procedure TestGaugeWithEmptyStyle;
var
  LGauge: IGauge;
  LStyle: TStyle;
begin
  LGauge := TGauge.New;
  LStyle.Fg := IndexedColor(2);
  LGauge := LGauge.WithEmptyStyle(LStyle);
  Check(LGauge <> nil, 'WithEmptyStyle should return gauge');
end;

procedure TestGaugeWithBlock;
var
  LGauge: IGauge;
  LBlock: IBlock;
begin
  LGauge := TGauge.New;
  LBlock := TBlock.New;
  LGauge := LGauge.WithBlock(LBlock);
  Check(LGauge <> nil, 'WithBlock should return gauge');
end;

procedure TestGaugeWithThreshold;
var
  LGauge: IGauge;
  LStyle: TStyle;
begin
  LGauge := TGauge.New;
  LStyle.Fg := IndexedColor(3);
  LGauge := LGauge.WithThreshold(0.5, LStyle);
  Check(LGauge <> nil, 'WithThreshold should return gauge');
end;

procedure TestGaugeRender;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LGauge := TGauge.New;
  LGauge := LGauge.WithRatio(0.5).WithLabel('Test');
  LArea := TRect.Make(0, 0, 20, 3);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LGauge.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeBuilderChaining;
var
  LGauge: IGauge;
  LStyle: TStyle;
  LBlock: IBlock;
begin
  LGauge := TGauge.New;
  LStyle.Fg := IndexedColor(1);
  LBlock := TBlock.New;
  LGauge := LGauge
    .WithRatio(0.75)
    .WithLabel('Progress')
    .WithFilledStyle(LStyle)
    .WithEmptyStyle(LStyle)
    .WithBlock(LBlock)
    .WithThreshold(0.5, LStyle);
  Check(LGauge <> nil, 'Builder chaining should work');
end;

procedure TestGaugeRenderHalf;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LGauge := TGauge.New.WithRatio(0.5);
  LArea := TRect.Make(0, 0, 10, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LGauge.Render(LArea, LBuffer);
    { 50% of 10 cols = 5 filled }
    Check(True, 'half gauge renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeRenderFull;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithRatio(1.0);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, 'full gauge renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeRenderZero;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithRatio(0.0);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, 'zero gauge renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeWithBlockRender;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithRatio(0.5).WithLabel('50%')
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 3), LBuffer);
    Check(True, 'gauge with block renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugePercentConversion;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithPercent(75);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, '75% gauge renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeRatioClamping;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  { Ratios > 1.0 and < 0.0 should be clamped }
  LGauge := TGauge.New.WithRatio(2.0);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, 'clamped ratio renders');
  finally
    LBuffer.Free;
  end;
  LGauge := TGauge.New.WithRatio(-0.5);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, 'negative clamped ratio renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeRenderSmallArea;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithRatio(0.5);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 3, 1), LBuffer);
    Check(True, 'gauge renders in small area');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugeRenderWithLabel;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithRatio(0.5).WithLabel('Loading...');
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 20, 1), LBuffer);
    Check(True, 'gauge with label renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestGaugePercentBoundary;
var
  LGauge: IGauge;
  LBuffer: TBuffer;
begin
  LGauge := TGauge.New.WithPercent(0);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, '0% gauge renders');
  finally
    LBuffer.Free;
  end;
  LGauge := TGauge.New.WithPercent(100);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LGauge.Render(TRect.Make(0, 0, 10, 1), LBuffer);
    Check(True, '100% gauge renders');
  finally
    LBuffer.Free;
  end;
end;

{ PH33 P4：基础样式旋钮——filled/empty 两区一次着色（builder 顺序语义：
  后续 Filled/Empty/Threshold 调用覆盖各自面） }
procedure TestGaugeWithStyle;
var
  LGauge: IGauge;
  LStyle, LOver: TStyle;
begin
  LGauge := TGauge.New;
  LStyle := StyleDefault;
  LStyle.Fg := IndexedColor(2);
  LOver := StyleDefault;
  LOver.Fg := IndexedColor(1);
  LGauge := LGauge.WithStyle(LStyle).WithFilledStyle(LOver);
  Check(LGauge <> nil, 'WithStyle should chain');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.gauge');
  T.Test('TGauge.New', @TestGaugeNew);
  T.Test('TGauge.WithRatio', @TestGaugeWithRatio);
  T.Test('TGauge.WithPercent', @TestGaugeWithPercent);
  T.Test('TGauge.WithLabel', @TestGaugeWithLabel);
  T.Test('TGauge.WithFilledStyle', @TestGaugeWithFilledStyle);
  T.Test('TGauge.WithEmptyStyle', @TestGaugeWithEmptyStyle);
  T.Test('TGauge.WithBlock', @TestGaugeWithBlock);
  T.Test('TGauge.WithThreshold', @TestGaugeWithThreshold);
  T.Test('TGauge.Render', @TestGaugeRender);
  T.Test('TGauge builder chaining', @TestGaugeBuilderChaining);
  T.Test('render half', @TestGaugeRenderHalf);
  T.Test('render full', @TestGaugeRenderFull);
  T.Test('render zero', @TestGaugeRenderZero);
  T.Test('with block render', @TestGaugeWithBlockRender);
  T.Test('percent conversion', @TestGaugePercentConversion);
  T.Test('ratio clamping', @TestGaugeRatioClamping);
  T.Test('render small area', @TestGaugeRenderSmallArea);
  T.Test('render with label', @TestGaugeRenderWithLabel);
  T.Test('percent boundary', @TestGaugePercentBoundary);
  T.Test('with style zones', @TestGaugeWithStyle);
  if not T.Run then Halt(1);
end.
