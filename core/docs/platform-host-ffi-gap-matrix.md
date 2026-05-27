# Platform Host FFI Gap Matrix

This document records the current platform host ABI surface for
`nextpas.core.platform`. It is a source-surface guard companion, not runtime
proof. Runtime behavior tests cover the unified public contracts in
`platform.time`, `platform.sync`, and `platform.thread`; raw OS APIs such as
`clock_gettime`, `pthread_*`, `futex`, POSIX `fork`, `WaitOnAddress`,
`CreateProcessA/W`, `QueryPerformanceCounter`, and `GetSystemTimeAsFileTime`
are accepted from FPC source, copied into host-owned declarations, and guarded
through source-surface integration checks and compile-only gates.

The source evidence route for those declarations is tracked in
`docs/platform-ffi-source-evidence-index.md`. Keep that index, this gap matrix,
and the official verification routes synchronized: FPC source evidence explains
where ABI truth comes from; this matrix records what nextPas currently owns and
which gaps are still deliberate.

The import workflow for expanding this matrix is tracked in
`docs/platform-ffi-import-workflow.md`. Use that workflow before adding a new API
surface or closing a known gap.

## Host Base/FFI Ownership Matrix

Host `base` units own ABI constants, record shapes, opaque carriers, scalar
aliases, and capability tokens. Host `ffi` units own external declarations and
ABI-local helper projections around those declarations; new helpers must use a
host or shared-owner prefix and must not look like a unified public
`platform_*` contract. Feature modules are unified platform contracts and should
not create `platform.time.ffi`, `platform.sync.ffi`, or `platform.thread.ffi`.

| Host | Base owner | FFI owner | Clock | Errno | CPU count | Native thread id | Thread lifecycle | TLS | pthread sync | Timeout capability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Linux | `nextpas.core.platform.linux.base` | `nextpas.core.platform.linux.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 1`, platform clock helpers | `__errno_location`, Linux `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 84` | `gettid` plus `platform_posix_thread_self_token_u64` for self token | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers plus Linux futex wait/wake | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1` |
| Android | `nextpas.core.platform.android.base` | `nextpas.core.platform.android.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 1`, platform clock helpers | Android `__errno`, Android `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 97` | `gettid` plus `platform_posix_thread_self_token_u64` for self token | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1` |
| Darwin | `nextpas.core.platform.darwin.base` | `nextpas.core.platform.darwin.ffi` | POSIX realtime plus Mach monotonic helpers | `__error`, Darwin `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 58` | `pthread_threadid_np`, fallback to `platform_posix_thread_self_token_u64` if needed | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0` |
| FreeBSD | `nextpas.core.platform.freebsd.base` | `nextpas.core.platform.freebsd.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 4`, platform clock helpers | `__error`, FreeBSD `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 58` | `pthread_getthreadid_np`, fallback to `platform_posix_thread_self_token_u64` if needed | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1` |
| generic Unix | `nextpas.core.platform.unix.base` | `nextpas.core.platform.unix.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 1`, platform clock helpers | generic `__errno_location`, generic `PLATFORM_POSIX_E*` fallback values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = -1` | fallback to `platform_posix_thread_self_token_u64` | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0` |
| Windows | `nextpas.core.platform.windows.base` | `nextpas.core.platform.windows.ffi` | Windows kernel32 path: QPC for monotonic time, FILETIME for realtime | `GetLastError` result helpers | `GetSystemInfo` | `GetCurrentThreadId` | `CreateThread`, wait, close, and state refcount helpers | `TlsAlloc`, `TlsFree`, `TlsSetValue`, `TlsGetValue` | `SRWLOCK`, `CONDITION_VARIABLE`, and `WaitOnAddress` helpers | millisecond timeout conversion and kernel32 timeout classifiers |

## Known Gaps

- Platform Host ABI Completeness Wave 6 covers the process-control raw ABI inventory for
  host `base/ffi` owners. Shared POSIX FFI now owns raw `fork`, `execve`,
  `waitpid`, `_exit`, and `kill` declarations only; POSIX host `ffi` units must
  not expose `platform_process_*` helpers in this wave. FPC Unix source directly
  declares those libc bindings through `FpFork`, `FpExecve`, `FpWaitpid`,
  `FpExit`, and `FpKill`. Windows now carries `PROCESS_INFORMATION`, `STARTUPINFOA`,
  `STARTUPINFOW`, `SECURITY_ATTRIBUTES`, Windows ABI aliases, process creation flags and priority class tokens,
  `CreateProcessA`, `CreateProcessW`, `GetStartupInfoA`, `GetStartupInfoW`,
  `TerminateProcess`, `GetExitCodeProcess`, and `ExitProcess` as raw FPC-shaped
  declarations. This remains an integration and compile-coherence guard with no
  public platform.process contract. There is no public platform.process
  contract in this wave.
- Wave 6 source evidence tokens are synchronized with the evidence index:
  `fork`, `execve`, `waitpid`, `_exit`, `kill`, `PROCESS_INFORMATION`,
  `STARTUPINFOA`, `STARTUPINFOW`, `CreateProcessA`, `CreateProcessW`,
  `GetStartupInfoA`, `GetStartupInfoW`, `TerminateProcess`,
  `GetExitCodeProcess`, and `ExitProcess`.
- Platform Host ABI Completeness Wave 7 covers the process wait-status raw ABI
  inventory for host `base` owners and shared POSIX math helpers. POSIX host
  `base` units now carry `WNOHANG`, `WUNTRACED`, `SIGHUP`, `SIGINT`, `SIGKILL`,
  `SIGTERM`, and host-specific `SIGCHLD` as
  `PLATFORM_WAIT_NOHANG`, `PLATFORM_WAIT_UNTRACED`,
  `PLATFORM_SIGNAL_HANGUP`, `PLATFORM_SIGNAL_INTERRUPT`,
  `PLATFORM_SIGNAL_KILL`, `PLATFORM_SIGNAL_TERMINATE`, and
  `PLATFORM_SIGNAL_CHILD`. Linux and Android use `SIGCHLD = 17`; Darwin and
  FreeBSD use `SIGCHLD = 20`; generic Unix keeps the Linux-style fallback until
  a specific host is promoted. Shared POSIX math now owns FPC wait-status macro
  projections for `WEXITSTATUS`, `WTERMSIG`, `WSTOPSIG`, `WIFEXITED`,
  `WIFSIGNALED`, `WIFSTOPPED`, `WCOREDUMP`, `W_EXITCODE`, and `W_STOPCODE`.
  Windows base now carries `WAIT_TIMEOUT`, `WAIT_FAILED`, `STILL_ACTIVE`,
  `SYNCHRONIZE`, `PROCESS_TERMINATE`, and `DUPLICATE_SAME_ACCESS`. This remains
  source-surface and compile evidence with no public platform.process contract.
- Wave 7 source evidence tokens are synchronized with the evidence index:
  `WNOHANG`, `WUNTRACED`, `WEXITSTATUS`, `WTERMSIG`, `WSTOPSIG`,
  `WIFEXITED`, `WIFSIGNALED`, `WIFSTOPPED`, `WCOREDUMP`, `W_EXITCODE`,
  `W_STOPCODE`, `SIGHUP`, `SIGINT`, `SIGKILL`, `SIGTERM`, `SIGCHLD`,
  `WAIT_TIMEOUT`, `WAIT_FAILED`, `STILL_ACTIVE`, `SYNCHRONIZE`,
  `PROCESS_TERMINATE`, and `DUPLICATE_SAME_ACCESS`.
- Platform Host ABI Completeness Wave 5 covers the environment ABI raw inventory for
  host `ffi` owners. POSIX hosts now expose delegated helpers for `getenv`,
  `setenv`, `unsetenv`, and `putenv`. FPC Unix source directly declares `getenv`;
  `setenv`, `unsetenv`, and `putenv` are recorded as POSIX libc/header fallback
  declarations because current FPC Unix units do not expose them. Windows now
  carries `GetEnvironmentVariableA`, `GetEnvironmentVariableW`,
  `SetEnvironmentVariableA`, `SetEnvironmentVariableW`,
  `GetEnvironmentStringsA`, `GetEnvironmentStringsW`,
  `FreeEnvironmentStringsA`, `FreeEnvironmentStringsW`,
  `ExpandEnvironmentStringsA`, `ExpandEnvironmentStringsW`, and thin result
  helpers. This remains source-surface and compile evidence with no public
  platform.env contract. There is no public platform.env contract in this wave.
- Wave 5 source evidence tokens are synchronized with the evidence index:
  `getenv`, `setenv`, `unsetenv`, `putenv`, POSIX libc/header fallback,
  `GetEnvironmentVariableA`, `GetEnvironmentVariableW`,
  `SetEnvironmentVariableA`, `SetEnvironmentVariableW`,
  `GetEnvironmentStringsA`, `GetEnvironmentStringsW`,
  `FreeEnvironmentStringsA`, `FreeEnvironmentStringsW`,
  `ExpandEnvironmentStringsA`, and `ExpandEnvironmentStringsW`.
- Platform Host ABI Completeness Wave 4 covers the directory/path ABI raw inventory for
  host `base/ffi` owners. POSIX hosts now carry `F_OK`, `X_OK`,
  `W_OK`, `R_OK` access tokens plus delegated helpers for `mkdir`, `rmdir`,
  `unlink`, `rename`, `access`, `getcwd`, and `chdir`. Windows now carries
  `LPSTR`, `LPWSTR`, `PLPSTR`, `PLPWSTR`, `CreateDirectoryA`,
  `CreateDirectoryW`, `RemoveDirectoryA`, `RemoveDirectoryW`, `DeleteFileA`,
  `DeleteFileW`, `MoveFileA`, `MoveFileW`, `GetCurrentDirectoryA`,
  `GetCurrentDirectoryW`, `SetCurrentDirectoryA`, `SetCurrentDirectoryW`,
  `GetFullPathNameA`, `GetFullPathNameW`, and thin result helpers. This remains
  source-surface and compile evidence with no public platform.file contract.
- Wave 4 source evidence tokens are synchronized with the evidence index:
  `mkdir`, `rmdir`, `unlink`, `rename`, `access`, `getcwd`, `chdir`, `F_OK`,
  `X_OK`, `W_OK`, `R_OK`, `CreateDirectoryA`, `CreateDirectoryW`,
  `RemoveDirectoryA`, `RemoveDirectoryW`, `DeleteFileA`, `DeleteFileW`,
  `MoveFileA`, `MoveFileW`, `GetCurrentDirectoryA`, `GetCurrentDirectoryW`,
  `SetCurrentDirectoryA`, `SetCurrentDirectoryW`, `GetFullPathNameA`, and
  `GetFullPathNameW`.
- Platform Host ABI Completeness Wave 1 covers process id, `timeval`, mmap, and
  dynamic loader inventory for host `base/ffi` owners. POSIX hosts now carry
  `pid_t`, RTLD constants, `platform_process_id`, `platform_parent_process_id`,
  mmap helpers, and dynamic loader helpers; Windows carries process id,
  `LoadLibraryA`, `GetProcAddress`, `FreeLibrary`, `VirtualAlloc`,
  `VirtualFree`, and `VirtualProtect` inventory. This is source-surface and
  compile evidence, not a new public `platform.process` or `platform.memory`
  contract.
- Wave 1 source evidence tokens are synchronized with the evidence index:
  `getpid`, `getppid`, `fpmmap`, `fpmunmap`, `dlopen`, `dlsym`,
  `LoadLibraryA`, `GetProcAddress`, and `VirtualAlloc`.
- Historical Wave 1 marker: `stat/open/fcntl deferred`. Wave 2 resolves the
  `open` / `fcntl` part of that marker and keeps only `stat` as the remaining
  deferred file-family risk.
- Platform Host ABI Completeness Wave 2 covers the file ABI raw inventory for
  host `base/ffi` owners. POSIX hosts now carry file descriptor aliases,
  `open`, `close`, `fcntl`, basic open/access flags, fcntl command tokens,
  `platform_file_open`, `platform_file_close`, `platform_file_fcntl`, and
  `platform_file_fcntl_i32`. Windows now carries `GENERIC_READ`,
  `GENERIC_WRITE`, `FILE_SHARE_READ`, `FILE_SHARE_WRITE`,
  `FILE_SHARE_DELETE`, `CREATE_ALWAYS`, `OPEN_EXISTING`,
  `FILE_ATTRIBUTE_NORMAL`, `CreateFileA`, `CreateFileW`, `ReadFile`,
  `WriteFile`, and a file close helper that delegates to the existing
  `CloseHandle` owner. This remains source-surface and compile evidence, not a
  new public `platform.file` contract.
- Wave 2 source evidence tokens are synchronized with the evidence index:
  `open`, `close`, `fcntl`, `O_CLOEXEC`, `F_DUPFD`, `F_GETFD`, `F_SETFD`,
  `F_GETFL`, `F_SETFL`, `FD_CLOEXEC`, `CreateFileA`, `CreateFileW`,
  `ReadFile`, and `WriteFile`.
- Platform Host ABI Completeness Wave 3 covers the file status ABI raw inventory
  for host `base/ffi` owners. Linux now carries `statx` records,
  `STATX_BASIC_STATS`, `AT_FDCWD`, `AT_SYMLINK_NOFOLLOW`, `AT_EMPTY_PATH`,
  `LINUX_SYSCALL_STATX`, `linux_statx`, `linux_statx_path_basic`, and
  `linux_statx_fd_basic`. Windows now carries `GET_FILEEX_INFO_LEVELS`,
  `WIN32_FILE_ATTRIBUTE_DATA`, `BY_HANDLE_FILE_INFORMATION`, expanded
  `FILE_ATTRIBUTE_*` constants, `GetFileAttributesExA`,
  `GetFileAttributesExW`, `GetFileInformationByHandle`, and thin result helpers.
  This remains source-surface and compile evidence, not a new public
  `platform.file` contract.
- Wave 3 source evidence tokens are synchronized with the evidence index:
  `statx`, `__xstat`, `__lxstat`, `__fxstat`, Darwin `$INODE64`,
  `GetFileAttributesExA`, `GetFileAttributesExW`,
  `GetFileInformationByHandle`, `WIN32_FILE_ATTRIBUTE_DATA`, and
  `BY_HANDLE_FILE_INFORMATION`.
- The older Wave 2 marker `stat remains deferred` remains intentionally present
  as route-truth compatibility. Wave 3 refines that marker to the narrower
  `posix stat record remains deferred` decision below.
- `posix stat record remains deferred`: traditional POSIX `stat`, `fstat`, and
  `lstat` record import is still out of the shared POSIX owner because record
  layouts, symbol suffixes, large-file policy, and 32/64-bit behavior differ by
  host. Linux `statx` and Windows file status are host-owned raw ABI inventory,
  not proof of a unified file-status contract.
- Darwin has `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0`, so pthread
  condition-variable timeout policy uses the host-owned realtime clock token.
- Darwin has `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0`. Its
  `platform_pthread_mutex_timedlock_abs` helper is an explicit unsupported
  stub returning the host `PLATFORM_POSIX_ENOTSUP` value.
- generic Unix has `PLATFORM_SYSCONF_NPROCESSORS_ONLN = -1`. CPU count goes
  through the same helper path as other POSIX hosts, but the token deliberately
  records that there is no proven host-specific sysconf id yet.
- generic Unix native thread id falls back to
  `platform_posix_thread_self_token_u64`. This is a documented fallback, not
  proof that the token equals a kernel thread id on every Unix.
- generic Unix has `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0`. The helper
  returns the host `PLATFORM_POSIX_ENOTSUP` fallback until a real host ABI is
  proven from source evidence.
- Windows is not a POSIX branch. It uses the Windows kernel32 path for
  `WaitOnAddress`, SRW locks, condition variables, thread lifecycle, TLS, QPC,
  and FILETIME.

## Verification Boundary

The official host gap matrix check is a source-surface integration guard. It
checks that the document, host `base/ffi` tokens, known gap markers, and
feature-FFI absence stay synchronized. It is not runtime proof for Darwin,
Android, FreeBSD, generic Unix, or Windows, and it is not a correctness proof
for FPC's raw ABI definitions.

Current evidence classes should be read separately:

- Linux behavior tests are runtime proof for the Linux host.
- Win64 checks are compile-only proof for the Windows branch.
- Simulated Darwin, Android, FreeBSD, and generic Unix checks are compile-only
  proof for branch selection and unit surface coherence.
- Source-surface checks keep ownership boundaries from drifting between host
  `base/ffi`, shared POSIX helpers, and unified feature contracts.
