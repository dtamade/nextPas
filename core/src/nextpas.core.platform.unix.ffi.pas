unit nextpas.core.platform.unix.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.ffi;

type
  TPlatformPThreadTokenAlign = record
    Value: pthread_t;
  end;

  TPlatformPThreadMutexAlign = record
    Value: pthread_mutex_t;
  end;

  TPlatformPThreadRwLockAlign = record
    Value: pthread_rwlock_t;
  end;

  TPlatformPThreadCondVarAlign = record
    Value: pthread_cond_t;
  end;

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(-1);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);
  PLATFORM_PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PLATFORM_PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PLATFORM_PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  PLATFORM_POSIX_EAGAIN = 11;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 95;
  PLATFORM_POSIX_ETIMEDOUT = 110;

function platform_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function platform_posix_errno_value: Int32; inline;
function platform_thread_self_token_u64: UInt64; inline;
function platform_native_thread_id_u64: UInt64; inline;
function platform_cpu_count_i32: Int32; inline;
function platform_pthread_create_handle(AThreadStorage: Pointer; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
function platform_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
function platform_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
procedure platform_pthread_yield; inline;
procedure platform_pthread_sleep_ns(const ANanoseconds: UInt64); inline;
function platform_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
function platform_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
function platform_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
function platform_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
function platform_clock_monotonic_now(ATime: Pointer): Int32; inline;
function platform_clock_realtime_now(ATime: Pointer): Int32; inline;
function platform_clock_monotonic_getres(ATime: Pointer): Int32; inline;
function platform_clock_monotonic_ns_u64: UInt64; inline;
function platform_clock_realtime_ns_u64: UInt64; inline;
function platform_clock_monotonic_resolution_ns_u64: UInt64; inline;
function platform_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
function platform_pthread_mutex_init(AMutex: Pointer; const AKind: Int32): Int32; inline;
function platform_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
function platform_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
function platform_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
function platform_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
function platform_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
function platform_pthread_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
function platform_pthread_condvar_init(ACondVar: Pointer): Int32; inline;
function platform_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
function platform_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
function platform_pthread_condvar_timedwait_abs(ACondVar: Pointer; AMutex: Pointer; ADeadline: Pointer): Int32; inline;
function platform_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
function platform_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

implementation

type
  PPThreadToken = ^pthread_t;

function platform_posix_errno_value: Int32; inline;
begin
  Result := platform_errno_location^;
end;

function platform_thread_self_token_u64: UInt64; inline;
begin
  Result := UInt64(PtrUInt(pthread_self));
end;

function platform_native_thread_id_u64: UInt64; inline;
begin
  Result := platform_thread_self_token_u64;
end;

function platform_cpu_count_i32: Int32; inline;
var
  LResult: PtrInt;
begin
  LResult := sysconf(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

function platform_pthread_create_handle(AThreadStorage: Pointer; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  Result := pthread_create(AThreadStorage, nil, TPThreadStartRoutine(AStartRoutine), AArgument);
end;

function platform_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
begin
  Result := pthread_join(PPThreadToken(AThreadStorage)^, ARetVal);
end;

function platform_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
begin
  Result := pthread_detach(PPThreadToken(AThreadStorage)^);
end;

procedure platform_pthread_yield; inline;
begin
  sched_yield;
end;

procedure platform_pthread_sleep_ns(const ANanoseconds: UInt64); inline;
var
  LReq: timespec;
  LRem: timespec;
begin
  if ANanoseconds = 0 then
    Exit;

  LReq.tv_sec := ANanoseconds div 1000000000;
  LReq.tv_nsec := ANanoseconds mod 1000000000;
  LRem.tv_sec := 0;
  LRem.tv_nsec := 0;

  while nanosleep(@LReq, @LRem) <> 0 do
  begin
    if platform_posix_errno_value <> PLATFORM_POSIX_EINTR then
      Break;
    LReq := LRem;
  end;
end;

function platform_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
var
  LKey: pthread_key_t;
begin
  Result := pthread_key_create(@LKey, nil);
  if Result = 0 then
    AKey := PtrUInt(LKey)
  else
    AKey := 0;
end;

function platform_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  Result := pthread_key_delete(pthread_key_t(AKey));
end;

function platform_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := pthread_setspecific(pthread_key_t(AKey), AValue);
end;

function platform_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  Result := pthread_getspecific(pthread_key_t(AKey));
end;

function platform_clock_monotonic_now(ATime: Pointer): Int32; inline;
begin
  if clock_gettime(PLATFORM_CLOCK_MONOTONIC_ID, ATime) = 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function platform_clock_realtime_now(ATime: Pointer): Int32; inline;
begin
  if clock_gettime(PLATFORM_CLOCK_REALTIME_ID, ATime) = 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function platform_clock_monotonic_getres(ATime: Pointer): Int32; inline;
begin
  if clock_getres(PLATFORM_CLOCK_MONOTONIC_ID, ATime) = 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function platform_clock_monotonic_ns_u64: UInt64; inline;
var
  LTime: timespec;
begin
  if platform_clock_monotonic_now(@LTime) <> 0 then
    Exit(0);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

function platform_clock_realtime_ns_u64: UInt64; inline;
var
  LTime: timespec;
begin
  if platform_clock_realtime_now(@LTime) <> 0 then
    Exit(0);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

function platform_clock_monotonic_resolution_ns_u64: UInt64; inline;
var
  LTime: timespec;
begin
  if platform_clock_monotonic_getres(@LTime) <> 0 then
    Exit(1);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
  if Result = 0 then
    Result := 1;
end;

function platform_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
begin
  if clock_gettime(PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID, ATime) = 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function platform_pthread_mutex_init(AMutex: Pointer; const AKind: Int32): Int32; inline;
var
  LAttr: pthread_mutexattr_t;
begin
  Result := pthread_mutexattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    Result := pthread_mutexattr_settype(@LAttr, AKind);
    if Result <> 0 then
      Exit;
    Result := pthread_mutex_init(AMutex, @LAttr);
  finally
    pthread_mutexattr_destroy(@LAttr);
  end;
end;

function platform_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_destroy(AMutex);
end;

function platform_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_lock(AMutex);
end;

function platform_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_trylock(AMutex);
end;

function platform_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_unlock(AMutex);
end;

function platform_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_init(ARwLock, nil);
end;

function platform_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_destroy(ARwLock);
end;

function platform_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_rdlock(ARwLock);
end;

function platform_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_tryrdlock(ARwLock);
end;

function platform_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_wrlock(ARwLock);
end;

function platform_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_trywrlock(ARwLock);
end;

function platform_pthread_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_unlock(ARwLock);
end;

function platform_pthread_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_unlock(ARwLock);
end;

function platform_pthread_condvar_init(ACondVar: Pointer): Int32; inline;
var
  LAttr: pthread_condattr_t;
begin
  Result := pthread_condattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    if PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED <> 0 then
    begin
      Result := platform_pthread_condattr_setclock(@LAttr, PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID);
      if Result <> 0 then
        Exit;
    end;
    Result := pthread_cond_init(ACondVar, @LAttr);
  finally
    pthread_condattr_destroy(@LAttr);
  end;
end;

function platform_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_destroy(ACondVar);
end;

function platform_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  Result := pthread_cond_wait(ACondVar, AMutex);
end;

function platform_pthread_condvar_timedwait_abs(ACondVar: Pointer; AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := pthread_cond_timedwait(ACondVar, AMutex, PTimeSpec(ADeadline));
end;

function platform_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_signal(ACondVar);
end;

function platform_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_broadcast(ACondVar);
end;

end.
