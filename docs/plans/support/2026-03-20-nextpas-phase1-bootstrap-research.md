# nextPas 第一阶段自举调研记录

- 关联计划：`docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md`
- 目的：汇总访谈结论、仓库勘察结果，以及塑造第一阶段自举
  计划的早期技术决策

## 已确认的需求

- 项目目标是把 FreePascal 重塑为一个更现代、更模块化、更易维护的
  Pascal 工具链与运行时生态。
- nextPas 是一个与 FreePascal 兼容的现代化重构项目，不是一个引入新语法的
  语言分叉。
- 第一阶段必须坚持文档优先和验证优先，在更深层实现开始前先把架构、
  兼容性边界和自举规则定清。
- 第一阶段范围仅限 Linux x86_64。
- `stage0` 使用 FreePascal 完成自举。
- 第一阶段必须把源码兼容、语义兼容、unit/module 行为，以及 RTL/CRT
  行为都视为一等规划关注点。

## 已确认的技术决策

- 第一批交付物是架构文档和兼容性文档，而不是直接进入编译器或 RTL 实现。
- ABI 与二进制兼容被明确延后，不是第一阶段硬目标。
- 第一阶段没有新语法计划。
- 项目应保留 FreePascal 可识别的外部生态边界，同时对内部结构做现代化重组。
- 由于上游 `packages/` 树过于宽广，包兼容必须按分层方式推进，不能在第一阶段
  一次性整体承诺。
- 验证规则和负向 grep 模式本身就是这些文档的实际接口，因此措辞必须与
  检查命令兼容。

## 仓库与环境发现

- 当前工作区不是 Git 仓库，因此规划上下文只能从磁盘上的既有记录恢复，而不能
  依赖 VCS 历史。
- 仓库最初几乎为空，只有隐藏的计划工件，之后才逐步加入架构文档。
- 第一批可执行工作是第一波次文档集合，因为后续的 `stage0` 和 `harness` 工作
  都依赖这些基线文档先写清楚。
- 当前已完成的文档有：
  - `docs/adr/0001-fpc-reference-baseline.md`
  - `docs/architecture/documentation-baseline-specification.md`
  - `docs/architecture/overview.md`
  - `docs/architecture/compatibility-matrix.md`
  - `docs/architecture/directory-structure-specification.md`
  - `docs/architecture/bootstrap-roadmap.md`
  - `docs/architecture/compiler-specification.md`
  - `docs/architecture/rtl-specification.md`
  - `docs/architecture/crt-specification.md`
  - `docs/architecture/distribution-layout-specification.md`
  - `docs/architecture/test-harness-specification.md`
  - `docs/architecture/stage0-driver-specification.md`
  - `docs/architecture/target-platform-specification.md`

## 上游参考结论

- `/home/dtamade/freepascal/fpcsrc/README.md` 确认了 FPC 的顶层边界：
  `compiler`、`rtl`、`packages`、`utils`、`tests`。
- `/home/dtamade/freepascal/fpcsrc/rtl/README.txt` 说明 RTL 围绕可安装 unit
  以及平台相关的底层例程组织。
- `/home/dtamade/freepascal/fpcsrc/tests/readme.txt` 说明测试套件会明确区分
  `compile-pass`、`compile-fail`、运行执行、辅助 unit，以及驱动/测试环境。
- `/home/dtamade/freepascal/fpcsrc/compiler/pp.pas` 明确表明目标平台选择和
  编译器驱动行为都是一等关注点。
- `/home/dtamade/freepascal/fpcsrc/packages` 非常宽且异构，因此 packages 的
  兼容性叙事必须分阶段推进。

## 风险与护栏

- 主要架构风险不是语法设计，而是兼容边界、自举路线和
  编译器到运行时边界说明是否模糊。
- 主要执行风险是范围膨胀，在基线稳定之前过早扩展到包管理器、
  IDE 支持、LSP 或多平台野心。
- 计划中不能把 ABI 兼容、Delphi 兼容或同步多平台首发悄悄提升为第一阶段
  硬目标。

## 参考资料

- FPC 源码树：`/home/dtamade/freepascal/fpcsrc`
- FPC 编译器入口：`/home/dtamade/freepascal/fpcsrc/compiler/pp.pas`
- FPC RTL 说明：`/home/dtamade/freepascal/fpcsrc/rtl/README.txt`
- FPC 测试套件说明：`/home/dtamade/freepascal/fpcsrc/tests/readme.txt`
- FPC utilities 说明：`/home/dtamade/freepascal/fpcsrc/utils/README.txt`
- 编译器语义测试示例：
  `/home/dtamade/projects/castle-engine/tests/code/testcases/testcompiler.pas`
- RTL 行为测试示例：
  `/home/dtamade/projects/castle-engine/tests/code/testcases/testsysutils.pas`
