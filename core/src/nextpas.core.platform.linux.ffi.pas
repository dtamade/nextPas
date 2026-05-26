unit nextpas.core.platform.linux.ffi;

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
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(84);
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

  FUTEX_WAIT         = 0;
  FUTEX_WAKE         = 1;
  FUTEX_PRIVATE_FLAG = 128;

  {$IFDEF NEXTPAS_X86_64}
  LINUX_SYSCALL_FUTEX = 202;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  LINUX_SYSCALL_FUTEX = 98;
  {$ELSE}
    {$FATAL 'nextpas.core.platform.linux.ffi: unsupported Linux CPU for futex syscall'}
  {$ENDIF}

function linux_syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function gettid: Int32; cdecl; external 'c' name 'gettid';
function platform_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function platform_posix_errno_value: Int32; inline;
function linux_futex_wait_i32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
function linux_futex_wake_one_i32(AAddr: PInt32): Int32;
function linux_futex_wake_all_i32(AAddr: PInt32): Int32;
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
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

implementation

function platform_posix_errno_value: Int32; inline;
begin
  Result := platform_errno_location^;
end;

function linux_futex_wait_i32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
var
  LRet: PtrInt;
  LTs: timespec;
begin
  if ATimeoutNs < 0 then
    LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG), PtrUInt(UInt32(AExpected)),
      PtrUInt(0), PtrUInt(0), PtrUInt(0))
  else
  begin
    LTs.tv_sec := ATimeoutNs div 1000000000;
    LTs.tv_nsec := ATimeoutNs mod 1000000000;
    LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG), PtrUInt(UInt32(AExpected)),
      PtrUInt(@LTs), PtrUInt(0), PtrUInt(0));
  end;

  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function linux_futex_wake_one_i32(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(1),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function linux_futex_wake_all_i32(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(High(Int32)),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_errno_value;
end;

function platform_thread_self_token_u64: UInt64; inline;
begin
  Result := platform_posix_thread_self_token_u64;
end;

function platform_native_thread_id_u64: UInt64; inline;
begin
  Result := UInt64(UInt32(gettid));
end;

function platform_cpu_count_i32: Int32; inline;
begin
  Result := platform_posix_sysconf_positive_i32(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
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
