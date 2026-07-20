program test_sync_freebsd_compile_gate;

{ Forced FreeBSD host compile gate for nextpas.core.sync.
  Syntax/semantic only (-Cn); not FreeBSD runtime evidence. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.sync;

procedure TouchFacade;
var
  LM: INativeMutex;
  LF: IMutex;
  LRW: IRWLock;
  LWg: IWaitGroup;
  LCv: ICondVar;
  LOnce: IOnce;
  LS: ISpinLock;
  LSem: ISemaphore;
  LBar: IBarrier;
  LEv: IEvent;
begin
  LM := Mutex;
  LF := FutexMutex;
  LRW := RWLock;
  LWg := WaitGroup;
  LCv := CondVar;
  LOnce := Once;
  LS := SpinLock;
  LSem := Semaphore(1);
  LBar := Barrier(1);
  LEv := Event(True);
  if (LM = nil) or (LF = nil) or (LRW = nil) or (LWg = nil) or (LCv = nil) or
     (LOnce = nil) or (LS = nil) or (LSem = nil) or (LBar = nil) or (LEv = nil) then
    Halt(1);
end;

begin
  TouchFacade;
end.
