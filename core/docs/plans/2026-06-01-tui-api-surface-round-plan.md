# nextpas.core.tui API Surface Round Plan

## Goal

Make the migrated `nextpas.core.tui` module usable through its documented facade, with compile-time API coverage and heaptrc proof for the changed public surface.

## Architecture Position

`nextpas.core.tui` is an L3 framework module. Its facade must stay logic-free and explicitly re-export public types from lower TUI units because FPC does not provide automatic re-export through `uses`.

This round does not change rendering, buffer diffing, grapheme segmentation, input parsing, or benchmark strategy. It is an API-surface hardening round before consumer integration or merge.

## Scope

1. Add a dedicated facade test project.
2. Extend `src/nextpas.core.tui.pas` so `uses nextpas.core.tui` exposes the natural public names documented by README and catalog.
3. Preserve existing `TTui*` compatibility aliases.
4. Decide the fate of `TWidgetAdapter` with evidence and tests/docs.
5. Update docs and goal tree with this API-surface closure.

## Non-Goals

- No benchmark comparison work in this round.
- No consumer repository integration.
- No widget behavior rewrite.
- No history rewrite, rebase, or destructive git operation.

## Verification Plan

- [x] New facade test failed before implementation because symbols were missing from the facade.
- [x] Focused facade/widget interface tests pass after implementation with `-gh`.
- [x] All `tests/nextpas.core.tui/*` projects should pass before closing the round.
- [x] `git status` must be checked after tests to remove accidental generated artifacts.

## Review Checklist

- Does the facade remain aliases-only and logic-free?
- Are all catalog widgets either exported or intentionally documented as non-widget utilities?
- Is adapter compatibility either tested or removed with no call sites?
- Did docs and the goal tree reflect the final state?

## Decisions

| Decision | Rationale |
|----------|-----------|
| Keep `TWidgetAdapter` | It remains a useful low-level extension bridge for custom render functions and external widget shims, even though built-in widgets now implement `IWidget` directly. |
| Export adapter through `nextpas.core.tui` | A retained public extension point should be reachable from the documented single-entry facade. |
| Reject nil render functions at construction | Fail-fast prevents a later nil callback crash and avoids object leaks when callers construct without assigning to an interface. |
| Export builder support types/constants | Facade consumers should be able to call documented widget builder methods such as paragraph wrapping and table alignment without importing subunits. |
| Forward `BorderSet*` functions | The source border presets are initialized variables; facade forwarding keeps the single-entry API tied to the canonical values instead of static copies. |

## Focused Verification Evidence

| Command | Result |
|---------|--------|
| `make -C tests/nextpas.core.tui/test_tui_widget_intf clean test` | 4 total, 4 passed, 0 failed; heaptrc 0 unfreed memory blocks |
| `make -C tests/nextpas.core.tui/test_tui_facade clean test` | 4 total, 4 passed, 0 failed; heaptrc 0 unfreed memory blocks |
| `make -C tests/nextpas.core.tui/test_tui_widget_batch FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc clean test` | 11 total, 11 passed, 0 failed; heaptrc 0 unfreed memory blocks |

## Broad Verification Evidence

| Command | Result |
|---------|--------|
| Full `tests/nextpas.core.tui/*` loop with `FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc` | 32 projects; 236 total, 236 passed, 0 failed; 13 heaptrc summaries, all `0 unfreed memory blocks` |
| `git diff --check` | clean |

The first broad loop was launched through `bash -lc` and failed because that shell did not see the FPC binary. The rerun used the absolute FPC path to avoid environment drift.

## Review Follow-up

The Codex-style review found no critical blockers. Important findings were handled in this round:

- `TWrap`, `WRAP_TRIM`, and `TContentAlign` are now facade-visible, and table alignment constants remain public from the table subunit.
- `BorderSetPlain`, `BorderSetRounded`, `BorderSetDouble`, `BorderSetHeavy`, and `BorderSetDashed` are facade forwarding functions instead of copied typed constants.

## Known Noise

Focused facade compilation still emits existing dependency warnings from `nextpas.core.text.number.pow10.inc`,
`nextpas.core.tui.terminal.pas`, and `nextpas.core.tui.layout.dsl.pas`. This round does not claim warning cleanup.
