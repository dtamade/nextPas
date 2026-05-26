unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(84);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;

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
  Result := UInt64(UInt32(gettid));
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
