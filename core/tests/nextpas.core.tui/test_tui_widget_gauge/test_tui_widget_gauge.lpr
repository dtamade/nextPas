program test_tui_widget_gauge;

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
  if not T.Run then Halt(1);
end.
