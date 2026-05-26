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

  PLATFORM_POSIX_EAGAIN = 35;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

function mach_absolute_time: UInt64; cdecl; external 'c' name 'mach_absolute_time';
function mach_timebase_info(out info: mach_timebase_info_data_t): Int32; cdecl; external 'c' name 'mach_timebase_info';
function pthread_threadid_np(thread: Pointer; thread_id: PUInt64): Int32; cdecl; external 'pthread' name 'pthread_threadid_np';
function platform_errno_location: PInt32; cdecl; external 'c' name '__error';

implementation

end.
