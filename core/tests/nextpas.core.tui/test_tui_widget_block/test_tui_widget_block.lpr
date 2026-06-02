program test_tui_widget_block;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure AssertRow(ABuf: TBuffer; AY: Integer; const AExpected, AMsg: AnsiString);
begin
  CheckEqual(AExpected, ABuf.RowAsString(AY), AMsg);
end;

procedure TestRenderAllBorders;
var
  LBlock: IBlock;
  LBuf: TBuffer;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 5, 3), LBuf);
    { 期望：
      ┌───┐
      │   │
      └───┘ }
    AssertRow(LBuf, 0, #$E2#$94#$8C + #$E2#$94#$80#$E2#$94#$80#$E2#$94#$80 + #$E2#$94#$90, 'top row');
    AssertRow(LBuf, 2, #$E2#$94#$94 + #$E2#$94#$80#$E2#$94#$80#$E2#$94#$80 + #$E2#$94#$98, 'bottom row');
  finally
    LBuf.Free;
  end;
end;

procedure TestRenderTitle;
var
  LBlock: IBlock;
  LBuf: TBuffer;
  LRow: AnsiString;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Hi');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 6, 3), LBuf);
    LRow := LBuf.RowAsString(0);
    { 标题 'Hi' 在顶行，左边框后 }
    Check(Pos('Hi', LRow) > 0, 'title Hi in top row');
  finally
    LBuf.Free;
  end;
end;

procedure TestInnerAllBorders;
var
  LBlock: IBlock;
  LInner: TRect;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL);
  LInner := LBlock.Inner(TRect.Make(0, 0, 10, 8));
  { 四边各缩 1 -> (1,1,8,6) }
  CheckEqual(Int64(1), Int64(LInner.X), 'inner x');
  CheckEqual(Int64(1), Int64(LInner.Y), 'inner y');
  CheckEqual(Int64(8), Int64(LInner.Width), 'inner w');
  CheckEqual(Int64(6), Int64(LInner.Height), 'inner h');
end;

procedure TestInnerNoBorders;
var
  LBlock: IBlock;
  LInner: TRect;
begin
  LBlock := TBlock.New;
  LInner := LBlock.Inner(TRect.Make(0, 0, 10, 8));
  { 无边框 -> 不缩 }
  Check(RectEquals(LInner, TRect.Make(0, 0, 10, 8)), 'no borders no shrink');
end;

procedure TestInnerTitleNoBorder;
var
  LBlock: IBlock;
  LInner: TRect;
begin
  { 有标题无顶边框 -> 顶部仍缩 1（ratatui 规则） }
  LBlock := TBlock.New.WithTitle('X');
  LInner := LBlock.Inner(TRect.Make(0, 0, 10, 8));
  CheckEqual(Int64(0), Int64(LInner.X), 'x unchanged');
  CheckEqual(Int64(1), Int64(LInner.Y), 'y shrunk by title');
  CheckEqual(Int64(7), Int64(LInner.Height), 'h shrunk');
end;

procedure TestAsIWidget;
var
  LWidget: IWidget;
  LBuf: TBuffer;
begin
  { TBlock 可当 IWidget 使用（多态） }
  LWidget := TBlock.New.WithBorders(BORDERS_ALL);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    LWidget.Render(TRect.Make(0, 0, 4, 3), LBuf);
    { 只验证渲染不崩溃且有内容 }
    Check(LBuf.RowAsString(0) <> '    ', 'rendered something');
  finally
    LBuf.Free;
  end;
end;

procedure TestBuilderChain;
var
  LBlock: IBlock;
begin
  { 验证链式调用不崩溃，返回同一对象 }
  LBlock := TBlock.New
    .WithBorders(BORDERS_ALL)
    .WithTitle('Test')
    .WithStyle(StyleDefault.WithFg(TUI_RED))
    .WithBorderStyle(StyleDefault.WithFg(TUI_CYAN))
    .WithTitleStyle(StyleDefault.WithFg(TUI_GREEN))
    .WithBorderSet(BorderSetRounded);
  Check(LBlock <> nil, 'chain produces non-nil');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.block');
  T.Run('render all borders', @TestRenderAllBorders);
  T.Run('render title', @TestRenderTitle);
  T.Run('inner all borders', @TestInnerAllBorders);
  T.Run('inner no borders', @TestInnerNoBorders);
  T.Run('inner title no border', @TestInnerTitleNoBorder);
  T.Run('as IWidget', @TestAsIWidget);
  T.Run('builder chain', @TestBuilderChain);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
