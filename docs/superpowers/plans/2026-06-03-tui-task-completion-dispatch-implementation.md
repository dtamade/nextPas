# TUI Task Completion Dispatch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the `nextpas.core.tui.ext` task-completion dispatch contract so `TApp` routes task completions to the top screen by default and to an explicit app callback when installed.

**Architecture:** Keep the change inside the TUI app-framework seam. `TScreen` gains a no-op virtual completion hook, `TApp` gains an explicit task-completion callback plus a default dispatch method, and `TApp.Run` drains completion batches before render and poll. Focused proof stays in `test_tui_app`.

**Tech Stack:** Free Pascal, `nextpas.core.tui.app`, `nextpas.core.tui.app.screen`, `nextpas.core.tui.task`, focused `make`-driven tests

---

### Task 1: Freeze the focused RED in `test_tui_app`

**Files:**
- Modify: `core/tests/nextpas.core.tui/test_tui_app/test_tui_app.lpr`
- Test: `core/tests/nextpas.core.tui/test_tui_app/Makefile`

- [ ] **Step 1: Write the failing test contract**

```pascal
procedure TRecordingScreen.HandleTaskCompletions(
  const Slots: array of TCompletionSlot; SlotCount: Integer); override;

property OnTaskCompletionCb;

CheckEqual(Int64(0), Int64(LApp.BeginFrameCount),
  'task completion quit stops app before rendering');
CheckEqual(Int64(0), Int64(LApp.PollCount),
  'task completion quit stops app before polling');
```

- [ ] **Step 2: Run the focused test to verify RED**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_app clean test
```

Expected: FAIL during compile because `TScreen` does not yet expose `HandleTaskCompletions` and `TApp` does not yet expose the task-completion callback surface.

- [ ] **Step 3: Tighten the focused assertions**

```pascal
T.Run('app routes task completions to top screen by default',
  @TestAppRoutesTaskCompletionsToTopScreenByDefault);
T.Run('app routes task completions to callback path',
  @TestAppRoutesTaskCompletionsToCallbackPath);
```

Add assertions that the screen path and callback path can both stop the loop before render and poll.

- [ ] **Step 4: Re-run the focused test to keep RED honest**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_app clean test
```

Expected: still FAIL for missing production contract, not for malformed test code.

- [ ] **Step 5: Commit checkpoint after GREEN only**

```bash
git add core/tests/nextpas.core.tui/test_tui_app/test_tui_app.lpr
git commit -m "test(tui): freeze task completion dispatch contract"
```

### Task 2: Implement the screen and app completion surface

**Files:**
- Modify: `core/src/nextpas.core.tui.app.screen.pas`
- Modify: `core/src/nextpas.core.tui.app.pas`
- Test: `core/tests/nextpas.core.tui/test_tui_app/test_tui_app.lpr`

- [ ] **Step 1: Add the screen-side virtual hook**

```pascal
procedure HandleTaskCompletions(
  const Slots: array of TCompletionSlot; SlotCount: Integer); virtual;
```

Default implementation should be a no-op, just like the base `HandleEvent`.

- [ ] **Step 2: Add the app-level callback and default dispatcher**

```pascal
type
  TAppTaskCompletionProc = procedure(App: TApp;
    const Slots: array of TCompletionSlot; SlotCount: Integer) of object;

protected
  procedure HandleTaskCompletions(
    const Slots: array of TCompletionSlot; SlotCount: Integer); virtual;

public
  property OnTaskCompletionCb: TAppTaskCompletionProc
    read FOnTaskCompletion write FOnTaskCompletion;
```

The default dispatcher should:

- return immediately when `SlotCount <= 0`
- call `OnTaskCompletionCb` when assigned
- otherwise call `Screens.Top.HandleTaskCompletions(...)` when a top screen exists

- [ ] **Step 3: Replace the completion wakeup path in `TApp.Run`**

```pascal
if FTasks.CompletionCount > 0 then
begin
  LCompletionCount := FTasks.DrainCompleted(LCompletions, Length(LCompletions));
  HandleTaskCompletions(LCompletions, LCompletionCount);
  ConsumeScreenQuitRequest;
  if FShouldQuit then
    Continue;
end;
```

Do not route completion delivery through `DispatchTick`.

- [ ] **Step 4: Run the focused test to verify GREEN**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_app clean test
```

Expected: PASS with the new completion routing contract.

- [ ] **Step 5: Refactor only if needed**

```pascal
procedure TApp.HandleTaskCompletions(...);
var
  LTop: TScreen;
begin
  ...
end;
```

Keep the helper small and explicit. Do not widen the app framework or scheduler surface in this task.

- [ ] **Step 6: Commit the behavior change**

```bash
git add core/src/nextpas.core.tui.app.screen.pas core/src/nextpas.core.tui.app.pas core/tests/nextpas.core.tui/test_tui_app/test_tui_app.lpr
git commit -m "feat(tui): dispatch task completions through app and screen"
```

### Task 3: Synchronize the TUI control surface and verify closure

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`
- Modify: `core/docs/plans/2026-05-31-tui-migration-goaltree.md`
- Test: `core/tests/nextpas.core.tui/test_tui_app/Makefile`

- [ ] **Step 1: Record the implementation truth**

```markdown
- 当前 completion contract 真相：
  - 默认 path -> top screen
  - explicit app callback -> callback precedence
  - quit is consumed before render/poll
```

- [ ] **Step 2: Re-run the focused verification for final evidence**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_app clean test
```

Expected: PASS, with heaptrc showing `0 unfreed memory blocks`.

- [ ] **Step 3: Check git hygiene**

Run:

```bash
git status --short --branch
```

Expected: only the intended TUI files are modified before the final commit, and the worktree is clean after commit.

- [ ] **Step 4: Commit the control-surface sync**

```bash
git add task_plan.md findings.md progress.md core/docs/plans/2026-05-31-tui-migration-goaltree.md docs/superpowers/plans/2026-06-03-tui-task-completion-dispatch-implementation.md
git commit -m "docs(tui): record task completion dispatch closure"
```

- [ ] **Step 5: Final closeout report**

Include:

```text
- what changed
- focused verification evidence
- retrospective
- next TUI seam to tackle
- final commit ids
```
