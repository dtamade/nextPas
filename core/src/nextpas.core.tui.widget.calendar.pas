unit nextpas.core.tui.widget.calendar;

{$I nextpas.core.settings.inc}

{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block;

type
  TCalendarState = record
    Year: Word;
    Month: Word;
    SelectedDay: Word;

    class function Today: TCalendarState; static;
    class function Make(AYear, AMonth, ADay: Word): TCalendarState; static;
    procedure PrevMonth;
    procedure NextMonth;
    procedure PrevDay;
    procedure NextDay;
    function DaysInMonth: Word;
  end;

  TCalendar = record
    Style: TStyle;
    HeaderStyle: TStyle;
    SelectedStyle: TStyle;
    TodayStyle: TStyle;
    WeekendStyle: TStyle;
    HasBlock: Boolean;
    Block: IBlock;

    class function Default: TCalendar; static;
    function WithStyle(const S: TStyle): TCalendar;
    function WithHeaderStyle(const S: TStyle): TCalendar;
    function WithSelectedStyle(const S: TStyle): TCalendar;
    function WithTodayStyle(const S: TStyle): TCalendar;
    function WithWeekendStyle(const S: TStyle): TCalendar;
    function WithBlock(const B: TBlock): TCalendar;
    procedure RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TCalendarState);
  end;

implementation

uses
  SysUtils, DateUtils;

{ TCalendarState }

class function TCalendarState.Today: TCalendarState;
var Y, M, D: Word;
begin
  DecodeDate(Now, Y, M, D);
  Result.Year := Y;
  Result.Month := M;
  Result.SelectedDay := D;
end;

class function TCalendarState.Make(AYear, AMonth, ADay: Word): TCalendarState;
begin
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.SelectedDay := ADay;
end;

function TCalendarState.DaysInMonth: Word;
begin
  Result := DateUtils.DaysInAMonth(Year, Month);
end;

procedure TCalendarState.PrevMonth;
begin
  if Month = 1 then
  begin
    Month := 12;
    Dec(Year);
  end
  else
    Dec(Month);
  if SelectedDay > DaysInMonth then
    SelectedDay := DaysInMonth;
end;

procedure TCalendarState.NextMonth;
begin
  if Month = 12 then
  begin
    Month := 1;
    Inc(Year);
  end
  else
    Inc(Month);
  if SelectedDay > DaysInMonth then
    SelectedDay := DaysInMonth;
end;

procedure TCalendarState.PrevDay;
begin
  if SelectedDay > 1 then
    Dec(SelectedDay)
  else
  begin
    PrevMonth;
    SelectedDay := DaysInMonth;
  end;
end;

procedure TCalendarState.NextDay;
begin
  if SelectedDay < DaysInMonth then
    Inc(SelectedDay)
  else
  begin
    NextMonth;
    SelectedDay := 1;
  end;
end;

{ TCalendar }

class function TCalendar.Default: TCalendar;
begin
  Result.Style := TStyle.Default;
  Result.HeaderStyle := TStyle.Default.WithModifier([mbBold]);
  Result.SelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  Result.TodayStyle := TStyle.Default.WithFg(TUI_CYAN);
  Result.WeekendStyle := TStyle.Default.WithFg(TUI_RED);
  Result.HasBlock := False;
  Result.Block := nil;
end;

function TCalendar.WithStyle(const S: TStyle): TCalendar;
begin Result := Self; Result.Style := S; end;

function TCalendar.WithHeaderStyle(const S: TStyle): TCalendar;
begin Result := Self; Result.HeaderStyle := S; end;

function TCalendar.WithSelectedStyle(const S: TStyle): TCalendar;
begin Result := Self; Result.SelectedStyle := S; end;

function TCalendar.WithTodayStyle(const S: TStyle): TCalendar;
begin Result := Self; Result.TodayStyle := S; end;

function TCalendar.WithWeekendStyle(const S: TStyle): TCalendar;
begin Result := Self; Result.WeekendStyle := S; end;

function TCalendar.WithBlock(const B: TBlock): TCalendar;
begin Result := Self; Result.HasBlock := True; Result.Block := B; end;

procedure TCalendar.RenderStateful(const Area: TRect; ABuf: TBuffer; var State: TCalendarState);
var
  Inner: TRect;
  HeaderStr: AnsiString;
  FirstDow, Days, Day, Col, Row, Y, X: Integer;
  DayBuf: string[2];
  CellStyle: TStyle;
  NowY, NowM, NowD: Word;
  IsToday: Boolean;
const
  DowHeader = 'Mo Tu We Th Fr Sa Su';
begin
  if Area.IsEmpty then Exit;

  ABuf.SetStyle(Area, Style);

  if HasBlock then
  begin
    Block.Render(Area, ABuf);
    Inner := Block.Inner(Area);
  end
  else
    Inner := Area;

  if (Inner.Width < 20) or (Inner.Height < 3) then Exit;

  // Header: "January 2026"
  HeaderStr := FormatDateTime('mmmm yyyy', EncodeDate(State.Year, State.Month, 1));
  X := Inner.X + (Inner.Width - Length(HeaderStr)) div 2;
  if X < Inner.X then X := Inner.X;
  ABuf.SetStringN(X, Inner.Y, HeaderStr, Inner.Width, HeaderStyle);

  // Day-of-week header
  Y := Inner.Y + 1;
  ABuf.SetStringN(Inner.X, Y, DowHeader, Inner.Width, HeaderStyle);

  // Calendar grid
  Days := State.DaysInMonth;
  FirstDow := DayOfTheWeek(EncodeDate(State.Year, State.Month, 1)); // 1=Mon..7=Sun

  DecodeDate(Now, NowY, NowM, NowD);

  Day := 1;
  Row := 0;
  while Day <= Days do
  begin
    Y := Inner.Y + 2 + Row;
    if Y >= Inner.Y + Inner.Height then Break;

    for Col := 1 to 7 do
    begin
      if (Row = 0) and (Col < FirstDow) then Continue;
      if Day > Days then Break;

      X := Inner.X + (Col - 1) * 3;
      if X + 2 > Inner.X + Inner.Width then Break;

      Str(Day:2, DayBuf);

      IsToday := (State.Year = NowY) and (State.Month = NowM) and (Word(Day) = NowD);

      if Word(Day) = State.SelectedDay then
        CellStyle := SelectedStyle
      else if IsToday then
        CellStyle := TodayStyle
      else if (Col >= 6) then
        CellStyle := WeekendStyle
      else
        CellStyle := Style;

      ABuf.SetStringN(X, Y, DayBuf, 2, CellStyle);
      Inc(Day);
    end;
    Inc(Row);
  end;
end;

end.
