# nextPas UI rendering 规范

用这份规范定义 nextPas 长期 UI rendering control plane 的稳定边界。它回答的不是
“先选 Vulkan 还是 Metal”，而是“`UiScene` 如何下沉成稳定 draw plan、render pass、
surface present 与 render asset pipeline，才能让 nextPas 的 GUI 体系真正成为现代、
高性能、优雅的硬件加速 UI stack，而不是一堆平台 binding、OpenGL sample 或 toolkit canvas
的拼接物”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`ui-interaction-specification.md`、
`ui-layout-specification.md`、`ui-style-theme-specification.md`、
`ui-motion-specification.md`、`ui-text-layout-specification.md`、
`ui-accessibility-specification.md`、`runtime-bootstrap-specification.md`、
`toolchain-specification.md`、`distribution-layout-specification.md`、
`render-asset-pipeline-specification.md`、`ide-specification.md` 一起工作。前者们分别冻结 GUI
总体骨架、platform shell 宿主边界、runtime control plane、interaction control plane、
general layout control plane、style/theme control plane、motion control plane、text/layout
control plane、accessibility control plane、runtime handshake、toolchain control plane、公开发行布局、
render asset pipeline 与 future IDE workbench；这里冻结 rendering 自身的正式控制面。

## 先看 FPC 真源码已经把 rendering 相关能力分散成什么样

这份规范直接回应 `/home/dtamade/projects/fpc/packages/` 里的这些真实事实：

- `packages/gtk2/fpmake.pp`
  - `Description := 'Header to the GTK widgetset (v2.x).'`
  - 依赖 `x11` 和 `cairo`
  - 还明确写了 “This is all so complex... Use the build-unit...”
  - 说明这条路线本质上是 widgetset header + build complexity，不是统一 render control plane
- `packages/fpgtk/fpmake.pp`
  - `Description := 'Lightweight OOP wrapper over GTK1.'`
  - 说明 wrapper route 确实存在，但它不是新的 retained UI runtime
- `packages/opengl/fpmake.pp`
  - 直接暴露 `gl.pp`、`glu.pp`、`glut.pp`、`glx.pp`
  - 还带 `glxtest.pp` 等 sample
  - 说明 graphics API binding 存在，但 draw API binding 不等于 UI rendering architecture
- `packages/cocoaint/fpmake.pp`
  - 直接暴露 `CocoaAll.pas`、`CoreVideo.pas`、`GLKit.pas`、`SceneKit.pas`、`SpriteKit.pas`
  - 说明平台 graphics / media / scene API 很多，但它们属于平台接口族，不是统一 Pascal UI renderer
- `packages/x11/src/`
  - 公开 `xrender.pp`、`xinput2.pp`、`xshm.pp` 等窗口系统与扩展 binding
  - 说明 native surface / input / transport 层是真实存在的，但仍然不是 scene-to-render contract
- `packages/fv/fpmake.pp`
  - `Description := 'Free Vision, a portable Turbo Vision clone.'`
  - 说明 text UI 是另一条产品线，不能被误写成 modern GPU-backed rendering

这些事实组合起来说明：

- FPC 生态里有 widget binding、graphics binding、platform graphics binding 和 TUI
- 但没有一份把 scene、frame、pass、resource lifetime、asset pipeline 明确收成统一 rendering truth 的正式架构
- nextPas 如果只说“会硬件加速”，却不把这层控制面单独写清，最终还是会退回 wrapper + sample + post-build script

## rendering 必须是 GUI stack 里的独立控制面，而不是 `RenderBackend` 一行说明

`gui-framework-specification.md` 已经冻结了 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架，但那份文档回答的是“GUI stack 怎么分层”，不是“rendering 怎么运转”。

nextPas 在这里进一步冻结：

- `UiScene` 继续定义 UI 语义、layout、style、text 和 input routing
- style/theme control plane 继续负责 semantic visual truth，并把 resolved `ThemeSnapshot` /
  `ThemeAssetSet` 交给 rendering
- motion control plane 继续负责 sampled opacity / transform / reveal phase，并把 `MotionSnapshot`
  交给 rendering
- UI rendering 负责把 scene 结果下沉成 backend-neutral draw plan、pass dependency、
  surface present 和 render asset contract
- `RenderBackend` 继续是执行 owner，但不能既当 scene owner 又当 asset pipeline owner
- IDE workbench、future preview surface、offscreen snapshot 和 app window 都必须复用同一条 rendering truth

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| Pascal app / IDE workbench / preview surface         |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| UiScene + layout + text + theme + motion             |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| DrawPlan                                              |
| clip / transform / glyph run / image / layer intent  |
+------------------------------------------------------+
                        |
                        v
+------------------------------------------------------+
| RenderGraph                                           |
| pass DAG / transient attachments / composition        |
+------------------------------------------------------+
                        |
            +-----------+-------------+
            |                         |
            v                         v
+-----------------------+   +-------------------------+
| SurfaceFrame          |   | RenderAssetBundle       |
| target / scale / sync |   | shaders / atlases /    |
| / present contract    |   | font metadata / themes  |
+-----------------------+   +-------------------------+
            |                         |
            +-----------+-------------+
                        |
                        v
+------------------------------------------------------+
| RenderBackend + PlatformShell                        |
+------------------------------------------------------+
```

这张图的硬约束是：

- render truth 在 scene 之后、backend 之前显式存在
- asset pipeline 是正式层，不是 post-build 零散脚本
- on-screen surface 和 offscreen surface 继续走同一条 rendering control plane

## 只冻结四个 rendering 对象，不再把细节塞回 GUI 总规范

为了保持边界清楚且不过度膨胀，nextPas 在 UI rendering 上只冻结四个核心对象：

- `DrawPlan`
- `RenderGraph`
- `SurfaceFrame`
- `RenderAssetBundle`

| 对象                | 负责什么                                                                                              | 明确不负责什么                                         |
| ------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `DrawPlan`          | 表达 scene/layout/text/theme/motion 输出的 backend-neutral draw intent、clip、transform 和 layer 信息 | 不直接生成 GPU command，不拥有 native surface          |
| `RenderGraph`       | 把一次 frame 的 render pass、attachment dependency、composition 顺序与 transient resource 收紧        | 不重新解释 UI semantics，不充当 window manager         |
| `SurfaceFrame`      | 表达一次 present target 的像素尺寸、scale、sync policy、damage/resize 和 present 生命周期             | 不定义 scene，不决定 package/layout truth              |
| `RenderAssetBundle` | 表达 shader package、icon atlas、font metadata、theme/image asset 等 render-side compiled inputs      | 不替代 package manager，不保存 workspace/package graph |

这里最关键的边界是：

- `UiScene` 仍然是 retained UI 语义 owner
- `UiRuntime` 仍然拥有 frame clock、event dispatch 与 resource lifetime 的外层时序
- rendering 这四个对象只把 scene 到 backend 之间原本最容易失控的部分正式化

## `DrawPlan` 必须是 backend-neutral 且增量友好的下沉结果

如果 nextPas 的 rendering 想高性能，就不能让每个 backend 自己从 scene 树重新猜一遍怎么画。

因此 nextPas 冻结：

- `DrawPlan` 是 `UiScene` 与 render execution 之间的正式桥梁
- 它至少要能表达 clip stack、transform、text run、image draw、shape fill/stroke、
  effect/layer boundary 和 hit-test 需要的可见性信息
- 它不暴露具体 GPU API 细节，也不把 `gl*`、`mtl*`、`vk*` 之类名字写进公开 contract
- small UI mutation 应该尽量只导致局部 draw plan invalidation，而不是强迫全树重降级

这条规则直接挡住两种坏方向：

- immediate callback 风格的“到 backend 里再说”
- 每个 backend 各自维护一份 scene lowering 逻辑

这里的 hit-test / visibility 信息只提供 rendering-facing geometry 支撑，不让 `DrawPlan`
反向成为 interaction 或 accessibility semantics owner。更细的 `InputEvent`、`FocusPath`、
`CommandIntent` 与 `InteractionRouter` 由 `ui-interaction-specification.md` 定义。更细的
`LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 与 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。更细的
accessibility tree、action 与 platform bridge 边界由 `ui-accessibility-specification.md`
定义。

## `RenderGraph` 必须表达 pass dependency，而不是一串随手调用

FPC 的现有 graphics packages 证明了 API binding 可以很多，但它们没有回答“复杂 UI frame
怎样稳定执行”的问题。

nextPas 在这里明确：

- UI frame 的执行顺序应进入 `RenderGraph`
- pass boundary 至少要能解释 opaque/content pass、text/glyph pass、effect/composition pass、
  offscreen layer pass 和 final present pass 这一类关系
- transient attachment、intermediate texture、resolve target 和 dependency ordering 应该有正式归属
- render graph 是 execution plan，不是公开 UI DSL

这条边界的目的，是让 rendering 在复杂效果、offscreen composition、IDE preview、future designer
surface 出现后仍然可解释、可回放、可调试。

## `SurfaceFrame` 必须把 native surface 生命周期单独关住

只要 UI 框架真的进入硬件加速，window resize、DPI 变化、occlusion、vsync、offscreen target、
present failure 就都是正式问题。

因此 nextPas 要求 `SurfaceFrame` 至少要能解释：

- target surface identity
- logical size 与 pixel size
- scale factor / DPI facts
- present mode / sync policy
- resize / lost surface / recreate boundary
- damage 或 partial redraw 语义

这里最重要的职责分界是：

- `PlatformShell` 负责把 native surface 与 window lifecycle 暴露出来
- `SurfaceFrame` 负责把一次 frame 真正面对的 present target 收成稳定 contract
- `RenderBackend` 消费 `SurfaceFrame`，但不反向拥有窗口系统

这样同一套 render path 才能同时服务 app window、IDE panel、preview pane 和 offscreen snapshot。

更细的 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding` 由
`platform-shell-specification.md` 定义。

## `RenderAssetBundle` 必须进入 toolchain，而不是留给运行时临时解析

GUI 真正进入硬件加速后，最容易在 shader、font、icon atlas、theme image、effect metadata
这些资产上重新长出“本机脚本能跑就行”的坏结构。

因此 nextPas 冻结：

- shader compilation、shader reflection、icon atlas generation、font preprocessing、
  theme/image preprocessing 如果未来存在，都应收敛到 `RenderAssetBundle`
- `ThemeAssetSet` 继续拥有 semantic theme asset family，`RenderAssetBundle` 只拥有 render-side
  compiled payload
- `RenderAssetBundle` 是 render-side compiled input，不是 package manifest，不是 runtime config dump
- 这些 sidecar 资产必须由 `ToolchainBinding + ToolInvocationPlan` 生产或验证
- runtime 可以 lazy-load bundle 内容，但不应在每次启动时重新做昂贵预处理

这条规则直接承接 `toolchain-specification.md`：render asset pipeline 也必须是 thin entrypoint +
shared core，而不是 UI 私有脚本群。
更细的 `RenderAssetSourceSet`、bundle identity、asset build 与 install/control plane 关系由
`render-asset-pipeline-specification.md` 定义。

## text、glyph 和 image composition 不能成为 backend 私货

现代 UI rendering 里，text 往往是最重也最容易碎裂的子系统。

nextPas 不提前锁死具体 text engine 名字，但先冻结这些边界：

- text shaping/layout 的语义结果先进入 `UiScene` / `DrawPlan`
- glyph atlas、font metadata、subpixel/raster strategy 属于 rendering control plane
- image decoding 与 theme asset loading 可以有 specialized helpers，但它们对 rendering 的可见结果
  仍应经由 `RenderAssetBundle` 和 `DrawPlan`
- backend 不允许因为自己好实现，就偷偷定义第二套 text/image contract

更细的 logical text、layout snapshot、glyph run、caret/selection mapping 与 IME/input session 由
`ui-text-layout-specification.md` 定义。

否则 IDE editor、GUI controls、preview surface 与 app runtime 很快又会各画各的字。

## 性能模型必须从第一天进入 rendering 设计

既然用户目标是现代、高性能、优雅，rendering 规范不能只谈分层，不谈性能。

第一阶段先冻结这些性能方向：

- draw plan invalidation 优先做结构化 diff，不优先整树重构
- render graph 应允许 transient attachment reuse，而不是每帧重新分配全部资源
- `SurfaceFrame` 应允许 partial damage / partial redraw 语义，不把全窗口 repaint 设成默认
- render asset preprocessing 优先离线或 build-time 进行，不把 shader/font/icon 预处理全压到运行时
- on-screen 与 offscreen frame 继续复用同一套 draw plan / render graph contract，减少双实现

这几条不等于现在就实现完整优化器；它们只是保证架构不会天然把性能做差。

## rendering 与发行布局必须共享同一套公开落点

`distribution-layout-specification.md` 已经冻结了 `units/<target>/`、`lib/` 和 `share/`
的公开语义。UI rendering 不允许例外。

因此：

- public Pascal UI/render units
  - 继续落在 `units/<target>/`
- private render helpers、compiled shader pack、backend support library、pipeline metadata
  - 落在 `lib/nextpas/ui/render/` 或等价私有 `lib/` 子树
- themes、icon/image assets、font metadata、examples、docs
  - 落在 `share/nextpas/ui/` 或等价共享 `share/` 子树

这样 people 才能解释一个 render asset 到底是公开 API、私有支持物，还是共享内容。

## cross target rendering 仍然不能逃离统一 target truth

UI rendering 一旦涉及 shader target、surface capability、font asset packing、sysroot library、
present support，就已经进入 target-aware territory。

因此 nextPas 明确：

- rendering 不单独维护第二套 platform matrix
- render helper tool、shader compiler、surface support library 继续受 `TargetFacts + ToolchainBinding`
  控制
- cross-compiling GUI app 或 IDE shell 时，render asset bundle 仍按 target key 产出与安装
- `host == target` 不能因为 GUI 看起来“更上层”就被重新写死

这条边界很关键，不然 GUI 一到 cross compilation 又会退回“本机先跑起来”的历史脚本模型。

## IDE 与 preview tooling 只能消费同一条 rendering truth

nextPas IDE 将来会是这套 GUI framework 的 flagship application，但 IDE 不允许拥有另一条 renderer。

因此：

- IDE editor、panel、test result view、preview pane 都应建立在 `UiScene -> DrawPlan -> RenderGraph`
  这条控制线上
- future design preview、component gallery、snapshot capture 也应复用同一条 `SurfaceFrame`
  与 render asset contract
- IDE 不允许为了“先做出来”就塞一个私有 webview/canvas renderer，当成长期路线

这条规则是为了避免 UI framework 和 IDE 又重新长成两套图形系统。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 rendering control plane 的对象边界
  - 不承诺当前最小 `nextpas build` 立刻支持 GUI app、shader tool 或 preview surface
- `stage1`
  - 可以开始实现最小 `DrawPlan`、单 surface present、最小 render asset pipeline 与 offscreen proof path
  - 但仍必须服从同一套 runtime/toolchain/distribution truth
- `stage2`
  - 只有在 scene/runtime/render/surface/asset bundle 都稳定后，才值得继续调查 richer effect pipeline、
    hot reload、designer tooling、advanced preview workflow

这条阶段关系的重点是：先把 scene-to-render 这条控制线写对，再决定哪一层先落实现。

## 第一阶段非目标

- 不在这一阶段锁死 Vulkan / Metal / OpenGL / D3D 的具体主 API
- 不把 widget wrapper、`gl*` sample 或 platform graphics binding 误写成新的 UI renderer
- 不把 text shaping、image decoding、shader preprocessing 各自拆成独立产品线
- 不让 IDE 或 preview tooling 长出私有 renderer
- 不把 visual designer、effect editor、live-reload pipeline 写成当前阶段承诺

第一阶段真正要交付的是：一份把 nextPas UI rendering 明确写成“scene lowering +
render graph + surface contract + asset pipeline”的正式架构规范。
