# Task Plan: Exception Root Convergence

## Goal

将 nextpas.core 异常体系收敛到一个正式框架根，同时保留兼容层，第一阶段只处理最危险的 `ETimeoutError` 和 out-of-memory 分裂。

## Roadmap Position

- 项目目标树：`G0` 质量纪律 + Core L0 `base/errors/mem` 架构治理。
- 当前不推进 HTTP performance 路线。
- 当前不触碰 compiler 工作。

## Worktree

- Path: `/home/dtamade/.config/superpowers/worktrees/nextPas/exception-root-20260605`
- Branch: `codex/exception-root-20260605`
- Base commit: `5c28a959b5fd5065d1de98c93f9089d60bf80de1`
- Shared `main` remains dirty and untouched.

## Checklist

- [x] 建隔离 worktree，避免污染共享 `main`。
- [x] baseline: `make -C tests/nextpas.core.errors/test_errors clean test` 通过，heaptrc 0 泄漏。
- [x] 写设计文档：`docs/plans/2026-06-05-exception-root-convergence-design.md`。
- [x] 写实施计划：`docs/plans/2026-06-05-exception-root-convergence-plan.md`。
- [x] RED: 新增 unified root focused test 并确认失败原因正确。
- [x] GREEN: 新增 `nextpas.core.exception`。
- [x] GREEN: rewiring `base` / `errors`，消除 `ETimeoutError` 双定义。
- [x] GREEN: rewiring `mem.error`，收敛 OOM 主语义。
- [x] `/codex` 子代理复核：确认 OOM canonical 优先，修正 `ECore` 为统一根 alias。
- [x] Focused verification: exception/errors/http-server gates + heaptrc。
- [x] 更新 findings/progress。
- [ ] 提交分支。
- [ ] 只在共享 `main` 干净或获得确认后再考虑合并。

## Scope

允许修改：

- `src/nextpas.core.exception.pas`
- `src/nextpas.core.base.pas`
- `src/nextpas.core.errors.pas`
- `src/nextpas.core.mem.error.pas`
- `tests/nextpas.core.exception/test_exception_root/*`
- `tests/nextpas.core.errors/test_errors/test_errors.lpr`
- 必要时 `tests/nextpas.core.mem/test_exception_root/*`
- `docs/plans/2026-06-05-exception-root-convergence-design.md`
- `docs/plans/2026-06-05-exception-root-convergence-plan.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

禁止修改：

- compiler 任何文件。
- HTTP 行为、benchmark、parser、transport 逻辑。
- 共享 `main` 上 HTTP 同事的脏改。

## Verification Commands

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
make -C tests/nextpas.core.errors/test_errors clean test
make -C tests/nextpas.core.http/test_http_server clean test
git diff --check
git status --short --branch
```

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| `planning-with-files` first read used wrong skill path | 1 | Re-read from `/home/dtamade/.codex/skills/planning-with-files/SKILL.md`. |
| Relative `apply_patch` wrote RED test into shared `main` checkout | 1 | Deleted the two files I created there, verified shared `main` no longer reports `tests/nextpas.core.exception`, then recreated the files with absolute worktree paths. |
| RED focused test failed because `nextpas.core.exception` is missing | 1 | Expected TDD failure; proceed to add the canonical root unit. |
| Added `ECore` catch coverage failed with `Class or Object types "ECore" and "EOutOfMemoryError" are not related` | 1 | Correct RED proof that `ECore` must be a compatibility alias of `ENextPasError`, not a sibling subclass. |
