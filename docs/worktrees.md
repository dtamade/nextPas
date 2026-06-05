# Worktree Policy

## Rule

All project-owned linked worktrees for this repository must live under the
repository root:

```text
.worktrees/<short-name>
```

The `.worktrees/` directory is ignored by Git and must never be committed as
source. Do not create new nextPas worktrees under `~/.config/superpowers`,
`.claude/worktrees`, or arbitrary sibling directories.

## Module Lanes

Use one persistent worktree per active module or governance lane. This keeps
agent session context, branch state, and module ownership easy to resume.

Recommended layout:

```text
.worktrees/core-http
.worktrees/core-math
.worktrees/core-mem
.worktrees/core-platform
.worktrees/core-simd
.worktrees/compiler
```

Recommended branch names:

```text
codex/core-http
codex/core-math
codex/core-mem
codex/core-platform
codex/core-simd
codex/compiler
```

Do not create a new date-stamped branch for every prompt. The module lane is
the long-lived continuation branch. Use small commits inside that lane, and use
temporary `landing/<module>-YYYYMMDD` branches only when preparing reviewed
mainline integration.

## Create A Module Worktree

Use the project script:

```bash
scripts/worktree-add.sh codex/core-http main
```

The script creates:

```text
.worktrees/core-http
```

If the branch already exists, the script checks it out in that directory. If it
does not exist, the script creates it from `main` by default:

```bash
scripts/worktree-add.sh codex/core-http main
```

Then resume the agent session from the worktree path:

```bash
cd .worktrees/core-http
codex
```

or:

```bash
cd .worktrees/core-http
claude
```

Only the controller should create new module lanes unless the user explicitly
delegates that setup. Module owners should continue from the assigned worktree
instead of creating new side branches.

## Audit Worktrees

Run:

```bash
scripts/worktree-audit.sh
```

The audit reports every linked worktree, its branch, dirtiness, and whether it
is inside the project-local `.worktrees/` directory. Any non-main linked
worktree outside `.worktrees/` is a policy violation.

Run this audit before branch cleanup, before a landing wave, and when a user
asks whether the repository is still in worktree/branch debt.

## Move An Existing Worktree

Do not move a worktree with `mv`. Use Git so `.git/worktrees` metadata stays
valid:

```bash
git worktree move <old-path> .worktrees/<short-name>
```

Only move a worktree after its owner confirms no agent or build is currently
running inside it.

After moving, run:

```bash
scripts/worktree-audit.sh
git worktree list --porcelain
```

Do not delete the old path manually. Let Git update its linked-worktree
metadata.

## Starting A Module Session

The controller should give the module owner a paste-ready prompt that includes:

- module name and assigned worktree path
- branch name and current `HEAD`
- allowed paths and forbidden paths
- current module status and known red points
- focused verification commands
- reporting format
- merge/landing constraints

The module owner should start by running:

```bash
git status --short --branch
git rev-parse --short HEAD
scripts/worktree-audit.sh
make hygiene
```

If `make hygiene` fails before any local edits, report it as baseline debt
instead of silently cleaning or committing unrelated files.

## Landing Discipline

Worktree location does not make a branch safe to merge.

Before landing any branch:

1. Confirm the worktree is clean.
2. Confirm the changed paths are in the intended module.
3. Rebase, merge, or replay onto current `main` in a landing candidate.
4. Run focused verification for the changed surface.
5. Merge only with `ff-only` or an equivalent reviewed landing commit.
6. Remove the worktree after the branch is fully absorbed.

Cleanup command after a successful landing:

```bash
git worktree remove .worktrees/<short-name>
git branch -d <branch-name>
git worktree prune
```

For branches that should not land but are still historically useful, create an
archive tag before deleting the branch:

```bash
git tag archive/<short-name> <branch-or-commit>
```

Do not raw-merge long-lived module lanes into `main`. Land them through a clean
candidate branch, reviewed cherry-picks, or path-limited replay. The controller
owns final mainline integration unless explicitly delegated.

## Reporting Discipline

Module owners should not report every small action. Report only when the state
changes:

- `Ready`: implementation and focused verification are complete, and the branch
  is ready for landing review.
- `Blocked`: progress requires controller or user decision.
- `Landed`: changes reached `main`, verification was rerun, and cleanup status
  is known.
- `Needs Review`: a design or cross-module decision is required before more
  code should be written.

A `Ready` report must include branch, worktree path, `HEAD`, changed file list,
files that must not be landed, focused verification evidence, and merge
recommendation.

Do not bring root `task_plan.md`, `findings.md`, or `progress.md` into `main`
as routine module status. If durable documentation is needed, write a scoped
document under `docs/plans/` or the module's documentation path.

## Do Not

- Do not commit `.worktrees/` contents or gitlink placeholders.
- Do not raw-merge a branch just because its worktree is clean.
- Do not delete a dirty worktree without owner approval.
- Do not move a worktree manually with `mv`.
- Do not keep stale completed worktrees around after their code has landed.
- Do not create a new branch/worktree when an assigned module lane already
  exists.
- Do not use a module lane to make unrelated cross-module changes.
