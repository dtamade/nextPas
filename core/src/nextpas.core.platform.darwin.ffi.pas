unit nextpas.core.platform.darwin.ffi;

{$I nextpas.core.settings.inc}

interface

type
  mach_timebase_info_data_t = record
    numer: UInt32;
    denom: UInt32;
  end;

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(58);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_REALTIME_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;

  PLATFORM_POSIX_EAGAIN = 35;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';
function pthread_threadid_np(thread: Pointer; thread_id: PUInt64): Int32; cdecl; external 'pthread' name 'pthread_threadid_np';
function platform_errno_location: PInt32; cdecl; external 'c' name '__error';
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32;

implementation

function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32;
begin
  Result := PLATFORM_POSIX_ENOTSUP;
end;

end.
