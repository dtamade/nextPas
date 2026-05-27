unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.linux.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function linux_syscall(ANumber: PtrInt; A1: PtrUInt; A2: PtrUInt; A3: PtrUInt; A4: PtrUInt; A5: PtrUInt; A6: PtrUInt): PtrInt; cdecl; external 'c' name 'syscall';
function gettid: Int32; cdecl; external 'c' name 'gettid';
function linux_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function linux_errno_value: Int32; inline;
function linux_pthread_sync_result(
  const AError: Int32;
  const AAgainResult: Int32;
  const ABusyResult: Int32;
  const AInvalidResult: Int32;
  const AUnsupportedResult: Int32;
  const ATimeoutResult: Int32): Int32; inline;
function linux_futex_wait_i32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
function linux_futex_wake_one_i32(AAddr: PInt32): Int32;
function linux_futex_wake_all_i32(AAddr: PInt32): Int32;
function linux_rt_sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformLinuxSigAction;
  AOldAction: PPlatformLinuxSigAction): Int32; inline;
function linux_rt_sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformLinuxSignalSet;
  AOldSet: PPlatformLinuxSignalSet): Int32; inline;
function linux_statx(
  const ADirectoryFileDescriptor: Int32;
  const APath: PAnsiChar;
  const AFlags: UInt32;
  const AMask: UInt32;
  out ABuffer: TPlatformLinuxStatx): Int32; inline;
function linux_statx_path_basic(
  const APath: PAnsiChar;
  out ABuffer: TPlatformLinuxStatx): Int32; inline;
function linux_statx_fd_basic(
  const AFileDescriptor: TPlatformFileDescriptor;
  out ABuffer: TPlatformLinuxStatx): Int32; inline;
function linux_xstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__xstat';
function linux_lxstat(
  const AVersion: Int32;
  const AFileName: PAnsiChar;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__lxstat';
function linux_fxstat(
  const AVersion: Int32;
  const AFileDescriptor: Int32;
  var AStat: TPlatformLinuxStat): Int32; cdecl; external 'c' name '__fxstat';
function linux_stat_path(
  const APath: PAnsiChar;
  out ABuffer: TPlatformLinuxStat): Int32; inline;
function linux_lstat_path(
  const APath: PAnsiChar;
  out ABuffer: TPlatformLinuxStat): Int32; inline;
function linux_fstat_fd(
  const AFileDescriptor: TPlatformFileDescriptor;
  out ABuffer: TPlatformLinuxStat): Int32; inline;
function linux_thread_self_token_u64: UInt64; inline;
function linux_native_thread_id_u64: UInt64; inline;
function linux_cpu_count_i32: Int32; inline;
function linux_pthread_create_handle(AThreadStorage: Pointer; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
function linux_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
function linux_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
function linux_pthread_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
function linux_pthread_state_join(const AState: PPlatformPThreadState; out ARetVal: Pointer): Int32; inline;
function linux_pthread_state_detach(const AState: PPlatformPThreadState): Int32; inline;
procedure linux_pthread_yield; inline;
procedure linux_pthread_sleep_ns(const ANanoseconds: UInt64); inline;
function linux_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
function linux_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
function linux_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
function linux_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
function linux_clock_monotonic_now(ATime: Pointer): Int32; inline;
function linux_clock_realtime_now(ATime: Pointer): Int32; inline;
function linux_clock_monotonic_getres(ATime: Pointer): Int32; inline;
function linux_clock_monotonic_ns_u64: UInt64; inline;
function linux_clock_realtime_ns_u64: UInt64; inline;
function linux_clock_monotonic_resolution_ns_u64: UInt64; inline;
function linux_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
function linux_pthread_timeout_deadline_after_ns(
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
function linux_pthread_timeout_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
function linux_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
function linux_pthread_mutex_init(AMutex: Pointer; const AKind: Int32): Int32; inline;
function linux_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
function linux_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
function linux_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
function linux_pthread_mutex_timedlock_abs(AMutex: Pointer; ADeadline: Pointer): Int32; inline;
function linux_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
function linux_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
function linux_pthread_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
function linux_pthread_condvar_init(ACondVar: Pointer): Int32; inline;
function linux_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
function linux_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
function linux_pthread_condvar_timedwait_abs(ACondVar: Pointer; AMutex: Pointer; ADeadline: Pointer): Int32; inline;
function linux_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
function linux_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
function linux_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function linux_process_id: TPlatformProcessId; inline;
function linux_parent_process_id: TPlatformProcessId; inline;
function platform_mmap(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32;
  const AFlags: Int32;
  const AFileDescriptor: Int32;
  const AOffset: Int64): Pointer; inline;
function platform_munmap(AAddress: Pointer; const ALength: PtrUInt): Int32; inline;
function platform_mprotect(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32): Int32; inline;
function platform_file_open(
  const APath: PAnsiChar;
  const AFlags: Int32;
  const AMode: TPlatformFileModeArg): TPlatformFileDescriptor; inline;
function platform_file_close(const AFileDescriptor: TPlatformFileDescriptor): Int32; inline;
function platform_file_read(
  const AFileDescriptor: TPlatformFileDescriptor;
  ABuffer: Pointer;
  const AByteCount: size_t): ssize_t; inline;
function platform_file_write(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ABuffer: Pointer;
  const AByteCount: size_t): ssize_t; inline;
function platform_file_seek(
  const AFileDescriptor: TPlatformFileDescriptor;
  const AOffset: TPlatformFileOffset;
  const AWhence: Int32): TPlatformFileOffset; inline;
function platform_file_sync(const AFileDescriptor: TPlatformFileDescriptor): Int32; inline;
function platform_file_truncate(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ALength: TPlatformFileOffset): Int32; inline;
function platform_file_fcntl(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32): Int32; inline;
function platform_file_fcntl_i32(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32;
  const AArgument: Int32): Int32; inline;
function platform_directory_create(
  const APath: PAnsiChar;
  const AMode: TPlatformFileModeArg): Int32; inline;
function platform_directory_remove(const APath: PAnsiChar): Int32; inline;
function platform_path_unlink(const APath: PAnsiChar): Int32; inline;
function platform_path_rename(
  const AOldPath: PAnsiChar;
  const ANewPath: PAnsiChar): Int32; inline;
function platform_path_access(
  const APath: PAnsiChar;
  const AMode: Int32): Int32; inline;
function platform_path_get_current_directory(
  ABuffer: PAnsiChar;
  const ASize: PtrUInt): PAnsiChar; inline;
function platform_path_set_current_directory(const APath: PAnsiChar): Int32; inline;
function platform_environment_get(const AName: PAnsiChar): PAnsiChar; inline;
function platform_environment_set(
  const AName: PAnsiChar;
  const AValue: PAnsiChar;
  const AOverwrite: Int32): Int32; inline;
function platform_environment_unset(const AName: PAnsiChar): Int32; inline;
function platform_environment_put(const AEntry: PAnsiChar): Int32; inline;
function platform_dlopen(const AName: PAnsiChar; const AFlags: Int32): Pointer; inline;
function platform_dlsym(ALibrary: Pointer; const AName: PAnsiChar): Pointer; inline;
function platform_dlclose(ALibrary: Pointer): Int32; inline;
function platform_dlerror: PAnsiChar; inline;
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'dl' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'dl' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'dl' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'dl' name 'dlerror';

implementation

function linux_errno_value: Int32; inline;
begin
  Result := platform_posix_errno_value_from_location(linux_errno_location);
end;

function linux_process_id: TPlatformProcessId; inline;
begin
  Result := platform_posix_getpid;
end;

function linux_parent_process_id: TPlatformProcessId; inline;
begin
  Result := platform_posix_getppid;
end;

function platform_mmap(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32;
  const AFlags: Int32;
  const AFileDescriptor: Int32;
  const AOffset: Int64): Pointer; inline;
begin
  Result := platform_posix_mmap(AAddress, ALength, AProtection, AFlags, AFileDescriptor, AOffset);
end;

function platform_munmap(AAddress: Pointer; const ALength: PtrUInt): Int32; inline;
begin
  Result := platform_posix_munmap(AAddress, ALength);
end;

function platform_mprotect(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32): Int32; inline;
begin
  Result := platform_posix_mprotect(AAddress, ALength, AProtection);
end;

function platform_file_open(
  const APath: PAnsiChar;
  const AFlags: Int32;
  const AMode: TPlatformFileModeArg): TPlatformFileDescriptor; inline;
begin
  Result := platform_posix_open(APath, AFlags, AMode);
end;

function platform_file_close(const AFileDescriptor: TPlatformFileDescriptor): Int32; inline;
begin
  Result := platform_posix_close(AFileDescriptor);
end;

function platform_file_read(
  const AFileDescriptor: TPlatformFileDescriptor;
  ABuffer: Pointer;
  const AByteCount: size_t): ssize_t; inline;
begin
  Result := platform_posix_read(AFileDescriptor, ABuffer, AByteCount);
end;

function platform_file_write(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ABuffer: Pointer;
  const AByteCount: size_t): ssize_t; inline;
begin
  Result := platform_posix_write(AFileDescriptor, ABuffer, AByteCount);
end;

function platform_file_seek(
  const AFileDescriptor: TPlatformFileDescriptor;
  const AOffset: TPlatformFileOffset;
  const AWhence: Int32): TPlatformFileOffset; inline;
begin
  Result := platform_posix_seek(AFileDescriptor, AOffset, AWhence);
end;

function platform_file_sync(const AFileDescriptor: TPlatformFileDescriptor): Int32; inline;
begin
  Result := platform_posix_sync(AFileDescriptor);
end;

function platform_file_truncate(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ALength: TPlatformFileOffset): Int32; inline;
begin
  Result := platform_posix_truncate(AFileDescriptor, ALength);
end;

function platform_file_fcntl(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32): Int32; inline;
begin
  Result := platform_posix_fcntl(AFileDescriptor, ACommand);
end;

function platform_file_fcntl_i32(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32;
  const AArgument: Int32): Int32; inline;
begin
  Result := platform_posix_fcntl_i32(AFileDescriptor, ACommand, AArgument);
end;

function platform_directory_create(
  const APath: PAnsiChar;
  const AMode: TPlatformFileModeArg): Int32; inline;
begin
  Result := platform_posix_directory_create(APath, AMode);
end;

function platform_directory_remove(const APath: PAnsiChar): Int32; inline;
begin
  Result := platform_posix_directory_remove(APath);
end;

function platform_path_unlink(const APath: PAnsiChar): Int32; inline;
begin
  Result := platform_posix_path_unlink(APath);
end;

function platform_path_rename(
  const AOldPath: PAnsiChar;
  const ANewPath: PAnsiChar): Int32; inline;
begin
  Result := platform_posix_path_rename(AOldPath, ANewPath);
end;

function platform_path_access(
  const APath: PAnsiChar;
  const AMode: Int32): Int32; inline;
begin
  Result := platform_posix_path_access(APath, AMode);
end;

function platform_path_get_current_directory(
  ABuffer: PAnsiChar;
  const ASize: PtrUInt): PAnsiChar; inline;
begin
  Result := platform_posix_path_get_current_directory(ABuffer, ASize);
end;

function platform_path_set_current_directory(const APath: PAnsiChar): Int32; inline;
begin
  Result := platform_posix_path_set_current_directory(APath);
end;

function platform_environment_get(const AName: PAnsiChar): PAnsiChar; inline;
begin
  Result := platform_posix_environment_get(AName);
end;

function platform_environment_set(
  const AName: PAnsiChar;
  const AValue: PAnsiChar;
  const AOverwrite: Int32): Int32; inline;
begin
  Result := platform_posix_environment_set(AName, AValue, AOverwrite);
end;

function platform_environment_unset(const AName: PAnsiChar): Int32; inline;
begin
  Result := platform_posix_environment_unset(AName);
end;

function platform_environment_put(const AEntry: PAnsiChar): Int32; inline;
begin
  Result := platform_posix_environment_put(AEntry);
end;

function platform_dlopen(const AName: PAnsiChar; const AFlags: Int32): Pointer; inline;
begin
  Result := dlopen(AName, AFlags);
end;

function platform_dlsym(ALibrary: Pointer; const AName: PAnsiChar): Pointer; inline;
begin
  Result := dlsym(ALibrary, AName);
end;

function platform_dlclose(ALibrary: Pointer): Int32; inline;
begin
  Result := dlclose(ALibrary);
end;

function platform_dlerror: PAnsiChar; inline;
begin
  Result := dlerror;
end;

function linux_pthread_sync_result(
  const AError: Int32;
  const AAgainResult: Int32;
  const ABusyResult: Int32;
  const AInvalidResult: Int32;
  const AUnsupportedResult: Int32;
  const ATimeoutResult: Int32): Int32; inline;
begin
  Result := platform_posix_sync_result_from_error(
    AError,
    PLATFORM_POSIX_EAGAIN,
    PLATFORM_POSIX_EBUSY,
    PLATFORM_POSIX_EINVAL,
    PLATFORM_POSIX_ENOTSUP,
    PLATFORM_POSIX_ETIMEDOUT,
    AAgainResult,
    ABusyResult,
    AInvalidResult,
    AUnsupportedResult,
    ATimeoutResult);
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
    Result := linux_errno_value;
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
    Result := linux_errno_value;
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
    Result := linux_errno_value;
end;

function linux_rt_sigaction(
  const ASignal: Int32;
  ANewAction: PPlatformLinuxSigAction;
  AOldAction: PPlatformLinuxSigAction): Int32; inline;
begin
  Result := Int32(linux_syscall(
    LINUX_SYSCALL_RT_SIGACTION,
    PtrUInt(ASignal),
    PtrUInt(ANewAction),
    PtrUInt(AOldAction),
    PtrUInt(8),
    PtrUInt(0),
    PtrUInt(0)));
end;

function linux_rt_sigprocmask(
  const AHow: Int32;
  ANewSet: PPlatformLinuxSignalSet;
  AOldSet: PPlatformLinuxSignalSet): Int32; inline;
begin
  Result := Int32(linux_syscall(
    LINUX_SYSCALL_RT_SIGPROCMASK,
    PtrUInt(AHow),
    PtrUInt(ANewSet),
    PtrUInt(AOldSet),
    PtrUInt(8),
    PtrUInt(0),
    PtrUInt(0)));
end;

function linux_statx(
  const ADirectoryFileDescriptor: Int32;
  const APath: PAnsiChar;
  const AFlags: UInt32;
  const AMask: UInt32;
  out ABuffer: TPlatformLinuxStatx): Int32; inline;
var
  LRet: PtrInt;
begin
  FillChar(ABuffer, SizeOf(ABuffer), 0);
  LRet := linux_syscall(
    LINUX_SYSCALL_STATX,
    PtrUInt(ADirectoryFileDescriptor),
    PtrUInt(APath),
    PtrUInt(AFlags),
    PtrUInt(AMask),
    PtrUInt(@ABuffer),
    PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := linux_errno_value;
end;

function linux_statx_path_basic(
  const APath: PAnsiChar;
  out ABuffer: TPlatformLinuxStatx): Int32; inline;
begin
  Result := linux_statx(
    PLATFORM_LINUX_AT_FDCWD,
    APath,
    UInt32(PLATFORM_LINUX_AT_NO_AUTOMOUNT),
    PLATFORM_LINUX_STATX_BASIC_STATS,
    ABuffer);
end;

function linux_statx_fd_basic(
  const AFileDescriptor: TPlatformFileDescriptor;
  out ABuffer: TPlatformLinuxStatx): Int32; inline;
const
  EMPTY_PATH: array[0..0] of AnsiChar = (#0);
begin
  Result := linux_statx(
    Int32(AFileDescriptor),
    @EMPTY_PATH[0],
    UInt32(PLATFORM_LINUX_AT_EMPTY_PATH),
    PLATFORM_LINUX_STATX_BASIC_STATS,
    ABuffer);
end;

function linux_stat_path(
  const APath: PAnsiChar;
  out ABuffer: TPlatformLinuxStat): Int32; inline;
begin
  FillChar(ABuffer, SizeOf(ABuffer), 0);
  Result := linux_xstat(PLATFORM_LINUX_STAT_VERSION, APath, ABuffer);
end;

function linux_lstat_path(
  const APath: PAnsiChar;
  out ABuffer: TPlatformLinuxStat): Int32; inline;
begin
  FillChar(ABuffer, SizeOf(ABuffer), 0);
  Result := linux_lxstat(PLATFORM_LINUX_STAT_VERSION, APath, ABuffer);
end;

function linux_fstat_fd(
  const AFileDescriptor: TPlatformFileDescriptor;
  out ABuffer: TPlatformLinuxStat): Int32; inline;
begin
  FillChar(ABuffer, SizeOf(ABuffer), 0);
  Result := linux_fxstat(PLATFORM_LINUX_STAT_VERSION, Int32(AFileDescriptor), ABuffer);
end;

function linux_thread_self_token_u64: UInt64; inline;
begin
  Result := platform_posix_thread_self_token_u64;
end;

function linux_native_thread_id_u64: UInt64; inline;
begin
  Result := UInt64(UInt32(gettid));
end;

function linux_cpu_count_i32: Int32; inline;
begin
  Result := platform_posix_sysconf_positive_i32(PLATFORM_SYSCONF_NPROCESSORS_ONLN);
end;

function linux_pthread_create_handle(AThreadStorage: Pointer; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_create_handle(AThreadStorage, AStartRoutine, AArgument);
end;

function linux_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_join_handle(AThreadStorage, ARetVal);
end;

function linux_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_detach_handle(AThreadStorage);
end;

function linux_pthread_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
begin
  AState := nil;
  if AStartRoutine = nil then
    Exit(-1);

  New(AState);
  FillChar(AState^, SizeOf(AState^), 0);

  Result := platform_posix_pthread_state_create(@AState^.Thread[0], AStartRoutine, AArgument);
  if Result <> 0 then
  begin
    Dispose(AState);
    AState := nil;
  end;
end;

function linux_pthread_state_join(const AState: PPlatformPThreadState; out ARetVal: Pointer): Int32; inline;
begin
  ARetVal := nil;
  if AState = nil then
    Exit(-1);

  Result := platform_posix_pthread_state_join(@AState^.Thread[0], @ARetVal);
  if Result = 0 then
    Dispose(AState);
end;

function linux_pthread_state_detach(const AState: PPlatformPThreadState): Int32; inline;
begin
  if AState = nil then
    Exit(-1);

  Result := platform_posix_pthread_state_detach(@AState^.Thread[0]);
  if Result = 0 then
    Dispose(AState);
end;

procedure linux_pthread_yield; inline;
begin
  platform_posix_pthread_yield;
end;

procedure linux_pthread_sleep_ns(const ANanoseconds: UInt64); inline;
begin
  platform_posix_pthread_sleep_ns(ANanoseconds, linux_errno_location, PLATFORM_POSIX_EINTR);
end;

function linux_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
begin
  Result := platform_posix_pthread_tls_create(AKey);
end;

function linux_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  Result := platform_posix_pthread_tls_destroy(AKey);
end;

function linux_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_tls_set(AKey, AValue);
end;

function linux_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  Result := platform_posix_pthread_tls_get(AKey);
end;

function linux_clock_monotonic_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_CLOCK_MONOTONIC_ID,
    ATime,
    linux_errno_location);
end;

function linux_clock_realtime_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_CLOCK_REALTIME_ID,
    ATime,
    linux_errno_location);
end;

function linux_clock_monotonic_getres(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_getres(
    PLATFORM_CLOCK_MONOTONIC_ID,
    ATime,
    linux_errno_location);
end;

function linux_clock_monotonic_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_ns_u64(
    PLATFORM_CLOCK_MONOTONIC_ID,
    linux_errno_location);
end;

function linux_clock_realtime_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_ns_u64(
    PLATFORM_CLOCK_REALTIME_ID,
    linux_errno_location);
end;

function linux_clock_monotonic_resolution_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_resolution_ns_u64(
    PLATFORM_CLOCK_MONOTONIC_ID,
    linux_errno_location);
end;

function linux_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    ATime,
    linux_errno_location);
end;

function linux_pthread_timeout_deadline_after_ns(
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
begin
  Result := platform_posix_clock_deadline_after_ns(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    linux_errno_location,
    ANanoseconds,
    ADeadline);
end;

function linux_pthread_timeout_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
begin
  Result := platform_posix_clock_deadline_remaining_ns_u64(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    linux_errno_location,
    ADeadline,
    ARemainingNs);
end;

function linux_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_init_public_kind(
    AMutex,
    AKind,
    PLATFORM_PTHREAD_MUTEX_NORMAL_KIND,
    PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND,
    PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND);
end;

function linux_pthread_mutex_init(AMutex: Pointer; const AKind: Int32): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_init_kind(AMutex, AKind);
end;

function linux_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_destroy(AMutex);
end;

function linux_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_lock(AMutex);
end;

function linux_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_trylock(AMutex);
end;

function linux_pthread_mutex_timedlock_abs(AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_timedlock_abs(AMutex, ADeadline);
end;

function linux_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_unlock(AMutex);
end;

function linux_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_init(ARwLock);
end;

function linux_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_destroy(ARwLock);
end;

function linux_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_rdlock(ARwLock);
end;

function linux_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_tryrdlock(ARwLock);
end;

function linux_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_wrlock(ARwLock);
end;

function linux_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_trywrlock(ARwLock);
end;

function linux_pthread_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_unlock(ARwLock);
end;

function linux_pthread_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_rwlock_unlock(ARwLock);
end;

function linux_pthread_condvar_init(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_init_with_clock(
    ACondVar,
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED,
    @linux_pthread_condattr_setclock);
end;

function linux_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_destroy(ACondVar);
end;

function linux_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_wait(ACondVar, AMutex);
end;

function linux_pthread_condvar_timedwait_abs(ACondVar: Pointer; AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_timedwait_abs(ACondVar, AMutex, ADeadline);
end;

function linux_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_signal(ACondVar);
end;

function linux_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_condvar_broadcast(ACondVar);
end;

end.
