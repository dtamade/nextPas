unit nextpas.core.platform.windows.base;

{$I nextpas.core.settings.inc}

interface

type
  {** @desc 无符号 8 位整数 *}
  BYTE = UInt8;
  {** @desc 无符号 16 位整数 *}
  WORD = UInt16;
  {** @desc 无符号 32 位整数 *}
  UINT = UInt32;
  {** @desc 无符号 32 位整数 *}
  DWORD = UInt32;
  {** @desc 有符号 32 位整数 *}
  LONG = Int32;
  {** @desc 无符号 32 位整数 *}
  ULONG = UInt32;
  {** @desc 有符号 64 位整数 *}
  LONGLONG = Int64;
  {** @desc Windows 布尔类型 *}
  WINBOOL = LongBool;
  {** @desc 布尔类型 *}
  BOOL = WINBOOL;
  {** @desc Win32 BOOLEAN (1-byte). Do not confuse with BOOL/LongBool. *}
  WINDOWS_BOOLEAN = Byte;
  {** @desc 句柄类型（不透明指针） *}
  HANDLE = Pointer;
  PHANDLE = ^HANDLE;
  {** @desc 函数指针类型 *}
  FARPROC = Pointer;
  {** @desc 模块句柄类型 *}
  HMODULE = HANDLE;
  {** @desc void 指针类型 *}
  LPVOID = Pointer;
  {** @desc ANSI 字符串指针类型 *}
  LPCSTR = PAnsiChar;
  {** @desc 可修改 ANSI 字符串指针类型 *}
  LPSTR = PAnsiChar;
  {** @desc Unicode 字符串指针类型 *}
  LPCWSTR = PWideChar;
  {** @desc 可修改 Unicode 字符串指针类型 *}
  LPWSTR = PWideChar;
  {** @desc DWORD 指针类型 *}
  LPDWORD = ^DWORD;
  {** @desc LONG 指针类型 *}
  PLONG = ^LONG;
  {** @desc 64 位整数指针类型（alias System.PInt64; do not redeclare ^Int64
      or case-insensitive PInt64 shadows break public APIs that use PInt64) *}
  PINT64 = System.PInt64;
  {** @desc BYTE 指针类型 *}
  LPBYTE = ^BYTE;
  {** @desc LPSTR 指针类型 *}
  PLPSTR = ^LPSTR;
  {** @desc LPWSTR 指针类型 *}
  PLPWSTR = ^LPWSTR;
  {** @desc SRW 锁类型（轻量读写锁） *}
  SRWLOCK = Pointer;
  {** @desc 条件变量类型 *}
  CONDITION_VARIABLE = Pointer;
  {** @desc Windows 线程入口函数类型 *}
  TPlatformWindowsThreadProc = function(AArg: Pointer): Pointer; cdecl;
  {** @desc 控制台信号处理函数类型 *}
  TConsoleCtrlHandlerRoutine = function(dwCtrlType: DWORD): WINBOOL; stdcall;

  {** @desc 文件时间结构（100 纳秒精度） *}
  FILETIME = record
    dwLowDateTime: DWORD;
    dwHighDateTime: DWORD;
  end;

  {** @desc 64 位整数结构（高低双字或四字） *}
  LARGE_INTEGER = record
    case Byte of
      0: (
        LowPart: DWORD;
        HighPart: LONG);
      1: (
        QuadPart: LONGLONG);
  end;
  PLARGE_INTEGER = ^LARGE_INTEGER;

  {** @desc 文件属性信息级别枚举 *}
  GET_FILEEX_INFO_LEVELS = (
    GetFileExInfoStandard,
    GetFileExMaxInfoLevel
  );
  PGET_FILEEX_INFO_LEVELS = ^GET_FILEEX_INFO_LEVELS;

  {** @desc 文件属性数据结构 *}
  WIN32_FILE_ATTRIBUTE_DATA = packed record
    dwFileAttributes: DWORD;
    ftCreationTime: FILETIME;
    ftLastAccessTime: FILETIME;
    ftLastWriteTime: FILETIME;
    nFileSizeHigh: DWORD;
    nFileSizeLow: DWORD;
  end;
  PWIN32_FILE_ATTRIBUTE_DATA = ^WIN32_FILE_ATTRIBUTE_DATA;

  {** @desc 文件句柄信息结构 *}
  BY_HANDLE_FILE_INFORMATION = record
    dwFileAttributes: DWORD;
    ftCreationTime: FILETIME;
    ftLastAccessTime: FILETIME;
    ftLastWriteTime: FILETIME;
    dwVolumeSerialNumber: DWORD;
    nFileSizeHigh: DWORD;
    nFileSizeLow: DWORD;
    nNumberOfLinks: DWORD;
    nFileIndexHigh: DWORD;
    nFileIndexLow: DWORD;
  end;
  PBY_HANDLE_FILE_INFORMATION = ^BY_HANDLE_FILE_INFORMATION;

  SECURITY_ATTRIBUTES = record
    nLength: DWORD;
    lpSecurityDescriptor: LPVOID;
    bInheritHandle: WINBOOL;
  end;
  LPSECURITY_ATTRIBUTES = ^SECURITY_ATTRIBUTES;

  PROCESS_INFORMATION = record
    hProcess: HANDLE;
    hThread: HANDLE;
    dwProcessId: DWORD;
    dwThreadId: DWORD;
  end;
  LPPROCESS_INFORMATION = ^PROCESS_INFORMATION;

  STARTUPINFOA = record
    cb: DWORD;
    lpReserved: LPSTR;
    lpDesktop: LPSTR;
    lpTitle: LPSTR;
    dwX: DWORD;
    dwY: DWORD;
    dwXSize: DWORD;
    dwYSize: DWORD;
    dwXCountChars: DWORD;
    dwYCountChars: DWORD;
    dwFillAttribute: DWORD;
    dwFlags: DWORD;
    wShowWindow: WORD;
    cbReserved2: WORD;
    lpReserved2: LPBYTE;
    hStdInput: HANDLE;
    hStdOutput: HANDLE;
    hStdError: HANDLE;
  end;
  LPSTARTUPINFOA = ^STARTUPINFOA;

  STARTUPINFOW = record
    cb: DWORD;
    lpReserved: LPWSTR;
    lpDesktop: LPWSTR;
    lpTitle: LPWSTR;
    dwX: DWORD;
    dwY: DWORD;
    dwXSize: DWORD;
    dwYSize: DWORD;
    dwXCountChars: DWORD;
    dwYCountChars: DWORD;
    dwFillAttribute: DWORD;
    dwFlags: DWORD;
    wShowWindow: WORD;
    cbReserved2: WORD;
    lpReserved2: LPBYTE;
    hStdInput: HANDLE;
    hStdOutput: HANDLE;
    hStdError: HANDLE;
  end;
  LPSTARTUPINFOW = ^STARTUPINFOW;

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

  MEMORY_BASIC_INFORMATION = record
    BaseAddress: Pointer;
    AllocationBase: Pointer;
    AllocationProtect: DWORD;
    PartitionId: WORD;
    RegionSize: PtrUInt;
    State: DWORD;
    Protect: DWORD;
    Type_: DWORD;
  end;
  PMEMORY_BASIC_INFORMATION = ^MEMORY_BASIC_INFORMATION;

  TWinThreadStartRoutine = function(lpThreadParameter: Pointer): DWORD; stdcall;
  TFlsCallbackFunction = procedure(lpFlsData: Pointer); stdcall;
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

  {** @desc 矩形区域 (Windows RECT / tagRECT) — host owner single source.
         ABI: left,top,right,bottom 4×LONG (16B)，与 Win32 SDK 二进制一致。
         window.win32.ffi 与 webview.webview2.ffi 均复用此定义，禁止各家重定义。
         性能：纯值类型 16B 栈上传参，inline 零拷贝，无堆分配。 *}
  tagRECT = record Left, Top, Right, Bottom: LONG; end;
  RECT = tagRECT;
  PRECT = ^RECT;
  PRect = ^RECT;
  TRect = tagRECT;

const
  INFINITE = DWORD($FFFFFFFF);
  WAIT_OBJECT_0 = DWORD(0);
  WAIT_ABANDONED_0 = DWORD($80);
  WAIT_TIMEOUT = DWORD($102);
  WAIT_IO_COMPLETION = DWORD($C0);
  WAIT_ABANDONED = DWORD($80);
  WAIT_FAILED = DWORD($FFFFFFFF);
  STILL_ACTIVE = DWORD($103);
  ERROR_TIMEOUT = DWORD(1460);
  TLS_OUT_OF_INDEXES = DWORD($FFFFFFFF);
  FLS_OUT_OF_INDEXES = DWORD($FFFFFFFF);
  DUPLICATE_CLOSE_SOURCE = DWORD(1);
  SYNCHRONIZE = DWORD($100000);
  PROCESS_TERMINATE = DWORD($0001);
  FILE_BEGIN = DWORD(0);
  FILE_CURRENT = DWORD(1);
  FILE_END = DWORD(2);
  INVALID_SET_FILE_POINTER = DWORD($FFFFFFFF);
  INVALID_HANDLE_VALUE = PtrInt(-1);
  MEM_COMMIT = DWORD($00001000);
  MEM_RESERVE = DWORD($00002000);
  MEM_DECOMMIT = DWORD($00004000);
  MEM_RELEASE = DWORD($00008000);
  PAGE_NOACCESS = DWORD($00000001);
  GENERIC_READ = DWORD($80000000);
  GENERIC_WRITE = DWORD($40000000);
  FILE_SHARE_READ = DWORD(1);
  FILE_SHARE_WRITE = DWORD(2);
  FILE_SHARE_DELETE = DWORD(4);
  { Directory open access for ReadDirectoryChangesW (flags live in kernel32.inc). }
  FILE_LIST_DIRECTORY = DWORD($0001);
  FILE_NOTIFY_CHANGE_FILE_NAME = DWORD($00000001);
  FILE_NOTIFY_CHANGE_DIR_NAME = DWORD($00000002);
  FILE_NOTIFY_CHANGE_ATTRIBUTES = DWORD($00000004);
  FILE_NOTIFY_CHANGE_SIZE = DWORD($00000008);
  FILE_NOTIFY_CHANGE_LAST_WRITE = DWORD($00000010);
  FILE_ACTION_ADDED = DWORD(1);
  FILE_ACTION_REMOVED = DWORD(2);
  FILE_ACTION_MODIFIED = DWORD(3);
  FILE_ACTION_RENAMED_OLD_NAME = DWORD(4);
  FILE_ACTION_RENAMED_NEW_NAME = DWORD(5);
  CREATE_ALWAYS = DWORD(2);
  OPEN_EXISTING = DWORD(3);
  OPEN_ALWAYS = DWORD(4);
  TRUNCATE_EXISTING = DWORD(5);
  DEBUG_PROCESS = DWORD(1);
  DEBUG_ONLY_THIS_PROCESS = DWORD(2);
  CREATE_SUSPENDED = DWORD(4);
  DETACHED_PROCESS = DWORD(8);
  CREATE_NEW_CONSOLE = DWORD(16);
  NORMAL_PRIORITY_CLASS = DWORD(32);
  IDLE_PRIORITY_CLASS = DWORD(64);
  HIGH_PRIORITY_CLASS = DWORD(128);
  REALTIME_PRIORITY_CLASS = DWORD(256);
  CREATE_NEW_PROCESS_GROUP = DWORD(512);
  CREATE_UNICODE_ENVIRONMENT = DWORD($00000400);
  CREATE_SEPARATE_WOW_VDM = DWORD($00000800);
  CREATE_SHARED_WOW_VDM = DWORD($00001000);
  CREATE_FORCEDOS = DWORD($00002000);
  BELOW_NORMAL_PRIORITY_CLASS = DWORD($00004000);
  ABOVE_NORMAL_PRIORITY_CLASS = DWORD($00008000);
  STACK_SIZE_PARAM_IS_A_RESERVATION = DWORD($00010000);
  FILE_ATTRIBUTE_READONLY = DWORD($00000001);
  FILE_ATTRIBUTE_HIDDEN = DWORD($00000002);
  FILE_ATTRIBUTE_SYSTEM = DWORD($00000004);
  FILE_ATTRIBUTE_DIRECTORY = DWORD($00000010);
  FILE_ATTRIBUTE_ARCHIVE = DWORD($00000020);
  FILE_ATTRIBUTE_DEVICE = DWORD($00000040);
  FILE_ATTRIBUTE_NORMAL = DWORD($80);
  FILE_ATTRIBUTE_TEMPORARY = DWORD($00000100);
  FILE_ATTRIBUTE_SPARSE_FILE = DWORD($00000200);
  FILE_ATTRIBUTE_REPARSE_POINT = DWORD($00000400);
  FILE_ATTRIBUTE_COMPRESSED = DWORD($00000800);
  FILE_ATTRIBUTE_OFFLINE = DWORD($00001000);
  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = DWORD($00002000);
  FILE_ATTRIBUTE_ENCRYPTED = DWORD($00004000);
  FILE_ATTRIBUTE_INTEGRITY_STREAM = DWORD($00008000);
  FILE_ATTRIBUTE_VIRTUAL = DWORD($00010000);
  FILE_ATTRIBUTE_NO_SCRUB_DATA = DWORD($00020000);
  FILE_ATTRIBUTE_EA = DWORD($00040000);
  FILE_ATTRIBUTE_PINNED = DWORD($00080000);
  FILE_ATTRIBUTE_UNPINNED = DWORD($00100000);
  FILE_ATTRIBUTE_RECALL_ON_OPEN = DWORD($00040000);
  FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = DWORD($00400000);
  WINDOWS_FILETIME_UNIX_EPOCH_OFFSET_100NS = UInt64(116444736000000000);
  WINDOWS_FILETIME_NANOSECONDS_PER_TICK = UInt64(100);
  WINDOWS_MUTEX_SIZE = SizeOf(SRWLOCK);
  WINDOWS_RWLOCK_SIZE = SizeOf(SRWLOCK);
  WINDOWS_CONDVAR_SIZE = SizeOf(CONDITION_VARIABLE);
  CP_UTF8 = UINT(65001);
  MB_ERR_INVALID_CHARS = DWORD($00000008);
  WC_ERR_INVALID_CHARS = DWORD($00000080);
  CTRL_C_EVENT = DWORD(0);
  CTRL_BREAK_EVENT = DWORD(1);
  ERROR_NOT_SUPPORTED = DWORD(50);

  { Virtual memory allocation types }
  WINDOWS_MEM_COMMIT  = DWORD($00001000);
  WINDOWS_MEM_RESERVE = DWORD($00002000);
  WINDOWS_MEM_DECOMMIT = DWORD($00004000);
  WINDOWS_MEM_RELEASE = DWORD($00008000);
  WINDOWS_PAGE_READWRITE = DWORD($00000004);

{ additional kernel32 types, error codes, and constants }
{$I nextpas.core.platform.windows.base.kernel32.inc}

{ winsock2 types and constants }
{$I nextpas.core.platform.windows.base.winsock2.inc}

{ advapi32 types and constants }
{$I nextpas.core.platform.windows.base.advapi32.inc}

implementation

end.
