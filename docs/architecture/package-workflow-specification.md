# nextPas package workflow 规范

用这份规范定义 nextPas 长期 package workflow 的稳定边界。它回答的不是“第一阶段先实现几个
`pkg` 子命令”，而是“package manifest、resolution、fetch/install/cache、target-aware
placement 和 diagnostics/result contract 应该怎样建立在统一 workspace truth、
toolchain control plane 与 distribution layout 之上，才能让 nextPas 的 package manager
像现代开发环境那样好用、好扩展、好验证，而不是重复 FPC 里分散在 config、repository
和 utility 里的历史耦合”。

这份文档和 `packages-specification.md`、`workspace-specification.md`、
`workspace-file-format-specification.md`、`developer-tooling-specification.md`、
`toolchain-specification.md`、`distribution-layout-specification.md`、
`ide-specification.md` 一起工作。前者们分别冻结包生态边界、shared workspace truth、
persisted file layer、统一 command surface、toolchain control plane、公开安装布局与
future IDE workbench；这里冻结 package workflow 本身。

## 先看 FPC 真源码已经把 package workflow 散在什么地方

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/fppkg/src/pkgfppkg.pp`
  - `TpkgFPpkg` 同时持有 options、compiler options、repository list、mirror state、
    configuration filename
  - `InitializeGlobalOptions` 会在 local/global config 之间查找或生成 `fppkg.cfg`
  - `DetermineSourcePackage`、`GetInstallRepository`、`GetRemoteRepositoryURL` 分别处理
    source package 选择、install repository 选择与 remote transport URL 选择
  - `GetInstallRepository` 会按 command line、source repository、global config、
    installed repository fallback 的顺序决定安装目标
  - `PackageBuildPath`、`GetRemoteRepositoryURL` 说明 build root、remote source、
    compiler version 都会影响 package 行为
- `/home/dtamade/projects/fpc/packages/fppkg/src/pkguninstalledsrcsrepo.pp`
  - `GetBaseInstallDir`、`GetConfigFileForPackage`、`GetBuildPathDirectory` 直接把 source path、
    build path、install dir 和 `CompilerTarget` 绑在一起
  - `AddPackagesToRepository` 还会在扫描 source repository 时临时生成 manifest
- `/home/dtamade/projects/fpc/packages/fppkg/src/pkgcommands.pp`
  - 下载 available packages 前会先根据 `RemoteRepository='auto'` 决定是否刷新 mirrors，
    再经由 `GetRemoteRepositoryURL` 生成真正下载地址
  - install 流程里会先 `DetermineSourcePackage`，再 `GetInstallRepository`，必要时还会针对
    `URLPackageName` 重新加载 manifest
  - `P.Name`、`P.Author`、`P.Version.AsString`、`P.License`、`P.Description`、`P.Dependencies`
    会直接进入 package info / dependency install workflow
  - `P.Dependencies[i].PackageName`、`MinVersion`、`OSes`、`CPUs` 说明 package identity、
    version requirement 与 compatibility constraint 本来就是 workflow 输入，而不是附属文案
- `/home/dtamade/projects/fpc/packages/fppkg/fpmake.pp`
  - `P.SourcePath.Add('src')` 说明 source roots 也是 package declaration 的正式组成部分
- `/home/dtamade/projects/fpc/utils/fppkg/fpmake.pp`
  - `Description := 'Free Pascal package repository utility.'`
  - 说明 package manager 在 FPC 里是正式工具，但它作为独立 utility 生长
- `/home/dtamade/projects/fpc/utils/fpcmkcfg/fpcmkcfg.pp`
  - builtin template 同时覆盖 `fpc.cfg`、`fp.ini`、`fppkg.cfg` 和 default compiler template
  - `GetDefaultLocalRepository`、`GetDefaultLocalBasepath`、`GetDefaultCompilerConfigDir`
    说明 config location、repository root、compiler template 也是 package workflow 的一部分

这些事实组合起来说明：

- FPC 不是没有 package workflow
- 它的问题是 manifest、repository、config、install placement、mirror 和 target-specific
  naming 分散在不同 utility、不同 config 和不同对象里
- 当前源码取证没有展示出一条“workspace truth -> package workflow -> install layout ->
  IDE/automation” 的统一控制线

nextPas 要做现代、优雅、高性能的 Pascal 开发环境，就必须把这条线主动抽出来。

## package workflow 不是 `packages/` 目录的别名，也不是边角 utility

`packages-specification.md` 已经冻结了包生态边界，但那份文档回答的是“哪些包何时进入范围”，
不是“包工作流怎样运行”。

nextPas 在这里进一步冻结：

- `packages/` 继续表达生态范围与推进分层
- package workflow 负责表达 workspace package、external dependency、fetch/build/install
  和 publish 类 action 的统一控制面
- `pkg` family 属于 `nextpas` 的一级 command surface，不是仓库角落里的独立小程序
- IDE package actions、CLI package actions 和 future automation 必须共享同一条 workflow truth

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| nextpas pkg / IDE package actions / automation       |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| CommandIntent(pkg-*) + CommandExecutionContext       |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| WorkspaceModel + PackageRef + TargetSelection        |
| + ArtifactRootSet                                    |
+------------------------------------------------------+
                        |
        +---------------+----------------+------------------+
        |               |                |                  |
        v               v                v                  v
+---------------+ +---------------+ +------------------+ +-------------+
| PackageManifest| | PackageLock   | | PackageInstallPlan| | diagnostics |
+---------------+ +---------------+ +------------------+ +-------------+
                        |
                        v
+------------------------------------------------------+
| ToolchainBinding + units/<target> / lib / share      |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| CommandResultEnvelope + doctor                        |
+------------------------------------------------------+
```

这张图的硬约束是：

- package workflow 站在统一 command surface 之下，不另起一套产品壳
- workflow 继续消费已冻结的 `WorkspaceModel`、`PackageRef`、`TargetSelection`、
  `ArtifactRootSet`
- install placement、tool invocation 和 diagnostics 继续服从已有 control plane

## 只新增三个 workflow 对象，不重新发明第二个世界观

为了保持边界清楚且不额外膨胀，nextPas 在 package workflow 上只新增三个正式对象：

- `PackageManifest`
- `PackageLock`
- `PackageInstallPlan`

| 对象                 | 负责什么                                                                                                                                                             | 明确不负责什么                                         |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `PackageManifest`    | 表达 workspace member 的 package identity、declared dependency intent、optional compatibility hint、source provenance hint 与 package-local render asset declaration | 不保存已解析图，不替代 workspace truth                 |
| `PackageLock`        | 表达一次已解析 graph 的 version/source provenance/target-sensitive resolution snapshot                                                                               | 不重新定义 target naming，不充当 registry              |
| `PackageInstallPlan` | 把 fetched source、build/cache root、render bundle result 与 install root 映射成一次可执行的 package placement                                                       | 不重新定义 `ToolchainBinding`，不发明第二套 layout key |

这里最重要的边界是：

- `CommandIntent` 继续表达用户动作，例如 package fetch/install/update/graph/publish 类 intent
- `CommandExecutionContext` 继续持有 workspace、target、toolchain 和 diagnostics policy
- `PackageManifest`、`PackageLock`、`PackageInstallPlan` 只是把 package workflow 必须新增的三类 truth
  补齐，而不是再造一层大而全平台

当前仓库里的最小真实落点已经先有了 compiler-owned truth skeleton：
`compiler/frontend/np_package_workflow.pas` 现阶段只持有 `TPackageManifestTruth`、
`TPackageLockTruth`、`TPackageInstallPlanTruth` 与 `TPackageWorkflowTruth`，并且只消费
`np_package_manifest.pas` 已有的 `TPackageManifestInfo`。这批 reality 先冻结四件事：

- manifest truth 可以如实投影 `ready|missing`、manifest path、package root、package name 与
  source root count
- lock truth 当前只冻结 canonical path `<workspace>/nextpas.lock` 与 `status=deferred`
- install plan truth 当前只冻结 workspace/package provenance 与 `status=deferred`
- 这批刻意不执行 registry lookup、fetch、dependency solver、install placement 或 lockfile write

## repository、registry、source、mirror 必须分角色，而不是混成一个词

FPC 的 `InstallRepository`、`SourceRepositoryName`、`RemoteRepository`、`LocalMirrorsFile`
已经说明，这几个概念如果不分开，后面 install 与 resolution 会越来越难解释。

nextPas 在这里冻结：

| 角色         | 正式含义                                                                  | 明确不等于什么                                      |
| ------------ | ------------------------------------------------------------------------- | --------------------------------------------------- |
| `registry`   | authoritative metadata/index source，用来解析 package identity 与版本空间 | 不等于 fetched source tree，不等于 install root     |
| `source`     | concrete package contents，例如 workspace-local tree、archive、checkout   | 不等于 registry，也不等于 mirror                    |
| `mirror`     | transport replica 或优先级切换入口，只改变访问路径                        | 不改变 package identity，不改写 manifest/lock truth |
| `repository` | workspace-visible collection 或 install boundary，例如 installed set      | 不单独定义 target truth，不单独定义 config world    |

因此：

- manifest 和 lock 里记录的是 package identity 与 provenance，不是“最后碰巧走了哪个 mirror”
- mirror 选择可以影响下载路径，但不应改变解析图的语义 identity
- repository/install 边界要落回 `WorkspaceModel` 与 `ArtifactRootSet`，不能只存在于 CLI 临时分支里
- CLI、IDE 和 automation 对这些词的理解必须完全一致

## manifest truth、lock truth 和 workspace truth 必须彻底分开

现代 package workflow 最容易退化的地方，就是把“项目声明想要什么”“本次解析得到了什么”
和“当前工作区里实际有什么”混成一个文件或一个对象。

nextPas 不接受这种混法：

- `PackageManifest`
  - 表达 workspace member 的声明性依赖、identity、source roots、render asset declaration
    和 low-entropy source provenance hint
- `PackageLock`
  - 表达已解析 graph 的稳定结果、source provenance、selected versions 和 target-sensitive snapshot
- `WorkspaceModel`
  - 表达当前 project roots、package membership、source roots、artifact roots、default target

这三层必须保持清楚的职责：

- manifest 说“项目想要什么”
- lock 说“这次解析确认了什么”
- workspace 说“现在整套开发环境实际把什么纳入控制面”

也因此：

- IDE 不允许偷偷保存一份自己的 package graph 或 private lock
- CLI 不允许靠当前工作目录猜出 package membership
- generated metadata 可以存在，但它属于 artifact roots，不属于 source roots
- 第一阶段可以先不冻结 manifest/lock 的最终文件语法，但它们的语义角色必须先冻结

更细的 canonical filenames、root discovery 和文件层 ownership 由
`workspace-file-format-specification.md` 定义。

## `PackageManifest` 必须把 source package truth 和 `RenderAssetSourceSet` 放在同一份声明里

`render-asset-pipeline-specification.md` 已经明确：render-side asset truth 不能靠目录扫描或
preview 私有缓存补出来。package workflow 在这里继续把这条边界写死：

- package-local shader、icon/image、font input、theme/effect input 继续通过 `PackageManifest`
  声明，不允许退回 post-build scan
- manifest 里表达的是 logical asset family、package-relative input、optional preprocessing hint
  与 export/install intent，而不是 target-specific bundle 名称
- package dependency 或 workspace preview 如果要引用这些资产，只能经由 package identity +
  declared asset family，而不是越过 manifest 直接抓文件系统路径
- asset declaration 的存在不改变 manifest 的核心身份：它仍然是 author-owned declaration，
  不是 install result、cache entry 或 tool invocation plan

这样设计的意义很直接：

- package manager、IDE preview、component gallery 和 shipped app 看到的是同一份 package asset truth
- GUI framework 不会在 package workflow 旁边再长一套“资源注册表”
- workspace/package/toolchain 三层边界能继续保持清楚

为了让这份声明能被 workflow 直接消费，而不是留给实现时再猜，当前 package workflow
至少要理解这组 manifest fields：

| manifest field                    | workflow 怎么消费                                                                       | 明确不意味着什么                                           |
| --------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `package.name`                    | 参与 package identity、resolution key、workspace package view 与 install explainability | 不等于 install root 路径猜测或目录名约定                   |
| `package.version`                 | 参与 version selection、publish/provenance 记录与 dependency check                      | 不等于 compiler version、target suffix 或 cache revision   |
| `sources.roots`                   | 参与 local source discovery、analysis scope 与 build input 集合                         | 不包含 artifact root、cache root 或 install root           |
| `sources.public_units`            | 参与 package public surface、install result explainability 与 IDE package outline       | 不等于完整 compiled unit graph dump                        |
| `[dependencies]`                  | 参与 declared dependency graph、version requirement 与 install planning                 | 不等于 resolved graph、mirror choice 或 installed state    |
| `compatibility.targets`           | 参与 candidate filtering、early reject 与 package discoverability                       | 不等于 target registry、`TargetFacts` 或 resolved snapshot |
| `provenance.kind`                 | 参与 source family hint、publish intent 与 lockfile declared provenance projection      | 不等于 resolved URL、mirror choice 或 install repository   |
| `provenance.registry`             | 在 `kind = "registry"` 时参与 logical registry selection                                | 不等于 transport endpoint、mirror URL 或 content locator   |
| `render_assets[*].family`         | 参与 package-local asset identity、install result explainability 与 replay lookup       | 不等于 compiled bundle filename                            |
| `render_assets[*].kind`           | 参与 preprocessing route 与 runtime-facing asset contract 选择                          | 不等于 tool executable choice                              |
| `render_assets[*].inputs`         | 参与 source dependency fingerprint、incremental invalidation 与 cache reuse 判断        | 不允许越过 package root 直接抓任意 host path               |
| `render_assets[*].preprocess`     | 进入 `ToolInvocationPlan` 的 declarative hint，帮助决定 atlas/compile/metadata 路线     | 不允许直接写成 shell command 或 post-build hook            |
| `render_assets[*].install_intent` | 决定结果落向 runtime-private 还是 shared-content 语义，再由 install layout 映射落点     | 不直接写死最终 `lib/` / `share/` 子路径                    |

换句话说，workflow 消费的是结构化 declaration，而不是“某个目录里大概有这些资源”。

## dependency requirement 与 compatibility hint 必须先收成 deterministic contract

如果这两部分继续保持口头约定，package workflow 很快就会重新退回“resolver 自己懂、IDE 自己猜”。

因此 nextPas 先冻结：

- dependency requirement string 当前最小支持 `=`、`>`、`>=`、`<`、`<=`
- 多个 comparator 用逗号表达 intersection，例如 `>=0.1.0, <0.2.0`
- 第一阶段不要求 union range、feature flag、optional dependency、target-specific dependency table
  或复杂 solver annotation
- compatibility hint 当前最小只推荐 `[compatibility].targets = [...]`
- compatibility hint 缺省时，package 继续按 target-neutral declaration 处理
- 一旦声明 compatibility hint，workflow 可以在 resolution / install / doctor 之前先做 early reject
  或 candidate filter
- compatibility hint 继续只引用已经存在的 target id；真正 target semantics 仍然来自
  `TargetSelection + TargetFacts`

这条 contract 的意义很直接：

- 它能覆盖 FPC 里已经真实存在的 `MinVersion`、`OSes`、`CPUs` 这类 workflow 输入
- 它又不会把 nextPas 的 target model 重新打散成 package manager 私有枚举

## manifest provenance hint 必须保持低熵声明，resolved provenance 继续留给 lock

FPC 现有实现已经证明，source family、remote transport、install repository 和 mirror policy
如果揉成一团，package workflow 就会越来越难解释。

nextPas 在这里先冻结：

- `PackageManifest` 里的 `[provenance]` 只表达 author-owned source family hint，例如
  `workspace`、`registry`、`archive`
- 当 `kind = "registry"` 时，manifest 最多再给出 `registry = "default"` 这种 logical registry
  name，帮助 resolver 选择 authoritative metadata 空间
- workspace member 如果省略 `[provenance]`，workflow 可以按 manifest path 与 workspace membership
  把它解释为 `workspace`
- manifest provenance hint 不写 remote URL、不写 mirror、不写 content digest，也不写
  install repository、toolchain binding 或 target snapshot
- `mirror` 和具体下载地址只属于 fetch policy / execution context；mirror 切换不能改写 package
  identity，也不能把 manifest 变成 transport config
- `PackageLock` 必须把 `declared_provenance` 和 resolved `source` / `content_locator` /
  `content_digest` 并列保存，保证 declaration 与实际解析结果都可解释

这条边界直接回应 FPC 当前几处真实耦合：

- `pkgcommands.pp` 会先处理 `RemoteRepository='auto'` 与 mirror 下载，再生成实际 packages URL
- `pkgfppkg.pp` 继续把 `DetermineSourcePackage`、`GetInstallRepository`、`GetRemoteRepositoryURL`
  拆成不同职责
- `pkgcommands.pp` 还允许 `URLPackageName` 进入流程，说明 author intent 和 resolved fetch source
  不是同一层对象

换句话说，nextPas 的 manifest 不是 mini downloader config，也不是 install policy 文件；
它只保留 package author 真正该负责的 provenance hint。

## `PackageLock` 必须保留 requirement、provenance 和 target snapshot 的可解释投影

manifest 负责表达“想要什么”，那 lock 就必须能明确回答“这次到底解析成了什么”。

因此 nextPas 要求 `PackageLock` 至少保留：

- target snapshot key
- selected package identity / version
- declared provenance hint projection
- resolved source provenance
- content locator / digest 或等价 replay evidence
- declared dependency requirement 与 resolved selection 的并列投影

这条规则有三个直接目的：

- `doctor` 能解释“为什么这次锁到了这个版本”
- CI / automation 能在同一 target snapshot 上做 deterministic replay
- IDE package view 能展示 declaration 和 resolved result 之间的差异，而不是只剩一个版本号

同时继续明确：

- `PackageLock` 不拥有 install root、cache root 或 tool executable path
- `PackageLock` 不复制完整 manifest、完整 target registry 或完整 toolchain binding
- `PackageLock` 可以保留 `declared_provenance` 这类 machine-owned projection，但不拥有 mirror
  preference 或 install repository policy
- 它只保留 resolution replay 真正需要的投影，而不是再长成第二份 package database

## fetched source roots、build roots、cache roots、install roots 必须各自有正式语义

`pkguninstalledsrcsrepo.pp` 已经说明，source path、build path、install dir 只要一旦混在一起，
package 行为就会越来越依赖约定俗成目录。

nextPas 要求 package workflow 继续建立在 `ArtifactRootSet` 之上，但把角色写得更细：

- fetched source root
  - 放置下载或 checkout 的 dependency source
  - 可复用，但不属于公开发行布局
- build/work root
  - 放置一次 package build、manifest generation、render asset preprocessing 与 temporary sidecar assets
  - 可以是 ephemeral
- reusable cache root
  - 放置 archive cache、metadata cache、resolution cache、package-level reusable artifacts 与 reusable render bundles
- install roots
  - 放置对 workspace 或发行布局真正可见的安装结果

并且继续保持一条很重要的 ownership 边界：

- package cache / source / install 语义继续由 `pkg` workflow 解释
- future `env clean` / `env gc` 只能维护 env-owned distribution/runtime/toolchain cache，不接管
  package resolution cache、fetched source root 或 package install truth

并且公开安装语义继续服从 `distribution-layout-specification.md`：

- public units 落到 `units/<target>/`
- private helper libraries 或 package-private support assets 落到 `lib/`
- docs、examples、shared assets 落到 `share/`

这条边界很关键，因为 nextPas 不允许 package workflow 为了“方便实现”再发明第二套安装布局。

## `PackageInstallPlan` 必须显式承接 `RenderAssetSourceSet -> RenderAssetBundle`

如果 package workflow 想和 future GUI framework 共用同一套现代控制面，它就必须显式解释
render bundle 在 fetch/build/cache/install 里的归属，而不是把这件事留给“后面某个 UI 工具”。

因此 nextPas 冻结：

- `PackageInstallPlan` 可以消费 package-local `RenderAssetSourceSet`，但它产出的始终是 install/cache
  decision，不是第二份 asset declaration
- build/work root 可以容纳 shader compile sidecar、atlas temp file、font preprocessing temp result
  或等价中间物，但这些都不进入 source roots
- reusable cache root 可以持有 target-aware `RenderAssetBundle` cache、asset digest/index 和 replay metadata，
  以便同 target 下复用已验证结果
- install roots 必须把 target-private render bundle 放进 `lib/nextpas/ui/render/` 或等价私有 `lib/`
  子树，把 shared docs/examples/theme payload 放进 `share/nextpas/ui/` 或等价共享 `share/` 子树
- `PackageInstallPlan` 不得把 compiled asset output 回写到 manifest，也不得要求 UI package 自己维护
  install script 或 copy script

也就是说，package workflow 在这里负责的是“把 package declaration 变成正式 placement”，而不是
重造一套 GUI asset world。

## target-aware package workflow 必须从 `TargetSelection` 出发，而不是靠临时 flag 拼出来

FPC 的 `GetConfigFileForPackage` 会把 `CompilerTarget` 写进 config filename，
`GetRemoteRepositoryURL` 会把 compiler version 写进 remote archive path。这已经说明：
package workflow 从来不是 target-neutral 的。

因此 nextPas 冻结：

- resolution、fetch、build、install 都消费同一份 `TargetSelection`
- package install result 继续按 target key 落地，例如 `units/<target>/`
- target-sensitive render bundle 也继续绑定同一份 `TargetSelection`；package workflow 不为 GUI 资产再造
  第二套 host/target 矩阵
- command line 可以临时 override target，但 override 只作用在 `CommandExecutionContext`
- package workflow 不重新定义 target naming；target 事实仍然来自 `TargetFacts`
- cross compilation 时，host/target、sysroot 和 tool discovery 仍由 `ToolchainBinding`
  负责，`pkg` 只是消费它

这样 future cross-target package install、IDE dependency analysis 和 CLI build 才能继续收敛。

## publish contract 必须围绕 immutable source package release，而不是安装残留物

FPC 现有 packager 已经把这件事暴露得很明显：

- `utils/fppkg/README.txt` 直接把 package 描述成“可 compile、install、zip，并生成 repository
  可导入 manifest”的单元
- 同一份 README 也直接给出 `fpmake archive` 再 `fppkg build *.zip` 的路径，说明 archive 是 source
  package release，不是 install result
- `pkgfppkg.pp` 里的 `PackageRemoteArchive` 又说明远端获取对象最终仍是 archive 或等价 source payload，
  而不是某个已安装 `units/` 树
- `utils/fpcm/fpcmake.ini` 里的 `Package.fpc`、installed units、libraries 和 shared files 则说明
  install tree 是另一层派生结果

因此 nextPas 在这里先冻结：

- `publish` 的 canonical input 是 author-owned package declaration：
  `nextpas.package.toml`、declared source roots，以及允许进入公开分发的 docs/examples/shared assets
- `publish` 的 canonical output 是 immutable source package release；它至少绑定 package identity、
  version、declared provenance family 与 content digest
- source package release 可以物化为 archive、content-addressed snapshot 或等价 registry object，
  但它的语义始终是“可重放的 source truth”
- publish artifact 不包含 `units/<target>/`、linker output、private runtime helper install result、
  target-private `RenderAssetBundle`、workspace-local artifact cache 或 `nextpas.lock`
- install result 继续是 `source package release + TargetSelection + ToolchainBinding + Sysroot`
  的派生结果，不反向改写 publish truth
- manifest 可以包含 publish metadata，但不能把 toolchain binding、remote transport URL、
  mirror choice 或 host-private path 写成 publish identity

这条边界的直接收益是：

- package identity 与 host/target/toolchain 不再绑死
- registry 可以稳定保存 declaration 与 source digest，而不是替每个 target 存一份 install 树
- future IDE、CI 与 automation 可以先共享 source release truth，再各自派生 install/build 结果

同样重要的是：这条规则没有提前承诺 binary package stability。future 如果真的需要 binary package、
SDK bundle 或 prebuilt runtime bundle，它们也只能是额外分发物，不能替代 canonical source release。

## registry metadata 必须继续只回答 source package release，不接管 SDK 或 toolchain release

modern Pascal 环境当然不只会发布 source package。nextPas 长期也会有 target runtime SDK、
bundled toolchain、甚至更完整的 developer distribution。

但 package workflow 在这里要先把边界守住：

- registry metadata 先只回答“哪些 package source release 存在、版本是什么、source truth 指向哪里”
- registry object 可以投影 package identity、version、declared provenance、compatibility hint、
  source release locator 与 content digest
- target runtime SDK、prebuilt runtime payload、bundled toolchain payload 不属于 package dependency
  graph 的普通节点
- `PackageManifest` 不能把 toolchain bundle、runtime SDK bundle 或 host-private executable path
  写成普通 dependency
- workspace 如果未来需要管理 compiler/runtime/toolchain channel，也应走
  `WorkspaceModel + TargetSelection + ToolchainBinding` 这条控制线，而不是把这些对象塞进
  package registry schema

这条规则的意义很直接：

- package resolver 仍然只做自己该做的事：解析 source package graph
- runtime / SDK / toolchain 版本管理可以独立演进，而不把 package lock 搞成第二份环境数据库
- IDE、automation 和 future `env` workflow 可以共享同一份 package truth，同时再叠加各自需要的
  SDK / toolchain 选择结果

## 高性能的 package workflow 不能靠“每次都全量重扫”

既然 nextPas 要现代、高性能，package workflow 就不能默认把每次操作都做成一次全仓扫描。

第一阶段先冻结这些性能方向：

- manifest、lock、`PackageRef` 与 install state 要能 cheap to diff
- registry metadata cache 和 fetched source cache 分离，避免一次变化让所有层同时失效
- target change 只使 target-sensitive resolution/build/install 失效，不强迫所有 package 重新抓取
- target change 只使 target-sensitive `RenderAssetBundle` cache 与 install placement 失效，不迫使
  source declaration 重新生成
- mirror 切换如果不改变 provenance，就不应导致整个 lock graph 失效
- package-generated artifacts 必须与 source roots 分离，避免 language service 和 IDE 热路径误扫

这几条不是优化建议，而是 package workflow 想保持现代、优雅的基础前提。

## `pkg` 结果必须进入统一 envelope，`doctor` 必须能解释 package health

如果 package manager 想成为 nextPas 的一级能力，它的结果就不能继续像历史 utility 那样
各自拼 usage 和 error 文本。

因此 nextPas 要求：

- package workflow 结果进入同一类 `CommandResultEnvelope`
- result 至少能表达 affected package set、resolved graph locator、install/cache locator、
  diagnostics summary 和 human-readable outcome
- package failure 应继续进入统一 diagnostics contract，例如 manifest parse failure、
  resolution failure、fetch failure、install placement conflict、toolchain precondition failure
- `doctor` 必须能检查 manifest/lock coherence、registry or mirror reachability、install root health、
  target/toolchain compatibility 和 workspace package state

这条规则会直接决定 future IDE package view、CI automation 和 local diagnostics 是否优雅。

## CLI、IDE 和 automation 只能共享同一条 package workflow truth

nextPas 的 package manager 不只是 CLI 需求。长期 IDE、future automation 和 workspace tooling
都要靠它。

因此关系固定如下：

- CLI
  - 通过 `nextpas` unified command surface 发起 package intent
- IDE
  - 只显示或操作 package workflow 的结构化结果，不拥有私有 dependency truth
- automation / CI
  - 消费同一类 `CommandResultEnvelope` 与 diagnostics，而不是 scrape 文本输出
- workspace
  - 继续持有 package membership、source roots、artifact roots、target defaults

换句话说，package workflow 可以有多种前端，但不能有多种世界观。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 当前不承诺完整 `pkg` family，也不承诺 manifest/lock file format
  - 当前最小 reality 只先落地 non-executing package workflow truth skeleton
  - 但 package workflow 的对象边界、install root 角色与相邻控制面必须先冻结
- `stage1`
  - 可以开始把受控的 package fetch/install/graph workflow 接到统一 command surface
  - 重点是复用 `WorkspaceModel`、`TargetSelection`、`ToolchainBinding` 和 result envelope
- `stage2`
  - 当 compiler、workspace、toolchain、language service、GUI framework 和 IDE 都稳定后，
    更完整的 package UX、publish workflow 和 IDE package actions 才值得进入正式波次

这条阶段关系的重点不是“以后也许会有 package manager”，而是“以后 package manager 也不能绕开
已冻结的 shared core”。

## 第一阶段非目标

- 不把这份规范写成“现在立刻实现完整 package manager”
- 不在这里冻结最终 manifest file syntax、lockfile syntax 或 registry protocol
- 不把 mirror 选择写成 package identity 的一部分
- 不让 package workflow 重新定义 target naming、toolchain discovery 或 distribution layout
- 不把 binary package stability 或 `ABI compatibility` 写成当前既成事实
- 不让 IDE、CLI、automation 各自维护第二份 package graph

第一阶段真正要交付的是：一份把 nextPas package workflow 写成“统一 command surface +
shared workspace truth + target-aware install layout”的正式架构规范。
