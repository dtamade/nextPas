# nextPas IDE 规范

用这份规范定义 nextPas 长期 IDE 体系的稳定边界。它回答的不是“以后做不做一个编辑器”，
而是“当 nextPas 完成 compiler kernel 和自有 GUI framework 之后，自己的 IDE 应该怎样建立在
同一套 workspace、language service、toolchain、test 与 package truth 之上，而不是重新长成
一套割裂的工具岛”。

这份文档和 `toolchain-specification.md`、`gui-framework-specification.md`、
`platform-shell-specification.md`、`ui-runtime-specification.md`、
`ui-rendering-specification.md`、`ui-text-layout-specification.md`、
`ui-interaction-specification.md`、`ui-layout-specification.md`、`ui-style-theme-specification.md`、
`ui-motion-specification.md`、
`ui-accessibility-specification.md`、`workspace-specification.md`、
`workspace-file-format-specification.md`、`language-service-specification.md`、
`test-harness-specification.md`、`packages-specification.md`、
`package-workflow-specification.md`、`stage0-driver-specification.md` 一起工作。前者们分别冻结
工具链控制面、GUI stack、platform shell 宿主边界、runtime control plane、rendering control plane、
text/layout control plane、interaction control plane、general layout control plane、style/theme
control plane、motion control plane、accessibility control plane、workspace control plane、
persisted workspace file layer、shared analysis service、验证控制面、包生态、package workflow 与
当前最小 CLI；这里冻结 future IDE 的正式边界。

## 先看 FPC 真源码已经把 IDE / package / test surface 分散成什么样

这份规范直接回应 `/home/dtamade/projects/fpc/packages/` 里的这些真实事实：

- `packages/ide/fpmake.pp`
  - 包含 `gdb` / `libgdb` 检测、`msg2inc` 消息文件生成、编译器目录探测等复杂逻辑
  - 说明 IDE 与 compiler / debugger / build artifacts 耦合很深
- `packages/ide/`
  - 还直接暴露 `weditor.pas`、`fpcompil.pas`、`gdbmicon.pas`、`readme.ide` 等 terminal IDE 资产
  - 说明上游 IDE 路线本质上是历史集成型 workbench，而不是现代 service-oriented IDE
- `packages/testinsight/fpmake.pp`
  - `Description := 'Send FPCUnit test results to a webserver (e.g. embedded in Lazarus IDE).'`
  - 说明测试体验被做成附加集成，而不是统一测试控制面
- `packages/fppkg/fpmake.pp`
  - `Description := 'Libraries to create fppkg package managers.'`
  - 说明 package manager 能力也是独立工具库，而不是与 workspace / IDE 一体化设计

这些事实合起来说明：

- FPC 生态并不是没有 IDE、test integration、package manager 能力
- 但这些能力是分散的、历史累计的，而且经常直接绑在 compiler 或特定宿主流程上
- 当前源码树并没有一套建立在统一 UI framework、统一 language service、统一 build/test/package
  控制面之上的 next-generation Pascal IDE 架构

这正是 nextPas 需要主动定义自己 IDE 路线的原因。

## nextPas 的 IDE 必须建立在自有 GUI framework 之上

nextPas 已经明确 future GUI stack 不走 LCL 路线，因此 IDE 也必须跟着冻结这条关系：

- nextPas IDE 不是独立于 UI framework 的另一套可视化壳
- nextPas IDE 默认建立在 nextPas 自己的 GUI framework 之上
- IDE workbench、editor surface、panels、debug views、test views、package views 都属于同一套
  Pascal-first GUI stack 的上层应用

这条边界的意义是：

- compiler 完成之后，不是直接跳去做一堆 IDE 特判 UI
- 先完成自有 GUI framework，再让 IDE 建立在稳定 UI runtime / scene / render / shell 之上
- IDE 不重新回头依赖历史 widgetset compatibility layer

更细的 `DrawPlan`、`RenderGraph` 与 `SurfaceFrame` 由
`ui-rendering-specification.md` 定义。
更细的 `RenderAssetSourceSet` 与 `RenderAssetBundle` 由
`render-asset-pipeline-specification.md` 定义。
更细的 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding` 由
`platform-shell-specification.md` 定义。
更细的 `RuntimeClock`、`DispatchCycle`、`UiInvalidation` 和 `UiTaskQueue` 由
`ui-runtime-specification.md` 定义。
更细的 text/layout、glyph run、caret/selection mapping 与 IME/input session 由
`ui-text-layout-specification.md` 定义。
更细的 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 由
`ui-interaction-specification.md` 定义。
更细的 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。
更细的 `ThemeToken`、`StyleResolver`、`ThemeSnapshot` 和 `ThemeAssetSet` 由
`ui-style-theme-specification.md` 定义。
更细的 `MotionClock`、`MotionTransition`、`MotionSnapshot` 和 `MotionScheduler` 由
`ui-motion-specification.md` 定义。
更细的 `AccessibilityNode`、`AccessibilitySnapshot`、`AccessibilityAction` 和
`AccessibilityBridge` 由 `ui-accessibility-specification.md` 定义。

## IDE 不允许拥有第二套 runtime / event loop system

nextPas 既然已经把 runtime 写成正式控制面，IDE 也必须跟着冻结这条边界：

- IDE editor、project tree、terminal panel、test view、package view、preview pane 和 future designer
  surface 都必须建立在同一套 `RuntimeClock -> DispatchCycle -> UiInvalidation -> UiTaskQueue`
  线上
- workbench background build/test/package/lang-service result 必须通过同一条 `UiTaskQueue`
  回到 UI，而不是各自维护私有 main-thread callback
- IDE 不允许长期依赖 webview event loop、preview-only scheduler、workbench-local idle queue 或
  panel-specific frame pump

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套 runtime system。

## IDE 不允许拥有第二套 platform shell system

nextPas 既然已经把宿主接缝写成正式边界，IDE 也必须跟着冻结这条关系：

- IDE workbench window、popup、preview pane、clipboard、file drop、cursor policy 和 native surface
  都必须建立在同一套 `HostWindow -> DisplayTopology -> DataTransferSession -> SurfaceBinding`
  线上
- workbench 里的 package view、editor、test view、terminal panel 和 future designer surface
  不能各自维护私有 webview shell、私有 pasteboard bridge 或 preview-only host window glue
- IDE 不允许长期依赖第二套嵌入式窗口系统、第二套 clipboard/DnD bridge 或第二套 preview shell

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套宿主系统。

## IDE 不允许拥有第二套 palette / theme system

nextPas 既然已经把 style/theme 写成正式控制面，IDE 也必须跟着冻结这条边界：

- IDE editor、project tree、outline、terminal panel、test view、settings form、command palette、
  package view 和 future designer surface 都必须建立在同一套 `ThemeToken -> StyleResolver ->
ThemeSnapshot` 线上
- workbench theme selection、density choice 或 appearance preference 如果未来存在，也必须进入
  shared style/theme control plane，而不是 IDE 私有 palette resolver
- IDE 不允许长期依赖私有 CSS bridge、私有 icon registry、私有 webview theme shell 或
  workbench-local appearance callback

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套视觉系统。

## IDE 不允许拥有第二套 motion system

nextPas 既然已经把 motion 写成正式控制面，IDE 也必须跟着冻结这条边界：

- IDE editor、project tree、outline、terminal panel、test view、settings form、command palette、
  package view、preview pane 和 future designer surface 都必须建立在同一套
  `MotionClock -> MotionScheduler -> MotionSnapshot` 线上
- workbench panel transition、tree expand/collapse、editor reveal、preview playback 和 future component
  gallery 都不能各自维护私有 timer 或 animation coordinator
- IDE 不允许长期依赖 webview CSS transition、preview-only timing shell 或 workbench-local animation callback

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套 temporal system。

## IDE 不是另一个 compiler front-end

nextPas IDE 必须消费 compiler 和 language service，而不是重新实现 compiler。

因此 nextPas 冻结：

- compiler 负责解析、语义、诊断、incremental analysis、build intent
- IDE 负责把这些能力组织成可视化工作流
- IDE 不维护第二套 parser、第二套 diagnostics catalog、第二套 search path 语义
- IDE 的 project/workspace 模型必须复用已文档化的 `UnitGraph`、`TargetFacts`、
  `ToolchainBinding` 和 diagnostics contract

更细的 shared analysis、open file overlay、incremental invalidation 与 query contract 由
`language-service-specification.md` 定义。

否则 IDE 一旦和 compiler 分叉，后面所有“编辑器里对、命令行里错”的问题都会重新出现。

## 用这条分层作为唯一推荐方向

nextPas 推荐的 IDE 主骨架如下：

```text
Workbench UI
  -> WorkspaceModel
  -> LanguageServiceSession
  -> BuildOrchestrator
  -> TestOrchestrator
  -> Toolchain control plane / compiler kernel / harness
```

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| nextPas IDE                                          |
| editor / project tree / terminal / test / debug view |
+---------------------------+--------------------------+
                            |
     +----------------------+----------------------+
     |                      |                      |
     v                      v                      v
+------------+     +------------------+    +---------------+
| Workspace  |     | LanguageService  |    | Build/Test    |
| model      |     | session          |    | orchestrators |
+------------+     +------------------+    +---------------+
     |                      |                      |
     +----------------------+----------------------+
                            |
                            v
+------------------------------------------------------+
| compiler / toolchain / harness / package surfaces    |
+------------------------------------------------------+
```

这张图的硬约束是：

- IDE UI 只负责 workbench，不偷做编译器判断
- language service 不偷维护 package manager truth
- build/test orchestrator 不自己拼另一套工具链调用

## 只冻结四个核心对象，不把 IDE 写成万能黑箱

为了保持清楚而不过度膨胀，nextPas 先只冻结四个核心对象：

- `WorkspaceModel`
- `LanguageServiceSession`
- `BuildOrchestrator`
- `TestOrchestrator`

| 对象                     | 负责什么                                                                                           | 明确不负责什么                                      |
| ------------------------ | -------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| `WorkspaceModel`         | project/workspace roots、package references、target selection、editor-visible source topology      | 不重新定义 unit resolution 或 target facts          |
| `LanguageServiceSession` | open file state、incremental parse/analyze、go to definition、hover、rename、diagnostics streaming | 不重新实现编译器语义，不负责 build graph execution  |
| `BuildOrchestrator`      | 把 IDE build/run/debug intent 下沉到统一 driver / toolchain control plane                          | 不绕开 `ToolchainBinding` 私自找 linker / assembler |
| `TestOrchestrator`       | 驱动 `harness`、test grouping、snapshot replay、IDE test UX                                        | 不自己再造一套测试分类或证据格式                    |

这四层已经足够定义 IDE 的主骨架。debug adapter、package browser、profiler、designer 等后续能力，
都应该挂在这四层之上，而不是抢先当成新的基础层。

## `WorkspaceModel` 必须先于 IDE UI 被正式建模

FPC 的 package manager、IDE、编译器和测试能力分散存在，反过来说明一个问题：
workspace truth 没有被统一抽出来。

因此 nextPas 要求：

- workspace / project model 先是结构化对象，再是 IDE tree
- workspace 里的 target、package、source root、generated artifact root 都有正式字段
- IDE 显示的是 `WorkspaceModel` 的视图，不是本地目录树偶然长什么样就显示什么
- CLI、IDE、future package/workspace tools 应共用同一套 workspace truth

这样 IDE 才不会重新掉进“目录浏览器 + 若干临时按钮”的老路。

更细的 `WorkspaceModel`、`PackageRef`、`TargetSelection` 和 `ArtifactRootSet` 由
`workspace-specification.md` 定义。
更细的 workspace descriptor、package manifest、lockfile 和 root discovery 由
`workspace-file-format-specification.md` 定义。

## `LanguageServiceSession` 必须和 compiler 共用同一套语义真相

如果 future IDE 有补全、跳转、重命名、错误提示，那它背后就必须有正式 language service。

nextPas 要求：

- language service 复用 compiler 的 source database、syntax、semantic model 和 diagnostics contract
- open file overlays、incremental invalidation、semantic queries 是 service concerns，不是第二套语义系统
- IDE renderer 只显示 diagnostics / symbols / references，不重新解释诊断代码和语义类别
- CLI build 与 IDE analysis 对同一份源码必须能追溯到同一套核心 truth

这条规则会直接决定 future IDE 的可信度。

更细的 `LanguageServiceSession`、`OpenDocumentOverlay`、`AnalysisSnapshot` 和 diagnostics
streaming contract 由 `language-service-specification.md` 定义。

## `BuildOrchestrator` 只能站在统一 toolchain control plane 上

nextPas 已经有 `toolchain-specification.md`。IDE 必须服从它，而不是绕开它。

因此：

- IDE 的 build / run / debug / package intent 先变成结构化 build intent
- 再交给 driver / toolchain control plane 解析
- tool discovery、sysroot resolution、cross binding、response file、sidecar assets 仍由统一工具链负责
- IDE 不允许为了“看起来更方便”就自己拼一套 shell command

这条边界能避免 IDE 成为另一条无法回放、无法快照、无法 CI 对齐的隐式构建路径。

## `TestOrchestrator` 必须复用 `harness`

FPC `testinsight` 的存在说明测试可视化有价值，但 nextPas 不打算把测试 UI 设计成孤立插件。

因此 nextPas 要求：

- IDE test runner 复用 `test-harness-specification.md` 已经冻结的 test grouping 与证据模型
- IDE 的 test tree、test status、snapshot diff view 都建立在同一套 `harness` 输出之上
- 不因为 IDE 出现，就重新定义 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt`、
  `regression` 的分类
- CLI、CI 和 IDE 必须能回放同一份 test truth

这让 IDE test UX 是验证控制面的可视化层，而不是新的验证孤岛。

## 包生态与 IDE 不能脱节

FPC `fppkg` 说明 package manager 是真实需求，但 nextPas 不想重复“包工具是一套，IDE 又是另一套”的历史结构。

因此 nextPas 冻结：

- IDE 的 package view / dependency view / workspace package actions 必须建立在统一 package surface 上
- package metadata、source roots、resolved package graph 先属于 `WorkspaceModel`
- package install / update / fetch 如果未来存在，也必须复用统一 toolchain / package workflow
- IDE 不能自己保存一份私有 package lock / private dependency truth

这条边界是为了后续把 package manager、workspace manager、IDE 做成同一条产品线，而不是三种不兼容工具。
更细的 manifest/lock/install root 和 `pkg` result contract 由
`package-workflow-specification.md` 定义。
更细的 persisted file ownership 由 `workspace-file-format-specification.md` 定义。

## IDE 必须是 GUI framework 的上层产品，而不是 GUI framework 的前提

阶段顺序也必须明确：

- compiler kernel 先收敛
- GUI framework 再收敛
- IDE 建立在这两层之上

也就是说：

- GUI framework 不是为了 IDE 专门做的临时控件包
- IDE 是 GUI framework 的 flagship application 之一
- 一旦 GUI framework 和 IDE 互相倒置，UI stack 很快又会被 IDE 私货绑死

## `stage0`、`stage1` 与更后续阶段如何接 IDE

- `stage0`
  - 当前只承诺最小 `nextpas build` 与 `harness` 路径
  - IDE 明确不属于当前公开交付面
- `stage1`
  - compiler、toolchain、GUI framework 可以开始为 future IDE 提前收敛正式边界
  - 但 IDE 本体仍不是当前范围承诺
- `stage2`
  - 当 compiler、GUI framework、workspace truth、language service、toolchain replay 都稳定后，
    nextPas 才适合进入自有 IDE 的正式实现波次

这条关系也正好对应你的长期目标顺序：先编译器，再 UI framework，再 IDE。

## 第一阶段非目标

- 不把当前 `stage0` CLI 扩张成半个 IDE
- 不在这一阶段承诺 visual designer、debugger integration、plugin marketplace
- 不让 IDE 重新发明 compiler、toolchain、test 或 package truth
- 不让 IDE 反向主导 GUI framework 的基础抽象
- 不把历史 terminal IDE 或外部 IDE 适配层写成 nextPas 的长期主线

第一阶段真正要交付的是：一份把 nextPas IDE 明确写成“建立在自有 compiler + GUI framework
之上的统一开发环境 workbench”的正式架构规范。
