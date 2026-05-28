unit nextpas.core.platform.posix.base;

{$I nextpas.core.settings.inc}
{$packrecords c}

interface

{$I nextpas.core.platform.ctypes.inc}

type
  dev_t    = cuint64;
  TDev     = dev_t;
  pDev     = ^dev_t;

  ino_t    = clong;
  TIno     = ino_t;
  pIno     = ^ino_t;

  ino64_t  = cuint64;
  TIno64   = ino64_t;
  pIno64   = ^ino64_t;

{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
  mode_t   = cint;
{$ELSE}
  mode_t   = cuint32;
{$ENDIF}
  TMode    = mode_t;
  pMode    = ^mode_t;

  nlink_t  = cuint32;
  TnLink   = nlink_t;
  pnLink   = ^nlink_t;

  off_t    = cint64;
  TOff     = off_t;
  pOff     = ^off_t;

  off64_t  = cint64;
  TOff64   = off64_t;
  pOff64   = ^off64_t;

  pid_t    = cint;
  TPid     = pid_t;
  pPid     = ^pid_t;

{$IF defined(NEXTPAS_X86_64) or defined(NEXTPAS_AARCH64)}
  size_t   = cuint64;
  ssize_t  = cint64;
  clock_t  = cuint64;
  time_t   = cint64;
{$ELSE}
  size_t   = cuint32;
  ssize_t  = cint32;
  clock_t  = culong;
  time_t   = clong;
{$ENDIF}
  TSize    = size_t;
  pSize    = ^size_t;
  psize_t  = pSize;
  TSSize   = ssize_t;
  pSSize   = ^ssize_t;
  TClock   = clock_t;
  pClock   = ^clock_t;
  pTime    = ^time_t;
  ptime_t  = ^time_t;

  uid_t    = cuint32;
  TUid     = uid_t;
  pUid     = ^uid_t;

  gid_t    = cuint32;
  TGid     = gid_t;
  pGid     = ^gid_t;

  socklen_t = cuint32;
  TSockLen  = socklen_t;
  pSockLen  = ^socklen_t;

  TIOCtlRequest = culong;

  TPlatformFileDescriptor = cint;
  TPlatformFileModeArg = cuint32;
  TPlatformFileOffset = off_t;

  timespec = record
    tv_sec: time_t;
    tv_nsec: clong;
  end;
  TTimeSpec = timespec;
  PTimeSpec = ^timespec;

  timeval = record
    tv_sec: time_t;
{$IFDEF NEXTPAS_MACOS}
    tv_usec: cint;
{$ELSE}
    tv_usec: clong;
{$ENDIF}
  end;
  TTimeVal = timeval;
  PTimeVal = ^timeval;

  {$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  pthread_t = Pointer;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  pthread_t = PtrInt;
  {$ELSE}
  pthread_t = PtrUInt;
  {$ENDIF}

  {$IFDEF NEXTPAS_MACOS}
  pthread_key_t = PtrUInt;
  {$ELSEIF defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
  pthread_key_t = Int32;
  {$ELSE}
  pthread_key_t = UInt32;
  {$ENDIF}

  TPThreadStartRoutine = function(AArg: Pointer): Pointer; cdecl;
  TPThreadCondAttrSetClockProc = function(attr: Pointer; clk_id: Int32): Int32; cdecl;

  {$IFDEF NEXTPAS_FREEBSD}
  pthread_mutex_t = Pointer;
  pthread_mutexattr_t = Pointer;
  pthread_rwlock_t = Pointer;
  pthread_rwlockattr_t = Pointer;
  pthread_cond_t = Pointer;
  pthread_condattr_t = Pointer;
  {$ELSEIF defined(NEXTPAS_MACOS)}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..63] of Byte);
  end;

  pthread_mutexattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..15] of Byte);
  end;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..199] of Byte);
  end;

  pthread_rwlockattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..23] of Byte);
  end;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..15] of Byte);
  end;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = PtrInt;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = PtrInt;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = PtrInt;
  {$ELSEIF defined(NEXTPAS_LINUX)}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = Int32;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = Int64;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = Int32;
  {$ELSE}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;
  {$ENDIF}

const
  PLATFORM_POSIX_PROT_NONE = Int32(0);
  PLATFORM_POSIX_PROT_READ = Int32(1);
  PLATFORM_POSIX_PROT_WRITE = Int32(2);
  PLATFORM_POSIX_PROT_EXEC = Int32(4);
  PLATFORM_POSIX_MAP_SHARED = Int32(1);
  PLATFORM_POSIX_MAP_PRIVATE = Int32(2);
  PLATFORM_POSIX_MAP_FAILED = PtrInt(-1);
  PLATFORM_POSIX_MAP_FAILED_PTR = PtrUInt(High(PtrUInt));
  PLATFORM_WAIT_CORE_FLAG = Int32($80);
  PLATFORM_FILE_MODE_DEFAULT = TPlatformFileModeArg(438);

type
  iovec = record
    iov_base: Pointer;
    iov_len: size_t;
  end;
  tiovec = iovec;
  piovec = ^tiovec;

{ POSIX socket types - shared struct shapes }
{$I nextpas.core.platform.posix.base.socket.inc}

implementation

end.
