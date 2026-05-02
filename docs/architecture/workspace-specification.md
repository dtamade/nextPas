# nextPas workspace 规范

用这份规范定义 nextPas 长期 workspace truth 的稳定边界。它回答的不是
“以后 IDE 左侧目录树怎么画”，而是“project roots、package refs、target selection、
source topology、generated artifact roots 和 install roots 应该怎样被建模，才能让
CLI、future package/workspace tools、language service 和 IDE 共用同一套开发环境真相，
而不是各自维护一份看起来差不多的本地状态”。

这份文档和 `stage0-driver-specification.md`、`toolchain-specification.md`、
`distribution-layout-specification.md`、`packages-specification.md`、
`language-service-specification.md`、`developer-tooling-specification.md`、
`package-workflow-specification.md`、`workspace-file-format-specification.md`、
`ide-specification.md` 一起工作。前者们分别冻结当前最小 CLI、工具链控制面、公开发行布局、
包生态边界、shared analysis service、统一 developer command surface、package workflow、
workspace persisted file layer 与 IDE workbench；这里冻结 workspace control plane 本身。

## 先看 FPC 真源码已经把 workspace / package / project state 散在什么地方

这份规范直接回应这些 FPC 真实源码事实：

- `packages/ide/fpintf.pas`
  - `SetPrimaryFile` 会读取 `.pri` 文件
  - 文件里只用几行文本保存 `PrimaryFileMain`、`PrimaryFileSwitches`、`PrimaryFilePara`
  - 说明 project/workspace state 更像 editor-hosted ad-hoc file，而不是正式结构化模型
- `packages/fppkg/src/pkgfppkg.pp`
  - 会在 local/global config 之间查找 `fppkg.cfg`
  - 还要再加载 compiler config 与 fpmake compiler config
  - `GetInstallRepository` 会在 command line、source repository、global config 与 installed repository 之间决定 install target
  - 说明 package/workspace/install truth 真实存在，但散在 config、repository logic 和命令流程里
- `packages/fppkg/src/pkguninstalledsrcsrepo.pp`
  - `GetBaseInstallDir`、`GetConfigFileForPackage`、`GetBuildPathDirectory`
    直接把 source path、build path、install dir、compiler target 绑定在一起
  - 说明 source roots、generated build roots、target-specific config names 都是正式问题，不是 IDE 顺手推断一下就够

这些事实组合起来说明：

- FPC 生态不是没有 workspace/package/project state
- 它的问题是这些事实分散在 IDE project file、package config、repository logic、compiler config 和 build directory 习惯里
- 当前源码取证没有展示出一层“统一 workspace truth -> shared tools / IDE / package workflow”的正式边界

nextPas 要做现代、高性能、优雅的开发环境，就必须把这一层主动抽出来。

## workspace 是开发环境控制面，不是目录浏览器

nextPas 对 workspace 的定义先冻结为：

- workspace 是 developer-facing truth model
- 它先表达 source topology、package refs、target selection 和 artifact roots
- 然后才派生 IDE tree、CLI defaults、language service scope 和 package actions
- 它不是单纯的“给一个根目录，然后到处 `find` 文件”

这条规则的意义很直接：

- IDE 左侧树不再等价于本地目录偶然长什么样
- CLI 不再需要靠一串重复 flag 才能凑出完整上下文
- package/workspace tool 不再单独维护另一份 target 与 install 语义

## workspace control plane 的目的之一，就是让 package manager 和 devtools 容易长

nextPas 既然明确要参考 Rust、Go 这类现代开发环境，那 `WorkspaceModel` 的价值就不该只停在
“给 IDE 左侧树提供数据”。

它还必须做到：

- package manager 很容易知道当前 project roots、package refs、install roots 和 target defaults
- formatter、language service、test runner、doctor 之类工具很容易接入同一份 workspace truth
- 新工具不需要先发明一份自己的 config / root discovery / package graph 语义，才有办法工作

换句话说，workspace control plane 的存在，本身就是为了降低 future developer tools 的设计成本。

## 当前仓库已经把最小 `WorkspaceModel` 落成真实实体

当前实现不再只在架构文档里讨论 `WorkspaceModel`。`compiler/frontend/np_workspace_model.pas`
已经把这四个核心对象落成真实 Pascal 实体：

- `TWorkspaceModel`
- `TPackageRef`
- `TTargetSelection`
- `TArtifactRootSet`

`ResolveWorkspaceModel(...)` 当前已经正式拥有这些最小事实：

- workspace root 与 discovery kind：
  `explicit-workspace-override`、`nearest-workspace-descriptor`、
  `nearest-package-manifest`、`source-directory-fallback`
- workspace descriptor path、nearest package manifest path 与 workspace member package refs
- project unit root infos 与去重后的 project unit roots
- artifact root、output dir 与 host-fpc cache root
- requested / resolved target id

更重要的是，这份 model 已经进入真实执行路径：

- `np_package_manifest.pas` 继续只负责 manifest parser 与 typed package/root info 输入
- `tools/stage0/nextpas.pas` 现在先加载 `ResolveWorkspaceModel(...)`，再做 CLI override
  补充与 build orchestration
- `TCompilationSession` 现在正式拥有这份 model，并从它读取 resolver roots、
  artifact root 与 output dir

## WorkspaceModel 生命周期与所有权策略

当前 `stage0` 采用 **per-session ownership** 策略：

- `ResolveWorkspaceModel(...)` 创建一个新的 `TWorkspaceModel` 实例
- `TCompilationSession` 在构造时接管这个实例的所有权
- session 结束时，model 随之释放

这个策略对 `stage0` 的 one-shot build/query 场景是合适的，但 nextPas 必须明确：

**future language service 与 IDE 需要 long-lived workspace**：

- language service 的 `LanguageServiceSession` 应该持有 workspace model 的**引用**而非所有权
- IDE workbench 应该拥有一个 shared `WorkspaceModel`，多个 analysis session 共享它
- incremental compilation 需要 workspace model 在多次 build 之间保持存活
- file watcher 需要在 workspace model 上执行 incremental invalidation

因此 nextPas 冻结以下生命周期策略：

| 场景                          | 所有权策略                                                   | 当前状态       |
| ----------------------------- | ------------------------------------------------------------ | -------------- |
| `stage0` one-shot build/query | `TCompilationSession` 拥有 model，session 结束时释放         | ✅ 已实现      |
| `stage1` language service     | `LanguageServiceSession` 持有 model **引用**，不拥有所有权  | 🔜 future      |
| `stage1` IDE workbench        | IDE 拥有 shared model，多个 session 共享                    | 🔜 future      |
| `stage1` incremental build    | Build orchestrator 持有 model 引用，model 在多次 build 间存活 | 🔜 future      |

当前 `stage0` 的 per-session ownership 不是设计缺陷，而是**阶段性的合理选择**。
但在 `stage1` 引入 language service 或 IDE integration 之前，必须重构为 shared ownership。

## 用这条分层作为唯一推荐方向

```text
CLI / IDE / future package-workspace surfaces
  -> WorkspaceModel
  -> PackageRef set + SourceRoot set + TargetSelection + ArtifactRootSet
  -> LanguageServiceSession / Build intent / Test intent
  -> ToolchainBinding + UnitGraph + Distribution layout
```

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| CLI / IDE / package-workspace tool surfaces          |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| WorkspaceModel                                       |
| - package refs                                       |
| - source roots                                       |
| - target selection                                   |
| - artifact roots                                     |
+------------------------------------------------------+
                        |
        +---------------+----------------+
        |                                |
        v                                v
+---------------------------+   +----------------------+
| LanguageServiceSession    |   | Build / Test intent  |
+---------------------------+   +----------------------+
        |                                |
        +---------------+----------------+
                        |
                        v
+------------------------------------------------------+
| UnitGraph / ToolchainBinding / distribution layout   |
+------------------------------------------------------+
```

这张图的硬约束是：

- workspace 先建模，再派生各类开发者表面
- language service、build/test orchestration 和 package workflow 都消费同一份 workspace truth
- toolchain、distribution 和 unit resolution 不反向拥有 workspace state

## 只冻结四个核心对象，不把 workspace 写成万能黑箱

为了保持边界清楚而不过度膨胀，nextPas 先只冻结四个核心对象：

- `WorkspaceModel`
- `PackageRef`
- `TargetSelection`
- `ArtifactRootSet`

| 对象              | 负责什么                                                                                  | 明确不负责什么                                |
| ----------------- | ----------------------------------------------------------------------------------------- | --------------------------------------------- |
| `WorkspaceModel`  | 统一持有 workspace roots、source topology、package refs、target selection、artifact roots | 不重新定义 Pascal 语义，不代替 IDE UI         |
| `PackageRef`      | 表达 workspace 里某个 package/member 的 identity、metadata origin 与 source/install 关系  | 不等价于 installed unit，不负责具体 tool 调用 |
| `TargetSelection` | 表达当前 workspace 默认 target、可选 target 与与 host 无关的 target-facing build truth    | 不反向拥有 `ToolchainBinding` discovery       |
| `ArtifactRootSet` | 表达 generated outputs、cache roots、install roots 与 `units/<target>/` 对齐关系          | 不伪装成 source root，不重新定义发行布局语义  |

这里的重点是：

- `WorkspaceModel` 是统一拥有者
- `PackageRef` 让 package truth 不再漂浮在 IDE 私有状态里
- `TargetSelection` 把 target 从单次命令参数提升成 workspace-level fact
- `ArtifactRootSet` 把 build outputs / install roots 从临时目录习惯升级成正式边界

## workspace roots 和 source roots 必须先被声明，再被消费

nextPas 不能继续把 workspace 理解成“从某个目录往下扫，扫到哪里算哪里”。

因此第一阶段先冻结：

- workspace 至少要能表达一个或多个 root
- source roots 是正式字段，不是 UI 层自己遍历出来的结果
- generated roots、cache roots、install roots 不能混进 source roots
- 同一 physical path 是否属于 source root、artifact root 或 shared asset root，必须可以解释

这条规则直接回应 FPC `fppkg` 里 source path、build path、install dir 被不同结构各自持有的问题。

## `PackageRef` 必须表达来源和角色，而不是只表达名字

package/workspace 真相最容易退化成“列表里有几个名字”。这不够。

nextPas 要求 `PackageRef` 至少能解释：

- 这个 package/member 从哪里来
- 它是 workspace-local source、fetched dependency、installed package，还是 generated package metadata
- 它贡献哪些 source roots 或 public units
- 它和当前 workspace 默认 target / install roots 的关系是什么

因此：

- IDE dependency view 不能自己维护私有 package list
- CLI build path 不能只靠当前工作目录猜 package membership
- future package tool 如果存在，也必须把解析结果写回 `WorkspaceModel`

这条边界承接了 `packages-specification.md` 对包生态的约束，但把“包在当前工作区里意味着什么”
单独固定了下来。

## package manager 必须被项目结构欢迎，而不是被项目结构阻碍

nextPas 不会把 package manager 当成补丁工具。既然它是长期开发环境的一部分，仓库结构就必须天然适合它。

因此：

- package manager 的公开入口应落在 `tools/` 或统一 command surface 上
- package resolution、workspace membership、target-aware install placement 不应被写死在 CLI 壳里
- package metadata 与 source/install 关系应先进入 `WorkspaceModel` / `PackageRef`
- package install 结果仍要对齐 `distribution-layout-specification.md` 的公开 layout

这也是为什么项目结构要更接近 Rust / Go 的先进之处：工具可以自然长出来，而不是每次都从零搭脚手架。

更细的 unified command surface、`CommandExecutionContext` 和 result envelope 由
`developer-tooling-specification.md` 定义。
更细的 manifest/lock/install workflow 由 `package-workflow-specification.md` 定义。
更细的 workspace descriptor、package manifest、lockfile 和 root discovery 由
`workspace-file-format-specification.md` 定义。

## `TargetSelection` 必须是 workspace fact，不只是命令参数

`stage0` 当前只承诺 `nextpas build <source> --target linux-x86_64`，但长期架构不能因此把
target 继续当成一次性 flag。

nextPas 冻结：

- command line 可以覆盖 target，但 target selection 必须有 workspace-level 归属
- language service、build orchestration、package resolution、artifact placement 都消费同一份 `TargetSelection`
- target change 会触发 analysis / build invalidation，但不应导致另一套 workspace truth 被暗中生成
- `TargetSelection` 负责 target-facing intent；`ToolchainBinding` 继续负责 host-to-target execution mapping

这样 cross target IDE analysis、CLI build 与 future package/install workflow 才不会再次分叉。

## `ArtifactRootSet` 必须把 build roots、cache roots 和 install roots 分开

FPC `pkguninstalledsrcsrepo.pp` 已经证明：build path、config file path、install dir 会一起影响 package 行为。
nextPas 必须把这些路径角色提前写清楚。

因此 `ArtifactRootSet` 至少要能表达：

- ephemeral build/work directory
- reusable cache root
- target-aware install root，例如 `units/<target>/`
- shared asset / doc root 与 private helper root 的映射点

并且要求：

- source roots 不能被 artifact 反向污染
- installed units 继续服从 `distribution-layout-specification.md` 的 `units/<target>/` 语义
- package-generated metadata、future GUI assets、toolchain sidecar artifacts 都要能解释自己落在哪类 root
- 一个 artifact path 如果无法说明自己属于哪一类 root，说明 workspace 设计还不够强

## machine-local environment state 也必须属于 `ArtifactRootSet`

如果 nextPas 未来真的要把 `env` 做成现代、高性能、优雅的环境控制面，它就不能把 machine-local
state 再偷偷塞回 workspace truth。

FPC 的 `fppkg.cfg` 已经把反例写得很清楚：

- `LocalRepository`、`BuildDir`、`ArchivesDir` 都是 machine-local path
- `CompilerConfigDir` 和 `conf.d` include tree 也表达的是本机环境状态，而不是 source truth

这说明 environment state、archive cache、build cache、activation sidecar 一旦没有正式归属，
很快就会和 package/workspace truth 混住。

因此 nextPas 继续冻结：

- machine-local env selection sidecar、distribution metadata cache、downloaded archive cache、
  unpacked toolchain/runtime staging 与 activation scratch state 都属于 `ArtifactRootSet`
- 它们可以是 workspace-local，也可以是 user-level environment root，但逻辑角色必须仍能被
  `ArtifactRootSet` 解释
- `WorkspaceModel` 只拥有这些 root 的 logical role，不拥有每个缓存文件的内部格式
- `env`、`pkg`、IDE、language service 可以消费这些 roots，但都不重新发明第二套 path ownership

这条边界的核心不是“目录名叫什么”，而是“这些状态绝不能伪装成 source root、manifest truth
或 lockfile truth”。

## 可重建缓存、可切换选择和公开安装结果必须继续分层

现代环境控制面如果不把这三类东西分开，最后一定会出现“不敢清缓存”“一切都要全量重装”或者
“CI 和本地状态互相污染”的问题。

因此 `ArtifactRootSet` 继续至少要支持这三种语义：

- reusable env cache
  - 放置 distribution metadata cache、downloaded archive cache、resolved environment cache
- activation / selection sidecar
  - 放置当前机器当前采用的 channel、distribution release、preferred binding 与等价本地选择结果
- install / visible result
  - 继续放置 `units/<target>/`、`lib/`、`share/` 映射到的真正可见结果

并且保持这些规则：

- reusable env cache 可以清理并重建，不改变 author-owned workspace/package truth
- activation / selection sidecar 是 machine-local state，但不是 canonical distribution truth
- install / visible result 继续服从 `distribution-layout-specification.md`，不因为本地 cache 策略而漂移

只有这样，future `env clean`、CI replay、IDE environment panel 和 package/install workflow 才能共用
同一套环境控制线。

## language service、build、test 只能消费 workspace，不拥有它

workspace 处在开发环境中间，但它不是每个系统的附属品。

关系固定如下：

- `language-service-specification.md`
  - 从 `WorkspaceModel` 接收 source topology、package refs、target selection、generated artifact roots
- `toolchain-specification.md`
  - 从 workspace 进入的 build intent 中消费 target 与 artifact placement 前提
- `test-harness-specification.md`
  - 继续拥有 test grouping 与 evidence model，不反向拥有 workspace truth
- `ide-specification.md`
  - IDE 只显示或操作 `WorkspaceModel` 的视图

这条边界是为了避免出现：

- IDE 里一套 workspace state
- CLI 里一套 path/target state
- package manager 里一套 repository/install state

三套系统看起来都“差不多能用”，但彼此不一致。

## `stage0` 现在最小，workspace 以后要接得上

workspace 规范不会把当前 `stage0` 写成已经拥有完整 project system。它只冻结长期收敛方向。

因此：

- `stage0` 当前可以继续只支持单一 `build <source> --target linux-x86_64` 路径
- 但当前仓库已经把最小 workspace truth 收进 compiler-owned `TWorkspaceModel`；
  `stage0 build` 不再直接维护 workspace/package/artifact discovery 规则
- 但 future package/workspace tools 不能绕开这份规范再发明自己的根模型
- 当 `nextpas` 将来出现 workspace-aware verb 时，它应建立在 `WorkspaceModel` 上，而不是重新扫目录 + 拼路径
- 当前最小 CLI 和 future IDE/workspace UX 必须能收敛到同一条开发环境控制线

这条规则既保留了第一阶段诚实性，也保留了后续扩展的一致性。

## 性能模型必须从第一天进入 workspace 设计

workspace 不是纯配置文件话题，它直接影响 analysis 与 build 性能。

nextPas 第一阶段先冻结这些性能方向：

- source roots、package refs、artifact roots 要能被 cheap to compare 和 cheap to diff
- target change、package change、source root change 要有明确 invalidation surface
- workspace reload 优先做结构化 diff，不优先做整目录重扫
- generated artifact roots 与 source roots 分离，避免 analysis 热路径误扫产物目录
- path normalization、identity normalization 与 target-aware install root mapping 必须有单点规则

这也是现代、高性能、优雅的 workspace control plane 应该具备的基本素质。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 不承诺公开 workspace file format、workspace verb 或 package manager UI
  - 当前仓库已经通过 `TWorkspaceModel` 冻结最小 workspace truth，
    避免后续每个工具各写一份
- `stage1`
  - 在当前已落地的 `WorkspaceModel`、`PackageRef`、`TargetSelection`、
    `ArtifactRootSet` 基线上继续扩展
  - `nextpas` 可以逐步出现受控的 workspace-aware surface
- `stage2`
  - 只有在 compiler、workspace truth、language service、toolchain replay 与 GUI framework 都稳定后，
    自有 IDE 与更完整 package/workspace tool 才值得进入正式实现波次

## 第一阶段非目标

- 不把这份规范写成“马上实现 package manager”
- 不把 `WorkspaceModel` 写成 IDE 专用 UI 数据结构
- 不把 source roots、artifact roots 和 install roots 混成一张模糊路径表
- 不让 package workflow 重新定义 target 或发行布局
- 不把当前 `stage0` 单文件 build 路径夸大成已经拥有完整 workspace system

第一阶段真正要交付的是：一份把 nextPas workspace 写成“整套开发环境共享控制面”的正式架构规范。
