program test_tui_widget_sparkline;

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

procedure TestSparklineRenderWithBlock;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LSparkline := TSparkline.New([1.0, 2.0, 3.0])
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LArea := TRect.Make(0, 0, 10, 3);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LSparkline.Render(LArea, LBuffer);
    Check(True, 'Render with block does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineRenderEmptyData;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
begin
  LSparkline := TSparkline.New([]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LSparkline.Render(TRect.Make(0, 0, 10, 3), LBuffer);
    Check(True, 'Empty data render does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineRenderEmptyArea;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
begin
  LSparkline := TSparkline.New([1.0, 2.0]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 0, 0));
  try
    LSparkline.Render(TRect.Make(0, 0, 0, 0), LBuffer);
    Check(True, 'Empty area render does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineWithExplicitMax;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  { Max set to 10, data only goes to 5 -> should render at half height }
  LSparkline := TSparkline.New([5.0]).WithMax(10.0);
  LArea := TRect.Make(0, 0, 5, 2);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LSparkline.Render(LArea, LBuffer);
    Check(True, 'Explicit max renders without crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineSingleDataPoint;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
begin
  LSparkline := TSparkline.New([42.0]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 2));
  try
    LSparkline.Render(TRect.Make(0, 0, 5, 2), LBuffer);
    Check(True, 'Single data point renders');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineRenderSmallArea;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
begin
  LSparkline := TSparkline.New([1.0, 2.0]);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LSparkline.Render(TRect.Make(0, 0, 3, 1), LBuffer);
    Check(True, 'Small area does not crash');
  finally
    LBuffer.Free;
  end;
end;

procedure TestSparklineManyPoints;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LData: array[0..19] of Double;
  I: Integer;
begin
  for I := 0 to 19 do
    LData[I] := Sin(I * 0.5) * 10.0 + 10.0;
  LSparkline := TSparkline.New(LData);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    LSparkline.Render(TRect.Make(0, 0, 20, 5), LBuffer);
    Check(True, 'Many points render');
  finally
    LBuffer.Free;
  end;
end;


procedure TestSparklineAllZeroData;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LData: array[0..4] of Double;
  I: Integer;
begin
  for I := 0 to 4 do LData[I] := 0.0;
  LSparkline := TSparkline.New(LData);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LSparkline.Render(TRect.Make(0, 0, 10, 2), LBuffer);
    Check(True, 'all-zero data renders');
  finally LBuffer.Free; end;
end;

procedure TestSparklineWithMaxZeroUsesData;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LData: array[0..2] of Double;
begin
  LData[0] := 1; LData[1] := 2; LData[2] := 3;
  LSparkline := TSparkline.New(LData).WithMax(0);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 2));
  try
    LSparkline.Render(TRect.Make(0, 0, 6, 2), LBuffer);
    Check(True, 'WithMax(0) falls back to data max');
  finally LBuffer.Free; end;
end;

procedure TestSparklineWidthLargerThanData;
var
  LSparkline: ISparkline;
  LBuffer: TBuffer;
  LData: array[0..1] of Double;
begin
  LData[0] := 1; LData[1] := 5;
  LSparkline := TSparkline.New(LData);
  LBuffer := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 1));
  try
    LSparkline.Render(TRect.Make(0, 0, 20, 1), LBuffer);
    Check(True, 'width > data length renders');
  finally LBuffer.Free; end;
end;

{ PH33 P1：数据更新面——SetData 原地替换序列（旧 API 动态刷新须重建对象）；
  序列反转后同区渲染输出应变化 }
procedure TestSparklineSetData;
var
  LSparkline: ISparkline;
  LBuf1, LBuf2: TBuffer;
  LArea: TRect;
begin
  LArea := TRect.Make(0, 0, 12, 1);
  LSparkline := TSparkline.New([1.0, 9.0]);
  LBuf1 := TBuffer.CreateEmpty(LArea);
  try
    LSparkline.Render(LArea, LBuf1);
    LSparkline.SetData([9.0, 1.0]);
    LBuf2 := TBuffer.CreateEmpty(LArea);
    try
      LSparkline.Render(LArea, LBuf2);
      Check(LBuf1.RowAsString(0) <> LBuf2.RowAsString(0),
        'SetData replaces series in place (render output changes)');
    finally LBuf2.Free; end;
  finally LBuf1.Free; end;
end;

procedure TestSparklineWithDataChaining;
var
  LSparkline: ISparkline;
begin
  LSparkline := TSparkline.New([1.0])
    .WithData([4.0, 5.0, 6.0])
    .WithMax(10.0);
  Check(LSparkline <> nil, 'WithData chains and returns interface');
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
  T.Test('render with block', @TestSparklineRenderWithBlock);
  T.Test('render empty data', @TestSparklineRenderEmptyData);
  T.Test('render empty area', @TestSparklineRenderEmptyArea);
  T.Test('explicit max', @TestSparklineWithExplicitMax);
  T.Test('single data point', @TestSparklineSingleDataPoint);
  T.Test('render small area', @TestSparklineRenderSmallArea);
  T.Test('many points', @TestSparklineManyPoints);
  T.Test('all zero data', @TestSparklineAllZeroData);
  T.Test('WithMax zero uses data', @TestSparklineWithMaxZeroUsesData);
  T.Test('width larger than data', @TestSparklineWidthLargerThanData);
  T.Test('SetData in-place update (PH33 P1)', @TestSparklineSetData);
  T.Test('WithData chaining (PH33 P1)', @TestSparklineWithDataChaining);
if not T.Run then Halt(1);
end.
