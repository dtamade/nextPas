program test_platform_sync_stress;

{ nextPas Platform Sync — stress + edge-case test
  Multi-threaded contention, timeout behavior, signal/broadcast edge cases }

{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.platform.sync,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

type
  TCounterState = record
    Mutex: ^TPlatformMutex;
    Counter: PInt64;
  end;

  TReaderState = record
    RwLock: ^TPlatformRwLock;
    Value: PInt64;
    Done: PBoolean;
    TornReads: Integer;
  end;

  TWriterState = record
    RwLock: ^TPlatformRwLock;
    Value: PInt64;
    Done: PBoolean;
  end;

  TWaiterState = record
    Mutex: ^TPlatformMutex;
    Cond: ^TPlatformCondVar;
    Ready: PInteger;
    Woke: Boolean;
  end;

var
  T: TTestSuite;

function CounterThreadProc(AArg: Pointer): Pointer; cdecl;
var
  I: Integer;
  PState: ^TCounterState;
begin
  PState := AArg;
  for I := 0 to 9999 do
  begin
    platform_mutex_lock(PState^.Mutex^);
    Inc(PState^.Counter^);
    platform_mutex_unlock(PState^.Mutex^);
  end;
  Result := nil;
end;

function ReaderThreadProc(AArg: Pointer): Pointer; cdecl;
var
  LV1, LV2: Int64;
  PState: ^TReaderState;
begin
  PState := AArg;
  PState^.TornReads := 0;
  while not PState^.Done^ do
  begin
    platform_rwlock_rdlock(PState^.RwLock^);
    LV1 := PState^.Value^;
    LV2 := PState^.Value^;
    platform_rwlock_rdunlock(PState^.RwLock^);
    if LV1 <> LV2 then
      Inc(PState^.TornReads);
  end;
  Result := nil;
end;

function WriterThreadProc(AArg: Pointer): Pointer; cdecl;
var
  I: Integer;
  PState: ^TWriterState;
begin
  PState := AArg;
  for I := 1 to 5000 do
  begin
    platform_rwlock_wrlock(PState^.RwLock^);
    PState^.Value^ := I;
    PState^.Value^ := I;
    platform_rwlock_wrunlock(PState^.RwLock^);
  end;
  PState^.Done^ := True;
  Result := nil;
end;

function WaiterThreadProc(AArg: Pointer): Pointer; cdecl;
var
  PState: ^TWaiterState;
begin
  PState := AArg;
  platform_mutex_lock(PState^.Mutex^);
  while PState^.Ready^ = 0 do
    platform_condvar_wait(PState^.Cond^, PState^.Mutex^);
  Dec(PState^.Ready^);
  PState^.Woke := True;
  platform_mutex_unlock(PState^.Mutex^);
  Result := nil;
end;

{ 1. Mutex: 4 threads x 10k lock/unlock, shared counter must be exact }
procedure TestMutexContendedCounter;
const
  NUM_THREADS = 4;
var
  LMutex: TPlatformMutex;
  LCounter: Int64;
  LStates: array[0..NUM_THREADS - 1] of TCounterState;
  LThreads: array[0..NUM_THREADS - 1] of TPlatformThreadRecord;
  I: Integer;
begin
  Check(platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) = 0, 'mutex init');
  LCounter := 0;

  for I := 0 to NUM_THREADS - 1 do
  begin
    LStates[I].Mutex := @LMutex;
    LStates[I].Counter := @LCounter;
    Check(platform_thread_spawn(LThreads[I], @CounterThreadProc, @LStates[I]) = 0,
      'spawn counter thread ' + IntToStr(I));
  end;

  for I := 0 to NUM_THREADS - 1 do
    platform_thread_wait(LThreads[I]);

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
  LReaderStates: array[0..NUM_READERS - 1] of TReaderState;
  LWriterState: TWriterState;
  LReaders: array[0..NUM_READERS - 1] of TPlatformThreadRecord;
  LWriter: TPlatformThreadRecord;
  I, LTornTotal: Integer;
begin
  Check(platform_rwlock_init(LRwLock) = 0, 'rwlock init');
  LSharedValue := 0;
  LWriteDone := False;

  for I := 0 to NUM_READERS - 1 do
  begin
    LReaderStates[I].RwLock := @LRwLock;
    LReaderStates[I].Value := @LSharedValue;
    LReaderStates[I].Done := @LWriteDone;
    LReaderStates[I].TornReads := 0;
    Check(platform_thread_spawn(LReaders[I], @ReaderThreadProc, @LReaderStates[I]) = 0,
      'spawn reader thread');
  end;

  LWriterState.RwLock := @LRwLock;
  LWriterState.Value := @LSharedValue;
  LWriterState.Done := @LWriteDone;
  Check(platform_thread_spawn(LWriter, @WriterThreadProc, @LWriterState) = 0,
    'spawn writer thread');

  platform_thread_wait(LWriter);

  LTornTotal := 0;
  for I := 0 to NUM_READERS - 1 do
  begin
    platform_thread_wait(LReaders[I]);
    Inc(LTornTotal, LReaderStates[I].TornReads);
  end;

  Check(LTornTotal = 0, 'no torn reads (torn=' + IntToStr(LTornTotal) + ')');
  Check(LSharedValue = 5000, 'final value = ' + IntToStr(LSharedValue));
  platform_rwlock_destroy(LRwLock);
end;

{ 3. Condvar: broadcast wakes all waiters }
procedure TestCondvarBroadcast;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LReady: Integer;
  LStates: array[0..1] of TWaiterState;
  LThreads: array[0..1] of TPlatformThreadRecord;
  I, LWokeCount: Integer;
begin
  Check(platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) = 0, 'mutex init');
  Check(platform_condvar_init(LCond) = 0, 'condvar init');
  LReady := 0;

  for I := 0 to 1 do
  begin
    LStates[I].Mutex := @LMutex;
    LStates[I].Cond := @LCond;
    LStates[I].Ready := @LReady;
    LStates[I].Woke := False;
    Check(platform_thread_spawn(LThreads[I], @WaiterThreadProc, @LStates[I]) = 0,
      'spawn waiter thread');
  end;

  platform_thread_sleep_ns(50000000); { 50ms }

  platform_mutex_lock(LMutex);
  LReady := 2;
  platform_condvar_broadcast(LCond);
  platform_mutex_unlock(LMutex);

  LWokeCount := 0;
  for I := 0 to 1 do
  begin
    platform_thread_wait(LThreads[I]);
    if LStates[I].Woke then
      Inc(LWokeCount);
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
  T := TTestSuite.Create('nextpas.core.platform.sync.stress');

  T.Test('mutex contended counter (4 threads x 10k)', @TestMutexContendedCounter);
  T.Test('rwlock readers+writer no torn reads', @TestRwLockReadersWriter);
  T.Test('condvar broadcast wakes all waiters', @TestCondvarBroadcast);
  T.Test('wait_address32 value mismatch', @TestWaitAddressValueMismatch);
  T.Test('wait_address64 value mismatch', @TestWaitAddress64ValueMismatch);
  T.Test('mutex trylock contended returns BUSY', @TestMutexTrylockContended);
  T.Test('mutex init/destroy stress (10k cycles)', @TestMutexInitDestroyStress);

  if not T.Run then Halt(1);
end.
