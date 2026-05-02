# nextPas unit 解析规范

用这份规范定义 nextPas 当前已经落地的 unit 解析边界，以及下一步应该怎样继续收紧。
这份文档不再把“未来也许会这样”与“当前代码已经这样做了”混在一起，而是明确区分：

- 当前仓库已真实实现并验证过的行为
- 下一轮仍需扩展、但现在还不能过度宣称的设计方向

这份文档承接 `compiler-pipeline-specification.md` 中的 `UnitGraph` 原则，也和
`runtime-bootstrap-specification.md`、`compatibility-matrix.md` 一起定义
“unit/module behavior” 这条硬兼容边界。

## 先承认 FPC 真实把哪些事情揉在一起

这份规范直接回应这些 FPC compiler 单元里的真实耦合：

- `compiler/pmodules.pas`：`AddUnit` 直接串起 `registerunit -> adddependency -> loadppu`
- `compiler/fmodule.pas`：`tmodule` 同时持有 used units、dependency graph、symtable 和 link 资产
- `compiler/fppu.pas`：`tppumodule` 同时承担 search、load、reload 和持久化

nextPas 不是否认这些行为需求，而是把它们拆成更清楚的边界：

- unit identity
- search paths
- resolution diagnostics
- dependency graph
- runtime init/fini 前提

## 当前仓库里已经真实落地的部分

当前仓库已经把最小可执行 resolution 骨架接进真实代码：

- `compiler/frontend/np_unit_graph.pas`
  - `TSearchPathSet`
  - `TResolvedUnit`
  - `TUnitGraph`
- `compiler/frontend/np_unit_resolver.pas`
  - `TUnitResolver`
- `compiler/frontend/np_compilation_session.pas`
  - 统一持有 resolution status、search paths 与 `UnitGraph`
- `compiler/syntax/np_ast_facade.pas`
  - 公开 `InterfaceUse*` 与 `ImplementationUse*` 访问面
- `tools/stage0/nextpas.pas`
  - 在 syntax 之后、宿主 FPC 之前真实运行 resolution

当前成功路径已经会投影这些结果：

- `resolution-status`
- `unit-graph-status`
- `search-path-count`
- `search-index-status`
- `indexed-search-root-count`
- `search-index-scan-count`
- `resolved-unit-count`
- `unit-graph-edge-count`
- `unit-graph-root-name`

当前失败路径已经有真实、可验证的 resolution diagnostics：

- `resolver.unit-not-found`
- `resolver.ambiguous-unit-source`
- `resolver.unit-cycle-detected`
- `resolver.unit-name-mismatch`

## search index 现在是每个 root 的 lazy cache，而不是 eager 扫描副作用

当前 `TUnitResolver` 已经不再对每次 candidate lookup 都重新全量扫描 search roots。
实现现在保留最小 per-root search index，并把这份状态显式暴露出来：

- `SearchIndexStatus`
- `IndexedRootCount`
- `SearchIndexScanCount`

这条 contract 的重点不是”尽快把状态变成 ready”，而是把 resolver 当前真实消费过的事实如实投影。

也就是说：

- resolver 初始化后，index status 默认是 `deferred`
- 只有当某个 lookup 真的需要消费 search roots 时，对应 root 才会建立 index
- 重复 lookup 会复用已建立的 root index，而不是再次增加 scan count
- `TCompilationSession` 会把这份 resolver-owned state 投影成
  `search-index-status`、`indexed-search-root-count` 与 `search-index-scan-count`

### Search Index 的三种稳定状态

nextPas 明确定义 search index 的三种状态及其语义：

| 状态       | 含义                                                                 | 何时出现                                     |
| ---------- | -------------------------------------------------------------------- | -------------------------------------------- |
| `deferred` | 尚未需要构建 index，resolver 还没有触发任何需要扫描 search roots 的 lookup | root unit 不依赖外部 unit 时                 |
| `ready`    | 已构建完整 index，所有 search roots 都已扫描                         | 需要解析 dependency 且扫描了所有 tier        |
| `partial`  | 已构建部分 index，高优先级 tier 命中后停止扫描低优先级 tier          | precedence 生效，提前命中后跳过低优先级 tier |

**错误处理边界**：

- 如果 resolver 在 `deferred` 状态下被要求解析 dependency，它会按需构建 index
- 如果 search root 不存在或不可读，resolver 会跳过该 root 并记录 diagnostic，不会让整个 resolution 失败
- 如果所有 search roots 都不可用，resolver 会进入 `ready` 状态但 `indexed-search-root-count=0`
- unit-not-found 错误在 resolution 阶段产生，不在 index 构建阶段产生

**future incremental invalidation 预留**：

当前三种状态足够 `stage0` 使用。future language service 如果需要 incremental invalidation，
可以引入第四种状态 `stale`（需要重建），但这不是当前 `stage0` 的承诺。

因此当前两条 smoke 路径表现不同是刻意的、也是正确的：

- `examples/smoke/hello.pas` 没有触发额外 unit lookup，当前如实表现为
  `search-index-status=deferred`、`indexed-search-root-count=0`、
  `search-index-scan-count=0`
- `examples/smoke/hello_with_units.pas` 真实解析了 dependency unit，当前如实表现为
  `search-index-status=ready`、`indexed-search-root-count=2`、
  `search-index-scan-count=2`

这不是 CLI projection 不一致，而是在把“是否真的消费了 resolution search roots”当成
session-owned truth 公开出来。

除了 `deferred` 与 `ready`，当前仓库里还已经有一类同样真实、而且很重要的状态：
`partial`。

`partial` 的含义不是“做了一半失败了”，而是“resolver 已经扫描了部分高优先级 roots，
并且在更高优先级 tier 成功命中后，故意没有继续扫描更低优先级 roots”。

当前这类行为已经能在多条 precedence fixture 上稳定复现：

- `root_source_precedence_smoke` 当前会表现为
  `search-index-status=partial`、`indexed-search-root-count=1`、
  `search-index-scan-count=1`
- `explicit_unit_root_smoke` 当前会表现为
  `search-index-status=partial`、`indexed-search-root-count=2`、
  `search-index-scan-count=2`
- `package_manifest_source_precedence_smoke` 当前也会表现为
  `search-index-status=partial`、`indexed-search-root-count=2`、
  `search-index-scan-count=2`

这条 `partial` contract 的意义很直接：

- 它证明 resolver 真正遵守了 precedence，而不是命中后仍然继续把低优先级 roots 全扫一遍
- 它让 session/CLI/envelope 能解释“为什么这次只扫描了前几层”
- 它也让 future verify 能防止 resolver 退化回 eager 全扫描或丢失 scan accounting

## unit identity 必须先规范化，再参与解析

当前实现已经把 requested unit name 先规范化成 `UnitId`，再参与查找和 graph 连接。
这保证：

- 大小写差异不会变成正式 identity
- 同一 compilation session 里的同名 unit 会收敛到同一个 `UnitId`
- dependency edge 基于 canonical identity，而不是文件名偶然性

这个规则是 correctness 和后续增量编译的共同前提，不是可选优化。

## root unit 和 dependency unit 都必须解析 implementation uses

这是本轮修正后的硬规则。

当前实现里：

- `ResolveRoot(...)` 会同时解析 `interface uses` 与 `implementation uses`
- `ResolveDependency(...)` 在加载依赖单元后，也会继续同时解析两类 `uses`
- `UnitGraph` 当前已经显式区分：
  - `root-request`
  - `interface-use`
  - `implementation-use`
  - `implicit-runtime`

这意味着 implementation-only dependency 已经不再只是“依赖单元会处理，根单元先忽略”的
半成品行为。根单元的 implementation imports 现在同样是 resolution graph 的正式输入。

## 请求名和文件内声明名必须一致

当前 resolver 在找到候选文件后，不会再直接信任“文件名刚好对得上”。

当前规则是：

- 先按 requested name 找候选 `.pas`
- 解析候选文件的 `DeclaredName`
- 如果 `DeclaredName` 规范化后不等于 requested unit identity，发出
  `resolver.unit-name-mismatch`

也就是说，下面这种静默错绑现在是不允许的：

- `uses WrongNameHelper;`
- 解析到某个文件
- 但文件内部声明的是 `unit DifferentName;`

这种情况现在必须明确失败，而不是把错误文件绑定成“解析成功”。

## implicit `System` 仍然要显式入图，但不能遮蔽真实源码

程序、library 或 package 进入 resolution 时，当前 resolver 仍会保证 graph 上存在一条
implicit runtime dependency。这一点没有改变。

但当前实现已经补上一个关键约束：

- implicit runtime edge 可以先把 `System` 作为 placeholder 放进 `UnitGraph`
- 如果后续出现显式 `uses System`，resolver 仍然必须继续查找真实 `System.pas`
- `TUnitGraph.AddResolvedUnit(...)` 会在 placeholder 只有空 `SourcePath` 时，用真实 source
  升级这个节点

这条规则确保：

- graph 始终有显式的 runtime edge
- 显式 `uses System` 不会再被 placeholder 静默短路
- 真实 `System` 的 provenance、依赖和错误都能继续被看见

所以显式 `uses System` 现在能够暴露真实 `System.pas` 的依赖问题，而不是直接命中一个
无来源的 synthetic 节点就结束。

## search path 现在是显式集合，而且已经有真实 precedence

当前 `TSearchPathSet` 已经是 session 内的正式对象，不再是 driver 里散落的路径字符串。

当前真实实现现在包含四类 root：

- root source 所在目录
- nearest package manifest 与 workspace member 声明贡献的 package source roots
- command/workspace 提供的 explicit unit roots
- `units/<target>/` 对齐的 target-installed root

当前 search precedence 也已经固定为：

- `root-source`
- `package-source-root`
- `explicit-unit-root`
- `target-installed`

实现层当前还额外收紧了一条 correctness 规则：

- resolver 会按 precedence tier 逐层找候选
- 一旦某一层找到匹配文件，只在这一层内部判断“是否 ambiguity”
- 后续较低优先级 root 不会再把更高优先级命中的结果反向制造成假 ambiguity

这让 root-local override、package/workspace source roots 与 explicit unit root override
都进入了真实可验证路径。

但这仍然不等于“已经完成 multi-root workspace / package-level source graph”。

所以这里必须诚实区分：

- current CLI/session 已经拥有 explicit unit roots
- nearest `nextpas.package.toml` 的 `[sources].roots` 已经进入 `TCompilationOptions`
  与 `TSearchPathSet`
- `nextpas.workspace.toml` 的 `members` 当前也会把 member package 的 source roots 纳入
  search path
- `build/verify_local.sh` 已经对
  `package-manifest-source-root-check`、
  `workspace-member-source-root-check` 与
  `package-manifest-source-precedence-check` 建立真实 gate
- 但 `ResolveUnits` 当前仍不是完整的 workspace model：
  它还没有 richer package metadata、typed workspace provenance、完整 multi-root graph
  invalidation，也没有把更深的 package/workspace topology 变成正式对象

所以今天可以说“最小 project/package source roots 已进入真实执行路径”，
但还不能把它包装成“workspace truth 已完整落地”。

## `ResolvedUnit` 现在至少要绑定这些事实

当前 `ResolvedUnit` 已经把这些内容收进正式记录：

- canonical unit name
- source path
- origin class
- target affinity
- root kind
- file id

当前 origin class 至少区分：

- `root-source`
- `project-source`
- `installed-source`
- `implicit-runtime`

这让后续阶段能解释：某个 unit 为什么会被选中，它来自哪里，它是不是显式源码，还是运行时隐式依赖。

## failure model 必须继续保持结构化

当前 resolution 层已经真实落地这些失败类别：

- missing unit
- ambiguous unit source
- unit cycle
- requested-name / declared-name mismatch

这些失败当前都必须以结构化 diagnostic 进入 `resolution` phase，而不是退化成
“最后宿主编译器报错了，大概是路径问题”。

这条规则的意义不是漂亮，而是可验证：

- `build/verify_local.sh` 当前已经 gate 这些失败
- `compiler-fail` fixtures 当前已经把这些失败写进 snapshot baseline
- 对 missing unit / ambiguous unit 两类 failure，
  当前 diagnostic message 还会继续投影 consulted root / candidate origin 摘要：
  - missing unit：至少包含 consulted root 的 `scope`、`provenance` 与 `root`
  - ambiguous unit：至少包含 candidate 的 `path`，以及命中 search root 的
    `scope`、`provenance` 与 `root`

## runtime init/fini 仍然依赖 `UnitGraph`，但不由它执行

这里的边界没有变化：

- resolution 负责构建 `UnitGraph`
- 后续语义 / IR 负责消费这份 graph
- runtime bootstrap 负责执行已经决定好的 init/fini 顺序

因此：

- runtime 不应该重新扫描源码再猜一次依赖
- 如果某个 unit 无法稳定进入 graph，后续计划不应继续假装“依赖已经确定”

## 性能模型必须直接约束这一层

如果 nextPas 想在结构和性能上超过历史实现，unit resolution 不能只是“先把功能做出来再说”。
当前这层设计至少坚持这些规则：

- requested name 规范化一次，再传播 `UnitId`
- search roots 进入 session 级集合，不在每次解析时重新拼接
- graph edge 是 typed kind，不在字符串路径列表上反复推断语义
- diagnostics 以结构化结果输出，不把热路径浪费在四处即时格式化文本

这些规则现在还只是最小骨架，但方向已经必须固定。

## 下一轮应继续收紧什么

当前这一层还没有完成，下一轮至少要继续推进这些点：

- 让 search root provenance 在 `root-source` / `package-source-root` /
  `explicit-unit-root` / `target-installed` 之上继续接入 typed package/workspace
  provenance
- 把 consulted roots 与 candidate origins 从当前的 message-level summary，
  继续提升成更丰富的 typed package/workspace provenance / package graph 解释面
- 把 nearest-manifest + workspace-member roots 继续提升成更明确的 workspace model /
  package graph 输入，而不是长期停在 ad-hoc 文件扫描
- 把 unit-level invalidation 继续往 session / cache key 设计里落

这些都是合理的下一步，但它们必须建立在当前这套真实实现之上，而不是跳过现实状态直接写成
“已经支持”。

## 当前阶段必须诚实描述什么

今天可以明确说的是：

- nextPas 已经真实拥有自己的 unit identity、graph construction 和 resolution diagnostics
- `stage0 build` 会在宿主 FPC 之前真实运行 resolution
- 最小 package/workspace source roots 已经进入 search path 和 verify gate
- root implementation uses、name mismatch、显式 `System` source upgrade 这些 correctness
  问题已经进入正式行为

今天还不能过度宣称的是：

- multi-root workspace 已完成
- 完整 package/workspace graph 已稳定
- nextPas 已完全脱离宿主 FPC 独立生成最终产物

换句话说，resolution 这一层已经从“骨架”走向“真实闭环”，但整个编译器还没有因此自动变成
完全独立的全栈实现。

## 第一阶段非目标

- 不把 IDE / LSP / package manager 的 search path 语义提前混进当前实现
- 不把 on-disk cache format 或 graph serialization 过早冻结
- 不把 runtime 执行细节塞进 resolution 文档
- 不把当前还未完成的完整 workspace/package graph 写成“已完成能力”

这份规范的目标，是让当前已经真实成立的 unit 解析行为足够清楚，也让下一轮必须补的空白足够诚实。
