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
  TPThreadCondAttrSetClockProc = function(attr: Pointer; clk_id: Int32): Int32; cdecl;

  {$IFDEF NEXTPAS_FREEBSD}
  pthread_mutex_t = Pointer;
  pthread_mutexattr_t = Pointer;
  pthread_rwlock_t = Pointer;
  pthread_rwlockattr_t = Pointer;
  pthread_cond_t = Pointer;
  pthread_condattr_t = Pointer;
  {$ELSEIF defined(NEXTPAS_MACOS)}
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
  {$ELSEIF defined(NEXTPAS_ANDROID)}
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
  {$ELSEIF defined(NEXTPAS_LINUX)}
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

function platform_posix_timespec_to_ns_u64(const ATime: PTimeSpec): UInt64; inline;
procedure platform_posix_timespec_add_ns(var ATime: timespec; const ANanoseconds: UInt64); inline;
function platform_posix_timespec_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  const ANow: PTimeSpec): UInt64; inline;
function platform_posix_thread_self_token_u64: UInt64; inline;
function platform_posix_sysconf_positive_i32(const AName: Int32): Int32; inline;
function platform_posix_pthread_create_handle(
  AThreadStorage: Pointer;
  const AStartRoutine: Pointer;
  const AArgument: Pointer): Int32; inline;
function platform_posix_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
function platform_posix_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
procedure platform_posix_pthread_yield; inline;
procedure platform_posix_pthread_sleep_ns(
  const ANanoseconds: UInt64;
  const AErrnoLocation: PInt32;
  const AEintr: Int32); inline;
function platform_posix_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
function platform_posix_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
function platform_posix_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
function platform_posix_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
function platform_posix_clock_now(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
function platform_posix_clock_getres(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
function platform_posix_clock_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
function platform_posix_clock_resolution_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
function platform_posix_errno_value_from_location(const AErrnoLocation: PInt32): Int32; inline;
function platform_posix_pthread_mutex_init_kind(
  AMutex: Pointer;
  const AKind: Int32): Int32; inline;
function platform_posix_pthread_mutex_init_public_kind(
  AMutex: Pointer;
  const APublicKind: Int32;
  const ANormalKind: Int32;
  const ARecursiveKind: Int32;
  const AErrorCheckKind: Int32): Int32; inline;
function platform_posix_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_rwlock_unlock(ARwLock: Pointer): Int32; inline;
function platform_posix_pthread_condvar_init_with_clock(
  ACondVar: Pointer;
  const AClockId: Int32;
  const ASetClockSupported: Int32;
  const ASetClockProc: TPThreadCondAttrSetClockProc): Int32; inline;
function platform_posix_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
function platform_posix_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
function platform_posix_pthread_condvar_timedwait_abs(
  ACondVar: Pointer;
  AMutex: Pointer;
  ADeadline: Pointer): Int32; inline;
function platform_posix_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
function platform_posix_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;

function clock_gettime(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_gettime';
function clock_getres(const clk_id: Int32; tp: Pointer): Int32; cdecl; external 'c' name 'clock_getres';
function nanosleep(req: Pointer; rem: Pointer): Int32; cdecl; external 'c' name 'nanosleep';
function sched_yield: Int32; cdecl; external 'c' name 'sched_yield';
function sysconf(name: Int32): PtrInt; cdecl; external 'c' name 'sysconf';

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
function pthread_condattr_destroy(attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_condattr_destroy';
function pthread_cond_init(cond: Pointer; attr: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_init';
function pthread_cond_destroy(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_destroy';
function pthread_cond_wait(cond: Pointer; mutex: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_wait';
function pthread_cond_timedwait(cond: Pointer; mutex: Pointer; abstime: PTimeSpec): Int32; cdecl; external 'pthread' name 'pthread_cond_timedwait';
function pthread_cond_signal(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_signal';
function pthread_cond_broadcast(cond: Pointer): Int32; cdecl; external 'pthread' name 'pthread_cond_broadcast';

implementation

const
  PLATFORM_POSIX_NANOSECONDS_PER_SECOND = UInt64(1000000000);

type
  PPThreadToken = ^pthread_t;

function platform_posix_timespec_to_ns_u64(const ATime: PTimeSpec): UInt64; inline;
var
  LSecNs: UInt64;
  LNsec: UInt64;
begin
  if ATime = nil then
    Exit(0);
  if (ATime^.tv_sec < 0) or (ATime^.tv_nsec < 0) then
    Exit(0);
  if UInt64(ATime^.tv_sec) > High(UInt64) div PLATFORM_POSIX_NANOSECONDS_PER_SECOND then
    Exit(High(UInt64));

  LSecNs := UInt64(ATime^.tv_sec) * PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
  LNsec := UInt64(ATime^.tv_nsec);
  if LSecNs > High(UInt64) - LNsec then
    Exit(High(UInt64));

  Result := LSecNs + LNsec;
end;

procedure platform_posix_timespec_add_ns(var ATime: timespec; const ANanoseconds: UInt64); inline;
var
  LSeconds: UInt64;
  LNanos: UInt64;
begin
  LSeconds := ANanoseconds div PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
  LNanos := ANanoseconds mod PLATFORM_POSIX_NANOSECONDS_PER_SECOND;
  ATime.tv_sec := ATime.tv_sec + Int64(LSeconds);
  ATime.tv_nsec := ATime.tv_nsec + Int64(LNanos);
  if ATime.tv_nsec >= Int64(PLATFORM_POSIX_NANOSECONDS_PER_SECOND) then
  begin
    Inc(ATime.tv_sec);
    Dec(ATime.tv_nsec, Int64(PLATFORM_POSIX_NANOSECONDS_PER_SECOND));
  end;
end;

function platform_posix_timespec_remaining_ns_u64(
  const ADeadline: PTimeSpec;
  const ANow: PTimeSpec): UInt64; inline;
var
  LDeadlineNs: UInt64;
  LNowNs: UInt64;
begin
  LDeadlineNs := platform_posix_timespec_to_ns_u64(ADeadline);
  LNowNs := platform_posix_timespec_to_ns_u64(ANow);
  if LDeadlineNs <= LNowNs then
    Exit(0);
  Result := LDeadlineNs - LNowNs;
end;

function platform_posix_thread_self_token_u64: UInt64; inline;
begin
  Result := UInt64(PtrUInt(pthread_self));
end;

function platform_posix_sysconf_positive_i32(const AName: Int32): Int32; inline;
var
  LResult: PtrInt;
begin
  LResult := sysconf(AName);
  if LResult < 1 then
    Result := 1
  else
    Result := Int32(LResult);
end;

function platform_posix_pthread_create_handle(
  AThreadStorage: Pointer;
  const AStartRoutine: Pointer;
  const AArgument: Pointer): Int32; inline;
begin
  Result := pthread_create(AThreadStorage, nil, TPThreadStartRoutine(AStartRoutine), AArgument);
end;

function platform_posix_pthread_join_handle(AThreadStorage: Pointer; ARetVal: Pointer): Int32; inline;
begin
  Result := pthread_join(PPThreadToken(AThreadStorage)^, ARetVal);
end;

function platform_posix_pthread_detach_handle(AThreadStorage: Pointer): Int32; inline;
begin
  Result := pthread_detach(PPThreadToken(AThreadStorage)^);
end;

procedure platform_posix_pthread_yield; inline;
begin
  sched_yield;
end;

procedure platform_posix_pthread_sleep_ns(
  const ANanoseconds: UInt64;
  const AErrnoLocation: PInt32;
  const AEintr: Int32); inline;
var
  LReq: timespec;
  LRem: timespec;
begin
  if ANanoseconds = 0 then
    Exit;

  LReq.tv_sec := Int64(ANanoseconds div PLATFORM_POSIX_NANOSECONDS_PER_SECOND);
  LReq.tv_nsec := Int64(ANanoseconds mod PLATFORM_POSIX_NANOSECONDS_PER_SECOND);
  LRem.tv_sec := 0;
  LRem.tv_nsec := 0;

  while nanosleep(@LReq, @LRem) <> 0 do
  begin
    if (AErrnoLocation = nil) or (AErrnoLocation^ <> AEintr) then
      Break;
    LReq := LRem;
  end;
end;

function platform_posix_pthread_tls_create(out AKey: PtrUInt): Int32; inline;
var
  LKey: pthread_key_t;
begin
  Result := pthread_key_create(@LKey, nil);
  if Result = 0 then
    AKey := PtrUInt(LKey)
  else
    AKey := 0;
end;

function platform_posix_pthread_tls_destroy(const AKey: PtrUInt): Int32; inline;
begin
  Result := pthread_key_delete(pthread_key_t(AKey));
end;

function platform_posix_pthread_tls_set(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := pthread_setspecific(pthread_key_t(AKey), AValue);
end;

function platform_posix_pthread_tls_get(const AKey: PtrUInt): Pointer; inline;
begin
  Result := pthread_getspecific(pthread_key_t(AKey));
end;

function platform_posix_clock_now(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
begin
  if clock_gettime(AClockId, ATime) = 0 then
    Exit(0);
  if AErrnoLocation = nil then
    Exit(-1);
  Result := AErrnoLocation^;
end;

function platform_posix_clock_getres(
  const AClockId: Int32;
  ATime: Pointer;
  const AErrnoLocation: PInt32): Int32; inline;
begin
  if clock_getres(AClockId, ATime) = 0 then
    Exit(0);
  if AErrnoLocation = nil then
    Exit(-1);
  Result := AErrnoLocation^;
end;

function platform_posix_clock_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
var
  LTime: timespec;
begin
  if platform_posix_clock_now(AClockId, @LTime, AErrnoLocation) <> 0 then
    Exit(0);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
end;

function platform_posix_clock_resolution_ns_u64(
  const AClockId: Int32;
  const AErrnoLocation: PInt32): UInt64; inline;
var
  LTime: timespec;
begin
  if platform_posix_clock_getres(AClockId, @LTime, AErrnoLocation) <> 0 then
    Exit(1);
  Result := platform_posix_timespec_to_ns_u64(@LTime);
  if Result = 0 then
    Result := 1;
end;

function platform_posix_errno_value_from_location(const AErrnoLocation: PInt32): Int32; inline;
begin
  if AErrnoLocation = nil then
    Exit(0);
  Result := AErrnoLocation^;
end;

function platform_posix_pthread_mutex_init_kind(
  AMutex: Pointer;
  const AKind: Int32): Int32; inline;
var
  LAttr: pthread_mutexattr_t;
begin
  Result := pthread_mutexattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    Result := pthread_mutexattr_settype(@LAttr, AKind);
    if Result <> 0 then
      Exit;
    Result := pthread_mutex_init(AMutex, @LAttr);
  finally
    pthread_mutexattr_destroy(@LAttr);
  end;
end;

function platform_posix_pthread_mutex_init_public_kind(
  AMutex: Pointer;
  const APublicKind: Int32;
  const ANormalKind: Int32;
  const ARecursiveKind: Int32;
  const AErrorCheckKind: Int32): Int32; inline;
var
  LHostKind: Int32;
begin
  case APublicKind of
    0: LHostKind := ANormalKind;
    2: LHostKind := ARecursiveKind;
  else
    LHostKind := AErrorCheckKind;
  end;
  Result := platform_posix_pthread_mutex_init_kind(AMutex, LHostKind);
end;

function platform_posix_pthread_mutex_destroy(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_destroy(AMutex);
end;

function platform_posix_pthread_mutex_lock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_lock(AMutex);
end;

function platform_posix_pthread_mutex_trylock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_trylock(AMutex);
end;

function platform_posix_pthread_mutex_unlock(AMutex: Pointer): Int32; inline;
begin
  Result := pthread_mutex_unlock(AMutex);
end;

function platform_posix_pthread_rwlock_init(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_init(ARwLock, nil);
end;

function platform_posix_pthread_rwlock_destroy(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_destroy(ARwLock);
end;

function platform_posix_pthread_rwlock_rdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_rdlock(ARwLock);
end;

function platform_posix_pthread_rwlock_tryrdlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_tryrdlock(ARwLock);
end;

function platform_posix_pthread_rwlock_wrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_wrlock(ARwLock);
end;

function platform_posix_pthread_rwlock_trywrlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_trywrlock(ARwLock);
end;

function platform_posix_pthread_rwlock_unlock(ARwLock: Pointer): Int32; inline;
begin
  Result := pthread_rwlock_unlock(ARwLock);
end;

function platform_posix_pthread_condvar_init_with_clock(
  ACondVar: Pointer;
  const AClockId: Int32;
  const ASetClockSupported: Int32;
  const ASetClockProc: TPThreadCondAttrSetClockProc): Int32; inline;
var
  LAttr: pthread_condattr_t;
begin
  Result := pthread_condattr_init(@LAttr);
  if Result <> 0 then
    Exit;
  try
    if ASetClockSupported <> 0 then
    begin
      if not Assigned(ASetClockProc) then
        Exit(-1);
      Result := ASetClockProc(@LAttr, AClockId);
      if Result <> 0 then
        Exit;
    end;
    Result := pthread_cond_init(ACondVar, @LAttr);
  finally
    pthread_condattr_destroy(@LAttr);
  end;
end;

function platform_posix_pthread_condvar_destroy(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_destroy(ACondVar);
end;

function platform_posix_pthread_condvar_wait(ACondVar: Pointer; AMutex: Pointer): Int32; inline;
begin
  Result := pthread_cond_wait(ACondVar, AMutex);
end;

function platform_posix_pthread_condvar_timedwait_abs(
  ACondVar: Pointer;
  AMutex: Pointer;
  ADeadline: Pointer): Int32; inline;
begin
  Result := pthread_cond_timedwait(ACondVar, AMutex, PTimeSpec(ADeadline));
end;

function platform_posix_pthread_condvar_signal(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_signal(ACondVar);
end;

function platform_posix_pthread_condvar_broadcast(ACondVar: Pointer): Int32; inline;
begin
  Result := pthread_cond_broadcast(ACondVar);
end;

end.
