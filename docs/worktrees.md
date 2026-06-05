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

## Create A Worktree

Use the project script:

```bash
scripts/worktree-add.sh codex/my-task-20260606
```

The script creates:

```text
.worktrees/my-task-20260606
```

If the branch already exists, the script checks it out in that directory. If it
does not exist, the script creates it from `main` by default:

```bash
scripts/worktree-add.sh codex/my-task-20260606 main
```

Then resume the agent session from the worktree path:

```bash
cd .worktrees/my-task-20260606
codex
```

or:

```bash
cd .worktrees/my-task-20260606
claude
```

## Audit Worktrees

Run:

```bash
scripts/worktree-audit.sh
```

The audit reports every linked worktree, its branch, dirtiness, and whether it
is inside the project-local `.worktrees/` directory. Any non-main linked
worktree outside `.worktrees/` is a policy violation.

## Move An Existing Worktree

Do not move a worktree with `mv`. Use Git so `.git/worktrees` metadata stays
valid:

```bash
git worktree move <old-path> .worktrees/<short-name>
```

Only move a worktree after its owner confirms no agent or build is currently
running inside it.

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

## Do Not

- Do not commit `.worktrees/` contents or gitlink placeholders.
- Do not raw-merge a branch just because its worktree is clean.
- Do not delete a dirty worktree without owner approval.
- Do not move a worktree manually with `mv`.
- Do not keep stale completed worktrees around after their code has landed.
