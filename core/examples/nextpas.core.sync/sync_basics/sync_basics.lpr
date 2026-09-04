{**
 * nextpas.core.sync consumer smoke (L1 facade).
 *
 * Demonstrates Mutex/INativeMutex + CondVar, WaitGroup, Once, Event,
 * and SpinLock guard using nextpas thread + time (no FPC RTL units).
 *}
program sync_basics;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.thread.base,
  nextpas.core.time.base,
  nextpas.core.sync;

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
  GOnceHits: Int32;
  GWgHits: Int32;

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

procedure OnceMark;
begin
  InterlockedIncrement(GOnceHits);
end;

procedure Require(const ACond: Boolean; const AMsg: string);
begin
  if not ACond then
  begin
    WriteLn('FAIL: ', AMsg);
    Halt(1);
  end;
end;

procedure DemoMutexAndCondVar;
var
  LM: INativeMutex;
  LCv: ICondVar;
  LGuard: ILockGuard;
begin
  LM := Mutex;
  LCv := CondVar;
  LGuard := LM.Lock;
  Require(not LM.TryAcquire, 'mutex held by guard');
  LGuard := nil;
  Require(LM.TryAcquire, 'mutex free after guard');
  LM.Release;

  LM.Acquire;
  Require(not LCv.WaitTimeout(LM, TDuration.FromMilliseconds(1)),
    'condvar timeout without signal');
  LM.Release;
end;

procedure DemoWaitGroup;
var
  LWg: IWaitGroup;
  LThreads: array[0..3] of TProcWorker;
  LI: Integer;
begin
  LWg := WaitGroup;
  GWgHits := 0;
  LWg.Add(4);
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TProcWorker.Create(procedure
    begin
      InterlockedIncrement(GWgHits);
      LWg.Done;
    end);
    LThreads[LI].Start;
  end;
  LWg.Wait;
  Require(GWgHits = 4, 'waitgroup all done');
  for LI := 0 to 3 do
  begin
    LThreads[LI].WaitFor;
    LThreads[LI].Free;
  end;
end;

procedure DemoOnceAndEvent;
var
  LOnce: IOnce;
  LEv: IEvent;
  LI: Integer;
begin
  LOnce := Once;
  GOnceHits := 0;
  for LI := 1 to 5 do
    LOnce.DoOnce(@OnceMark);
  Require(GOnceHits = 1, 'once runs once');
  Require(LOnce.Done, 'once done');

  LEv := Event(False);
  Require(not LEv.IsSet, 'event initially unset');
  LEv.SetEvent;
  Require(LEv.WaitTimeout(TDuration.FromMilliseconds(1)), 'event wait after set');
  Require(not LEv.IsSet, 'auto-reset consumed');
end;

procedure DemoSpinLock;
var
  LS: ISpinLock;
  LG: ILockGuard;
begin
  LS := SpinLock;
  LG := LS.Lock;
  Require(not LS.TryAcquire, 'spinlock held');
  LG := nil;
  Require(LS.TryAcquire, 'spinlock free');
  LS.Release;
end;

procedure DemoP3;
var
  LLatch: ILatch;
  LNotify: INotify;
  LCh: IChannel;
  LP: Pointer;
  LRec: INativeMutex;
begin
  LLatch := Latch(1);
  LLatch.CountDown;
  Require(LLatch.TryWait, 'latch open');

  LNotify := Notify;
  LNotify.NotifyOne;
  LNotify.Wait;

  LCh := Channel(1);
  Require(LCh.Send(Pointer(1)), 'channel send');
  Require(LCh.Recv(LP), 'channel recv');
  Require(PtrUInt(LP) = 1, 'channel value');

  LRec := RecursiveMutex;
  LRec.Acquire;
  LRec.Acquire;
  LRec.Release;
  LRec.Release;

  WithLock(Mutex, procedure
  begin
    { scoped ok }
  end);
end;

begin
  WriteLn('sync-basics=ready');
  DemoMutexAndCondVar;
  WriteLn('  mutex+condvar=ok');
  DemoWaitGroup;
  WriteLn('  waitgroup=ok');
  DemoOnceAndEvent;
  WriteLn('  once+event=ok');
  DemoSpinLock;
  WriteLn('  spinlock=ok');
  DemoP3;
  WriteLn('  p3 latch/notify/channel/recursive/scoped=ok');
  WriteLn('sync-basics-status=pass');
end.
