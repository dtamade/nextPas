# nextPas Platform Goal Tree

Stable terminology lives in [master-spec](master-spec.md). This file tracks
phase state and evidence only.

## Current position

Platform is in truth hardening. Linux has broad focused-runtime coverage.
Windows has source-contract and forced-compile coverage for several seams, but
no real runtime or ci-matrix proof. macOS, FreeBSD, and Android remain mixed.

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
