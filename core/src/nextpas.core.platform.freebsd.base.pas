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
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(4);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(58);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 2;
  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 3;
  PLATFORM_PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PLATFORM_PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PLATFORM_PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  PLATFORM_POSIX_EAGAIN = 35;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

  PLATFORM_WAIT_NOHANG = Int32(1);
  PLATFORM_WAIT_UNTRACED = Int32(2);

  PLATFORM_SIGNAL_HANGUP = Int32(1);
  PLATFORM_SIGNAL_INTERRUPT = Int32(2);
  PLATFORM_SIGNAL_KILL = Int32(9);
  PLATFORM_SIGNAL_TERMINATE = Int32(15);
  PLATFORM_SIGNAL_CHILD = Int32(20);
  PLATFORM_SIGNAL_ACTION_SIGINFO = Int32($040);
  PLATFORM_SIGNAL_ACTION_RESTART = Int32($002);
  PLATFORM_SIGNAL_MASK_BLOCK = Int32(1);
  PLATFORM_SIGNAL_MASK_UNBLOCK = Int32(2);
  PLATFORM_SIGNAL_MASK_SETMASK = Int32(3);

  PLATFORM_RTLD_LAZY = Int32(1);
  PLATFORM_RTLD_NOW = Int32(2);
  PLATFORM_RTLD_LOCAL = Int32(0);
  PLATFORM_RTLD_GLOBAL = Int32($100);

  PLATFORM_OPEN_READ_ONLY = Int32(0);
  PLATFORM_OPEN_WRITE_ONLY = Int32(1);
  PLATFORM_OPEN_READ_WRITE = Int32(2);
  PLATFORM_OPEN_CREATE = Int32($200);
  PLATFORM_OPEN_EXCLUSIVE = Int32($800);
  PLATFORM_OPEN_TRUNCATE = Int32($400);
  PLATFORM_OPEN_APPEND = Int32($8);

  PLATFORM_SEEK_SET = Int32(0);
  PLATFORM_SEEK_CURRENT = Int32(1);
  PLATFORM_SEEK_END = Int32(2);

  PLATFORM_FCNTL_DUP_FD = Int32(0);
  PLATFORM_FCNTL_GET_FD = Int32(1);
  PLATFORM_FCNTL_SET_FD = Int32(2);
  PLATFORM_FCNTL_GET_FLAGS = Int32(3);
  PLATFORM_FCNTL_SET_FLAGS = Int32(4);
  PLATFORM_FCNTL_FD_CLOEXEC = Int32(1);

  PLATFORM_ACCESS_EXISTS = Int32(0);
  PLATFORM_ACCESS_EXECUTE = Int32(1);
  PLATFORM_ACCESS_WRITE = Int32(2);
  PLATFORM_ACCESS_READ = Int32(4);

implementation

end.
