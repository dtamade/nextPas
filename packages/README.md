# nextPas packages/

`packages/` 保留 nextPas 的显式生态边界，但第一阶段不会把它写成“立刻整体移植 FPC
包树”的承诺。这里首先要冻结的是进入条件、分层规则和验证关系。

如果你要看稳定边界，读 `docs/architecture/packages-specification.md`。如果你要看
当前推进波次和候选包族，读 `docs/plans/2026-03-21-nextpas-phase1-packages-plan.md`。
如果你要看 future GUI stack 为什么不走 LCL 路线，继续读
`docs/architecture/gui-framework-specification.md`。
如果你要看 package refs、source roots、target selection 和 artifact roots 怎样先收成
统一 workspace truth，继续读 `docs/architecture/workspace-specification.md`。
如果你要看 manifest、lock、repository/registry/source/mirror、install root 和 `pkg`
workflow 怎样被正式冻结，继续读
`docs/architecture/package-workflow-specification.md`。
如果你要看 future IDE 怎样和 package/workspace surface 共用同一套 truth，继续读
`docs/architecture/ide-specification.md`。

## 第一阶段如何理解这个目录

- 第 0 层核心基线继续由 `compiler/`、`rtl/`、`crt/`、`tests/`、`tools/` 和 `build/`
  支撑，不重新包装成包兼容工作。
- 第 1 层只接受直接服务 `stage0`、`harness`、smoke 样例或迁移证据的精选包类别。
- 第 2 层更广的 FPC 包生态继续延后，只有在前两层稳定后才允许推进。

## 这里必须和谁对齐

- `build/`：只消费单一 `linux-x86_64` 目标事实，不私自维护第二套平台矩阵
- `tests/`：优先复用 `harness`、smoke、regression 和现有测试桶，不把
  `tests/packages/` 设成前提
- 发行布局：安装结果继续服从 `units/<target>/` 和 `share/` 的公开语义
- `rtl/` / `crt/`：包只能建立在已文档化的运行时边界之上

## 这里现在不做什么

- 不承诺完整 FPC `packages/` 覆盖面。
- 不把包管理器、依赖解析器、IDE 或 LSP 混入这个目录。
- 不为了个别包去反向改写 `compiler/`、`rtl/`、`crt/` 或目标平台事实。
