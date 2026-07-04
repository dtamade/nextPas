program bench_platform_sync;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.platform.sync;
var GSink: UInt64 = 0;
procedure BenchMutexLockUnlock(const ACtx: IBenchContext);
var LM: TPlatformMutex;
begin
  if platform_mutex_init(LM, PLATFORM_MUTEX_NORMAL) <> 0 then begin ACtx.Skip; Exit; end;
  platform_mutex_lock(LM); platform_mutex_unlock(LM);
  platform_mutex_destroy(LM);
end;
procedure BenchRwLockReadUnlock(const ACtx: IBenchContext);
var LR: TPlatformRwLock;
begin
  if platform_rwlock_init(LR) <> 0 then begin ACtx.Skip; Exit; end;
  platform_rwlock_rdlock(LR); platform_rwlock_rdunlock(LR);
  platform_rwlock_destroy(LR);
end;
procedure BenchSpinLockLockUnlock(const ACtx: IBenchContext);
var LS: TPlatformSpinLock;
begin
  platform_spin_lock_init(LS); platform_spin_lock_lock(LS); platform_spin_lock_unlock(LS);
end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('platform-sync');
  LSuite.Add('Mutex/LockUnlock', @BenchMutexLockUnlock).Add('RwLock/ReadUnlock', @BenchRwLockReadUnlock).Add('SpinLock/LockUnlock', @BenchSpinLockLockUnlock);
  WriteLn(LSuite.Run.PrintToConsole);
end.
