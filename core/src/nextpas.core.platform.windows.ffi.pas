unit nextpas.core.platform.windows.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.windows.base;

function windows_timeout_ns_to_ms(const ATimeoutNs: Int64): DWORD; inline;
function windows_sleep_ns_to_ms(const ANanoseconds: UInt64): DWORD; inline;
function windows_last_error_i32: Int32; inline;
function windows_last_error_is_timeout(const AError: DWORD): Boolean; inline;
function windows_error_i32_is_timeout(const AError: Int32): Boolean; inline;
function windows_wait_for_single_object_is_signaled(const AWaitResult: DWORD): Boolean; inline;
function windows_mutex_init(const AMutex: Pointer): Int32; inline;
function windows_mutex_lock(const AMutex: Pointer): Int32; inline;
function windows_mutex_trylock(const AMutex: Pointer): Boolean; inline;
function windows_mutex_trylock_busy_result(const AMutex: Pointer; const ABusyResult: Int32): Int32; inline;
function windows_mutex_unlock(const AMutex: Pointer): Int32; inline;
function windows_mutex_destroy(const AMutex: Pointer): Int32; inline;
function windows_rwlock_init(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_rdlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_tryrdlock(const ARwLock: Pointer): Boolean; inline;
function windows_rwlock_tryrdlock_busy_result(const ARwLock: Pointer; const ABusyResult: Int32): Int32; inline;
function windows_rwlock_wrlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_trywrlock(const ARwLock: Pointer): Boolean; inline;
function windows_rwlock_trywrlock_busy_result(const ARwLock: Pointer; const ABusyResult: Int32): Int32; inline;
function windows_rwlock_rdunlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_wrunlock(const ARwLock: Pointer): Int32; inline;
function windows_rwlock_destroy(const ARwLock: Pointer): Int32; inline;
function windows_condvar_init(const ACondVar: Pointer): Int32; inline;
function windows_condvar_destroy(const ACondVar: Pointer): Int32; inline;
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
function windows_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64; inline;
function windows_qpc_resolution_ns(const AFrequency: UInt64): UInt64; inline;
function windows_filetime_now_unix_ns: UInt64;
function platform_clock_monotonic_ns_u64: UInt64;
function platform_clock_realtime_ns_u64: UInt64; inline;
function platform_clock_monotonic_resolution_ns_u64: UInt64;
function windows_process_id_u64: UInt64; inline;
function windows_load_library_a(const AName: PAnsiChar): HMODULE; inline;
function windows_get_proc_address(const AModule: HMODULE; const AName: PAnsiChar): FARPROC; inline;
function windows_free_library(const AModule: HMODULE): Int32; inline;
function windows_virtual_alloc(
  const AAddress: Pointer;
  const ASize: PtrUInt;
  const AAllocationType: DWORD;
  const AProtect: DWORD): Pointer; inline;
function windows_virtual_free(
  const AAddress: Pointer;
  const ASize: PtrUInt;
  const AFreeType: DWORD): Int32; inline;
function windows_virtual_protect(
  const AAddress: Pointer;
  const ASize: PtrUInt;
  const ANewProtect: DWORD;
  out AOldProtect: DWORD): Int32; inline;
function windows_create_file_a(
  const AFileName: LPCSTR;
  const ADesiredAccess: DWORD;
  const AShareMode: DWORD;
  const ASecurityAttributes: Pointer;
  const ACreationDisposition: DWORD;
  const AFlagsAndAttributes: DWORD;
  const ATemplateFile: HANDLE): HANDLE; inline;
function windows_create_file_w(
  const AFileName: LPCWSTR;
  const ADesiredAccess: DWORD;
  const AShareMode: DWORD;
  const ASecurityAttributes: Pointer;
  const ACreationDisposition: DWORD;
  const AFlagsAndAttributes: DWORD;
  const ATemplateFile: HANDLE): HANDLE; inline;
function windows_read_file(
  const AFile: HANDLE;
  const ABuffer: Pointer;
  const ABytesToRead: DWORD;
  out ABytesRead: DWORD): Int32; inline;
function windows_write_file(
  const AFile: HANDLE;
  const ABuffer: Pointer;
  const ABytesToWrite: DWORD;
  out ABytesWritten: DWORD): Int32; inline;
function windows_file_close_handle(const AHandle: HANDLE): Int32; inline;
function windows_get_file_size(
  const AFile: HANDLE;
  out AFileSize: UInt64): Int32; inline;
function windows_get_file_size_ex(
  const AFile: HANDLE;
  out AFileSize: Int64): Int32; inline;
function windows_set_file_pointer(
  const AFile: HANDLE;
  const ADistanceToMove: LONG;
  ADistanceToMoveHigh: PLONG;
  const AMoveMethod: DWORD;
  out ANewFilePointerLow: DWORD): Int32; inline;
function windows_set_file_pointer_ex(
  const AFile: HANDLE;
  const ADistanceToMove: Int64;
  out ANewFilePointer: Int64;
  const AMoveMethod: DWORD): Int32; inline;
function windows_flush_file_buffers(const AFile: HANDLE): Int32; inline;
function windows_set_end_of_file(const AFile: HANDLE): Int32; inline;
function windows_get_file_attributes_ex_a(
  const AFileName: LPCSTR;
  out AFileInformation: WIN32_FILE_ATTRIBUTE_DATA): Int32; inline;
function windows_get_file_attributes_ex_w(
  const AFileName: LPCWSTR;
  out AFileInformation: WIN32_FILE_ATTRIBUTE_DATA): Int32; inline;
function windows_get_file_information_by_handle(
  const AFile: HANDLE;
  out AFileInformation: BY_HANDLE_FILE_INFORMATION): Int32; inline;
function windows_create_directory_a(
  const APathName: LPCSTR;
  const ASecurityAttributes: Pointer): Int32; inline;
function windows_create_directory_w(
  const APathName: LPCWSTR;
  const ASecurityAttributes: Pointer): Int32; inline;
function windows_remove_directory_a(const APathName: LPCSTR): Int32; inline;
function windows_remove_directory_w(const APathName: LPCWSTR): Int32; inline;
function windows_delete_file_a(const AFileName: LPCSTR): Int32; inline;
function windows_delete_file_w(const AFileName: LPCWSTR): Int32; inline;
function windows_move_file_a(
  const AExistingFileName: LPCSTR;
  const ANewFileName: LPCSTR): Int32; inline;
function windows_move_file_w(
  const AExistingFileName: LPCWSTR;
  const ANewFileName: LPCWSTR): Int32; inline;
function windows_get_current_directory_a(
  const ABufferLength: DWORD;
  ABuffer: LPSTR): DWORD; inline;
function windows_get_current_directory_w(
  const ABufferLength: DWORD;
  ABuffer: LPWSTR): DWORD; inline;
function windows_set_current_directory_a(const APathName: LPCSTR): Int32; inline;
function windows_set_current_directory_w(const APathName: LPCWSTR): Int32; inline;
function windows_get_full_path_name_a(
  const AFileName: LPCSTR;
  const ABufferLength: DWORD;
  ABuffer: LPSTR;
  AFilePart: PLPSTR): DWORD; inline;
function windows_get_full_path_name_w(
  const AFileName: LPCWSTR;
  const ABufferLength: DWORD;
  ABuffer: LPWSTR;
  AFilePart: PLPWSTR): DWORD; inline;
function windows_get_environment_variable_a(
  const AName: LPCSTR;
  ABuffer: LPSTR;
  const ABufferLength: DWORD): DWORD; inline;
function windows_get_environment_variable_w(
  const AName: LPCWSTR;
  ABuffer: LPWSTR;
  const ABufferLength: DWORD): DWORD; inline;
function windows_set_environment_variable_a(
  const AName: LPCSTR;
  const AValue: LPCSTR): Int32; inline;
function windows_set_environment_variable_w(
  const AName: LPCWSTR;
  const AValue: LPCWSTR): Int32; inline;
function windows_get_environment_strings_a: LPSTR; inline;
function windows_get_environment_strings_w: LPWSTR; inline;
function windows_free_environment_strings_a(const AEnvironment: LPSTR): Int32; inline;
function windows_free_environment_strings_w(const AEnvironment: LPWSTR): Int32; inline;
function windows_expand_environment_strings_a(
  const ASource: LPCSTR;
  ADestination: LPSTR;
  const ADestinationLength: DWORD): DWORD; inline;
function windows_expand_environment_strings_w(
  const ASource: LPCWSTR;
  ADestination: LPWSTR;
  const ADestinationLength: DWORD): DWORD; inline;

function CreateThread(lpThreadAttributes: Pointer; dwStackSize: PtrUInt; lpStartAddress: TWinThreadStartRoutine; lpParameter: Pointer; dwCreationFlags: DWORD; lpThreadId: Pointer): HANDLE; stdcall; external 'kernel32' name 'CreateThread';
function WaitForSingleObject(hHandle: HANDLE; dwMilliseconds: DWORD): DWORD; stdcall; external 'kernel32' name 'WaitForSingleObject';
function CloseHandle(hObject: HANDLE): BOOL; stdcall; external 'kernel32' name 'CloseHandle';
function GetCurrentProcessId: DWORD; stdcall; external 'kernel32' name 'GetCurrentProcessId';
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
function LoadLibraryA(lpLibFileName: PAnsiChar): HMODULE; stdcall; external 'kernel32' name 'LoadLibraryA';
function GetProcAddress(hModule: HMODULE; lpProcName: PAnsiChar): FARPROC; stdcall; external 'kernel32' name 'GetProcAddress';
function FreeLibrary(hLibModule: HMODULE): BOOL; stdcall; external 'kernel32' name 'FreeLibrary';
function VirtualAlloc(lpAddress: Pointer; dwSize: PtrUInt; flAllocationType: DWORD; flProtect: DWORD): Pointer; stdcall; external 'kernel32' name 'VirtualAlloc';
function VirtualFree(lpAddress: Pointer; dwSize: PtrUInt; dwFreeType: DWORD): BOOL; stdcall; external 'kernel32' name 'VirtualFree';
function VirtualProtect(lpAddress: Pointer; dwSize: PtrUInt; flNewProtect: DWORD; var lpflOldProtect: DWORD): BOOL; stdcall; external 'kernel32' name 'VirtualProtect';
function CreateFileA(lpFileName: LPCSTR; dwDesiredAccess: DWORD; dwShareMode: DWORD; lpSecurityAttributes: Pointer; dwCreationDisposition: DWORD; dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE; stdcall; external 'kernel32' name 'CreateFileA';
function CreateFileW(lpFileName: LPCWSTR; dwDesiredAccess: DWORD; dwShareMode: DWORD; lpSecurityAttributes: Pointer; dwCreationDisposition: DWORD; dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE; stdcall; external 'kernel32' name 'CreateFileW';
function ReadFile(hFile: HANDLE; lpBuffer: Pointer; nNumberOfBytesToRead: DWORD; lpNumberOfBytesRead: LPDWORD; lpOverlapped: Pointer): BOOL; stdcall; external 'kernel32' name 'ReadFile';
function WriteFile(hFile: HANDLE; lpBuffer: Pointer; nNumberOfBytesToWrite: DWORD; lpNumberOfBytesWritten: LPDWORD; lpOverlapped: Pointer): BOOL; stdcall; external 'kernel32' name 'WriteFile';
function GetFileSize(hFile: HANDLE; lpFileSizeHigh: LPDWORD): DWORD; stdcall; external 'kernel32' name 'GetFileSize';
function FlushFileBuffers(hFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'FlushFileBuffers';
function SetEndOfFile(hFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'SetEndOfFile';
function SetFilePointer(hFile: HANDLE; lDistanceToMove: LONG; lpDistanceToMoveHigh: PLONG; dwMoveMethod: DWORD): DWORD; stdcall; external 'kernel32' name 'SetFilePointer';
function GetFileSizeEx(InFileHandle: HANDLE; OutFileSize: PINT64): BOOL; stdcall; external 'kernel32' name 'GetFileSizeEx';
function SetFilePointerEx(InFile: HANDLE; InDistanceToMove: Int64; OutoptNewFilePointer: PINT64; InMoveMethod: DWORD): BOOL; stdcall; external 'kernel32' name 'SetFilePointerEx';
function GetFileAttributesExA(lpFileName: LPCSTR; fInfoLevelId: GET_FILEEX_INFO_LEVELS; lpFileInformation: Pointer): BOOL; stdcall; external 'kernel32' name 'GetFileAttributesExA';
function GetFileAttributesExW(lpFileName: LPCWSTR; fInfoLevelId: GET_FILEEX_INFO_LEVELS; lpFileInformation: Pointer): BOOL; stdcall; external 'kernel32' name 'GetFileAttributesExW';
function GetFileInformationByHandle(hFile: HANDLE; lpFileInformation: PBY_HANDLE_FILE_INFORMATION): BOOL; stdcall; external 'kernel32' name 'GetFileInformationByHandle';
function CreateDirectoryA(lpPathName: LPCSTR; lpSecurityAttributes: Pointer): BOOL; stdcall; external 'kernel32' name 'CreateDirectoryA';
function CreateDirectoryW(lpPathName: LPCWSTR; lpSecurityAttributes: Pointer): BOOL; stdcall; external 'kernel32' name 'CreateDirectoryW';
function RemoveDirectoryA(lpPathName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'RemoveDirectoryA';
function RemoveDirectoryW(lpPathName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'RemoveDirectoryW';
function DeleteFileA(lpFileName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'DeleteFileA';
function DeleteFileW(lpFileName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'DeleteFileW';
function MoveFileA(lpExistingFileName: LPCSTR; lpNewFileName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'MoveFileA';
function MoveFileW(lpExistingFileName: LPCWSTR; lpNewFileName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'MoveFileW';
function GetCurrentDirectoryA(nBufferLength: DWORD; lpBuffer: LPSTR): DWORD; stdcall; external 'kernel32' name 'GetCurrentDirectoryA';
function GetCurrentDirectoryW(nBufferLength: DWORD; lpBuffer: LPWSTR): DWORD; stdcall; external 'kernel32' name 'GetCurrentDirectoryW';
function SetCurrentDirectoryA(lpPathName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'SetCurrentDirectoryA';
function SetCurrentDirectoryW(lpPathName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'SetCurrentDirectoryW';
function GetFullPathNameA(lpFileName: LPCSTR; nBufferLength: DWORD; lpBuffer: LPSTR; lpFilePart: PLPSTR): DWORD; stdcall; external 'kernel32' name 'GetFullPathNameA';
function GetFullPathNameW(lpFileName: LPCWSTR; nBufferLength: DWORD; lpBuffer: LPWSTR; lpFilePart: PLPWSTR): DWORD; stdcall; external 'kernel32' name 'GetFullPathNameW';
function GetEnvironmentVariableA(lpName: LPCSTR; lpBuffer: LPSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'GetEnvironmentVariableA';
function GetEnvironmentVariableW(lpName: LPCWSTR; lpBuffer: LPWSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'GetEnvironmentVariableW';
function SetEnvironmentVariableA(lpName: LPCSTR; lpValue: LPCSTR): BOOL; stdcall; external 'kernel32' name 'SetEnvironmentVariableA';
function SetEnvironmentVariableW(lpName: LPCWSTR; lpValue: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'SetEnvironmentVariableW';
function GetEnvironmentStringsA: LPSTR; stdcall; external 'kernel32' name 'GetEnvironmentStringsA';
function GetEnvironmentStringsW: LPWSTR; stdcall; external 'kernel32' name 'GetEnvironmentStringsW';
function FreeEnvironmentStringsA(lpszEnvironmentBlock: LPSTR): BOOL; stdcall; external 'kernel32' name 'FreeEnvironmentStringsA';
function FreeEnvironmentStringsW(lpszEnvironmentBlock: LPWSTR): BOOL; stdcall; external 'kernel32' name 'FreeEnvironmentStringsW';
function ExpandEnvironmentStringsA(lpSrc: LPCSTR; lpDst: LPSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'ExpandEnvironmentStringsA';
function ExpandEnvironmentStringsW(lpSrc: LPCWSTR; lpDst: LPWSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'ExpandEnvironmentStringsW';
function CreateProcessA(lpApplicationName: LPCSTR; lpCommandLine: LPSTR; lpProcessAttributes: LPSECURITY_ATTRIBUTES; lpThreadAttributes: LPSECURITY_ATTRIBUTES; bInheritHandles: WINBOOL; dwCreationFlags: DWORD; lpEnvironment: LPVOID; lpCurrentDirectory: LPCSTR; lpStartupInfo: LPSTARTUPINFOA; lpProcessInformation: LPPROCESS_INFORMATION): WINBOOL; stdcall; external 'kernel32' name 'CreateProcessA';
function CreateProcessW(lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR; lpProcessAttributes: LPSECURITY_ATTRIBUTES; lpThreadAttributes: LPSECURITY_ATTRIBUTES; bInheritHandles: WINBOOL; dwCreationFlags: DWORD; lpEnvironment: LPVOID; lpCurrentDirectory: LPCWSTR; lpStartupInfo: LPSTARTUPINFOW; lpProcessInformation: LPPROCESS_INFORMATION): WINBOOL; stdcall; external 'kernel32' name 'CreateProcessW';
procedure GetStartupInfoA(lpStartupInfo: LPSTARTUPINFOA); stdcall; external 'kernel32' name 'GetStartupInfoA';
procedure GetStartupInfoW(lpStartupInfo: LPSTARTUPINFOW); stdcall; external 'kernel32' name 'GetStartupInfoW';
function TerminateProcess(hProcess: HANDLE; uExitCode: UINT): WINBOOL; stdcall; external 'kernel32' name 'TerminateProcess';
function GetExitCodeProcess(hProcess: HANDLE; lpExitCode: LPDWORD): WINBOOL; stdcall; external 'kernel32' name 'GetExitCodeProcess';
procedure ExitProcess(uExitCode: UINT); stdcall; external 'kernel32' name 'ExitProcess';

implementation

uses
  nextpas.core.platform.windows.math;

const
  WINDOWS_NANOSECONDS_PER_MILLISECOND = UInt64(1000000);

var
  GWindowsQpcFrequency: Int64 = 0;

function windows_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64; inline;
begin
  Result := nextpas.core.platform.windows.math.windows_qpc_to_ns(ACounter, AFrequency);
end;

function windows_qpc_resolution_ns(const AFrequency: UInt64): UInt64; inline;
begin
  Result := nextpas.core.platform.windows.math.windows_qpc_resolution_ns(AFrequency);
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

function windows_process_id_u64: UInt64; inline;
begin
  Result := UInt64(GetCurrentProcessId);
end;

function windows_load_library_a(const AName: PAnsiChar): HMODULE; inline;
begin
  Result := LoadLibraryA(AName);
end;

function windows_get_proc_address(const AModule: HMODULE; const AName: PAnsiChar): FARPROC; inline;
begin
  Result := GetProcAddress(AModule, AName);
end;

function windows_free_library(const AModule: HMODULE): Int32; inline;
begin
  if FreeLibrary(AModule) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_virtual_alloc(
  const AAddress: Pointer;
  const ASize: PtrUInt;
  const AAllocationType: DWORD;
  const AProtect: DWORD): Pointer; inline;
begin
  Result := VirtualAlloc(AAddress, ASize, AAllocationType, AProtect);
end;

function windows_virtual_free(
  const AAddress: Pointer;
  const ASize: PtrUInt;
  const AFreeType: DWORD): Int32; inline;
begin
  if VirtualFree(AAddress, ASize, AFreeType) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_virtual_protect(
  const AAddress: Pointer;
  const ASize: PtrUInt;
  const ANewProtect: DWORD;
  out AOldProtect: DWORD): Int32; inline;
begin
  AOldProtect := 0;
  if VirtualProtect(AAddress, ASize, ANewProtect, AOldProtect) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_create_file_a(
  const AFileName: LPCSTR;
  const ADesiredAccess: DWORD;
  const AShareMode: DWORD;
  const ASecurityAttributes: Pointer;
  const ACreationDisposition: DWORD;
  const AFlagsAndAttributes: DWORD;
  const ATemplateFile: HANDLE): HANDLE; inline;
begin
  Result := CreateFileA(
    AFileName,
    ADesiredAccess,
    AShareMode,
    ASecurityAttributes,
    ACreationDisposition,
    AFlagsAndAttributes,
    ATemplateFile);
end;

function windows_create_file_w(
  const AFileName: LPCWSTR;
  const ADesiredAccess: DWORD;
  const AShareMode: DWORD;
  const ASecurityAttributes: Pointer;
  const ACreationDisposition: DWORD;
  const AFlagsAndAttributes: DWORD;
  const ATemplateFile: HANDLE): HANDLE; inline;
begin
  Result := CreateFileW(
    AFileName,
    ADesiredAccess,
    AShareMode,
    ASecurityAttributes,
    ACreationDisposition,
    AFlagsAndAttributes,
    ATemplateFile);
end;

function windows_read_file(
  const AFile: HANDLE;
  const ABuffer: Pointer;
  const ABytesToRead: DWORD;
  out ABytesRead: DWORD): Int32; inline;
begin
  ABytesRead := 0;
  if ReadFile(AFile, ABuffer, ABytesToRead, @ABytesRead, nil) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_write_file(
  const AFile: HANDLE;
  const ABuffer: Pointer;
  const ABytesToWrite: DWORD;
  out ABytesWritten: DWORD): Int32; inline;
begin
  ABytesWritten := 0;
  if WriteFile(AFile, ABuffer, ABytesToWrite, @ABytesWritten, nil) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_file_close_handle(const AHandle: HANDLE): Int32; inline;
begin
  Result := windows_thread_close_handle(AHandle);
end;

function windows_get_file_size(
  const AFile: HANDLE;
  out AFileSize: UInt64): Int32; inline;
var
  LLow: DWORD;
  LHigh: DWORD;
  LLastError: DWORD;
begin
  AFileSize := 0;
  LHigh := 0;
  LLow := GetFileSize(AFile, @LHigh);
  if LLow <> INVALID_SET_FILE_POINTER then
  begin
    AFileSize := (UInt64(LHigh) shl 32) or UInt64(LLow);
    Exit(0);
  end;

  LLastError := GetLastError;
  if LLastError = 0 then
  begin
    AFileSize := (UInt64(LHigh) shl 32) or UInt64(LLow);
    Exit(0);
  end;

  Result := Int32(LLastError);
end;

function windows_get_file_size_ex(
  const AFile: HANDLE;
  out AFileSize: Int64): Int32; inline;
begin
  AFileSize := 0;
  if GetFileSizeEx(AFile, @AFileSize) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_set_file_pointer(
  const AFile: HANDLE;
  const ADistanceToMove: LONG;
  ADistanceToMoveHigh: PLONG;
  const AMoveMethod: DWORD;
  out ANewFilePointerLow: DWORD): Int32; inline;
var
  LLastError: DWORD;
begin
  ANewFilePointerLow := SetFilePointer(AFile, ADistanceToMove, ADistanceToMoveHigh, AMoveMethod);
  if ANewFilePointerLow <> INVALID_SET_FILE_POINTER then
    Exit(0);

  LLastError := GetLastError;
  if LLastError = 0 then
    Result := 0
  else
    Result := Int32(LLastError);
end;

function windows_set_file_pointer_ex(
  const AFile: HANDLE;
  const ADistanceToMove: Int64;
  out ANewFilePointer: Int64;
  const AMoveMethod: DWORD): Int32; inline;
begin
  ANewFilePointer := 0;
  if SetFilePointerEx(AFile, ADistanceToMove, @ANewFilePointer, AMoveMethod) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_flush_file_buffers(const AFile: HANDLE): Int32; inline;
begin
  if FlushFileBuffers(AFile) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_set_end_of_file(const AFile: HANDLE): Int32; inline;
begin
  if SetEndOfFile(AFile) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_get_file_attributes_ex_a(
  const AFileName: LPCSTR;
  out AFileInformation: WIN32_FILE_ATTRIBUTE_DATA): Int32; inline;
begin
  FillChar(AFileInformation, SizeOf(AFileInformation), 0);
  if GetFileAttributesExA(AFileName, GetFileExInfoStandard, @AFileInformation) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_get_file_attributes_ex_w(
  const AFileName: LPCWSTR;
  out AFileInformation: WIN32_FILE_ATTRIBUTE_DATA): Int32; inline;
begin
  FillChar(AFileInformation, SizeOf(AFileInformation), 0);
  if GetFileAttributesExW(AFileName, GetFileExInfoStandard, @AFileInformation) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_get_file_information_by_handle(
  const AFile: HANDLE;
  out AFileInformation: BY_HANDLE_FILE_INFORMATION): Int32; inline;
begin
  FillChar(AFileInformation, SizeOf(AFileInformation), 0);
  if GetFileInformationByHandle(AFile, @AFileInformation) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_create_directory_a(
  const APathName: LPCSTR;
  const ASecurityAttributes: Pointer): Int32; inline;
begin
  if CreateDirectoryA(APathName, ASecurityAttributes) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_create_directory_w(
  const APathName: LPCWSTR;
  const ASecurityAttributes: Pointer): Int32; inline;
begin
  if CreateDirectoryW(APathName, ASecurityAttributes) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_remove_directory_a(const APathName: LPCSTR): Int32; inline;
begin
  if RemoveDirectoryA(APathName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_remove_directory_w(const APathName: LPCWSTR): Int32; inline;
begin
  if RemoveDirectoryW(APathName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_delete_file_a(const AFileName: LPCSTR): Int32; inline;
begin
  if DeleteFileA(AFileName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_delete_file_w(const AFileName: LPCWSTR): Int32; inline;
begin
  if DeleteFileW(AFileName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_move_file_a(
  const AExistingFileName: LPCSTR;
  const ANewFileName: LPCSTR): Int32; inline;
begin
  if MoveFileA(AExistingFileName, ANewFileName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_move_file_w(
  const AExistingFileName: LPCWSTR;
  const ANewFileName: LPCWSTR): Int32; inline;
begin
  if MoveFileW(AExistingFileName, ANewFileName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_get_current_directory_a(
  const ABufferLength: DWORD;
  ABuffer: LPSTR): DWORD; inline;
begin
  Result := GetCurrentDirectoryA(ABufferLength, ABuffer);
end;

function windows_get_current_directory_w(
  const ABufferLength: DWORD;
  ABuffer: LPWSTR): DWORD; inline;
begin
  Result := GetCurrentDirectoryW(ABufferLength, ABuffer);
end;

function windows_set_current_directory_a(const APathName: LPCSTR): Int32; inline;
begin
  if SetCurrentDirectoryA(APathName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_set_current_directory_w(const APathName: LPCWSTR): Int32; inline;
begin
  if SetCurrentDirectoryW(APathName) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_get_full_path_name_a(
  const AFileName: LPCSTR;
  const ABufferLength: DWORD;
  ABuffer: LPSTR;
  AFilePart: PLPSTR): DWORD; inline;
begin
  Result := GetFullPathNameA(AFileName, ABufferLength, ABuffer, AFilePart);
end;

function windows_get_full_path_name_w(
  const AFileName: LPCWSTR;
  const ABufferLength: DWORD;
  ABuffer: LPWSTR;
  AFilePart: PLPWSTR): DWORD; inline;
begin
  Result := GetFullPathNameW(AFileName, ABufferLength, ABuffer, AFilePart);
end;

function windows_get_environment_variable_a(
  const AName: LPCSTR;
  ABuffer: LPSTR;
  const ABufferLength: DWORD): DWORD; inline;
begin
  Result := GetEnvironmentVariableA(AName, ABuffer, ABufferLength);
end;

function windows_get_environment_variable_w(
  const AName: LPCWSTR;
  ABuffer: LPWSTR;
  const ABufferLength: DWORD): DWORD; inline;
begin
  Result := GetEnvironmentVariableW(AName, ABuffer, ABufferLength);
end;

function windows_set_environment_variable_a(
  const AName: LPCSTR;
  const AValue: LPCSTR): Int32; inline;
begin
  if SetEnvironmentVariableA(AName, AValue) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_set_environment_variable_w(
  const AName: LPCWSTR;
  const AValue: LPCWSTR): Int32; inline;
begin
  if SetEnvironmentVariableW(AName, AValue) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_get_environment_strings_a: LPSTR; inline;
begin
  Result := GetEnvironmentStringsA;
end;

function windows_get_environment_strings_w: LPWSTR; inline;
begin
  Result := GetEnvironmentStringsW;
end;

function windows_free_environment_strings_a(const AEnvironment: LPSTR): Int32; inline;
begin
  if FreeEnvironmentStringsA(AEnvironment) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_free_environment_strings_w(const AEnvironment: LPWSTR): Int32; inline;
begin
  if FreeEnvironmentStringsW(AEnvironment) then
    Result := 0
  else
    Result := windows_last_error_i32;
end;

function windows_expand_environment_strings_a(
  const ASource: LPCSTR;
  ADestination: LPSTR;
  const ADestinationLength: DWORD): DWORD; inline;
begin
  Result := ExpandEnvironmentStringsA(ASource, ADestination, ADestinationLength);
end;

function windows_expand_environment_strings_w(
  const ASource: LPCWSTR;
  ADestination: LPWSTR;
  const ADestinationLength: DWORD): DWORD; inline;
begin
  Result := ExpandEnvironmentStringsW(ASource, ADestination, ADestinationLength);
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

function windows_mutex_trylock_busy_result(const AMutex: Pointer; const ABusyResult: Int32): Int32; inline;
begin
  if windows_mutex_trylock(AMutex) then
    Exit(0);
  Result := ABusyResult;
end;

function windows_mutex_unlock(const AMutex: Pointer): Int32; inline;
begin
  ReleaseSRWLockExclusive(AMutex);
  Result := 0;
end;

function windows_mutex_destroy(const AMutex: Pointer): Int32; inline;
begin
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

function windows_rwlock_tryrdlock_busy_result(const ARwLock: Pointer; const ABusyResult: Int32): Int32; inline;
begin
  if windows_rwlock_tryrdlock(ARwLock) then
    Exit(0);
  Result := ABusyResult;
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

function windows_rwlock_trywrlock_busy_result(const ARwLock: Pointer; const ABusyResult: Int32): Int32; inline;
begin
  if windows_rwlock_trywrlock(ARwLock) then
    Exit(0);
  Result := ABusyResult;
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

function windows_rwlock_destroy(const ARwLock: Pointer): Int32; inline;
begin
  Result := 0;
end;

function windows_condvar_init(const ACondVar: Pointer): Int32; inline;
begin
  InitializeConditionVariable(ACondVar);
  Result := 0;
end;

function windows_condvar_destroy(const ACondVar: Pointer): Int32; inline;
begin
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
