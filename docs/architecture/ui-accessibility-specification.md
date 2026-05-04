# nextPas UI accessibility 规范

用这份规范定义 nextPas 长期 UI accessibility control plane 的稳定边界。它回答的不是
“以后先接哪一个 screen reader API”，而是“语义角色、焦点状态、文本边界、可访问操作和平台桥接
应该怎样进入统一 Pascal UI stack，才能让 nextPas 的 GUI framework、editor、future IDE 和
automation surface 共享同一条 accessibility truth，而不是重新回到平台 binding、widget toolkit
accessible wrapper 和 IDE 私有补丁各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`ui-interaction-specification.md`、
`ui-layout-specification.md`、`ui-style-theme-specification.md`、
`ui-motion-specification.md`、`ui-text-layout-specification.md`、
`ui-rendering-specification.md`、`ide-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、
platform shell 宿主边界、runtime control plane、interaction control plane、general layout
control plane、style/theme control plane、motion control plane、text/layout control plane、
rendering control plane 与 future IDE workbench；这里冻结 accessibility 本身的正式控制面。

## 先看 FPC 真源码已经把 accessibility 相关能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/fpmake.pp`
  - `gtk2` package 明确把 `src/atk` 纳入 build
  - 还通过 `AddInclude` 引入 `atkobject.inc`、`atkcomponent.inc`、`atkaction.inc`、
    `atktext.inc` 等接口
  - 说明 accessibility object、geometry、action、text boundary 这些面向辅助技术的 contract
    都是真实需求
- `/home/dtamade/projects/fpc/packages/gtk2/src/atk/atkobject.inc`
  - 文件头直接写 `AtkObject represents the minimum information all accessible objects return`
  - 还暴露 accessible name / description / role / state / parent / children
  - 同时列出 `ATK_ROLE_DIALOG`、`ATK_ROLE_TEXT`、`ATK_ROLE_TREE`、`ATK_ROLE_WINDOW`
    等角色
  - 说明语义角色树不是 UI 附件，而是正式系统边界
- `/home/dtamade/projects/fpc/packages/gtk2/src/atk/atkcomponent.inc`
  - 暴露 `contains`、`ref_accessible_at_point`、`get_extents`、`get_position`、`get_size`、
    `grab_focus`、`get_layer`、`get_mdi_zorder`
  - 说明 geometry、hit-testing、focus、layering 也是 accessibility contract 的组成部分
- `/home/dtamade/projects/fpc/packages/gtk2/src/atk/atkaction.inc`
  - 暴露 `do_action`、`get_n_actions`、`get_description`、`get_name`、`get_keybinding`
  - 说明 accessible action 是独立控制面，不是点击事件的副产品
- `/home/dtamade/projects/fpc/packages/gtk2/src/atk/atktext.inc`
  - 暴露 `get_caret_offset`、`get_offset_at_point`、`get_selection`、`set_selection`、
    `get_character_extents`
  - 说明 text boundary、caret、selection 和 character geometry 必须和 accessibility 对齐
- `/home/dtamade/projects/fpc/packages/cocoaint/src/MediaAccessibility.pas`
  - 直接声明 `unit MediaAccessibility;`
  - 还直接 `{$linkframework MediaAccessibility}`
  - 说明平台 accessibility framework 真实存在，但当前仍属于平台接口族的一部分
- `/home/dtamade/projects/fpc/packages/fv/fpmake.pp`
  - `Description := 'Free Vision, a portable Turbo Vision clone.'`
  - 说明 TUI / editor 交互路线真实存在
- `/home/dtamade/projects/fpc/packages/fv/src/editors.inc`
  - 长期维护 clipboard、selection、cursor、word wrap、search/replace 一类 editor 交互逻辑
- `/home/dtamade/projects/fpc/packages/fv/src/views.inc`
  - 长期维护 cursor visibility 和 focus/view state

这些事实组合起来说明：

- FPC 生态里并不是没有 accessibility 相关能力
- 它的问题是这些能力分散在 toolkit binding、platform framework binding、text boundary API 和
  editor 私有交互逻辑里
- 当前源码树没有一份把 semantic tree、focus/state、text boundary、accessible action 和
  platform bridge 收成统一 Pascal accessibility control plane 的正式架构

nextPas 如果不把这层单独冻结，future GUI controls、code editor、project tree、command palette、
settings form 和 IDE workbench 很快又会各自长一套 accessibility truth。

## accessibility 必须是 GUI stack 里的独立控制面，而不是 `PlatformShell` 的附带说明

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-text-layout-specification.md` 已经冻结 `TextContent`、
`TextLayoutSnapshot`、`GlyphRun`、`TextInputSession`。但这些文档都不会替代 accessibility
自身的正式边界。

nextPas 在这里进一步冻结：

- `UiScene` 继续拥有 controls、editor、panel 和 workbench 的语义来源
- `TextLayoutSnapshot` 继续拥有 text boundary、caret、selection 与 character geometry 真相
- accessibility control plane 负责把 role、name、description、state、relation、action 和
  focusable structure 收成稳定 accessibility truth
- style/theme control plane 继续拥有 focus ring、contrast adaptation 和 visual appearance 真相，
  accessibility 不自己维护第二套 palette / theme system
- motion control plane 继续拥有 reduced-motion adaptation 与 temporal policy，accessibility 可以提供
  preference input，但不自己维护第二套 timer / animation system
- `AccessibilityBridge` 负责把统一语义映射到平台 accessibility API 和 automation surface
- `AccessibilityAction` 负责把辅助技术请求合法回流到 `UiRuntime`、focus routing 和
  `TextInputSession`

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| Pascal app / editor / IDE workbench                  |
+------------------------------------------------------+
                            |
                            v
+------------------------------------------------------+
| UiScene                                              |
| control semantics / editor semantics / focus intent  |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| TextLayoutSnapshot                                   |
| text boundary / caret / selection / char geometry    |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| AccessibilityNode set                                |
| role / label / state / relation / bounds reference   |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| AccessibilitySnapshot                                |
| stable tree / focused node / selection-facing state  |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| AccessibilityBridge                                  |
| platform API mapping / automation / event emission   |
+---------------------------+--------------------------+
                            |
                            v
      OS accessibility APIs / screen reader / automation

OS action / accessibility request
            |
            v
  AccessibilityBridge -> AccessibilityAction
            |
            v
  UiRuntime / focus routing / TextInputSession
```

这张图的硬约束是：

- accessibility truth 在 `UiScene` 和平台 bridge 之间显式存在
- text boundary、caret 和 selection 不能只留给 editor 私货或平台层
- screen reader、switch control、keyboard navigation 和 IDE automation 必须复用同一条语义线

## 只冻结四个 accessibility 对象，不把这层膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 accessibility 上只冻结四个核心对象：

- `AccessibilityNode`
- `AccessibilitySnapshot`
- `AccessibilityAction`
- `AccessibilityBridge`

| 对象                    | 负责什么                                                                                         | 明确不负责什么                                         |
| ----------------------- | ------------------------------------------------------------------------------------------------ | ------------------------------------------------------ |
| `AccessibilityNode`     | 表达单个可访问语义单元的 role、label、description、state、relation、bounds reference 与 text ref | 不直接拥有 native widget，不直接做 layout 或 rendering |
| `AccessibilitySnapshot` | 表达一次稳定 accessibility tree、focused node、selection-facing state 与可消费语义视图           | 不重新 shape text，不自己生成第二套 scene model        |
| `AccessibilityAction`   | 表达 invoke、focus、expand、scroll、set value、set selection 等结构化可访问操作                  | 不绕开 `UiRuntime` / `TextInputSession` 直接改状态     |
| `AccessibilityBridge`   | 把 snapshot、delta 和 action 映射到平台 accessibility API、automation surface 与事件流           | 不反向拥有语义树，不保存第二份 text 或 focus truth     |

这里最关键的边界是：

- `AccessibilityNode` 先定义“哪个东西对辅助技术可见，以及它是什么”
- `AccessibilitySnapshot` 再定义“当前 frame / revision 下整棵语义树是什么样”
- `AccessibilityAction` 定义“辅助技术合法地要求 UI 做什么”
- `AccessibilityBridge` 最后定义“这些真相怎样进入平台世界”

## `AccessibilityNode` 必须先是语义对象，而不是平台 widget wrapper

ATK 已经明确把 role、state、parent/children、name/description 当成 accessible object 的最小集合。
nextPas 需要把这件事写得更彻底：

- `AccessibilityNode` 的 identity 应来自统一 UI 语义层，而不是来自平台控件句柄
- dialog、button、tree item、text field、editor viewport、tab、menu item、status item 之类角色，
  都应先是 nextPas 语义，再被映射到平台角色
- node 至少要能表达 label、description、role、state、relation 和 geometry reference
- text-bearing node 还要能引用 `TextLayoutSnapshot` 提供的 boundary / caret / selection 事实

这样 nextPas 才不会回到这些坏结构：

- GTK 一套 accessible node，Cocoa 再一套 accessible node
- IDE editor 再额外拼一套“专供 screen reader”的隐藏对象树
- simple controls 和 code editor 各自解释“焦点”“选中”“展开”的含义

## `AccessibilitySnapshot` 必须拥有稳定 tree、focus 和 geometry 真相

`atkcomponent.inc` 已经说明 `ref_accessible_at_point`、`get_extents`、`grab_focus` 这些能力
不是附加项，而是 contract。

因此 nextPas 冻结：

- `AccessibilitySnapshot` 是一次稳定 accessibility revision 的 owner
- 它至少要能表达 node hierarchy、focused node、selected node set 或等价 selection-facing state、
  visible semantics 和 geometry mapping
- node identity 应尽量跨小幅 UI 更新保持稳定，避免每次 frame 都把整棵树重建成新对象
- geometry 继续来自 `LayoutSnapshot` / `TextLayoutSnapshot` 的已存在真相，而不是 accessibility
  再自己算一遍 layout

这条规则的意义很直接：

- `ref_accessible_at_point` 一类查询有正式落点
- focus 变化、selection 变化、tree expand/collapse 可以从 snapshot delta 中清楚描述
- IDE workbench 和 app runtime 可以共享同一套辅助技术可见结构

## `AccessibilityAction` 必须是结构化回流，而不是直接调用控件内部私货

ATK 已经把 `do_action`、action name、keybinding 写成正式接口。nextPas 也必须承认：
辅助技术不是只读消费者，它会驱动 UI。

因此 nextPas 冻结：

- `AccessibilityAction` 是结构化 intent，而不是平台 callback 原样透传
- action 至少要覆盖 focus、invoke、toggle、expand/collapse、scroll、set value、
  set selection 和 text navigation / edit 这一类基础请求
- text-related action 必须经过 `TextInputSession`
- control-related action 必须经过 `UiRuntime` 的 command / focus 路径

这条分层直接挡住两种坏结构：

- screen reader 直接改 editor buffer，绕开 text invalidation
- platform bridge 直接 poke 某个控件私有字段，绕开统一 command / focus routing

更细的 `InputEvent`、`FocusPath`、`CommandIntent` 和 `InteractionRouter` 由
`ui-interaction-specification.md` 定义。
更细的 `LayoutNode`、`LayoutConstraint`、`LayoutSnapshot` 和 `LayoutInvalidation` 由
`ui-layout-specification.md` 定义。

## `AccessibilityBridge` 必须把平台 API 映射关在边界上，而不是反向拥有语义真相

`MediaAccessibility.pas` 这类 FPC 事实说明平台 accessibility framework 真实存在，但 nextPas
不能因为这点就把长期语义边界交给平台。

因此 nextPas 要求：

- `AccessibilityBridge` 消费 `AccessibilitySnapshot` 与 snapshot delta
- 它负责向平台 accessibility API、screen reader、automation surface 发出结构化映射
- 它也负责接收平台动作请求，再把它们转换成 `AccessibilityAction`
- bridge 可以有 target-specific 实现，但公开 accessibility control plane 不因此分裂

也就是说：

- 平台层负责 transport
- accessibility control plane 负责 truth
- `PlatformShell` 负责宿主接缝，但不拥有第二棵语义树

更细的 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding` 由
`platform-shell-specification.md` 定义。

## text accessibility 只能建立在同一份 `TextLayoutSnapshot` 上

`atktext.inc` 暴露的 `get_caret_offset`、`get_offset_at_point`、`get_selection`、
`set_selection`、`get_character_extents` 已经说明：text accessibility 不是简单的 label 字符串导出。

nextPas 明确要求：

- text-bearing accessibility node 的 boundary、caret、selection 和 character geometry 必须来自
  `TextLayoutSnapshot`
- code editor、text field、tree filter input、search box、command palette 和 simple label
  继续收敛到同一条 text truth
- accessibility bridge 不允许为了“先能读出来”就私自维护另一套 text offset / selection 语义
- text navigation action 和 editable text action 继续走 `TextInputSession`

更细的 `TextContent`、`TextLayoutSnapshot`、`GlyphRun` 与 `TextInputSession` 由
`ui-text-layout-specification.md` 定义。

## rendering 可以提供可见性与 geometry 支撑，但不能反向拥有 accessibility tree

`ui-rendering-specification.md` 已经冻结 `DrawPlan`、`RenderGraph`、`SurfaceFrame`、
`RenderAssetBundle`。这些对象可能提供 clip、visibility、transform、layer 和 surface-facing
geometry 信息，但 nextPas 在这里明确：

- rendering control plane 不是 accessibility semantics owner
- backend 不允许自己维护第二套 hit-testing / focusable object tree
- accessibility 所需 geometry 继续建立在 `LayoutSnapshot`、`TextLayoutSnapshot` 与稳定 snapshot 之上
- offscreen preview、snapshot capture、IDE panel 和主窗口仍然消费同一条 accessibility truth

这条规则是为了防止出现“画面是一套，辅助技术看到的又是另一套”的历史回流。

## IDE 不能私自维护第二套 accessibility workbench

nextPas 长期既要有自有 GUI framework，也要有自有 IDE。这意味着 accessibility 不能只停在
通用 controls 层。

因此 nextPas 冻结：

- IDE editor、project tree、outline、terminal panel、test view、settings form、command palette
  都必须建立在同一套 accessibility control plane 上
- IDE 不允许为了 workbench 复杂度就私自保存第二套 semantic tree
- compiler、language service、test runner 和 package workflow 的可视化结果，应通过
  `UiScene -> AccessibilitySnapshot` 进入平台 bridge，而不是每个面板各自拼接输出
- future accessibility inspector 如果出现，也应建立在同一份 snapshot 之上

更细的 IDE 边界由 `ide-specification.md` 定义。

## 性能模型必须从第一天进入 accessibility 设计

用户目标是现代、高性能、优雅，因此 accessibility 规范不能写成“最后补一层导出器”。

nextPas 第一阶段先冻结这些性能方向：

- node identity 应尽量稳定，避免小改动触发整棵 tree 失效
- semantic delta、focus delta 和 text boundary delta 应能被分开观察，而不是每次都全量重建
- text accessibility 查询应复用 `TextLayoutSnapshot` 的已有映射和缓存，而不是每次重新 shape
- platform event emission 应建立在受控 snapshot/revision 上，避免 bridge 看到撕裂状态

这条规则的本质是：accessibility 也是 UI runtime 的正式性能路径，不是纯导出格式。

## `stage0`、`stage1` 与更后续阶段如何接 accessibility

- `stage0`
  - 先只冻结 accessibility control plane 的架构边界
  - 不要求当前最小 `nextpas build` 路径立刻支持 GUI app 或 platform accessibility bridge
- `stage1`
  - 可以开始收敛 `AccessibilityNode`、`AccessibilitySnapshot`、`AccessibilityAction` 的内部模型
  - 可以开始为最小 GUI runtime 和 text surface 预留 bridge hooks
  - 但不承诺完整平台 support matrix
- `stage2`
  - 只有当 GUI framework、text/layout、rendering、workspace truth 和 IDE workbench 都稳定后，
    完整 platform bridge、IDE adoption 和更广 automation story 才适合进入正式实现波次

这条阶段关系的重点是：先把 accessibility 写成系统边界，再决定哪些 bridge 先落地。

## 第一阶段非目标

- 不在这一阶段锁死具体平台 accessibility API 名字
- 不把 accessibility 写成“只有 screen reader support”的狭义附加功能
- 不让 IDE、rendering backend 或 platform shell 反向拥有第二套语义树
- 不把 text boundary、caret、selection geometry 重新发明成 accessibility 私有算法
- 不提前承诺完整 target matrix、完整 automation compatibility 或完整 accessibility inspector 产品面

第一阶段真正要交付的是：一份把 nextPas UI accessibility 明确写成“统一语义树 +
稳定 snapshot + 结构化 action + 平台 bridge”的正式架构规范。
