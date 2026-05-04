# nextPas packages 规范

用这份规范定义 nextPas 第一阶段 `packages/` 的稳定边界。它回答的不是“现在先移植哪些包”，
而是“包兼容如何在不吞掉核心基线的前提下进入范围、如何分层推进，以及它必须和现有
`build`、`tests`、发行布局规则如何对齐”。

## 把 `packages/` 保留成显式生态边界，而不是模糊的“以后再说”

nextPas 保留 `packages/`，是为了延续 FreePascal 生态里可识别的包兼容边界；不是为了把
所有尚未归属的辅助代码都塞进去，也不是为了在第一阶段默认承诺整个 FPC 包树。

`/home/dtamade/projects/fpc/packages` 已经说明，上游 `packages/` 树同时包含网络、
图形、数据库、并发、平台专用单元和各类示例/测试资产。第一阶段如果不先把 `packages/`
的进入条件和范围护栏写清，后续就会把“保留顶层边界”误解成“立刻整体移植”。

因此，`packages/` 在第一阶段的首要职责不是扩大交付面，而是把包兼容的推进顺序写清楚，
让项目能够在 Linux x86_64 上按证据扩展，而不是按想象扩展。

## future GUI stack 不是 LCL 迁移任务

nextPas 既然要成为整套开发环境，就不能默认把 future GUI story 理解成“以后把 LCL 搬过来”。

这里先冻结一个长期方向：

- nextPas 会有自己的 Pascal GUI 体系
- 这套 GUI 体系要走硬件加速 UI framework 路线
- 它属于 nextPas 自己的 runtime / packages / toolchain 生态，而不是 LCL compatibility layer

因此，后续如果出现 GUI 相关 package、runtime service 或 tooling surface，它们的目标也不该是
把 LCL 原样包进 nextPas，而应该是围绕新的 UI stack 建模。
更细的 GUI 主骨架边界由 `gui-framework-specification.md` 定义。
更细的 host window、screen/monitor、clipboard/DnD 与 native surface 接缝由
`platform-shell-specification.md` 定义。
更细的 package/workspace 协同边界由 `workspace-specification.md` 定义。
更细的 package manager workflow、manifest/lock/install 边界由
`package-workflow-specification.md` 定义。
更细的 IDE workbench 边界由 `ide-specification.md` 定义。

## 包兼容必须继续服从核心基线，而不是反过来支配它

第一阶段中，`packages/` 永远处在 `compiler/`、`rtl/`、`crt/`、`diagnostics`、
`stage0` 和 `harness` 基线之后：

- `compiler`、`rtl` 和 `crt` 先冻结硬边界，`packages/` 只能消费这些边界，不能反向改写
  语言、运行时或目标平台事实。
- `packages/` 不负责定义新的目标矩阵；它只能运行在已声明的 Linux x86_64 目标之上。
- 包兼容的推进不能绕过 `stage0` 路径和验证证据。没有可重复验证的包，不属于第一阶段
  的有效承诺。

这条顺序的目的，是防止“为了迁就某个包”而把 core baseline 重新写回模糊接口。

## 用三层规则冻结推进边界，而不是提前冻结包清单

第一阶段继续沿用兼容性矩阵里的三层语义，但把它写成 `packages/` 的明确推进规则：

| 分层    | 第一阶段含义                                                                | 进入条件                                                         | 不做什么                                                |
| ------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| 第 0 层 | 核心基线，由 `compiler`、`rtl`、`crt`、`tests`、`tools` 和 `build` 共同支撑 | 已经属于 phase1 硬目标与现有 smoke/验证路径                      | 不把核心 unit、运行时服务或控制面重新包装成“包兼容”工作 |
| 第 1 层 | 直接支撑 `stage0`、验证路径或分阶段迁移的精选包类别                         | 必须存在明确的 Linux x86_64 使用场景、验证入口和可解释的依赖理由 | 不因为“以后可能会用”就提前纳入                          |
| 第 2 层 | 更广的 FPC 包生态兼容                                                       | 只能在第 0 层和第 1 层稳定后，再按证据逐步扩展                   | 不在第一阶段写成默认完成项                              |

这意味着第一阶段先冻结规则，不冻结名单。某个包想进入第 1 层，至少要同时满足：

- 它直接服务 `stage0`、`harness`、smoke 样例或分阶段迁移证据。
- 它的目标平台假设能完全落在 Linux x86_64 与现有发行布局之内。
- 它可以接入可重复的测试或证据路径，而不是只停留在“未来可能需要”。

如果这些条件说不清，就继续留在延后范围，而不是抢先变成正式交付物。

## `packages/` 必须和 `build`、`tests`、发行布局一起工作

`packages/` 不是孤立目录，它必须继续受现有控制层约束：

| 相邻边界         | `packages/` 必须保持的关系                                                                                        |
| ---------------- | ----------------------------------------------------------------------------------------------------------------- |
| `build/`         | 继续使用单一 `linux-x86_64` 目标事实，不私自维护第二套平台矩阵                                                    |
| `tests/`         | 包兼容验证先复用现有 `harness`、smoke、regression 与证据路径；第一阶段不要求先定义单独的 `tests/packages/` 测试桶 |
| 发行布局         | 已安装的包相关 units 继续服从 `units/<target>/` 语义，共享文档和样例继续归入 `share/`                             |
| `rtl/` 与 `crt/` | 包只能建立在已文档化的运行时边界之上，不能把核心 RTL/CRT 约束重新藏回包内部                                       |

这也是为什么 `packages/` 规范是一份边界说明，而不是一份脱离 `build`、`tests` 和
发行布局的独立愿景稿。
更细的 package resolution、install root 和 `pkg` family workflow 由
`package-workflow-specification.md` 定义。

## 先把 `packages` 写成受控扩展门，而不是新的路线图入口

第一阶段只要求项目把 `packages/` 的进入条件和分层逻辑说清。它不要求现在就给出一份
固定的包族清单，也不要求把后续推进波次提前写死。

这样做不是保守，而是为了保持文档诚实：当上游 `packages/` 树本身就很宽、很异构时，
先冻结筛选规则，比先写一串可能很快失效的包名单更有约束力。

如果后续真的需要给出首批候选包族、推进波次或更细的验证策略，应另行进入新的计划或
路线图文档，而不是把这份稳定规范写成半份实施计划。

## 第一阶段非目标

- 不承诺完整 FPC `packages/` 覆盖面。
- 不在这份规范里点名默认首批包清单或固定迁移波次。
- 不引入包管理器、依赖解析器、IDE 集成或 LSP 语义。
- 不为 `packages/` 单独发明多平台矩阵或第二套目标平台事实。
- 不把包级二进制稳定性写成当前承诺，`ABI compatibility is deferred`。

第一阶段要得到的是“清楚、可验证、可延后”的包兼容边界，而不是一个看起来完整、
实际上无法收口的 package universe 计划。
