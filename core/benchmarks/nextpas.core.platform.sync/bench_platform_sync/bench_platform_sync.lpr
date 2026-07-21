program bench_platform_sync;
{$I nextpas.core.settings.inc}
uses nextpas.core.bench, nextpas.core.bench.intf, nextpas.core.platform.sync;
var GSink: UInt64 = 0;
procedure BenchMutexLockUnlock(const ACtx: IBenchContext);
var LM: TPlatformMutex;
begin
  if platform_mutex_init(LM, PLATFORM_MUTEX_NORMAL) <> 0 then
  begin
    ACtx.Skip('platform_mutex_init failed');
    Exit;
  end;
  platform_mutex_lock(LM); platform_mutex_unlock(LM);
  platform_mutex_destroy(LM);
end;
procedure BenchRwLockReadUnlock(const ACtx: IBenchContext);
var LR: TPlatformRwLock;
begin
  if platform_rwlock_init(LR) <> 0 then
  begin
    ACtx.Skip('platform_rwlock_init failed');
    Exit;
  end;
  platform_rwlock_rdlock(LR); platform_rwlock_rdunlock(LR);
  platform_rwlock_destroy(LR);
end;
procedure BenchCondVarSignal(const ACtx: IBenchContext);
var LC: TPlatformCondVar;
begin
  if platform_condvar_init(LC) <> 0 then
  begin
    ACtx.Skip('platform_condvar_init failed');
    Exit;
  end;
  platform_condvar_signal(LC);
  platform_condvar_destroy(LC);
  Inc(GSink);
end;
var LSuite: IBenchSuite;
begin
  LSuite := TBenchSuite.Create('platform-sync');
  LSuite.Add('Mutex/LockUnlock', @BenchMutexLockUnlock)
    .Add('RwLock/ReadUnlock', @BenchRwLockReadUnlock)
    .Add('CondVar/Signal', @BenchCondVarSignal);
  WriteLn(LSuite.Run.PrintToConsole);
end.
