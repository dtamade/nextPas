{**
 * nextpas.core.sync consumer smoke (L1 facade).
 *
 * Demonstrates Mutex/INativeMutex + CondVar, WaitGroup, Once, Event,
 * and SpinLock guard without depending on FPC SyncObjs.
 *}
program sync_basics;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.thread.init,
  nextpas.core.sync;

var
  GOnceHits: Int32;
  GWgHits: Int32;

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
  Require(not LCv.WaitTimeout(LM, 1000000), 'condvar timeout without signal');
  LM.Release;
end;

procedure DemoWaitGroup;
var
  LWg: IWaitGroup;
  LThreads: array[0..3] of TThread;
  LI: Integer;
begin
  LWg := WaitGroup;
  GWgHits := 0;
  LWg.Add(4);
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TThread.CreateAnonymousThread(procedure
    begin
      InterlockedIncrement(GWgHits);
      LWg.Done;
    end);
    LThreads[LI].FreeOnTerminate := False;
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
    LOnce.Do_(@OnceMark);
  Require(GOnceHits = 1, 'once runs once');
  Require(LOnce.Done, 'once done');

  LEv := Event(False);
  Require(not LEv.IsSet, 'event initially unset');
  LEv.SetEvent;
  Require(LEv.WaitTimeout(1000000), 'event wait after set');
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
  WriteLn('sync-basics-status=pass');
end.
