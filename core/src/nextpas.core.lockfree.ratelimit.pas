unit nextpas.core.lockfree.ratelimit;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.lockfree.base;

type
  TLockFreeRateLimiterResult = (rlAllowed, rlRejected, rlClosed);

  {** @desc 并发令牌桶限流器（Token Bucket Rate Limiter）
    @details 以恒定速率生成令牌，请求消耗令牌。
      令牌桶容量 = burst，每秒生成 rate 个令牌。
      适用于：API 限流、请求整形。
  }
  TTokenBucketLimiter = class
  private
    FRate: Double;
    FBurst: Double;
    FTokens: Double;
    FLastRefillNs: Int64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    procedure Refill;
  public
    constructor Create(const ARatePerSecond: Double; const ABurst: Double);
    function TryAcquire: TLockFreeRateLimiterResult;
    function TryAcquireN(const AN: Double): TLockFreeRateLimiterResult;
    procedure Close;
    function IsClosed: Boolean;
    function GetRate: Double;
    function GetBurst: Double;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.time.base;

function GetNowNs: Int64;
begin
  Result := TInstant.Now.Elapsed.AsNanoseconds;
end;

constructor TTokenBucketLimiter.Create(const ARatePerSecond: Double; const ABurst: Double);
begin
  if ARatePerSecond <= 0 then
    raise EArgumentError.Create('TTokenBucketLimiter: rate must be > 0');
  if ABurst <= 0 then
    raise EArgumentError.Create('TTokenBucketLimiter: burst must be > 0');
  inherited Create;
  FRate := ARatePerSecond;
  FBurst := ABurst;
  FTokens := ABurst;
  FLastRefillNs := GetNowNs;
  FLock := 0;
  FClosed := 0;
end;

procedure TTokenBucketLimiter.Lock;
begin
  while AtomicCompareExchange32(FLock, 1, 0, moAcqRel) <> 0 do
    ThreadSwitch;
end;

procedure TTokenBucketLimiter.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TTokenBucketLimiter.Refill;
var
  LNowNs: Int64;
  LElapsed: Double;
  LNewTokens: Double;
begin
  LNowNs := GetNowNs;
  LElapsed := (LNowNs - FLastRefillNs) / 1000000000.0;
  if LElapsed <= 0 then
    Exit;
  LNewTokens := LElapsed * FRate;
  FTokens := FTokens + LNewTokens;
  if FTokens > FBurst then
    FTokens := FBurst;
  FLastRefillNs := LNowNs;
end;

function TTokenBucketLimiter.TryAcquire: TLockFreeRateLimiterResult;
begin
  Result := TryAcquireN(1.0);
end;

function TTokenBucketLimiter.TryAcquireN(const AN: Double): TLockFreeRateLimiterResult;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TTokenBucketLimiter.TryAcquireN: N must be > 0');
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(rlClosed);
  Lock;
  try
    Refill;
    if FTokens >= AN then
    begin
      FTokens := FTokens - AN;
      Result := rlAllowed;
    end
    else
      Result := rlRejected;
  finally
    Unlock;
  end;
end;

procedure TTokenBucketLimiter.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TTokenBucketLimiter.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

function TTokenBucketLimiter.GetRate: Double;
begin
  Result := FRate;
end;

function TTokenBucketLimiter.GetBurst: Double;
begin
  Result := FBurst;
end;

end.
