unit nextpas.core.time.datetime;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base,
  nextpas.core.time.date,
  nextpas.core.time.timeofday;

type
  TNaiveDateTime = record
  private
    FDate: TDate;
    FNanosOfDay: Int64;
  public
    class function Create(AYear, AMonth, ADay, AHour, AMinute, ASecond: Integer; ANanosecond: Integer = 0): TNaiveDateTime; static;
    class function FromDateAndTime(const ADate: TDate; const ATime: TTimeOfDay): TNaiveDateTime; static; inline;

    function GetDate: TDate; inline;
    function GetTime: TTimeOfDay; inline;
    function GetYear: Integer; inline;
    function GetMonth: Integer; inline;
    function GetDay: Integer; inline;
    function GetHour: Integer; inline;
    function GetMinute: Integer; inline;
    function GetSecond: Integer; inline;
    function GetNanosecond: Integer; inline;

    function AddDays(ADays: Integer): TNaiveDateTime;
    function AddDuration(const ADur: TDuration): TNaiveDateTime;
    function SubDuration(const ADur: TDuration): TNaiveDateTime;

    function DurationUntil(const AOther: TNaiveDateTime): TDuration;
    function DurationSince(const AOther: TNaiveDateTime): TDuration;

    function WithDate(const ANewDate: TDate): TNaiveDateTime; inline;
    function WithTime(const ANewTime: TTimeOfDay): TNaiveDateTime; inline;

    class operator =(const A, B: TNaiveDateTime): Boolean; inline;
    class operator <(const A, B: TNaiveDateTime): Boolean;
    class operator >(const A, B: TNaiveDateTime): Boolean;
    class operator <=(const A, B: TNaiveDateTime): Boolean;
    class operator >=(const A, B: TNaiveDateTime): Boolean;

    function ToISO8601: string;
    function ToString: string;
  end;

implementation

uses
  SysUtils;

const
  NS_PER_SEC_C  = Int64(1000000000);
  NS_PER_MIN_C  = Int64(60) * NS_PER_SEC_C;
  NS_PER_HOUR_C = Int64(3600) * NS_PER_SEC_C;
  NS_PER_DAY_C  = Int64(86400) * NS_PER_SEC_C;

{ TNaiveDateTime }

class function TNaiveDateTime.Create(AYear, AMonth, ADay, AHour, AMinute, ASecond: Integer; ANanosecond: Integer): TNaiveDateTime;
begin
  Result.FDate := TDate.Create(AYear, AMonth, ADay);
  Result.FNanosOfDay := Int64(AHour) * NS_PER_HOUR_C +
                        Int64(AMinute) * NS_PER_MIN_C +
                        Int64(ASecond) * NS_PER_SEC_C +
                        Int64(ANanosecond);
end;

class function TNaiveDateTime.FromDateAndTime(const ADate: TDate; const ATime: TTimeOfDay): TNaiveDateTime;
begin
  Result.FDate := ADate;
  Result.FNanosOfDay := ATime.ToNanoseconds;
end;

function TNaiveDateTime.GetDate: TDate;
begin
  Result := FDate;
end;

function TNaiveDateTime.GetTime: TTimeOfDay;
begin
  Result := TTimeOfDay.FromNanoseconds(FNanosOfDay);
end;

function TNaiveDateTime.GetYear: Integer;
begin
  Result := FDate.GetYear;
end;

function TNaiveDateTime.GetMonth: Integer;
begin
  Result := FDate.GetMonth;
end;

function TNaiveDateTime.GetDay: Integer;
begin
  Result := FDate.GetDay;
end;

function TNaiveDateTime.GetHour: Integer;
begin
  Result := Integer(FNanosOfDay div NS_PER_HOUR_C);
end;

function TNaiveDateTime.GetMinute: Integer;
begin
  Result := Integer((FNanosOfDay mod NS_PER_HOUR_C) div NS_PER_MIN_C);
end;

function TNaiveDateTime.GetSecond: Integer;
begin
  Result := Integer((FNanosOfDay mod NS_PER_MIN_C) div NS_PER_SEC_C);
end;

function TNaiveDateTime.GetNanosecond: Integer;
begin
  Result := Integer(FNanosOfDay mod NS_PER_SEC_C);
end;

function TNaiveDateTime.AddDays(ADays: Integer): TNaiveDateTime;
begin
  Result.FDate := FDate.AddDays(ADays);
  Result.FNanosOfDay := FNanosOfDay;
end;

function TNaiveDateTime.AddDuration(const ADur: TDuration): TNaiveDateTime;
var
  LTotal, LDays, LRem: Int64;
begin
  LTotal := FNanosOfDay + ADur.AsNanoseconds;
  if LTotal >= 0 then
  begin
    LDays := LTotal div NS_PER_DAY_C;
    LRem := LTotal mod NS_PER_DAY_C;
  end
  else
  begin
    LDays := (LTotal - NS_PER_DAY_C + 1) div NS_PER_DAY_C;
    LRem := LTotal - LDays * NS_PER_DAY_C;
  end;
  Result.FDate := FDate.AddDays(Integer(LDays));
  Result.FNanosOfDay := LRem;
end;

function TNaiveDateTime.SubDuration(const ADur: TDuration): TNaiveDateTime;
begin
  Result := AddDuration(ADur.Negate);
end;

function TNaiveDateTime.DurationUntil(const AOther: TNaiveDateTime): TDuration;
var
  LDiffDays: Int64;
  LDiffNs: Int64;
begin
  LDiffDays := Int64(AOther.FDate.ToJulianDay) - Int64(FDate.ToJulianDay);
  LDiffNs := LDiffDays * NS_PER_DAY_C + (AOther.FNanosOfDay - FNanosOfDay);
  Result := TDuration.FromNanoseconds(LDiffNs);
end;

function TNaiveDateTime.DurationSince(const AOther: TNaiveDateTime): TDuration;
begin
  Result := AOther.DurationUntil(Self);
end;

function TNaiveDateTime.WithDate(const ANewDate: TDate): TNaiveDateTime;
begin
  Result.FDate := ANewDate;
  Result.FNanosOfDay := FNanosOfDay;
end;

function TNaiveDateTime.WithTime(const ANewTime: TTimeOfDay): TNaiveDateTime;
begin
  Result.FDate := FDate;
  Result.FNanosOfDay := ANewTime.ToNanoseconds;
end;

class operator TNaiveDateTime.=(const A, B: TNaiveDateTime): Boolean;
begin
  Result := (A.FDate = B.FDate) and (A.FNanosOfDay = B.FNanosOfDay);
end;

class operator TNaiveDateTime.<(const A, B: TNaiveDateTime): Boolean;
begin
  if A.FDate < B.FDate then
    Result := True
  else if A.FDate > B.FDate then
    Result := False
  else
    Result := A.FNanosOfDay < B.FNanosOfDay;
end;

class operator TNaiveDateTime.>(const A, B: TNaiveDateTime): Boolean;
begin
  Result := B < A;
end;

class operator TNaiveDateTime.<=(const A, B: TNaiveDateTime): Boolean;
begin
  Result := not (B < A);
end;

class operator TNaiveDateTime.>=(const A, B: TNaiveDateTime): Boolean;
begin
  Result := not (A < B);
end;

function TNaiveDateTime.ToISO8601: string;
var
  LNs: Integer;
  LFrac: string;
  LI: Integer;
begin
  LNs := GetNanosecond;
  if LNs = 0 then
    Result := Format('%sT%.2d:%.2d:%.2d',
      [FDate.ToISO8601, GetHour, GetMinute, GetSecond])
  else
  begin
    LFrac := Format('%.9d', [LNs]);
    LI := Length(LFrac);
    while (LI > 1) and (LFrac[LI] = '0') do
      Dec(LI);
    LFrac := Copy(LFrac, 1, LI);
    Result := Format('%sT%.2d:%.2d:%.2d.%s',
      [FDate.ToISO8601, GetHour, GetMinute, GetSecond, LFrac]);
  end;
end;

function TNaiveDateTime.ToString: string;
begin
  Result := ToISO8601;
end;

end.
