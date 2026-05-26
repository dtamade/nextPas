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
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

implementation

uses
  nextpas.core.platform.posix.ffi;

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

end.
