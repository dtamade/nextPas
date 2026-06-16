program test_platform_sync_stress;

{ nextPas Platform Sync — stress + edge-case test
  Multi-threaded contention, timeout behavior, signal/broadcast edge cases }

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes,
  nextpas.core.testing,
  nextpas.core.platform.sync,
  nextpas.core.platform.time;

type
  TCounterThread = class(TThread)
    FMutex: Pointer;
    FCounter: PInt64;
    procedure Execute; override;
  end;

  TReaderThread = class(TThread)
    FRwLock: Pointer;
    FValue: PInt64;
    FDone: PBoolean;
    FTornReads: Integer;
    procedure Execute; override;
  end;

  TWriterThread = class(TThread)
    FRwLock: Pointer;
    FValue: PInt64;
    FDone: PBoolean;
    procedure Execute; override;
  end;

  TWaiterThread = class(TThread)
    FMutex: Pointer;
    FCond: Pointer;
    FReady: PInteger;
    FWoke: Boolean;
    procedure Execute; override;
  end;

var
  T: TTestRunner;

procedure TCounterThread.Execute;
var
  I: Integer;
  PM: ^TPlatformMutex;
begin
  PM := FMutex;
  for I := 0 to 9999 do
  begin
    platform_mutex_lock(PM^);
    Inc(FCounter^);
    platform_mutex_unlock(PM^);
  end;
end;

procedure TReaderThread.Execute;
var
  LV1, LV2: Int64;
  PR: ^TPlatformRwLock;
begin
  PR := FRwLock;
  FTornReads := 0;
  while not FDone^ do
  begin
    platform_rwlock_rdlock(PR^);
    LV1 := FValue^;
    LV2 := FValue^;
    platform_rwlock_rdunlock(PR^);
    if LV1 <> LV2 then
      Inc(FTornReads);
  end;
end;

procedure TWriterThread.Execute;
var
  I: Integer;
  PR: ^TPlatformRwLock;
begin
  PR := FRwLock;
  for I := 1 to 5000 do
  begin
    platform_rwlock_wrlock(PR^);
    FValue^ := I;
    FValue^ := I;
    platform_rwlock_wrunlock(PR^);
  end;
  FDone^ := True;
end;

procedure TWaiterThread.Execute;
var
  PM: ^TPlatformMutex;
  PC: ^TPlatformCondVar;
begin
  PM := FMutex;
  PC := FCond;
  platform_mutex_lock(PM^);
  while FReady^ = 0 do
    platform_condvar_wait(PC^, PM^);
  Dec(FReady^);
  FWoke := True;
  platform_mutex_unlock(PM^);
end;

{ 1. Mutex: 4 threads x 10k lock/unlock, shared counter must be exact }
procedure TestMutexContendedCounter;
const
  NUM_THREADS = 4;
var
  LMutex: TPlatformMutex;
  LCounter: Int64;
  LThreads: array[0..NUM_THREADS - 1] of TThread;
  I: Integer;
begin
  Check(platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) = 0, 'mutex init');
  LCounter := 0;

  for I := 0 to NUM_THREADS - 1 do
  begin
    LThreads[I] := TCounterThread.Create(True);
    TCounterThread(LThreads[I]).FMutex := @LMutex;
    TCounterThread(LThreads[I]).FCounter := @LCounter;
    LThreads[I].Start;
  end;

  for I := 0 to NUM_THREADS - 1 do
    LThreads[I].WaitFor;
  for I := 0 to NUM_THREADS - 1 do
    LThreads[I].Free;

  Check(LCounter = Int64(NUM_THREADS) * 10000,
    'contended counter = ' + IntToStr(LCounter));
  platform_mutex_destroy(LMutex);
end;

{ 2. RwLock: 4 readers + 1 writer, verify no torn reads }
procedure TestRwLockReadersWriter;
const
  NUM_READERS = 4;
var
  LRwLock: TPlatformRwLock;
  LSharedValue: Int64;
  LWriteDone: Boolean;
  LReaders: array[0..NUM_READERS - 1] of TThread;
  LWriter: TWriterThread;
  I, LTornTotal: Integer;
begin
  Check(platform_rwlock_init(LRwLock) = 0, 'rwlock init');
  LSharedValue := 0;
  LWriteDone := False;

  for I := 0 to NUM_READERS - 1 do
  begin
    LReaders[I] := TReaderThread.Create(True);
    TReaderThread(LReaders[I]).FRwLock := @LRwLock;
    TReaderThread(LReaders[I]).FValue := @LSharedValue;
    TReaderThread(LReaders[I]).FDone := @LWriteDone;
    LReaders[I].Start;
  end;

  LWriter := TWriterThread.Create(True);
  LWriter.FRwLock := @LRwLock;
  LWriter.FValue := @LSharedValue;
  LWriter.FDone := @LWriteDone;
  LWriter.Start;

  LWriter.WaitFor;
  LWriter.Free;

  LTornTotal := 0;
  for I := 0 to NUM_READERS - 1 do
  begin
    LReaders[I].WaitFor;
    Inc(LTornTotal, TReaderThread(LReaders[I]).FTornReads);
    LReaders[I].Free;
  end;

  Check(LTornTotal = 0, 'no torn reads (torn=' + IntToStr(LTornTotal) + ')');
  Check(LSharedValue = 5000, 'final value = ' + IntToStr(LSharedValue));
  platform_rwlock_destroy(LRwLock);
end;

{ 3. Condvar: signal wakes exactly one waiter }
procedure TestCondvarSignalOne;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LReady: Integer;
  LThreads: array[0..1] of TThread;
  I, LWokeCount: Integer;
begin
  Check(platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) = 0, 'mutex init');
  Check(platform_condvar_init(LCond) = 0, 'condvar init');
  LReady := 0;
  LWokeCount := 0;

  for I := 0 to 1 do
  begin
    LThreads[I] := TWaiterThread.Create(True);
    TWaiterThread(LThreads[I]).FMutex := @LMutex;
    TWaiterThread(LThreads[I]).FCond := @LCond;
    TWaiterThread(LThreads[I]).FReady := @LReady;
    TWaiterThread(LThreads[I]).FWoke := False;
    LThreads[I].Start;
  end;

  Sleep(50);

  platform_mutex_lock(LMutex);
  LReady := 2; { both waiters should proceed }
  platform_condvar_broadcast(LCond);
  platform_mutex_unlock(LMutex);

  for I := 0 to 1 do
  begin
    LThreads[I].WaitFor;
    if TWaiterThread(LThreads[I]).FWoke then
      Inc(LWokeCount);
    LThreads[I].Free;
  end;

  Check(LWokeCount = 2, 'both threads woke from broadcast (woke=' + IntToStr(LWokeCount) + ')');

  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;

{ 4. Address-wait: value mismatch returns immediately }
procedure TestWaitAddressValueMismatch;
var
  LVal: Int32;
  LRet: Int32;
begin
  LVal := 0;
  { Wait for LVal to equal 1 — it's 0, so returns immediately }
  LRet := platform_wait_address32(@LVal, 1, 50000000);
  Check(LRet <> 0, 'wait_address32 value mismatch returns error (ret=' + IntToStr(LRet) + ')');
end;

{ 5. Address-wait 64-bit: value mismatch returns immediately }
procedure TestWaitAddress64ValueMismatch;
var
  LVal: Int64;
  LRet: Int32;
begin
  LVal := 0;
  LRet := platform_wait_address64(@LVal, 1, 50000000);
  Check(LRet <> 0, 'wait_address64 value mismatch returns error (ret=' + IntToStr(LRet) + ')');
end;

{ 6. Mutex trylock on locked mutex returns immediately }
procedure TestMutexTrylockContended;
var
  LMutex: TPlatformMutex;
begin
  Check(platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) = 0, 'mutex init');
  Check(platform_mutex_lock(LMutex) = 0, 'lock');
  Check(platform_mutex_trylock(LMutex) = PLATFORM_ERR_BUSY, 'trylock on locked returns BUSY');
  Check(platform_mutex_unlock(LMutex) = 0, 'unlock');
  Check(platform_mutex_trylock(LMutex) = 0, 'trylock on unlocked succeeds');
  Check(platform_mutex_unlock(LMutex) = 0, 'unlock');
  platform_mutex_destroy(LMutex);
end;

{ 7. Stress: rapid mutex init/destroy cycle }
procedure TestMutexInitDestroyStress;
const
  ITERS = 10000;
var
  LMutex: TPlatformMutex;
  I: Integer;
begin
  for I := 0 to ITERS - 1 do
  begin
    Check(platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) = 0, 'init');
    platform_mutex_lock(LMutex);
    platform_mutex_unlock(LMutex);
    Check(platform_mutex_destroy(LMutex) = 0, 'destroy');
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.stress');

  T.Run('mutex contended counter (4 threads x 10k)', @TestMutexContendedCounter);
  T.Run('rwlock readers+writer no torn reads', @TestRwLockReadersWriter);
  T.Run('condvar signal wakes one waiter', @TestCondvarSignalOne);
  T.Run('wait_address32 value mismatch', @TestWaitAddressValueMismatch);
  T.Run('wait_address64 value mismatch', @TestWaitAddress64ValueMismatch);
  T.Run('mutex trylock contended returns BUSY', @TestMutexTrylockContended);
  T.Run('mutex init/destroy stress (10k cycles)', @TestMutexInitDestroyStress);

  T.Summary;
end.
