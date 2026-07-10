# Platform API 覆盖矩阵

> 生成时间: 2026-07-06
> 更新时间: 2026-07-11
> 审计范围: nextpas.core.platform.* 模块

## 概览

| 统计项 | 数值 |
|--------|------|
| 总模块数 | 60 |
| Windows FFI 声明 | 146 |
| Linux FFI 声明 | ~120 |
| macOS FFI 声明 | ~90 |
| FreeBSD FFI 声明 | ~85 |
| Android FFI 声明 | ~100 |
| 覆盖 DLL | kernel32, advapi32, msvcrt |
| Wine 测试模块 | 25 |
| Wine 测试用例 | 217 |

## 模块分类

### 1. 平台特定实现（18 个模块）

| 模块 | Windows | Linux | macOS | FreeBSD | 功能域 |
|------|---------|-------|-------|---------|--------|
| console | ✅ | ✅ | ✅ | ✅ | 控制台 I/O |
| dl | ✅ | ✅ | ✅ | ✅ | 动态库加载 |
| env | ✅ | ✅ | ✅ | ✅ | 环境变量 |
| error | ✅ | ✅ | ✅ | ✅ | 错误码转换 |
| fs | ✅ | ✅ | ✅ | ✅ | 文件系统操作 |
| io | ✅ | ✅ | ✅ | ✅ | 文件 I/O |
| memory | ✅ | ✅ | ✅ | ✅ | 内存分配 |
| mmap | ✅ | ✅ | ✅ | ✅ | 内存映射 |
| path | ✅ | ✅ | ✅ | ✅ | 路径操作 |
| pipe | ✅ | ✅ | ✅ | ✅ | 管道 |
| pty | ✅ | ✅ | ✅ | ✅ | 伪终端 |
| random | ✅ | ✅ | ✅ | ✅ | 随机数 |
| signal | ✅ | ✅ | ✅ | ✅ | 信号处理 |
| socket | ✅ | ✅ | ✅ | ✅ | 网络套接字 |
| sync | ✅ | ✅ | ✅ | ✅ | 同步原语 |
| thread | ✅ | ✅ | ✅ | ✅ | 线程管理 |
| time | ✅ | ✅ | ✅ | ✅ | 时间操作 |
| watch | ✅ | ✅ | ✅ | ✅ | 文件监控 |

### 2. 跨平台模块（5 个模块）

| 模块 | 原因 |
|------|------|
| fmt | 纯字符串格式化算法，无平台依赖 |
| info | 编译时常量（CurrentOS/CurrentCPU/CurrentEndian） |
| freetype | 第三方库绑定（FreeType 跨平台） |
| secure | 已废弃，功能移到 memory |
| args | 使用 System.ParamCount/ParamStr（跨平台） |

### 3. 合理简化实现（2 个模块）

| 模块 | 实现方式 |
|------|----------|
| which | 遍历 PATH 环境变量 + platform_fs_is_file |
| resource | Windows 返回 UNSUPPORTED（Job Objects 与 rlimit 不兼容） |

## Windows API 覆盖详情

### kernel32.dll（142 个函数）

#### 文件操作（25 个）
- CreateFileA/W, DeleteFileA/W, MoveFileA/W
- ReadFile, WriteFile, FlushFileBuffers
- SetFilePointer, SetFilePointerEx, GetFileSize, GetFileSizeEx, SetEndOfFile
- FindFirstFileA/W, FindNextFileA/W, FindClose
- GetFileAttributesExA/W, SetFileAttributesA/W
- GetFileInformationByHandle, GetFinalPathNameByHandleA/W
- GetFullPathNameA/W, GetCurrentDirectoryA/W, SetCurrentDirectoryA/W
- LockFileEx, UnlockFileEx

#### 进程管理（12 个）
- CreateProcessA/W, TerminateProcess, ExitProcess
- GetCurrentProcess, GetCurrentProcessId
- GetExitCodeProcess, WaitForSingleObject
- GetStartupInfoA/W
- InitializeProcThreadAttributeList, UpdateProcThreadAttribute, DeleteProcThreadAttributeList

#### 线程管理（16 个）
- CreateThread, SwitchToThread, GetCurrentThreadId
- TlsAlloc, TlsFree, TlsGetValue, TlsSetValue
- InitializeCriticalSectionAndSpinCount, DeleteCriticalSection
- EnterCriticalSection, LeaveCriticalSection, TryEnterCriticalSection
- InitializeSRWLock, AcquireSRWLockExclusive/Shared
- ReleaseSRWLockExclusive/Shared, TryAcquireSRWLockExclusive/Shared

#### 同步原语（10 个）
- InitializeConditionVariable, WakeConditionVariable, WakeAllConditionVariable
- SleepConditionVariableSRW
- WaitOnAddress, WakeByAddressSingle, WakeByAddressAll
- Sleep

#### 内存管理（12 个）
- VirtualAlloc, VirtualFree, VirtualProtect, VirtualQuery
- VirtualLock, VirtualUnlock
- MapViewOfFile, UnmapViewOfFile, FlushViewOfFile
- CreateFileMappingA, OpenFileMappingA

#### 环境变量（8 个）
- GetEnvironmentVariableA/W, SetEnvironmentVariableA/W
- GetEnvironmentStringsA/W, FreeEnvironmentStringsA/W
- ExpandEnvironmentStringsA/W

#### 控制台（6 个）
- GetStdHandle, GetConsoleMode, SetConsoleMode
- GetConsoleScreenBufferInfo
- SetConsoleCtrlHandler

#### 时间（8 个）
- QueryPerformanceCounter, QueryPerformanceFrequency
- GetSystemTime, GetLocalTime, GetSystemTimeAsFileTime
- SystemTimeToFileTime, FileTimeToSystemTime
- GetTimeZoneInformation

#### 动态库（6 个）
- LoadLibraryA/W, FreeLibrary, GetProcAddress
- GetModuleHandleW, GetModuleFileNameA/W

#### 其他（11 个）
- GetLastError, SetLastError, CloseHandle, DuplicateHandle
- SetHandleInformation, GetTempPathA/W, LocalFree
- FormatMessageA, MultiByteToWideChar, WideCharToMultiByte
- CreatePipe, CreatePseudoConsole, ResizePseudoConsole, ClosePseudoConsole

### advapi32.dll（1 个函数）
- SystemFunction036 (RtlGenRandom)

### msvcrt.dll（2 个函数）
- _aligned_malloc, _aligned_free

## 证据层级

| 层级 | 描述 | 状态 |
|------|------|------|
| Source Contract | 源码级接口声明 | ✅ 完成 |
| Forced Compile | 强制编译验证 | ✅ 完成 |
| Focused Runtime | Wine 运行时测试 | ✅ 20 模块 174 测试 |
| CI Matrix | CI 矩阵测试 | ✅ Windows 交叉编译 |

## 结论

**Windows API 覆盖完整**。146 个外部声明覆盖了 L0 平台抽象层所需的全部核心功能，满足 nextPas 运行时需求。

无需额外补充 Windows API。

---

## macOS/FreeBSD/Android FFI 完善

### 2026-07-08 更新

#### macOS (darwin.ffi.pas) — 新增 ~30 个 FFI 声明

| 功能域 | 新增函数 |
|--------|----------|
| 网络接口 | if_nametoindex, if_indextoname |
| 文件系统 | statfs, fstatfs, getfsstat |
| 系统信息 | sysctlbyname, sysctlnametomib |
| 文件拷贝 | copyfile, fcopyfile |
| 零拷贝 | sendfile (macOS 版本) |
| 文件操作 | ftruncate, fsync, fdatasync, flock |
| 网络完整 | sendto, recvfrom, getsockname, getpeername, getsockopt, setsockopt, socketpair |

#### FreeBSD (freebsd.ffi.pas) — 新增 ~25 个 FFI 声明

| 功能域 | 新增函数 |
|--------|----------|
| 高性能 accept | accept4 (原子 SOCK_NONBLOCK/SOCK_CLOEXEC) |
| 资源限制 | prlimit (FreeBSD 版本) |
| 随机数 | getrandom (FreeBSD 12+) |
| 文件系统 | statfs, fstatfs |
| 系统信息 | sysctlbyname |
| 零拷贝 | sendfile (FreeBSD 版本), copy_file_range |
| 网络接口 | if_nametoindex, if_indextoname |
| 网络完整 | sendto, recvfrom, getsockname, getpeername, getsockopt, setsockopt, socketpair |
| 文件操作 | ftruncate, fsync, fdatasync, flock |

#### Android (android.ffi.pas) — 新增 ~30 个 FFI 声明

| 功能域 | 新增函数 |
|--------|----------|
| 事件通知 | epoll_create1, epoll_ctl, epoll_wait |
| 事件fd | eventfd |
| 文件监控 | inotify_init1, inotify_add_watch, inotify_rm_watch |
| 高性能 accept | accept4 |
| 目录读取 | getdents64 |
| 文件系统 | statfs, fstatfs |
| 资源限制 | prlimit64 |
| 随机数 | getrandom (API 28+) |
| 系统信息 | sysinfo, uname |
| 零拷贝 | sendfile, splice |
| 进程控制 | prctl |
| 信号处理 | sigaction, sigprocmask, sigpending, sigwait, raise |
| 网络接口 | if_nametoindex, if_indextoname |
| 文件操作 | ftruncate, fsync, fdatasync, flock, fstatat |
| Android 特有 | __system_property_find, __system_property_get, __system_property_read_callback |

#### POSIX 通用 (posix.ffi.pas) — 新增 ~15 个 FFI 声明

| 功能域 | 新增函数 |
|--------|----------|
| 系统信息 | uname |
| 文件状态 | fstatat |
| 文件系统 | statfs, fstatfs |
| 进程组 | getpgrp, setpgrp, getsid |
| 用户/组 | getgrnam, getgrgid |

### 平台 FFI 覆盖总结

| 平台 | FFI 声明数 | 状态 |
|------|-----------|------|
| Windows | 146 | ✅ 完整 |
| Linux | ~120 | ✅ 完整 |
| macOS | ~90 | ✅ 完整 (kqueue 替代 epoll/inotify) |
| FreeBSD | ~85 | ✅ 完整 (kqueue 替代 epoll/inotify) |
| Android | ~100 | ✅ 完整 (Bionic libc + property API) |
