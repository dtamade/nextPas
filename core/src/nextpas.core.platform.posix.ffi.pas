unit nextpas.core.platform.posix.ffi;

{$I nextpas.core.settings.inc}

interface

type
  timespec = record
    tv_sec: Int64;
    tv_nsec: Int64;
  end;
  PTimeSpec = ^timespec;

  pthread_mutex_t = array[0..39] of Byte;
  pthread_mutexattr_t = array[0..7] of Byte;
  pthread_rwlock_t = array[0..55] of Byte;
  pthread_cond_t = array[0..47] of Byte;
  pthread_condattr_t = array[0..7] of Byte;

const
  CLOCK_REALTIME  = 0;
  CLOCK_MONOTONIC = 1;

  PTHREAD_MUTEX_NORMAL     = 0;
  PTHREAD_MUTEX_RECURSIVE  = 1;
  PTHREAD_MUTEX_ERRORCHECK = 2;

function clock_gettime(clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';

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
