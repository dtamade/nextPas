program bench_sync;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.thread.init,
  nextpas.core.bench,
  nextpas.core.time.base,
  nextpas.core.sync;

var
  LResults: IBenchResults;
  GSink: Int64;
  GContendedMutex: IMutex;
  GContendedIters: Int64;

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

{ 2-thread contended lock/unlock: wall-clock total / (2 * iters) as ns/op. }
function RunContended2T(const ALabel: string; const AMutex: IMutex;
  const AItersPerThread: Int64): Double;
var
  LThreads: array[0..1] of TThread;
  LStart, LElapsed: TDateTime;
  LI: Integer;
  LTotalOps: Int64;
  LNs: Double;
begin
  GContendedMutex := AMutex;
  GContendedIters := AItersPerThread;
  LStart := Now;
  for LI := 0 to 1 do
  begin
    LThreads[LI] := TThread.CreateAnonymousThread(procedure
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
    LThreads[LI].FreeOnTerminate := False;
    LThreads[LI].Start;
  end;
  for LI := 0 to 1 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
  LElapsed := Now - LStart;
  LTotalOps := AItersPerThread * 2;
  { days -> ns }
  LNs := LElapsed * 24.0 * 3600.0 * 1.0e9 / LTotalOps;
  WriteLn(Format('  %-36s  2T x %d  ~%.1f ns/op  (wall, total ops=%d)',
    [ALabel, AItersPerThread, LNs, LTotalOps]));
  Result := LNs;
end;

var
  GSc7Ns, GSc8Ns: Double;

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
  ForceDirectories('build');
  LResults.SaveToJSON('build/bench-sync.json');

  WriteLn;
  WriteLn('=== contended (2 threads, wall-clock ns/op) ===');
  WriteLn;
  GSc7Ns := RunContended2T('sync/Mutex/Contended2T', Mutex, 200000);
  GSc8Ns := RunContended2T('sync/FutexMutex/Contended2T', FutexMutex, 200000);
  WriteLn;
  WriteLn(Format('SCORECARD_HINT SC7_Mutex_2T_ns_op=%.1f SC8_Futex_2T_ns_op=%.1f',
    [GSc7Ns, GSc8Ns]));
end.
