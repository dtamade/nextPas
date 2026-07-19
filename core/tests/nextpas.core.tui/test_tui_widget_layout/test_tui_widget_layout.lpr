program test_tui_widget_layout;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.layout,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.panel,
  nextpas.core.tui.widget.split_pane,
  nextpas.core.tui.widget.modal,
  nextpas.core.tui.widget.popover,
  nextpas.core.tui.widget.tooltip,
  nextpas.core.test;
var T: TTestSuite;

{ === TPanel === }
procedure TestPanelNew;
var P: IPanel; G: TPanelGrid; LBuf: TBuffer;
begin
  P := TPanel.New([LengthConstraint(10), MinConstraint(0)], [MinConstraint(0)]);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 20));
  try
    G := P.RenderGrid(TRect.Make(0, 0, 40, 20), LBuf);
    Check(G.ColCount = 2, 'panel 2 cols');
    Check(G.RowCount = 1, 'panel 1 row');
  finally LBuf.Free; end;
end;

procedure TestPanelLayout;
var P: IPanel; G: TPanelGrid;
begin
  P := TPanel.New([LengthConstraint(5), LengthConstraint(5)], [LengthConstraint(3)]);
  G := P.Layout(TRect.Make(0, 0, 12, 5));
  Check(G.ColCount = 2, 'layout 2 cols');
  Check(PanelCell(G, 0, 0).Width > 0, 'cell 0,0 has width');
end;

procedure TestPanelAsIWidget;
var P: IWidget; LBuf: TBuffer;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    P.Render(TRect.Make(0, 0, 20, 10), LBuf);
    Check(True, 'panel renders as IWidget');
  finally LBuf.Free; end;
end;

procedure TestPanelSidebar;
var P: IPanel; G: TPanelGrid; LBuf: TBuffer;
begin
  P := TPanel.Sidebar(10);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 20));
  try
    G := P.RenderGrid(TRect.Make(0, 0, 40, 20), LBuf);
    Check(G.ColCount = 2, 'sidebar 2 cols');
  finally LBuf.Free; end;
end;

{ === TSplitPane === }
procedure TestSplitPaneHorizontal;
var S: IWidget; LBuf: TBuffer;
begin
  S := TSplitPane.Horizontal as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 20));
  try
    S.Render(TRect.Make(0, 0, 30, 20), LBuf);
    Check(True, 'hsplit renders');
  finally LBuf.Free; end;
end;

procedure TestSplitPaneVertical;
var S: IWidget; LBuf: TBuffer;
begin
  S := TSplitPane.Vertical as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 20));
  try
    S.Render(TRect.Make(0, 0, 30, 20), LBuf);
    Check(True, 'vsplit renders');
  finally LBuf.Free; end;
end;

procedure TestSplitPaneMouseDownOutsideDividerDoesNotStartDrag;
var
  S: ISplitPane;
  LState: TSplitPaneState;
  LPane1, LPane2, LDivider: TRect;
  LEv: TEvent;
  LConsumed: Boolean;
begin
  S := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  Check(S.Split(TRect.Make(0, 0, 30, 10), LState, LPane1, LPane2, LDivider),
    'split area is valid');
  Check(LDivider.X > 1, 'test click is outside divider');

  LEv := MouseEvent(mkDown, mbLeft, 1, 1, []);
  LConsumed := S.HandleMouse(TRect.Make(0, 0, 30, 10), LEv.Mouse, LState);
  Check(not LConsumed, 'pane click is not consumed as divider drag');
  Check(not LState.Dragging, 'pane click does not start drag');

  LEv := MouseEvent(mkDrag, mbLeft, 25, 1, []);
  LConsumed := S.HandleMouse(TRect.Make(0, 0, 30, 10), LEv.Mouse, LState);
  Check(not LConsumed, 'drag without capture is ignored');
  Check(Abs(LState.Ratio - 0.5) < 0.0001, 'drag without capture keeps ratio');
end;

{ === TModal === }
procedure TestModalContentArea;
var M: IModal; R: TRect;
begin
  M := TModal.New.WithSize(20, 10).WithVisible(True);
  R := M.ContentArea(TRect.Make(0, 0, 80, 24));
  Check(R.Width = 20, 'modal width 20');
  Check(R.Height = 10, 'modal height 10');
  Check(R.X = 30, 'modal centered X');
end;

procedure TestModalRender;
var M: IWidget; LBuf: TBuffer;
begin
  M := TModal.New.WithVisible(True).WithSize(10, 5) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 20));
  try
    M.Render(TRect.Make(0, 0, 40, 20), LBuf);
    Check(True, 'modal renders');
  finally LBuf.Free; end;
end;

procedure TestModalInvisible;
var M: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  M := TModal.New as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    M.Render(TRect.Make(0, 0, 20, 10), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(LRow = '                    ', 'invisible modal no output');
  finally LBuf.Free; end;
end;

{ === TTooltip === }
procedure TestTooltipRenderAt;
var Tip: ITooltip; LBuf: TBuffer; LRow: AnsiString;
begin
  Tip := TTooltip.New('Hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tip.RenderAt(TRect.Make(5, 5, 1, 1), TRect.Make(0, 0, 20, 10), LBuf);
    LRow := LBuf.RowAsString(3);
    Check(Pos('Hello', LRow) > 0, 'tooltip text visible');
  finally LBuf.Free; end;
end;

procedure TestTooltipAsIWidget;
var Tip: IWidget; LBuf: TBuffer;
begin
  Tip := TTooltip.New('Test').WithPosition(ttpBelow) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tip.Render(TRect.Make(0, 0, 20, 10), LBuf);
    Check(True, 'tooltip renders as IWidget');
  finally LBuf.Free; end;
end;

{ === TPopover === }
procedure TestPopoverBorderedTinyWidthDoesNotLeakContent;
var
  Pop: IPopover;
  State: TPopoverState;
  LBuf: TBuffer;
  LRow: AnsiString;
begin
  Pop := TPopover.New(['Item']).WithWidth(1).WithBorder(True);
  State := TPopoverState.Hidden;
  State.Show;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 12, 6));
  try
    Pop.RenderStateful(TRect.Make(0, 0, 1, 1), TRect.Make(0, 0, 12, 6),
      LBuf, State);
    LRow := LBuf.RowAsString(2);
    Check(Pos('Item', LRow) = 0, 'tiny bordered popover does not leak content outside border');
  finally LBuf.Free; end;
end;

{ === Modal builders === }
procedure TestModalSizePercent;
var M: IModal; R: TRect;
begin
  M := TModal.New.WithSizePercent(50, 50).WithVisible(True);
  R := M.ContentArea(TRect.Make(0, 0, 80, 24));
  Check(R.Width = 40, '50% of 80 = 40');
  Check(R.Height = 12, '50% of 24 = 12');
end;

procedure TestModalDimBackground;
var M: IWidget; LBuf: TBuffer;
begin
  M := TModal.New.WithVisible(True).WithDimBackground(True).WithSize(10, 5) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 20));
  try
    M.Render(TRect.Make(0, 0, 40, 20), LBuf);
    Check(True, 'modal with dim background renders');
  finally LBuf.Free; end;
end;

{ === Tooltip builders === }
procedure TestTooltipAbove;
var Tip: ITooltip; LBuf: TBuffer; LRow: AnsiString;
begin
  Tip := TTooltip.New('Above').WithPosition(ttpAbove);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tip.RenderAt(TRect.Make(5, 5, 1, 1), TRect.Make(0, 0, 20, 10), LBuf);
    LRow := LBuf.RowAsString(3);
    Check(Pos('Above', LRow) > 0, 'above tooltip visible');
  finally LBuf.Free; end;
end;

procedure TestTooltipMaxWidth;
var Tip: ITooltip; LBuf: TBuffer;
begin
  Tip := TTooltip.New('Long text that should wrap').WithMaxWidth(8);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Tip.RenderAt(TRect.Make(0, 0, 1, 1), TRect.Make(0, 0, 20, 10), LBuf);
    Check(True, 'tooltip with max width renders');
  finally LBuf.Free; end;
end;

{ === Popover builders === }
procedure TestPopoverShowHide;
var State: TPopoverState;
begin
  State := TPopoverState.Hidden;
  Check(not State.Visible, 'hidden by default');
  State.Show;
  Check(State.Visible, 'visible after show');
  State.Hide;
  Check(not State.Visible, 'hidden after hide');
end;

procedure TestPopoverMaxHeight;
var
  Pop: IPopover;
  State: TPopoverState;
  LBuf: TBuffer;
begin
  Pop := TPopover.New(['A', 'B', 'C', 'D', 'E']).WithMaxHeight(3).WithBorder(True);
  State := TPopoverState.Hidden;
  State.Show;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 10));
  try
    Pop.RenderStateful(TRect.Make(0, 0, 1, 1), TRect.Make(0, 0, 20, 10),
      LBuf, State);
    Check(True, 'popover with max height renders');
  finally LBuf.Free; end;
end;

{ === SplitPane drag === }
procedure TestSplitPaneDividerDrag;
var
  S: ISplitPane;
  LState: TSplitPaneState;
  LPane1, LPane2, LDivider: TRect;
  LEv: TEvent;
  LConsumed: Boolean;
  LOriginalRatio: Double;
begin
  S := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  S.Split(TRect.Make(0, 0, 30, 10), LState, LPane1, LPane2, LDivider);
  LOriginalRatio := LState.Ratio;

  { click on divider to start drag }
  LEv := MouseEvent(mkDown, mbLeft, LDivider.X, LDivider.Y, []);
  LConsumed := S.HandleMouse(TRect.Make(0, 0, 30, 10), LEv.Mouse, LState);
  Check(LConsumed, 'divider click consumed');
  Check(LState.Dragging, 'dragging started');

  { drag to new position }
  LEv := MouseEvent(mkDrag, mbLeft, LDivider.X + 3, LDivider.Y, []);
  LConsumed := S.HandleMouse(TRect.Make(0, 0, 30, 10), LEv.Mouse, LState);
  Check(LConsumed, 'drag consumed');
  Check(Abs(LState.Ratio - LOriginalRatio) > 0.001, 'ratio changed after drag');

  { release }
  LEv := MouseEvent(mkUp, mbLeft, LDivider.X + 3, LDivider.Y, []);
  LConsumed := S.HandleMouse(TRect.Make(0, 0, 30, 10), LEv.Mouse, LState);
  Check(not LState.Dragging, 'dragging ended on release');
end;

{ === Layout constraints === }
procedure TestLayoutFillConstraint;
var L: TLayout; Rs: TRectArray;
begin
  L := TLayout.Horizontal([LengthConstraint(5), FillConstraint(1), FillConstraint(2)]);
  Rs := L.Split(TRect.Make(0, 0, 35, 1));
  CheckEqual(3, Length(Rs), '3 regions');
  CheckEqual(5, Rs[0].Width, 'first is fixed 5');
  { fill 1:fill 2 in 30 remaining → 10:20 }
  Check(Rs[1].Width > 0, 'fill 1 has width');
  Check(Rs[2].Width > Rs[1].Width, 'fill 2 > fill 1');
  CheckEqual(35, Rs[0].Width + Rs[1].Width + Rs[2].Width, 'total preserved');
end;

procedure TestLayoutPercentageConstraint;
var L: TLayout; Rs: TRectArray;
begin
  L := TLayout.Horizontal([PercentageConstraint(50), PercentageConstraint(50)]);
  Rs := L.Split(TRect.Make(0, 0, 100, 1));
  CheckEqual(2, Length(Rs), '2 regions');
  CheckEqual(50, Rs[0].Width, '50% of 100 = 50');
  CheckEqual(50, Rs[1].Width, '50% of 100 = 50');
end;

procedure TestLayoutRatioConstraint;
var L: TLayout; Rs: TRectArray;
begin
  { RatioConstraint(1,3) = 33%, RatioConstraint(2,3) = 66% }
  L := TLayout.Horizontal([RatioConstraint(1, 3), RatioConstraint(2, 3)]);
  Rs := L.Split(TRect.Make(0, 0, 60, 1));
  CheckEqual(2, Length(Rs), '2 regions');
  Check(Rs[0].Width > 0, 'ratio 1/3 has width');
  Check(Rs[1].Width > Rs[0].Width, 'ratio 2/3 > 1/3');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.layout');
  T.Test('panel new', @TestPanelNew);
  T.Test('panel layout', @TestPanelLayout);
  T.Test('panel as IWidget', @TestPanelAsIWidget);
  T.Test('panel sidebar', @TestPanelSidebar);
  T.Test('split_pane horizontal', @TestSplitPaneHorizontal);
  T.Test('split_pane vertical', @TestSplitPaneVertical);
  T.Test('split_pane mouse down outside divider does not start drag',
    @TestSplitPaneMouseDownOutsideDividerDoesNotStartDrag);
  T.Test('modal content area', @TestModalContentArea);
  T.Test('modal render', @TestModalRender);
  T.Test('modal invisible', @TestModalInvisible);
  T.Test('tooltip render at', @TestTooltipRenderAt);
  T.Test('tooltip as IWidget', @TestTooltipAsIWidget);
  T.Test('popover bordered tiny width does not leak content',
    @TestPopoverBorderedTinyWidthDoesNotLeakContent);
  T.Test('modal size percent', @TestModalSizePercent);
  T.Test('modal dim background', @TestModalDimBackground);
  T.Test('tooltip above', @TestTooltipAbove);
  T.Test('tooltip max width', @TestTooltipMaxWidth);
  T.Test('popover show/hide', @TestPopoverShowHide);
  T.Test('popover max height', @TestPopoverMaxHeight);
  T.Test('split_pane divider drag', @TestSplitPaneDividerDrag);
  T.Test('layout fill constraint', @TestLayoutFillConstraint);
  T.Test('layout percentage constraint', @TestLayoutPercentageConstraint);
  T.Test('layout ratio constraint', @TestLayoutRatioConstraint);
  if not T.Run then Halt(1);
end.
