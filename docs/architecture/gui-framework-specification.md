# nextPas GUI 框架规范

用这份规范定义 nextPas 长期 GUI 体系的稳定边界。它回答的不是“先选哪个 widget toolkit”，
而是“nextPas 作为下一代 Pascal 开发环境，应该怎样把 GUI runtime、UI framework、
GPU-backed rendering、platform shell 与 asset/tooling 边界写清，才能走向现代、高性能、
优雅的 UI stack，而不是重新回到 LCL 式兼容层”。

这份文档和 `overview.md`、`packages-specification.md`、`runtime-bootstrap-specification.md`、
`toolchain-specification.md`、`distribution-layout-specification.md` 一起工作。前者定义顶层方向，
其余文档分别冻结包生态、runtime handshake、工具链控制面与发行布局；这里冻结 GUI stack
本身的正式边界。如果你要看 future IDE 怎样建立在这套 GUI stack 之上，继续读
`ide-specification.md`。如果你要看 `RuntimeClock`、`DispatchCycle`、`UiInvalidation` 和
`UiTaskQueue` 怎样把 `UiRuntime` 单独冻结成正式 control plane，继续读
`ui-runtime-specification.md`。如果你要看 `HostWindow`、`DisplayTopology`、
`DataTransferSession` 和 `SurfaceBinding` 怎样把 `PlatformShell` 单独冻结成正式宿主边界，继续读
`platform-shell-specification.md`。如果你要看 `UiScene` 之后的 `DrawPlan`、`RenderGraph`、
`SurfaceFrame` 怎样单独冻结，继续读 `ui-rendering-specification.md`。如果你要看 shader、
icon atlas、font metadata、theme/image preprocessing 和 `RenderAssetBundle` 怎样单独冻结，继续读
`render-asset-pipeline-specification.md`。如果你要看 text/layout、glyph run、caret/selection、
IME/input session 怎样单独冻结，继续读 `ui-text-layout-specification.md`。如果你要看
input event、focus path、command intent 和 interaction router 怎样单独冻结，继续读
`ui-interaction-specification.md`。如果你要看 layout node、constraint、snapshot 和
invalidation 怎样单独冻结，继续读 `ui-layout-specification.md`。如果你要看
`ThemeToken`、`StyleResolver`、`ThemeSnapshot` 和 `ThemeAssetSet` 怎样单独冻结，继续读
`ui-style-theme-specification.md`。如果你要看 `MotionClock`、`MotionTransition`、
`MotionSnapshot` 和 `MotionScheduler` 怎样单独冻结，继续读
`ui-motion-specification.md`。如果你要看
accessibility node、snapshot、action 和 platform bridge 怎样单独冻结，继续读
`ui-accessibility-specification.md`。

## 先看 FPC 真源码已经把 GUI 相关能力分散成什么样

这份规范直接回应 `/home/dtamade/projects/fpc/packages/` 里的真实事实：

- `packages/gtk2/fpmake.pp`
  - `Description := 'Header to the GTK widgetset (v2.x).'`
  - 依赖 `x11` 和 `cairo`
  - 还专门保留 `buildgtk2.pp` 这种复杂 build-unit
- `packages/fpgtk/fpmake.pp`
  - `Description := 'Lightweight OOP wrapper over GTK1.'`
  - 本质上仍是 GTK1 wrapper，不是新的 UI runtime
- `packages/x11/src/`
  - 提供 `x.pp`、`xrender.pp`、`xinput2.pp`、`xshm.pp` 等原始窗口系统 / 扩展绑定
- `packages/opengl/fpmake.pp`
  - 提供 `gl.pp`、`glu.pp`、`glut.pp`、`glx.pp`
  - 说明图形加速能力也以独立 binding package 形式存在
- `packages/cocoaint/fpmake.pp`
  - 面向 `darwin`
  - 直接暴露 `CocoaAll.pas`、`CoreVideo.pas`、`GLKit.pas`、`SpriteKit.pas` 等平台接口
- `packages/fv/fpmake.pp`
  - `Description := 'Free Vision, a portable Turbo Vision clone.'`
  - 说明 FPC 生态里也保留了 TUI / text UI 路线
- 当前 `/home/dtamade/projects/fpc/packages/` 里并不存在 `lcl/`、`lazarus/` 或 `fpGUI/`
  这样的目录

这些事实组合起来说明了一件很重要的事：

- FPC 生态里确实有很多 GUI / graphics / window-system 相关能力
- 但它们大多是 binding、wrapper、compatibility layer 或单个平台接口
- 当前源码树并没有一套统一、语言级、硬件加速、跨平台抽象一致的 Pascal GUI framework

这正是 nextPas 应该主动设计新 GUI stack 的理由，而不是理由不足。

## nextPas 的 GUI 目标不是 LCL compatibility layer

nextPas 在 GUI 方向上先冻结一个明确立场：

- 不把 GUI story 定义成“给 LCL 换一层现代皮肤”
- 不把 GUI story 定义成“把若干 toolkit binding 打包成看起来更整齐的 wrapper”
- 不把 GUI story 定义成“让 compiler 直接内建一套 UI 魔法语法”

nextPas 真正要做的是：

- 一个新的 Pascal-first GUI framework
- 一个默认面向硬件加速渲染的 UI runtime
- 一个和 runtime、toolchain、distribution、package story 共用同一套系统边界的 UI stack

这条立场的意义，是从第一天就挡住“先兼容历史 widgetset，架构以后再说”的回流。

## 用这条分层作为唯一推荐方向

nextPas 推荐的 GUI 主骨架如下：

```text
Pascal application code
  -> UI framework API
  -> UiScene
  -> UiRuntime
  -> RenderBackend
  -> PlatformShell
  -> OS window / GPU surface
```

为了让这条分层更可读，先用一个简化的 ASCII 示意：

```text
+--------------------------------------------------+
| nextPas app                                      |
| state / commands / UI declarations               |
+-------------------------+------------------------+
                          |
                          v
+--------------------------------------------------+
| UiScene                                          |
| retained tree / layout / style / text / input    |
+-------------------------+------------------------+
                          |
                          v
+--------------------------------------------------+
| UiRuntime                                        |
| frame clock / event dispatch / resource lifetime |
+-------------------------+------------------------+
                          |
              +-----------+-----------+
              |                       |
              v                       v
+--------------------------+  +--------------------+
| RenderBackend            |  | PlatformShell      |
| GPU passes / surfaces    |  | window / IME / DnD |
+--------------------------+  +--------------------+
```

这里最重要的约束是：

- 应用代码不直接拼平台 API
- `UiScene` 不直接持有 OS-specific window facts
- `RenderBackend` 不回头定义 UI 语义
- `PlatformShell` 不反向主导布局、样式或 scene 模型

更细的 scene-to-render lowering、pass dependency、surface lifecycle 与 render-side asset contract
由 `ui-rendering-specification.md` 定义。

## 只冻结四个核心对象，不再膨胀名词

为了保持边界清楚但不过度造词，nextPas 先只冻结四个核心对象：

- `UiScene`
- `UiRuntime`
- `RenderBackend`
- `PlatformShell`

它们分别负责：

| 对象            | 负责什么                                                                                      | 明确不负责什么                                      |
| --------------- | --------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| `UiScene`       | retained UI tree、layout、style、text flow、focus / input routing 的逻辑模型                  | 不直接调用 OS API，不直接管理 GPU 命令              |
| `UiRuntime`     | frame clock、event dispatch、resource lifetime、async-to-UI handoff、application session      | 不重新定义 windowing，不私自决定 draw backend       |
| `RenderBackend` | GPU-backed rendering、surface submission、composition、text/image/shape draw plan 的执行      | 不重新发明 widget semantics，不充当 package manager |
| `PlatformShell` | window、clipboard、IME、cursor、accessibility、native surface integration、system chrome glue | 不定义跨平台 UI API，不持有 compiler truth          |

这四层已经足够表达长期架构，不需要现在就继续发明第二层、第三层抽象名词。

更细的 `RuntimeClock`、`DispatchCycle`、`UiInvalidation` 和 `UiTaskQueue` 由
`ui-runtime-specification.md` 定义。
更细的 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding` 由
`platform-shell-specification.md` 定义。

## `UiScene` 必须是 retained、组合式的 UI 语义层

FPC 现有 package 事实已经说明：只靠平台 binding、widget wrapper 或 OpenGL binding，
得不到统一 GUI framework。

因此 nextPas 要求 `UiScene` 至少具备这些特征：

- retained tree，而不是每个平台 API 各自维护一套 widget object graph
- 组合式 UI 语义，而不是强绑定原生控件族谱
- layout、text、style、input focus 都进入同一个逻辑模型
- UI 语义先于渲染后端存在，不因为 GPU backend 不同就分裂成两套 API

更细的 `TextContent`、`TextLayoutSnapshot`、`GlyphRun` 与 `TextInputSession` 由
`ui-text-layout-specification.md` 定义。
更细的 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 由
`ui-interaction-specification.md` 定义。
更细的 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。
更细的 `ThemeToken`、`StyleResolver`、`ThemeSnapshot` 和 `ThemeAssetSet` 由
`ui-style-theme-specification.md` 定义。
更细的 `MotionClock`、`MotionTransition`、`MotionSnapshot` 和 `MotionScheduler` 由
`ui-motion-specification.md` 定义。

这等于明确拒绝两种老路：

- 一种是 GTK / Cocoa / Win32 各自包装一层，最后 UI 语义完全跟平台走
- 另一种是只有 draw calls，没有正式 scene / layout / event 语义

## `RenderBackend` 必须默认面向硬件加速

既然 nextPas 的 GUI 方向已经明确不是 LCL，也不是纯 widgetset compatibility layer，
那渲染层就不能继续建立在“CPU paint callback + toolkit canvas”的默认前提上。

因此 nextPas 冻结：

- `RenderBackend` 默认是 GPU-backed rendering interface
- scene 到 rendering 的下沉必须保留 batch / composition / clip / transform / text/image pass 语义
- backend 可以有不同实现，但公开 UI contract 不能随着 backend 切换而改写
- software fallback 如果将来存在，也只能是降级路径，不是主架构出发点

更细的 `DrawPlan`、`RenderGraph` 与 `SurfaceFrame` 由
`ui-rendering-specification.md` 定义。
更细的 `RenderAssetSourceSet` 与 `RenderAssetBundle` 由
`render-asset-pipeline-specification.md` 定义。

这里不提前锁死 Vulkan、Metal、D3D 或 OpenGL 中的某一个具体 API。当前阶段先锁的是
“硬件加速是主路径”，而不是“API 名字现在就必须一次定死”。

## `PlatformShell` 必须把窗口系统接缝单独关住

FPC `packages/x11/`、`packages/gtk2/`、`packages/cocoaint/` 已经证明，windowing / platform API
差异是真实存在的。

因此 nextPas 不能假装“跨平台 UI”意味着平台层消失，而是要把它隔离到 `PlatformShell`：

- window creation / destruction
- monitor / DPI / surface size updates
- IME / clipboard / drag-and-drop
- pointer / keyboard / touch ingestion
- system chrome / native integration
- accessibility bridge

这样 platform integration 是正式层，但不会反向吞掉 scene、layout 和 rendering contract。

更细的 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 由
`ui-interaction-specification.md` 定义。
更细的 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。
更细的 `AccessibilityNode`、`AccessibilitySnapshot`、`AccessibilityAction` 和
`AccessibilityBridge` 由 `ui-accessibility-specification.md` 定义。
更细的 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding` 由
`platform-shell-specification.md` 定义。

## compiler 不为 GUI 发明第二套语言

nextPas 的 GUI framework 是 Pascal-first，但这不等于 compiler 要为 GUI 特判一堆新语法。

因此先冻结：

- GUI 不引入“只有 UI 才能用”的语言子方言
- compiler 继续只负责正常 Pascal 语义、类型系统、泛型、模块和 toolchain integration
- GUI API 作为 runtime / package surface 暴露，而不是 compiler 魔法
- 如果未来需要 declarative UI DSL，也必须建立在已文档化的语言与 library 边界之上

这条规则很关键。否则 GUI 很容易反过来把 compiler 重新拖进框架私货。

## GUI stack 必须跨 `rtl/`、`packages/`、toolchain 三层协同

GUI 既不是纯 package，也不是纯 runtime，更不是纯 tool binary。nextPas 要求：

- `rtl/`
  - 负责 GUI stack 需要复用的底层 runtime primitives，例如时钟、任务调度、资源生命周期基础设施
- `packages/`
  - 负责公开的 UI framework API、controls、style system、higher-level application model
- toolchain
  - 负责 GUI 相关 sidecar tools，例如未来可能出现的 shader compilation、asset packing、
    icon atlas generation、font preprocessing

更细的 `ThemeToken`、`StyleResolver`、`ThemeSnapshot` 和 `ThemeAssetSet` 由
`ui-style-theme-specification.md` 定义。

这意味着 GUI 体系必须和 `toolchain-specification.md` 对齐：

- GUI asset/shader tools 若出现，必须进入 `ToolchainBinding`
- 不允许每个 UI package 在 post-build 脚本里各自偷偷调一堆外部工具
- diagnostics、cache、replay 和 cross compilation 仍然走统一 toolchain control plane

## 发行布局必须给 GUI 资产留出正式落点

GUI 框架如果只有 Pascal 单元，没有资源与资产语义，最终还是会退化成临时拼装。

因此 nextPas 要求 future GUI stack 至少遵守这套落点：

- GUI public units
  - 继续落在 `units/<target>/`
- GUI private runtime helpers、GPU helper libraries、compiled support artifacts
  - 落在 `lib/nextpas/ui/` 或等价私有 `lib/` 子树
- GUI shared assets、themes、fonts metadata、examples、docs
  - 落在 `share/nextpas/ui/` 或等价共享 `share/` 子树

这条规则和 `distribution-layout-specification.md` 是同一条原则：公开路径要先设计清楚，
后续实现才不会把 UI runtime 资产散落回临时目录。

## 交叉编译和 GUI 不能各写各的 target truth

只要 GUI 涉及 GPU surface、windowing、text stack 或平台资产，就会和 target facts 打交道。

因此 nextPas 明确：

- GUI stack 不能单独维护第二套 platform matrix
- 哪些 shell/backend 可用于哪个 target，仍然由 `TargetFacts + ToolchainBinding` 决定
- cross-compiling GUI app 时，sysroot、library resolution、GUI helper artifacts 继续走统一控制面
- GUI 不是逃离 compiler/toolchain architecture 的例外区

否则一到 cross target，UI stack 就会重新回到“本机先能跑起来再说”的历史泥潭。

## `stage0`、`stage1` 与更后续阶段如何接 GUI

- `stage0`
  - 先只冻结 GUI framework 的架构边界
  - 不要求当前最小 `nextpas build` 路径立刻支持 GUI application
- `stage1`
  - 可以开始播种 UI runtime primitives、public package surface 和最小 render path
  - 但仍必须服从同一套 runtime/toolchain/distribution truth
- `stage2`
  - 只有在 GUI scene/runtime/render/platform shell 边界都稳定后，才值得继续调查 designer tooling、
    hot reload、richer visual workflow 或更复杂的 app model

这条阶段关系的重点是：先把 architecture 写对，再决定哪一层先实现。

当 compiler kernel 和 GUI framework 都稳定后，nextPas 的自有 IDE 才应进入正式实现波次。
更细的 IDE 边界由 `ide-specification.md` 定义。

## 第一阶段非目标

- 不把 LCL compatibility 写成长期主线
- 不把 GTK / Cocoa / Win32 wrapper 重新包装成“新框架”
- 不在这一阶段锁死具体 GPU API 名称
- 不把 compiler 扩展成 GUI-specific sublanguage
- 不提前承诺 visual designer、form file format 或 IDE 集成

第一阶段真正要交付的是：一份把 nextPas GUI 体系明确写成“全新、硬件加速、Pascal-first、
不走 LCL 路线”的正式架构规范。
