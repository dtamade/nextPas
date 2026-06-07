# Mem L0 Residual Debt Lane Kickoff

## Lane identity

- Module: `mem`
- New clean lane:
  - worktree: `/home/dtamade/projects/nextPas/.worktrees/core-mem-l0-debt`
  - branch: `codex/core-mem-l0-debt`
- Base truth: `main@9951242f`

## Overall objective

Continue `nextpas.core.mem` toward a truly clean L0 allocation foundation.

This is a long-running lane. Do not auto-complete the module after one small
`Ready` slice. Keep iterating through narrow, verified slices until the
controller says stop.

## Current truth

- Landed fact: `a8e411b0 fix(mem): move raw mmap and shm ownership into platform`
  is already on `main`.
- `mem` is not done, and L0 is not clean.
- The stable allocator/core direction in `core/docs/mem/README.md` is still
  correct, but its debt count is stale.
- Live source-boundary truth is the script:
  `core/tests/nextpas.core.mem/test_l0_dependency_boundaries/check_mem_l0_dependencies.sh`
- Current live allowlisted debt count is `8`, not `11`.
- Old lane `codex/core-mem` at `/home/dtamade/projects/nextPas/.worktrees/core-mem`
  is frozen history only. Do not continue there.

## Read first

1. `core/AGENTS.md`
2. `core/docs/design-conventions.md`
3. `core/docs/mem/README.md`
4. `core/docs/plans/2026-06-06-mem-l0-dependency-boundary.md`
5. `core/docs/plans/2026-06-06-mem-memory-map-shared-memory-owner-boundary-review.md`
6. `core/tests/nextpas.core.mem/test_l0_dependency_boundaries/check_mem_l0_dependencies.sh`

## Immediate route

Run the lane as narrow verified slices, not as a broad cleanup sweep.

Immediate priority order:

1. Reconfirm the live `8` residual debt entries from the source-boundary gate.
2. First implementation target:
   remove the `nextpas.core.text.conv` dependency from
   `core/src/nextpas.core.mem.pool.fixed.pas` without widening public surface or
   moving policy into `mem`.
3. If that slice closes cleanly and still stays narrow:
   decide the next smallest residual debt target.
   Prefer source-contract-first work on `mem.secure` or `mapped_*` only if the
   owner boundary is explicit and the touched paths stay small.
4. If a residual debt item requires a new platform-owned seam, stop at
   `Needs Review` before broad cross-module migration.

## Default modification scope

- `core/src/nextpas.core.mem*.pas`
- `core/tests/nextpas.core.mem/**`
- `core/tests/nextpas.core.os.env/**` only if a focused compile-truth blocker
  reappears and the reason is explicit
- `core/docs/mem/**`
- `core/docs/plans/2026-06-07-mem-*`

## Controlled cross-module rule

Cross-module changes are allowed only if the current `mem` slice cannot be made
correct without moving a host/owner seam behind `platform`.

If you touch outside `mem`, you must:

1. explain the owner-boundary reason before editing;
2. keep the touched paths minimal;
3. run both the `mem` gate and the affected consumer/owner gate;
4. list all cross-module touched files in the `Ready` report;
5. stop at `Needs Review` if the slice starts expanding into a new platform
   capability batch.

## Non-goals

- Do not claim `mem` is complete.
- Do not claim the L0 boundary is clean just because one debt entry is removed.
- Do not reopen `memory_map` / shared-memory owner-boundary work that already
  landed unless a new blocker proves it is necessary.
- Do not raw-merge old `codex/core-mem`.
- Do not mix unrelated allocator API redesign into this lane.

## Baseline commands

Run first:

```bash
git status --short --branch
git rev-parse --short HEAD
scripts/worktree-audit.sh
make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test
```

Then pick only the focused gates needed for the active slice.

## Preferred focused gates

Always:

```bash
make -C core/tests/nextpas.core.mem/test_l0_dependency_boundaries test
git diff --check
```

Add as needed by touched paths:

```bash
make -C core/tests/nextpas.core.mem/test_pool clean test
make -C core/tests/nextpas.core.mem/test_mem clean test
make -C core/tests/nextpas.core.mem/test_memory_map_compile_gate clean test
make -C core/tests/nextpas.core.mem/test_memory_map_allocator clean test
make -C core/tests/nextpas.core.mem/test_mapped_slab_pool clean test
make hygiene
```

Do not default to broad sweeps unless the touched surface genuinely requires it.

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

- No raw merge from the long-running lane.
- Landing must use a clean landing worktree plus path-limited replay or
  cherry-pick.
- Keep `task_plan.md`, `findings.md`, `progress.md`, generated files, and
  temporary logs out of landing unless explicitly authorized.

## Paste-ready goal

Use this in the new worktree:

```text
/goal Follow core/docs/plans/2026-06-07-mem-l0-residual-debt-lane-kickoff.md. Keep the mem lane active as a long-running L0 cleanup effort. Work in narrow verified slices, do not auto-complete after one Ready batch, and stop only at Ready, Needs Review, Blocked, or Landed.
```
