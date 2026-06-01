# Task Plan: nextpas.core.tui API Surface Round

## Goal
Close the `nextpas.core.tui` public facade so consumers can use the migrated TUI module through the documented single-entry unit, with interface tests and heaptrc proof.

## Current Phase
Round complete

## /plan

### Phase 1: Architecture & Scope Lock
- [x] Read `docs/design-conventions.md`
- [x] Read the TUI migration goal tree
- [x] Confirm worktree and branch status
- [x] Identify current facade/export gaps
- [x] Write this round plan and evidence notes
- **Status:** complete

### Phase 2: TDD Facade Test
- [x] Add `tests/nextpas.core.tui/test_tui_facade/test_tui_facade.lpr`
- [x] Add matching `Makefile`
- [x] Run the new test and confirm RED failure from missing facade symbols
- **Status:** complete

### Phase 3: Facade API Completion
- [x] Update `src/nextpas.core.tui.pas` to re-export all TUI widget units used by the catalog
- [x] Add natural type aliases for public TUI records/classes/interfaces so `uses nextpas.core.tui` matches README examples
- [x] Keep existing `TTui*` compatibility aliases
- [x] Keep facade logic-free, with aliases and inline forwarding only where facade helpers are required
- **Status:** complete

### Phase 4: Widget Adapter Decision
- [x] Review whether `TWidgetAdapter` has real consumers
- [x] If retained, make the contract explicit and tested
- [x] If removed, prove no consumers and update docs/tests
- **Status:** complete

### Phase 5: Docs & Goal Tree Sync
- [x] Update `docs/plans/2026-05-31-tui-migration-goaltree.md`
- [x] Update `docs/tui/README.md` / `ARCHITECTURE.md` if facade behavior changes
- [x] Add this round plan under `docs/plans/`
- **Status:** complete

### Phase 6: Verification, Review, Commit
- [x] Run focused tests with heaptrc
- [x] Run all TUI tests if focused tests pass
- [x] Check `git diff` and `git status`
- [x] Do a Codex-style round review: requirements, risks, next step
- [x] Commit a clear logical change
- **Status:** complete

## Key Questions
1. Does `nextpas.core.tui` expose the same practical public API promised by the docs?
2. Does every API-facing change have a direct unit test and heaptrc evidence?
3. Does `TWidgetAdapter` still serve a framework-level purpose after all widgets became `IWidget`?
4. Does this round stay within API surface cleanup instead of drifting into benchmark work?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Start with facade/API surface, not benchmark CI | Benchmark comparison is intentionally later; public API should be coherent before consumer integration |
| Use TDD for facade aliases | Compile-time facade tests catch missing re-export symbols exactly where consumers feel them |
| Preserve existing `TTui*` aliases | Avoid breaking current consumers while adding the natural documented names |
| Retain `TWidgetAdapter` | It is useful as a small custom render bridge, but not part of the built-in widget implementation path |
| Export `TWidgetAdapter` through the facade | A retained public extension point should work with `uses nextpas.core.tui` |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `/home/dtamade/.codex/memories/MEMORY.md` missing | Memory quick pass | Proceeded from user-provided state, design conventions, and local repo evidence |
| `planning-with-files` catchup script path missing | Session catchup | Used existing local planning files directly |
| `TWidgetAdapter.Create(nil)` did not raise and leaked 48 bytes in the failing test | Focused widget_intf TDD run | Added constructor nil validation before storing the render function |
| `TWidgetAdapter` was not reachable from `nextpas.core.tui` | Added facade assertion and reran `test_tui_facade` | Re-exported `TWidgetRenderFn` and `TWidgetAdapter` from the facade |
| Full TUI loop failed 32/32 with `make: fpc: No such file or directory` | First broad verification used `bash -lc`, which dropped `/opt/fpcupdeluxe/fpc/bin/x86_64-linux` from `PATH` | Reran the same 32 projects with explicit `FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc`; all passed |

## Verification Evidence
| Command | Result |
|---------|--------|
| `make -C tests/nextpas.core.tui/test_tui_facade FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc clean test` | Included in full suite; 4 total, 4 passed, 0 failed; heaptrc 0 unfreed |
| `make -C tests/nextpas.core.tui/test_tui_widget_intf FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc clean test` | Included in full suite; 4 total, 4 passed, 0 failed; heaptrc 0 unfreed |
| `make -C tests/nextpas.core.tui/test_tui_widget_batch FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc clean test` | 11 total, 11 passed, 0 failed; heaptrc 0 unfreed |
| Full `tests/nextpas.core.tui/*` loop with explicit `FPC` | 32 projects, 236 total, 236 passed, 0 failed; 13 heaptrc summaries, all `0 unfreed memory blocks` |
| `git diff --check` | clean |

## Review Follow-up
| Finding | Resolution |
|---------|------------|
| Facade missed builder parameter types/constants such as `TWrap`, `WRAP_TRIM`, `TContentAlign`, and table alignment constants | Added facade aliases/tests; kept table subunit compatibility by aliasing `TContentAlign` to `TAlignment` and re-exporting `caLeft`/`caCenter`/`caRight` from the table unit |
| Facade copied `BorderSet*` initialized variables as independent typed consts | Replaced copies with thin forwarding functions that read the canonical `nextpas.core.tui.borders` variables |

## Notes
- Worktree: `/home/dtamade/projects/nextPas/core-tui-migration`, branch `feat/tui-migration`.
- Core root: `/home/dtamade/projects/nextPas/core-tui-migration/core`.
- Keep changes minimal and traceable because this is a shared worktree environment.
