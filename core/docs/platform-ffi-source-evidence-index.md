# Platform FFI Source Evidence Index

This document records where platform host ABI declarations should be checked
before they are copied into nextPas. It is an audit map for
`nextpas.core.platform`, not a second platform API.

The workflow for importing declarations after this evidence is recorded lives in
`docs/platform-ffi-import-workflow.md`. Keep that workflow, this evidence index,
the host gap matrix, and the official verification routes synchronized.

## Evidence Boundary

FPC source is reference authority, not production dependency. The platform layer
must still declare ABI truth in nextPas-owned host base/ffi units and must not
`uses` FPC platform units such as `Linux`, `UnixType`, `BaseUnix`, `PThreads`,
`Syscall`, or `Windows`.

Use this document to answer two questions:

- Which upstream source family justifies this constant, record shape, symbol
  name, calling convention, or syscall number?
- Which nextPas-owned host base/ffi unit owns the copied declaration?

This is not runtime proof. Runtime behavior tests cover the unified public
contracts in `platform.time`, `platform.sync`, and `platform.thread`. Raw OS
APIs such as `clock_gettime`, `pthread_*`, Linux `futex`, POSIX `fork`,
POSIX `read` / `write` / `lseek`, Windows `WaitOnAddress`,
`CreateProcessA/W`, `QueryPerformanceCounter`, and
`GetSystemTimeAsFileTime` are accepted from FPC source and then guarded only at
the nextPas integration boundary: owner placement, source-surface checks,
compile-only gates, route truth, and focused runtime tests of nextPas
abstractions that consume them.

## Host Evidence Matrix

| Host | nextPas owner | FPC source evidence | Evidence scope |
| --- | --- | --- | --- |
| Linux | `nextpas.core.platform.linux.base` / `nextpas.core.platform.linux.ffi` | `rtl/linux/linux.pp`, `rtl/linux/ptypes.inc`, `rtl/linux/pthread.inc`, `rtl/linux/signal.inc`, `rtl/linux/sysos.inc`, `rtl/linux/ostypes.inc`, `rtl/linux/ossysc.inc`, `rtl/linux/x86_64/sysnr.inc`, and sibling arch `sysnr.inc` files | `CLOCK_REALTIME`, `CLOCK_MONOTONIC`, `clock_gettime`, `clock_getres`, `timespec`, `__errno_location`, `gettid`, `_SC_NPROCESSORS_ONLN`, pthread shapes/functions, `pthread_condattr_setclock`, `pthread_mutex_timedlock`, `syscall_nr_futex`, `FUTEX_WAIT`, `FUTEX_WAKE`, POSIX environment helpers, shared POSIX process-control externals, shared POSIX file I/O externals, Linux traditional stat records and libc wrappers, Linux signal-control records/constants and `rt_sigaction` / `rt_sigprocmask` syscall projections |
| Android | `nextpas.core.platform.android.base` / `nextpas.core.platform.android.ffi` | `rtl/android/Makefile`, `rtl/android/*/sysnr.inc`, `rtl/android/sysandroid.inc`, `packages/pthreads/src/pthrandroid.inc`, `rtl/linux/signal.inc`, `rtl/linux/ostypes.inc`, `rtl/linux/ossysc.inc`, `rtl/linux/x86_64/stat.inc`, `rtl/linux/aarch64/stat.inc`, and Android Bionic headers when FPC does not expose the libc symbol directly | Android `clock_gettime` / `clock_getres` syscall families, `timespec`, `__errno`, `gettid`, `_SC_NPROCESSORS_ONLN`, pthread lifecycle/TLS/sync declarations, `pthread_mutex_timedlock`, `pthread_condattr_setclock`, POSIX environment helpers, shared POSIX process-control externals, shared POSIX file I/O externals, Android traditional stat records plus syscall-backed `newfstatat` / `fstat` helpers, and Android signal-control records/constants plus `rt_sigaction` / `rt_sigprocmask` syscall projections |
| Darwin | `nextpas.core.platform.darwin.base` / `nextpas.core.platform.darwin.ffi` | `rtl/darwin/ptypes.inc`, `rtl/darwin/pthread.inc`, `rtl/darwin/signal.inc`, `rtl/bsd/sysos.inc`, `rtl/bsd/ostypes.inc`, `rtl/macos/macostp.inc`, `rtl/unix/oscdeclh.inc`, `rtl/unix/initc.pp`, plus Apple Darwin/Mach headers for Mach-only calls | `timespec`, pthread shapes/functions, `__error`, `pthread_threadid_np`, `mach_absolute_time`, `mach_timebase_info`, POSIX environment helpers, shared POSIX process-control externals, shared POSIX file I/O externals, Darwin `$INODE64` traditional stat bindings, Darwin signal-control records/constants and libc `sigaction` / `sigprocmask` plus `pthread_sigmask`, and the documented absence of `pthread_mutex_timedlock` / monotonic condattr policy on the current nextPas Darwin path |
| FreeBSD | `nextpas.core.platform.freebsd.base` / `nextpas.core.platform.freebsd.ffi` | `rtl/freebsd/freebsd.pas`, `rtl/freebsd/ptypes.inc`, `rtl/freebsd/pthread.inc`, `rtl/freebsd/signal.inc`, `rtl/freebsd/sysnr.inc`, `rtl/bsd/sysos.inc`, `rtl/bsd/ostypes.inc`, `rtl/unix/oscdeclh.inc` | `CLOCK_REALTIME`, `CLOCK_MONOTONIC = 4`, `clock_gettime`, `clock_getres`, `timespec`, `__error`, `pthread_getthreadid_np`, pthread lifecycle/TLS/sync declarations, `pthread_mutex_timedlock`, `pthread_condattr_setclock`, POSIX environment helpers, shared POSIX process-control externals, shared POSIX file I/O externals, FreeBSD traditional stat bindings, and FreeBSD signal-control records/constants plus libc `sigaction` / `sigprocmask` and `pthread_sigmask` |
| generic Unix | `nextpas.core.platform.unix.base` / `nextpas.core.platform.unix.ffi` | `rtl/unix/baseunix.pp`, `rtl/unix/unix.pp`, `rtl/unix/oscdeclh.inc`, `rtl/unix/unxdeclh.inc`, `rtl/unix/initc.pp`, `rtl/unix/cthreads.pp`, and the closest proven host-specific FPC source before promoting a fallback into a real host | shared POSIX `clock_gettime`, `clock_getres`, `timespec`, `__errno_location` / `__error` errno families, pthread lifecycle/TLS/sync declarations, `pthread_condattr_setclock` policy, `_SC_NPROCESSORS_ONLN` fallback, `pthread_self` native-id fallback, POSIX environment helpers, shared POSIX process-control externals, and shared POSIX file I/O externals |
| Windows | `nextpas.core.platform.windows.base` / `nextpas.core.platform.windows.ffi` | `rtl/win32/windows.pp`, `rtl/win64/windows.pp`, `rtl/win/wininc`, `rtl/win/sysfile.inc`, `rtl/win/sysutils.pp`, `packages/winunits-base`, and Windows OS SDK headers when FPC does not expose newer kernel32 APIs | `FILETIME`, `SYSTEM_INFO`, `PROCESS_INFORMATION`, `STARTUPINFOA/W`, `CreateThread`, `CreateProcessA/W`, `WaitForSingleObject`, `CloseHandle`, `GetCurrentThreadId`, `QueryPerformanceCounter`, `GetSystemTimeAsFileTime`, `TlsAlloc`, `TlsFree`, `TlsSetValue`, `TlsGetValue`, `GetSystemInfo`, `SRWLOCK`, `CONDITION_VARIABLE`, `SleepConditionVariableSRW`, `WaitOnAddress`, `WakeByAddressSingle`, `WakeByAddressAll`, Windows environment entrypoints, Windows process-control entrypoints, Windows file I/O entrypoints |

## Declaration Evidence Classes

### Platform Host ABI Completeness Wave 11: POSIX signal-control raw ABI

Wave 11 promotes POSIX signal-control raw ABI inventory into host owners. It
copies FPC's host-specific signal set widths, `sigactionrec` layouts, signal
action flags, signal-mask operation constants, libc bindings, pthread signal
mask bindings, and Linux-derived `rt_sigaction` / `rt_sigprocmask` syscall
routes. Shared POSIX signal-control remains deferred because FPC records
host-specific layouts; this wave has no public platform.signal contract.

- Linux signal-control evidence starts in FPC `rtl/linux/signal.inc`,
  `rtl/linux/ostypes.inc`, `rtl/linux/ossysc.inc`,
  `rtl/linux/x86_64/sysnr.inc`, and `rtl/linux/sysnr-gen.inc`.
  `nextpas.core.platform.linux.base` owns `TPlatformLinuxSignalSet`,
  `PPlatformLinuxSignalSet`, `TPlatformLinuxSigAction`,
  `PPlatformLinuxSigAction`, `PLATFORM_SIGNAL_ACTION_SIGINFO`,
  `PLATFORM_SIGNAL_ACTION_RESTART`, `PLATFORM_SIGNAL_MASK_BLOCK`,
  `PLATFORM_SIGNAL_MASK_UNBLOCK`, `PLATFORM_SIGNAL_MASK_SETMASK`,
  `LINUX_SYSCALL_RT_SIGACTION`, and
  `LINUX_SYSCALL_RT_SIGPROCMASK`. `nextpas.core.platform.linux.ffi` owns
  `linux_rt_sigaction` and `linux_rt_sigprocmask` syscall projections.
- Android signal-control evidence starts in FPC `rtl/linux/signal.inc`,
  `rtl/linux/ossysc.inc`, `rtl/android/x86_64/sysnr.inc`, and
  `rtl/android/aarch64/sysnr.inc`. `nextpas.core.platform.android.base` owns
  `TPlatformAndroidSignalSet`, `PPlatformAndroidSignalSet`,
  `TPlatformAndroidSigAction`, `PPlatformAndroidSigAction`, the host signal
  action/mask tokens, `ANDROID_SYSCALL_RT_SIGACTION`, and
  `ANDROID_SYSCALL_RT_SIGPROCMASK`. `nextpas.core.platform.android.ffi` owns
  `android_rt_sigaction` and `android_rt_sigprocmask` syscall projections.
- Darwin signal-control evidence starts in FPC `rtl/darwin/signal.inc`,
  `rtl/darwin/pthread.inc`, and `rtl/unix/oscdeclh.inc`.
  `nextpas.core.platform.darwin.base` owns `TPlatformDarwinSignalSet`,
  `PPlatformDarwinSignalSet`, `TPlatformDarwinSigAction`,
  `PPlatformDarwinSigAction`, and the Darwin signal action/mask tokens.
  `nextpas.core.platform.darwin.ffi` owns `darwin_sigaction`,
  `darwin_sigprocmask`, and `darwin_pthread_sigmask`.
- FreeBSD signal-control evidence starts in FPC `rtl/freebsd/signal.inc`,
  `rtl/freebsd/pthread.inc`, `rtl/bsd/ostypes.inc`,
  `rtl/freebsd/sysnr.inc`, and `rtl/unix/oscdeclh.inc`.
  `nextpas.core.platform.freebsd.base` owns `TPlatformFreeBSDSignalSet`,
  `PPlatformFreeBSDSignalSet`, `TPlatformFreeBSDSigAction`,
  `PPlatformFreeBSDSigAction`, and the FreeBSD signal action/mask tokens.
  `nextpas.core.platform.freebsd.ffi` owns `freebsd_sigaction`,
  `freebsd_sigprocmask`, and `freebsd_pthread_sigmask`.
- Generic Unix keeps a conservative libc-backed fallback in
  `nextpas.core.platform.unix.base` / `nextpas.core.platform.unix.ffi` through
  `TPlatformUnixSignalSet`, `TPlatformUnixSigAction`, `unix_sigaction`, and
  `unix_sigprocmask`. It does not invent a Linux `rt_sigaction` syscall route.
- Shared POSIX owners still do not carry `TPlatformPosixSignalSet`,
  `TPlatformPosixSigAction`, shared `sigaction`, or shared `sigprocmask`.
  `rtl/unix/gensigset.inc` is evidence for future host-local or parameterized
  pure signal-set helpers, not a universal record layout.

No public platform.signal contract is created in Wave 11.

### Platform Host ABI Completeness Wave 10: Darwin / FreeBSD / Android traditional stat raw ABI

Wave 10 promotes the Darwin / FreeBSD / Android traditional stat raw ABI from
the deferred POSIX stat family. It copies FPC's host-specific record shapes,
Darwin symbol suffix policy, FreeBSD direct libc symbol route, and Android
Linux-derived syscall route into host-owned declarations. Shared POSIX stat and
generic Unix stat stay deferred; this wave still does not create a public
`platform.file` contract.

- Darwin / FreeBSD / Android traditional stat evidence starts in FPC
  `rtl/bsd/ostypes.inc`, `rtl/darwin/ptypes.inc`,
  `rtl/freebsd/ptypes.inc`, `rtl/unix/oscdeclh.inc`,
  `rtl/android/Makefile`, `rtl/linux/x86_64/stat.inc`,
  `rtl/linux/aarch64/stat.inc`, `rtl/android/x86_64/sysnr.inc`,
  `rtl/android/aarch64/sysnr.inc`, `rtl/linux/ossysc.inc`, and
  `rtl/linux/bunxsysc.inc`.
- Darwin host owners now carry `TPlatformDarwinStat`,
  `PPlatformDarwinStat`, `darwin_stat`, `darwin_lstat`, `darwin_fstat`,
  `darwin_stat_path`, `darwin_lstat_path`, and `darwin_fstat_fd`. FPC records
  the non-Linux Unix binding route in `rtl/unix/oscdeclh.inc`, including
  `darwinsuffix64bit = '$INODE64'`, so the raw symbols are `stat$INODE64`,
  `lstat$INODE64`, and `fstat$INODE64`.
- FreeBSD host owners now carry `TPlatformFreeBSDStat`,
  `PPlatformFreeBSDStat`, `freebsd_stat`, `freebsd_lstat`, `freebsd_fstat`,
  `freebsd_stat_path`, `freebsd_lstat_path`, and `freebsd_fstat_fd`. FPC
  records the direct libc route in `rtl/unix/oscdeclh.inc` with `stat`,
  `lstat`, and `fstat`.
- Android host owners now carry `TPlatformAndroidStat`,
  `PPlatformAndroidStat`, `PLATFORM_ANDROID_AT_FDCWD`,
  `PLATFORM_ANDROID_AT_SYMLINK_NOFOLLOW`, `ANDROID_SYSCALL_NEWFSTATAT`,
  `ANDROID_SYSCALL_FSTAT`, `android_syscall`, `android_newfstatat`,
  `android_fstat`, `android_stat_path`, `android_lstat_path`, and
  `android_fstat_fd`. FPC records Android as `generic_linux_syscalls`, so
  path stat routes through `newfstatat`, fd stat routes through `fstat`, and
  lstat routes through `newfstatat` with `AT_SYMLINK_NOFOLLOW`.
- Generic Unix remains deferred because FPC does not define one universal Unix
  `stat` layout or suffix policy that can safely become
  `TPlatformUnixStat`. Shared POSIX `stat`, `lstat`, and `fstat` remain
  absent from `nextpas.core.platform.posix.base` and
  `nextpas.core.platform.posix.ffi`.

### Platform Host ABI Completeness Wave 9: Linux traditional stat raw ABI

Wave 9 promotes only the Linux traditional stat raw ABI from the deferred POSIX
stat family. It copies FPC's Linux `stat` record shape, CPU-specific
`_STAT_VER` policy, and libc wrapper route into Linux host-owned declarations.
It keeps shared POSIX stat deferred and does not create a public
`platform.file` contract.

- Linux traditional stat evidence starts in FPC `rtl/linux/ostypes.inc`,
  `rtl/linux/x86_64/stat.inc`, `rtl/linux/aarch64/stat.inc`, and
  `rtl/linux/osmacro.inc`. `nextpas.core.platform.linux.base` owns
  `TPlatformLinuxStat`, `PPlatformLinuxStat`, and
  `PLATFORM_LINUX_STAT_VERSION`.
- Linux libc wrapper evidence starts in `rtl/linux/osmacro.inc`, where FPC
  declares `__xstat`, `__lxstat`, and `__fxstat`, then routes `FpStat`,
  `FpLstat`, and `FpFstat` through those wrappers with `_STAT_VER`.
  `nextpas.core.platform.linux.ffi` owns `linux_xstat`, `linux_lxstat`,
  `linux_fxstat`, `linux_stat_path`, `linux_lstat_path`, and
  `linux_fstat_fd`.
- Shared POSIX `stat`, `lstat`, and `fstat` remain deferred because
  `rtl/unix/oscdeclh.inc` records host-specific symbol suffix policy, and the
  Linux, Darwin, FreeBSD, Android, and generic Unix record layouts still need
  separate host-owner decisions.

### Platform Host ABI Completeness Wave 8: file I/O continuation

Wave 8 extends the low-level file ABI inventory with file I/O continuation
entrypoints. It covers POSIX `read`, `write`, `lseek`, `fsync`, `ftruncate`,
host seek tokens, and Windows kernel32 file positioning, sizing, syncing, and
truncation entrypoints. It keeps no public platform.file contract in this wave.

- Shared POSIX file I/O scalar aliases live in
  `nextpas.core.platform.posix.base`: `size_t`, `ssize_t`, `off_t`, and
  `TPlatformFileOffset`. FPC evidence starts in the Unix file descriptor source
  family that exposes `TSize`, `TSSize`, and `TOff` around the same libc
  calls.
- POSIX seek tokens stay in host `base` units: `SEEK_SET`, `SEEK_CUR`, and
  `SEEK_END` become `PLATFORM_SEEK_SET`, `PLATFORM_SEEK_CURRENT`, and
  `PLATFORM_SEEK_END`. Evidence starts in FPC `rtl/linux/ostypes.inc`,
  `rtl/bsd/ostypes.inc`, and `rtl/macos/macostp.inc`.
- Shared POSIX externals and thin helpers live in
  `nextpas.core.platform.posix.ffi`: `read`, `write`, `lseek`, `fsync`,
  `ftruncate`, `platform_posix_read`, `platform_posix_write`,
  `platform_posix_seek`, `platform_posix_sync`, and
  `platform_posix_truncate`. Evidence starts in `rtl/unix/oscdeclh.inc` for
  `read`, `write`, `lseek`, and `ftruncate`; in `rtl/unix/unxdeclh.inc` for
  `fsync`; and in `rtl/unix/bunxh.inc`, `rtl/linux/ossysc.inc`, and
  `rtl/bsd/ossysc.inc` for the `FPC_SYSC_READ`, `FPC_SYSC_WRITE`,
  `FPC_SYSC_LSEEK`, and `FPC_SYSC_FTRUNCATE` syscall wrapper aliases.
- POSIX host `ffi` units expose `platform_file_read`, `platform_file_write`,
  `platform_file_seek`, `platform_file_sync`, and
  `platform_file_truncate` by delegating to the shared POSIX helpers. These are
  raw host helper projections following the Wave 2 file helper precedent, not a
  public `platform.file` contract.
- Windows file I/O continuation evidence starts in FPC `rtl/win/wininc/func.inc`
  and `rtl/win/wininc/redef.inc` for `GetFileSize`, `SetFilePointer`,
  `FlushFileBuffers`, `SetEndOfFile`, `GetFileSizeEx`, and
  `SetFilePointerEx`; `rtl/win/sysfile.inc` and `rtl/win/sysutils.pp` show FPC
  using those entrypoints for file position, size, flush, and truncate flows.
  Windows ABI aliases, `LARGE_INTEGER`, `FILE_BEGIN`, `FILE_CURRENT`,
  `FILE_END`, and `INVALID_SET_FILE_POINTER` live in
  `nextpas.core.platform.windows.base`; raw declarations and thin
  Windows-prefixed helpers live in `nextpas.core.platform.windows.ffi`.

### Platform Host ABI Completeness Wave 6: process-control raw ABI inventory

Wave 6 imports the process-control raw ABI inventory that future process or
command-execution contracts can consume. It covers POSIX process-control
entrypoints and Windows kernel32 process-control entrypoints. It keeps no public
platform.process contract in this wave.

- Shared POSIX process-control externals live in
  `nextpas.core.platform.posix.ffi`: `fork`, `execve`, `waitpid`, `_exit`,
  and `kill`. Wave 6 intentionally does not add shared process helpers because
  process-control semantics need a future public `platform.process` design.
  FPC evidence starts in
  `rtl/unix/oscdeclh.inc`, where `FpFork`, `FpExecve`, `FpWaitpid`, `FpExit`,
  and `FpKill` bind libc `fork`, `execve`, `waitpid`, `_exit`, and `kill`.
  Linux and BSD syscall wrapper families are supporting evidence, not a
  production dependency.
- POSIX host `ffi` units must not expose `platform_process_*` helpers in this
  wave. That name shape looks like a unified nextPas platform contract, while
  Wave 6 is only raw host ABI inventory.
- Windows process-control evidence starts in FPC `rtl/win/wininc/struct.inc`
  for `PROCESS_INFORMATION`, `STARTUPINFOA`, and `STARTUPINFOW`; in
  `rtl/win/wininc/defines.inc` for process creation flags and priority class
  tokens; in `rtl/win/wininc/ascfun.inc` / `rtl/win/wininc/unifun.inc` for
  `CreateProcessA`, `CreateProcessW`, `GetStartupInfoA`, and
  `GetStartupInfoW`; and in `rtl/win/wininc/func.inc` for `ExitProcess`,
  `TerminateProcess`, and `GetExitCodeProcess`.
- Windows record layouts, ABI aliases, and creation tokens live in
  `nextpas.core.platform.windows.base`. Windows raw entrypoints live in
  `nextpas.core.platform.windows.ffi`: `CreateProcessA`, `CreateProcessW`,
  `GetStartupInfoA`, `GetStartupInfoW`, `TerminateProcess`,
  `GetExitCodeProcess`, and `ExitProcess`. Wave 6 intentionally does not add
  non-FPC `windows_*process*` result wrappers.

### Platform Host ABI Completeness Wave 7: process wait-status raw ABI inventory

Wave 7 extends the process-control inventory with raw process wait-status
helpers, wait option tokens, POSIX signal tokens, and Windows wait/status/access
constants. It still does not create a public `platform.process` contract.

- POSIX wait option tokens stay in host `base` units: `WNOHANG` and
  `WUNTRACED` become `PLATFORM_WAIT_NOHANG` and `PLATFORM_WAIT_UNTRACED`.
  Evidence starts in FPC `rtl/linux/ostypes.inc`, `rtl/bsd/ostypes.inc`, and
  `packages/libc/src/bwaitflagsh.inc`.
- POSIX signal tokens stay in host `base` units: `SIGHUP`, `SIGINT`,
  `SIGKILL`, `SIGTERM`, and host-specific `SIGCHLD` become
  `PLATFORM_SIGNAL_HANGUP`, `PLATFORM_SIGNAL_INTERRUPT`,
  `PLATFORM_SIGNAL_KILL`, `PLATFORM_SIGNAL_TERMINATE`, and
  `PLATFORM_SIGNAL_CHILD`. Linux evidence starts in `rtl/linux/signal.inc`;
  Darwin evidence starts in `rtl/darwin/signal.inc`; FreeBSD evidence starts in
  `rtl/freebsd/signal.inc`. Android follows the current Linux/Bionic-style
  nextPas host evidence for this wave, while generic Unix keeps the Linux-style
  fallback until a more specific host owner is promoted.
- POSIX wait-status macro arithmetic lives in
  `nextpas.core.platform.posix.math`: `platform_posix_wait_exit_status`,
  `platform_posix_wait_term_signal`, `platform_posix_wait_stop_signal`,
  `platform_posix_wait_if_exited`, `platform_posix_wait_if_signaled`,
  `platform_posix_wait_if_stopped`, `platform_posix_wait_core_dumped`,
  `platform_posix_wait_exit_code`, and `platform_posix_wait_stop_code`.
  Evidence starts in FPC `packages/libc/src/bwaitflags.inc`,
  `packages/libc/src/bwaitstatus.inc`, `packages/libc/src/bwaitstatush.inc`,
  and `rtl/unix/unix.pp`, where `WEXITSTATUS`, `WTERMSIG`, `WSTOPSIG`,
  `WIFEXITED`, `WIFSIGNALED`, `WIFSTOPPED`, `WCOREDUMP`, `W_EXITCODE`, and
  `W_STOPCODE` are defined.
- Windows wait and process-status constants live in
  `nextpas.core.platform.windows.base`: `WAIT_TIMEOUT`, `WAIT_FAILED`,
  `STILL_ACTIVE`, `SYNCHRONIZE`, `PROCESS_TERMINATE`, and
  `DUPLICATE_SAME_ACCESS`. Evidence starts in FPC
  `rtl/win/wininc/defines.inc`, with existing raw process entrypoints still
  owned by `nextpas.core.platform.windows.ffi`.

### Platform Host ABI Completeness Wave 5: environment ABI raw inventory

Wave 5 imports the environment ABI raw inventory that future environment or
process contracts can consume. It covers POSIX libc environment entrypoints and
Windows kernel32 environment entrypoints. It keeps no public platform.env contract in
this wave.

- Shared POSIX environment externals and thin helpers live in
  `nextpas.core.platform.posix.ffi`: `getenv`, `setenv`, `unsetenv`, `putenv`,
  `platform_posix_environment_get`, `platform_posix_environment_set`,
  `platform_posix_environment_unset`, and `platform_posix_environment_put`.
  FPC evidence for `getenv` starts in `rtl/unix/oscdeclh.inc`, where
  `fpgetenv` binds libc `getenv`, and continues through `rtl/unix/baseunix.pp`,
  `rtl/unix/genfuncs.inc`, and `rtl/unix/unix.pp`. FPC does not expose
  `setenv`, `unsetenv`, or `putenv` in the current Unix source surface, so those
  mutating declarations are recorded as a POSIX libc/header fallback before
  nextPas owns them.
- POSIX host `ffi` units expose `platform_environment_get`,
  `platform_environment_set`, `platform_environment_unset`, and
  `platform_environment_put` by delegating to the shared POSIX helpers.
- Android keeps the POSIX libc environment helper path. FPC
  `rtl/android/sysandroid.inc` records the libc `environ` startup path, while
  the function declarations themselves stay in the shared POSIX owner for this
  wave.
- Windows environment evidence starts in FPC `rtl/win/wininc/ascfun.inc`,
  `rtl/win/wininc/unifun.inc`, `rtl/win/wininc/ascdef.inc`,
  `rtl/win/wininc/unidef.inc`, and `rtl/win/sysos.inc`. Wave 5 imports
  `GetEnvironmentVariableA`, `GetEnvironmentVariableW`,
  `SetEnvironmentVariableA`, `SetEnvironmentVariableW`,
  `GetEnvironmentStringsA`, `GetEnvironmentStringsW`,
  `FreeEnvironmentStringsA`, `FreeEnvironmentStringsW`,
  `ExpandEnvironmentStringsA`, `ExpandEnvironmentStringsW`, and thin result
  helpers.

### Platform Host ABI Completeness Wave 4: directory/path ABI raw inventory

Wave 4 imports the directory/path ABI raw inventory that future file or path
contracts can consume. It covers POSIX directory and path entrypoints and
Windows kernel32 directory/path entrypoints. It keeps no public platform.file contract in
this wave.

- Shared POSIX path externals and thin helpers live in
  `nextpas.core.platform.posix.ffi`: `mkdir`, `rmdir`, `unlink`, `rename`,
  `access`, `getcwd`, `chdir`, `platform_posix_directory_create`,
  `platform_posix_directory_remove`, `platform_posix_path_unlink`,
  `platform_posix_path_rename`, `platform_posix_path_access`,
  `platform_posix_path_get_current_directory`, and
  `platform_posix_path_set_current_directory`. FPC evidence starts in
  `rtl/unix/oscdeclh.inc`, where the libc external declarations are visible,
  and in `rtl/linux/ossysc.inc` / `rtl/bsd/ossysc.inc`, where syscall wrappers
  expose `FpMkdir`, `FpRmdir`, `FpUnlink`, `FpRename`, `FpAccess`, `FpGetcwd`,
  and `FpChdir`.
- POSIX access mode tokens stay in host `base` units: `F_OK`, `X_OK`, `W_OK`,
  and `R_OK` become `PLATFORM_ACCESS_EXISTS`, `PLATFORM_ACCESS_EXECUTE`,
  `PLATFORM_ACCESS_WRITE`, and `PLATFORM_ACCESS_READ`. Evidence starts in FPC
  `rtl/linux/ostypes.inc` and `rtl/bsd/ostypes.inc`; generic Unix keeps the
  same proven POSIX values until a more specific host owner is promoted.
- POSIX host `ffi` units expose `platform_directory_create`,
  `platform_directory_remove`, `platform_path_unlink`, `platform_path_rename`,
  `platform_path_access`, `platform_path_get_current_directory`, and
  `platform_path_set_current_directory` by delegating to the shared POSIX
  helpers.
- Windows path and directory evidence starts in FPC
  `rtl/win/wininc/ascfun.inc`, `rtl/win/wininc/unifun.inc`,
  `rtl/win/wininc/ascdef.inc`, `rtl/win/wininc/unidef.inc`, and
  `rtl/win/sysos.inc`. Wave 4 imports `LPSTR`, `LPWSTR`, `PLPSTR`, `PLPWSTR`,
  `CreateDirectoryA`, `CreateDirectoryW`, `RemoveDirectoryA`,
  `RemoveDirectoryW`, `DeleteFileA`, `DeleteFileW`, `MoveFileA`, `MoveFileW`,
  `GetCurrentDirectoryA`, `GetCurrentDirectoryW`, `SetCurrentDirectoryA`,
  `SetCurrentDirectoryW`, `GetFullPathNameA`, `GetFullPathNameW`, and thin
  result helpers.

### Platform Host ABI Completeness Wave 3: file status ABI raw inventory

Wave 3 imports the file status ABI raw inventory that is safe to own without
creating a public `platform.file` contract. It covers Linux `statx` raw ABI
inventory and Windows file-attribute / file-information entry points. POSIX
stat record remains deferred because the traditional POSIX `stat` / `fstat` /
`lstat` family is not a single shared ABI shape across the supported hosts.

- Linux `statx` evidence starts in FPC `rtl/linux/linux.pp`,
  `rtl/linux/ostypes.inc`, `rtl/linux/ossysc.inc`,
  `rtl/linux/x86_64/sysnr.inc`, and generic syscall-number include files such
  as `rtl/linux/sysnr-gen.inc`. `nextpas.core.platform.linux.base` owns
  `TPlatformLinuxStatxTimestamp`, `TPlatformLinuxStatx`,
  `PLATFORM_LINUX_STATX_BASIC_STATS`, Linux `AT_*` stat flags, and the
  `LINUX_SYSCALL_STATX` token. `nextpas.core.platform.linux.ffi` owns
  `linux_statx`, `linux_statx_path_basic`, and `linux_statx_fd_basic`.
- Traditional Linux libc `stat` evidence starts in FPC `rtl/linux/osmacro.inc`
  and `rtl/linux/ostypes.inc`: FPC routes `FpStat`, `FpLstat`, and `FpFstat`
  through `__xstat`, `__lxstat`, and `__fxstat` with `_STAT_VER`. `_STAT_VER`
  itself differs by CPU family, so nextPas does not import a generic Linux
  libc stat wrapper in this wave.
- Generic Unix / BSD / Darwin stat symbol evidence starts in
  `rtl/unix/oscdeclh.inc` and `rtl/bsd/ostypes.inc`. Those files show
  `suffix64bit` and Darwin `$INODE64` suffix handling, plus host-specific
  record layouts and padding. POSIX stat record remains deferred until each
  host layout and symbol suffix policy has its own owner decision.
- Windows file status evidence starts in FPC `rtl/win/wininc/struct.inc`,
  `rtl/win/wininc/defines.inc`, `rtl/win/wininc/ascfun.inc`,
  `rtl/win/wininc/unifun.inc`, and `rtl/win/wininc/func.inc`. Wave 3 imports
  `GET_FILEEX_INFO_LEVELS`, `WIN32_FILE_ATTRIBUTE_DATA`,
  `BY_HANDLE_FILE_INFORMATION`, additional `FILE_ATTRIBUTE_*` constants,
  `GetFileAttributesExA`, `GetFileAttributesExW`, and
  `GetFileInformationByHandle`.

### Platform Host ABI Completeness Wave 2: file ABI raw inventory

Wave 2 imports the low-level file ABI inventory that future file contracts can
consume. It covers POSIX file descriptors, `open`, `close`, `fcntl`, basic
open/access flags, fcntl command tokens, and Windows kernel32 file entrypoints.
It does not create a public `platform.file` contract. `stat remains deferred`
because `stat` / `fstat` / `lstat` record layout, large-file suffixes, and
32/64-bit policy differ enough across hosts to deserve a separate evidence pass.

- Shared POSIX file descriptor and mode argument aliases live in
  `nextpas.core.platform.posix.base`. FPC evidence starts in
  `rtl/unix/oscdecl.inc`, `rtl/unix/oscdeclh.inc`,
  `rtl/linux/ossysc.inc`, and `rtl/bsd/ossysc.inc`, where `open`, `close`, and
  `fcntl` are bound or wrapped as libc/syscall-level file descriptor APIs.
- POSIX host open/access flags stay in host `base` units. Linux and Android use
  the FPC `rtl/linux/ostypes.inc` / `rtl/linux/linux.pp` values for
  `O_RDONLY`, `O_WRONLY`, `O_RDWR`, `O_CREAT`, `O_EXCL`, `O_TRUNC`,
  `O_APPEND`, and `O_CLOEXEC`; Darwin uses `rtl/macos/macostp.inc`; FreeBSD
  uses `rtl/bsd/ostypes.inc`; generic Unix keeps the Darwin-style fallback until
  a more specific host is promoted.
- POSIX fcntl command tokens stay in host `base` units: `F_DUPFD`, `F_GETFD`,
  `F_SETFD`, `F_GETFL`, `F_SETFL`, and `FD_CLOEXEC`. Evidence starts in
  `rtl/bsd/ostypes.inc`, `rtl/linux/bunxsysc.inc`, `rtl/bsd/bunxsysc.inc`, and
  `rtl/unix/oscdecl.inc`.
- Shared POSIX externals and thin helpers live in
  `nextpas.core.platform.posix.ffi`: `open`, `close`, `fcntl`,
  `platform_posix_open`, `platform_posix_close`, `platform_posix_fcntl`, and
  `platform_posix_fcntl_i32`. Host `ffi` units expose `platform_file_open`,
  `platform_file_close`, `platform_file_fcntl`, and
  `platform_file_fcntl_i32` by delegating to those shared helpers.
- Windows file evidence starts in FPC `rtl/win/sysos.inc`,
  `rtl/win/sysfile.inc`, `rtl/win/wininc/defines.inc`,
  `rtl/win/wininc/ascfun.inc`, `rtl/win/wininc/unifun.inc`, and
  `rtl/win/wininc/redef.inc`. Wave 2 imports `GENERIC_READ`,
  `GENERIC_WRITE`, `FILE_SHARE_READ`, `FILE_SHARE_WRITE`,
  `FILE_SHARE_DELETE`, `CREATE_ALWAYS`, `OPEN_EXISTING`,
  `FILE_ATTRIBUTE_NORMAL`, `CreateFileA`, `CreateFileW`, `ReadFile`, and
  `WriteFile`. File close delegates to the existing `CloseHandle` owner.

### Platform Host ABI Completeness Wave 1: process id, timeval, mmap, and dynamic loader

Wave 1 imports the first low-risk host ABI inventory used by future
`platform.process`, `platform.memory`, and dynamic-library contracts. It covers
process id, `timeval`, mmap, and dynamic loader declarations. The historical
`stat/open/fcntl deferred` marker is deliberate: Wave 1 kept those families out
because they needed a later, narrower evidence pass. Wave 2 now covers
`open` / `fcntl` file ABI tokens, while `stat` remains deferred.

- Shared `timeval` shape belongs in `nextpas.core.platform.posix.base`.
  Evidence starts in FPC `rtl/linux/ptypes.inc`,
  `rtl/darwin/ptypes.inc`, and `rtl/freebsd/ptypes.inc`. Darwin keeps its
  `suseconds_t = cint32` `tv_usec` field while the Linux/Android/FreeBSD/current
  generic Unix path uses long-sized fields.
- Shared process id declarations use FPC `rtl/unix/oscdeclh.inc`, where
  `FpGetpid` and `FpGetppid` bind to `getpid` and `getppid`. Host `base` units
  own `pid_t` / `TPlatformProcessId`, and host `ffi` units expose host-prefixed projections such as
  `linux_process_id`, `android_process_id`, `darwin_process_id`,
  `freebsd_process_id`, and `unix_process_id` plus matching
  `*_parent_process_id` helpers. The old `platform_process_id` naming is
  deliberately forbidden because it looks like a public unified
  `platform.process` contract.
- Shared mmap declarations use FPC `rtl/unix/baseunix.pp` for `PROT_READ`,
  `PROT_WRITE`, `PROT_EXEC`, `PROT_NONE`, `MAP_SHARED`, `MAP_PRIVATE`, and
  `MAP_FAILED`; FPC `rtl/unix/oscdeclh.inc` records `fpmmap`, `fpmunmap`, and
  `fpmprotect` as libc bindings for `mmap`, `munmap`, and `mprotect`.
- POSIX dynamic loader evidence starts in FPC `rtl/unix/dl.pp`, which records
  `RTLD_LAZY`, `RTLD_NOW`, `RTLD_LOCAL`, `RTLD_GLOBAL`, `dlopen`, `dlsym`,
  `dlclose`, and `dlerror`. RTLD constants and the external library owner vary
  by host, so constants stay in host `base` units and declarations stay in host
  `ffi` units.
- Windows Wave 1 process, memory, and dynamic-library evidence starts in FPC
  `rtl/win32/objinc.inc`, `rtl/win32/classes.pp`, `rtl/win64/system.pp`, and
  `packages/winunits-base`, then falls back to Windows OS SDK headers for exact
  kernel32 signatures. The imported surface includes `GetCurrentProcessId`,
  `LoadLibraryA`, `GetProcAddress`, `FreeLibrary`, `VirtualAlloc`,
  `VirtualFree`, and `VirtualProtect`.

### POSIX clock and time declarations

- Shared `timespec` shape belongs in `nextpas.core.platform.posix.base`.
  Evidence starts in FPC `rtl/linux/ptypes.inc`, `rtl/darwin/ptypes.inc`,
  `rtl/freebsd/ptypes.inc`, and `rtl/unix/aliasptp.inc`.
- Shared `clock_gettime`, `clock_getres`, `nanosleep`, and `sysconf`
  declarations belong in `nextpas.core.platform.posix.ffi`. Evidence starts in
  FPC `rtl/linux/linux.pp`, `rtl/freebsd/freebsd.pas`,
  `rtl/unix/oscdeclh.inc`, and `rtl/unix/cthreads.pp`.
- Host clock ids and capability tokens belong in host base units. Linux and
  Android currently use `CLOCK_REALTIME = 0` and `CLOCK_MONOTONIC = 1`;
  FreeBSD uses `CLOCK_MONOTONIC = 4`; generic Unix keeps the explicit fallback
  token until better host evidence is added.
- Darwin monotonic time uses `mach_absolute_time` and `mach_timebase_info`.
  FPC covers the surrounding Darwin/POSIX pthread and errno families, while the
  Mach-only calls are checked against Apple Darwin/Mach headers before they are
  declared in `nextpas.core.platform.darwin.ffi`.
- Windows monotonic and realtime clocks use `QueryPerformanceCounter`,
  `QueryPerformanceFrequency`, `FILETIME`, and `GetSystemTimeAsFileTime`.
  FPC `rtl/win32/windows.pp`, `rtl/win64/windows.pp`, and
  `packages/winunits-base` are the first pass; Windows OS SDK headers remain the
  tie-breaker for newer or missing kernel32 symbols.

### Errno declarations

- Linux errno storage uses `__errno_location`, with evidence in
  `rtl/linux/sysos.inc`.
- Android errno storage uses `__errno`, with evidence from Android Bionic
  headers and cross-checks against FPC Android source families when available.
- Darwin and FreeBSD errno storage use `__error`, with evidence in
  `rtl/bsd/sysos.inc` and `rtl/unix/initc.pp`.
- Generic Unix must not silently inherit Linux errno truth. It records either a
  proven host-specific errno symbol or an explicit fallback in
  `nextpas.core.platform.unix.base` / `nextpas.core.platform.unix.ffi`.

### pthread, thread lifecycle, TLS, and sync declarations

- Shared pthread entry points live in `nextpas.core.platform.posix.ffi`:
  `pthread_create`, `pthread_join`, `pthread_detach`, `pthread_self`,
  `pthread_key_create`, `pthread_key_delete`, `pthread_setspecific`,
  `pthread_getspecific`, mutex, rwlock, condvar, and attr functions.
- Shared pthread storage shapes live in `nextpas.core.platform.posix.base` only
  when the shape is genuinely shared for the current target family. Evidence
  starts in FPC `rtl/linux/ptypes.inc`, `rtl/darwin/ptypes.inc`,
  `rtl/freebsd/ptypes.inc`, `packages/pthreads/src/pthrlinux.inc`,
  `packages/pthreads/src/pthrandroid.inc`, and sibling pthread source files.
- Host-specific pthread capability truth stays in host base/ffi:
  `pthread_mutex_timedlock`, `pthread_condattr_setclock`,
  `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED`, timeout clock policy, mutex kind
  values, and `PLATFORM_POSIX_E*` mappings.
- Native thread id evidence is host-specific: Linux/Android use `gettid`,
  Darwin uses `pthread_threadid_np`, FreeBSD uses `pthread_getthreadid_np`, and
  generic Unix documents the `pthread_self` token fallback.

### CPU count declarations

- POSIX CPU count uses `sysconf` in shared POSIX FFI and
  `_SC_NPROCESSORS_ONLN` in host base. FPC source evidence starts in
  `rtl/linux`, `rtl/android`, `rtl/freebsd`, and `rtl/unix` families, but each
  host must own its own token.
- Windows CPU count uses `SYSTEM_INFO` and `GetSystemInfo`, declared in
  `nextpas.core.platform.windows.base` / `nextpas.core.platform.windows.ffi`.
  Evidence starts in FPC Windows units and falls back to Windows OS SDK headers
  when the installed FPC source does not expose the exact declaration text.

### Linux futex declarations

- Linux futex support belongs only in `nextpas.core.platform.linux.base` /
  `nextpas.core.platform.linux.ffi`.
- FPC `rtl/linux/linux.pp` records `FUTEX_WAIT`, `FUTEX_WAKE`, and futex helper
  shape. FPC `rtl/linux/x86_64/sysnr.inc` records `syscall_nr_futex = 202` for
  the current Linux x86_64 host; other architecture files prove that the syscall
  number is architecture-specific and must not be treated as universal.
- nextPas wrappers such as `linux_futex_wait_i32` and `linux_futex_wake_i32`
  consume the host-owned syscall number and operation tokens. They remain
  implementation evidence for `platform.sync`, not public API.

### Windows kernel32 declarations

- Windows base owns ABI shapes and constants: `SRWLOCK`,
  `CONDITION_VARIABLE`, `FILETIME`, `SYSTEM_INFO`, `DWORD`, `BOOL`, `HANDLE`,
  `INFINITE`, `WAIT_OBJECT_0`, `ERROR_TIMEOUT`, and TLS sentinel values.
- Windows FFI owns kernel32 declarations: `CreateThread`,
  `WaitForSingleObject`, `CloseHandle`, `GetCurrentThreadId`,
  `QueryPerformanceCounter`, `QueryPerformanceFrequency`,
  `GetSystemTimeAsFileTime`, `Sleep`, `SwitchToThread`, `GetLastError`,
  `GetSystemInfo`, `TlsAlloc`, `TlsFree`, `TlsSetValue`, `TlsGetValue`,
  `InitializeSRWLock`, `AcquireSRWLock*`, `TryAcquireSRWLock*`,
  `ReleaseSRWLock*`, `InitializeConditionVariable`,
  `SleepConditionVariableSRW`, `WakeConditionVariable`,
  `WakeAllConditionVariable`, `WaitOnAddress`, `WakeByAddressSingle`, and
  `WakeByAddressAll`.
- FPC Windows units are the first evidence pass. If the installed FPC source
  lacks newer APIs such as `WaitOnAddress`, the Windows OS SDK is the source of
  record, and the declaration must still land in nextPas-owned Windows base/ffi
  instead of a feature-specific `platform.sync.ffi`.

## Review Checklist

Before adding or changing a host ABI declaration:

- Check the relevant FPC source family and record the unit or include file in
  this index if it is not already listed.
- If FPC lacks the declaration, record the OS SDK/header family that supplies
  the missing truth.
- Put constants, record layouts, scalar aliases, opaque storage, and capability
  tokens in the host `base` owner.
- Put external declarations and thin host helpers in the host `ffi` owner.
- Keep `platform.time`, `platform.sync`, and `platform.thread` as unified
  public contracts that consume host base/ffi.
- Do not add runtime tests for raw OS APIs. Add or extend integration guards:
  owner placement, source-surface route truth, compile-only gates, and
  unified-contract tests for consumers instead.
