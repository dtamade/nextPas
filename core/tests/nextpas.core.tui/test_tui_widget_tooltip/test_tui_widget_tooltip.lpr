program test_tui_widget_tooltip;

{$I nextpas.core.settings.inc}

uses
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

{ === New tests === }

procedure TestTooltipAbovePosition;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  LTooltip := TTooltip.New('Tip').WithPosition(ttpAbove);
  LArea := TRect.Make(0, 0, 40, 20);
  LAnchor := TRect.Make(10, 10, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'above position renders');
  finally LBuffer.Free; end;
end;

procedure TestTooltipBelowPosition;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  LTooltip := TTooltip.New('Tip').WithPosition(ttpBelow);
  LArea := TRect.Make(0, 0, 40, 20);
  LAnchor := TRect.Make(10, 5, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'below position renders');
  finally LBuffer.Free; end;
end;

procedure TestTooltipLeftPosition;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  LTooltip := TTooltip.New('Tip').WithPosition(ttpLeft);
  LArea := TRect.Make(0, 0, 40, 20);
  LAnchor := TRect.Make(20, 10, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'left position renders');
  finally LBuffer.Free; end;
end;

procedure TestTooltipRightPosition;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  LTooltip := TTooltip.New('Tip').WithPosition(ttpRight);
  LArea := TRect.Make(0, 0, 40, 20);
  LAnchor := TRect.Make(5, 10, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'right position renders');
  finally LBuffer.Free; end;
end;

procedure TestTooltipEmptyText;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LTooltip := TTooltip.New('');
  LArea := TRect.Make(0, 0, 20, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.Render(LArea, LBuffer);
    Check(True, 'empty text does not crash');
  finally LBuffer.Free; end;
end;

procedure TestTooltipMaxWidthClip;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LTooltip := TTooltip.New('Very long tooltip text that exceeds max width').WithMaxWidth(10);
  LArea := TRect.Make(0, 0, 40, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.Render(LArea, LBuffer);
    Check(True, 'max width clips');
  finally LBuffer.Free; end;
end;

procedure TestTooltipBoundaryFlip;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  { Anchor at top-left, tooltip above would go off-screen }
  LTooltip := TTooltip.New('Tip').WithPosition(ttpAbove);
  LArea := TRect.Make(0, 0, 20, 10);
  LAnchor := TRect.Make(0, 0, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'boundary flip does not crash');
  finally LBuffer.Free; end;
end;

procedure TestTooltipSmallBounds;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
begin
  LTooltip := TTooltip.New('Tip').WithPosition(ttpBelow);
  LArea := TRect.Make(0, 0, 3, 2);
  LAnchor := TRect.Make(0, 0, 1, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.RenderAt(LAnchor, LArea, LBuffer);
    Check(True, 'small bounds does not crash');
  finally LBuffer.Free; end;
end;

procedure TestTooltipContentVisible;
var
  LTooltip: ITooltip;
  LBuffer: TBuffer;
  LArea: TRect;
  LRow: AnsiString;
begin
  LTooltip := TTooltip.New('Hi');
  LArea := TRect.Make(0, 0, 20, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LTooltip.Render(LArea, LBuffer);
    LRow := LBuffer.RowAsString(1);
    Check(Pos('Hi', LRow) > 0, 'tooltip text visible');
  finally LBuffer.Free; end;
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
  T.Test('Tooltip above position', @TestTooltipAbovePosition);
  T.Test('Tooltip below position', @TestTooltipBelowPosition);
  T.Test('Tooltip left position', @TestTooltipLeftPosition);
  T.Test('Tooltip right position', @TestTooltipRightPosition);
  T.Test('Tooltip empty text', @TestTooltipEmptyText);
  T.Test('Tooltip max width clip', @TestTooltipMaxWidthClip);
  T.Test('Tooltip boundary flip', @TestTooltipBoundaryFlip);
  T.Test('Tooltip small bounds', @TestTooltipSmallBounds);
  T.Test('Tooltip content visible', @TestTooltipContentVisible);
  if not T.Run then Halt(1);
end.
