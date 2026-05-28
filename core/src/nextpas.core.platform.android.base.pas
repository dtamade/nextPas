unit nextpas.core.platform.android.base;

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

  TPlatformAndroidSignalSet = record
    Words: array[0..1] of PtrUInt;
  end;
  PPlatformAndroidSignalSet = ^TPlatformAndroidSignalSet;

  TPlatformAndroidSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;
  TPlatformAndroidSigRestorer = procedure; cdecl;

  TPlatformAndroidSigAction = record
    sa_handler: TPlatformAndroidSigActionHandler;
    sa_flags: PtrUInt;
    sa_restorer: TPlatformAndroidSigRestorer;
    sa_mask: TPlatformAndroidSignalSet;
  end;
  PPlatformAndroidSigAction = ^TPlatformAndroidSigAction;

  {$IFDEF NEXTPAS_AARCH64}
  TPlatformAndroidStat = record
    st_dev: UInt64;
    st_ino: UInt64;
    st_mode: UInt32;
    st_nlink: UInt32;
    st_uid: UInt32;
    st_gid: UInt32;
    st_rdev: UInt64;
    __pad1a: UInt64;
    st_size: Int64;
    st_blksize: Int32;
    __pad2a: Int32;
    st_blocks: Int64;
    st_atime: Int64;
    st_atime_nsec: UInt64;
    st_mtime: Int64;
    st_mtime_nsec: UInt64;
    st_ctime: Int64;
    st_ctime_nsec: UInt64;
    __unused4a: UInt32;
    __unused5a: UInt32;
  end;
  {$ELSE}
  TPlatformAndroidStat = record
    st_dev: UInt64;
    st_ino: UInt64;
    st_nlink: UInt64;
    st_mode: UInt32;
    st_uid: UInt32;
    st_gid: UInt32;
    __pad1: UInt32;
    st_rdev: UInt64;
    st_size: Int64;
    st_blksize: Int64;
    st_blocks: Int64;
    st_atime: UInt64;
    st_atime_nsec: UInt64;
    st_mtime: UInt64;
    st_mtime_nsec: UInt64;
    st_ctime: UInt64;
    st_ctime_nsec: UInt64;
    __unused2: array[0..2] of Int64;
  end;
  {$ENDIF}
  PPlatformAndroidStat = ^TPlatformAndroidStat;

  PPlatformPThreadState = ^TPlatformPThreadState;
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
  end;

const
  CLOCK_REALTIME = Int32(0);
  CLOCK_MONOTONIC = Int32(1);
  _SC_NPROCESSORS_ONLN = Int32(97);
  PTHREAD_TIMEOUT_CLOCK_ID = CLOCK_MONOTONIC;
  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1;

  _PTHREAD_MUTEX_NORMAL = 0;
  _PTHREAD_MUTEX_RECURSIVE = 1;
  _PTHREAD_MUTEX_ERRORCHECK = 2;
  PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  ESysEAGAIN = 11;
  ESysEBUSY = 16;
  ESysEINTR = 4;
  ESysEINVAL = 22;
  ESysEOPNOTSUPP = 95;
  ESysETIMEDOUT = 110;

  WNOHANG = Int32(1);
  WUNTRACED = Int32(2);

  SIGHUP = Int32(1);
  SIGINT = Int32(2);
  SIGKILL = Int32(9);
  SIGTERM = Int32(15);
  SIGCHLD = Int32(17);
  SA_SIGINFO = Int32(4);
  SA_RESTART = Int32($10000000);
  SIG_BLOCK = Int32(0);
  SIG_UNBLOCK = Int32(1);
  SIG_SETMASK = Int32(2);

  RTLD_LAZY = Int32(1);
  RTLD_NOW = Int32(2);
  RTLD_LOCAL = Int32(0);
  RTLD_GLOBAL = Int32($100);

  O_RDONLY = Int32(0);
  O_WRONLY = Int32(1);
  O_RDWR = Int32(2);
  O_CREAT = Int32($40);
  O_EXCL = Int32($80);
  O_TRUNC = Int32($200);
  O_APPEND = Int32($400);
  O_CLOEXEC = Int32($80000);

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

  PLATFORM_ANDROID_AT_FDCWD = Int32(-100);
  PLATFORM_ANDROID_AT_SYMLINK_NOFOLLOW = Int32($100);

  {$IFDEF NEXTPAS_X86_64}
  ANDROID_SYSCALL_FSTAT = 5;
  ANDROID_SYSCALL_RT_SIGACTION = 13;
  ANDROID_SYSCALL_RT_SIGPROCMASK = 14;
  ANDROID_SYSCALL_NEWFSTATAT = 262;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  ANDROID_SYSCALL_NEWFSTATAT = 79;
  ANDROID_SYSCALL_FSTAT = 80;
  ANDROID_SYSCALL_RT_SIGACTION = 134;
  ANDROID_SYSCALL_RT_SIGPROCMASK = 135;
  {$ELSE}
    {$FATAL 'nextpas.core.platform.android.base: unsupported Android CPU for stat syscalls'}
  {$ENDIF}

implementation

end.
