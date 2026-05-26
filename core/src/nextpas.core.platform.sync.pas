unit nextpas.core.platform.sync;

{$I nextpas.core.settings.inc}

interface

const
  {$IFDEF NEXTPAS_LINUX}
  PLATFORM_MUTEX_SIZE   = 48;
  PLATFORM_RWLOCK_SIZE  = 56;
  PLATFORM_CONDVAR_SIZE = 48;
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  PLATFORM_MUTEX_SIZE   = 40;
  PLATFORM_RWLOCK_SIZE  = 56;
  PLATFORM_CONDVAR_SIZE = 48;
  {$ELSEIF defined(NEXTPAS_MACOS)}
  PLATFORM_MUTEX_SIZE   = 64;
  PLATFORM_RWLOCK_SIZE  = 200;
  PLATFORM_CONDVAR_SIZE = 48;
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  PLATFORM_MUTEX_SIZE   = 8;
  PLATFORM_RWLOCK_SIZE  = 8;
  PLATFORM_CONDVAR_SIZE = 8;
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  PLATFORM_MUTEX_SIZE   = 40;
  PLATFORM_RWLOCK_SIZE  = 8;
  PLATFORM_CONDVAR_SIZE = 8;
  {$ELSEIF defined(NEXTPAS_UNIX)}
  PLATFORM_MUTEX_SIZE   = 64;
  PLATFORM_RWLOCK_SIZE  = 256;
  PLATFORM_CONDVAR_SIZE = 64;
  {$ELSE}
  PLATFORM_MUTEX_SIZE   = 64;
  PLATFORM_RWLOCK_SIZE  = 64;
  PLATFORM_CONDVAR_SIZE = 64;
  {$ENDIF}

type
  TPlatformMutex = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..PLATFORM_MUTEX_SIZE - 1] of Byte);
  end;

  TPlatformRwLock = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..PLATFORM_RWLOCK_SIZE - 1] of Byte);
  end;

  TPlatformCondVar = record
    case Integer of
      0: (FAlign: UInt64);
      1: (FOpaque: array[0..PLATFORM_CONDVAR_SIZE - 1] of Byte);
  end;

const
  PLATFORM_MUTEX_NORMAL     = 0;
  PLATFORM_MUTEX_ERRORCHECK = 1;
  PLATFORM_MUTEX_RECURSIVE  = 2;

  PLATFORM_ERR_AGAIN       = 11;
  PLATFORM_ERR_BUSY        = 16;
  PLATFORM_ERR_INVALID     = 22;
  PLATFORM_ERR_UNSUPPORTED = 95;
  PLATFORM_ERR_TIMEOUT     = 110;

{ Mutex }
function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32 = PLATFORM_MUTEX_ERRORCHECK): Int32;
function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32;
function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32;
function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;

{ RWLock }
function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;

{ CondVar }
function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32;
function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32;
function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32;
function platform_condvar_timedwait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex; const ATimeoutNs: Int64): Int32;
function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32;
function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32;

{ Address-wait (portable futex abstraction) }
function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
function platform_wake_address_one(AAddr: PInt32): Int32;
function platform_wake_address_all(AAddr: PInt32): Int32;

implementation

{$IFDEF NEXTPAS_UNIX}
uses
  nextpas.core.platform.posix.ffi
  {$IFDEF NEXTPAS_LINUX}, nextpas.core.platform.linux.ffi{$ENDIF};
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ENDIF}

const
  NANOSECONDS_PER_SECOND = UInt64(1000000000);

{$IFDEF NEXTPAS_UNIX}
const
  POSIX_WAIT_BUCKET_COUNT = 64;

type
  TPosixWaitBucket = record
    Mutex: TPlatformMutex;
    CondVar: TPlatformCondVar;
    Waiters: Int32;
    Generation: UInt64;
  end;

var
  GPosixWaitBuckets: array[0..POSIX_WAIT_BUCKET_COUNT - 1] of TPosixWaitBucket;
  GPosixWaitBucketsState: Int32 = 0;
  GPosixWaitBucketsInitResult: Int32 = 0;

function platform_posix_errno: Int32; inline;
begin
  {$IFDEF NEXTPAS_LINUX}
  Result := linux_errno_location^;
  {$ELSE}
  Result := posix_errno_location^;
  {$ENDIF}
end;

function platform_posix_map_error(const ACode: Int32): Int32; inline;
begin
  case ACode of
    0: Result := 0;
    POSIX_EAGAIN: Result := PLATFORM_ERR_AGAIN;
    POSIX_EBUSY: Result := PLATFORM_ERR_BUSY;
    POSIX_EINVAL: Result := PLATFORM_ERR_INVALID;
    POSIX_ENOTSUP: Result := PLATFORM_ERR_UNSUPPORTED;
    POSIX_ETIMEDOUT: Result := PLATFORM_ERR_TIMEOUT;
  else
    Result := ACode;
  end;
end;

function platform_posix_timeout_clock_id: Int32; inline;
begin
  {$IFDEF NEXTPAS_MACOS}
  Result := CLOCK_REALTIME;
  {$ELSE}
  Result := CLOCK_MONOTONIC;
  {$ENDIF}
end;

function platform_posix_now(out ATime: timespec): Int32;
begin
  if clock_gettime(platform_posix_timeout_clock_id, @ATime) = 0 then
    Result := 0
  else
    Result := platform_posix_map_error(platform_posix_errno);
end;

procedure platform_posix_add_timeout(var ATime: timespec; const ANanoseconds: UInt64); inline;
var
  LSeconds: UInt64;
  LNanos: UInt64;
begin
  LSeconds := ANanoseconds div NANOSECONDS_PER_SECOND;
  LNanos := ANanoseconds mod NANOSECONDS_PER_SECOND;
  ATime.tv_sec := ATime.tv_sec + Int64(LSeconds);
  ATime.tv_nsec := ATime.tv_nsec + Int64(LNanos);
  if ATime.tv_nsec >= Int64(NANOSECONDS_PER_SECOND) then
  begin
    Inc(ATime.tv_sec);
    Dec(ATime.tv_nsec, Int64(NANOSECONDS_PER_SECOND));
  end;
end;

function platform_posix_timespec_to_ns(const ATime: timespec): UInt64; inline;
var
  LSecNs: UInt64;
begin
  if (ATime.tv_sec <= 0) and (ATime.tv_nsec <= 0) then
    Exit(0);

  if ATime.tv_sec > 0 then
  begin
    if UInt64(ATime.tv_sec) > High(UInt64) div NANOSECONDS_PER_SECOND then
      Exit(High(UInt64));
    LSecNs := UInt64(ATime.tv_sec) * NANOSECONDS_PER_SECOND;
  end
  else
    LSecNs := 0;

  if ATime.tv_nsec > 0 then
  begin
    if LSecNs > High(UInt64) - UInt64(ATime.tv_nsec) then
      Exit(High(UInt64));
    Result := LSecNs + UInt64(ATime.tv_nsec);
  end
  else
    Result := LSecNs;
end;

function platform_posix_remaining_ns(const ADeadline: timespec; const ANow: timespec): UInt64; inline;
var
  LDeadlineNs: UInt64;
  LNowNs: UInt64;
begin
  LDeadlineNs := platform_posix_timespec_to_ns(ADeadline);
  LNowNs := platform_posix_timespec_to_ns(ANow);
  if LDeadlineNs <= LNowNs then
    Exit(0);
  Result := LDeadlineNs - LNowNs;
end;

function platform_posix_bucket_index(AAddr: PInt32): PtrUInt; inline;
begin
  Result := (PtrUInt(AAddr) shr 2) and PtrUInt(POSIX_WAIT_BUCKET_COUNT - 1);
end;

function platform_posix_mutex_kind(const AKind: Int32): Int32; inline;
begin
  case AKind of
    PLATFORM_MUTEX_NORMAL: Result := PTHREAD_MUTEX_NORMAL;
    PLATFORM_MUTEX_RECURSIVE: Result := PTHREAD_MUTEX_RECURSIVE;
  else
    Result := PTHREAD_MUTEX_ERRORCHECK;
  end;
end;

function platform_posix_mutex_init_impl(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
var
  LAttr: pthread_mutexattr_t;
begin
  FillChar(AMutex, SizeOf(AMutex), 0);
  Result := platform_posix_map_error(pthread_mutexattr_init(@LAttr));
  if Result <> 0 then
    Exit;
  try
    Result := platform_posix_map_error(
      pthread_mutexattr_settype(@LAttr, platform_posix_mutex_kind(AKind)));
    if Result <> 0 then
      Exit;
    Result := platform_posix_map_error(pthread_mutex_init(@AMutex.FOpaque[0], @LAttr));
  finally
    pthread_mutexattr_destroy(@LAttr);
  end;
end;

function platform_posix_condvar_init_impl(var ACondVar: TPlatformCondVar): Int32;
var
  LAttr: pthread_condattr_t;
begin
  FillChar(ACondVar, SizeOf(ACondVar), 0);
  Result := platform_posix_map_error(pthread_condattr_init(@LAttr));
  if Result <> 0 then
    Exit;
  try
    {$IFNDEF NEXTPAS_MACOS}
    Result := platform_posix_map_error(
      pthread_condattr_setclock(@LAttr, platform_posix_timeout_clock_id));
    if Result <> 0 then
      Exit;
    {$ENDIF}
    Result := platform_posix_map_error(pthread_cond_init(@ACondVar.FOpaque[0], @LAttr));
  finally
    pthread_condattr_destroy(@LAttr);
  end;
end;

function platform_posix_condvar_timedwait_abs(
  var ACondVar: TPlatformCondVar;
  var AMutex: TPlatformMutex;
  const ADeadline: timespec): Int32;
var
  LDeadline: timespec;
begin
  LDeadline := ADeadline;
  Result := platform_posix_map_error(
    pthread_cond_timedwait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0], @LDeadline));
end;

procedure platform_posix_wait_buckets_destroy_range(const ALastIndex: Integer);
var
  I: Integer;
begin
  for I := ALastIndex downto 0 do
  begin
    platform_condvar_destroy(GPosixWaitBuckets[I].CondVar);
    platform_mutex_destroy(GPosixWaitBuckets[I].Mutex);
  end;
end;

function platform_posix_wait_buckets_init: Int32;
var
  I: Integer;
begin
  for I := 0 to POSIX_WAIT_BUCKET_COUNT - 1 do
  begin
    GPosixWaitBuckets[I].Waiters := 0;
    GPosixWaitBuckets[I].Generation := 0;
    Result := platform_posix_mutex_init_impl(
      GPosixWaitBuckets[I].Mutex, PLATFORM_MUTEX_NORMAL);
    if Result <> 0 then
    begin
      if I > 0 then
        platform_posix_wait_buckets_destroy_range(I - 1);
      Exit;
    end;
    Result := platform_posix_condvar_init_impl(GPosixWaitBuckets[I].CondVar);
    if Result <> 0 then
    begin
      platform_mutex_destroy(GPosixWaitBuckets[I].Mutex);
      if I > 0 then
        platform_posix_wait_buckets_destroy_range(I - 1);
      Exit;
    end;
  end;
  Result := 0;
end;

function platform_posix_ensure_wait_buckets: Int32;
begin
  if InterlockedCompareExchange(GPosixWaitBucketsState, 0, 0) = 2 then
    Exit(GPosixWaitBucketsInitResult);

  if InterlockedCompareExchange(GPosixWaitBucketsState, 1, 0) = 0 then
  begin
    GPosixWaitBucketsInitResult := platform_posix_wait_buckets_init;
    InterlockedExchange(GPosixWaitBucketsState, 2);
    Exit(GPosixWaitBucketsInitResult);
  end;

  while InterlockedCompareExchange(GPosixWaitBucketsState, 0, 0) <> 2 do
    sched_yield;
  Result := GPosixWaitBucketsInitResult;
end;

{ Mutex }

function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
begin
  Result := platform_posix_mutex_init_impl(AMutex, AKind);
end;

function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(pthread_mutex_destroy(@AMutex.FOpaque[0]));
end;

function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(pthread_mutex_lock(@AMutex.FOpaque[0]));
end;

function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(pthread_mutex_trylock(@AMutex.FOpaque[0]));
end;

function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(pthread_mutex_unlock(@AMutex.FOpaque[0]));
end;

{ RWLock }

function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32;
begin
  FillChar(ARwLock, SizeOf(ARwLock), 0);
  Result := platform_posix_map_error(pthread_rwlock_init(@ARwLock.FOpaque[0], nil));
end;

function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_destroy(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_rdlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_tryrdlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_wrlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_trywrlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_unlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(pthread_rwlock_unlock(@ARwLock.FOpaque[0]));
end;

{ CondVar }

function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_condvar_init_impl(ACondVar);
end;

function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_map_error(pthread_cond_destroy(@ACondVar.FOpaque[0]));
end;

function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(
    pthread_cond_wait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0]));
end;

function platform_condvar_timedwait(
  var ACondVar: TPlatformCondVar;
  var AMutex: TPlatformMutex;
  const ATimeoutNs: Int64): Int32;
var
  LDeadline: timespec;
begin
  if ATimeoutNs < 0 then
    Exit(platform_condvar_wait(ACondVar, AMutex));

  Result := platform_posix_now(LDeadline);
  if Result <> 0 then
    Exit;

  platform_posix_add_timeout(LDeadline, UInt64(ATimeoutNs));
  Result := platform_posix_condvar_timedwait_abs(ACondVar, AMutex, LDeadline);
end;

function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_map_error(pthread_cond_signal(@ACondVar.FOpaque[0]));
end;

function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_map_error(pthread_cond_broadcast(@ACondVar.FOpaque[0]));
end;

function platform_posix_wait_address_fallback(
  AAddr: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64): Int32;
var
  LBucket: ^TPosixWaitBucket;
  LDeadline: timespec;
  LNow: timespec;
  LRemainingNs: UInt64;
  LGeneration: UInt64;
  LRet: Int32;
  LLocked: Boolean;
  LWaiting: Boolean;
  LDone: Boolean;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);
  if AAddr^ <> AExpected then
    Exit(PLATFORM_ERR_AGAIN);

  Result := platform_posix_ensure_wait_buckets;
  if Result <> 0 then
    Exit;

  LBucket := @GPosixWaitBuckets[platform_posix_bucket_index(AAddr)];
  LLocked := False;
  LWaiting := False;
  LDone := False;

  Result := platform_mutex_lock(LBucket^.Mutex);
  if Result <> 0 then
    Exit;
  LLocked := True;
  try
    if AAddr^ <> AExpected then
      Result := PLATFORM_ERR_AGAIN
    else if ATimeoutNs = 0 then
      Result := PLATFORM_ERR_TIMEOUT
    else
    begin
      Inc(LBucket^.Waiters);
      LWaiting := True;
      LGeneration := LBucket^.Generation;

      if ATimeoutNs > 0 then
      begin
        Result := platform_posix_now(LDeadline);
        if Result = 0 then
          platform_posix_add_timeout(LDeadline, UInt64(ATimeoutNs))
        else
          LDone := True;
      end;

      while (Result = 0) and not LDone do
      begin
        if ATimeoutNs < 0 then
          LRet := platform_condvar_wait(LBucket^.CondVar, LBucket^.Mutex)
        else
        begin
          Result := platform_posix_now(LNow);
          if Result <> 0 then
            Break;
          LRemainingNs := platform_posix_remaining_ns(LDeadline, LNow);
          if LRemainingNs = 0 then
          begin
            Result := PLATFORM_ERR_TIMEOUT;
            Break;
          end;
          LRet := platform_posix_condvar_timedwait_abs(
            LBucket^.CondVar, LBucket^.Mutex, LDeadline);
        end;

        if LRet = 0 then
        begin
          if (LBucket^.Generation <> LGeneration) or (AAddr^ <> AExpected) then
            LDone := True;
        end
        else if LRet = PLATFORM_ERR_TIMEOUT then
        begin
          if (LBucket^.Generation <> LGeneration) or (AAddr^ <> AExpected) then
            Result := 0
          else
            Result := PLATFORM_ERR_TIMEOUT;
          LDone := True;
        end
        else
        begin
          Result := LRet;
          LDone := True;
        end;
      end;
    end;
  finally
    if LWaiting then
      Dec(LBucket^.Waiters);
    if LLocked then
      platform_mutex_unlock(LBucket^.Mutex);
  end;
end;

function platform_posix_wake_address_one_fallback(AAddr: PInt32): Int32;
var
  LBucket: ^TPosixWaitBucket;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);

  Result := platform_posix_ensure_wait_buckets;
  if Result <> 0 then
    Exit;

  LBucket := @GPosixWaitBuckets[platform_posix_bucket_index(AAddr)];
  Result := platform_mutex_lock(LBucket^.Mutex);
  if Result <> 0 then
    Exit;
  try
    Inc(LBucket^.Generation);
    if LBucket^.Waiters > 0 then
      Result := platform_condvar_signal(LBucket^.CondVar)
    else
      Result := 0;
  finally
    platform_mutex_unlock(LBucket^.Mutex);
  end;
end;

function platform_posix_wake_address_all_fallback(AAddr: PInt32): Int32;
var
  LBucket: ^TPosixWaitBucket;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);

  Result := platform_posix_ensure_wait_buckets;
  if Result <> 0 then
    Exit;

  LBucket := @GPosixWaitBuckets[platform_posix_bucket_index(AAddr)];
  Result := platform_mutex_lock(LBucket^.Mutex);
  if Result <> 0 then
    Exit;
  try
    Inc(LBucket^.Generation);
    if LBucket^.Waiters > 0 then
      Result := platform_condvar_broadcast(LBucket^.CondVar)
    else
      Result := 0;
  finally
    platform_mutex_unlock(LBucket^.Mutex);
  end;
end;

{$IFDEF NEXTPAS_LINUX}
{$IFNDEF NEXTPAS_PLATFORM_SYNC_FORCE_POSIX_WAIT_FALLBACK}
{ Address-wait (futex on Linux) }

function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
var
  LTs: timespec;
  LRet: PtrInt;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);

  if ATimeoutNs < 0 then
  begin
    LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG), PtrUInt(UInt32(AExpected)),
      PtrUInt(0), PtrUInt(0), PtrUInt(0));
  end
  else
  begin
    LTs.tv_sec := ATimeoutNs div 1000000000;
    LTs.tv_nsec := ATimeoutNs mod 1000000000;
    LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG), PtrUInt(UInt32(AExpected)),
      PtrUInt(@LTs), PtrUInt(0), PtrUInt(0));
  end;
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_map_error(platform_posix_errno);
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);

  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(1),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_map_error(platform_posix_errno);
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);

  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(High(Int32)),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_posix_map_error(platform_posix_errno);
end;
{$ENDIF}
{$ENDIF}

{$IFNDEF NEXTPAS_LINUX}
{ Address-wait (generic POSIX fallback) }
function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
begin
  Result := platform_posix_wait_address_fallback(AAddr, AExpected, ATimeoutNs);
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
begin
  Result := platform_posix_wake_address_one_fallback(AAddr);
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
begin
  Result := platform_posix_wake_address_all_fallback(AAddr);
end;
{$ELSE}
{$IFDEF NEXTPAS_PLATFORM_SYNC_FORCE_POSIX_WAIT_FALLBACK}
{ Address-wait (generic POSIX fallback forced on Linux for verification) }
function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
begin
  Result := platform_posix_wait_address_fallback(AAddr, AExpected, ATimeoutNs);
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
begin
  Result := platform_posix_wake_address_one_fallback(AAddr);
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
begin
  Result := platform_posix_wake_address_all_fallback(AAddr);
end;
{$ENDIF}
{$ENDIF}
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}

function platform_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD;
var
  LMs: UInt64;
begin
  if ATimeoutNs < 0 then
    Exit(INFINITE);
  if ATimeoutNs = 0 then
    Exit(0);

  LMs := UInt64(ATimeoutNs div 1000000);
  if (ATimeoutNs mod 1000000) <> 0 then
    Inc(LMs);
  if LMs >= UInt64(INFINITE) then
    Result := INFINITE - 1
  else
    Result := DWORD(LMs);
end;

{ Mutex - SRWLOCK based (exclusive only for mutex semantics) }

function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
begin
  FillChar(AMutex, SizeOf(AMutex), 0);
  InitializeSRWLock(@AMutex.FOpaque[0]);
  Result := 0;
end;

function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32;
begin
  Result := 0;
end;

function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
begin
  AcquireSRWLockExclusive(@AMutex.FOpaque[0]);
  Result := 0;
end;

function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32;
begin
  if TryAcquireSRWLockExclusive(@AMutex.FOpaque[0]) then
    Result := 0
  else
    Result := PLATFORM_ERR_BUSY;
end;

function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;
begin
  ReleaseSRWLockExclusive(@AMutex.FOpaque[0]);
  Result := 0;
end;

{ RWLock - SRWLOCK }

function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32;
begin
  FillChar(ARwLock, SizeOf(ARwLock), 0);
  InitializeSRWLock(@ARwLock.FOpaque[0]);
  Result := 0;
end;

function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := 0;
end;

function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  AcquireSRWLockShared(@ARwLock.FOpaque[0]);
  Result := 0;
end;

function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  if TryAcquireSRWLockShared(@ARwLock.FOpaque[0]) then
    Result := 0
  else
    Result := PLATFORM_ERR_BUSY;
end;

function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  AcquireSRWLockExclusive(@ARwLock.FOpaque[0]);
  Result := 0;
end;

function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  if TryAcquireSRWLockExclusive(@ARwLock.FOpaque[0]) then
    Result := 0
  else
    Result := PLATFORM_ERR_BUSY;
end;

function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  ReleaseSRWLockShared(@ARwLock.FOpaque[0]);
  Result := 0;
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  ReleaseSRWLockExclusive(@ARwLock.FOpaque[0]);
  Result := 0;
end;

{ CondVar - CONDITION_VARIABLE }

function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32;
begin
  FillChar(ACondVar, SizeOf(ACondVar), 0);
  InitializeConditionVariable(@ACondVar.FOpaque[0]);
  Result := 0;
end;

function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := 0;
end;

function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32;
begin
  if SleepConditionVariableSRW(@ACondVar.FOpaque[0], @AMutex.FOpaque[0], INFINITE, 0) then
    Result := 0
  else
    Result := GetLastError;
end;

function platform_condvar_timedwait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex; const ATimeoutNs: Int64): Int32;
var
  LMs: DWORD;
begin
  LMs := platform_timeout_ns_to_ms(ATimeoutNs);
  if SleepConditionVariableSRW(@ACondVar.FOpaque[0], @AMutex.FOpaque[0], LMs, 0) then
    Result := 0
  else if GetLastError = ERROR_TIMEOUT then
    Result := PLATFORM_ERR_TIMEOUT
  else
    Result := GetLastError;
end;

function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32;
begin
  WakeConditionVariable(@ACondVar.FOpaque[0]);
  Result := 0;
end;

function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32;
begin
  WakeAllConditionVariable(@ACondVar.FOpaque[0]);
  Result := 0;
end;

{ Address-wait (WaitOnAddress on Windows 8+) }

function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
var
  LMs: DWORD;
  LExpected: Int32;
begin
  LExpected := AExpected;
  LMs := platform_timeout_ns_to_ms(ATimeoutNs);
  if WaitOnAddress(AAddr, @LExpected, SizeOf(Int32), LMs) then
    Result := 0
  else if GetLastError = ERROR_TIMEOUT then
    Result := PLATFORM_ERR_TIMEOUT
  else
    Result := GetLastError;
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
begin
  WakeByAddressSingle(AAddr);
  Result := 0;
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
begin
  WakeByAddressAll(AAddr);
  Result := 0;
end;

{$ENDIF}

{$IFNDEF NEXTPAS_UNIX}{$IFNDEF NEXTPAS_WINDOWS}
function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_mutex_lock(var AMutex: TPlatformMutex): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_condvar_timedwait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex; const ATimeoutNs: Int64): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_wake_address_one(AAddr: PInt32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
function platform_wake_address_all(AAddr: PInt32): Int32; begin Result := PLATFORM_ERR_UNSUPPORTED; end;
{$ENDIF}{$ENDIF}

end.
