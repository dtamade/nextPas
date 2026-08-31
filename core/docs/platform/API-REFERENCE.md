# Platform API 参考手册

**日期**: 2026-07-06
**更新**: 2026-08-31 (同步 CONTRACT v2.4；wave-4 + 时效校正)
**版本**: v1.4
**模块数**: 24
**API数**: ~1067

**Authority companions** (do not invent names from this catalog alone):

- Errors: [ERROR-HANDLING.md](ERROR-HANDLING.md) + `nextpas.core.platform.error.pas`
- Return tiers / out-init / length / dual-IO: [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md)
- Module table (live names): [CONTRACT.md](CONTRACT.md)
- Examples: [EXAMPLES.md](EXAMPLES.md), [BEST-PRACTICES.md](BEST-PRACTICES.md)

---

## 1. args — 命令行参数

| 函数 | 说明 |
|------|------|
| `platform_args_count: Int32` | 获取参数个数 |
| `platform_args_get(AIndex, ABuf, ABufSize): Int32` | 获取指定索引的参数 |
| `platform_args_exe_path(ABuf, ABufSize): Int32` | 获取可执行文件路径 |

## 2. console — 控制台 I/O

| 函数 | 说明 |
|------|------|
| `platform_console_is_terminal(AFd): Boolean` | 判断是否为终端 |
| `platform_console_get_size(out ASize): Int32` | 获取终端大小(stdout) |
| `platform_console_get_size_fd(AFd, out ASize): Int32` | 获取指定 fd 的终端大小 |
| `platform_console_enable_ansi: Int32` | 启用 ANSI 转义序列(Windows) |
| `platform_console_set_raw(AFd, out AMode): Int32` | 设置原始模式 |
| `platform_console_restore_raw(AFd, AMode): Int32` | 恢复终端模式 |
| `platform_console_read(AFd, ABuf, ACount): Int32` | 从终端读取；**value/sentinel**：成功 `>=0` 字节，失败 **`-1`**（勿把正 `PLATFORM_ERR_*` 当字节数） |
| `platform_console_write(AFd, ABuf, ACount): Int32` | 写入终端；同上 value/sentinel |
| `platform_console_wait_readable(AFd, ATimeoutMs): TPlatformConsoleWait` | 等待数据可读 |

## 3. dl — 动态库加载

| 函数 | 说明 |
|------|------|
| `platform_dl_open(APath, AFlags, out ALib): Int32` | 打开动态库 |
| `platform_dl_sym(ALib, AName, out AProc): Int32` | 查找符号 |
| `platform_dl_close(var ALib): Int32` | 关闭动态库 |
| `platform_dl_error(ABuf, ABufSize): Int32` | 获取错误信息 |

## 4. env — 环境变量

| 函数 | 说明 |
|------|------|
| `platform_env_get(AName, ABuf, ABufSize, out ALen): Int32` | 获取环境变量 |
| `platform_env_set(AName, AValue): Int32` | 设置环境变量 |
| `platform_env_unset(AName): Int32` | 删除环境变量 |
| `platform_env_exists(AName): Boolean` | 检查环境变量是否存在 |
| `platform_env_enumerate(ACallback, AUserData): Int32` | 遍历所有环境变量 |
| `platform_env_names_case_sensitive: Boolean` | 名称是否区分大小写 |
| `platform_env_get_str(AName): AnsiString` | **FPC managed 便捷面**（非稳定 C ABI）；可移植路径优先 `platform_env_get` buffer API |

## 5. error — 错误处理

| 函数 | 说明 |
|------|------|
| `platform_error_message(ACode, ABuf, ABufSize): Int32` | 获取错误消息 |
| `platform_error_category(ACode): TErrorCategory` | 获取错误分类 |
| `platform_get_last_error: Int32` | 最近一次错误，映射为 `PLATFORM_ERR_*` |
| `platform_get_last_os_error: Int32` | 最近一次宿主原生错误码（`errno` / `GetLastError`，未映射） |
| `platform_fatal(AMsg)` | 致命错误退出 |
| `platform_fatal_code(AMsg, ACode)` | 带错误码的致命退出（退出码按低 8 位截断） |

## 6. fmt — 格式化与解析

| 函数 | 说明 |
|------|------|
| `platform_fmt_int(AValue, ABuf, ABufSize): Int32` | 格式化整数 |
| `platform_fmt_uint(AValue, ABuf, ABufSize): Int32` | 格式化无符号整数 |
| `platform_fmt_hex(AValue, ABuf, ABufSize): Int32` | 格式化十六进制 |
| `platform_fmt_float(AValue, ADecimals, ABuf, ABufSize): Int32` | 格式化浮点数 |
| `platform_parse_int(AStr, ALen, out AValue): Int32` | 解析整数 |
| `platform_parse_uint(AStr, ALen, out AValue): Int32` | 解析无符号整数 |
| `platform_parse_hex(AStr, ALen, out AValue): Int32` | 解析十六进制 |
| `platform_parse_float(AStr, ALen, out AValue): Int32` | 解析浮点数 |
| `platform_str_lower(ASrc, ALen, ADst, ADstSize): Int32` | 转小写 |
| `platform_str_upper(ASrc, ALen, ADst, ADstSize): Int32` | 转大写 |
| `platform_str_trim(ASrc, ALen, ADst, ADstSize): Int32` | 去空白 |
| `platform_str_equal_nocase(A, ALen, B, BLen): Boolean` | 大小写无关比较 |
| `platform_str_find(AHaystack, AHLen, ANeedle, ANLen): Int32` | 查找子串 |
| `platform_str_starts_with(AStr, ALen, APrefix, APLen): Boolean` | 前缀检查 |
| `platform_str_ends_with(AStr, ALen, ASuffix, ASLen): Boolean` | 后缀检查 |

## 7. freetype — FreeType 字体绑定

| 函数 | 说明 |
|------|------|
| `ft_load: Int32` | 加载 FreeType 库 |
| `ft_unload` | 卸载 FreeType 库 |
| `ft_is_loaded: Boolean` | 是否已加载 |

## 8. fs — 文件系统操作

| 函数 | 说明 |
|------|------|
| `platform_fs_exists(APath): Boolean` | 检查路径是否存在 |
| `platform_fs_is_file(APath): Boolean` | 是否为文件 |
| `platform_fs_is_dir(APath): Boolean` | 是否为目录 |
| `platform_fs_is_executable(APath): Boolean` | 是否可执行 |
| `platform_fs_file_size(APath, out ASize): Int32` | 获取文件大小 |
| `platform_fs_temp_dir(ABuf, ABufSize): Int32` | 获取临时目录 |
| `platform_fs_mktemp(APrefix, ASuffix, ABuf, ABufSize): Int32` | 创建临时文件路径 |
| `platform_fs_mktemp_handle(APrefix, ASuffix, out AHandle): Int32` | 创建临时文件句柄 |
| `platform_fs_mkdir_p(APath, AMode): Int32` | 递归创建目录 |
| `platform_fs_copy_file(ASrc, ADst): Int32` | 复制文件 |
| `platform_fs_write_atomic(APath, AData, ASize): Int32` | 原子写入文件 |
| `platform_fs_read_file(APath, out AData, out ASize): Int32` | 读取整个文件 |
| `platform_fs_read_file_into(APath, ABuf, ABufSize): Int32` | 读取文件到缓冲区 |
| `platform_fs_free_buf(AData)` | 释放读取缓冲区 |
| `platform_fs_walk(ARoot, ACallback, AUserData): Int32` | 递归遍历目录 |
| `platform_fs_write_all(AHandle, AData, ASize): Int32` | 写入全部数据 |
| `platform_fs_read_all(AHandle, ABuf, ABufSize): Int32` | 读取全部数据 |
| `platform_fs_read_until_eof(AHandle, out AData, out ASize): Int32` | 读取到 EOF |
| `platform_fs_move_file(ASrc, ADst): Int32` | 移动文件（rename 或 copy+delete） |
| `platform_fs_remove_file(APath): Int32` | 删除文件 |
| `platform_fs_remove_dir(APath): Int32` | 删除空目录 |
| `platform_fs_rename(AOldPath, ANewPath): Int32` | 重命名文件或目录 |

## 9. info — 系统信息

| 函数 | 说明 |
|------|------|
| `CurrentOS: TOSKind` | 获取当前操作系统 |
| `CurrentCPU: TCPUArch` | 获取当前 CPU 架构 |
| `CurrentEndian: TEndianness` | 获取字节序 |
| `OSName: string` | 获取操作系统名称 |
| `CPUName: string` | 获取 CPU 架构名称 |

## 10. io — I/O 多路复用

| 函数 | 说明 |
|------|------|
| `platform_poller_create(out APoller): Int32` | 创建 poller |
| `platform_poller_close(var APoller): Int32` | 关闭 poller |
| `platform_poller_add(var APoller, AFd, AEvents, AUserData): Int32` | 添加 fd |
| `platform_poller_modify(var APoller, AFd, AEvents): Int32` | 修改事件 |
| `platform_poller_remove(var APoller, AFd): Int32` | 移除 fd |
| `platform_poller_enable_wake(var APoller, out AWakeFd): Int32` | 启用唤醒 |
| `platform_poller_wake(var APoller): Int32` | 唤醒 poller |
| `platform_poller_drain_wake(var APoller): Int32` | 清空唤醒事件 |
| `platform_poller_wait(var APoller, AEvents, AMaxEvents, ATimeoutMs): Int32` | 等待事件 |

## 11. memory — 内存管理

| 函数 | 说明 |
|------|------|
| `platform_aligned_alloc(ASize, AAlignment): Pointer` | 对齐分配 |
| `platform_aligned_realloc(APtr, ANewSize, AAlignment): Pointer` | 对齐重分配 |
| `platform_aligned_free(APtr)` | 释放对齐内存 |
| `platform_aligned_alloc_backend: TPlatformAlignedAllocBackend` | 获取分配后端 |
| `platform_aligned_alloc_is_native: Boolean` | 是否为原生实现 |
| `platform_secure_zero_memory_backend: TPlatformSecureZeroBackend` | 获取安全清零后端 |
| `platform_secure_zero_memory_is_native: Boolean` | 是否为原生实现 |
| `platform_secure_zero_memory(APtr, ASize)` | 安全清零内存 |
| `platform_virtual_reserve(ASize): Pointer` | 虚拟内存预留 |
| `platform_virtual_commit(APtr, ASize): Boolean` | 虚拟内存提交 |
| `platform_virtual_decommit(APtr, ASize)` | 虚拟内存反提交 |
| `platform_virtual_release(APtr, ASize)` | 虚拟内存释放 |
| `platform_madvise_thp(APtr, ASize)` | 建议透明大页 |

## 12. mmap — 内存映射

| 函数 | 说明 |
|------|------|
| `platform_mmap_file(APath, out AMap): Int32` | 映射文件 |
| `platform_mmap_open_file(APath, AAccess, out AMap): Int32` | 打开映射文件 |
| `platform_mmap_create_anonymous(ASize, AAccess, out AMap): Int32` | 创建匿名映射 |
| `platform_mmap_flush(var AMap, AOffset, ASize): Int32` | 刷新映射 |
| `platform_mmap_lock(var AMap, AOffset, ASize): Int32` | 锁定映射 |
| `platform_mmap_unlock(var AMap, AOffset, ASize): Int32` | 解锁映射 |
| `platform_mmap_close(var AMap): Int32` | 关闭映射 |
| `platform_mmap_page_size: UInt64` | 获取页面大小 |
| `platform_shm_create(AName, ASize, AAccess, out AMap): Int32` | 创建共享内存 |
| `platform_shm_open(AName, AAccess, out AMap): Int32` | 打开共享内存 |
| `platform_shm_close(var AMap): Int32` | 关闭共享内存 |

## 13. path — 路径操作

| 函数 | 说明 |
|------|------|
| `platform_path_join(ABase, AChild, AOut, AOutSize): Int32` | 连接路径 |
| `platform_path_join3(A, B, C, AOut, AOutSize): Int32` | 三段路径连接 |
| `platform_path_dirname(APath, AOut, AOutSize): Int32` | 获取目录部分 |
| `platform_path_basename(APath, AOut, AOutSize): Int32` | 获取文件名部分 |
| `platform_path_basename_ptr(APath): PAnsiChar` | 获取文件名指针 |
| `platform_path_extension(APath, AOut, AOutSize): Int32` | 获取扩展名 |
| `platform_path_extension_ptr(APath): PAnsiChar` | 获取扩展名指针 |
| `platform_path_change_ext(APath, ANewExt, AOut, AOutSize): Int32` | 修改扩展名 |
| `platform_path_is_absolute(APath): Boolean` | 是否为绝对路径 |
| `platform_path_is_root(APath): Boolean` | 是否为根路径 |
| `platform_path_normalize(APath, AOut, AOutSize): Int32` | 规范化路径 |
| `platform_path_relative(ABase, ATarget, AOut, AOutSize): Int32` | 计算相对路径 |
| `platform_path_resolve(APath, AOut, AOutSize): Int32` | 解析路径 |
| `platform_path_ensure_sep(APath, AOut, AOutSize): Int32` | 确保末尾分隔符 |
| `platform_path_trim_sep(APath, AOut, AOutSize): Int32` | 去除末尾分隔符 |
| `platform_path_same_file_name(ALeft, ARight): Boolean` | 文件名比较 |

## 14. pipe — 管道

| 函数 | 说明 |
|------|------|
| `platform_pipe_create(out APipe): Int32` | 创建管道 |
| `platform_pipe_close_read(var APipe): Int32` | 关闭读端 |
| `platform_pipe_close_write(var APipe): Int32` | 关闭写端 |
| `platform_pipe_close(var APipe): Int32` | 关闭管道 |
| `platform_dup2(AOldFd, ANewFd): Int32` | 复制文件描述符 |

## 14b. process — 进程（节选）

| 函数 | 说明 |
|------|------|
| `platform_process_spawn(...)` | 启动进程 |
| `platform_process_wait` / `try_wait` | 等待退出 |
| `platform_process_create_piped(...)` | 带 stdin/stdout/stderr 管道启动 |
| `platform_process_write_stdin_ex(fd, data, len, out n): Int32` | **规范** stdin 写：`0` 成功 |
| `platform_process_read_stdout_ex(fd, buf, len, out n): Int32` | **规范** stdout 读：`0` 成功；EAGAIN/EOF → n=0 |
| `platform_process_read_stderr_ex(fd, buf, len, out n): Int32` | **规范** stderr 读：同上 |
| `platform_process_write_stdin` / `read_stdout` / `read_stderr` | **deprecated** 兼容包装（字节数/-1） |

## 15. pty — 伪终端

| 函数 | 说明 |
|------|------|
| `platform_pty_open(ASize, out APty): Int32` | 打开伪终端 |
| `platform_pty_spawn(var APty, APath, AArgv, AEnvp, ACwd, out APid, out AFailStage): Int32` | 在 PTY 中启动进程 |
| `platform_pty_resize(var APty, ASize): Int32` | 调整 PTY 大小 |
| `platform_pty_close(var APty): Int32` | 关闭 PTY |
| `platform_pty_master_fd(APty): PtrInt` | 获取 master fd |

## 16. random — 随机数

| 函数 | 说明 |
|------|------|
| `platform_random_bytes(ABuf, ALen): Int32` | 生成随机字节 |

## 17. resource — 资源限制

| 函数 | 说明 |
|------|------|
| `platform_resource_get_limit(AKind, out ALimit): Int32` | 获取资源限制 |
| `platform_resource_set_limit(AKind, ALimit): Int32` | 设置资源限制 |

## 18. secure — 安全内存(已废弃)

| 函数 | 说明 |
|------|------|
| `platform_secure_zero(Buffer, Size)` | 安全清零(已废弃,使用 memory 模块) |

## 19. signal — 信号处理

| 函数 | 说明 |
|------|------|
| `platform_signal_set(ASignal, AHandler, out AOldHandler): Int32` | 设置信号处理 |
| `platform_signal_ignore(ASignal): Int32` | 忽略信号 |
| `platform_signal_reset(ASignal): Int32` | 重置信号处理 |
| `platform_signal_block(ASignal): Int32` | 阻塞信号 |
| `platform_signal_unblock(ASignal): Int32` | 解除信号阻塞 |

## 20. socket — 网络套接字

| 函数 | 说明 |
|------|------|
| `platform_socket_create(ADomain, AType, AProtocol, out ASocket): Int32` | 创建套接字 |
| `platform_socket_close(var ASocket): Int32` | 关闭套接字 |
| `platform_socket_bind(ASocket, AAddr): Int32` | 绑定地址 |
| `platform_socket_listen(ASocket, ABacklog): Int32` | 监听 |
| `platform_socket_accept(ASocket, out AClient, out AAddr): Int32` | 接受连接 |
| `platform_socket_connect(ASocket, AAddr): Int32` | 连接 |
| `platform_socket_send(ASocket, AData, ASize): Int32` | 发送数据 |
| `platform_socket_recv(ASocket, ABuf, ASize): Int32` | 接收数据 |
| `platform_socket_shutdown(ASocket, AHow): Int32` | 关闭连接 |
| `platform_socket_setsockopt(ASocket, ALevel, AOptName, AOptVal, AOptLen): Int32` | 设置选项 |
| `platform_socket_getsockopt(ASocket, ALevel, AOptName, AOptVal, AOptLen): Int32` | 获取选项 |
| `platform_socket_sendto(ASocket, AData, ASize, AAddr): Int32` | 发送到地址 |
| `platform_socket_recvfrom(ASocket, ABuf, ASize, out AAddr): Int32` | 从地址接收 |
| `platform_socket_getsockname(ASocket, out AAddr): Int32` | 获取本地地址 |
| `platform_socket_getpeername(ASocket, out AAddr): Int32` | 获取对端地址 |
| `platform_socket_resolve_ipv4(AHost, out AAddr): Int32` | 解析 IPv4 地址 |
| `platform_socket_pair(ADomain, AType, AProtocol, out AS1, out AS2): Int32` | 创建连接的 socket 对 |
| `platform_socket_set_nonblocking(ASocket, ANonBlocking): Int32` | 设置非阻塞 |
| `platform_socket_set_timeout(ASocket, ATimeoutMs): Int32` | 设置超时 |
| `platform_socket_set_tcp_nodelay(ASocket, AEnable): Int32` | 设置 TCP_NODELAY |
| `platform_socket_set_reuseaddr(ASocket, AEnable): Int32` | 设置 SO_REUSEADDR |
| `platform_socket_set_keepalive(ASocket, AEnable): Int32` | 设置 SO_KEEPALIVE |
| `platform_socket_set_linger(ASocket, AEnable, ALingerSec): Int32` | 设置 SO_LINGER |
| `platform_socket_set_recvbuf(ASocket, ASize): Int32` | 设置 SO_RCVBUF 接收缓冲区 |
| `platform_socket_set_sendbuf(ASocket, ASize): Int32` | 设置 SO_SNDBUF 发送缓冲区 |
| `platform_socket_get_error(ASocket, out AError): Int32` | 获取 SO_ERROR 待处理错误 |
| `platform_socket_error_would_block(AError): Boolean` | 是否为阻塞错误 |
| `platform_socket_error_timed_out(AError): Boolean` | 是否为超时错误 |
| `platform_socket_error_interrupted(AError): Boolean` | 是否为信号打断（EINTR / WSAEINTR，调用方应重试） |
| `platform_sockaddr_ipv4(APort, AAddr): TPlatformSockAddr` | 构造 IPv4 地址 |

## 21. sync — 同步原语

| 函数 | 说明 |
|------|------|
| `platform_mutex_init(var AMutex, AKind): Int32` | 初始化互斥锁 |
| `platform_mutex_destroy(var AMutex): Int32` | 销毁互斥锁 |
| `platform_mutex_lock(var AMutex): Int32` | 加锁 |
| `platform_mutex_trylock(var AMutex): Int32` | 尝试加锁 |
| `platform_mutex_unlock(var AMutex): Int32` | 解锁 |
| `platform_rwlock_init(var ARwLock): Int32` | 初始化读写锁 |
| `platform_rwlock_destroy(var ARwLock): Int32` | 销毁读写锁 |
| `platform_rwlock_rdlock(var ARwLock): Int32` | 读锁 |
| `platform_rwlock_tryrdlock(var ARwLock): Int32` | 尝试读锁 |
| `platform_rwlock_wrlock(var ARwLock): Int32` | 写锁 |
| `platform_rwlock_trywrlock(var ARwLock): Int32` | 尝试写锁 |
| `platform_rwlock_rdunlock(var ARwLock): Int32` | 释放读锁 |
| `platform_rwlock_wrunlock(var ARwLock): Int32` | 释放写锁 |
| `platform_condvar_init(var ACondVar): Int32` | 初始化条件变量 |
| `platform_condvar_destroy(var ACondVar): Int32` | 销毁条件变量 |
| `platform_condvar_wait(var ACondVar, var AMutex): Int32` | 等待条件变量 |
| `platform_condvar_timedwait(var ACondVar, var AMutex, ATimeoutNs): Int32` | 带超时等待 |
| `platform_condvar_signal(var ACondVar): Int32` | 唤醒一个等待者 |
| `platform_condvar_broadcast(var ACondVar): Int32` | 唤醒所有等待者 |
| `platform_wait_address32(AAddr, AExpected, ATimeoutNs): Int32` | 等待地址值变化 |
| `platform_barrier_init(var ABarrier, ACount): Int32` | 初始化屏障 |
| `platform_barrier_destroy(var ABarrier): Int32` | 销毁屏障 |
| `platform_barrier_wait(var ABarrier): Int32` | 等待屏障 |
| `platform_once_init(var AOnce): Int32` | 初始化 once |
| `platform_once_destroy(var AOnce): Int32` | 销毁 once |
| `platform_once_exec(var AOnce, AProc): Int32` | 执行一次性初始化 |

## 22. thread — 线程管理

| 函数 | 说明 |
|------|------|
| `platform_thread_create(out AHandle, AProc, AArg): Int32` | 创建线程 |
| `platform_thread_join(AHandle, out ARetVal): Int32` | 等待线程结束 |
| `platform_thread_timedjoin(AHandle, ATimeoutMs, out ARetVal): Int32` | 带超时等待 |
| `platform_thread_detach(AHandle): Int32` | 分离线程 |
| `platform_thread_self: TPlatformThreadToken` | 获取当前线程 |
| `platform_thread_id: UInt64` | 获取线程 ID |
| `platform_thread_yield` | 让出 CPU |
| `platform_thread_sleep_ns(ANanoseconds)` | 纳秒级睡眠 |
| `platform_thread_sleep_ms(AMilliseconds)` | 毫秒级睡眠 |
| `platform_thread_sleep_sec(ASeconds)` | 秒级睡眠 |
| `platform_tls_create(out AKey): Int32` | 创建 TLS key |
| `platform_tls_destroy(AKey): Int32` | 销毁 TLS key |
| `platform_tls_set(AKey, AValue): Int32` | 设置 TLS 值 |
| `platform_tls_get(AKey): Pointer` | 获取 TLS 值 |
| `platform_cpu_count: Int32` | 获取 CPU 核心数 |
| `platform_thread_set_name(AName): Int32` | 设置当前线程名称（Linux prctl） |
| `platform_thread_get_name(ABuf, ABufSize): Int32` | 获取当前线程名称 |

## 23. time — 时间操作

| 函数 | 说明 |
|------|------|
| `platform_monotonic_ns: TPlatformTimeNanoseconds` | 单调时钟(纳秒) |
| `platform_realtime_ns: TPlatformTimeNanoseconds` | 实时时钟(纳秒) |
| `platform_monotonic_resolution_ns: TPlatformTimeNanoseconds` | 单调时钟分辨率 |
| `platform_qpc_to_ns(AQpc, AFreq): TPlatformTimeNanoseconds` | QPC 转纳秒 |
| `platform_resolution_from_frequency_ns(AFreq): TPlatformTimeNanoseconds` | 频率转分辨率 |
| `platform_timespec_to_ns(ATvSec, ATvNsec): TPlatformTimeNanoseconds` | timespec 转纳秒 |
| `platform_utc_offset_seconds: Int32` | UTC 偏移(秒) |
| `platform_time_breakdown_utc(ANs, out ABreakdown)` | UTC 时间分解 |

## 24. watch — 文件监控

| 函数 | 说明 |
|------|------|
| `platform_watch_create(out AWatcher): Int32` | 创建监控器 |
| `platform_watch_add(var AWatcher, APath): Int32` | 添加监控路径 |
| `platform_watch_poll(var AWatcher, out AEvent, ATimeoutMs): Int32` | 等待事件 |
| `platform_watch_close(var AWatcher): Int32` | 关闭监控器 |

## 25. which — 可执行文件查找

| 函数 | 说明 |
|------|------|
| `platform_which(AName, ABuf, ABufSize): Int32` | 查找可执行文件 |

---

## 错误码常量

Live authority: [`ERROR-HANDLING.md`](ERROR-HANDLING.md) and
`nextpas.core.platform.error.pas`. Success is integer `0` (there is no
OK constant under the PLATFORM_ERR family).

| 常量 | 值 | 说明 |
|------|---:|------|
| *(success)* | 0 | 错误码 API 成功 |
| `PLATFORM_ERR_PERM` | 1 | 操作不允许 |
| `PLATFORM_ERR_NOENT` | 2 | 不存在 |
| `PLATFORM_ERR_INTR` | 4 | 被信号中断 |
| `PLATFORM_ERR_IO` | 5 | I/O 错误 |
| `PLATFORM_ERR_BADF` | 9 | 无效句柄/描述符 |
| `PLATFORM_ERR_AGAIN` | 11 | 暂时不可用 |
| `PLATFORM_ERR_NOMEM` | 12 | 内存不足 |
| `PLATFORM_ERR_BUSY` | 16 | 资源忙 |
| `PLATFORM_ERR_EXIST` | 17 | 已存在 |
| `PLATFORM_ERR_NOTDIR` | 20 | 不是目录 |
| `PLATFORM_ERR_INVALID` | 22 | 无效参数 |
| `PLATFORM_ERR_NOSPC` | 28 | 空间满 |
| `PLATFORM_ERR_PIPE` | 32 | 管道断开 |
| `PLATFORM_ERR_NOSYS` | 38 | 未实现 |
| `PLATFORM_ERR_UNSUPPORTED` | 95 | 不支持 |
| `PLATFORM_ERR_CONNRESET` | 104 | 连接重置 |
| `PLATFORM_ERR_TIMEDOUT` | 110 | 超时（alias `PLATFORM_ERR_TIMEOUT`） |
| `PLATFORM_ERR_CONNREFUSED` | 111 | 连接拒绝 |
| `PLATFORM_ERR_PATH_TOO_LONG` | -7 | 路径过长（域内 `PLATFORM_FS_MAX_PATH`，非 OS ENAMETOOLONG） |
| `PLATFORM_ERR_UNKNOWN` | -8 | 无法映射的宿主原生错误（Windows 未映射码；禁止 raw ERROR_* 透传） |

Do not invent catalog-only error names. Use the live table above and
ERROR-HANDLING; never alias NOT_FOUND/EXISTS/ACCESS/FULL/ABORTED/NETWORK
as separate PLATFORM_ERR identifiers.

---

**文档维护**: 随 platform 模块演进更新（同步 CONTRACT v2.4）
**最后更新**: 2026-08-31
