# nextPas Platform Module — 目标树与演进路线

## 定位

nextPas 是基于 LLVM 后端的现代 Pascal 编译器。本模块（`nextpas.core.platform`）是编译器
自身的运行时平台基座，承担所有 OS/CPU 交互的底层职责。

设计原则：
- 对 FPC 代码保持最大兼容（类型、常量、命名）
- 禁止 uses FPC 平台/RTL 绑定单元，所有 OS API 自行声明
- LLVM 处理 codegen/ABI，platform 层只关心 OS API surface 和 struct layout
- 追求正确性、先进性、优雅性、可维护性与性能

## Target 矩阵

### Tier 1（首批全量支持，完整 platform + 100% 接口测试覆盖）

| OS      | CPU              | 状态   |
|---------|------------------|--------|
| Linux   | x86_64, aarch64  | 进行中 |
| macOS   | x86_64, aarch64  | 待启动 |
| Windows | x86_64           | 待启动 |

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
- [ ] 验证与 FPC ctypes/unixtype 的 ABI 兼容性

### G2: Linux host 全量 API
- [x] errno 全表 (132 错误码)
- [x] syscall 号全表 (x86_64 + aarch64)
- [ ] syscall 号: riscv64 (从 FPC 搬运)
- [ ] syscall 号: arm32 (从 FPC 搬运)
- [ ] settings.inc 加入 riscv64, arm32 检测
- [ ] ostypes: pollfd, iovec, dirent, statfs, rlimit, rusage, utsname, flock, tms, fdset
- [ ] linux.pp 扩展: epoll, futex, clone, timerfd, eventfd, signalfd, inotify
- [ ] socket 类型与常量: sockaddr 系列, AF_*, SOCK_*, SOL_*, SO_*, IPPROTO_*
- [ ] 终端: termios, ioctl 常量
- [ ] linux.ffi 扩展: pipe2, dup3, epoll_*, eventfd, timerfd_*, signalfd, inotify_*
- [ ] posix.ffi 扩展: pipe, dup2, readlink, symlink, chmod, chown, getuid 系列
- [ ] 单元测试: 编译验证 + 结构体 SizeOf/Offset 断言

### G3: Darwin host 全量 API
- [ ] errno 全表 (Darwin 值不同于 Linux)
- [ ] Darwin 专属类型: kqueue, kevent, dispatch, mach 扩展
- [ ] darwin.ffi 扩展: kqueue, kevent, dispatch_*, mach_*
- [ ] 单元测试

### G4: FreeBSD host 全量 API
- [ ] errno 全表
- [ ] FreeBSD 专属: kqueue, capsicum, jail
- [ ] 单元测试

### G5: Windows host 全量 API
- [ ] windows.base: kernel32 类型/常量 (HANDLE, DWORD, OVERLAPPED, SECURITY_ATTRIBUTES...)
- [ ] windows.base: ws2_32 类型/常量 (SOCKET, WSADATA, sockaddr...)
- [ ] windows.base: advapi32/ntdll 类型
- [ ] windows.ffi: kernel32 (CreateFile, ReadFile, WriteFile, CreateProcess, WaitForSingleObject, CreateThread, InitializeCriticalSection, CreateEvent, IOCP...)
- [ ] windows.ffi: ws2_32 (WSAStartup, socket, bind, listen, accept, WSARecv, WSASend...)
- [ ] windows.ffi: advapi32 (RegOpenKeyEx, OpenProcessToken...)
- [ ] 单元测试

### G6: POSIX 共享层完善
- [ ] posix.ffi 补齐所有共享签名 API
- [ ] posix.base 补齐共享常量 (POSIX signal 全表等)
- [ ] 单元测试

### G7: 统一平台抽象层
- [x] platform.time
- [x] platform.sync
- [x] platform.thread
- [ ] platform.file (文件/目录操作)
- [ ] platform.io (I/O 多路复用: epoll/kqueue/IOCP 统一)
- [ ] platform.net (socket 统一抽象)
- [ ] platform.process (进程管理)
- [ ] 每个模块 100% 接口测试覆盖 + 无内存泄漏验证

### G8: Tier 2 剩余扩展
- [ ] Windows aarch64 支持
- [ ] 交叉编译验证矩阵

### G9: Tier 3 远期
- [ ] WASM target 评估与原型
- [ ] LoongArch64 syscall 表
- [ ] powerpc64le 支持

## 执行顺序

1. **当前**: G2 (Linux host 全量，含 riscv64/arm32 syscall 搬运) — 编译器自身运行在 Linux 上
2. **其次**: G5 (Windows) + G6 (POSIX 共享层) 并行 — Windows 高优先级
3. **然后**: G3 (Darwin) — macOS 支持
4. **之后**: G7 (统一抽象层) — 在 host 层齐全后构建
5. **之后**: G4 (FreeBSD) + G8 (Tier 2 剩余: Windows aarch64 等)
6. **远期**: G9 (WASM / LoongArch / powerpc64le) — 低优先级，按需

## 质量门禁

- 所有 API 接口必须有单元测试覆盖（接口测试覆盖率 100%）
- 结构体必须有 SizeOf + 字段 Offset 断言（确保 ABI 兼容）
- 无内存泄漏（统一抽象层必须 valgrind/heaptrc 验证）
- 每轮工作提交 git，commit message 清晰
- 关键设计决策与 Codex 讨论后落地
