# nextPas PlatformShell 规范

用这份规范定义 nextPas 长期 `PlatformShell` layer 的稳定边界。它回答的不是
“以后先包哪一个 window toolkit API”，而是“window/screen、DPI/scale、clipboard/selection、
drag-and-drop、cursor、native text service、system chrome 和 native surface integration
应该怎样进入统一 Pascal UI stack，才能让 nextPas 的 GUI framework、editor、future IDE 和
preview surface 共享同一条 host truth，而不是重新回到 toolkit widget wrapper、platform
binding、OS callback 和 workbench 私有宿主 glue 各管一段的历史结构”。

这份文档和 `gui-framework-specification.md`、`ui-runtime-specification.md`、
`ui-interaction-specification.md`、`ui-layout-specification.md`、
`ui-style-theme-specification.md`、`ui-text-layout-specification.md`、
`ui-accessibility-specification.md`、`ui-rendering-specification.md`、`ide-specification.md`
一起工作。前者们分别冻结 GUI 总骨架、runtime control plane、interaction control plane、
general layout control plane、style/theme control plane、text/layout control plane、
accessibility control plane、rendering control plane 与 future IDE workbench；这里冻结
`PlatformShell` 自身的正式宿主边界。

## 先看 FPC 真源码已经把 platform shell 相关能力分散成什么样

这份规范直接回应这些 FPC 真实源码事实：

- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkwindow.inc`
  - 直接暴露 `gtk_window_new`、`gtk_window_present`、`gtk_window_set_default_size`、
    `gtk_window_resize`、`gtk_window_move`
  - 还暴露 `gtk_window_fullscreen`、`gtk_window_unfullscreen`
  - 说明 toplevel window creation、activation、geometry 和 fullscreen lifecycle 都是真实宿主边界
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkclipboard.inc`
  - 直接暴露 `gtk_clipboard_get`、`gtk_clipboard_get_for_display`、`gtk_clipboard_set_text`、
    `gtk_clipboard_request_text`、`gtk_clipboard_store`
  - 说明 clipboard owner、display-local clipboard 与 deferred request/store 是正式问题
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gtk/gtkselection.inc`
  - 直接暴露 `gtk_selection_owner_set`、`gtk_selection_convert`、`gtk_selection_data_get_targets`、
    `gtk_selection_data_set_uris`
  - 说明 selection owner、target negotiation 和 URI payload 也属于宿主 transport 边界
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk/gdkdisplay.inc`
  - 直接暴露 `gdk_display_get_default`、`gdk_display_get_n_screens`、`gdk_display_get_event`、
    `gdk_display_put_event`
  - 还暴露 `gdk_display_get_default_cursor_size`、`gdk_display_supports_clipboard_persistence`、
    `gdk_display_supports_selection_notification`
  - 说明 display、host event queue、cursor capability 与 clipboard persistence 是正式 display fact
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk/gdkscreen.inc`
  - 直接暴露 `gdk_screen_get_width`、`gdk_screen_get_height`、`gdk_screen_get_width_mm`、
    `gdk_screen_get_height_mm`
  - 还暴露 `gdk_screen_get_n_monitors`、`gdk_screen_get_monitor_geometry`
  - 说明 screen size、physical size、monitor topology 和 geometry 是正式宿主真相
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk/gdkcursor.inc`
  - 直接暴露 `gdk_cursor_new_for_display`、`gdk_cursor_new_from_pixbuf`、`gdk_cursor_get_display`、
    `gdk_cursor_get_screen`
  - 说明 cursor identity、cursor image 和 display/screen attachment 本来就是宿主对象
- `/home/dtamade/projects/fpc/packages/gtk2/src/gtk+/gdk/gdkdnd.inc`
  - 直接暴露 `gdk_drag_context_new`、`gdk_drag_get_selection`、
    `gdk_drag_find_window_for_screen`
  - 说明 drag context、payload selection 和 drop target discovery 是正式 DnD transport
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSWindow.inc`
  - 直接暴露 `initWithContentRect:styleMask:backing:defer:screen:`、`setTitle:`、
    `setFrame:display:`、`setContentSize:`、`makeKeyAndOrderFront:`、`orderFront:`
  - 还暴露 `screen`、`backingScaleFactor`、`toggleFullScreen:`、
    `setAcceptsMouseMovedEvents:`
  - 说明 host window、screen/backing scale、visibility、fullscreen 与 pointer event intake 都是真实平台契约
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSPasteboard.inc`
  - 直接暴露 `pasteboardWithName`、`pasteboardWithUniqueName`、`pasteboardItems`
  - 还暴露 `pasteboard:provideDataForType:`、`pasteboardChangedOwner:`
  - 说明 pasteboard identity、item list 和 owner callback 都是真实宿主 data-transfer contract
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSDragging.inc`
  - 直接暴露 `draggingDestinationWindow`、`draggingPasteboard`、`draggingLocation`
  - 还暴露 `draggingEntered:`、`draggingUpdated:`、`draggingExited:`、
    `draggingSession:endedAtPoint:operation:`
  - 说明 drag session、pasteboard payload 和 drag lifecycle 是正式平台对象
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSCursor.inc`
  - 直接暴露 `dragLinkCursor`、`dragCopyCursor`
  - 说明 cursor 不只是“鼠标图标”，它还承载 drag semantic hint
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSScreen.inc`
  - 直接暴露 `screens`、`backingScaleFactor`
  - 说明 multi-screen topology 和 scale factor 在平台层天然存在
- `/home/dtamade/projects/fpc/packages/cocoaint/src/appkit/NSView.inc`
  - 直接暴露 `addCursorRect:cursor:`、`draggingEntered:`、`draggingUpdated:`、
    `draggingEnded:`、`writePDFInsideRect:toPasteboard:`
  - 说明 cursor rect、drag target 和 copy/export to pasteboard 在 view bridge 上也是真实宿主接缝
- `/home/dtamade/projects/fpc/packages/x11/src/xlib.pp`
  - 直接暴露 `XGrabKeyboard`、`XGrabPointer`、`XInternAtom`
  - 还暴露 `WidthOfScreen`、`HeightOfScreen`、`WidthMMOfScreen`、`HeightMMOfScreen`
  - 说明低层 window-system 路线里，grab、atom/selection identity 与 screen geometry 同样是正式 host fact
- `/home/dtamade/projects/fpc/packages/x11/src/xfixes.pp`
  - 直接暴露 `XFixesSelectSelectionInput`、`XFixesSelectCursorInput`
  - 还暴露 `XFixesHideCursor`、`XFixesShowCursor`、`XFixesSetCursorName`
  - 说明 selection notification、cursor notification 和 cursor visibility 在低层宿主路线上是正式控制面

这些事实组合起来说明：

- FPC 生态里并不是没有 window、screen、clipboard、drag-and-drop、cursor 和 native surface 相关能力
- 它的问题是这些能力分散在 GTK/GDK wrapper、Cocoa framework binding 和 X11 raw binding 里
- 当前源码树没有一份把宿主 windowing、display topology、data transfer 和 native surface binding
  收成统一 Pascal `PlatformShell` 边界的正式架构

nextPas 如果不把这层单独冻结，future controls、editor、preview surface、package UI 和 IDE workbench
很快又会各自长一套 window glue、clipboard bridge、file drop hook、cursor policy 和 screen-scale
真相。

## `PlatformShell` 必须是 GUI stack 里的独立宿主边界，而不是 `UiRuntime` 或 interaction 的附带说明

`gui-framework-specification.md` 已经冻结 `UiScene`、`UiRuntime`、`RenderBackend`、
`PlatformShell` 四层骨架；`ui-runtime-specification.md` 已经冻结 frame pump、dispatch cycle、
invalidation 与 async-to-UI handoff；`ui-interaction-specification.md` 已经冻结 input/focus/command
truth；`ui-rendering-specification.md` 已经冻结 draw plan、surface frame 和 render asset contract。
但这些文档都不会替代宿主接缝本身的正式边界。

nextPas 在这里进一步冻结：

- `PlatformShell` 负责把 native window、screen/monitor、clipboard/selection、drag-and-drop、
  cursor、system chrome、native text service 与 native surface integration 收成稳定 host truth
- `UiRuntime` 继续负责 outer pump、dispatch ordering、dirty merge 与 task reentry
- interaction control plane 继续负责把 native event transport 变成 `InputEvent` / `CommandIntent`
- text/layout control plane 继续负责 text content、caret、selection 和 `TextInputSession`，
  `PlatformShell` 只提供宿主 IME / pasteboard / native text service bridge
- accessibility control plane 继续负责语义树和 action truth，`PlatformShell` 只提供 host API transport
- rendering control plane 继续负责 draw/submit/present，`PlatformShell` 只提供 native surface binding
  与 display facts

为了让关系更直观，先给一个 ASCII 示意：

```text
+------------------------------------------------------+
| UiRuntime / Interaction / TextInputSession / A11y    |
| frame pump / input normalization / semantic truth    |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| PlatformShell                                        |
| host window / screen / clipboard / DnD / cursor      |
+-------------+----------------------+-----------------+
              |                      |                 |
              v                      v                 v
+----------------------+  +------------------+  +------------------+
| HostWindow           |  | DisplayTopology  |  | DataTransfer     |
| title / chrome /     |  | monitors / scale |  | clipboard / DnD  |
| focus / IME attach   |  | / DPI / workarea |  | / selection      |
+----------+-----------+  +--------+---------+  +--------+---------+
           |                       |                     |
           +-----------+-----------+---------------------+
                       |
                       v
+------------------------------------------------------+
| SurfaceBinding                                       |
| native surface / view / layer / recreate boundary    |
+---------------------------+--------------------------+
                            |
                            v
+------------------------------------------------------+
| RenderBackend / OS window system / platform APIs     |
+------------------------------------------------------+
```

这张图的硬约束是：

- host truth 在 `UiRuntime` / interaction / text / accessibility / rendering 和 OS 之间显式存在
- native callback、clipboard owner、drag session 和 cursor policy 不能散回 widget wrapper 或 IDE 私有 glue
- same app window、editor surface、preview pane 和 future IDE workbench 必须复用同一套宿主边界

## 只冻结四个宿主对象，不把 shell 膨胀成名词森林

为了保持边界清楚且不过度膨胀，nextPas 在 `PlatformShell` 上只冻结四个核心对象：

- `HostWindow`
- `DisplayTopology`
- `DataTransferSession`
- `SurfaceBinding`

| 对象                  | 负责什么                                                                                                           | 明确不负责什么                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| `HostWindow`          | 表达 toplevel / popup / dialog 等 native window identity、title/chrome、visibility、fullscreen、cursor、IME attach | 不持有 UI 语义树，不解释 command 或 layout semantics |
| `DisplayTopology`     | 表达 display / screen / monitor、work area、scale、DPI、backing factor 与 window-to-display mapping                | 不替代 `LayoutSnapshot`，不决定 visual theme meaning |
| `DataTransferSession` | 表达 clipboard、selection、drag-and-drop、pasteboard item / target / URI / image / text payload negotiation        | 不直接改 text buffer，不拥有 `CommandIntent` truth   |
| `SurfaceBinding`      | 表达 native surface / view / layer 与 render target 的绑定、resize / recreate / lost / destroy boundary            | 不拥有 render graph，不直接执行 GPU command          |

这里最关键的边界是：

- `HostWindow` 先定义“宿主到底暴露了哪个窗口和哪些窗口级事实”
- `DisplayTopology` 再定义“这个窗口当前附着在哪些 screen / monitor / scale truth 上”
- `DataTransferSession` 定义“宿主数据交换这次在传什么、怎么协商”
- `SurfaceBinding` 最后定义“rendering 真正绑定到哪个 native surface 上”

## `HostWindow` 必须先是宿主窗口对象，而不是 scene node 或 platform callback 拼图

`gtk_window_new`、`gtk_window_present`、`setTitle:`、`setFrame:display:`、`makeKeyAndOrderFront:`、
`toggleFullScreen:` 这些事实都说明：window lifecycle、activation、frame 和 chrome 从来不是 UI 小细节。

因此 nextPas 冻结：

- `HostWindow` 是 app window、dialog、popup、tool window、preview window 这一类 native host object 的正式表达
- 它至少要能表达 title、visibility、activation/focus transport、frame/content size、chrome/fullscreen、
  cursor policy、native text service attach 与 surface-facing attachment point
- `UiScene` 不直接持有 `NSWindow*`、`GtkWindow*`、`X11 Window` 一类宿主对象
- `HostWindow` 变化先进入 `PlatformShell` 与 `UiRuntime`，再影响 interaction/layout/rendering，而不是反过来

这条规则直接挡住两种坏结构：

- scene node 自己偷偷持有平台 window 句柄
- IDE 各个 surface 各自维护一套 dialog / popup / preview window glue

## `DisplayTopology` 必须拥有 screen、monitor、scale 和 work area 真相

`gdk_screen_get_n_monitors`、`gdk_screen_get_monitor_geometry`、`backingScaleFactor`、
`WidthMMOfScreen` 这些事实都说明：display 和 monitor 几何不是附带数据，而是正式宿主真相。

因此 nextPas 要求：

- `DisplayTopology` 是 screen / monitor / work area / scale / DPI / backing factor 的正式 owner
- 它至少要能表达 display identity、monitor geometry、window-to-monitor mapping、logical-vs-physical size
  与 scale-facing facts
- layout control plane 可以消费这些 facts 去决定 constraint，但不能自己变成 screen owner
- style/theme control plane 可以消费 platform appearance / scale-facing input，但不能自己维护第二套
  display topology

这条规则的意义很直接：

- window move、monitor change、DPI change、HiDPI backing change 都有单一正式来源
- preview pane、main window、future multi-window IDE workbench 可以共用同一套 screen truth
- Linux/macOS 以及 future target 的 screen 差异不会被散回各层局部 callback

## `DataTransferSession` 必须把 clipboard、selection 和 drag-and-drop 收成同一条宿主传输线

`gtk_clipboard_*`、`gtk_selection_*`、`gdk_drag_*`、`NSPasteboard`、`NSDragging` 与 X11 selection
事实说明：clipboard、selection、drag-and-drop 虽然看起来分散，但它们本质上都是宿主 data transfer 边界。

因此 nextPas 冻结：

- `DataTransferSession` 是 clipboard、selection、drag-and-drop、file drop、text/image/URI payload negotiation
  的统一宿主 transport owner
- 它至少要能表达 source/target window、payload kind、offered types、ownership、lifecycle state 和
  completion / cancellation
- interaction control plane 可以消费 drop / paste / copy trigger，但 payload transport 仍然归
  `DataTransferSession`
- `TextInputSession` 可以消费 text-facing clipboard / pasteboard 结果，但 `PlatformShell` 不直接改 text model

这条分层直接挡住两种坏结构：

- editor 一套 clipboard bridge，普通 controls 再一套 clipboard bridge
- IDE project tree、package view、designer surface 各自维护 file drop / URI drop 私有实现

## `SurfaceBinding` 必须把 native surface integration 单独关住

`gdk_drag_find_window_for_screen`、`gdk_window_set_cursor`、`screen` / `backingScaleFactor`、
`initWithContentRect:styleMask:backing:defer:screen:` 和 `ui-rendering-specification.md` 里的
`SurfaceFrame` 一起说明：windowing 和 rendering 的接缝必须显式建模。

因此 nextPas 明确：

- `SurfaceBinding` 负责表达某个 `HostWindow` 或 native view/layer 和 render target 之间的正式绑定
- 它至少要能解释 native handle attachment、resize / recreate boundary、scale propagation、destroy / lost surface、
  focus-visible presentability 与 offscreen-vs-onscreen distinction
- `RenderBackend` 消费 `SurfaceBinding` 与 `SurfaceFrame`，但不反向拥有 windowing truth
- `PlatformShell` 可以暴露 target-specific surface handle，但公开宿主边界不因此分裂成 backend-private API

这条规则能直接提供：

- on-screen app window、IDE workbench、preview pane 和 offscreen snapshot 的统一宿主接缝
- lost surface、recreate、scale change 和 window destroy 的正式归属
- rendering / runtime / shell 各自职责清楚的 surface lifecycle

## interaction、text 和 accessibility 只消费宿主 transport，不拥有第二套 host truth

只要 UI 进入真实平台，输入、IME、clipboard、drag-and-drop、assistive transport 一定会和其他 control plane 相接。
但 nextPas 在这里明确：

- interaction control plane 继续拥有 `InputEvent`、`FocusPath`、`CommandIntent` 和 routing truth
- `PlatformShell` 只负责把 pointer / keyboard / touch / selection / DnD / native command transport 接进来
- `TextInputSession` 继续拥有 composition、caret、selection 和 edit mediation truth，`PlatformShell`
  只提供宿主 IME / pasteboard / native text service bridge
- `AccessibilityBridge` 继续负责平台 accessibility API 映射与 action transport，`PlatformShell`
  不拥有第二棵 accessibility tree

这条边界是为了避免：

- clipboard transport 重新吞掉 text model
- native menu / drag / pasteboard callback 直接绕开 interaction router
- 平台 accessibility 对象重新变成系统唯一语义树

## 性能模型必须直接进入 `PlatformShell` 设计

如果 nextPas 想现代、高性能、优雅，宿主边界本身就必须有明确性能约束。

第一阶段坚持这些规则：

- native window、display、surface 和 data-transfer identity 应尽量稳定，避免每次小更新都重新建桥
- DPI / screen / backing change 应优先走结构化 delta，不优先全 UI 重建
- clipboard / DnD payload negotiation 应避免无控制地复制大对象，优先保留 lazy / deferred transport 能力
- 平台句柄和 callback 只在 `PlatformShell` 边界内停留，不向 scene / layout / text / rendering 泛滥
- same workbench window、preview surface 和 app window 应建立在同一套 shell contract 上，不继续散成 toolkit-private glue

这条规则的本质是：host integration 不是“反正包一层就行”的杂项，它也是长期架构和性能路径的一部分。

## `stage0`、`stage1` 与 `stage2` 如何接这份规范

- `stage0`
  - 先只冻结 `PlatformShell` 的对象边界和相邻职责
  - 不要求当前最小 `nextpas build` 路径立刻交付 GUI app、native dialog、multi-window workbench 或 designer
- `stage1`
  - 可以开始实现最小 `HostWindow`、`DisplayTopology`、`DataTransferSession` 和 `SurfaceBinding`
  - 可以开始为 single-window app、editor surface、preview surface 和 file/text clipboard 预留正式入口
  - 但不承诺完整 platform feature matrix、native menu system 或 advanced window management
- `stage2`
  - 只有当 shell/runtime/interaction/text/accessibility/rendering 都稳定后，才值得继续调查 richer
    multi-window IDE、system integration、portal/desktop-service bridge 与更完整的 host policy

## 第一阶段非目标

- 不把这份规范写成 GTK、Cocoa、X11 或 future Win32 API 的逐项封装清单。
- 不让 `PlatformShell` 反向拥有 UI 语义树、layout truth、text truth 或 accessibility truth。
- 不把 clipboard / DnD / IME transport 直接写成 editor 私货或 IDE 私有 callback 集合。
- 不在第一阶段承诺 native menu bar、visual designer、dock/floating window policy 或系统文件对话框全覆盖。
- 不把 target-specific handle 类型暴露成 nextPas 长期公开 UI API 的主体。
