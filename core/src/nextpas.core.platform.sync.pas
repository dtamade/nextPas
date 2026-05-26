unit nextpas.core.platform.sync;

{$I nextpas.core.settings.inc}

interface

const
  {$IFDEF NEXTPAS_LINUX}
  PLATFORM_MUTEX_SIZE   = 48;
  PLATFORM_RWLOCK_SIZE  = 56;
  PLATFORM_CONDVAR_SIZE = 48;
  {$ELSEIF defined(NEXTPAS_WINDOWS)}
  PLATFORM_MUTEX_SIZE   = 40;
  PLATFORM_RWLOCK_SIZE  = 8;
  PLATFORM_CONDVAR_SIZE = 8;
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

{$IFDEF NEXTPAS_LINUX}
uses
  nextpas.core.platform.posix.ffi,
  nextpas.core.platform.linux.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_WINDOWS}
uses
  nextpas.core.platform.windows.ffi;
{$ENDIF}

{$IFDEF NEXTPAS_LINUX}

function platform_linux_errno: Int32; inline;
begin
  Result := linux_errno_location^;
end;

{ Mutex }

function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
var
  LAttr: pthread_mutexattr_t;
  LKind: Int32;
begin
  FillChar(AMutex, SizeOf(AMutex), 0);
  Result := pthread_mutexattr_init(@LAttr);
  if Result <> 0 then Exit;
  try
    case AKind of
      PLATFORM_MUTEX_NORMAL: LKind := PTHREAD_MUTEX_NORMAL;
      PLATFORM_MUTEX_RECURSIVE: LKind := PTHREAD_MUTEX_RECURSIVE;
    else
      LKind := PTHREAD_MUTEX_ERRORCHECK;
    end;
    Result := pthread_mutexattr_settype(@LAttr, LKind);
    if Result <> 0 then Exit;
    Result := pthread_mutex_init(@AMutex.FOpaque[0], @LAttr);
  finally
    pthread_mutexattr_destroy(@LAttr);
  end;
end;

function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32;
begin
  Result := pthread_mutex_destroy(@AMutex.FOpaque[0]);
end;

function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
begin
  Result := pthread_mutex_lock(@AMutex.FOpaque[0]);
end;

function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32;
begin
  Result := pthread_mutex_trylock(@AMutex.FOpaque[0]);
end;

function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;
begin
  Result := pthread_mutex_unlock(@AMutex.FOpaque[0]);
end;

{ RWLock }

function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32;
begin
  FillChar(ARwLock, SizeOf(ARwLock), 0);
  Result := pthread_rwlock_init(@ARwLock.FOpaque[0], nil);
end;

function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_destroy(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_rdlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_tryrdlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_wrlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_trywrlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_unlock(@ARwLock.FOpaque[0]);
end;

function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32;
begin
  Result := pthread_rwlock_unlock(@ARwLock.FOpaque[0]);
end;

{ CondVar }

function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32;
var
  LAttr: pthread_condattr_t;
begin
  FillChar(ACondVar, SizeOf(ACondVar), 0);
  Result := pthread_condattr_init(@LAttr);
  if Result <> 0 then Exit;
  try
    Result := pthread_condattr_setclock(@LAttr, CLOCK_MONOTONIC);
    if Result <> 0 then Exit;
    Result := pthread_cond_init(@ACondVar.FOpaque[0], @LAttr);
  finally
    pthread_condattr_destroy(@LAttr);
  end;
end;

function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := pthread_cond_destroy(@ACondVar.FOpaque[0]);
end;

function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32;
begin
  Result := pthread_cond_wait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0]);
end;

function platform_condvar_timedwait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex; const ATimeoutNs: Int64): Int32;
var
  LTs: timespec;
  LNow: timespec;
begin
  if ATimeoutNs < 0 then
  begin
    Result := pthread_cond_wait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0]);
    Exit;
  end;

  Result := clock_gettime(CLOCK_MONOTONIC, @LNow);
  if Result <> 0 then
  begin
    Result := platform_linux_errno;
    Exit;
  end;
  LTs.tv_sec := LNow.tv_sec + (ATimeoutNs div 1000000000);
  LTs.tv_nsec := LNow.tv_nsec + (ATimeoutNs mod 1000000000);
  if LTs.tv_nsec >= 1000000000 then
  begin
    Inc(LTs.tv_sec);
    Dec(LTs.tv_nsec, 1000000000);
  end;
  Result := pthread_cond_timedwait(@ACondVar.FOpaque[0], @AMutex.FOpaque[0], @LTs);
end;

function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := pthread_cond_signal(@ACondVar.FOpaque[0]);
end;

function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32;
begin
  Result := pthread_cond_broadcast(@ACondVar.FOpaque[0]);
end;

{ Address-wait (futex on Linux) }

function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
var
  LTs: timespec;
  LRet: PtrInt;
begin
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
    Result := platform_linux_errno;
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(1),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_linux_errno;
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
var
  LRet: PtrInt;
begin
  LRet := linux_syscall(LINUX_SYSCALL_FUTEX, PtrUInt(AAddr),
    PtrUInt(FUTEX_WAKE or FUTEX_PRIVATE_FLAG), PtrUInt(High(Int32)),
    PtrUInt(0), PtrUInt(0), PtrUInt(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := platform_linux_errno;
end;

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

{$IFNDEF NEXTPAS_LINUX}{$IFNDEF NEXTPAS_WINDOWS}
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
