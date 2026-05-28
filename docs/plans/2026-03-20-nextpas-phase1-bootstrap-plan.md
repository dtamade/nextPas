# nextPas 第一阶段自举主计划

- 状态：完成
- 日期：2026-03-20
- 范围：nextPas 现代化工程的第一阶段规划与执行基线

## 把这份文档当作活动主计划入口

这是 nextPas 第一阶段自举工作的活动主计划。它替代了旧的隐藏计划位置，并把详细任务图、
验收标准和验证规则统一到当前的计划入口里。

不过，这份文档只负责计划层的执行事实。稳定的平台、自举和架构边界仍然以
`docs/adr/` 与 `docs/architecture/` 为准，文档分层与裁决顺序见
`docs/architecture/documentation-baseline-specification.md`。

## 当前状态

- 任务 1-3 已完成并验证。
- 任务 4-5 已完成并验证。
- 任务 6 已完成并验证。
- 任务 7 已完成并验证。
- 任务 8 已完成并验证。
- 任务 9 已完成并验证。
- 任务 10 已完成并验证。
- 任务 11 已完成并验证。
- 任务 12 已完成并验证。
- `packages` 现已具备独立专题规范、推进计划和配套调研记录，作为后续 packages 工作入口，
  但不改变当前主线批次和任务编号。
- 可执行级配套计划现已存在于
  `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`.
- 最终验证波次 F1-F4 已执行，结果已写入 `.sisyphus/evidence/`。
- 用户已明确接受 phase1 收口结果，第一阶段现已正式完成。
- 后续工作不再回写这份主计划的任务状态，而是进入新的批次主线。
- 验证证据继续保存在 `.sisyphus/evidence/`。

## 相关文档

- 文档基线与裁决顺序：
  `docs/architecture/documentation-baseline-specification.md`
- 架构目录入口：
  `docs/architecture/README.md`
- 实施计划：
  `docs/plans/2026-03-20-nextpas-phase1-implementation-plan.md`
- packages 推进计划：
  `docs/plans/2026-03-21-nextpas-phase1-packages-plan.md`
- packages 调研记录：
  `docs/plans/support/2026-03-21-nextpas-phase1-packages-research.md`
- 调研记录：
  `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`
- 进度日志：
  `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md`
- 已冻结的兼容性基线：
  `docs/adr/0001-fpc-reference-baseline.md`
- 稳定架构规范集合：
  `docs/architecture/README.md`

## 摘要

> **摘要**：从空仓启动 nextPas，先交付一套文档优先、验证优先、以 FreePascal 为 `stage0` 的兼容性重构基线；目标不是发明新语法，而是在 Linux x86_64 上建立一个可持续迭代的现代 Pascal 工具体系，以及更现代的 Pascal RTL/CRT 基座。
> **交付物**：
>
> - 总体架构概览与兼容性基线文档
> - 自举路线图、目录结构规范、包兼容分层与其他专题规范文档
> - `tests` / `harness` / 基线快照 / CI 的首批基础设施
> - FreePascal 驱动的 `stage0` `nextpas` 最小纵切
> - 现代化 RTL/CRT 核心骨架、包兼容边界与发行布局约束
>   **工作量**：超大
>   **并行性**：可并行，共 4 个波次
>   **关键路径**：1 → 2 → 5 → 7 → 9 → 12

## 背景

### 原始请求

- 用户原始意图："我非常想重塑 freePascal 所以我建立了一个 nextPas 的项目. 从工具链到rtl 想做一个全新的 pascal 语言体系"

### 访谈摘要

- nextPas 被定义为 **FreePascal 全兼容重构项目**，不是新语法的新语言项目。
- 当前 **没有新语法计划**；兼容重点在源码级、语义级、RTL/CRT 行为级和 unit/module 组织。
- **ABI/二进制兼容不是第一阶段硬目标**，但必须在文档中被明确延后，而不是模糊处理。
- 第一阶段先交付 **总体架构概览** 与相关决策文档，再进入实现。
- stage0 使用 **FreePascal 自举**，逐步迭代到 nextPas 自有实现。
- 首发唯一平台锁定为 **Linux x86_64**。
- **验证基础设施必须首批建设**，不能等实现后补。

### Metis 复核（已补齐的缺口）

- 已补入“冻结 FPC 参考基线”的前置任务，避免执行中对齐目标漂移。
- 已补入“验证体系先行”的前置任务，避免兼容项目在缺少基准裁决时实现漂移。
- 已明确范围蔓延护栏：第一阶段不做新语法、不做 ABI 硬承诺、不做双平台并行、不做包管理器 / IDE / LSP 的提前实现。
- 已将“目录结构规范、兼容性矩阵、自举路线图、验证设计说明”拆成单独产物，避免总体文档过载。

## 工作目标

### 核心目标

在空仓 `nextPas` 中建立一个 **与 FPC 兼容、文档优先、验证优先** 的工程启动基线：先冻结参考标准与架构边界，再以 FreePascal 为 stage0 打通一个最小可验证的 `nextpas` 纵切，为后续编译器、现代化工具体系、现代化 RTL/CRT 与生态演进提供不歧义的起点。

### 交付物

- `docs/architecture/overview.md`
- `docs/architecture/compatibility-matrix.md`
- `docs/architecture/directory-structure-specification.md`
- `docs/architecture/bootstrap-roadmap.md`
- `docs/architecture/packages-specification.md`
- `docs/architecture/rtl-specification.md`
- `docs/architecture/crt-specification.md`
- `docs/architecture/distribution-layout-specification.md`
- `docs/architecture/test-harness-specification.md`
- `docs/architecture/stage0-driver-specification.md`
- `docs/architecture/target-platform-specification.md`
- `docs/adr/0001-fpc-reference-baseline.md`
- `compiler/`, `rtl/`, `packages/`, `tests/`, `tools/`, `build/` 初始目录与所有权说明/README
- `tests/harness/` 统一测试驱动、`tests/snapshots/` 基线快照、`tests/run_all_tests.sh`
- `tools/stage0/nextpas.pas` 最小命令行驱动入口
- Linux x86_64 的 CI 骨架与本地验证入口

### 完成定义（可通过命令验证）

- `test -f docs/architecture/overview.md`
- `test -f docs/architecture/compatibility-matrix.md`
- `test -f docs/architecture/directory-structure-specification.md`
- `test -f docs/architecture/bootstrap-roadmap.md`
- `test -f docs/architecture/packages-specification.md`
- `test -f docs/architecture/rtl-specification.md`
- `test -f docs/architecture/crt-specification.md`
- `test -f docs/architecture/distribution-layout-specification.md`
- `test -f docs/architecture/test-harness-specification.md`
- `test -f docs/architecture/stage0-driver-specification.md`
- `test -f docs/architecture/target-platform-specification.md`
- `test -f docs/adr/0001-fpc-reference-baseline.md`
- `test -d compiler && test -d rtl && test -d packages && test -d tests && test -d tools && test -d build`
- `test -x tests/run_all_tests.sh`
- `fpc tools/stage0/nextpas.pas`
- `./tests/run_all_tests.sh --filter smoke`
- `./build/verify_local.sh`
- `grep -n "Linux x86_64" docs/architecture/overview.md`
- `grep -n "ABI compatibility is deferred" docs/architecture/compatibility-matrix.md`
- `grep -n "CRT 行为" docs/architecture/compatibility-matrix.md`

### 必须具备

- 单一参考基线：以本地 `/home/dtamade/freepascal/fpcsrc` 为第一阶段兼容对照源。
- 单一平台：仅 Linux x86_64。
- 单一自举起点：FreePascal `stage0`。
- 文档、目录、验证、最小驱动同时成型。
- tests 必须拆分为 compiler-pass / compiler-fail / diagnostics / rtl / crt / regression。
- 第一阶段必须给出现代化工具体系与现代化 RTL/CRT 的明确边界，而不是只有编译器计划。

### 禁止事项（护栏、反 AI slop 模式、范围边界）

- 不引入任何新语法设计或语法扩展承诺。
- 不把 Delphi 兼容、双平台、ABI 兼容写成第一阶段硬目标。
- 不把包管理器、LSP、IDE、格式化工具或完整 packages 生态塞进首批实现。
- 不照搬 FPC `compiler/` 的历史平铺结构；必须采用现代子模块边界。
- 不允许“先写代码、以后再补兼容性矩阵 / tests”的执行顺序。

## 验证策略

> 零人工介入：所有验证都必须由代理自行执行。

- 测试决策：在 `harness` 存在后，对可执行任务采用 TDD；对文档或结构任务采用命令级断言验证。框架为 `shell harness + 与 FPCUnit 兼容的 runner + 基线快照`。
- QA 策略：每个任务都必须带显式的成功路径与失败/边界场景。
- 证据：`.sisyphus/evidence/task-{N}-{slug}.{ext}`

## 执行策略

### 并行执行波次

> 目标：每个波次 5-8 个任务。除最终波次外，少于 3 个任务说明拆分不足。
> 尽量把共享依赖前移到波次 1，以最大化并行度。

波次 1：冻结参考基线、总体架构概览、兼容性矩阵、目录结构规范、自举路线图
波次 2：仓库脚手架、验证 harness、测试桶
波次 3：`stage0` 命令行驱动入口、目标平台配置模型、RTL/CRT 规范、CI/本地验证与发行布局语义
波次 4：docs/code 对齐收口、示例程序路径、兼容性证据刷新

### 依赖矩阵（全部任务）

| 任务 | 依赖        |
| ---- | ----------- |
| 1    | —           |
| 2    | 1           |
| 3    | 1           |
| 4    | 1           |
| 5    | 1,2,3,4     |
| 6    | 2,4         |
| 7    | 3,5,6       |
| 8    | 6,7         |
| 9    | 5,6         |
| 10   | 5,9         |
| 11   | 3,5,6       |
| 12   | 7,8,9,10,11 |

### 代理分发摘要（波次 → 任务数 → 类别）

- 波次 1 → 5 个任务 → `writing` / `deep`
- 波次 2 → 3 个任务 → `unspecified-high` / `deep`
- 波次 3 → 4 个任务 → `unspecified-high` / `deep`
- 波次 4 → 0 个直接任务；保留给 F1-F4 之前的最终验证对齐

## TODO 列表

> 实现与测试视为同一个任务，绝不拆开。
> 每个任务都必须包含：代理画像、并行信息与 QA 场景。

<!-- TASKS_INSERT_HERE -->

- [x] 9. 实现 `stage0` `nextpas` 命令行驱动入口

  **要做什么**：创建 `tools/stage0/nextpas.pas` 和 `tools/stage0/README.md`，作为最小可用的 `stage0` 工具入口。它只支持一条明确的成功路径命令：在 Linux x86_64 上通过 FreePascal 托管执行 `nextpas build <source>`。同时补齐清晰的使用说明、确定性的退出码，以及适合留证的 `stderr` 消息。再新增 `examples/smoke/hello.pas` 作为标准 smoke 输入。
  **禁止事项**：不要加入包管理、格式化工具、IDE 挂钩或跨平台 flags；也不要把未来不稳定命令提前暴露为公开命令行接口。

  **推荐执行代理画像：**
  - 类别：`unspecified-high`
  - 原因：同时涉及 Pascal 实现、命令行接口设计和第一阶段范围纪律。
  - 技能：[`tdd-guide`]，用 smoke tests 固化命令行行为。
  - 省略：[`frontend-design`]，不涉及 UI。

  **并行信息：** 可并行：是 | 波次 3 | 会阻塞：[10,12] | 受阻于：[5,6]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`docs/architecture/bootstrap-roadmap.md`，用于确认 `stage0` 范围和晋级门槛。
  - 参考：`docs/architecture/overview.md`，用于确认工具链边界与第一阶段非目标。
  - 参考：`docs/architecture/stage0-driver-specification.md`，用于对齐公开命令、退出行为与范围边界。
  - 参考：`/home/dtamade/freepascal/fpcsrc/compiler/pp.pas`，作为历史 compiler driver 的参照。
  - 参考：`tests/compiler/pass/`，这里的 smoke 样例必须能够被该命令行入口构建。

  **验收标准（仅限代理可执行）：**
  - [x] `test -f tools/stage0/nextpas.pas`
  - [x] `test -f tools/stage0/README.md`
  - [x] `test -f examples/smoke/hello.pas`
  - [x] `fpc tools/stage0/nextpas.pas`
  - [x] `./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：`stage0` 驱动入口构建并编译 smoke 示例
    工具：Bash
    步骤：运行 `fpc tools/stage0/nextpas.pas && ./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64 | tee .sisyphus/evidence/task-9-stage0-driver.txt`
    预期：`stage0` 驱动入口能成功编译，并报告 smoke build 成功。
    证据：`.sisyphus/evidence/task-9-stage0-driver.txt`

  场景：未知命令能被干净拒绝
    工具：Bash
    步骤：运行 `! ./tools/stage0/nextpas frobnicate examples/smoke/hello.pas > .sisyphus/evidence/task-9-stage0-driver-error.txt 2>&1`
    预期：命令以非零状态退出，并打印清晰的 unsupported-command 提示。
    证据：`.sisyphus/evidence/task-9-stage0-driver-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`feat(stage0): add nextpas build driver` | 文件：[`tools/stage0/nextpas.pas`, `tools/stage0/README.md`, `examples/smoke/hello.pas`]

- [x] 10. 外置 Linux x86_64 目标平台与工具链配置

  **要做什么**：创建 `build/targets/linux-x86_64.toml` 和 `tools/stage0/target_config.pas`，让 `stage0` 驱动入口读取单一且显式的目标平台规格，而不是把平台规则埋在代码里。配置中要写清宿主编译器路径、输出布局假设，以及仅服务于 Linux x86_64 的 FPC 调用选项。
  **禁止事项**：不要引入多目标矩阵；也不要为了“以后可能会用”而硬编码 Windows/macOS 占位配置。

  **推荐执行代理画像：**
  - 类别：`deep`
  - 原因：目标平台规格是现代工具链与临时 shell 拼接之间的关键边界。
  - 技能：[`docs-write`]，保证配置注释和文档可读；[`tdd-guide`]，用可执行检查驱动配置解析。
  - 省略：[`frontend-design`]，无关。

  **并行信息：** 可并行：是 | 波次 3 | 会阻塞：[12] | 受阻于：[5,9]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`docs/adr/0001-fpc-reference-baseline.md`，用于确认冻结的仅限 Linux x86_64 范围。
  - 参考：`docs/architecture/bootstrap-roadmap.md`，用于确认 `stage0` 的运行假设。
  - 参考：`docs/architecture/target-platform-specification.md`，用于对齐外置目标规格的职责与拒绝行为。
  - 参考：`/home/dtamade/freepascal/fpcsrc/compiler/pp.pas`，借鉴 `compiler` 选项与目标平台处理方式。
  - 参考：`tools/stage0/nextpas.pas`，即 任务 9 的命令行入口。

  **验收标准（仅限代理可执行）：**
  - [x] `test -f build/targets/linux-x86_64.toml`
  - [x] `test -f tools/stage0/target_config.pas`
  - [x] `grep -n "linux-x86_64" build/targets/linux-x86_64.toml`
  - [x] `./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64`
  - [x] `! ./tools/stage0/nextpas build examples/smoke/hello.pas --target windows-x86_64`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：目标平台配置驱动受支持的构建路径
    工具：Bash
    步骤：运行 `grep -n "linux-x86_64" build/targets/linux-x86_64.toml && ./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64 > .sisyphus/evidence/task-10-target-config.txt 2>&1`
    预期：配置文件明确写出唯一支持的目标平台，且构建能成功执行。
    证据：`.sisyphus/evidence/task-10-target-config.txt`

  场景：不支持的目标平台会被拒绝
    工具：Bash
    步骤：运行 `! ./tools/stage0/nextpas build examples/smoke/hello.pas --target windows-x86_64 > .sisyphus/evidence/task-10-target-config-error.txt 2>&1`
    预期：命令以非零状态退出，并清晰报告 unsupported target。
    证据：`.sisyphus/evidence/task-10-target-config-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`feat(targets): externalize linux x86_64 stage0 config` | 文件：[`build/targets/linux-x86_64.toml`, `tools/stage0/target_config.pas`]

- [x] 11. 定义现代 RTL/CRT 规范与骨架

  **要做什么**：对齐现有 `docs/architecture/rtl-specification.md` 和 `docs/architecture/crt-specification.md` 的运行时边界定义，然后补上 `rtl/core/README.md`、`rtl/core/system/README.md`、`rtl/crt/README.md`，以及为未来公开表面预留位置所需的最小占位文件。文档必须明确写清“第一阶段中的现代化 RTL/CRT 规范”到底意味着什么：该保留的 FPC 兼容行为、更清晰的模块所有权、核心运行时服务与 CRT/控制台关注点的显式分离，以及不提前承诺整体移植。
  **禁止事项**：第一阶段不要尝试整体移植 FPC RTL 或 CRT；也不要把 CRT 淹没在泛化 RTL 文本里。

  **推荐执行代理画像：**
  - 类别：`deep`
  - 原因：RTL/CRT 规范是跨模块、长期生效的架构边界。
  - 技能：[`feature-design-assistant`, `docs-write`]，既要把行为承诺写准，也要压住范围。
  - 省略：[`frontend-design`]，无关。

  **并行信息：** 可并行：是 | 波次 3 | 会阻塞：[12] | 受阻于：[3,5,6]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/freepascal/fpcsrc/rtl/README.txt`，用于了解官方 RTL 组织方式。
  - 参考：`docs/architecture/compatibility-matrix.md`，用于对齐 RTL/CRT 必须遵守的兼容承诺。
  - 参考：`docs/architecture/directory-structure-specification.md`，用于确认 `rtl/core` 与 `rtl/crt` 的保留位置。
  - 参考：`/home/dtamade/projects/castle-engine/tests/code/testcases/testsysutils.pas`，作为运行时行为断言示例。

  **验收标准（仅限代理可执行）：**
  - [x] `test -f docs/architecture/rtl-specification.md`
  - [x] `test -f docs/architecture/crt-specification.md`
  - [x] `test -f rtl/core/README.md`
  - [x] `test -f rtl/core/system/README.md`
  - [x] `test -f rtl/core/system/system_placeholder.pas`
  - [x] `test -f rtl/crt/README.md`
  - [x] `test -f rtl/crt/crt_placeholder.pas`
  - [x] `grep -n "现代化" docs/architecture/rtl-specification.md`
  - [x] `grep -n "控制台" docs/architecture/crt-specification.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：RTL 与 CRT 规范明确分离
    工具：Bash
    步骤：运行 `grep -n "行为" docs/architecture/rtl-specification.md && grep -n "控制台" docs/architecture/crt-specification.md && test -f rtl/core/system/README.md && test -f rtl/crt/README.md`
    预期：RTL 与 CRT 分别有独立规范文档和骨架位置。
    证据：`.sisyphus/evidence/task-11-rtl-crt-contracts.txt`

  场景：第一阶段范围没有被夸大
    工具：Bash
    步骤：运行 `! grep -n "第一阶段完整 RTL 移植\|第一阶段完整 CRT 替换" docs/architecture/rtl-specification.md docs/architecture/crt-specification.md`
    预期：两份文档都不会提前承诺立即完成整体移植。
    证据：`.sisyphus/evidence/task-11-rtl-crt-contracts-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`docs(runtime): define nextpas rtl and crt specifications` | 文件：[`docs/architecture/rtl-specification.md`, `docs/architecture/crt-specification.md`, `rtl/core/README.md`, `rtl/core/system/README.md`, `rtl/crt/README.md`]

- [x] 12. 增加 Linux CI 与本地验证入口

  **要做什么**：创建 `.github/workflows/ci.yml`、`build/verify_local.sh` 和 `docs/architecture/distribution-layout-specification.md`。工作流与本地脚本都必须执行 docs 存在性检查、用 FPC 编译 `stage0` 驱动入口、运行 smoke `harness` 覆盖，并落实未来发行布局的语义约束（`bin/`、`lib/`、`units/<target>/`、`share/`），同时绝不能假装已经支持多平台。
  **禁止事项**：不要增加 Windows/macOS 矩阵任务；不要跳过 smoke `harness`；不要让安装布局保持隐式状态。

  **推荐执行代理画像：**
  - 类别：`unspecified-high`
  - 原因：这个任务把文档、构建编排、CI 与发行布局约束绑在一起。
  - 技能：[`senior-devops`, `docs-write`]，建立稳妥的 Linux-only CI 路径，并把发行布局写清楚。
  - 省略：[`frontend-design`]，不涉及 UI。

  **并行信息：** 可并行：否 | 波次 3 | 会阻塞：[] | 受阻于：[7,8,9,10,11]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/freepascal/fpc`，作为本机 FPC 发行布局参照。
  - 参考：`/home/dtamade/projects/fpdev-fpc/README.md`，用于对照已发布的二进制布局（`bin/`、`lib/fpc/{version}/units/{target}/`、`share/`）。
  - 参考：`tests/run_all_tests.sh`，即 任务 7 的 `harness` 入口。
  - 参考：`tools/stage0/nextpas.pas`，即 任务 9 的驱动入口构建输入。
  - 参考：`build/targets/linux-x86_64.toml`，即 任务 10 中唯一支持的目标平台。
  - 参考：`docs/architecture/rtl-specification.md` 与 `docs/architecture/crt-specification.md`，CI 需要持续关注这些运行时交付物。

  **验收标准（仅限代理可执行）：**
  - [ ] `test -f .github/workflows/ci.yml`
  - [ ] `test -x build/verify_local.sh`
  - [ ] `test -f docs/architecture/distribution-layout-specification.md`
  - [ ] `./build/verify_local.sh`
  - [ ] `grep -n "Linux" .github/workflows/ci.yml`
  - [ ] `grep -n "bin/\|units/<target>/\|share/" docs/architecture/distribution-layout-specification.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：本地验证路径覆盖完整的第一阶段基线
    工具：Bash
    步骤：运行 `./build/verify_local.sh | tee .sisyphus/evidence/task-12-local-verify.txt`
    预期：脚本会检查 docs、编译 `stage0` 驱动入口，并成功运行 smoke `harness`。
    证据：`.sisyphus/evidence/task-12-local-verify.txt`

  场景：CI 仍然保持 Linux-only 且不越界
    工具：Bash
    步骤：运行 `grep -n "ubuntu\|linux" .github/workflows/ci.yml && ! grep -n "windows\|macos" .github/workflows/ci.yml`
    预期：工作流明确只针对 Linux，不会误引入不支持的平台。
    证据：`.sisyphus/evidence/task-12-local-verify-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`ci(linux): add nextpas local and github verification` | 文件：[`.github/workflows/ci.yml`, `build/verify_local.sh`, `docs/architecture/distribution-layout-specification.md`]

- [x] 5. 编写自举路线图

  **要做什么**：创建 `docs/architecture/bootstrap-roadmap.md`，明确阶段推进顺序：`stage0` = 由 FreePascal 托管的 nextPas 驱动入口与脚手架，`stage1` = 由 nextPas 自有的前端与控制面模块接管更多职责，但外层构建路径仍依赖 FPC，`stage2` = 在兼容性证据足够成熟之后才允许开始的可选自托管调查。每个阶段都必须写清 promotion gates、产物和回退条件。
  **禁止事项**：不要暗示自托管属于第一阶段；也不要把自举写成没有进入/退出标准的抽象愿景。

  **推荐执行代理画像：**
  - 类别：`deep`
  - 原因：自举顺序是工具、编译器所有权和验证体系之间的战略依赖。
  - 技能：[`feature-design-assistant`, `docs-write`]，把长期有效的架构推进顺序写清楚。
  - 省略：[`frontend-design`]，与视觉设计无关。

  **并行信息：** 可并行：是 | 波次 1 | 会阻塞：[7,9,10,11] | 受阻于：[1,2,3,4]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`docs/adr/0001-fpc-reference-baseline.md`，用于确认冻结的 `stage0` 与平台假设。
  - 参考：`docs/architecture/overview.md`，用于确认顶层系统边界。
  - 参考：`docs/architecture/compatibility-matrix.md`，用于确认自举各阶段必须维护的兼容承诺。
  - 参考：`docs/architecture/directory-structure-specification.md`，用于确认各阶段将逐步填充的文件系统模块。
  - 参考：`/home/dtamade/freepascal/fpcsrc/compiler/pp.pas`，用于借鉴命令行 compiler 入口形态。

  **验收标准（仅限代理可执行）：**
  - [ ] `test -f docs/architecture/bootstrap-roadmap.md`
  - [ ] `grep -n "stage0" docs/architecture/bootstrap-roadmap.md`
  - [ ] `grep -n "stage1" docs/architecture/bootstrap-roadmap.md`
  - [ ] `grep -n "stage2" docs/architecture/bootstrap-roadmap.md`
  - [ ] `grep -n "Linux x86_64" docs/architecture/bootstrap-roadmap.md`
  - [ ] `grep -n "promotion gate" docs/architecture/bootstrap-roadmap.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：路线图定义了全部自举阶段与晋级门槛
    工具：Bash
    步骤：运行 `for term in stage0 stage1 stage2 "promotion gate"; do grep -n "$term" docs/architecture/bootstrap-roadmap.md; done`
    预期：文档中明确出现每个阶段以及每个 promotion gate。
    证据：`.sisyphus/evidence/task-5-bootstrap-roadmap.txt`

  场景：自托管没有被误写成第一阶段内容
    工具：Bash
    步骤：运行 `! grep -n "第一阶段.*自托管" docs/architecture/bootstrap-roadmap.md`
    预期：不会出现把自托管说成第一阶段完成条件的陈述。
    证据：`.sisyphus/evidence/task-5-bootstrap-roadmap-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`docs(architecture): define nextpas bootstrap roadmap` | 文件：[`docs/architecture/bootstrap-roadmap.md`]

- [x] 6. 搭建现代仓库边界

  **要做什么**：创建顶层仓库骨架和所有权/readme 文件：`compiler/`、`rtl/`、`packages/`、`tests/`、`tools/`、`build/`，以及 `docs/architecture/` 和 `docs/adr/`。在 `compiler/` 内创建 `frontend/`、`syntax/`、`sema/`、`ir/`、`backend/`、`targets/`、`driver/`、`diagnostics/` 等子目录；在 `rtl/` 内至少创建 `core/` 和 `crt/`。再为每个区域补上简洁的 `README.md` 或 `OWNERS.md`，让责任从第一天就明确下来。
  **禁止事项**：不要让仓库只剩一堆没有责任说明的空目录；也不要照搬平铺式 FPC `compiler` 布局。

  **推荐执行代理画像：**
  - 类别：`unspecified-high`
  - 原因：这是一个跨多个目录的仓库自举任务，并且受架构边界约束。
  - 技能：[`writing-plans`]，把结构写具体、写完整；[`docs-write`]，保证 owner/readme 文档不是占位文字。
  - 省略：[`frontend-design`]，无关。

  **并行信息：** 可并行：是 | 波次 2 | 会阻塞：[7,8,9,11] | 受阻于：[2,4]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`docs/architecture/overview.md`，作为顶层区域的权威定义。
  - 参考：`docs/architecture/directory-structure-specification.md`，用于确认目录职责。
  - 参考：`/home/dtamade/freepascal/fpcsrc`，用于保留外部生态边界名称。
  - 参考：`/home/dtamade/freepascal/fpcsrc/compiler`，用于知道哪些历史结构不能直接照搬。

  **验收标准（仅限代理可执行）：**
  - [x] `for dir in compiler rtl packages tests tools build docs/architecture docs/adr; do test -d "$dir"; done`
  - [x] `for dir in compiler/frontend compiler/syntax compiler/sema compiler/ir compiler/backend compiler/targets compiler/driver compiler/diagnostics rtl/core rtl/crt; do test -d "$dir"; done`
  - [x] `test -f compiler/README.md && test -f rtl/README.md && test -f packages/README.md && test -f tools/README.md && test -f tests/README.md && test -f build/README.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：仓库骨架与目录结构规范一致
    工具：Bash
    步骤：运行 `for dir in compiler rtl packages tests tools build compiler/frontend compiler/syntax compiler/sema compiler/ir compiler/backend compiler/targets compiler/driver compiler/diagnostics rtl/core rtl/crt; do test -d "$dir" || exit 1; done`
    预期：所有必需目录都存在。
    证据：`.sisyphus/evidence/task-6-repo-skeleton.txt`

  场景：每个顶层区域都有 ownership/readme 文件
    工具：Bash
    步骤：运行 `for file in compiler/README.md rtl/README.md tools/README.md tests/README.md build/README.md; do test -f "$file" || exit 1; done`
    预期：不会有顶层区域处于未文档化状态。
    证据：`.sisyphus/evidence/task-6-repo-skeleton-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`chore(repo): scaffold nextpas repository boundaries` | 文件：[`compiler/`, `rtl/`, `packages/`, `tests/`, `tools/`, `build/`, `docs/architecture/`, `docs/adr/`]

- [x] 7. 搭建验证 `harness` 骨架

  **要做什么**：创建 `tests/run_all_tests.sh`、`tests/harness/README.md`、`tests/harness/runner.pas` 和 `tests/harness/snapshot_support.pas`。这个 `harness` 必须能枚举 test groups、支持 `--filter <group>`、输出确定性的 exit code，并为 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt` 和 `regression` 套件保留 evidence-friendly 输出。
  **禁止事项**：不要把单一 smoke 文件路径硬编码进 harness；也不要在失败时让 harness 覆盖掉 diff evidence。

  **推荐执行代理画像：**
  - 类别：`deep`
  - 原因：验证架构是兼容性资产本身，不是胶水代码。
  - 技能：[`tdd-guide`]，保证 harness 行为可测试；[`docs-write`]，把使用方式写清楚。
  - 省略：[`frontend-design`]，不涉及视觉工作。

  **并行信息：** 可并行：是 | 波次 2 | 会阻塞：[8,12] | 受阻于：[3,5,6]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/projects/nextpas.core/docs/TESTING.md`，用于借鉴仓库级 regression 编排。
  - 参考：`/home/dtamade/projects/nextpas.core/tests/nextpas.core.test/BuildOrTest.sh`，用于借鉴分模块 build/test driver 形态。
  - 参考：`/home/dtamade/projects/nextpas.core/src/nextpas.core.test.runner.pas`，用于借鉴统一 Pascal test runner 行为。
  - 参考：`/home/dtamade/projects/nextpas.core/src/nextpas.core.test.snapshot.pas`，用于借鉴 snapshot/diff 支持。
  - 参考：`docs/architecture/compatibility-matrix.md`，用于确认必须暴露的 test group 类别。
  - 参考：`docs/architecture/bootstrap-roadmap.md`，用于确认 `stage0` 工具假设。
  - 参考：`docs/architecture/test-harness-specification.md`，用于对齐分组名、公开行为与失败语义。

  **验收标准（仅限代理可执行）：**
  - [x] `test -x tests/run_all_tests.sh`
  - [x] `test -f tests/harness/README.md`
  - [x] `test -f tests/harness/runner.pas`
  - [x] `test -f tests/harness/snapshot_support.pas`
  - [x] `./tests/run_all_tests.sh --list-groups | grep -E "compiler-pass|compiler-fail|diagnostics|rtl|crt|regression"`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：`harness` 列出全部受支持的 test groups
    工具：Bash
    步骤：运行 `./tests/run_all_tests.sh --list-groups | tee .sisyphus/evidence/task-7-harness-groups.txt`
    预期：输出包含 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt` 和 `regression`。
    证据：`.sisyphus/evidence/task-7-harness.txt`

  场景：非法分组会稳定失败
    工具：Bash
    步骤：运行 `! ./tests/run_all_tests.sh --filter does-not-exist > .sisyphus/evidence/task-7-harness-invalid.txt 2>&1`
    预期：命令以非零状态退出，并打印清晰的 unknown-group 错误。
    证据：`.sisyphus/evidence/task-7-harness-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`test(harness): add nextpas verification skeleton` | 文件：[`tests/run_all_tests.sh`, `tests/harness/README.md`, `tests/harness/runner.pas`, `tests/harness/snapshot_support.pas`]

- [x] 8. 预置兼容性测试桶与 smoke 样例

  **要做什么**：创建初始测试目录 `tests/compiler/pass/`、`tests/compiler/fail/`、`tests/diagnostics/parser/`、`tests/rtl/`、`tests/crt/` 和 `tests/regression/`，并为每个类别至少补一个 smoke 样例，在需要的地方补齐对应基线快照输出。必须让 CRT 测试桶作为独立区域显式存在，而不是被折叠进泛化 RTL 覆盖。
  **禁止事项**：不要让任何已声明 test group 为空；也不要把 diagnostics snapshots 混进 `compiler-pass` 或 `compiler-fail` 目录。

  **推荐执行代理画像：**
  - 类别：`unspecified-high`
  - 原因：这个任务同时涉及仓库结构、fixture 设计和验证语义。
  - 技能：[`tdd-guide`]，把测试组织成稳定基准，而不是临时样例。
  - 省略：[`frontend-design`]，无关。

  **并行信息：** 可并行：是 | 波次 2 | 会阻塞：[12] | 受阻于：[6,7]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/projects/castle-engine/tests/code/testcases/testcompiler.pas`，用于借鉴 compiler 兼容性 fixture 设计。
  - 参考：`/home/dtamade/projects/castle-engine/tests/code/testcases/testsysutils.pas`，用于借鉴 RTL 行为样例设计。
  - 参考：`/home/dtamade/projects/castle-engine/tests/code/testcases/testoldfpcbugs.pas`，用于借鉴 regression bucket 组织方式。
  - 参考：`/home/dtamade/projects/nextpas.core/tests/nextpas.core.test/Test_core_help_snapshots.pas`，用于借鉴带 snapshot 的输出测试。
  - 参考：`tests/harness/README.md`，用于对齐 任务 7 中已声明的 harness 约定。

  **验收标准（仅限代理可执行）：**
  - [x] `for dir in tests/compiler/pass tests/compiler/fail tests/diagnostics/parser tests/rtl tests/crt tests/regression; do test -d "$dir"; done`
  - [x] `find tests/compiler/pass -type f | grep -q .`
  - [x] `find tests/compiler/fail -type f | grep -q .`
  - [x] `find tests/rtl -type f | grep -q .`
  - [x] `find tests/crt -type f | grep -q .`
  - [x] `./tests/run_all_tests.sh --filter smoke`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：smoke 样例覆盖所有已声明类别
    工具：Bash
    步骤：运行 `./tests/run_all_tests.sh --filter smoke | tee .sisyphus/evidence/task-8-smoke.txt`
    预期：`harness` 能完成执行，并在每个已播种类别中至少报告一个通过的 smoke 样例。
    证据：`.sisyphus/evidence/task-8-smoke.txt`

  场景：`compiler-fail` 样例被当作预期失败处理
    工具：Bash
    步骤：运行 `./tests/run_all_tests.sh --filter compiler-fail > .sisyphus/evidence/task-8-smoke-error.txt 2>&1`
    预期：harness 会把预期的编译失败报告为 PASS，而不是基础设施错误。
    证据：`.sisyphus/evidence/task-8-smoke-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`test(compat): seed nextpas smoke compatibility buckets` | 文件：[`tests/compiler/pass/`, `tests/compiler/fail/`, `tests/diagnostics/parser/`, `tests/rtl/`, `tests/crt/`, `tests/regression/`]

<!-- TASKS_INSERT_HERE -->

- [x] 1. 冻结 FPC 参考基线

  **要做什么**：创建 `docs/adr/0001-fpc-reference-baseline.md`，作为第一阶段兼容性的唯一事实来源。文档中必须记录权威本地参考树（`/home/dtamade/freepascal/fpcsrc`）、Linux x86_64 范围、FreePascal 作为 `stage0` 的事实、硬性兼容层（`Source syntax`、`Core semantics`、RTL 行为、单元/模块组织），以及显式非目标（`No new syntax`、Delphi 对等兼容、ABI 硬保证、双平台同步首发）。
  **禁止事项**：不要把基线写成“最新 FPC”或“当前已安装版本即可”；不要承诺 ABI 兼容；不要把 Delphi 写成默认的隐含次级目标。

  **推荐执行代理画像：**
  - 类别：`writing`
  - 原因：这是 ADR 级别的约束文档，必须尽可能消除歧义。
  - 技能：[`docs-write`]，输出清晰、可执行的架构约束文字。
  - 省略：[`frontend-design`]，不涉及 UI 或视觉产物。

  **并行信息：** 可并行：是 | 波次 1 | 会阻塞：[2,3,4,5] | 受阻于：[]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/freepascal/fpcsrc/README.md`，用于确认官方顶层源码树边界。
  - 参考：`/home/dtamade/freepascal/fpcsrc/compiler/pp.pas`，用于确认 compiler 入口与 target 假设。
  - 参考：`/home/dtamade/freepascal/fpcsrc/rtl/README.txt`，用于确认 RTL 组织与平台切分。
  - 参考：`/home/dtamade/freepascal/fpcsrc/tests/readme.txt`，用于确认 FPC 的验证预期。
  - 外部参考：`docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`，用于确认这次规划中的访谈结论和调研记录。

  **验收标准（仅限代理可执行）：**
  - [ ] `test -f docs/adr/0001-fpc-reference-baseline.md`
  - [ ] `grep -n "/home/dtamade/freepascal/fpcsrc" docs/adr/0001-fpc-reference-baseline.md`
  - [ ] `grep -n "Linux x86_64" docs/adr/0001-fpc-reference-baseline.md`
  - [ ] `grep -n "ABI compatibility is deferred" docs/adr/0001-fpc-reference-baseline.md`
  - [ ] `grep -n "No new syntax" docs/adr/0001-fpc-reference-baseline.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：基线文档完整可核验
    工具：Bash
    步骤：运行 `test -f docs/adr/0001-fpc-reference-baseline.md && grep -n "/home/dtamade/freepascal/fpcsrc" docs/adr/0001-fpc-reference-baseline.md && grep -n "Linux x86_64" docs/adr/0001-fpc-reference-baseline.md && grep -n "No new syntax" docs/adr/0001-fpc-reference-baseline.md`
    预期：所有检查都成功，并打印对应匹配行。
    证据：`.sisyphus/evidence/task-1-freeze-fpc-baseline.txt`

  场景：受限范围不会渗出到文档里
    工具：Bash
    步骤：运行 `! grep -n "Delphi.*硬目标\|ABI.*硬目标\|双平台" docs/adr/0001-fpc-reference-baseline.md`
    预期：命令成功退出，且不会找到任何被禁止的硬目标表述。
    证据：`.sisyphus/evidence/task-1-freeze-fpc-baseline-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`docs(adr): freeze nextpas fpc reference baseline` | 文件：[`docs/adr/0001-fpc-reference-baseline.md`]

- [x] 2. 编写总体架构概览

  **要做什么**：创建 `docs/architecture/overview.md` 作为主架构文档。文档必须定义顶层边界（`compiler`、`rtl`、`packages`、`tests`、`tools`、`build`）、单平台 Linux x86_64 范围、FreePascal `stage0` 自举位置、内部现代化规则（在保留外部生态边界的同时引入现代子模块），以及显式的第一阶段 non-goals。
  **禁止事项**：不要模糊“保留外部兼容性”与“重设计内部结构”之间的差别；不要让包管理器、IDE 或 LSP 的范围保持含混。

  **推荐执行代理画像：**
  - 类别：`deep`
  - 原因：这份架构概览会支配后续所有仓库与实现决策。
  - 技能：[`feature-design-assistant`, `docs-write`]，既要保持系统层面的连贯性，也要让文字能被执行。
  - 省略：[`frontend-design`]，这不是 UI 规划问题。

  **并行信息：** 可并行：是 | 波次 1 | 会阻塞：[6,9,11] | 受阻于：[1]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/freepascal/fpcsrc/README.md`，用于确认规范的顶层源码区域。
  - 参考：`/home/dtamade/freepascal/fpcsrc/utils/README.txt`，用于证明 tools 是一等区域，而不是 compiler 边角料。
  - 参考：`docs/adr/0001-fpc-reference-baseline.md`，即 任务 1 冻结出的兼容性基线。
  - 外部参考：`docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-research.md`，用于补足访谈决策和发现记录。

  **验收标准（仅限代理可执行）：**
  - [ ] `test -f docs/architecture/overview.md`
  - [ ] `grep -n "compiler" docs/architecture/overview.md`
  - [ ] `grep -n "rtl" docs/architecture/overview.md`
  - [ ] `grep -n "packages" docs/architecture/overview.md`
  - [ ] `grep -n "tests" docs/architecture/overview.md`
  - [ ] `grep -n "tools" docs/architecture/overview.md`
  - [ ] `grep -n "build" docs/architecture/overview.md`
  - [ ] `grep -n "Linux x86_64" docs/architecture/overview.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：架构概览覆盖全部顶层层次
    工具：Bash
    步骤：运行 `for term in compiler rtl packages tests tools build; do grep -n "$term" docs/architecture/overview.md; done && grep -n "Linux x86_64" docs/architecture/overview.md`
    预期：每个必需术语至少出现一次，且平台范围明确。
    证据：`.sisyphus/evidence/task-2-architecture-blueprint.txt`

  场景：范围蔓延被显式排除
    工具：Bash
    步骤：运行 `grep -n "Non-goals" docs/architecture/overview.md && grep -n "包管理器\|LSP\|IDE\|ABI" docs/architecture/overview.md`
    预期：文档中有独立的 non-goals 章节，并明确点名延后项。
    证据：`.sisyphus/evidence/task-2-architecture-blueprint-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`docs(architecture): add nextpas architecture overview` | 文件：[`docs/architecture/overview.md`]

- [x] 3. 定义兼容性矩阵

  **要做什么**：创建 `docs/architecture/compatibility-matrix.md`，用显式行列写清 `Source syntax`、`Core semantics`、单元/模块行为、RTL 行为、包兼容分层、诊断预期与 ABI/二进制兼容状态。必须把源码/语义/RTL/unit 兼容标成第一阶段硬目标，把 ABI 标成延后，并把核心 RTL 之外的包定义为分阶段后续工作。
  **禁止事项**：不要把所有兼容性压缩成一句模糊的“全面兼容”；也不要只在散文里含糊带过延后区域而不提供表格。

  **推荐执行代理画像：**
  - 类别：`writing`
  - 原因：核心任务是把宽泛的兼容性意图压缩成清晰的决策表。
  - 技能：[`docs-write`]，输出表格清楚、措辞强约束的文档。
  - 省略：[`frontend-design`]，与兼容性规格无关。

  **并行信息：** 可并行：是 | 波次 1 | 会阻塞：[7,8,11] | 受阻于：[1]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`docs/adr/0001-fpc-reference-baseline.md`，用于确认冻结的兼容范围。
  - 参考：`/home/dtamade/projects/castle-engine/tests/code/testcases/testcompiler.pas`，用于借鉴 compiler 语义兼容断言。
  - 参考：`/home/dtamade/projects/castle-engine/tests/code/testcases/testsysutils.pas`，用于借鉴 RTL 行为断言。
  - 参考：`/home/dtamade/freepascal/fpcsrc/packages`，用于证明包兼容必须分层，而不能默认全部承诺。

  **验收标准（仅限代理可执行）：**
  - [ ] `test -f docs/architecture/compatibility-matrix.md`
  - [ ] `grep -n "Source syntax" docs/architecture/compatibility-matrix.md`
  - [ ] `grep -n "Core semantics" docs/architecture/compatibility-matrix.md`
  - [ ] `grep -n "RTL 行为" docs/architecture/compatibility-matrix.md`
  - [ ] `grep -n "单元/模块" docs/architecture/compatibility-matrix.md`
  - [ ] `grep -n "ABI compatibility is deferred" docs/architecture/compatibility-matrix.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：兼容性矩阵列出每一层
    工具：Bash
    步骤：运行 `for term in "Source syntax" "Core semantics" "RTL 行为" "单元/模块" "诊断" "ABI"; do grep -n "$term" docs/architecture/compatibility-matrix.md; done`
    预期：矩阵中能看到所有兼容层级。
    证据：`.sisyphus/evidence/task-3-compatibility-matrix.txt`

  场景：延后项不会被错误提升
    工具：Bash
    步骤：运行 `grep -n "ABI compatibility is deferred" docs/architecture/compatibility-matrix.md && ! grep -n "ABI.*第一阶段硬目标" docs/architecture/compatibility-matrix.md`
    预期：ABI 被明确标记为 deferred，且不会被写成第一阶段硬目标。
    证据：`.sisyphus/evidence/task-3-compatibility-matrix-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`docs(architecture): define nextpas compatibility matrix` | 文件：[`docs/architecture/compatibility-matrix.md`]

- [x] 4. 发布仓库目录结构规范

  **要做什么**：创建 `docs/architecture/directory-structure-specification.md`，把 FPC 顶层区域映射到 nextPas 对应目录。文档必须保留 `compiler / rtl / packages / tests / tools` 作为外部生态边界，增加 `build/` 作为现代编排层，并定义现代 `compiler` 内部子模块（`frontend`、`syntax`、`sema`、`ir`、`backend`、`targets`、`driver`、`diagnostics`），而不是沿用平铺式历史源码树。
  **禁止事项**：不要复制平铺式 FPC 编译器源码布局；也不要让任何顶层目录缺少所有权/意图说明。

  **推荐执行代理画像：**
  - 类别：`deep`
  - 原因：这份文档会成为兼容性要求与实际仓库骨架之间的桥梁。
  - 技能：[`feature-design-assistant`, `docs-write`]，把架构意图对齐到可落地的文件系统布局。
  - 省略：[`frontend-design`]，不适用。

  **并行信息：** 可并行：是 | 波次 1 | 会阻塞：[6,12] | 受阻于：[1]

  **参考资料（执行者没有访谈上下文，务必完整）：**
  - 参考：`/home/dtamade/freepascal/fpcsrc/README.md`，用于确认 FPC 的顶层结构。
  - 参考：`/home/dtamade/freepascal/fpcsrc/compiler`，用于确认哪些历史 compiler 树需要内部现代化。
  - 参考：`/home/dtamade/freepascal/fpcsrc/rtl/README.txt`，用于确认 RTL 目录职责。
  - 参考：`/home/dtamade/freepascal/fpcsrc/packages/build/Makefile`，用于确认 packages 的构建协同方式。
  - 参考：`/home/dtamade/freepascal/fpcsrc/tests/readme.txt`，用于确认 tests 必须是一等顶层区域。

  **验收标准（仅限代理可执行）：**
  - [ ] `test -f docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "compiler" docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "rtl" docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "packages" docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "tests" docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "tools" docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "build" docs/architecture/directory-structure-specification.md`
  - [ ] `grep -n "frontend\|syntax\|sema\|ir\|backend\|targets\|driver\|diagnostics" docs/architecture/directory-structure-specification.md`

  **QA 场景（强制，缺失即任务不完整）：**

  ```
  场景：目录结构规范保留外部生态边界
    工具：Bash
    步骤：运行 `for term in compiler rtl packages tests tools build; do grep -n "$term" docs/architecture/directory-structure-specification.md; done`
    预期：所有顶层 nextPas 区域都被明确映射。
    证据：`.sisyphus/evidence/task-4-directory-blueprint.txt`

  场景：编译器现代化边界写得足够明确
    工具：Bash
    步骤：运行 `for term in frontend syntax sema ir backend targets driver diagnostics; do grep -n "$term" docs/architecture/directory-structure-specification.md; done`
    预期：现代 compiler 子模块边界被逐项点名。
    证据：`.sisyphus/evidence/task-4-directory-blueprint-error.txt`
  ```

  **提交建议：** 是 | 提交信息：`docs(architecture): publish nextpas directory structure specification` | 文件：[`docs/architecture/directory-structure-specification.md`]

<!-- TASKS_INSERT_HERE -->

## 最终验证波次（强制，必须在全部实现任务之后）

> 4 个审查代理必须并行运行，且必须全部批准。向用户汇总整合后的结果，并在获得明确的 `okay` 之后才能结束。
> **验证完成后不要自动继续。必须等待用户的明确批准，才能标记工作完成。**
> **在获得用户的 `okay` 之前，绝不能把 F1-F4 标记为已检查。** 如果被拒绝或收到反馈，就修复、重跑、再次汇报，然后继续等待 `okay`。

- [x] F1. 计划一致性审计 — `oracle`
- [x] F2. 代码质量审查 — `unspecified-high`
- [x] F3. 真实手动 QA — `unspecified-high`
- [x] F4. 范围忠实性检查 — `deep`

## 提交策略

- 提交 1：冻结架构决策与兼容性基线文档
- 提交 2：补齐仓库骨架与所有权说明/README 文件
- 提交 3：加入验证 `harness`、测试桶与示例样例
- 提交 4：加入 `stage0` 命令行驱动入口与 Linux x86_64 目标平台模型
- 提交 5：加入 CI/本地验证与发行布局约束

## 成功标准

- 执行者无需再询问“兼容谁、先做什么、哪些不做、如何验证”。
- 所有第一阶段产物都能由命令验证存在性、可编译性或可执行性。
- `nextpas` 至少能在 Linux x86_64 上通过 FreePascal 驱动一个 smoke 程序编译路径。
- 验证体系能明确区分 compiler-pass、compiler-fail、diagnostics、rtl、crt、regression 六类结果。
- 文档中的边界、目录、自举路线与代码骨架保持一致。
