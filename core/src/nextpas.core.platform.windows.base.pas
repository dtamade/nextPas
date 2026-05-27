unit nextpas.core.platform.windows.base;

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

implementation

end.
