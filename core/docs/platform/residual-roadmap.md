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
| **LT2** | `process.pipe` off all `platform_io_*` call sites; dual-IO symbols remain on `platform.process` only | F5 | **Done** |
| **LT3** | `platform_get_last_os_error` raw host side-channel + docs/tests | F6 | **Done** |
| **LT4** | Windows ci-matrix / macOS focused-runtime evidence | F12 | **Registered only** |
| Deferred | POSIX/Windows mapping symmetry, ALen rename, diagnostics hooks, freetype move-out | F7 / F9 / F10 / F14 | Won't this program |

## LT4 registration (not this land)

**Status**: registered only. Local inventory does **not** promote truth tiers.

### Entry criteria (all required to leave "registered only")

| Host | Promote to | Required evidence |
|------|------------|-------------------|
| Windows x86_64 | `ci-matrix` | Real Windows CI runner (not only Wine) repeating focused-runtime gates |
| macOS x86_64/arm64 | `focused-runtime` | Real macOS host (or durable Actions runner) running named module gates |
| FreeBSD / Android | higher than compile | Device/host runtime gates (out of scope until owners exist) |

Wine remains `wine-runtime-smoke` forever: useful regression signal, **never** substitute for real Windows `ci-matrix`.

### Local host inventory (2026-07-17, Linux x86_64)

Probe: `./scripts/platform-lt4-readiness.sh`

| Prerequisite | State on this workstation |
|--------------|---------------------------|
| `fpc` + `fpc -Twin64 -Px86_64` | Ready (ppcrossx64 under FPC units; not required on `$PATH`) |
| `wine` runs Win64 PE | Ready |
| `core/tests/common.mk` `wine-runtime-smoke` target | Restored (was lost in common.mk batch convert) |
| `core/scripts/platform-wine-ci-matrix.sh` | Present |
| Sample wine gates (2026-07-17) | `time` 5/5 + `error` 6/6 under Wine 10.0; heaptrc 0 leak |
| Real Windows CI runner | **Blocked** |
| macOS focused-runtime host | **Blocked** |

### Win64 compile fixes landed with LT4 prep (still wine-runtime-smoke)

| Fix | Why |
|-----|-----|
| `windows.base` `PINT64 = System.PInt64` | `PINT64 = ^Int64` shadowed `System.PInt64` (case-insensitive) and broke `platform_wait_address64` forwards |
| mem Fls helpers local `TFlsDWord`/`TFlsBool` | raw `DWORD`/`BOOL` without host types under `MSWINDOWS` |
| `test.expect` IUnknown methods `stdcall` on Windows | `{$IFNDEF WINDOWS}cdecl{$ENDIF}` left empty calling-convention slot → syntax error |

### Operator commands (still not LT4 complete)

```bash
./scripts/platform-lt4-readiness.sh
make -C core/tests/nextpas.core.platform.time/test_platform_time_wine wine-runtime-smoke
make -C core/tests/nextpas.core.platform.error/test_platform_error_wine wine-runtime-smoke
./core/scripts/platform-wine-ci-matrix.sh   # wine-runtime-smoke matrix; not ci-matrix truth
./scripts/platform-wine-runtime-smoke.sh    # broader *_wine discovery runner
```

Do **not** rewrite [runtime-truth-matrix.md](runtime-truth-matrix.md) or claim `ci-matrix` until entry criteria above are met with host logs.

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

Production **call sites** of `platform_io_read` / `platform_io_write` / `platform_io_poll` / `platform_io_close`:

| Unit | Allowed | Notes |
|------|---------|-------|
| `nextpas.core.platform.process.pas` | definitions (and any internal use) | transitional dual-API owner; keep symbols for compatibility |
| all other production units | **none** | `process.pipe` uses `platform.files` + local `PipePoll` (posix.ffi) |

New code must use `platform.files` / `platform_process_*_ex` / `platform.io` poller.

## Raw OS side-channel (F6)

| API | Role |
|-----|------|
| `platform_get_last_error` | Portable `PLATFORM_ERR_*` (mapped) |
| `platform_get_last_os_error` | Raw host code (`errno` / `GetLastError`) for diagnostics |

`platform_error_message` is unchanged; it remains a length API over portable (and host strerror) codes.
