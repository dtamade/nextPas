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
  nextpas.core.time.period;

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

function ParseISO8601Date(const AStr: string): nextpas.core.time.date.TDate; inline;
function TryParseISO8601Date(const AStr: string; out ADate: nextpas.core.time.date.TDate): Boolean; inline;
function ParseISO8601Time(const AStr: string): nextpas.core.time.timeofday.TTimeOfDay; inline;
function TryParseISO8601Time(const AStr: string; out ATime: nextpas.core.time.timeofday.TTimeOfDay): Boolean; inline;
function ParseISO8601DateTime(const AStr: string): nextpas.core.time.datetime.TNaiveDateTime; inline;
function TryParseISO8601DateTime(const AStr: string; out ADT: nextpas.core.time.datetime.TNaiveDateTime): Boolean; inline;

implementation

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

end.
