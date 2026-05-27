# Platform Host FFI Gap Matrix

This document records the current platform host ABI surface for
`nextpas.core.platform`. It is a source-surface guard companion, not runtime
proof. Runtime behavior tests cover the unified public contracts in
`platform.time`, `platform.sync`, and `platform.thread`; raw OS APIs such as
`clock_gettime`, `pthread_*`, `futex`, `WaitOnAddress`,
`QueryPerformanceCounter`, and `GetSystemTimeAsFileTime` are verified through
FPC source evidence, host-owned declarations, source-surface checks, and
compile-only gates.

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
thin helpers around those declarations. Feature modules are unified platform
contracts and should not create `platform.time.ffi`, `platform.sync.ffi`, or
`platform.thread.ffi`.

| Host | Base owner | FFI owner | Clock | Errno | CPU count | Native thread id | Thread lifecycle | TLS | pthread sync | Timeout capability |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Linux | `nextpas.core.platform.linux.base` | `nextpas.core.platform.linux.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 1`, platform clock helpers | `__errno_location`, Linux `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 84` | `gettid` plus `platform_posix_thread_self_token_u64` for self token | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers plus Linux futex wait/wake | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1` |
| Android | `nextpas.core.platform.android.base` | `nextpas.core.platform.android.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 1`, platform clock helpers | Android `__errno`, Android `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 97` | `gettid` plus `platform_posix_thread_self_token_u64` for self token | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1` |
| Darwin | `nextpas.core.platform.darwin.base` | `nextpas.core.platform.darwin.ffi` | POSIX realtime plus Mach monotonic helpers | `__error`, Darwin `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 58` | `pthread_threadid_np`, fallback to `platform_posix_thread_self_token_u64` if needed | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 0`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0` |
| FreeBSD | `nextpas.core.platform.freebsd.base` | `nextpas.core.platform.freebsd.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 4`, platform clock helpers | `__error`, FreeBSD `PLATFORM_POSIX_E*` values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = 58` | `pthread_getthreadid_np`, fallback to `platform_posix_thread_self_token_u64` if needed | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 1` |
| generic Unix | `nextpas.core.platform.unix.base` | `nextpas.core.platform.unix.ffi` | `CLOCK_REALTIME = 0`, `CLOCK_MONOTONIC = 1`, platform clock helpers | generic `__errno_location`, generic `PLATFORM_POSIX_E*` fallback values | `PLATFORM_SYSCONF_NPROCESSORS_ONLN = -1` | fallback to `platform_posix_thread_self_token_u64` | pthread state helper backed by `pthread_create/join/detach` | pthread TLS helpers | pthread mutex/rwlock/condvar helpers | `PLATFORM_PTHREAD_CONDATTR_SETCLOCK_SUPPORTED = 1`, `PLATFORM_PTHREAD_MUTEX_TIMEDLOCK_SUPPORTED = 0` |
| Windows | `nextpas.core.platform.windows.base` | `nextpas.core.platform.windows.ffi` | Windows kernel32 path: QPC for monotonic time, FILETIME for realtime | `GetLastError` result helpers | `GetSystemInfo` | `GetCurrentThreadId` | `CreateThread`, wait, close, and state refcount helpers | `TlsAlloc`, `TlsFree`, `TlsSetValue`, `TlsGetValue` | `SRWLOCK`, `CONDITION_VARIABLE`, and `WaitOnAddress` helpers | millisecond timeout conversion and kernel32 timeout classifiers |

## Known Gaps

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

The official host gap matrix check is a source-surface guard. It checks that the
document, host `base/ffi` tokens, known gap markers, and feature-FFI absence
stay synchronized. It is not runtime proof for Darwin, Android, FreeBSD,
generic Unix, or Windows.

Current evidence classes should be read separately:

- Linux behavior tests are runtime proof for the Linux host.
- Win64 checks are compile-only proof for the Windows branch.
- Simulated Darwin, Android, FreeBSD, and generic Unix checks are compile-only
  proof for branch selection and unit surface coherence.
- Source-surface checks keep ownership boundaries from drifting between host
  `base/ffi`, shared POSIX helpers, and unified feature contracts.
