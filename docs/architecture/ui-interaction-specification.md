# nextPas UI interaction 规范

用这份规范定义 nextPas 长期 UI interaction control plane 的稳定边界。它回答的不是
“以后键盘和鼠标事件怎么分发一下”，而是“平台输入、焦点流转、快捷键、菜单动作、辅助技术请求和
text edit session 应该怎样收敛成统一 Pascal UI stack 的交互真相，才能让 nextPas 的 GUI
framework、editor、future IDE 和 automation surface 共用同一条 input/focus/command line，
而不是重新回到 widget callback、平台事件结构体和 workbench 私有命令系统各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`ui-layout-specification.md`、
`ui-style-theme-specification.md`、`ui-motion-specification.md`、
`ui-text-layout-specification.md`、`ui-accessibility-specification.md`、
`ui-rendering-specification.md`、`ide-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、
platform shell 宿主边界、runtime control plane、general layout control plane、style/theme
control plane、motion control plane、text/layout control plane、accessibility control plane、
rendering control plane 与 future IDE workbench；这里冻结 interaction 本身的正式控制面。

## 先看 FPC 真源码已经把 input / focus / command 相关能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/x11/src/xi2.pp`
  - 直接列出 `XI_KeyPress`、`XI_KeyRelease`、`XI_ButtonPress`、`XI_ButtonRelease`、
    `XI_Motion`、`XI_Enter`、`XI_Leave`、`XI_FocusIn`、`XI_FocusOut`
  - 还列出 `XI_RawKeyPress`、`XI_RawButtonPress`、`XI_RawMotion`、`XI_TouchBegin`、
    `XI_TouchUpdate`、`XI_TouchEnd`
  - 说明 pointer、keyboard、focus、raw input、touch 和多设备输入都是真实平台事实
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkwidget.inc`
  - 直接暴露 `grab_focus`、`focus`、`event`
  - 还暴露 `button_press_event`、`button_release_event`、`scroll_event`、
    `motion_notify_event`、`key_press_event`、`key_release_event`、`focus_in_event`、
    `focus_out_event`
  - 同时暴露 `selection_*`、`drag_*` 和 `get_accessible`
  - 说明现代 GUI 交互天然把输入、焦点、selection、drag-and-drop 和 accessibility 紧耦合在
    widget callback 上
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtktextview.inc`
  - 直接保留 `im_context`
  - 还暴露 `move_cursor`、`insert_at_cursor`、`delete_from_cursor`、`cut_clipboard`、
    `copy_clipboard`、`paste_clipboard`、`move_focus`
  - 说明 text edit、clipboard、focus traversal 和 keybinding action 在 toolkit 里本来就是
    同一条交互线
- `/home/dtamade/projects/fpc/packages/fv/src/views.inc`
  - 直接写 `PositionalEvents: Word = evMouse`
  - 也直接写 `FocusedEvents: Word = evKeyboard + evCommand`
  - `TGroup.HandleEvent` 还分成 `phPreProcess`、`phFocused`、`phPostProcess`
  - 对 positional event 走 contains-mouse 路由，对 focused event 走 current view 路由
  - 说明 pointer routing、focused routing 和 pre/post process 本来就是独立控制面
- `/home/dtamade/projects/fpc/packages/fv/src/views.inc`
  - 长期维护 `SelectNext`、`SetCurrent`、`sfFocused`
  - 说明 focus traversal 和 current owner 的维护是真实架构问题
- `/home/dtamade/projects/fpc/packages/fv/src/editors.inc`
  - `EventMask := evMouseWheel + evMouseDown + evKeyDown + evCommand + evBroadcast`
  - `TEditor.ConvertEvent` 还会把 `evKeyDown` 转成 `evCommand`
  - 说明 keybinding 到 command intent 的转换，在历史实现里也是单独存在的控制线

这些事实组合起来说明：

- FPC 生态里并不是没有 input、focus、command routing
- 它的问题是这些能力分散在平台事件常量、widget callback、text widget action 和 TUI event loop 里
- 当前源码树没有一份把 platform input normalization、focus ownership、command intent 和
  route mediation 收成统一 Pascal interaction control plane 的正式架构

nextPas 如果不把这层单独冻结，future controls、editor、command palette、menu bar、tool window、
debug panel 和 accessibility action 很快又会各自长一套交互真相。

## interaction 必须是 GUI stack 里的独立控制面，而不是 `UiRuntime` 的一句注脚

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-text-layout-specification.md` 已经冻结 `TextInputSession`；
`ui-accessibility-specification.md` 已经冻结 `AccessibilityAction`。但这些文档都不会替代
interaction 自身的正式边界。

nextPas 在这里进一步冻结：

- `PlatformShell` 继续负责接入 native pointer / keyboard / touch / drag-and-drop / clipboard /
  text service 事件
- interaction control plane 负责把平台输入、menu/toolbar action、shortcut trigger 和
  accessibility request 收成稳定 interaction truth
- `FocusPath` 负责维护 active focus owner、focus scope、traversal 和 current interaction owner
- `InteractionRouter` 负责把 `InputEvent`、`AccessibilityAction` 和 command source 正式路由到
  `UiScene`、`TextInputSession` 与 `UiRuntime`
- `CommandIntent` 负责表达 activate、cancel、copy、paste、next panel、open palette 这一类
  backend-neutral 交互意图
- style/theme control plane 继续消费 focus / hover / pressed / selected 一类 visual-facing state，
  但 interaction 不直接拥有 appearance semantics
- motion control plane 继续消费 state change 与 command result，并决定 reveal / fade / pulse /
  scroll settle 一类 temporal behavior，但 interaction 不直接拥有 timer lifecycle
- hit-testing、focus reveal 和 viewport-adjacent geometry 继续建立在稳定 layout truth 之上

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| PlatformShell / menu / toolbar / command palette     |
| keyboard / pointer / touch / DnD / clipboard         |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| InputEvent / AccessibilityAction / command trigger   |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| InteractionRouter                                    |
| normalize / hit-test / focus route / command route   |
+-------------+--------------------+-------------------+
              |                    |                   |
              v                    v                   v
+----------------------+  +------------------+  +------------------+
| FocusPath            |  | TextInputSession |  | CommandIntent    |
| current owner /      |  | composition /    |  | activate / copy /|
| traversal / scope    |  | edit mediation   |  | save / navigate  |
+----------+-----------+  +--------+---------+  +--------+---------+
           |                       |                     |
           +-----------+-----------+---------------------+
                       |
                       v
+------------------------------------------------------+
| UiScene / UiRuntime                                  |
| control semantics / state mutation / async handoff   |
+------------------------------------------------------+
```

这张图的硬约束是：

- 平台输入在进入 scene 之前，必须先经过正式 interaction control plane
- 焦点、shortcut、菜单动作、辅助技术动作不能各自维护不同的 command 语义
- text editing 继续是 text system 的会话，不被 raw key callback 重新吞回平台层

## 只冻结四个 interaction 对象，不把这层膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 interaction 上只冻结四个核心对象：

- `InputEvent`
- `FocusPath`
- `CommandIntent`
- `InteractionRouter`

| 对象                | 负责什么                                                                                    | 明确不负责什么                                           |
| ------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| `InputEvent`        | 表达 pointer、keyboard、wheel、touch、drag/drop、clipboard、host text service 等规范化输入  | 不直接携带平台 widget 指针，不直接改 scene 或 text       |
| `FocusPath`         | 表达 active focus owner、focus scope、traversal order、temporary capture 与 current owner   | 不重新做 layout，不自己解释 command 或 text semantics    |
| `CommandIntent`     | 表达 activate、cancel、copy、paste、save、navigate、toggle、close 等 backend-neutral 意图   | 不等价于 shell command，不拥有平台 keymap                |
| `InteractionRouter` | 把 `InputEvent`、`AccessibilityAction` 和 command source 路由到 scene、focus、text、command | 不拥有 `UiScene` truth，不替代 `TextInputSession` 或 IDE |

这里最关键的边界是：

- `InputEvent` 先定义“宿主发生了什么”
- `FocusPath` 再定义“当前谁应该接这类输入”
- `CommandIntent` 定义“最终交互语义是什么”
- `InteractionRouter` 最后定义“这些事实怎样稳定流过 UI stack”

## `InputEvent` 必须先是规范化交互输入，而不是平台结构体透传

`xi2.pp` 和 `gtkwidget.inc` 已经说明：平台世界里的输入事件种类很多，而且不断把 raw、
focus、pointer、touch、selection、drag/drop 混在宿主 callback 里。

因此 nextPas 冻结：

- `InputEvent` 必须先是 nextPas 规范化交互对象，而不是 `GdkEvent*`、`XEvent*` 或其他平台结构体
- 它至少要能区分 device kind、event kind、position、delta、modifiers、button/key identity、
  phase、timestamp 和 source surface
- raw input 可以存在，但它不能绕开正式路由直接改 UI 状态
- text composition / commit 如果来自宿主 text service，也应作为受控 interaction 输入进入，再由
  `TextInputSession` 接管

这样 nextPas 才不会重新掉回：

- Linux 一套事件字段
- macOS 一套事件字段
- editor 再自己发明一套“内部按键对象”

## `FocusPath` 必须拥有 focus scope、traversal 和 current owner 真相

`views.inc` 已经把 `FocusedEvents`、`SelectNext`、`SetCurrent`、`sfFocused` 写成真实系统行为。
这说明 focus 不是 widget 附件，而是架构边界。

因此 nextPas 要求：

- `FocusPath` 是 active interaction owner 的正式表达
- 它至少要能描述 focused node、focus scope、modal boundary、tab traversal 和 temporary capture
- keyboard-focused owner、menu-focused owner、text-edit owner 和 pointer-captured owner 必须能被
  清楚区分，而不是都挤进一个布尔值
- focus 变化应能稳定地产生 delta，供 accessibility、IDE workbench 和 style/theme control plane
  共同消费
- 同一份 focus / hover / pressed delta 也必须能被 motion control plane 消费，触发统一 reveal /
  pulse / settle 行为

这条规则的意义很直接：

- command palette、editor、project tree、settings form 可以共用同一条 focus 线
- modal surface、popup、context menu、drag capture 不需要各自重写焦点逻辑
- IDE 的 panel switching 和 app runtime 的 control traversal 可以建立在同一套控制面上

## `CommandIntent` 必须把 shortcut、menu、toolbar 和 accessibility action 收成同一条命令线

`editors.inc` 把 `evKeyDown` 转成 `evCommand`，已经说明历史实现里就存在“按键不等于最终命令”的边界。
nextPas 要把这件事写得更清楚：

- `CommandIntent` 是交互语义，而不是输入设备
- 同一个命令可以来自 shortcut、menu item、toolbar button、context menu、command palette、
  accessibility action 或 automation trigger
- `CommandIntent` 至少要能表达作用域、target identity、payload 和 cancelability 一类受控字段
- IDE workbench 的 close tab、next diagnostic、open command palette 这一类命令，也必须进入
  同一条命令线，而不是私有 event bus

这条分层直接挡住两种坏结构：

- 每个 UI surface 自己解释一套快捷键和按钮行为
- accessibility action、menu action、keyboard shortcut 对同一功能触发出不同结果

## `InteractionRouter` 必须是唯一推荐的 routing owner

`TGroup.HandleEvent` 已经证明：focused routing、positional routing、preprocess 和 postprocess
都是正式问题，不是写几个 callback 就能自然收口。

因此 nextPas 冻结：

- `InteractionRouter` 是 interaction control plane 的主调度者
- positional input 先根据 `LayoutSnapshot` 支撑的 hit-testing 和 current capture 做 routing
- focused input 先根据 `FocusPath` 做 routing
- command source 先归一到 `CommandIntent`，再进入 `UiRuntime`
- editable text input 先归一到 `TextInputSession`

也就是说：

- pointer route 不等于 keyboard route
- text edit 不等于 command route
- accessibility action 也不是一条额外旁路

所有这些线都必须经过同一个 router，而不是 scattered callback。

## text input 继续属于 `TextInputSession`，但它必须接在 interaction control plane 上

`gtktextview.inc` 里同时出现 `im_context`、`move_cursor`、`insert_at_cursor`、`delete_from_cursor`、
`cut_clipboard`、`copy_clipboard`、`paste_clipboard`、`move_focus`，这正好说明 text input 从来不是
单纯的 keydown 问题。

nextPas 明确要求：

- `InteractionRouter` 负责识别当前 `FocusPath` 下的 editable text owner
- 一旦目标是 editable text surface，router 应把相关输入合法转交给 `TextInputSession`
- `TextInputSession` 继续拥有 composition、selection mutation、clipboard mediation 和 edit command
- global shortcut 和 text-local edit command 必须能清楚区分，不能因为 key sequence 相同就混用

更细的 `TextContent`、`TextLayoutSnapshot`、`GlyphRun` 与 `TextInputSession` 由
`ui-text-layout-specification.md` 定义。
更细的 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。

## accessibility action 必须并回 interaction control plane，而不是单独开旁路

`ui-accessibility-specification.md` 已经冻结 `AccessibilityAction`，但 action 回流到 UI 时，
不能再重新走平台私货。

因此 nextPas 冻结：

- `AccessibilityAction` 进入 `InteractionRouter` 后，必须和 keyboard / menu / toolbar action
  收敛到同一条 `CommandIntent` / focus / text 路径
- focus request、invoke、expand/collapse、set selection、text navigation 一类 action，不允许绕开
  `FocusPath`、`TextInputSession` 或 `UiRuntime`
- automation surface 也应走这条统一回流线
- interaction control plane 是 accessibility 的上游共享交互内核，不是之后临时补的转接脚本

更细的 `AccessibilityNode`、`AccessibilitySnapshot`、`AccessibilityAction` 和
`AccessibilityBridge` 由 `ui-accessibility-specification.md` 定义。

## rendering 可以提供 hit-test 支撑，但不能反向拥有 input semantics

现代 UI 一定需要 geometry、clip、transform 和 visible region 才能做高质量 interaction。
但 nextPas 在这里明确：

- hit-testing 继续服务 interaction control plane，而不是让 rendering 变成 input owner
- `DrawPlan` 或等价 geometry cache 可以提供 routing 所需的可见区域和命中支撑
- `InteractionRouter` 继续拥有“该把输入交给谁”的最终语义决策
- backend 不允许自己维护第二套 hover / focus / capture tree

这条规则能避免出现“看起来点到了 A，实际事件却进了 B”的架构撕裂。

更细的 `DrawPlan`、`RenderGraph` 与 `SurfaceFrame` 由 `ui-rendering-specification.md` 定义。
更细的 `RenderAssetBundle` 资产线由 `render-asset-pipeline-specification.md` 定义。

## IDE 不能长出第二套 command system 和 focus routing

nextPas 长期不只是 compiler，也要有自有 IDE。这意味着 interaction 不能只停在 generic control。

因此 nextPas 要求：

- IDE editor、project tree、outline、command palette、terminal panel、test runner、settings form
  都必须建立在同一套 interaction control plane 上
- command palette 不是 IDE 私有 event bus，而是 `CommandIntent` 的一个高层入口
- workbench panel switch、editor focus、global shortcut 和 local text edit 不能互相踩边界
- future automation、macro、palette search、context action 也应建立在同一条命令线之上

更细的 IDE 边界由 `ide-specification.md` 定义。

## 性能模型必须从第一天进入 interaction 设计

用户目标是现代、高性能、优雅，因此 interaction 规范不能写成“先能派发事件，之后再整理”。

nextPas 第一阶段先冻结这些性能方向：

- `InputEvent` normalization 应尽量轻量，避免把平台事件复制成大量临时对象
- `FocusPath` 应支持稳定增量更新，而不是每次交互都全树扫描
- hit-testing、shortcut resolution 和 command dispatch 应尽量绑定受控 revision / scope
- router 不应因为一个 local interaction 就触发全场景重路由

这条规则的本质是：interaction 也是 UI runtime 的正式性能路径，不是附属 glue。

## `stage0`、`stage1` 与更后续阶段如何接 interaction

- `stage0`
  - 先只冻结 interaction control plane 的架构边界
  - 不要求当前最小 `nextpas build` 路径立刻支持完整 GUI interaction
- `stage1`
  - 可以开始收敛 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 的内部模型
  - 可以开始为最小 GUI runtime、editor surface 和 command surface 预留正式入口
  - 但不承诺完整 platform feature matrix
- `stage2`
  - 只有当 GUI framework、text/layout、accessibility、rendering 和 IDE workbench 都稳定后，
    更完整的 shortcut system、automation 和 advanced interaction policy 才适合进入正式实现波次

这条阶段关系的重点是：先把 interaction 写成共享系统边界，再决定哪些交互特性先落。

## 第一阶段非目标

- 不在这一阶段锁死具体平台 keybinding API、gesture API 或 event loop 名字
- 不把 interaction 规范写成 widget callback 列表
- 不让 IDE、text editor 或 accessibility bridge 反向拥有第二套 command/focus truth
- 不把 `TextInputSession` 重写成 global event bus
- 不提前承诺完整 gesture framework、macro system、plugin command marketplace 或 automation 产品面

第一阶段真正要交付的是：一份把 nextPas UI interaction 明确写成“规范化输入 +
稳定 focus path + 统一 command intent + 受控 routing”的正式架构规范。
