unit nextpas.core.platform.windows.ffi;

{$I nextpas.core.settings.inc}

interface

type
  DWORD = UInt32;
  BOOL = LongBool;
  HANDLE = Pointer;
  SRWLOCK = Pointer;
  CONDITION_VARIABLE = Pointer;
  TPlatformWindowsThreadProc = function(AArg: Pointer): Pointer; cdecl;

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
  PPlatformWindowsThreadState = ^TPlatformWindowsThreadState;
  TPlatformWindowsThreadState = record
    Handle: HANDLE;
    Proc: TPlatformWindowsThreadProc;
    Arg: Pointer;
    ReturnValue: Pointer;
    RefCount: Int32;
  end;

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
function windows_error_i32_is_timeout(const AError: Int32): Boolean; inline;
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
function windows_condvar_timedwait_ns(
  const ACondVar: Pointer;
  const AMutex: Pointer;
  const ATimeoutNs: Int64): Int32; inline;
function windows_condvar_timedwait_timeout_result(
  const ACondVar: Pointer;
  const AMutex: Pointer;
  const ATimeoutNs: Int64;
  const ATimeoutResult: Int32): Int32; inline;
function windows_condvar_signal(const ACondVar: Pointer): Int32; inline;
function windows_condvar_broadcast(const ACondVar: Pointer): Int32; inline;
function windows_wait_address_i32(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutMs: DWORD): Int32; inline;
function windows_wait_address_i32_timeout_ns(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64): Int32; inline;
function windows_wait_address_i32_timeout_result(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64;
  const ATimeoutResult: Int32): Int32; inline;
function windows_wake_address_single(const AAddress: PInt32): Int32; inline;
function windows_wake_address_all(const AAddress: PInt32): Int32; inline;
function windows_current_thread_id_u64: UInt64; inline;
function windows_thread_create_handle(
  const AStartAddress: TWinThreadStartRoutine;
  const AParameter: Pointer;
  out AHandle: HANDLE): Int32; inline;
function windows_thread_wait_terminated(const AHandle: HANDLE): Int32; inline;
function windows_thread_close_handle(const AHandle: HANDLE): Int32; inline;
function windows_thread_state_create(
  const AProc: TPlatformWindowsThreadProc;
  const AArg: Pointer;
  out AState: PPlatformWindowsThreadState): Int32; inline;
function windows_thread_state_join(
  const AState: PPlatformWindowsThreadState;
  out ARetVal: Pointer): Int32; inline;
function windows_thread_state_detach(
  const AState: PPlatformWindowsThreadState): Int32; inline;
procedure windows_thread_sleep_ns(const ANanoseconds: UInt64); inline;
function windows_atomic_decrement_i32(var AValue: Int32): Int32; inline;
procedure windows_thread_yield; inline;
function windows_tls_alloc_key(out AIndex: DWORD): Int32; inline;
function windows_tls_free_key(const AIndex: DWORD): Int32; inline;
function windows_tls_set_value(const AIndex: DWORD; const AValue: Pointer): Int32; inline;
function windows_tls_get_value(const AIndex: DWORD): Pointer; inline;
function windows_tls_create_platform_key(out AKey: PtrUInt): Int32; inline;
function windows_tls_destroy_platform_key(const AKey: PtrUInt): Int32; inline;
function windows_tls_set_platform_key(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
function windows_tls_get_platform_key(const AKey: PtrUInt): Pointer; inline;
function windows_cpu_count_i32: Int32; inline;
function windows_qpc_frequency_u64: UInt64;
function windows_qpc_counter_u64(out ACounter: UInt64): Boolean;
function windows_filetime_now_unix_ns: UInt64;
function platform_clock_monotonic_ns_u64: UInt64;
function platform_clock_realtime_ns_u64: UInt64; inline;
function platform_clock_monotonic_resolution_ns_u64: UInt64;

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
  WINDOWS_NANOSECONDS_PER_SECOND = UInt64(1000000000);

var
  GWindowsQpcFrequency: Int64 = 0;

function windows_mul_div_floor(const AValue: UInt64; const AMultiplier: UInt64; const ADivisor: UInt64): UInt64;
var
  LFactor: UInt64;
  LQuotient: UInt64;
  LRemainder: UInt64;
  LTermQuotient: UInt64;
  LTermRemainder: UInt64;
begin
  if (AValue = 0) or (AMultiplier = 0) then
    Exit(0);
  if ADivisor = 0 then
    Exit(High(UInt64));

  LFactor := AMultiplier;
  LQuotient := 0;
  LRemainder := 0;
  LTermQuotient := AValue div ADivisor;
  LTermRemainder := AValue mod ADivisor;

  while LFactor <> 0 do
  begin
    if (LFactor and UInt64(1)) <> 0 then
    begin
      if LQuotient > High(UInt64) - LTermQuotient then
        Exit(High(UInt64));
      LQuotient := LQuotient + LTermQuotient;

      if LTermRemainder <> 0 then
      begin
        if LRemainder >= ADivisor - LTermRemainder then
        begin
          LRemainder := LRemainder - (ADivisor - LTermRemainder);
          if LQuotient = High(UInt64) then
            Exit(High(UInt64));
          Inc(LQuotient);
        end
        else
          LRemainder := LRemainder + LTermRemainder;
      end;
    end;

    LFactor := LFactor shr 1;
    if LFactor = 0 then
      Break;

    if LTermQuotient > High(UInt64) div 2 then
      LTermQuotient := High(UInt64)
    else
      LTermQuotient := LTermQuotient * 2;

    if LTermRemainder <> 0 then
    begin
      if LTermRemainder >= ADivisor - LTermRemainder then
      begin
        LTermRemainder := LTermRemainder - (ADivisor - LTermRemainder);
        if LTermQuotient <> High(UInt64) then
          Inc(LTermQuotient);
      end
      else
        LTermRemainder := LTermRemainder + LTermRemainder;
    end;
  end;

  Result := LQuotient;
end;

function windows_scale_units(const AValue: UInt64; const ADivisor: UInt64; const AMultiplier: UInt64): UInt64;
var
  LDivisor: UInt64;
  LWhole: UInt64;
  LRem: UInt64;
  LFrac: UInt64;
begin
  if AMultiplier = 0 then
    Exit(0);

  LDivisor := ADivisor;
  if LDivisor = 0 then
    LDivisor := 1;

  LWhole := AValue div LDivisor;
  LRem := AValue mod LDivisor;

  if LWhole > High(UInt64) div AMultiplier then
    Exit(High(UInt64));

  Result := LWhole * AMultiplier;

  if LRem = 0 then
    LFrac := 0
  else if LRem <= High(UInt64) div AMultiplier then
    LFrac := (LRem * AMultiplier) div LDivisor
  else
    LFrac := windows_mul_div_floor(LRem, AMultiplier, LDivisor);

  if Result > High(UInt64) - LFrac then
    Exit(High(UInt64));

  Result := Result + LFrac;
end;

function windows_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64; inline;
begin
  Result := windows_scale_units(ACounter, AFrequency, WINDOWS_NANOSECONDS_PER_SECOND);
end;

function windows_qpc_resolution_ns(const AFrequency: UInt64): UInt64; inline;
begin
  if AFrequency = 0 then
    Exit(1);
  if AFrequency >= WINDOWS_NANOSECONDS_PER_SECOND then
    Exit(1);
  Result := (WINDOWS_NANOSECONDS_PER_SECOND + AFrequency - 1) div AFrequency;
  if Result = 0 then
    Result := 1;
end;

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

function windows_error_i32_is_timeout(const AError: Int32): Boolean; inline;
begin
  Result := (AError >= 0) and windows_last_error_is_timeout(DWORD(AError));
end;

function windows_wait_for_single_object_is_signaled(const AWaitResult: DWORD): Boolean; inline;
begin
  Result := AWaitResult = WAIT_OBJECT_0;
end;

function windows_wait_error_timeout_result(
  const AError: Int32;
  const ATimeoutResult: Int32): Int32; inline;
begin
  if AError = 0 then
    Exit(0);
  if windows_error_i32_is_timeout(AError) then
    Exit(ATimeoutResult);
  Result := AError;
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

function windows_condvar_timedwait_ns(
  const ACondVar: Pointer;
  const AMutex: Pointer;
  const ATimeoutNs: Int64): Int32; inline;
begin
  Result := windows_condvar_timedwait_ms(
    ACondVar, AMutex, windows_timeout_ns_to_ms(ATimeoutNs));
end;

function windows_condvar_timedwait_timeout_result(
  const ACondVar: Pointer;
  const AMutex: Pointer;
  const ATimeoutNs: Int64;
  const ATimeoutResult: Int32): Int32; inline;
begin
  Result := windows_wait_error_timeout_result(
    windows_condvar_timedwait_ns(ACondVar, AMutex, ATimeoutNs),
    ATimeoutResult);
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

function windows_wait_address_i32_timeout_ns(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64): Int32; inline;
begin
  Result := windows_wait_address_i32(
    AAddress, AExpected, windows_timeout_ns_to_ms(ATimeoutNs));
end;

function windows_wait_address_i32_timeout_result(
  const AAddress: PInt32;
  const AExpected: Int32;
  const ATimeoutNs: Int64;
  const ATimeoutResult: Int32): Int32; inline;
begin
  Result := windows_wait_error_timeout_result(
    windows_wait_address_i32_timeout_ns(AAddress, AExpected, ATimeoutNs),
    ATimeoutResult);
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

procedure windows_thread_state_release(const AState: PPlatformWindowsThreadState); inline;
begin
  if AState = nil then
    Exit;

  if windows_atomic_decrement_i32(AState^.RefCount) = 0 then
    Dispose(AState);
end;

function windows_thread_entry(AParameter: Pointer): DWORD; stdcall;
var
  LState: PPlatformWindowsThreadState;
  LReturnValue: Pointer;
begin
  LState := PPlatformWindowsThreadState(AParameter);
  LReturnValue := nil;

  if (LState <> nil) and Assigned(LState^.Proc) then
    LReturnValue := LState^.Proc(LState^.Arg);

  if LState <> nil then
  begin
    LState^.ReturnValue := LReturnValue;
    windows_thread_state_release(LState);
  end;

  Result := 0;
end;

function windows_thread_state_create(
  const AProc: TPlatformWindowsThreadProc;
  const AArg: Pointer;
  out AState: PPlatformWindowsThreadState): Int32; inline;
begin
  AState := nil;
  if not Assigned(AProc) then
    Exit(-1);

  New(AState);
  AState^.Handle := nil;
  AState^.Proc := AProc;
  AState^.Arg := AArg;
  AState^.ReturnValue := nil;
  AState^.RefCount := 2;

  Result := windows_thread_create_handle(@windows_thread_entry, AState, AState^.Handle);
  if Result <> 0 then
  begin
    Dispose(AState);
    AState := nil;
  end;
end;

function windows_thread_state_join(
  const AState: PPlatformWindowsThreadState;
  out ARetVal: Pointer): Int32; inline;
begin
  ARetVal := nil;
  if AState = nil then
    Exit(-1);

  Result := windows_thread_wait_terminated(AState^.Handle);
  if Result = 0 then
  begin
    ARetVal := AState^.ReturnValue;
    Result := windows_thread_close_handle(AState^.Handle);
    AState^.Handle := nil;
    windows_thread_state_release(AState);
  end;
end;

function windows_thread_state_detach(
  const AState: PPlatformWindowsThreadState): Int32; inline;
begin
  if AState = nil then
    Exit(-1);

  Result := windows_thread_close_handle(AState^.Handle);
  if Result = 0 then
  begin
    AState^.Handle := nil;
    windows_thread_state_release(AState);
  end;
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

function windows_tls_create_platform_key(out AKey: PtrUInt): Int32; inline;
var
  LIndex: DWORD;
begin
  Result := windows_tls_alloc_key(LIndex);
  if Result = 0 then
    AKey := PtrUInt(LIndex)
  else
    AKey := 0;
end;

function windows_tls_destroy_platform_key(const AKey: PtrUInt): Int32; inline;
begin
  Result := windows_tls_free_key(DWORD(AKey));
end;

function windows_tls_set_platform_key(const AKey: PtrUInt; const AValue: Pointer): Int32; inline;
begin
  Result := windows_tls_set_value(DWORD(AKey), AValue);
end;

function windows_tls_get_platform_key(const AKey: PtrUInt): Pointer; inline;
begin
  Result := windows_tls_get_value(DWORD(AKey));
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

function platform_clock_monotonic_ns_u64: UInt64;
var
  LCounter: UInt64;
  LFrequency: UInt64;
begin
  if not windows_qpc_counter_u64(LCounter) then
    Exit(0);
  LFrequency := windows_qpc_frequency_u64;
  Result := windows_qpc_to_ns(LCounter, LFrequency);
end;

function platform_clock_realtime_ns_u64: UInt64; inline;
begin
  Result := windows_filetime_now_unix_ns;
end;

function platform_clock_monotonic_resolution_ns_u64: UInt64;
begin
  Result := windows_qpc_resolution_ns(windows_qpc_frequency_u64);
  if Result = 0 then
    Result := 1;
end;

end.
