# nextPas Platform Goal Tree

Stable terminology: [master-spec](master-spec.md). Forward queue: [ROADMAP.md](ROADMAP.md).
Closed usability freeze: [residual-roadmap.md](residual-roadmap.md).

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.

- **Windows x86_64**: durable **`ci-matrix`** for documented 17-gate set on GHA
  `test-windows-runtime` (14 wine-suite dirs + poller/io/socket real); Wine
  runtime smoke secondary (now **15** matrix modules including `platform.error`).
  Windows script lists **18-gate candidate** (+error) pending durable GHA green
  before promote claims. Outside matrix: deeper AcceptEx/ConnectEx; signal is
  forced-compile/source-contract only; secure-zero is permanent FillChar+barrier.
  Forced Windows compile gates remain the compile-coherence boundary; remaining
  modules outside the documented set still need real-Windows runtime proof.
- **macOS**: **focused-runtime** for documented 8-gate set (ROADMAP D2.c).
- **FreeBSD / Android**: source-contract, forced-compile, or best-effort CI only.

Usability maintenance baseline 8.21 is closed (LT0–LT3 + dual-IO/F6 freeze). D0–D3 closed.
F7/F9/F10 Won't; F14 freetype stays under platform.

## Host Status

| Host | Current truth | Required next proof |
| --- | --- | --- |
| Linux x86_64 | focused-runtime across facade modules | keep gates green |
| Windows x86_64 | **ci-matrix** 17-gate set; wine 15-module secondary; 18-gate Windows script candidate | GHA green for +error then promote; keep wine green |
| macOS | **focused-runtime** 8-gate set (D2.c) | keep GHA matrix green |
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

**Wine smoke** (Win64 PE under Wine; secondary; **15** matrix modules): time,
memory, sync, thread, io, process, files, fs, path, env, mmap, random, socket,
error, io.reactor.iocp. Suites exist but are not matrix-gated yet: dl, pipe,
fmt, info, which. Not covered: signal, console, args, freetype/net, pty.

**Real Windows ci-matrix (17 promoted; 18-gate script candidate)**: time, memory,
sync, thread, io, process, files, fs, path, env, mmap, random, socket, error
(candidate), io.reactor.iocp, poller.windows_runtime_smoke,
platform.io.windows_real, platform.socket.windows_real. Promote 18 only after
durable GHA `test-windows-runtime` green. Not full-host parity outside that list.

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
| P7 macOS/Darwin | host truth | focused-runtime 8-gate set | keep matrix green |
| P8 FreeBSD | host truth | deferred | cross-platform-actions CI |
| P9 Android | host truth | deferred | NDK + bionic runtime |

## Evidence rules

- No status label without an evidence tier.
- `forced-compile` is not runtime proof.
- Linux runtime does not imply Windows runtime.
- Consumer source-contract tests prove ownership expectations, not host runtime.
