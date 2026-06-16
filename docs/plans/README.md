# 计划文档

`docs/plans/` 用于存放正式项目计划，包括主计划和可执行级实施计划。
`docs/plans/support/` 用于存放帮助这些计划执行、审计和回溯的支撑说明。

如果你要判断第一阶段文档的分层和权威顺序，先读
`docs/architecture/documentation-baseline-specification.md`。

## 目录分工保持简单

- `docs/plans/`：正式计划，包括主计划和实施计划
- `docs/plans/support/`：支撑某个计划的历史调研记录与进度日志
- `docs/adr/`：已接受的架构决策
- `docs/architecture/`：稳定的架构与兼容性文档
- `.sisyphus/evidence/`：原始验证输出和命令证据

## 统一命名规则

所有计划文件统一使用以下格式：

`YYYY-MM-DD-<project>-<scope>-<kind>.md`

允许的 `kind`：

- `plan`
- `research`
- `progress`

示例：

- `2026-03-20-nextpas-phase1-bootstrap-plan.md`
- `2026-03-20-nextpas-phase1-implementation-plan.md`
- `2026-03-20-nextpas-phase1-bootstrap-research.md`
- `2026-03-20-nextpas-phase1-bootstrap-progress.md`

## 何时新建，何时更新

- 当同一范围仍在继续推进时，更新现有的 `...-plan.md`
- 只有当范围发生实质变化时，才新建新的 `...-plan.md`
- 支撑性的调研发现放在 `...-research.md`
- 执行历史与验证检查点放在 `...-progress.md`

## 当前主线入口

- 文档基线与分层规则：
  `docs/architecture/documentation-baseline-specification.md`
- 已接受的兼容性基线决策：
  `docs/adr/0001-fpc-reference-baseline.md`
- 架构目录入口：
  `docs/architecture/README.md`
- 产品主路线图：
  `docs/architecture/master-roadmap.md`
- 编译器主路线图：
  `docs/architecture/compiler-roadmap.md`
- 自举路线图：
  `docs/architecture/bootstrap-roadmap.md`
- 当前活动主计划：
  `docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`
  其中已经包含“用编译器路线图看当前批次”的正式映射表。
- 当前接手治理计划：
  `docs/plans/2026-06-15-nextpas-workmap-takeover-plan.md`
  负责新接手 AI 的工作地图、治理债清理与并行 lane 推进顺序。
- packages 推进计划：
  `docs/plans/2026-03-21-nextpas-phase1-packages-plan.md`
- 迭代推进工作模式：
  `docs/plans/2026-03-24-nextpas-iteration-mode-plan.md`
- 已完成的 phase1 主计划：
  `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
- 已完成的 phase1 实施计划：
  `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
- packages 调研记录：
  `docs/plans/support/2026-03-21-nextpas-phase1-packages-research.md`
- 历史调研记录：
  `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`
- 历史进度日志：
  `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`
