program test_tui_widget_tooltip;

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
  nextpas.core.tui.widget.tooltip,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestTooltipPositionEnum;
begin
  Check(Ord(ttpAbove) = 0, 'ttpAbove should be 0');
  Check(Ord(ttpBelow) = 1, 'ttpBelow should be 1');
  Check(Ord(ttpLeft) = 2, 'ttpLeft should be 2');
  Check(Ord(ttpRight) = 3, 'ttpRight should be 3');
end;

procedure TestTooltipNew;
var
  LTooltip: ITooltip;
begin
  LTooltip := TTooltip.New('Hello');
  Check(LTooltip <> nil, 'New tooltip should not be nil');
end;

procedure TestTooltipWithPosition;
var
  LTooltip: ITooltip;
begin
  LTooltip := TTooltip.New('Test');
  LTooltip := LTooltip.WithPosition(ttpBelow);
  Check(LTooltip <> nil, 'WithPosition should return tooltip');
end;

procedure TestTooltipWithStyle;
var
  LTooltip: ITooltip;
  LStyle: TStyle;
begin
  LTooltip := TTooltip.New('Test');
  LStyle.Fg := IndexedColor(1);
  LTooltip := LTooltip.WithStyle(LStyle);
  Check(LTooltip <> nil, 'WithStyle should return tooltip');
end;

procedure TestTooltipWithBorderStyle;
var
  LTooltip: ITooltip;
  LStyle: TStyle;
begin
  LTooltip := TTooltip.New('Test');
  LStyle.Fg := IndexedColor(2);
  LTooltip := LTooltip.WithBorderStyle(LStyle);
  Check(LTooltip <> nil, 'WithBorderStyle should return tooltip');
end;

procedure TestTooltipWithMaxWidth;
var
  LTooltip: ITooltip;
begin
  LTooltip := TTooltip.New('Test');
  LTooltip := LTooltip.WithMaxWidth(20);
  Check(LTooltip <> nil, 'WithMaxWidth should return tooltip');
end;

procedure TestTooltipRender;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LTooltip := TTooltip.New('Hello World');
  LArea := TRect.Make(0, 0, 30, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestTooltipRenderAt;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  LTooltip := TTooltip.New('Tooltip text');
  LTooltip := LTooltip.WithPosition(ttpBelow);
  LArea := TRect.Make(0, 0, 40, 20);
  LAnchor := TRect.Make(10, 5, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'RenderAt should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestTooltipBuilderChaining;
var
  LTooltip: ITooltip;
  LStyle: TStyle;
begin
  LTooltip := TTooltip.New('Test');
  LStyle.Fg := IndexedColor(1);
  LTooltip := LTooltip
    .WithPosition(ttpRight)
    .WithStyle(LStyle)
    .WithBorderStyle(LStyle)
    .WithMaxWidth(30);
  Check(LTooltip <> nil, 'Builder chaining should work');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.tooltip');
  T.Test('TTooltipPosition enum', @TestTooltipPositionEnum);
  T.Test('TTooltip.New', @TestTooltipNew);
  T.Test('TTooltip.WithPosition', @TestTooltipWithPosition);
  T.Test('TTooltip.WithStyle', @TestTooltipWithStyle);
  T.Test('TTooltip.WithBorderStyle', @TestTooltipWithBorderStyle);
  T.Test('TTooltip.WithMaxWidth', @TestTooltipWithMaxWidth);
  T.Test('TTooltip.Render', @TestTooltipRender);
  T.Test('TTooltip.RenderAt', @TestTooltipRenderAt);
  T.Test('TTooltip builder chaining', @TestTooltipBuilderChaining);
  if not T.Run then Halt(1);
end.
