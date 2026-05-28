unit nextpas.core.platform.sync;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.sync.base;

type
  TPlatformMutexAlign = nextpas.core.platform.sync.base.TPlatformMutexAlign;
  TPlatformRwLockAlign = nextpas.core.platform.sync.base.TPlatformRwLockAlign;
  TPlatformCondVarAlign = nextpas.core.platform.sync.base.TPlatformCondVarAlign;
  TPlatformMutex = nextpas.core.platform.sync.base.TPlatformMutex;
  TPlatformRwLock = nextpas.core.platform.sync.base.TPlatformRwLock;
  TPlatformCondVar = nextpas.core.platform.sync.base.TPlatformCondVar;

const
  PTHREAD_MUTEX_SIZE = nextpas.core.platform.sync.base.PTHREAD_MUTEX_SIZE;
  PTHREAD_RWLOCK_SIZE = nextpas.core.platform.sync.base.PTHREAD_RWLOCK_SIZE;
  PTHREAD_CONDVAR_SIZE = nextpas.core.platform.sync.base.PTHREAD_CONDVAR_SIZE;
  PLATFORM_MUTEX_NORMAL = nextpas.core.platform.sync.base.PLATFORM_MUTEX_NORMAL;
  PLATFORM_MUTEX_ERRORCHECK = nextpas.core.platform.sync.base.PLATFORM_MUTEX_ERRORCHECK;
  PLATFORM_MUTEX_RECURSIVE = nextpas.core.platform.sync.base.PLATFORM_MUTEX_RECURSIVE;
  PLATFORM_ERR_AGAIN = nextpas.core.platform.sync.base.PLATFORM_ERR_AGAIN;
  PLATFORM_ERR_BUSY = nextpas.core.platform.sync.base.PLATFORM_ERR_BUSY;
  PLATFORM_ERR_INVALID = nextpas.core.platform.sync.base.PLATFORM_ERR_INVALID;
  PLATFORM_ERR_UNSUPPORTED = nextpas.core.platform.sync.base.PLATFORM_ERR_UNSUPPORTED;
  PLATFORM_ERR_TIMEOUT = nextpas.core.platform.sync.base.PLATFORM_ERR_TIMEOUT;

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
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.posix.math
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.linux.base
  , nextpas.core.platform.linux.ffi
  {$ELSEIF defined(NEXTPAS_MACOS)}
  , nextpas.core.platform.darwin.base
  , nextpas.core.platform.darwin.ffi
  {$ELSEIF defined(NEXTPAS_ANDROID)}
  , nextpas.core.platform.android.base
  , nextpas.core.platform.android.ffi
  {$ELSEIF defined(NEXTPAS_FREEBSD)}
  , nextpas.core.platform.freebsd.base
  , nextpas.core.platform.freebsd.ffi
  {$ELSE}
  , nextpas.core.platform.unix.base
  , nextpas.core.platform.unix.ffi
  {$ENDIF}
  ;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.base,
  nextpas.core.platform.windows.ffi;
{$ENDIF}

function platform_sync_validate_address(AAddr: PInt32): Int32; inline;
begin
  if AAddr = nil then
    Exit(PLATFORM_ERR_INVALID);
  Result := 0;
end;

function platform_sync_validate_wait_address(AAddr: PInt32; const AExpected: Int32): Int32; inline;
begin
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;
  if AAddr^ <> AExpected then
    Result := PLATFORM_ERR_AGAIN;
end;

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

function platform_sync_host_pthread_sync_result(
  const AError: Int32;
  const AAgainResult: Int32;
  const ABusyResult: Int32;
  const AInvalidResult: Int32;
  const AUnsupportedResult: Int32;
  const ATimeoutResult: Int32): Int32; inline;
begin
  if AError = 0 then
    Result := 0
  else if AError = ESysEAGAIN then
    Result := AAgainResult
  else if AError = ESysEBUSY then
    Result := ABusyResult
  else if AError = ESysEINVAL then
    Result := AInvalidResult
  else if AError = ESysEOPNOTSUPP then
    Result := AUnsupportedResult
  else if AError = ESysETIMEDOUT then
    Result := ATimeoutResult
  else
    Result := AError;
end;

function platform_sync_host_pthread_mutex_init_platform_kind(AMutex: Pointer; const AKind: Int32): Int32; inline;
var
  LAttr: pthread_mutexattr_t;
  LHostKind: Int32;
begin
  case AKind of
    PLATFORM_MUTEX_NORMAL:
      LHostKind := _PTHREAD_MUTEX_NORMAL;
    PLATFORM_MUTEX_RECURSIVE:
      LHostKind := _PTHREAD_MUTEX_RECURSIVE;
  else
    LHostKind := _PTHREAD_MUTEX_ERRORCHECK;
  end;

  Result := pthread_mutexattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    Result := pthread_mutexattr_settype(@LAttr, LHostKind);
    if Result <> 0 then
      Exit;
    Result := pthread_mutex_init(AMutex, @LAttr);
  finally
    pthread_mutexattr_destroy(@LAttr);
  end;
end;

function platform_sync_host_pthread_condvar_init(ACondVar: Pointer): Int32; inline;
var
  LAttr: pthread_condattr_t;
begin
  Result := pthread_condattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    {$IFDEF NEXTPAS_MACOS}
    Result := pthread_cond_init(ACondVar, @LAttr);
    {$ELSE}
    if PTHREAD_CONDATTR_SETCLOCK_SUPPORTED <> 0 then
    begin
      {$IFDEF NEXTPAS_LINUX}
      Result := pthread_condattr_setclock(@LAttr, PTHREAD_TIMEOUT_CLOCK_ID);
      {$ELSEIF defined(NEXTPAS_ANDROID)}
      Result := pthread_condattr_setclock(@LAttr, PTHREAD_TIMEOUT_CLOCK_ID);
      {$ELSEIF defined(NEXTPAS_FREEBSD)}
      Result := pthread_condattr_setclock(@LAttr, PTHREAD_TIMEOUT_CLOCK_ID);
      {$ELSE}
      Result := pthread_condattr_setclock(@LAttr, PTHREAD_TIMEOUT_CLOCK_ID);
      {$ENDIF}
      if Result <> 0 then
        Exit;
    end;
    Result := pthread_cond_init(ACondVar, @LAttr);
    {$ENDIF}
  finally
    pthread_condattr_destroy(@LAttr);
  end;
end;

function platform_sync_host_pthread_condvar_timedwait_abs(ACondVar: Pointer; AMutex: Pointer; ADeadline: Pointer): Int32; inline;
begin
  Result := pthread_cond_timedwait(ACondVar, AMutex, PTimeSpec(ADeadline));
end;

procedure platform_sync_host_pthread_yield; inline;
begin
  sched_yield;
end;

function platform_sync_host_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_destroy(AMutex);
end;

function platform_sync_host_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_lock(AMutex);
end;

function platform_sync_host_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_trylock(AMutex);
end;

function platform_sync_host_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_unlock(AMutex);
end;

function platform_sync_host_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_init(ARwLock, nil);
end;

function platform_sync_host_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_destroy(ARwLock);
end;

function platform_sync_host_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_rdlock(ARwLock);
end;

function platform_sync_host_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_tryrdlock(ARwLock);
end;

function platform_sync_host_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_wrlock(ARwLock);
end;

function platform_sync_host_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_trywrlock(ARwLock);
end;

function platform_sync_host_pthread_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_unlock(ARwLock);
end;

function platform_sync_host_pthread_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_unlock(ARwLock);
end;

function platform_sync_host_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_destroy(ACondVar);
end;

function platform_sync_host_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  Result := pthread_cond_wait(ACondVar, AMutex);
end;

function platform_sync_host_pthread_timeout_deadline_after_ns(
  const ANanoseconds: UInt64;
  out ADeadline: timespec): Int32; inline;
begin
  if clock_gettime(PTHREAD_TIMEOUT_CLOCK_ID, @ADeadline) <> 0 then
    Exit(PLATFORM_ERR_INVALID);
  platform_posix_timespec_add_ns(ADeadline, ANanoseconds);
  Result := 0;
end;

function platform_sync_host_pthread_timeout_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  out ARemainingNs: UInt64): Int32; inline;
var
  LNow: timespec;
begin
  ARemainingNs := 0;
  if ADeadline = nil then
    Exit(PLATFORM_ERR_INVALID);
  if clock_gettime(PTHREAD_TIMEOUT_CLOCK_ID, @LNow) <> 0 then
    Exit(PLATFORM_ERR_INVALID);
  ARemainingNs := platform_posix_timespec_remaining_ns_u64(ADeadline, @LNow);
  Result := 0;
end;

function platform_sync_host_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_signal(ACondVar);
end;

function platform_sync_host_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_broadcast(ACondVar);
end;

function platform_posix_map_error(const ACode: Int32): Int32; inline;
begin
  Result := platform_sync_host_pthread_sync_result(
    ACode,
    PLATFORM_ERR_AGAIN,
    PLATFORM_ERR_BUSY,
    PLATFORM_ERR_INVALID,
    PLATFORM_ERR_UNSUPPORTED,
    PLATFORM_ERR_TIMEOUT);
end;

function platform_posix_bucket_index(AAddr: PInt32): PtrUInt; inline;
begin
  Result := (PtrUInt(AAddr) shr 2) and PtrUInt(POSIX_WAIT_BUCKET_COUNT - 1);
end;

function platform_posix_wait_address_released(
  const ABucketGeneration: UInt64;
  const AWaitGeneration: UInt64;
  AAddr: PInt32;
  const AExpected: Int32): Boolean; inline;
begin
  Result := (ABucketGeneration <> AWaitGeneration) or (AAddr^ <> AExpected);
end;

function platform_posix_mutex_init_impl(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
begin
  FillChar(AMutex, SizeOf(AMutex), 0);
  Result := platform_posix_map_error(
    platform_sync_host_pthread_mutex_init_platform_kind(@AMutex.FOpaque[0], AKind));
end;

function platform_posix_condvar_init_impl(var ACondVar: TPlatformCondVar): Int32;
begin
  FillChar(ACondVar, SizeOf(ACondVar), 0);
  Result := platform_posix_map_error(platform_sync_host_pthread_condvar_init(@ACondVar.FOpaque[0]));
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
    platform_sync_host_pthread_condvar_timedwait_abs(@ACondVar.FOpaque[0], @AMutex.FOpaque[0], @LDeadline));
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
    platform_sync_host_pthread_yield;
  Result := GPosixWaitBucketsInitResult;
end;

{ Mutex }

function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
begin
  Result := platform_posix_mutex_init_impl(AMutex, AKind);
end;

function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_mutex_destroy(@AMutex.FOpaque[0]));
end;

function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_mutex_lock(@AMutex.FOpaque[0]));
end;

function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_mutex_trylock(@AMutex.FOpaque[0]));
end;

function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_mutex_unlock(@AMutex.FOpaque[0]));
end;

{ RWLock }

function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32;
begin
  FillChar(ARwLock, SizeOf(ARwLock), 0);
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_init(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_destroy(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_rdlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_tryrdlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_wrlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_trywrlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_rdunlock(@ARwLock.FOpaque[0]));
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_rwlock_wrunlock(@ARwLock.FOpaque[0]));
end;

{ CondVar }

function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_condvar_init_impl(ACondVar);
end;

function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_condvar_destroy(@ACondVar.FOpaque[0]));
end;

function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_posix_map_error(
    platform_sync_host_pthread_condvar_wait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0]));
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

  Result := platform_posix_map_error(
    platform_sync_host_pthread_timeout_deadline_after_ns(UInt64(ATimeoutNs), LDeadline));
  if Result <> 0 then
    Exit;
  Result := platform_posix_condvar_timedwait_abs(ACondVar, AMutex, LDeadline);
end;

function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_condvar_signal(@ACondVar.FOpaque[0]));
end;

function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_posix_map_error(platform_sync_host_pthread_condvar_broadcast(@ACondVar.FOpaque[0]));
end;

function platform_posix_wait_address_fallback(
  AAddr: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64): Int32;
var
  LBucket: ^TPosixWaitBucket;
  LDeadline: timespec;
  LRemainingNs: UInt64;
  LGeneration: UInt64;
  LRet: Int32;
  LLocked: Boolean;
  LWaiting: Boolean;
  LDone: Boolean;
begin
  Result := platform_sync_validate_wait_address(AAddr, AExpected);
  if Result <> 0 then
    Exit;

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
        Result := platform_posix_map_error(
          platform_sync_host_pthread_timeout_deadline_after_ns(UInt64(ATimeoutNs), LDeadline));
        if Result <> 0 then
          LDone := True;
      end;

      while (Result = 0) and not LDone do
      begin
        if ATimeoutNs < 0 then
          LRet := platform_condvar_wait(LBucket^.CondVar, LBucket^.Mutex)
        else
        begin
          Result := platform_posix_map_error(
            platform_sync_host_pthread_timeout_remaining_ns_u64(@LDeadline, LRemainingNs));
          if Result <> 0 then
            Break;
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
          if platform_posix_wait_address_released(
            LBucket^.Generation, LGeneration, AAddr, AExpected) then
            LDone := True;
        end
        else if LRet = PLATFORM_ERR_TIMEOUT then
        begin
          if platform_posix_wait_address_released(
            LBucket^.Generation, LGeneration, AAddr, AExpected) then
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
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;

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
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;

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

function platform_linux_errno_value: Int32; inline;
begin
  Result := __errno_location^;
end;

function platform_linux_futex_wait_i32(
  AAddr: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64): Int32;
var
  LRet: PtrInt;
  LTimeout: timespec;
begin
  if ATimeoutNs < 0 then
    LRet := syscall(
      syscall_nr_futex,
      PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG),
      PtrUInt(UInt32(AExpected)),
      PtrUInt(0),
      PtrUInt(0),
      PtrUInt(0))
  else
  begin
    LTimeout.tv_sec := ATimeoutNs div 1000000000;
    LTimeout.tv_nsec := ATimeoutNs mod 1000000000;
    LRet := syscall(
      syscall_nr_futex,
      PtrUInt(AAddr),
      PtrUInt(FUTEX_WAIT or FUTEX_PRIVATE_FLAG),
      PtrUInt(UInt32(AExpected)),
      PtrUInt(@LTimeout),
      PtrUInt(0),
      PtrUInt(0));
  end;

  if LRet >= 0 then
    Result := 0
  else
    Result := platform_linux_errno_value;
end;

function platform_linux_futex_wake_i32(AAddr: PInt32; const ACount: Int32): Int32;
var
  LRet: PtrInt;
begin
  LRet := syscall(
    syscall_nr_futex,
    PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG),
    PtrUInt(ACount),
    PtrUInt(0),
    PtrUInt(0),
    PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_linux_errno_value;
end;

function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
begin
  Result := platform_sync_validate_wait_address(AAddr, AExpected);
  if Result <> 0 then
    Exit;

  Result := platform_linux_futex_wait_i32(AAddr, AExpected, ATimeoutNs);
  if Result = 0 then
    Result := 0
  else
    Result := platform_posix_map_error(Result);
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
begin
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;

  Result := platform_linux_futex_wake_i32(AAddr, 1);
  if Result = 0 then
    Result := 0
  else
    Result := platform_posix_map_error(Result);
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
begin
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;

  Result := platform_linux_futex_wake_i32(AAddr, High(Int32));
  if Result = 0 then
    Result := 0
  else
    Result := platform_posix_map_error(Result);
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

function platform_sync_windows_last_error_i32: Int32; inline;
begin
  Result := Int32(GetLastError);
end;

function platform_sync_windows_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD; inline;
var
  LMilliseconds: UInt64;
begin
  if ATimeoutNs < 0 then
    Exit(INFINITE);
  if ATimeoutNs = 0 then
    Exit(0);

  LMilliseconds := UInt64(ATimeoutNs) div 1000000;
  if (UInt64(ATimeoutNs) mod 1000000) <> 0 then
    Inc(LMilliseconds);

  if LMilliseconds >= UInt64(INFINITE) then
    Result := INFINITE - 1
  else
    Result := DWORD(LMilliseconds);
end;

function platform_sync_windows_timeout_result(const AError: Int32; const ATimeoutResult: Int32): Int32; inline;
begin
  if DWORD(AError) = ERROR_TIMEOUT then
    Result := ATimeoutResult
  else
    Result := AError;
end;

function platform_sync_windows_mutex_init(AMutex: Pointer): Int32; inline;
begin
  InitializeSRWLock(AMutex);
  Result := 0;
end;

function platform_sync_windows_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := 0;
end;

function platform_sync_windows_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  AcquireSRWLockExclusive(AMutex);
  Result := 0;
end;

function platform_sync_windows_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  if TryAcquireSRWLockExclusive(AMutex) then
    Result := 0
  else
    Result := PLATFORM_ERR_BUSY;
end;

function platform_sync_windows_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  ReleaseSRWLockExclusive(AMutex);
  Result := 0;
end;

function platform_sync_windows_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  InitializeSRWLock(ARwLock);
  Result := 0;
end;

function platform_sync_windows_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := 0;
end;

function platform_sync_windows_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  AcquireSRWLockShared(ARwLock);
  Result := 0;
end;

function platform_sync_windows_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  if TryAcquireSRWLockShared(ARwLock) then
    Result := 0
  else
    Result := PLATFORM_ERR_BUSY;
end;

function platform_sync_windows_rwlock_rdunlock(ARwLock: Pointer): Int32; inline;
begin
  ReleaseSRWLockShared(ARwLock);
  Result := 0;
end;

function platform_sync_windows_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  AcquireSRWLockExclusive(ARwLock);
  Result := 0;
end;

function platform_sync_windows_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  if TryAcquireSRWLockExclusive(ARwLock) then
    Result := 0
  else
    Result := PLATFORM_ERR_BUSY;
end;

function platform_sync_windows_rwlock_wrunlock(ARwLock: Pointer): Int32; inline;
begin
  ReleaseSRWLockExclusive(ARwLock);
  Result := 0;
end;

function platform_sync_windows_condvar_init(ACondVar: Pointer): Int32; inline;
begin
  InitializeConditionVariable(ACondVar);
  Result := 0;
end;

function platform_sync_windows_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := 0;
end;

function platform_sync_windows_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  if SleepConditionVariableSRW(ACondVar, AMutex, INFINITE, 0) then
    Result := 0
  else
    Result := platform_sync_windows_last_error_i32;
end;

function platform_sync_windows_condvar_timedwait(
  ACondVar: Pointer;
  AMutex: Pointer;
  const ATimeoutNs: Int64): Int32; inline;
begin
  if SleepConditionVariableSRW(
    ACondVar,
    AMutex,
    platform_sync_windows_timeout_ns_to_ms(ATimeoutNs),
    0) then
    Result := 0
  else
    Result := platform_sync_windows_timeout_result(
      platform_sync_windows_last_error_i32,
      PLATFORM_ERR_TIMEOUT);
end;

function platform_sync_windows_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  WakeConditionVariable(ACondVar);
  Result := 0;
end;

function platform_sync_windows_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  WakeAllConditionVariable(ACondVar);
  Result := 0;
end;

function platform_sync_windows_wait_address_i32(
  AAddr: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64): Int32; inline;
var
  LExpected: Int32;
begin
  LExpected := AExpected;
  if WaitOnAddress(
    AAddr,
    @LExpected,
    SizeOf(LExpected),
    platform_sync_windows_timeout_ns_to_ms(ATimeoutNs)) then
    Result := 0
  else
    Result := platform_sync_windows_timeout_result(
      platform_sync_windows_last_error_i32,
      PLATFORM_ERR_TIMEOUT);
end;

function platform_sync_windows_wake_address_one(AAddr: PInt32): Int32; inline;
begin
  WakeByAddressSingle(AAddr);
  Result := 0;
end;

function platform_sync_windows_wake_address_all(AAddr: PInt32): Int32; inline;
begin
  WakeByAddressAll(AAddr);
  Result := 0;
end;

{ Mutex - SRWLOCK based (exclusive only for mutex semantics) }

function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
begin
  FillChar(AMutex, SizeOf(AMutex), 0);
  Result := platform_sync_windows_mutex_init(@AMutex.FOpaque[0]);
end;

function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_sync_windows_mutex_destroy(@AMutex.FOpaque[0]);
end;

function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_sync_windows_mutex_lock(@AMutex.FOpaque[0]);
end;

function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_sync_windows_mutex_trylock(@AMutex.FOpaque[0]);
end;

function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_sync_windows_mutex_unlock(@AMutex.FOpaque[0]);
end;

{ RWLock - SRWLOCK }

function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32;
begin
  FillChar(ARwLock, SizeOf(ARwLock), 0);
  Result := platform_sync_windows_rwlock_init(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_destroy(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_rdlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_tryrdlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_wrlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_trywrlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_rdunlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := platform_sync_windows_rwlock_wrunlock(@ARwLock.FOpaque[0]);
end;

{ CondVar - CONDITION_VARIABLE }

function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32;
begin
  FillChar(ACondVar, SizeOf(ACondVar), 0);
  Result := platform_sync_windows_condvar_init(@ACondVar.FOpaque[0]);
end;

function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_sync_windows_condvar_destroy(@ACondVar.FOpaque[0]);
end;

function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32;
begin
  Result := platform_sync_windows_condvar_wait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0]);
end;

function platform_condvar_timedwait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex; const ATimeoutNs: Int64): Int32;
begin
  Result := platform_sync_windows_condvar_timedwait(
    @ACondVar.FOpaque[0], @AMutex.FOpaque[0], ATimeoutNs);
end;

function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_sync_windows_condvar_signal(@ACondVar.FOpaque[0]);
end;

function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := platform_sync_windows_condvar_broadcast(@ACondVar.FOpaque[0]);
end;

{ Address-wait (Windows address-wait primitive) }

function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
begin
  Result := platform_sync_validate_wait_address(AAddr, AExpected);
  if Result <> 0 then
    Exit;

  Result := platform_sync_windows_wait_address_i32(AAddr, AExpected, ATimeoutNs);
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
begin
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;

  Result := platform_sync_windows_wake_address_one(AAddr);
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
begin
  Result := platform_sync_validate_address(AAddr);
  if Result <> 0 then
    Exit;

  Result := platform_sync_windows_wake_address_all(AAddr);
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
