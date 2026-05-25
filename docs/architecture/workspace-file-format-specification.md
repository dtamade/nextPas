# nextPas workspace 文件格式规范

用这份规范定义 nextPas 长期 workspace persisted truth 的稳定边界。它回答的不是
“以后文件名起得像不像某个现成工具”，而是“workspace descriptor、package manifest、
lockfile、root discovery、target default persistence 和 generated metadata 应该怎样落盘，
才能让 CLI、IDE、package workflow 和 automation 共享同一份文件层真相，而不是重复 FPC
里 `.pri`、`fppkg.cfg`、临时 manifest 和 target-specific config filename 的分裂结构”。

这份文档和 `workspace-specification.md`、`package-workflow-specification.md`、
`developer-tooling-specification.md`、`ide-specification.md`、
`toolchain-specification.md`、`distribution-layout-specification.md` 一起工作。前者们分别冻结
workspace control plane、package workflow、统一 command surface、future IDE workbench、
toolchain control plane 与公开发行布局；这里冻结这些真相怎样进入稳定文件层。

## 先看 FPC 真源码已经把 workspace file / config / manifest 分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/ide/fpintf.pas`
  - `SetPrimaryFile` 会读取 `.pri` 文件
  - 文件里只保存 `PrimaryFileMain`、`PrimaryFileSwitches`、`PrimaryFilePara` 这类几行文本
  - 说明 project state 更像 editor-hosted ad-hoc file，而不是正式结构化 workspace truth
- `/home/dtamade/projects/fpc/packages/fppkg/src/pkgfppkg.pp`
  - `InitializeGlobalOptions` 会在 local/global config 之间查找或生成 `fppkg.cfg`
  - package 行为会被 config discovery 顺序直接影响
  - 说明 package/workspace truth 被拆进独立 config world，而不是一套统一 project file contract
- `/home/dtamade/projects/fpc/packages/fppkg/src/pkguninstalledsrcsrepo.pp`
  - `GetConfigFileForPackage` 会生成带 `CompilerTarget` 的 package config filename
  - `AddPackagesToRepository` 还会在扫描 source repository 时重新生成 manifest
  - `GetBaseInstallDir`、`GetBuildPathDirectory` 又把 source/build/install 混在一起
  - 说明 file truth、target truth 和 artifact truth 没有被稳定分层
- `/home/dtamade/projects/fpc/packages/fppkg/fpmake.pp`
  - `P.Author`、`P.License`、`P.HomepageURL`、`P.Description` 与 `P.SourcePath.Add('src')`
    说明 package metadata 和 source roots 本来就是 author-owned truth
  - 但这些真相当前主要寄存在 `fpmake.pp` 与后续 manifest generation 路径里，而不是稳定、
    统一的 package manifest file
- `/home/dtamade/projects/fpc/utils/fpcmkcfg/fpcmkcfg.pp`
  - builtin template 同时覆盖 `fpc.cfg`、`fp.ini`、`fppkg.cfg`
  - 说明 config generation 本身又长成一条独立 utility 路线

这些事实组合起来说明：

- FPC 生态不是没有 project/workspace/package files
- 它的问题是这些文件职责分散在 IDE 私有文件、compiler config、package config、generated
  manifest 和 repository 习惯里
- 当前源码取证没有展示出一条“workspace truth -> persisted files -> CLI / IDE / automation”
  的正式控制线

nextPas 既然要现代、优雅、高性能，就必须把这条线主动抽出来。

## 文件层必须是 persisted truth，不是某个宿主的私有缓存

nextPas 在这里先冻结一个明确立场：

- workspace file layer 是 developer-facing persisted truth
- CLI、IDE、automation、future `pkg` workflow 都要消费同一套 root discovery 和同一组正式文件
- persisted truth 先表达 workspace、package 和 resolution 的边界，再派生 UI state、command
  defaults 和 package actions
- editor-local cache、preview snapshot、language-service index、generated sidecar metadata 都不属于
  source truth

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| CLI / IDE / automation / future pkg surfaces         |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| WorkspaceDiscoveryPolicy                             |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| WorkspaceDescriptorFile                              |
| + PackageManifestFile set                            |
| + PackageLockfile                                    |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| WorkspaceModel / PackageRef / TargetSelection        |
| / ArtifactRootSet / PackageManifest / PackageLock    |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| ToolchainBinding / LanguageService / IDE / pkg       |
+------------------------------------------------------+
```

这张图的硬约束是：

- 先发现文件层，再恢复结构化对象
- workspace、package 和 lock 的持久化角色必须彻底分开
- CLI、IDE 和 automation 不允许各自再长一份私有 project truth

## 只冻结四个文件侧对象，不把文件层写成万能黑箱

为了保持边界清楚且不过度膨胀，nextPas 在文件层只新增四个正式对象：

- `WorkspaceDiscoveryPolicy`
- `WorkspaceDescriptorFile`
- `PackageManifestFile`
- `PackageLockfile`

| 对象                       | 负责什么                                                                                                                                                | 明确不负责什么                                         |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `WorkspaceDiscoveryPolicy` | 定义 root discovery、explicit path override、implicit single-package workspace 规则                                                                     | 不负责 package resolution，不拥有 tool invocation      |
| `WorkspaceDescriptorFile`  | 持久化 workspace root、member declaration、artifact root roles、default target persistence                                                              | 不保存 resolved package graph，不替代 package manifest |
| `PackageManifestFile`      | 持久化单个 package 的 identity、declared deps、source roots、public unit intent、optional compatibility hint 与 target-neutral render asset declaration | 不持有 workspace membership，不持有 install result     |
| `PackageLockfile`          | 持久化一次 workspace-scoped resolution 的 graph、provenance 与 target-sensitive snapshot                                                                | 不拥有 default target，不替代 toolchain binding        |

这里最重要的边界是：

- workspace file 先定义“这片开发环境是什么”
- package manifest 再定义“某个 package 想要什么”
- lockfile 最后定义“这次解析确认了什么”

## 规范先冻结 canonical filenames 和 serialization direction

为了让 root discovery、IDE 集成和 automation replay 足够稳定，nextPas 先冻结这些 canonical names：

- workspace descriptor：`nextpas.workspace.toml`
- package manifest：`nextpas.package.toml`
- lockfile：`nextpas.lock`

并且冻结这些方向：

- author-owned descriptor / manifest 使用 human-editable structured text
- serialization direction 优先与现有 `build/targets/*.toml` 保持一致，因此当前推荐 `.toml`
- machine-owned lockfile 使用 deterministic text format，优先 cheap to diff、cheap to rewrite
- schema version 可以演进，但 canonical filename 和职责边界不应漂移

这里刻意不在第一阶段把每个字段的最终 grammar 全部写死；真正先要稳定的是：

- 哪些事实属于哪个文件
- 哪个文件能被人手改
- 哪个文件只能由 resolver 写
- 哪些文件会进入 root discovery

当前仓库里的最小真实落点已经先把 lockfile owner/path 作为 typed truth 暴露出来：
`compiler/frontend/np_package_workflow.pas` 现阶段会把 workspace-scoped canonical
`nextpas.lock` 路径投影成 `TPackageLockTruth.LockfilePath`，并通过
`compiler/frontend/np_package_lock.pas` 读取最小 v1 TOML skeleton，投影
`status=missing|ready|invalid`、format version、package entries、snapshot skeleton 与 validation
issues。snapshot selection / digest / target 的最小一致性校验也属于这份只读 truth，不会触发
resolver 或 lockfile write；当 valid lockfile 已经声明 snapshot 集合但缺 requested target
snapshot 时，install-plan preflight 会 blocked 为 `package-lock-target-snapshot-missing`，而不是
把 lockfile 标成 invalid。也就是说，文件层 ownership 已经先收口成 compiler-owned truth，对应的写入和 atomic
replace 仍未开始实现。

## root discovery 必须 deterministic，而且不能靠全树重扫

nextPas 不接受“先从当前目录往下扫一遍，看起来像项目就算项目”的做法。

`WorkspaceDiscoveryPolicy` 固定如下：

1. 如果调用方显式提供 workspace path，那么显式输入优先。
2. 如果调用方显式提供 package manifest path，那么先以该 manifest 所在目录为 package root，
   再决定它属于显式 workspace，还是隐式 single-package workspace。
3. 如果没有显式输入，那么从 CLI 当前目录、IDE 当前打开文件目录或 automation 指定入口向上查找。
4. 查找时优先寻找最近的 `nextpas.workspace.toml`。
5. 如果没有任何 `nextpas.workspace.toml`，那么最近的 `nextpas.package.toml` 会形成
   implicit single-package workspace。

这条规则带来三个硬约束：

- workspace root discovery 不需要全量遍历子目录
- package membership 不能靠“刚好扫到了某个目录”来推断
- CLI、IDE、automation 对同一路径必须收敛到同一个 workspace root

为了避免歧义，再给一个 ASCII 目录示意：

```text
repo/
  nextpas.workspace.toml
  nextpas.lock
  apps/ide/nextpas.package.toml
  packages/ui/nextpas.package.toml
  packages/runtime/nextpas.package.toml
```

在这类布局下：

- `repo/` 是 workspace root
- `apps/ide`、`packages/ui`、`packages/runtime` 是 member package roots
- `nextpas.lock` 属于整个 workspace，而不是属于某个 member

## `WorkspaceDescriptorFile` 必须拥有 member declaration 和 target default persistence

`workspace-specification.md` 已经冻结 `WorkspaceModel`、`PackageRef`、`TargetSelection`、
`ArtifactRootSet`。这里进一步冻结这些事实怎样落盘：

- workspace member declaration 属于 `nextpas.workspace.toml`
- member paths 以 relative path 形式持久化，并且默认要求 explicit declaration
- root package 如果存在，仍然需要自己的 `nextpas.package.toml`，并显式作为 workspace member
- default target selection 的 persisted owner 是 workspace descriptor，不是 IDE 私有文件，不是
  lockfile
- artifact roots 的 logical roles 也由 workspace descriptor 持久化，而不是散在脚本参数里

也因此：

- IDE target switcher 改的是 `TargetSelection` view，不是另存一份自己的 project config
- CLI `--target` override 只作用于一次 `CommandExecutionContext`，不应暗中改写 workspace descriptor
- package manager 不允许自己再定义第二套 member declaration 语义

这条边界对 cross compilation 尤其重要，因为 target default 一旦没有正式 owner，IDE、CLI 和
package workflow 很快就会各自漂移。

## workspace member declaration 必须显式，不能把 glob 扫描写成正确性前提

现代、高性能、优雅的 workspace 设计，不该把“目录里碰巧有什么”当成主真相。

因此 nextPas 冻结：

- workspace descriptor 默认用 explicit member list
- future convenience glob 如果存在，也只能是 author-controlled sugar，不是 correctness path
- 未声明的 package root 不能因为目录命名看起来像 package 就自动加入 workspace
- member 删除、重命名、移动后，workspace diff 必须直接体现在 descriptor 变更里

这条规则的意义很直接：

- root reload 可以 cheap to diff
- IDE project tree 不用每次整仓重扫
- package graph 和 workspace graph 有单点真相

## `PackageManifestFile` 只表达 package declaration，不表达 workspace ownership

`PackageManifest` 是 package workflow 的正式对象，但文件层还要再补一层硬边界：

- 每个 package root 最多拥有一个 `nextpas.package.toml`
- manifest 表达 package identity、declared dependencies、source roots、public unit intent、
  optional compatibility hint、target-neutral render asset declaration 与 optional provenance hint
- manifest 不表达 workspace member list
- manifest 不表达 resolved graph
- manifest 不表达 install root 或 build cache path

这条规则直接回应 FPC `pkguninstalledsrcsrepo.pp` 在 repository scan 过程中重新生成 manifest
的历史结构。nextPas 明确不接受：

- 扫描 source repository 时静默生成 author-owned manifest
- IDE 为了“方便”另写一份 package declaration file
- package install 结果反向改写 manifest

如果 tooling 需要创建或迁移 manifest，它必须是显式 author action 或显式 command intent，
而不是扫描副作用。

## `PackageManifestFile` 必须容纳 target-neutral `RenderAssetSourceSet` declaration

`render-asset-pipeline-specification.md` 已经把 source-facing asset truth 冻结成
`RenderAssetSourceSet`。文件层现在必须继续回答：这份 truth 到底写在哪里。

nextPas 在这里明确：

- package-local render asset declaration 属于 `nextpas.package.toml`，与 source roots、public
  unit intent 并列，而不是躲进 IDE 私有配置或 post-build 脚本
- declaration 至少要能表达 logical asset family、package-relative inputs、optional preprocessing
  hint 与 export/install intent，而不是只剩几条裸路径
- declaration 必须保持 target-neutral；它不写 compiled bundle filename、不写 cache locator、
  不写 host tool path，也不写最终 `lib/` / `share/` 落点
- workspace descriptor 如果未来要做跨 package 的 preview/theme 聚合，只能引用或组合这些 package
  declaration，不能静默复制出第二份 asset truth
- generated normalization metadata、bundle digest、shader reflection、atlas mapping 之类结果仍然是
  artifact-root sidecar，不回写 author-owned manifest

这条规则是为了主动挡住几种坏结构：

- package author 只放 asset 文件，真正语义靠 CLI 或 IDE 运行时扫描推断
- cross-target build 把目标相关 bundle 名称直接写回 `nextpas.package.toml`
- preview、IDE、app runtime 各自维护一份私有 asset declaration

## 先冻结一份最小 package manifest skeleton，不把 author-facing declaration 留成口头约定

前面已经冻结“package declaration 属于 `nextpas.package.toml`”。如果这一步继续只停在抽象描述，
后面实现时还是很容易重新滑回脚本约定、目录猜测或 IDE 私有 JSON。

因此 nextPas 先推荐一份最小、可演进、但已经足够 authoring 的 TOML skeleton：

```toml
[package]
name = "nextpas.ui.controls"
version = "0.1.0"
description = "GPU-backed UI controls for nextPas"
license = "Apache-2.0 OR MIT"

[sources]
roots = ["src"]
public_units = ["NextPas.UI.Controls", "NextPas.UI.Button"]

[dependencies]
"nextpas.ui.runtime" = { version = ">=0.1.0, <0.2.0" }
"nextpas.graphics" = { version = ">=0.1.0" }

[compatibility]
targets = ["linux-x86_64"]

[provenance]
kind = "workspace"

[[render_assets]]
family = "core.shaders"
kind = "shader"
inputs = ["assets/shaders/*.vert", "assets/shaders/*.frag"]
preprocess = "compile-pack"
install_intent = "runtime-private"

[[render_assets]]
family = "core.icons"
kind = "image"
inputs = ["assets/icons/**/*.svg"]
preprocess = "atlas"
install_intent = "shared-content"

[[render_assets]]
family = "core.fonts.default"
kind = "font"
inputs = ["assets/fonts/nextpas-sans.ttf"]
preprocess = "font-metadata"
install_intent = "shared-content"
```

这份 skeleton 先表达这些稳定字段：

- `package.name`
  - package identity 的稳定主键；它不该从目录名、install root 或 current working directory 倒推
- `package.version`
  - author-declared version truth，服务 resolution、publish 与 provenance replay；它不是 compiler version，
    也不是 target suffix
- `sources.roots`
  - package source roots 的正式声明；它不包含 cache root、generated root 或 install root
- `sources.public_units`
  - package 的 public unit intent，供 package view、install explainability 与 IDE surface 共用；
    它不是完整 compiled unit graph dump
- `[dependencies]`
  - 继续表达 declared dependency intent。当前推荐 keyed table + inline table，是为了让 package identity
    稳定、cheap to diff，并避免 positional list 在后续扩展时变得脆弱
- `compatibility.targets`
  - 当前最小 compatibility hint 继续直接引用 `TargetFacts` 的 target id，例如 `linux-x86_64`；
    它帮助 package discovery / resolution 提前做约束过滤，但不拥有 target model
- `provenance.kind`
  - 当前最小 source provenance hint family，推荐值是 `workspace`、`registry`、`archive`；它只表达
    author intent，不表达 resolved download URL 或 content digest
- `provenance.registry`
  - 只在 `kind = "registry"` 时出现；它继续只是 logical registry name，不是 mirror URL，也不是
    transport endpoint
- `render_assets[*].family`
  - package 内稳定的 logical asset family key，供 preview、runtime、component gallery 与 package
    dependency 共享引用
- `render_assets[*].kind`
  - 当前最小推荐值是 `shader`、`image`、`font`、`theme`、`effect`
- `render_assets[*].inputs`
  - package-relative input locator 列表；如果支持 pattern，它也必须是 author-owned、受 package root
    约束的选择器，而不是无边界目录扫描
- `render_assets[*].preprocess`
  - 声明性 preprocessing hint，例如 `compile-pack`、`atlas`、`font-metadata`；它不是 executable path，
    也不是 shell command
- `render_assets[*].install_intent`
  - 只表达 placement intent，例如 `runtime-private` 或 `shared-content`；它不是最终 `lib/` / `share/`
    路径，更不是 compiled bundle filename

这份 shape 仍然刻意保留演进空间：

- 当前先冻结 package identity、version、source roots、public unit intent、declared dependencies 与
  render asset declaration 的 owner
- 未来可以在不打破 owner 边界的前提下补充 `homepage`、`authors`、publish metadata 或
  richer dependency attributes
- 可以在 future schema version 里补充 variant、fallback policy 或 semantic tags
- 但第一阶段不接受把最小 source truth 再拆成第二份 UI-specific manifest
- 也不接受让 compiled output path、cache key 或 host tool choice 进入 author-owned manifest

## dependency requirement 与 compatibility hint 先冻结到最小 grammar

nextPas 现在不需要一次把整套 package grammar 全锁死，但有几条最小 contract 已经必须写清：

- `[dependencies]` 当前至少接受 keyed table + inline table 形状
- dependency requirement string 当前最小支持这些 comparator：`=`、`>`、`>=`、`<`、`<=`
- 多个 comparator 用逗号表达 intersection，例如 `>=0.1.0, <0.2.0`
- 不符合这套 grammar 的 requirement 仍属于 manifest/workflow truth，必须投影 validation
  status 与 issue detail，不能静默消失
- 第一阶段不要求现在就支持 union range、feature flag、optional dependency 或 target-specific
  dependency table
- `[compatibility]` 当前最小只推荐 `targets = [...]`
- compatibility hint 缺省时，package 视为 target-neutral declaration；一旦声明，就只能当作 early
  filter / early reject hint，而不是第二套 `TargetFacts`
- `[provenance]` 当前最小只推荐：

  ```toml
  [provenance]
  kind = "workspace"
  ```

  或：

  ```toml
  [provenance]
  kind = "registry"
  registry = "default"
  ```

  或：

  ```toml
  [provenance]
  kind = "archive"
  ```

- provenance hint 缺省时，workspace-local package 可以由 manifest path 隐式解释为 `workspace`
- manifest provenance hint 不写 remote URL、不写 mirror、不写 content digest，也不写 resolved
  install repository

这样设计的原因有两条：

- 它已经足够覆盖 FPC 当前真实存在的 package name / version / dependency / target-compatibility 事实
- 它又不会把 target naming、toolchain binding 或 lock snapshot 重新塞回 author-owned manifest

## `PackageLockfile` 必须 workspace-scoped、target-aware，而且只能有一个正式 owner

`package-workflow-specification.md` 已经冻结 `PackageLock` 是 resolution snapshot。这里继续冻结：

- `nextpas.lock` 默认属于 workspace root
- multi-package workspace 不允许每个 member 各存一份私有 lockfile
- implicit single-package workspace 的 lockfile 与 manifest 同目录
- lockfile 记录 resolved graph、selected versions、source provenance、content locator，以及
  target-sensitive resolution snapshot
- lockfile 不拥有 workspace default target，不拥有 IDE state，也不持有 mirror UI 偏好

当前这条 ownership 也已经先在最小 package workflow skeleton 里落成 code-level truth：
只要调用方给出 workspace root，就能稳定得到 canonical `nextpas.lock` 路径，并只读解析最小
v1 skeleton；但这批不会创建、改写或重写 lockfile，本质上仍是 non-executing provenance surface。

这条边界是为了保证：

- workspace package graph 有唯一 replay point
- IDE package view、CLI `pkg graph`、CI replay 共享同一份 resolution truth
- mirror 切换如果不改变 provenance，不需要把 lockfile 语义写成另一套世界

## 先冻结一份最小 lockfile skeleton，让 resolution snapshot 有正式文件形状

既然 `nextpas.lock` 是 machine-owned replay point，它就不能只剩“以后 resolver 自己知道怎么写”。

因此 nextPas 当前先落地一份最小、deterministic 的 lockfile v1 skeleton：

```toml
[lockfile]
format-version = 1

[[package]]
name = "nextpas.graphics"
version = "0.1.0"

[[snapshot]]
target = "linux-x86_64"
provenance = "manifest:nextpas.graphics"
digest = "sha256:..."
selection = "nextpas.graphics@0.1.0"
```

这份 skeleton 当前先冻结这些 ownership：

- `lockfile.format-version`
  - machine-owned grammar version，不是 package version
- `package[*].name` / `version`
  - resolved package identity 与 selected version
- `snapshot[*].target` / `provenance` / `digest` / `selection`
  - target-sensitive replay skeleton；缺字段、selection 不匹配 `package[*].name@version`、
    重复 target 或非 `sha256:` digest shape 会让 lockfile invalid，但这仍不是完整 resolver output

更完整的 dependency selected-version graph、content locator 细节与 resolver decision transcript
仍是后续 resolver / lock writer 应该补进来的 replay evidence；当前只读 preflight 先解析最小
skeleton，并要求 manifest package name/version 能在 lock entries 中找到同名同版本项；如果
lockfile 已经有 target-sensitive snapshots，还要求 requested target 能找到对应 snapshot，让 tooling
可以诚实区分 missing、ready、invalid 与 out-of-sync。

这里继续明确不允许什么：

- lockfile 不拥有 install root、cache root 或 tool executable path
- lockfile 不复制 `TargetFacts`、`ToolchainBinding` 或完整 package manifest
- lockfile 不把 target-sensitive snapshot 反向写回 `nextpas.package.toml`

## target persistence 和 target-sensitive resolution 必须写进正确的文件

用户长期明确要求 cross compilation、LLVM backend、C interop 与 toolchain 都要接得优雅。
文件层必须先把 target 相关 ownership 写清楚：

- workspace default target 属于 `WorkspaceDescriptorFile`
- package manifest 可以表达 target-neutral declaration，或最多表达 compatibility hint
- `RenderAssetSourceSet` 的 source-facing declaration 继续属于 package manifest；target-specific
  bundle identity、cache result 与 install placement 不进入 manifest
- lockfile 可以表达 target-sensitive resolution snapshot
- `ToolchainBinding`、sysroot、linker/archiver/resource tool mapping 继续留在
  `toolchain-specification.md` 定义的控制面，不进入 workspace descriptor
- active channel、resolved distribution release、dist root、host-private environment activation
  继续属于 `env` / distribution truth，不进入 workspace descriptor 或 lockfile
- target facts 继续来自 `build/targets/<target>.toml`，而不是复制进 manifest/lockfile

换句话说：

- descriptor 持有“默认想编到哪”
- lockfile 持有“这次解析在该 target 上收敛成什么”
- `env` 持有“当前机器选择了哪套 distribution/binding/runtime 组合”
- toolchain 持有“怎么真正把 host-to-target build 跑起来”

只有这样，cross target IDE analysis、`pkg` resolution、CLI build 和 future automation 才不会互相污染。

## generated metadata 必须进入 artifact roots，不能混进 source roots

FPC 的 `.pri`、`fppkg.cfg`、generated manifest 和 package-specific config filename 已经说明：
一旦 source truth、tool cache 和 IDE state 混住，后面就很难再恢复清楚边界。

因此 nextPas 冻结：

- language-service index
- package resolution cache
- fetched source metadata
- generated manifest sidecar
- render asset metadata
- preview snapshot
- IDE local panel/session cache

这些都属于 `ArtifactRootSet`，不属于 source roots。

更具体地说：

- `nextpas.package.toml` 继续持有 author-owned source declaration，包括 package-local render asset intent
- `ArtifactRootSet` 持有 generated manifest sidecar、render asset digest/index、compiled asset metadata
  与 preview cache
- distribution-facing install result 继续经由 `lib/` / `share/` 暴露，不反向改写 manifest

同样重要的是，`ArtifactRootSet` 也继续持有 machine-local env state：

- distribution metadata cache
- downloaded archive cache
- unpacked toolchain/runtime staging
- activation / selection sidecar
- environment resolution cache

为了避免 FPC `fppkg.cfg` 里 `LocalRepository`、`BuildDir`、`ArchivesDir`、`CompilerConfigDir`
这类 machine-local path 再次混成一团，nextPas 推荐把 `<artifact-root>/env/` 继续按 ownership
分成最小几类 bucket：

- `env/metadata/`
  - 放置 channel/distribution metadata cache、digest sidecar 与等价只读索引
- `env/archives/`
  - 放置下载后的 distribution archive、runtime SDK archive 与等价可复用压缩物
- `env/staging/`
  - 放置 unpack / verify / materialize 期间的临时 staging root 与 interrupted work state
- `env/selections/`
  - 放置 machine-local active channel、distribution release、preferred binding 等 selection sidecar
  - 当前 `stage0 env use` 已先落地 workspace-local preferred binding sidecar：
    `env/selections/<target>.toml`
- `env/resolution/`
  - 放置 environment resolution cache，例如 workspace requirement 到 binding/sysroot/runtime set 的
    派生结果
  - 当前 `stage0 env sync` 已先落地 workspace-local resolution sidecar：
    `env/resolution/<target>.toml`
- 当前 `stage0 env clean` 先收口 workspace-local `env/selections/` 与 `env/resolution/` 两个 sidecar
  bucket，不碰 descriptor / manifest / lockfile

这里故意只推荐 bucket，不新增新的 persisted truth object：

- workspace descriptor 继续只声明 artifact root role，不拥有这些目录内部文件名
- canonical distribution identity 继续由 `distribution-layout-specification.md` 定义，不由本地 bucket 命名决定
- helper tool roots、`units/<target>/`、`lib/`、`share/` 继续属于 distribution / install layout，
  不是 `env/` sidecar 本身

这些内容和 generated metadata 一样，都不属于 persisted file truth。

也就是说，一个现代化 nextPas workspace 更应该长成：

```text
workspace-root/
  nextpas.workspace.toml
  nextpas.lock
  packages/ui/nextpas.package.toml
  packages/ui/src/
  apps/ide/nextpas.package.toml
  apps/ide/src/
  <artifact-root>/
    cache/
    env/
      metadata/
      archives/
      staging/
      selections/
      resolution/
    language-service/
    preview/
    generated/
```

这里的 `<artifact-root>/` 可以是 workspace descriptor 声明的本地目录，例如 `.nextpas/` 或其他
受控路径；但无论叫什么，它都不能被伪装成 source root。

## machine-local env state 不能写回 descriptor / manifest / lockfile

这条规则必须继续写死。否则 nextPas 很快又会退回 FPC 那种 config、repository、local build state
互相缠住的旧路。

因此：

- `nextpas.workspace.toml` 不保存 active channel、resolved dist root、downloaded archive locator
- `nextpas.package.toml` 不保存 host-local toolchain/runtime activation 结果
- `nextpas.lock` 不保存 machine-local environment cache、activation scratch data 或 archive cache index
- machine-local env sidecar 如果需要持久化，也只能落在 `ArtifactRootSet` 管理的本地目录下

换句话说，正式文件层继续表达 shared truth；本地环境状态继续表达 machine-local replay aid。

## 清理边界必须先写清，避免把 cache 当 source truth 供奉

既然 artifact root 里会逐渐承载更多 env/package/render/language-service sidecar，就必须提前把
cleanability 写清楚。

因此 nextPas 冻结：

- metadata cache、archive cache、environment resolution cache、preview cache、generated manifest sidecar
  都应被视为 rebuildable
- activation / selection sidecar 可以被显式重建或切换，但它不是必须纳入版本控制的 source truth
- `nextpas.workspace.toml`、`nextpas.package.toml`、`nextpas.lock` 与公开 install result
  不是 cache clean 的目标
- future automation 如果要做 clean/replay，应优先清 artifact-root sidecar，而不是去猜哪些 source 文件
  “大概是生成的”

如果 artifact root 采用上面的 `env/` 分桶，cleanability 还应继续收紧成这些默认规则：

- `env/metadata/` 与 `env/resolution/` 属于 cheap-to-rebuild sidecar，可以在不再被 active selection
  引用后按 age 或 reachability 回收
- `env/staging/` 不属于长期 truth；中断、失败或已被后续物化替代的 staging state 应允许被积极回收
- `env/archives/` 虽然仍然 rebuildable，但下载成本更高，因此默认应比 metadata/resolution 更保守地保留
- `env/selections/` 必须保留当前 active selection；旧 selection snapshot 只有在确认不再被 workspace
  或 user-level choice 引用时，才可被显式清理或保守回收
- 当前 `stage0 env clean` 先只清 `env/selections/` 与 `env/resolution/`；更广义的 metadata/archive/staging
  回收仍留给 future gc 或后续 maintenance 扩展
- 无论采用什么目录名，公开 install result 与 shared persisted truth 都不是 `env` clean/gc 的默认目标

这条边界对高性能也很重要：只有把“能删掉再重来”的状态单独收口，workspace reload、CI cache、
增量 build 和 environment repair 才能做得既快又可解释。

## CLI、IDE 和 automation 只能共享同一份 persisted file truth

这条规则必须写死，因为 nextPas 不是只做 compiler binary。

关系固定如下：

- CLI
  - 用同一套 root discovery 找到 workspace descriptor / manifest / lockfile
- IDE
  - workspace tree、package view、target switcher 只显示或操作正式文件层恢复出来的 truth
- automation / CI
  - 用同一套 persisted file truth 做 replay，不通过额外脚本倒推 package graph
- language service
  - 从文件层恢复 `WorkspaceModel`，但不拥有文件层

这能直接避免三种老问题：

- IDE 私有 project file 和 CLI 不一致
- CI 依赖脚本拼出来的隐式 root discovery
- package manager 再发明一份自己的 config world

## 文件写入必须 atomic、deterministic，而且 cheap to diff

如果 nextPas 真想高性能、优雅，就不能把 descriptor / manifest / lockfile 的写入做成
“能跑就行”的脚本副作用。

第一阶段先冻结这些性能方向：

- root discovery 结果可缓存，并按 descriptor / manifest 变更做精确 invalidation
- descriptor / manifest / lockfile 序列化必须 deterministic，避免无意义 churn
- lockfile 写入必须支持 atomic replace，避免 IDE、CLI、automation 并发时留下半写文件
- workspace reload 优先结构化 diff，而不是整仓重扫
- target change 只使 target-sensitive resolution / analysis / build 路径失效，不强迫文件层全量重建

这些不是实现优化建议，而是 file-layer architecture contract。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 当前不承诺已经公开实现 workspace-aware CLI、automatic lock maintenance 或 package manifest authoring
  - 但文件层角色、canonical filenames 和 ownership boundary 必须先冻结
- `stage1`
  - 开始把 `nextpas.workspace.toml`、`nextpas.package.toml`、`nextpas.lock` 接进正式 root discovery
  - 逐步让 build/query/pkg surface 消费同一份 persisted truth
- `stage2`
  - 当 compiler、workspace、toolchain、language service、GUI framework 与 IDE 都稳定后，
    更完整的 IDE package UX、workspace editor、publish workflow 才值得进入正式实现波次

## 第一阶段非目标

- 不把这份规范写成每个字段都已经最终冻结的 parser grammar 文档
- 不把 recursive scan 或隐式 glob 写成 workspace correctness 的前提
- 不允许 IDE 私有 project state 再写回 source roots
- 不允许 repository scan 静默重写 `PackageManifestFile`
- 不把 lockfile 变成 install layout、toolchain binding 或 editor session 的混合文件
- 不把当前 `stage0` 单文件 build 路径夸大成已经具备完整 workspace UX

第一阶段真正要交付的是：一份把 nextPas 的 workspace / manifest / lockfile 写成“统一、
可重放、可扩展、对 CLI 和 IDE 同时友好”的正式文件层架构规范。
