# nextPas Platform Module — 目标树与演进路线

## 定位

nextPas 是基于 LLVM 后端的现代 Pascal 编译器。本模块（`nextpas.core.platform`）是
**我们自有体系的通用 OS 底座** —— 既是未来自有 system 的地基，也是 sysroot 兼容
路径的共享底座。承担所有 OS/CPU 交互的底层职责。

设计原则：
- **不对 FPC 兼容。** nextpas 兼容 FPC 项目只通过 sysroot（见 memory:
  fpc-sysroot-mechanism）。platform 层是我们自己的体系，按"任何 system 都需要的
  OS 原语"建设，不为 FPC 的类型/常量/命名服务。
- 禁止 uses FPC 平台/RTL 绑定单元，所有 OS API 自行声明
- LLVM 处理 codegen/ABI，platform 层只关心 OS API surface 和 struct layout
- 追求正确性、先进性、优雅性、可维护性与性能
- 进 platform 的判据：通用 OS 原语（syscall/mmap/线程/时间/文件/信号…）✅；
  FPC 专属形状（fpc_*、TAnsiRec 偏移、baseunix 命名）❌ → 属 sysroot 侧

> 注：历史上 G1 阶段曾以"FPC ABI 兼容"为 struct 布局的对照基准。这个**对照**仍有
> 价值（确认 layout 正确，如 TPlatformLinuxStat 与内核 struct 一致），但**目标**
> 不是兼容 FPC——是 ABI 正确。措辞已校正。

## Target 矩阵

### Tier 1（首批全量支持，完整 platform + 100% 接口测试覆盖）

| OS      | CPU              | 状态                    |
|---------|------------------|-------------------------|
| Linux   | x86_64, aarch64  | ✅ 完成 (CI 全绿)        |
| macOS   | x86_64, aarch64  | 代码完成, CI 待修复 (FPC trunk linker issue) |
| Windows | x86_64           | 代码完成, 无 CI          |

### Tier 2（第二批，platform 定义齐全，交叉编译验证）

| OS      | CPU              | 理由                        |
|---------|------------------|-----------------------------|
| Linux   | riscv64          | RISC-V 生态快速增长          |
| Linux   | arm (32-bit)     | 嵌入式/IoT                   |
| Windows | aarch64          | Windows on ARM 趋势          |
| FreeBSD | x86_64, aarch64  | BSD 生态                     |
| Android | aarch64          | 移动端                       |

### Tier 3（远期，按需扩展）

| OS/Target | CPU           | 理由                |
|-----------|---------------|---------------------|
| WASM      | wasm32/wasm64 | 浏览器/边缘计算      |
| Linux     | loongarch64   | 国产化需求           |
| Linux     | powerpc64le   | IBM 服务器           |

## 架构分层

```
┌─────────────────────────────────────────────────┐
│  ctypes.inc (FPC 兼容 C 类型别名)                │
├─────────────────────────────────────────────────┤
│  posix.base (ptypes + 共享 POSIX 类型)           │
├─────────────────────────────────────────────────┤
│  posix.ffi (签名一致的共享 POSIX API)            │
├──────────┬───────────┬──────────┬───────────────┤
│linux.base│darwin.base│freebsd   │windows.base   │ ← host 专属常量/结构
│  *.inc   │  *.inc    │.base     │  *.inc        │   (用 inc 按域组织)
├──────────┼───────────┼──────────┼───────────────┤
│linux.ffi │darwin.ffi │freebsd   │windows.ffi    │ ← host 专属 raw FFI
│          │           │.ffi      │  *.inc        │   (按 DLL 组织 inc)
├──────────┴───────────┴──────────┴───────────────┤
│  platform.time / platform.sync / platform.thread │ ← 统一平台抽象层
│  platform.file / platform.io / platform.net      │   (直接消费 base+ffi)
└─────────────────────────────────────────────────┘
```

## CPU 架构差异处理策略

| 差异类型       | 处理方式                                    |
|---------------|---------------------------------------------|
| syscall 号    | 按架构分 inc: syscall.x86_64.inc / syscall.generic.inc / syscall.riscv64.inc |
| struct 布局   | {$IFDEF NEXTPAS_AARCH64} 条件编译            |
| ABI 调用约定  | LLVM 后端处理，platform 层不关心              |
| 原子操作      | 按架构分 inc: atomic.x86_64.inc / atomic.aarch64.inc |
| 对齐/padding  | {$packrecords c} + 架构条件编译              |

## 目标树

### G1: 类型基础 ✅
- [x] ctypes.inc (FPC 兼容 C 类型别名)
- [x] posix.base 扩展 (完整 ptypes)
- [x] 验证与 FPC ctypes/unixtype 的 ABI 兼容性 (10 tests: cint/clong/csize_t/cfloat/cdouble/pid_t/pthread_t)

### G2: Linux host 全量 API ✅
- [x] errno 全表 (132 错误码)
- [x] syscall 号全表 (x86_64 + aarch64)
- [x] syscall 号: riscv64 (从 FPC 搬运)
- [x] syscall 号: arm32 (从 FPC 搬运)
- [x] settings.inc 加入 riscv64, arm32 检测
- [x] ostypes: pollfd, iovec, dirent, statfs, rlimit, utsname, flock, tms, fdset
- [x] linux.base 扩展: epoll, inotify, sysinfo, signal
- [x] socket 类型与常量: sockaddr 系列, AF_*, SOCK_*, SOL_*, SO_*, IPPROTO_*
- [x] 终端: termios, ioctl 常量
- [x] linux.ffi 扩展: pipe2, dup3, epoll_*, eventfd, timerfd_*, signalfd, inotify_*, getdents64, getrandom, sysinfo, uname
- [x] posix.ffi 扩展: pipe, dup2, readlink, symlink, chmod, chown, getuid 系列, tcgetattr/tcsetattr/ioctl
- [x] 单元测试: ostypes_abi, subsystems_abi, socket_abi, platform_files

### G3: Darwin host 全量 API ✅
- [x] errno 全表 (104 Darwin 错误码)
- [x] Darwin 专属类型: kqueue, kevent, signal
- [x] darwin.ffi 扩展: kqueue, kevent, pipe, dup2, readlink, symlink, chmod, chown, getuid 系列, socket 全套, getaddrinfo/freeaddrinfo/getnameinfo
- [x] socket 常量 (AF_INET6=30, SOL_SOCKET=$FFFF, etc.)

### G4: FreeBSD host 全量 API ✅
- [x] errno 全表 (96 FreeBSD 错误码)
- [x] FreeBSD 专属: kqueue, kevent, signal
- [x] freebsd.ffi 扩展: kqueue, kevent, pipe, dup2, readlink, symlink, chmod, chown, getuid 系列, socket 全套, getaddrinfo/freeaddrinfo/getnameinfo
- [x] socket 常量 (BSD family, same as Darwin)

### G5: Windows host 全量 API ✅
- [x] windows.base: kernel32 类型/常量 (HANDLE, DWORD, OVERLAPPED, CRITICAL_SECTION, WIN32_FIND_DATA, SYSTEMTIME, error codes, MAX_PATH, STD_*_HANDLE, STARTF_*, FILE_FLAG_*)
- [x] windows.base: ws2_32 类型/常量 (TSocket, TWSAData, WSABUF, AF_*/SOCK_*/SOL_*/SO_*/IPPROTO_*/TCP_*/MSG_*/AI_*/NI_*, WSA error codes, IOCTL)
- [x] windows.base: advapi32 类型/常量 (Registry, Token, Service)
- [x] windows.ffi: kernel32 (CreateFile, ReadFile, WriteFile, CreateProcess, WaitForSingleObject, CreateThread, CriticalSection, IOCP, FindFirstFile/FindNextFile/FindClose, GetSystemTime, GetOverlappedResult, CancelIo)
- [x] windows.ffi: ws2_32 (WSAStartup, socket, bind, listen, accept, connect, send, recv, closesocket, shutdown, select, ioctlsocket, setsockopt, getsockopt, getaddrinfo, freeaddrinfo, getnameinfo, WSARecv, WSASend, WSASocketW, htons/ntohs/htonl/ntohl)
- [x] windows.ffi: advapi32 (Registry 14 + Token 10 + Service 9 = 37 functions)

### G6: POSIX 共享层完善 ✅
- [x] posix.ffi 补齐所有共享签名 API (42+ functions)
- [x] posix.base 补齐共享常量 + socket structs
- [x] termios FFI (tcgetattr/tcsetattr/ioctl/isatty)

### G7: 统一平台抽象层 ✅
- [x] platform.time
- [x] platform.sync
- [x] platform.thread
- [x] platform.files (文件/目录操作, 17 tests; symlink/readlink, Windows dir backend)
- [x] platform.io (I/O 多路复用: epoll/kqueue/WSAPoll, 6 tests)
- [x] platform.net (socket 统一抽象, 5 tests)
- [x] platform.process (进程管理: fork+execve/CreateProcess, 5 tests)
- [x] platform.pipe (管道+dup2 统一抽象, 5 tests)
- [x] platform.mmap (内存映射文件: mmap/CreateFileMapping, 5 tests)
- [x] platform.dl (动态库加载: dlopen/LoadLibrary, 8 tests)
- [x] platform.env (环境变量: getenv/GetEnvironmentVariable, 8 tests)
- [x] platform.random (系统熵源: getrandom/arc4random_buf/RtlGenRandom, 5 tests)
- [x] platform.signal (信号处理: sigaction/SetConsoleCtrlHandler, 6 tests)
- [x] platform.console (终端检测: isatty/GetConsoleMode, ANSI 启用, 5 tests)
- [x] platform.error (错误码转字符串: strerror/FormatMessage, 5 tests)
- [x] platform.path (路径操作: join/dirname/basename/ext/normalize, 10 tests)
- [x] platform.fs (文件系统便利: exists/is_file/is_dir/size/temp_dir/walk, 12 tests)
- [x] platform.args (命令行参数: count/get/exe_path, 5 tests)
- [x] 每个模块无内存泄漏验证 (heaptrc: 18 modules, 0 leaks)

### G8: Tier 2 剩余扩展
- [x] Windows aarch64 支持 — 代码已就绪（共享 Win32 API surface，无架构特定代码）
- [ ] 交叉编译验证矩阵 — 需要 CI 环境（FPC cross-compiler for win-aarch64）
- [ ] RISC-V Linux 验证 — platform.linux 已支持，需 QEMU 或真机验证
- [ ] ARM32 Linux 验证 — 需交叉编译环境

### G9: Tier 3 远期
- [ ] WASM target 评估与原型
- [ ] LoongArch64 syscall 表
- [ ] powerpc64le 支持

## 执行顺序

G1-G7 全部完成。当前状态：

1. ✅ G1 (类型基础) — 完成
2. ✅ G2 (Linux host 全量) — 完成
3. ✅ G3 (Darwin host 全量) — 完成
4. ✅ G4 (FreeBSD host 全量) — 完成
5. ✅ G5 (Windows host 全量) — 完成
6. ✅ G6 (POSIX 共享层) — 完成
7. ✅ G7 (统一抽象层: 16 modules) — 完成
8. **待推进**: G8 (Tier 2 扩展: Windows aarch64, 交叉编译验证)
9. **远期**: G9 (WASM / LoongArch / powerpc64le)

## 质量门禁

- 所有 API 接口必须有单元测试覆盖（接口测试覆盖率 100%）
- 结构体必须有 SizeOf + 字段 Offset 断言（确保 ABI 兼容）
- 无内存泄漏（统一抽象层必须 valgrind/heaptrc 验证）
- 每轮工作提交 git，commit message 清晰
- 关键设计决策与 Codex 讨论后落地
