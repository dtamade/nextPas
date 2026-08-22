program test_tui_widget_block;

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
  nextpas.core.test;

var
  T: TTestSuite;

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
  Check(RectEquals(LInner, TRect.Make(0, 0, 10, 8)), 'no borders no shrink');
end;

procedure TestInnerTitleNoBorder;
var
  LBlock: IBlock;
  LInner: TRect;
begin
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
  LWidget := TBlock.New.WithBorders(BORDERS_ALL);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 3));
  try
    LWidget.Render(TRect.Make(0, 0, 4, 3), LBuf);
    Check(LBuf.RowAsString(0) <> '    ', 'rendered something');
  finally
    LBuf.Free;
  end;
end;

procedure TestBuilderChain;
var
  LBlock: IBlock;
begin
  LBlock := TBlock.New
    .WithBorders(BORDERS_ALL)
    .WithTitle('Test')
    .WithStyle(StyleDefault.WithFg(TUI_RED))
    .WithBorderStyle(StyleDefault.WithFg(TUI_CYAN))
    .WithTitleStyle(StyleDefault.WithFg(TUI_GREEN))
    .WithBorderSet(BorderSetRounded);
  Check(LBlock <> nil, 'chain produces non-nil');
end;

procedure TestRenderNoBorders;
var
  LBlock: IBlock;
  LBuf: TBuffer;
begin
  LBlock := TBlock.New;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 5, 3), LBuf);
    Check(True, 'no borders render does not crash');
  finally
    LBuf.Free;
  end;
end;

procedure TestRenderPartialBorders;
var
  LBlock: IBlock;
  LBuf: TBuffer;
begin
  LBlock := TBlock.New.WithBorders([bsTop, bsBottom]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 5, 3), LBuf);
    Check(True, 'partial borders render does not crash');
  finally
    LBuf.Free;
  end;
end;

procedure TestInnerPartialBorders;
var
  LBlock: IBlock;
  LInner: TRect;
begin
  LBlock := TBlock.New.WithBorders([bsTop, bsBottom]);
  LInner := LBlock.Inner(TRect.Make(0, 0, 10, 8));
  CheckEqual(Int64(0), Int64(LInner.X), 'x unchanged');
  CheckEqual(Int64(1), Int64(LInner.Y), 'y shrunk by top');
  CheckEqual(Int64(10), Int64(LInner.Width), 'w unchanged');
  CheckEqual(Int64(6), Int64(LInner.Height), 'h shrunk by top+bottom');
end;

procedure TestRenderSmallArea;
var
  LBlock: IBlock;
  LBuf: TBuffer;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    LBlock.Render(TRect.Make(0, 0, 1, 1), LBuf);
    Check(True, 'tiny area render does not crash');
  finally
    LBuf.Free;
  end;
end;

procedure TestInnerLeftRightOnly;
var
  LBlock: IBlock;
  LInner: TRect;
begin
  LBlock := TBlock.New.WithBorders([bsLeft, bsRight]);
  LInner := LBlock.Inner(TRect.Make(0, 0, 10, 8));
  CheckEqual(Int64(1), Int64(LInner.X), 'lr x');
  CheckEqual(Int64(0), Int64(LInner.Y), 'lr y');
  CheckEqual(Int64(8), Int64(LInner.Width), 'lr w');
  CheckEqual(Int64(8), Int64(LInner.Height), 'lr h');
end;

procedure TestTitleEmptyString;
var
  LBlock: IBlock;
  LBuf: TBuffer;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 6, 3), LBuf);
    Check(True, 'empty title does not crash');
  finally
    LBuf.Free;
  end;
end;

procedure TestTitleLongClips;
var
  LBlock: IBlock;
  LBuf: TBuffer;
  LRow: AnsiString;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('ABCDEFGH');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 6, 3), LBuf);
    LRow := LBuf.RowAsString(0);
    { Row contains border chars + clipped title, multi-byte UTF-8 }
    Check(Length(LRow) > 0, 'title long renders');
  finally
    LBuf.Free;
  end;
end;

procedure TestRoundedBorderSet;
var
  LBlock: IBlock;
  LBuf: TBuffer;
  LRow: AnsiString;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithBorderSet(BorderSetRounded);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 5, 3), LBuf);
    LRow := LBuf.RowAsString(0);
    { Rounded corners: ╭──╮ }
    Check(Length(LRow) > 0, 'rounded rendered');
  finally
    LBuf.Free;
  end;
end;

procedure TestBorderStyleApplied;
var
  LBlock: IBlock;
  LBuf: TBuffer;
  LCell: PCell;
begin
  LBlock := TBlock.New.WithBorders(BORDERS_ALL)
    .WithBorderStyle(StyleDefault.WithFg(TUI_RED));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    LBlock.Render(TRect.Make(0, 0, 5, 3), LBuf);
    LCell := LBuf.CellAt(0, 0);
    Check(LCell <> nil, 'border cell exists');
    Check(ColorEquals(TUI_RED, LCell^.Fg), 'border fg red');
  finally
    LBuf.Free;
  end;
end;

{ PH33 P2b：布局属性——WithPadding 内容区四边内缩（边框收缩之后叠加） }
procedure TestInnerPadding;
var
  LBlock: IBlock;
  LInner: TRect;
begin
  LBlock := TBlock.New
    .WithBorders([bsLeft, bsRight, bsTop, bsBottom]).WithPadding(2);
  LInner := LBlock.Inner(TRect.Make(0, 0, 20, 12));
  CheckEqual(Int64(3), Int64(LInner.X), 'x = left border 1 + pad 2');
  CheckEqual(Int64(3), Int64(LInner.Y), 'y = top border 1 + pad 2');
  CheckEqual(Int64(14), Int64(LInner.Width), 'w = 20 - 2*1 border - 2*2 pad');
  CheckEqual(Int64(6), Int64(LInner.Height), 'h = 12 - 2*1 border - 2*2 pad');
end;

procedure TestInnerPaddingNoBorders;
var
  LInner: TRect;
begin
  LInner := TBlock.New.WithPadding(1).Inner(TRect.Make(5, 5, 10, 8));
  CheckEqual(Int64(6), Int64(LInner.X), 'x inset by pad');
  CheckEqual(Int64(6), Int64(LInner.Y), 'y inset by pad');
  CheckEqual(Int64(8), Int64(LInner.Width), 'w minus 2*pad');
  CheckEqual(Int64(6), Int64(LInner.Height), 'h minus 2*pad');
end;

procedure TestInnerPaddingOversizeClampsEmpty;
var
  LInner: TRect;
begin
  { 内缩超过区尺寸 -> 空区（语义对齐 tui888 geometry margin） }
  LInner := TBlock.New.WithBorders([bsLeft, bsRight]).WithPadding(9)
    .Inner(TRect.Make(0, 0, 10, 4));
  CheckEqual(Int64(0), Int64(LInner.Width), 'oversized pad clamps to empty w');
end;

procedure TestPaddingNegativeClampsZero;
var
  LInner: TRect;
begin
  LInner := TBlock.New.WithPadding(-3).Inner(TRect.Make(0, 0, 10, 4));
  CheckEqual(Int64(10), Int64(LInner.Width), 'negative pad treated as 0');
end;

procedure TestRenderPaddingUnchangedEdges;
var
  LBuf: TBuffer;
  LBlock: IBlock;
begin
  { padding 只收缩内容区，边框仍绘制在区边缘 }
  LBlock := TBlock.Bordered('T').WithPadding(1);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 5));
  try
    LBlock.Render(TRect.Make(0, 0, 12, 5), LBuf);
    Check(Pos(#$e2#$94#$8c, LBuf.RowAsString(0)) > 0, 'top-left border at edge');
    Check(Pos(#$e2#$94#$94, LBuf.RowAsString(4)) > 0, 'bottom-left border at edge');
  finally LBuf.Free; end;
end;

procedure TestWithPaddingChaining;
begin
  Check(TBlock.New.WithPadding(2).WithTitle('x') <> nil, 'padding chains');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.block');
  T.Test('render all borders', @TestRenderAllBorders);
  T.Test('render title', @TestRenderTitle);
  T.Test('inner all borders', @TestInnerAllBorders);
  T.Test('inner no borders', @TestInnerNoBorders);
  T.Test('inner title no border', @TestInnerTitleNoBorder);
  T.Test('as IWidget', @TestAsIWidget);
  T.Test('builder chain', @TestBuilderChain);
  T.Test('render no borders', @TestRenderNoBorders);
  T.Test('render partial borders', @TestRenderPartialBorders);
  T.Test('inner partial borders', @TestInnerPartialBorders);
  T.Test('render small area', @TestRenderSmallArea);
  T.Test('inner left right only', @TestInnerLeftRightOnly);
  T.Test('title empty string', @TestTitleEmptyString);
  T.Test('title long clips', @TestTitleLongClips);
  T.Test('rounded border set', @TestRoundedBorderSet);
  T.Test('border style applied', @TestBorderStyleApplied);
  T.Test('inner padding with borders (PH33 P2b)', @TestInnerPadding);
  T.Test('inner padding no borders (PH33 P2b)', @TestInnerPaddingNoBorders);
  T.Test('padding oversize clamps empty (PH33 P2b)', @TestInnerPaddingOversizeClampsEmpty);
  T.Test('negative padding clamps zero (PH33 P2b)', @TestPaddingNegativeClampsZero);
  T.Test('render padding keeps border edges (PH33 P2b)', @TestRenderPaddingUnchangedEdges);
  T.Test('WithPadding chaining (PH33 P2b)', @TestWithPaddingChaining);
  if not T.Run then Halt(1);
end.
