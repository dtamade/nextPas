unit nextpas.core.platform.freebsd.ffi;

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
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(4);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(58);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 2;
  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 3;
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);
  PLATFORM_PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PLATFORM_PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PLATFORM_PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  PLATFORM_POSIX_EAGAIN = 35;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

function platform_errno_location: PInt32; cdecl; external 'c' name '__error';
function pthread_getthreadid_np: Int32; cdecl; external 'pthread' name 'pthread_getthreadid_np';
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
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function platform_clock_monotonic_now(ATime: Pointer): Int32; inline;
function platform_clock_realtime_now(ATime: Pointer): Int32; inline;
function platform_clock_monotonic_getres(ATime: Pointer): Int32; inline;
function platform_clock_monotonic_ns_u64: UInt64; inline;
function platform_clock_realtime_ns_u64: UInt64; inline;
function platform_clock_monotonic_resolution_ns_u64: UInt64; inline;
function platform_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
function platform_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
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

implementation

function platform_posix_errno_value: Int32; inline;
begin
  Result := platform_errno_location^;
end;

function platform_thread_self_token_u64: UInt64; inline;
begin
  Result := platform_posix_thread_self_token_u64;
end;

function platform_native_thread_id_u64: UInt64; inline;
begin
  Result := UInt64(UInt32(pthread_getthreadid_np));
  if Result = 0 then
    Result := platform_thread_self_token_u64;
end;

function platform_cpu_count_i32: Int32; inline;
begin
  Result := platform_posix_sysconf_positive_i32(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
end;

function platform_clock_monotonic_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_CLOCK_MONOTONIC_ID,
    ATime,
    platform_errno_location);
end;

function platform_clock_realtime_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_CLOCK_REALTIME_ID,
    ATime,
    platform_errno_location);
end;

function platform_clock_monotonic_getres(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_getres(
    PLATFORM_CLOCK_MONOTONIC_ID,
    ATime,
    platform_errno_location);
end;

function platform_clock_monotonic_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_ns_u64(
    PLATFORM_CLOCK_MONOTONIC_ID,
    platform_errno_location);
end;

function platform_clock_realtime_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_ns_u64(
    PLATFORM_CLOCK_REALTIME_ID,
    platform_errno_location);
end;

function platform_clock_monotonic_resolution_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_resolution_ns_u64(
    PLATFORM_CLOCK_MONOTONIC_ID,
    platform_errno_location);
end;

function platform_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    ATime,
    platform_errno_location);
end;

function platform_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
var
  LHostKind: Int32;
begin
  case AKind of
    0: LHostKind := PLATFORM_PTHREAD_MUTEX_NORMAL_KIND;
    2: LHostKind := PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND;
  else
    LHostKind := PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND;
  end;
  Result := platform_pthread_mutex_init(AMutex, LHostKind);
end;

function platform_pthread_mutex_init(AMutex: Pointer; const AKind: Int32): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_init_kind(AMutex, AKind);
end;

function platform_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_destroy(AMutex);
end;

function platform_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_lock(AMutex);
end;

function platform_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_trylock(AMutex);
end;

function platform_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_unlock(AMutex);
end;

function platform_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_init(ARwLock);
end;

function platform_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_destroy(ARwLock);
end;

function platform_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_rdlock(ARwLock);
end;

function platform_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_tryrdlock(ARwLock);
end;

function platform_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_wrlock(ARwLock);
end;

function platform_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_trywrlock(ARwLock);
end;

function platform_pthread_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_unlock(ARwLock);
end;

function platform_pthread_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_unlock(ARwLock);
end;

function platform_pthread_condvar_init(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_init_with_clock(
    ACondVar,
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED,
    @platform_pthread_condattr_setclock);
end;

function platform_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_destroy(ACondVar);
end;

function platform_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_wait(ACondVar, AMutex);
end;

function platform_pthread_condvar_timedwait_abs(ACondVar: Pointer; AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_timedwait_abs(ACondVar, AMutex, ADeadline);
end;

function platform_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_signal(ACondVar);
end;

function platform_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_broadcast(ACondVar);
end;

function platform_pthread_create_handle(AThreadStorage: Pointer; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_create_handle(AThreadStorage, AStartRoutine, AArgument);
end;

function platform_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_join_handle(AThreadStorage, ARetVal);
end;

function platform_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_detach_handle(AThreadStorage);
end;

procedure platform_pthread_yield; inline;
begin
  platform_posix_pthread_yield;
end;

procedure platform_pthread_sleep_ns(const ANanoseconds: UInt64); inline;
begin
  platform_posix_pthread_sleep_ns(ANanoseconds, platform_errno_location, PLATFORM_POSIX_EINTR);
end;

function platform_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
begin
  Result := platform_posix_pthread_tls_create(AKey);
end;

function platform_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  Result := platform_posix_pthread_tls_destroy(AKey);
end;

function platform_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_tls_set(AKey, AValue);
end;

function platform_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  Result := platform_posix_pthread_tls_get(AKey);
end;

end.
