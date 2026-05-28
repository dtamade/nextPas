unit nextpas.core.platform.windows.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.windows.base;


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

function CreateIoCompletionPort(FileHandle: HANDLE; ExistingCompletionPort: HANDLE; CompletionKey: ULONG_PTR; NumberOfConcurrentThreads: DWORD): HANDLE; stdcall; external 'kernel32' name 'CreateIoCompletionPort';
function GetQueuedCompletionStatus(CompletionPort: HANDLE; lpNumberOfBytesTransferred: LPDWORD; lpCompletionKey: Pointer; lpOverlapped: Pointer; dwMilliseconds: DWORD): WINBOOL; stdcall; external 'kernel32' name 'GetQueuedCompletionStatus';
function PostQueuedCompletionStatus(CompletionPort: HANDLE; dwNumberOfBytesTransferred: DWORD; dwCompletionKey: ULONG_PTR; lpOverlapped: LPOVERLAPPED): WINBOOL; stdcall; external 'kernel32' name 'PostQueuedCompletionStatus';
function FindFirstFileW(lpFileName: LPCWSTR; lpFindFileData: LPWIN32_FIND_DATAW): HANDLE; stdcall; external 'kernel32' name 'FindFirstFileW';
function FindNextFileW(hFindFile: HANDLE; lpFindFileData: LPWIN32_FIND_DATAW): WINBOOL; stdcall; external 'kernel32' name 'FindNextFileW';
function FindClose(hFindFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'FindClose';
procedure GetSystemTime(lpSystemTime: LPSYSTEMTIME); stdcall; external 'kernel32' name 'GetSystemTime';
procedure GetLocalTime(lpSystemTime: LPSYSTEMTIME); stdcall; external 'kernel32' name 'GetLocalTime';
function SystemTimeToFileTime(lpSystemTime: LPSYSTEMTIME; lpFileTime: Pointer): WINBOOL; stdcall; external 'kernel32' name 'SystemTimeToFileTime';
function FileTimeToSystemTime(lpFileTime: Pointer; lpSystemTime: LPSYSTEMTIME): WINBOOL; stdcall; external 'kernel32' name 'FileTimeToSystemTime';
function InitializeCriticalSectionAndSpinCount(lpCriticalSection: LPCRITICAL_SECTION; dwSpinCount: DWORD): WINBOOL; stdcall; external 'kernel32' name 'InitializeCriticalSectionAndSpinCount';
procedure DeleteCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'DeleteCriticalSection';
procedure EnterCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'EnterCriticalSection';
procedure LeaveCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'LeaveCriticalSection';
function TryEnterCriticalSection(lpCriticalSection: LPCRITICAL_SECTION): WINBOOL; stdcall; external 'kernel32' name 'TryEnterCriticalSection';
function GetOverlappedResult(hFile: HANDLE; lpOverlapped: LPOVERLAPPED; lpNumberOfBytesTransferred: LPDWORD; bWait: WINBOOL): WINBOOL; stdcall; external 'kernel32' name 'GetOverlappedResult';
function CancelIo(hFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'CancelIo';
function CancelIoEx(hFile: HANDLE; lpOverlapped: LPOVERLAPPED): WINBOOL; stdcall; external 'kernel32' name 'CancelIoEx';

{ winsock2 FFI }
{$I nextpas.core.platform.windows.ffi.winsock2.inc}

implementation

end.
