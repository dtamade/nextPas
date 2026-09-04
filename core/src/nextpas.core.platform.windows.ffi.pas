unit nextpas.core.platform.windows.ffi;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.platform.windows.base;


{ Thread / Process }

{** @desc 创建线程
    @param lpThreadAttributes 安全属性
    @param dwStackSize 栈大小
    @param lpStartAddress 线程入口函数
    @param lpParameter 传递给线程的参数
    @param dwCreationFlags 创建标志
    @param lpThreadId 输出线程 ID
    @return 线程句柄，NULL 失败 *}
function CreateThread(lpThreadAttributes: Pointer; dwStackSize: PtrUInt; lpStartAddress: TWinThreadStartRoutine; lpParameter: Pointer; dwCreationFlags: DWORD; lpThreadId: Pointer): HANDLE; stdcall; external 'kernel32' name 'CreateThread';

{** @desc 等待对象（线程/进程/事件等）
    @param hHandle 对象句柄
    @param dwMilliseconds 超时毫秒数（INFINITE 无限等待）
    @return WAIT_OBJECT_0 成功，WAIT_TIMEOUT 超时 *}
function WaitForSingleObject(hHandle: HANDLE; dwMilliseconds: DWORD): DWORD; stdcall; external 'kernel32' name 'WaitForSingleObject';

{** @desc 等待多个对象
    @return WAIT_OBJECT_0+i 或 WAIT_TIMEOUT *}
function WaitForMultipleObjects(nCount: DWORD; lpHandles: PHANDLE;
  bWaitAll: WINBOOL; dwMilliseconds: DWORD): DWORD; stdcall;
  external 'kernel32' name 'WaitForMultipleObjects';

function ResetEvent(hEvent: HANDLE): WINBOOL; stdcall;
  external 'kernel32' name 'ResetEvent';

{** @desc 关闭句柄
    @param hObject 句柄
    @return TRUE 成功 *}
function CloseHandle(hObject: HANDLE): BOOL; stdcall; external 'kernel32' name 'CloseHandle';

{** @desc 获取当前进程 ID
    @return 进程 ID *}
function GetCurrentProcessId: DWORD; stdcall; external 'kernel32' name 'GetCurrentProcessId';

{** @desc 获取当前线程 ID
    @return 线程 ID *}
function GetCurrentThreadId: DWORD; stdcall; external 'kernel32' name 'GetCurrentThreadId';

{** @desc 获取当前线程句柄（伪句柄） *}
function GetCurrentThread: HANDLE; stdcall; external 'kernel32' name 'GetCurrentThread';

{** @desc 获取当前处理器编号 *}
function GetCurrentProcessorNumber: DWORD; stdcall; external 'kernel32' name 'GetCurrentProcessorNumber';

{ NUMA }

function GetNumaHighestNodeNumber(var HighestNodeNumber: DWORD): WINBOOL; stdcall; external 'kernel32' name 'GetNumaHighestNodeNumber';
function GetNumaProcessorNode(Processor: BYTE; var NodeNumber: BYTE): WINBOOL; stdcall; external 'kernel32' name 'GetNumaProcessorNode';
function GetNumaNodeProcessorMask(Node: DWORD; var ProcessorMask: UInt64): WINBOOL; stdcall; external 'kernel32' name 'GetNumaNodeProcessorMask';
function VirtualAllocExNuma(hProcess: HANDLE; lpAddress: Pointer; dwSize: PtrUInt; flAllocationType: DWORD; flProtect: DWORD; nndPreferred: DWORD): Pointer; stdcall; external 'kernel32' name 'VirtualAllocExNuma';
function VirtualFreeEx(hProcess: HANDLE; lpAddress: Pointer; dwSize: PtrUInt; dwFreeType: DWORD): WINBOOL; stdcall; external 'kernel32' name 'VirtualFreeEx';
function SetThreadAffinityMask(hThread: HANDLE; dwThreadAffinityMask: UInt64): UInt64; stdcall; external 'kernel32' name 'SetThreadAffinityMask';

{ Performance counters }

{** @desc 获取性能计数器频率
    @param lpFrequency 输出频率
    @return TRUE 成功 *}
function QueryPerformanceFrequency(var lpFrequency: Int64): BOOL; stdcall; external 'kernel32' name 'QueryPerformanceFrequency';

{** @desc 获取性能计数器值
    @param lpPerformanceCount 输出计数器值
    @return TRUE 成功 *}
function QueryPerformanceCounter(var lpPerformanceCount: Int64): BOOL; stdcall; external 'kernel32' name 'QueryPerformanceCounter';

{ Time }

{** @desc 获取系统时间（FILETIME 格式）
    @param lpSystemTimeAsFileTime 输出 FILETIME *}
procedure GetSystemTimeAsFileTime(var lpSystemTimeAsFileTime: FILETIME); stdcall; external 'kernel32' name 'GetSystemTimeAsFileTime';

{** @desc 获取时区信息
    @param lpTimeZoneInformation 输出时区信息
    @return 时区状态 *}
function GetTimeZoneInformation(var lpTimeZoneInformation): DWORD; stdcall; external 'kernel32' name 'GetTimeZoneInformation';

{ Scheduler }

{** @desc 让出 CPU 时间片
    @return TRUE 成功 *}
function SwitchToThread: BOOL; stdcall; external 'kernel32' name 'SwitchToThread';

{** @desc 线程休眠
    @param dwMilliseconds 休眠毫秒数 *}
procedure Sleep(dwMilliseconds: DWORD); stdcall; external 'kernel32' name 'Sleep';

{ Error }

{** @desc 获取最后错误码
    @return 错误码 *}
function GetLastError: DWORD; stdcall; external 'kernel32' name 'GetLastError';

{** @desc 设置错误码
    @param dwErrCode 错误码 *}
procedure SetLastError(dwErrCode: DWORD); stdcall; external 'kernel32' name 'SetLastError';

{ System }

{** @desc 获取系统信息
    @param lpSystemInfo 输出系统信息 *}
procedure GetSystemInfo(var lpSystemInfo: SYSTEM_INFO); stdcall; external 'kernel32' name 'GetSystemInfo';

{ Version }

{** @desc Windows 版本信息（GetVersionEx 输入输出；字段布局与 Win32 API 一致） *}
type
  POSVERSIONINFO = ^OSVERSIONINFO;
  OSVERSIONINFO = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of AnsiChar;
  end;

{** @desc 获取 Windows 版本信息（kernel32）
    @param lpVersionInformation 版本信息（调用前置 dwOSVersionInfoSize）
    @return 非零成功 *}
function GetVersionEx(var lpVersionInformation: OSVERSIONINFO): BOOL; stdcall; external 'kernel32' name 'GetVersionExA';

{ TLS (Thread Local Storage) }

{** @desc 分配 TLS 索引
    @return TLS 索引，TLS_OUT_OF_INDEXES 失败 *}
function TlsAlloc: DWORD; stdcall; external 'kernel32' name 'TlsAlloc';

{** @desc 释放 TLS 索引
    @param dwTlsIndex TLS 索引
    @return TRUE 成功 *}
function TlsFree(dwTlsIndex: DWORD): BOOL; stdcall; external 'kernel32' name 'TlsFree';

{** @desc 设置 TLS 值
    @param dwTlsIndex TLS 索引
    @param lpTlsValue 值
    @return TRUE 成功 *}
function TlsSetValue(dwTlsIndex: DWORD; lpTlsValue: Pointer): BOOL; stdcall; external 'kernel32' name 'TlsSetValue';

{** @desc 获取 TLS 值
    @param dwTlsIndex TLS 索引
    @return 值指针 *}
function TlsGetValue(dwTlsIndex: DWORD): Pointer; stdcall; external 'kernel32' name 'TlsGetValue';

{ FLS (Fiber Local Storage) - supports per-thread destructor callback }

{** @desc 分配 FLS 索引（支持析构回调）
    @param lpCallback 析构回调函数（线程退出时调用）
    @return FLS 索引，FLS_OUT_OF_INDEXES 失败 *}
function FlsAlloc(lpCallback: TFlsCallbackFunction): DWORD; stdcall; external 'kernel32' name 'FlsAlloc';

{** @desc 释放 FLS 索引
    @param dwFlsIndex FLS 索引
    @return TRUE 成功 *}
function FlsFree(dwFlsIndex: DWORD): BOOL; stdcall; external 'kernel32' name 'FlsFree';

{** @desc 设置 FLS 值
    @param dwFlsIndex FLS 索引
    @param lpFlsValue 值
    @return TRUE 成功 *}
function FlsSetValue(dwFlsIndex: DWORD; lpFlsValue: Pointer): BOOL; stdcall; external 'kernel32' name 'FlsSetValue';

{** @desc 获取 FLS 值
    @param dwFlsIndex FLS 索引
    @return 值指针 *}
function FlsGetValue(dwFlsIndex: DWORD): Pointer; stdcall; external 'kernel32' name 'FlsGetValue';

{ InterlockedDecrement/Increment are provided by FPC's System unit as
  compiler intrinsics (FPC_INTERLOCKEDDECREMENT etc.). Declaring them
  from kernel32 breaks Wine compatibility since Wine doesn't export
  these functions from kernel32.dll. }

{ SRWLock (Slim Reader/Writer Lock) }

{** @desc 初始化 SRW 锁
    @param SRWLock SRW 锁指针 *}
procedure InitializeSRWLock(SRWLock: Pointer); stdcall; external 'kernel32' name 'InitializeSRWLock';

{** @desc 获取 SRW 排他锁
    @param SRWLock SRW 锁指针 *}
procedure AcquireSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockExclusive';

{** @desc 尝试获取 SRW 排他锁
    @param SRWLock SRW 锁指针
    @return non-zero on success (Win32 BOOLEAN, 1-byte — not BOOL/LongBool) *}
function TryAcquireSRWLockExclusive(SRWLock: Pointer): WINDOWS_BOOLEAN; stdcall; external 'kernel32' name 'TryAcquireSRWLockExclusive';

{** @desc 释放 SRW 排他锁
    @param SRWLock SRW 锁指针 *}
procedure ReleaseSRWLockExclusive(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockExclusive';

{** @desc 获取 SRW 共享锁
    @param SRWLock SRW 锁指针 *}
procedure AcquireSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'AcquireSRWLockShared';

{** @desc 尝试获取 SRW 共享锁
    @param SRWLock SRW 锁指针
    @return non-zero on success (Win32 BOOLEAN, 1-byte — not BOOL/LongBool) *}
function TryAcquireSRWLockShared(SRWLock: Pointer): WINDOWS_BOOLEAN; stdcall; external 'kernel32' name 'TryAcquireSRWLockShared';

{** @desc 释放 SRW 共享锁
    @param SRWLock SRW 锁指针 *}
procedure ReleaseSRWLockShared(SRWLock: Pointer); stdcall; external 'kernel32' name 'ReleaseSRWLockShared';

{ Condition Variable }

{** @desc 初始化条件变量
    @param ConditionVariable 条件变量指针 *}
procedure InitializeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'InitializeConditionVariable';

{** @desc 等待条件变量（SRW 锁）
    @param ConditionVariable 条件变量指针
    @param SRWLock SRW 锁指针
    @param dwMilliseconds 超时毫秒数
    @param Flags 标志
    @return TRUE 成功 *}
function SleepConditionVariableSRW(ConditionVariable: Pointer; SRWLock: Pointer; dwMilliseconds: DWORD; Flags: DWORD): BOOL; stdcall; external 'kernel32' name 'SleepConditionVariableSRW';

{** @desc 唤醒一个等待线程
    @param ConditionVariable 条件变量指针 *}
procedure WakeConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeConditionVariable';

{** @desc 唤醒所有等待线程
    @param ConditionVariable 条件变量指针 *}
procedure WakeAllConditionVariable(ConditionVariable: Pointer); stdcall; external 'kernel32' name 'WakeAllConditionVariable';

{ Address wait (futex-like) }

{** @desc 等待地址值变化
    @param Address 监视的地址
    @param CompareAddress 比较地址
    @param AddressSize 地址大小
    @param dwMilliseconds 超时毫秒数
    @return TRUE 成功 *}
function WaitOnAddress(Address: Pointer; CompareAddress: Pointer; AddressSize: PtrUInt; dwMilliseconds: DWORD): BOOL; stdcall; external 'kernel32' name 'WaitOnAddress';

{** @desc 唤醒一个等待地址的线程
    @param Address 监视的地址 *}
procedure WakeByAddressSingle(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressSingle';

{** @desc 唤醒所有等待地址的线程
    @param Address 监视的地址 *}
procedure WakeByAddressAll(Address: Pointer); stdcall; external 'kernel32' name 'WakeByAddressAll';

{ Dynamic linking }

{** @desc 加载动态库（ANSI）
    @param lpLibFileName 库文件路径
    @return 库句柄，NULL 失败 *}
function LoadLibraryA(lpLibFileName: PAnsiChar): HMODULE; stdcall; external 'kernel32' name 'LoadLibraryA';

{** @desc 加载动态库（Unicode）
    @param lpLibFileName 库文件路径
    @return 库句柄，NULL 失败 *}
function LoadLibraryW(lpLibFileName: PWideChar): HMODULE; stdcall; external 'kernel32' name 'LoadLibraryW';

{** @desc 获取模块句柄
    @param lpModuleName 模块名称（nil 获取自身）
    @return 模块句柄 *}
function GetModuleHandleW(lpModuleName: PWideChar): HMODULE; stdcall; external 'kernel32' name 'GetModuleHandleW';

{** @desc 获取函数地址
    @param hModule 模块句柄
    @param lpProcName 函数名称
    @return 函数地址，NULL 失败 *}
function GetProcAddress(hModule: HMODULE; lpProcName: PAnsiChar): FARPROC; stdcall; external 'kernel32' name 'GetProcAddress';

{** @desc 释放动态库
    @param hLibModule 库句柄
    @return TRUE 成功 *}
function FreeLibrary(hLibModule: HMODULE): BOOL; stdcall; external 'kernel32' name 'FreeLibrary';

{ Virtual memory }

{** @desc 分配虚拟内存
    @param lpAddress 期望地址（nil 由系统选择）
    @param dwSize 分配大小
    @param flAllocationType 分配类型（MEM_COMMIT/RESERVE）
    @param flProtect 保护标志（PAGE_READWRITE 等）
    @return 分配的地址，NULL 失败 *}
function VirtualAlloc(lpAddress: Pointer; dwSize: PtrUInt; flAllocationType: DWORD; flProtect: DWORD): Pointer; stdcall; external 'kernel32' name 'VirtualAlloc';

{** @desc 释放虚拟内存
    @param lpAddress 内存地址
    @param dwSize 释放大小
    @param dwFreeType 释放类型（MEM_DECOMMIT/RELEASE）
    @return TRUE 成功 *}
function VirtualFree(lpAddress: Pointer; dwSize: PtrUInt; dwFreeType: DWORD): BOOL; stdcall; external 'kernel32' name 'VirtualFree';

{** @desc 修改内存保护
    @param lpAddress 内存地址
    @param dwSize 大小
    @param flNewProtect 新保护标志
    @param lpflOldProtect 输出旧保护标志
    @return TRUE 成功 *}
function VirtualProtect(lpAddress: Pointer; dwSize: PtrUInt; flNewProtect: DWORD; var lpflOldProtect: DWORD): BOOL; stdcall; external 'kernel32' name 'VirtualProtect';

{** @desc 锁定内存页
    @param lpAddress 内存地址
    @param dwSize 大小
    @return TRUE 成功 *}
function VirtualLock(lpAddress: Pointer; dwSize: PtrUInt): BOOL; stdcall; external 'kernel32' name 'VirtualLock';

{** @desc 解锁内存页
    @param lpAddress 内存地址
    @param dwSize 大小
    @return TRUE 成功 *}
function VirtualUnlock(lpAddress: Pointer; dwSize: PtrUInt): BOOL; stdcall; external 'kernel32' name 'VirtualUnlock';

{** @desc 查询内存信息
    @param lpAddress 内存地址
    @param lpBuffer 输出内存信息
    @param dwLength 缓冲区大小
    @return 返回字节数 *}
function VirtualQuery(lpAddress: Pointer; lpBuffer: PMEMORY_BASIC_INFORMATION; dwLength: PtrUInt): PtrUInt; stdcall; external 'kernel32' name 'VirtualQuery';
{ File I/O }

{** @desc 创建/打开文件（ANSI）
    @param lpFileName 文件路径
    @param dwDesiredAccess 访问模式（GENERIC_READ/WRITE）
    @param dwShareMode 共享模式
    @param lpSecurityAttributes 安全属性
    @param dwCreationDisposition 创建方式（CREATE_NEW/OPEN_EXISTING 等）
    @param dwFlagsAndAttributes 标志和属性
    @param hTemplateFile 模板文件
    @return 文件句柄，INVALID_HANDLE_VALUE 失败 *}
function CreateFileA(lpFileName: LPCSTR; dwDesiredAccess: DWORD; dwShareMode: DWORD; lpSecurityAttributes: Pointer; dwCreationDisposition: DWORD; dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE; stdcall; external 'kernel32' name 'CreateFileA';

{** @desc 创建/打开文件（Unicode）
    @param lpFileName 文件路径
    @param dwDesiredAccess 访问模式
    @param dwShareMode 共享模式
    @param lpSecurityAttributes 安全属性
    @param dwCreationDisposition 创建方式
    @param dwFlagsAndAttributes 标志和属性
    @param hTemplateFile 模板文件
    @return 文件句柄，INVALID_HANDLE_VALUE 失败 *}
function CreateFileW(lpFileName: LPCWSTR; dwDesiredAccess: DWORD; dwShareMode: DWORD; lpSecurityAttributes: Pointer; dwCreationDisposition: DWORD; dwFlagsAndAttributes: DWORD; hTemplateFile: HANDLE): HANDLE; stdcall; external 'kernel32' name 'CreateFileW';

{** @desc 读取文件
    @param hFile 文件句柄
    @param lpBuffer 输出缓冲区
    @param nNumberOfBytesToRead 读取字节数
    @param lpNumberOfBytesRead 实际读取字节数
    @param lpOverlapped 异步结构
    @return TRUE 成功 *}
function ReadFile(hFile: HANDLE; lpBuffer: Pointer; nNumberOfBytesToRead: DWORD; lpNumberOfBytesRead: LPDWORD; lpOverlapped: LPOVERLAPPED): BOOL; stdcall; external 'kernel32' name 'ReadFile';

{** @desc 写入文件
    @param hFile 文件句柄
    @param lpBuffer 数据缓冲区
    @param nNumberOfBytesToWrite 写入字节数
    @param lpNumberOfBytesWritten 实际写入字节数
    @param lpOverlapped 异步结构
    @return TRUE 成功 *}
function WriteFile(hFile: HANDLE; lpBuffer: Pointer; nNumberOfBytesToWrite: DWORD; lpNumberOfBytesWritten: LPDWORD; lpOverlapped: LPOVERLAPPED): BOOL; stdcall; external 'kernel32' name 'WriteFile';

{** @desc 获取文件大小
    @param hFile 文件句柄
    @param lpFileSizeHigh 输出高 32 位
    @return 低 32 位大小 *}
function GetFileSize(hFile: HANDLE; lpFileSizeHigh: LPDWORD): DWORD; stdcall; external 'kernel32' name 'GetFileSize';

{** @desc 刷新文件缓冲区
    @param hFile 文件句柄
    @return TRUE 成功 *}
function FlushFileBuffers(hFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'FlushFileBuffers';

{** @desc 设置文件结束位置
    @param hFile 文件句柄
    @return TRUE 成功 *}
function SetEndOfFile(hFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'SetEndOfFile';

{** @desc 移动文件指针
    @param hFile 文件句柄
    @param lDistanceToMove 偏移量低 32 位
    @param lpDistanceToMoveHigh 偏移量高 32 位
    @param dwMoveMethod 起点（FILE_BEGIN/CURRENT/END）
    @return 新位置低 32 位 *}
function SetFilePointer(hFile: HANDLE; lDistanceToMove: LONG; lpDistanceToMoveHigh: PLONG; dwMoveMethod: DWORD): DWORD; stdcall; external 'kernel32' name 'SetFilePointer';

{** @desc 获取文件大小（64 位）
    @param InFileHandle 文件句柄
    @param OutFileSize 输出大小
    @return TRUE 成功 *}
function GetFileSizeEx(InFileHandle: HANDLE; OutFileSize: PINT64): BOOL; stdcall; external 'kernel32' name 'GetFileSizeEx';

{** @desc 移动文件指针（64 位）
    @param InFile 文件句柄
    @param InDistanceToMove 偏移量
    @param OutoptNewFilePointer 输出新位置
    @param InMoveMethod 起点
    @return TRUE 成功 *}
function SetFilePointerEx(InFile: HANDLE; InDistanceToMove: Int64; OutoptNewFilePointer: PINT64; InMoveMethod: DWORD): BOOL; stdcall; external 'kernel32' name 'SetFilePointerEx';

{ File attributes }

{** @desc 获取文件属性（ANSI）
    @param lpFileName 文件路径
    @param fInfoLevelId 信息级别
    @param lpFileInformation 输出信息
    @return TRUE 成功 *}
function GetFileAttributesExA(lpFileName: LPCSTR; fInfoLevelId: GET_FILEEX_INFO_LEVELS; lpFileInformation: Pointer): BOOL; stdcall; external 'kernel32' name 'GetFileAttributesExA';

{** @desc 设置文件属性（ANSI）
    @param lpFileName 文件路径
    @param dwFileAttributes 属性
    @return TRUE 成功 *}
function SetFileAttributesA(lpFileName: LPCSTR; dwFileAttributes: DWORD): BOOL; stdcall; external 'kernel32' name 'SetFileAttributesA';

{** @desc 获取文件属性（Unicode）
    @param lpFileName 文件路径
    @param fInfoLevelId 信息级别
    @param lpFileInformation 输出信息
    @return TRUE 成功 *}
function GetFileAttributesExW(lpFileName: LPCWSTR; fInfoLevelId: GET_FILEEX_INFO_LEVELS; lpFileInformation: Pointer): BOOL; stdcall; external 'kernel32' name 'GetFileAttributesExW';

{** @desc 设置文件属性（Unicode）
    @param lpFileName 文件路径
    @param dwFileAttributes 属性
    @return TRUE 成功 *}
function SetFileAttributesW(lpFileName: LPCWSTR; dwFileAttributes: DWORD): BOOL; stdcall; external 'kernel32' name 'SetFileAttributesW';

{** @desc 获取文件信息（通过句柄）
    @param hFile 文件句柄
    @param lpFileInformation 输出信息
    @return TRUE 成功 *}
function GetFileInformationByHandle(hFile: HANDLE; lpFileInformation: PBY_HANDLE_FILE_INFORMATION): BOOL; stdcall; external 'kernel32' name 'GetFileInformationByHandle';

{ Directory }

{** @desc 创建目录（ANSI）
    @param lpPathName 路径
    @param lpSecurityAttributes 安全属性
    @return TRUE 成功 *}
function CreateDirectoryA(lpPathName: LPCSTR; lpSecurityAttributes: Pointer): BOOL; stdcall; external 'kernel32' name 'CreateDirectoryA';

{** @desc 创建目录（Unicode）
    @param lpPathName 路径
    @param lpSecurityAttributes 安全属性
    @return TRUE 成功 *}
function CreateDirectoryW(lpPathName: LPCWSTR; lpSecurityAttributes: Pointer): BOOL; stdcall; external 'kernel32' name 'CreateDirectoryW';

{** @desc 删除目录（ANSI）
    @param lpPathName 路径
    @return TRUE 成功 *}
function RemoveDirectoryA(lpPathName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'RemoveDirectoryA';

{** @desc 删除目录（Unicode）
    @param lpPathName 路径
    @return TRUE 成功 *}
function RemoveDirectoryW(lpPathName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'RemoveDirectoryW';

{ File operations }

{** @desc 删除文件（ANSI）
    @param lpFileName 文件路径
    @return TRUE 成功 *}
function DeleteFileA(lpFileName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'DeleteFileA';

{** @desc 删除文件（Unicode）
    @param lpFileName 文件路径
    @return TRUE 成功 *}
function DeleteFileW(lpFileName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'DeleteFileW';

{** @desc 移动文件（ANSI）
    @param lpExistingFileName 现有路径
    @param lpNewFileName 新路径
    @return TRUE 成功 *}
function MoveFileA(lpExistingFileName: LPCSTR; lpNewFileName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'MoveFileA';

{** @desc 移动文件（Unicode）
    @param lpExistingFileName 现有路径
    @param lpNewFileName 新路径
    @return TRUE 成功 *}
function MoveFileW(lpExistingFileName: LPCWSTR; lpNewFileName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'MoveFileW';

{** @desc 移动文件（Unicode，可覆盖已存在目标）
    @param lpExistingFileName 现有路径
    @param lpNewFileName 新路径
    @param dwFlags MOVEFILE_* 标志（如 MOVEFILE_REPLACE_EXISTING）
    @return TRUE 成功 *}
function MoveFileExW(lpExistingFileName: LPCWSTR; lpNewFileName: LPCWSTR;
  dwFlags: DWORD): BOOL; stdcall; external 'kernel32' name 'MoveFileExW';

{ Working directory }

{** @desc 获取当前目录（ANSI）
    @param nBufferLength 缓冲区大小
    @param lpBuffer 输出缓冲区
    @return 路径长度 *}
function GetCurrentDirectoryA(nBufferLength: DWORD; lpBuffer: LPSTR): DWORD; stdcall; external 'kernel32' name 'GetCurrentDirectoryA';

{** @desc 获取当前目录（Unicode）
    @param nBufferLength 缓冲区大小
    @param lpBuffer 输出缓冲区
    @return 路径长度 *}
function GetCurrentDirectoryW(nBufferLength: DWORD; lpBuffer: LPWSTR): DWORD; stdcall; external 'kernel32' name 'GetCurrentDirectoryW';

{** @desc 设置当前目录（ANSI）
    @param lpPathName 路径
    @return TRUE 成功 *}
function SetCurrentDirectoryA(lpPathName: LPCSTR): BOOL; stdcall; external 'kernel32' name 'SetCurrentDirectoryA';

{** @desc 设置当前目录（Unicode）
    @param lpPathName 路径
    @return TRUE 成功 *}
function SetCurrentDirectoryW(lpPathName: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'SetCurrentDirectoryW';

{** @desc 获取完整路径（ANSI）
    @param lpFileName 文件名
    @param nBufferLength 缓冲区大小
    @param lpBuffer 输出缓冲区
    @param lpFilePart 输出文件名部分
    @return 路径长度 *}
function GetFullPathNameA(lpFileName: LPCSTR; nBufferLength: DWORD; lpBuffer: LPSTR; lpFilePart: PLPSTR): DWORD; stdcall; external 'kernel32' name 'GetFullPathNameA';

{** @desc 获取完整路径（Unicode）
    @param lpFileName 文件名
    @param nBufferLength 缓冲区大小
    @param lpBuffer 输出缓冲区
    @param lpFilePart 输出文件名部分
    @return 路径长度 *}
function GetFullPathNameW(lpFileName: LPCWSTR; nBufferLength: DWORD; lpBuffer: LPWSTR; lpFilePart: PLPWSTR): DWORD; stdcall; external 'kernel32' name 'GetFullPathNameW';
{ Environment }

{** @desc 获取环境变量（ANSI）
    @param lpName 变量名
    @param lpBuffer 输出缓冲区
    @param nSize 缓冲区大小
    @return 值长度 *}
{** @desc 获取进程命令行（Unicode） *}
function GetCommandLineW: LPCWSTR; stdcall; external 'kernel32' name 'GetCommandLineW';

{** @desc 将命令行拆成 argv 向量（Unicode）；返回值用 LocalFree 释放 *}
function CommandLineToArgvW(lpCmdLine: LPCWSTR; pNumArgs: PLONG): Pointer; stdcall;
  external 'shell32' name 'CommandLineToArgvW';

function GetEnvironmentVariableA(lpName: LPCSTR; lpBuffer: LPSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'GetEnvironmentVariableA';

{** @desc 获取环境变量（Unicode）
    @param lpName 变量名
    @param lpBuffer 输出缓冲区
    @param nSize 缓冲区大小
    @return 值长度 *}
function GetEnvironmentVariableW(lpName: LPCWSTR; lpBuffer: LPWSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'GetEnvironmentVariableW';

{** @desc 设置环境变量（ANSI）
    @param lpName 变量名
    @param lpValue 变量值
    @return TRUE 成功 *}
function SetEnvironmentVariableA(lpName: LPCSTR; lpValue: LPCSTR): BOOL; stdcall; external 'kernel32' name 'SetEnvironmentVariableA';

{** @desc 设置环境变量（Unicode）
    @param lpName 变量名
    @param lpValue 变量值
    @return TRUE 成功 *}
function SetEnvironmentVariableW(lpName: LPCWSTR; lpValue: LPCWSTR): BOOL; stdcall; external 'kernel32' name 'SetEnvironmentVariableW';

{** @desc 获取环境字符串块（ANSI）
    @return 环境字符串指针 *}
function GetEnvironmentStringsA: LPSTR; stdcall; external 'kernel32' name 'GetEnvironmentStringsA';

{** @desc 获取环境字符串块（Unicode）
    @return 环境字符串指针 *}
function GetEnvironmentStringsW: LPWSTR; stdcall; external 'kernel32' name 'GetEnvironmentStringsW';

{** @desc 释放环境字符串块（ANSI）
    @param lpszEnvironmentBlock 环境字符串指针
    @return TRUE 成功 *}
function FreeEnvironmentStringsA(lpszEnvironmentBlock: LPSTR): BOOL; stdcall; external 'kernel32' name 'FreeEnvironmentStringsA';

{** @desc 释放环境字符串块（Unicode）
    @param lpszEnvironmentBlock 环境字符串指针
    @return TRUE 成功 *}
function FreeEnvironmentStringsW(lpszEnvironmentBlock: LPWSTR): BOOL; stdcall; external 'kernel32' name 'FreeEnvironmentStringsW';

{** @desc 展开环境变量（ANSI）
    @param lpSrc 源字符串
    @param lpDst 输出缓冲区
    @param nSize 缓冲区大小
    @return 展开后长度 *}
function ExpandEnvironmentStringsA(lpSrc: LPCSTR; lpDst: LPSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'ExpandEnvironmentStringsA';

{** @desc 展开环境变量（Unicode）
    @param lpSrc 源字符串
    @param lpDst 输出缓冲区
    @param nSize 缓冲区大小
    @return 展开后长度 *}
function ExpandEnvironmentStringsW(lpSrc: LPCWSTR; lpDst: LPWSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'ExpandEnvironmentStringsW';

{ String conversion }

{** @desc 多字节转宽字符
    @param CodePage 代码页（CP_UTF8 等）
    @param dwFlags 标志
    @param lpMultiByteStr 多字节字符串
    @param cbMultiByte 字符串长度（-1 自动）
    @param lpWideCharStr 输出缓冲区
    @param cchWideChar 缓冲区大小
    @return 写入字符数 *}
function MultiByteToWideChar(CodePage: UINT; dwFlags: DWORD; lpMultiByteStr: LPCSTR; cbMultiByte: Int32; lpWideCharStr: LPWSTR; cchWideChar: Int32): Int32; stdcall; external 'kernel32' name 'MultiByteToWideChar';

{** @desc 宽字符转多字节
    @param CodePage 代码页
    @param dwFlags 标志
    @param lpWideCharStr 宽字符字符串
    @param cchWideChar 字符串长度
    @param lpMultiByteStr 输出缓冲区
    @param cbMultiByte 缓冲区大小
    @param lpDefaultChar 默认字符
    @param lpUsedDefaultChar 是否使用默认字符
    @return 写入字节数 *}
function WideCharToMultiByte(CodePage: UINT; dwFlags: DWORD; lpWideCharStr: LPCWSTR; cchWideChar: Int32; lpMultiByteStr: LPSTR; cbMultiByte: Int32; lpDefaultChar: LPCSTR; lpUsedDefaultChar: Pointer): Int32; stdcall; external 'kernel32' name 'WideCharToMultiByte';

{ Process }

{** @desc 创建进程（ANSI）
    @param lpApplicationName 应用程序名
    @param lpCommandLine 命令行
    @param lpProcessAttributes 进程安全属性
    @param lpThreadAttributes 线程安全属性
    @param bInheritHandles 是否继承句柄
    @param dwCreationFlags 创建标志
    @param lpEnvironment 环境变量
    @param lpCurrentDirectory 工作目录
    @param lpStartupInfo 启动信息
    @param lpProcessInformation 输出进程信息
    @return TRUE 成功 *}
function CreateProcessA(lpApplicationName: LPCSTR; lpCommandLine: LPSTR; lpProcessAttributes: LPSECURITY_ATTRIBUTES; lpThreadAttributes: LPSECURITY_ATTRIBUTES; bInheritHandles: WINBOOL; dwCreationFlags: DWORD; lpEnvironment: LPVOID; lpCurrentDirectory: LPCSTR; lpStartupInfo: LPSTARTUPINFOA; lpProcessInformation: LPPROCESS_INFORMATION): WINBOOL; stdcall; external 'kernel32' name 'CreateProcessA';

{** @desc 创建进程（Unicode）
    @param lpApplicationName 应用程序名
    @param lpCommandLine 命令行
    @param lpProcessAttributes 进程安全属性
    @param lpThreadAttributes 线程安全属性
    @param bInheritHandles 是否继承句柄
    @param dwCreationFlags 创建标志
    @param lpEnvironment 环境变量
    @param lpCurrentDirectory 工作目录
    @param lpStartupInfo 启动信息
    @param lpProcessInformation 输出进程信息
    @return TRUE 成功 *}
function CreateProcessW(lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR; lpProcessAttributes: LPSECURITY_ATTRIBUTES; lpThreadAttributes: LPSECURITY_ATTRIBUTES; bInheritHandles: WINBOOL; dwCreationFlags: DWORD; lpEnvironment: LPVOID; lpCurrentDirectory: LPCWSTR; lpStartupInfo: LPSTARTUPINFOW; lpProcessInformation: LPPROCESS_INFORMATION): WINBOOL; stdcall; external 'kernel32' name 'CreateProcessW';

{** @desc 获取启动信息（ANSI）
    @param lpStartupInfo 输出启动信息 *}
procedure GetStartupInfoA(lpStartupInfo: LPSTARTUPINFOA); stdcall; external 'kernel32' name 'GetStartupInfoA';

{** @desc 获取启动信息（Unicode）
    @param lpStartupInfo 输出启动信息 *}
procedure GetStartupInfoW(lpStartupInfo: LPSTARTUPINFOW); stdcall; external 'kernel32' name 'GetStartupInfoW';

{** @desc 终止进程
    @param hProcess 进程句柄
    @param uExitCode 退出码
    @return TRUE 成功 *}
function TerminateProcess(hProcess: HANDLE; uExitCode: UINT): WINBOOL; stdcall; external 'kernel32' name 'TerminateProcess';

{** @desc 恢复挂起线程
    @return 先前挂起计数；失败 $FFFFFFFF *}
function ResumeThread(hThread: HANDLE): DWORD; stdcall; external 'kernel32' name 'ResumeThread';

{** @desc 创建 Job Object（进程树容器，M2-W2） *}
function CreateJobObjectW(lpJobAttributes: LPSECURITY_ATTRIBUTES;
  lpName: LPCWSTR): HANDLE; stdcall; external 'kernel32' name 'CreateJobObjectW';

{** @desc 将进程加入 Job *}
function AssignProcessToJobObject(hJob, hProcess: HANDLE): WINBOOL; stdcall;
  external 'kernel32' name 'AssignProcessToJobObject';

{** @desc 终止 Job 内全部进程 *}
function TerminateJobObject(hJob: HANDLE; uExitCode: UINT): WINBOOL; stdcall;
  external 'kernel32' name 'TerminateJobObject';

{** @desc 获取进程退出码
    @param hProcess 进程句柄
    @param lpExitCode 输出退出码
    @return TRUE 成功 *}
function GetExitCodeProcess(hProcess: HANDLE; lpExitCode: LPDWORD): WINBOOL; stdcall; external 'kernel32' name 'GetExitCodeProcess';

{** @desc 退出当前进程
    @param uExitCode 退出码 *}
procedure ExitProcess(uExitCode: UINT); stdcall; external 'kernel32' name 'ExitProcess';

{ I/O Completion Port }

{** @desc 创建/关联 I/O 完成端口
    @param FileHandle 文件句柄
    @param ExistingCompletionPort 已有端口（INVALID_HANDLE_VALUE 创建新）
    @param CompletionKey 完成键
    @param NumberOfConcurrentThreads 并发线程数
    @return 完成端口句柄 *}
function CreateIoCompletionPort(FileHandle: HANDLE; ExistingCompletionPort: HANDLE; CompletionKey: ULONG_PTR; NumberOfConcurrentThreads: DWORD): HANDLE; stdcall; external 'kernel32' name 'CreateIoCompletionPort';

{** @desc 获取完成状态
    @param CompletionPort 完成端口
    @param lpNumberOfBytesTransferred 输出传输字节数
    @param lpCompletionKey 输出完成键
    @param lpOverlapped 输出异步结构
    @param dwMilliseconds 超时毫秒数
    @return TRUE 成功 *}
function GetQueuedCompletionStatus(CompletionPort: HANDLE; lpNumberOfBytesTransferred: LPDWORD; lpCompletionKey: PULONG_PTR; lpOverlapped: PLPOVERLAPPED; dwMilliseconds: DWORD): WINBOOL; stdcall; external 'kernel32' name 'GetQueuedCompletionStatus';

{** @desc 投递完成状态
    @param CompletionPort 完成端口
    @param dwNumberOfBytesTransferred 传输字节数
    @param dwCompletionKey 完成键
    @param lpOverlapped 异步结构
    @return TRUE 成功 *}
function PostQueuedCompletionStatus(CompletionPort: HANDLE; dwNumberOfBytesTransferred: DWORD; dwCompletionKey: ULONG_PTR; lpOverlapped: LPOVERLAPPED): WINBOOL; stdcall; external 'kernel32' name 'PostQueuedCompletionStatus';

{ File find }

{** @desc 查找第一个文件（Unicode）
    @param lpFileName 文件名模式
    @param lpFindFileData 输出查找数据
    @return 查找句柄，INVALID_HANDLE_VALUE 失败 *}
function FindFirstFileW(lpFileName: LPCWSTR; lpFindFileData: LPWIN32_FIND_DATAW): HANDLE; stdcall; external 'kernel32' name 'FindFirstFileW';

{** @desc 查找下一个文件（Unicode）
    @param hFindFile 查找句柄
    @param lpFindFileData 输出查找数据
    @return TRUE 成功 *}
function FindNextFileW(hFindFile: HANDLE; lpFindFileData: LPWIN32_FIND_DATAW): WINBOOL; stdcall; external 'kernel32' name 'FindNextFileW';

{** @desc 关闭查找句柄
    @param hFindFile 查找句柄
    @return TRUE 成功 *}
function FindClose(hFindFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'FindClose';

{ Time }

{** @desc 获取系统时间（UTC）
    @param lpSystemTime 输出系统时间 *}
procedure GetSystemTime(lpSystemTime: LPSYSTEMTIME); stdcall; external 'kernel32' name 'GetSystemTime';

{** @desc 获取本地时间
    @param lpSystemTime 输出本地时间 *}
procedure GetLocalTime(lpSystemTime: LPSYSTEMTIME); stdcall; external 'kernel32' name 'GetLocalTime';

{** @desc 系统时间转文件时间
    @param lpSystemTime 系统时间
    @param lpFileTime 输出文件时间
    @return TRUE 成功 *}
function SystemTimeToFileTime(lpSystemTime: LPSYSTEMTIME; lpFileTime: Pointer): WINBOOL; stdcall; external 'kernel32' name 'SystemTimeToFileTime';

{** @desc 文件时间转系统时间
    @param lpFileTime 文件时间
    @param lpSystemTime 输出系统时间
    @return TRUE 成功 *}
function FileTimeToSystemTime(lpFileTime: Pointer; lpSystemTime: LPSYSTEMTIME): WINBOOL; stdcall; external 'kernel32' name 'FileTimeToSystemTime';

{ Critical Section }

{** @desc 初始化临界区（带自旋计数）
    @param lpCriticalSection 临界区
    @param dwSpinCount 自旋计数
    @return TRUE 成功 *}
{** @desc 初始化临界区（与 Delete/Enter/Leave 配对）
    @param lpCriticalSection 临界区 *}
procedure InitializeCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'InitializeCriticalSection';
function InitializeCriticalSectionAndSpinCount(lpCriticalSection: LPCRITICAL_SECTION; dwSpinCount: DWORD): WINBOOL; stdcall; external 'kernel32' name 'InitializeCriticalSectionAndSpinCount';

{** @desc 删除临界区
    @param lpCriticalSection 临界区 *}
procedure DeleteCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'DeleteCriticalSection';

{** @desc 进入临界区
    @param lpCriticalSection 临界区 *}
procedure EnterCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'EnterCriticalSection';

{** @desc 离开临界区
    @param lpCriticalSection 临界区 *}
procedure LeaveCriticalSection(lpCriticalSection: LPCRITICAL_SECTION); stdcall; external 'kernel32' name 'LeaveCriticalSection';

{** @desc 尝试进入临界区
    @param lpCriticalSection 临界区
    @return TRUE 成功 *}
function TryEnterCriticalSection(lpCriticalSection: LPCRITICAL_SECTION): WINBOOL; stdcall; external 'kernel32' name 'TryEnterCriticalSection';

{ Overlapped I/O }

{** @desc 获取异步操作结果
    @param hFile 文件句柄
    @param lpOverlapped 异步结构
    @param lpNumberOfBytesTransferred 输出传输字节数
    @param bWait 是否等待
    @return TRUE 成功 *}
function GetOverlappedResult(hFile: HANDLE; lpOverlapped: LPOVERLAPPED; lpNumberOfBytesTransferred: LPDWORD; bWait: WINBOOL): WINBOOL; stdcall; external 'kernel32' name 'GetOverlappedResult';

{** @desc 创建事件对象（UTF-16）
    @return 事件句柄，失败为 NULL *}
function CreateEventW(lpEventAttributes: Pointer; bManualReset: WINBOOL;
  bInitialState: WINBOOL; lpName: LPCWSTR): HANDLE; stdcall;
  external 'kernel32' name 'CreateEventW';

{** @desc 目录变更通知（异步）
    @param hDirectory 目录句柄（FILE_LIST_DIRECTORY）
    @param lpBuffer 输出缓冲
    @param nBufferLength 缓冲字节数
    @param bWatchSubtree 是否递归子树
    @param dwNotifyFilter FILE_NOTIFY_CHANGE_*
    @param lpBytesReturned 同步完成时写入字节数
    @param lpOverlapped 异步结构
    @param lpCompletionRoutine 完成例程（通常 nil）
    @return TRUE 同步完成；FALSE 时可能 ERROR_IO_PENDING *}
function ReadDirectoryChangesW(hDirectory: HANDLE; lpBuffer: Pointer;
  nBufferLength: DWORD; bWatchSubtree: WINBOOL; dwNotifyFilter: DWORD;
  lpBytesReturned: LPDWORD; lpOverlapped: LPOVERLAPPED;
  lpCompletionRoutine: Pointer): WINBOOL; stdcall;
  external 'kernel32' name 'ReadDirectoryChangesW';

{** @desc 取消 I/O 操作
    @param hFile 文件句柄
    @return TRUE 成功 *}
function CancelIo(hFile: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'CancelIo';

{** @desc 取消指定 I/O 操作
    @param hFile 文件句柄
    @param lpOverlapped 异步结构
    @return TRUE 成功 *}
function CancelIoEx(hFile: HANDLE; lpOverlapped: LPOVERLAPPED): WINBOOL; stdcall; external 'kernel32' name 'CancelIoEx';

{ Memory-mapped file }

{** @desc 创建文件映射（ANSI）
    @param hFile 文件句柄
    @param lpAttributes 安全属性
    @param flProtect 保护标志
    @param dwMaximumSizeHigh 大小高 32 位
    @param dwMaximumSizeLow 大小低 32 位
    @param lpName 映射名称
    @return 映射句柄 *}
function CreateFileMappingA(hFile: HANDLE; lpAttributes: LPSECURITY_ATTRIBUTES; flProtect: DWORD; dwMaximumSizeHigh: DWORD; dwMaximumSizeLow: DWORD; lpName: LPCSTR): HANDLE; stdcall; external 'kernel32' name 'CreateFileMappingA';

{** @desc 打开文件映射（ANSI）
    @param dwDesiredAccess 访问模式
    @param bInheritHandle 是否继承
    @param lpName 映射名称
    @return 映射句柄 *}
function OpenFileMappingA(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: LPCSTR): HANDLE; stdcall; external 'kernel32' name 'OpenFileMappingA';

{** @desc 映射文件视图
    @param hFileMappingObject 映射句柄
    @param dwDesiredAccess 访问模式
    @param dwFileOffsetHigh 偏移高 32 位
    @param dwFileOffsetLow 偏移低 32 位
    @param dwNumberOfBytesToMap 映射字节数
    @return 映射地址 *}
function MapViewOfFile(hFileMappingObject: HANDLE; dwDesiredAccess: DWORD; dwFileOffsetHigh: DWORD; dwFileOffsetLow: DWORD; dwNumberOfBytesToMap: PtrUInt): Pointer; stdcall; external 'kernel32' name 'MapViewOfFile';

{** @desc 取消映射文件视图
    @param lpBaseAddress 映射地址
    @return TRUE 成功 *}
function UnmapViewOfFile(lpBaseAddress: Pointer): WINBOOL; stdcall; external 'kernel32' name 'UnmapViewOfFile';

{** @desc 刷新文件视图
    @param lpBaseAddress 映射地址
    @param dwNumberOfBytesToFlush 刷新字节数
    @return TRUE 成功 *}
function FlushViewOfFile(lpBaseAddress: Pointer; dwNumberOfBytesToFlush: PtrUInt): WINBOOL; stdcall; external 'kernel32' name 'FlushViewOfFile';

{ Pipe }

{** @desc 创建管道
    @param hReadPipe 输出读端句柄
    @param hWritePipe 输出写端句柄
    @param lpPipeAttributes 安全属性
    @param nSize 缓冲区大小
    @return TRUE 成功 *}
function CreatePipe(hReadPipe: PHANDLE; hWritePipe: PHANDLE; lpPipeAttributes: LPSECURITY_ATTRIBUTES; nSize: DWORD): WINBOOL; stdcall; external 'kernel32' name 'CreatePipe';

{** @desc 窥探命名/匿名管道可读字节数 *}
function PeekNamedPipe(hNamedPipe: HANDLE; lpBuffer: Pointer;
  nBufferSize: DWORD; lpBytesRead: LPDWORD; lpTotalBytesAvail: LPDWORD;
  lpBytesLeftThisMessage: LPDWORD): WINBOOL; stdcall;
  external 'kernel32' name 'PeekNamedPipe';

{ Handle }

{** @desc 设置句柄信息
    @param hObject 句柄
    @param dwMask 掩码
    @param dwFlags 标志
    @return TRUE 成功 *}
function SetHandleInformation(hObject: HANDLE; dwMask: DWORD; dwFlags: DWORD): WINBOOL; stdcall; external 'kernel32' name 'SetHandleInformation';

{** @desc 复制句柄
    @param hSourceProcessHandle 源进程
    @param hSourceHandle 源句柄
    @param hTargetProcessHandle 目标进程
    @param lpTargetHandle 输出目标句柄
    @param dwDesiredAccess 访问模式
    @param bInheritHandle 是否继承
    @param dwOptions 选项
    @return TRUE 成功 *}
function DuplicateHandle(hSourceProcessHandle: HANDLE; hSourceHandle: HANDLE; hTargetProcessHandle: HANDLE; lpTargetHandle: PHANDLE; dwDesiredAccess: DWORD; bInheritHandle: WINBOOL; dwOptions: DWORD): WINBOOL; stdcall; external 'kernel32' name 'DuplicateHandle';

{** @desc 获取当前进程句柄
    @return 进程句柄 *}
function GetCurrentProcess: HANDLE; stdcall; external 'kernel32' name 'GetCurrentProcess';

{ Console }

{** @desc 设置控制台 Ctrl+C 处理
    @param HandlerRoutine 处理函数
    @param Add 是否添加
    @return TRUE 成功 *}
function SetConsoleCtrlHandler(HandlerRoutine: TConsoleCtrlHandlerRoutine; Add: WINBOOL): WINBOOL; stdcall; external 'kernel32' name 'SetConsoleCtrlHandler';

{** @desc 向控制台进程组发送控制事件（Ctrl+C / Ctrl+Break）
    @param dwCtrlEvent 控制事件类型（CTRL_C_EVENT / CTRL_BREAK_EVENT）
    @param dwProcessGroupId 进程组 ID（0 表示当前）
    @return TRUE 成功 *}
function GenerateConsoleCtrlEvent(dwCtrlEvent: DWORD; dwProcessGroupId: DWORD): WINBOOL; stdcall; external 'kernel32' name 'GenerateConsoleCtrlEvent';

{** @desc 获取标准句柄
    @param nStdHandle 标准句柄类型（STD_INPUT/OUTPUT/ERROR_HANDLE）
    @return 句柄 *}
function GetStdHandle(nStdHandle: DWORD): HANDLE; stdcall; external 'kernel32' name 'GetStdHandle';

{** @desc 获取控制台模式
    @param hConsoleHandle 控制台句柄
    @param lpMode 输出模式
    @return TRUE 成功 *}
function GetConsoleMode(hConsoleHandle: HANDLE; lpMode: LPDWORD): WINBOOL; stdcall; external 'kernel32' name 'GetConsoleMode';

{** @desc 设置控制台模式
    @param hConsoleHandle 控制台句柄
    @param dwMode 模式
    @return TRUE 成功 *}
function SetConsoleMode(hConsoleHandle: HANDLE; dwMode: DWORD): WINBOOL; stdcall; external 'kernel32' name 'SetConsoleMode';

{** @desc 获取控制台屏幕缓冲区信息
    @param hConsoleOutput 控制台输出句柄
    @param lpConsoleScreenBufferInfo 输出信息
    @return TRUE 成功 *}
function GetConsoleScreenBufferInfo(hConsoleOutput: HANDLE; lpConsoleScreenBufferInfo: Pointer): WINBOOL; stdcall; external 'kernel32' name 'GetConsoleScreenBufferInfo';

{ Format / Error }

{** @desc 格式化消息（ANSI）
    @param dwFlags 标志
    @param lpSource 消息源
    @param dwMessageId 消息 ID
    @param dwLanguageId 语言 ID
    @param lpBuffer 输出缓冲区
    @param nSize 缓冲区大小
    @param Arguments 参数
    @return 写入长度 *}
function FormatMessageA(dwFlags: DWORD; lpSource: Pointer; dwMessageId: DWORD; dwLanguageId: DWORD; lpBuffer: LPSTR; nSize: DWORD; Arguments: Pointer): DWORD; stdcall; external 'kernel32' name 'FormatMessageA';

const
  FORMAT_MESSAGE_FROM_SYSTEM = $1000;
  FORMAT_MESSAGE_IGNORE_INSERTS = $200;
  LANG_NEUTRAL = 0;
  SUBLANG_DEFAULT = 1;

{** @desc 构造语言 ID（Win32 MAKELANGID 宏单源：子语言左移 10 位或主语言） *}
function MAKELANGID(const APrimary, ASub: WORD): DWORD; inline;

{** @desc 格式化消息（ANSI 别名，与 FormatMessageA 同签名，供存量调用点使用） *}
function FormatMessage(dwFlags: DWORD; lpSource: Pointer; dwMessageId: DWORD; dwLanguageId: DWORD; lpBuffer: LPSTR; nSize: DWORD; Arguments: Pointer): DWORD; stdcall; external 'kernel32' name 'FormatMessageA';

{** @desc 释放本地内存
    @param hMem 内存句柄
    @return NULL *}
function LocalFree(hMem: Pointer): Pointer; stdcall; external 'kernel32' name 'LocalFree';

{ Module }

{** @desc 获取模块文件名（ANSI）
    @param hModule 模块句柄
    @param lpFilename 输出缓冲区
    @param nSize 缓冲区大小
    @return 路径长度 *}
function GetModuleFileNameA(hModule: HMODULE; lpFilename: LPSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'GetModuleFileNameA';

{** @desc 获取模块文件名（Unicode）
    @param hModule 模块句柄
    @param lpFilename 输出缓冲区
    @param nSize 缓冲区大小
    @return 路径长度 *}
function GetModuleFileNameW(hModule: HMODULE; lpFilename: LPWSTR; nSize: DWORD): DWORD; stdcall; external 'kernel32' name 'GetModuleFileNameW';

{ Temp path }

{** @desc 获取临时目录路径（ANSI）
    @param nBufferLength 缓冲区大小
    @param lpBuffer 输出缓冲区
    @return 路径长度 *}
function GetTempPathA(nBufferLength: DWORD; lpBuffer: LPSTR): DWORD; stdcall; external 'kernel32' name 'GetTempPathA';

{** @desc 获取临时目录路径（Unicode）
    @param nBufferLength 缓冲区大小
    @param lpBuffer 输出缓冲区
    @return 路径长度 *}
function GetTempPathW(nBufferLength: DWORD; lpBuffer: LPWSTR): DWORD; stdcall; external 'kernel32' name 'GetTempPathW';

{ Random }

{** @desc 生成随机数
    @param RandomBuffer 输出缓冲区
    @param RandomBufferLength 缓冲区大小
    @return TRUE 成功 *}
function RtlGenRandom(RandomBuffer: Pointer; RandomBufferLength: DWORD): WINBOOL; stdcall; external 'advapi32' name 'SystemFunction036';

{ File locking }

{** @desc 锁定文件区域
    @param hFile 文件句柄
    @param dwFlags 标志（LOCKFILE_EXCLUSIVE_LOCK 等）
    @param dwReserved 保留
    @param nNumberOfBytesToLockLow 锁定字节数低 32 位
    @param nNumberOfBytesToLockHigh 锁定字节数高 32 位
    @param lpOverlapped 异步结构
    @return TRUE 成功 *}
function LockFileEx(hFile: HANDLE; dwFlags: DWORD; dwReserved: DWORD; nNumberOfBytesToLockLow: DWORD; nNumberOfBytesToLockHigh: DWORD; lpOverlapped: LPOVERLAPPED): WINBOOL; stdcall; external 'kernel32' name 'LockFileEx';

{** @desc 解锁文件区域
    @param hFile 文件句柄
    @param dwReserved 保留
    @param nNumberOfBytesToUnlockLow 解锁字节数低 32 位
    @param nNumberOfBytesToUnlockHigh 解锁字节数高 32 位
    @param lpOverlapped 异步结构
    @return TRUE 成功 *}
function UnlockFileEx(hFile: HANDLE; dwReserved: DWORD; nNumberOfBytesToUnlockLow: DWORD; nNumberOfBytesToUnlockHigh: DWORD; lpOverlapped: LPOVERLAPPED): WINBOOL; stdcall; external 'kernel32' name 'UnlockFileEx';

{ Symbolic link }

{** @desc 创建符号链接（ANSI）
    @param lpSymlinkFileName 链接路径
    @param lpTargetFileName 目标路径
    @param dwFlags 标志
    @return TRUE 成功 *}
function CreateSymbolicLinkA(lpSymlinkFileName: LPCSTR; lpTargetFileName: LPCSTR; dwFlags: DWORD): BOOL; stdcall; external 'kernel32' name 'CreateSymbolicLinkA';

{** @desc 创建符号链接（Unicode）
    @param lpSymlinkFileName 链接路径
    @param lpTargetFileName 目标路径
    @param dwFlags 标志
    @return TRUE 成功 *}
function CreateSymbolicLinkW(lpSymlinkFileName: LPCWSTR; lpTargetFileName: LPCWSTR; dwFlags: DWORD): BOOL; stdcall; external 'kernel32' name 'CreateSymbolicLinkW';

{** @desc 创建硬链接（Unicode）
    @param lpFileName 新链接路径
    @param lpExistingFileName 已有文件路径
    @param lpSecurityAttributes 安全属性（可为 nil）
    @return TRUE 成功 *}
function CreateHardLinkW(lpFileName: LPCWSTR; lpExistingFileName: LPCWSTR;
  lpSecurityAttributes: Pointer): BOOL; stdcall; external 'kernel32' name 'CreateHardLinkW';

{** @desc 设置文件时间
    @param hFile 文件句柄
    @param lpCreationTime 创建时间（可为 nil）
    @param lpLastAccessTime 访问时间（可为 nil）
    @param lpLastWriteTime 修改时间（可为 nil）
    @return TRUE 成功 *}
function SetFileTime(hFile: HANDLE; lpCreationTime: Pointer;
  lpLastAccessTime: Pointer; lpLastWriteTime: Pointer): BOOL; stdcall;
  external 'kernel32' name 'SetFileTime';

{** @desc 获取最终路径（ANSI）
    @param hFile 文件句柄
    @param lpszFilePath 输出缓冲区
    @param cchFilePath 缓冲区大小
    @param dwFlags 标志
    @return 路径长度 *}
function GetFinalPathNameByHandleA(hFile: HANDLE; lpszFilePath: LPSTR; cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall; external 'kernel32' name 'GetFinalPathNameByHandleA';

{** @desc 获取最终路径（Unicode）
    @param hFile 文件句柄
    @param lpszFilePath 输出缓冲区
    @param cchFilePath 缓冲区大小
    @param dwFlags 标志
    @return 路径长度 *}
function GetFinalPathNameByHandleW(hFile: HANDLE; lpszFilePath: LPWSTR; cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall; external 'kernel32' name 'GetFinalPathNameByHandleW';

{** @desc 查找第一个文件（ANSI）
    @param lpFileName 文件名模式
    @param lpFindFileData 输出查找数据
    @return 查找句柄 *}
function FindFirstFileA(lpFileName: LPCSTR; lpFindFileData: LPWIN32_FIND_DATAA): HANDLE; stdcall; external 'kernel32' name 'FindFirstFileA';

{** @desc 查找下一个文件（ANSI）
    @param hFindFile 查找句柄
    @param lpFindFileData 输出查找数据
    @return TRUE 成功 *}
function FindNextFileA(hFindFile: HANDLE; lpFindFileData: LPWIN32_FIND_DATAA): WINBOOL; stdcall; external 'kernel32' name 'FindNextFileA';

{ Memory allocation (CRT) }

{** @desc 对齐内存分配
    @param size 分配大小
    @param alignment 对齐要求
    @return 内存指针，NULL 失败 *}
function _aligned_malloc(size: SizeUInt; alignment: SizeUInt): Pointer; cdecl; external 'msvcrt.dll' name '_aligned_malloc';

{** @desc 释放对齐内存
    @param memblock 内存指针 *}
procedure _aligned_free(memblock: Pointer); cdecl; external 'msvcrt.dll' name '_aligned_free';

{ winsock2 FFI }
{$I nextpas.core.platform.windows.ffi.winsock2.inc}

{ advapi32 FFI }
{$I nextpas.core.platform.windows.ffi.advapi32.inc}

{ ConPTY (Windows 10 1809+) }

{** @desc 创建伪终端控制台
    @param size 终端大小
    @param hInput 输入句柄
    @param hOutput 输出句柄
    @param dwFlags 标志
    @param phPC 输出伪终端句柄
    @return S_OK 成功 *}
function CreatePseudoConsole(size: COORD; hInput: HANDLE; hOutput: HANDLE; dwFlags: DWORD; out phPC: HPCON): Int32; stdcall; external 'kernel32' name 'CreatePseudoConsole';

{** @desc 关闭伪终端控制台
    @param hPC 伪终端句柄 *}
procedure ClosePseudoConsole(hPC: HPCON); stdcall; external 'kernel32' name 'ClosePseudoConsole';

{** @desc 调整伪终端大小
    @param hPC 伪终端句柄
    @param size 新大小
    @return S_OK 成功 *}
function ResizePseudoConsole(hPC: HPCON; size: COORD): Int32; stdcall; external 'kernel32' name 'ResizePseudoConsole';

{ Process thread attribute list }

{** @desc 初始化进程线程属性列表
    @param lpAttributeList 属性列表
    @param dwAttributeCount 属性数量
    @param dwFlags 标志
    @param lpSize 输出所需大小
    @return TRUE 成功 *}
function InitializeProcThreadAttributeList(lpAttributeList: Pointer; dwAttributeCount: DWORD; dwFlags: DWORD; var lpSize: PtrUInt): WINBOOL; stdcall; external 'kernel32' name 'InitializeProcThreadAttributeList';

{** @desc 更新进程线程属性
    @param lpAttributeList 属性列表
    @param dwFlags 标志
    @param Attribute 属性
    @param lpValue 属性值
    @param cbSize 值大小
    @param lpPreviousValue 输出旧值
    @param lpReturnSize 输出旧值大小
    @return TRUE 成功 *}
function UpdateProcThreadAttribute(lpAttributeList: Pointer; dwFlags: DWORD; Attribute: PtrUInt; lpValue: Pointer; cbSize: PtrUInt; lpPreviousValue: Pointer; lpReturnSize: Pointer): WINBOOL; stdcall; external 'kernel32' name 'UpdateProcThreadAttribute';

{** @desc 删除进程线程属性列表
    @param lpAttributeList 属性列表 *}
procedure DeleteProcThreadAttributeList(lpAttributeList: Pointer); stdcall; external 'kernel32' name 'DeleteProcThreadAttributeList';

{ Global memory (kernel32) —— 剪贴板 CF_UNICODETEXT 传输用 }

{** @desc 分配全局内存块
    @param uFlags GMEM_MOVEABLE 等标志
    @param dwBytes 字节数
    @return 内存句柄，nil 失败 *}
function GlobalAlloc(uFlags: DWORD; dwBytes: PtrUInt): HANDLE; stdcall; external 'kernel32' name 'GlobalAlloc';

{** @desc 锁定全局内存块,返回可读写指针
    @param hMem 内存句柄
    @return 内存指针,nil 失败 *}
function GlobalLock(hMem: HANDLE): LPVOID; stdcall; external 'kernel32' name 'GlobalLock';

{** @desc 解锁全局内存块(须与 GlobalLock 配对)
    @param hMem 内存句柄
    @return TRUE 成功 *}
function GlobalUnlock(hMem: HANDLE): WINBOOL; stdcall; external 'kernel32' name 'GlobalUnlock';

{** @desc 释放全局内存块(仅未被系统接管时)
    @param hMem 内存句柄
    @return nil 成功 *}
function GlobalFree(hMem: HANDLE): HANDLE; stdcall; external 'kernel32' name 'GlobalFree';

{ Clipboard (user32) —— 系统剪贴板原生访问 }

{** @desc 打开剪贴板
    @param hWndNewOwner 窗口所有者(nil = 与当前任务关联)
    @return TRUE 成功 *}
function OpenClipboard(hWndNewOwner: Pointer): WINBOOL; stdcall; external 'user32' name 'OpenClipboard';

{** @desc 关闭剪贴板(须与 OpenClipboard 配对)
    @return TRUE 成功 *}
function CloseClipboard: WINBOOL; stdcall; external 'user32' name 'CloseClipboard';

{** @desc 清空剪贴板
    @return TRUE 成功 *}
function EmptyClipboard: WINBOOL; stdcall; external 'user32' name 'EmptyClipboard';

{** @desc 以指定格式放置剪贴板数据(成功后所有权归系统)
    @param uFormat CF_* 格式
    @param hMem GlobalAlloc 句柄
    @return 句柄,nil 失败 *}
function SetClipboardData(uFormat: UINT; hMem: HANDLE): HANDLE; stdcall; external 'user32' name 'SetClipboardData';

{** @desc 以指定格式取剪贴板数据(只读,勿释放)
    @param uFormat CF_* 格式
    @return 内存句柄,nil 无此格式 *}
function GetClipboardData(uFormat: UINT): HANDLE; stdcall; external 'user32' name 'GetClipboardData';

implementation

function MAKELANGID(const APrimary, ASub: WORD): DWORD; inline;
begin
  Result := (DWORD(ASub) shl 10) or DWORD(APrimary);
end;

end.
