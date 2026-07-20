# Windows native async host evidence — assessment (Q17 → Q24B)

**Date**: 2026-07-20  
**Scope**: nextpas.core async I/O on **native Windows** (not Wine)

## Current evidence tiers

| Tier | Mechanism | Claim |
|------|-----------|--------|
| `truth=wine-runtime-smoke` | `test_reactor_iocp_wine`, `test_poller_windows_runtime_smoke` under Wine on Linux CI | IOCP implementation exercised under Wine — **not** bare-metal Windows |
| `truth=windows-compile-gate` | FORCE_HOST / cross-compile gates | Source compiles for Windows targets |
| `truth=native-windows-candidate` | `async-windows-native-smoke` **fail-closed** on `windows-latest` (Q24B) | Suite-limited host evidence — **not** full host parity |
| `truth=native-windows` | — | **Not claimed** (full parity) |

## What native Windows host evidence covers

1. **Runner**: `windows-latest` with FPC trunk **x86_64-win64** (core-ci snapshot install).
2. **Suite (async smoke)**:
   - `test_async_windows_compile_gate` / `test_async_windows_contract`
   - `test_poller_windows_runtime_smoke`
   - `test_reactor_iocp_wine` (on native host)
   - `test_async_accept_connect_smoke`
3. **CI policy**: fail-closed after streak ≥14 consecutive step successes (Q24B).

## Current CI reality

- `test-windows-runtime` runs platform matrix + async Windows native smoke.
- Async step: **no** `continue-on-error`; `ASYNC_WINDOWS_STRICT=1`.
- Soft escape (local only): `NEXTPAS_ASYNC_WINDOWS_BEST_EFFORT=1`.
- Wine smoke remains a separate honest IOCP tier under Linux CI.

## Decision (Q24B)

| Option | Choice |
|--------|--------|
| Promote full `truth=native-windows`? | **No** — suite-limited |
| Keep wine-runtime-smoke? | **Yes** |
| Fail-closed async smoke on Windows CI? | **Yes** |
| Claim | **native-windows-candidate** |

### Step / script

| Field | Value |
|-------|--------|
| Job | `test-windows-runtime` |
| Step | `Async Windows native smoke (fail-closed on Windows host)` |
| Script | `core/scripts/async-windows-native-smoke.sh` |
| STRICT | CI exports `ASYNC_WINDOWS_STRICT=1`; script defaults STRICT=1 on Windows hosts |

### Streak observer

```bash
bash core/scripts/async-windows-smoke-streak.sh
# promote-ready=yes with consecutive_step_success≥14 triggered Q24B
```

### Rollback

- Temporarily re-add `continue-on-error` only with assessment note + streak reset if FPC/Windows flakes dominate.

## Non-goals

- Do not treat Wine green as bare-metal native Windows.
- Do not block Linux/macOS gates on Windows native.
- Do not claim full-host Windows async parity from this suite alone.
