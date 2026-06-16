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
