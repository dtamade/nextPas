# nextPas UI layout 规范

用这份规范定义 nextPas 长期 general UI layout control plane 的稳定边界。它回答的不是
“以后先做 stack、split、grid 还是别的什么布局器”，而是“bounds negotiation、container
arrangement、scroll viewport、resize propagation 和 workbench panel geometry 应该怎样进入统一
Pascal UI stack，才能让 nextPas 的 GUI framework、editor、future IDE 和 preview surface
共享同一条 layout truth，而不是重新回到 toolkit container、text widget、scroll view 和 TUI bounds
逻辑各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`ui-interaction-specification.md`、
`ui-style-theme-specification.md`、`ui-motion-specification.md`、
`ui-text-layout-specification.md`、`ui-accessibility-specification.md`、
`ui-rendering-specification.md`、`ide-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、
platform shell 宿主边界、runtime control plane、interaction control plane、style/theme
control plane、motion control plane、text/layout control plane、accessibility control plane、
rendering control plane 与 future IDE workbench；这里冻结 general layout 本身的正式控制面。

## 先看 FPC 真源码已经把 general layout 相关能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtklayout.inc`
  - 直接暴露 `gtk_layout_put`、`gtk_layout_move`、`gtk_layout_set_size`、`gtk_layout_get_size`
  - 还暴露 `gtk_layout_get_hadjustment`、`gtk_layout_get_vadjustment` 与 `gtk_layout_freeze`、
    `gtk_layout_thaw`
  - 说明 child placement、content extent、scroll adjustment 和 layout freeze/thaw 都是真实问题
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtktextview.inc`
  - 对象里直接持有 `layout` 与 `pending_scroll`
  - 还暴露 `gtk_text_view_scroll_to_iter`、`gtk_text_view_scroll_to_mark`、
    `gtk_text_view_get_visible_rect`
  - 说明 text widget 的 viewport、visible rect 和 scroll-to-caret 在 toolkit 里被单独维护
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtktreeview.inc`
  - 暴露 `set_scroll_adjustments`
  - 还暴露 `gtk_tree_view_scroll_to_point`、`gtk_tree_view_scroll_to_cell`
  - 说明 tree / outline / explorer 这一类 structured view 也天然带 viewport 和 scroll geometry
- `/home/dtamade/projects/fpc/packages/fv/src/views.inc`
  - `TScroller.ScrollTo`、`TScroller.ChangeBounds`、`TScroller.SetLimit` 长期维护 delta、limit、
    scrollbar params 和 redraw
  - `TWindow.CalcBounds` 还会围绕 `ZoomRect` 重算 bounds
  - 说明 scroll surface、resize、window geometry 和 bounds recalculation 都是真实控制面
- `/home/dtamade/projects/fpc/packages/fv/src/dialogs.inc`
  - `TDialog.CalcBounds` 根据 owner size 和 delta 重新计算 bounds
  - 说明相对布局、resize propagation 和 grow/shrink policy 也是正式边界

这些事实组合起来说明：

- FPC 生态里并不是没有 layout、viewport、scroll 和 resize 逻辑
- 它的问题是这些事实分散在 toolkit container、text view、tree view、TUI scroller 和 dialog bounds
  算法里
- 当前源码树没有一份把 layout semantics、constraint propagation、resolved bounds、scroll viewport
  和 invalidation 收成统一 Pascal layout control plane 的正式架构

nextPas 如果不把这层单独冻结，future controls、editor split、side bar、outline tree、terminal panel、
preview surface 和 settings form 很快又会各自长一套 geometry truth。

## layout 必须是 GUI stack 里的独立控制面，而不是 scene 或 rendering 的附注

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-text-layout-specification.md` 已经冻结 text/layout control plane；
`ui-interaction-specification.md` 已经冻结 input/focus/command routing。它们都重要，但不会替代
general layout 自身的正式边界。

nextPas 在这里进一步冻结：

- `UiScene` 继续拥有 container、panel、scroll surface、overlay、split 和 workbench node 的语义来源
- layout control plane 负责把 available space、child policy、scroll viewport 和 bounds negotiation
  收成稳定 layout truth
- style/theme control plane 可以提供 resolved density、padding role、border thickness 和 minimum
  control metric 这类 visual-facing metric input，但最终几何仍然归 layout control plane 所有
- motion control plane 可以提供 sampled reveal ratio、scroll settle offset 和 animated metric input，
  但最终几何仍然归 layout control plane 所有
- text layout 继续负责文本本身的 line breaking 和 caret mapping，但它建立在已知 layout constraint 上
- interaction、accessibility 和 rendering 都必须消费同一份 resolved layout geometry
- `PlatformShell` 继续只提供 surface size、DPI 与宿主 window facts，不反向拥有 layout semantics

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| Pascal app / IDE workbench / preview surface         |
+------------------------------------------------------+
                            |
                            v
+------------------------------------------------------+
| UiScene layout subtree                               |
| panel / split / overlay / scroll / control nodes     |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| LayoutConstraint                                      |
| available size / min-max / viewport / scale facts    |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| LayoutSnapshot                                        |
| bounds / child placement / viewport / scroll extent  |
+-------------+----------------------+-----------------+
              |                      |                 |
              v                      v                 v
+----------------------+  +------------------+  +------------------+
| TextLayoutSnapshot   |  | InteractionRouter|  | Accessibility    |
| text leaf geometry   |  | hit-test input   |  | geometry consumers|
+----------+-----------+  +--------+---------+  +--------+---------+
           |                       |                     |
           +-----------+-----------+---------------------+
                       |
                       v
+------------------------------------------------------+
| DrawPlan / RenderGraph / RenderBackend               |
+------------------------------------------------------+
```

这张图的硬约束是：

- general layout truth 在 `UiScene` 和 rendering / interaction / accessibility 之间显式存在
- text layout 不是整套 UI layout 的替代品
- split、panel、scroll viewport、overlay geometry 不能只留给 IDE 私货或平台 container

## 只冻结四个 layout 对象，不把这层膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 general layout 上只冻结四个核心对象：

- `LayoutNode`
- `LayoutConstraint`
- `LayoutSnapshot`
- `LayoutInvalidation`

| 对象                 | 负责什么                                                                                         | 明确不负责什么                                           |
| -------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| `LayoutNode`         | 表达某个 UI node 的 layout semantics，例如 stack、split、overlay、scroll container、leaf measure | 不直接持有平台 widget，不直接做 text shaping 或 GPU draw |
| `LayoutConstraint`   | 表达 available size、min/max、alignment、viewport、scale 与 parent-provided layout facts         | 不直接保存 child bounds，不自己做 command routing        |
| `LayoutSnapshot`     | 表达某次稳定 layout revision 下的 resolved bounds、child placement、viewport 与 scroll extent    | 不自己修改 scene，不重新 shape text                      |
| `LayoutInvalidation` | 表达 measure / arrange / viewport / resize 失效范围与重算边界                                    | 不替代 frame scheduler，不自己成为 render graph owner    |

这里最关键的边界是：

- `LayoutNode` 先定义“这个节点怎样参与布局”
- `LayoutConstraint` 再定义“父级和宿主给了它什么空间事实”
- `LayoutSnapshot` 定义“最终几何结果是什么”
- `LayoutInvalidation` 最后定义“哪里需要重算，重算到哪里为止”

## `LayoutNode` 必须先是语义布局对象，而不是 toolkit container wrapper

`gtklayout.inc`、`gtktreeview.inc` 和 `views.inc` 已经说明：container、scrollable view、dialog、
window、list viewer 都会携带自己的 bounds 语义。nextPas 要把这件事写得更彻底：

- `LayoutNode` 的 identity 应来自统一 `UiScene` 语义层，而不是平台 container 句柄
- panel、toolbar、split、editor group、overlay、status bar、tree view、scroll surface 之类角色，
  都应先是 nextPas layout semantics，再决定具体实现
- layout policy 至少要能表达 intrinsic sizing、stretch/shrink、alignment、padding/spacing、
  scrollability 和 child ordering 一类正式字段
- leaf control 可以很轻量，但不应该因此退回“每个控件自己算一个矩形”的私有路子

这条规则直接挡住两种坏结构：

- GTK 一套 container layout，IDE 再自己拼一套 workbench layout
- text/editor surface 之外的 controls 继续靠 ad-hoc bounds 计算维持

## `LayoutConstraint` 必须拥有 available size、viewport 和宿主 geometry 真相

现代 UI layout 真正容易碎掉的，不是能不能画出来，而是这些事实到底归谁：

- 当前 surface 给了多少空间
- min/max / preferred size 怎么约束
- scroll viewport 和 content extent 怎样相互作用
- resize / DPI 变化后，哪些节点必须重新 measure

nextPas 在这里明确：

- `LayoutConstraint` 是 parent-to-child layout negotiation 的正式载体
- 它至少要能表达 available width/height、min/max、layout direction、scale factor、viewport facts
  与 scroll offset context
- surface resize、window chrome 变化、panel collapse/expand 和 split ratio 变化，都应先变成
  新的 constraint 事实
- text node、list/tree node、editor viewport 和 simple control 都应消费同一类 constraint truth

这条规则的意义很直接：

- layout 不是“拿到最终大小后再算一下”
- scroll viewport 不是 interaction 层或 rendering 层单独决定的事情
- IDE workbench 和普通 app UI 可以共享同一套 geometry negotiation

## `LayoutSnapshot` 必须拥有 bounds、viewport 和 child placement 真相

`gtk_layout_set_size`、`gtk_text_view_get_visible_rect`、`gtk_tree_view_scroll_to_cell`、
`TScroller.ScrollTo`、`TDialog.CalcBounds` 这些事实都在指向同一个问题：最终几何结果必须有
稳定 owner。

因此 nextPas 冻结：

- `LayoutSnapshot` 是一次稳定 layout revision 的 owner
- 它至少要能表达 resolved bounds、child placement、visible viewport、content extent、
  clip-facing geometry 和 scroll position
- node identity 应尽量跨小幅 UI 更新保持稳定，避免轻微状态变化就把整棵 layout tree 重建成新对象
- interaction、accessibility、rendering 应共同消费同一份 snapshot，而不是各自重算几何

这条规则能直接提供：

- hit-testing 的正式几何来源
- accessibility extents 和 visible region 的正式来源
- render lowering 的稳定 bounds 输入

## `LayoutInvalidation` 必须把 measure / arrange / viewport dirty range 单独关住

如果 nextPas 想现代、高性能、优雅，就不能在每次 resize、scroll、panel toggle 后整棵 UI 树全量重排。

因此 nextPas 要求：

- `LayoutInvalidation` 至少要区分 measure invalidation、arrange invalidation、viewport invalidation
  与 scroll-only invalidation
- text changes、theme metric changes、panel collapse、window resize、scroll offset 变化应能落在不同
  失效面上
- motion-driven reveal / settle / collapse 变化也应能落在受控失效面上，而不是默认整树重排
- 子树级别的 layout 重算应尽量局部，而不是默认全场景重排
- 旧 snapshot 可以被正在显示的 UI 短暂消费，但不能继续扩展成新 revision 的 truth

这条边界承接 UI runtime 的 frame 调度，也承接未来 IDE 大型 workbench 的性能需求。

更细的 `RuntimeClock`、`DispatchCycle`、`UiInvalidation` 和 `UiTaskQueue` 由
`ui-runtime-specification.md` 定义。

## general layout 和 text layout 必须分工，而不是彼此覆盖

nextPas 已经有 `ui-text-layout-specification.md`，但那份文档回答的是文本怎样排，不是 panel /
split / viewport 怎样排。

因此 nextPas 明确：

- general layout control plane 负责 block/container geometry、available space、child arrangement、
  viewport 和 scroll extent
- text layout control plane 负责文字本身的 shaping、line breaking、caret/selection mapping 与
  glyph run
- text leaf node 应从 `LayoutConstraint` 获取可用空间，再产出自己的 `TextLayoutSnapshot`
- general layout 再把 text leaf 的测量结果收进统一 `LayoutSnapshot`

这条规则很关键，因为 code editor 不是唯一 layout-heavy surface，IDE workbench 也一样重。

更细的 `TextContent`、`TextLayoutSnapshot`、`GlyphRun` 与 `TextInputSession` 由
`ui-text-layout-specification.md` 定义。
更细的 `ThemeToken`、`StyleResolver`、`ThemeSnapshot` 和 `ThemeAssetSet` 由
`ui-style-theme-specification.md` 定义。
更细的 `MotionClock`、`MotionTransition`、`MotionSnapshot` 和 `MotionScheduler` 由
`ui-motion-specification.md` 定义。

## interaction 和 accessibility 只能消费同一份 layout geometry

只要 UI 有 pointer hit-testing、focus ring、screen reader extents、scroll-to-view、caret reveal，
layout geometry 就不能各算各的。

nextPas 明确要求：

- `InteractionRouter` 的 hit-testing 和 focus-adjacent geometry 必须来自 `LayoutSnapshot`
- `AccessibilitySnapshot` 的 bounds、visible region 和 viewport-facing extents 必须来自同一份
  layout truth
- focus reveal、scroll into view、command palette 定位、context menu anchor 和 tree item extents
  不允许各自维护第二套矩形系统
- text-facing geometry 继续通过 `TextLayoutSnapshot` 接到同一条 layout line 上

更细的 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 由
`ui-interaction-specification.md` 定义。
更细的 `AccessibilityNode`、`AccessibilitySnapshot`、`AccessibilityAction` 和
`AccessibilityBridge` 由 `ui-accessibility-specification.md` 定义。

## rendering 消费 resolved layout，而不是反向拥有布局真相

现代 UI 一定需要 geometry、clip、layer boundary 和 scroll viewport 才能正确绘制，但 nextPas 在这里明确：

- `DrawPlan` 继续消费 `LayoutSnapshot` 与 `TextLayoutSnapshot`
- `RenderBackend` 不允许因为自己好实现，就偷偷维护第二套 bounds / viewport / clip 逻辑
- scroll damage、clip propagation 和 visible region 可以进入 rendering execution，但 general layout
  truth 仍然归 layout control plane 所有
- preview surface、offscreen snapshot 和主窗口继续共用同一份 layout 结果

这条规则是为了避免出现“画出来的位置”和“交互 / 辅助技术看到的位置”不一致。

更细的 `DrawPlan`、`RenderGraph` 与 `SurfaceFrame` 由 `ui-rendering-specification.md` 定义。
更细的 `RenderAssetBundle` 资产线由 `render-asset-pipeline-specification.md` 定义。

## IDE 不能为 workbench 再造第二套 layout system

nextPas 长期要有自己的 IDE，这意味着 layout 不能只服务普通 controls。

因此 nextPas 冻结：

- editor group、side bar、bottom panel、outline、terminal、test runner、settings form、command palette
  都必须建立在同一套 general layout control plane 上
- dock / split / overlay / transient popup 如果未来存在，也必须先接到 `LayoutNode` /
  `LayoutConstraint` / `LayoutSnapshot`
- IDE 不允许为了 workbench 复杂度就私自维护另一套 panel geometry truth
- future designer / preview / inspector 如果出现，也应继续消费同一份 layout snapshot

更细的 IDE 边界由 `ide-specification.md` 定义。

## 性能模型必须从第一天进入 layout 设计

用户目标是现代、高性能、优雅，因此 layout 规范不能写成“先把 bounds 算出来，之后再优化”。

nextPas 第一阶段先冻结这些性能方向：

- layout 失效优先局部传播，不默认全树重算
- viewport / scroll 变化应尽量复用已有 measure 结果
- text leaf 的测量缓存应能和 general layout 协同，而不是相互打穿
- layout snapshot 应绑定稳定 revision，避免 interaction / accessibility / rendering 看到撕裂状态

这条规则的本质是：general layout 也是 UI runtime 的正式性能路径，不是 scene 旁边的一段 helper。

## `stage0`、`stage1` 与更后续阶段如何接 layout

- `stage0`
  - 先只冻结 general layout control plane 的架构边界
  - 不要求当前最小 `nextpas build` 路径立刻支持完整 GUI layout system
- `stage1`
  - 可以开始收敛 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation`
  - 可以开始为最小 panel/container/scroll surface 预留正式入口
  - 但不承诺完整 layout policy family
- `stage2`
  - 只有当 GUI framework、interaction、text/layout、accessibility、rendering 和 IDE workbench 都稳定后，
    更复杂的 dock/split/designer surface 才适合进入正式实现波次

这条阶段关系的重点是：先把 layout 写成共享系统边界，再决定哪一类 container / panel 先落。

## 第一阶段非目标

- 不在这一阶段锁死具体 flex / grid / dock 算法名字
- 不把 general layout 规范写成某个 toolkit container API 对照表
- 不让 IDE panel system、render backend 或 accessibility bridge 反向拥有第二套 geometry truth
- 不把 text layout 误写成整套 UI layout 的替代品
- 不提前承诺完整 docking framework、visual designer、constraint solver 或 animation layout 产品面

第一阶段真正要交付的是：一份把 nextPas UI layout 明确写成“语义 layout node +
constraint propagation + stable layout snapshot + controlled invalidation”的正式架构规范。
