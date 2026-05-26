unit nextpas.core.platform.sync;

{$I nextpas.core.settings.inc}

interface

const
  {$IFDEF UNIX}
  PLATFORM_MUTEX_SIZE   = 48;
  PLATFORM_RWLOCK_SIZE  = 56;
  PLATFORM_CONDVAR_SIZE = 48;
  {$ENDIF}
  {$IFDEF WINDOWS}
  PLATFORM_MUTEX_SIZE   = 40;
  PLATFORM_RWLOCK_SIZE  = 8;
  PLATFORM_CONDVAR_SIZE = 8;
  {$ENDIF}
  {$IFNDEF UNIX}{$IFNDEF WINDOWS}
  PLATFORM_MUTEX_SIZE   = 64;
  PLATFORM_RWLOCK_SIZE  = 64;
  PLATFORM_CONDVAR_SIZE = 64;
  {$ENDIF}{$ENDIF}

type
  TPlatformMutex = record
    FOpaque: array[0..PLATFORM_MUTEX_SIZE - 1] of Byte;
  end;

  TPlatformRwLock = record
    FOpaque: array[0..PLATFORM_RWLOCK_SIZE - 1] of Byte;
  end;

  TPlatformCondVar = record
    FOpaque: array[0..PLATFORM_CONDVAR_SIZE - 1] of Byte;
  end;

const
  PLATFORM_MUTEX_NORMAL     = 0;
  PLATFORM_MUTEX_ERRORCHECK = 1;
  PLATFORM_MUTEX_RECURSIVE  = 2;

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

{$IFDEF UNIX}
uses
  Linux, PThreads, UnixType, BaseUnix, Syscall;

function pthread_condattr_setclock(AAttr: Ppthread_condattr_t; AClockId: cint): cint; cdecl; external 'pthread';
{$ENDIF}

{$IFDEF WINDOWS}
uses
  Windows;
{$ENDIF}

{$IFDEF UNIX}

{ Mutex }

function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32;
var
  LAttr: pthread_mutexattr_t;
  LKind: Integer;
begin
  FillChar(AMutex, SizeOf(AMutex), 0);
  Result := pthread_mutexattr_init(@LAttr);
  if Result <> 0 then Exit;
  try
    case AKind of
      PLATFORM_MUTEX_NORMAL: LKind := 0;
      PLATFORM_MUTEX_RECURSIVE: LKind := 1;
    else
      LKind := 2;
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
  LTs: TimeSpec;
  LNow: TimeSpec;
begin
  clock_gettime(CLOCK_MONOTONIC, @LNow);
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

const
  FUTEX_WAIT         = 0;
  FUTEX_WAKE         = 1;
  FUTEX_PRIVATE_FLAG = 128;

function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32;
var
  LTs: TimeSpec;
  LRet: cint;
begin
  if ATimeoutNs < 0 then
  begin
    LRet := do_syscall(syscall_nr_futex, TSysParam(AAddr),
      FUTEX_WAIT or FUTEX_PRIVATE_FLAG, TSysParam(AExpected),
      TSysParam(nil), TSysParam(nil), TSysParam(0));
  end
  else
  begin
    LTs.tv_sec := ATimeoutNs div 1000000000;
    LTs.tv_nsec := ATimeoutNs mod 1000000000;
    LRet := do_syscall(syscall_nr_futex, TSysParam(AAddr),
      FUTEX_WAIT or FUTEX_PRIVATE_FLAG, TSysParam(AExpected),
      TSysParam(@LTs), TSysParam(nil), TSysParam(0));
  end;
  if LRet >= 0 then
    Result := 0
  else
    Result := -LRet;
end;

function platform_wake_address_one(AAddr: PInt32): Int32;
var
  LRet: cint;
begin
  LRet := do_syscall(syscall_nr_futex, TSysParam(AAddr),
    FUTEX_WAKE or FUTEX_PRIVATE_FLAG, TSysParam(1),
    TSysParam(nil), TSysParam(nil), TSysParam(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := -LRet;
end;

function platform_wake_address_all(AAddr: PInt32): Int32;
var
  LRet: cint;
begin
  LRet := do_syscall(syscall_nr_futex, TSysParam(AAddr),
    FUTEX_WAKE or FUTEX_PRIVATE_FLAG, TSysParam(High(Int32)),
    TSysParam(nil), TSysParam(nil), TSysParam(0));
  if LRet >= 0 then
    Result := 0
  else
    Result := -LRet;
end;

{$ENDIF}

{$IFDEF WINDOWS}

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
    Result := 16; // EBUSY
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
    Result := 16;
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
    Result := 16;
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
  if ATimeoutNs < 0 then
    LMs := INFINITE
  else
    LMs := DWORD(ATimeoutNs div 1000000);
  if SleepConditionVariableSRW(@ACondVar.FOpaque[0], @AMutex.FOpaque[0], LMs, 0) then
    Result := 0
  else if GetLastError = ERROR_TIMEOUT then
    Result := 110 // ETIMEDOUT
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
  if ATimeoutNs < 0 then
    LMs := INFINITE
  else
    LMs := DWORD(ATimeoutNs div 1000000);
  if WaitOnAddress(AAddr, @LExpected, SizeOf(Int32), LMs) then
    Result := 0
  else if GetLastError = ERROR_TIMEOUT then
    Result := 110
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

{$IFNDEF UNIX}{$IFNDEF WINDOWS}
function platform_mutex_init(var AMutex: TPlatformMutex; const AKind: Int32): Int32; begin Result := -1; end;
function platform_mutex_destroy(var AMutex: TPlatformMutex): Int32; begin Result := -1; end;
function platform_mutex_lock(var AMutex: TPlatformMutex): Int32; begin Result := -1; end;
function platform_mutex_trylock(var AMutex: TPlatformMutex): Int32; begin Result := -1; end;
function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32; begin Result := -1; end;
function platform_rwlock_init(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_destroy(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_rdlock(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_tryrdlock(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_wrlock(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_trywrlock(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_rdunlock(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_rwlock_wrunlock(var ARwLock: TPlatformRwLock): Int32; begin Result := -1; end;
function platform_condvar_init(var ACondVar: TPlatformCondVar): Int32; begin Result := -1; end;
function platform_condvar_destroy(var ACondVar: TPlatformCondVar): Int32; begin Result := -1; end;
function platform_condvar_wait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex): Int32; begin Result := -1; end;
function platform_condvar_timedwait(var ACondVar: TPlatformCondVar; var AMutex: TPlatformMutex; const ATimeoutNs: Int64): Int32; begin Result := -1; end;
function platform_condvar_signal(var ACondVar: TPlatformCondVar): Int32; begin Result := -1; end;
function platform_condvar_broadcast(var ACondVar: TPlatformCondVar): Int32; begin Result := -1; end;
function platform_wait_address32(AAddr: PInt32; const AExpected: Int32; const ATimeoutNs: Int64): Int32; begin Result := -1; end;
function platform_wake_address_one(AAddr: PInt32): Int32; begin Result := -1; end;
function platform_wake_address_all(AAddr: PInt32): Int32; begin Result := -1; end;
{$ENDIF}{$ENDIF}

end.
