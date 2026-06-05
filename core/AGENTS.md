# nextpas.core Agent Rules

本文件适用于 `core/` 下的所有 nextpas.core 工作。仓库根目录 `AGENTS.md` 仍然适用；
本文件只补充 core 专属入口、设计规范和验证纪律。

## Read First

- `docs/design-conventions.md` 是 nextpas.core 的设计风格、模块范式、分层约束、测试布局和代码组织权威文件。
- `README.md` 是 core 子项目导航，不替代设计规范。
- 模块专题文档在 `docs/<module>/` 或 `docs/nextpas.core.<module>*.md`。
- 活动计划在 `docs/plans/`。不要把临时 `task_plan.md`、`findings.md`、`progress.md` 直接带入主线，除非总控明确要求。
- worktree/lane 规则以仓库根目录 `docs/worktrees.md` 为准。

开始任何 core 代码、测试、示例或 benchmark 改动前，先读 `docs/design-conventions.md`
和对应模块文档。

## Start Every Session

Run:

```bash
git status --short --branch
REPO_ROOT="$(git rev-parse --show-toplevel)"
"$REPO_ROOT/scripts/worktree-audit.sh"
make -C "$REPO_ROOT" hygiene
```

## Module Scope

- A module lane should touch only its owned module paths unless the task explicitly requires cross-module work.
- Typical module paths are `src/nextpas.core.<module>*`, `tests/nextpas.core.<module>/`,
  `examples/nextpas.core.<module>/`, `benchmarks/nextpas.core.<module>/`, and the matching `docs/` paths.
- Cross-module changes must be called out in the report with the reason, risk, and verification impact.
- Do not bypass layer rules from `docs/design-conventions.md`.

## Verification

- Prefer focused module gates over broad sweeps.
- Use each focused project `Makefile`, for example:

```bash
make -C tests/nextpas.core.http/test_http_client clean test
```

- For exposed API or ownership changes, focused tests must cover the changed surface and leak-sensitive paths.
- Run `git diff --check` and `make -C "$(git rev-parse --show-toplevel)" hygiene`
  before reporting `Ready` or `Landed`.
- Do not claim full green if only focused gates ran. State exactly what passed and what remains unverified.

## Landing

- Do not raw-merge long-lived module lanes into `main`.
- `Ready` reports must include branch, worktree path, `HEAD`, changed files, files that must not land,
  focused verification evidence, and merge recommendation.
- Final mainline integration is owned by the controller unless explicitly delegated.
