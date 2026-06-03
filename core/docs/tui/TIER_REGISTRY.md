# nextpas.core.tui Tier Registry

This file is the frozen ownership map for the four public TUI facades. When a new symbol is exported,
the first question is not "can it compile from the default facade?" but "which tier actually owns it?"

## Keep `nextpas.core.tui` as the correctness-first default

`nextpas.core.tui` owns the terminal-correctness minimum closure:

- Foundational types
  - `nextpas.core.tui.base`
  - `nextpas.core.tui.error`
  - `nextpas.core.tui.color`
  - `nextpas.core.tui.modifier`
  - `nextpas.core.tui.style`
  - `nextpas.core.tui.cell`
- Render model
  - `nextpas.core.tui.buffer`
  - `nextpas.core.tui.overlay`
  - `nextpas.core.tui.text`
  - `nextpas.core.tui.text.format`
  - `nextpas.core.tui.borders`
  - `nextpas.core.tui.layout`
  - `nextpas.core.tui.layout.grid`
  - `nextpas.core.tui.layout.dsl`
- Event and terminal pipeline
  - `nextpas.core.tui.event`
  - `nextpas.core.tui.input`
  - `nextpas.core.tui.ansi`
  - `nextpas.core.tui.backend.ansi`
  - `nextpas.core.tui.backend.test`
  - `nextpas.core.tui.terminal`
- Widget contract and basic widgets
  - `nextpas.core.tui.widget.intf`
  - `nextpas.core.tui.widget.block`
  - `nextpas.core.tui.widget.paragraph`
  - `nextpas.core.tui.widget.list`
  - `nextpas.core.tui.widget.clear`
  - `nextpas.core.tui.widget.tabs`
  - `nextpas.core.tui.widget.scrollbar`
  - `nextpas.core.tui.widget.table`
  - `nextpas.core.tui.widget.input`

Default core does not own:

- `TApp`
- theme presets
- task runtime
- image protocol and clipboard contracts
- advanced widget catalog outside the basic set above

## Keep `nextpas.core.tui.ext` as the stable framework layer

`nextpas.core.tui.ext` owns the stable app/runtime surface layered on top of `core`:

- Interaction and focus orchestration
  - `nextpas.core.tui.focus`
  - `nextpas.core.tui.interaction`
  - `nextpas.core.tui.keybind`
- Stable runtime and scheduling
  - `nextpas.core.tui.anim`
  - `nextpas.core.tui.animator`
  - `nextpas.core.tui.frame_budget`
  - `nextpas.core.tui.task`
  - `nextpas.core.tui.loading`
  - `nextpas.core.tui.app`
  - `nextpas.core.tui.app.screen`
- Stable presentation helpers
  - `nextpas.core.tui.theme`
  - `nextpas.core.tui.widget.panel`
  - `nextpas.core.tui.widget.chat_theme`

Use `ext` when you need:

- `TApp`
- app-owned shared-state injection (`TApp.SharedStateObject` and `TScreen.SharedStateObject`)
- render-loop callbacks
- panel/grid orchestration
- stable theme presets
- task/frame-budget integration

## Keep `nextpas.core.tui.experimental` opt-in

`nextpas.core.tui.experimental` owns the volatile protocol surface:

- `nextpas.core.tui.image_cap`
- `nextpas.core.tui.sixel`
- `nextpas.core.tui.image_mgr`
- `nextpas.core.tui.clipboard`

This tier is where protocol detection and transport experiments belong. These symbols should not move
back into the default facade just because a particular terminal happens to support them.

## Keep `nextpas.core.tui.full` as the compatibility umbrella

`nextpas.core.tui.full` aggregates:

- everything from `core`
- everything from `ext`
- everything from `experimental`
- the current advanced widget catalog that is still kept on the broad migration surface

The current full-only advanced widget families include:

- `widget.gauge`
- `widget.sparkline`
- `widget.barchart`
- `widget.canvas`
- `widget.tree`
- `widget.dialog`
- `widget.menu`
- `widget.split_pane`
- `widget.modal`
- `widget.popover`
- `widget.tooltip`
- `widget.select`
- `widget.scrollview`
- `widget.calendar`
- `widget.breadcrumb`
- `widget.statusbar`
- `widget.timeline`
- `widget.progress_group`
- `widget.linechart`
- `widget.input_editor`
- `widget.diffview`
- `widget.file_tree`
- `widget.kanban`
- `widget.markdown`
- `widget.virtual_list`
- `widget.command_palette`
- `widget.notification_center`
- `widget.form`
- `widget.syntax`
- `widget.toast`

`full` is for migration and broad compatibility. It is not the target shape of the default public API.
