# Task Plan: config startup example focused smoke

## Goal

把 `examples/nextpas.core.config/config_startup_patterns` 纳入 `tests/nextpas.core.config`
下的 focused smoke 自动化，确保 Phase 3 的 startup usage patterns 不只停留在文档和人工
`make run`，而是有可重复的回归入口。

## Current Phase

Phase 3 文档/示例收敛后的自动化补强：当前 `README` 和 runnable example 已经进主线，本轮只新增
focused smoke suite，不扩张 config API，不重开 Phase 3D2 设计。

## Active Batch Checklist

- [x] 检查共享 `main`、worktree 和分支状态，确认只在隔离 worktree 内工作。
- [x] 读取 `docs/design-conventions.md`、`docs/plans/2026-06-01-config-phase3.md`、现有 config
  example / tests / helper 模式。
- [x] 确认 `codex/config-phase3-example-main-20260603` worktree clean，且 `HEAD=fbd37d60` 与当前
  `main` 一致。
- [x] 重置本地 planning files，避免继续沿用无关 HTTP 计划。
- [x] 新增 `tests/nextpas.core.config/test_config_examples` Makefile 和 suite。
- [x] 第一遍运行新 suite，记录它是 RED 还是直接 GREEN。
- [x] 如有失败，最小化修正测试 harness，直到 focused GREEN。
- [x] 回归三组既有 config suite，并确认 heaptrc 0 泄漏。
- [x] 运行 `git diff --check`，审查变更面，只提交本轮 config 文件。
- [ ] 提交 feature worktree，并安全 fast-forward 合回 `main`。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只做 config example smoke 自动化，不引入 `WithInterpolation`、borrowed view、raw required 或模块拆分。 |
| Test gate | 新增 suite 必须覆盖 example 成功执行、关键输出标记、退出码。 |
| Leak gate | changed-surface focused suites 与既有 config suites 运行后都要给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 不触碰共享 checkout 中无关脏改动；所有开发、提交、合并都在 worktree 流程内完成。 |
| Reporting | 轮末报告必须包含验证证据、复盘、下一步和 commit 信息。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 复用 `codex/config-phase3-example-main-20260603` | 该 worktree 已隔离、clean、且基于当前 `main`，风险最低。 |
| 新增独立 `test_config_examples` suite | 与 `test_config_phase3` 的 builder/source API 断言解耦，单独守 startup example 行为。 |
| 用 `TProcess` 跑 example 的 `make run` | 可以同时覆盖 example 的构建、运行目录与输出标记，最接近真实用法。 |
| 用 core-root 自动探测而非硬编码单一路径 | 让 suite 在 test 目录、repo root 或 build 输出目录启动时都能解析到 example 路径。 |
| 若首跑直接通过，如实记为 coverage expansion | 当前目标是自动化收口，不虚构生产 bugfix。 |
| 一并提交 planning files | 这三份文件在仓库中已被跟踪，本轮记录如果不落盘，worktree 会残留脏状态且执行上下文会回退到旧 HTTP 批次。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 初次读取 worktree 时停在仓库根路径，example/test 相对路径不对 | 1 | 切回 `.../config-phase3-example-main-20260603/core` 作为实际工作目录。 |
| `core/task_plan.md` 等文件仍是旧 HTTP 批次内容 | 1 | 直接替换为当前 config smoke batch 计划，避免后续记录串线。 |
