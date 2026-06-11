# nextPas Platform Goal Tree

Stable terminology lives in [master-spec](master-spec.md). This file tracks
phase state and evidence only.

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.
Windows has source-contract and forced-compile coverage for several seams, but
no real runtime or ci-matrix proof. macOS, FreeBSD, and Android remain mixed.

## Host Status

| Host | Current truth | Required next proof |
| --- | --- | --- |
| Linux x86_64 | focused-runtime through platform/io, async, process, file, and consumer gates with heaptrc expectations | keep focused gates green and expand consumer coverage only when contracts change |
| Windows x86_64 | source-contract plus forced Windows compile coverage for readiness and completion seams; real-Windows runtime proof missing | run named real-Windows runtime gates on a Windows host and promote only after ci-matrix proof |
| macOS / FreeBSD | source-contract and selected compile/runtime fragments | record passed rows separately; skipped rows are non-evidence |
| Android / other forced hosts | forced-compile fragments | add host-specific runtime rows before claiming runtime readiness |

## Evidence Gates

Current Windows readiness and completion source/compile proof is split across:

- `test_poller_windows_contract` for IOCP/poller source-contract ownership.
- `test_poller_windows_compile_gate` for the consumer-facing IOCP forced Windows compile gate.
- `test_platform_windows_poller_compile_gate` for the platform readiness poller forced Windows compile gate.
- `test_async` for the Linux async consumer runtime gate with heaptrc expectations.

These gates do not prove Windows runtime behavior. They only prove source shape,
forced Windows compile coherence, and Linux focused-runtime behavior where the
gate actually runs.

## Readiness And Completion Boundaries

The Windows readiness poller remains separate from IOCP completion. The
readiness lane covers `platform_poller_*`, wake, userdata, and empty-interest
re-entry. The completion lane covers IOCP read/write file operations and async
loop ownership. IOCP read/write has source-contract and compile coverage, plus
optional Wine smoke coverage recorded as non-real-Windows evidence. Socket
completion operations that are not implemented remain unsupported until they
have implementation and real-Windows runtime proof.

## Milestones

| Milestone | Goal | Current truth | Next proof |
| --- | --- | --- | --- |
| P1 Host ABI inventory | Host constants, records, handles, raw declarations | source-contract + focused ABI tests for many hosts | keep gap matrix current and fail new raw owner leaks |
| P2 Feature facades | Portable APIs for time, sync, thread, files, io, process, mmap, env, random, signal, console, path, fs, args | Linux focused-runtime; other hosts mixed | per-feature truth matrix by host |
| P3 Readiness lane | `platform_poller_*`, wake, userdata, empty-interest, net readiness consumers | Linux runtime; Windows source/compile | Windows runtime proof and ci-matrix |
| P4 Completion lane | IOCP/proactor ownership and async loop completion consumers | source-contract + forced compile | Windows real runtime for file lifecycle and timeout/close paths |
| P5 Tier 2 targets | Windows aarch64, Linux riscv64/arm32, FreeBSD/Android | source/compile fragments | cross-compile and runtime matrix |
| P6 Benchmarks | Platform performance comparison | deferred | only after contract/runtime truth stabilizes |

## Evidence rules

- Do not use a status label without an evidence tier.
- `forced-compile` is not runtime proof.
- Linux runtime proof does not imply Windows runtime proof.
- Consumer source-contract tests prove ownership expectations, not host runtime
  behavior.
