unit nextpas.core.platform.windows.base;

{$I nextpas.core.settings.inc}

interface

type
  DWORD = UInt32;
  BOOL = LongBool;
  HANDLE = Pointer;
  FARPROC = Pointer;
  HMODULE = HANDLE;
  LPCSTR = PAnsiChar;
  LPCWSTR = PWideChar;
  LPDWORD = ^DWORD;
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
  PLATFORM_WINDOWS_INVALID_HANDLE_VALUE = PtrInt(-1);
  PLATFORM_WINDOWS_MEM_COMMIT = DWORD($00001000);
  PLATFORM_WINDOWS_MEM_RESERVE = DWORD($00002000);
  PLATFORM_WINDOWS_MEM_DECOMMIT = DWORD($00004000);
  PLATFORM_WINDOWS_MEM_RELEASE = DWORD($00008000);
  PLATFORM_WINDOWS_PAGE_NOACCESS = DWORD($00000001);
  PLATFORM_WINDOWS_PAGE_READONLY = DWORD($00000002);
  PLATFORM_WINDOWS_PAGE_READWRITE = DWORD($00000004);
  PLATFORM_WINDOWS_PAGE_EXECUTE_READ = DWORD($00000020);
  PLATFORM_WINDOWS_PAGE_EXECUTE_READWRITE = DWORD($00000040);
  PLATFORM_WINDOWS_GENERIC_READ = DWORD($80000000);
  PLATFORM_WINDOWS_GENERIC_WRITE = DWORD($40000000);
  PLATFORM_WINDOWS_FILE_SHARE_READ = DWORD(1);
  PLATFORM_WINDOWS_FILE_SHARE_WRITE = DWORD(2);
  PLATFORM_WINDOWS_FILE_SHARE_DELETE = DWORD(4);
  PLATFORM_WINDOWS_CREATE_ALWAYS = DWORD(2);
  PLATFORM_WINDOWS_OPEN_EXISTING = DWORD(3);
  PLATFORM_WINDOWS_FILE_ATTRIBUTE_NORMAL = DWORD($80);
  WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS = UInt64(116444736000000000);
  WINDOWS_FILETIME_NANOSECONDS_PER_TICK = UInt64(100);
  PLATFORM_WINDOWS_MUTEX_SIZE = SizeOf(SRWLOCK);
  PLATFORM_WINDOWS_RWLOCK_SIZE = SizeOf(SRWLOCK);
  PLATFORM_WINDOWS_CONDVAR_SIZE = SizeOf(CONDITION_VARIABLE);

implementation

end.
