unit nextpas.core.platform.freebsd.base;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.posix.base;

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

const
  PLATFORM_CLOCK_REALTIME_ID = Int32(0);
  PLATFORM_CLOCK_MONOTONIC_ID = Int32(4);
  PLATFORM_SYSCONF_NPROCESSORS_ONLN = Int32(58);
  PLATFORM_PTHREAD_TIMEOUT_CLOCK_ID = PLATFORM_CLOCK_MONOTONIC_ID;
  PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1;

  PLATFORM_PTHREAD_MUTEX_ERRORCHECK_KIND = 1;
  PLATFORM_PTHREAD_MUTEX_RECURSIVE_KIND = 2;
  PLATFORM_PTHREAD_MUTEX_NORMAL_KIND = 3;
  PLATFORM_PTHREAD_TOKEN_SIZE = SizeOf(pthread_t);
  PLATFORM_PTHREAD_MUTEX_SIZE = SizeOf(pthread_mutex_t);
  PLATFORM_PTHREAD_RWLOCK_SIZE = SizeOf(pthread_rwlock_t);
  PLATFORM_PTHREAD_CONDVAR_SIZE = SizeOf(pthread_cond_t);

  PLATFORM_POSIX_EAGAIN = 35;
  PLATFORM_POSIX_EBUSY = 16;
  PLATFORM_POSIX_EINTR = 4;
  PLATFORM_POSIX_EINVAL = 22;
  PLATFORM_POSIX_ENOTSUP = 45;
  PLATFORM_POSIX_ETIMEDOUT = 60;

implementation

end.
