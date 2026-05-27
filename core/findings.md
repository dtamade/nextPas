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
