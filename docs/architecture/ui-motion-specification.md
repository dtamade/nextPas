# nextPas UI motion 规范

用这份规范定义 nextPas 长期 UI motion control plane 的稳定边界。它回答的不是
“以后默认用哪条 easing curve”或“要不要做几个漂亮过渡”，而是“frame tick、timed transition、
caret blink、scroll settle、panel reveal 和 preview timing 应该怎样进入统一 Pascal UI stack，
才能让 nextPas 的 GUI framework、editor、future IDE 和 preview surface 共享同一条 temporal truth，
而不是重新回到 toolkit timeout、widget-local animation callback、platform implicit animation
和 IDE 私有动效脚本各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`ui-runtime-specification.md`、`runtime-bootstrap-specification.md`、
`ui-interaction-specification.md`、`ui-style-theme-specification.md`、
`ui-layout-specification.md`、`ui-text-layout-specification.md`、
`ui-accessibility-specification.md`、`ui-rendering-specification.md`、
`ide-specification.md` 一起工作。前者们分别冻结 GUI 总骨架、platform shell 宿主边界、
runtime control plane、runtime handshake、interaction control plane、style/theme control plane、
general layout control plane、text/layout control plane、accessibility control plane、
rendering control plane 与 future IDE workbench；这里冻结 motion 本身的正式控制面。

## 先看 FPC 真源码已经把 motion / animation / timing 能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/src/glib/gmain.inc`
  - 直接暴露 `g_timeout_source_new`、`g_timeout_add`、`g_timeout_add_full`
  - 也直接暴露 `g_idle_source_new`、`g_idle_add`
  - 说明 UI timing / idle scheduling 在 toolkit 路线上天然是 main-loop source，而不是统一 UI motion contract
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtktextview.inc`
  - `TGtkTextView` 里直接持有 `scroll_timeout`、`blink_timeout`、`first_validate_idle`、
    `incremental_validate_idle`
  - 还同时持有 `pending_scroll`
  - 说明 caret blink、scroll reveal、onscreen validate 和 text viewport timing 在 toolkit 内本来就耦合在 widget 私有状态里
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkimage.inc`
  - `TGtkImageAnimationData` 直接保留 `anim`、`iter`、`frame_timeout`
  - 还直接暴露 `gtk_image_new_from_animation`、`gtk_image_set_from_animation`、
    `gtk_image_get_animation`
  - 说明 animated image 的 frame lifecycle 在 toolkit 路线上本来就被写成 widget-private storage
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk-pixbuf/gdk2pixbuf.pas`
  - 直接写 `Animation support`
  - 还暴露 `gdk_pixbuf_animation_get_iter`、`gdk_pixbuf_animation_iter_get_delay_time`、
    `gdk_pixbuf_animation_iter_advance`
  - 说明 frame-based animated asset 的 delay / advance 本身就是正式问题
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSAnimation.inc`
  - 直接暴露 `NSAnimationEaseInOut`、`NSAnimationEaseIn`、`NSAnimationEaseOut`、`NSAnimationLinear`
  - 还暴露 `currentProgress`、`duration`、`frameRate`、`animationCurve`、`progressMarks`、
    `animationDidEnd`
  - 说明 duration、curve、sampling rate、progress mark 和 completion 都是真实平台控制面
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSAnimationContext.inc`
  - 直接暴露 `runAnimationGroup:completionHandler:`
  - 还暴露 `duration`、`timingFunction`、`completionHandler`、`allowsImplicitAnimation`
  - 说明 explicit / implicit animation grouping 与 timing function 在平台层是正式对象
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSView.inc`
  - 直接持有 `_layer: CALayer`
  - 还暴露 `makeBackingLayer`、`wantsLayer`、`layer`、`animator`、`animations`、
    `animationForKey`
  - 说明 layer-backed view 和 implicit animation container 天然会把 motion 绑在 view 生命周期上
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSOutlineView.inc`
  - 直接暴露 `insertRowsAtIndexes:withAnimation:`、`removeRowsAtIndexes:withAnimation:`
  - 还保留 `animateExpandAndCollapse`
  - 说明 structural transition 也是 UI motion 的一部分，而不只是 opacity tween
- `/home/dtamade/projects/fpc/packages/fv/src/drivers.inc`
  - 直接提供 `GetDosTicks`
  - 还长期维护 `DownTicks`、`AutoTicks`
  - 说明历史 UI / TUI 路线同样需要 tick-based timing，只是它以 event loop 私有计数存在
- `/home/dtamade/projects/fpc/packages/fv/src/asciitab.inc`
  - 直接写 `{ add blinking if enable }`
  - 说明 blink / periodic visual change 在更老的 UI 路线上也是真实产品需求

这些事实组合起来说明：

- FPC 生态里并不是没有 animation、timing、blink、implicit transition 或 timed asset support
- 它的问题是这些能力分散在 GLib timeout、GTK widget 私有字段、animated pixbuf iterator、Cocoa
  animation object、layer-backed view 和 TUI tick counter 里
- 当前源码树没有一份把 clock、transition lifecycle、sampled motion state 与 scheduling owner
  收成统一 Pascal motion control plane 的正式架构

nextPas 如果不把这层单独冻结，future controls、editor、project tree、command palette、
preview surface 和 IDE workbench 很快又会各自长一套 timer、curve、implicit animation 和
scroll reveal 真相。

## motion 必须是 GUI stack 里的独立控制面，而不是 `UiRuntime` 或 backend 的一句注脚

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-style-theme-specification.md` 已经冻结 visual truth；
`ui-layout-specification.md` 已经冻结 geometry truth；`ui-rendering-specification.md`
已经冻结 draw / render truth。但这些文档都不会替代 motion 自身的正式边界。

nextPas 在这里进一步冻结：

- `UiRuntime` 继续拥有 frame clock 的外层调度前提，但 motion control plane 负责把 tick、transition、
  sampling、completion 和 interruption 收成稳定 temporal truth
- `PlatformShell` 继续拥有 `HostWindow` visibility/background、`DisplayTopology` scale /
  refresh-facing facts 与 `SurfaceBinding` presentability，motion 只消费这些宿主条件，不拥有第二套 host loop
- interaction control plane 继续拥有 focus、hover、pressed、command 和 text input 真相，
  但它不直接拥有 timer 或 animation lifecycle
- style/theme control plane 继续拥有 visual role、appearance 和 contrast truth，
  motion control plane 负责 temporal behavior 与 reduced-motion adaptation
- layout、text/layout 和 rendering 都只能消费同一份 sampled motion result，而不是各自维护第二套时间线
- IDE workbench 和 preview tooling 不允许因为“先做出来”就长出私有 animation system

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| UiScene / FocusPath / ThemeSnapshot                  |
| semantic state / interaction state / visual truth    |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| MotionTransition requests                            |
| reveal / collapse / fade / scroll settle / blink     |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| MotionScheduler                                      |
| start / interrupt / coalesce / complete              |
+-------------+----------------------+-----------------+
              |                      |
              v                      v
+----------------------+  +---------------------------+
| MotionClock          |  | MotionSnapshot            |
| monotonic tick /     |  | sampled progress / value  |
| frame timestamp      |  | / phase / completion      |
+----------+-----------+  +------------+--------------+
           |                           |
           +------------+--------------+
                        |
                        v
+------------------------------------------------------+
| Layout / TextLayout / DrawPlan / RenderBackend       |
+------------------------------------------------------+
```

这张图的硬约束是：

- temporal truth 在 `UiScene` 和 layout / rendering 之间显式存在
- `UiRuntime` 继续给时钟与 pump，motion control plane 才是 transition owner
- widget-local timeout、platform implicit animation 和 IDE 私有 preview timer 都不能当长期路线

## 只冻结四个 motion 对象，不把这层膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 motion 上只冻结四个核心对象：

- `MotionClock`
- `MotionTransition`
- `MotionSnapshot`
- `MotionScheduler`

| 对象               | 负责什么                                                                                      | 明确不负责什么                                              |
| ------------------ | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| `MotionClock`      | 表达 monotonic tick、frame timestamp、pause/resume、time-scale 与 sampling 所需的时间事实     | 不直接改 scene，不自己决定 visual role                      |
| `MotionTransition` | 表达一次受控 temporal change 的 source/target、duration、curve、repeat 与 interruption policy | 不直接生成 draw command，不自己拥有 node geometry           |
| `MotionSnapshot`   | 表达某次稳定 frame revision 下的 sampled progress、animated value、phase 与 completion state  | 不替代 `LayoutSnapshot`、`TextLayoutSnapshot` 或 `DrawPlan` |
| `MotionScheduler`  | 负责启动、合并、中断、采样和结束 active transition                                            | 不反向拥有 `UiScene`、`ThemeSnapshot` 或 backend truth      |

这里最关键的边界是：

- `MotionClock` 先定义“现在是什么时间、该如何采样”
- `MotionTransition` 再定义“哪一类状态变化应以什么 temporal contract 演进”
- `MotionSnapshot` 定义“这一帧真正看到的 sampled motion result 是什么”
- `MotionScheduler` 最后定义“这些变化怎样稳定进入 UI stack”

## `MotionClock` 必须是 monotonic、frame-facing 的时间源，而不是临时 wall clock

GLib timeout、Cocoa animation frame rate 和 Free Vision tick counter 都说明：UI timing 不是“拿当前时间减一下”这么简单。

因此 nextPas 冻结：

- `MotionClock` 必须是 monotonic time source，而不是 wall clock / locale time / date API
- 它至少要能表达 frame timestamp、elapsed time、pause / resume、background suspension 和 time-scale
- same frame 内的 layout、text、rendering 和 completion logic 必须共享同一个 sampled clock value
- `UiRuntime` 可以提供 pump 和 frame cadence，但具体 motion sampling 仍由 `MotionClock` formalize

这条规则的意义很直接：

- preview capture、snapshot replay、IDE workbench 和 app runtime 才能共享同一条 timing line
- frame hitch、pause、background 恢复不会让 motion 状态变成不可解释
- 测试和留证也有稳定时间语义可引用

## `MotionTransition` 必须先是语义时序对象，而不是 widget-local property tween

`NSAnimation`、`NSAnimationContext`、`NSOutlineView withAnimation:` 和 `gtk_text_view` 的
scroll / blink 字段都说明：真正的 UI motion 不只是“把一个浮点值插值一下”。

因此 nextPas 要求：

- `MotionTransition` 先表达 semantic transition，例如 panel reveal、row insert/remove、scroll settle、
  caret blink、focus ring pulse、indeterminate progress、view fade
- 它至少要能描述 source/target value、duration、curve、delay、repeat / alternate、completion policy
  与 interruption policy
- transition identity 应来自统一 UI node / surface 语义，而不是平台 widget 指针
- same semantic change 在 controls、editor、IDE workbench 和 preview surface 上必须可落到同一类
  temporal contract，而不是各自偷写 timer

这条规则直接挡住两种坏结构：

- 每个 widget 自己持有一堆 timeout id 和 progress float
- backend 因为自己好实现，就偷偷定义另一套 transition semantics

## `MotionSnapshot` 必须拥有 sampled motion truth，而不是让 layout / rendering 各自补帧

nextPas 如果想现代、高性能、优雅，就不能让 layout、rendering、preview capture 在同一帧里各算各的 progress。

因此 nextPas 明确：

- `MotionSnapshot` 是一次稳定 frame revision 的 sampled motion owner
- 它至少要能表达 progress、phase、animated scalar / vector value、loop state、completion state
  与 target identity
- layout、text/layout、rendering 和 preview tooling 必须消费同一份 `MotionSnapshot`
- snapshot identity 应尽量跨小幅状态变化保持稳定，避免轻微 hover / focus 变化就把整棵 active motion set 重建

这条规则能直接提供：

- layout-facing animated metric 的正式来源
- render-facing opacity / transform / clip phase 的正式来源
- deterministic preview capture 和 trace replay 的正式来源

## `MotionScheduler` 必须是唯一推荐的 transition owner

GLib timeout、GTK widget 私有 timeout、Cocoa implicit animation group 和 TUI tick counter 说明：
如果不把 scheduling owner 单独冻住，motion 很快就会重新散掉。

因此 nextPas 冻结：

- `MotionScheduler` 是 active motion lifecycle 的唯一推荐 owner
- 它负责 start、coalesce、interrupt、retarget、sample、complete 和 cleanup
- same node 上的 hover fade、selection highlight、panel collapse、scroll reveal 和 caret blink
  必须通过同一个 scheduler 协调，而不是各自独立跑 timer
- scheduler 可以依赖 `UiRuntime` frame pump，但不能反向变成新的 scene / render owner

这样 nextPas 才不会重新掉回：

- controls 一套 timer
- editor 一套 timer
- IDE preview 一套 timer

## interaction、style/theme 和 accessibility 只提供输入，不拥有时间线

只要 UI 有 hover、focus、pressed、selection、platform appearance 和 reduced motion，motion 就一定会和别的控制面相接。但 nextPas 在这里明确：

- `InteractionRouter`、`FocusPath` 和 `CommandIntent` 继续拥有交互与状态变化真相
- `ThemeSnapshot` 继续拥有 visual role / appearance truth
- accessibility control plane 继续拥有 assistive-facing preference 与 action flow
- `MotionScheduler` 消费这些状态变化与偏好，并决定哪些 motion 应该启动、跳过、缩短或立即完成

这条边界的重点是：

- focused / hovered / selected 是 interaction truth
- dark / light / contrast 是 style/theme truth
- reduced motion / immediate completion policy 进入 motion control plane 后，才变成 temporal behavior

## layout 和 text/layout 可以消费 animated metric，但不能反向拥有 motion truth

motion 和几何 / text 的边界必须提前说清，否则很快就会重新混成 toolkit 私货。

nextPas 在这里冻结：

- layout control plane 可以消费 `MotionSnapshot` 提供的 panel reveal ratio、scroll settle offset、
  overlay entrance progress 或等价 animated metric
- 但最终 bounds、viewport、child placement 仍然只属于 `LayoutSnapshot`
- text/layout control plane 可以消费 `MotionSnapshot` 提供的 caret blink phase、scroll-to-caret
  reveal progress 或等价 text-facing temporal input
- 但 logical text、caret mapping、selection geometry 和 glyph run 仍然只属于 text/layout control plane

也就是说：

- motion 可以影响几何采样结果，但不能替代 layout geometry truth
- motion 可以影响 caret / reveal 的时序，但不能替代 text truth
- same sampled progress 必须同时服务普通 controls、code editor 和 IDE workbench text surface

## rendering 只消费 sampled motion，不拥有 motion semantics

`ui-rendering-specification.md` 已经冻结 `DrawPlan`、`RenderGraph`、`SurfaceFrame` 与
`RenderAssetBundle`。这里进一步把 motion 和 rendering 的边界钉死：

- `DrawPlan` 可以消费 `MotionSnapshot` 里的 opacity、transform、clip reveal、effect phase 或等价 sampled value
- `RenderBackend` 只执行 sampled result，不重新解释 curve、duration、repeat 或 completion semantics
- backend 不允许因为自己好实现，就偷偷定义另一套 fade / spring / scroll settle / implicit animation 规则
- on-screen window、offscreen snapshot、preview pane 和 component gallery 必须共用同一份 motion sample

这条规则会直接决定 future GPU-backed UI stack 能不能既顺滑又可解释。

## IDE 和 preview tooling 不允许拥有第二套 motion system

nextPas 的 IDE 会是这套 GUI framework 的 flagship application，但 motion 不是 IDE 的例外区。

因此 nextPas 要求：

- editor、project tree、outline、terminal panel、test view、settings form、command palette、
  preview pane 和 future designer surface 都必须建立在同一套 `MotionClock -> MotionScheduler ->
MotionSnapshot` 线上
- workbench panel transition、tree expand/collapse、editor reveal、preview playback 和 future component
  gallery 都不能各自维护私有 timer / animation coordinator
- IDE 不允许长期依赖 webview CSS transition、workbench-local animation callback 或 preview-only timing shell

这条规则是为了避免 GUI framework 和 IDE 又重新长成两套 temporal system。

## 性能模型必须从第一天进入 motion 设计

既然用户目标是现代、高性能、优雅，motion 规范不能只谈“看起来顺不顺眼”，不谈性能和确定性。

第一阶段先冻结这些性能方向：

- active transition 应优先局部调度，不让每次 frame 都整树扫描全部 node
- layout-affecting motion 和 paint-only motion 应能被区分，避免所有动画都升级成全量 layout/re-render
- `MotionSnapshot` 采样应在 stable revision 上完成，避免 layout / render / completion 看到撕裂状态
- reduced-motion preference、background suspension 和 preview replay 应走同一条 formal policy，
  不让 hot path 到处散落特判
- deterministic capture / replay 应优先建立在 sampled clock 与 sampled snapshot 上，而不是录一堆
  widget callback 副作用

这几条不等于现在就实现完整 animation engine；它们只是保证架构不会天然把性能和一致性做差。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 motion control plane 的对象边界
  - 不承诺当前最小 `nextpas build` 立刻支持 GUI animation、smooth scroll、preview playback 或 designer motion tooling
- `stage1`
  - 可以开始收敛最小 `MotionClock`、最小 `MotionTransition`、最小 `MotionSnapshot`
    和最小 `MotionScheduler`
  - 也可以开始为 caret blink、focus pulse、panel reveal、row transition 或 scroll settle 预留正式入口
  - 但不承诺完整 spring library、visual timeline editor 或 live motion designer
- `stage2`
  - 只有在 GUI framework、style/theme、layout、text/layout、rendering 和 IDE workbench 都稳定后，
    richer motion system、timeline tooling、transition inspector 和 designer playback 才适合进入正式实现波次

这条阶段关系的重点是：先把 temporal truth 写对，再决定哪种动效先值得落实现。

## 第一阶段非目标

- 不在这一阶段锁死具体 spring equation、timeline DSL 或 keyframe file format
- 不把 GLib timeout、GTK widget 私有 animation 字段、Cocoa implicit animation API 重新包装成 nextPas 的长期 motion architecture
- 不让 rendering/backend 反向拥有 curve、duration 或 completion semantics
- 不让 IDE、preview tooling 或 editor renderer 长出私有 animation system
- 不把 visual motion editor、timeline authoring tool、cinematic effect pipeline 写成当前承诺

第一阶段真正要交付的是：一份把 nextPas UI motion 明确写成“clock + transition +
motion snapshot + scheduler”的正式架构规范。
