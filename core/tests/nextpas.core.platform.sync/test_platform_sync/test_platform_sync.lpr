program test_platform_sync;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  {$IFDEF NEXTPAS_LINUX}nextpas.core.platform.posix.ffi,{$ENDIF}
  nextpas.core.testing,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

const
  WAIT_PENDING = -999999;

{$IFDEF NEXTPAS_LINUX}
type
  PCondWaitState = ^TCondWaitState;
  TCondWaitState = record
    Mutex: ^TPlatformMutex;
    Cond: ^TPlatformCondVar;
    Ready: Int32;
    WaitRet: Int32;
  end;

  PAddressWaitState = ^TAddressWaitState;
  TAddressWaitState = record
    Value: PInt32;
    Ready: Int32;
    WaitRet: Int32;
  end;

procedure WaitOneMs;
var
  LSleep: Int32;
begin
  LSleep := 0;
  platform_wait_address32(@LSleep, 0, 1000000);
end;

procedure WaitForReady(var AReady: Int32; const AName: string);
var
  I: Integer;
begin
  for I := 0 to 99 do
  begin
    if AReady <> 0 then
      Exit;
    platform_wait_address32(@AReady, 0, 10000000);
  end;
  Check(AReady <> 0, AName + ' ready');
end;

function CondWaitThread(AArg: Pointer): Pointer; cdecl;
var
  LState: PCondWaitState;
begin
  LState := PCondWaitState(AArg);
  platform_mutex_lock(LState^.Mutex^);
  LState^.Ready := 1;
  platform_wake_address_all(@LState^.Ready);
  LState^.WaitRet := platform_condvar_wait(LState^.Cond^, LState^.Mutex^);
  platform_mutex_unlock(LState^.Mutex^);
  Result := Pointer(PtrUInt(UInt32(LState^.WaitRet)));
end;

function AddressWaitThread(AArg: Pointer): Pointer; cdecl;
var
  LState: PAddressWaitState;
begin
  LState := PAddressWaitState(AArg);
  LState^.Ready := 1;
  platform_wake_address_all(@LState^.Ready);
  LState^.WaitRet := platform_wait_address32(LState^.Value, 0, 1000000000);
  Result := Pointer(PtrUInt(UInt32(LState^.WaitRet)));
end;

procedure WakeOneUntilDone(AAddr: PInt32; var AState: TAddressWaitState; const AName: string);
var
  I: Integer;
begin
  for I := 0 to 99 do
  begin
    if AState.WaitRet <> WAIT_PENDING then
      Break;
    platform_wake_address_one(AAddr);
    WaitOneMs;
  end;
  CheckEqual(Int64(0), Int64(AState.WaitRet), AName);
end;

procedure WakeAllUntilDone(AAddr: PInt32; var AState1: TAddressWaitState; var AState2: TAddressWaitState);
var
  I: Integer;
begin
  for I := 0 to 99 do
  begin
    if (AState1.WaitRet <> WAIT_PENDING) and (AState2.WaitRet <> WAIT_PENDING) then
      Break;
    platform_wake_address_all(AAddr);
    WaitOneMs;
  end;
  CheckEqual(Int64(0), Int64(AState1.WaitRet), 'wake all first waiter');
  CheckEqual(Int64(0), Int64(AState2.WaitRet), 'wake all second waiter');
end;
{$ENDIF}

procedure TestPublicErrorConstants;
begin
  CheckEqual(Int64(11), Int64(PLATFORM_ERR_AGAIN), 'PLATFORM_ERR_AGAIN');
  CheckEqual(Int64(16), Int64(PLATFORM_ERR_BUSY), 'PLATFORM_ERR_BUSY');
  CheckEqual(Int64(22), Int64(PLATFORM_ERR_INVALID), 'PLATFORM_ERR_INVALID');
  CheckEqual(Int64(95), Int64(PLATFORM_ERR_UNSUPPORTED), 'PLATFORM_ERR_UNSUPPORTED');
  CheckEqual(Int64(110), Int64(PLATFORM_ERR_TIMEOUT), 'PLATFORM_ERR_TIMEOUT');
end;

procedure TestMutexBasic;
var
  LMutex: TPlatformMutex;
  LRet: Int32;
begin
  LRet := platform_mutex_init(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'init');

  LRet := platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'lock');

  LRet := platform_mutex_unlock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'unlock');

  LRet := platform_mutex_destroy(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'destroy');
end;

procedure TestMutexTryLock;
var
  LMutex: TPlatformMutex;
  LRet: Int32;
begin
  platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL);

  LRet := platform_mutex_trylock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'trylock should succeed');

  LRet := platform_mutex_trylock(LMutex);
  Check(LRet <> 0, 'trylock should fail when held');

  platform_mutex_unlock(LMutex);
  platform_mutex_destroy(LMutex);
end;

procedure TestMutexErrorCheckTryLock;
var
  LMutex: TPlatformMutex;
  LRet: Int32;
begin
  platform_mutex_init(LMutex, PLATFORM_MUTEX_ERRORCHECK);

  LRet := platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'lock');

  LRet := platform_mutex_trylock(LMutex);
  CheckEqual(Int64(PLATFORM_ERR_BUSY), Int64(LRet),
    'error-check trylock should report busy when held');

  platform_mutex_unlock(LMutex);
  platform_mutex_destroy(LMutex);
end;

procedure TestMutexRecursive;
var
  LMutex: TPlatformMutex;
  LRet: Int32;
begin
  platform_mutex_init(LMutex, PLATFORM_MUTEX_RECURSIVE);

  LRet := platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'first lock');

  LRet := platform_mutex_trylock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'recursive trylock');

  LRet := platform_mutex_unlock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'first unlock');

  LRet := platform_mutex_unlock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'second unlock');

  platform_mutex_destroy(LMutex);
end;

procedure TestRwLockBasic;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  LRet := platform_rwlock_init(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'init');

  LRet := platform_rwlock_rdlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'rdlock');

  LRet := platform_rwlock_rdunlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'rdunlock');

  LRet := platform_rwlock_wrlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'wrlock');

  LRet := platform_rwlock_wrunlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'wrunlock');

  LRet := platform_rwlock_destroy(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'destroy');
end;

procedure TestRwLockWriteBlockedByReader;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  LRet := platform_rwlock_init(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'init');

  LRet := platform_rwlock_rdlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'rdlock');

  LRet := platform_rwlock_trywrlock(LRwLock);
  Check(LRet <> 0, 'trywrlock should fail while read lock is held');

  LRet := platform_rwlock_rdunlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'rdunlock');

  LRet := platform_rwlock_destroy(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'destroy');
end;

procedure TestRwLockReadBlockedByWriter;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  LRet := platform_rwlock_init(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'init');

  LRet := platform_rwlock_wrlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'wrlock');

  LRet := platform_rwlock_tryrdlock(LRwLock);
  Check(LRet <> 0, 'tryrdlock should fail while write lock is held');

  LRet := platform_rwlock_wrunlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'wrunlock');

  LRet := platform_rwlock_destroy(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'destroy');
end;

procedure TestCondVarBasic;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LRet: Int32;
begin
  platform_mutex_init(LMutex);
  LRet := platform_condvar_init(LCond);
  CheckEqual(Int64(0), Int64(LRet), 'condvar init');

  platform_mutex_lock(LMutex);
  LRet := platform_condvar_timedwait(LCond, LMutex, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet), 'timedwait should timeout (1ms)');
  platform_mutex_unlock(LMutex);

  LRet := platform_condvar_signal(LCond);
  CheckEqual(Int64(0), Int64(LRet), 'signal');

  LRet := platform_condvar_broadcast(LCond);
  CheckEqual(Int64(0), Int64(LRet), 'broadcast');

  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestCondVarSignalWakesWaiter;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LState: TCondWaitState;
  LHandle: pthread_t;
  LRetVal: Pointer;
begin
  platform_mutex_init(LMutex);
  platform_condvar_init(LCond);
  LState.Mutex := @LMutex;
  LState.Cond := @LCond;
  LState.Ready := 0;
  LState.WaitRet := WAIT_PENDING;

  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(pthread_create(@LHandle, nil, @CondWaitThread, @LState)),
    'create waiter');
  platform_mutex_unlock(LMutex);

  WaitForReady(LState.Ready, 'condvar waiter');
  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(platform_condvar_signal(LCond)), 'signal');
  platform_mutex_unlock(LMutex);

  CheckEqual(Int64(0), Int64(pthread_join(LHandle, @LRetVal)), 'join waiter');
  CheckEqual(Int64(0), Int64(LState.WaitRet), 'waiter should wake from signal');

  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;

procedure TestCondVarBroadcastWakesWaiters;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LState1: TCondWaitState;
  LState2: TCondWaitState;
  LHandle1: pthread_t;
  LHandle2: pthread_t;
  LRetVal: Pointer;
begin
  platform_mutex_init(LMutex);
  platform_condvar_init(LCond);
  LState1.Mutex := @LMutex;
  LState1.Cond := @LCond;
  LState1.Ready := 0;
  LState1.WaitRet := WAIT_PENDING;
  LState2 := LState1;

  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(pthread_create(@LHandle1, nil, @CondWaitThread, @LState1)),
    'create first waiter');
  CheckEqual(Int64(0), Int64(pthread_create(@LHandle2, nil, @CondWaitThread, @LState2)),
    'create second waiter');
  platform_mutex_unlock(LMutex);

  WaitForReady(LState1.Ready, 'first condvar waiter');
  WaitForReady(LState2.Ready, 'second condvar waiter');
  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(platform_condvar_broadcast(LCond)), 'broadcast');
  platform_mutex_unlock(LMutex);

  CheckEqual(Int64(0), Int64(pthread_join(LHandle1, @LRetVal)), 'join first waiter');
  CheckEqual(Int64(0), Int64(pthread_join(LHandle2, @LRetVal)), 'join second waiter');
  CheckEqual(Int64(0), Int64(LState1.WaitRet), 'first waiter should wake');
  CheckEqual(Int64(0), Int64(LState2.WaitRet), 'second waiter should wake');

  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;
{$ENDIF}

procedure TestAddressWait;
var
  LValue: Int32;
  LRet: Int32;
begin
  LValue := 42;

  // value != expected: futex returns EAGAIN immediately (not blocked)
  LRet := platform_wait_address32(@LValue, 99, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet),
    'wait should return EAGAIN when value <> expected');

  LRet := platform_wait_address32(@LValue, 99, -1);
  CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet),
    'negative timeout should still return EAGAIN when value <> expected');

  LRet := platform_wait_address32(@LValue, 42, 0);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'zero timeout should poll and return timeout when value = expected');

  // value = expected, no wake: should timeout
  LRet := platform_wait_address32(@LValue, 42, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'wait should timeout when value = expected and no wake');

  LRet := platform_wake_address_one(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake one');

  LRet := platform_wake_address_all(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake all');
end;

{$IFDEF NEXTPAS_LINUX}
procedure TestAddressWakeOneReleasesWaiter;
var
  LValue: Int32;
  LState: TAddressWaitState;
  LHandle: pthread_t;
  LRetVal: Pointer;
begin
  LValue := 0;
  LState.Value := @LValue;
  LState.Ready := 0;
  LState.WaitRet := WAIT_PENDING;

  CheckEqual(Int64(0), Int64(pthread_create(@LHandle, nil, @AddressWaitThread, @LState)),
    'create waiter');
  WaitForReady(LState.Ready, 'address waiter');
  WakeOneUntilDone(@LValue, LState, 'wake one should release waiter');
  CheckEqual(Int64(0), Int64(pthread_join(LHandle, @LRetVal)), 'join waiter');
end;

procedure TestAddressWakeAllReleasesWaiters;
var
  LValue: Int32;
  LState1: TAddressWaitState;
  LState2: TAddressWaitState;
  LHandle1: pthread_t;
  LHandle2: pthread_t;
  LRetVal: Pointer;
begin
  LValue := 0;
  LState1.Value := @LValue;
  LState1.Ready := 0;
  LState1.WaitRet := WAIT_PENDING;
  LState2 := LState1;

  CheckEqual(Int64(0), Int64(pthread_create(@LHandle1, nil, @AddressWaitThread, @LState1)),
    'create first waiter');
  CheckEqual(Int64(0), Int64(pthread_create(@LHandle2, nil, @AddressWaitThread, @LState2)),
    'create second waiter');
  WaitForReady(LState1.Ready, 'first address waiter');
  WaitForReady(LState2.Ready, 'second address waiter');
  WakeAllUntilDone(@LValue, LState1, LState2);
  CheckEqual(Int64(0), Int64(pthread_join(LHandle1, @LRetVal)), 'join first waiter');
  CheckEqual(Int64(0), Int64(pthread_join(LHandle2, @LRetVal)), 'join second waiter');
end;
{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.sync');
  T.Run('Public error constants', @TestPublicErrorConstants);
  T.Run('Mutex basic', @TestMutexBasic);
  T.Run('Mutex trylock', @TestMutexTryLock);
  T.Run('Mutex error-check trylock', @TestMutexErrorCheckTryLock);
  T.Run('Mutex recursive', @TestMutexRecursive);
  T.Run('RwLock basic', @TestRwLockBasic);
  T.Run('RwLock write blocked by reader', @TestRwLockWriteBlockedByReader);
  T.Run('RwLock read blocked by writer', @TestRwLockReadBlockedByWriter);
  T.Run('CondVar basic', @TestCondVarBasic);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('CondVar signal wakes waiter', @TestCondVarSignalWakesWaiter);
  T.Run('CondVar broadcast wakes waiters', @TestCondVarBroadcastWakesWaiters);
  {$ENDIF}
  T.Run('Address wait', @TestAddressWait);
  {$IFDEF NEXTPAS_LINUX}
  T.Run('Address wake one releases waiter', @TestAddressWakeOneReleasesWaiter);
  T.Run('Address wake all releases waiters', @TestAddressWakeAllReleasesWaiters);
  {$ENDIF}
  T.Summary;
end.
