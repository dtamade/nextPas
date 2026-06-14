# nextPas Platform Goal Tree

Stable terminology lives in [master-spec](master-spec.md). This file tracks
phase state and evidence only.

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.
Windows has focused-runtime evidence for all 14 modules on real Windows VM via SSH.
macOS, FreeBSD, and Android remain mixed.

## Host Status

| Host | Current truth | Required next proof |
| --- | --- | --- |
| Linux x86_64 | focused-runtime through platform/io, async, process, file, and consumer gates with heaptrc expectations | keep focused gates green and expand consumer coverage only when contracts change |
| Windows x86_64 | focused-runtime for 14/14 modules on real Windows VM via SSH; wine-runtime-smoke for all 14 modules; real-Windows runner via SSH | promote to ci-matrix |
| macOS / FreeBSD | source-contract and selected compile/runtime fragments | record passed rows separately; skipped rows are non-evidence |
| Android / other forced hosts | forced-compile fragments | add host-specific runtime rows before claiming runtime readiness |

## Evidence Gates

Current Windows readiness and completion source/compile proof is split across:

- `test_poller_windows_contract` for IOCP/poller source-contract ownership.
- `test_poller_windows_compile_gate` for the consumer-facing IOCP forced Windows compile gate.
- `test_platform_windows_poller_compile_gate` for the platform readiness poller forced Windows compile gate.
- `test_async` for the Linux async consumer runtime gate with heaptrc expectations.
- `test_platform_resource` for Linux resource limits focused-runtime proof,
  Windows stable unsupported behavior, and Android resource limits
  forced-compile/source-contract proof.
- `test_platform_memory` and `test_platform_memory_secure_zero_compile_gate`
  for POSIX `explicit_bzero` secure-zero backend truth, Linux runtime zeroing,
  and Windows fallback/deferred source-contract proof.
- `test_platform_files_android_compile` and `test_platform_mmap_android_compile`
  for Android files/mmap forced-compile proof only. The files gate includes
  stat/lstat/fstat and directory enumeration source proof; it is not Android
  device runtime proof.

These gates do not prove Windows runtime behavior. They only prove source shape,
forced Windows compile coherence, and Linux focused-runtime behavior where the
gate actually runs.

Windows focused-runtime evidence covers all 14 facade modules on a real Windows 10 VM
(desktop-6m81kru). IOCP completion lane now has full lifecycle evidence for AsyncSend,
AsyncRecv, AcceptEx, and ConnectEx.

## Wine Runtime Smoke Evidence

Wine 10.0 runtime smoke evidence covers 14 facade modules. These tests are
cross-compiled to Win64 PE via `-Twin64` and executed under Wine. Evidence tier
is `wine-runtime-smoke` (not `ci-matrix`).

## Windows Focused Runtime Evidence (real Windows VM)

Same 14 modules cross-compiled and executed on a real Windows 10 VM
(desktop-6m81kru) via SCP + SSH. Evidence tier is `focused-runtime`.

| Module | Gate path | Tests | Real Windows | Known gaps |
| --- | --- | --- | :-: | --- |
| platform.time | `tests/nextpas.core.platform.time/test_platform_time_wine/` | 5 | ✅ | — |
| platform.memory | `tests/nextpas.core.platform.memory/test_platform_memory_wine/` | 8 | ✅ | — |
| platform.sync | `tests/nextpas.core.platform.sync/test_platform_sync_wine/` | 14 | ✅ | recursive mutex (SRWLOCK does not support recursive) |
| platform.thread | `tests/nextpas.core.platform.thread/test_platform_thread_wine/` | 9 | ✅ | WaitOnAddress not available on some hosts |
| platform.io | `tests/nextpas.core.platform.io/test_platform_io_wine/` | 4 | ✅ | — |
| platform.process | `tests/nextpas.core.platform.process/test_platform_process_wine/` | 7 | ✅ | — |
| platform.files | `tests/nextpas.core.platform.files/test_platform_files_wine/` | 14 | ✅ | — |
| platform.fs | `tests/nextpas.core.platform.fs/test_platform_fs_wine/` | 11 | ✅ | — |
| platform.path | `tests/nextpas.core.platform.path/test_platform_path_wine/` | 11 | ✅ | — |
| platform.env | `tests/nextpas.core.platform.env/test_platform_env_wine/` | 5 | ✅ | — |
| platform.mmap | `tests/nextpas.core.platform.mmap/test_platform_mmap_wine/` | 7 | ✅ | — |
| platform.random | `tests/nextpas.core.platform.random/test_platform_random_wine/` | 4 | ✅ | — |
| platform.socket | `tests/nextpas.core.platform.socket/test_platform_socket_wine/` | 4 | ✅ | — |
| io.reactor.iocp | `tests/nextpas.core.io.uring/test_reactor_iocp_wine/` | 6 | ✅ | ConnectEx graceful skip on Wine (not a gap) |

Not covered by Wine runtime smoke: platform.signal, platform.console, platform.args
(no Wine runtime test needed — signal uses SetConsoleCtrlHandler which is
Wine-unsupported; console relies on Wine pseudo-TTY behavior not suitable for
evidence; args uses FPC RTL ParamStr which is cross-platform).

## Readiness And Completion Boundaries

The Windows readiness poller remains separate from IOCP completion. The
readiness lane covers `platform_poller_*`, wake, userdata, and empty-interest
re-entry. The completion lane covers IOCP read/write file operations, async
send/recv over sockets, accept (via AcceptEx), connect (via ConnectEx), and
close. IOCP socket completion operations now have wine-runtime-smoke for
AsyncSend/AsyncRecv (3 tests), and are additionally covered by source-contract
and forced Windows compile gates.

## Milestones

| Milestone | Goal | Current truth | Next proof |
| --- | --- | --- | --- |
| P1 Host ABI inventory | Host constants, records, handles, raw declarations | ✅ complete | keep gap matrix current |
| P2 Feature facades | Portable APIs for time, sync, thread, files, io, process, mmap, env, random, path, fs | ✅ 14/14 focused-runtime on Windows | expand consumer coverage |
| P3 Readiness lane | `platform_poller_*`, wake, userdata, empty-interest, net readiness consumers | Linux runtime; Windows source/compile | promote to ci-matrix |
| P4 Completion lane | IOCP/proactor ownership and async loop completion consumers | ✅ source-contract + forced compile + focused-runtime (AsyncSend/Recv/Accept/Connect) | timeout/close paths |
| P5 Tier 2 targets | Windows aarch64, Linux riscv64/arm32, FreeBSD/Android | source/compile fragments | cross-compile and runtime matrix |
| P6 Benchmarks | Platform performance comparison | deferred | only after contract/runtime truth stabilizes |

## Evidence rules

- Do not use a status label without an evidence tier.
- `forced-compile` is not runtime proof.
- Linux runtime proof does not imply Windows runtime proof.
- Consumer source-contract tests prove ownership expectations, not host runtime
  behavior.
