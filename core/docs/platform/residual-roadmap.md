# Platform residual roadmap (long-term)

**Authority**: long-term residual backlog for `nextpas.core.platform`.
**Companion**: [goal-tree.md](goal-tree.md), [RETURN-SEMANTICS.md](RETURN-SEMANTICS.md), [ERROR-HANDLING.md](ERROR-HANDLING.md).
**Usability baseline**: **8.21/10 LOW–MEDIUM** (wave-4, 2026-07-17) — **maintenance**, not open-ended rescoring.

## Stance

| Item | Policy |
|------|--------|
| Usability waves 1–4 | **Closed** |
| Wave-5 | Not opened without a large public-API or contract change |
| Truth tiers | Never promote Windows/macOS/FreeBSD/Android without host evidence |
| FPC RTL | Only `nextpas.core.system` may `uses` FPC RTL units |

## Milestone table

| Stage | Goal | Residual IDs | Status |
|-------|------|--------------|--------|
| **LT0** | Freeze maintenance baseline, backlog authority, README/goal-tree pointers | A | **Done** (this file + goal-tree) |
| **LT1** | QUICKSTART/EXAMPLES/BEST-PRACTICES live-name gates + docs live patterns smoke | F8 | **Done** |
| **LT2** | `process.pipe` off `platform_io_read/write/close`; production whitelist for remaining dual-IO | F5 | **Done** |
| **LT3** | `platform_get_last_os_error` raw host side-channel + docs/tests | F6 | **Done** |
| **LT4** | Windows ci-matrix / macOS focused-runtime evidence | F12 | **Registered only** |
| Deferred | POSIX/Windows mapping symmetry, ALen rename, diagnostics hooks, freetype move-out | F7 / F9 / F10 / F14 | Won't this program |

## LT4 registration (not this land)

- Promote Windows from Wine + partial real-Windows to broader `ci-matrix` only with real host evidence.
- macOS / FreeBSD / Android: still `source-contract` / `forced-compile` until runtime gates exist.
- No fake readiness language in goal-tree or runtime-truth-matrix.

## Maintenance gates (must stay green)

```bash
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_return_semantics_contract
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_docs_live_patterns
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.platform/test_platform_goal_tree_contract
make -C core/tests/architecture/source_contracts host-raw-ffi-audit
make hygiene
```

## dual-IO consumer whitelist (F5)

Production call sites of `platform_io_read` / `platform_io_write` / `platform_io_poll` are limited to:

| Unit | Allowed symbols | Notes |
|------|-----------------|-------|
| `nextpas.core.platform.process.pas` | definitions + internal use | transitional dual-API owner |
| `nextpas.core.process.pipe.pas` | `platform_io_poll` only | drain path; read/write/close use `platform.files` |

New consumers must use `platform.files` / `platform_process_*_ex` / `platform.io` poller.

## Raw OS side-channel (F6)

| API | Role |
|-----|------|
| `platform_get_last_error` | Portable `PLATFORM_ERR_*` (mapped) |
| `platform_get_last_os_error` | Raw host code (`errno` / `GetLastError`) for diagnostics |

`platform_error_message` is unchanged; it remains a length API over portable (and host strerror) codes.
