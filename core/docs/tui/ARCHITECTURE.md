# nextpas.core.tui Architecture

## Start from the facade that matches your job

Since the surface-freeze slice, the public surface is split into four facades:

- `nextpas.core.tui`
- `nextpas.core.tui.ext`
- `nextpas.core.tui.experimental`
- `nextpas.core.tui.full`

The split is intentional:

- `nextpas.core.tui` owns terminal correctness: buffer, text, layout, event/input, ANSI backend,
  `TTerminal`, and the smallest useful widget set.
- `nextpas.core.tui.ext` owns stable app/runtime framework concerns: `TApp`, panel/layout helpers,
  theme, task, frame budget, focus, interaction, and animation primitives.
- `nextpas.core.tui.experimental` owns high-volatility protocol features such as image capability
  detection, image transport, sixel, and clipboard negotiation.
- `nextpas.core.tui.full` keeps the migration-era broad surface alive, so existing code can keep
  compiling while dependencies are moved toward `core` or `ext`.

If a feature does not belong to terminal correctness, it should not quietly leak back into the default
`nextpas.core.tui` facade.

## Keep the runtime layers separate

```
┌──────────────────────────────────────────────────────────┐
│ Public facades                                           │
│ core | ext | experimental | full                         │
├──────────────────────────────────────────────────────────┤
│ App/runtime layer                                        │
│ TApp, screens, tasks, themes, panel orchestration        │
├──────────────────────────────────────────────────────────┤
│ Widget layer                                              │
│ IWidget hierarchy, basic widgets, advanced widgets       │
├──────────────────────────────────────────────────────────┤
│ Text/layout/render model                                  │
│ TText, TLayout, TBuffer, overlay, diff                   │
├──────────────────────────────────────────────────────────┤
│ Terminal/runtime truth                                    │
│ TTerminal, capability profile, ANSI backend, input       │
├──────────────────────────────────────────────────────────┤
│ Platform                                                  │
│ console, signal, time, io                                │
└──────────────────────────────────────────────────────────┘
```

`full` is not another architectural layer. It is a compatibility aggregation of the other surfaces plus
the still-migrating broad widget/runtime catalog.

## Keep `ext` app-first

`nextpas.core.tui.ext` is no longer just a place where `TApp` happens to be visible. The intended stable
happy path is now:

1. Create `TApp`
2. Push a `TScreen` into `App.Screens`
3. Let the default render/event path delegate to the top screen

That means:

- `TApp.Render` defaults to `Screens.Render(...)` when no explicit callback or override is provided
- `TApp.HandleEvent` defaults to `Screens.HandleEvent(...)`
- `TScreenStack.RequestQuit` is consumed by the app loop, so a screen can terminate the app without
  reaching back into terminal internals
- `TApp.SharedStateObject` owns the app-level shared-state object for cross-screen runtime coordination
- `TScreen.SharedStateObject` exposes that object to screens through `TScreenStack`, without adding an
  `App` back-reference to the screen model

Callbacks still exist for lightweight demos or adapter-style use, but the framework-level contract now
centers `ext` on screen-driven apps rather than raw callback wiring.

## Keep shared state app-owned and injected

The current shared-state seam is intentionally small:

- `TApp.SharedStateObject` is the single app-owned slot
- `TScreenStack.SharedStateObject` carries the same object through runtime ownership
- `TScreen.SharedStateObject` is the screen-facing read path

This seam exists so cross-screen state can be injected through the stable `ext` runtime boundary without
turning `nextpas.core.tui` into a retained-mode state framework.

The contract remains strict:

- background tasks do not mutate UI state directly from worker threads
- completion-time writes still happen through the app-owned completion path
- screens observe shared state, but they do not become implicit owners of callback-driven completion writes
- this is not a store/reducer/message-bus system

## Keep capability truth in `TTerminal.CapabilityProfile`

Enhanced terminal features now flow through `TTerminal.CapabilityProfile`, not through a loose set of
boolean fields.

The profile currently owns:

- `Truecolor`
- `KittyKeyboard`
- `ImageProtocol`

Each capability tracks:

- `Requested`
- `Detected`
- `Active`
- `Verified`
- `FallbackReason`

This matters because some capabilities are only candidates until the session proves them. For example,
kitty/wezterm/ghostty hints can mark kitty keyboard support as detected, but it remains inactive until
terminal-side negotiation is implemented.

Compatibility properties still exist:

- `HasTruecolor`
- `HasKittyKeyboard`
- `ImageProtocol`

They now read only the active projection. They are no longer the canonical source of runtime truth.

## Keep rendering immediate-mode

The render loop has not changed:

1. `TTerminal.BeginFrame` prepares the current buffer.
2. Application or caller code renders widgets into that buffer.
3. `TTerminal.EndFrame` merges overlay state, diffs previous and current buffers, emits ANSI patches,
   and swaps the frame buffers.

Widgets still do not own render state. Stateful behavior lives in explicit state records or app/runtime
orchestration.

## Keep widget contracts interface-first

All widgets still implement `IWidget`:

```pascal
IWidget = interface
  procedure Render(const AArea: TRect; ABuffer: TBuffer);
end;
```

Dedicated widget interfaces add builder/state methods. `TWidgetAdapter` remains the escape hatch for
wrapping a non-nil render callback as `IWidget`, but built-in widgets should continue to use dedicated
`class(TInterfacedObject, IWidget, IXxx)` implementations.

## Keep the hot path allocation-light

- `TCell` stays a 40-byte packed record.
- `TBuffer` stores a contiguous cell array.
- The diff engine still uses fixed-width cell comparison.
- ANSI output still funnels through `TStringBuilder`.
- Dirty-row tracking still avoids unnecessary patch emission.

The surface split is about contract clarity, not about changing the hot-path render model.

## Keep Unicode truth consistent end-to-end

Non-ASCII text still routes through the grapheme-aware path. The current contract is that
`text.width`, `tui.buffer`, `tui.overlay`, and `tui.text` must agree on width for ZWJ emoji,
skin-tone modifiers, keycap emoji, variation selectors, combining marks, and East Asian wide
characters.

That consistency goal is part of the core facade's correctness bar.

## Verify with focused TUI gates

This line does not rely on full-repo verification to prove TUI correctness. The maintained envelope is:

- `test_tui_cap_base`
- `test_tui_core_facade`
- `test_tui_ext_facade`
- `test_tui_experimental_facade`
- `test_tui_facade`
- `test_tui_terminal`
- `test_tui_image_cap`
- `test_tui_backend`
- `test_tui_buffer`
- `test_tui_widget_intf`
- `core/benchmarks/nextpas.core.tui/run_all.sh`

That keeps terminal correctness, facade ownership, and performance smoke tied to the TUI module itself.
