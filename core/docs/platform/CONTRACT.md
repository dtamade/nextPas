# nextpas.core.platform 代码契约

**模块路径**：`core/src/nextpas.core.platform*.pas`（60+ 个源文件）
**层级**：L0 — host FFI（`platform.*.base` / `*.ffi`）+ `core.base` / `errors` / `exception`
**FPC RTL**：生产/测试/示例 **禁止** `uses SysUtils` / `BaseUnix` / `Windows` / `Classes` 等 FPC RTL。
仅 `nextpas.core.system` 允许直接引用 FPC RTL（仓库级编译器无关性原则）。
**Owner**：platform lane（`.worktrees/platform`）
**最后更新**：2026-08-31
**版本**：2.4

### 0.1 审计闭环不变量（2026-08-31）

- **console read/write**：value/sentinel；失败 `-1`；禁止正 `PLATFORM_ERR_*` 冒充字节数。
- **L0 堆**：platform 可用 System `GetMem`/`FreeMem`；**不得** `uses nextpas.core.mem`。
- **dual-IO**：`platform_io_*` 符号仅 `platform.process` 拥有；无新 call site。
- **freetype/x11**：optional host binding，非 OS 契约核心；迁出需独立 lane。
- **process/socket/sync 巨型单元**：本轮不物理拆分；拆包为后续 ROADMAP D5 / F-004 延期 batch，按需拆分（无消费者痛点不展开，见 `ROADMAP.md §5/D5`）。

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 | 主要 API |
|------|------|----------|
| platform.pas | 门面 re-export | — |
| platform.base.pas | TOSKind, TCPUArch, TEndianness | — |
| platform.error.pas | 错误码常量 + 消息映射 + last-error | PLATFORM_ERR_*, platform_error_message, platform_get_last_error, platform_get_last_os_error |
| platform.info.pas | OS/架构/字节序检测 | CurrentOS, CurrentCPU, OSName, CPUName |
| platform.time.pas | 时间 API | platform_monotonic_ns, platform_realtime_ns |
| platform.process.pas (`platform_io_*`) | 过渡 fd I/O 定义（无生产外呼；value/sentinel） | platform_io_read/write/poll 定义；close 为 error-code；pipe 走 files + PipePoll |
| platform.files.pas | 文件操作 | platform_file_open, platform_file_stat, platform_dir_open |
| platform.fs.pas | 文件系统高级操作 | platform_fs_mkdir_p, platform_fs_copy_file, platform_fs_walk |
| platform.path.pas | 路径操作 | platform_path_join, platform_path_dirname |
| platform.pipe.pas | 管道操作 | platform_pipe_create, platform_pipe_close |
| platform.dl.pas | 动态库加载 | platform_dl_open, platform_dl_sym |
| platform.socket.pas | 网络 Socket | platform_socket_create, platform_socket_create_tcp, platform_socket_connect |
| platform.process.pas | 进程管理 | platform_process_spawn, platform_process_wait, platform_process_*_ex |
| platform.signal.pas | 信号处理 | platform_signal_set, platform_signal_block |
| platform.thread.pas | 线程管理 | platform_thread_create, platform_thread_join |
| platform.sync.pas | 同步原语 | platform_mutex_*, platform_rwlock_*, platform_condvar_* |
| platform.memory.pas | 内存分配 | platform_aligned_alloc, platform_aligned_realloc |
| platform.mmap.pas | 内存映射 | platform_mmap_file, platform_mmap_close, platform_shm_create |
| platform.env.pas | 环境变量 | platform_env_get, platform_env_set（`env_get_str` 为 FPC managed 便捷面） |
| platform.args.pas | 命令行参数 | platform_args_count, platform_args_get |
| platform.console.pas | 控制台 I/O | platform_console_read/write (**-1** 失败), set_raw, get_size |
| platform.random.pas | 随机数 | platform_random_bytes |
| platform.resource.pas | 资源限制 | platform_resource_get_limit, platform_resource_set_limit |
| platform.secure.pas | 安全操作 | platform_secure_zero |
| platform.fmt.pas | 格式化/解析 | platform_fmt_int/uint/hex/float/buf, platform_parse_*, platform_str_* |
| platform.watch.pas | 文件监控 | platform_watch_create |
| platform.which.pas | 可执行文件查找 | platform_which |
| platform.pty.pas | 伪终端 | platform_pty_open |
| platform.freetype.pas | FreeType 可选宿主绑定（D3.d：保留在 platform；迁出需独立 owner lane） | ft_load, ft_unload, ft_is_loaded |

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
function platform_file_read(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesRead: PtrUInt): Int32;
function platform_file_write(const AHandle: TPlatformFileHandle; ABuf: Pointer;
  ALen: PtrUInt; out ABytesWritten: PtrUInt): Int32;
function platform_file_close(var AHandle: TPlatformFileHandle): Int32;

// 进程
function platform_process_spawn(const APath: PAnsiChar; AArgv: PPAnsiChar;
  AEnvp: PPAnsiChar; out AProc: TPlatformProcess): Int32;
function platform_process_wait(const AProc: TPlatformProcess;
  out AResult: TPlatformProcessResult; ATimeoutMs: Int64 = 0): Int32;

// 进程管道 IO（规范错误码 API；0 = 成功）
function platform_process_write_stdin_ex(AStdinWrite: PtrInt;
  AData: PAnsiChar; ALen: Int32; out ABytesWritten: Int32): Int32;
function platform_process_read_stdout_ex(AStdoutRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
function platform_process_read_stderr_ex(AStderrRead: PtrInt;
  ABuf: PAnsiChar; ABufLen: Int32; out ABytesRead: Int32): Int32;
// 兼容旧 API（deprecated）：成功返回字节数；失败返回 -1；
// unsupported 平台返回 PLATFORM_ERR_UNSUPPORTED。
// 新代码必须使用 *_ex。

// 线程
function platform_thread_create(out AHandle: TPlatformThreadHandle;
  AProc: TPlatformThreadProc; AArg: Pointer): Int32;
function platform_thread_join(const AHandle: TPlatformThreadHandle;
  out ARetVal: Pointer): Int32;

// 同步
function platform_mutex_init(var AMutex: TPlatformMutex;
  const AKind: Int32 = PLATFORM_MUTEX_ERRORCHECK): Int32;
function platform_mutex_lock(var AMutex: TPlatformMutex): Int32;
function platform_mutex_unlock(var AMutex: TPlatformMutex): Int32;

// 内存
function platform_aligned_alloc(ASize, AAlignment: SizeUInt): Pointer;
function platform_aligned_realloc(APtr: Pointer; ANewSize, AAlignment: SizeUInt): Pointer;
```

---

## 2. 不变量

### 2.1 三类返回语义（必须区分）

完整表见 [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md)。

| 类别 | 约定 | 示例 |
|------|------|------|
| **Error-code APIs** | `Int32`：`0` = 成功；`PLATFORM_ERR_*` = 失败；禁止 bare `-1` 作为错误码 | `platform_file_open`, `platform_process_write_stdin_ex`, `platform_resource_get_limit` |
| **Length / size APIs** | `>= 0` = 长度；失败返回 `PLATFORM_ERR_*` | `platform_args_get`, `platform_error_message`, `platform_fs_temp_dir` |
| **Value / sentinel APIs** | 业务值；无效用 sentinel（`-1`/`nil`） | `platform_pty_master_fd`、`platform_io_read` 字节数、`platform_aligned_alloc` |

禁止在 **Error-code API** 失败路径返回无语义 `-1`。Legacy 长度包装可以保留 `-1`，但必须 `deprecated` 并指向 `*_ex`。

### 2.2 其它不变量

- **句柄无效值**: `TPlatformFileHandle.Value = -1`（Unix）/ `INVALID_HANDLE_VALUE`（Windows）
- **Socket 句柄**: >= 0（Unix）/ > 0（Windows）
- **文件描述符**: 0/1/2 保留给 stdin/stdout/stderr
- **内存分配**: 返回 `Pointer`，`nil` 表示失败
- **字符串参数**: 所有 `PAnsiChar` 参数接受 nil（返回 `PLATFORM_ERR_INVALID`，除非语义允许空/零长度）
- **out 参数**: Error-code API 在 early-exit 前必须初始化 out 结果（字节数/句柄等）

---

## 3. 错误处理

- **不抛异常**: 所有平台调用返回 `Int32` 错误码
- **错误码**: `PLATFORM_ERR_*` 常量（`nextpas.core.platform.error`）
  - `PLATFORM_ERR_INVALID` (22) — 无效参数/nil 指针
  - `PLATFORM_ERR_ENOENT` (2) — 文件不存在
  - `PLATFORM_ERR_EEXIST` (17) — 文件已存在
  - `PLATFORM_ERR_ENOTDIR` (20) — 不是目录
  - `PLATFORM_ERR_BADF` (9) — 无效文件描述符
  - `PLATFORM_ERR_TIMEOUT` (110) — 操作超时
  - `PLATFORM_ERR_BUSY` (16) — 资源忙
  - `PLATFORM_ERR_AGAIN` (11) — 资源暂时不可用
  - `PLATFORM_ERR_UNSUPPORTED` (95) — 不支持的操作
  - `PLATFORM_ERR_PATH_TOO_LONG` (-7) — 路径超过 PLATFORM_FS_MAX_PATH（域钳制，非 OS ENAMETOOLONG）
  - `PLATFORM_ERR_UNKNOWN` (-8) — 宿主原生错误无法映射（Windows 禁止 raw ERROR_* 透传）
  - `PLATFORM_ERR_IO` (5) — I/O 错误；`PLATFORM_FS_SHORT_READ/WRITE_ERROR` 为其 **alias**（无平行 -5/-6）
- **错误消息**: `platform_error_message` 是 length API：成功返回写入字节数，失败返回 `PLATFORM_ERR_*`
- **错误分类**: `platform_error_category(ACode)` 返回 `TErrorCategory`（`nextpas.core.exception`）
- **单一错误族**: 资源限制等 API 同样返回 `PLATFORM_ERR_*`，无独立 `PLATFORM_RESOURCE_ERROR_*` 公共语言
- **RTL 隔离**: 生产/测试/示例 platform 不得 `uses` FPC RTL；`platform.args` 不得依赖 `ParamCount`/`ParamStr`
- **parse 失败**: `platform_parse_*` 返回 `PLATFORM_ERR_INVALID`，禁止 bare `-1` 作为错误码
- **length 失败**: `platform_fmt_*` / `platform_dl_error` / `platform_error_message` 等 length API 失败返回 `PLATFORM_ERR_*`（禁止 bare `-1`，deprecated 包装除外）
- **out-init**: error-code + `out` 参数在宿主调用前写 sentinel（见 RETURN-SEMANTICS §13）
- **convenience managed API**: `platform_env_get_str` 等返回 `AnsiString` 的接口为 **FPC 便捷面**，非稳定 C ABI；可移植核心路径优先 `PAnsiChar` buffer API
- **文档权威**: API 目录以 `API-REFERENCE.md` 为准；`api-reference.md` 仅为 redirect；示例以 `EXAMPLES.md` / `BEST-PRACTICES.md`（live）为准

### 3.1 files / fs / io 边界

- **files**: 句柄与目录原语
- **fs**: 路径级组合（可调用 files）
- **io**: poller；`process` 内 `platform_io_*` 为 value/sentinel 过渡 API

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

## 6. 平台支持（证据语言，对齐 goal-tree）

| 平台 | Truth tier | 证据 |
|------|------------|------|
| Linux x86_64 | focused-runtime | 本地 focused gates + heaptrc |
| Linux aarch64 / arm32 / riscv64 | forced-compile | cross-compile gates；runtime 非全覆盖 |
| Windows x86_64 | wine-runtime-smoke + 部分 focused-runtime | Wine smoke；真机 runtime 偏 io/socket |
| macOS / FreeBSD | source-contract / selected compile | 无完整 runtime ready 声称 |
| Android | forced-compile / source-contract | files/mmap 等片段 |
| Fallback stub | compile-coherent | 返回 `PLATFORM_ERR_UNSUPPORTED` |

详细矩阵见 `goal-tree.md` 与 `runtime-truth-matrix.md`。

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
- process.pas: `ATimeoutMs: Int64` 参数（Unix 轮询 + Windows 原生）
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

### Phase 9: Timeout 类型统一 (2026-07-06)
- 所有 `ATimeoutMs` 参数统一为 `Int64` 类型
  - console.pas: `platform_console_wait_readable` — `ATimeoutMs: Int32` → `Int64`
  - io.pas: `platform_poller_wait` — `ATimeoutMs: Int32` → `Int64`
  - process.pas: `platform_process_wait` — `ATimeoutMs: Int32` → `Int64`
  - watch.pas: `platform_watch_poll` — `ATimeoutMs: Int32` → `Int64`
  - socket.pas: `platform_socket_set_timeout` — `AMs: UInt32` → `ATimeoutMs: Int64`
- sync.pas: `ATimeoutNs: Int64` 保持不变（纳秒精度是同步原语的刚需）
- thread.pas: `ATimeoutMs: Int64` 已经是正确类型
- 测试：所有 33 个测试套件通过，0 unfreed

### Phase 10: TPlatformDuration 设计决策 (2026-07-06)
- **决策**: 不引入 `TPlatformDuration` 类型，保持 `Int64` 参数
- **原因**:
  1. 平台模块是 L0 层，应保持最小化和低级抽象
  2. `TDuration` 类型已在 L1 层 (`nextpas.core.time.base`) 定义
  3. 平台模块不能依赖 L1 层（会创建循环依赖）
  4. `Int64` 参数简单高效，符合 L0 层的设计原则
- **方案**:
  1. 平台模块继续使用 `Int64` 参数（ms 或 ns）
  2. 高层模块使用 `TDuration` 类型，调用平台函数时转换为 `Int64`
  3. 文档明确参数单位（ms 或 ns）
- **对标**:
  - Rust: `std::time::Duration` 在标准库层，系统调用层使用 `timespec`
  - Go: `time.Duration` 在标准库层，系统调用层使用 `int64` 纳秒
  - nextPas: `TDuration` 在 L1 层，平台层使用 `Int64`

### Phase 11: 高阶封装 API 设计决策 (2026-07-06)
- **决策**: 不在平台模块添加 `read_all`/`write_all`/`send_all` 等高阶封装
- **原因**:
  1. 平台模块是 L0 层，应保持最小化和低级抽象
  2. `platform_fs_read_all` 和 `platform_fs_write_all` 已在 `nextpas.core.platform.fs` 中实现
  3. Socket 的 `send_all`/`recv_all` 应在 L1/L2 层实现（如 `nextpas.core.net`）
  4. 平台模块只提供低级系统调用封装
- **方案**:
  1. 平台模块保持当前的低级 API（`platform_socket_send`/`platform_socket_recv`）
  2. 高层模块实现便利函数（`send_all`/`recv_all`）
  3. 文档明确 API 边界
- **对标**:
  - Rust: `std::io::Write::write_all` 在标准库层，系统调用层使用 `write`
  - Go: `io.WriteFull` 在标准库层，系统调用层使用 `write`
  - nextPas: 高阶封装在 L1/L2 层，平台层使用 `send`/`recv`

### Phase 12: -1 返回值统一 (2026-07-06)
- **目标**: 将参数验证和内存分配失败的 `-1` 返回值替换为语义化的 `PLATFORM_ERR_*` 常量
- **修改范围**: 10 个文件，39 个 `-1` 返回值
  - `args.pas`: 3 个参数验证 → `PLATFORM_ERR_INVALID`
  - `error.pas`: 1 个参数验证 → `PLATFORM_ERR_INVALID`
  - `thread.pas`: 5 个参数验证 → `PLATFORM_ERR_INVALID`
  - `fs.pas`: 6 个参数验证/内存分配 → `PLATFORM_ERR_INVALID`
  - `console.pas`: 2 个参数验证 → `PLATFORM_ERR_INVALID`
  - `fmt.pas`: 5 个参数验证/缓冲区 → `PLATFORM_ERR_INVALID`
  - `path.pas`: 3 个参数验证/缓冲区 → `PLATFORM_ERR_INVALID`
  - `files.pas`: 1 个参数验证 → `PLATFORM_ERR_INVALID`
  - `socket.pas`: 4 个错误处理 → `PLATFORM_ERR_INVALID`
  - `watch.pas`: 1 个错误处理 → `PLATFORM_ERR_BADF`
- **保留 -1 的场景**:
  - "未找到"指示器（如 `platform_str_find` 返回 -1 表示未找到）
  - 无效文件描述符（如 `platform_pty_master_fd` 返回 -1 表示无效 fd）
  - 错误条件（如 `platform_fs_mktemp` 失败时返回 -1）
- **测试**: 所有平台测试通过，0 unfreed
- **契约检查**: 26 通过，0 失败，1 警告（5 个合法 -1 返回）
