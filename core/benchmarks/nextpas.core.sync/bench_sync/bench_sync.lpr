program bench_sync;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.math,
  nextpas.core.thread.init,
  nextpas.core.thread.base,
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.text,
  nextpas.core.fs,
  nextpas.core.sync;

const
  CONTENDED_ITERS = 200000;
  CONTENDED_SAMPLES = 7;
  CONTENDED_WARMUP = 1;

type
  TProcWorker = class(TWorkerThread)
  private
    FProc: TThreadTask;
  protected
    procedure Execute; override;
  public
    constructor Create(const AProc: TThreadTask);
  end;

var
  LResults: IBenchResults;
  GSink: Int64;
  GContendedMutex: IMutex;
  GContendedIters: Int64;

constructor TProcWorker.Create(const AProc: TThreadTask);
begin
  inherited Create;
  FProc := AProc;
end;

procedure TProcWorker.Execute;
begin
  if Assigned(FProc) then
    FProc();
end;

procedure BenchMutexLockUnlock(aIters: Int64);
var
  LIt: Int64;
  LM: IMutex;
begin
  LM := Mutex;
  for LIt := 1 to aIters do
  begin
    LM.Acquire;
    LM.Release;
  end;
end;

procedure BenchFutexMutexLockUnlock(aIters: Int64);
var
  LIt: Int64;
  LM: IMutex;
begin
  LM := FutexMutex;
  for LIt := 1 to aIters do
  begin
    LM.Acquire;
    LM.Release;
  end;
end;

procedure BenchSpinLockLockUnlock(aIters: Int64);
var
  LIt: Int64;
  LS: ISpinLock;
begin
  LS := SpinLock;
  for LIt := 1 to aIters do
  begin
    LS.Acquire;
    LS.Release;
  end;
end;

procedure BenchRWLockReadLock(aIters: Int64);
var
  LIt: Int64;
  LRW: IRWLock;
begin
  LRW := RWLock;
  for LIt := 1 to aIters do
  begin
    LRW.AcquireRead;
    LRW.ReleaseRead;
  end;
end;

procedure BenchRWLockWriteLock(aIters: Int64);
var
  LIt: Int64;
  LRW: IRWLock;
begin
  LRW := RWLock;
  for LIt := 1 to aIters do
  begin
    LRW.AcquireWrite;
    LRW.ReleaseWrite;
  end;
end;

procedure BenchMutexTryAcquire(aIters: Int64);
var
  LIt: Int64;
  LM: IMutex;
begin
  LM := Mutex;
  for LIt := 1 to aIters do
  begin
    if LM.TryAcquire then
      LM.Release;
  end;
end;

function SampleContended2T(const AMutex: IMutex; const AItersPerThread: Int64): Double;
var
  LThreads: array[0..1] of TProcWorker;
  LStart: TInstant;
  LI: Integer;
  LTotalOps: Int64;
  LNs: Int64;
begin
  GContendedMutex := AMutex;
  GContendedIters := AItersPerThread;
  LStart := TInstant.Now;
  for LI := 0 to 1 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    var
      LIt: Int64;
    begin
      for LIt := 1 to GContendedIters do
      begin
        GContendedMutex.Acquire;
        Inc(GSink);
        GContendedMutex.Release;
      end;
    end);
    LThreads[LI].Start;
  end;
  for LI := 0 to 1 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
  LTotalOps := AItersPerThread * 2;
  LNs := LStart.Elapsed.AsNanoseconds;
  if LTotalOps <= 0 then
    Exit(0);
  Result := LNs / LTotalOps;
end;

procedure SortDoubles(var A: array of Double; ACount: Integer);
var
  I, J: Integer;
  T: Double;
begin
  for I := 0 to ACount - 2 do
    for J := I + 1 to ACount - 1 do
      if A[J] < A[I] then
      begin
        T := A[I];
        A[I] := A[J];
        A[J] := T;
      end;
end;

type
  TContendedStats = record
    Median: Double;
    P95: Double;
    MinV: Double;
    MaxV: Double;
    Mean: Double;
    CVPct: Double;
  end;

function RunContended2TRobust(const ALabel: string; const AMutex: IMutex): TContendedStats;
var
  LSamples: array[0..CONTENDED_SAMPLES - 1] of Double;
  LI: Integer;
  LSum, LVar, LStd: Double;
  LIdxP95: Integer;
begin
  for LI := 1 to CONTENDED_WARMUP do
    SampleContended2T(AMutex, CONTENDED_ITERS);

  LSum := 0;
  for LI := 0 to CONTENDED_SAMPLES - 1 do
  begin
    LSamples[LI] := SampleContended2T(AMutex, CONTENDED_ITERS);
    LSum := LSum + LSamples[LI];
  end;

  SortDoubles(LSamples, CONTENDED_SAMPLES);
  Result.MinV := LSamples[0];
  Result.MaxV := LSamples[CONTENDED_SAMPLES - 1];
  Result.Median := LSamples[CONTENDED_SAMPLES div 2];
  LIdxP95 := (CONTENDED_SAMPLES * 95) div 100;
  if LIdxP95 >= CONTENDED_SAMPLES then
    LIdxP95 := CONTENDED_SAMPLES - 1;
  Result.P95 := LSamples[LIdxP95];
  Result.Mean := LSum / CONTENDED_SAMPLES;
  LVar := 0;
  for LI := 0 to CONTENDED_SAMPLES - 1 do
    LVar := LVar + Sqr(LSamples[LI] - Result.Mean);
  LVar := LVar / CONTENDED_SAMPLES;
  LStd := Sqrt(LVar);
  if Result.Mean > 0 then
    Result.CVPct := 100.0 * LStd / Result.Mean
  else
    Result.CVPct := 0;

  WriteLn(TextFormat(
    '  %-32s  n=%d  median=%.1f  p95=%.1f  min=%.1f  max=%.1f  mean=%.1f  CV=%.1f%%',
    [ALabel, CONTENDED_SAMPLES, Result.Median, Result.P95, Result.MinV, Result.MaxV,
     Result.Mean, Result.CVPct]));
  if Result.CVPct > 25.0 then
    WriteLn('  WARNING: noisy samples (CV>25%) — treat as trend only');
end;

var
  GSc9, GSc10: TContendedStats;

begin
  WriteLn('=== nextpas.core.sync benchmark (uncontended) ===');
  WriteLn;
  LResults := TBenchSuite.Create('sync')
    .SetQuiet(True)
    .SetMinDuration(TDuration.FromMilliseconds(50))
    .SetMinSamples(5)
    .AddLoop('sync/Mutex/LockUnlock', @BenchMutexLockUnlock)
    .AddLoop('sync/FutexMutex/LockUnlock', @BenchFutexMutexLockUnlock)
    .AddLoop('sync/SpinLock/LockUnlock', @BenchSpinLockLockUnlock)
    .AddLoop('sync/RWLock/Read', @BenchRWLockReadLock)
    .AddLoop('sync/RWLock/Write', @BenchRWLockWriteLock)
    .AddLoop('sync/Mutex/TryAcquire', @BenchMutexTryAcquire)
    .Run;
  WriteLn(LResults.PrintToConsole);
  MkdirAll('build');
  LResults.SaveToJSON('build/bench-sync.json');

  WriteLn;
  WriteLn(TextFormat('=== contended 2T (warmup=%d samples=%d iters/thread=%d, TInstant wall) ===',
    [CONTENDED_WARMUP, CONTENDED_SAMPLES, CONTENDED_ITERS]));
  WriteLn;
  GSc9 := RunContended2TRobust('sync/Mutex/Contended2T', Mutex);
  GSc10 := RunContended2TRobust('sync/FutexMutex/Contended2T', FutexMutex);
  WriteLn;
  WriteLn(TextFormat(
    'SCORECARD_HINT SC9_median=%.1f SC9_p95=%.1f SC10_median=%.1f SC10_p95=%.1f',
    [GSc9.Median, GSc9.P95, GSc10.Median, GSc10.P95]));
end.
