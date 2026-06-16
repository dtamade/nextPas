# nextPas 自举路线图

用这份路线图来决定 nextPas 如何从一个由 FPC 托管的自举路径，逐步过渡到
接管更多编译器职责。它存在的目的，是让项目能够按受控顺序推进能力升级，并在
Linux x86_64 上为每次推进配套明确的证据要求与回退条件。

如果你要看 nextPas 作为整套开发环境的全局推进顺序，继续读 `master-roadmap.md`。
如果你要看 compiler 自己的执行主线，继续读 `compiler-roadmap.md`。
这份文档只负责 bootstrap ownership，不负责把 workspace、package、GUI framework 和 IDE
也写成同一份自举说明。

## 自举原则

- 使用 `/home/dtamade/projects/fpc` 作为冻结的兼容性对照基准。
- 把 Linux x86_64 保持为基线阶段唯一的宿主和目标。
- 在 nextPas 通过证据赢得更多所有权之前，一直把 FreePascal 视为 `stage0`
  实现工具链。
- `System` 路线采用 `FPC-compatible source, nextPas-owned semantic authority`：
  源码应尽量能被 FPC 构建，但对象生命周期、managed lifetime、RTTI、unit lifecycle
  和 runtime helper 的最终语义以 `np.system.*` contract 为准。
- 只有当 `harness` 执行层、smoke 路径和架构文档三者一致时才允许升级。
- 每一次升级都必须保留一个已知可工作的低一级阶段，确保随时可回退。

FPC compatibility is a build vehicle, not the architecture authority. `stage0`
可以通过 FPC-compatible adapter 运行同一批 System-facing 源码；`stage1+`
必须逐步把这些语义降到 nextPas-owned contract，而不是继续继承宿主 RTL 的隐式规则。

## 阶段概览

| 阶段     | 主要所有者                     | 谁来运行构建路径                                               | 状态                           |
| -------- | ------------------------------ | -------------------------------------------------------------- | ------------------------------ |
| `stage0` | nextPas 仓库形状与对外构建规范 | FreePascal 编译并执行第一条 `nextpas` 路径                     | ✅ 已完成（Batch 1-10）        |
| `stage1` | nextPas 自有前端与控制面模块   | FreePascal 仍托管最外层构建路径，但 nextPas 接管更多编译器逻辑 | ✅ 已完成（Batch 11-35）       |
| `stage2` | 可选的自托管调查               | nextPas 探索替换外层宿主编译器依赖                             | 📋 准备评估可行性              |

第一阶段的完成条件，是把 `stage0` 基线文档化、执行化、验证化。超出 `stage0`
的升级是后续决策，不是完成第一版基线后的自动后果。

## `stage0`：由 FPC 托管的 nextPas 基线

`stage0` 是第一条执行目标，因为 nextPas 需要先把控制面、仓库边界、
`harness` 执行层和 smoke 路径建起来，之后才能安全地接管更多编译器内部模块。

### 所有权边界

- nextPas 负责仓库形状、架构文档、兼容规则、测试分类、证据布局，以及第一版
  `nextpas` 驱动入口的公开行为。
- FreePascal 负责宿主编译器角色，把 `stage0` 驱动入口和 smoke 样例
  转化成可执行行为。

### 交付物

- `docs/architecture/directory-structure-specification.md`
- `docs/architecture/bootstrap-roadmap.md`
- `tests/run_all_tests.sh` 与第一版 `harness` 骨架
- 面向 `compiler`、`diagnostics`、RTL、CRT 与回归覆盖的
  `tests/...` smoke 样例
- `tools/stage0/nextpas.pas`
- `build/targets/linux-x86_64.toml`
- `build/verify_local.sh` 与 Linux CI 入口

### 晋级门槛（promotion gate）

只有同时满足以下条件，`stage0` 的 promotion gate 才算通过：

- 架构文档能无矛盾地定义仓库边界、自举路径、运行时边界
  和发行布局
- `stage0` `nextpas` 驱动入口能在 Linux x86_64 上通过 FreePascal 构建
- smoke 路径能通过 `harness` 跑通
- 目标平台规格已经外置，而不是深埋在 Pascal 代码里
- 本地验证与 Linux CI 运行的是同一条基线路径

### 回退条件

如果后续任务打断了 smoke 路径、破坏了 Linux x86_64 可重复性，或者让文档与
可执行路径出现不一致，就必须回退到上一个已验证的 `stage0` 基线，并先恢复证据，
再谈下一次升级。

## `stage1`：nextPas 自有前端与控制面

**状态：✅ 已完成（2026-05-02，Batch 35）**

Stage1 已经通过 Batch 1-35 的持续推进实质完成。nextPas 现在拥有完整的前端、语义分析、
IR、后端和工具链集成模块，FreePascal 仅作为宿主编译器构建 nextPas 自身。

### 完成证据

详见 `docs/architecture/stage1-completion-assessment.md`。

**核心模块：**
- ✅ Frontend: compilation session, unit resolver, workspace model, package manifest
- ✅ Syntax: lexer, green tree, AST facade
- ✅ Sema: semantic analyzer, semantic model
- ✅ IR: HIR, MIR
- ✅ Backend: code generation, toolchain integration
- ✅ Diagnostics: diagnostics sink, error recovery

**验证状态：**
- ✅ `verify-local=pass` 包含所有 smoke、failure、regression 测试
- ✅ Compiler modules 在 harness 下做出确定性决策
- ✅ 清晰的控制面边界（driver vs. compiler modules）
- ✅ 保留回退到 stage0 的能力

只有当仓库形状、`harness` 执行层、目标平台模型和 `stage0` 驱动规范已经足够稳定时，
`stage1` 才允许开始。

### 所有权边界

- nextPas 开始接管前端与控制面模块，例如解析、语义分析、诊断分类，以及更高层的
  `driver` 决策。
- FreePascal 仍然可以继续托管最外层构建路径，直到这些模块成熟。

### 交付物

- `compiler/` 下早期的 `frontend`、`syntax`、`sema`、`driver` 和
  `diagnostics` 模块
- 更强的样例覆盖，用来证明源码形式、核心语义、unit 行为、诊断输出、RTL 行为和
  CRT 行为仍保持对齐
- nextPas 自有编译器模块与剩余 FreePascal 托管构建路径之间更清晰的
  接口边界

### 晋级门槛（promotion gate）

`stage1` 的 promotion gate 需要：

- 可重复的证据，证明 nextPas 自有模块在 `harness` 下能做出确定性决策
- 已文档化的兼容层没有发生回归
- nextPas 逻辑与 FreePascal 宿主之间存在稳定的控制面边界
- 保留回退到最后一个可工作 `stage0` 路径的说明

### 回退条件

如果 nextPas 自有模块破坏了 smoke 路径、模糊了兼容边界，或者引入了未文档化的
目标平台假设，就要回退到最后一个已验证的 `stage0` 基线，并缩小这次所有权变更。

## `stage2`：可选的自托管调查

`stage2` 是一个可选的自托管调查阶段。只有当项目拥有足够证据，足以判断
是否适合移除外层宿主编译器依赖时，才允许进入。

### 所有权边界

- nextPas 探索接管最外层编译器宿主角色。
- FreePascal 从主要 `stage0` 宿主退为后备参考与回退路径。

### 交付物

- 面向自托管执行边界的可行性说明
- 更强的编译器与运行时基线兼容性证据
- 一旦调查失败即可执行的显式回退说明

### 晋级门槛（promotion gate）

`stage2` 的 promotion gate 需要：

- 在 `compiler`、RTL、CRT、`diagnostics` 与回归分类上已经积累成熟的
  兼容性证据
- 有足够信心说明目标平台模型、发行布局与验证管线
  不再依赖未文档化的宿主编译器行为
- 保留回退到最后一个由 FreePascal 托管的基线的路径

### 回退条件

如果这项调查削弱了兼容性信心、破坏了可重复性，或者移除了已知可工作的回退
路径，就必须终止调查并回退到上一个已验证阶段。

## 让路线图保持范围安全

- 不要把后续阶段升级当成引入新语法工作的许可证。
- 在 Linux x86_64 证据稳定前，不要扩大支持平台集合。
- 不要把 workspace/package/GUI/IDE 主路线也塞进这份 bootstrap 文档；那属于 `master-roadmap.md`。
- 不要把包管理器、IDE、格式化工具或 LSP 工作混进自举里程碑。
- 不要仅仅因为存在一条部分可工作的构建路径，就跳过 promotion gate 检查。
