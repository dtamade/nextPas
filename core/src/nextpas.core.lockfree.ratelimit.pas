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
    FLastRefillNs: UInt64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    procedure Refill;
  public
    constructor Create(const ARatePerSecond: Double; const ABurst: Double);
    destructor Destroy; override;
    function TryAcquire: TLockFreeRateLimiterResult;
    function TryAcquireN(const AN: Double): TLockFreeRateLimiterResult;
    procedure Close;
    function IsClosed: Boolean; inline;
    function GetRate: Double; inline;
    function GetBurst: Double; inline;
  end;

implementation

uses
  nextpas.core.math,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.time;

function GetNowNs: UInt64;
begin
  Result := platform_monotonic_ns;
end;

constructor TTokenBucketLimiter.Create(const ARatePerSecond: Double; const ABurst: Double);
begin
  if IsNaN(ARatePerSecond) or IsInfinite(ARatePerSecond) or
     (ARatePerSecond <= 0) then
    raise EArgumentError.Create('TTokenBucketLimiter: rate must be > 0');
  if IsNaN(ABurst) or IsInfinite(ABurst) or (ABurst <= 0) then
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
var
  LSpin: Integer;
  LCasExpected: Int32;
begin
  LSpin := 0;
  while True do
  begin
    LCasExpected := 0;
    if atomic_compare_exchange_strong(FLock, LCasExpected, 1, mo_acq_rel, mo_acquire) then
      Break;
    Inc(LSpin);
    if LSpin > LOCKFREE_SPIN_COUNT then
    begin
      if LSpin > LOCKFREE_SPIN_COUNT + LOCKFREE_YIELD_COUNT then
        LSpin := LOCKFREE_SPIN_COUNT;
      ThreadSwitch;
    end
    else
      CpuPause;
  end;
end;

procedure TTokenBucketLimiter.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TTokenBucketLimiter.Refill;
var
  LNowNs: UInt64;
  LElapsedNs: UInt64;
  LElapsed: Double;
  LMissingTokens: Double;
begin
  LNowNs := GetNowNs;
  if LNowNs <= FLastRefillNs then
    Exit;
  LElapsedNs := LNowNs - FLastRefillNs;
  FLastRefillNs := LNowNs;
  if FTokens >= FBurst then
    Exit;
  LElapsed := Double(LElapsedNs) / 1000000000.0;
  LMissingTokens := FBurst - FTokens;
  if LElapsed >= LMissingTokens / FRate then
    FTokens := FBurst;
  if FTokens < FBurst then
    FTokens := FTokens + LElapsed * FRate;
end;

function TTokenBucketLimiter.TryAcquire: TLockFreeRateLimiterResult;
begin
  Result := TryAcquireN(1.0);
end;

function TTokenBucketLimiter.TryAcquireN(const AN: Double): TLockFreeRateLimiterResult;
begin
  if IsNaN(AN) or IsInfinite(AN) or (AN <= 0) then
    raise EArgumentError.Create('TTokenBucketLimiter.TryAcquireN: N must be > 0');
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(rlClosed);
  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(rlClosed);
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
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

destructor TTokenBucketLimiter.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TTokenBucketLimiter.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

function TTokenBucketLimiter.GetRate: Double; inline;
begin
  Result := FRate;
end;

function TTokenBucketLimiter.GetBurst: Double; inline;
begin
  Result := FBurst;
end;

end.
