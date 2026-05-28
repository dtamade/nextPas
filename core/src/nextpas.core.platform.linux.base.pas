unit nextpas.core.platform.linux.base;

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

  TPlatformLinuxSignalSet = record
    Words: array[0..1] of PtrUInt;
  end;
  PPlatformLinuxSignalSet = ^TPlatformLinuxSignalSet;

  TPlatformLinuxSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;
  TPlatformLinuxSigRestorer = procedure; cdecl;

  TPlatformLinuxSigAction = record
    sa_handler: TPlatformLinuxSigActionHandler;
    sa_flags: PtrUInt;
    sa_restorer: TPlatformLinuxSigRestorer;
    sa_mask: TPlatformLinuxSignalSet;
  end;
  PPlatformLinuxSigAction = ^TPlatformLinuxSigAction;

  {$IFDEF NEXTPAS_AARCH64}
  TPlatformLinuxStat = record
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
  TPlatformLinuxStat = record
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
  PPlatformLinuxStat = ^TPlatformLinuxStat;

  TPlatformLinuxStatxTimestamp = record
    tv_sec: Int64;
    tv_nsec: UInt32;
    __reserved: Int32;
  end;
  PPlatformLinuxStatxTimestamp = ^TPlatformLinuxStatxTimestamp;

  TPlatformLinuxStatx = record
    stx_mask: UInt32;
    stx_blksize: UInt32;
    stx_attributes: UInt64;
    stx_nlink: UInt32;
    stx_uid: UInt32;
    stx_gid: UInt32;
    stx_mode: UInt16;
    __spare0: array[0..0] of UInt16;
    stx_ino: UInt64;
    stx_size: UInt64;
    stx_blocks: UInt64;
    stx_attributes_mask: UInt64;
    stx_atime: TPlatformLinuxStatxTimestamp;
    stx_btime: TPlatformLinuxStatxTimestamp;
    stx_ctime: TPlatformLinuxStatxTimestamp;
    stx_mtime: TPlatformLinuxStatxTimestamp;
    stx_rdev_major: UInt32;
    stx_rdev_minor: UInt32;
    stx_dev_major: UInt32;
    stx_dev_minor: UInt32;
    __spare2: array[0..13] of UInt64;
  end;
  PPlatformLinuxStatx = ^TPlatformLinuxStatx;

  PPlatformPThreadState = ^TPlatformPThreadState;
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
  end;

const
  CLOCK_REALTIME           = cint(0);
  CLOCK_MONOTONIC          = cint(1);
  CLOCK_MONOTONIC_RAW      = cint(4);
  CLOCK_REALTIME_COARSE    = cint(5);
  CLOCK_MONOTONIC_COARSE   = cint(6);

  _SC_NPROCESSORS_ONLN     = cint(84);

  _PTHREAD_MUTEX_TIMED_NP      = 0;
  _PTHREAD_MUTEX_RECURSIVE_NP  = 1;
  _PTHREAD_MUTEX_ERRORCHECK_NP = 2;
  _PTHREAD_MUTEX_ADAPTIVE_NP   = 3;
  _PTHREAD_MUTEX_NORMAL        = _PTHREAD_MUTEX_TIMED_NP;
  _PTHREAD_MUTEX_RECURSIVE     = _PTHREAD_MUTEX_RECURSIVE_NP;
  _PTHREAD_MUTEX_ERRORCHECK    = _PTHREAD_MUTEX_ERRORCHECK_NP;
  _PTHREAD_MUTEX_DEFAULT       = _PTHREAD_MUTEX_NORMAL;

  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED   = 1;
  PTHREAD_TIMEOUT_CLOCK_ID            = CLOCK_MONOTONIC;

  PTHREAD_MUTEX_SIZE    = SizeOf(pthread_mutex_t);
  PTHREAD_RWLOCK_SIZE   = SizeOf(pthread_rwlock_t);
  PTHREAD_CONDVAR_SIZE  = SizeOf(pthread_cond_t);

  WNOHANG   = cint(1);
  WUNTRACED = cint(2);

  FUTEX_WAIT         = 0;
  FUTEX_WAKE         = 1;
  FUTEX_FD           = 2;
  FUTEX_REQUEUE      = 3;
  FUTEX_CMP_REQUEUE  = 4;
  FUTEX_WAKE_OP      = 5;
  FUTEX_LOCK_PI      = 6;
  FUTEX_UNLOCK_PI    = 7;
  FUTEX_TRYLOCK_PI   = 8;
  FUTEX_PRIVATE_FLAG = 128;

  RTLD_LAZY   = cint(1);
  RTLD_NOW    = cint(2);
  RTLD_LOCAL  = cint(0);
  RTLD_GLOBAL = cint($100);

  O_RDONLY    = cint(0);
  O_WRONLY    = cint(1);
  O_RDWR      = cint(2);
  O_CREAT     = cint($40);
  O_EXCL      = cint($80);
  O_NOCTTY    = cint($100);
  O_TRUNC     = cint($200);
  O_APPEND    = cint($400);
  O_NONBLOCK  = cint($800);
  O_NDELAY    = O_NONBLOCK;
  O_SYNC      = cint($1000);
  O_DIRECT    = cint($4000);
  O_DIRECTORY = cint($10000);
  O_NOFOLLOW  = cint($20000);
  O_CLOEXEC   = cint($80000);
  O_LARGEFILE = cint($8000);

  SEEK_SET = cint(0);
  SEEK_CUR = cint(1);
  SEEK_END = cint(2);

  F_DUPFD  = cint(0);
  F_GETFD  = cint(1);
  F_SETFD  = cint(2);
  F_GETFL  = cint(3);
  F_SETFL  = cint(4);
  F_GETLK  = cint(5);
  F_SETLK  = cint(6);
  F_SETLKW = cint(7);
  F_SETOWN = cint(8);
  F_GETOWN = cint(9);
  FD_CLOEXEC = cint(1);

  F_OK = cint(0);
  X_OK = cint(1);
  W_OK = cint(2);
  R_OK = cint(4);

  S_IFMT   = $F000;
  S_IFSOCK = $C000;
  S_IFLNK  = $A000;
  S_IFREG  = $8000;
  S_IFBLK  = $6000;
  S_IFDIR  = $4000;
  S_IFCHR  = $2000;
  S_IFIFO  = $1000;
  S_ISUID  = $0800;
  S_ISGID  = $0400;
  S_ISVTX  = $0200;
  S_IRUSR  = $0100;
  S_IWUSR  = $0080;
  S_IXUSR  = $0040;
  S_IRWXU  = S_IRUSR or S_IWUSR or S_IXUSR;
  S_IRGRP  = $0020;
  S_IWGRP  = $0010;
  S_IXGRP  = $0008;
  S_IRWXG  = S_IRGRP or S_IWGRP or S_IXGRP;
  S_IROTH  = $0004;
  S_IWOTH  = $0002;
  S_IXOTH  = $0001;
  S_IRWXO  = S_IROTH or S_IWOTH or S_IXOTH;

  MAP_ANONYMOUS = $20;
  MAP_GROWSDOWN = $100;

  AT_FDCWD            = cint(-100);
  AT_SYMLINK_NOFOLLOW = cint($100);
  AT_REMOVEDIR        = cint($200);
  AT_SYMLINK_FOLLOW   = cint($400);
  AT_NO_AUTOMOUNT     = cint($800);
  AT_EMPTY_PATH       = cint($1000);
  AT_STATX_SYNC_TYPE     = cint($6000);
  AT_STATX_SYNC_AS_STAT  = cint($0000);
  AT_STATX_FORCE_SYNC    = cint($2000);
  AT_STATX_DONT_SYNC     = cint($4000);

  STATX_BASIC_STATS = cuint32($000007ff);

  {$IFDEF NEXTPAS_X86_64}
  _STAT_VER_LINUX = cint(1);
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  _STAT_VER_LINUX = cint(0);
  {$ENDIF}

{ errno constants - full table from FPC }
{$I nextpas.core.platform.linux.base.errno.inc}

{ syscall numbers - architecture specific }
{$IFDEF NEXTPAS_X86_64}
{$I nextpas.core.platform.linux.base.syscall.x86_64.inc}
{$ENDIF}
{$IFDEF NEXTPAS_AARCH64}
{$I nextpas.core.platform.linux.base.syscall.generic.inc}
{$ENDIF}
{$IFDEF NEXTPAS_RISCV64}
{$I nextpas.core.platform.linux.base.syscall.riscv64.inc}
{$ENDIF}
{$IFDEF NEXTPAS_ARM}
{$I nextpas.core.platform.linux.base.syscall.arm32.inc}
{$ENDIF}

{ core OS types - pollfd, iovec, dirent, statfs, rlimit, flock, tms, utsname, fdset, cpu_set }
{$I nextpas.core.platform.linux.base.ostypes.inc}

{ signal constants and types - full signal table, sigaction, sigset }
{$I nextpas.core.platform.linux.base.signal.inc}

{ epoll types and constants }
{$I nextpas.core.platform.linux.base.epoll.inc}

{ inotify types and constants }
{$I nextpas.core.platform.linux.base.inotify.inc}

{ sysinfo, clone, extended futex ops, splice, statx extensions }
{$I nextpas.core.platform.linux.base.sysinfo.inc}

{ socket constants - AF_*, SOL_*, SO_*, IPPROTO_*, TCP_*, MSG_*, etc. }
{$I nextpas.core.platform.linux.base.socket.inc}

implementation

end.
