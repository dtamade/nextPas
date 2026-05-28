unit nextpas.core.platform.freebsd.base;

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

  TPlatformFreeBSDDev = UInt64;
  TPlatformFreeBSDIno = UInt64;
  TPlatformFreeBSDMode = UInt16;
  TPlatformFreeBSDNLink = UInt64;
  TPlatformFreeBSDUid = UInt32;
  TPlatformFreeBSDGid = UInt32;
  TPlatformFreeBSDOff = Int64;
  TPlatformFreeBSDTime = Int64;
  TPlatformFreeBSDLong = Int64;

  TPlatformFreeBSDSignalSet = record
    Words: array[0..3] of Int32;
  end;
  PPlatformFreeBSDSignalSet = ^TPlatformFreeBSDSignalSet;

  TPlatformFreeBSDSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;

  TPlatformFreeBSDSigAction = packed record
    sa_handler: TPlatformFreeBSDSigActionHandler;
    sa_flags: Int32;
    sa_mask: TPlatformFreeBSDSignalSet;
  end;
  PPlatformFreeBSDSigAction = ^TPlatformFreeBSDSigAction;

  TPlatformFreeBSDStat = record
    st_dev: TPlatformFreeBSDDev;
    st_ino: TPlatformFreeBSDIno;
    st_nlink: TPlatformFreeBSDNLink;
    st_mode: TPlatformFreeBSDMode;
    st_padding0: Int16;
    st_uid: TPlatformFreeBSDUid;
    st_gid: TPlatformFreeBSDGid;
    st_padding1: Int32;
    st_rdev: TPlatformFreeBSDDev;
    st_atime: TPlatformFreeBSDTime;
    st_atimensec: TPlatformFreeBSDLong;
    st_mtime: TPlatformFreeBSDTime;
    st_mtimensec: TPlatformFreeBSDLong;
    st_ctime: TPlatformFreeBSDTime;
    st_ctimensec: TPlatformFreeBSDLong;
    st_birthtime: TPlatformFreeBSDTime;
    st_birthtimensec: TPlatformFreeBSDLong;
    st_size: TPlatformFreeBSDOff;
    st_blocks: Int64;
    st_blksize: Int32;
    st_flags: UInt32;
    st_gen: UInt64;
    st_spare: array[0..9] of UInt64;
  end;
  PPlatformFreeBSDStat = ^TPlatformFreeBSDStat;

  PPlatformPThreadState = ^TPlatformPThreadState;
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
  end;

const
  CLOCK_REALTIME = Int32(0);
  CLOCK_MONOTONIC = Int32(4);
  _SC_NPROCESSORS_ONLN = Int32(58);
  PTHREAD_TIMEOUT_CLOCK_ID = CLOCK_MONOTONIC;
  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1;

  _PTHREAD_MUTEX_ERRORCHECK = 1;
  _PTHREAD_MUTEX_RECURSIVE = 2;
  _PTHREAD_MUTEX_NORMAL = 3;
  PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  WNOHANG = Int32(1);
  WUNTRACED = Int32(2);

  RTLD_LAZY = Int32(1);
  RTLD_NOW = Int32(2);
  RTLD_LOCAL = Int32(0);
  RTLD_GLOBAL = Int32($100);

  O_RDONLY = Int32(0);
  O_WRONLY = Int32(1);
  O_RDWR = Int32(2);
  O_CREAT = Int32($200);
  O_EXCL = Int32($800);
  O_TRUNC = Int32($400);
  O_APPEND = Int32($8);
  O_NONBLOCK = Int32($4);
  O_DIRECTORY = Int32($20000);
  O_CLOEXEC = Int32($100000);

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
{$I nextpas.core.platform.freebsd.base.errno.inc}

{ signal constants - full table }
{$I nextpas.core.platform.freebsd.base.signal.inc}

{ kqueue types and constants }
{$I nextpas.core.platform.freebsd.base.kqueue.inc}

{ socket constants }
{$I nextpas.core.platform.freebsd.base.socket.inc}

implementation

end.
