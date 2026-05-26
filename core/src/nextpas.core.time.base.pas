unit nextpas.core.time.base;

{$I nextpas.core.settings.inc}

interface

const
  NS_PER_US    = Int64(1000);
  NS_PER_MS    = Int64(1000000);
  NS_PER_SEC   = Int64(1000000000);
  NS_PER_MIN   = Int64(60) * NS_PER_SEC;
  NS_PER_HOUR  = Int64(60) * NS_PER_MIN;
  NS_PER_DAY   = Int64(24) * NS_PER_HOUR;

  DURATION_ZERO = Int64(0);
  DURATION_MAX  = High(Int64);
  DURATION_MIN  = Low(Int64);

type
  {**
   * @desc 时长，内部以纳秒 Int64 存储
   * @note 范围约 +/-292 年，溢出时饱和到极值
   *}
  TDuration = record
  private
    FNs: Int64;
    class function Saturate(const AValue: Int64; const AOverflow: Boolean; const APositive: Boolean): TDuration; static; inline;
  public
    class function Zero: TDuration; static; inline;
    class function MaxValue: TDuration; static; inline;
    class function MinValue: TDuration; static; inline;

    class function FromNanoseconds(const ANs: Int64): TDuration; static; inline;
    class function FromMicroseconds(const AUs: Int64): TDuration; static;
    class function FromMilliseconds(const AMs: Int64): TDuration; static;
    class function FromSeconds(const ASec: Int64): TDuration; static;
    class function FromMinutes(const AMin: Int64): TDuration; static;
    class function FromHours(const AHours: Int64): TDuration; static;
    class function FromDays(const ADays: Int64): TDuration; static;

    function AsNanoseconds: Int64; inline;
    function AsMicroseconds: Int64; inline;
    function AsMilliseconds: Int64; inline;
    function AsSeconds: Int64; inline;
    function AsSecondsF: Double; inline;

    function IsZero: Boolean; inline;
    function IsPositive: Boolean; inline;
    function IsNegative: Boolean; inline;
    function Abs: TDuration; inline;
    function Negate: TDuration; inline;

    function Add(const AOther: TDuration): TDuration;
    function Sub(const AOther: TDuration): TDuration;
    function Mul(const AFactor: Int64): TDuration;
    function DivBy(const ADivisor: Int64): TDuration;

    class operator +(const A, B: TDuration): TDuration; inline;
    class operator -(const A, B: TDuration): TDuration; inline;
    class operator *(const A: TDuration; const B: Int64): TDuration; inline;
    class operator =(const A, B: TDuration): Boolean; inline;
    class operator <(const A, B: TDuration): Boolean; inline;
    class operator >(const A, B: TDuration): Boolean; inline;
    class operator <=(const A, B: TDuration): Boolean; inline;
    class operator >=(const A, B: TDuration): Boolean; inline;

    function ToString: string;
  end;

  {**
   * @desc 单调时间点，内部以纳秒 UInt64 存储
   * @note 用于测量经过时间，不受系统时钟调整影响
   *}
  TInstant = record
  private
    FNs: UInt64;
  public
    class function Now: TInstant; static;
    function Elapsed: TDuration; inline;
    function DurationSince(const AEarlier: TInstant): TDuration;
    function Add(const ADuration: TDuration): TInstant;
    function Sub(const ADuration: TDuration): TInstant;

    class operator -(const A, B: TInstant): TDuration; inline;
    class operator =(const A, B: TInstant): Boolean; inline;
    class operator <(const A, B: TInstant): Boolean; inline;
    class operator >(const A, B: TInstant): Boolean; inline;
  end;

implementation

uses
  SysUtils
  {$IFDEF UNIX}, Linux, UnixType{$ENDIF};

{ TDuration }

class function TDuration.Saturate(const AValue: Int64; const AOverflow: Boolean; const APositive: Boolean): TDuration;
begin
  if AOverflow then
  begin
    if APositive then
      Result.FNs := DURATION_MAX
    else
      Result.FNs := DURATION_MIN;
  end
  else
    Result.FNs := AValue;
end;

class function TDuration.Zero: TDuration;
begin
  Result.FNs := 0;
end;

class function TDuration.MaxValue: TDuration;
begin
  Result.FNs := DURATION_MAX;
end;

class function TDuration.MinValue: TDuration;
begin
  Result.FNs := DURATION_MIN;
end;

class function TDuration.FromNanoseconds(const ANs: Int64): TDuration;
begin
  Result.FNs := ANs;
end;

class function TDuration.FromMicroseconds(const AUs: Int64): TDuration;
var
  LNs: Int64;
  LOverflow: Boolean;
begin
  LOverflow := (AUs > DURATION_MAX div NS_PER_US) or (AUs < DURATION_MIN div NS_PER_US);
  if not LOverflow then
    LNs := AUs * NS_PER_US
  else
    LNs := 0;
  Result := Saturate(LNs, LOverflow, AUs > 0);
end;

class function TDuration.FromMilliseconds(const AMs: Int64): TDuration;
var
  LNs: Int64;
  LOverflow: Boolean;
begin
  LOverflow := (AMs > DURATION_MAX div NS_PER_MS) or (AMs < DURATION_MIN div NS_PER_MS);
  if not LOverflow then
    LNs := AMs * NS_PER_MS
  else
    LNs := 0;
  Result := Saturate(LNs, LOverflow, AMs > 0);
end;

class function TDuration.FromSeconds(const ASec: Int64): TDuration;
var
  LNs: Int64;
  LOverflow: Boolean;
begin
  LOverflow := (ASec > DURATION_MAX div NS_PER_SEC) or (ASec < DURATION_MIN div NS_PER_SEC);
  if not LOverflow then
    LNs := ASec * NS_PER_SEC
  else
    LNs := 0;
  Result := Saturate(LNs, LOverflow, ASec > 0);
end;

class function TDuration.FromMinutes(const AMin: Int64): TDuration;
var
  LNs: Int64;
  LOverflow: Boolean;
begin
  LOverflow := (AMin > DURATION_MAX div NS_PER_MIN) or (AMin < DURATION_MIN div NS_PER_MIN);
  if not LOverflow then
    LNs := AMin * NS_PER_MIN
  else
    LNs := 0;
  Result := Saturate(LNs, LOverflow, AMin > 0);
end;

class function TDuration.FromHours(const AHours: Int64): TDuration;
var
  LNs: Int64;
  LOverflow: Boolean;
begin
  LOverflow := (AHours > DURATION_MAX div NS_PER_HOUR) or (AHours < DURATION_MIN div NS_PER_HOUR);
  if not LOverflow then
    LNs := AHours * NS_PER_HOUR
  else
    LNs := 0;
  Result := Saturate(LNs, LOverflow, AHours > 0);
end;

class function TDuration.FromDays(const ADays: Int64): TDuration;
var
  LNs: Int64;
  LOverflow: Boolean;
begin
  LOverflow := (ADays > DURATION_MAX div NS_PER_DAY) or (ADays < DURATION_MIN div NS_PER_DAY);
  if not LOverflow then
    LNs := ADays * NS_PER_DAY
  else
    LNs := 0;
  Result := Saturate(LNs, LOverflow, ADays > 0);
end;

function TDuration.AsNanoseconds: Int64;
begin
  Result := FNs;
end;

function TDuration.AsMicroseconds: Int64;
begin
  Result := FNs div NS_PER_US;
end;

function TDuration.AsMilliseconds: Int64;
begin
  Result := FNs div NS_PER_MS;
end;

function TDuration.AsSeconds: Int64;
begin
  Result := FNs div NS_PER_SEC;
end;

function TDuration.AsSecondsF: Double;
begin
  Result := FNs / NS_PER_SEC;
end;

function TDuration.IsZero: Boolean;
begin
  Result := FNs = 0;
end;

function TDuration.IsPositive: Boolean;
begin
  Result := FNs > 0;
end;

function TDuration.IsNegative: Boolean;
begin
  Result := FNs < 0;
end;

function TDuration.Abs: TDuration;
begin
  if FNs >= 0 then
    Result.FNs := FNs
  else if FNs = DURATION_MIN then
    Result.FNs := DURATION_MAX
  else
    Result.FNs := -FNs;
end;

function TDuration.Negate: TDuration;
begin
  if FNs = DURATION_MIN then
    Result.FNs := DURATION_MAX
  else
    Result.FNs := -FNs;
end;

function TDuration.Add(const AOther: TDuration): TDuration;
var
  LResult: Int64;
  LOverflow: Boolean;
begin
  LResult := FNs + AOther.FNs;
  LOverflow := ((AOther.FNs > 0) and (LResult < FNs)) or
               ((AOther.FNs < 0) and (LResult > FNs));
  Result := Saturate(LResult, LOverflow, AOther.FNs > 0);
end;

function TDuration.Sub(const AOther: TDuration): TDuration;
var
  LResult: Int64;
  LOverflow: Boolean;
begin
  LResult := FNs - AOther.FNs;
  LOverflow := ((AOther.FNs < 0) and (LResult < FNs)) or
               ((AOther.FNs > 0) and (LResult > FNs));
  Result := Saturate(LResult, LOverflow, AOther.FNs < 0);
end;

function TDuration.Mul(const AFactor: Int64): TDuration;
var
  LOverflow: Boolean;
  LResult: Int64;
begin
  if (AFactor = 0) or (FNs = 0) then
  begin
    Result.FNs := 0;
    Exit;
  end;
  LOverflow := (FNs > 0) and (AFactor > 0) and (FNs > DURATION_MAX div AFactor);
  LOverflow := LOverflow or ((FNs > 0) and (AFactor < 0) and (AFactor < DURATION_MIN div FNs));
  LOverflow := LOverflow or ((FNs < 0) and (AFactor > 0) and (FNs < DURATION_MIN div AFactor));
  LOverflow := LOverflow or ((FNs < 0) and (AFactor < 0) and (FNs < DURATION_MAX div AFactor));
  if not LOverflow then
    LResult := FNs * AFactor
  else
    LResult := 0;
  Result := Saturate(LResult, LOverflow, (FNs > 0) = (AFactor > 0));
end;

function TDuration.DivBy(const ADivisor: Int64): TDuration;
begin
  if ADivisor = 0 then
    raise EDivByZero.Create('TDuration.DivBy: division by zero');
  Result.FNs := FNs div ADivisor;
end;

class operator TDuration.+(const A, B: TDuration): TDuration;
begin
  Result := A.Add(B);
end;

class operator TDuration.-(const A, B: TDuration): TDuration;
begin
  Result := A.Sub(B);
end;

class operator TDuration.*(const A: TDuration; const B: Int64): TDuration;
begin
  Result := A.Mul(B);
end;

class operator TDuration.=(const A, B: TDuration): Boolean;
begin
  Result := A.FNs = B.FNs;
end;

class operator TDuration.<(const A, B: TDuration): Boolean;
begin
  Result := A.FNs < B.FNs;
end;

class operator TDuration.>(const A, B: TDuration): Boolean;
begin
  Result := A.FNs > B.FNs;
end;

class operator TDuration.<=(const A, B: TDuration): Boolean;
begin
  Result := A.FNs <= B.FNs;
end;

class operator TDuration.>=(const A, B: TDuration): Boolean;
begin
  Result := A.FNs >= B.FNs;
end;

function TDuration.ToString: string;
var
  LAbsNs: Int64;
  LNeg: Boolean;
begin
  LNeg := FNs < 0;
  if FNs = DURATION_MIN then
    LAbsNs := DURATION_MAX
  else if LNeg then
    LAbsNs := -FNs
  else
    LAbsNs := FNs;

  if LAbsNs < NS_PER_US then
    Result := IntToStr(FNs) + 'ns'
  else if LAbsNs < NS_PER_MS then
    Result := Format('%.3fus', [LAbsNs / NS_PER_US])
  else if LAbsNs < NS_PER_SEC then
    Result := Format('%.3fms', [LAbsNs / NS_PER_MS])
  else
    Result := Format('%.3fs', [LAbsNs / NS_PER_SEC]);

  if LNeg and (LAbsNs >= NS_PER_US) then
    Result := '-' + Result;
end;

{ TInstant }

class function TInstant.Now: TInstant;
{$IFDEF UNIX}
var
  LTs: TimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @LTs);
  Result.FNs := UInt64(LTs.tv_sec) * UInt64(NS_PER_SEC) + UInt64(LTs.tv_nsec);
end;
{$ELSE}
begin
  Result.FNs := 0;
end;
{$ENDIF}

function TInstant.Elapsed: TDuration;
begin
  Result := TInstant.Now.DurationSince(Self);
end;

function TInstant.DurationSince(const AEarlier: TInstant): TDuration;
begin
  if FNs >= AEarlier.FNs then
    Result := TDuration.FromNanoseconds(Int64(FNs - AEarlier.FNs))
  else
    Result := TDuration.FromNanoseconds(-Int64(AEarlier.FNs - FNs));
end;

function TInstant.Add(const ADuration: TDuration): TInstant;
begin
  if ADuration.AsNanoseconds >= 0 then
    Result.FNs := FNs + UInt64(ADuration.AsNanoseconds)
  else
    Result.FNs := FNs - UInt64(-ADuration.AsNanoseconds);
end;

function TInstant.Sub(const ADuration: TDuration): TInstant;
begin
  if ADuration.AsNanoseconds >= 0 then
    Result.FNs := FNs - UInt64(ADuration.AsNanoseconds)
  else
    Result.FNs := FNs + UInt64(-ADuration.AsNanoseconds);
end;

class operator TInstant.-(const A, B: TInstant): TDuration;
begin
  Result := A.DurationSince(B);
end;

class operator TInstant.=(const A, B: TInstant): Boolean;
begin
  Result := A.FNs = B.FNs;
end;

class operator TInstant.<(const A, B: TInstant): Boolean;
begin
  Result := A.FNs < B.FNs;
end;

class operator TInstant.>(const A, B: TInstant): Boolean;
begin
  Result := A.FNs > B.FNs;
end;

end.
