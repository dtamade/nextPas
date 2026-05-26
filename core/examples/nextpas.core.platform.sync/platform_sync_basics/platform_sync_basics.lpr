program platform_sync_basics;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.sync;

procedure RequireOk(const ACode: Int32);
begin
  if ACode <> 0 then
    Halt(ACode);
end;

procedure RequireCode(const AExpected: Int32; const AActual: Int32);
begin
  if AExpected <> AActual then
    Halt(1);
end;

var
  LMutex: TPlatformMutex;
  LRwLock: TPlatformRwLock;
  LCondVar: TPlatformCondVar;
  LValue: Int32;

begin
  RequireOk(platform_mutex_init(LMutex));
  RequireOk(platform_mutex_lock(LMutex));
  RequireOk(platform_mutex_unlock(LMutex));
  RequireOk(platform_mutex_destroy(LMutex));

  RequireOk(platform_rwlock_init(LRwLock));
  RequireOk(platform_rwlock_rdlock(LRwLock));
  RequireOk(platform_rwlock_rdunlock(LRwLock));
  RequireOk(platform_rwlock_wrlock(LRwLock));
  RequireOk(platform_rwlock_wrunlock(LRwLock));
  RequireOk(platform_rwlock_destroy(LRwLock));

  RequireOk(platform_mutex_init(LMutex));
  RequireOk(platform_condvar_init(LCondVar));
  RequireOk(platform_mutex_lock(LMutex));
  RequireCode(PLATFORM_ERR_TIMEOUT, platform_condvar_timedwait(LCondVar, LMutex, 0));
  RequireOk(platform_mutex_unlock(LMutex));
  RequireOk(platform_condvar_signal(LCondVar));
  RequireOk(platform_condvar_broadcast(LCondVar));
  RequireOk(platform_condvar_destroy(LCondVar));
  RequireOk(platform_mutex_destroy(LMutex));

  LValue := 42;
  RequireCode(PLATFORM_ERR_AGAIN, platform_wait_address32(@LValue, 7, 0));
  RequireCode(PLATFORM_ERR_TIMEOUT, platform_wait_address32(@LValue, 42, 0));
  RequireOk(platform_wake_address_one(@LValue));
  RequireOk(platform_wake_address_all(@LValue));
end.
