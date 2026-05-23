# nextPas language service 规范

用这份规范定义 nextPas 长期 language service 的稳定边界。它回答的不是
“以后要不要做一个 LSP server”，而是“compiler kernel 应该怎样把解析、语义、诊断、
增量失效和语义查询收成一套共享分析控制面，供 future IDE、CLI、formatter、refactor
与其他 developer-facing tools 共同消费，而不是各自再长出第二套 parser 和语义真相”。

这份文档和 `compiler-pipeline-specification.md`、`semantic-model-specification.md`、
`diagnostics-specification.md`、`unit-resolution-specification.md`、
`toolchain-specification.md`、`workspace-specification.md`、`ide-specification.md`
一起工作。前者们分别冻结编译流水线、语义核心、诊断数据面、unit 解析控制面、工具链控制面、
workspace control plane 与 IDE workbench 边界；这里冻结 shared analysis service 本身的正式边界。

## 先看 FPC 真源码已经把 editor / compiler integration 做成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `packages/ide/fpintf.pas`
  - IDE 可以直接 `ExecuteRedir(ExternalCompilerExe, ...)`
  - 然后逐行解析编译器文本输出，靠匹配 `Error:`、`Fatal:`、`Hint:`、`Note:` 来恢复严重级别
  - 还要自己从 `module(line,column)` 文本里解析位置
- `packages/ide/fpmake.pp`
  - IDE build 过程直接探测 `../../compiler`
  - 同时包含 `msg2inc` 消息生成、`gdb` / `libgdb` 检测和编译选项拼接
  - 说明 IDE、compiler tree 和 debugger support 被绑在同一宿主流程里
- `packages/testinsight/fpmake.pp`
  - `Description := 'Send FPCUnit test results to a webserver (e.g. embedded in Lazarus IDE).'`
  - 说明测试可视化更多是附加集成，而不是和 compiler 共享统一 analysis / test truth

由这些源码事实可以直接推断出两个问题：

- FPC 生态不是没有 IDE integration，而是主要依赖命令调用、文本 scraping 和宿主脚本耦合
- 当前源码取证没有展示出一层“compiler semantic truth -> shared language service -> IDE/CLI adapters”
  的正式边界

nextPas 要做现代化、高性能、优雅的开发环境，就必须主动补上这一层，而不是把它继续留给
编辑器插件或 IDE 私有逻辑。

## language service 是共享分析控制面，不是协议壳

nextPas 对 language service 的定义先冻结为：

- 它是 compiler-backed shared analysis surface
- 它服务 future IDE，也服务 CLI 与其他 developer-facing tools
- 它不是某个具体协议实现的别名
- 它不是把编译器 stderr/stdout 重新包装一下的 message proxy

因此要先区分三层：

- language service core
  - 持有 analysis session、open file overlays、incremental invalidation、semantic queries、
    diagnostics streaming
- protocol / transport adapter
  - future LSP、IPC、stdio、embedded API 或 IDE 进程内调用
- UI / tool surface
  - IDE editor、workspace explorer、code actions、CLI query verbs、future formatter/refactor tools

nextPas 冻结：协议适配器可以替换，但 language service core 不能跟着每个宿主各写一份。

## 用这条分层作为唯一推荐方向

```text
IDE / CLI / future protocol adapters
  -> WorkspaceModel + target selection
  -> OpenDocumentOverlay set
  -> LanguageServiceSession
  -> Source database
  -> UnitGraph
  -> Semantic model / Typed HIR
  -> Structured diagnostics
```

为了让边界更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| IDE / CLI / formatter / refactor / protocol adapters |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| WorkspaceModel + target facts + package roots        |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| OpenDocumentOverlay set                              |
| LanguageServiceSession                               |
| - analysis revision                                  |
| - query execution                                    |
| - diagnostics stream                                 |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| source database / UnitGraph / semantic model         |
| Typed HIR / diagnostics contract                     |
+------------------------------------------------------+
```

这张图的硬约束是：

- service core 只消费 compiler truth，不重做第二套 parser 或 type checker
- protocol adapter 只负责 transport，不偷做语义判断
- IDE/CLI 只显示、导航或组织结果，不靠文本再反推语义

## 只冻结三个核心对象，不把 service 写成万能黑箱

为了保持抽象清楚但不过度膨胀，nextPas 先只冻结三个核心对象：

- `LanguageServiceSession`
- `OpenDocumentOverlay`
- `AnalysisSnapshot`

| 对象                     | 负责什么                                                                                                        | 明确不负责什么                                  |
| ------------------------ | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `LanguageServiceSession` | 持有一次 analysis session 的共享状态、revision、incremental invalidation、query dispatch、diagnostics streaming | 不执行 build graph，不生成第二套 compiler truth |
| `OpenDocumentOverlay`    | 表达未保存源码、版本号和与磁盘内容的偏差                                                                        | 不直接写回磁盘，不重新定义 unit identity        |
| `AnalysisSnapshot`       | 表达某个稳定 revision 下的语义视图、diagnostics view 与 query-consumable facts                                  | 不充当长期 workspace authority，不成为 UI model |

这里的重点是：

- session 是共享分析拥有者
- overlay 是 editor state 的正式输入
- snapshot 是 query 与 renderer 可以安全消费的稳定视图

## open file overlay 必须是第一类输入，而不是 IDE 私货

如果 future IDE 要做到“未保存也能看错误、跳定义、改名预检查”，那 open document state
就不能继续等价于磁盘文件。

因此 nextPas 冻结：

- 未保存源码以 `OpenDocumentOverlay` 进入 service，而不是偷偷写临时文件再调用编译器
- overlay 至少要绑定 `FileId` 或等价 source identity、document version、text payload
- 同一 `LanguageServiceSession` 可以同时持有多个活动 overlay
- service 返回的 query / diagnostics 结果必须能说明自己基于哪个 analysis revision
- 当 overlay 与磁盘内容不一致时，build path 不能被伪装成“已经和编辑器分析完全一致”

这条规则直接避免 FPC `fpintf.pas` 那种“先执行编译器，再从文本消息里恢复编辑器状态”的旧路。

## 增量失效必须以 `UnitGraph` 和语义依赖为边界

高性能 language service 不能建立在“每按一个键就整工程重编”的前提上。

nextPas 要求：

- overlay 变更先失效对应 source entry，再按 `UnitGraph` 和语义依赖向外传播
- 未受影响的 syntax tree、semantic facts、interned identities 与 diagnostics 应尽量复用
- 失效传播至少要区分 syntax-only、name-resolution、semantic 和 query-cache 这几类影响面
- 新 revision 产生后，旧 revision 允许继续被正在显示的 UI 短暂消费，但不能再扩展为新的真相
- 过时分析任务必须允许被取消或被更新 revision 覆盖

这条边界承接 `compiler-pipeline-specification.md` 里已经冻结的会话级、unit 级和阶段级生命周期，
也承接 `unit-resolution-specification.md` 对 `UnitGraph` 的正式要求。

## semantic query 必须直接消费 snapshot，而不是消费消息文本

nextPas language service 至少要把这些查询族写成正式表面：

- go to definition / declaration
- hover / type summary / symbol summary
- document symbols / workspace symbols
- find references
- rename preflight 与 structured edit plan
- completion candidates

这些查询共同遵守以下规则：

- query 先消费 `AnalysisSnapshot`，不直接读 UI 控件状态
- rename 返回结构化编辑计划，不允许退化成盲目文本替换
- completion 可以延后冻结排序策略，但候选来源必须来自语义真相
- document / workspace symbol 查询不能绕开 `UnitGraph` 和 workspace roots 私扫目录

这意味着 future IDE、CLI 甚至 formatter/refactor surface，都应该站在同一条 query contract 上。

当前 `stage0` 已经先落地一条最小 CLI-facing probe：
`nextpas query symbols <source> --target linux-x86_64 [--toolchain-binding <id>] [--workspace <root>]`。
这条路径复用 `TCompilationSession` 执行 syntax、unit resolution 与 semantic analysis，并把
`query-kind=symbols`、`query-status=success`、`analysis-source=compilation-session`
与 `query-result-count=<count>` 投影到 line-based output 和 `command-envelope=<json>`。
这里的 `analysis-source` 必须保持为 `compilation-session`，因为当前还没有正式
`LanguageServiceSession`、open document overlay、incremental invalidation 或 protocol adapter。

## diagnostics streaming 必须复用结构化 diagnostics，而不是解析 stderr

`diagnostics-specification.md` 已经把诊断冻结成结构化记录。language service 必须直接复用它，
而不是重新发明 editor-only diagnostics。

因此 nextPas 冻结：

- service 向上游暴露的是 diagnostics stream / diagnostics snapshot，而不是格式化后的终端文本
- 每条 diagnostics 都继续保留 `DiagnosticCode`、`Severity`、`Phase`、`PrimarySpan` 等字段
- IDE renderer、CLI renderer 和 future protocol adapter 共享同一条结构化记录来源
- localized message、pretty formatting、squiggle rendering 属于消费层，不属于 service core
- toolchain / build failure 如果需要进入 workbench，也必须以已结构化的 diagnostics surface 进入

这条规则会直接消灭 `fpintf.pas` 那种靠 `Error:` / `Hint:` 文本前缀推断严重级别的历史耦合。

## target-aware analysis 属于 service 输入，但 tool invocation 不属于它

nextPas 既然要覆盖 cross compilation、LLVM backend、C interop 和更完整的开发环境，
language service 也必须尊重 target selection。

因此：

- service session 必须绑定来自 `WorkspaceModel` 或等价 workspace truth 的 target selection
- conditional compilation、target-visible units、ABI-sensitive semantic checks 继续消费 `TargetFacts`
- 更换 target 可能触发大范围 invalidation，但这是 analysis truth 的一部分，不是 IDE 自己决定的
- assembler/linker/archiver/resource tool 调用仍属于 `toolchain-specification.md` 的控制面
- language service 不得为了“更方便预览”就自己拼接 build command

这样 cross target editor analysis、CLI semantic query 和真实 build path 才能共享同一套 target truth。

更细的 workspace roots、package refs、`TargetSelection` 和 `ArtifactRootSet` 由
`workspace-specification.md` 定义。

## workspace、package、build 与 test 必须只是邻接边界，不是 service 所有权

language service 处在 developer workflow 中央，但它不是所有系统的拥有者。

nextPas 明确要求：

- workspace roots、package references、generated artifact roots、target selection 先属于 `WorkspaceModel`
- package install / fetch / update 不属于 language service
- build / run / debug intent 不属于 language service
- test grouping、snapshot evidence 与 test replay 不属于 language service

service 和这些系统的关系固定如下：

- 从 workspace 接收 source topology、target 和 package truth
- 向 IDE / CLI 提供 diagnostics、symbols、references、rename plan 等分析结果
- 把真正的 build/test/package intent 交回 driver、toolchain 与 harness

这条边界可以避免 language service 退化成“半个 IDE + 半个 build tool + 半个 package manager”的黑箱。

## IDE、CLI 与 future adapters 必须共用同一套语义真相

现代开发环境最怕的不是功能少，而是同一个工程在不同入口看到不同真相。

因此 nextPas 冻结：

- 在相同 workspace、相同 target、无 overlay 差异的前提下，CLI analysis 与 IDE analysis 必须收敛到同一套诊断和语义查询结论
- overlay 造成的“编辑中真相”必须有正式 revision 标识，不能伪装成磁盘 build 结果
- future LSP 只是 `LanguageServiceSession` 的 transport adapter，不是另一份语义实现
- IDE 不能维护私有 parser、私有 symbol index 或私有 diagnostics catalog

这条规则会直接决定 future IDE 是否真的可信。

## 性能模型必须从第一天写进 language service

nextPas 想要现代、高性能、优雅，就不能把 language service 写成“先能跑，之后再优化”。

第一阶段先冻结这些性能方向：

- 尽量复用 compiler 的 source database、green tree、interning 和 arena-owned facts
- query 结果优先绑定 analysis revision，避免跨 revision 偷复用脏结果
- unit 级 invalidation 优先于 workspace 全量失效
- diagnostics 与 query 优先延迟格式化，避免在热路径里提前生成大量字符串
- stale work cancellation 和 revision supersede 必须可实现，避免编辑时结果倒灌

这不是实现细节，而是 architecture contract。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 不承诺公开 language service binary、LSP server 或 IDE integration
  - 但 compiler pipeline、semantic model、diagnostics 和 target truth 必须按 shared analysis 方向收敛
  - 当前 `query symbols` 只能作为 compilation-session-backed 的最小 CLI semantic query，
    可以投影 `querySymbols`、`queryScopes` 与 `queryTypes` 这类 session-owned semantic
    graph snapshots，但不能被描述成完整 language service
- `stage1`
  - 开始把 `LanguageServiceSession`、overlay、snapshot 和 query surface 收紧成正式内部边界
  - 可以先以进程内 API 或受控实验入口验证 analysis contract
- `stage2`
  - 只有在 compiler、workspace truth、toolchain replay、GUI framework 和 IDE workbench 都稳定后，
    才值得进入 nextPas 自有 IDE 或独立 protocol surface 的正式实现阶段

这条阶段关系的重点是：先冻结 shared semantic truth，再讨论协议和 UI。

## 第一阶段非目标

- 不把这份规范写成“马上交付一个 LSP server”
- 不让 language service 重新实现 compiler front-end
- 不让 IDE 或协议 adapter 反向定义语义和诊断
- 不让 language service 自己接管 build、package manager 或 test harness
- 不把未保存文件支持退化成临时文件 + shell command 的兼容技巧

第一阶段真正要交付的是：一份把 nextPas language service 写成“共享分析控制面”的正式架构规范。
