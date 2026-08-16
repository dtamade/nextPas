{******************************************************************************
  nextpas.core.lockfree.circuit

  Sliding-window circuit breaker — error-rate tripping + half-open probing.

  State machine:
    csClosed     calls admitted; Record feeds a sliding-window error rate.
                 When the window holds >= MinRequests samples and the error
                 rate exceeds ErrorThreshold, the breaker trips to csOpen.
    csOpen       calls rejected for OpenDurationMs (fail-fast).
    csHalfOpen   lazily entered on the first TryAllow after the open duration
                 lapses; admits at most HalfOpenMaxProbes probe calls;
                 SuccessToClose consecutive probe successes re-close the
                 breaker, any probe failure re-opens it.

  Window: a ring of CIRCUIT_BUCKET_COUNT time buckets covering WindowSizeMs.
  Total/error counts are kept as rolling counters, so evaluation is O(1)
  after a bounded expiry walk (worst case K bucket drops after an idle gap,
  amortized O(1) under steady traffic).

  Concurrency: transitions run under a CAS spin lock (same structure as
  lockfree.ratelimit / lockfree.slidingwindow); State() is a lock-free
  atomic read.

  Time comes from the platform monotonic clock; backward steps are guarded
  and the offending observation is discarded (defensive: monotonic clocks
  do not roll back).

  2026-08-16  B4 backfeed (sliding-window circuit breaker, gateway
  mailGateway888)
******************************************************************************}
unit nextpas.core.lockfree.circuit;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.lockfree.base;

const
  { Ring size of the sliding error-rate window (power of two). }
  CIRCUIT_BUCKET_COUNT = 64;

type
  {** @desc Circuit breaker state. }
  TCircuitState = (
    csClosed,    // healthy: calls admitted, error rate tracked
    csOpen,      // tripped: calls rejected until the open duration elapses
    csHalfOpen   // probing: limited probes admitted to test recovery
  );

  {** @desc Circuit breaker configuration.
    @note ErrorThreshold must be in (0, 1). Rate == threshold does not trip
      (tripping is strictly "exceeds threshold"). }
  TCircuitOptions = record
    { Sliding-window error rate that trips the breaker; e.g. 0.5. }
    ErrorThreshold: Double;
    { Minimum recorded samples per window before the threshold is evaluated
      (guards against tripping on thin traffic). 0 = always evaluate. }
    MinRequests: Int64;
    { Sliding window size in milliseconds. }
    WindowSizeMs: Int64;
    { How long the breaker stays open (ms) before probing in half-open. }
    OpenDurationMs: Int64;
    { Probe quota admitted per half-open round. }
    HalfOpenMaxProbes: Int64;
    { Consecutive half-open probe successes required to re-close. }
    SuccessToClose: Int64;
  end;

  ECircuitError = class(ENextPasError);
  {** @desc Raised by Allow when the breaker rejects the call. }
  ECircuitOpenError = class(ECircuitError);

  {** @desc Sliding-window circuit breaker.
    @details Usage contract for callers:
      - TryAllow = admitted short-circuit check; on True perform the call and
        always follow up with RecordSuccess / RecordFailure (probes in
        half-open are resolved by these records).
      - Allow rejects by raising ECircuitOpenError instead of returning False.
      - TryRecord returns False only when the breaker is already open, which
        happens when a call raced with an open transition; it is a safe no-op
        and never raises (raising here could mask the caller's own error in
        except-handlers).
    @concurrency Thread-safe: TryAllow/Record*/Allow/Reset are serialized by a
    CAS spin lock; State() is a lock-free atomic read.
    @note If half-open probes are admitted but never resolved via Record, the
    breaker idles in half-open until Reset (callers must always Record). }
  TCircuitBreaker = class
  private
    FOptions: TCircuitOptions;
    FWindowNs: UInt64;
    FBucketNs: UInt64;
    FOpenDurationNs: UInt64;
    FStateCode: Int32;            // TCircuitState, atomically read
    FOpenSinceNs: UInt64;
    FProbesUsed: Int64;
    FClosedStreak: Int64;
    FLock: Int32;
    FWindowHead: Integer;         // oldest active bucket index
    FWindowCount: Integer;        // active buckets
    FWindowTotal: Int64;
    FWindowErrors: Int64;
    FBucketStartNs: array[0..CIRCUIT_BUCKET_COUNT - 1] of UInt64;
    FBucketTotal: array[0..CIRCUIT_BUCKET_COUNT - 1] of Int64;
    FBucketErrors: array[0..CIRCUIT_BUCKET_COUNT - 1] of Int64;
    procedure Lock;
    procedure Unlock;
    procedure AdvanceWindow(ANowNs: UInt64);
    procedure AddSample(ANowNs: UInt64; ASucceeded: Boolean);
    procedure Trip(ANowNs: UInt64);
    procedure Reclose;
    procedure ResetWindow;
    function WindowErrorRate(ANowNs: UInt64; out ATotal: Int64): Double;
  protected
    { Time source seam; virtual so tests can inject a deterministic clock.
      Defaults to the platform monotonic clock. }
    function TimeNowNs: UInt64; virtual;
  public
    constructor Create(const AOptions: TCircuitOptions);
    destructor Destroy; override;

    function TryAllow: Boolean;
    procedure Allow;
    function TryRecord(const ASucceeded: Boolean): Boolean;
    procedure RecordSuccess; inline;
    procedure RecordFailure; inline;
    procedure Reset;

    function State: TCircuitState; inline;
    function IsTripped: Boolean; inline;
    function GetOptions: TCircuitOptions; inline;
  end;

{** @desc Sensible defaults: 0.5 error rate, 20 min samples, 60s window,
   30s open, 10 probes, 3 consecutive successes to close. }
function DefaultCircuitOptions: TCircuitOptions;

implementation

uses
  nextpas.core.math,
  nextpas.core.atomic,
  nextpas.core.platform.time;

function TCircuitBreaker.TimeNowNs: UInt64;
begin
  Result := platform_monotonic_ns;
end;

function DefaultCircuitOptions: TCircuitOptions;
begin
  Result := Default(TCircuitOptions);
  Result.ErrorThreshold := 0.5;
  Result.MinRequests := 20;
  Result.WindowSizeMs := 60000;
  Result.OpenDurationMs := 30000;
  Result.HalfOpenMaxProbes := 10;
  Result.SuccessToClose := 3;
end;

constructor TCircuitBreaker.Create(const AOptions: TCircuitOptions);
begin
  if IsNaN(AOptions.ErrorThreshold) or IsInfinite(AOptions.ErrorThreshold) or
     (AOptions.ErrorThreshold <= 0) or (AOptions.ErrorThreshold >= 1.0) then
    raise EArgumentError.Create(
      'TCircuitBreaker: ErrorThreshold must be in (0, 1)');
  if AOptions.MinRequests < 0 then
    raise EArgumentError.Create('TCircuitBreaker: MinRequests must be >= 0');
  if AOptions.WindowSizeMs <= 0 then
    raise EArgumentError.Create('TCircuitBreaker: WindowSizeMs must be > 0');
  if UInt64(AOptions.WindowSizeMs) > High(UInt64) div 1000000 then
    raise EArgumentError.Create('TCircuitBreaker: WindowSizeMs is too large');
  if AOptions.OpenDurationMs < 0 then
    raise EArgumentError.Create('TCircuitBreaker: OpenDurationMs must be >= 0');
  if AOptions.HalfOpenMaxProbes < 1 then
    raise EArgumentError.Create('TCircuitBreaker: HalfOpenMaxProbes must be >= 1');
  if AOptions.SuccessToClose < 1 then
    raise EArgumentError.Create('TCircuitBreaker: SuccessToClose must be >= 1');
  inherited Create;
  FOptions := AOptions;
  FWindowNs := UInt64(AOptions.WindowSizeMs) * 1000000;
  FBucketNs := FWindowNs div CIRCUIT_BUCKET_COUNT;
  if FBucketNs = 0 then
    FBucketNs := 1;
  FOpenDurationNs := UInt64(AOptions.OpenDurationMs) * 1000000;
  FStateCode := Ord(csClosed);
  FOpenSinceNs := 0;
  FProbesUsed := 0;
  FClosedStreak := 0;
  FLock := 0;
  ResetWindow;
end;

destructor TCircuitBreaker.Destroy;
begin
  inherited Destroy;
end;

procedure TCircuitBreaker.ResetWindow;
var
  LI: Integer;
begin
  FWindowHead := 0;
  FWindowCount := 0;
  FWindowTotal := 0;
  FWindowErrors := 0;
  for LI := 0 to CIRCUIT_BUCKET_COUNT - 1 do
  begin
    FBucketStartNs[LI] := 0;
    FBucketTotal[LI] := 0;
    FBucketErrors[LI] := 0;
  end;
end;

procedure TCircuitBreaker.Lock;
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

procedure TCircuitBreaker.Unlock;
begin
  atomic_store(FLock, 0, mo_release);
end;

{ Drop buckets that have aged a full window. }
procedure TCircuitBreaker.AdvanceWindow(ANowNs: UInt64);
begin
  if FWindowCount = 0 then
    Exit;
  if ANowNs < FBucketStartNs[FWindowHead] then
    Exit; { monotonic roll-back guard: keep the window as-is }
  while (FWindowCount > 0) and
        (ANowNs - FBucketStartNs[FWindowHead] >= FWindowNs) do
  begin
    Dec(FWindowTotal, FBucketTotal[FWindowHead]);
    Dec(FWindowErrors, FBucketErrors[FWindowHead]);
    FWindowHead := (FWindowHead + 1) and (CIRCUIT_BUCKET_COUNT - 1);
    Dec(FWindowCount);
  end;
end;

procedure TCircuitBreaker.AddSample(ANowNs: UInt64; ASucceeded: Boolean);
var
  LTail: Integer;
begin
  if (FWindowCount > 0) and (ANowNs < FBucketStartNs[FWindowHead]) then
    Exit; { roll-back: discard the observation }
  AdvanceWindow(ANowNs);
  if FWindowCount = 0 then
  begin
    FWindowHead := 0;
    FBucketStartNs[0] := ANowNs;
    FBucketTotal[0] := 0;
    FBucketErrors[0] := 0;
    FWindowCount := 1;
    LTail := 0;
  end
  else
  begin
    LTail := (FWindowHead + FWindowCount - 1) and (CIRCUIT_BUCKET_COUNT - 1);
    if ANowNs - FBucketStartNs[LTail] >= FBucketNs then
    begin
      if FWindowCount = CIRCUIT_BUCKET_COUNT then
      begin
        { Defensive: expiry above drops heads before a tail-capped bucket is
          needed, so a full ring implies the head already aged past the
          window and this branch is unreachable. It only guards the ring
          against wrapping corruptly. }
        Dec(FWindowTotal, FBucketTotal[FWindowHead]);
        Dec(FWindowErrors, FBucketErrors[FWindowHead]);
        FWindowHead := (FWindowHead + 1) and (CIRCUIT_BUCKET_COUNT - 1);
      end
      else
        Inc(FWindowCount);
      LTail := (FWindowHead + FWindowCount - 1) and (CIRCUIT_BUCKET_COUNT - 1);
      FBucketStartNs[LTail] := ANowNs;
      FBucketTotal[LTail] := 0;
      FBucketErrors[LTail] := 0;
    end;
  end;
  Inc(FWindowTotal);
  Inc(FBucketTotal[LTail]);
  if not ASucceeded then
  begin
    Inc(FWindowErrors);
    Inc(FBucketErrors[LTail]);
  end;
end;

function TCircuitBreaker.WindowErrorRate(ANowNs: UInt64; out ATotal: Int64): Double;
begin
  AdvanceWindow(ANowNs);
  ATotal := FWindowTotal;
  if FWindowTotal <= 0 then
    Result := 0.0
  else
    Result := Double(FWindowErrors) / Double(FWindowTotal);
end;

procedure TCircuitBreaker.Trip(ANowNs: UInt64);
begin
  FStateCode := Ord(csOpen);
  FOpenSinceNs := ANowNs;
  FProbesUsed := 0;
  FClosedStreak := 0;
  ResetWindow;
end;

procedure TCircuitBreaker.Reclose;
begin
  FStateCode := Ord(csClosed);
  FProbesUsed := 0;
  FClosedStreak := 0;
  ResetWindow; { pre-trip samples must not poison the new closed run }
end;

function TCircuitBreaker.TryAllow: Boolean;
var
  LNowNs: UInt64;
  LRate: Double;
  LTotal: Int64;
begin
  Result := False;
  Lock;
  try
    LNowNs := TimeNowNs;
    case TCircuitState(FStateCode) of
      csOpen:
        if (FOpenSinceNs <= LNowNs) and
           (LNowNs - FOpenSinceNs >= FOpenDurationNs) then
        begin
          { Open duration elapsed: enter half-open, admit as first probe. }
          FStateCode := Ord(csHalfOpen);
          FProbesUsed := 1;
          FClosedStreak := 0;
          Result := True;
        end;
      csHalfOpen:
        if FProbesUsed < FOptions.HalfOpenMaxProbes then
        begin
          Inc(FProbesUsed);
          Result := True;
        end;
      csClosed:
        begin
          LRate := WindowErrorRate(LNowNs, LTotal);
          if (LTotal >= FOptions.MinRequests) and
             (LRate > FOptions.ErrorThreshold) then
            Trip(LNowNs)
          else
            Result := True;
        end;
    end;
  finally
    Unlock;
  end;
end;

function TCircuitBreaker.TryRecord(const ASucceeded: Boolean): Boolean;
var
  LNowNs: UInt64;
  LRate: Double;
  LTotal: Int64;
begin
  Result := False;
  Lock;
  try
    LNowNs := TimeNowNs;
    case TCircuitState(FStateCode) of
      csClosed:
        begin
          AddSample(LNowNs, ASucceeded);
          LRate := WindowErrorRate(LNowNs, LTotal);
          if (LTotal >= FOptions.MinRequests) and
             (LRate > FOptions.ErrorThreshold) then
            Trip(LNowNs);
          Result := True;
        end;
      csHalfOpen:
        begin
          if ASucceeded then
          begin
            Inc(FClosedStreak);
            if FClosedStreak >= FOptions.SuccessToClose then
              Reclose;
          end
          else
          begin
            FClosedStreak := 0;
            Trip(LNowNs);
          end;
          Result := True;
        end;
      csOpen:
        { No call was admitted while open; a record here means the call
          raced with an open transition. Safe no-op — never raise, that
          could mask the caller's original error. }
        Result := False;
    end;
  finally
    Unlock;
  end;
end;

procedure TCircuitBreaker.Allow;
begin
  if not TryAllow then
    raise ECircuitOpenError.Create(
      'TCircuitBreaker.Allow: circuit is open, call rejected');
end;

procedure TCircuitBreaker.RecordSuccess;
begin
  TryRecord(True);
end;

procedure TCircuitBreaker.RecordFailure;
begin
  TryRecord(False);
end;

procedure TCircuitBreaker.Reset;
begin
  Lock;
  try
    FStateCode := Ord(csClosed);
    FOpenSinceNs := 0;
    FProbesUsed := 0;
    FClosedStreak := 0;
    ResetWindow;
  finally
    Unlock;
  end;
end;

function TCircuitBreaker.State: TCircuitState; inline;
begin
  Result := TCircuitState(atomic_load(FStateCode, mo_acquire));
end;

function TCircuitBreaker.IsTripped: Boolean; inline;
begin
  Result := State <> csClosed;
end;

function TCircuitBreaker.GetOptions: TCircuitOptions; inline;
begin
  Result := FOptions;
end;

end.