program bench_sync;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.bench,
  nextpas.core.sync;

var
  B: TBenchRunner;
  GSink: Int64;

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

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.sync benchmark (uncontended) ===');
  WriteLn;
  B.Run('Mutex Lock/Unlock', @BenchMutexLockUnlock);
  B.Run('FutexMutex Lock/Unlock', @BenchFutexMutexLockUnlock);
  B.Run('SpinLock Lock/Unlock', @BenchSpinLockLockUnlock);
  B.Run('RWLock ReadLock/Unlock', @BenchRWLockReadLock);
  B.Run('RWLock WriteLock/Unlock', @BenchRWLockWriteLock);
  B.Run('Mutex TryAcquire', @BenchMutexTryAcquire);
  WriteLn;
  B.Summary;
  B.Free;
end.
