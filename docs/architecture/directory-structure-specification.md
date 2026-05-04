# nextPas 目录结构规范

这份文档把冻结的 FPC 参考树映射到 nextPas 第一阶段的仓库形状上。目标是在保留
熟悉外部生态边界的同时，让内部所有权模型更干净、更现代，并且更容易在
Linux x86_64 上验证。

这里的“更现代”不是抽象形容词。nextPas 明确参考 Rust、Go 这类先进项目结构里已经被证明有效的
原则：顶层边界稳定、命令入口轻、共享核心厚、公开表面和内部实现分层清楚。但 nextPas 不会为了
看起来像它们，就机械照抄 `cmd/`、`pkg/`、`internal/` 或 Cargo workspace 的名字。
nextPas 要学的是结构原则，不是目录名 cosplay。

## 顶层边界保持可识别

nextPas 仓库保留 FPC 参考树对外暴露的顶层区域，并额外增加一个显式的编排层，
用来容纳现代构建与验证入口。

| 外部边界   | nextPas 位置 | 第一阶段职责                                               | 说明                                                    |
| ---------- | ------------ | ---------------------------------------------------------- | ------------------------------------------------------- |
| `compiler` | `compiler/`  | 语言前端、语义、IR、targets、diagnostics 与驱动控制面      | 保留生态侧可识别边界，但不复制历史平铺式编译器树        |
| `rtl`      | `rtl/`       | 运行时基线、核心运行时服务，以及显式拆分出来的 CRT         | 让 RTL 行为与 CRT 行为都保持可见，并能单独验证          |
| `packages` | `packages/`  | 在核心基线稳定后分阶段推进包兼容                           | 第一阶段不承诺整个 FPC 包全集                           |
| `tests`    | `tests/`     | 编译、诊断、运行时、CRT、回归、`harness` 与 smoke 路径验证 | `tests` 是系统边界的一部分，不是收尾工作                |
| `tools`    | `tools/`     | `stage0` 入口与未来面向开发者的工具                        | 第一个公开工具是由 FreePascal 托管的 `nextpas` 驱动入口 |
| `build`    | `build/`     | 可重复编排、目标平台规格、本地验证和 CI 粘合层             | 这是 FPC 没有明确抽成单一顶层区域的现代控制层           |

这种布局让已经熟悉 FreePascal 的人一眼能认出 `compiler`、`rtl`、`packages`、
`tests` 和 `tools`，同时也让 nextPas 从第一天起就拥有更清晰的仓库结构约束。

## 参考 Rust / Go 的结构原则，但不照抄目录名

nextPas 的仓库结构应当吸收 Rust / Go 的这几条成熟经验：

- 顶层目录先表达稳定所有权，再表达历史习惯。
- command entrypoint 尽量薄，核心逻辑沉到可复用模块。
- package manager、formatter、language service、test runner、doctor 等工具共享控制面，不各自重写一套。
- internal implementation 留在 owning subsystem 里，不把全仓扔进一个模糊 `utils` 目录。

把这几条翻译到 nextPas，就是：

- `tools/` 在角色上接近 Go 的 `cmd/` 或 Rust 的 thin binary surface，但命名继续保持 Pascal 项目语境。
- `compiler/`、`build/`、`rtl/`、`packages/`、`tests/` 持有真正可复用的核心逻辑，而不是给 CLI 当附件。
- `workspace-specification.md`、`toolchain-specification.md`、`language-service-specification.md`
  这些控制面文档，决定 future developer tools 怎样共享真相。

这条规则的重点不是“长得像 Rust/Go”，而是“像它们那样利于持续长工具链”。

## 把 FPC 区域映射到 nextPas 职责

冻结的 FPC 源码树仍然是解释这些保留边界含义的对照基准：

- FPC `compiler` 映射到 nextPas `compiler/`，但保留的只是边界，内部布局会重设计。
- FPC `rtl` 映射到 nextPas `rtl/`，并且更严格地区分核心运行时服务与
  控制台导向的 CRT 行为。
- FPC `packages` 映射到 nextPas `packages/`，但第一阶段只把它当作分阶段后续区域，
  而不是立即追求“全量完成”。
- FPC `tests` 映射到 nextPas `tests/`，其中 `harness` 代码、smoke 样例和
  兼容性测试桶都是显式的仓库资产。
- FPC `utils` 的职责在 nextPas 中拆分为 `tools/` 与 `build/`：开发者入口放在
  `tools/`，编排和目标平台控制放在 `build/`。

## 在 `compiler/` 内部做现代化重组

nextPas 保留 `compiler/` 作为公开边界，但第一阶段不会继承历史平铺式源码组织。
推荐的内部布局如下：

- `frontend`：源码摄取、编译会话建立，以及把流程导入 `syntax`/`sema`
  处理阶段的高层编排
- `syntax`：对保留的 FreePascal 源码形式做词法与语法分析
- `sema`：负责类型检查、符号解析和影响可观察正确性的语义规则
- `ir`：把语言分析和下游代码生成隔开的内部表示与转换边界
- `backend`：位于语义分析下游的代码生成所有权区域
- `targets`：目标平台相关能力、限制与布局假设
- `driver`：命令行入口、构建编排与 `stage0` 控制流
- `diagnostics`：确定性错误分类、报告规则与便于留证的输出表面

这些子模块的存在，是为了保留兼容性，而不是保留历史偶然形成的结构。

## 让 `tools/` 能自然长出 package manager 和现代 developer tools

如果项目结构真的要参考 Rust、Go 的先进之处，那它就必须天然利于工具扩展，而不是每加一个工具就
再拼一层私有脚本。

因此 nextPas 冻结：

- `tools/` 负责公开 entrypoint，不负责独占 package resolution、workspace loading、target selection 或 diagnostics policy。
- future package manager、formatter、language service、test runner、doctor、IDE helper 等工具，
  都应优先复用 `workspace`、`toolchain`、`language service` 和 `harness` 控制面。
- 一个新工具如果需要重写 source root discovery、package graph understanding、tool discovery 或 target mapping，
  说明项目结构还不够现代。
- command surface 可以继续保持 `nextpas ...` 的统一产品感，而不必把每个能力拆成散落二进制。

这正是 Rust 的 `cargo` / Go 的 `go` 这类现代工具链真正值得学的地方：不是命令名本身，
而是“薄入口 + 共享内核 + 清楚所有权”。

## 让 RTL、CRT 和 tests 保持显式

第一阶段必须让运行时和验证表面在文件系统中一眼可见：

- `rtl/` 是运行时兼容工作的父边界。
- `rtl/core/` 为核心运行时服务预留位置，尤其是 `System` 和相关基线 units 所需行为。
- `rtl/crt/` 为控制台导向行为预留位置，并要求它保持显式且可单独测试。
- `tests/harness/` 是把兼容性承诺转化为可重复检查的执行层。
- `tests/compiler/pass/`、`tests/compiler/fail/`、`tests/diagnostics/`、
  `tests/rtl/`、`tests/crt/` 和 `tests/regression/` 是验证证据的稳定分类边界。

这也是为什么目录结构规范不能把 CRT 当成藏在泛化 RTL 文本里的实现细节，也不能把
tests 当成可有可无的附录。

## 为后续任务预留所有权

这份规范先定义意图，后续任务再按顺序把树填实：

- 任务 6 在 `compiler/`、`rtl/`、`packages/`、`tests/`、`tools/` 和 `build/`
  下补齐 `README.md` 所有权说明。
- 任务 7 在 `tests/harness/` 下加入 `harness` 入口。
- 任务 8 补上初始 smoke 样例和基于快照的测试桶。
- 任务 9 在 `tools/stage0/` 下加入 `stage0` 驱动入口。
- 任务 10 在 `build/targets/` 下加入 Linux x86_64 目标平台规格。
- 任务 11 补齐第一版显式的 `rtl/core/` 与 `rtl/crt/` 规范骨架。
- 任务 12 把已验证的目录布局接入本地验证和 Linux CI。

## 把这些反模式挡在树外

- 不要把历史平铺式 FPC 编译器树原样复制进 `compiler/`。
- 不要把 `build` 职责藏进零散脚本里，放到与其无关的目录下。
- 不要把 CRT 行为折叠进泛化的 RTL 文案。
- 不要在任务 6 脚手架完成后仍让顶层目录缺少责任说明。
- 不要让 package manager、formatter、LSP、doctor 等 future tools 各自维护一套私有 path/target/package 逻辑。
- 当 Linux x86_64 仍是第一阶段唯一支持平台时，不要引入 Windows 或 macOS
  的布局分支。
