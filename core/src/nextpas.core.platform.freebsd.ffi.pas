unit nextpas.core.platform.freebsd.ffi;

{$I nextpas.core.settings.inc}

interface

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(4);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(58);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 2;
  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 3;

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

implementation

uses
  nextpas.core.platform.posix.ffi;

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
  Result := UInt64(UInt32(pthread_getthreadid_np));
  if Result = 0 then
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

end.
