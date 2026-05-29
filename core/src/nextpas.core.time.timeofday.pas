unit nextpas.core.time.timeofday;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.time.base;

type
  TTimeOfDay = record
  private
    FNanos: Int64;

    class function IsValidTime(AHour, AMinute, ASecond, ANano: Integer): Boolean; static;
    class procedure NanosToComponents(ANanos: Int64; out AHour, AMinute, ASecond, ANano: Integer); static;
  public
    class function Create(AHour, AMinute: Integer; ASecond: Integer = 0; ANanosecond: Integer = 0): TTimeOfDay; static;
    class function TryCreate(AHour, AMinute, ASecond, ANanosecond: Integer; out ATime: TTimeOfDay): Boolean; static;
    class function FromNanoseconds(ANanos: Int64): TTimeOfDay; static;
    class function Midnight: TTimeOfDay; static; inline;
    class function Noon: TTimeOfDay; static; inline;
    class function MinValue: TTimeOfDay; static; inline;
    class function MaxValue: TTimeOfDay; static; inline;

    function ToNanoseconds: Int64; inline;

    function GetHour: Integer; inline;
    function GetMinute: Integer;
    function GetSecond: Integer;
    function GetMillisecond: Integer;
    function GetSubsecondNanos: Integer; inline;

    function AddNanoseconds(ANanos: Int64): TTimeOfDay;
    function AddSeconds(ASeconds: Integer): TTimeOfDay;
    function AddMinutes(AMinutes: Integer): TTimeOfDay;
    function AddHours(AHours: Integer): TTimeOfDay;

    function DurationUntil(const AOther: TTimeOfDay): TDuration;
    function DurationSince(const AOther: TTimeOfDay): TDuration;

    class operator +(const ATime: TTimeOfDay; const ADur: TDuration): TTimeOfDay;
    class operator -(const ATime: TTimeOfDay; const ADur: TDuration): TTimeOfDay;
    class operator -(const A, B: TTimeOfDay): TDuration;
    class operator =(const A, B: TTimeOfDay): Boolean; inline;
    class operator <(const A, B: TTimeOfDay): Boolean; inline;
    class operator >(const A, B: TTimeOfDay): Boolean; inline;
    class operator <=(const A, B: TTimeOfDay): Boolean; inline;
    class operator >=(const A, B: TTimeOfDay): Boolean; inline;

    function ToISO8601: string;
    function ToString: string;
  end;

implementation

uses
  SysUtils;

const
  NS_PER_SEC_L  = Int64(1000000000);
  NS_PER_MIN_L  = Int64(60) * NS_PER_SEC_L;
  NS_PER_HOUR_L = Int64(3600) * NS_PER_SEC_L;
  NS_PER_DAY_L  = Int64(86400) * NS_PER_SEC_L;

{ TTimeOfDay }

class function TTimeOfDay.IsValidTime(AHour, AMinute, ASecond, ANano: Integer): Boolean;
begin
  Result := (AHour >= 0) and (AHour <= 23) and
            (AMinute >= 0) and (AMinute <= 59) and
            (ASecond >= 0) and (ASecond <= 59) and
            (ANano >= 0) and (ANano <= 999999999);
end;

class procedure TTimeOfDay.NanosToComponents(ANanos: Int64; out AHour, AMinute, ASecond, ANano: Integer);
var
  LNs: Int64;
begin
  LNs := ANanos mod NS_PER_DAY_L;
  if LNs < 0 then
    LNs := LNs + NS_PER_DAY_L;

  AHour := Integer(LNs div NS_PER_HOUR_L);
  LNs := LNs mod NS_PER_HOUR_L;
  AMinute := Integer(LNs div NS_PER_MIN_L);
  LNs := LNs mod NS_PER_MIN_L;
  ASecond := Integer(LNs div NS_PER_SEC_L);
  ANano := Integer(LNs mod NS_PER_SEC_L);
end;

class function TTimeOfDay.Create(AHour, AMinute: Integer; ASecond: Integer; ANanosecond: Integer): TTimeOfDay;
begin
  if not IsValidTime(AHour, AMinute, ASecond, ANanosecond) then
    raise Exception.CreateFmt('TTimeOfDay: invalid time %d:%d:%d.%d', [AHour, AMinute, ASecond, ANanosecond]);
  Result.FNanos := Int64(AHour) * NS_PER_HOUR_L +
                   Int64(AMinute) * NS_PER_MIN_L +
                   Int64(ASecond) * NS_PER_SEC_L +
                   ANanosecond;
end;

class function TTimeOfDay.TryCreate(AHour, AMinute, ASecond, ANanosecond: Integer; out ATime: TTimeOfDay): Boolean;
begin
  Result := IsValidTime(AHour, AMinute, ASecond, ANanosecond);
  if Result then
    ATime := Create(AHour, AMinute, ASecond, ANanosecond);
end;

class function TTimeOfDay.FromNanoseconds(ANanos: Int64): TTimeOfDay;
begin
  Result.FNanos := ANanos mod NS_PER_DAY_L;
  if Result.FNanos < 0 then
    Result.FNanos := Result.FNanos + NS_PER_DAY_L;
end;

class function TTimeOfDay.Midnight: TTimeOfDay;
begin
  Result.FNanos := 0;
end;

class function TTimeOfDay.Noon: TTimeOfDay;
begin
  Result.FNanos := 12 * NS_PER_HOUR_L;
end;

class function TTimeOfDay.MinValue: TTimeOfDay;
begin
  Result.FNanos := 0;
end;

class function TTimeOfDay.MaxValue: TTimeOfDay;
begin
  Result.FNanos := NS_PER_DAY_L - 1;
end;

function TTimeOfDay.ToNanoseconds: Int64;
begin
  Result := FNanos;
end;

function TTimeOfDay.GetHour: Integer;
begin
  Result := Integer(FNanos div NS_PER_HOUR_L);
end;

function TTimeOfDay.GetMinute: Integer;
begin
  Result := Integer((FNanos mod NS_PER_HOUR_L) div NS_PER_MIN_L);
end;

function TTimeOfDay.GetSecond: Integer;
begin
  Result := Integer((FNanos mod NS_PER_MIN_L) div NS_PER_SEC_L);
end;

function TTimeOfDay.GetMillisecond: Integer;
begin
  Result := Integer((FNanos mod NS_PER_SEC_L) div 1000000);
end;

function TTimeOfDay.GetSubsecondNanos: Integer;
begin
  Result := Integer(FNanos mod NS_PER_SEC_L);
end;

function TTimeOfDay.AddNanoseconds(ANanos: Int64): TTimeOfDay;
begin
  Result := FromNanoseconds(FNanos + ANanos);
end;

function TTimeOfDay.AddSeconds(ASeconds: Integer): TTimeOfDay;
begin
  Result := FromNanoseconds(FNanos + Int64(ASeconds) * NS_PER_SEC_L);
end;

function TTimeOfDay.AddMinutes(AMinutes: Integer): TTimeOfDay;
begin
  Result := FromNanoseconds(FNanos + Int64(AMinutes) * NS_PER_MIN_L);
end;

function TTimeOfDay.AddHours(AHours: Integer): TTimeOfDay;
begin
  Result := FromNanoseconds(FNanos + Int64(AHours) * NS_PER_HOUR_L);
end;

function TTimeOfDay.DurationUntil(const AOther: TTimeOfDay): TDuration;
var
  LDiff: Int64;
begin
  LDiff := (AOther.FNanos - FNanos) mod NS_PER_DAY_L;
  if LDiff < 0 then
    LDiff := LDiff + NS_PER_DAY_L;
  Result := TDuration.FromNanoseconds(LDiff);
end;

function TTimeOfDay.DurationSince(const AOther: TTimeOfDay): TDuration;
var
  LDiff: Int64;
begin
  LDiff := (FNanos - AOther.FNanos) mod NS_PER_DAY_L;
  if LDiff < 0 then
    LDiff := LDiff + NS_PER_DAY_L;
  Result := TDuration.FromNanoseconds(LDiff);
end;

class operator TTimeOfDay.+(const ATime: TTimeOfDay; const ADur: TDuration): TTimeOfDay;
begin
  Result := ATime.AddNanoseconds(ADur.AsNanoseconds mod NS_PER_DAY_L);
end;

class operator TTimeOfDay.-(const ATime: TTimeOfDay; const ADur: TDuration): TTimeOfDay;
begin
  Result := ATime.AddNanoseconds(-(ADur.AsNanoseconds mod NS_PER_DAY_L));
end;

class operator TTimeOfDay.-(const A, B: TTimeOfDay): TDuration;
begin
  Result := B.DurationUntil(A);
end;

class operator TTimeOfDay.=(const A, B: TTimeOfDay): Boolean;
begin
  Result := A.FNanos = B.FNanos;
end;

class operator TTimeOfDay.<(const A, B: TTimeOfDay): Boolean;
begin
  Result := A.FNanos < B.FNanos;
end;

class operator TTimeOfDay.>(const A, B: TTimeOfDay): Boolean;
begin
  Result := A.FNanos > B.FNanos;
end;

class operator TTimeOfDay.<=(const A, B: TTimeOfDay): Boolean;
begin
  Result := A.FNanos <= B.FNanos;
end;

class operator TTimeOfDay.>=(const A, B: TTimeOfDay): Boolean;
begin
  Result := A.FNanos >= B.FNanos;
end;

function TTimeOfDay.ToISO8601: string;
var
  LHour, LMinute, LSecond, LNano: Integer;
begin
  NanosToComponents(FNanos, LHour, LMinute, LSecond, LNano);
  if LNano = 0 then
    Result := Format('%.2d:%.2d:%.2d', [LHour, LMinute, LSecond])
  else if (LNano mod 1000000) = 0 then
    Result := Format('%.2d:%.2d:%.2d.%.3d', [LHour, LMinute, LSecond, LNano div 1000000])
  else if (LNano mod 1000) = 0 then
    Result := Format('%.2d:%.2d:%.2d.%.6d', [LHour, LMinute, LSecond, LNano div 1000])
  else
    Result := Format('%.2d:%.2d:%.2d.%.9d', [LHour, LMinute, LSecond, LNano]);
end;

function TTimeOfDay.ToString: string;
begin
  Result := ToISO8601;
end;

end.
