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
APIs such as `clock_gettime`, `pthread_*`, Linux `futex`, Windows
`WaitOnAddress`, `QueryPerformanceCounter`, and
`GetSystemTimeAsFileTime` are guarded by source evidence, source-surface checks,
compile-only gates, and focused runtime tests of the nextPas abstractions.

## Host Evidence Matrix

| Host | nextPas owner | FPC source evidence | Evidence scope |
| --- | --- | --- | --- |
| Linux | `nextpas.core.platform.linux.base` / `nextpas.core.platform.linux.ffi` | `rtl/linux/linux.pp`, `rtl/linux/ptypes.inc`, `rtl/linux/pthread.inc`, `rtl/linux/sysos.inc`, `rtl/linux/x86_64/sysnr.inc`, and sibling arch `sysnr.inc` files | `CLOCK_REALTIME`, `CLOCK_MONOTONIC`, `clock_gettime`, `clock_getres`, `timespec`, `__errno_location`, `gettid`, `_SC_NPROCESSORS_ONLN`, pthread shapes/functions, `pthread_condattr_setclock`, `pthread_mutex_timedlock`, `syscall_nr_futex`, `FUTEX_WAIT`, `FUTEX_WAKE` |
| Android | `nextpas.core.platform.android.base` / `nextpas.core.platform.android.ffi` | `rtl/android/*/sysnr.inc`, `packages/pthreads/src/pthrandroid.inc`, and Android Bionic headers when FPC does not expose the libc symbol directly | Android `clock_gettime` / `clock_getres` syscall families, `timespec`, `__errno`, `gettid`, `_SC_NPROCESSORS_ONLN`, pthread lifecycle/TLS/sync declarations, `pthread_mutex_timedlock`, `pthread_condattr_setclock` |
| Darwin | `nextpas.core.platform.darwin.base` / `nextpas.core.platform.darwin.ffi` | `rtl/darwin/ptypes.inc`, `rtl/darwin/pthread.inc`, `rtl/bsd/sysos.inc`, `rtl/unix/initc.pp`, plus Apple Darwin/Mach headers for Mach-only calls | `timespec`, pthread shapes/functions, `__error`, `pthread_threadid_np`, `mach_absolute_time`, `mach_timebase_info`, and the documented absence of `pthread_mutex_timedlock` / monotonic condattr policy on the current nextPas Darwin path |
| FreeBSD | `nextpas.core.platform.freebsd.base` / `nextpas.core.platform.freebsd.ffi` | `rtl/freebsd/freebsd.pas`, `rtl/freebsd/ptypes.inc`, `rtl/freebsd/pthread.inc`, `rtl/freebsd/sysnr.inc`, `rtl/bsd/sysos.inc` | `CLOCK_REALTIME`, `CLOCK_MONOTONIC = 4`, `clock_gettime`, `clock_getres`, `timespec`, `__error`, `pthread_getthreadid_np`, pthread lifecycle/TLS/sync declarations, `pthread_mutex_timedlock`, `pthread_condattr_setclock` |
| generic Unix | `nextpas.core.platform.unix.base` / `nextpas.core.platform.unix.ffi` | `rtl/unix/baseunix.pp`, `rtl/unix/unix.pp`, `rtl/unix/oscdeclh.inc`, `rtl/unix/initc.pp`, `rtl/unix/cthreads.pp`, and the closest proven host-specific FPC source before promoting a fallback into a real host | shared POSIX `clock_gettime`, `clock_getres`, `timespec`, `__errno_location` / `__error` errno families, pthread lifecycle/TLS/sync declarations, `pthread_condattr_setclock` policy, `_SC_NPROCESSORS_ONLN` fallback, and `pthread_self` native-id fallback |
| Windows | `nextpas.core.platform.windows.base` / `nextpas.core.platform.windows.ffi` | `rtl/win32/windows.pp`, `rtl/win64/windows.pp`, `packages/winunits-base`, and Windows OS SDK headers when FPC does not expose newer kernel32 APIs | `FILETIME`, `SYSTEM_INFO`, `CreateThread`, `WaitForSingleObject`, `CloseHandle`, `GetCurrentThreadId`, `QueryPerformanceCounter`, `GetSystemTimeAsFileTime`, `TlsAlloc`, `TlsFree`, `TlsSetValue`, `TlsGetValue`, `GetSystemInfo`, `SRWLOCK`, `CONDITION_VARIABLE`, `SleepConditionVariableSRW`, `WaitOnAddress`, `WakeByAddressSingle`, `WakeByAddressAll` |

## Declaration Evidence Classes

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
  own `pid_t` / `TPlatformProcessId`, and host `ffi` units expose
  `platform_process_id` and `platform_parent_process_id`.
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
- Do not add runtime tests for raw OS APIs. Add or extend source-surface,
  compile-only, and unified-contract tests instead.
