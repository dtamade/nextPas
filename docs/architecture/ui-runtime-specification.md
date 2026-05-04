# nextPas UI runtime 规范

用这份规范定义 nextPas 长期 UI runtime control plane 的稳定边界。它回答的不是
“以后主线程到底调用哪一个 event loop API”，而是“host event source、frame pump、
main-thread handoff、invalidation scheduling、surface session、resource lifetime 和
present cadence 应该怎样进入统一 Pascal UI stack，才能让 nextPas 的 GUI framework、
editor、future IDE 和 preview surface 共享同一条 runtime truth，而不是重新回到 toolkit
main loop、widget-local idle callback、platform run loop 和 workbench 私有调度器各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`platform-shell-specification.md`、
`runtime-bootstrap-specification.md`、`ui-interaction-specification.md`、
`ui-layout-specification.md`、`ui-style-theme-specification.md`、
`ui-motion-specification.md`、`ui-text-layout-specification.md`、
`ui-accessibility-specification.md`、`ui-rendering-specification.md`、`ide-specification.md`
一起工作。前者们分别冻结 GUI 总骨架、platform shell 宿主边界、runtime handshake、
interaction control plane、general layout control plane、style/theme control plane、motion
control plane、text/layout control plane、accessibility control plane、rendering control plane
与 future IDE workbench；这里冻结 UI runtime 本身的正式控制面。

## 先看 FPC 真源码已经把 UI runtime 相关能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/src/glib/gmain.inc`
  - 直接暴露 `g_main_context_iteration`、`g_main_context_prepare`、`g_main_context_check`、
    `g_main_context_dispatch`、`g_main_loop_run`、`g_main_iteration`
  - 还暴露 `g_source_attach`、`g_source_destroy`、`g_timeout_add`、`g_idle_add`
  - 说明 main-loop turn、source attach/destroy、timeout wake-up 和 idle wake-up 在 toolkit 路线上
    本来就是显式 runtime contract
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkmain.inc`
  - 直接暴露 `gtk_events_pending`、`gtk_main_do_event`、`gtk_main`、
    `gtk_main_iteration`、`gtk_main_iteration_do`、`gtk_main_level`
  - 还暴露 `gtk_timeout_add`、`gtk_idle_add`
  - 说明 event drain、nested main loop level、dispatch ordering 和 idle/timeout scheduling 在
    toolkit 层是正式问题
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkwidget.inc`
  - 直接暴露 `gtk_widget_queue_draw`、`gtk_widget_queue_draw_area`、`gtk_widget_queue_resize`、
    `gtk_widget_queue_resize_no_redraw`
  - 说明 render invalidation、partial redraw 和 resize invalidation 在 widget 路线上被写成显式
    queue API
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkcontainer.inc`
  - 直接暴露 `_gtk_container_queue_resize`、`_gtk_container_dequeue_resize_handler`
  - 说明 container resize propagation 也有自己的 runtime queue 和 handler 生命周期
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtktextview.inc`
  - `TGtkTextView` 里直接持有 `scroll_timeout`、`blink_timeout`、`first_validate_idle`、
    `incremental_validate_idle`、`pending_scroll`
  - 说明 text surface 的 scroll reveal、caret blink、incremental validate 和 pending work
    在 toolkit 路线上天然耦合在 widget 私有 runtime 状态里
- `/home/dtamade/projects/fpc/packages/cocoaint/src/foundation/NSRunLoop.inc`
  - 直接暴露 `currentRunLoop`、`mainRunLoop`、`getCFRunLoop`、`run`、`runUntilDate`、
    `runMode:beforeDate:`、`acceptInputForMode:beforeDate:`
  - 说明 run loop、mode、limited run 和 input acceptance 在平台层是正式对象
- `/home/dtamade/projects/fpc/packages/cocoaint/src/foundation/NSThread.inc`
  - 直接暴露 `isMainThread`、`mainThread`、`performSelectorOnMainThread:withObject:waitUntilDone:`、
    `performSelector:onThread:withObject:waitUntilDone:`、`detachNewThreadSelector`
  - 说明 main-thread affinity、cross-thread handoff 和 background thread entry 都是真实 runtime 边界
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSApplication.inc`
  - 直接暴露 `run`、`runModalForWindow`、`nextEventMatchingMask:untilDate:inMode:dequeue:`、
    `postEvent:atStart:`、`sendEvent`、`updateWindows`
  - 说明 app pump、modal loop、posted event queue 和 display update phase 在平台层被单独 formalize
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSWindow.inc`
  - 直接暴露 `nextEventMatchingMask`、`nextEventMatchingMask:untilDate:inMode:dequeue:`、
    `sendEvent`、`displayIfNeeded`
  - 说明 window-level event intake 和 display pass 也是显式 runtime boundary
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSView.inc`
  - 直接暴露 `setNeedsDisplay`、`setNeedsDisplayInRect`、`displayIfNeeded`
  - 说明 invalidation request 与 actual display/update 是分开的
- `/home/dtamade/projects/fpc/packages/fv/src/drivers.inc`
  - 直接提供 `InitEvents`、`DoneEvents`、`InitVideo`、`DoneVideo`、`GetKeyEvent`、
    `GetMouseEvent`、`PutEventInQueue`、`NextQueuedEvent`、`GiveUpTimeSlice`、`GetDosTicks`
  - 说明更老的 TUI 路线同样需要 event init/done、queue、time slice 和 tick-based runtime contract

这些事实组合起来说明：

- FPC 生态里并不是没有 main loop、event queue、display invalidation、thread handoff 和 surface update
- 它的问题是这些能力分散在 GLib source、GTK widget queue、Cocoa run loop / application object 和
  Free Vision driver 里
- 当前源码树没有一份把 frame pump、dispatch ordering、invalidations、UI task reentry、surface session
  和 resource lifetime 收成统一 Pascal UI runtime control plane 的正式架构

nextPas 如果不把这层单独冻结，future controls、editor、preview surface、package UI、test UI 和
IDE workbench 很快又会各自长一套 event loop、idle queue、display request 和 background callback
真相。

## runtime 必须是 GUI stack 里的独立控制面，而不是 `UiScene`、motion 或 rendering 的一句注脚

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`runtime-bootstrap-specification.md` 已经冻结 process startup、
unit init/fini 与 runtime helper contract；`ui-motion-specification.md` 已经冻结 transition 和
temporal truth；`ui-rendering-specification.md` 已经冻结 draw / render truth。但这些文档都不会替代
UI runtime 自身的正式边界。

nextPas 在这里进一步冻结：

- `PlatformShell` 继续负责 host event source、native window/surface lifecycle、IME/clipboard wake-up
  与 platform integration
- UI runtime control plane 负责把 event intake、dispatch ordering、frame cadence、invalidation merge、
  async-to-UI handoff、surface session 和 resource lifetime 收成稳定 runtime truth
- interaction control plane 继续拥有 input/focus/command truth，但它不拥有 outer pump 或 posted task queue
- motion control plane 继续拥有 transition lifecycle 和 temporal sampling，但它不拥有 app/session event loop
- layout、text/layout、style/theme、accessibility 和 rendering 都必须共享同一个 dispatch revision 与
  invalidation boundary，而不是各自维护第二套 frame scheduler
- `runtime-bootstrap-specification.md` 继续定义 process/runtime handshake，但它不替代 GUI per-frame runtime
- IDE workbench、preview surface 和 designer tooling 不允许因为“先做出来”就长出第二套 workbench event loop

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| PlatformShell / language service / build/test tasks  |
| host events / surface lifecycle / async completions  |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| UiTaskQueue                                          |
| main-thread handoff / priority / cancellation        |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| DispatchCycle                                        |
| event drain / routing / invalidation merge / commit  |
+-------------+----------------------+-----------------+
              |                      |
              v                      v
+----------------------+  +----------------------------+
| RuntimeClock         |  | UiInvalidation             |
| monotonic frame time |  | dirty scopes / coalescing  |
| / cadence / phase    |  | / revision boundary        |
+----------+-----------+  +-------------+--------------+
           |                              |
           +--------------+---------------+
                          |
                          v
+------------------------------------------------------+
| Interaction / Layout / Text / Theme / Motion / A11y  |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| DrawPlan / RenderBackend / surface present           |
+------------------------------------------------------+
```

这张图的硬约束是：

- runtime truth 在 `PlatformShell` 和各个 UI control plane 之间显式存在
- dispatch ordering、invalidation merge 和 main-thread handoff 不能散回 widget callback、idle handler 或
  workbench 私有 glue
- 同一份 UI state mutation 必须沿着同一条 runtime 线进入 interaction、layout、text、motion、
  accessibility 和 rendering

## 只冻结四个 runtime 对象，不把这层膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 UI runtime 上只冻结四个核心对象：

- `RuntimeClock`
- `DispatchCycle`
- `UiInvalidation`
- `UiTaskQueue`

| 对象             | 负责什么                                                                                         | 明确不负责什么                                     |
| ---------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------- |
| `RuntimeClock`   | 表达 monotonic frame timestamp、wake-up deadline、suspend/resume 和 dispatch-facing 时间事实     | 不直接拥有 transition semantics，不等价 wall clock |
| `DispatchCycle`  | 表达一次稳定 UI turn 的 event drain、action dispatch、state commit、frame boundary 与 cleanup    | 不重新定义 app model，不替代平台 windowing         |
| `UiInvalidation` | 表达 scene/layout/text/style/accessibility/render/surface dirty scope、reason 和 coalescing 边界 | 不替代 `LayoutInvalidation` 或 `RenderGraph`       |
| `UiTaskQueue`    | 表达 async-to-UI handoff、deferred task、priority、cancellation 和 revision-bound reentry        | 不充当通用线程池，不执行长期 background compute    |

这里最关键的边界是：

- `RuntimeClock` 先定义“当前 UI runtime 面对的时间事实是什么”
- `DispatchCycle` 再定义“一次合法 UI turn 该按什么顺序流过系统”
- `UiInvalidation` 定义“这次 turn 里到底哪里脏了，合并到哪里为止”
- `UiTaskQueue` 最后定义“后台结果怎样回到 UI 线程且不破坏 revision truth”

## `RuntimeClock` 必须是 monotonic、dispatch-facing 的时间源

GLib source、Cocoa run loop 和 Free Vision tick counter 都说明：UI runtime 的时间源不是“随手取一下当前时间”。

因此 nextPas 冻结：

- `RuntimeClock` 必须是 monotonic time source，而不是 locale time 或 wall clock
- 它至少要能表达 frame timestamp、wake-up deadline、background suspension / resume、surface-visible cadence
  和 dispatch phase 所需的时间事实
- 同一个 `DispatchCycle` 内 interaction、motion、layout、text、accessibility、rendering 必须共享同一个
  sampled clock value
- platform-specific vsync、timer、poll 或 idle source 可以存在，但它们进入 runtime 后必须收敛成同一类
  `RuntimeClock` contract

这条规则的意义很直接：

- preview capture、trace replay、IDE workbench 和 app runtime 才能共享同一条 timing line
- event timestamp、frame timestamp 和 motion sampling 不会在不同 control plane 里各算各的
- runtime suspend / resume 后的 dirty state 与 task reentry 也有正式时间语义可引用

## `DispatchCycle` 必须把 event dispatch ordering 明确写死

`gtk_main_iteration`、`gtk_main_do_event`、`nextEventMatchingMask:untilDate:inMode:dequeue:`、
`sendEvent` 和 `updateWindows` 说明：一轮 UI turn 里先收什么、后发什么、什么时候 display，
从来都不是小细节。

因此 nextPas 要求 `DispatchCycle` 至少要关住这条推荐顺序：

1. 从 `PlatformShell` intake host event、surface lifecycle change 和 posted platform callback。
2. 按受控预算 drain `UiTaskQueue` 里可执行的 UI reentry task。
3. 把输入、accessible action、command source 交给 interaction / text / focus 路径。
4. 对 state mutation 归类并合并成 `UiInvalidation`。
5. 只对 dirty scope 重新计算 layout、text、style/theme、accessibility snapshot，并采样 motion。
6. 在需要时下沉 draw plan、驱动 render submit 和 surface present。
7. 清理 stale task、过期 invalidation、dead surface/session 关联资源。

这条顺序背后的硬约束是：

- posted task 不允许在任意栈深处偷偷改 UI state
- display/update 不允许绕开 invalidation merge 直接乱入
- modal surface、popup、drag capture 和 preview interaction 仍然建立在同一份 `DispatchCycle` 上，
  不把 nested `gtk_main` / `runModal` style secondary loop 当成长期推荐架构

## `UiInvalidation` 必须把跨控制面的 dirty truth 单独关住

`gtk_widget_queue_draw`、`gtk_widget_queue_resize`、`_gtk_container_queue_resize`、
`setNeedsDisplay`、`displayIfNeeded` 和 `gtk_text_view` 的 validate idle 都说明：
真正容易失控的不是“有没有 dirty flag”，而是 dirty reason 和 dirty boundary 到底归谁。

因此 nextPas 冻结：

- `UiInvalidation` 至少要能区分 input-only、command result、style/theme metric、text content、
  layout geometry、accessibility snapshot、render-only 和 surface lifecycle 这一类失效面
- dirty scope 应优先按 node subtree、surface session、document/editor viewport 或等价稳定 identity
  合并，而不是默认整场景重做
- `LayoutInvalidation`、text relayout、style diff、accessibility delta 和 draw plan invalidation
  可以继续保留各自的 plane-local detail，但外层 dispatch / frame boundary 必须统一落到
  `UiInvalidation`
- stale invalidation 不允许越过 surface destroy、session reset 或 revision cancellation 继续执行

这条规则能直接提供：

- 一份给 interaction/layout/text/motion/accessibility/rendering 共同消费的 dirty truth
- resize、scroll、hover、theme switch、async diagnostics update 不同路径的受控合并点
- 大型 IDE workbench 和普通 GUI app 都可复用的 runtime invalidation model

## `UiTaskQueue` 必须是唯一推荐的 async-to-UI handoff owner

`g_idle_add`、`g_timeout_add`、`performSelectorOnMainThread:withObject:waitUntilDone:` 和
Free Vision 的 event queue 已经证明：后台结果回到 UI，从来都是真实架构问题。

因此 nextPas 冻结：

- `UiTaskQueue` 是 language service、toolchain、build/test worker、package fetch、preview pipeline、
  filesystem watch 和 background I/O 回到 UI 线程的唯一推荐入口
- queue item 至少要能表达 target session / surface、priority、cancellation token、revision precondition
  和 deferred commit policy
- task 只在 `DispatchCycle` 的受控时点执行，不允许随机穿透到当前 UI call stack
- queue 可以支持 idle-like deferred work，但它不是通用 background executor，也不替代 async runtime

这条分层直接挡住两种坏结构：

- editor 一套 `g_idle_add` 风格 reentry，preview pane 再一套 main-thread callback
- IDE workbench 因为 build/test/package/lang-service 各自方便，就维护四五套 posted-task bus

## `UiRuntime` 必须拥有 surface session 和 resource lifetime 的外层协调权

GLib `g_source_attach` / `g_source_destroy`、Cocoa `displayIfNeeded`、Free Vision `InitEvents` /
`DoneEvents` 与 `InitVideo` / `DoneVideo` 都说明：session start、session end、resource attach、
resource release 不能只是 backend 或 shell 的内部小事。

nextPas 在这里明确：

- `PlatformShell` 继续拥有 native window、native surface、IME context、clipboard handle 这类宿主对象
- `RenderBackend` 继续拥有 GPU resource、present object 和 backend-private cache
- UI runtime control plane 负责定义这些对象在一个 UI application session / surface session 里的外层生灭顺序
- surface destroy、session suspend、window occlusion、resize/recreate、preview close、IDE panel detach
  这类事件都必须先进入 runtime，再决定哪些 task、snapshot、invalidation 和 backend resource 应该作废

这条规则的意义很直接：

- backend 不需要反过来拥有 app/session policy
- shell 不需要反过来判断 scene/layout/text/motion 哪些状态还能继续存活
- future multi-surface IDE 和 app runtime 不会因为 surface lifecycle 分散而长出不可回收的状态岛

## interaction、motion 和 rendering 都只消费同一份 runtime revision，不拥有第二套泵

只要 UI stack 足够复杂，很多子系统都会想自己偷带一个 timer、callback 或 frame hook。nextPas 在这里明确：

- interaction control plane 继续拥有 input/focus/command truth，但 command commit 仍要回到统一 `DispatchCycle`
- motion control plane 继续拥有 transition lifecycle 与 sampled temporal truth，但 outer frame pump 仍然来自
  UI runtime control plane
- rendering control plane 继续拥有 draw plan、render graph 和 surface submit，但 app/session event loop
  不属于 rendering
- accessibility action、text input session、layout invalidation 和 style/theme diff 都必须沿着同一份
  runtime revision 往下流

这条边界是为了避免：

- caret blink 一套 timer
- preview playback 一套 timer
- render backend 一套 frame callback
- IDE workbench 再一套 animation / task scheduler

## 性能模型必须直接进入 UI runtime 设计

如果 nextPas 想现代、高性能、优雅，runtime control plane 本身就必须有正式性能约束。

第一阶段坚持这些规则：

- event drain 应该是 bounded batch，而不是无限制把 host queue 一次吃空
- `UiInvalidation` 应优先做结构化 coalescing，不优先整场景重算
- 同一 `DispatchCycle` 只采样一次 `RuntimeClock`，不让各 control plane 各取各的时间
- stale task、dead surface 和 old revision 应优先取消，不在 UI 线程上白做无效 work
- dispatch ordering 要避免深层 reentrancy，避免一个 local callback 触发不可控 nested cycle
- single-surface app、editor-heavy surface 和 future IDE workbench 都必须建立在同一套 runtime model 上

这条规则的本质是：runtime 不是“把事件转一转就好”的 glue，它本身就是 UI stack 的性能路径。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 UI runtime control plane 的架构边界
  - 不要求当前最小 `nextpas build` 路径立刻支持完整 GUI app、multi-surface runtime 或 IDE workbench
- `stage1`
  - 可以开始实现最小 single-surface `RuntimeClock`、`DispatchCycle`、`UiInvalidation` 和 `UiTaskQueue`
  - 可以开始为 editor surface、preview surface 和最小 workbench shell 预留正式入口
  - 但不承诺完整 platform feature matrix、nested modal policy 或 advanced trace tooling
- `stage2`
  - 只有当 runtime / interaction / layout / motion / text / accessibility / rendering 都稳定后，
    更完整的 multi-surface orchestration、runtime trace/replay、designer tooling 和 richer scheduling
    才适合进入正式实现波次

## 第一阶段非目标

- 不把这份规范写成某个平台 main loop API 的完整封装手册。
- 不把 `UiTaskQueue` 误写成 nextPas 全程序的通用 async runtime 或线程池。
- 不把 `UiRuntime` 变成第二套 `System`、第二套 workspace service，或第二套 render backend。
- 不要求 `stage0` 立刻交付 GUI app、preview pane、designer 或 IDE。
- 不允许因为 modal、popup 或 preview 需求，就默认把 nested loop / widget-local idle callback 写回长期主架构。
