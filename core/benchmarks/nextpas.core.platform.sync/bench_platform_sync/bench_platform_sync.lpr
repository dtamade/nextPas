program bench_platform_sync;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.sync,
  nextpas.core.platform.time;

const
  ITERATIONS = 1000000;

procedure ReportMetric(const AName: string; const AElapsedNs: UInt64);
begin
  WriteLn(AName, '-iterations=', ITERATIONS);
  WriteLn(AName, '-elapsed-ns=', AElapsedNs);
  if ITERATIONS > 0 then
    WriteLn(AName, '-ns-per-op=', AElapsedNs div ITERATIONS);
end;

procedure BenchMutexLockUnlock;
var
  LMutex: TPlatformMutex;
  LStart: UInt64;
  LElapsed: UInt64;
  I: Integer;
begin
  if platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) <> 0 then
    Halt(1);
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
  begin
    platform_mutex_lock(LMutex);
    platform_mutex_unlock(LMutex);
  end;
  LElapsed := platform_monotonic_ns - LStart;
  platform_mutex_destroy(LMutex);
  ReportMetric('platform-sync-mutex-lock-unlock', LElapsed);
end;

procedure BenchRwLockReadUnlock;
var
  LRwLock: TPlatformRwLock;
  LStart: UInt64;
  LElapsed: UInt64;
  I: Integer;
begin
  if platform_rwlock_init(LRwLock) <> 0 then
    Halt(1);
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
  begin
    platform_rwlock_rdlock(LRwLock);
    platform_rwlock_rdunlock(LRwLock);
  end;
  LElapsed := platform_monotonic_ns - LStart;
  platform_rwlock_destroy(LRwLock);
  ReportMetric('platform-sync-rwlock-read-unlock', LElapsed);
end;

procedure BenchAddressMismatch;
var
  LValue: Int32;
  LStart: UInt64;
  LElapsed: UInt64;
  I: Integer;
begin
  LValue := 1;
  LStart := platform_monotonic_ns;
  for I := 1 to ITERATIONS do
    if platform_wait_address32(@LValue, 2, 0) <> PLATFORM_ERR_AGAIN then
      Halt(1);
  LElapsed := platform_monotonic_ns - LStart;
  ReportMetric('platform-sync-address-mismatch', LElapsed);
end;

begin
  {$IFNDEF NEXTPAS_LINUX}
  {$IFNDEF NEXTPAS_WINDOWS}
  WriteLn('platform-sync-bench-status=unsupported');
  Halt(0);
  {$ENDIF}
  {$ENDIF}

  WriteLn('platform-sync-bench=running');
  BenchMutexLockUnlock;
  BenchRwLockReadUnlock;
  BenchAddressMismatch;
  WriteLn('platform-sync-bench-status=pass');
end.
