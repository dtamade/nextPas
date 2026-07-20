# Windows native async host evidence — assessment (Q17)

**Date**: 2026-07-20  
**Scope**: nextpas.core async I/O on **native Windows** (not Wine)

## Current evidence tiers

| Tier | Mechanism | Claim |
|------|-----------|--------|
| `truth=wine-runtime-smoke` | `test_reactor_iocp_wine`, `test_poller_windows_runtime_smoke` under Wine on Linux CI | IOCP implementation exercised under Wine — **not** bare-metal Windows |
| `truth=windows-compile-gate` | FORCE_HOST / cross-compile gates | Source compiles for Windows targets |
| `truth=native-windows` | — | **Not claimed** |

## What native Windows would require

1. **Runner**: `windows-latest` (or self-hosted) with FPC trunk **x86_64-win64** capable of building `nextpas.core` (function references / ObjFPC).
2. **Suite (minimum)**:
   - `test_poller_windows_runtime_smoke` on bare metal
   - `test_reactor_iocp_wine` equivalent without Wine
   - `test_async_accept_connect_smoke` (if loop creates `pbIocp`)
   - dial/resolve host matrix subset (optional phase 2)
3. **CI job**: fail-closed only after 2+ consecutive green weekly runs (avoid flapping FPC trunk installs).

## Current CI reality

- `test-windows-runtime` job exists in `core-ci.yml` and focuses on **platform** matrix + toolchain, not full async host parity.
- Chocolatey / MSYS2 FPC packaging remains a **blocker risk** for nextpas.core (needs 3.3.1+).
- Wine smoke remains the **honest** IOCP runtime evidence layer.

## Decision (Q17 / Q20 light)

| Option | Choice |
|--------|--------|
| Promote to native-windows claim now? | **No** |
| Keep wine-runtime-smoke? | **Yes** |
| Next action | When FPC trunk on `windows-latest` is stable for core-ci platform job, add opt-in job `async-windows-native-smoke` (continue-on-error → fail-closed after green streak) |

### Suggested opt-in job (not wired fail-closed)

| Field | Value |
|-------|--------|
| Job name | `async-windows-native-smoke` |
| Runner | `windows-latest` + FPC ≥ 3.3.1 |
| Suite (min) | poller windows runtime smoke; IOCP smoke; accept/connect if `pbIocp` |
| CI policy | `continue-on-error: true` until 2+ consecutive weekly green |
| Out of scope for job-1 | dial concurrent bench, public DNS, full host-matrix |

Q20 does **not** land this job — documentation hook only.

## Non-goals

- Do not treat Wine green as native Windows host-runtime.
- Do not block Linux/macOS quality gates on Windows native.
- Do not claim `truth=native-windows` from wine or compile-only gates.
