unit nextpas.core.platform.darwin.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.darwin.base,
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';
function pthread_threadid_np(thread: Pointer; thread_id: PUInt64): Int32; cdecl; external 'pthread' name 'pthread_threadid_np';
function platform_errno_location: PInt32; cdecl; external 'c' name '__error';
function platform_posix_errno_value: Int32; inline;
function platform_pthread_sync_result(
  const AError: Int32;
  const AAgainResult: Int32;
  const ABusyResult: Int32;
  const AInvalidResult: Int32;
  const AUnsupportedResult: Int32;
  const ATimeoutResult: Int32): Int32; inline;
function platform_thread_self_token_u64: UInt64; inline;
function platform_native_thread_id_u64: UInt64; inline;
function platform_cpu_count_i32: Int32; inline;
function platform_pthread_create_handle(AThreadStorage: Pointer; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
function platform_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
function platform_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
function platform_pthread_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
function platform_pthread_state_join(const AState: PPlatformPThreadState; out ARetVal: Pointer): Int32; inline;
function platform_pthread_state_detach(const AState: PPlatformPThreadState): Int32; inline;
procedure platform_pthread_yield; inline;
procedure platform_pthread_sleep_ns(const ANanoseconds: UInt64); inline;
function platform_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
function platform_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
function platform_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
function platform_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
function platform_clock_monotonic_now(ATime: Pointer): Int32; inline;
function platform_clock_realtime_now(ATime: Pointer): Int32; inline;
function platform_clock_monotonic_getres(ATime: Pointer): Int32; inline;
function platform_clock_monotonic_ns_u64: UInt64;
function platform_clock_realtime_ns_u64: UInt64; inline;
function platform_clock_monotonic_resolution_ns_u64: UInt64;
function platform_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
function platform_pthread_timeout_deadline_after_ns(
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
function platform_pthread_timeout_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
function platform_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
function platform_pthread_mutex_init(AMutex: Pointer; const AKind: Int32): Int32; inline;
function platform_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
function platform_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
function platform_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
function platform_pthread_mutex_timedlock_abs(AMutex: Pointer; ADeadline: Pointer): Int32; inline;
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
function darwin_mach_monotonic_ns: UInt64;
function darwin_mach_monotonic_resolution_ns: UInt64;
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl;
function platform_process_id: TPlatformProcessId; inline;
function platform_parent_process_id: TPlatformProcessId; inline;
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
function platform_file_fcntl(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32): Int32; inline;
function platform_file_fcntl_i32(
  const AFileDescriptor: TPlatformFileDescriptor;
  const ACommand: Int32;
  const AArgument: Int32): Int32; inline;
function platform_dlopen(const AName: PAnsiChar; const AFlags: Int32): Pointer; inline;
function platform_dlsym(ALibrary: Pointer; const AName: PAnsiChar): Pointer; inline;
function platform_dlclose(ALibrary: Pointer): Int32; inline;
function platform_dlerror: PAnsiChar; inline;
function dlopen(Name: PAnsiChar; Flags: Int32): Pointer; cdecl; external 'c' name 'dlopen';
function dlsym(Lib: Pointer; Name: PAnsiChar): Pointer; cdecl; external 'c' name 'dlsym';
function dlclose(Lib: Pointer): Int32; cdecl; external 'c' name 'dlclose';
function dlerror: PAnsiChar; cdecl; external 'c' name 'dlerror';

implementation

var
  GDarwinTimebaseNumer: UInt64 = 0;
  GDarwinTimebaseDenom: UInt64 = 0;

function platform_process_id: TPlatformProcessId; inline;
begin
  Result := platform_posix_getpid;
end;

function platform_parent_process_id: TPlatformProcessId; inline;
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

function platform_posix_errno_value: Int32; inline;
begin
  Result := platform_posix_errno_value_from_location(platform_errno_location);
end;

function platform_pthread_sync_result(
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

function platform_thread_self_token_u64: UInt64; inline;
begin
  Result := platform_posix_thread_self_token_u64;
end;

function platform_native_thread_id_u64: UInt64; inline;
begin
  Result := 0;
  if pthread_threadid_np(nil, @Result) <> 0 then
    Result := platform_thread_self_token_u64;
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

function platform_pthread_state_create(out AState: PPlatformPThreadState; const AStartRoutine: Pointer; const AArgument: Pointer): Int32; inline;
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

function platform_pthread_state_join(const AState: PPlatformPThreadState; out ARetVal: Pointer): Int32; inline;
begin
  ARetVal := nil;
  if AState = nil then
    Exit(-1);

  Result := platform_posix_pthread_state_join(@AState^.Thread[0], @ARetVal);
  if Result = 0 then
    Dispose(AState);
end;

function platform_pthread_state_detach(const AState: PPlatformPThreadState): Int32; inline;
begin
  if AState = nil then
    Exit(-1);

  Result := platform_posix_pthread_state_detach(@AState^.Thread[0]);
  if Result = 0 then
    Dispose(AState);
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

function platform_pthread_timeout_clock_now(ATime: Pointer): Int32; inline;
begin
  Result := platform_posix_clock_now(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    ATime,
    platform_errno_location);
end;

function platform_pthread_timeout_deadline_after_ns(
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
begin
  Result := platform_posix_clock_deadline_after_ns(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    platform_errno_location,
    ANanoseconds,
    ADeadline);
end;

function platform_pthread_timeout_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
begin
  Result := platform_posix_clock_deadline_remaining_ns_u64(
    PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID,
    platform_errno_location,
    ADeadline,
    ARemainingNs);
end;

function platform_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
begin
  Result := platform_posix_pthread_mutex_init_public_kind(
    AMutex,
    AKind,
    PLATFORM_PTHREAD_MUTEX_NORMAL_KIND,
    PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND,
    PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND);
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

function platform_pthread_mutex_timedlock_abs(AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := PLATFORM_POSIX_ENOTSUP;
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

function darwin_mul_div_floor(const AValue: UInt64; const AMultiplier: UInt64; const ADivisor: UInt64): UInt64;
var
  LFactor: UInt64;
  LQuotient: UInt64;
  LRemainder: UInt64;
  LTermQuotient: UInt64;
  LTermRemainder: UInt64;
begin
  if (AValue = 0) or (AMultiplier = 0) then
    Exit(0);
  if ADivisor = 0 then
    Exit(High(UInt64));

  LFactor := AMultiplier;
  LQuotient := 0;
  LRemainder := 0;
  LTermQuotient := AValue div ADivisor;
  LTermRemainder := AValue mod ADivisor;

  while LFactor <> 0 do
  begin
    if (LFactor and UInt64(1)) <> 0 then
    begin
      if LQuotient > High(UInt64) - LTermQuotient then
        Exit(High(UInt64));
      LQuotient := LQuotient + LTermQuotient;

      if LTermRemainder <> 0 then
      begin
        if LRemainder >= ADivisor - LTermRemainder then
        begin
          LRemainder := LRemainder - (ADivisor - LTermRemainder);
          if LQuotient = High(UInt64) then
            Exit(High(UInt64));
          Inc(LQuotient);
        end
        else
          LRemainder := LRemainder + LTermRemainder;
      end;
    end;

    LFactor := LFactor shr 1;
    if LFactor = 0 then
      Break;

    if LTermQuotient > High(UInt64) div 2 then
      LTermQuotient := High(UInt64)
    else
      LTermQuotient := LTermQuotient * 2;

    if LTermRemainder <> 0 then
    begin
      if LTermRemainder >= ADivisor - LTermRemainder then
      begin
        LTermRemainder := LTermRemainder - (ADivisor - LTermRemainder);
        if LTermQuotient <> High(UInt64) then
          Inc(LTermQuotient);
      end
      else
        LTermRemainder := LTermRemainder + LTermRemainder;
    end;
  end;

  Result := LQuotient;
end;

function darwin_scale_units(const AValue: UInt64; const ADivisor: UInt64; const AMultiplier: UInt64): UInt64;
var
  LDivisor: UInt64;
  LWhole: UInt64;
  LRem: UInt64;
  LFrac: UInt64;
begin
  if AMultiplier = 0 then
    Exit(0);

  LDivisor := ADivisor;
  if LDivisor = 0 then
    LDivisor := 1;

  LWhole := AValue div LDivisor;
  LRem := AValue mod LDivisor;

  if LWhole > High(UInt64) div AMultiplier then
    Exit(High(UInt64));

  Result := LWhole * AMultiplier;

  if LRem = 0 then
    LFrac := 0
  else if LRem <= High(UInt64) div AMultiplier then
    LFrac := (LRem * AMultiplier) div LDivisor
  else
    LFrac := darwin_mul_div_floor(LRem, AMultiplier, LDivisor);

  if Result > High(UInt64) - LFrac then
    Exit(High(UInt64));

  Result := Result + LFrac;
end;

procedure darwin_ensure_timebase;
var
  LInfo: mach_timebase_info_data_t;
begin
  if GDarwinTimebaseDenom = 0 then
  begin
    mach_timebase_info(LInfo);
    GDarwinTimebaseNumer := LInfo.numer;
    GDarwinTimebaseDenom := LInfo.denom;
    if GDarwinTimebaseDenom = 0 then
    begin
      GDarwinTimebaseNumer := 1;
      GDarwinTimebaseDenom := 1;
    end;
  end;
end;

function darwin_mach_monotonic_ns: UInt64;
begin
  darwin_ensure_timebase;
  Result := darwin_scale_units(mach_absolute_time, GDarwinTimebaseDenom, GDarwinTimebaseNumer);
end;

function platform_clock_monotonic_ns_u64: UInt64;
begin
  Result := darwin_mach_monotonic_ns;
end;

function platform_clock_realtime_ns_u64: UInt64; inline;
begin
  Result := platform_posix_clock_ns_u64(
    PLATFORM_CLOCK_REALTIME_ID,
    platform_errno_location);
end;

function darwin_mach_monotonic_resolution_ns: UInt64;
begin
  darwin_ensure_timebase;
  if GDarwinTimebaseDenom = 0 then
    Result := 1
  else if GDarwinTimebaseNumer >= GDarwinTimebaseDenom then
    Result := (GDarwinTimebaseNumer + GDarwinTimebaseDenom - 1) div GDarwinTimebaseDenom
  else
    Result := 1;

  if Result = 0 then
    Result := 1;
end;

function platform_clock_monotonic_resolution_ns_u64: UInt64;
begin
  Result := darwin_mach_monotonic_resolution_ns;
end;

function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl;
begin
  Result := PLATFORM_POSIX_ENOTSUP;
end;

end.
