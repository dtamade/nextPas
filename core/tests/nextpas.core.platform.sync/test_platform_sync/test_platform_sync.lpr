program test_platform_sync;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.platform.thread,
  nextpas.core.platform.sync;

var
  T: TTestSuite;

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
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  platform_mutex_init(LMutex);
  platform_condvar_init(LCond);
  LState.Mutex := @LMutex;
  LState.Cond := @LCond;
  LState.Ready := 0;
  LState.WaitRet := WAIT_PENDING;

  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(platform_thread_create(LHandle, @CondWaitThread, @LState)),
    'create waiter');
  platform_mutex_unlock(LMutex);

  WaitForReady(LState.Ready, 'condvar waiter');
  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(platform_condvar_signal(LCond)), 'signal');
  platform_mutex_unlock(LMutex);

  CheckEqual(Int64(0), Int64(platform_thread_join(LHandle, LRetVal)), 'join waiter');
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
  LHandle1: TPlatformThreadHandle;
  LHandle2: TPlatformThreadHandle;
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
  CheckEqual(Int64(0), Int64(platform_thread_create(LHandle1, @CondWaitThread, @LState1)),
    'create first waiter');
  CheckEqual(Int64(0), Int64(platform_thread_create(LHandle2, @CondWaitThread, @LState2)),
    'create second waiter');
  platform_mutex_unlock(LMutex);

  WaitForReady(LState1.Ready, 'first condvar waiter');
  WaitForReady(LState2.Ready, 'second condvar waiter');
  platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(platform_condvar_broadcast(LCond)), 'broadcast');
  platform_mutex_unlock(LMutex);

  CheckEqual(Int64(0), Int64(platform_thread_join(LHandle1, LRetVal)), 'join first waiter');
  CheckEqual(Int64(0), Int64(platform_thread_join(LHandle2, LRetVal)), 'join second waiter');
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
  LRet := platform_wait_address32(nil, 0, 0);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'nil wait address should be invalid');

  LRet := platform_wake_address_one(nil);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'nil wake-one address should be invalid');

  LRet := platform_wake_address_all(nil);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'nil wake-all address should be invalid');

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
  LHandle: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  LValue := 0;
  LState.Value := @LValue;
  LState.Ready := 0;
  LState.WaitRet := WAIT_PENDING;

  CheckEqual(Int64(0), Int64(platform_thread_create(LHandle, @AddressWaitThread, @LState)),
    'create waiter');
  WaitForReady(LState.Ready, 'address waiter');
  WakeOneUntilDone(@LValue, LState, 'wake one should release waiter');
  CheckEqual(Int64(0), Int64(platform_thread_join(LHandle, LRetVal)), 'join waiter');
end;

procedure TestAddressWakeAllReleasesWaiters;
var
  LValue: Int32;
  LState1: TAddressWaitState;
  LState2: TAddressWaitState;
  LHandle1: TPlatformThreadHandle;
  LHandle2: TPlatformThreadHandle;
  LRetVal: Pointer;
begin
  LValue := 0;
  LState1.Value := @LValue;
  LState1.Ready := 0;
  LState1.WaitRet := WAIT_PENDING;
  LState2 := LState1;

  CheckEqual(Int64(0), Int64(platform_thread_create(LHandle1, @AddressWaitThread, @LState1)),
    'create first waiter');
  CheckEqual(Int64(0), Int64(platform_thread_create(LHandle2, @AddressWaitThread, @LState2)),
    'create second waiter');
  WaitForReady(LState1.Ready, 'first address waiter');
  WaitForReady(LState2.Ready, 'second address waiter');
  WakeAllUntilDone(@LValue, LState1, LState2);
  CheckEqual(Int64(0), Int64(platform_thread_join(LHandle1, LRetVal)), 'join first waiter');
  CheckEqual(Int64(0), Int64(platform_thread_join(LHandle2, LRetVal)), 'join second waiter');
end;
{$ENDIF}

procedure TestAddress64Basic;
var
  LValue: Int64;
  LRet: Int32;
begin
  LRet := platform_wait_address64(nil, 0, 0);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'nil wait address64 should be invalid');

  LRet := platform_wake_address_one64(nil);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'nil wake-one address64 should be invalid');

  LRet := platform_wake_address_all64(nil);
  CheckEqual(Int64(PLATFORM_ERR_INVALID), Int64(LRet),
    'nil wake-all address64 should be invalid');

  LValue := 42;

  // value != expected: should return EAGAIN immediately
  LRet := platform_wait_address64(@LValue, 99, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet),
    'wait64 should return EAGAIN when value <> expected');

  // value = expected, no wake: should timeout
  LRet := platform_wait_address64(@LValue, 42, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'wait64 should timeout when value = expected and no wake');

  LRet := platform_wake_address_one64(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake one 64');

  LRet := platform_wake_address_all64(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake all 64');
end;

procedure TestAddress64LargeValues;
var
  LValue: Int64;
  LRet: Int32;
begin
  // Test with values that don't fit in 32 bits
  LValue := $100000000; // 2^32
  LRet := platform_wait_address64(@LValue, 0, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_AGAIN), Int64(LRet),
    'wait64 with large value mismatch returns EAGAIN');

  LValue := High(Int64);
  LRet := platform_wait_address64(@LValue, High(Int64), 1000000);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'wait64 with max int64 times out');

  LRet := platform_wake_address_one64(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake one 64 max value');

  LRet := platform_wake_address_all64(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake all 64 max value');
end;

{ Error path tests }
procedure TestMutexUnlockWhenNotLocked;
var
  LMutex: TPlatformMutex;
  LRet: Int32;
begin
  platform_mutex_init(LMutex, PLATFORM_MUTEX_ERRORCHECK);

  { Unlock on error-check mutex when not locked should return error }
  LRet := platform_mutex_unlock(LMutex);
  Check(LRet <> 0, 'unlock when not locked returns error');

  platform_mutex_destroy(LMutex);
end;

procedure TestMutexTryLockWhenAlreadyLocked;
var
  LMutex: TPlatformMutex;
  LRet: Int32;
begin
  platform_mutex_init(LMutex, PLATFORM_MUTEX_ERRORCHECK);

  LRet := platform_mutex_lock(LMutex);
  CheckEqual(Int64(0), Int64(LRet), 'lock');

  { Try lock on error-check mutex when already locked should return busy }
  LRet := platform_mutex_trylock(LMutex);
  CheckEqual(Int64(PLATFORM_ERR_BUSY), Int64(LRet), 'trylock when locked returns busy');

  platform_mutex_unlock(LMutex);
  platform_mutex_destroy(LMutex);
end;

procedure TestRwLockTryRdLockWhenWriteLocked;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  platform_rwlock_init(LRwLock);

  LRet := platform_rwlock_wrlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'wrlock');

  { Try rdlock when write locked should fail }
  LRet := platform_rwlock_tryrdlock(LRwLock);
  Check(LRet <> 0, 'tryrdlock when write locked fails');

  platform_rwlock_wrunlock(LRwLock);
  platform_rwlock_destroy(LRwLock);
end;

procedure TestRwLockTryWrLockWhenReadLocked;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  platform_rwlock_init(LRwLock);

  LRet := platform_rwlock_rdlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'rdlock');

  { Try wrlock when read locked should fail }
  LRet := platform_rwlock_trywrlock(LRwLock);
  Check(LRet <> 0, 'trywrlock when read locked fails');

  platform_rwlock_rdunlock(LRwLock);
  platform_rwlock_destroy(LRwLock);
end;

procedure TestCondVarTimedWaitTimeout;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LRet: Int32;
begin
  platform_mutex_init(LMutex);
  platform_condvar_init(LCond);

  platform_mutex_lock(LMutex);

  { Timed wait with 1ms timeout should return timeout }
  LRet := platform_condvar_timedwait(LCond, LMutex, 1000000);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet), 'timedwait 1ms returns timeout');

  platform_mutex_unlock(LMutex);
  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;

procedure TestCondVarTimedWaitZeroTimeout;
var
  LMutex: TPlatformMutex;
  LCond: TPlatformCondVar;
  LRet: Int32;
begin
  platform_mutex_init(LMutex);
  platform_condvar_init(LCond);

  platform_mutex_lock(LMutex);

  { Timed wait with 0 timeout should return timeout immediately }
  LRet := platform_condvar_timedwait(LCond, LMutex, 0);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet), 'timedwait 0 returns timeout');

  platform_mutex_unlock(LMutex);
  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;

procedure TestAddressWaitZeroTimeout;
var
  LValue: Int32;
  LRet: Int32;
begin
  LValue := 42;

  { Wait with 0 timeout should poll and return timeout when value = expected }
  LRet := platform_wait_address32(@LValue, 42, 0);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'wait32 with 0 timeout returns timeout when value = expected');
end;

procedure TestAddress64WaitZeroTimeout;
var
  LValue: Int64;
  LRet: Int32;
begin
  LValue := 42;

  { Wait with 0 timeout should poll and return timeout when value = expected }
  LRet := platform_wait_address64(@LValue, 42, 0);
  CheckEqual(Int64(PLATFORM_ERR_TIMEOUT), Int64(LRet),
    'wait64 with 0 timeout returns timeout when value = expected');
end;

procedure TestBarrierBasic;
var
  LBarrier: TPlatformBarrier;
  LRet: Int32;
begin
  LRet := platform_barrier_init(LBarrier, 1);
  CheckEqual(Int64(0), Int64(LRet), 'barrier_init(1) succeeds');

  LRet := platform_barrier_wait(LBarrier);
  CheckEqual(Int64(0), Int64(LRet), 'barrier_wait with count=1 returns immediately');

  LRet := platform_barrier_destroy(LBarrier);
  CheckEqual(Int64(0), Int64(LRet), 'barrier_destroy succeeds');
end;

type
  TBarrierState = record
    Barrier: Pointer;
    Ready: Int32;
    WaitRet: Int32;
  end;

function BarrierThread(AArg: Pointer): Pointer; cdecl;
var
  LState: ^TBarrierState;
begin
  LState := Pointer(AArg);
  InterLockedExchange(LState^.Ready, 1);
  LState^.WaitRet := platform_barrier_wait(TPlatformBarrier(LState^.Barrier^));
  Result := nil;
end;

procedure TestBarrierMultiThread;
var
  LBarrier: TPlatformBarrier;
  LState: array[0..2] of TBarrierState;
  LHandles: array[0..2] of TPlatformThreadHandle;
  LRetVal: Pointer;
  LRet: Int32;
  LI: Integer;
begin
  LRet := platform_barrier_init(LBarrier, 4); { 3 threads + main }
  CheckEqual(Int64(0), Int64(LRet), 'barrier_init(4)');

  for LI := 0 to 2 do
  begin
    LState[LI].Barrier := @LBarrier;
    LState[LI].Ready := 0;
    LState[LI].WaitRet := -1;
    CheckEqual(Int64(0), Int64(platform_thread_create(LHandles[LI], @BarrierThread, @LState[LI])),
      'create barrier thread');
  end;

  { Wait for all threads to be ready }
  for LI := 0 to 2 do
    WaitForReady(LState[LI].Ready, 'barrier thread ready');

  { Main thread also waits on barrier - this should release all }
  LRet := platform_barrier_wait(LBarrier);
  CheckEqual(Int64(0), Int64(LRet), 'main barrier_wait');

  for LI := 0 to 2 do
  begin
    CheckEqual(Int64(0), Int64(platform_thread_join(LHandles[LI], LRetVal)),
      'join barrier thread');
    CheckEqual(Int64(0), Int64(LState[LI].WaitRet),
      'barrier thread wait returned 0');
  end;

  platform_barrier_destroy(LBarrier);
end;

procedure TestBarrierInvalidCount;
var
  LBarrier: TPlatformBarrier;
  LRet: Int32;
begin
  LRet := platform_barrier_init(LBarrier, 0);
  Check(LRet <> 0, 'barrier_init(0) fails');

  LRet := platform_barrier_init(LBarrier, -1);
  Check(LRet <> 0, 'barrier_init(-1) fails');
end;

var
  GOnceCounter: Int32 = 0;

procedure OnceCallback; cdecl;
begin
  InterLockedIncrement(GOnceCounter);
end;

procedure TestOnceBasic;
var
  LOnce: TPlatformOnce;
  LRet: Int32;
begin
  GOnceCounter := 0;
  LRet := platform_once_init(LOnce);
  CheckEqual(Int64(0), Int64(LRet), 'once_init succeeds');

  LRet := platform_once_exec(LOnce, @OnceCallback);
  CheckEqual(Int64(0), Int64(LRet), 'once_exec first call');
  CheckEqual(Int64(1), Int64(GOnceCounter), 'callback called once');

  LRet := platform_once_exec(LOnce, @OnceCallback);
  CheckEqual(Int64(0), Int64(LRet), 'once_exec second call');
  CheckEqual(Int64(1), Int64(GOnceCounter), 'callback still called once');

  LRet := platform_once_destroy(LOnce);
  CheckEqual(Int64(0), Int64(LRet), 'once_destroy succeeds');
end;

procedure TestOnceNilCallback;
var
  LOnce: TPlatformOnce;
  LRet: Int32;
begin
  LRet := platform_once_init(LOnce);
  CheckEqual(Int64(0), Int64(LRet), 'once_init');

  LRet := platform_once_exec(LOnce, nil);
  Check(LRet <> 0, 'once_exec(nil) fails');

  platform_once_destroy(LOnce);
end;

begin
  T := TTestSuite.Create('nextpas.core.platform.sync');
  T.Test('Public error constants', @TestPublicErrorConstants);
  T.Test('Mutex basic', @TestMutexBasic);
  T.Test('Mutex trylock', @TestMutexTryLock);
  T.Test('Mutex error-check trylock', @TestMutexErrorCheckTryLock);
  T.Test('Mutex recursive', @TestMutexRecursive);
  T.Test('RwLock basic', @TestRwLockBasic);
  T.Test('RwLock write blocked by reader', @TestRwLockWriteBlockedByReader);
  T.Test('RwLock read blocked by writer', @TestRwLockReadBlockedByWriter);
  T.Test('CondVar basic', @TestCondVarBasic);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('CondVar signal wakes waiter', @TestCondVarSignalWakesWaiter);
  T.Test('CondVar broadcast wakes waiters', @TestCondVarBroadcastWakesWaiters);
  {$ENDIF}
  T.Test('Address wait', @TestAddressWait);
  {$IFDEF NEXTPAS_LINUX}
  T.Test('Address wake one releases waiter', @TestAddressWakeOneReleasesWaiter);
  T.Test('Address wake all releases waiters', @TestAddressWakeAllReleasesWaiters);
  {$ENDIF}
  T.Test('Address64 basic', @TestAddress64Basic);
  T.Test('Address64 large values', @TestAddress64LargeValues);
  T.Test('Mutex unlock when not locked', @TestMutexUnlockWhenNotLocked);
  T.Test('Mutex trylock when already locked', @TestMutexTryLockWhenAlreadyLocked);
  T.Test('RwLock tryrdlock when write locked', @TestRwLockTryRdLockWhenWriteLocked);
  T.Test('RwLock trywrlock when read locked', @TestRwLockTryWrLockWhenReadLocked);
  T.Test('CondVar timedwait timeout', @TestCondVarTimedWaitTimeout);
  T.Test('CondVar timedwait zero timeout', @TestCondVarTimedWaitZeroTimeout);
  T.Test('Address wait zero timeout', @TestAddressWaitZeroTimeout);
  T.Test('Address64 wait zero timeout', @TestAddress64WaitZeroTimeout);
  T.Test('Barrier basic', @TestBarrierBasic);
  T.Test('Barrier multi-thread', @TestBarrierMultiThread);
  T.Test('Barrier invalid count', @TestBarrierInvalidCount);
  T.Test('Once basic', @TestOnceBasic);
  T.Test('Once nil callback', @TestOnceNilCallback);
  if not T.Run then Halt(1);
end.
