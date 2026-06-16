unit nextpas.core.time;
{**
 * @desc 时间门面：TDuration、TInstant、TDeadline、DateTime、Timer。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.stopwatch,
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.datetime,
  nextpas.core.time.iso8601,
  nextpas.core.time.deadline,
  nextpas.core.time.sleep,
  nextpas.core.time.timer,
  nextpas.core.time.ticker,
  nextpas.core.time.period,
  nextpas.core.time.format;

type
  TDuration = nextpas.core.time.base.TDuration;
  TInstant = nextpas.core.time.base.TInstant;
  TStopwatch = nextpas.core.time.stopwatch.TStopwatch;
  TDate = nextpas.core.time.date.TDate;
  TDayOfWeek = nextpas.core.time.date.TDayOfWeek;
  TTimeOfDay = nextpas.core.time.timeofday.TTimeOfDay;
  TNaiveDateTime = nextpas.core.time.datetime.TNaiveDateTime;
  TDeadlineKind = nextpas.core.time.deadline.TDeadlineKind;
  TDeadline = nextpas.core.time.deadline.TDeadline;
  TSleep = nextpas.core.time.sleep.TSleep;
  TTimerState = nextpas.core.time.timer.TTimerState;
  TTimer = nextpas.core.time.timer.TTimer;
  TTick = nextpas.core.time.ticker.TTick;
  TTicker = nextpas.core.time.ticker.TTicker;
  TPeriod = nextpas.core.time.period.TPeriod;

function DateTimeNow: TDateTime;
function DateTimeUtcNow: TDateTime;
function DateTimeSecondsBetween(const ANewer, AOlder: TDateTime): Int64;
function DateTimeMillisecondsBetween(const ANewer, AOlder: TDateTime): Int64;
function DateTimeAddSeconds(const AValue: TDateTime; const ASeconds: Int64): TDateTime;
function ParseISO8601Date(const AStr: string): nextpas.core.time.date.TDate; inline;
function TryParseISO8601Date(const AStr: string; out ADate: nextpas.core.time.date.TDate): Boolean; inline;
function ParseISO8601Time(const AStr: string): nextpas.core.time.timeofday.TTimeOfDay; inline;
function TryParseISO8601Time(const AStr: string; out ATime: nextpas.core.time.timeofday.TTimeOfDay): Boolean; inline;
function ParseISO8601DateTime(const AStr: string): nextpas.core.time.datetime.TNaiveDateTime; inline;
function TryParseISO8601DateTime(const AStr: string; out ADT: nextpas.core.time.datetime.TNaiveDateTime): Boolean; inline;
function FormatDateTime(const APattern: string; const ADT: TDateTime): string; inline;
function DateTimeToStr(const ADT: TDateTime): string; inline;
function DateToStr(const ADT: TDateTime): string; inline;
function EncodeDate(const AYear, AMonth, ADay: Word): TDateTime;
function EncodeTime(const AHour, AMinute, ASecond, AMSec: Word): TDateTime;
procedure DecodeDate(const AValue: TDateTime; out AYear, AMonth, ADay: Word);
procedure DecodeTime(const AValue: TDateTime; out AHour, AMinute, ASecond, AMSec: Word);

implementation

uses
  nextpas.core.platform.time;

const
  UNIX_EPOCH_TDATETIME = 25569.0;

function DateTimeNow: TDateTime;
var
  LNowNs: Int64;
  LDays: Int64;
  LDayNs: Int64;
begin
  LNowNs := Int64(nextpas.core.platform.time.platform_realtime_ns) +
    Int64(nextpas.core.platform.time.platform_utc_offset_seconds) * NS_PER_SEC;
  LDays := LNowNs div NS_PER_DAY;
  LDayNs := LNowNs mod NS_PER_DAY;
  if LDayNs < 0 then
  begin
    Dec(LDays);
    Inc(LDayNs, NS_PER_DAY);
  end;

  Result := UNIX_EPOCH_TDATETIME + LDays + (LDayNs / Double(NS_PER_DAY));
end;

function DateTimeUtcNow: TDateTime;
var
  LNowNs: Int64;
  LDays: Int64;
  LDayNs: Int64;
begin
  LNowNs := Int64(nextpas.core.platform.time.platform_realtime_ns);
  LDays := LNowNs div NS_PER_DAY;
  LDayNs := LNowNs mod NS_PER_DAY;
  if LDayNs < 0 then
  begin
    Dec(LDays);
    Inc(LDayNs, NS_PER_DAY);
  end;

  Result := UNIX_EPOCH_TDATETIME + LDays + (LDayNs / Double(NS_PER_DAY));
end;

function DateTimeSecondsBetween(const ANewer, AOlder: TDateTime): Int64;
begin
  Result := Trunc((ANewer - AOlder) * 86400.0);
end;

function DateTimeMillisecondsBetween(const ANewer, AOlder: TDateTime): Int64;
begin
  Result := Trunc((ANewer - AOlder) * 86400000.0);
end;

function DateTimeAddSeconds(const AValue: TDateTime; const ASeconds: Int64): TDateTime;
begin
  Result := AValue + (ASeconds / 86400.0);
end;

function ParseISO8601Date(const AStr: string): nextpas.core.time.date.TDate;
begin
  Result := nextpas.core.time.iso8601.ParseISO8601Date(AStr);
end;

function TryParseISO8601Date(const AStr: string; out ADate: nextpas.core.time.date.TDate): Boolean;
begin
  Result := nextpas.core.time.iso8601.TryParseISO8601Date(AStr, ADate);
end;

function ParseISO8601Time(const AStr: string): nextpas.core.time.timeofday.TTimeOfDay;
begin
  Result := nextpas.core.time.iso8601.ParseISO8601Time(AStr);
end;

function TryParseISO8601Time(const AStr: string; out ATime: nextpas.core.time.timeofday.TTimeOfDay): Boolean;
begin
  Result := nextpas.core.time.iso8601.TryParseISO8601Time(AStr, ATime);
end;

function ParseISO8601DateTime(const AStr: string): nextpas.core.time.datetime.TNaiveDateTime;
begin
  Result := nextpas.core.time.iso8601.ParseISO8601DateTime(AStr);
end;

function TryParseISO8601DateTime(const AStr: string; out ADT: nextpas.core.time.datetime.TNaiveDateTime): Boolean;
begin
  Result := nextpas.core.time.iso8601.TryParseISO8601DateTime(AStr, ADT);
end;

function FormatDateTime(const APattern: string; const ADT: TDateTime): string;
begin
  Result := nextpas.core.time.format.FormatDateTime(APattern, ADT);
end;

function DateTimeToStr(const ADT: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ADT);
end;

function DateToStr(const ADT: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd', ADT);
end;

function EncodeDate(const AYear, AMonth, ADay: Word): TDateTime;
const
  CUM_DAYS: array[1..12] of Word = (
    0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334
  );
var
  LDays: Int64;
begin
  // Days from year 1 to year-1 (inclusive), then add months + day
  LDays := Int64(AYear - 1) * 365
         + (Int64(AYear - 1) div 4)
         - (Int64(AYear - 1) div 100)
         + (Int64(AYear - 1) div 400)
         + CUM_DAYS[AMonth]
         + ADay;
  // Leap year adjustment: Feb 29 counts if month > Feb
  if (AMonth > 2) and
     (((AYear mod 4 = 0) and (AYear mod 100 <> 0)) or (AYear mod 400 = 0)) then
    Inc(LDays);
  // TDateTime epoch: 1899-12-30 = day 693594 from year 1
  Result := LDays - 693594;
end;

function EncodeTime(const AHour, AMinute, ASecond, AMSec: Word): TDateTime;
begin
  Result := (AHour * 3600000.0 + AMinute * 60000.0 + ASecond * 1000.0 + AMSec) / 86400000.0;
end;

procedure DecodeDate(const AValue: TDateTime; out AYear, AMonth, ADay: Word);
var
  LDays: Int64;
  LJD, LL, LN, LI, LJ: Int64;
begin
  LDays := Trunc(AValue);
  // Meeus JD-to-Gregorian. OLE epoch noon JDN = 2415019.
  LJD := LDays + 2415019;
  LL := LJD + 68569;
  LN := (4 * LL) div 146097;
  LL := LL - (146097 * LN + 3) div 4;
  LI := (4000 * (LL + 1)) div 1461001;
  LL := LL - (1461 * LI) div 4 + 31;
  LJ := (80 * LL) div 2447;
  AYear  := Word(100 * (LN - 49) + LI + LJ div 11);
  AMonth := Word(LJ + 2 - 12 * (LJ div 11));
  ADay   := Word(LL - (2447 * LJ) div 80);
end;

procedure DecodeTime(const AValue: TDateTime; out AHour, AMinute, ASecond, AMSec: Word);
var
  LDayNs: Int64;
begin
  LDayNs := Round(Frac(AValue) * 864000000000.0);
  if LDayNs < 0 then
    LDayNs := LDayNs + 864000000000;
  AHour   := Word(LDayNs div 3600000000000);
  LDayNs  := LDayNs mod 3600000000000;
  AMinute := Word(LDayNs div 60000000000);
  LDayNs  := LDayNs mod 60000000000;
  ASecond := Word(LDayNs div 1000000000);
  AMSec   := Word((LDayNs mod 1000000000) div 1000000);
end;

end.
