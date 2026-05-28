program test_date;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.time.base,
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.datetime,
  nextpas.core.time.iso8601;

var
  T: TTestRunner;

{ TDate tests }

procedure TestDateCreate;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 3, 15);
  CheckEqual(2024, LD.GetYear, 'year');
  CheckEqual(3, LD.GetMonth, 'month');
  CheckEqual(15, LD.GetDay, 'day');
end;

procedure TestDateInvalid;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    TDate.Create(2024, 2, 30);
  except
    LCaught := True;
  end;
  Check(LCaught, 'should raise on invalid date');
end;

procedure TestDateTryCreate;
var
  LD: TDate;
begin
  Check(TDate.TryCreate(2024, 2, 29, LD), 'leap year feb 29');
  Check(not TDate.TryCreate(2023, 2, 29, LD), 'non-leap year feb 29');
  Check(not TDate.TryCreate(2024, 13, 1, LD), 'month 13');
  Check(not TDate.TryCreate(2024, 0, 1, LD), 'month 0');
end;

procedure TestDateEpoch;
var
  LD: TDate;
begin
  LD := TDate.Epoch;
  CheckEqual(1970, LD.GetYear, 'epoch year');
  CheckEqual(1, LD.GetMonth, 'epoch month');
  CheckEqual(1, LD.GetDay, 'epoch day');
  CheckEqual(0, LD.ToUnixDays, 'epoch unix days');
end;

procedure TestDateUnixDays;
var
  LD: TDate;
begin
  LD := TDate.FromUnixDays(1);
  CheckEqual(1970, LD.GetYear);
  CheckEqual(1, LD.GetMonth);
  CheckEqual(2, LD.GetDay);

  LD := TDate.Create(2000, 1, 1);
  CheckEqual(10957, LD.ToUnixDays, '2000-01-01 unix days');
end;

procedure TestDateAddDays;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 1, 31);
  LD := LD.AddDays(1);
  CheckEqual(2, LD.GetMonth, 'add 1 day from jan 31');
  CheckEqual(1, LD.GetDay);

  LD := TDate.Create(2024, 2, 28);
  LD := LD.AddDays(1);
  CheckEqual(29, LD.GetDay, 'leap year feb 28 + 1');
end;

procedure TestDateAddMonths;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 1, 31);
  LD := LD.AddMonths(1);
  CheckEqual(2, LD.GetMonth, 'jan 31 + 1 month');
  CheckEqual(29, LD.GetDay, 'clamped to feb 29 in leap year');

  LD := TDate.Create(2023, 1, 31);
  LD := LD.AddMonths(1);
  CheckEqual(28, LD.GetDay, 'clamped to feb 28 in non-leap year');

  LD := TDate.Create(2024, 3, 15);
  LD := LD.AddMonths(-1);
  CheckEqual(2, LD.GetMonth, 'subtract 1 month');
  CheckEqual(15, LD.GetDay);
end;

procedure TestDateAddYears;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 2, 29);
  LD := LD.AddYears(1);
  CheckEqual(2025, LD.GetYear);
  CheckEqual(28, LD.GetDay, 'leap day clamped');
end;

procedure TestDateDayOfWeek;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 1, 1);
  Check(LD.GetDayOfWeek = dowMonday, '2024-01-01 is Monday');

  LD := TDate.Create(2024, 3, 17);
  Check(LD.GetDayOfWeek = dowSunday, '2024-03-17 is Sunday');
end;

procedure TestDateDayOfYear;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 1, 1);
  CheckEqual(1, LD.GetDayOfYear, 'jan 1');

  LD := TDate.Create(2024, 12, 31);
  CheckEqual(366, LD.GetDayOfYear, 'dec 31 leap year');

  LD := TDate.Create(2023, 12, 31);
  CheckEqual(365, LD.GetDayOfYear, 'dec 31 non-leap');
end;

procedure TestDateLeapYear;
begin
  Check(TDate.Create(2024, 1, 1).IsLeapYear, '2024 leap');
  Check(not TDate.Create(2023, 1, 1).IsLeapYear, '2023 not leap');
  Check(TDate.Create(2000, 1, 1).IsLeapYear, '2000 leap');
  Check(not TDate.Create(1900, 1, 1).IsLeapYear, '1900 not leap');
end;

procedure TestDateOperators;
var
  LA, LB: TDate;
begin
  LA := TDate.Create(2024, 3, 15);
  LB := LA + 10;
  CheckEqual(25, LB.GetDay, 'date + 10');

  LB := LA - 15;
  CheckEqual(2, LB.GetMonth, 'date - 15 crosses month');
  CheckEqual(29, LB.GetDay);

  CheckEqual(10, (LA + 10) - LA, 'diff');
  Check(LA < LA + 1);
  Check(LA + 1 > LA);
  Check(LA = LA);
  Check(LA <= LA);
  Check(LA >= LA);
end;

procedure TestDateISO8601;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 3, 5);
  CheckEqual('2024-03-05', LD.ToISO8601, 'format');

  LD := TDate.Create(1, 1, 1);
  CheckEqual('0001-01-01', LD.ToISO8601, 'min date format');
end;

procedure TestDateStartEndOfMonth;
var
  LD: TDate;
begin
  LD := TDate.Create(2024, 3, 15);
  CheckEqual(1, LD.StartOfMonth.GetDay, 'start of month');
  CheckEqual(31, LD.EndOfMonth.GetDay, 'end of march');

  LD := TDate.Create(2024, 2, 15);
  CheckEqual(29, LD.EndOfMonth.GetDay, 'end of feb leap');
end;

{ TTimeOfDay tests }

procedure TestTimeCreate;
var
  LT: TTimeOfDay;
begin
  LT := TTimeOfDay.Create(14, 30, 45, 123000000);
  CheckEqual(14, LT.GetHour, 'hour');
  CheckEqual(30, LT.GetMinute, 'minute');
  CheckEqual(45, LT.GetSecond, 'second');
  CheckEqual(123, LT.GetMillisecond, 'ms');
end;

procedure TestTimeFromNanos;
var
  LT: TTimeOfDay;
begin
  LT := TTimeOfDay.FromNanoseconds(Int64(3600) * 1000000000 + 500000000);
  CheckEqual(1, LT.GetHour, 'hour from nanos');
  CheckEqual(0, LT.GetMinute);
  CheckEqual(0, LT.GetSecond);
  CheckEqual(500000000, LT.GetSubsecondNanos, 'subsec nanos');
end;

procedure TestTimeWrap;
var
  LT: TTimeOfDay;
begin
  LT := TTimeOfDay.Create(23, 0);
  LT := LT.AddHours(2);
  CheckEqual(1, LT.GetHour, 'wraps past midnight');

  LT := TTimeOfDay.Create(1, 0);
  LT := LT.AddHours(-3);
  CheckEqual(22, LT.GetHour, 'wraps before midnight');
end;

procedure TestTimeOperators;
var
  LA, LB: TTimeOfDay;
  LD: TDuration;
begin
  LA := TTimeOfDay.Create(10, 0);
  LB := TTimeOfDay.Create(12, 30);
  LD := LB - LA;
  CheckEqual(Int64(2) * 3600000000000 + Int64(30) * 60000000000, LD.AsNanoseconds, 'time diff');

  Check(LA < LB);
  Check(LB > LA);
  Check(LA = LA);
end;

procedure TestTimeISO8601;
var
  LT: TTimeOfDay;
begin
  LT := TTimeOfDay.Create(9, 5, 3);
  CheckEqual('09:05:03', LT.ToISO8601, 'no frac');

  LT := TTimeOfDay.Create(14, 30, 0, 500000000);
  CheckEqual('14:30:00.500', LT.ToISO8601, 'ms frac');
end;

{ TNaiveDateTime tests }

procedure TestDateTimeCreate;
var
  LDT: TNaiveDateTime;
begin
  LDT := TNaiveDateTime.Create(2024, 6, 15, 14, 30, 45);
  CheckEqual(2024, LDT.GetYear, 'year');
  CheckEqual(6, LDT.GetMonth, 'month');
  CheckEqual(15, LDT.GetDay, 'day');
  CheckEqual(14, LDT.GetHour, 'hour');
  CheckEqual(30, LDT.GetMinute, 'minute');
  CheckEqual(45, LDT.GetSecond, 'second');
end;

procedure TestDateTimeAddDuration;
var
  LDT: TNaiveDateTime;
begin
  LDT := TNaiveDateTime.Create(2024, 1, 1, 23, 30, 0);
  LDT := LDT.AddDuration(TDuration.FromHours(2));
  CheckEqual(2, LDT.GetDay, 'crosses midnight');
  CheckEqual(1, LDT.GetHour);
  CheckEqual(30, LDT.GetMinute);
end;

procedure TestDateTimeSubDuration;
var
  LDT: TNaiveDateTime;
begin
  LDT := TNaiveDateTime.Create(2024, 1, 2, 1, 0, 0);
  LDT := LDT.SubDuration(TDuration.FromHours(3));
  CheckEqual(1, LDT.GetDay, 'crosses back');
  CheckEqual(22, LDT.GetHour);
end;

procedure TestDateTimeDuration;
var
  LA, LB: TNaiveDateTime;
  LD: TDuration;
begin
  LA := TNaiveDateTime.Create(2024, 1, 1, 0, 0, 0);
  LB := TNaiveDateTime.Create(2024, 1, 2, 12, 0, 0);
  LD := LA.DurationUntil(LB);
  CheckEqual(Int64(36) * 3600000000000, LD.AsNanoseconds, '36 hours');
end;

procedure TestDateTimeComparison;
var
  LA, LB: TNaiveDateTime;
begin
  LA := TNaiveDateTime.Create(2024, 1, 1, 10, 0, 0);
  LB := TNaiveDateTime.Create(2024, 1, 1, 10, 0, 1);
  Check(LA < LB);
  Check(LB > LA);
  Check(LA = LA);
  Check(LA <= LB);
  Check(LB >= LA);
end;

procedure TestDateTimeISO8601;
var
  LDT: TNaiveDateTime;
begin
  LDT := TNaiveDateTime.Create(2024, 3, 15, 14, 30, 45);
  CheckEqual('2024-03-15T14:30:45', LDT.ToISO8601, 'no frac');

  LDT := TNaiveDateTime.Create(2024, 3, 15, 14, 30, 45, 123000000);
  CheckEqual('2024-03-15T14:30:45.123', LDT.ToISO8601, 'ms frac');
end;

{ ISO 8601 parse tests }

procedure TestParseDate;
var
  LD: TDate;
begin
  LD := ParseISO8601Date('2024-03-15');
  CheckEqual(2024, LD.GetYear);
  CheckEqual(3, LD.GetMonth);
  CheckEqual(15, LD.GetDay);

  Check(not TryParseISO8601Date('2024-13-01', LD), 'invalid month');
  Check(not TryParseISO8601Date('abc', LD), 'garbage');
end;

procedure TestParseTime;
var
  LT: TTimeOfDay;
begin
  LT := ParseISO8601Time('14:30:45');
  CheckEqual(14, LT.GetHour);
  CheckEqual(30, LT.GetMinute);
  CheckEqual(45, LT.GetSecond);

  LT := ParseISO8601Time('09:05:03.500');
  CheckEqual(500, LT.GetMillisecond, 'ms parse');

  LT := ParseISO8601Time('12:00:00.123456789');
  CheckEqual(123456789, LT.GetSubsecondNanos, 'full nano parse');
end;

procedure TestParseDateTime;
var
  LDT: TNaiveDateTime;
begin
  LDT := ParseISO8601DateTime('2024-06-15T14:30:45');
  CheckEqual(2024, LDT.GetYear);
  CheckEqual(6, LDT.GetMonth);
  CheckEqual(15, LDT.GetDay);
  CheckEqual(14, LDT.GetHour);
  CheckEqual(30, LDT.GetMinute);
  CheckEqual(45, LDT.GetSecond);

  LDT := ParseISO8601DateTime('2024-01-01T00:00:00.5');
  CheckEqual(500000000, LDT.GetNanosecond, 'fractional');

  Check(not TryParseISO8601DateTime('not-a-date', LDT), 'garbage');
end;

begin
  T := TTestRunner.Create('nextpas.core.time.wave2');

  T.Run('Date create', @TestDateCreate);
  T.Run('Date invalid', @TestDateInvalid);
  T.Run('Date try create', @TestDateTryCreate);
  T.Run('Date epoch', @TestDateEpoch);
  T.Run('Date unix days', @TestDateUnixDays);
  T.Run('Date add days', @TestDateAddDays);
  T.Run('Date add months', @TestDateAddMonths);
  T.Run('Date add years', @TestDateAddYears);
  T.Run('Date day of week', @TestDateDayOfWeek);
  T.Run('Date day of year', @TestDateDayOfYear);
  T.Run('Date leap year', @TestDateLeapYear);
  T.Run('Date operators', @TestDateOperators);
  T.Run('Date ISO 8601', @TestDateISO8601);
  T.Run('Date start/end of month', @TestDateStartEndOfMonth);

  T.Run('Time create', @TestTimeCreate);
  T.Run('Time from nanos', @TestTimeFromNanos);
  T.Run('Time wrap', @TestTimeWrap);
  T.Run('Time operators', @TestTimeOperators);
  T.Run('Time ISO 8601', @TestTimeISO8601);

  T.Run('DateTime create', @TestDateTimeCreate);
  T.Run('DateTime add duration', @TestDateTimeAddDuration);
  T.Run('DateTime sub duration', @TestDateTimeSubDuration);
  T.Run('DateTime duration', @TestDateTimeDuration);
  T.Run('DateTime comparison', @TestDateTimeComparison);
  T.Run('DateTime ISO 8601', @TestDateTimeISO8601);

  T.Run('Parse ISO date', @TestParseDate);
  T.Run('Parse ISO time', @TestParseTime);
  T.Run('Parse ISO datetime', @TestParseDateTime);

  T.Summary;
end.