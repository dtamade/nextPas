unit nextpas.core.platform.windows.ffi;

{$I nextpas.core.settings.inc}

interface

type
  DWORD = UInt32;
  BOOL = LongBool;
  HANDLE = Pointer;
  SRWLOCK = Pointer;
  CONDITION_VARIABLE = Pointer;

  FILETIME = record
    dwLowDateTime: DWORD;
    dwHighDateTime: DWORD;
  end;

  SYSTEM_INFO = record
    dwOemId: DWORD;
    dwPageSize: DWORD;
    lpMinimumApplicationAddress: Pointer;
    lpMaximumApplicationAddress: Pointer;
    dwActiveProcessorMask: PtrUInt;
    dwNumberOfProcessors: DWORD;
    dwProcessorType: DWORD;
    dwAllocationGranularity: DWORD;
    wProcessorLevel: UInt16;
    wProcessorRevision: UInt16;
  end;

  TWinThreadStartRoutine = function(lpThreadParameter: Pointer): DWORD; stdcall;
  TPlatformWindowsMutexAlign = record
    Value: SRWLOCK;
  end;

  TPlatformWindowsRwLockAlign = record
    Value: SRWLOCK;
  end;

  TPlatformWindowsCondVarAlign = record
    Value: CONDITION_VARIABLE;
  end;

const
  INFINITE = DWORD($FFFFFFFF);
  WAIT_OBJECT_0 = DWORD(0);
  ERROR_TIMEOUT = DWORD(1460);
  TLS_OUT_OF_INDEXES = DWORD($FFFFFFFF);
  WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS = UInt64(116444736000000000);
  WINDOWS_FILETIME_NANOSECONDS_PER_TICK = UInt64(100);
  PLATFORM_WINDOWS_MUTEX_SIZE = SizeOf(SRWLOCK);
  PLATFORM_WINDOWS_RWLOCK_SIZE = SizeOf(SRWLOCK);
  PLATFORM_WINDOWS_CONDVAR_SIZE = SizeOf(CONDITION_VARIABLE);

function windows_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD; inline;
function windows_sleep_ns_to_ms(const ANanoseconds: UInt64): DWORD; inline;
function windows_last_error_i32: Int32; inline;
function windows_last_error_is_timeout(const AError: DWORD): Boolean; inline;
function windows_wait_for_single_object_is_signaled(const AWaitResult: DWORD): Boolean; inline;
function windows_mutex_init(const AMutex: Pointer): Int32; inline;
function windows_mutex_lock(const AMutex: Pointer): Int32; inline;
function windows_mutex_trylock(const AMutex: Pointer): Boolean; inline;
function windows_mutex_unlock(const AMutex: Pointer): Int32; inline;
function windows_rwlock_init(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_rdlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_tryrdlock(const ARwLock: Pointer): Boolean; inline;
function windows_rwlock_wrlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_trywrlock(const ARwLock: Pointer): Boolean; inline;
function windows_rwlock_rdunlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_wrunlock(const ARwLock: Pointer): Int32; inline;
function windows_condvar_init(const ACondVar: Pointer): Int32; inline;
function windows_condvar_wait(const ACondVar: Pointer; const AMutex: Pointer): Int32; inline;
function windows_condvar_timedwait_ms(
  const ACondVar: Pointer;
  const AMutex: Pointer;
  const ATimeoutMs: DWORD): Int32; inline;
function windows_condvar_signal(const ACondVar: Pointer): Int32; inline;
function windows_condvar_broadcast(const ACondVar: Pointer): Int32; inline;
function windows_wait_address_i32(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutMs: DWORD): Int32; inline;
function windows_wake_address_single(const AAddress: PInt32): Int32; inline;
function windows_wake_address_all(const AAddress: PInt32): Int32; inline;
function windows_current_thread_id_u64: UInt64; inline;
function windows_thread_create_handle(
  const AStartAddress: TWinThreadStartRoutine;
  const AParameter: Pointer;
  out AHandle: HANDLE): Int32; inline;
function windows_thread_wait_terminated(const AHandle: HANDLE): Int32; inline;
function windows_thread_close_handle(const AHandle: HANDLE): Int32; inline;
procedure windows_thread_sleep_ns(const ANanoseconds: UInt64); inline;
function windows_atomic_decrement_i32(var AValue: Int32): Int32; inline;
procedure windows_thread_yield; inline;
function windows_tls_alloc_key(out AIndex: DWORD): Int32; inline;
function windows_tls_free_key(const AIndex: DWORD): Int32; inline;
function windows_tls_set_value(const AIndex: DWORD; const AValue: Pointer): Int32; inline;
function windows_tls_get_value(const AIndex: DWORD): Pointer; inline;
function windows_cpu_count_i32: Int32; inline;
function windows_qpc_frequency_u64: UInt64;
function windows_qpc_counter_u64(out ACounter: UInt64): Boolean;
function windows_filetime_now_unix_ns: UInt64;

function CreateThread(lpThreadAttributes: Pointer; dwStackSize: PtrUInt; lpStartAddress: TWinThreadStartRoutine; lpParameter: Pointer; dwCreationFlags: DWORD; lpThreadId: Pointer): HANDLE; stdcall; external 'kernel32' name 'CreateThread';
function WaitForSingleObject(hHandle: HANDLE; dwMilliseconds: DWORD): DWORD; stdcall; external 'kernel32' name 'WaitForSingleObject';
function CloseHandle(hObject: HANDLE): BOOL; stdcall; external 'kernel32' name 'CloseHandle';
function GetCurrentThreadId: DWORD; stdcall; external 'kernel32' name 'GetCurrentThreadId';
function QueryPerformanceFrequency(var lpFrequency: Int64): BOOL; stdcall; external 'kernel32' name 'QueryPerformanceFrequency';
function QueryPerformanceCounter(var lpPerformanceCount: Int64): BOOL; stdcall; external 'kernel32' name 'QueryPerformanceCounter';
procedure GetSystemTimeAsFileTime(var lpSystemTimeAsFileTime: FILETIME); stdcall; external 'kernel32' name 'GetSystemTimeAsFileTime';
function SwitchToThread: BOOL; stdcall; external 'kernel32' name 'SwitchToThread';
procedure Sleep(dwMilliseconds: DWORD); stdcall; external 'kernel32' name 'Sleep';
function GetLastError: DWORD; stdcall; external 'kernel32' name 'GetLastError';
procedure GetSystemInfo(var lpSystemInfo: SYSTEM_INFO); stdcall; external 'kernel32' name 'GetSystemInfo';

function TlsAlloc: DWORD; stdcall; external 'kernel32' name 'TlsAlloc';
function TlsFree(dwTlsIndex: DWORD): BOOL; stdcall; external 'kernel32' name 'TlsFree';
function TlsSetValue(dwTlsIndex: DWORD; lpTlsValue: Pointer): BOOL; stdcall; external 'kernel32' name 'TlsSetValue';
function TlsGetValue(dwTlsIndex: DWORD): Pointer; stdcall; external 'kernel32' name 'TlsGetValue';

function InterlockedDecrement(var Addend: Int32): Int32; stdcall; external 'kernel32' name 'InterlockedDecrement';

procedure InitializeSRWLock(SRWLock: Pointer); stdcall; external 'kernel32' name 'InitializeSRWLock';
procedure AcquireSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockExclusive';
function TryAcquireSRWLockExclusive(SRWLock: Pointer): BOOL; stdcall; external 'kernel32' name 'TryAcquireSRWLockExclusive';
procedure ReleaseSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockExclusive';
procedure AcquireSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockShared';
function TryAcquireSRWLockShared(SRWLock: Pointer): BOOL; stdcall; external 'kernel32' name 'TryAcquireSRWLockShared';
procedure ReleaseSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockShared';

procedure InitializeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'InitializeConditionVariable';
function SleepConditionVariableSRW(ConditionVariable: Pointer; SRWLock: Pointer; dwMilliseconds: DWORD; Flags: DWORD): BOOL; stdcall; external 'kernel32' name 'SleepConditionVariableSRW';
procedure WakeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeConditionVariable';
procedure WakeAllConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeAllConditionVariable';

function WaitOnAddress(Address: Pointer; CompareAddress: Pointer; AddressSize: PtrUInt; dwMilliseconds: DWORD): BOOL; stdcall; external 'kernel32' name 'WaitOnAddress';
procedure WakeByAddressSingle(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressSingle';
procedure WakeByAddressAll(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressAll';

implementation

const
  WINDOWS_NANOSECONDS_PER_MILLISECOND = UInt64(1000000);

var
  GWindowsQpcFrequency: Int64 = 0;

function windows_positive_ns_to_ms(const ANanoseconds: UInt64): DWORD; inline;
var
  LMs: UInt64;
begin
  if ANanoseconds = 0 then
    Exit(0);

  LMs := ANanoseconds div WINDOWS_NANOSECONDS_PER_MILLISECOND;
  if (ANanoseconds mod WINDOWS_NANOSECONDS_PER_MILLISECOND) <> 0 then
    Inc(LMs);

  if LMs >= UInt64(INFINITE) then
    Result := INFINITE - 1
  else
    Result := DWORD(LMs);
end;

function windows_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD; inline;
begin
  if ATimeoutNs < 0 then
    Exit(INFINITE);

  Result := windows_positive_ns_to_ms(UInt64(ATimeoutNs));
end;

function windows_sleep_ns_to_ms(const ANanoseconds: UInt64): DWORD; inline;
begin
  Result := windows_positive_ns_to_ms(ANanoseconds);
end;

function windows_last_error_i32: Int32; inline;
begin
  Result := Int32(GetLastError);
end;

function windows_last_error_is_timeout(const AError: DWORD): Boolean; inline;
begin
  Result := AError = ERROR_TIMEOUT;
end;

function windows_wait_for_single_object_is_signaled(const AWaitResult: DWORD): Boolean; inline;
begin
  Result := AWaitResult = WAIT_OBJECT_0;
end;

function windows_mutex_init(const AMutex: Pointer): Int32; inline;
begin
  InitializeSRWLock(AMutex);
  Result := 0;
end;

function windows_mutex_lock(const AMutex: Pointer): Int32; inline;
begin
  AcquireSRWLockExclusive(AMutex);
  Result := 0;
end;

function windows_mutex_trylock(const AMutex: Pointer): Boolean; inline;
begin
  Result := TryAcquireSRWLockExclusive(AMutex);
end;

function windows_mutex_unlock(const AMutex: Pointer): Int32; inline;
begin
  ReleaseSRWLockExclusive(AMutex);
  Result := 0;
end;

function windows_rwlock_init(const ARwLock: Pointer): Int32; inline;
begin
  InitializeSRWLock(ARwLock);
  Result := 0;
end;

function windows_rwlock_rdlock(const ARwLock: Pointer): Int32; inline;
begin
  AcquireSRWLockShared(ARwLock);
  Result := 0;
end;

function windows_rwlock_tryrdlock(const ARwLock: Pointer): Boolean; inline;
begin
  Result := TryAcquireSRWLockShared(ARwLock);
end;

function windows_rwlock_wrlock(const ARwLock: Pointer): Int32; inline;
begin
  AcquireSRWLockExclusive(ARwLock);
  Result := 0;
end;

function windows_rwlock_trywrlock(const ARwLock: Pointer): Boolean; inline;
begin
  Result := TryAcquireSRWLockExclusive(ARwLock);
end;

function windows_rwlock_rdunlock(const ARwLock: Pointer): Int32; inline;
begin
  ReleaseSRWLockShared(ARwLock);
  Result := 0;
end;

function windows_rwlock_wrunlock(const ARwLock: Pointer): Int32; inline;
begin
  ReleaseSRWLockExclusive(ARwLock);
  Result := 0;
end;

function windows_condvar_init(const ACondVar: Pointer): Int32; inline;
begin
  InitializeConditionVariable(ACondVar);
  Result := 0;
end;

function windows_condvar_wait(const ACondVar: Pointer; const AMutex: Pointer): Int32; inline;
begin
  Result := windows_condvar_timedwait_ms(ACondVar, AMutex, INFINITE);
end;

function windows_condvar_timedwait_ms(
  const ACondVar: Pointer;
  const AMutex: Pointer;
  const ATimeoutMs: DWORD): Int32; inline;
begin
  if SleepConditionVariableSRW(ACondVar, AMutex, ATimeoutMs, 0) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_condvar_signal(const ACondVar: Pointer): Int32; inline;
begin
  WakeConditionVariable(ACondVar);
  Result := 0;
end;

function windows_condvar_broadcast(const ACondVar: Pointer): Int32; inline;
begin
  WakeAllConditionVariable(ACondVar);
  Result := 0;
end;

function windows_wait_address_i32(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutMs: DWORD): Int32; inline;
var
  LExpected: Int32;
begin
  LExpected := AExpected;
  if WaitOnAddress(AAddress, @LExpected, SizeOf(Int32), ATimeoutMs) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_wake_address_single(const AAddress: PInt32): Int32; inline;
begin
  WakeByAddressSingle(AAddress);
  Result := 0;
end;

function windows_wake_address_all(const AAddress: PInt32): Int32; inline;
begin
  WakeByAddressAll(AAddress);
  Result := 0;
end;

function windows_current_thread_id_u64: UInt64; inline;
begin
  Result := UInt64(GetCurrentThreadId);
end;

function windows_thread_create_handle(
  const AStartAddress: TWinThreadStartRoutine;
  const AParameter: Pointer;
  out AHandle: HANDLE): Int32; inline;
var
  LId: DWORD;
begin
  AHandle := nil;
  LId := 0;
  AHandle := CreateThread(nil, 0, AStartAddress, AParameter, 0, @LId);
  if AHandle <> nil then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_thread_wait_terminated(const AHandle: HANDLE): Int32; inline;
begin
  if windows_wait_for_single_object_is_signaled(
    WaitForSingleObject(AHandle, INFINITE)) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_thread_close_handle(const AHandle: HANDLE): Int32; inline;
begin
  if CloseHandle(AHandle) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

procedure windows_thread_sleep_ns(const ANanoseconds: UInt64); inline;
var
  LMs: DWORD;
begin
  if ANanoseconds = 0 then
    Exit;

  LMs := windows_sleep_ns_to_ms(ANanoseconds);
  Sleep(LMs);
end;

function windows_atomic_decrement_i32(var AValue: Int32): Int32; inline;
begin
  Result := InterlockedDecrement(AValue);
end;

procedure windows_thread_yield; inline;
begin
  SwitchToThread;
end;

function windows_tls_alloc_key(out AIndex: DWORD): Int32; inline;
begin
  AIndex := TlsAlloc;
  if AIndex <> TLS_OUT_OF_INDEXES then
    Result := 0
  else
  begin
    AIndex := 0;
    Result := windows_last_error_i32;
  end;
end;

function windows_tls_free_key(const AIndex: DWORD): Int32; inline;
begin
  if TlsFree(AIndex) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_tls_set_value(const AIndex: DWORD; const AValue: Pointer): Int32; inline;
begin
  if TlsSetValue(AIndex, AValue) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_tls_get_value(const AIndex: DWORD): Pointer; inline;
begin
  Result := TlsGetValue(AIndex);
end;

function windows_cpu_count_i32: Int32; inline;
var
  LInfo: SYSTEM_INFO;
begin
  GetSystemInfo(LInfo);
  Result := Int32(LInfo.dwNumberOfProcessors);
  if Result < 1 then
    Result := 1;
end;

function windows_qpc_frequency_u64: UInt64;
begin
  if GWindowsQpcFrequency = 0 then
  begin
    if not QueryPerformanceFrequency(GWindowsQpcFrequency) then
      GWindowsQpcFrequency := 1;
    if GWindowsQpcFrequency <= 0 then
      GWindowsQpcFrequency := 1;
  end;

  Result := UInt64(GWindowsQpcFrequency);
end;

function windows_qpc_counter_u64(out ACounter: UInt64): Boolean;
var
  LCounter: Int64;
begin
  LCounter := 0;
  Result := QueryPerformanceCounter(LCounter);
  if not Result then
  begin
    ACounter := 0;
    Exit;
  end;

  if LCounter < 0 then
    ACounter := 0
  else
    ACounter := UInt64(LCounter);
end;

function windows_filetime_now_unix_ns: UInt64;
var
  LFt: FILETIME;
  LVal: UInt64;
begin
  GetSystemTimeAsFileTime(LFt);
  LVal := (UInt64(LFt.dwHighDateTime) shl 32) or UInt64(LFt.dwLowDateTime);
  Result := (LVal - WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS)
    * WINDOWS_FILETIME_NANOSECONDS_PER_TICK;
end;

end.
