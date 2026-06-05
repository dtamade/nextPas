# Historical Task Plan: Exception Root Convergence

## Goal

将 nextpas.core 异常体系收敛到一个正式框架根，同时保留兼容层。第一阶段先处理最危险的 `ETimeoutError` 和 out-of-memory 分裂；本轮 Stage 1B 继续把已发现的生产 OOM 产生点和 TUI 模块根迁到正式根语义。

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
- [x] 提交分支：`f198fc86 refactor(errors): introduce unified framework exception root`。
- [x] 只在共享 `main` 干净或获得确认后再考虑合并；本轮未合并。
- [x] Stage 1B RED/GREEN: `TVec.Reserve/ReserveExact` 失败路径从旧 `ECore` 迁到 canonical OOM。
- [x] Stage 1B RED/GREEN: mem 模块 `aeOutOfMemory` 抛出点收敛到 `EOutOfMemoryError` 主语义。
- [x] Stage 1B: `nextpas.core.tui.error.ETui` 从 `ECore` 兼容层迁到正式根 `ENextPasError`。
- [x] Stage 1B focused verification: exception/errors/base/collections/mem/tui/http-server gates + heaptrc。
- [x] Stage 1B 提交分支：`refactor(errors): migrate remaining oom and tui root seams`。
- [x] 合并前重新 merge 当前 `main` 并完成 post-merge focused verification。
- [x] 合并安全审查：异常分支改动与共享 `main` 未提交/未跟踪文件无路径交集，且可 fast-forward。
- [x] 合并前 reviewer 复盘：无阻塞合并问题。
- [x] 在共享 `main` 可 fast-forward 且无路径交集时执行合并。

## Scope

允许修改：

- `src/nextpas.core.exception.pas`
- `src/nextpas.core.base.pas`
- `src/nextpas.core.errors.pas`
- `src/nextpas.core.mem.error.pas`
- `src/nextpas.core.collections.vec.pas`
- `src/nextpas.core.mem.blockpool.pas`
- `src/nextpas.core.mem.blockpool.growable.pas`
- `src/nextpas.core.mem.arena.growable.pas`
- `src/nextpas.core.mem.pool.fixed.pas`
- `src/nextpas.core.mem.pool.fixed.growable.pas`
- `src/nextpas.core.mem.ring_buffer.pas`
- `src/nextpas.core.mem.stack_pool.pas`
- `src/nextpas.core.tui.error.pas`
- `tests/nextpas.core.exception/test_exception_root/*`
- `tests/nextpas.core.errors/test_errors/test_errors.lpr`
- `tests/nextpas.core.collections/test_vec/test_vec.lpr`
- `tests/nextpas.core.mem/test_oom/*`
- `tests/nextpas.core.tui/test_tui_error/test_tui_error.lpr`
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
make -C tests/nextpas.core.base/test_base clean test
make -C tests/nextpas.core.collections/test_vec clean test
make -C tests/nextpas.core.mem/test_oom clean test
make -C tests/nextpas.core.mem/test_mem clean test
make -C tests/nextpas.core.mem/test_arena clean test
make -C tests/nextpas.core.mem/test_arena_class clean test
make -C tests/nextpas.core.mem/test_pool clean test
make -C tests/nextpas.core.mem/test_blockpool clean test
make -C tests/nextpas.core.mem/test_contracts clean test
make -C tests/nextpas.core.tui/test_tui_error clean test
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
| Unsafe `TVec.Reserve(SizeUInt(-1))` RED test could attempt a huge allocation | 1 | Replaced with `FCount + aAdditional` overflow after one `Push`, so failure is deterministic and allocation-free. |
| `TGrowthStrategy.GetGrowSize` clamps custom no-grow results to required size | 1 | Stopped using no-grow to trigger `Reserve`; used add-overflow instead. |
