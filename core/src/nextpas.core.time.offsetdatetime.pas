unit nextpas.core.time.offsetdatetime;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.date,
  nextpas.core.time.timeofday,
  nextpas.core.time.datetime,
  nextpas.core.time.timezone;

type
  TOffsetDateTime = record
  private
    FDateTime: TNaiveDateTime;
    FOffset: TUtcOffset;
  public
    class function Now: TOffsetDateTime; static;
    class function NowUtc: TOffsetDateTime; static;
    class function Create(const ADateTime: TNaiveDateTime;
      const AOffset: TUtcOffset): TOffsetDateTime; static;
    class function FromUnixSeconds(const ASec: Int64): TOffsetDateTime; static;
    class function FromUnixMillis(const AMs: Int64): TOffsetDateTime; static;
    class function FromUnixNanos(const ANs: Int64): TOffsetDateTime; static;

    function GetDateTime: TNaiveDateTime; inline;
    function GetOffset: TUtcOffset; inline;
    function GetDate: TDate; inline;
    function GetTime: TTimeOfDay; inline;
    function GetYear: Integer; inline;
    function GetMonth: Integer; inline;
    function GetDay: Integer; inline;
    function GetHour: Integer; inline;
    function GetMinute: Integer; inline;
    function GetSecond: Integer; inline;
    function GetNanosecond: Integer; inline;

    function ToUtc: TOffsetDateTime;
    function ToOffset(const ANewOffset: TUtcOffset): TOffsetDateTime;
    function ToUnixSeconds: Int64;
    function ToUnixMillis: Int64;
    function ToUnixNanos: Int64;

    function Add(const ADuration: TDuration): TOffsetDateTime;
    function Sub(const ADuration: TDuration): TOffsetDateTime;
    function DurationUntil(const AOther: TOffsetDateTime): TDuration;

    function ToISO8601: string;
    function ToString: string;

    class operator =(const A, B: TOffsetDateTime): Boolean;
    class operator <(const A, B: TOffsetDateTime): Boolean;
    class operator >(const A, B: TOffsetDateTime): Boolean;
    class operator <=(const A, B: TOffsetDateTime): Boolean;
    class operator >=(const A, B: TOffsetDateTime): Boolean;
  end;

implementation

uses
  nextpas.core.platform.time;

const
  NS_PER_SEC = Int64(1000000000);
  NS_PER_MS  = Int64(1000000);

function UnixNsToNaiveDateTime(ANs: Int64): TNaiveDateTime;
var
  LDays: Integer;
  LDayNs: Int64;
begin
  LDays := Integer(ANs div (NS_PER_SEC * 86400));
  LDayNs := ANs mod (NS_PER_SEC * 86400);
  if LDayNs < 0 then
  begin
    Dec(LDays);
    Inc(LDayNs, NS_PER_SEC * 86400);
  end;
  Result := TNaiveDateTime.FromDateAndTime(
    TDate.FromUnixDays(LDays),
    TTimeOfDay.FromNanoseconds(LDayNs));
end;

function NaiveDateTimeToUnixNs(const ADT: TNaiveDateTime): Int64;
begin
  Result := Int64(ADT.GetDate.ToUnixDays) * NS_PER_SEC * 86400
    + ADT.GetTime.ToNanoseconds;
end;

class function TOffsetDateTime.Now: TOffsetDateTime;
var
  LUtcNs: Int64;
  LOffset: TUtcOffset;
begin
  LUtcNs := Int64(platform_realtime_ns);
  LOffset := TUtcOffset.Local;
  Result.FOffset := LOffset;
  Result.FDateTime := UnixNsToNaiveDateTime(LUtcNs + Int64(LOffset.TotalSeconds) * NS_PER_SEC);
end;

class function TOffsetDateTime.NowUtc: TOffsetDateTime;
begin
  Result.FOffset := TUtcOffset.UTC;
  Result.FDateTime := UnixNsToNaiveDateTime(Int64(platform_realtime_ns));
end;

class function TOffsetDateTime.Create(const ADateTime: TNaiveDateTime;
  const AOffset: TUtcOffset): TOffsetDateTime;
begin
  Result.FDateTime := ADateTime;
  Result.FOffset := AOffset;
end;

class function TOffsetDateTime.FromUnixSeconds(const ASec: Int64): TOffsetDateTime;
begin
  Result.FOffset := TUtcOffset.UTC;
  Result.FDateTime := UnixNsToNaiveDateTime(ASec * NS_PER_SEC);
end;

class function TOffsetDateTime.FromUnixMillis(const AMs: Int64): TOffsetDateTime;
begin
  Result.FOffset := TUtcOffset.UTC;
  Result.FDateTime := UnixNsToNaiveDateTime(AMs * NS_PER_MS);
end;

class function TOffsetDateTime.FromUnixNanos(const ANs: Int64): TOffsetDateTime;
begin
  Result.FOffset := TUtcOffset.UTC;
  Result.FDateTime := UnixNsToNaiveDateTime(ANs);
end;

function TOffsetDateTime.GetDateTime: TNaiveDateTime;
begin
  Result := FDateTime;
end;

function TOffsetDateTime.GetOffset: TUtcOffset;
begin
  Result := FOffset;
end;

function TOffsetDateTime.GetDate: TDate;
begin
  Result := FDateTime.GetDate;
end;

function TOffsetDateTime.GetTime: TTimeOfDay;
begin
  Result := FDateTime.GetTime;
end;

function TOffsetDateTime.GetYear: Integer;
begin
  Result := FDateTime.GetYear;
end;

function TOffsetDateTime.GetMonth: Integer;
begin
  Result := FDateTime.GetMonth;
end;

function TOffsetDateTime.GetDay: Integer;
begin
  Result := FDateTime.GetDay;
end;

function TOffsetDateTime.GetHour: Integer;
begin
  Result := FDateTime.GetHour;
end;

function TOffsetDateTime.GetMinute: Integer;
begin
  Result := FDateTime.GetMinute;
end;

function TOffsetDateTime.GetSecond: Integer;
begin
  Result := FDateTime.GetSecond;
end;

function TOffsetDateTime.GetNanosecond: Integer;
begin
  Result := FDateTime.GetNanosecond;
end;

function TOffsetDateTime.ToUnixNanos: Int64;
begin
  Result := NaiveDateTimeToUnixNs(FDateTime) - Int64(FOffset.TotalSeconds) * NS_PER_SEC;
end;

function TOffsetDateTime.ToUnixSeconds: Int64;
begin
  Result := ToUnixNanos div NS_PER_SEC;
end;

function TOffsetDateTime.ToUnixMillis: Int64;
begin
  Result := ToUnixNanos div NS_PER_MS;
end;

function TOffsetDateTime.ToUtc: TOffsetDateTime;
begin
  Result.FOffset := TUtcOffset.UTC;
  Result.FDateTime := UnixNsToNaiveDateTime(ToUnixNanos);
end;

function TOffsetDateTime.ToOffset(const ANewOffset: TUtcOffset): TOffsetDateTime;
var
  LUtcNs: Int64;
begin
  LUtcNs := ToUnixNanos;
  Result.FOffset := ANewOffset;
  Result.FDateTime := UnixNsToNaiveDateTime(LUtcNs + Int64(ANewOffset.TotalSeconds) * NS_PER_SEC);
end;

function TOffsetDateTime.Add(const ADuration: TDuration): TOffsetDateTime;
begin
  Result.FOffset := FOffset;
  Result.FDateTime := FDateTime.AddDuration(ADuration);
end;

function TOffsetDateTime.Sub(const ADuration: TDuration): TOffsetDateTime;
begin
  Result.FOffset := FOffset;
  Result.FDateTime := FDateTime.SubDuration(ADuration);
end;

function TOffsetDateTime.DurationUntil(const AOther: TOffsetDateTime): TDuration;
begin
  Result := TDuration.FromNanoseconds(AOther.ToUnixNanos - Self.ToUnixNanos);
end;

function TOffsetDateTime.ToISO8601: string;
begin
  Result := FDateTime.ToISO8601 + FOffset.ToString;
end;

function TOffsetDateTime.ToString: string;
begin
  Result := ToISO8601;
end;

class operator TOffsetDateTime.=(const A, B: TOffsetDateTime): Boolean;
begin
  Result := A.ToUnixNanos = B.ToUnixNanos;
end;

class operator TOffsetDateTime.<(const A, B: TOffsetDateTime): Boolean;
begin
  Result := A.ToUnixNanos < B.ToUnixNanos;
end;

class operator TOffsetDateTime.>(const A, B: TOffsetDateTime): Boolean;
begin
  Result := A.ToUnixNanos > B.ToUnixNanos;
end;

class operator TOffsetDateTime.<=(const A, B: TOffsetDateTime): Boolean;
begin
  Result := A.ToUnixNanos <= B.ToUnixNanos;
end;

class operator TOffsetDateTime.>=(const A, B: TOffsetDateTime): Boolean;
begin
  Result := A.ToUnixNanos >= B.ToUnixNanos;
end;

end.
