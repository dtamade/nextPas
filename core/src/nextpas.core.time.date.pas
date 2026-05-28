unit nextpas.core.time.date;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

const
  JULIAN_DAY_EPOCH = 2440588;
  DAYS_PER_WEEK    = 7;
  MONTHS_PER_YEAR  = 12;

type
  TDayOfWeek = (
    dowSunday = 1,
    dowMonday = 2,
    dowTuesday = 3,
    dowWednesday = 4,
    dowThursday = 5,
    dowFriday = 6,
    dowSaturday = 7
  );

  TDate = record
  private
    FJulianDay: Integer;

    class function IsValidDate(AYear, AMonth, ADay: Integer): Boolean; static;
    class function DateToJulianDay(AYear, AMonth, ADay: Integer): Integer; static;
    class procedure JulianDayToDate(AJulianDay: Integer; out AYear, AMonth, ADay: Integer); static;
  public
    class function Create(AYear, AMonth, ADay: Integer): TDate; static;
    class function TryCreate(AYear, AMonth, ADay: Integer; out ADate: TDate): Boolean; static;
    class function FromJulianDay(AJulianDay: Integer): TDate; static; inline;
    class function FromUnixDays(AUnixDays: Integer): TDate; static; inline;
    class function Epoch: TDate; static; inline;
    class function MinValue: TDate; static;
    class function MaxValue: TDate; static;

    function ToJulianDay: Integer; inline;
    function ToUnixDays: Integer; inline;

    function GetYear: Integer;
    function GetMonth: Integer;
    function GetDay: Integer;
    function GetDayOfWeek: TDayOfWeek;
    function GetDayOfYear: Integer;
    function GetQuarter: Integer;

    function IsLeapYear: Boolean;
    function DaysInMonth: Integer;
    function DaysInYear: Integer;
    function IsWeekend: Boolean;

    function AddDays(ADays: Integer): TDate; inline;
    function AddMonths(AMonths: Integer): TDate;
    function AddYears(AYears: Integer): TDate;

    function DaysBetween(const AOther: TDate): Integer; inline;
    function DaysUntil(const AOther: TDate): Integer; inline;

    function WithYear(AYear: Integer): TDate;
    function WithMonth(AMonth: Integer): TDate;
    function WithDay(ADay: Integer): TDate;

    function StartOfMonth: TDate;
    function EndOfMonth: TDate;
    function StartOfYear: TDate;
    function EndOfYear: TDate;

    class operator +(const ADate: TDate; ADays: Integer): TDate; inline;
    class operator -(const ADate: TDate; ADays: Integer): TDate; inline;
    class operator -(const A, B: TDate): Integer; inline;
    class operator =(const A, B: TDate): Boolean; inline;
    class operator <(const A, B: TDate): Boolean; inline;
    class operator >(const A, B: TDate): Boolean; inline;
    class operator <=(const A, B: TDate): Boolean; inline;
    class operator >=(const A, B: TDate): Boolean; inline;

    function ToISO8601: string;
    function ToString: string;
  end;

function IsLeapYearFn(AYear: Integer): Boolean; inline;
function DaysInMonthFn(AYear, AMonth: Integer): Integer;

implementation

uses
  SysUtils;

const
  DAYS_IN_MONTH: array[1..12] of Integer = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

function IsLeapYearFn(AYear: Integer): Boolean;
begin
  Result := (AYear mod 4 = 0) and ((AYear mod 100 <> 0) or (AYear mod 400 = 0));
end;

function DaysInMonthFn(AYear, AMonth: Integer): Integer;
begin
  if AMonth = 2 then
  begin
    if IsLeapYearFn(AYear) then
      Result := 29
    else
      Result := 28;
  end
  else
    Result := DAYS_IN_MONTH[AMonth];
end;

{ TDate }

class function TDate.IsValidDate(AYear, AMonth, ADay: Integer): Boolean;
begin
  Result := (AYear >= 1) and (AYear <= 9999) and
            (AMonth >= 1) and (AMonth <= 12) and
            (ADay >= 1) and (ADay <= DaysInMonthFn(AYear, AMonth));
end;

class function TDate.DateToJulianDay(AYear, AMonth, ADay: Integer): Integer;
var
  LA, LY, LM: Integer;
begin
  LA := (14 - AMonth) div 12;
  LY := AYear + 4800 - LA;
  LM := AMonth + 12 * LA - 3;
  Result := ADay + (153 * LM + 2) div 5 + 365 * LY + LY div 4 - LY div 100 + LY div 400 - 32045;
end;

class procedure TDate.JulianDayToDate(AJulianDay: Integer; out AYear, AMonth, ADay: Integer);
var
  LA, LB, LC, LD, LE, LM: Integer;
begin
  LA := AJulianDay + 32044;
  LB := (4 * LA + 3) div 146097;
  LC := LA - (146097 * LB) div 4;
  LD := (4 * LC + 3) div 1461;
  LE := LC - (1461 * LD) div 4;
  LM := (5 * LE + 2) div 153;

  ADay := LE - (153 * LM + 2) div 5 + 1;
  AMonth := LM + 3 - 12 * (LM div 10);
  AYear := 100 * LB + LD - 4800 + LM div 10;
end;

class function TDate.Create(AYear, AMonth, ADay: Integer): TDate;
begin
  if not IsValidDate(AYear, AMonth, ADay) then
    raise Exception.CreateFmt('TDate: invalid date %d-%d-%d', [AYear, AMonth, ADay]);
  Result.FJulianDay := DateToJulianDay(AYear, AMonth, ADay);
end;

class function TDate.TryCreate(AYear, AMonth, ADay: Integer; out ADate: TDate): Boolean;
begin
  Result := IsValidDate(AYear, AMonth, ADay);
  if Result then
    ADate.FJulianDay := DateToJulianDay(AYear, AMonth, ADay);
end;

class function TDate.FromJulianDay(AJulianDay: Integer): TDate;
begin
  Result.FJulianDay := AJulianDay;
end;

class function TDate.FromUnixDays(AUnixDays: Integer): TDate;
begin
  Result.FJulianDay := JULIAN_DAY_EPOCH + AUnixDays;
end;

class function TDate.Epoch: TDate;
begin
  Result.FJulianDay := JULIAN_DAY_EPOCH;
end;

class function TDate.MinValue: TDate;
begin
  Result := Create(1, 1, 1);
end;

class function TDate.MaxValue: TDate;
begin
  Result := Create(9999, 12, 31);
end;

function TDate.ToJulianDay: Integer;
begin
  Result := FJulianDay;
end;

function TDate.ToUnixDays: Integer;
begin
  Result := FJulianDay - JULIAN_DAY_EPOCH;
end;

function TDate.GetYear: Integer;
var
  LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, Result, LMonth, LDay);
end;

function TDate.GetMonth: Integer;
var
  LYear, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, Result, LDay);
end;

function TDate.GetDay: Integer;
var
  LYear, LMonth: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, Result);
end;

function TDate.GetDayOfWeek: TDayOfWeek;
begin
  Result := TDayOfWeek(((FJulianDay + 1) mod 7) + 1);
end;

function TDate.GetDayOfYear: Integer;
var
  LYear, LMonth, LDay, LI: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := LDay;
  for LI := 1 to LMonth - 1 do
    Result := Result + DaysInMonthFn(LYear, LI);
end;

function TDate.GetQuarter: Integer;
begin
  Result := ((GetMonth - 1) div 3) + 1;
end;

function TDate.IsLeapYear: Boolean;
begin
  Result := IsLeapYearFn(GetYear);
end;

function TDate.DaysInMonth: Integer;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := DaysInMonthFn(LYear, LMonth);
end;

function TDate.DaysInYear: Integer;
begin
  if IsLeapYear then
    Result := 366
  else
    Result := 365;
end;

function TDate.IsWeekend: Boolean;
var
  LDow: TDayOfWeek;
begin
  LDow := GetDayOfWeek;
  Result := (LDow = dowSunday) or (LDow = dowSaturday);
end;

function TDate.AddDays(ADays: Integer): TDate;
begin
  Result.FJulianDay := FJulianDay + ADays;
end;

function TDate.AddMonths(AMonths: Integer): TDate;
var
  LYear, LMonth, LDay, LNewYear, LNewMonth, LMaxDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  LNewMonth := LMonth + AMonths;
  LNewYear := LYear;

  while LNewMonth > 12 do
  begin
    LNewMonth := LNewMonth - 12;
    Inc(LNewYear);
  end;
  while LNewMonth < 1 do
  begin
    LNewMonth := LNewMonth + 12;
    Dec(LNewYear);
  end;

  LMaxDay := DaysInMonthFn(LNewYear, LNewMonth);
  if LDay > LMaxDay then
    LDay := LMaxDay;

  Result := TDate.Create(LNewYear, LNewMonth, LDay);
end;

function TDate.AddYears(AYears: Integer): TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  if (LMonth = 2) and (LDay = 29) and not IsLeapYearFn(LYear + AYears) then
    LDay := 28;
  Result := TDate.Create(LYear + AYears, LMonth, LDay);
end;

function TDate.DaysBetween(const AOther: TDate): Integer;
begin
  Result := System.Abs(FJulianDay - AOther.FJulianDay);
end;

function TDate.DaysUntil(const AOther: TDate): Integer;
begin
  Result := AOther.FJulianDay - FJulianDay;
end;

function TDate.WithYear(AYear: Integer): TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  if (LMonth = 2) and (LDay = 29) and not IsLeapYearFn(AYear) then
    LDay := 28;
  Result := TDate.Create(AYear, LMonth, LDay);
end;

function TDate.WithMonth(AMonth: Integer): TDate;
var
  LYear, LMonth, LDay, LMaxDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  LMaxDay := DaysInMonthFn(LYear, AMonth);
  if LDay > LMaxDay then
    LDay := LMaxDay;
  Result := TDate.Create(LYear, AMonth, LDay);
end;

function TDate.WithDay(ADay: Integer): TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := TDate.Create(LYear, LMonth, ADay);
end;

function TDate.StartOfMonth: TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := TDate.Create(LYear, LMonth, 1);
end;

function TDate.EndOfMonth: TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := TDate.Create(LYear, LMonth, DaysInMonthFn(LYear, LMonth));
end;

function TDate.StartOfYear: TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := TDate.Create(LYear, 1, 1);
end;

function TDate.EndOfYear: TDate;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := TDate.Create(LYear, 12, 31);
end;

class operator TDate.+(const ADate: TDate; ADays: Integer): TDate;
begin
  Result.FJulianDay := ADate.FJulianDay + ADays;
end;

class operator TDate.-(const ADate: TDate; ADays: Integer): TDate;
begin
  Result.FJulianDay := ADate.FJulianDay - ADays;
end;

class operator TDate.-(const A, B: TDate): Integer;
begin
  Result := A.FJulianDay - B.FJulianDay;
end;

class operator TDate.=(const A, B: TDate): Boolean;
begin
  Result := A.FJulianDay = B.FJulianDay;
end;

class operator TDate.<(const A, B: TDate): Boolean;
begin
  Result := A.FJulianDay < B.FJulianDay;
end;

class operator TDate.>(const A, B: TDate): Boolean;
begin
  Result := A.FJulianDay > B.FJulianDay;
end;

class operator TDate.<=(const A, B: TDate): Boolean;
begin
  Result := A.FJulianDay <= B.FJulianDay;
end;

class operator TDate.>=(const A, B: TDate): Boolean;
begin
  Result := A.FJulianDay >= B.FJulianDay;
end;

function TDate.ToISO8601: string;
var
  LYear, LMonth, LDay: Integer;
begin
  JulianDayToDate(FJulianDay, LYear, LMonth, LDay);
  Result := Format('%.4d-%.2d-%.2d', [LYear, LMonth, LDay]);
end;

function TDate.ToString: string;
begin
  Result := ToISO8601;
end;

end.
