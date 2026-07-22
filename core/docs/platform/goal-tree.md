# nextPas Platform Goal Tree

Stable terminology: [master-spec](master-spec.md). Forward queue: [ROADMAP.md](ROADMAP.md).
Closed usability freeze: [residual-roadmap.md](residual-roadmap.md).

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.

- **Windows x86_64**: durable **`ci-matrix`** for documented **27 platform gates**
  on GHA `test-windows-runtime` (+… +pty +watch S1–S3 multi-dir). `watch` PASS on run
  29746628175 (pass=28 fail=0 with mem.host). L2 `l2.fs.watch` (multi-path +
  AddTree walk, no `bWatchSubtree`) step-green on GHA 29759582229 @ `1790012ef`.
  Wine secondary **25** (+console). Watch expand series **closed** 2026-07-21.
  **Not full-host real-Windows runtime** parity: modules outside the 27-gate list,
  AcceptEx/ConnectEx depth, and whole-job reds (async native) are not platform claims.
- **macOS**: **focused-runtime** for documented **9 platform gates** (layer A:
  `platform-macos-ci-matrix.sh` fail-closed). Script may list mem.host → total=10.
  **Whole `test-macos` job** (layer B) may fail on non-platform inventory; that
  does not demote layer A.
- **FreeBSD / Android**: source-contract, forced-compile, or best-effort CI only.

Usability maintenance baseline 8.21 is closed (LT0–LT3 + dual-IO/F6 freeze). D0–D3 closed.
F7/F9/F10 Won't; F14 freetype stays under platform.

## Host Status

| Host | Current truth | Required next proof |
| --- | --- | --- |
| Linux x86_64 | focused-runtime across facade modules | keep gates green |
| Windows x86_64 | **ci-matrix** 27 platform gates (+ optional mem.host in script) | keep GHA+wine green; remaining real-Windows runtime gap = full-host parity / non-matrix modules; expand only on consumer pain |
| macOS | **focused-runtime** 9 platform gates (layer A fail-closed) | keep layer A green; layer B job is not platform evidence |
| FreeBSD | best-effort | forced-compile or runtime when CI stable |
| Android | forced-compile fragments | runtime evidence |

## Evidence Gates

| Gate family | What it proves |
| --- | --- |
| `test_poller_windows_contract` | IOCP/poller source-contract |
| `test_poller_windows_compile_gate` | IOCP forced Windows compile |
| `test_platform_windows_poller_compile_gate` | platform poller forced Windows compile |
| `test_async` | Linux async consumer runtime |
| `test_platform_resource` | Linux resource limits (focused-runtime) |
| Android resource limits | Android resource-limit source/compile proof only |
| `test_platform_memory*` | secure zero + compile gate |
| Android files/mmap forced-compile proof only | files/mmap compile-only truth |

These prove source shape and forced compile coherence, not full-host runtime.
Focused runtime gates use heaptrc for leak-proof validation.

## Windows matrix evidence

**Wine smoke** (Win64 PE under Wine; secondary; **25** matrix modules): time,
memory, sync, thread, io, process, files, fs, path, env, mmap, random, socket,
error, fmt, info, which, dl, pipe, args, resource, watch (RDCW create/timeout;
event soft under Wine), pty (ConPTY open/close; resize may E_NOTIMPL under Wine),
console (is_terminal/get_size/enable_ansi/write smoke), io.reactor.iocp.
Not covered: signal, freetype/net.

**Real Windows ci-matrix (27 platform gates)** via `platform-windows-ci-matrix.sh`:
time, memory, sync, thread, io, process, files, fs, path, env, mmap, random,
socket, error, fmt, info, which, dl, args, pipe, resource, pty, watch,
io.reactor.iocp, poller.windows_runtime_smoke, platform.io.windows_real,
platform.socket.windows_real. Promoted with `watch` after GHA PASS
platform.watch (run 29746628175). Optional **mem.host_runtime** is mem-owned.
L2 consumer min-set (`l2-windows-ci-matrix.sh`) includes `l2.fs.watch`
(multi-path + AddTree; host-windows hard asserts).

## IOCP / readiness boundary

- **Windows readiness poller**: readiness-only path; durable under documented
  ci-matrix + wine-runtime-smoke. Separate from completion-queue depth.
- **IOCP read/write**: file AsyncRead/AsyncWrite implemented and smoke-covered.
- Non-read/write completion depth beyond current AcceptEx/ConnectEx smoke remains
  unsupported as a full-host claim (see [runtime-truth-matrix.md](runtime-truth-matrix.md)).

## Milestones

| Milestone | Goal | Current truth | Next proof |
| --- | --- | --- | --- |
| P1 Host ABI inventory | constants, records, handles | stable | keep gap matrix current |
| P2 Feature facades | portable APIs | focused-runtime / Windows ci-matrix | expand consumers |
| P3 Readiness lane | platform_poller_*, wake | Linux runtime; Windows in ci-matrix | keep GHA green |
| P4 Completion lane | IOCP/proactor | ci-matrix poller/iocp + focused-runtime | deepen AcceptEx/ConnectEx |
| P5 Tier 2 targets | aarch64/riscv64/arm32 | 13-module forced-compile | FreeBSD/Android compile |
| P6 Benchmarks | performance baseline | 14-operation baseline | cross-platform compare |
| P7 macOS/Darwin | host truth | focused-runtime 9-gate set | keep matrix green |
| P8 FreeBSD | host truth | deferred | cross-platform-actions CI |
| P9 Android | host truth | deferred | NDK + bionic runtime |

## Evidence rules

- No status label without an evidence tier.
- `forced-compile` is not runtime proof.
- Linux runtime does not imply Windows runtime.
- Consumer source-contract tests prove ownership expectations, not host runtime.
