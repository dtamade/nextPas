# Platform residual roadmap (closed program)

**Authority**: closed residual backlog for usability maintenance (LT0–LT3 **Done**).
**Forward execution**: remaining host/evidence work lives in [ROADMAP.md](ROADMAP.md) phases **D1–D5**.
**Companion**: [goal-tree.md](goal-tree.md), [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md), [ERROR-HANDLING.md](ERROR-HANDLING.md).
**Usability baseline**: **8.21/10 LOW–MEDIUM** (wave-4, 2026-07-17) — **maintenance**, not open-ended rescoring.

## Stance

| Item | Policy |
|------|--------|
| Usability waves 1–4 | **Closed** |
| Wave-5 | Not opened without a large public-API or contract change |
| Truth tiers | Never promote Windows/macOS/FreeBSD/Android without host evidence |
| FPC RTL | Only `nextpas.core.system` may `uses` FPC RTL units |
| Forward queue | [ROADMAP.md](ROADMAP.md) only |

## Milestone table

| Stage | Goal | Residual IDs | Status |
|-------|------|--------------|--------|
| **LT0** | Freeze maintenance baseline, backlog authority, README/goal-tree pointers | A | **Done** |
| **LT1** | QUICKSTART/EXAMPLES/BEST-PRACTICES live-name gates + docs live patterns smoke | F8 | **Done** |
| **LT2** | `process.pipe` off all `platform_io_*` call sites; dual-IO symbols remain on `platform.process` only | F5 | **Done** |
| **LT3** | `platform_get_last_os_error` raw host side-channel + docs/tests | F6 | **Done** |
| **LT4** | Windows ci-matrix / macOS focused-runtime evidence | F12 | **Moved** → ROADMAP **D1** (Windows) + **D2** (macOS) |
| Deferred | POSIX/Windows mapping symmetry, ALen rename, diagnostics hooks, freetype move-out | F7 / F9 / F10 / F14 | Won't this program (see ROADMAP D3) |

## LT4 handoff (do not re-open as residual-only)

LT4 is no longer a residual-only stage. Track and execute under:

| Former LT4 piece | ROADMAP phase |
|------------------|---------------|
| Wine matrix keep-green + Win64 compile | D1.a / D1.c |
| Real Windows GHA expand → ci-matrix | D1.b / D1.d |
| macOS focused-runtime | D2 |

### Snapshot evidence (2026-07-17)

| Item | State |
|------|--------|
| Wine CI matrix (14 modules) | pass=14 fail=0 skip=0 (secondary) |
| Real Windows GHA gates | `platform-windows-ci-matrix.sh`: 14 suite dirs + poller/io/socket real gates |
| Windows `ci-matrix` | **Promoted (D1.d)** for documented 17-gate set only; not full-host parity |
| macOS `focused-runtime` | **Promoted (D2.c)** for documented 8-gate set only; not full-host parity |

Wine remains `wine-runtime-smoke` forever: useful regression signal, **never** substitute for real Windows `ci-matrix`.

### Operator commands

```bash
./scripts/platform-lt4-readiness.sh
./core/scripts/platform-wine-ci-matrix.sh   # wine-runtime-smoke; not ci-matrix truth
./scripts/platform-wine-runtime-smoke.sh
```

## Maintenance gates (must stay green)

```bash
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_return_semantics_contract
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_docs_live_patterns
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_goal_tree_contract
make -C core/tests/architecture/source_contracts host-raw-ffi-audit
make hygiene
```

## dual-IO consumer whitelist (F5) — permanent owner-only (D3.c)

Production **call sites** of `platform_io_read` / `platform_io_write` / `platform_io_poll` / `platform_io_close`:

| Unit | Allowed | Notes |
|------|---------|-------|
| `nextpas.core.platform.process.pas` | definitions (and any internal use) | **permanent** dual-API owner; symbols retained for compatibility; **no sunset this program** |
| all other production units | **none** | `process.pipe` uses `platform.files` + local `PipePoll` (posix.ffi) |

New code must use `platform.files` / `platform_process_*_ex` / `platform.io` poller.

**Deprecation schedule (D3.c):** none. dual-IO remains owner-only on `platform.process` indefinitely for this program. Removal would require a future explicit owner decision + consumer migration plan outside residual LT0–LT3.

## Raw OS side-channel (F6)

| API | Role |
|-----|------|
| `platform_get_last_error` | Portable `PLATFORM_ERR_*` (mapped) |
| `platform_get_last_os_error` | Raw host code (`errno` / `GetLastError`) for diagnostics |

`platform_error_message` is unchanged; it remains a length API over portable (and host strerror) codes.
