program test_tui_widget_data;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.linechart,
  nextpas.core.tui.widget.progress_group,
  nextpas.core.tui.widget.timeline,
  nextpas.core.tui.widget.calendar,
  nextpas.core.tui.widget.breadcrumb,
  nextpas.core.tui.widget.statusbar,
  nextpas.core.testing;
var T: TTestRunner;

procedure CheckOutsideAreaEmpty(LBuf: TBuffer; const AArea: TRect; const AMessage: AnsiString);
var
  LX, LY: Integer;
  LCell: PCell;
begin
  for LY := LBuf.Area.Y to LBuf.Area.Y + LBuf.Area.Height - 1 do
    for LX := LBuf.Area.X to LBuf.Area.X + LBuf.Area.Width - 1 do
      if not AArea.Contains(PositionMake(LX, LY)) then
      begin
        LCell := LBuf.CellAt(LX, LY);
        Check(CellEquals(LCell^, CELL_EMPTY), AMessage);
      end;
end;

{ === TLineChart === }
procedure TestLineChartRender;
var LC: IWidget; LBuf: TBuffer;
begin
  LC := TLineChart.New([
    TDataSeries.Create('CPU', [10.0, 50.0, 30.0, 80.0, 20.0])
  ]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 12));
  try
    LC.Render(TRect.Make(0, 0, 40, 12), LBuf);
    Check(True, 'linechart renders');
  finally LBuf.Free; end;
end;

procedure TestLineChartMultiSeries;
var LC: IWidget; LBuf: TBuffer;
begin
  LC := TLineChart.New([
    TDataSeries.Create('A', [1.0, 2.0, 3.0]),
    TDataSeries.Create('B', [3.0, 2.0, 1.0])
  ]).WithShowAxes(True).WithShowLegend(True) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 10));
  try
    LC.Render(TRect.Make(0, 0, 30, 10), LBuf);
    Check(True, 'multi-series renders');
  finally LBuf.Free; end;
end;

{ === TProgressGroup === }
procedure TestProgressGroupRender;
var PG: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  PG := TProgressGroup.New([
    TProgressItem.Make('Task A', 0.75),
    TProgressItem.Make('Task B', 0.30)
  ]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 3));
  try
    PG.Render(TRect.Make(0, 0, 40, 3), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Task A', LRow) > 0, 'label A visible');
  finally LBuf.Free; end;
end;

procedure TestProgressGroupTinyAreaDoesNotWriteOutsideCallerArea;
var
  PG: IWidget;
  LBuf: TBuffer;
begin
  PG := TProgressGroup.New([
    TProgressItem.Make('LongTask', 0.75),
    TProgressItem.Make('Second', 0.30)
  ]) as IWidget;
  LBuf := TBuffer.CreateFilled(TRect.Make(0, 0, 12, 3), CELL_EMPTY);
  try
    PG.Render(TRect.Make(0, 0, 1, 1), LBuf);
    CheckOutsideAreaEmpty(LBuf, TRect.Make(0, 0, 1, 1),
      'progress group keeps caller area boundary');
  finally LBuf.Free; end;
end;

{ === TTimeline === }
procedure TestTimelineRender;
var TL: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  TL := TTimeline.New([
    TTimelineEvent.Make('09:00', 'Start'),
    TTimelineEvent.Make('10:30', 'Meeting').WithDescription('Team sync')
  ]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 8));
  try
    TL.Render(TRect.Make(0, 0, 40, 8), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Start', LRow) > 0, 'first event visible');
  finally LBuf.Free; end;
end;

{ === TCalendar === }
procedure TestCalendarRender;
var Cal: IWidget; LBuf: TBuffer;
begin
  Cal := TCalendar.New as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 22, 9));
  try
    Cal.Render(TRect.Make(0, 0, 22, 9), LBuf);
    Check(True, 'calendar renders');
  finally LBuf.Free; end;
end;

{ === TBreadcrumb === }
procedure TestBreadcrumbRender;
var BC: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  BC := TBreadcrumb.New(['Home', 'Projects', 'TUI']) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 1));
  try
    BC.Render(TRect.Make(0, 0, 40, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Home', LRow) > 0, 'Home visible');
    Check(Pos('>', LRow) > 0, 'separator visible');
    Check(Pos('TUI', LRow) > 0, 'TUI visible');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbTotalWidth;
var BC: IBreadcrumb;
begin
  BC := TBreadcrumb.New(['A', 'B', 'C']);
  Check(BC.TotalWidth = 9, 'A > B > C = 9 cols');
end;

{ === TStatusBar === }
procedure TestStatusBarRender;
var SB: IWidget; LBuf: TBuffer; LRow: AnsiString;
begin
  SB := TStatusBar.New
    .WithLeft([TStatusSegment.Make('LEFT')])
    .WithRight([TStatusSegment.Make('RIGHT')]) as IWidget;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 1));
  try
    SB.Render(TRect.Make(0, 0, 30, 1), LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('LEFT', LRow) > 0, 'left segment');
    Check(Pos('RIGHT', LRow) > 0, 'right segment');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.data');
  T.Run('linechart render', @TestLineChartRender);
  T.Run('linechart multi-series', @TestLineChartMultiSeries);
  T.Run('progress_group render', @TestProgressGroupRender);
  T.Run('progress_group tiny area clipping', @TestProgressGroupTinyAreaDoesNotWriteOutsideCallerArea);
  T.Run('timeline render', @TestTimelineRender);
  T.Run('calendar render', @TestCalendarRender);
  T.Run('breadcrumb render', @TestBreadcrumbRender);
  T.Run('breadcrumb total width', @TestBreadcrumbTotalWidth);
  T.Run('statusbar render', @TestStatusBarRender);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
