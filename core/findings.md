# Findings & Decisions

## Requirements
- Continue `nextpas.core.tui` migration work from the v0.9.0 state.
- Start from overall specification, architecture principles, and evolution route.
- Use the TUI goal tree as the control map.
- Do not call API/interface work complete without unit tests and memory-leak verification.
- End the round with a detailed report, retrospective, next-step plan, and git commit.

## Research Findings
- `docs/design-conventions.md` defines facade units as explicit re-export units: types and functions must be redeclared because FPC does not automatically re-export `uses` units.
- `docs/plans/2026-05-31-tui-migration-goaltree.md` marks all seven migration phases complete but still frames facade re-export and API proof as part of the public contract.
- `src/nextpas.core.tui.pas` currently uses only 12 widget units plus `widget.intf`, and defines only `ITuiWidget` and `ITuiBlock` as widget interface aliases.
- `docs/tui/WIDGET_CATALOG.md` lists 40+ widgets and states that all widgets implement `IWidget` via `class(TInterfacedObject, IWidget, IXxx)`.
- `docs/tui/README.md` shows `uses nextpas.core.tui;` as the quick-start entry point and documents `IWidget` / `IBlock` directly.
- `src/nextpas.core.tui.widget.intf.pas` still defines `TWidgetRenderFn` and `TWidgetAdapter`, but `rg` found no production or test consumers of either name.
- `TCheckbox` and `TRadioGroup` live in `nextpas.core.tui.widget.form.pas`; they account for the catalog's extra widget entries beyond individual widget-unit count.
- Focused TDD showed `TWidgetAdapter.Create(nil)` previously created an object without raising, and the test leaked one 48-byte block because no interface owned that object.
- A retained public adapter also needs facade aliases; otherwise `uses nextpas.core.tui` cannot access the extension point.
- Broad TUI verification must pass an explicit `FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc` when launched from a shell that may not preserve the interactive FPC path.
- Codex-style review found two API surface risks: facade missed some builder support types/constants (`TWrap`, `WRAP_TRIM`, `TContentAlign`), and copied `BorderSet*` values instead of forwarding to canonical initialized variables.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Treat facade completion as the next API-quality slice | Consumer integration and merge are safer once `nextpas.core.tui` is a coherent single entry point |
| Add compile-time facade tests | Missing aliases are compile-time API breaks, so a dedicated test project is the direct proof |
| Keep `TWidgetAdapter` decision explicit | Removing unused API is tempting, but public API cleanup must be deliberate and documented |
| Retain `TWidgetAdapter` | It is a small extension bridge for custom render functions/external widget shims, while built-in widgets continue to use dedicated `IWidget` classes |
| Reject nil render functions in `TWidgetAdapter.Create` | Failing at construction is clearer than allowing a later nil callback and prevents ownership leaks in invalid construction paths |
| Make table `TContentAlign` an alias of text `TAlignment` | Paragraph and table alignment share the same semantic values; using one canonical enum avoids duplicate `caLeft` / `caCenter` / `caRight` constants in facade consumers |
| Forward `BorderSet*` from the facade as functions | The canonical border presets live as initialized variables in `nextpas.core.tui.borders`; forwarding avoids static copies drifting from the source unit |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Existing planning files described an old regex review | Replaced them with this TUI API round plan |
| `.github` was not present under `core/` | Used the root `Makefile` test discovery rules to understand test integration |
| Facade compile test exposed missing `TWidgetAdapter` alias | Added `TWidgetRenderFn` and `TWidgetAdapter` aliases to `nextpas.core.tui` |
| Focused facade compilation emits many existing warnings | Recorded as known dependency noise; not claimed as warning cleanup in this round |
| Full TUI test loop initially failed with `make: fpc: No such file or directory` | Reran the same 32 test projects with explicit `FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc`; all passed |
| Codex-style review found missing facade builder support types and `BorderSet*` copy semantics | Added focused tests; exported missing aliases/constants; changed `BorderSet*` to forwarding functions; reran full suite |

## Resources
- `docs/design-conventions.md`
- `docs/plans/2026-05-31-tui-migration-goaltree.md`
- `docs/tui/README.md`
- `docs/tui/ARCHITECTURE.md`
- `docs/tui/WIDGET_CATALOG.md`
- `src/nextpas.core.tui.pas`
- `src/nextpas.core.tui.widget.intf.pas`

## Visual/Browser Findings
- None; this is source/API work.
