unit nextpas.core.platform.freebsd.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

const
  {** @desc FreeBSD pthread 令牌大小 *}
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);

type
  {** @desc FreeBSD pthread 令牌对齐记录 *}
  TPlatformPThreadTokenAlign = record
    Value: pthread_t;
  end;

  {** @desc FreeBSD pthread 互斥锁对齐记录 *}
  TPlatformPThreadMutexAlign = record
    Value: pthread_mutex_t;
  end;

  {** @desc FreeBSD pthread 读写锁对齐记录 *}
  TPlatformPThreadRwLockAlign = record
    Value: pthread_rwlock_t;
  end;

  {** @desc FreeBSD pthread 条件变量对齐记录 *}
  TPlatformPThreadCondVarAlign = record
    Value: pthread_cond_t;
  end;

  {** @desc FreeBSD 进程 ID 类型 *}
  TPlatformProcessId = pid_t;

  {** @desc FreeBSD 设备号类型 *}
  TPlatformFreeBSDDev = UInt64;
  {** @desc FreeBSD inode 号类型 *}
  TPlatformFreeBSDIno = UInt64;
  {** @desc FreeBSD 文件模式类型 *}
  TPlatformFreeBSDMode = UInt16;
  {** @desc FreeBSD 硬链接计数类型 *}
  TPlatformFreeBSDNLink = UInt64;
  {** @desc FreeBSD 用户 ID 类型 *}
  TPlatformFreeBSDUid = UInt32;
  {** @desc FreeBSD 组 ID 类型 *}
  TPlatformFreeBSDGid = UInt32;
  {** @desc FreeBSD 文件偏移类型 *}
  TPlatformFreeBSDOff = Int64;
  {** @desc FreeBSD 时间类型 *}
  TPlatformFreeBSDTime = Int64;
  {** @desc FreeBSD 长整型 *}
  TPlatformFreeBSDLong = Int64;

  {** @desc FreeBSD 信号集类型 *}
  TPlatformFreeBSDSignalSet = record
    Words: array[0..3] of Int32;
  end;
  PPlatformFreeBSDSignalSet = ^TPlatformFreeBSDSignalSet;

  {** @desc FreeBSD 信号处理器函数类型 *}
  TPlatformFreeBSDSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;

  {** @desc FreeBSD 信号动作结构体 *}
  TPlatformFreeBSDSigAction = record
    sa_handler: TPlatformFreeBSDSigActionHandler;
    sa_flags: Int32;
    sa_mask: TPlatformFreeBSDSignalSet;
  end;
  PPlatformFreeBSDSigAction = ^TPlatformFreeBSDSigAction;

  {** @desc FreeBSD 文件状态结构体 *}
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
  _SC_PAGESIZE = Int32(47);
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

{ termios ioctl constants and winsize }
{$I nextpas.core.platform.freebsd.base.termios.inc}

{ stat structure - FreeBSD 12+ }
const
  S_IFMT  = $F000;
  S_IFREG = $8000;
  S_IFDIR = $4000;
  S_IFLNK = $A000;
  S_IFCHR = $2000;
  S_IFBLK = $6000;
  S_IFIFO = $1000;
  S_IFSOCK = $C000;

type
{$packrecords c}
  TFreeBSDStat = record
    st_dev: UInt64;
    st_ino: UInt64;
    st_nlink: UInt64;
    st_mode: UInt16;
    st_padding0: Int16;
    st_uid: UInt32;
    st_gid: UInt32;
    st_padding1: Int32;
    st_rdev: UInt64;
    st_atime: Int64;
    st_atimensec: Int64;
    st_mtime: Int64;
    st_mtimensec: Int64;
    st_ctime: Int64;
    st_ctimensec: Int64;
    st_birthtime: Int64;
    st_birthtimensec: Int64;
    st_size: Int64;
    st_blocks: Int64;
    st_blksize: Int32;
    st_flags: UInt32;
    st_gen: UInt64;
    st_spare: array[0..9] of UInt64;
  end;
{$packrecords default}

implementation

end.
