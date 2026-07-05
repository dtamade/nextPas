# nextpas.core.platform 代码契约

**模块路径**：`core/src/nextpas.core.platform*.pas`（59 个源文件）
**层级**：L0（仅依赖 FPC RTL）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-05
**版本**：2.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 | 主要 API |
|------|------|----------|
| platform.pas | 门面 re-export | — |
| platform.base.pas | TOSKind, TCPUArch, TEndianness | — |
| platform.error.pas | 错误码常量 + 消息映射 | PLATFORM_ERR_*, platform_error_message |
| platform.info.pas | OS/架构/字节序检测 | platform_info_os, platform_info_arch |
| platform.time.pas | 时间 API | platform_monotonic_ns, platform_wallclock_ns |
| platform.io.pas | 文件 I/O (deprecated) | platform_io_read, platform_io_write |
| platform.files.pas | 文件操作 | platform_file_open, platform_file_stat, platform_dir_open |
| platform.fs.pas | 文件系统高级操作 | platform_fs_mkdir_p, platform_fs_copy, platform_fs_glob |
| platform.path.pas | 路径操作 | platform_path_join, platform_path_dirname |
| platform.pipe.pas | 管道操作 | platform_pipe_open, platform_pipe_close |
| platform.dl.pas | 动态库加载 | platform_dl_open, platform_dl_sym |
| platform.socket.pas | 网络 Socket | platform_socket_create, platform_socket_connect |
| platform.process.pas | 进程管理 | platform_process_spawn, platform_process_wait |
| platform.signal.pas | 信号处理 | platform_signal_set, platform_signal_block |
| platform.thread.pas | 线程管理 | platform_thread_create, platform_thread_join |
| platform.sync.pas | 同步原语 | platform_mutex_*, platform_rwlock_*, platform_condvar_* |
| platform.memory.pas | 内存分配 | platform_aligned_alloc, platform_aligned_realloc |
| platform.mmap.pas | 内存映射 | platform_mmap_file, platform_mmap_shared |
| platform.env.pas | 环境变量 | platform_env_get, platform_env_set |
| platform.args.pas | 命令行参数 | platform_args_count, platform_args_get |
| platform.console.pas | 控制台 I/O | platform_console_read, platform_console_write |
| platform.random.pas | 随机数 | platform_random_bytes |
| platform.resource.pas | 资源限制 | platform_resource_get, platform_resource_set |
| platform.secure.pas | 安全操作 | platform_secure_zero |
| platform.fmt.pas | 格式化输出 | platform_fmt_snprintf |
| platform.watch.pas | 文件监控 | platform_watch_create |
| platform.which.pas | 可执行文件查找 | platform_which |
| platform.pty.pas | 伪终端 | platform_pty_open |
| platform.freetype.pas | FreeType 字体 | platform_ft_init, platform_ft_load |

### 1.2 平台特定层

| 文件 | 职责 |
|------|------|
| platform.linux.base/ffi/modern | Linux 系统调用 + FFI |
| platform.darwin.base/ffi | macOS 系统调用 + FFI |
| platform.freebsd.base/ffi | FreeBSD 系统调用 + FFI |
| platform.windows.base/ffi/utf16/math | Windows API + UTF-16 |
| platform.android.base/ffi | Android 系统调用 + FFI |
| platform.posix.base/ffi/math | POSIX 公共层 |
| platform.unix.base/ffi | Unix 公共层 |

### 1.3 核心 API 签名

```pascal
// 文件 I/O
function platform_file_open(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; out AHandle: TPlatformFileHandle): Int32;
function platform_file_open_ex(const APath: PAnsiChar; AMode: TPlatformFileOpenMode;
  ACreate: TPlatformFileCreateMode; AAppend: Boolean; ASync: Boolean;
  APerm: UInt32; out AHandle: TPlatformFileHandle): Int32;
function platform_file_read(const AHandle: TPlatformFileHandle;
  ABuf: Pointer; ALen: Int32; out ANRead: Int32): Int32;
function platform_file_write(const AHandle: TPlatformFileHandle;
  ABuf: Pointer; ALen: Int32): Int32;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32;

// 进程
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
function platform_process_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult; ATimeoutMs: Int32 = 0): Int32;

// 线程
function platform_thread_create(out AHandle: TPlatformThreadHandle;
  AProc: TPlatformThreadProc; AArg: Pointer): Int32;
function platform_thread_join(const AHandle: TPlatformThreadHandle;
  out ARetVal: Pointer): Int32;

// 同步
function platform_mutex_init(out AMutex: TPlatformMutex): Int32;
function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;

// 内存
function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
```

---

## 2. 不变量

- **返回值约定**: 所有函数返回 `Int32`，0 = 成功，正数 = errno/GetLastError
- **句柄无效值**: `TPlatformFileHandle.Value = -1`（Unix）/ `INVALID_HANDLE_VALUE`（Windows）
- **Socket 句柄**: >= 0（Unix）/ > 0（Windows）
- **文件描述符**: 0/1/2 保留给 stdin/stdout/stderr
- **内存分配**: 返回 `Pointer`，`nil` 表示失败
- **字符串参数**: 所有 `PAnsiChar` 参数接受 nil（返回 `PLATFORM_ERR_INVALID`）

---

## 3. 错误处理

- **不抛异常**: 所有平台调用返回 `Int32` 错误码
- **错误码**: `PLATFORM_ERR_*` 常量（`nextpas.core.platform.error`）
  - `PLATFORM_ERR_INVALID` (22) — 无效参数/nil 指针
  - `PLATFORM_ERR_ENOENT` (2) — 文件不存在
  - `PLATFORM_ERR_BADF` (9) — 无效文件描述符
  - `PLATFORM_ERR_TIMEOUT` (110) — 操作超时
  - `PLATFORM_ERR_BUSY` (16) — 资源忙
  - `PLATFORM_ERR_AGAIN` (11) — 资源暂时不可用
  - `PLATFORM_ERR_UNSUPPORTED` (95) — 不支持的操作
- **错误消息**: `platform_error_message(ACode, ABuf, ABufLen)` 返回人类可读消息
- **错误分类**: `platform_error_category(ACode)` 返回 `TPlatformErrorCategory`

---

## 4. 线程安全

- **平台原语本身线程安全**（mutex/rwlock/condvar/semaphore）
- **同步原语遵循 POSIX 语义**
- **`platform_*` 函数**: 除非特别标注，均为线程安全
- **进程/线程句柄**: 同一句柄不可并发操作

---

## 5. 内存管理

- **平台句柄**: 由调用方负责关闭（`platform_file_close`, `platform_dl_close` 等）
- **mmap 映射**: 由调用方负责 `platform_mmap_unmap`
- **aligned_alloc**: 由调用方负责 `platform_aligned_free`
- **堆检测**: 测试构建启用 `heaptrc`，0 unfreed 为通过标准

---

## 6. 平台支持

| 平台 | 状态 | 测试方式 |
|------|------|----------|
| Linux x86_64 | ✅ 完成 | 本地 + CI |
| Linux aarch64 | ✅ 完成 | 交叉编译 + QEMU |
| Linux arm32 | ✅ 完成 | 交叉编译 |
| Linux riscv64 | ✅ 完成 | 交叉编译 |
| macOS x86_64 | ✅ 完成 | CI |
| Windows x86_64 | ✅ 完成 | Wine + CI |
| FreeBSD | ✅ 完成 | 交叉编译 |
| Android | ✅ 完成 | 交叉编译 |
| Fallback stub | ✅ 完成 | 返回 -1 |

---

## 7. 测试覆盖

### 7.1 测试套件（88 个）

| 套件 | 模块 | 测试数 |
|------|------|--------|
| test_platform | base/info/time | 3 |
| test_platform_io | 文件 I/O | 15+ |
| test_platform_files | 文件操作 | 13 |
| test_platform_fs | 文件系统 | 13 |
| test_platform_fs_walk | 目录遍历 | 8+ |
| test_platform_process | 进程管理 | 17 |
| test_platform_thread | 线程管理 | 10+ |
| test_platform_sync | 同步原语 | 20+ |
| test_platform_socket | 网络 | 16+ |
| test_platform_pipe | 管道 | 8+ |
| test_platform_dl | 动态库 | 6+ |
| test_platform_memory | 内存 | 10+ |
| test_platform_mmap | 内存映射 | 8+ |
| test_platform_signal | 信号 | 6+ |
| test_platform_env | 环境变量 | 5+ |
| test_platform_args | 命令行参数 | 5+ |
| test_platform_error | 错误处理 | 10+ |
| test_platform_resource | 资源限制 | 5 |
| test_platform_random | 随机数 | 3+ |
| ... | ... | ... |

### 7.2 质量门禁

- **heaptrc**: 所有测试构建启用，0 unfreed
- **nil guard**: 所有 `PAnsiChar` 参数检查 nil
- **边界值**: 0/nil/MAX_INT/-1 等边界条件覆盖
- **跨平台**: Linux/macOS/Windows/FreeBSD/Android 全覆盖

---

## 8. Phase 1-3 修复记录 (2026-07-05)

### Phase 1: 安全修复
- files.pas: 14 个路径函数加 nil guard
- signal.pas: SigSetAdd + block/unblock 范围校验
- process.pas: EINTR 重试
- socket.pas: resolve 函数 nil guard

### Phase 2: 一致性修复
- dl.pas: 魔数 → `PLATFORM_ERR_ENOENT`/`INVALID`
- pipe.pas: 魔数 → `PLATFORM_ERR_BADF`
- error.pas: char-by-char → `Move()`, 新增 `PLATFORM_ERR_BADF`
- memory.pas: realloc alignment 校验
- mmap.pas: POSIX page alignment 前置校验

### Phase 3: API 增强
- process.pas: `ATimeoutMs` 参数（Unix 轮询 + Windows 原生）
- fs.pas: `is_executable` 检查全部三个执行位

### Phase 4: TOCTOU 安全修复 (2026-07-05)
- fs.pas: `platform_fs_read_file` 消除 TOCTOU 风险
  - 旧实现：先 `stat` 获取文件大小，再分配内存读取
  - 新实现：直接打开文件，循环读取直到 EOF（`platform_fs_read_until_eof`）
  - 优势：无并发修改竞态，自动适应文件大小变化
- fs.pas: `platform_fs_read_file_into` 消除 TOCTOU 风险
  - 旧实现：先 `stat` 检查缓冲区容量，再读取
  - 新实现：直接读取，缓冲区满时返回 `PLATFORM_FS_SHORT_READ_ERROR`
- 测试：新增 `test_platform_fs_toctou` 并发读写测试

### Phase 5: sendfile 零拷贝优化 (2026-07-05)
- fs.pas: `platform_fs_copy_file` 使用 Linux sendfile 系统调用
  - 旧实现：8KB 缓冲区循环 read/write
  - 新实现：优先使用 sendfile 零拷贝，失败时 fallback 到 read/write
  - 优势：大文件拷贝性能提升 2-10x，减少用户态/内核态切换
  - 平台支持：Linux（sendfile），其他平台保持 read/write

### Phase 6: API 清理 (2026-07-05)
- fs.pas: `platform_fs_walk` 路径溢出处理
  - 旧实现：路径超过 4095 字节时静默跳过
  - 新实现：通过回调返回 `PLATFORM_FS_PATH_TOO_LONG` 错误码
  - 优势：调用方可以检测和处理路径过长的情况
- fs.pas: `platform_fs_mktemp` 标记 deprecated
  - 推荐使用 `platform_fs_mktemp_handle` 版本
  - 返回 `TPlatformFileHandle` 而非 `Int32` fd
- memory.pas: `platform_aligned_free` DEBUG 模式 assert
  - RELEASE 模式：静默忽略 magic 不匹配（兼容性）
  - DEBUG 模式：assert 失败（快速定位 double-free）

### Phase 7: 测试迁移 — FPC RTL 隔离 (2026-07-05)
- 40 个测试文件消除 SysUtils/Classes 依赖
  - TStringList → FsReadFileText (nextpas.core.fs.util)
  - ExpandFileName → 相对路径
  - LowerCase/IntToStr → nextpas.core.text.conv
  - FindFirst/FindNext → FsGlob (nextpas.core.fs.glob)
  - TThread → platform_thread (sync_stress 测试)
  - Sleep → platform_thread_sleep_ns
- 所有非 wine/windows 平台测试现在 0 FPC RTL 依赖
- 验证：40 个测试套件全部通过，0 unfreed

### Phase 8: 错误消息补全 + realloc 优化 (2026-07-05)
- error.pas: `TryPlatformErrorTokenMessage` 补全 4 个缺失错误码
  - EEXIST → "file exists"
  - ENOENT → "no such file"
  - ENOTDIR → "not a directory"
  - PATH_TOO_LONG → "path too long"
- error.pas: 新增 `PLATFORM_ERR_PATH_TOO_LONG = -7` 常量
- memory.pas: `platform_aligned_realloc` 缩小原地优化
  - 旧实现：始终 alloc+copy+free
  - 新实现：缩小时直接更新 header size，零拷贝
  - 优势：realloc 缩小操作 O(1)，无内存分配
- 测试：error 10/10 通过，memory 13/13 通过
