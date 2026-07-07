# Platform Module API Reference

> Generated: 2026-06-16
> Module: `nextpas.core.platform.*`

## Architecture

```
L0: nextpas.core.platform.{posix,windows,darwin,freebsd,linux,unix}.base.pas  ← FFI types/constants
    nextpas.core.platform.{posix,windows,darwin,freebsd,linux}.ffi.pas        ← Foreign bindings
L1: nextpas.core.platform.{files,sync,io,socket,memory,random,...}.pas        ← Unified facade
```

All functions return `Int32` error codes (0 = success). Platform-specific
implementations are selected via `{$IFDEF}` blocks. Unimplemented platforms
return stub values.

## Modules

### platform.files — File Operations

| Function | Description |
|----------|-------------|
| `platform_file_open` | Open file with mode/creation flags |
| `platform_file_open_ex` | Open with append/sync/perm options |
| `platform_file_close` | Close file handle |
| `platform_file_read` | Read bytes from file |
| `platform_file_write` | Write bytes to file |
| `platform_file_pread` | Positional read (no seek) |
| `platform_file_pwrite` | Positional write (no seek) |
| `platform_file_seek` | Seek to position |
| `platform_file_sync` | Fsync/fdatasync |
| `platform_file_truncate` | Truncate file to size |
| `platform_file_stat/lstat/fstat` | File metadata |
| `platform_file_chmod` | Change permissions |
| `platform_file_mkdir` | Create directory |
| `platform_file_rmdir` | Remove directory |
| `platform_file_unlink` | Delete file |
| `platform_file_rename` | Rename file |
| `platform_file_lock/trylock/unlock` | Advisory file locking |
| `platform_file_symlink/readlink` | Symbolic links |
| `platform_dir_open/read/close` | Directory iteration |

### platform.fs — High-level Filesystem

| Function | Description |
|----------|-------------|
| `platform_fs_exists` | Check file/dir existence |
| `platform_fs_is_file/is_dir/is_symlink` | Type checks |
| `platform_fs_is_executable` | Executable permission check |
| `platform_fs_mkdir_p` | Recursive mkdir |
| `platform_fs_copy_file` | Copy file (copy_file_range on Linux) |
| `platform_fs_write_atomic` | Atomic write via temp+rename |
| `platform_fs_read_file` | Read entire file into buffer |
| `platform_fs_walk` | Recursive directory walk |

### platform.sync — Synchronization Primitives

| Function | Description |
|----------|-------------|
| `platform_mutex_init/destroy/lock/trylock/unlock` | Pthread mutex |
| `platform_rwlock_init/destroy/rdlock/wrlock/tryrdlock/trywlock/rdunlock/wrunlock` | Pthread rwlock |
| `platform_condvar_init/destroy/wait/signal/broadcast` | Condition variables |
| `platform_wait_address/wait_address64` | Futex-based address wait |
| `platform_wake_address_one/all` | Wake waiters |

### platform.socket — Network Sockets

| Function | Description |
|----------|-------------|
| `platform_socket_create/close` | Socket lifecycle |
| `platform_socket_bind/listen/accept/connect` | TCP connection |
| `platform_socket_send/recv` | Stream I/O |
| `platform_socket_sendto/recvfrom` | Datagram I/O |
| `platform_socket_shutdown` | Half-close |
| `platform_socket_setsockopt` | Set socket option |
| `platform_socket_set_nonblocking` | Non-blocking mode |
| `platform_socket_set_timeout` | Send/recv timeout |
| `platform_socket_resolve_ipv4/ipv6` | DNS resolution |
| `platform_sockaddr_ipv4/ipv6` | Address construction |
| `platform_sockaddr_loopback4/6` | Loopback addresses |

**Constants:** `PLATFORM_AF_INET6`, `PLATFORM_SOCK_DGRAM`, `PLATFORM_SO_REUSEPORT`,
`PLATFORM_SO_LINGER`, `PLATFORM_TCP_NODELAY`, `PLATFORM_SO_KEEPALIVE`

### platform.io — I/O Multiplexing

| Function | Description |
|----------|-------------|
| `platform_poller_create/close` | Poller lifecycle (epoll/kqueue/IOCP) |
| `platform_poller_add/modify/remove` | Registration |
| `platform_poller_wait` | Wait for events (stack-allocated for ≤256) |
| `platform_poller_enable_wake/wake/drain_wake` | Cross-thread wakeup |

### platform.time — High-resolution Timing

| Function | Description |
|----------|-------------|
| `platform_monotonic_ns` | Monotonic clock (nanoseconds) |
| `platform_realtime_ns` | Wall clock (nanoseconds) |
| `platform_monotonic_resolution_ns` | Clock resolution |
| `platform_qpc_to_ns` | Windows QPC conversion |
| `platform_utc_offset_seconds` | UTC offset |
| `platform_time_breakdown_utc` | Decompose timestamp |

### platform.memory — Memory Management

| Function | Description |
|----------|-------------|
| `platform_aligned_alloc/realloc/free` | Aligned allocation |
| `platform_secure_zero_memory` | Secure zero (explicit_bzero on POSIX) |

### platform.random — Cryptographic Random

| Function | Description |
|----------|-------------|
| `platform_random_bytes` | Fill buffer with random bytes |
| | Linux: getrandom, macOS: arc4random, Windows: BCryptGenRandom+RtlGenRandom fallback |

### platform.process — Process Management

| Function | Description |
|----------|-------------|
| `platform_process_spawn/spawn_fds/run` | Process creation |
| `platform_process_wait/try_wait` | Wait for exit |
| `platform_process_detach` | Detach process |
| `platform_process_signal/kill` | Send signal |
| `platform_process_pid` | Get PID |
| `platform_process_create_pipe/open_null` | I/O setup |

### platform.env — Environment Variables

| Function | Description |
|----------|-------------|
| `platform_env_get` | Get environment variable value |
| `platform_env_set` | Set environment variable |
| `platform_env_unset` | Remove environment variable |
| `platform_env_exists` | Check if variable exists |
| `platform_env_enumerate` | Iterate all variables via callback |
| `platform_env_names_case_sensitive` | Whether names are case-sensitive |
| `platform_env_get_str` | Get as AnsiString (convenience) |
| `platform_env_name_valid` | Validate variable name |

### platform.path — Path Operations

| Function | Description |
|----------|-------------|
| `platform_path_join/join3` | Join 2 or 3 path components |
| `platform_path_dirname` | Extract directory part |
| `platform_path_basename/basename_ptr` | Extract filename part |
| `platform_path_extension/extension_ptr` | Extract file extension |
| `platform_path_change_ext` | Change file extension |
| `platform_path_is_absolute` | Check if path is absolute |
| `platform_path_is_root` | Check if path is a root |
| `platform_path_normalize` | Normalize path (collapse `.`/`..`) |
| `platform_path_relative` | Compute relative path |
| `platform_path_resolve` | Resolve to absolute path |
| `platform_path_ensure_sep/trim_sep` | Ensure/trim trailing separator |

### platform.mmap — Memory Mapping

| Function | Description |
|----------|-------------|
| `platform_mmap_file` | Map file into memory (read-only) |
| `platform_mmap_open_file` | Map file with access mode |
| `platform_mmap_create_anonymous` | Create anonymous mapping |
| `platform_mmap_flush` | Flush dirty pages |
| `platform_mmap_lock/unlock` | Lock/unlock pages in memory |
| `platform_mmap_close` | Unmap and close |
| `platform_mmap_page_size` | Get system page size |
| `platform_shm_create/open/close` | POSIX shared memory |

### platform.signal — Signal Handling

| Function | Description |
|----------|-------------|
| `platform_signal_set` | Install signal handler |
| `platform_signal_ignore` | Ignore signal |
| `platform_signal_reset` | Reset to default handler |
| `platform_signal_block/unblock` | Block/unblock signal delivery |

### platform.console — Console I/O

| Function | Description |
|----------|-------------|
| `platform_console_is_terminal` | Check if fd is a terminal |
| `platform_console_get_size/get_size_fd` | Get terminal dimensions |
| `platform_console_enable_ansi` | Enable ANSI escape sequences |
| `platform_console_set_raw/restore_raw` | Enter/exit raw mode |
| `platform_console_read/write` | Read/write console I/O |
| `platform_console_wait_readable` | Poll for readable data |

### platform.dl — Dynamic Library Loading

| Function | Description |
|----------|-------------|
| `platform_dl_open` | Load shared library (dlopen/LoadLibrary) |
| `platform_dl_sym` | Lookup symbol address |
| `platform_dl_close` | Unload library |
| `platform_dl_error` | Get last error message |

### platform.pipe — Pipe Operations

| Function | Description |
|----------|-------------|
| `platform_pipe_create` | Create pipe pair |
| `platform_pipe_close_read/close_write` | Close individual ends |
| `platform_pipe_close` | Close both ends |
| `platform_dup2` | Duplicate file descriptor |

### platform.watch — File System Watching

| Function | Description |
|----------|-------------|
| `platform_watch_create` | Create watcher (inotify/FSEvents) |
| `platform_watch_add` | Add path to watch |
| `platform_watch_poll` | Poll for events |
| `platform_watch_close` | Destroy watcher |

### platform.pty — Pseudo-Terminal

| Function | Description |
|----------|-------------|
| `platform_pty_open` | Open PTY pair |
| `platform_pty_spawn` | Spawn process in PTY |
| `platform_pty_resize` | Resize PTY window |
| `platform_pty_close` | Close PTY |
| `platform_pty_master_fd` | Get master file descriptor |

### platform.resource — Resource Limits

| Function | Description |
|----------|-------------|
| `platform_resource_get_limit` | Get resource limit |
| `platform_resource_set_limit` | Set resource limit |

### platform.secure — Secure Operations

| Function | Description |
|----------|-------------|
| `platform_secure_zero` | Secure memory zeroing (explicit_bzero) |

### platform.fmt — Formatting & Parsing

| Function | Description |
|----------|-------------|
| `platform_fmt_int/uint/hex/float` | Format numeric values to string |
| `platform_fmt_buf` | Printf-style formatting |
| `platform_parse_int/uint/hex/float` | Parse string to numeric values |
| `platform_str_lower/upper/trim` | String case/whitespace operations |
| `platform_str_equal_nocase` | Case-insensitive comparison |
| `platform_str_find/starts_with` | String search |

### platform.args — Command-line Arguments

| Function | Description |
|----------|-------------|
| `platform_args_count` | Get argument count |
| `platform_args_get` | Get argument by index |
| `platform_args_exe_path` | Get executable path |

### platform.which — Executable Lookup

| Function | Description |
|----------|-------------|
| `platform_which` | Find executable in PATH |

### platform.info — System Information

| Function | Description |
|----------|-------------|
| `CurrentOS` | Get OS kind (enum) |
| `CurrentCPU` | Get CPU architecture (enum) |
| `CurrentEndian` | Get byte order (enum) |
| `OSName/CPUName` | Get human-readable names |

### platform.error — Error Handling

| Function | Description |
|----------|-------------|
| `platform_error_message` | Get error message string |
| `platform_error_category` | Classify error (general/io/net/process/memory/thread/sync) |
| `platform_fatal/fatal_code` | Fatal error with message (stderr + exit) |

## Cross-platform Status

| Platform | Compile | Runtime | Notes |
|----------|---------|---------|-------|
| Linux x86_64 | ✅ | ✅ 170/170 | Primary target |
| Linux aarch64 | ✅ | — | Compile gate only |
| Linux riscv64 | ✅ | — | Compile gate only |
| Windows x86_64 | ✅ | ✅ Wine | Compile gate + Wine smoke |
| macOS | ✅ | — | Source contract only |
| FreeBSD | ✅ | — | Source contract only |
| Android | ✅ | — | Compile gate only |
