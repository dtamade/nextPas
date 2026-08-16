program test_lockfree_circuit;

{ Sliding-window circuit breaker tests (nextpas.core.lockfree.circuit, B4). }

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.math.scalar,
  nextpas.core.platform.thread,
  nextpas.core.atomic,
  nextpas.core.lockfree.circuit,
  nextpas.core.errors,
  nextpas.core.test;

type
  { Deterministic clock for timing-sensitive tests. }
  TTestClock = class
  private
    FNowNs: UInt64;
  public
    constructor Create(AStartMs: UInt64);
    procedure AdvanceMs(const AMilliseconds: UInt64);
    procedure SetMs(const AMilliseconds: UInt64);
    function NowNs: UInt64; inline;
  end;

  { Circuit with injectable time source. }
  TInjectableCircuit = class(TCircuitBreaker)
  private
    FClock: TTestClock;
  protected
    function TimeNowNs: UInt64; override;
  public
    constructor Create(const AOptions: TCircuitOptions; AClock: TTestClock);
  end;

const
  THREADS = 8;
  OPS_PER_THREAD = 2000;

var
  GFailAllowed: Int32 = 0;
  GFailRejected: Int32 = 0;
  GOkAllowed: Int32 = 0;
  GOkRejected: Int32 = 0;
  GMixAllowed: Int32 = 0;
  GMixRejected: Int32 = 0;

function MakeOptions(const AErrorThreshold: Double; const AMinRequests: Int64;
  const AWindowMs: Int64; const AOpenMs: Int64; const AProbes: Int64;
  const AClose: Int64): TCircuitOptions;
begin
  Result := Default(TCircuitOptions);
  Result.ErrorThreshold := AErrorThreshold;
  Result.MinRequests := AMinRequests;
  Result.WindowSizeMs := AWindowMs;
  Result.OpenDurationMs := AOpenMs;
  Result.HalfOpenMaxProbes := AProbes;
  Result.SuccessToClose := AClose;
end;

{ Returns True when TCircuitBreaker.Create rejects with EArgumentError. }
function ExpectCreateRejected(const AOpts: TCircuitOptions): Boolean;
var
  LBreaker: TCircuitBreaker;
begin
  Result := False;
  try
    LBreaker := TCircuitBreaker.Create(AOpts);
    LBreaker.Free;
  except
    on E: EArgumentError do
      Result := True;
  end;
end;

procedure TestOptionsValidation;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
begin
  LOpts := DefaultCircuitOptions;

  LOpts.ErrorThreshold := 0.0;
  Check(ExpectCreateRejected(LOpts), 'threshold 0 must be rejected');
  LOpts.ErrorThreshold := 1.0;
  Check(ExpectCreateRejected(LOpts), 'threshold 1.0 must be rejected');
  LOpts.ErrorThreshold := 1.5;
  Check(ExpectCreateRejected(LOpts), 'threshold > 1 must be rejected');
  LOpts.ErrorThreshold := NaN;
  Check(ExpectCreateRejected(LOpts), 'threshold NaN must be rejected');
  LOpts.ErrorThreshold := Infinity;
  Check(ExpectCreateRejected(LOpts), 'threshold Infinity must be rejected');

  LOpts := DefaultCircuitOptions;
  LOpts.MinRequests := -1;
  Check(ExpectCreateRejected(LOpts), 'MinRequests < 0 must be rejected');
  LOpts := DefaultCircuitOptions;
  LOpts.WindowSizeMs := 0;
  Check(ExpectCreateRejected(LOpts), 'zero window must be rejected');
  LOpts := DefaultCircuitOptions;
  LOpts.OpenDurationMs := -1;
  Check(ExpectCreateRejected(LOpts), 'OpenDurationMs < 0 must be rejected');
  LOpts := DefaultCircuitOptions;
  LOpts.HalfOpenMaxProbes := 0;
  Check(ExpectCreateRejected(LOpts), 'zero probes must be rejected');
  LOpts := DefaultCircuitOptions;
  LOpts.SuccessToClose := 0;
  Check(ExpectCreateRejected(LOpts), 'zero SuccessToClose must be rejected');

  { Degenerate-but-legal extremes are accepted. }
  LOpts := DefaultCircuitOptions;
  LOpts.OpenDurationMs := 0;
  LOpts.HalfOpenMaxProbes := 1;
  LOpts.SuccessToClose := 1;
  Check(not ExpectCreateRejected(LOpts), 'legal extremes must be accepted');

  LOpts := DefaultCircuitOptions;
  Check(LOpts.ErrorThreshold = 0.5, 'default threshold');
  CheckEqual(Int64(20), Int64(LOpts.MinRequests), 'default MinRequests');
  CheckEqual(Int64(60000), Int64(LOpts.WindowSizeMs), 'default window');
  CheckEqual(Int64(30000), Int64(LOpts.OpenDurationMs), 'default open duration');
  CheckEqual(Int64(10), Int64(LOpts.HalfOpenMaxProbes), 'default probes');
  CheckEqual(Int64(3), Int64(LOpts.SuccessToClose), 'default close streak');

  LBreaker := TCircuitBreaker.Create(DefaultCircuitOptions);
  try
    Check(not LBreaker.IsTripped, 'fresh breaker must be closed');
  finally
    LBreaker.Free;
  end;
end;

procedure TestErrorRateTripsOpen;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
  LI: Integer;
  LRaised: Boolean;
begin
  LOpts := MakeOptions(0.5, 4, 60000, 60000, 3, 2);
  LBreaker := TCircuitBreaker.Create(LOpts);
  try
    for LI := 1 to 10 do
      LBreaker.RecordSuccess;
    for LI := 1 to 10 do
      LBreaker.RecordFailure;
    { Exactly at threshold (10/20 = 0.5): must NOT trip. }
    Check(LBreaker.State = csClosed, 'at-threshold must stay closed');
    Check(LBreaker.TryAllow, 'at-threshold must allow');
    Check(not LBreaker.IsTripped, 'at-threshold must not trip');

    LBreaker.RecordFailure; { 11/21 = 0.524 > 0.5 }
    Check(LBreaker.State = csOpen, 'above-threshold must open');
    Check(not LBreaker.TryAllow, 'open must reject');
    Check(LBreaker.IsTripped, 'open must be tripped');

    LRaised := False;
    try
      LBreaker.Allow;
    except
      on E: ECircuitOpenError do
        LRaised := True;
    end;
    Check(LRaised, 'Allow must raise ECircuitOpenError when open');

    Check(not LBreaker.TryRecord(True), 'TryRecord must be a no-op while open');
    Check(not LBreaker.TryRecord(False), 'TryRecord failure must be a no-op while open');
  finally
    LBreaker.Free;
  end;
end;

procedure TestFewRequestsDoNotTrip;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
  LI: Integer;
begin
  { Thin traffic: 100% errors but far below MinRequests — must stay closed. }
  LOpts := MakeOptions(0.5, 100, 60000, 60000, 1, 1);
  LBreaker := TCircuitBreaker.Create(LOpts);
  try
    for LI := 1 to 50 do
      LBreaker.RecordFailure;
    Check(LBreaker.State = csClosed, 'thin window must stay closed');
    Check(LBreaker.TryAllow, 'thin window must allow');
    for LI := 51 to 99 do
      LBreaker.RecordFailure;
    Check(LBreaker.TryAllow, '99 < MinRequests(100) must still allow');
  finally
    LBreaker.Free;
  end;
end;

procedure TestRateAtThresholdDoesNotTrip;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
  LI: Integer;
begin
  LOpts := MakeOptions(0.5, 4, 60000, 60000, 3, 2);
  LBreaker := TCircuitBreaker.Create(LOpts);
  try
    for LI := 1 to 10 do
      LBreaker.RecordSuccess;
    for LI := 1 to 10 do
      LBreaker.RecordFailure;
    Check(LBreaker.State = csClosed, 'exactly 0.5 must not trip');
    Check(LBreaker.TryAllow, 'exactly 0.5 must allow');
  finally
    LBreaker.Free;
  end;
end;

procedure TestHalfOpenProbeQuota;
var
  LOpts: TCircuitOptions;
  LClock: TTestClock;
  LBreaker: TInjectableCircuit;
begin
  LOpts := MakeOptions(0.5, 1, 60000, 40, 3, 100);
  LClock := TTestClock.Create(1000);
  LBreaker := TInjectableCircuit.Create(LOpts, LClock);
  try
    LBreaker.RecordFailure; { 1/1 = 100% with MinRequests=1 -> open }
    Check(LBreaker.State = csOpen, 'first failure must open');
    Check(not LBreaker.TryAllow, 'open must reject within duration');

    LClock.AdvanceMs(40); { open duration elapsed -> half-open, first probe }
    Check(LBreaker.TryAllow, 'elapsed open must admit first probe');
    Check(LBreaker.State = csHalfOpen, 'must enter half-open');
    Check(LBreaker.TryRecord(True), 'probe success must be accepted');

    Check(LBreaker.TryAllow, 'second probe admitted');
    Check(LBreaker.TryRecord(True), 'second probe success accepted');
    Check(LBreaker.TryAllow, 'third probe admitted');
    Check(LBreaker.TryRecord(True), 'third probe success accepted');
    Check(not LBreaker.TryAllow, 'quota exhausted: fourth probe rejected');
    Check(not LBreaker.TryAllow, 'quota stays exhausted');
  finally
    LBreaker.Free;
    LClock.Free;
  end;
end;

procedure TestHalfOpenSuccessRecloses;
var
  LOpts: TCircuitOptions;
  LClock: TTestClock;
  LBreaker: TInjectableCircuit;
begin
  LOpts := MakeOptions(0.5, 1, 60000, 40, 10, 2);
  LClock := TTestClock.Create(1000);
  LBreaker := TInjectableCircuit.Create(LOpts, LClock);
  try
    LBreaker.RecordFailure;
    Check(not LBreaker.TryAllow, 'open must reject before duration');

    LClock.AdvanceMs(40);
    Check(LBreaker.TryAllow, 'first probe admitted');
    Check(LBreaker.TryRecord(True), 'streak 1 accepted');
    Check(LBreaker.TryAllow, 'second probe admitted');
    Check(LBreaker.TryRecord(True), 'streak 2 reaches SuccessToClose');
    Check(LBreaker.State = csClosed, 'streak must reclose the breaker');
    Check(LBreaker.TryAllow, 'reclosed breaker must allow');

    { A fresh post-reclose failure trips again (window restarted empty). }
    LBreaker.RecordFailure;
    Check(LBreaker.State = csOpen, 'fresh failure must re-open');
    Check(not LBreaker.TryAllow, 're-opened breaker must reject');
  finally
    LBreaker.Free;
    LClock.Free;
  end;
end;

procedure TestHalfOpenFailureReopens;
var
  LOpts: TCircuitOptions;
  LClock: TTestClock;
  LBreaker: TInjectableCircuit;
begin
  LOpts := MakeOptions(0.5, 1, 60000, 40, 10, 2);
  LClock := TTestClock.Create(1000);
  LBreaker := TInjectableCircuit.Create(LOpts, LClock);
  try
    LBreaker.RecordFailure;
    Check(not LBreaker.TryAllow, 'must reject while open');

    LClock.AdvanceMs(40);
    Check(LBreaker.TryAllow, 'probe admitted in half-open');
    Check(LBreaker.TryRecord(False), 'probe failure accepted');
    Check(LBreaker.State = csOpen, 'probe failure must re-open');
    Check(not LBreaker.TryAllow, 're-opened breaker rejects immediately');

    LClock.AdvanceMs(40);
    Check(LBreaker.TryAllow, 'second half-open round admits a probe');
  finally
    LBreaker.Free;
    LClock.Free;
  end;
end;

procedure TestWindowSlides;
var
  LOpts: TCircuitOptions;
  LClock: TTestClock;
  LBreaker: TInjectableCircuit;
  LI: Integer;
begin
  LOpts := MakeOptions(0.5, 3, 60, 60000, 10, 2);
  LClock := TTestClock.Create(1000);
  LBreaker := TInjectableCircuit.Create(LOpts, LClock);
  try
    { 6 success + 4 failure = 40%: closed. }
    for LI := 1 to 6 do
      LBreaker.RecordSuccess;
    for LI := 1 to 4 do
      LBreaker.RecordFailure;
    Check(LBreaker.State = csClosed, '40% must stay closed');
    Check(LBreaker.TryAllow, '40% must allow');

    { Let the whole window elapse: the old failure burst ages out. }
    LClock.AdvanceMs(60);
    for LI := 1 to 2 do
      LBreaker.RecordFailure;
    Check(LBreaker.TryAllow, '2/2 but total(2) < MinRequests(3): must allow');
    Check(LBreaker.State = csClosed, 'thin fresh window must stay closed');

    { One more success: 3 fresh samples with 2 errors = 66% > 50% -> trips. }
    LBreaker.RecordSuccess;
    Check(LBreaker.State = csOpen, 'fresh window crossing threshold must open');
    Check(not LBreaker.TryAllow, 'opened window must reject');
  finally
    LBreaker.Free;
    LClock.Free;
  end;
end;

procedure TestExactOpenDurationBoundary;
var
  LOpts: TCircuitOptions;
  LClock: TTestClock;
  LBreaker: TInjectableCircuit;
begin
  LOpts := MakeOptions(0.5, 1, 60000, 40, 1, 1);
  LClock := TTestClock.Create(1000);
  LBreaker := TInjectableCircuit.Create(LOpts, LClock);
  try
    LBreaker.RecordFailure;
    LClock.AdvanceMs(39);
    Check(not LBreaker.TryAllow, '39ms < 40ms must stay open');
    LClock.AdvanceMs(1);
    Check(LBreaker.TryAllow, 'exactly 40ms must open half-open probing');
  finally
    LBreaker.Free;
    LClock.Free;
  end;
end;

procedure TestTimeRollbackGuard;
var
  LOpts: TCircuitOptions;
  LClock: TTestClock;
  LBreaker: TInjectableCircuit;
  LI: Integer;
begin
  LOpts := MakeOptions(0.5, 5, 100, 60000, 10, 2);
  LClock := TTestClock.Create(1000);
  LBreaker := TInjectableCircuit.Create(LOpts, LClock);
  try
    for LI := 1 to 2 do
      LBreaker.RecordFailure;
    for LI := 1 to 2 do
      LBreaker.RecordSuccess;
    Check(LBreaker.TryAllow, '4 samples below MinRequests(5): must allow');

    { Clock steps backward: the observation must be discarded, not corrupt
      the window (no crash, state stays consistent). }
    LClock.SetMs(400);
    LBreaker.RecordFailure;
    Check(LBreaker.TryAllow, 'roll-back sample must be discarded');

    { Forward again, past the whole window: aged samples drop, window restarts. }
    LClock.SetMs(2000);
    LBreaker.RecordFailure;
    Check(LBreaker.TryAllow, 'aged-out window restarts below MinRequests');
    for LI := 1 to 4 do
      LBreaker.RecordFailure; { 5/5 = 100%, MinRequests(5) reached }
    Check(LBreaker.State = csOpen, 'fresh full-failure window must open');
    Check(not LBreaker.TryAllow, 'opened breaker must reject');
  finally
    LBreaker.Free;
    LClock.Free;
  end;
end;

procedure TestRecordInOpenIsNoop;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
begin
  LOpts := MakeOptions(0.5, 1, 60000, 60000, 10, 2);
  LBreaker := TCircuitBreaker.Create(LOpts);
  try
    LBreaker.RecordFailure;
    Check(LBreaker.State = csOpen, 'must be open');
    Check(not LBreaker.TryRecord(True), 'success record while open must no-op');
    Check(not LBreaker.TryRecord(False), 'failure record while open must no-op');
    LBreaker.RecordSuccess; { must not raise nor reclose }
    Check(LBreaker.State = csOpen, 'must stay open after stray records');
    LBreaker.RecordFailure;
    Check(LBreaker.State = csOpen, 'must stay open');
  finally
    LBreaker.Free;
  end;
end;

procedure TestReset;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
begin
  LOpts := MakeOptions(0.5, 1, 60000, 60000, 10, 2);
  LBreaker := TCircuitBreaker.Create(LOpts);
  try
    LBreaker.RecordFailure;
    Check(LBreaker.State = csOpen, 'must open');
    Check(not LBreaker.TryAllow, 'must reject while open');

    LBreaker.Reset;
    Check(LBreaker.State = csClosed, 'reset must close');
    Check(LBreaker.TryAllow, 'reset must allow');

    LBreaker.RecordFailure;
    Check(LBreaker.State = csOpen, 'must trip again after reset');
    Check(not LBreaker.TryAllow, 'must reject after re-trip');
  finally
    LBreaker.Free;
  end;
end;

procedure TestRealClockAging;
var
  LOpts: TCircuitOptions;
  LBreaker: TCircuitBreaker;
  LI: Integer;
begin
  { End-to-end check through the real monotonic clock with a short window. }
  LOpts := MakeOptions(0.5, 3, 40, 60000, 10, 2);
  LBreaker := TCircuitBreaker.Create(LOpts);
  try
    for LI := 1 to 3 do
    begin
      LBreaker.RecordSuccess;
      LBreaker.RecordFailure;
    end;
    Check(LBreaker.TryAllow, '50% exactly must not trip');
    Check(LBreaker.State = csClosed, 'must stay closed at 50%');

    platform_thread_sleep_ms(80); { window (40ms) fully elapses }
    for LI := 1 to 2 do
      LBreaker.RecordFailure;
    Check(LBreaker.TryAllow, 'aged window + 2 failures below MinRequests(3)');
    Check(LBreaker.State = csClosed, 'must stay closed on thin window');

    LBreaker.RecordSuccess; { 3 fresh samples, 2 errors -> > 50% }
    Check(LBreaker.State = csOpen, 'real-clock fresh window must open');
    Check(not LBreaker.TryAllow, 'must reject after real-clock trip');
  finally
    LBreaker.Free;
  end;
end;

type
  PCircuitCtx = ^TCircuitCtx;
  TCircuitCtx = record
    Breaker: TCircuitBreaker;
    Mode: Integer; { 0 = all fail, 1 = all succeed, 2 = alternate }
    Ops: Integer;
  end;

function CircuitWorker(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PCircuitCtx;
  LI: Integer;
begin
  Result := nil;
  LCtx := PCircuitCtx(AArg);
  for LI := 1 to LCtx^.Ops do
  begin
    if LCtx^.Breaker.TryAllow then
    begin
      case LCtx^.Mode of
        0:
          begin
            atomic_fetch_add(GFailAllowed, 1);
            LCtx^.Breaker.RecordFailure;
          end;
        1:
          begin
            atomic_fetch_add(GOkAllowed, 1);
            LCtx^.Breaker.RecordSuccess;
          end;
      else
        atomic_fetch_add(GMixAllowed, 1);
        if (LI and 3) = 0 then
          LCtx^.Breaker.RecordSuccess
        else
          LCtx^.Breaker.RecordFailure;
      end;
    end
    else
      case LCtx^.Mode of
        0: atomic_fetch_add(GFailRejected, 1);
        1: atomic_fetch_add(GOkRejected, 1);
      else
        atomic_fetch_add(GMixRejected, 1);
      end;
  end;
end;

procedure RunConcurrent(const ABreaker: TCircuitBreaker; const AMode: Integer;
  const AThreads, AOps: Integer);
var
  LHandles: array[0..THREADS - 1] of TPlatformThreadHandle;
  LCtx: TCircuitCtx;
  LRetVal: Pointer;
  LResult: Int32;
  LI: Integer;
begin
  LCtx.Breaker := ABreaker;
  LCtx.Mode := AMode;
  LCtx.Ops := AOps;
  for LI := 0 to AThreads - 1 do
  begin
    LResult := platform_thread_create(LHandles[LI], @CircuitWorker, @LCtx);
    CheckEqual(Int64(0), Int64(LResult), 'thread create must succeed');
  end;
  for LI := 0 to AThreads - 1 do
  begin
    LResult := platform_thread_join(LHandles[LI], LRetVal);
    CheckEqual(Int64(0), Int64(LResult), 'thread join must succeed');
  end;
end;

procedure TestConcurrentCalls;
var
  LOpts: TCircuitOptions;
  LFail, LOk, LMix: TCircuitBreaker;
  LTotal: Int64;
begin
  { All-failure breaker: trips fast, then every further call is rejected. }
  GFailAllowed := 0;
  GFailRejected := 0;
  LOpts := MakeOptions(0.5, 1, 60000, 60000, 10, 3);
  LFail := TCircuitBreaker.Create(LOpts);
  try
    RunConcurrent(LFail, 0, THREADS, OPS_PER_THREAD);
    Check(LFail.State = csOpen, 'all-failure breaker must end open');
    Check(GFailAllowed >= 1, 'at least one call must have been admitted');
    LTotal := Int64(GFailAllowed) + Int64(GFailRejected);
    CheckEqual(Int64(THREADS * OPS_PER_THREAD), LTotal, 'fail: all attempts accounted');
  finally
    LFail.Free;
  end;

  { All-success breaker: error rate stays 0, never trips. }
  GOkAllowed := 0;
  GOkRejected := 0;
  LOpts := MakeOptions(0.5, 1, 60000, 60000, 10, 3);
  LOk := TCircuitBreaker.Create(LOpts);
  try
    RunConcurrent(LOk, 1, THREADS, OPS_PER_THREAD);
    Check(LOk.State = csClosed, 'all-success breaker must stay closed');
    CheckEqual(Int64(0), Int64(GOkRejected), 'all-success breaker must not reject');
    CheckEqual(Int64(THREADS * OPS_PER_THREAD), Int64(GOkAllowed),
      'all-success: every attempt admitted and accounted');
  finally
    LOk.Free;
  end;

  { Mixed breaker: first failures trip it, rest are rejected. }
  GMixAllowed := 0;
  GMixRejected := 0;
  LOpts := MakeOptions(0.5, 1, 60000, 60000, 10, 3);
  LMix := TCircuitBreaker.Create(LOpts);
  try
    RunConcurrent(LMix, 2, THREADS, OPS_PER_THREAD);
    Check(LMix.State = csOpen, 'mixed breaker must end open');
    LTotal := Int64(GMixAllowed) + Int64(GMixRejected);
    CheckEqual(Int64(THREADS * OPS_PER_THREAD), LTotal, 'mixed: all attempts accounted');
  finally
    LMix.Free;
  end;
end;

{ TTestClock }

constructor TTestClock.Create(AStartMs: UInt64);
begin
  inherited Create;
  FNowNs := AStartMs * 1000000;
end;

procedure TTestClock.AdvanceMs(const AMilliseconds: UInt64);
begin
  Inc(FNowNs, AMilliseconds * 1000000);
end;

procedure TTestClock.SetMs(const AMilliseconds: UInt64);
begin
  FNowNs := AMilliseconds * 1000000;
end;

function TTestClock.NowNs: UInt64; inline;
begin
  Result := FNowNs;
end;

{ TInjectableCircuit }

constructor TInjectableCircuit.Create(const AOptions: TCircuitOptions; AClock: TTestClock);
begin
  inherited Create(AOptions);
  FClock := AClock;
end;

function TInjectableCircuit.TimeNowNs: UInt64;
begin
  Result := FClock.NowNs;
end;

begin
  WriteLn('=== test_lockfree_circuit ===');
  WriteLn;

  TestOptionsValidation;
  WriteLn('  + Options validation');
  TestErrorRateTripsOpen;
  WriteLn('  + Error-rate tripping');
  TestFewRequestsDoNotTrip;
  WriteLn('  + MinRequests guard');
  TestRateAtThresholdDoesNotTrip;
  WriteLn('  + Threshold boundary');
  TestHalfOpenProbeQuota;
  WriteLn('  + Half-open probe quota');
  TestHalfOpenSuccessRecloses;
  WriteLn('  + Half-open success re-closes');
  TestHalfOpenFailureReopens;
  WriteLn('  + Half-open failure re-opens');
  TestWindowSlides;
  WriteLn('  + Sliding window aging');
  TestExactOpenDurationBoundary;
  WriteLn('  + Exact open-duration boundary');
  TestTimeRollbackGuard;
  WriteLn('  + Time roll-back guard');
  TestRecordInOpenIsNoop;
  WriteLn('  + Stray records while open');
  TestReset;
  WriteLn('  + Reset');
  TestRealClockAging;
  WriteLn('  + Real-clock window aging');
  TestConcurrentCalls;
  WriteLn('  + Concurrent calls');

  WriteLn;
  WriteLn('All circuit breaker tests passed!');
end.