unit nextpas.core.platform.android.ffi;

{$I nextpas.core.settings.inc}

interface

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(97);

  PLATFORM_POSIX_EAGAIN = 11;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 95;
  PLATFORM_POSIX_ETIMEDOUT = 110;

function platform_errno_location: PInt32; cdecl; external 'c' name '__errno';
function gettid: Int32; cdecl; external 'c' name 'gettid';

implementation

end.
