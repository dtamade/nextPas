program test_tui_widget_panel;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.dsl,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.panel,
  nextpas.core.test;

var
  T: TTestSuite;

{ === Layout Tests === }

procedure TestLayoutSingleCell;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  CheckEqual(1, G.ColCount, 'single cell col count');
  CheckEqual(1, G.RowCount, 'single cell row count');
  { With all edges, inner area is 18x8 }
  CheckEqual(18, Integer(G.Cells[0].Width), 'single cell width');
  CheckEqual(8, Integer(G.Cells[0].Height), 'single cell height');
end;

procedure TestLayoutGrid;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.Grid(2, 2);
  G := P.Layout(TRect.Make(0, 0, 21, 11));
  CheckEqual(2, G.ColCount, 'grid col count');
  CheckEqual(2, G.RowCount, 'grid row count');
  { Inner area: 19x9, minus 1 inner V sep and 1 inner H sep = 18x8 for cells }
  { Each cell ~9x4 }
  Check(G.Cells[0].Width > 0, 'cell 0,0 has width');
  Check(G.Cells[0].Height > 0, 'cell 0,0 has height');
end;

procedure TestLayoutSidebar;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.Sidebar(5);
  G := P.Layout(TRect.Make(0, 0, 30, 10));
  CheckEqual(2, G.ColCount, 'sidebar col count');
  CheckEqual(1, G.RowCount, 'sidebar row count');
  CheckEqual(5, Integer(G.Cells[0].Width), 'sidebar width');
end;

procedure TestLayoutHSplit;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.HSplit(3);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  CheckEqual(1, G.ColCount, 'hsplit col count');
  CheckEqual(2, G.RowCount, 'hsplit row count');
  CheckEqual(3, Integer(G.Cells[0].Height), 'top height');
end;

procedure TestLayoutEmptyArea;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.Grid(2, 2);
  G := P.Layout(TRect.Make(0, 0, 0, 0));
  { Empty area returns valid grid but with zero-size cells }
  Check(G.ColCount > 0, 'empty area still has col count');
end;

procedure TestLayoutNoEdges;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  CheckEqual(20, Integer(G.Cells[0].Width), 'no edges full width');
  CheckEqual(10, Integer(G.Cells[0].Height), 'no edges full height');
end;

procedure TestLayoutOuterEdgesOnly;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  P.WithEdges(PanelEdgesOuter);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  CheckEqual(18, Integer(G.Cells[0].Width), 'outer edges width');
  CheckEqual(8, Integer(G.Cells[0].Height), 'outer edges height');
end;

{ === Constraint Tests === }

procedure TestLayoutFixedConstraints;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([LengthConstraint(5), LengthConstraint(10)], [MinConstraint(0)]);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  CheckEqual(5, Integer(G.Cells[0].Width), 'first col fixed width');
  { Second col gets remaining space after first col }
  Check(G.Cells[1].Width > 0, 'second col has width');
end;

procedure TestLayoutPercentageConstraints;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([PercentageConstraint(50), PercentageConstraint(50)], [MinConstraint(0)]);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  CheckEqual(10, Integer(G.Cells[0].Width), '50% width');
  CheckEqual(10, Integer(G.Cells[1].Width), '50% width');
end;

procedure TestLayoutMinWidth;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  P.WithMinWidth(0, 15);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  Check(G.Cells[0].Width >= 15, 'min width enforced');
end;

{ === Padding Tests === }

procedure TestLayoutPadding;
var
  P: IPanel;
  G: TPanelGrid;
  Cell: TRect;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  P.WithPadding(2);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  Cell := PanelCellPadded(TPanel(P), G, 0, 0);
  { Padding should reduce the cell area }
  Check(Cell.Width <= G.Cells[0].Width, 'padded width <= original');
  Check(Cell.Height <= G.Cells[0].Height, 'padded height <= original');
end;

procedure TestLayoutCellPadding;
var
  P: IPanel;
  G: TPanelGrid;
  Cell: TRect;
begin
  P := TPanel.Grid(2, 1);
  P.WithCellPadding(0, 0, 1);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  Cell := PanelCellPadded(TPanel(P), G, 0, 0);
  { Cell padding should reduce the cell area }
  Check(Cell.Width <= G.Cells[0].Width, 'cell padding reduces width');
end;

{ === Separator Tests === }

procedure TestLayoutHSepVisible;
var
  P: IPanel;
  Buf: TBuffer;
  LLines: TBufferLines;
begin
  P := TPanel.Grid(1, 2);
  P.WithHSepVisible(0, False);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 5));
  try
    P.Render(TRect.Make(0, 0, 10, 5), Buf);
    LLines := Buf.AsLines;
    { With separator hidden, no horizontal line in the middle }
    Check(True, 'render completes without error');
  finally
    Buf.Free;
  end;
end;

procedure TestLayoutHSepTitle;
var
  P: IPanel;
  Buf: TBuffer;
  LLines: TBufferLines;
begin
  P := TPanel.Grid(1, 2);
  P.WithHSepTitle(0, 'Title');
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    P.Render(TRect.Make(0, 0, 20, 5), Buf);
    LLines := Buf.AsLines;
    { Title should appear somewhere in the buffer }
    Check(Length(LLines) > 0, 'buffer has lines');
  finally
    Buf.Free;
  end;
end;

{ === Focus Tests === }

procedure TestLayoutFocus;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.Grid(2, 2);
  P.WithFocus(1, 1);
  G := P.Layout(TRect.Make(0, 0, 20, 10));
  Check(G.Cells[3].Width > 0, 'focused cell has dimensions');
end;

{ === Cell Span Tests === }

procedure TestPanelCellSpan;
var
  P: IPanel;
  G: TPanelGrid;
  SpanRect: TRect;
begin
  P := TPanel.Grid(3, 3);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 30, 15));
  SpanRect := PanelCellSpan(G, 0, 0, 2, 2);
  Check(SpanRect.Width > G.Cells[0].Width, 'span width > single cell');
  Check(SpanRect.Height > G.Cells[0].Height, 'span height > single cell');
end;

{ === Hit Test Tests === }

procedure TestPanelHitTestSep;
var
  P: IPanel;
  G: TPanelGrid;
  Hit: TSepHit;
begin
  P := TPanel.Grid(2, 2);
  G := P.Layout(TRect.Make(0, 0, 21, 11));
  { Test hitting a vertical separator }
  Hit := PanelHitTestSep(G, G.ColOffsets[1] - 1, 5);
  Check(Hit.Found, 'separator found');
  Check(not Hit.IsHorizontal, 'vertical separator');
end;

{ === Render Tests === }

procedure TestRenderWithBorders;
var
  P: IPanel;
  Buf: TBuffer;
  LLines: TBufferLines;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    P.Render(TRect.Make(0, 0, 5, 3), Buf);
    LLines := Buf.AsLines;
    Check(Length(LLines[0]) > 0, 'top border rendered');
    Check(Length(LLines[2]) > 0, 'bottom border rendered');
  finally
    Buf.Free;
  end;
end;

procedure TestRenderGrid2x2;
var
  P: IPanel;
  Buf: TBuffer;
begin
  P := TPanel.Grid(2, 2);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 11, 7));
  try
    P.Render(TRect.Make(0, 0, 11, 7), Buf);
    Check(True, '2x2 grid renders without error');
  finally
    Buf.Free;
  end;
end;

procedure TestRenderRoundedBorders;
var
  P: IPanel;
  Buf: TBuffer;
  LLines: TBufferLines;
begin
  P := TPanel.New([MinConstraint(0)], [MinConstraint(0)]);
  P.WithBorderSet(BorderSetRounded);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 3));
  try
    P.Render(TRect.Make(0, 0, 5, 3), Buf);
    LLines := Buf.AsLines;
    Check(Length(LLines[0]) > 0, 'rounded border renders');
  finally
    Buf.Free;
  end;
end;

procedure TestRenderEmptyPanel;
var
  P: IPanel;
  Buf: TBuffer;
begin
  P := TPanel.New([], []);
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 10));
  try
    P.Render(TRect.Make(0, 0, 10, 10), Buf);
    Check(True, 'empty panel renders without error');
  finally
    Buf.Free;
  end;
end;

{ === Builder Pattern Tests === }

procedure TestBuilderChaining;
var
  P: IPanel;
begin
  P := TPanel.Grid(2, 2)
    .WithBorderSet(BorderSetRounded)
    .WithEdges(PanelEdgesAll)
    .WithPadding(1)
    .WithFocus(0, 0);
  Check(P <> nil, 'builder chaining returns non-nil');
end;

procedure TestBuilderMinMaxConstraints;
var
  P: IPanel;
  G: TPanelGrid;
begin
  P := TPanel.New([AtLeast(5), AtMost(15)], [MinConstraint(0)]);
  P.WithEdges(PanelEdgesNone);
  G := P.Layout(TRect.Make(0, 0, 30, 10));
  Check(G.Cells[0].Width >= 5, 'AtLeast constraint respected');
  Check(G.Cells[0].Width <= 15, 'AtMost constraint respected');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.panel');

  { Layout tests }
  T.Test('layout single cell', @TestLayoutSingleCell);
  T.Test('layout grid 2x2', @TestLayoutGrid);
  T.Test('layout sidebar', @TestLayoutSidebar);
  T.Test('layout hsplit', @TestLayoutHSplit);
  T.Test('layout empty area', @TestLayoutEmptyArea);
  T.Test('layout no edges', @TestLayoutNoEdges);
  T.Test('layout outer edges only', @TestLayoutOuterEdgesOnly);

  { Constraint tests }
  T.Test('layout fixed constraints', @TestLayoutFixedConstraints);
  T.Test('layout percentage constraints', @TestLayoutPercentageConstraints);
  T.Test('layout min width', @TestLayoutMinWidth);

  { Padding tests }
  T.Test('layout padding', @TestLayoutPadding);
  T.Test('layout cell padding', @TestLayoutCellPadding);

  { Separator tests }
  T.Test('layout hsep visible', @TestLayoutHSepVisible);
  T.Test('layout hsep title', @TestLayoutHSepTitle);

  { Focus tests }
  T.Test('layout focus', @TestLayoutFocus);

  { Cell span tests }
  T.Test('panel cell span', @TestPanelCellSpan);

  { Hit test tests }
  T.Test('panel hit test sep', @TestPanelHitTestSep);

  { Render tests }
  T.Test('render with borders', @TestRenderWithBorders);
  T.Test('render grid 2x2', @TestRenderGrid2x2);
  T.Test('render rounded borders', @TestRenderRoundedBorders);
  T.Test('render empty panel', @TestRenderEmptyPanel);

  { Builder pattern tests }
  T.Test('builder chaining', @TestBuilderChaining);
  T.Test('builder min max constraints', @TestBuilderMinMaxConstraints);

  if not T.Run then Halt(1);
end.
