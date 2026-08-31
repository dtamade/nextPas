{******************************************************************************
  nextpas.core.lockfree.slidingwindow

  Sliding Window Counter Rate Limiter — smooth rate limiting.

  Design:
  - Tracks count in current window and previous window
  - Calculates weighted count based on position in current window
  - weight = (windowSize - elapsed) / windowSize
  - effectiveCount = currentCount + previousCount * weight
  - More accurate than fixed window, smoother than sliding window log
  - Concurrent-safe: CAS spin lock

  Theory: Cloudflare "How we built rate limiting capable of handling millions
  of requests per minute" — sliding window counter algorithm.

  2026-07-06  Phase 11
******************************************************************************}
{$mode ObjFPC}{$H+}{$J-}
unit nextpas.core.lockfree.slidingwindow;

interface

uses
  nextpas.core.lockfree.base;

type
  TSlidingWindowResult = (swAllowed, swRejected, swClosed);

  {** @desc 滑动窗口计数器限流器
    @details 结合当前窗口和上一个窗口的加权计数。
      比固定窗口更准确，比滑动窗口日志更高效。 }
  TSlidingWindowLimiter = class
  private
    FWindowMs: Int64;
    FWindowNs: UInt64;
    FLimit: Int64;
    FCurrentCount: Int64;
    FPreviousCount: Int64;
    FWindowStartNs: UInt64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    procedure AdvanceWindow(ANowNs: UInt64);
  public
    constructor Create(const ALimitPerWindow: Int64; const AWindowMs: Int64);
    destructor Destroy; override;
    function TryAcquire: TSlidingWindowResult;
    function TryAcquireN(AN: Int64): TSlidingWindowResult;
    function GetEffectiveCount: Double;
    function GetLimit: Int64; inline;
    function GetWindowMs: Int64; inline;
    procedure Close;
    function IsClosed: Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.time;

function GetNowNs: UInt64;
begin
  Result := platform_monotonic_ns;
end;

constructor TSlidingWindowLimiter.Create(const ALimitPerWindow: Int64; const AWindowMs: Int64);
begin
  if ALimitPerWindow <= 0 then
    raise EArgumentError.Create('TSlidingWindowLimiter: limit must be > 0');
  if AWindowMs <= 0 then
    raise EArgumentError.Create('TSlidingWindowLimiter: window must be > 0');
  if UInt64(AWindowMs) > High(UInt64) div 1000000 then
    raise EArgumentError.Create('TSlidingWindowLimiter: window is too large');
  inherited Create;
  FWindowMs := AWindowMs;
  FWindowNs := UInt64(AWindowMs) * 1000000;
  FLimit := ALimitPerWindow;
  FCurrentCount := 0;
  FPreviousCount := 0;
  FWindowStartNs := GetNowNs;
  FLock := 0;
  FClosed := 0;
end;

procedure TSlidingWindowLimiter.Lock;
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

procedure TSlidingWindowLimiter.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

procedure TSlidingWindowLimiter.AdvanceWindow(ANowNs: UInt64);
var
  LElapsedWindows: UInt64;
begin
  if ANowNs <= FWindowStartNs then
    Exit;
  LElapsedWindows := (ANowNs - FWindowStartNs) div FWindowNs;
  if LElapsedWindows = 0 then
    Exit;
  if LElapsedWindows = 1 then
    FPreviousCount := FCurrentCount;
  if LElapsedWindows > 1 then
    FPreviousCount := 0;
  FCurrentCount := 0;
  FWindowStartNs := FWindowStartNs + LElapsedWindows * FWindowNs;
end;

function TSlidingWindowLimiter.GetEffectiveCount: Double;
var
  LNowNs: UInt64;
  LElapsed: Double;
  LWeight: Double;
begin
  Lock;
  try
    LNowNs := GetNowNs;
    AdvanceWindow(LNowNs);
    LElapsed := Double(LNowNs - FWindowStartNs) / Double(FWindowNs);
    if LElapsed > 1.0 then
      LElapsed := 1.0;
    if LElapsed < 0.0 then
      LElapsed := 0.0;
    LWeight := 1.0 - LElapsed;
    Result := FCurrentCount + FPreviousCount * LWeight;
  finally
    Unlock;
  end;
end;

function TSlidingWindowLimiter.TryAcquire: TSlidingWindowResult;
begin
  Result := TryAcquireN(1);
end;

function TSlidingWindowLimiter.TryAcquireN(AN: Int64): TSlidingWindowResult;
var
  LNowNs: UInt64;
  LEffective: Double;
  LElapsed: Double;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TSlidingWindowLimiter.TryAcquireN: N must be > 0');
  if atomic_load(FClosed, mo_acquire) <> 0 then
    Exit(swClosed);
  Lock;
  try
    if atomic_load(FClosed, mo_acquire) <> 0 then
      Exit(swClosed);
    if AN > FLimit then
      Exit(swRejected);
    LNowNs := GetNowNs;
    AdvanceWindow(LNowNs);
    LElapsed := Double(LNowNs - FWindowStartNs) / Double(FWindowNs);
    if LElapsed > 1.0 then
      LElapsed := 1.0;
    if LElapsed < 0.0 then
      LElapsed := 0.0;
    LEffective := FCurrentCount + FPreviousCount * (1.0 - LElapsed);
    if (AN <= FLimit - FCurrentCount) and (LEffective + AN <= FLimit) then
    begin
      FCurrentCount := FCurrentCount + AN;
      Result := swAllowed;
    end
    else
      Result := swRejected;
  finally
    Unlock;
  end;
end;

function TSlidingWindowLimiter.GetLimit: Int64; inline;
begin
  Result := FLimit;
end;

function TSlidingWindowLimiter.GetWindowMs: Int64; inline;
begin
  Result := FWindowMs;
end;

procedure TSlidingWindowLimiter.Close;
begin
  Lock;
  try
    atomic_store(FClosed, 1, mo_release);
  finally
    Unlock;
  end;
end;

destructor TSlidingWindowLimiter.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TSlidingWindowLimiter.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

end.
