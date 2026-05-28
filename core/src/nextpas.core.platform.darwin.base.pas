unit nextpas.core.platform.darwin.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

const
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);

type
  TPlatformPThreadTokenAlign = record
    Value: pthread_t;
  end;

  TPlatformPThreadMutexAlign = record
    Value: pthread_mutex_t;
  end;

  TPlatformPThreadRwLockAlign = record
    Value: pthread_rwlock_t;
  end;

  TPlatformPThreadCondVarAlign = record
    Value: pthread_cond_t;
  end;

  TPlatformProcessId = pid_t;

  TPlatformDarwinDev = UInt32;
  TPlatformDarwinIno = UInt64;
  TPlatformDarwinMode = UInt16;
  TPlatformDarwinNLink = UInt16;
  TPlatformDarwinUid = UInt32;
  TPlatformDarwinGid = UInt32;
  TPlatformDarwinOff = Int64;
  TPlatformDarwinTime = Int64;
  TPlatformDarwinLong = Int64;

  TPlatformDarwinSignalSet = record
    Words: array[0..0] of UInt32;
  end;
  PPlatformDarwinSignalSet = ^TPlatformDarwinSignalSet;

  TPlatformDarwinSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;

  TPlatformDarwinSigAction = record
    sa_handler: TPlatformDarwinSigActionHandler;
    sa_mask: TPlatformDarwinSignalSet;
    sa_flags: Int32;
  end;
  PPlatformDarwinSigAction = ^TPlatformDarwinSigAction;

  TPlatformDarwinStat = record
    st_dev: TPlatformDarwinDev;
    st_mode: TPlatformDarwinMode;
    st_nlink: TPlatformDarwinNLink;
    st_ino: TPlatformDarwinIno;
    st_uid: TPlatformDarwinUid;
    st_gid: TPlatformDarwinGid;
    st_rdev: TPlatformDarwinDev;
    st_atime: TPlatformDarwinTime;
    st_atimensec: TPlatformDarwinLong;
    st_mtime: TPlatformDarwinTime;
    st_mtimensec: TPlatformDarwinLong;
    st_ctime: TPlatformDarwinTime;
    st_ctimensec: TPlatformDarwinLong;
    st_birthtime: TPlatformDarwinTime;
    st_birthtimensec: TPlatformDarwinLong;
    st_size: TPlatformDarwinOff;
    st_blocks: Int64;
    st_blksize: UInt32;
    st_flags: UInt32;
    st_gen: UInt32;
    st_lspare: UInt32;
    st_qspare: array[0..1] of Int64;
  end;
  PPlatformDarwinStat = ^TPlatformDarwinStat;

  PPlatformPThreadState = ^TPlatformPThreadState;
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
  end;

  mach_timebase_info_data_t = record
    numer: UInt32;
    denom: UInt32;
  end;

const
  CLOCK_REALTIME = Int32(0);
  CLOCK_MONOTONIC = Int32(1);
  _SC_NPROCESSORS_ONLN = Int32(58);
  PTHREAD_TIMEOUT_CLOCK_ID = CLOCK_REALTIME;
  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0;
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0;

  _PTHREAD_MUTEX_NORMAL = 0;
  _PTHREAD_MUTEX_RECURSIVE = 1;
  _PTHREAD_MUTEX_ERRORCHECK = 2;
  PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  WNOHANG = Int32(1);
  WUNTRACED = Int32(2);

  RTLD_LAZY = Int32(1);
  RTLD_NOW = Int32(2);
  RTLD_LOCAL = Int32(4);
  RTLD_GLOBAL = Int32(8);

  O_RDONLY = Int32(0);
  O_WRONLY = Int32(1);
  O_RDWR = Int32(2);
  O_CREAT = Int32($200);
  O_EXCL = Int32($800);
  O_NOCTTY = Int32($20000);
  O_TRUNC = Int32($400);
  O_APPEND = Int32($8);
  O_NONBLOCK = Int32($4);
  O_DIRECTORY = Int32($100000);
  O_CLOEXEC = Int32($1000000);

  SEEK_SET = Int32(0);
  SEEK_CUR = Int32(1);
  SEEK_END = Int32(2);

  F_DUPFD = Int32(0);
  F_GETFD = Int32(1);
  F_SETFD = Int32(2);
  F_GETFL = Int32(3);
  F_SETFL = Int32(4);
  FD_CLOEXEC = Int32(1);

  F_OK = Int32(0);
  X_OK = Int32(1);
  W_OK = Int32(2);
  R_OK = Int32(4);

{ errno constants - full table }
{$I nextpas.core.platform.darwin.base.errno.inc}

{ signal constants - full table }
{$I nextpas.core.platform.darwin.base.signal.inc}

{ kqueue types and constants }
{$I nextpas.core.platform.darwin.base.kqueue.inc}

implementation

end.
