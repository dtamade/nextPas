# System TypInfo Minimal Unlock Review Kickoff

## Lane identity

- Module: `system`
- New clean continuation lane:
  - worktree: `/home/dtamade/projects/nextPas/.worktrees/core-system-typinfo-unlock`
  - branch: `codex/core-system-typinfo-unlock`
- Base truth: `main@1387d5b9`

## Overall objective

Reopen `nextpas.core.system` through the narrowest credible S4 continuation:
review whether the seven-symbol TypInfo minimal surface is now ready to move
from `deferred` toward a controller-approved unlock slice.

This lane is active again, but the first target is still a review-quality
decision packet, not immediate implementation.

Do not auto-complete the entire `system` program after one narrow batch.

## Current truth

Already landed on `main`:

- `9c156f95` `nextpas.core.system` S0/S1/S2/S3 foundation
- `1387d5b9` TypInfo minimal pressure audit and source-contract sync

The landed audit fixed the current truth:

- `nextpas.core.system.typinfo` is still deferred
- the real pressure is narrow and concrete:
  - `PTypeInfo`
  - `TTypeKind`
  - `TypeInfo`
  - `GetTypeKind`
  - `InitializeArray`
  - `FinalizeArray`
  - `CopyArray`
- strongest live consumers are:
  - `compiler/tests/test_typinfo_contract.pas`
  - `core/src/nextpas.core.collections.element_manager.pas`
  - collections specialization users of `GetTypeKind`

Old lane warning:

- `/home/dtamade/projects/nextPas/.worktrees/core-system` on `codex/core-system`
  is now stale history, not the lane to continue in.

## Read first

1. `core/AGENTS.md`
2. `core/docs/design-conventions.md`
3. `core/docs/system/README.md`
4. `core/docs/system/goal-tree.md`
5. `core/docs/system/compatibility-facades.md`
6. `core/docs/system/compatibility-matrix.md`
7. `core/docs/system/typinfo-minimal-pressure.md`
8. `compiler/tests/test_typinfo_contract.pas`
9. `core/src/nextpas.core.collections.element_manager.pas`
10. `core/tests/nextpas.core.system/test_system_source_contracts/check_system_source_contracts.sh`

## Immediate route

The first slice is a `Needs Review` unlock review, not a live facade commit.

Immediate priority order:

1. Reconfirm the current seven-symbol pressure against live compiler and
   collections consumers.
2. Decide whether the project is now ready to open a minimal live
   `nextpas.core.system.typinfo` facade review, or whether the correct answer
   remains `deferred`.
3. If the answer is "still deferred", produce a tighter review packet naming
   the remaining blockers in compiler/runtime ABI, metadata layout, or
   managed-array lifecycle truth.
4. If the answer is "ready to unlock", stop at `Needs Review` with:
   - exact public symbol list
   - exact owner boundary
   - exact minimal file set
   - focused verification plan
   - explicit non-goals
5. Do not jump directly from this kickoff to implementation unless a later
   controller review explicitly approves that next step.

## Default modification scope

For the first slice:

- `core/docs/system/**`
- `core/tests/nextpas.core.system/test_system_source_contracts/**`
- `core/docs/plans/2026-06-07-system-*`

Read-only audit targets:

- `compiler/tests/test_typinfo_contract.pas`
- `core/src/nextpas.core.collections.*`

## Controlled cross-module rule

Cross-module edits are not the default for this first slice.

You may touch outside `system` only if the review packet cannot be made honest
without a tiny source-contract or evidence sync in an immediate consumer test.

If that happens, you must:

1. explain why the cross-module edit is required;
2. keep the touched paths minimal;
3. run the `system` focused gate plus the touched consumer gate;
4. list cross-module touched files in the report;
5. stop at `Needs Review` if the slice starts turning into a live TypInfo
   implementation batch.

## Non-goals

- Do not create `nextpas.core.system.typinfo` yet.
- Do not create `nextpas.core.system.sysutils`.
- Do not create `nextpas.core.system.classes`.
- Do not change compiler/runtime implementation in this first slice.
- Do not turn bootstrap RTL units into public `system.*` by default.
- Do not blur owner boundaries between compiler metadata, runtime helpers,
  `mem`, and collections.

## Baseline commands

Run first:

```bash
git status --short --branch
git rev-parse --short HEAD
scripts/worktree-audit.sh
make -C core/tests/nextpas.core.system clean test
```

## Preferred focused gates

Always:

```bash
make -C core/tests/nextpas.core.system clean test
git diff --check
```

Add only if you touch or formalize consumer proof:

```bash
make hygiene
```

Do not default to broad compiler or collections sweeps in this first review
slice unless the touched surface genuinely requires it.

## Reporting discipline

Only report at real state nodes:

- `Ready`
- `Needs Review`
- `Blocked`
- `Landed`

Expected first-state target:

- `Needs Review`

That report must include:

- branch / worktree / HEAD
- retained files
- excluded files
- focused verification evidence
- exact seven-symbol surface judgment
- owner-boundary judgment
- remaining blocker list, or exact unlock packet if ready
- landing / next-step recommendation

## Landing discipline

If this first slice ends as docs/source-contract only and is approved:

- no raw merge
- clean landing worktree only
- path-limited replay or cherry-pick only

## Paste-ready goal

Use this in the new worktree:

```text
/goal Follow core/docs/plans/2026-06-07-system-typinfo-minimal-unlock-kickoff.md. Reopen system through a narrow TypInfo minimal unlock review slice. First target is a controller-grade Needs Review packet, not implementation. Keep the lane active, work in narrow verified slices, and stop only at Ready, Needs Review, Blocked, or Landed.
```
