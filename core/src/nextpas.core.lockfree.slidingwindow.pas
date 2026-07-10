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
    FLimit: Int64;
    FCurrentCount: Int64;
    FPreviousCount: Int64;
    FWindowStartNs: Int64;
    FLock: Int32;
    FClosed: Int32;
    procedure Lock;
    procedure Unlock;
    procedure AdvanceWindow(ANowNs: Int64);
  public
    constructor Create(const ALimitPerWindow: Int64; const AWindowMs: Int64);
    function TryAcquire: TSlidingWindowResult;
    function TryAcquireN(AN: Int64): TSlidingWindowResult;
    function GetEffectiveCount: Double;
    function GetLimit: Int64;
    function GetWindowMs: Int64;
    procedure Close;
    function IsClosed: Boolean;
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

constructor TSlidingWindowLimiter.Create(const ALimitPerWindow: Int64; const AWindowMs: Int64);
begin
  if ALimitPerWindow <= 0 then
    raise EArgumentError.Create('TSlidingWindowLimiter: limit must be > 0');
  if AWindowMs <= 0 then
    raise EArgumentError.Create('TSlidingWindowLimiter: window must be > 0');
  inherited Create;
  FWindowMs := AWindowMs;
  FLimit := ALimitPerWindow;
  FCurrentCount := 0;
  FPreviousCount := 0;
  FWindowStartNs := GetNowNs;
  FLock := 0;
  FClosed := 0;
end;

procedure TSlidingWindowLimiter.Lock;
begin
  while AtomicCompareExchange32(FLock, 1, 0, moAcqRel) <> 0 do
    ThreadSwitch;
end;

procedure TSlidingWindowLimiter.Unlock;
begin
  AtomicStore32(FLock, 0, moRelease);
end;

procedure TSlidingWindowLimiter.AdvanceWindow(ANowNs: Int64);
var
  LWindowNs: Int64;
  LElapsedWindows: Int64;
begin
  LWindowNs := FWindowMs * 1000000;
  if LWindowNs <= 0 then
    Exit;
  if ANowNs <= FWindowStartNs then
    Exit;
  LElapsedWindows := (ANowNs - FWindowStartNs) div LWindowNs;
  if LElapsedWindows <= 0 then
    Exit;
  if LElapsedWindows = 1 then
    FPreviousCount := FCurrentCount;
  if LElapsedWindows > 1 then
    FPreviousCount := 0;
  FCurrentCount := 0;
  Inc(FWindowStartNs, LElapsedWindows * LWindowNs);
end;

function TSlidingWindowLimiter.GetEffectiveCount: Double;
var
  LNowNs: Int64;
  LWindowNs: Int64;
  LElapsed: Double;
  LWeight: Double;
begin
  Lock;
  try
    LNowNs := GetNowNs;
    AdvanceWindow(LNowNs);
    LWindowNs := FWindowMs * 1000000;
    LElapsed := (LNowNs - FWindowStartNs) / LWindowNs;
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
  LNowNs: Int64;
  LEffective: Double;
  LWindowNs: Int64;
  LElapsed: Double;
begin
  if AN <= 0 then
    raise EArgumentError.Create('TSlidingWindowLimiter.TryAcquireN: N must be > 0');
  if AtomicLoad32(FClosed, moAcquire) <> 0 then
    Exit(swClosed);
  Lock;
  try
    LNowNs := GetNowNs;
    AdvanceWindow(LNowNs);
    LWindowNs := FWindowMs * 1000000;
    LElapsed := (LNowNs - FWindowStartNs) / LWindowNs;
    if LElapsed > 1.0 then
      LElapsed := 1.0;
    if LElapsed < 0.0 then
      LElapsed := 0.0;
    LEffective := FCurrentCount + FPreviousCount * (1.0 - LElapsed);
    if LEffective + AN <= FLimit then
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

function TSlidingWindowLimiter.GetLimit: Int64;
begin
  Result := FLimit;
end;

function TSlidingWindowLimiter.GetWindowMs: Int64;
begin
  Result := FWindowMs;
end;

procedure TSlidingWindowLimiter.Close;
begin
  AtomicStore32(FClosed, 1, moRelease);
end;

function TSlidingWindowLimiter.IsClosed: Boolean;
begin
  Result := AtomicLoad32(FClosed, moAcquire) <> 0;
end;

end.
