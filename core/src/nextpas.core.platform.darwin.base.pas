unit nextpas.core.platform.darwin.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

const
  {** @desc macOS pthread 令牌大小 *}
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);

type
  {** @desc macOS pthread 令牌对齐记录 *}
  TPlatformPThreadTokenAlign = record
    Value: pthread_t;
  end;

  {** @desc macOS pthread 互斥锁对齐记录 *}
  TPlatformPThreadMutexAlign = record
    Value: pthread_mutex_t;
  end;

  {** @desc macOS pthread 读写锁对齐记录 *}
  TPlatformPThreadRwLockAlign = record
    Value: pthread_rwlock_t;
  end;

  {** @desc macOS pthread 条件变量对齐记录 *}
  TPlatformPThreadCondVarAlign = record
    Value: pthread_cond_t;
  end;

  {** @desc macOS 进程 ID 类型 *}
  TPlatformProcessId = pid_t;

  {** @desc macOS 设备号类型 *}
  TPlatformDarwinDev = UInt32;
  {** @desc macOS inode 号类型 *}
  TPlatformDarwinIno = UInt64;
  {** @desc macOS 文件模式类型 *}
  TPlatformDarwinMode = UInt16;
  {** @desc macOS 硬链接计数类型 *}
  TPlatformDarwinNLink = UInt16;
  {** @desc macOS 用户 ID 类型 *}
  TPlatformDarwinUid = UInt32;
  {** @desc macOS 组 ID 类型 *}
  TPlatformDarwinGid = UInt32;
  {** @desc macOS 文件偏移类型 *}
  TPlatformDarwinOff = Int64;
  {** @desc macOS 时间类型 *}
  TPlatformDarwinTime = Int64;
  {** @desc macOS 长整型 *}
  TPlatformDarwinLong = Int64;

  {** @desc macOS 信号集类型 *}
  TPlatformDarwinSignalSet = record
    Words: array[0..0] of UInt32;
  end;
  PPlatformDarwinSignalSet = ^TPlatformDarwinSignalSet;

  {** @desc macOS 信号处理器函数类型 *}
  TPlatformDarwinSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;

  {** @desc macOS 信号动作结构体 *}
  TPlatformDarwinSigAction = record
    sa_handler: TPlatformDarwinSigActionHandler;
    sa_mask: TPlatformDarwinSignalSet;
    sa_flags: Int32;
  end;
  PPlatformDarwinSigAction = ^TPlatformDarwinSigAction;

  {** @desc macOS 文件状态结构体 *}
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
  { Darwin has no pthread_timedjoin_np; store user entry so timedjoin can poll
    a Finished flag set by a trampoline before reaping with pthread_join. }
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (
        Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte;
        UserProc: Pointer;
        UserArg: Pointer;
        RetVal: Pointer;
        Finished: LongInt
      );
  end;

  mach_timebase_info_data_t = record
    numer: UInt32;
    denom: UInt32;
  end;

const
  CLOCK_REALTIME = Int32(0);
  CLOCK_MONOTONIC = Int32(1);
  _SC_PAGESIZE = Int32(29);
  _SC_NPROCESSORS_ONLN = Int32(58);
  PTHREAD_TIMEOUT_CLOCK_ID = CLOCK_REALTIME;
  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0;
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0;

  { Darwin pthread.h: NORMAL=0, ERRORCHECK=1, RECURSIVE=2 (not Linux order). }
  _PTHREAD_MUTEX_NORMAL = 0;
  _PTHREAD_MUTEX_ERRORCHECK = 1;
  _PTHREAD_MUTEX_RECURSIVE = 2;
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
  { Darwin fcntl.h: O_FSYNC=0x80; O_SYNC is an alias of O_FSYNC. }
  O_FSYNC = Int32($80);
  O_SYNC = O_FSYNC;
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

{ socket constants - Darwin-specific values }
{$I nextpas.core.platform.darwin.base.socket.inc}

{ termios ioctl constants and winsize }
{$I nextpas.core.platform.darwin.base.termios.inc}

{ stat structure - Darwin 64-bit (new iostructs layout) }
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
  TDarwinStat = record
    st_dev: Int32;
    st_mode: UInt16;
    st_nlink: UInt16;
    st_ino: UInt64;
    st_uid: UInt32;
    st_gid: UInt32;
    st_rdev: Int32;
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
    st_gen: UInt32;
    st_lspare: Int32;
    st_qspare: array[0..1] of Int64;
  end;
{$packrecords default}

implementation

end.
