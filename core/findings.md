# nextpas.core platform findings

## 2026-05-28: Wave 14 remaining host helper naming cleanup

- Wave 13 fixed Linux-owned pthread/clock/errno/thread/cpu helper names, but the
  same unified-looking helper-name leak remains in Android, Darwin, FreeBSD, and
  generic Unix host FFI owners.
- Wave 14 should rename these host-owned helpers to `android_*`, `darwin_*`,
  `freebsd_*`, and `unix_*` while preserving shared `platform_posix_*` names in
  `nextpas.core.platform.posix.ffi` and public `platform_*` names in
  `platform.time`, `platform.sync`, and `platform.thread`.
- The same owner-name rule applies to Windows host-owned clock helper
  projections. QPC/FILETIME helpers belong to `nextpas.core.platform.windows.ffi`
  and should use `windows_clock_*`, while public `platform.time` names remain in
  the unified contract.
- This is a nextPas owner-boundary correction only. FPC raw API definitions,
  constants, records, external symbol names, and calling conventions remain the
  correctness authority and should not be runtime-probed by nextPas tests.
- The current wave deliberately does not rename older file/path/env/dl helpers
  that also still carry `platform_*` names in host FFI units. That family should
  be handled as a separate cleanup wave after the thread/sync/time helper
  surface is no longer misleading.

## 2026-05-28: Wave 13 Linux host helper naming cleanup

- User review correctly flagged that Linux host FFI helpers named
  `platform_pthread_*` look like a unified public `platform` contract even
  though they are host-owned projections over POSIX pthread/raw Linux ABI.
- The same naming leak exists on the Linux host path for `platform_clock_*`,
  `platform_errno_location`, `platform_posix_errno_value`,
  `platform_thread_self_token_u64`, `platform_native_thread_id_u64`, and
  `platform_cpu_count_i32`.
- Wave 13 should rename the Linux host-owned helper surface to `linux_*` and
  update the Linux branches in `platform.time.host`, `platform.sync`, and
  `platform.thread` to consume Linux-owned names. Shared `platform_posix_*`
  names stay unchanged because their owner is `nextpas.core.platform.posix.ffi`.
- Android, Darwin, FreeBSD, and generic Unix carry the same historical helper
  naming pattern. They are deliberately left for the next cleanup wave so this
  Linux correction remains reviewable and can be verified on the real local
  Linux path first.
- No runtime proof is needed for these raw helpers. FPC remains the ABI
  authority; this wave verifies nextPas owner/name discipline and compile
  coherence.

## 2026-05-28: Wave 12 process-id owner-name cleanup

- Wave 12 corrects a boundary inconsistency left by the early raw ABI import
  waves: POSIX host FFI units exposed `platform_process_id` and
  `platform_parent_process_id`, but no public `platform.process` contract
  exists yet.
- Process-id raw ABI still belongs to host owners. The declarations remain thin
  projections over FPC-backed `getpid` / `getppid` evidence, but their names now
  use the host owner prefix: `linux_process_id`, `android_process_id`,
  `darwin_process_id`, `freebsd_process_id`, and `unix_process_id`, plus the
  matching `*_parent_process_id` helpers.
- This cleanup intentionally does not runtime-test process IDs. FPC source is
  the authority for `getpid` / `getppid`; nextPas guards source ownership,
  documentation truth, absence of unified-looking process helper leaks, and
  compile coherence.
- This wave is deliberately narrow. Other historical host FFI helpers still use
  `platform_*` naming and need later owner-by-owner cleanup, but process-id was
  fixed first because `platform_process_*` directly implies a public process
  abstraction that has not been designed.

## 2026-05-28: Wave 11 POSIX signal-control decisions

- Wave 11 follows Wave 7. Wave 7 copied host signal numbers and wait-status
  macro arithmetic; Wave 11 copies the lower signal-control ABI needed to set
  handlers and masks: `sigset_t`, `sigactionrec`, signal action flags,
  `sigaction`, `sigprocmask`, `pthread_sigmask`, and host-specific Linux /
  Android syscall numbers.
- Signal-control raw ABI belongs in host `base` / `ffi` owners. It must not
  create `nextpas.core.platform.signal`, `nextpas.core.platform.signal.ffi`,
  `nextpas.core.platform.process`, or `nextpas.core.platform.process.ffi`.
- Shared POSIX must not own a fake `sigset_t` or `sigactionrec` shape in this
  wave. FPC records different signal set widths and action record layouts for
  Linux, Darwin, and FreeBSD, so those records stay in host `base` owners.
  `rtl/unix/gensigset.inc` remains evidence for future host-local pure helper
  projections, not proof of one universal nextPas signal-set record.
- Linux and Android signal-control route should be syscall-backed through
  `rt_sigaction` / `rt_sigprocmask` according to FPC `rtl/linux/ossysc.inc`
  and Android/Linux syscall tables.
- Darwin and FreeBSD signal-control route should be libc-backed through
  `sigaction`, `sigprocmask`, and `pthread_sigmask` according to FPC
  `rtl/unix/oscdeclh.inc`, `rtl/darwin/pthread.inc`, and
  `rtl/freebsd/pthread.inc`.
- Darwin `pthread_sigmask` is declared by FPC in `rtl/darwin/pthread.inc` as
  `external 'c'`; nextPas Darwin host ffi should mirror that libc route rather
  than spelling a separate pthread library for this symbol.
- Windows is deliberately out of this wave. Windows control events and signal
  compatibility need a separate public design and should not be collapsed into
  POSIX signal ABI inventory.

## 2026-05-28: FPC source evidence for Wave 11

- Linux signal constants, `sigset_t`, handlers, and `sigactionrec` evidence
  starts in `rtl/linux/signal.inc`; `wordsinsigset`, `ln2bitsinword`, and
  `ln2bitmask` evidence starts in `rtl/linux/ostypes.inc`.
- Linux syscall route evidence starts in `rtl/linux/ossysc.inc`, where FPC
  implements `Fpsigaction` through `syscall_nr_rt_sigaction` and
  `FPSigProcMask` through `syscall_nr_rt_sigprocmask`; x86_64 syscall numbers
  start in `rtl/linux/x86_64/sysnr.inc`, and aarch64-style numbers start in
  `rtl/linux/sysnr-gen.inc`.
- Android syscall numbers start in `rtl/android/x86_64/sysnr.inc` and
  `rtl/android/aarch64/sysnr.inc`; Android follows the Linux-derived generic
  syscall route for this signal-control wave.
- Darwin signal constants, `sigset_t`, and `SigActionRec` evidence starts in
  `rtl/darwin/signal.inc`; Darwin libc `sigaction` / `sigprocmask` evidence
  starts in `rtl/unix/oscdeclh.inc`; Darwin `pthread_sigmask` evidence starts
  in `rtl/darwin/pthread.inc`.
- FreeBSD signal constants, `sigset_t`, and `SigActionRec` evidence starts in
  `rtl/freebsd/signal.inc`; BSD `wordsinsigset` evidence starts in
  `rtl/bsd/ostypes.inc`; FreeBSD syscall numbers are recorded in
  `rtl/freebsd/sysnr.inc`, while the host binding route for this wave remains
  the libc route from `rtl/unix/oscdeclh.inc` plus pthread mask evidence from
  `rtl/freebsd/pthread.inc`.
- Shared POSIX signal set arithmetic evidence starts in
  `rtl/unix/gensigset.inc`: `fpsigaddset`, `fpsigdelset`, `fpsigemptyset`,
  `fpsigfillset`, and `fpsigismember`. This evidence uses host parameters such
  as `wordsinsigset`, `ln2bitsinword`, and `ln2bitmask`; it should be promoted
  as host-local helpers or a parameterized helper later, not as a universal
  `TPlatformPosixSignalSet` record.

## 2026-05-28: Wave 10 POSIX host stat decisions

- Wave 10 continues the Wave 9 deferred POSIX stat family by promoting Darwin,
  FreeBSD, and Android traditional `stat` / `lstat` / `fstat` raw ABI into
  host-owned `base` / `ffi` units.
- Generic Unix traditional stat remains deferred. FPC records host-specific
  record layouts and suffix/syscall policies; nextPas must not invent a generic
  `TPlatformUnixStat` shape just to fill a matrix row.
- Darwin stat belongs in `nextpas.core.platform.darwin.base`, and Darwin raw
  bindings belong in `nextpas.core.platform.darwin.ffi` with the FPC
  `$INODE64` external symbol policy.
- FreeBSD stat belongs in `nextpas.core.platform.freebsd.base`, and FreeBSD
  raw bindings belong in `nextpas.core.platform.freebsd.ffi` through the direct
  libc `stat`, `lstat`, and `fstat` symbols.
- Android stat belongs in `nextpas.core.platform.android.base`, and Android
  raw helpers belong in `nextpas.core.platform.android.ffi` through FPC's
  Linux-derived syscall route (`newfstatat` / `fstat` for the current x86_64
  and aarch64 nextPas CPU set), not Linux glibc `__xstat` wrappers.
- Shared `nextpas.core.platform.posix.base` and
  `nextpas.core.platform.posix.ffi` must still not own a generic POSIX stat
  record or generic `stat` / `lstat` / `fstat` bindings.
- Wave 10 remains raw ABI inventory, not a public `platform.file` or
  `platform.fs` contract.

## 2026-05-28: FPC source evidence for Wave 10

- Darwin and FreeBSD stat record evidence starts in
  `rtl/bsd/ostypes.inc`. The Darwin branch uses `darwin_new_iostructs` for the
  current 64-bit nextPas Darwin target shape; the FreeBSD branch records the
  host-specific padding, birth time, flags, generation, and spare fields.
- Darwin scalar evidence starts in `rtl/darwin/ptypes.inc`, where FPC records
  `dev_t`, `ino_t`, `mode_t`, `nlink_t`, `uid_t`, `gid_t`, `off_t`, and
  `time_t` widths used by the Darwin stat record.
- FreeBSD scalar evidence starts in `rtl/freebsd/ptypes.inc`, where FPC records
  `dev_t`, `ino_t`, `mode_t`, `nlink_t`, `uid_t`, `gid_t`, `off_t`, and
  `time_t` widths used by the FreeBSD stat record.
- Non-Linux Unix symbol evidence starts in `rtl/unix/oscdeclh.inc`, where FPC
  binds `FpFstat`, `FpLstat`, and `FpStat` to direct libc symbols with
  large-file suffix handling, including Darwin's `darwinsuffix64bit =
  '$INODE64'`.
- Android source ownership starts in `rtl/android/Makefile`, which routes
  Android POSIX type/system include ownership through Linux include families.
  The concrete stat records for current nextPas Android CPUs come from
  `rtl/linux/x86_64/stat.inc` and `rtl/linux/aarch64/stat.inc`.
- Android syscall evidence starts in `rtl/android/x86_64/sysnr.inc` and
  `rtl/android/aarch64/sysnr.inc`; FPC records `syscall_nr_newfstatat` and
  `syscall_nr_fstat` for both current nextPas Android CPU targets.
- Android route evidence starts in `rtl/linux/osdefs.inc`,
  `rtl/linux/ossysc.inc`, and `rtl/linux/bunxsysc.inc`: Android defines
  `generic_linux_syscalls`, path stat routes through `fstatat` /
  `newfstatat`, fd stat routes through `fstat`, and lstat routes through
  `fstatat` with `AT_SYMLINK_NOFOLLOW`.

## 2026-05-28: raw ABI verification boundary reaffirmed

- FPC source is the correctness authority for copied platform API definitions.
  If FPC carries the API, constant, record shape, syscall number, external
  symbol, or calling convention, nextPas treats that definition as correct when
  importing raw ABI inventory.
- Wave 10 checks must not runtime-prove FPC's Darwin, FreeBSD, or Android stat
  layouts or syscall/libc routes. The nextPas guard checks only source-surface
  integration: owner placement, docs truth, route truth, absence of
  feature-specific FFI units, no FPC platform-unit dependencies, and simulated
  compile coherence.

## 2026-05-28: Wave 9 Linux traditional stat decisions

- Wave 9 is a host-specific promotion of the deferred POSIX stat family. It
  covers Linux traditional `stat` / `lstat` / `fstat` raw ABI only.
- Shared `nextpas.core.platform.posix.base` must still not own a generic
  `TPlatformStat` record, and shared `nextpas.core.platform.posix.ffi` must
  still not declare generic `stat`, `lstat`, or `fstat` bindings. FPC records
  host-specific layouts and suffix policy, so the shared POSIX owner would be
  the wrong layer.
- Linux stat record shape belongs in `nextpas.core.platform.linux.base`.
  Linux libc wrapper declarations and Linux-prefixed thin helpers belong in
  `nextpas.core.platform.linux.ffi`.
- Android, Darwin, FreeBSD, and generic Unix traditional stat promotion remains
  out of scope for this wave. They need separate owner decisions because FPC
  records Android syscall policy, Darwin `$INODE64` suffix handling, and BSD
  record layout differences separately.
- Wave 9 remains raw ABI import, not a public `platform.file` or
  `platform.fs` contract.

## 2026-05-28: FPC source evidence for Wave 9

- Linux `_STAT_VER` policy starts in `rtl/linux/ostypes.inc`. For the current
  nextPas Linux CPU set, FPC uses `_STAT_VER_LINUX = 1` on x86_64 and
  `_STAT_VER_LINUX = 0` on aarch64.
- Linux x86_64 record evidence starts in `rtl/linux/x86_64/stat.inc`, where
  FPC defines the packed `stat` record with `st_dev`, `st_ino`, `st_nlink`,
  `st_mode`, ownership ids, device ids, size/block fields, timestamp seconds /
  nanoseconds, and unused padding.
- Linux aarch64 record evidence starts in `rtl/linux/aarch64/stat.inc`, where
  FPC defines the asm-generic `stat` record with `st_dev`, `st_ino`, mode/link
  fields, ownership ids, device ids, size/block fields, timestamp seconds /
  nanoseconds, and trailing unused fields.
- Linux libc wrapper evidence starts in `rtl/linux/osmacro.inc`: FPC declares
  `__fxstat`, `__xstat`, and `__lxstat`, then implements `FpFstat`, `FpStat`,
  and `FpLstat` by passing `_STAT_VER`.
- `rtl/unix/oscdeclh.inc` records the broader Unix boundary: Linux gets macro
  wrappers, while non-Linux Unix hosts use direct `fstat`, `lstat`, and `stat`
  symbols with large-file / Darwin suffix policy. That is why Wave 9 keeps the
  shared POSIX owner empty and promotes only Linux.

## 2026-05-28: raw ABI correctness boundary

- FPC source is the authority for copied platform ABI definitions. If FPC carries
  the constant, record shape, external declaration, syscall number, or wait
  status macro logic, nextPas treats the definition as correct.
- nextPas raw ABI wave tests should not prove FPC values at runtime. They should
  guard only nextPas integration discipline: owner placement, documentation
  truth, official route truth, feature-specific FFI absence, no FPC platform-unit
  dependency, and compile coherence.
- A raw ABI import wave can cite FPC source evidence directly as the correctness
  authority. Extra nextPas runtime probes against libc/syscalls would be
  redundant and risk turning ABI inventory work into behavior testing.
- Runtime behavior tests remain necessary for unified nextPas public contracts
  such as `platform.time`, `platform.sync`, and `platform.thread`.

## 2026-05-28: Wave 8 file I/O continuation decisions

- Wave 8 continues the earlier file ABI inventory. It remains raw host ABI
  import, not a public `platform.file` contract.
- Shared POSIX file I/O scalar aliases belong in
  `nextpas.core.platform.posix.base`; shared POSIX externals and thin helpers
  for `read`, `write`, `lseek`, `fsync`, and `ftruncate` belong in
  `nextpas.core.platform.posix.ffi`.
- `SEEK_SET`, `SEEK_CUR`, and `SEEK_END` are host `base` constants even though
  the current FPC values match across Linux/BSD/macOS. Host ownership keeps the
  ABI source clear when more platforms are promoted.
- POSIX host `ffi` units may expose delegated file helpers with the existing
  `platform_file_*` raw-host-helper shape because Wave 2 already established
  that pattern for `open` / `close` / `fcntl`. This still must not create
  `nextpas.core.platform.file` or `nextpas.core.platform.file.ffi`.
- Windows file positioning, sizing, sync, and truncation belong in
  `nextpas.core.platform.windows.base` / `nextpas.core.platform.windows.ffi`.
  Raw declarations should mirror FPC-shaped kernel32 entrypoints first; helpers
  stay thin and Windows-prefixed.

## 2026-05-28: FPC source evidence for Wave 8

- POSIX `read`, `write`, `lseek`, and `ftruncate` evidence starts in
  `rtl/unix/oscdeclh.inc`, where FPC declares libc `read`, `write`,
  `lseek` plus suffix handling, and `ftruncate` plus suffix handling.
- POSIX syscall wrapper evidence also appears in `rtl/unix/bunxh.inc`,
  `rtl/linux/ossysc.inc`, and `rtl/bsd/ossysc.inc` through
  `FPC_SYSC_READ`, `FPC_SYSC_WRITE`, `FPC_SYSC_LSEEK`, and
  `FPC_SYSC_FTRUNCATE`.
- POSIX `fsync` evidence starts in `rtl/unix/unxdeclh.inc`, where FPC declares
  libc `fsync`; Linux and BSD syscall wrapper source records the same surface.
- POSIX seek token evidence starts in `rtl/linux/ostypes.inc`,
  `rtl/bsd/ostypes.inc`, and `rtl/macos/macostp.inc`, where `SEEK_SET = 0`,
  `SEEK_CUR = 1`, and `SEEK_END = 2`.
- Windows evidence starts in `rtl/win/wininc/func.inc` and
  `rtl/win/wininc/redef.inc` for `GetFileSize`, `SetFilePointer`,
  `FlushFileBuffers`, `SetEndOfFile`, `GetFileSizeEx`, and
  `SetFilePointerEx`; FPC usage is visible in `rtl/win/sysfile.inc` and
  `rtl/win/sysutils.pp`.

## 2026-05-28: Wave 7 owner decisions

- POSIX wait option tokens such as `WNOHANG` and `WUNTRACED` belong in each POSIX
  host `base` unit because wait option values are host ABI constants.
- POSIX signal tokens belong in each POSIX host `base` unit. Common values such
  as `SIGHUP`, `SIGINT`, `SIGKILL`, and `SIGTERM` are still host-owned; `SIGCHLD`
  must remain host-specific because Linux and BSD/Darwin differ.
- POSIX wait-status decoding is pure macro arithmetic in FPC. It belongs in
  `nextpas.core.platform.posix.math`, not in host `ffi` and not in a public
  process contract.
- Windows wait result, process status, duplication, synchronization, and process
  access tokens belong in `nextpas.core.platform.windows.base`.
- Wave 7 still must not create `nextpas.core.platform.process.pas` or
  `nextpas.core.platform.process.ffi.pas`.

## 2026-05-28: FPC source evidence for Wave 7

- POSIX wait options: `rtl/linux/ostypes.inc`, `rtl/bsd/ostypes.inc`, and
  `packages/libc/src/bwaitflagsh.inc` record `WNOHANG = 1` and `WUNTRACED = 2`
  for the current Linux/BSD-style nextPas hosts.
- POSIX wait-status macro logic: `packages/libc/src/bwaitflags.inc`,
  `packages/libc/src/bwaitstatus.inc`, `packages/libc/src/bwaitstatush.inc`,
  and `rtl/unix/unix.pp` record `WEXITSTATUS`, `WTERMSIG`, `WSTOPSIG`,
  `WIFEXITED`, `WIFSIGNALED`, `WIFSTOPPED`, `WCOREDUMP`, `W_EXITCODE`, and
  `W_STOPCODE`.
- Linux signal values come from `rtl/linux/signal.inc`. On the current
  non-SPARC/non-MIPS nextPas Linux CPU set, `SIGCHLD = 17`; `SIGHUP = 1`,
  `SIGINT = 2`, `SIGKILL = 9`, and `SIGTERM = 15`.
- Darwin signal values come from `rtl/darwin/signal.inc`, including
  `SIGCHLD = 20`.
- FreeBSD signal values come from `rtl/freebsd/signal.inc`, including
  `SIGCHLD = 20`.
- Windows constants come from `rtl/win/wininc/defines.inc`: `WAIT_TIMEOUT`,
  `WAIT_FAILED`, `STILL_ACTIVE`, `SYNCHRONIZE`, `PROCESS_TERMINATE`, and
  `DUPLICATE_SAME_ACCESS`.
