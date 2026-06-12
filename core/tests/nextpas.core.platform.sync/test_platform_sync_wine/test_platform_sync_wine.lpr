program test_platform_sync_wine;

{ Real Windows runtime evidence only when compiled and run on a Windows host.
  NOTE: The recursive mutex test is excluded on Windows because SRWLOCK
  (the Windows mutex backend) does not support recursive locking. The
  platform_mutex_init AKind parameter is silently ignored on Windows. }

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.platform.sync;

var
  T: TTestRunner;

{$IFDEF NEXTPAS_WINDOWS}

{ --- Mutex --- }

{ 1. Mutex init + destroy }
procedure TestMutexInitDestroy;
var
  LMutex: TPlatformMutex;
begin
  CheckEqual(0, platform_mutex_init(LMutex), 'mutex init');
  CheckEqual(0, platform_mutex_destroy(LMutex), 'mutex destroy');
end;

{ 2. Mutex lock + unlock }
procedure TestMutexLockUnlock;
var
  LMutex: TPlatformMutex;
begin
  CheckEqual(0, platform_mutex_init(LMutex), 'mutex init');
  CheckEqual(0, platform_mutex_lock(LMutex), 'mutex lock');
  CheckEqual(0, platform_mutex_unlock(LMutex), 'mutex unlock');
  CheckEqual(0, platform_mutex_destroy(LMutex), 'mutex destroy');
end;

{ 3. Mutex trylock success (when not held) }
procedure TestMutexTrylockSuccess;
var
  LMutex: TPlatformMutex;
begin
  CheckEqual(0, platform_mutex_init(LMutex), 'mutex init');
  CheckEqual(0, platform_mutex_trylock(LMutex), 'trylock should succeed when not held');
  CheckEqual(0, platform_mutex_unlock(LMutex), 'mutex unlock');
  CheckEqual(0, platform_mutex_destroy(LMutex), 'mutex destroy');
end;

{ 4. Mutex trylock conflict (already held) }
procedure TestMutexTrylockConflict;
var
  LMutex: TPlatformMutex;
begin
  CheckEqual(0, platform_mutex_init(LMutex), 'mutex init');
  CheckEqual(0, platform_mutex_lock(LMutex), 'mutex lock');
  CheckEqual(PLATFORM_ERR_BUSY, platform_mutex_trylock(LMutex), 'trylock should return BUSY when held');
  CheckEqual(0, platform_mutex_unlock(LMutex), 'mutex unlock');
  CheckEqual(0, platform_mutex_destroy(LMutex), 'mutex destroy');
end;

{ --- RwLock --- }

{ 5. RwLock init + destroy }
procedure TestRwLockInitDestroy;
var
  LRwLock: TPlatformRwLock;
begin
  CheckEqual(0, platform_rwlock_init(LRwLock), 'rwlock init');
  CheckEqual(0, platform_rwlock_destroy(LRwLock), 'rwlock destroy');
end;

{ 6. RwLock rdlock + rdunlock }
procedure TestRwLockRdLockUnlock;
var
  LRwLock: TPlatformRwLock;
begin
  CheckEqual(0, platform_rwlock_init(LRwLock), 'rwlock init');
  CheckEqual(0, platform_rwlock_rdlock(LRwLock), 'rdlock');
  CheckEqual(0, platform_rwlock_rdunlock(LRwLock), 'rdunlock');
  CheckEqual(0, platform_rwlock_destroy(LRwLock), 'rwlock destroy');
end;

{ 7. RwLock wrlock + wrunlock }
procedure TestRwLockWrLockUnlock;
var
  LRwLock: TPlatformRwLock;
begin
  CheckEqual(0, platform_rwlock_init(LRwLock), 'rwlock init');
  CheckEqual(0, platform_rwlock_wrlock(LRwLock), 'wrlock');
  CheckEqual(0, platform_rwlock_wrunlock(LRwLock), 'wrunlock');
  CheckEqual(0, platform_rwlock_destroy(LRwLock), 'rwlock destroy');
end;

{ 8. RwLock tryrdlock success }
procedure TestRwLockTryRdLock;
var
  LRwLock: TPlatformRwLock;
begin
  CheckEqual(0, platform_rwlock_init(LRwLock), 'rwlock init');
  CheckEqual(0, platform_rwlock_tryrdlock(LRwLock), 'tryrdlock should succeed');
  CheckEqual(0, platform_rwlock_rdunlock(LRwLock), 'rdunlock');
  CheckEqual(0, platform_rwlock_destroy(LRwLock), 'rwlock destroy');
end;

{ 9. RwLock trywrlock success }
procedure TestRwLockTryWrLock;
var
  LRwLock: TPlatformRwLock;
begin
  CheckEqual(0, platform_rwlock_init(LRwLock), 'rwlock init');
  CheckEqual(0, platform_rwlock_trywrlock(LRwLock), 'trywrlock should succeed');
  CheckEqual(0, platform_rwlock_wrunlock(LRwLock), 'wrunlock');
  CheckEqual(0, platform_rwlock_destroy(LRwLock), 'rwlock destroy');
end;

{ --- CondVar --- }

{ 10. CondVar init + destroy }
procedure TestCondVarInitDestroy;
var
  LCondVar: TPlatformCondVar;
begin
  CheckEqual(0, platform_condvar_init(LCondVar), 'condvar init');
  CheckEqual(0, platform_condvar_destroy(LCondVar), 'condvar destroy');
end;

{ 11. CondVar signal on empty queue (should not crash) }
procedure TestCondVarSignalEmpty;
var
  LCondVar: TPlatformCondVar;
begin
  CheckEqual(0, platform_condvar_init(LCondVar), 'condvar init');
  CheckEqual(0, platform_condvar_signal(LCondVar), 'signal on empty queue');
  CheckEqual(0, platform_condvar_destroy(LCondVar), 'condvar destroy');
end;

{ 12. CondVar broadcast on empty queue (should not crash) }
procedure TestCondVarBroadcastEmpty;
var
  LCondVar: TPlatformCondVar;
begin
  CheckEqual(0, platform_condvar_init(LCondVar), 'condvar init');
  CheckEqual(0, platform_condvar_broadcast(LCondVar), 'broadcast on empty queue');
  CheckEqual(0, platform_condvar_destroy(LCondVar), 'condvar destroy');
end;

{ --- Address Wait --- }

{ 13. Wait address value mismatch returns PLATFORM_ERR_AGAIN }
procedure TestWaitAddressValueMismatch;
var
  LValue: Int32;
begin
  LValue := 42;
  CheckEqual(PLATFORM_ERR_AGAIN, platform_wait_address32(@LValue, 99, -1),
    'wait_address32 should return AGAIN when value does not match');
end;

{ 14. Wait address nil pointer returns error }
procedure TestWaitAddressNil;
var
  LResult: Int32;
begin
  LResult := platform_wait_address32(nil, 0, -1);
  Check(LResult <> 0, 'wait_address32 with nil pointer should return error, got ' + IntToStr(LResult));
end;

{$ELSE}

procedure TestNonWindowsSkip;
begin
  WriteLn('not Windows runtime evidence on this host');
  Check(True, 'non-Windows skip');
end;

{$ENDIF}

begin
  T := TTestRunner.Create('nextpas.core.platform.sync.wine_runtime_smoke');
  {$IFDEF NEXTPAS_WINDOWS}
  T.Run('mutex init + destroy', @TestMutexInitDestroy);
  T.Run('mutex lock + unlock', @TestMutexLockUnlock);
  T.Run('mutex trylock success', @TestMutexTrylockSuccess);
  T.Run('mutex trylock conflict', @TestMutexTrylockConflict);
  T.Run('rwlock init + destroy', @TestRwLockInitDestroy);
  T.Run('rwlock rdlock + rdunlock', @TestRwLockRdLockUnlock);
  T.Run('rwlock wrlock + wrunlock', @TestRwLockWrLockUnlock);
  T.Run('rwlock tryrdlock', @TestRwLockTryRdLock);
  T.Run('rwlock trywrlock', @TestRwLockTryWrLock);
  T.Run('condvar init + destroy', @TestCondVarInitDestroy);
  T.Run('condvar signal empty queue', @TestCondVarSignalEmpty);
  T.Run('condvar broadcast empty queue', @TestCondVarBroadcastEmpty);
  T.Run('wait address value mismatch', @TestWaitAddressValueMismatch);
  T.Run('wait address nil pointer', @TestWaitAddressNil);
  {$ELSE}
  T.Run('non-Windows skip', @TestNonWindowsSkip);
  {$ENDIF}
  T.Summary;
end.