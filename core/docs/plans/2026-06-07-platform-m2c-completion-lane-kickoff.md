# Platform M2-C Completion Lane Kickoff

## Lane identity

- Module: `platform`
- New clean lane:
  - worktree: `/home/dtamade/projects/nextPas/.worktrees/core-platform-m2c-completion`
  - branch: `codex/core-platform-m2c-completion`
- Base truth: `main@9951242f`

## Overall objective

Continue `nextpas.core.platform` as a long-running OS-foundation lane.

Do not treat one `Ready` slice as platform completion. Keep the lane active
until the controller says stop.

## Current truth

Already landed on `main`:

- `49797342 test(net): lock readiness consumer contract`
- `0fb5fb3d fix(platform): harden windows completion contract`
- `222a6c20 fix(platform): require usable iouring probe`
- `a8e411b0 fix(mem): move raw mmap and shm ownership into platform`

Live architectural truth:

- `platform` is not runtime-complete.
- `platform.mmap` now owns raw mapping/shared-memory semantics.
- Linux must report `pbIoUring` only after a usable `io_uring_setup` probe.
- Windows completion truth is still partial:
  `TIocpReactor` has real port lifecycle and file `AsyncRead` / `AsyncWrite`,
  but `AsyncAccept` / `AsyncConnect` / `AsyncSend` / `AsyncRecv` /
  `AsyncClose` remain explicit unsupported paths.
- Windows is not yet "runtime ready".

Old lanes:

- `/home/dtamade/projects/nextPas/.worktrees/core-platform` is historical only.
- `/home/dtamade/projects/nextPas/.worktrees/core-platform-m2b-usability` is
  frozen after landing. Do not continue on either old lane.

## Read first

1. `core/AGENTS.md`
2. `core/docs/design-conventions.md`
3. `core/docs/platform-goal-tree.md`
4. `core/docs/plans/2026-06-06-platform-completion-design.md`
5. `core/docs/plans/2026-06-06-platform-completion-plan.md`
6. `core/src/nextpas.core.io.poller.pas`
7. `core/src/nextpas.core.io.reactor.iocp.pas`
8. `core/src/nextpas.core.platform.io.pas`

## Immediate route

Continue the completion lane in narrow, verifier-friendly slices.

Immediate priority order:

1. Reconfirm current completion truth on `main` with the focused Windows
   contract/compile gates.
2. First target:
   add or extend a focused contract slice around `TIocpReactor` lifecycle and
   consumer truth for `Poll` / `PollOne` / `Run` / `Stop` / `Flush`, plus the
   published unsupported boundary for unimplemented async operations.
3. Fix only the smallest real contract gap proven by RED.
4. If the next real gap requires broader socket completion API or actual Windows
   runtime evidence, either:
   - isolate a smaller source-contract / forced-compile slice; or
   - stop at `Needs Review` with the exact runtime-evidence plan.

## Default modification scope

- `core/src/nextpas.core.platform*.pas`
- `core/src/nextpas.core.io.poller.pas`
- `core/src/nextpas.core.io.reactor.iocp.pas`
- `core/src/nextpas.core.async*.pas`
- `core/tests/nextpas.core.platform*/**`
- `core/tests/nextpas.core.io.uring/**`
- `core/tests/nextpas.core.async/**`
- `core/tests/nextpas.core.net.server/**` only if a consumer contract slice
  truly needs it
- `core/docs/plans/2026-06-07-platform-*`

## Controlled cross-module rule

Cross-module work is allowed when consumer truth requires it, especially across
`platform`, `io.poller`, `io.reactor.iocp`, `async.loop`, and the immediate
consumer tests.

You must:

1. explain the consumer/owner-boundary reason before widening scope;
2. keep the slice narrow;
3. verify both the owner seam and the touched consumer seam;
4. list cross-module touched files in the `Ready` report;
5. stop at `Needs Review` if the slice turns into a broader Windows runtime or
   socket-completion publication batch.

## Non-goals

- Do not claim platform is complete.
- Do not write Windows as runtime-ready without real runtime evidence.
- Do not reopen the old historical `core-platform` lane.
- Do not expand into unrelated Darwin/Android cleanup in this batch.
- Do not silently publish unsupported IOCP socket operations as available.

## Baseline commands

Run first:

```bash
git status --short --branch
git rev-parse --short HEAD
scripts/worktree-audit.sh
make -C core/tests/nextpas.core.io.uring/test_poller_windows_contract clean test
make -C core/tests/nextpas.core.io.uring/test_poller_windows_compile_gate clean test
```

## Preferred focused gates

Always:

```bash
make -C core/tests/nextpas.core.io.uring/test_poller_windows_contract clean test
make -C core/tests/nextpas.core.io.uring/test_poller_windows_compile_gate clean test
git diff --check
```

Add as needed by touched paths:

```bash
make -C core/tests/nextpas.core.async/test_async_timeout clean test
make -C core/tests/nextpas.core.io.uring/test_poller clean test
make -C core/tests/nextpas.core.platform.io/test_platform_io clean test
make -C core/tests/nextpas.core.net.server/test_net_server clean test
make hygiene
```

Do not default to broad sweeps unless the actual touched surface requires it.

## Reporting discipline

Only report at real state nodes:

- `Ready`
- `Needs Review`
- `Blocked`
- `Landed`

`Ready` must include:

- branch / worktree / HEAD
- retained files
- excluded files
- focused verification evidence
- cross-module touched files, if any
- design reason
- risk
- landing recommendation

## Landing discipline

- No raw merge from long-running platform lanes.
- Landing must use a clean landing worktree plus path-limited replay or
  cherry-pick.
- Keep `task_plan.md`, `findings.md`, `progress.md`, generated files, and
  temporary logs out of landing unless explicitly authorized.

## Paste-ready goal

Use this in the new worktree:

```text
/goal Follow core/docs/plans/2026-06-07-platform-m2c-completion-lane-kickoff.md. Keep platform active as a long-running OS-foundation lane. Work in narrow verified completion-truth slices, do not auto-complete after one Ready batch, and stop only at Ready, Needs Review, Blocked, or Landed.
```
