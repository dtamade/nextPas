unit nextpas.core.platform.unix.ffi;

{$I nextpas.core.settings.inc}

interface

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(-1);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;

  PLATFORM_POSIX_EAGAIN = 11;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 95;
  PLATFORM_POSIX_ETIMEDOUT = 110;

function platform_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
function platform_pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';

implementation

end.
