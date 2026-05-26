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

const
  INFINITE = DWORD($FFFFFFFF);
  WAIT_OBJECT_0 = DWORD(0);
  ERROR_TIMEOUT = DWORD(1460);
  TLS_OUT_OF_INDEXES = DWORD($FFFFFFFF);
  WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS = UInt64(116444736000000000);
  WINDOWS_FILETIME_NANOSECONDS_PER_TICK = UInt64(100);

function windows_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD; inline;
function windows_sleep_ns_to_ms(const ANanoseconds: UInt64): DWORD; inline;
function windows_last_error_i32: Int32; inline;
function windows_last_error_is_timeout(const AError: DWORD): Boolean; inline;
function windows_wait_for_single_object_is_signaled(const AWaitResult: DWORD): Boolean; inline;

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

end.
