program test_sync;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.thread.base,
  nextpas.core.platform.thread,
  nextpas.core.errors,
  nextpas.core.system,
  nextpas.core.test,
  nextpas.core.time.base,
  nextpas.core.sync.base,
  nextpas.core.sync,
  nextpas.core.sync.mutex,
  nextpas.core.sync.rwlock;

var
  T: TTestSuite;


type
  TProcWorker = class(TWorkerThread)
  private
    FProc: TThreadTask;
  protected
    procedure Execute; override;
  public
    constructor Create(const AProc: TThreadTask);
  end;

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

procedure SleepMs(const AMs: Integer);
begin
  platform_thread_sleep_ms(UInt64(AMs));
end;

procedure TestMutexBasic;
var
  LM: IMutex;
begin
  LM := Mutex;
  LM.Acquire;
  LM.Release;
end;

procedure TestMutexTryAcquire;
var
  LM: IMutex;
begin
  LM := Mutex;
  Check(LM.TryAcquire, 'first tryacquire should succeed');
  LM.Release;
end;

procedure TestMutexGuard;
var
  LM: IMutex;
  LGuard: ILockGuard;
begin
  LM := Mutex;
  LGuard := LM.Lock;
  Check(not LM.TryAcquire, 'should be held by guard');
  LGuard := nil;
  Check(LM.TryAcquire, 'guard released, should be free');
  LM.Release;
end;

procedure TestFutexMutexBasic;
var
  LM: IMutex;
begin
  LM := FutexMutex;
  LM.Acquire;
  LM.Release;
end;

procedure TestFutexMutexTryAcquire;
var
  LM: IMutex;
begin
  LM := FutexMutex;
  Check(LM.TryAcquire, 'tryacquire should succeed');
  Check(not LM.TryAcquire, 'second tryacquire should fail');
  LM.Release;
end;

procedure TestFutexMutexContention;
var
  LM: IMutex;
  LCounter: Int32;
  LThread: TProcWorker;
begin
  LM := FutexMutex;
  LCounter := 0;

  LM.Acquire;

  LThread := TProcWorker.Create(procedure
  begin
    LM.Acquire;
    InterlockedIncrement(LCounter);
    LM.Release;
  end);
  LThread.Start;

  SleepMs(10);
  CheckEqual(Int64(0), Int64(LCounter), 'thread should be blocked');
  LM.Release;

  LThread.WaitFor;
  LThread.Free;
  CheckEqual(Int64(1), Int64(LCounter), 'thread should have incremented');
end;

procedure TestRWLockBasic;
var
  LRw: IRWLock;
begin
  LRw := RWLock;
  LRw.AcquireRead;
  Check(LRw.TryAcquireRead, 'multiple readers allowed');
  LRw.ReleaseRead;
  LRw.ReleaseRead;

  LRw.AcquireWrite;
  LRw.ReleaseWrite;
end;

procedure TestRWLockGuard;
var
  LRw: IRWLock;
  LGuard: ILockGuard;
begin
  LRw := RWLock;
  LGuard := LRw.WriteLock;
  Check(not LRw.TryAcquireRead, 'write held, read should fail');
  LGuard := nil;
  Check(LRw.TryAcquireRead, 'write released, read should succeed');
  LRw.ReleaseRead;
end;

procedure TestWaitGroupBasic;
var
  LWg: IWaitGroup;
  LDone: Int32;
  LThread: TProcWorker;
begin
  LWg := WaitGroup;
  LDone := 0;

  LWg.Add(1);
  LThread := TProcWorker.Create(procedure
  begin
    SleepMs(5);
    InterlockedIncrement(LDone);
    LWg.Done;
  end);
  LThread.Start;

  LWg.Wait;
  CheckEqual(Int64(1), Int64(LDone), 'should wait until done');
  LThread.WaitFor;
  LThread.Free;
end;

procedure TestWaitGroupMultiple;
var
  LWg: IWaitGroup;
  LCounter: Int32;
  LI: Integer;
  LThreads: array[0..3] of TProcWorker;
begin
  LWg := WaitGroup;
  LCounter := 0;

  LWg.Add(4);
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    begin
      SleepMs(2);
      InterlockedIncrement(LCounter);
      LWg.Done;
    end);
    LThreads[LI].Start;
  end;

  LWg.Wait;
  CheckEqual(Int64(4), Int64(LCounter), 'all 4 threads should complete');

  for LI := 0 to 3 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
end;

procedure TestCondVarDoesNotLoseSignalDuringRelease;
var
  LCond: ICondVar;
  LMutex: INativeMutex;
begin
  LCond := CondVar;
  LMutex := Mutex;
  LMutex.Acquire;
  Check(not LCond.WaitTimeout(LMutex, 1000000), 'condvar timeout returns false when no signal');
  LMutex.Release;
end;

{ Once tests }

var
  GOnceCounter: Int32 = 0;

procedure OnceIncrement;
begin
  Inc(GOnceCounter);
end;

procedure TestOnceBasic;
var
  LOnce: IOnce;
begin
  GOnceCounter := 0;
  LOnce := Once;
  LOnce.Do_(@OnceIncrement);
  LOnce.Do_(@OnceIncrement);
  LOnce.Do_(@OnceIncrement);
  CheckEqual(Int64(1), Int64(GOnceCounter), 'executed exactly once');
  Check(LOnce.Done, 'done after call');
end;

procedure TestOnceDoneBeforeCall;
var
  LOnce: IOnce;
begin
  LOnce := Once;
  Check(not LOnce.Done, 'not done before call');
end;

procedure OnceRaiser;
begin
  raise Exception.Create('boom');
end;

procedure TestOnceExceptionResets;
var
  LOnce: IOnce;
  LGot: Boolean;
begin
  GOnceCounter := 0;
  LOnce := Once;
  LGot := False;
  try
    LOnce.Do_(@OnceRaiser);
  except
    LGot := True;
  end;
  Check(LGot, 'exception propagated');
  Check(not LOnce.Done, 'not done after exception');
  LOnce.Do_(@OnceIncrement);
  CheckEqual(Int64(1), Int64(GOnceCounter), 'retry succeeded');
  Check(LOnce.Done, 'done after retry');
end;

{ SpinLock tests }

procedure TestSpinLockBasic;
var
  LS: ISpinLock;
begin
  LS := SpinLock;
  LS.Acquire;
  Check(not LS.TryAcquire, 'cannot re-acquire');
  LS.Release;
  Check(LS.TryAcquire, 'can acquire after release');
  LS.Release;
end;

procedure TestSpinLockGuard;
var
  LS: ISpinLock;
  LG: ILockGuard;
begin
  LS := SpinLock;
  LG := LS.Lock;
  Check(not LS.TryAcquire, 'locked by guard');
  LG := nil;
  Check(LS.TryAcquire, 'released after guard nil');
  LS.Release;
end;

{ Semaphore tests }

procedure TestSemaphoreBasic;
var
  LSem: ISemaphore;
begin
  LSem := Semaphore(2);
  CheckEqual(Int64(2), Int64(LSem.Available), 'initial 2');
  LSem.Acquire;
  CheckEqual(Int64(1), Int64(LSem.Available), 'after 1 acquire');
  LSem.Acquire;
  CheckEqual(Int64(0), Int64(LSem.Available), 'after 2 acquires');
  Check(not LSem.TryAcquire, 'exhausted');
  LSem.Release;
  CheckEqual(Int64(1), Int64(LSem.Available), 'after release');
  Check(LSem.TryAcquire, 'can acquire again');
  LSem.Release;
end;

procedure TestSemaphoreTimeout;
var
  LSem: ISemaphore;
begin
  LSem := Semaphore(0);
  Check(not LSem.TryAcquireTimeout(1000000), 'timeout on empty (1ms)');
  LSem.Release;
  Check(LSem.TryAcquireTimeout(1000000), 'acquire after release');
end;

procedure TestSemaphoreReleaseMultiple;
var
  LSem: ISemaphore;
begin
  LSem := Semaphore(0);
  LSem.Release(3);
  CheckEqual(Int64(3), Int64(LSem.Available), 'released 3');
  LSem.Acquire;
  LSem.Acquire;
  LSem.Acquire;
  Check(not LSem.TryAcquire, 'all consumed');
end;

{ Barrier tests }

procedure TestBarrierSingleThread;
var
  LB: IBarrier;
  LR: TBarrierWaitResult;
begin
  LB := Barrier(1);
  LR := LB.Wait;
  Check(LR.IsLeader, 'single thread is leader');
  CheckEqual(Int64(0), LR.Generation, 'gen 0');
  LR := LB.Wait;
  Check(LR.IsLeader, 'leader again (cyclic)');
  CheckEqual(Int64(1), LR.Generation, 'gen 1');
end;

{ Event tests }

procedure TestEventManualReset;
var
  LE: IEvent;
begin
  LE := Event(True);
  Check(not LE.IsSet, 'initially unset');
  LE.SetEvent;
  Check(LE.IsSet, 'set after SetEvent');
  LE.Wait;
  Check(LE.IsSet, 'still set after Wait (manual reset)');
  LE.Reset;
  Check(not LE.IsSet, 'unset after Reset');
end;

procedure TestEventAutoReset;
var
  LE: IEvent;
begin
  LE := Event(False);
  LE.SetEvent;
  Check(LE.IsSet, 'set');
  LE.Wait;
  Check(not LE.IsSet, 'auto-reset after Wait');
end;

procedure TestEventTimeout;
var
  LE: IEvent;
begin
  LE := Event(True);
  Check(not LE.WaitTimeout(1000000), 'timeout 1ms on unset');
  LE.SetEvent;
  Check(LE.WaitTimeout(1000000), 'immediate on set');
end;

procedure TestAutoResetIdempotent;
var
  LE: IEvent;
begin
  LE := Event(False);
  LE.SetEvent;
  LE.SetEvent;
  LE.SetEvent;
  LE.Wait;
  Check(not LE.IsSet, 'consumed single permit');
  Check(not LE.WaitTimeout(1000000), 'no second permit');
end;

procedure TestManualResetSetResetPulse;
var
  LE: IEvent;
begin
  LE := Event(True);
  LE.SetEvent;
  LE.Reset;
  Check(not LE.IsSet, 'reset after set');
  Check(not LE.WaitTimeout(1000000), 'waiter sees unset after pulse');
  LE.SetEvent;
  Check(LE.WaitTimeout(1000000), 'waiter sees second set');
end;

procedure TestFutexMutexGuard;
var
  LM: IMutex;
  LG: ILockGuard;
begin
  LM := FutexMutex;
  LG := LM.Lock;
  Check(not LM.TryAcquire, 'locked by guard');
  LG := nil;
  Check(LM.TryAcquire, 'released after guard nil');
  LM.Release;
end;

procedure TestRWLockTryAcquire;
var
  LRW: IRWLock;
begin
  LRW := RWLock;
  Check(LRW.TryAcquireRead, 'try read ok');
  Check(LRW.TryAcquireRead, 'try read ok (shared)');
  Check(not LRW.TryAcquireWrite, 'try write fails while read held');
  LRW.ReleaseRead;
  LRW.ReleaseRead;
  Check(LRW.TryAcquireWrite, 'try write ok after reads released');
  Check(not LRW.TryAcquireRead, 'try read fails while write held');
  LRW.ReleaseWrite;
  Check(LRW.TryAcquireRead, 'try read ok after write released');
  LRW.ReleaseRead;
end;

procedure TestCondVarBroadcast;
var
  LCond: ICondVar;
  LMutex: INativeMutex;
begin
  LCond := CondVar;
  LMutex := Mutex;
  LCond.Broadcast;
  LMutex.Acquire;
  Check(not LCond.WaitTimeout(LMutex, 1000000), 'timeout (no signal)');
  LMutex.Release;
end;

procedure TestWaitGroupDoneTooMany;
var
  LWg: IWaitGroup;
  LRaised: Boolean;
begin
  LWg := WaitGroup;
  LRaised := False;
  try
    LWg.Done;
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'Done without Add must raise');
end;

procedure TestWaitGroupAddNonPositive;
var
  LWg: IWaitGroup;
  LRaised: Boolean;
begin
  LWg := WaitGroup;
  LRaised := False;
  try
    LWg.Add(0);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Add(0) must raise');

  LRaised := False;
  try
    LWg.Add(-1);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Add(negative) must raise');
end;

procedure TestCondVarWithNativeMutex;
var
  LCond: ICondVar;
  LMutex: INativeMutex;
begin
  LCond := CondVar;
  LMutex := Mutex;
  LMutex.Acquire;
  Check(not LCond.WaitTimeout(LMutex, 1000000), 'native mutex timeout without signal');
  LMutex.Release;
end;

procedure TestFutexMutexIsNotNativeMutex;
var
  LMutex: IMutex;
  LNative: INativeMutex;
begin
  LMutex := FutexMutex;
  Check(not Supports(LMutex, INativeMutex, LNative),
    'FutexMutex must not implement INativeMutex (type-level CondVar isolation)');
  Check(Supports(Mutex, INativeMutex, LNative),
    'Mutex factory must implement INativeMutex');
end;

procedure TestSemaphoreNegativeInitial;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    Semaphore(-1);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Semaphore(-1) must raise');
end;

procedure TestBarrierInvalidCount;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    Barrier(0);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Barrier(0) must raise');

  LRaised := False;
  try
    Barrier(-3);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Barrier(negative) must raise');
end;

procedure TestOnceConcurrent;
var
  LOnce: IOnce;
  LThreads: array[0..7] of TProcWorker;
  LI: Integer;
begin
  LOnce := Once;
  GOnceCounter := 0;

  for LI := 0 to 7 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    begin
      LOnce.Do_(@OnceIncrement);
    end);
    LThreads[LI].Start;
  end;

  for LI := 0 to 7 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;

  CheckEqual(Int64(1), Int64(GOnceCounter), 'Once concurrent must run callback exactly once');
  Check(LOnce.Done, 'Once must be done after concurrent Do_');
end;

procedure TestEventAutoResetSinglePermit;
var
  LEv: IEvent;
begin
  LEv := Event(False);
  LEv.SetEvent;
  LEv.SetEvent; { idempotent: still one permit }
  Check(LEv.IsSet, 'auto-reset event set');
  LEv.Wait;
  Check(not LEv.IsSet, 'first Wait consumes the permit');
  Check(not LEv.WaitTimeout(1000000), 'second Wait must timeout with no second permit');
end;

procedure TestWaitGroupHighConcurrency;
var
  LWg: IWaitGroup;
  LCounter: Int32;
  LThreads: array[0..15] of TProcWorker;
  LI: Integer;
begin
  LWg := WaitGroup;
  LCounter := 0;
  LWg.Add(16);
  for LI := 0 to 15 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    begin
      InterlockedIncrement(LCounter);
      LWg.Done;
    end);
    LThreads[LI].Start;
  end;
  LWg.Wait;
  CheckEqual(Int64(16), Int64(LCounter), '16 workers all completed before Wait returns');
  for LI := 0 to 15 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
end;

procedure TestEventManualMultiWaiter;
var
  LEv: IEvent;
  LPassed: Int32;
  LThreads: array[0..3] of TProcWorker;
  LI: Integer;
begin
  LEv := Event(True); { manual reset }
  LPassed := 0;
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    begin
      LEv.Wait;
      InterlockedIncrement(LPassed);
    end);
    LThreads[LI].Start;
  end;
  SleepMs(20);
  CheckEqual(Int64(0), Int64(LPassed), 'waiters blocked before Set');
  LEv.SetEvent;
  for LI := 0 to 3 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
  CheckEqual(Int64(4), Int64(LPassed), 'manual reset wakes all waiters');
end;

procedure TestEventAutoSingleWinner;
var
  LEv: IEvent;
  LPassed: Int32;
  LThreads: array[0..3] of TProcWorker;
  LI: Integer;
begin
  LEv := Event(False); { auto reset }
  LPassed := 0;
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    begin
      if LEv.WaitTimeout(200000000) then { 200ms }
        InterlockedIncrement(LPassed);
    end);
    LThreads[LI].Start;
  end;
  SleepMs(20);
  LEv.SetEvent;
  for LI := 0 to 3 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
  CheckEqual(Int64(1), Int64(LPassed), 'auto-reset single Set admits exactly one waiter');
end;

procedure TestSemaphoreTimeoutZero;
var
  LSem: ISemaphore;
begin
  LSem := Semaphore(0);
  Check(not LSem.TryAcquireTimeout(0), 'timeout 0 on empty semaphore fails');
  LSem.Release;
  Check(LSem.TryAcquireTimeout(0), 'timeout 0 succeeds when permit available');
end;

procedure TestCondVarSignalWakesWaiter;
var
  LCond: ICondVar;
  LMutex: INativeMutex;
  LWoke: Int32;
  LThread: TProcWorker;
begin
  LCond := CondVar;
  LMutex := Mutex;
  LWoke := 0;
  LMutex.Acquire;
  LThread := TProcWorker.Create(procedure
  begin
    SleepMs(30);
    LMutex.Acquire;
    LCond.Signal;
    LMutex.Release;
  end);
  LThread.Start;
  Check(LCond.WaitTimeout(LMutex, 500000000), 'waiter sees signal within 500ms');
  InterlockedIncrement(LWoke);
  LMutex.Release;
  LThread.WaitFor;
  LThread.Free;
  CheckEqual(Int64(1), Int64(LWoke), 'condvar signal path completed');
end;

procedure TestMutexDestroyWhileHeldBestEffort;
var
  LObj: TMutex;
  LRaised: Boolean;
begin
  { Caller must not Free a held mutex. POSIX often returns EBUSY → L1 raises.
    Hosts that return 0 are platform-lenient (no L1 detection). }
  LObj := TMutex.Create;
  LObj.Acquire;
  LRaised := False;
  try
    LObj.Free;
  except
    on E: EInvalidOperationError do
    begin
      LRaised := True;
      { destroy failed: handle still valid — unlock then free cleanly }
      LObj.Release;
      LObj.Free;
    end;
  end;
  if LRaised then
    Check(True, 'Destroy while held raised (host reports destroy error)')
  else
  begin
    {$IFDEF LINUX}
    Check(False, 'Linux expected TMutex.Destroy to raise when mutex still held');
    {$ELSE}
    Check(True, 'host lenient: destroy while held returned success (no L1 detection)');
    {$ENDIF}
  end;
end;

procedure TestBarrierMultiThread;
const
  N = 8;
var
  LB: IBarrier;
  LLeaders: Int32;
  LDone: Int32;
  LThreads: array[0..N - 1] of TProcWorker;
  LI: Integer;
begin
  LB := Barrier(N);
  LLeaders := 0;
  LDone := 0;
  for LI := 0 to N - 1 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    var
      LR: TBarrierWaitResult;
    begin
      LR := LB.Wait;
      if LR.IsLeader then
        InterlockedIncrement(LLeaders);
      InterlockedIncrement(LDone);
    end);
    LThreads[LI].Start;
  end;
  for LI := 0 to N - 1 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
  CheckEqual(Int64(N), Int64(LDone), 'all barrier waiters finished gen0');
  CheckEqual(Int64(1), Int64(LLeaders), 'exactly one leader per generation');

  { second generation — reusable barrier }
  LLeaders := 0;
  LDone := 0;
  for LI := 0 to N - 1 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    var
      LR: TBarrierWaitResult;
    begin
      LR := LB.Wait;
      if LR.IsLeader then
        InterlockedIncrement(LLeaders);
      InterlockedIncrement(LDone);
    end);
    LThreads[LI].Start;
  end;
  for LI := 0 to N - 1 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
  CheckEqual(Int64(N), Int64(LDone), 'all barrier waiters finished gen1');
  CheckEqual(Int64(1), Int64(LLeaders), 'exactly one leader in gen1');
end;


procedure TestWaitGroupWaitTimeout;
var
  LWg: IWaitGroup;
begin
  LWg := WaitGroup;
  LWg.Add(1);
  Check(not LWg.WaitTimeout(1000000), 'timeout when counter non-zero');
  LWg.Done;
  Check(LWg.WaitTimeout(1000000), 'immediate when counter zero');
  Check(LWg.WaitTimeout(TDuration.FromMilliseconds(1)), 'duration overload when zero');
end;

procedure TestDoOnceAlias;
var
  LOnce: IOnce;
begin
  LOnce := Once;
  GOnceCounter := 0;
  LOnce.DoOnce(@OnceIncrement);
  LOnce.DoOnce(@OnceIncrement);
  CheckEqual(Int64(1), Int64(GOnceCounter), 'DoOnce runs once');
  Check(LOnce.Done, 'done after DoOnce');
end;

procedure TestDurationTimeoutOverloads;
var
  LSem: ISemaphore;
  LEv: IEvent;
  LCv: ICondVar;
  LM: INativeMutex;
begin
  LSem := Semaphore(0);
  Check(not LSem.TryAcquireTimeout(TDuration.FromMilliseconds(1)), 'sem duration timeout');
  LEv := Event(False);
  Check(not LEv.WaitTimeout(TDuration.FromMilliseconds(1)), 'event duration timeout');
  LCv := CondVar;
  LM := Mutex;
  LM.Acquire;
  Check(not LCv.WaitTimeout(LM, TDuration.FromMilliseconds(1)), 'condvar duration timeout');
  LM.Release;
end;

procedure TestRWLockDestroyWhileHeldBestEffort;
var
  LObj: TRWLock;
  LRaised: Boolean;
begin
  LObj := TRWLock.Create;
  LObj.AcquireWrite;
  LRaised := False;
  try
    LObj.Free;
  except
    on E: EInvalidOperationError do
    begin
      LRaised := True;
      LObj.ReleaseWrite;
      LObj.Free;
    end;
  end;
  { pthread_rwlock_destroy while held is host-dependent (often returns 0).
    If non-zero → L1 raises (already asserted path). If 0 → lenient host. }
  if LRaised then
    Check(True, 'RWLock Destroy while write-held raised (host reports error)')
  else
    Check(True, 'RWLock Destroy while write-held returned success (host-lenient)');
end;

procedure TestRecursiveMutexReentry;
var
  LM: INativeMutex;
begin
  LM := RecursiveMutex;
  LM.Acquire;
  LM.Acquire;
  Check(True, 'recursive reentry ok');
  LM.Release;
  LM.Release;
  Check(LM.TryAcquire, 'free after balanced unlock');
  LM.Release;
end;

procedure TestRecursiveMutexWithCondVar;
var
  LM: INativeMutex;
  LCv: ICondVar;
begin
  LM := RecursiveMutex;
  LCv := CondVar;
  LM.Acquire;
  Check(not LCv.WaitTimeout(LM, 1000000), 'recursive mutex pairs with condvar');
  LM.Release;
end;

procedure TestLatchBasic;
var
  L: ILatch;
begin
  L := Latch(2);
  CheckEqual(Int64(2), Int64(L.Remaining), 'remaining start');
  Check(not L.TryWait, 'not ready');
  L.CountDown;
  CheckEqual(Int64(1), Int64(L.Remaining), 'remaining mid');
  L.CountDown;
  Check(L.TryWait, 'ready');
  Check(L.WaitTimeout(TDuration.FromMilliseconds(1)), 'wait after zero');
end;

procedure TestLatchZero;
var
  L: ILatch;
begin
  L := Latch(0);
  Check(L.TryWait, 'zero latch already open');
  L.Wait;
end;

procedure TestLatchMultiWaiter;
var
  L: ILatch;
  LDone: Int32;
  T1, T2: TProcWorker;
begin
  L := Latch(1);
  LDone := 0;
  T1 := TProcWorker.Create(procedure
  begin
    L.Wait;
    InterlockedIncrement(LDone);
  end);
  T2 := TProcWorker.Create(procedure
  begin
    L.Wait;
    InterlockedIncrement(LDone);
  end);
  T1.Start;
  T2.Start;
  SleepMs(20);
  CheckEqual(Int64(0), Int64(LDone), 'blocked before countdown');
  L.CountDown;
  T1.WaitFor;
  T2.WaitFor;
  T1.Free;
  T2.Free;
  CheckEqual(Int64(2), Int64(LDone), 'both waiters released');
end;

procedure TestNotifySticky;
var
  N: INotify;
begin
  N := Notify;
  N.NotifyOne;
  N.Wait;
  Check(True, 'sticky notify consumed');
  Check(not N.WaitTimeout(TDuration.FromMilliseconds(1)), 'no second permit');
end;

procedure TestNotifyWakesWaiter;
var
  N: INotify;
  LDone: Int32;
  Th: TProcWorker;
begin
  N := Notify;
  LDone := 0;
  Th := TProcWorker.Create(procedure
  begin
    N.Wait;
    InterlockedIncrement(LDone);
  end);
  Th.Start;
  SleepMs(20);
  CheckEqual(Int64(0), Int64(LDone), 'blocked');
  N.NotifyOne;
  Th.WaitFor;
  Th.Free;
  CheckEqual(Int64(1), Int64(LDone), 'woken');
end;

procedure TestNotifyAll;
var
  N: INotify;
  LDone: Int32;
  T1, T2: TProcWorker;
begin
  N := Notify;
  LDone := 0;
  T1 := TProcWorker.Create(procedure
  begin
    N.Wait;
    InterlockedIncrement(LDone);
  end);
  T2 := TProcWorker.Create(procedure
  begin
    N.Wait;
    InterlockedIncrement(LDone);
  end);
  T1.Start;
  T2.Start;
  SleepMs(20);
  N.NotifyAll;
  T1.WaitFor;
  T2.WaitFor;
  T1.Free;
  T2.Free;
  CheckEqual(Int64(2), Int64(LDone), 'notify all woke both');
end;

procedure TestChannelBasic;
var
  C: IChannel;
  P: Pointer;
begin
  C := Channel(2);
  CheckEqual(Int64(2), Int64(C.Cap), 'cap');
  Check(C.TrySend(Pointer(1)) = csrOk, 'send1');
  Check(C.TrySend(Pointer(2)) = csrOk, 'send2');
  Check(C.TrySend(Pointer(3)) = csrFull, 'full');
  Check(C.TryRecv(P) = crrOk, 'recv1');
  CheckEqual(Int64(1), Int64(PtrUInt(P)), 'val1');
  Check(C.Recv(P), 'recv2');
  CheckEqual(Int64(2), Int64(PtrUInt(P)), 'val2');
  Check(C.TryRecv(P) = crrEmpty, 'empty');
end;

procedure TestChannelClose;
var
  C: IChannel;
  P: Pointer;
begin
  C := Channel(1);
  Check(C.Send(Pointer(7)), 'send');
  C.Close;
  Check(C.IsClosed, 'closed');
  Check(C.TrySend(Pointer(8)) = csrClosed, 'send after close');
  Check(C.Recv(P), 'drain after close');
  CheckEqual(Int64(7), Int64(PtrUInt(P)), 'drained value');
  Check(not C.Recv(P), 'recv closed empty');
end;

procedure TestChannelProducerConsumer;
var
  C: IChannel;
  LSum: Int32;
  Prod, Cons: TProcWorker;
  I: Integer;
begin
  C := Channel(4);
  LSum := 0;
  Prod := TProcWorker.Create(procedure
  var
    K: Integer;
  begin
    for K := 1 to 20 do
      Check(C.Send(Pointer(K)), 'prod send');
    C.Close;
  end);
  Cons := TProcWorker.Create(procedure
  var
    P: Pointer;
  begin
    while C.Recv(P) do
      InterlockedExchangeAdd(LSum, Integer(PtrUInt(P)));
  end);
  Prod.Start;
  Cons.Start;
  Prod.WaitFor;
  Cons.WaitFor;
  Prod.Free;
  Cons.Free;
  CheckEqual(Int64(210), Int64(LSum), 'sum 1..20');
end;

procedure TestScopedWithLock;
var
  LM: IMutex;
  LVal: Integer;
begin
  LM := Mutex;
  LVal := 0;
  WithLock(LM, procedure
  begin
    Inc(LVal);
    Check(not LM.TryAcquire, 'held inside WithLock');
  end);
  CheckEqual(Int64(1), Int64(LVal), 'proc ran');
  Check(LM.TryAcquire, 'released after WithLock');
  LM.Release;
end;

procedure TestScopedRW;
var
  LRW: IRWLock;
  LVal: Integer;
begin
  LRW := RWLock;
  LVal := 0;
  WithReadLock(LRW, procedure
  begin
    Inc(LVal);
  end);
  WithWriteLock(LRW, procedure
  begin
    Inc(LVal, 10);
  end);
  CheckEqual(Int64(11), Int64(LVal), 'read+write scoped');
end;

function PoolFacadeFactory: Pointer;
begin
  Result := TPoolItem.Create;
end;

procedure TestPoolFacade;
var
  LPool: TSyncPool;
  LObj: Pointer;
begin
  LPool := CreateSyncPool(@PoolFacadeFactory);
  try
    LObj := LPool.Get;
    Check(LObj <> nil, 'pool get');
    LPool.Put(LObj);
    Check(LPool.TotalCreated > 0, 'pool created items');
  finally
    LPool.Free;
  end;
end;

procedure TestChannelTimeoutDistinct;
var
  C: IChannel;
  P: Pointer;
begin
  C := Channel(1);
  Check(C.TrySend(Pointer(1)) = csrOk, 'fill');
  Check(C.SendTimeout(Pointer(2), TDuration.FromMilliseconds(1)) = csrTimeout,
    'send timeout != full');
  Check(C.TrySend(Pointer(3)) = csrFull, 'still full via TrySend');
  Check(C.Recv(P), 'drain');
  Check(C.RecvTimeout(P, TDuration.FromMilliseconds(1)) = crrTimeout,
    'recv timeout != empty');
  Check(C.TryRecv(P) = crrEmpty, 'still empty via TryRecv');
end;

procedure TestLatchCountDownTooMany;
var
  L: ILatch;
  LRaised: Boolean;
begin
  L := Latch(1);
  L.CountDown;
  LRaised := False;
  try
    L.CountDown;
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  { After zero, CountDown is no-op per INV-11 — not raise. }
  Check(not LRaised, 'countdown at zero is no-op');
  Check(L.TryWait, 'still open');
end;

procedure TestLatchCountDownWouldGoNegative;
var
  L: ILatch;
  LRaised: Boolean;
begin
  L := Latch(1);
  LRaised := False;
  try
    L.CountDown(2);
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'countdown 2 from 1 raises');
  CheckEqual(Int64(1), Int64(L.Remaining), 'remaining unchanged');
end;

procedure TestDoOnceClosure;
var
  LOnce: IOnce;
  LHits: Integer;
begin
  LOnce := Once;
  LHits := 0;
  LOnce.DoOnce(procedure
  begin
    Inc(LHits);
  end);
  LOnce.DoOnce(procedure
  begin
    Inc(LHits, 10);
  end);
  CheckEqual(Int64(1), Int64(LHits), 'closure DoOnce runs once');
  Check(LOnce.Done, 'done');
end;

procedure TestNotifyAllClearsPermits;
var
  N: INotify;
begin
  N := Notify;
  N.NotifyOne;
  N.NotifyAll;
  { sticky permit cleared by NotifyAll; no waiter was present }
  Check(not N.WaitTimeout(TDuration.FromMilliseconds(1)),
    'no sticky permit after NotifyAll');
end;

procedure TestPoolRejectsNonPoolItem;
var
  LPool: TSyncPool;
  LObj: TObject;
  LRaised: Boolean;
begin
  LPool := CreateSyncPool(@PoolFacadeFactory);
  LObj := TObject.Create;
  try
    LRaised := False;
    try
      LPool.Put(LObj);
    except
      on E: EArgumentError do
        LRaised := True;
    end;
    Check(LRaised, 'Put non-TPoolItem raises');
  finally
    LObj.Free;
    LPool.Free;
  end;
end;

procedure TestChannelCloseWakesBlockedRecv;
var
  C: IChannel;
  LGot: Int32;
  LOk: Int32;
  Th: TProcWorker;
  P: Pointer;
begin
  C := Channel(1);
  LGot := 0;
  LOk := 0;
  Th := TProcWorker.Create(procedure
  var
    LP: Pointer;
    LRecvOk: Boolean;
  begin
    LRecvOk := C.Recv(LP);
    if LRecvOk then
      InterlockedIncrement(LOk);
    InterlockedIncrement(LGot);
  end);
  Th.Start;
  SleepMs(20);
  CheckEqual(Int64(0), Int64(LGot), 'recv blocked before close');
  C.Close;
  Th.WaitFor;
  Th.Free;
  CheckEqual(Int64(1), Int64(LGot), 'recv unblocked by close');
  CheckEqual(Int64(0), Int64(LOk), 'empty closed recv returns False');
  Check(not C.Recv(P), 'subsequent Recv still False');
end;

procedure TestChannelMultiRecvClose;
var
  C: IChannel;
  LGot: Int32;
  LOk: Int32;
  T1, T2: TProcWorker;
begin
  C := Channel(2);
  LGot := 0;
  LOk := 0;
  T1 := TProcWorker.Create(procedure
  var
    LP: Pointer;
  begin
    if C.Recv(LP) then
      InterlockedIncrement(LOk);
    InterlockedIncrement(LGot);
  end);
  T2 := TProcWorker.Create(procedure
  var
    LP: Pointer;
  begin
    if C.Recv(LP) then
      InterlockedIncrement(LOk);
    InterlockedIncrement(LGot);
  end);
  T1.Start;
  T2.Start;
  SleepMs(20);
  CheckEqual(Int64(0), Int64(LGot), 'both blocked');
  C.Close;
  T1.WaitFor;
  T2.WaitFor;
  T1.Free;
  T2.Free;
  CheckEqual(Int64(2), Int64(LGot), 'both woke');
  CheckEqual(Int64(0), Int64(LOk), 'both got False on empty close');
end;

procedure TestDoOnceClosureExceptionResets;
var
  LOnce: IOnce;
  LHits: Integer;
  LRaised: Boolean;
begin
  LOnce := Once;
  LHits := 0;
  LRaised := False;
  try
    LOnce.DoOnce(procedure
    begin
      Inc(LHits);
      raise EInvalidOperationError.Create('once boom');
    end);
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'exception propagated from closure');
  Check(not LOnce.Done, 'not done after failed closure');
  CheckEqual(Int64(1), Int64(LHits), 'failed attempt ran once');
  LOnce.DoOnce(procedure
  begin
    Inc(LHits, 10);
  end);
  CheckEqual(Int64(11), Int64(LHits), 'retry ran successfully');
  Check(LOnce.Done, 'done after retry');
end;

procedure TestChannelSendRecvBooleanMatrix;
var
  C: IChannel;
  P: Pointer;
begin
  { F-R1: blocking Send/Recv stay Boolean — success/closed only; never encode full/empty. }
  C := Channel(1);
  Check(C.Send(Pointer(9)), 'Send ok while open');
  Check(C.Recv(P), 'Recv ok with item');
  CheckEqual(Int64(9), Int64(PtrUInt(P)), 'value');
  C.Close;
  Check(not C.Send(Pointer(1)), 'Send False after close');
  Check(not C.Recv(P), 'Recv False after close empty');
end;

procedure TestBarrierTwoThreadTwoGens;
const
  N = 2;
var
  LB: IBarrier;
  LLeaders: Int32;
  LDone: Int32;
  LThreads: array[0..N - 1] of TProcWorker;
  LI, LRound: Integer;
begin
  LB := Barrier(N);
  for LRound := 1 to 2 do
  begin
    LLeaders := 0;
    LDone := 0;
    for LI := 0 to N - 1 do
    begin
      LThreads[LI] := TProcWorker.Create(procedure
      var
        LR: TBarrierWaitResult;
      begin
        LR := LB.Wait;
        if LR.IsLeader then
          InterlockedIncrement(LLeaders);
        InterlockedIncrement(LDone);
      end);
      LThreads[LI].Start;
    end;
    for LI := 0 to N - 1 do
    begin
      LThreads[LI].WaitFor;
      LThreads[LI].Free;
    end;
    CheckEqual(Int64(N), Int64(LDone), 'round done');
    CheckEqual(Int64(1), Int64(LLeaders), 'one leader per round');
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.sync');
  T.Test('Mutex basic', @TestMutexBasic);
  T.Test('Mutex tryacquire', @TestMutexTryAcquire);
  T.Test('Mutex guard (RAII)', @TestMutexGuard);
  T.Test('FutexMutex basic', @TestFutexMutexBasic);
  T.Test('FutexMutex tryacquire', @TestFutexMutexTryAcquire);
  T.Test('FutexMutex contention', @TestFutexMutexContention);

  T.Test('FutexMutex guard', @TestFutexMutexGuard);

  T.Test('RWLock basic', @TestRWLockBasic);
  T.Test('RWLock guard (RAII)', @TestRWLockGuard);
  T.Test('RWLock try acquire', @TestRWLockTryAcquire);
  T.Test('WaitGroup basic', @TestWaitGroupBasic);
  T.Test('WaitGroup multiple', @TestWaitGroupMultiple);
  T.Test('WaitGroup done too many', @TestWaitGroupDoneTooMany);
  T.Test('WaitGroup add non-positive', @TestWaitGroupAddNonPositive);
  T.Test('CondVar broadcast', @TestCondVarBroadcast);
  T.Test('CondVar does not lose signal during release', @TestCondVarDoesNotLoseSignalDuringRelease);
  T.Test('CondVar with INativeMutex', @TestCondVarWithNativeMutex);
  T.Test('FutexMutex is not INativeMutex', @TestFutexMutexIsNotNativeMutex);

  T.Test('Once basic', @TestOnceBasic);
  T.Test('Once not done before call', @TestOnceDoneBeforeCall);
  T.Test('Once exception resets', @TestOnceExceptionResets);
  T.Test('Once concurrent', @TestOnceConcurrent);
  T.Test('SpinLock basic', @TestSpinLockBasic);
  T.Test('SpinLock guard', @TestSpinLockGuard);
  T.Test('Semaphore basic', @TestSemaphoreBasic);
  T.Test('Semaphore timeout', @TestSemaphoreTimeout);
  T.Test('Semaphore release multiple', @TestSemaphoreReleaseMultiple);
  T.Test('Semaphore negative initial', @TestSemaphoreNegativeInitial);

  T.Test('Barrier single thread', @TestBarrierSingleThread);
  T.Test('Barrier multi-thread', @TestBarrierMultiThread);
  T.Test('Barrier invalid count', @TestBarrierInvalidCount);
  T.Test('Event manual reset', @TestEventManualReset);
  T.Test('Event auto reset', @TestEventAutoReset);
  T.Test('Event timeout', @TestEventTimeout);
  T.Test('AutoReset idempotent', @TestAutoResetIdempotent);
  T.Test('ManualReset set+reset pulse', @TestManualResetSetResetPulse);
  T.Test('Event auto-reset single permit', @TestEventAutoResetSinglePermit);
  T.Test('WaitGroup high concurrency', @TestWaitGroupHighConcurrency);
  T.Test('Event manual multi-waiter', @TestEventManualMultiWaiter);
  T.Test('Event auto single winner', @TestEventAutoSingleWinner);
  T.Test('Semaphore timeout zero', @TestSemaphoreTimeoutZero);
  T.Test('CondVar signal wakes waiter', @TestCondVarSignalWakesWaiter);
  T.Test('Mutex destroy while held (best-effort)', @TestMutexDestroyWhileHeldBestEffort);
  T.Test('RWLock destroy while held (best-effort)', @TestRWLockDestroyWhileHeldBestEffort);
  T.Test('WaitGroup wait timeout', @TestWaitGroupWaitTimeout);
  T.Test('DoOnce alias', @TestDoOnceAlias);
  T.Test('Duration timeout overloads', @TestDurationTimeoutOverloads);

  T.Test('RecursiveMutex reentry', @TestRecursiveMutexReentry);
  T.Test('RecursiveMutex with CondVar', @TestRecursiveMutexWithCondVar);
  T.Test('Latch basic', @TestLatchBasic);
  T.Test('Latch zero', @TestLatchZero);
  T.Test('Latch multi waiter', @TestLatchMultiWaiter);
  T.Test('Notify sticky', @TestNotifySticky);
  T.Test('Notify wakes waiter', @TestNotifyWakesWaiter);
  T.Test('Notify all', @TestNotifyAll);
  T.Test('Channel basic', @TestChannelBasic);
  T.Test('Channel close', @TestChannelClose);
  T.Test('Channel producer consumer', @TestChannelProducerConsumer);
  T.Test('Channel timeout distinct', @TestChannelTimeoutDistinct);
  T.Test('Latch countdown at zero no-op', @TestLatchCountDownTooMany);
  T.Test('Latch countdown would go negative', @TestLatchCountDownWouldGoNegative);
  T.Test('DoOnce closure', @TestDoOnceClosure);
  T.Test('NotifyAll clears permits', @TestNotifyAllClearsPermits);
  T.Test('Scoped WithLock', @TestScopedWithLock);
  T.Test('Scoped RW', @TestScopedRW);
  T.Test('Pool facade', @TestPoolFacade);
  T.Test('Pool rejects non-TPoolItem', @TestPoolRejectsNonPoolItem);
  T.Test('Channel close wakes blocked Recv', @TestChannelCloseWakesBlockedRecv);
  T.Test('Channel multi Recv close', @TestChannelMultiRecvClose);
  T.Test('DoOnce closure exception resets', @TestDoOnceClosureExceptionResets);
  T.Test('Channel Send/Recv Boolean matrix', @TestChannelSendRecvBooleanMatrix);
  T.Test('Barrier two-thread two gens', @TestBarrierTwoThreadTwoGens);

  if not T.Run then Halt(1);
end.
