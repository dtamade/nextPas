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

end.
