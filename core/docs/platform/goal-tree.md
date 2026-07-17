# nextPas Platform Goal Tree

Stable terminology: [master-spec](master-spec.md). Forward queue: [ROADMAP.md](ROADMAP.md).
Closed usability freeze: [residual-roadmap.md](residual-roadmap.md).

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.

- **Windows x86_64**: durable **`ci-matrix`** for documented 17-gate set on GHA
  `test-windows-runtime` (14 wine-suite dirs + poller/io/socket real); Wine
  runtime smoke secondary. Outside matrix: deeper AcceptEx/ConnectEx; signal is
  forced-compile/source-contract only; secure-zero is permanent FillChar+barrier.
- **macOS**: **focused-runtime** for documented 8-gate set (ROADMAP D2.c).
- **FreeBSD / Android**: source-contract, forced-compile, or best-effort CI only.

Usability baseline 8.21 is maintenance (LT0–LT3 + dual-IO/F6 freeze). D0–D3 closed.
F7/F9/F10 Won't; F14 freetype stays under platform.

## Host Status

| Host | Current truth | Required next proof |
| --- | --- | --- |
| Linux x86_64 | focused-runtime across facade modules | keep gates green |
| Windows x86_64 | **ci-matrix** 17-gate set; wine secondary | expand matrix; keep GHA+wine green |
| macOS | **focused-runtime** 8-gate set (D2.c) | keep GHA matrix green |
| FreeBSD | best-effort | forced-compile or runtime when CI stable |
| Android | forced-compile fragments | runtime evidence |

## Evidence Gates

| Gate family | What it proves |
| --- | --- |
| `test_poller_windows_*` / platform poller compile | IOCP/poller source-contract + forced compile |
| `test_async` | Linux async consumer runtime |
| `test_platform_resource` | Linux resource limits |
| `test_platform_memory*` | secure zero + compile gate |
| Android files/mmap compile | forced-compile only |

These prove source shape and forced compile coherence, not full-host runtime.
Focused runtime gates use heaptrc for leak-proof validation.

## Windows matrix evidence

**Wine smoke** (Win64 PE under Wine; secondary): time, memory, sync, thread, io,
process, files, fs, path, env, mmap, random, socket, dl, pipe, fmt, info, error,
which, io.reactor.iocp. Not covered: signal, console, args, freetype/net, pty.

**Real Windows ci-matrix (17)** via `platform-windows-ci-matrix.sh`: time, memory,
sync, thread, io, process, files, fs, path, env, mmap, random, socket,
io.reactor.iocp, poller.windows_runtime_smoke, platform.io.windows_real,
platform.socket.windows_real. Not full-host parity outside that list.

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
