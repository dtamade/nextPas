program test_sync;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.testing,
  nextpas.core.sync;

var
  T: TTestRunner;

type
  TSignalOnReleaseMutex = class(TInterfacedObject, ILock, IMutex)
  private
    FCondVar: ICondVar;
    FReleased: Boolean;
  public
    constructor Create(const ACondVar: ICondVar);
    procedure Acquire;
    function TryAcquire: Boolean;
    procedure Release;
    function Lock: ILockGuard;
    property Released: Boolean read FReleased;
  end;

constructor TSignalOnReleaseMutex.Create(const ACondVar: ICondVar);
begin
  inherited Create;
  FCondVar := ACondVar;
  FReleased := False;
end;

procedure TSignalOnReleaseMutex.Acquire;
begin
end;

function TSignalOnReleaseMutex.TryAcquire: Boolean;
begin
  Result := True;
end;

procedure TSignalOnReleaseMutex.Release;
begin
  FReleased := True;
  FCondVar.Signal;
end;

function TSignalOnReleaseMutex.Lock: ILockGuard;
begin
  Result := nil;
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
  LThread: TThread;
begin
  LM := FutexMutex;
  LCounter := 0;

  LM.Acquire;

  LThread := TThread.CreateAnonymousThread(procedure
  begin
    LM.Acquire;
    InterlockedIncrement(LCounter);
    LM.Release;
  end);
  LThread.FreeOnTerminate := False;
  LThread.Start;

  Sleep(10);
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
  LThread: TThread;
begin
  LWg := WaitGroup;
  LDone := 0;

  LWg.Add(1);
  LThread := TThread.CreateAnonymousThread(procedure
  begin
    Sleep(5);
    InterlockedIncrement(LDone);
    LWg.Done;
  end);
  LThread.FreeOnTerminate := False;
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
  LThreads: array[0..3] of TThread;
begin
  LWg := WaitGroup;
  LCounter := 0;

  LWg.Add(4);
  for LI := 0 to 3 do
  begin
    LThreads[LI] := TThread.CreateAnonymousThread(procedure
    begin
      Sleep(2);
      InterlockedIncrement(LCounter);
      LWg.Done;
    end);
    LThreads[LI].FreeOnTerminate := False;
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
  LMutex: TSignalOnReleaseMutex;
begin
  LCond := CondVar;
  LMutex := TSignalOnReleaseMutex.Create(LCond);

  Check(LCond.WaitTimeout(LMutex, 20000000),
    'condvar wait must observe a signal sent while releasing the caller mutex');
  Check(LMutex.Released, 'test mutex must be released before waiting');
end;

begin
  T := TTestRunner.Create('nextpas.core.sync');
  T.Run('Mutex basic', @TestMutexBasic);
  T.Run('Mutex tryacquire', @TestMutexTryAcquire);
  T.Run('Mutex guard (RAII)', @TestMutexGuard);
  T.Run('FutexMutex basic', @TestFutexMutexBasic);
  T.Run('FutexMutex tryacquire', @TestFutexMutexTryAcquire);
  T.Run('FutexMutex contention', @TestFutexMutexContention);
  T.Run('RWLock basic', @TestRWLockBasic);
  T.Run('RWLock guard (RAII)', @TestRWLockGuard);
  T.Run('WaitGroup basic', @TestWaitGroupBasic);
  T.Run('WaitGroup multiple', @TestWaitGroupMultiple);
  T.Run('CondVar does not lose signal during release', @TestCondVarDoesNotLoseSignalDuringRelease);
  T.Summary;
end.
