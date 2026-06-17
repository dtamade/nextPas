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
  nextpas.core.tui.widget.intf,
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

  ICalendar = interface(IWidget)
    ['{B5C6D7E8-9F0A-1B2C-3D4E-5F6A7B8C9D0E}']
    function WithStyle(const S: TStyle): ICalendar;
    function WithHeaderStyle(const S: TStyle): ICalendar;
    function WithSelectedStyle(const S: TStyle): ICalendar;
    function WithTodayStyle(const S: TStyle): ICalendar;
    function WithWeekendStyle(const S: TStyle): ICalendar;
    function WithBlock(ABlock: IBlock): ICalendar;
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TCalendarState);
  end;

  TCalendar = class(TInterfacedObject, IWidget, ICalendar)
  private
    FStyle: TStyle;
    FHeaderStyle: TStyle;
    FSelectedStyle: TStyle;
    FTodayStyle: TStyle;
    FWeekendStyle: TStyle;
    FBlock: IBlock;
  public
    class function New: ICalendar; static;

    { ICalendar builder }
    function WithStyle(const S: TStyle): ICalendar;
    function WithHeaderStyle(const S: TStyle): ICalendar;
    function WithSelectedStyle(const S: TStyle): ICalendar;
    function WithTodayStyle(const S: TStyle): ICalendar;
    function WithWeekendStyle(const S: TStyle): ICalendar;
    function WithBlock(ABlock: IBlock): ICalendar;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { ICalendar }
    procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TCalendarState);
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.time.date,
  nextpas.core.time.offsetdatetime;

const
  MonthNames: array[1..12] of string = (
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  );

{ TCalendarState }

class function TCalendarState.Today: TCalendarState;
var
  LToday: TDate;
begin
  LToday := TOffsetDateTime.Now.GetDate;
  Result.Year := Word(LToday.GetYear);
  Result.Month := Word(LToday.GetMonth);
  Result.SelectedDay := Word(LToday.GetDay);
end;

class function TCalendarState.Make(AYear, AMonth, ADay: Word): TCalendarState;
begin
  Result.Year := AYear;
  Result.Month := AMonth;
  Result.SelectedDay := ADay;
end;

function TCalendarState.DaysInMonth: Word;
begin
  Result := Word(nextpas.core.time.date.DaysInMonthFn(Integer(Year), Integer(Month)));
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

class function TCalendar.New: ICalendar;
var
  LObj: TCalendar;
begin
  LObj := TCalendar.Create;
  LObj.FStyle := TStyle.Default;
  LObj.FHeaderStyle := TStyle.Default.WithModifier([mbBold]);
  LObj.FSelectedStyle := TStyle.Default.WithModifier([mbReversed]);
  LObj.FTodayStyle := TStyle.Default.WithFg(TUI_CYAN);
  LObj.FWeekendStyle := TStyle.Default.WithFg(TUI_RED);
  LObj.FBlock := nil;
  Result := LObj;
end;

function TCalendar.WithStyle(const S: TStyle): ICalendar;
begin
  FStyle := S;
  Result := Self;
end;

function TCalendar.WithHeaderStyle(const S: TStyle): ICalendar;
begin
  FHeaderStyle := S;
  Result := Self;
end;

function TCalendar.WithSelectedStyle(const S: TStyle): ICalendar;
begin
  FSelectedStyle := S;
  Result := Self;
end;

function TCalendar.WithTodayStyle(const S: TStyle): ICalendar;
begin
  FTodayStyle := S;
  Result := Self;
end;

function TCalendar.WithWeekendStyle(const S: TStyle): ICalendar;
begin
  FWeekendStyle := S;
  Result := Self;
end;

function TCalendar.WithBlock(ABlock: IBlock): ICalendar;
begin
  FBlock := ABlock;
  Result := Self;
end;

procedure TCalendar.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  { Calendar is stateful-only; Render without state is a no-op. }
end;

procedure TCalendar.RenderStateful(const AArea: TRect; ABuffer: TBuffer; var AState: TCalendarState);
var
  Inner: TRect;
  HeaderStr: AnsiString;
  FirstDow, Days, Day, Col, Row, Y, X: Integer;
  DayBuf: string[2];
  CellStyle: TStyle;
  NowDate: TDate;
  NowY, NowM, NowD: Integer;
  IsToday: Boolean;
  LFirstOfMonth: TDate;
const
  DowHeader = 'Mo Tu We Th Fr Sa Su';
begin
  if AArea.IsEmpty then Exit;

  ABuffer.SetStyle(AArea, FStyle);

  if FBlock <> nil then
  begin
    FBlock.Render(AArea, ABuffer);
    Inner := FBlock.Inner(AArea);
  end
  else
    Inner := AArea;

  if (Inner.Width < 20) or (Inner.Height < 3) then Exit;

  // Header: "January 2026"
  LFirstOfMonth := TDate.Create(Integer(AState.Year), Integer(AState.Month), 1);
  HeaderStr := MonthNames[AState.Month] + ' ' + nextpas.core.text.conv.IntToStr(Int64(AState.Year));
  X := Inner.X + (Inner.Width - Length(HeaderStr)) div 2;
  if X < Inner.X then X := Inner.X;
  ABuffer.SetStringN(X, Inner.Y, HeaderStr, Inner.Width, FHeaderStyle);

  // Day-of-week header
  Y := Inner.Y + 1;
  ABuffer.SetStringN(Inner.X, Y, DowHeader, Inner.Width, FHeaderStyle);

  // Calendar grid
  Days := AState.DaysInMonth;
  FirstDow := Ord(LFirstOfMonth.GetDayOfWeek);
  // Convert: dowSunday=1..dowSaturday=7 → ISO: Monday=1..Sunday=7
  if FirstDow = 1 then FirstDow := 7 else Dec(FirstDow);

  NowDate := TOffsetDateTime.Now.GetDate;
  NowY := NowDate.GetYear;
  NowM := NowDate.GetMonth;
  NowD := NowDate.GetDay;

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

      IsToday := (AState.Year = Word(NowY)) and (AState.Month = Word(NowM)) and (Word(Day) = Word(NowD));

      if Word(Day) = AState.SelectedDay then
        CellStyle := FSelectedStyle
      else if IsToday then
        CellStyle := FTodayStyle
      else if (Col >= 6) then
        CellStyle := FWeekendStyle
      else
        CellStyle := FStyle;

      ABuffer.SetStringN(X, Y, DayBuf, 2, CellStyle);
      Inc(Day);
    end;
    Inc(Row);
  end;
end;

end.
