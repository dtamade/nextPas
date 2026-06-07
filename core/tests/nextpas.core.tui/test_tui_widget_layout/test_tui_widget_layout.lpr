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
  nextpas.core.testing;
var T: TTestRunner;

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

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.layout');
  T.Run('panel new', @TestPanelNew);
  T.Run('panel layout', @TestPanelLayout);
  T.Run('panel as IWidget', @TestPanelAsIWidget);
  T.Run('panel sidebar', @TestPanelSidebar);
  T.Run('split_pane horizontal', @TestSplitPaneHorizontal);
  T.Run('split_pane vertical', @TestSplitPaneVertical);
  T.Run('split_pane mouse down outside divider does not start drag',
    @TestSplitPaneMouseDownOutsideDividerDoesNotStartDrag);
  T.Run('modal content area', @TestModalContentArea);
  T.Run('modal render', @TestModalRender);
  T.Run('modal invisible', @TestModalInvisible);
  T.Run('tooltip render at', @TestTooltipRenderAt);
  T.Run('tooltip as IWidget', @TestTooltipAsIWidget);
  T.Run('popover bordered tiny width does not leak content',
    @TestPopoverBorderedTinyWidthDoesNotLeakContent);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
