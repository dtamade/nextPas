unit nextpas.core.platform.unix.base;

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

  TPlatformUnixSignalSet = record
    Words: array[0..1] of PtrUInt;
  end;
  PPlatformUnixSignalSet = ^TPlatformUnixSignalSet;

  TPlatformUnixSigActionHandler = procedure(
    ASignal: Int32;
    AInfo: Pointer;
    AContext: Pointer); cdecl;

  TPlatformUnixSigAction = record
    sa_handler: TPlatformUnixSigActionHandler;
    sa_mask: TPlatformUnixSignalSet;
    sa_flags: Int32;
  end;
  PPlatformUnixSigAction = ^TPlatformUnixSigAction;

  PPlatformPThreadState = ^TPlatformPThreadState;
  TPlatformPThreadState = record
    case Integer of
      0: (FAlign: TPlatformPThreadTokenAlign);
      1: (Thread: array[0..PLATFORM_PTHREAD_TOKEN_SIZE - 1] of Byte);
  end;

const
  CLOCK_REALTIME = Int32(0);
  CLOCK_MONOTONIC = Int32(1);
  _SC_NPROCESSORS_ONLN = Int32(-1);
  PTHREAD_TIMEOUT_CLOCK_ID = CLOCK_MONOTONIC;
  PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0;

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
