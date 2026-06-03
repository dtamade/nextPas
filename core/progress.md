# Progress Log: process PATH resolution contract and child wait warning batch 11

## Session

- **Scope:** 收紧 `process` 的 PATH 搜索 contract，并清掉 `TChild.Wait` warning。
- **Status:** in_progress

## Baseline audit

- 读过 `docs/design-conventions.md`、现有 `docs/plans/2026-05-31-process-final-polish.md`、
  `task_plan.md` / `findings.md` / `progress.md`，确认需要切换控制文件到 `process` 当前批次。
- 核对 `git status --short --branch`：
  仓库有多处非本模块脏改动，本轮只允许 path-limited 修改与提交。
- 发现 `tests/nextpas.core.platform.process/test_platform_process/test_platform_process.lpr`
  已新增 duplicate `EnvAdd('PATH', ...)` final-view case，但这个 contract 更适合沉到
  高层 `process` suite 固化。

## Fresh baseline verification

- `make -C tests/nextpas.core.platform.process/test_platform_process test`
  - `13/13 passed`
  - heaptrc: `0 unfreed memory blocks`
  - 但编译阶段有 warning：
    `nextpas.core.process.child.pas(143,18) Warning: Function result variable of a managed type does not seem to be initialized`
- `make -C tests/nextpas.core.process/test_process test`
  - `49 passed, 0 failed`
  - 当前输出未见 leak

## Next execution slice

- 先在 `test_process` 写一个真正的 RED：
  PATH 前置同名不可执行文件时，仍应继续解析到后续可执行目标。
- 同批把 duplicate `EnvAdd('PATH', ...)` final-view 行为放入高层 `process` suite。
- 然后最小修改 `pathresolve` 与 `TChild.Wait`，再回跑 focused tests。
