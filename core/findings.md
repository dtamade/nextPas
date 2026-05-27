# nextpas.core platform findings

## 2026-05-28: raw ABI correctness boundary

- FPC source is the authority for copied platform ABI definitions. If FPC carries
  the constant, record shape, external declaration, syscall number, or wait
  status macro logic, nextPas treats the definition as correct.
- nextPas raw ABI wave tests should not prove FPC values at runtime. They should
  guard only nextPas integration discipline: owner placement, documentation
  truth, official route truth, feature-specific FFI absence, no FPC platform-unit
  dependency, and compile coherence.
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
