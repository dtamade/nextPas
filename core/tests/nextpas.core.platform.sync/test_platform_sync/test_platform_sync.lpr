program test_platform_sync;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

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

procedure TestRwLockBasic;
var
  LRwLock: TPlatformRwLock;
  LRet: Int32;
begin
  LRet := platform_rwlock_init(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'init');

  LRet := platform_rwlock_rdlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'rdlock');

  LRet := platform_rwlock_unlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'unlock rd');

  LRet := platform_rwlock_wrlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'wrlock');

  LRet := platform_rwlock_unlock(LRwLock);
  CheckEqual(Int64(0), Int64(LRet), 'unlock wr');

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
  Check(LRet <> 0, 'timedwait should timeout (1ms)');
  platform_mutex_unlock(LMutex);

  LRet := platform_condvar_signal(LCond);
  CheckEqual(Int64(0), Int64(LRet), 'signal');

  LRet := platform_condvar_broadcast(LCond);
  CheckEqual(Int64(0), Int64(LRet), 'broadcast');

  platform_condvar_destroy(LCond);
  platform_mutex_destroy(LMutex);
end;

procedure TestAddressWait;
var
  LValue: Int32;
  LRet: Int32;
begin
  LValue := 42;

  // value != expected: futex returns EAGAIN immediately (not blocked)
  LRet := platform_wait_address32(@LValue, 99, 1000000);
  Check(LRet <> 0, 'wait should return error when value <> expected (EAGAIN)');

  // value = expected, no wake: should timeout
  LRet := platform_wait_address32(@LValue, 42, 1000000);
  Check(LRet <> 0, 'wait should timeout when value = expected and no wake');

  LRet := platform_wake_address_one(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake one');

  LRet := platform_wake_address_all(@LValue);
  CheckEqual(Int64(0), Int64(LRet), 'wake all');
end;

begin
  T := TTestRunner.Create('nextpas.core.platform.sync');
  T.Run('Mutex basic', @TestMutexBasic);
  T.Run('Mutex trylock', @TestMutexTryLock);
  T.Run('RwLock basic', @TestRwLockBasic);
  T.Run('CondVar basic', @TestCondVarBasic);
  T.Run('Address wait', @TestAddressWait);
  T.Summary;
end.
