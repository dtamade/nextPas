program test_tui_widget_sparkline;

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
  nextpas.core.tui.widget.sparkline,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestSparklineNew;
var
  LSparkline: ISparkline;
  LData: array[0..4] of Double;
begin
  LData[0] := 1.0;
  LData[1] := 2.0;
  LData[2] := 3.0;
  LData[3] := 4.0;
  LData[4] := 5.0;
  LSparkline := TSparkline.New(LData);
  Check(LSparkline <> nil, 'New sparkline should not be nil');
end;

procedure TestSparklineNewEmpty;
var
  LSparkline: ISparkline;
begin
  LSparkline := TSparkline.New([]);
  Check(LSparkline <> nil, 'New empty sparkline should not be nil');
end;

procedure TestSparklineWithStyle;
var
  LSparkline: ISparkline;
  LStyle: TStyle;
begin
  LSparkline := TSparkline.New([]);
  LStyle.Fg := IndexedColor(1);
  LSparkline := LSparkline.WithStyle(LStyle);
  Check(LSparkline <> nil, 'WithStyle should return sparkline');
end;

procedure TestSparklineWithMax;
var
  LSparkline: ISparkline;
begin
  LSparkline := TSparkline.New([]);
  LSparkline := LSparkline.WithMax(100.0);
  Check(LSparkline <> nil, 'WithMax should return sparkline');
end;

procedure TestSparklineWithBlock;
var
  LSparkline: ISparkline;
  LBlock: IBlock;
begin
  LSparkline := TSparkline.New([]);
  LBlock := TBlock.New;
  LSparkline := LSparkline.WithBlock(LBlock);
  Check(LSparkline <> nil, 'WithBlock should return sparkline');
end;

procedure TestSparklineRender;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LArea: TRect;
  LData: array[0..4] of Double;
begin
  LData[0] := 1.0;
  LData[1] := 3.0;
  LData[2] := 2.0;
  LData[3] := 5.0;
  LData[4] := 4.0;
  LSparkline := TSparkline.New(LData);
  LArea := TRect.Make(0, 0, 20, 5);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LSparkline.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineBuilderChaining;
var
  LSparkline: ISparkline;
  LStyle: TStyle;
  LBlock: IBlock;
begin
  LSparkline := TSparkline.New([1.0, 2.0, 3.0]);
  LStyle.Fg := IndexedColor(1);
  LBlock := TBlock.New;
  LSparkline := LSparkline
    .WithStyle(LStyle)
    .WithMax(10.0)
    .WithBlock(LBlock);
  Check(LSparkline <> nil, 'Builder chaining should work');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.sparkline');
  T.Test('TSparkline.New', @TestSparklineNew);
  T.Test('TSparkline.New empty', @TestSparklineNewEmpty);
  T.Test('TSparkline.WithStyle', @TestSparklineWithStyle);
  T.Test('TSparkline.WithMax', @TestSparklineWithMax);
  T.Test('TSparkline.WithBlock', @TestSparklineWithBlock);
  T.Test('TSparkline.Render', @TestSparklineRender);
  T.Test('TSparkline builder chaining', @TestSparklineBuilderChaining);
  if not T.Run then Halt(1);
end.
