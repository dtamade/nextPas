# nextPas 开发者工具链表面规范

用这份规范定义 nextPas 长期 developer tooling surface 的稳定边界。它回答的不是
“以后会不会再做几个工具”，而是“package manager、formatter、test runner、doc tool、
doctor、environment bootstrap / channel management、semantic query 和其他 modern developer
tools 应该怎样建立在统一 command surface、workspace truth、toolchain control plane 与
shared analysis 之上，才能像 Rust / Go 那样好用、好扩展、好维护，而不是长成一串彼此不兼容的小工具”。

这份文档和 `stage0-driver-specification.md`、`toolchain-specification.md`、
`workspace-specification.md`、`workspace-file-format-specification.md`、
`distribution-layout-specification.md`、`language-service-specification.md`、
`test-harness-specification.md`、`packages-specification.md`、
`package-workflow-specification.md` 一起工作。前者们分别冻结当前最小 CLI、工具链控制面、
workspace truth、persisted file layer、发行布局、shared analysis、验证控制面、包生态边界与
package workflow；这里冻结 unified developer command surface 本身。

## 先看 FPC 真源码已经把 developer tools 长成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `utils/fppkg/fpmake.pp`
  - `Description := 'Free Pascal package repository utility.'`
  - 说明 package manager 是正式工具，而不是编译器附注
- `packages/fppkg/src/pkgfppkg.pp`
  - `TpkgFPpkg` 同时持有 options、compiler options、repository list、config file discovery
  - 说明 package workflow 背后有一整套真实状态机，而不是一条命令就结束
- `utils/fpcmkcfg/fpcmkcfg.pp`
  - 明确是 `Create a configuration file`
  - 同时带 `fpc.cfg`、`fp.ini`、`fppkg.cfg`、default compiler template 等 builtin template 入口
  - 说明 config generation 本身就是独立工具面
- `utils/fpcmkcfg/fppkg.cfg`
  - 把 `LocalRepository`、`BuildDir`、`ArchivesDir`、`CompilerConfigDir`、`RemoteMirrors`、
    `RemoteRepository`、`InstallRepository` 写成另一套环境/bootstrap/repository config truth
  - 说明 package/bootstrap/install state 在 FPC 里也是正式问题，但没有收进统一产品表面
- `utils/fpgmake/fpgmake.pp`
  - 暴露 template / output / macro / backup / directory creation 等独立命令行语义
  - 说明 build/project generation 也是单独工具类别
- `utils/fpdoc/fpdoc.pp`
  - 文件头直接写 `FPDoc  -  Free Pascal Documentation Tool`
  - 同时持有 XML、HTML、CHM、Markdown、Man page 等多 writer surface
  - 说明文档工具也是正式生态能力
- `utils/fpcm/fpcmake.ini`
  - 同时负责 `FPCDIR`、`CROSSBINDIR`、`UNITSDIR`、`PACKAGESDIR`、`INSTALL_*DIR` 与
    `RCPROG`/`ARPROG`/`NASMPROG`
  - 说明 tool discovery、cross helper、install layout 与 package metadata 也散在 make/config layer
- `utils/ptopu.pp`
  - 明确实现 `Pascal Pretty-Printer object`
  - 说明 formatting / pretty-printing 也是独立能力，而不是 IDE 私货

这些事实说明：

- FPC 生态不是没有 package / doc / config / formatting / generation 这些现代 developer tool 需求
- 它的问题是这些能力多以独立 utility、独立 config、独立 command line surface 的方式增长
- environment bootstrap、repository/channel choice、cross tool discovery 与 install layout
  也分散在不同 config / make / utility 里
- 当前取证没有展示出一条“统一产品命令面 -> shared core -> specialized verb families”的正式边界

nextPas 既然目标是下一代 Pascal 开发环境，就必须把这条边界主动写出来。

## 开发者工具链表面必须统一成一个产品，而不是一堆散落 utility

nextPas 先冻结一个明确立场：

- future developer tools 应优先收敛到统一 `nextpas` command surface
- nextPas 不追求把能力做成一堆互不相认的小程序
- nextPas 参考 Rust 的 `cargo`、Go 的 `go` 这类 unified product experience
- 但 nextPas 不机械照抄它们的命名或 verb 细节

这条立场的意义是：

- people 不需要先记住十几个互相风格不同的工具名
- 新工具可以复用现有 command context，而不是重新发明 config / target / path 语义
- 包管理、格式化、测试、语义查询和 build 可以天然共享同一套 workspace truth

## 用这条分层作为唯一推荐方向

```text
nextpas command surface
  -> verb family
  -> CommandIntent
  -> CommandExecutionContext
  -> workspace / toolchain / language service / harness / packages
```

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| nextpas command surface                              |
| build | test | pkg | fmt | doc | env | doctor | query |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| CommandIntent + CommandExecutionContext              |
+------------------------------------------------------+
                        |
        +---------------+----------------+------------------+
        |               |                |                  |
        v               v                v                  v
+---------------+ +--------------+ +---------------+ +-------------+
| WorkspaceModel| | Toolchain    | | Language      | | Test        |
| + PackageRef  | | Binding      | | Service       | | Harness     |
+---------------+ +--------------+ +---------------+ +-------------+
```

这张图的硬约束是：

- 公开命令面只有一层产品壳
- 语义真相、workspace 真相、toolchain 真相和 test truth 都在壳下面共享
- verb family 可以扩展，但不能各自长出第二套核心

## 只冻结四个核心对象，不把工具链表面写成万能黑箱

为了保持边界清楚而不过度膨胀，nextPas 先只冻结四个核心对象：

- `DeveloperCommandSurface`
- `CommandIntent`
- `CommandExecutionContext`
- `CommandResultEnvelope`

| 对象                      | 负责什么                                                                                                 | 明确不负责什么                                       |
| ------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `DeveloperCommandSurface` | 暴露统一 `nextpas` 产品命令面、verb family、help、global flags 与稳定出口                                | 不持有包解析、target 规则或 formatting 算法          |
| `CommandIntent`           | 把一次用户请求表达成结构化 intent，例如 build、test、pkg-install、fmt、doc、env-bootstrap、doctor、query | 不直接执行外部工具，不直接拥有 UI 状态               |
| `CommandExecutionContext` | 把 workspace、target、toolchain binding、diagnostics policy、output policy 收成共享上下文                | 不重新发明 compiler truth，不替代 subsystem owner    |
| `CommandResultEnvelope`   | 把退出码、结构化事件、结果摘要、diagnostics 与 artifact/result locator 收成稳定结果表面                  | 不充当内部 IR，不逼迫各 subsystem 输出纯文本拼接结果 |

这里的重点是：

- public command surface 先统一
- intent 先结构化
- execution context 先共享
- result envelope 先稳定

## 公开命令面必须统一，但 verb family 可以分层演进

nextPas 现在不需要一次冻结完整大命令树，但必须冻结长期方向。

推荐的 verb family 如下：

- `build`
- `test`
- `pkg`
- `fmt`
- `doc`
- `env`
- `doctor`
- `query`

这些 family 的意义分别是：

- `build`
  - 面向 build / run / artifact production
- `test`
  - 面向 harness-backed verification
- `pkg`
  - 面向 package graph、fetch/install/update/publish 等 future package workflow
- `fmt`
  - 面向 source formatting 与 style normalization
- `doc`
  - 面向 API / package / workspace docs generation
- `env`
  - 面向 bootstrap、channel、toolchain/runtime SDK provisioning、activation 与 reconciliation
- `doctor`
  - 面向 environment / toolchain / workspace health inspection
- `query`
  - 面向 CLI-facing semantic query surface，例如 symbols、references、target/debug facts

这不是当前交付承诺，而是长期结构收敛方向。

## environment bootstrap / channel management 也必须属于统一产品命令面

如果 nextPas 未来真的要成为现代 Pascal 开发环境，那么“怎么装、怎么切 channel、怎么拿到匹配的
toolchain/runtime SDK、怎么把 cross target 环境准备好”就不能落回另一套历史式脚本宇宙。

FPC 的真实源码已经把反例摆出来了：

- `utils/fpcmkcfg/fppkg.cfg` 用 `LocalRepository`、`BuildDir`、`ArchivesDir`、
  `CompilerConfigDir`、`RemoteMirrors`、`RemoteRepository`、`InstallRepository`
  承载 bootstrap 与 repository/install 状态
- `utils/fpcm/fpcmake.ini` 再分别发现 `FPCDIR`、`CROSSBINDIR`、`UNITSDIR`、`PACKAGESDIR`、
  `INSTALL_BINDIR`、`INSTALL_UNITDIR`、`INSTALL_LIBDIR`、`INSTALL_SOURCEDIR` 等路径，并继续派生
  `RCPROG`、`ARPROG`、`NASMPROG`

这说明 environment/bootstrap 不是小问题，而是整套开发环境的正式控制面问题。

因此 nextPas 继续冻结：

- environment bootstrap、toolchain install/update、runtime SDK sync、channel switch、binding activation
  应进入统一 `nextpas` command surface，例如 `env` family
- nextPas 不应把 installer、channel manager、SDK manager 再拆成第二个产品壳
- 这些 action 继续消费 `ToolchainBinding`、distribution layout、runtime SDK ownership 与
  workspace truth，而不是偷偷建立新的全局世界观
- CLI、IDE、automation、CI 调用这类动作时，结果继续走同一个 `CommandResultEnvelope`

把关系压成一条线后，长期形状应该像这样：

```text
nextpas env bootstrap/use/sync
  -> resolve channel + distribution metadata
  -> materialize dist root + toolchain bundle + runtime SDK
  -> activate ToolchainBinding + Sysroot
  -> emit CommandResultEnvelope
```

nextPas 真正追求的不是“命令少”，而是“命令多了以后仍然只有一个产品壳”。

## 先把 `env` 子动作收敛到最小集合，不抢跑成另一套大平台

为了防止 future environment tooling 又失控膨胀，nextPas 先只推荐一组最小、够用、边界清楚的
`env` 子动作：

- `bootstrap`
  - 在没有 workspace 的情况下，也能从 selected channel/distribution metadata 物化一套可用的
    host developer environment
- `sync`
  - 按当前 workspace 或 user-level selection，对齐缺失的 runtime SDK、toolchain bundle 或 binding activation
- `use`
  - 切换 active channel、distribution release 或 preferred binding，不改写 package/source truth
- `status`
  - 报告当前已解析的 environment state，例如 active channel、resolved binding、runtime SDK readiness

这组子动作的设计重点是：

- `bootstrap` 负责“从零到可用”
- `sync` 负责“把当前环境收敛到声明的需要”
- `use` 负责“改变选择”
- `status` 负责“陈述现状”

nextPas 现在不需要更大的 `env` 命令树。维护类动作即使出现，也只能保持在下面的
`clean` / `gc` 边界内。

## `env clean` 已经是最小 maintenance verb，`gc` 仍然单独保留

当环境控制面长到一定阶段，确实可能需要维护类动作。但 nextPas 也不接受把它们做成一团模糊的
“重装脚本合集”。

因此 nextPas 继续冻结：

- 长期核心 `env` surface 以 `bootstrap`、`sync`、`use`、`status`、`clean` 为主；当前 stage0 已落地
  `status`、`use`、`sync`、`clean` 的最小面
- 如果 future 确实需要更强的自动回收，只增加 `gc`
- `clean` 负责显式清理 workspace-local selection sidecar 与 resolution cache 这类可重建 env-local state
- `gc` 负责保守回收当前 active selection 已不再引用的 env-owned artifact

它们的职责必须继续保持分开：

- `clean`
  - 面向“我明确要清这类 cache / sidecar”
- `gc`
  - 面向“系统自动或半自动回收当前已不可达的 env-owned artifact”

nextPas 不应同时长出 `purge`、`repair-cache`、`vacuum`、`reinstall-everything` 这类语义重叠的维护命令名。

## `env clean` / `env gc` 只能触碰 rebuildable env-owned state

这条边界必须和 `workspace-specification.md`、`workspace-file-format-specification.md` 已冻结的
`ArtifactRootSet` 规则保持完全一致。

因此 nextPas 要求：

- `env clean` 当前先只清理 workspace-local selection / resolution sidecar 这类明确可重建的 env-owned state
- `env gc` 只能回收当前 channel/distribution/binding/runtime selection 已不再引用的 env-owned artifact
- 二者都不能默认删除 source roots、workspace descriptor、package manifest、lockfile
- 二者都不能默认删除公开 install result，例如 `units/<target>/`、`lib/`、`share/` 下的正式可见结果
- 二者都不能反向吞掉 package workflow 的 fetched source graph、resolution truth 或 install truth

换句话说，`env clean` / `env gc` 维护的是 environment replay aid，不是 shared project truth。

## `env gc` 必须遵守引用驱动的保留策略，而不是目录扫荡

如果 nextPas 真想把环境控制面做得现代、高性能、优雅，那么回收策略就必须可解释，而不是
“看到像 cache 的目录就删”。

结合 `workspace-file-format-specification.md` 推荐的 `env/metadata/`、`env/archives/`、
`env/staging/`、`env/selections/`、`env/resolution/` 分桶，nextPas 继续冻结：

- active workspace selection 或 user-level active selection 会保留其当前 distribution release、
  binding、runtime SDK target set 以及等价 resolution result
- 仍被当前 selection 引用的 metadata、archive、staging residue 或 selection sidecar 都不是 `gc`
  目标
- `env/metadata/` 与 `env/resolution/` 这类 cheap-to-rebuild artifact，在不再可达后可以按 age
  或 bounded-size policy 保守回收
- `env/staging/` 是最先允许被回收的桶，但前提仍是该 staging state 已中断、已过期，或已被新的成功物化替代
- `env/archives/` 仍然是 rebuildable state，但它直接影响离线重放、快速 channel switch 与回滚成本，
  因此默认应比 metadata/resolution 更保守；只有在明确不可达或显式 `clean` 请求下才适合移除
- `env/selections/` 必须保留当前 active choice；旧 selection snapshot 只有在确认没有 workspace
  或 user-level pointer 继续引用时，才可被保守回收
- 公开 install result、shared persisted truth 与 package-owned install/source/cache truth 始终不参与这套保留策略

这条保留规则的核心不是目录名，而是 reachability、selection ownership 和 rebuild cost 三者必须同时可解释。

## `env clean` / `env gc` 的结果也必须进入统一 envelope

维护动作如果只返回几行“删了什么”，IDE 和 CI 一样没法优雅消费。

因此 nextPas 继续要求：

- `env clean` / `env gc` 仍然返回同一类 `CommandResultEnvelope`
- result 至少能表达当前 action、affected scope、touched locator set、state delta 与 human summary
- 如果能够 cheap to compute，也应表达 reclaimed storage summary 或等价结果摘要
- 如果因为 scope 非法、artifact 正在使用或 selection 约束不允许删除而失败，仍然走统一 diagnostics/result contract

这条规则能保证当前 `env clean` 和 future `env gc` 对 CLI、IDE、automation 和 CI 来说都是同一种可消费对象。

## `env status` 不是 `doctor`，`env use` 也不是 package resolver

环境工具一旦不做分工，很快就会重新长成一团。

因此 nextPas 继续冻结：

- `env status` 只报告已解析 environment state，不负责健康判定
- `doctor` 继续解释为什么当前状态不能满足 build/test/pkg/doc/query
- `env use` 只改变 active selection，不参与 source package dependency resolution
- `pkg` 继续对 source graph 负责；`env` 继续对 distribution/binding/runtime selection 负责

这条分工的意义是：CLI、IDE、CI 和 automation 都能精确知道自己消费的是“状态”“诊断”还是“解析结果”。

## stage0 现在已公开 `build`、最小 `test`、`env status/use/sync/clean`、最小 `doctor`、最小 `query symbols` 与只读 `pkg inspect / pkg plan / pkg graph`，但不能阻断 future tools

`stage0-driver-specification.md` 已经明确：当前仓库已经公开
`nextpas build <source> --target linux-x86_64`，并把最小 harness-backed `test` surface、
`env status/use/sync/clean` surface、最小 `doctor` health inspection、最小 `query symbols`
semantic projection 与只读 `pkg inspect / pkg plan / pkg graph` package workflow projection 收进同一个
`nextpas` 产品壳。

这条最小范围必须保留，但 nextPas 同时冻结：

- 未来的 richer `pkg`、`fmt`、`doc`、richer `env`、richer `doctor`、richer `query` 不应再开辟另一套产品命令名
- `stage0` 当前是最小成功路径，不是长期 command architecture 的终点
- 当前 command parser、global options、result envelope 都应朝 future unified surface 收敛
- 当前 `env status/use/sync/clean` 只是最小 environment state projection、workspace-local selection
  mutation、workspace-local resolution cache mutation 与 selection/resolution sidecar cleanup，不等于 `env bootstrap`、download/unpack/install
  或完整 runtime SDK materialization；当前 `doctor`
  已经有最小 structured finding contract，但不等于完整
  package/workspace coherence taxonomy
- 当前 `query symbols` 只是 compilation-session-backed 的最小 CLI semantic query，不等于完整
  language service、LSP、open document overlay 或 IDE integration
- 当前 `pkg inspect / pkg plan / pkg graph` 只是 workspace-model-backed 的最小只读投影，不等于完整
  package manager、fetch/install/update/publish workflow 或 dependency resolution；其中 `pkg plan`
  是 install plan preflight 的专用只读面，它的 promotion gate 当前直接覆盖 package manifest
  ready path、workspace member lock-missing blocked path、package-free manifest-missing missing
  path、dependency-invalid blocked path、source-roots-missing blocked path、invalid-lock blocked path
  与 manifest-lock out-of-sync blocked path，并在 out-of-sync blocker 上公开 expected package
  与 actual lock entries detail；
  `pkg inspect / pkg graph`
  继续冻结 workspace descriptor root 解析到 member package 的
  ready 路径、source roots、declared dependencies 明细以及 package graph root/dependency nodes
  与 edges 的只读投影；canonical `nextpas.lock` 当前只读解析最小 v1 detail，公开
  `missing|ready|invalid`、format version、entries 与 issues，不写回 lockfile

也就是说，今天不做全命令树，不等于以后允许结构分叉。

## `CommandExecutionContext` 必须共享 workspace truth

如果 package manager 和其他工具真的要“方便使用、方便设计”，就不能每个工具自己解析一遍工作区。

因此 nextPas 冻结：

- tool-family command 先拿到同一份 `WorkspaceModel`
- package refs、target selection、artifact roots、source roots 不允许每个命令自己重建
- workspace-aware command 允许带局部 override，但 override 只作用在 context 上，不产生第二套持久真相
- package manager、formatter、query、doctor 的默认作用域都来自 workspace，而不是来自 shell 当前目录的偶然状态
- `env` family 可以在没有 workspace 时操作 user-level environment；但一旦存在 workspace，
  它也只能把 workspace-declared target/binding/runtime requirement 当作 context 输入，不能自建
  平行配置体系

这条规则直接承接 `workspace-specification.md`。

## package manager 必须是 command surface 的一级公民

nextPas 的 package manager 不应该被做成仓库边角工具。它必须被当成 unified developer tooling 的正式组成部分。

因此：

- `pkg` 或等价 family 应属于一级 verb family
- package workflow 必须共享 `WorkspaceModel`、`TargetSelection`、install roots 和 diagnostics contract
- package install / update / fetch / publish 如果未来存在，也必须进入同一条 result envelope 语义
- package manager 不单独定义第二套 config location、target naming 或 install layout

这样 people 在使用上更顺手，设计上也不会被工具孤岛拖累。
更细的 manifest/lock/install root、registry/source/mirror 与 package result contract
由 `package-workflow-specification.md` 定义。
更细的 workspace descriptor、package manifest、lockfile 和 root discovery 则由
`workspace-file-format-specification.md` 定义。

## formatter、doc、env、doctor、query 都应建立在共享核心之上

这一点很关键，因为现代开发环境最容易在这些工具上重新长出重复逻辑。

nextPas 要求：

- `fmt`
  - 共享 workspace roots、target-aware parsing 前提和 diagnostics policy
- `doc`
  - 共享 package/workspace truth，而不是重新扫一份项目结构
- `env`
  - 共享 `ToolchainBinding`、distribution layout、runtime SDK placement 与 diagnostics/result contract
- `doctor`
  - 共享 toolchain binding、sysroot、workspace config、distribution assumptions
- `query`
  - 共享 language service / semantic truth，而不是直接 scrape 文本输出

也就是说，这些工具可以各自有 specialization，但不应各自有第二份核心世界观。

## `env` 管 developer distribution，`pkg` 管 source package ecosystem

这条边界对 nextPas 特别重要，因为它决定整套环境会不会又退回 FPC 那种 config/make/repository
混写状态。

因此 nextPas 明确区分：

- `pkg` family 继续处理 source package graph、fetch/install/build/publish 与 registry metadata
- `env` family 继续处理 developer distribution、toolchain bundle、runtime SDK、channel policy
  与 activation state
- source package registry 不回答 “哪套 host linker/archiver/LLVM utility 应该被启用”
- environment channel metadata 也不回答 “某个 source package 的 semantic version graph 是什么”
- runtime SDK 与 bundled toolchain 继续不是普通 package dependency node；它们由
  `ToolchainBinding + Sysroot + distribution layout` 解释

这样 package workflow、cross compilation、LLVM backend 与 IDE integration 才能在同一个产品里
各司其职，而不是互相污染。

## `doctor` 负责诊断，`env` 负责收敛与物化

现代工具链里最容易混乱的一点，是把“检查环境”和“修改环境”塞进同一个模糊命令。

nextPas 不这么做。它要求：

- `doctor` 以只读 inspection 为主，解释当前环境为什么不适合 build/test/pkg/doc/query
- `env` 负责会改变环境状态的动作，当前最小集合先收敛到 `bootstrap`、`sync`、`use`，以及在确有
  维护需求时追加的 `clean` / `gc`
- 二者共享 `CommandExecutionContext`、`ToolchainBinding`、distribution assumptions 与
  `CommandResultEnvelope`
- `doctor` 可以给出“建议执行哪类 `env` action”的结构化 hint，但不取代 `env`

这条分工能直接降低 IDE、CI 与命令行之间的语义分叉。

## `CommandResultEnvelope` 必须保持结构化，而不是每个工具各拼一套文本

FPC 的独立工具生态说明了一个长期问题：一旦每个工具都有自己随意长出来的 usage、error 和 output 语义，
后面就很难组成统一产品体验。

因此 nextPas 要求：

- 所有 developer-facing command 尽量共享统一退出码语义
- tool status、diagnostics、artifact/result locator、human summary 应进入同一类 result envelope
- `build`、`test`、`pkg`、`doc`、`env`、`doctor` 的输出风格可以不同，但不应不同到无法统一消费
- CLI、IDE、future automation、CI 需要的结果字段，应优先来自结构化 envelope，而不是从纯文本倒推

这条规则会直接决定 future automation 和 IDE integration 是否优雅。

当前仓库已经有第一条真实 bridge：`tools/stage0/nextpas.pas` 在 `stage0 build` 的成功与失败路径上
都会输出 `command-envelope=<json>`。这不是最终 transport 定案，但它已经把结构化结果对象显式
暴露出来，让 `build/verify_local.sh`、CI 和 future IDE adapter 可以先站到同一份 truth 上。

`tests/run_all_tests.sh --filter <group>` 与 `--filter smoke` 现在也已经补上同样的
`command-envelope=<json>` bridge。当前 `tools/stage0/nextpas.pas` 也开始以 thin wrapper
公开 `nextpas test --filter <group>` / `--filter smoke`，并新增只读
`nextpas env status --target linux-x86_64 [--toolchain-binding <id>]`、workspace-local
`nextpas env use --target linux-x86_64 --toolchain-binding <id> --workspace <root>`、
`nextpas env sync --target linux-x86_64 [--toolchain-binding <id>] --workspace <root>`、
`nextpas env clean --target linux-x86_64 --workspace <root>` 与
`nextpas doctor --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`，以及
`nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`，所以 `build`、
`test`、最小 `env` state/selection/resolution/cleanup projection、最小 `doctor` health inspection 与最小 `query`
semantic projection、只读 `pkg inspect / pkg plan / pkg graph` package workflow projection 六类公开命令面都已经不再依赖 shell 调用方从纯文本里猜测
结果对象。

`build/verify_local.sh` 现在也会为 `verify-local` 自己输出同一类 `command-envelope=<json>`，
这样当前 `build`、`test`、`env`、`doctor`、`query`、`pkg`、`verify-local` 七条最小公开命令面已经都站到了同一类
result bridge 上。

## `env` 结果字段也必须是正式 contract，不是随手打印几行路径

环境命令最容易退化成“执行成功，然后打印一堆看起来像日志的路径”。nextPas 不接受这种做法。

因此 `env` family 的 `CommandResultEnvelope` 至少要能表达这些语义字段：

- 当前 action 是什么，例如 `bootstrap`、`sync`、`use`、`status`、`clean`、`gc`
- 当前 selected channel 与 distribution release 是什么
- 当前解析出的 `ToolchainBinding` / `Sysroot` / runtime SDK target set 是什么
- 这次动作涉及的 dist root、runtime SDK roots、distribution-local helper roots locator 是什么
- 这次动作对环境状态造成了什么变化，例如 `materialized`、`updated`、`switched`、`cleaned`、
  `reclaimed`、`unchanged`
- 当前 environment readiness 是什么，例如 `ready`、`degraded`、`incomplete`

这里真正要冻结的，不是 JSON key 拼写，而是结果语义：

- `env status` 也应返回同一类状态字段，而不是发明另一种私有输出风格
- `env use` / `env sync` 的成功结果必须既能表达“选中了什么”，也能表达“变更了什么”
- `env clean` / `env gc` 的成功结果必须既能表达“清了什么”，也能表达“哪些 shared truth 没被碰”
- IDE、CI 与 automation 需要的 machine-readable state 应直接来自 envelope，而不是去 scrape CLI 日志

只有这样，environment tooling 才算现代、优雅，而不是又回到历史 shell utility 的路子上。

当前 `tools/stage0/nextpas.pas` 已经先把这条 contract 的最小面落地：`nextpas env status`
会通过同一类 `command-envelope=<json>` 返回 target / binding / distribution / runtime state，
即使 runtime SDK 仍缺失，也会用 `environmentReadiness`、`environmentStatus`、
`runtimeSdkStatus`、`toolchainBindingStatus`、`distributionStatus` 与 `runtimeLibcPresent`
表达“不完整”，而不是把这类状态误报成命令执行失败。
`nextpas env use --target <target> --toolchain-binding <id> --workspace <root>` 则只写
`<workspace>/.nextpas/env/selections/<target>.toml`，并让后续
`env status --workspace <root>` 在没有显式 `--toolchain-binding` 时消费该 workspace-local
preferred binding selection。
`nextpas env sync --target <target> --workspace <root>` 则只刷新
`<workspace>/.nextpas/env/resolution/<target>.toml`，把当前 selection/default binding 解析出的
binding、distribution 与 runtime readiness 写成 machine-local resolution cache，并用
`envSyncChange` 表达本次是 `materialized`、`updated` 还是 `unchanged`；它仍不下载、不解包、不安装 runtime SDK，
也不修改 selection、descriptor、manifest 或 lockfile。
`nextpas env clean --target <target> --workspace <root>` 则只删除 workspace-local
`env/selections/<target>.toml` 与 `env/resolution/<target>.toml`，并用
`envCleanStatus`、`envCleanChange`、`envCleanSelectionPath`、
`envCleanResolutionPath` 与 `envCleanRemovedCount` 表达 cleanup 结果；它仍不删除
workspace descriptor、package manifest、lockfile 或公开 install result。

## `doctor` 必须是正式能力，不是 support 脚本

现代开发环境不该只在失败后说“环境坏了”，却不给正式入口检查环境。

因此 nextPas 冻结：

- environment / toolchain / workspace health inspection 应有正式 family，例如 `doctor`
- 当前最小 `doctor` 已经消费 `ToolchainBinding`、`Sysroot`、workspace root 与 distribution assumptions
- 它不直接做 build 替代，而是解释“现在为什么这个环境不适合 build/pkg/doc/query”
- 它的结果同样进入统一 result envelope

这条能力对 package manager 和 cross toolchain 尤其重要。

当前 `tools/stage0/nextpas.pas` 已经先落地最小只读 `doctor` surface：它复用 `env status`
的 target / binding / distribution / runtime truth，并额外输出
`doctorWorkspaceStatus`、`doctorToolchainBindingStatus`、`doctorStatus`、`doctorCheckCount`、
`doctorFindingCount` 与 `doctorFindings`。当前已冻结的代表性 finding 是
`doctor.runtime-sdk-missing`；当 workspace 缺少 package truth 时，还会投影
`doctor.package-workspace-missing`。当前 promotion gate 也覆盖 ready package workspace，确保
合法 package manifest/source root 不会被误报成 package truth 缺失；它还覆盖 workspace
descriptor root 解析到 member package 的 ready 路径，确保 developer tooling 不会把
workspace root 和 package root 混为一谈。package/workspace coherence 的更完整 health
taxonomy 仍应继续分批加固。

## `query` 必须消费 shared analysis，不得退化成文本扫描

semantic query 是 developer tooling 和 language service 的交界面。nextPas 不接受 CLI query
另写一套 parser、私扫目录，或从 build stdout 里反推 symbol truth。

因此 nextPas 冻结：

- `query` family 应消费 compiler / language-service shared analysis truth
- 当前最小 `query symbols` 已经消费 `ResolveWorkspaceModel(...)`、target facts、unit resolution
  与 semantic model
- 它不执行 backend 或 toolchain，也不把 query 成功误写成 build 成功
- 它的结果同样进入统一 result envelope

当前 `tools/stage0/nextpas.pas` 已经先落地最小只读 `query symbols` surface：
`nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]` 会通过
`TCompilationSession` 执行 syntax / resolution / semantic analysis，并输出
`queryKind=symbols`、`queryStatus=success`、`analysisSource=compilation-session` 与
`queryResultCount`，同时把同一份 semantic symbol graph 投影成 `querySymbols`。当前
`querySymbols[]` 既保留 `ownerUnitId` / `scopeId` / `typeId` 这类稳定 identity，也会从同一份
`TUnitGraph`、`TSemanticScope` 与 `TSemanticType` 补出可读的 owner unit、scope 和 type
metadata，方便 CLI、automation 与 future IDE adapter 直接消费，而不需要重扫源码或解析
build output。`queryScopes[]` 与 `queryTypes[]` 则把同一份 `TSemanticModel` 的 scope/type
graph 作为 normalized side tables 同步投影进 line output 与 result envelope，避免调用方在
`querySymbols[]` 之外维护第二套 `scopeId` / `typeId` lookup。`queryBindings[]` 则把同一份
`TSemanticModel` 的 source occurrence binding table 公开给 CLI、automation 与 future IDE
adapter；当前最小条目包含 `bindingId`、`kind`、`name`、`ownerUnitId`、`byteOffset` 与
`targetSymbolId`。`queryDefinitions[]` 继续把这些 binding 的 target symbol id join 回同一份
session-owned symbol/unit truth，公开 target `name` / `kind` / owner unit / source path /
byte offset，让调用方不需要在 query 外重扫源码或维护第二套 lookup。当前 binding surface
已经把 `Holder.Help();` 这类 selector/member callee 从 name-only lookup 中排除，避免误绑定
到 imported bare callable；同时先公开 `member-call` 的最小正向边界：direct class variable
receiver 的 method statement call（例如 `Worker.Run;` / `Worker.Run();` /
`Worker.SetValue(7);`）以及表达式参数里的 direct member function call（例如
`Halt(Worker.Add(1, 2));`）会绑定到 `TClass.Method` method symbol。带参数 method call
只用同名 method body declaration 的 argument count 做唯一匹配。完整 member lookup、
property accessor、record method、array/deref receiver、constructor binding、virtual/override
dispatch 与 type-based overload resolution 仍不属于当前 query contract。
这里的 `analysisSource` 故意不是 `language-service`，因为当前还没有正式
`LanguageServiceSession`、overlay、incremental invalidation 或 protocol adapter。

## design for tools 比 implement all tools 更重要

第一阶段不要求马上把所有工具做出来，但要求工具长出来时不会破坏架构。

因此：

- 现在先冻结 unified command surface
- 再冻结 workspace/toolchain/language service/harness 这些共享核心
- 然后 future tools 逐个挂上去

顺序不能反过来。否则先长出一堆工具，再谈统一，代价会非常高。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 已承诺 `build`，并补上 thin-wrapped `test`、只读 `env status`、只读 `doctor` 与
    compilation-session-backed `query symbols`
  - 但统一 command surface 的对象边界必须先冻结
- `stage1`
  - 开始把 `doctor`、`env`、`test`、`query` 或受控的 `pkg` surface 接到共享核心上
  - 重点是统一 context 和 result envelope，而不是命令数量
- `stage2`
  - 当 compiler、workspace、toolchain、language service 和 distribution 都稳定后，
    nextPas 才适合进入更完整的 package/doc/format tooling 波次

## 第一阶段非目标

- 不把这份规范写成“现在立刻实现全部工具”
- 不为每个工具单独冻结一套私有 CLI 风格
- 不把 package manager、formatter、doc、doctor 再拆成彼此独立的产品线
- 不把 installer、channel/bootstrap、runtime SDK 管理再拆成第二个产品壳
- 不让 command surface 反向拥有 compiler / workspace / toolchain / language service 真相
- 不把当前最小 `stage0` build 路径误写成已经完成 unified developer tooling

第一阶段真正要交付的是：一份把 nextPas developer tools 写成“统一产品命令面 + 共享核心”的正式架构规范。
