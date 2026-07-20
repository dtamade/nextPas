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
2. **Suite (async smoke, Q33 expanded)**:
   - `test_async_windows_compile_gate` / `test_async_windows_contract`
   - `test_poller_windows_runtime_smoke`
   - `test_reactor_iocp_wine` (on native host)
   - `test_async_accept_connect_smoke`
   - **Q33+**: `test_net_async_dial`, `test_net_async_resolve`, `test_net_async_udp`,
     `test_net_async_pool`, `test_net_error_classify`, `test_net_cancel_bridge`
3. **CI policy**: fail-closed (Q24B). Still **candidate** until multi-week green after expansion.

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
| When | Runs if FPC install succeeded, **even when platform matrix fails** (Q34) |
| Script | `core/scripts/async-windows-native-smoke.sh` |
| STRICT | CI exports `ASYNC_WINDOWS_STRICT=1`; script defaults STRICT=1 on Windows hosts |

### Streak observer

```bash
bash core/scripts/async-windows-smoke-streak.sh
# promote-ready=yes with consecutive_step_success≥14 triggered Q24B
```

### Rollback

- Temporarily re-add `continue-on-error` only with assessment note + streak reset if FPC/Windows flakes dominate.

## Notes (Q35–Q37)

- Host tests that need threads must use `{$IFDEF UNIX}cthreads,{$ENDIF}` — Windows FPC has no `cthreads` unit; unconditional `uses cthreads` fails compile on win64 smoke.
- Q33 expansion required this fix for dial/resolve/udp/pool/accept/cancel suites.
- **Q36**: sync `net.tcp`/`net.udp` use `TPlatformSockAddr` only (no POSIX `sockaddr_in` in product path).
- **Q37**: `async.tcp` no longer calls `accept4` (uses `platform_socket_accept` for sync try); `async.udp` uses `TPlatformSockAddr` like sync udp — unblocks Windows/macOS compile of expanded smoke suites.

## Full `truth=native-windows` (deferred)

Not claimed. Before promoting beyond **candidate**:

| Item | Status |
|------|--------|
| Async smoke fail-closed | **Q24B done** |
| + dial / resolve / udp on Windows CI | checklist only (risk: flaky) |
| Multi-week zero flake after expansion | required |
| Documented host parity matrix | required |

Until then keep claim **native-windows-candidate**.

## Non-goals

- Do not treat Wine green as bare-metal native Windows.
- Do not block Linux/macOS gates on Windows native.
- Do not claim full-host Windows async parity from this suite alone.
