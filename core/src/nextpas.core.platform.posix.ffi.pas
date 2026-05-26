unit nextpas.core.platform.posix.ffi;

{$I nextpas.core.settings.inc}

interface

type
  timespec = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;
  PTimeSpec = ^timespec;

  {$IF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  pthread_t = Pointer;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  pthread_t = PtrInt;
  {$ELSE}
  pthread_t = PtrUInt;
  {$ENDIF}

  {$IFDEF NEXTPAS_MACOS}
  pthread_key_t = PtrUInt;
  {$ELSEIF defined(NEXTPAS_ANDROID) or defined(NEXTPAS_FREEBSD)}
  pthread_key_t = Int32;
  {$ELSE}
  pthread_key_t = UInt32;
  {$ENDIF}

  TPThreadStartRoutine = function(AArg: Pointer): Pointer; cdecl;

  {$IFDEF NEXTPAS_FREEBSD}
  pthread_mutex_t = Pointer;
  pthread_mutexattr_t = Pointer;
  pthread_rwlock_t = Pointer;
  pthread_rwlockattr_t = Pointer;
  pthread_cond_t = Pointer;
  pthread_condattr_t = Pointer;
  {$ELSEIFDEF NEXTPAS_MACOS}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..63] of Byte);
  end;

  pthread_mutexattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..15] of Byte);
  end;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..199] of Byte);
  end;

  pthread_rwlockattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..23] of Byte);
  end;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..15] of Byte);
  end;
  {$ELSEIFDEF NEXTPAS_ANDROID}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = PtrInt;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = PtrInt;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = PtrInt;
  {$ELSEIFDEF NEXTPAS_LINUX}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = Int32;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = Int64;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = Int32;
  {$ELSE}
  pthread_mutex_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..39] of Byte);
  end;

  pthread_mutexattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;

  pthread_rwlock_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..55] of Byte);
  end;

  pthread_rwlockattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;

  pthread_cond_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..47] of Byte);
  end;

  pthread_condattr_t = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..7] of Byte);
  end;
  {$ENDIF}

const
  CLOCK_REALTIME = Int32(0);
  {$IFDEF NEXTPAS_FREEBSD}
  CLOCK_MONOTONIC = Int32(4);
  {$ELSE}
  CLOCK_MONOTONIC = Int32(1);
  {$ENDIF}

  {$IFDEF NEXTPAS_FREEBSD}
  PTHREAD_MUTEX_ERRORCHECK = 1;
  PTHREAD_MUTEX_RECURSIVE  = 2;
  PTHREAD_MUTEX_NORMAL     = 3;
  {$ELSE}
  PTHREAD_MUTEX_NORMAL     = 0;
  PTHREAD_MUTEX_RECURSIVE  = 1;
  PTHREAD_MUTEX_ERRORCHECK = 2;
  {$ENDIF}

  {$IFDEF NEXTPAS_LINUX}
  _SC_NPROCESSORS_ONLN = Int32(84);
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  _SC_NPROCESSORS_ONLN = Int32(97);
  {$ELSEIF defined(NEXTPAS_MACOS)}
  _SC_NPROCESSORS_ONLN = Int32(58);
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  _SC_NPROCESSORS_ONLN = Int32(58);
  {$ELSE}
  _SC_NPROCESSORS_ONLN = Int32(-1);
  {$ENDIF}

  {$IF defined(NEXTPAS_LINUX) or defined(NEXTPAS_ANDROID)}
  POSIX_EAGAIN    = 11;
  POSIX_EBUSY     = 16;
  POSIX_EINVAL    = 22;
  POSIX_ENOTSUP   = 95;
  POSIX_ETIMEDOUT = 110;
  {$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
  POSIX_EAGAIN    = 35;
  POSIX_EBUSY     = 16;
  POSIX_EINVAL    = 22;
  POSIX_ENOTSUP   = 45;
  POSIX_ETIMEDOUT = 60;
  {$ELSE}
  POSIX_EAGAIN    = 11;
  POSIX_EBUSY     = 16;
  POSIX_EINVAL    = 22;
  POSIX_ENOTSUP   = 95;
  POSIX_ETIMEDOUT = 110;
  {$ENDIF}

function clock_gettime(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';
function clock_getres(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_getres';
function nanosleep(req: Pointer; rem: Pointer): Int32; cdecl; external 'c' name 'nanosleep';
function sched_yield: Int32; cdecl; external 'c' name 'sched_yield';
function sysconf(name: Int32): PtrInt; cdecl; external 'c' name 'sysconf';
{$IFDEF NEXTPAS_ANDROID}
function posix_errno_location: PInt32; cdecl; external 'c' name '__errno';
{$ELSEIF defined(NEXTPAS_MACOS) or defined(NEXTPAS_FREEBSD)}
function posix_errno_location: PInt32; cdecl; external 'c' name '__error';
{$ELSE}
function posix_errno_location: PInt32; cdecl; external 'c' name '__errno_location';
{$ENDIF}

function pthread_create(thread: Pointer; attr: Pointer; start_routine: TPThreadStartRoutine; arg: Pointer): Int32; cdecl; external 'pthread' name 'pthread_create';
function pthread_join(thread: pthread_t; retval: Pointer): Int32; cdecl; external 'pthread' name 'pthread_join';
function pthread_detach(thread: pthread_t): Int32; cdecl; external 'pthread' name 'pthread_detach';
function pthread_self: pthread_t; cdecl; external 'pthread' name 'pthread_self';

function pthread_key_create(key: Pointer; destructor_proc: Pointer): Int32; cdecl; external 'pthread' name 'pthread_key_create';
function pthread_key_delete(key: pthread_key_t): Int32; cdecl; external 'pthread' name 'pthread_key_delete';
function pthread_setspecific(key: pthread_key_t; value: Pointer): Int32; cdecl; external 'pthread' name 'pthread_setspecific';
function pthread_getspecific(key: pthread_key_t): Pointer; cdecl; external 'pthread' name 'pthread_getspecific';

function pthread_mutexattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_init';
function pthread_mutexattr_settype(attr: Pointer; kind: Int32): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_settype';
function pthread_mutexattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutexattr_destroy';
function pthread_mutex_init(mutex: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_init';
function pthread_mutex_destroy(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_destroy';
function pthread_mutex_lock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_lock';
function pthread_mutex_trylock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_trylock';
function pthread_mutex_unlock(mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_mutex_unlock';

function pthread_rwlock_init(rwlock: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_init';
function pthread_rwlock_destroy(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_destroy';
function pthread_rwlock_rdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_rdlock';
function pthread_rwlock_tryrdlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_tryrdlock';
function pthread_rwlock_wrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_wrlock';
function pthread_rwlock_trywrlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_trywrlock';
function pthread_rwlock_unlock(rwlock: Pointer): Int32; cdecl; external 'pthread' name 'pthread_rwlock_unlock';

function pthread_condattr_init(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_init';
function pthread_condattr_setclock(attr: Pointer; clk_id: Int32): Int32; cdecl; external 'pthread' name 'pthread_condattr_setclock';
function pthread_condattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_destroy';
function pthread_cond_init(cond: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_init';
function pthread_cond_destroy(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_destroy';
function pthread_cond_wait(cond: Pointer; mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_wait';
function pthread_cond_timedwait(cond: Pointer; mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_cond_timedwait';
function pthread_cond_signal(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_signal';
function pthread_cond_broadcast(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_broadcast';

implementation

end.
