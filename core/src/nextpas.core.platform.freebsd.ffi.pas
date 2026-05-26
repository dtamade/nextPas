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
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

function platform_errno_location: PInt32; cdecl; external 'c' name '__error';
function pthread_getthreadid_np: Int32; cdecl; external 'pthread' name 'pthread_getthreadid_np';
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

implementation

end.
