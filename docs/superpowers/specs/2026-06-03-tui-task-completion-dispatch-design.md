# nextpas.core.tui task completion dispatch design

## What this changes

`nextpas.core.tui.ext` already has a stable screen-driven app model for render and input:

1. Create `TApp`
2. Push a `TScreen` into `App.Screens`
3. Let the default render and event path delegate to the top screen

Task completion is the remaining gap in that model. Today `TApp.Run` notices queued completions, but it still treats them as a wakeup for `DispatchTick` instead of as a first-class runtime contract.

This design makes task completion a real app-framework path:

- by default, drained task completions go to the current top screen
- if the app explicitly installs a task-completion callback, that callback takes over the batch
- quit requests raised during completion handling stop the loop before render and poll

This keeps `ext` screen-driven by default while preserving an explicit app-level escape hatch for demos, adapters, and apps that want to own async orchestration globally.

## Why this is needed

The current state is internally inconsistent:

- render defaults to `Screens.Render(...)`
- input defaults to `Screens.HandleEvent(...)`
- task completion does not yet have an equivalent default path

That leaves async work outside the stable `TApp + TScreenStack` contract. A screen can already own visible state, navigation, and quit behavior, but it cannot yet own the natural async result path without manual glue.

For a framework-grade app model, task completion should be aligned with the same ownership rules as render and input.

## Design goals

- Keep `nextpas.core.tui.ext` screen-driven by default
- Make task completion explicit in the app loop instead of piggybacking on tick dispatch
- Allow a single app-level interception point when a caller intentionally wants global ownership
- Keep framework policy minimal: pass through completion status, do not invent retry, toast, or quit semantics
- Freeze the behavior with focused `test_tui_app` coverage instead of widening to repo-level verification

## Non-goals

This slice does not introduce:

- a global state store or reducer system
- task ownership metadata or route tagging
- fan-out or broadcast delivery across multiple screens
- progress streaming or partial-result APIs
- task scheduler redesign
- benchmark expansion

## Current truth to preserve

These facts are already true and should remain true after the change:

- `nextpas.core.tui.ext` is the stable app/runtime layer
- `TApp.Render` defaults to the top screen when no explicit callback is installed
- `TApp.HandleEvent` defaults to the top screen when no explicit callback is installed
- `TScreenStack.RequestQuit` is consumed by the app loop
- explicit callbacks are still valid escape hatches for lightweight or adapter-style apps

## Dispatch model

### Default ownership

If the app has no explicit task-completion callback, task-completion ownership belongs to the current top screen.

That means a screen is the default owner of:

- async data refresh
- search results
- background actions that mutate visible state
- completion-driven screen-local navigation or quit

This matches the existing screen-driven render and input model.

### Explicit app interception

If the app installs an explicit task-completion callback, that callback becomes the owner of the drained completion batch for that dispatch round.

This is an override, not a fallback and not a second observer.

Once the callback is present:

- the callback receives the batch
- the screen does not receive the same batch
- the framework does not attempt bubbling, replay, or dual delivery

This keeps ownership clear and matches the existing “explicit callback overrides the default path” style already used by render and input.

### No dual propagation

The same completion batch must never be delivered to both:

- the app-level callback, and
- the top screen

in a single dispatch round.

Dual delivery would make completion ownership ambiguous and create duplicate side effects such as:

- repeated navigation
- repeated toasts or logging
- inconsistent state transitions
- multiple quit requests for the same completion

## Loop semantics

Task completion becomes its own step in `TApp.Run`.

The intended order for each loop iteration is:

1. drain task completions
2. dispatch the drained batch to the app callback or top screen
3. consume quit requests produced during completion handling
4. if still running, render a frame
5. if still running, poll an event

This changes the meaning of completion from “tick wakeup” to “async result delivery”.

### Empty drain behavior

If a wakeup check notices queued completions but `DrainCompleted(...)` returns `0`, the app does nothing.

The framework must not:

- call the app callback with an empty batch
- call the screen hook with an empty batch
- synthesize a fake completion tick

### Quit behavior

If completion handling triggers either:

- `App.Quit`, or
- `TScreenStack.RequestQuit`

the app loop consumes that quit signal immediately after the completion dispatch step.

In that case the same iteration must not continue into:

- render
- event polling
- another completion-dispatch step

This keeps quit behavior consistent with the existing screen-driven app model and lets screens terminate the app without touching terminal internals.

## Status handling

The framework passes task status through exactly as produced by `TTaskManager`.

That includes:

- `tsCompleted`
- `tsFailed`
- `tsCancelled`

The framework does not:

- translate failed completion into exceptions
- auto-quit on failed or cancelled status
- retry automatically
- generate UI feedback automatically

Status interpretation remains a screen-level or app-level policy decision.

## API shape

This design intentionally fixes semantics before implementation details, but the intended shape is:

- `TScreen` gains a virtual task-completion hook
- `TApp` gains an explicit task-completion callback property
- `TApp.Run` drains and dispatches completion batches directly

The callback should be named to make its ownership explicit, for example `OnTaskCompletionCb`.

The key design rule is semantic, not syntactic:

- no callback installed -> top screen owns completions
- callback installed -> app-level callback owns completions

## Focused verification envelope

This slice should be proven with focused `test_tui_app` coverage only.

The minimum contract to freeze is:

1. default completion path goes to the top screen
2. explicit app callback receives the batch instead of the screen
3. explicit app callback receives the original task id and status
4. top screen path can request quit before the first poll
5. callback path can request quit before render and poll
6. empty drain does not invoke either handler

These tests are enough to prove the new contract without widening into unrelated TUI modules or repo-wide verification.

## Risks and tradeoffs

### Why not bubble from screen to app

A handled-or-bubble model would support richer future routing, but it adds complexity now:

- it introduces a second propagation rule that render and input do not currently share
- it complicates ownership for the first stable async contract
- it conflicts with the current test intent, which already expects callback precedence

That may become valuable later for multi-window or more advanced orchestration, but it is not the right default for this D1 slice.

### Why not app-first by default

Making the app callback the implicit first stop would weaken the current `ext` direction.

The documented happy path is still:

- use `TApp`
- use `TScreen`
- let the default framework path delegate to the active screen

If task completion defaulted to app-first, async orchestration would quietly diverge from render and input ownership.

## Implementation boundary for the next step

The next implementation slice should only do the following:

- add the screen hook
- add the app callback
- wire direct completion dispatch into `TApp.Run`
- update `test_tui_app`
- synchronize the TUI goal tree and local control files

It should not reopen broader app architecture, state management, or scheduler design work.
