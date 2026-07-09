unit nextpas.core.platform.unix.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

const
  {** @desc Unix pthread 令牌大小 *}
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);

type
  {** @desc Unix pthread 令牌对齐记录 *}
  TPlatformPThreadTokenAlign = record
    Value: pthread_t;
  end;

  {** @desc Unix pthread 互斥锁对齐记录 *}
  TPlatformPThreadMutexAlign = record
    Value: pthread_mutex_t;
  end;

  {** @desc Unix pthread 读写锁对齐记录 *}
  TPlatformPThreadRwLockAlign = record
    Value: pthread_rwlock_t;
  end;

  {** @desc Unix pthread 条件变量对齐记录 *}
  TPlatformPThreadCondVarAlign = record
    Value: pthread_cond_t;
  end;

  {** @desc Unix 进程 ID 类型 *}
  TPlatformProcessId = pid_t;

  {** @desc Unix 信号集类型 *}
  TPlatformUnixSignalSet = record
    Words: array[0..1] of PtrUInt;
  end;
  PPlatformUnixSignalSet = ^TPlatformUnixSignalSet;

  {** @desc Unix 信号处理器函数类型 *}
  TPlatformUnixSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;

  {** @desc Unix 信号动作结构体 *}
  TPlatformUnixSigAction = record
    sa_handler: TPlatformUnixSigActionHandler;
    sa_mask: TPlatformUnixSignalSet;
    sa_flags: Int32;
  end;
  PPlatformUnixSigAction = ^TPlatformUnixSigAction;

  {** @desc Unix pthread 状态联合体 *}
  PPlatformPThreadState = ^TPlatformPThreadState;
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
  end;

const
  {** @desc 实时时钟 ID *}
  CLOCK_REALTIME = Int32(0);
  {** @desc 单调时钟 ID *}
  CLOCK_MONOTONIC = Int32(1);
  {** @desc 页面大小配置项 *}
  _SC_PAGESIZE = Int32(-1);
  {** @desc 在线处理器数配置项 *}
  _SC_NPROCESSORS_ONLN = Int32(-1);
  {** @desc pthread 超时时钟 ID *}
  PTHREAD_TIMEOUT_CLOCK_ID = CLOCK_MONOTONIC;
  {** @desc pthread 条件变量是否支持设置时钟 *}
  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  {** @desc pthread 互斥锁是否支持超时锁定 *}
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0;

  {** @desc pthread 普通互斥锁类型 *}
  _PTHREAD_MUTEX_NORMAL = 0;
  {** @desc pthread 递归互斥锁类型 *}
  _PTHREAD_MUTEX_RECURSIVE = 1;
  {** @desc pthread 错误检查互斥锁类型 *}
  _PTHREAD_MUTEX_ERRORCHECK = 2;
  {** @desc pthread 互斥锁大小 *}
  PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  {** @desc pthread 读写锁大小 *}
  PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  {** @desc pthread 条件变量大小 *}
  PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  {** @desc EAGAIN 错误码 *}
  ESysEAGAIN = 11;
  {** @desc EBUSY 错误码 *}
  ESysEBUSY = 16;
  {** @desc EINTR 错误码 *}
  ESysEINTR = 4;
  {** @desc EINVAL 错误码 *}
  ESysEINVAL = 22;
  {** @desc EOPNOTSUPP 错误码 *}
  ESysEOPNOTSUPP = 95;
  {** @desc ETIMEDOUT 错误码 *}
  ESysETIMEDOUT = 110;

  {** @desc waitpid 不阻塞标志 *}
  WNOHANG = Int32(1);
  {** @desc waitpid 返回停止状态 *}
  WUNTRACED = Int32(2);

  { Signal numbers, signal-handler sentinels, and sigprocmask actions are
    host-specific. Each platform base unit defines them in its signal.inc. }

  RTLD_LAZY = Int32(1);
  RTLD_NOW = Int32(2);
  RTLD_LOCAL = Int32(0);
  RTLD_GLOBAL = Int32($100);

  O_RDONLY = Int32(0);
  O_WRONLY = Int32(1);
  O_RDWR = Int32(2);
  O_CREAT = Int32($100);
  O_EXCL = Int32($400);
  O_TRUNC = Int32($200);
  O_APPEND = Int32($8);

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

implementation

end.
