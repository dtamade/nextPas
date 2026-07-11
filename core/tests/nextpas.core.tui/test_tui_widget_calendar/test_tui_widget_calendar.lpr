program test_tui_widget_calendar;

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
  nextpas.core.tui.widget.calendar,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestCalendarStateToday;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Today;
  Check(LState.Year >= 2024, 'Year should be >= 2024');
  Check((LState.Month >= 1) and (LState.Month <= 12), 'Month should be 1-12');
  Check((LState.SelectedDay >= 1) and (LState.SelectedDay <= 31), 'Day should be 1-31');
end;

procedure TestCalendarStateMake;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 15);
  Check(LState.Year = 2024, 'Year should be 2024');
  Check(LState.Month = 6, 'Month should be 6');
  Check(LState.SelectedDay = 15, 'Day should be 15');
end;

procedure TestCalendarStatePrevMonth;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 15);
  LState.PrevMonth;
  Check(LState.Month = 5, 'Month should be 5 after prev');
  Check(LState.Year = 2024, 'Year should still be 2024');
end;

procedure TestCalendarStatePrevMonthJanuary;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 1, 15);
  LState.PrevMonth;
  Check(LState.Month = 12, 'Month should be 12 after prev from January');
  Check(LState.Year = 2023, 'Year should be 2023 after prev from January');
end;

procedure TestCalendarStateNextMonth;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 15);
  LState.NextMonth;
  Check(LState.Month = 7, 'Month should be 7 after next');
  Check(LState.Year = 2024, 'Year should still be 2024');
end;

procedure TestCalendarStateNextMonthDecember;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 12, 15);
  LState.NextMonth;
  Check(LState.Month = 1, 'Month should be 1 after next from December');
  Check(LState.Year = 2025, 'Year should be 2025 after next from December');
end;

procedure TestCalendarStatePrevDay;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 15);
  LState.PrevDay;
  Check(LState.SelectedDay = 14, 'Day should be 14 after prev');
end;

procedure TestCalendarStatePrevDayFirst;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 1);
  LState.PrevDay;
  Check(LState.SelectedDay = 31, 'Day should be 31 after prev from June 1');
  Check(LState.Month = 5, 'Month should be 5 after prev from June 1');
end;

procedure TestCalendarStateNextDay;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 15);
  LState.NextDay;
  Check(LState.SelectedDay = 16, 'Day should be 16 after next');
end;

procedure TestCalendarStateNextDayLast;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 6, 30);
  LState.NextDay;
  Check(LState.SelectedDay = 1, 'Day should be 1 after next from June 30');
  Check(LState.Month = 7, 'Month should be 7 after next from June 30');
end;

procedure TestCalendarStateDaysInMonth;
var
  LState: TCalendarState;
begin
  LState := TCalendarState.Make(2024, 1, 1);
  Check(LState.DaysInMonth = 31, 'January should have 31 days');
  LState := TCalendarState.Make(2024, 2, 1);
  Check(LState.DaysInMonth = 29, 'February 2024 should have 29 days (leap year)');
  LState := TCalendarState.Make(2023, 2, 1);
  Check(LState.DaysInMonth = 28, 'February 2023 should have 28 days');
  LState := TCalendarState.Make(2024, 4, 1);
  Check(LState.DaysInMonth = 30, 'April should have 30 days');
  LState := TCalendarState.Make(2024, 12, 1);
  Check(LState.DaysInMonth = 31, 'December should have 31 days');
end;

procedure TestCalendarNew;
var
  LCalendar: ICalendar;
begin
  LCalendar := TCalendar.New;
  Check(LCalendar <> nil, 'New calendar should not be nil');
end;

procedure TestCalendarWithStyle;
var
  LCalendar: ICalendar;
  LStyle: TStyle;
begin
  LCalendar := TCalendar.New;
  LStyle.Fg := IndexedColor(1);
  LStyle.Bg := IndexedColor(2);
  LCalendar := LCalendar.WithStyle(LStyle);
  Check(LCalendar <> nil, 'WithStyle should return calendar');
end;

procedure TestCalendarWithHeaderStyle;
var
  LCalendar: ICalendar;
  LStyle: TStyle;
begin
  LCalendar := TCalendar.New;
  LStyle.Fg := IndexedColor(3);
  LCalendar := LCalendar.WithHeaderStyle(LStyle);
  Check(LCalendar <> nil, 'WithHeaderStyle should return calendar');
end;

procedure TestCalendarWithSelectedStyle;
var
  LCalendar: ICalendar;
  LStyle: TStyle;
begin
  LCalendar := TCalendar.New;
  LStyle.Fg := IndexedColor(4);
  LCalendar := LCalendar.WithSelectedStyle(LStyle);
  Check(LCalendar <> nil, 'WithSelectedStyle should return calendar');
end;

procedure TestCalendarWithTodayStyle;
var
  LCalendar: ICalendar;
  LStyle: TStyle;
begin
  LCalendar := TCalendar.New;
  LStyle.Fg := IndexedColor(5);
  LCalendar := LCalendar.WithTodayStyle(LStyle);
  Check(LCalendar <> nil, 'WithTodayStyle should return calendar');
end;

procedure TestCalendarWithWeekendStyle;
var
  LCalendar: ICalendar;
  LStyle: TStyle;
begin
  LCalendar := TCalendar.New;
  LStyle.Fg := IndexedColor(6);
  LCalendar := LCalendar.WithWeekendStyle(LStyle);
  Check(LCalendar <> nil, 'WithWeekendStyle should return calendar');
end;

procedure TestCalendarWithBlock;
var
  LCalendar: ICalendar;
  LBlock: IBlock;
begin
  LCalendar := TCalendar.New;
  LBlock := TBlock.New;
  LCalendar := LCalendar.WithBlock(LBlock);
  Check(LCalendar <> nil, 'WithBlock should return calendar');
end;

procedure TestCalendarRender;
var
  LCalendar: ICalendar;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LCalendar := TCalendar.New;
  LArea := TRect.Make(0, 0, 20, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LCalendar.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestCalendarRenderStateful;
var
  LCalendar: ICalendar;
  LBuffer: TBuffer;
  LArea: TRect;
  LState: TCalendarState;
begin
  LCalendar := TCalendar.New;
  LArea := TRect.Make(0, 0, 20, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LState := TCalendarState.Make(2024, 6, 15);
    LCalendar.RenderStateful(LArea, LBuffer, LState);
    Check(True, 'RenderStateful should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestCalendarBuilderChaining;
var
  LCalendar: ICalendar;
  LStyle: TStyle;
begin
  LCalendar := TCalendar.New;
  LStyle.Fg := IndexedColor(1);
  LCalendar := LCalendar
    .WithStyle(LStyle)
    .WithHeaderStyle(LStyle)
    .WithSelectedStyle(LStyle)
    .WithTodayStyle(LStyle)
    .WithWeekendStyle(LStyle);
  Check(LCalendar <> nil, 'Builder chaining should work');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.calendar');
  T.Test('TCalendarState.Today', @TestCalendarStateToday);
  T.Test('TCalendarState.Make', @TestCalendarStateMake);
  T.Test('TCalendarState.PrevMonth', @TestCalendarStatePrevMonth);
  T.Test('TCalendarState.PrevMonth January', @TestCalendarStatePrevMonthJanuary);
  T.Test('TCalendarState.NextMonth', @TestCalendarStateNextMonth);
  T.Test('TCalendarState.NextMonth December', @TestCalendarStateNextMonthDecember);
  T.Test('TCalendarState.PrevDay', @TestCalendarStatePrevDay);
  T.Test('TCalendarState.PrevDay first', @TestCalendarStatePrevDayFirst);
  T.Test('TCalendarState.NextDay', @TestCalendarStateNextDay);
  T.Test('TCalendarState.NextDay last', @TestCalendarStateNextDayLast);
  T.Test('TCalendarState.DaysInMonth', @TestCalendarStateDaysInMonth);
  T.Test('TCalendar.New', @TestCalendarNew);
  T.Test('TCalendar.WithStyle', @TestCalendarWithStyle);
  T.Test('TCalendar.WithHeaderStyle', @TestCalendarWithHeaderStyle);
  T.Test('TCalendar.WithSelectedStyle', @TestCalendarWithSelectedStyle);
  T.Test('TCalendar.WithTodayStyle', @TestCalendarWithTodayStyle);
  T.Test('TCalendar.WithWeekendStyle', @TestCalendarWithWeekendStyle);
  T.Test('TCalendar.WithBlock', @TestCalendarWithBlock);
  T.Test('TCalendar.Render', @TestCalendarRender);
  T.Test('TCalendar.RenderStateful', @TestCalendarRenderStateful);
  T.Test('TCalendar builder chaining', @TestCalendarBuilderChaining);
  if not T.Run then Halt(1);
end.
