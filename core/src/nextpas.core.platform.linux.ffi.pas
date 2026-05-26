unit nextpas.core.platform.linux.ffi;

{$I nextpas.core.settings.inc}

interface

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(84);

  PLATFORM_POSIX_EAGAIN = 11;
  PLATFORM_POSIX_EBUSY = 16;
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

implementation

end.
