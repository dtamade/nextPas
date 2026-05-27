unit nextpas.core.platform.posix.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.math;

function platform_posix_thread_self_token_u64: UInt64; inline;
function platform_posix_sysconf_positive_i32(const AName: Int32): Int32; inline;
function platform_posix_pthread_create_handle(
  AThreadStorage: Pointer;
  const AStartRoutine: Pointer;
  const AArgument: Pointer): Int32; inline;
function platform_posix_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
function platform_posix_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
function platform_posix_pthread_state_create(
  AThreadStorage: Pointer;
  const AStartRoutine: Pointer;
  const AArgument: Pointer): Int32; inline;
function platform_posix_pthread_state_join(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
function platform_posix_pthread_state_detach(AThreadStorage: Pointer): Int32; inline;
procedure platform_posix_pthread_yield; inline;
procedure platform_posix_pthread_sleep_ns(
  const ANanoseconds: UInt64;
  const AErrnoLocation: PInt32;
  const AEintr: Int32); inline;
function platform_posix_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
function platform_posix_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
function platform_posix_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
function platform_posix_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
function platform_posix_clock_now(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
function platform_posix_clock_getres(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
function platform_posix_clock_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
function platform_posix_clock_resolution_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
function platform_posix_clock_deadline_after_ns(
  const AClockId: Int32;
  const AErrnoLocation: PInt32;
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
function platform_posix_clock_deadline_remaining_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32;
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
function platform_posix_errno_value_from_location(const AErrnoLocation: PInt32): Int32; inline;
function platform_posix_sync_result_from_error(
  const AError: Int32;
  const AEAgain: Int32;
  const AEBusy: Int32;
  const AEInvalid: Int32;
  const AENotSup: Int32;
  const AETimedOut: Int32;
  const AAgainResult: Int32;
  const ABusyResult: Int32;
  const AInvalidResult: Int32;
  const AUnsupportedResult: Int32;
  const ATimeoutResult: Int32): Int32; inline;
function platform_posix_pthread_mutex_init_kind(
  AMutex: Pointer;
  const AKind: Int32): Int32; inline;
function platform_posix_pthread_mutex_init_public_kind(
  AMutex: Pointer;
  const APublicKind: Int32;
  const ANormalKind: Int32;
  const ARecursiveKind: Int32;
  const AErrorCheckKind: Int32): Int32; inline;
function platform_posix_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
function platform_posix_pthread_mutex_timedlock_abs(AMutex: Pointer; ADeadline: Pointer): Int32; inline;
{$ENDIF}
function platform_posix_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_unlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_condvar_init_with_clock(
  ACondVar: Pointer;
  const AClockId: Int32;
  const ASetClockSupported: Int32;
  const ASetClockProc: TPThreadCondAttrSetClockProc): Int32; inline;
function platform_posix_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
function platform_posix_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
function platform_posix_pthread_condvar_timedwait_abs(
  ACondVar: Pointer;
  AMutex: Pointer;
  ADeadline: Pointer): Int32; inline;
function platform_posix_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
function platform_posix_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
function platform_posix_mmap_failed(const AAddress: Pointer): Boolean; inline;
function platform_posix_mmap(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32;
  const AFlags: Int32;
  const AFileDescriptor: Int32;
  const AOffset: Int64): Pointer; inline;
function platform_posix_munmap(AAddress: Pointer; const ALength: PtrUInt): Int32; inline;
function platform_posix_mprotect(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32): Int32; inline;
function platform_posix_open(
  const APath: PAnsiChar;
  const AFlags: Int32;
  const AMode: TPlatformFileModeArg): TPlatformFileDescriptor; inline;
function platform_posix_close(const AFileDescriptor: TPlatformFileDescriptor): Int32; inline;
function platform_posix_fcntl(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32): Int32; inline;
function platform_posix_fcntl_i32(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32;
  const AArgument: Int32): Int32; inline;
function platform_posix_getpid: pid_t; inline;
function platform_posix_getppid: pid_t; inline;

function clock_gettime(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';
function clock_getres(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_getres';
function nanosleep(req: Pointer; rem: Pointer): Int32; cdecl; external 'c' name 'nanosleep';
function sched_yield: Int32; cdecl; external 'c' name 'sched_yield';
function sysconf(name: Int32): PtrInt; cdecl; external 'c' name 'sysconf';
function getpid: pid_t; cdecl; external 'c' name 'getpid';
function getppid: pid_t; cdecl; external 'c' name 'getppid';
function mmap(addr: Pointer; len: PtrUInt; prot: Int32; flags: Int32; fd: Int32; ofs: Int64): Pointer; cdecl; external 'c' name 'mmap';
function munmap(addr: Pointer; len: PtrUInt): Int32; cdecl; external 'c' name 'munmap';
function mprotect(addr: Pointer; len: PtrUInt; prot: Int32): Int32; cdecl; external 'c' name 'mprotect';
function open(path: PAnsiChar; flags: Int32; mode: TPlatformFileModeArg): TPlatformFileDescriptor; cdecl; external 'c' name 'open';
function close(fd: TPlatformFileDescriptor): Int32; cdecl; external 'c' name 'close';
function fcntl(fd: TPlatformFileDescriptor; cmd: Int32; arg: PtrInt): Int32; cdecl; external 'c' name 'fcntl';

function pthread_create(thread: Pointer; attr: Pointer; start_routine: TPThreadStartRoutine; arg: Pointer): Int32; cdecl; external 'pthread' name 'pthread_create';
function pthread_join(thread: pthread_t; retval: Pointer): Int32; cdecl; external 'pthread' name 'pthread_join';
function pthread_detach(thread: pthread_t): Int32; cdecl; external 'pthread' name 'pthread_detach';
function pthread_self: pthread_t; cdecl; external 'pthread' name 'pthread_self';

function pthread_key_create(key: Pointer; destructor_proc: Pointer): Int32; cdecl; external 'pthread' name 'pthread_key_create';
function pthread_key_delete(key: pthread_key_t): Int32; cdecl; external 'pthread' name 'pthread_key_delete';
function pthread_setspecific(key: pthread_key_t; value: Pointer): Int32; cdecl; external 'pthread' name 'pthread_setspecific';
function pthread_getspecific(key: pthread_key_t): Pointer; cdecl; external 'pthread' name 'pthread_getspecific';

function pthread_mutexattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_init';
function pthread_mutexattr_settype(attr: Pointer; kind: Int32): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_settype';
function pthread_mutexattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_destroy';
function pthread_mutex_init(mutex: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_init';
function pthread_mutex_destroy(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_destroy';
function pthread_mutex_lock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_lock';
function pthread_mutex_trylock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_trylock';
{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
function pthread_mutex_timedlock(mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_mutex_timedlock';
{$ENDIF}
function pthread_mutex_unlock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_unlock';

function pthread_rwlock_init(rwlock: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_init';
function pthread_rwlock_destroy(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_destroy';
function pthread_rwlock_rdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_rdlock';
function pthread_rwlock_tryrdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_tryrdlock';
function pthread_rwlock_wrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_wrlock';
function pthread_rwlock_trywrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_trywrlock';
function pthread_rwlock_unlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_unlock';

function pthread_condattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_init';
function pthread_condattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_destroy';
function pthread_cond_init(cond: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_init';
function pthread_cond_destroy(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_destroy';
function pthread_cond_wait(cond: Pointer; mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_wait';
function pthread_cond_timedwait(cond: Pointer; mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_cond_timedwait';
function pthread_cond_signal(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_signal';
function pthread_cond_broadcast(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_broadcast';

implementation

type
  PPThreadToken = ^pthread_t;

function platform_posix_thread_self_token_u64: UInt64; inline;
begin
  Result := UInt64(PtrUInt(pthread_self));
end;

function platform_posix_sysconf_positive_i32(const AName: Int32): Int32; inline;
var
  LResult: PtrInt;
begin
  LResult := sysconf(AName);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

function platform_posix_pthread_create_handle(
  AThreadStorage: Pointer;
  const AStartRoutine: Pointer;
  const AArgument: Pointer): Int32; inline;
begin
  Result := pthread_create(AThreadStorage, nil, TPThreadStartRoutine(AStartRoutine), AArgument);
end;

function platform_posix_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
begin
  Result := pthread_join(PPThreadToken(AThreadStorage)^, ARetVal);
end;

function platform_posix_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
begin
  Result := pthread_detach(PPThreadToken(AThreadStorage)^);
end;

function platform_posix_pthread_state_create(
  AThreadStorage: Pointer;
  const AStartRoutine: Pointer;
  const AArgument: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_create_handle(AThreadStorage, AStartRoutine, AArgument);
end;

function platform_posix_pthread_state_join(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_join_handle(AThreadStorage, ARetVal);
end;

function platform_posix_pthread_state_detach(AThreadStorage: Pointer): Int32; inline;
begin
  Result := platform_posix_pthread_detach_handle(AThreadStorage);
end;

procedure platform_posix_pthread_yield; inline;
begin
  sched_yield;
end;

procedure platform_posix_pthread_sleep_ns(
  const ANanoseconds: UInt64;
  const AErrnoLocation: PInt32;
  const AEintr: Int32); inline;
var
  LReq: timespec;
  LRem: timespec;
begin
  if ANanoseconds = 0 then
    Exit;

  LReq.tv_sec := Int64(ANanoseconds div PLATFORM_POSIX_NANOSECONDS_PER_SECOND);
  LReq.tv_nsec := Int64(ANanoseconds mod PLATFORM_POSIX_NANOSECONDS_PER_SECOND);
  LRem.tv_sec := 0;
  LRem.tv_nsec := 0;

  while nanosleep(@LReq, @LRem) <> 0 do
  begin
    if (AErrnoLocation = nil) or (AErrnoLocation^ <> AEintr) then
      Break;
    LReq := LRem;
  end;
end;

function platform_posix_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
var
  LKey: pthread_key_t;
begin
  Result := pthread_key_create(@LKey, nil);
  if Result = 0 then
    AKey := PtrUInt(LKey)
  else
    AKey := 0;
end;

function platform_posix_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  Result := pthread_key_delete(pthread_key_t(AKey));
end;

function platform_posix_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := pthread_setspecific(pthread_key_t(AKey), AValue);
end;

function platform_posix_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  Result := pthread_getspecific(pthread_key_t(AKey));
end;

function platform_posix_clock_now(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
begin
  if clock_gettime(AClockId, ATime) = 0 then
    Exit(0);
  if AErrnoLocation = nil then
    Exit(-1);
  Result := AErrnoLocation^;
end;

function platform_posix_clock_getres(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
begin
  if clock_getres(AClockId, ATime) = 0 then
    Exit(0);
  if AErrnoLocation = nil then
    Exit(-1);
  Result := AErrnoLocation^;
end;

function platform_posix_clock_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
var
  LTime: timespec;
begin
  if platform_posix_clock_now(AClockId, @LTime, AErrnoLocation) <> 0 then
    Exit(0);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

function platform_posix_clock_resolution_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
var
  LTime: timespec;
begin
  if platform_posix_clock_getres(AClockId, @LTime, AErrnoLocation) <> 0 then
    Exit(1);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
  if Result = 0 then
    Result := 1;
end;

function platform_posix_clock_deadline_after_ns(
  const AClockId: Int32;
  const AErrnoLocation: PInt32;
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
begin
  Result := platform_posix_clock_now(AClockId, @ADeadline, AErrnoLocation);
  if Result <> 0 then
    Exit;
  platform_posix_timespec_add_ns(ADeadline, ANanoseconds);
end;

function platform_posix_clock_deadline_remaining_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32;
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
var
  LNow: timespec;
begin
  ARemainingNs := 0;
  if ADeadline = nil then
    Exit(-1);
  Result := platform_posix_clock_now(AClockId, @LNow, AErrnoLocation);
  if Result <> 0 then
    Exit;
  ARemainingNs := platform_posix_timespec_remaining_ns_u64(ADeadline, @LNow);
end;

function platform_posix_mmap_failed(const AAddress: Pointer): Boolean; inline;
begin
  Result := PtrUInt(AAddress) = PLATFORM_POSIX_MAP_FAILED_PTR;
end;

function platform_posix_mmap(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32;
  const AFlags: Int32;
  const AFileDescriptor: Int32;
  const AOffset: Int64): Pointer; inline;
begin
  Result := mmap(AAddress, ALength, AProtection, AFlags, AFileDescriptor, AOffset);
end;

function platform_posix_munmap(AAddress: Pointer; const ALength: PtrUInt): Int32; inline;
begin
  Result := munmap(AAddress, ALength);
end;

function platform_posix_mprotect(
  AAddress: Pointer;
  const ALength: PtrUInt;
  const AProtection: Int32): Int32; inline;
begin
  Result := mprotect(AAddress, ALength, AProtection);
end;

function platform_posix_getpid: pid_t; inline;
begin
  Result := getpid;
end;

function platform_posix_open(
  const APath: PAnsiChar;
  const AFlags: Int32;
  const AMode: TPlatformFileModeArg): TPlatformFileDescriptor; inline;
begin
  Result := open(APath, AFlags, AMode);
end;

function platform_posix_close(const AFileDescriptor: TPlatformFileDescriptor): Int32; inline;
begin
  Result := close(AFileDescriptor);
end;

function platform_posix_fcntl(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32): Int32; inline;
begin
  Result := fcntl(AFileDescriptor, ACommand, 0);
end;

function platform_posix_fcntl_i32(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32;
  const AArgument: Int32): Int32; inline;
begin
  Result := fcntl(AFileDescriptor, ACommand, PtrInt(AArgument));
end;

function platform_posix_getppid: pid_t; inline;
begin
  Result := getppid;
end;

function platform_posix_errno_value_from_location(const AErrnoLocation: PInt32): Int32; inline;
begin
  if AErrnoLocation = nil then
    Exit(0);
  Result := AErrnoLocation^;
end;

function platform_posix_sync_result_from_error(
  const AError: Int32;
  const AEAgain: Int32;
  const AEBusy: Int32;
  const AEInvalid: Int32;
  const AENotSup: Int32;
  const AETimedOut: Int32;
  const AAgainResult: Int32;
  const ABusyResult: Int32;
  const AInvalidResult: Int32;
  const AUnsupportedResult: Int32;
  const ATimeoutResult: Int32): Int32; inline;
begin
  if AError = 0 then
    Result := 0
  else if AError = AEAgain then
    Result := AAgainResult
  else if AError = AEBusy then
    Result := ABusyResult
  else if AError = AEInvalid then
    Result := AInvalidResult
  else if AError = AENotSup then
    Result := AUnsupportedResult
  else if AError = AETimedOut then
    Result := ATimeoutResult
  else
    Result := AError;
end;

function platform_posix_pthread_mutex_init_kind(
  AMutex: Pointer;
  const AKind: Int32): Int32; inline;
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

function platform_posix_pthread_mutex_init_public_kind(
  AMutex: Pointer;
  const APublicKind: Int32;
  const ANormalKind: Int32;
  const ARecursiveKind: Int32;
  const AErrorCheckKind: Int32): Int32; inline;
var
  LHostKind: Int32;
begin
  case APublicKind of
    0: LHostKind := ANormalKind;
    2: LHostKind := ARecursiveKind;
  else
    LHostKind := AErrorCheckKind;
  end;
  Result := platform_posix_pthread_mutex_init_kind(AMutex, LHostKind);
end;

function platform_posix_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_destroy(AMutex);
end;

function platform_posix_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_lock(AMutex);
end;

function platform_posix_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_trylock(AMutex);
end;

{$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
function platform_posix_pthread_mutex_timedlock_abs(AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := pthread_mutex_timedlock(AMutex, PTimeSpec(ADeadline));
end;
{$ENDIF}

function platform_posix_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_unlock(AMutex);
end;

function platform_posix_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_init(ARwLock, nil);
end;

function platform_posix_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_destroy(ARwLock);
end;

function platform_posix_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_rdlock(ARwLock);
end;

function platform_posix_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_tryrdlock(ARwLock);
end;

function platform_posix_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_wrlock(ARwLock);
end;

function platform_posix_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_trywrlock(ARwLock);
end;

function platform_posix_pthread_rwlock_unlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_unlock(ARwLock);
end;

function platform_posix_pthread_condvar_init_with_clock(
  ACondVar: Pointer;
  const AClockId: Int32;
  const ASetClockSupported: Int32;
  const ASetClockProc: TPThreadCondAttrSetClockProc): Int32; inline;
var
  LAttr: pthread_condattr_t;
begin
  Result := pthread_condattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    if ASetClockSupported <> 0 then
    begin
      if not Assigned(ASetClockProc) then
        Exit(-1);
      Result := ASetClockProc(@LAttr, AClockId);
      if Result <> 0 then
        Exit;
    end;
    Result := pthread_cond_init(ACondVar, @LAttr);
  finally
    pthread_condattr_destroy(@LAttr);
  end;
end;

function platform_posix_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_destroy(ACondVar);
end;

function platform_posix_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  Result := pthread_cond_wait(ACondVar, AMutex);
end;

function platform_posix_pthread_condvar_timedwait_abs(
  ACondVar: Pointer;
  AMutex: Pointer;
  ADeadline: Pointer): Int32; inline;
begin
  Result := pthread_cond_timedwait(ACondVar, AMutex, PTimeSpec(ADeadline));
end;

function platform_posix_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_signal(ACondVar);
end;

function platform_posix_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_broadcast(ACondVar);
end;

end.
