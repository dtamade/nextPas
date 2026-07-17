# nextPas Platform Goal Tree

Stable terminology lives in [master-spec](master-spec.md). This file tracks
phase state and evidence only.

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.
Windows has focused-runtime evidence for 14 modules on real Windows VM via SSH,
plus Wine runtime smoke for 20 modules. macOS, FreeBSD, and Android remain
source-contract or forced-compile only.

### 2026-07-17 process/console/pty contract slice

Linux focused-runtime evidence added/refreshed for:

- `platform_process_*_ex` pipe IO error-code APIs + deprecated legacy wrappers
- console unsupported write stubs (`PLATFORM_ERR_UNSUPPORTED`, no raw `-1`)
- pty `IsEmpty` / Windows validity / unsupported close clearing

Windows truth tiers are **unchanged** by this slice (no new real-Windows or
Wine matrix promotion). Wine compile remains environment-dependent
(`ppcrossx64` required).

### 2026-07-17 usability residual (M0–M7)

- `PLATFORM_ERR_UNKNOWN` (-8): Windows unmapped host errors never passthrough raw `ERROR_*`
- `PLATFORM_ERR_PATH_TOO_LONG` stays -7 (domain path clamp; not OS ENAMETOOLONG)
- `platform_io_*` dual-API documented as transitional for process.pipe
- EXAMPLES.md: no SysUtils in sample code
- Authority: ERROR-HANDLING / RETURN-SEMANTICS / API-REFERENCE aligned

### 2026-07-17 usability residual wave-2 (assessment 7.28)

- EXAMPLES rewritten to live `files`/`fs`/`socket`/`env`/`fmt` APIs (no `fileio` / `platform.net_*` ghosts)
- `PLATFORM_FS_SHORT_*` → alias `PLATFORM_ERR_IO`; `platform_parse_*` fails with `PLATFORM_ERR_INVALID`
- CONTRACT L0 wording: host FFI + ban FPC RTL (not “depends on FPC RTL”)
- Full production RTL uses scan + expanded out-init contracts in return_semantics gate
- Windows/macOS/Android truth tiers **unchanged** (no fake promotion)

### 2026-07-17 usability residual wave-3 (assessment 7.91)

- BEST-PRACTICES rewritten to live APIs; `api-reference.md` redirect-only; historical USABILITY banner points to wave-3 score
- `platform_dl_error` length failure → `PLATFORM_ERR_INVALID`; RETURN length/out-init/stub rules expanded
- files seek/stat out-init strengthened; return_semantics contracts for dl_error / seek / stat / BEST-PRACTICES ghosts
- F6 raw OS side-channel **Won't this wave**; F7 POSIX/Windows asymmetry **documented**; F10 diagnostics deferred
- Host truth tiers **unchanged** (no fake promotion)

### 2026-07-17 usability residual wave-4 (assessment 8.21)

- CONTRACT §1.1 submodule table aligned to live API names (no resource_get / fmt_snprintf / pipe_open ghosts)
- unsupported stubs: files open + socket create/accept (+ Windows socket_pair) out-init sentinels
- USABILITY banner → 8.21; API-REFERENCE cross-links RETURN/ERROR; RETURN names `str_find` as index value-sentinel
- F6 raw OS API / F8 doctest / F9 rename / host truth **unchanged** (Won't or deferred)

### 2026-07-17 long-term residual LT0–LT3 (usability maintenance)

Usability is **maintenance baseline 8.21** — no open wave-5. Authority: [residual-roadmap.md](residual-roadmap.md).

| Stage | Result |
| --- | --- |
| LT0 | residual-roadmap + goal-tree/README freeze; USABILITY maintenance banner |
| LT1 | QUICKSTART live-name gate + `test_platform_docs_live_patterns` smoke (F8) |
| LT2 | `process.pipe` off all `platform_io_*` call sites; dual-IO owner-only (F5) |
| LT3 | `platform_get_last_os_error` raw host side-channel (F6) |
| LT4 | Windows/macOS host truth — **registered only**, not claimed ready |
| Deferred | F7 mapping symmetry, F9 rename, F10 diagnostics, F14 freetype move-out |

## Host Status

| Host | Current truth | Required next proof |
| --- | --- | --- |
| Linux x86_64 | focused-runtime across all facade modules | keep gates green |
| Windows x86_64 | focused-runtime 14 modules; wine-runtime-smoke 20 modules; real-Windows runtime gap remains | promote to ci-matrix |
| macOS / FreeBSD | source-contract and selected compile fragments | runtime evidence |
| Android | forced-compile fragments | runtime evidence |

## Evidence Gates

Windows readiness and completion proof is split across:
- `test_poller_windows_contract` — IOCP/poller source-contract (IOCP read/write operations)
- `test_poller_windows_compile_gate` — consumer IOCP forced compile
- `test_platform_windows_poller_compile_gate` — platform readiness poller
- `test_async` — Linux async consumer runtime
- `test_platform_resource` — Linux resource limits (Linux runtime, Windows unsupported)
- `test_platform_memory` / `test_platform_memory_secure_zero_compile_gate` — secure zero
- `test_platform_files_android_compile` / `test_platform_mmap_android_compile` — Android files/mmap forced-compile proof only

These gates prove source shape and forced Windows compile coherence, not Windows runtime behavior.
Focused runtime gates use heaptrc for leak-proof validation.

## Wine Runtime Smoke Evidence (20 modules)

Cross-compiled to Win64 PE via `-Twin64`, executed under Wine 10.0.

| Module | Tests | Known gaps |
| --- | :-: | --- |
| platform.time | 5 | — |
| platform.memory | 8 | — |
| platform.sync | 14 | recursive mutex (SRWLOCK unsupported) |
| platform.thread | 9 | WaitOnAddress availability |
| platform.io | 4 | — |
| platform.process | 7 | — |
| platform.files | 14 | — |
| platform.fs | 11 | — |
| platform.path | 11 | — |
| platform.env | 5 | — |
| platform.mmap | 7 | — |
| platform.random | 4 | — |
| platform.socket | 4 | — |
| platform.dl | 8 | — |
| platform.pipe | 8 | — |
| platform.fmt | 10 | — |
| platform.info | 5 | — |
| platform.error | 6 | — |
| platform.which | 5 | — |
| io.reactor.iocp | 8 | ConnectEx graceful skip |

Not covered by Wine: signal (SetConsoleCtrlHandler unsupported), console (pseudo-TTY),
args (FPC RTL ParamStr cross-platform), freetype/net (extra deps), pty (Unix-only).

## Windows Real Runtime Evidence

| Module | Tests | Known gaps |
| --- | :-: | --- |
| platform.io (real) | 10 | IOCP/AcceptEx/ConnectEx not tested |
| platform.socket (real) | 16 | AcceptEx/ConnectEx/TransmitFile not tested |

## Milestones

| Milestone | Goal | Current truth | Next proof |
| --- | --- | --- | --- |
| P1 Host ABI inventory | Host constants, records, handles | done | keep gap matrix current |
| P2 Feature facades | 14 portable APIs | focused-runtime on Windows | expand consumer coverage |
| P3 Readiness lane | platform_poller_*, wake, userdata | Linux runtime; Wine CI matrix; Windows readiness poller | real-Windows CI runner |
| P4 Completion lane | IOCP/proactor | focused-runtime | promote to ci-matrix |
| P5 Tier 2 targets | aarch64/riscv64/arm32 | 13-module forced-compile | FreeBSD/Android compile gate |
| P6 Benchmarks | Performance baseline | 14-operation baseline | cross-platform comparison |

## P5 Evidence Matrix

| Target | Status | Evidence |
|--------|--------|----------|
| riscv64-linux | PASS | 13-module forced-compile |
| aarch64-linux | PASS | 13-module forced-compile |
| arm32-linux | PASS | 13-module forced-compile |

## Deferred Milestones

| Milestone | Status | Reason |
|-----------|--------|--------|
| P7 macOS/Darwin | Deferred | Requires Darwin cross-compiler toolchain |
| P8 FreeBSD | Deferred | Requires cross-platform-actions CI |
| P9 Android | Deferred | NDK + bionic libc + syscall differences; Android resource limits source-contract only |

## Evidence rules

- Do not use a status label without an evidence tier.
- `forced-compile` is not runtime proof.
- Linux runtime proof does not imply Windows runtime proof.
- Consumer source-contract tests prove ownership expectations, not host runtime behavior.
