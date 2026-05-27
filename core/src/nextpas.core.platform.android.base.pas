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
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(1);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(97);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;
  PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 0;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 2;
  PLATFORM_PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PLATFORM_PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PLATFORM_PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  PLATFORM_POSIX_EAGAIN = 11;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 95;
  PLATFORM_POSIX_ETIMEDOUT = 110;

  PLATFORM_WAIT_NOHANG = Int32(1);
  PLATFORM_WAIT_UNTRACED = Int32(2);

  PLATFORM_SIGNAL_HANGUP = Int32(1);
  PLATFORM_SIGNAL_INTERRUPT = Int32(2);
  PLATFORM_SIGNAL_KILL = Int32(9);
  PLATFORM_SIGNAL_TERMINATE = Int32(15);
  PLATFORM_SIGNAL_CHILD = Int32(17);

  PLATFORM_RTLD_LAZY = Int32(1);
  PLATFORM_RTLD_NOW = Int32(2);
  PLATFORM_RTLD_LOCAL = Int32(0);
  PLATFORM_RTLD_GLOBAL = Int32($100);

  PLATFORM_OPEN_READ_ONLY = Int32(0);
  PLATFORM_OPEN_WRITE_ONLY = Int32(1);
  PLATFORM_OPEN_READ_WRITE = Int32(2);
  PLATFORM_OPEN_CREATE = Int32($40);
  PLATFORM_OPEN_EXCLUSIVE = Int32($80);
  PLATFORM_OPEN_TRUNCATE = Int32($200);
  PLATFORM_OPEN_APPEND = Int32($400);
  PLATFORM_OPEN_CLOSE_ON_EXEC = Int32($80000);

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

  PLATFORM_ANDROID_AT_FDCWD = Int32(-100);
  PLATFORM_ANDROID_AT_SYMLINK_NOFOLLOW = Int32($100);

  {$IFDEF NEXTPAS_X86_64}
  ANDROID_SYSCALL_FSTAT = 5;
  ANDROID_SYSCALL_NEWFSTATAT = 262;
  {$ELSEIF defined(NEXTPAS_AARCH64)}
  ANDROID_SYSCALL_NEWFSTATAT = 79;
  ANDROID_SYSCALL_FSTAT = 80;
  {$ELSE}
    {$FATAL 'nextpas.core.platform.android.base: unsupported Android CPU for stat syscalls'}
  {$ENDIF}

implementation

end.
