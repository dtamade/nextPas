# nextpas.core.window

**状态**: 1.0 稳定 — S1→S5+M-band→F1-F4 单源收口全完成，13 门禁全绿，`bench_dispatcher` 365/161µs 中位（PostSingle/Zero 单一口径，O(1)+inline+共享队列+家族化 210/16ns 单次实测）
**层级**: L2 系统能力（依赖 L0-L1；被 L3 的 `webview` / `gpu` / `directui` / 外部 `game888` 复用）
**Owner**: core-window lane
**最后更新**: 2026-08-28（1.0 收口：window.gtk3 Raw 12项 + webview.gtk.win shim 单源 + 5×方差固化 + Win/mac compile-only 残差诚实）
**对标基准**: Rust `winit` + `tao` / `GLFW` / `SDL2 Window` / `Flutter View` / Android `Activity.getWindow()` / iOS `UIWindow`

---

## 模块定位

`nextpas.core.window` 为所有需要操作系统窗口/表面的上层模块提供统一、可复用、零成本的最小完整抽象：

```
platform(L0) ──► window(L2) ──► gpu(L3) ──► directui(L3)
                    ▲  ▲  ▲
                    │  │  └─ game888.graphics.window 的未来底座（SDL2 后端复用）
                    │  └──── webview(L3) = window 壳 + WebKit/WebView2/WK 内容
                    └─────── 未来对话框/IDE workbench 等任意需窗体的消费者
```

* **tui 不需要本模块**（终端格网，无窗口概念），但 `gpu` / `webview` / `directui` / `game888` 全部需要窗口 — 这就是把 `window` 独立在 L2 而非藏在某个 L3 内部的根本理由。
* `nextpas.core.webview.gtk.win` 已在 F4 单源化为 `window.gtk3 Raw` 的 `inline` shim（零逻辑，窗口创建已收敛），`nextpas.core.gpu.gl`（自管 `glXGetProcAddress`）、`game888.graphics.window`（私有 SDL2 窗口）待 `gpu` 波次同理收敛。

**命名说明**：公共模块名定为 `window` 而非 `shell`。`shell` 仅见于 Eclipse SWT 与 Wayland 协议的极小范围，主流跨平台框架清一色叫 `Window`（`winit::Window` / `tao::Window` / `QWindow` / `SDL_Window` / `GLFWwindow`，Android 自身即 `Activity.getWindow()`、iOS 即 `UIWindow`），Flutter 称 `FlutterView` 亦为同一语义。移动端的 `attach 到宿主 Surface（Activity/UIView）` 只是 `WindowKind = Embedded` 的一种实现形态，不是另一个概念；与 `tui` / `webview` 的 `view` 亦不混淆。文档内唯一需要解释的是 `Window = TopLevel on desktop, Embedded Surface on Android/iOS`。

---

## 能力总览

| 域 | 最小闭包（S1-M-band） | 后续扩展（Deferred 登记，触发前不占位） |
|---|---|---|
| 生命周期 | `Create / Show / Hide / Close(幂等) / IsClosed / IsVisible / Focus` | `close-request veto（关闭前确认）` |
| 标题与几何 | `Title / SetBounds(Width/Height) / Min/Max / Resizable / Maximized-Minimize-Restore / GetBounds` | `decorations / transparent / alwaysOnTop / icon / fullscreen / dragRegion` |
| DPI | `GetScaleFactor: Double（GTK 整数诚实升格） / weScaleChanged`，逻辑坐标 = 物理像素 / scale | `per-monitor dynamic reflow` |
| 输入与事件 | `OnEvent(TWindowEvent)` 统一分发（Close/Resized/Moved/FocusIn/Out/ScaleChanged），主线程投递 `IWindowDispatcher.Post`（拒绝 `LM_` 消息伪装） | `键盘/鼠标/触摸/滚轮细分事件、IME` |
| 句柄 | `NativeHandle: TWindowNativeHandle`（X11 XID / HWND / NSWindow* / ANativeWindow* / Wayland nil / WASM canvas 诚实表） | — |
| 主循环 | `WindowRunLoop / WindowExitLoop`（阻塞至末窗关闭或显式退出）；`WindowPumpOnce / PumpAll` 非阻塞单步（M-band，game/directui tick 复用）；`fake` 提供确定性驱动 | `IterateOnce` 完整融入 `TAsyncLoop`（已以 `PumpOnce` 最小落地） |
| 宿主驱动 | `IWindowHost.HostResized/HostScaleChanged/HostCloseRequested`（`wasm/android/uikit/fake` 经 `Supports` 探测，M-band） | — |
| 多窗口 | `TWindowBuilder.New … Build: IWindow` 可多次调用，共享同一 UI 主循环 | `多 view 单窗 / 窗口间通信` |

跨平台差异一律以 **语义诚实表** 记录在 `CONTRACT.md §2`，不做假装。

---

## 依赖方向

```
gtk3/4/2.base ← gtk3/4/2.ffi ← gtk3/4/2.loader (独立 L2 家族，不知 window)
qt5pas/qt.base ← qt5pas/qt.ffi ← qt5pas/qt.loader (独立 L2，deferred)
                │
base ← intf ← fake ─┐  │ one-way 消费
                 factory ← 门面 ←─┘  (wkGtk 智能回退 gtk4>gtk3>gtk2)
base ← window.gtk.impl ← window.gtk3/4/2  (显式共享单元 TGtkOps/TGtkContext，INV-3/INV-5 可扫描；gtk3 另暴露 Raw 12项供 webview 单源)
              sdl2.ffi ← sdl2.loader ← sdl2 ─┘  （同位）
              win32.* / cocoa.* / android.*  同位
  webview.gtk.win (L3 shim) ──► window.gtk3 Raw (单源已收口)
```

* `base` / `intf` 禁止 `uses` 任何后端、`factory`、`bridge`。
* `*.ffi` 只含 ABI 类型与函数指针变量，无逻辑、无 `external`；gtk/qt 的 `ffi` 已提升为独立 L2 家族，`window` 仅消费。
* `*.loader` 是家族内唯一允许触碰动态装载设施的单元，原语一律来自 `nextpas.core.platform.dl`，**禁止 `DynLibs`**；factory 对 `wkGtk` 以 `ProbeGtk4|3|2` 聚合与 `CreateGtkSmart` 回退。
* 生产单元（非 loader）禁止出现 `Windows` / `BaseUnix` / `Unix` / `ctypes` 等 raw host units。

---

## 后端矩阵

| 后端 | 平台 | 窗口实现 | 波次 | 探活 |
|------|------|----------|------|------|
| `win32` | Windows | `CreateWindowEx` + `WM_*` + message-only `PostMessage` | S4 | `WindowWin32IsAvailable` |
| `cocoa` | macOS | `NSWindow` / `NSView` + `dispatch_async` | S4 | `WindowCocoaIsAvailable` |
| `android` | Android | `ANativeWindow` attach 到 `Activity`（`ParentHandle` 必需，`IWindowHost` 驱动） | S5 | `WindowAndroidIsAvailable` |
| `uikit` | iOS | `UIWindow` attach（`ParentHandle` 必需，`IWindowHost`） | S5 | `WindowUIKitIsAvailable` |
| `wasm` | Browser | `<canvas>` attach（`ParentHandle` canvas id，CSS×`devicePixelRatio`，`IWindowHost`） | S5 | `WindowWasmIsAvailable` |
| `gtk` | Linux | GTK 2/3/4 `GtkWindow`（`g_idle_add_full` + 6 信号，显式共享 `window.gtk.impl`；`wkGtk` 智能回退 gtk4>gtk3>gtk2，族显式 `WindowGtk4/3/2IsAvailable`；`gtk3` 另暴露 `WindowGtkRaw*` 12项低阶壳供 webview 单源） | S2+扭转+F4 | `WindowGtkIsAvailable`（聚合） / `ProbeGtk4/3/2` / `WindowGtkRawIsAvailable` |
| `qt` | Linux | Qt5Pas `libQt5Pas.so.1` / 自包装 `libnextpas-qt.so`（独立 L2 家族，window 消费，deferred） | qt | `ProbeQt5Pas/ProbeQt`（独立 diagnostics） |
| `sdl2` | 全平台（含 game888 复用） | `SDL_Window` / `SDL_CreateWindow` + user-event | S3 | `WindowSdl2IsAvailable` |
| `fake` | 全平台无头 | 纯 Pascal 脚本化驱动（`IWindowHost` 全实现） | S1 | 恒真（CI 唯一载体） |

> 探测顺序 `win32 > cocoa > android > uikit > wasm > gtk(聚合 4>3>2) > sdl2 > fake`，`DefaultWindowKind` 能力驱动；`WindowBackendDiagnostics` 追加 `gtk4/gtk2/qt5pas/qt` 独立行；`bench_dispatcher` 365ns 单次中位 `PostSingle` + 16ns 单一口径纯净 `WindowPumpOnceZero`（32cap 共享队列，O(1)+`GetWidth/GetHeight`/`IsClosed`/`GetDispatcher`/`IsOnMainThread` inline + `CheckWindowOptions` 富错误信息；零锁单次原子读快路径零聚合，1.9% 跨机方差收敛，0 泄漏；`window.gtk3 Raw` 零开销 `inline` 单源）。

---

## 使用示例（目标形态）

```pascal
uses
  nextpas.core.window;

var
  LWin: IWindow;
begin
  LWin := TWindowBuilder.New
    .Title('Demo')
    .Size(1280, 720)
    .MinSize(640, 480)
    .Resizable(True)
    .Build;                          // IWindow，COM 引用计数
  LWin.OnEvent(procedure(const E: TWindowEvent)
  begin
    if E.Kind = weCloseRequested then
      LWin.Close;
    if E.Kind = weResized then
      InvalidateScene(E.Width, E.Height);
  end);
  LWin.Show;

  // 让出主线程给窗口系统；阻塞直到末窗关闭或 WindowExitLoop
  WindowRunLoop;
end;
```

嵌入内容（gpu / webview / directui）统一经句柄 + 宿主扩展：

```pascal
// gpu 侧：拿句柄建 GL 上下文
Ctx := gl_context_create(LWin.NativeHandle, LWin.GetScaleFactor);
// webview 侧：组合 window 壳 + web 内容
WvWin := TWebviewBuilder.New.WithWindow(LWin).Navigate('npres://app/index.html').Build;
// 宿主侧（Android/iOS/WASM）：经强类型 IWindowHost 注入，不经 LM_ 消息
if Supports(LWin, IWindowHost, Host) then
begin
  Host.HostResized(ANativeWindow_getWidth(H), ANativeWindow_getHeight(H));
  Host.HostScaleChanged(NewScale);
end;
// game 侧：tick 循环非阻塞泵，不阻塞 RunLoop
while not Quit do
begin
  WindowPumpOnce; // fake/sdl/wasm/android/uikit 合泵
  GameTick; Render;
end;
```

前端无需关心后端；单元测试一律走 `wvFake / winFake`：

```pascal
LWin := TWindowBuilder.New.Kind(wkFake).Size(800, 600).Build;
LWin.Show;
Check(LWin.IsVisible);
LWin.Close;
Check(LWin.IsClosed);
```

复用实证见 `core/examples/nextpas.core.window/demo_pump_loop/`：同一 `IWindow` 既可 `WindowRunLoop` 阻塞，也可 `WindowPumpOnce` 在 `while not Quit do begin PumpOnce; GameTick; Render; end` 中无阻塞复用（`fake` 上 `IWindowHost` 模拟宿主、`WindowPumpOnce` 零活窗快速路径），`make -C core/examples/nextpas.core.window/demo_pump_loop run` 即验（heaptrc 0）。

---

## 设计红线

1. **base/intf 零后端依赖**；后端经工厂注册进入。
2. **拒绝 LCL 式 `LM_` 跨平台消息**：业务语义永走强类型接口/事件/`Supports`，消息仅作底层唤醒原语（`g_idle_add/PostMessage/SDL_PushEvent/dispatch_async`）。
3. **eval/渲染均不提供同步阻塞形态**；跨线程只走 `IWindowDispatcher.Post`，宿主驱动经 `IWindowHost`。
4. **所有用户回调统一在 UI 主线程触发**；可跨线程的仅 `Post` 与 `Close(内部 marshal, 幂等)`。
5. **整体事件驱动，不得硬编码等待**：`RunLoop` 以 `gtk_main/SDL_WaitEvent/WaitMessage/dispatch` 或 `IEvent` 阻塞于 OS/宿主事件，`DispatcherPush` 以 `SetEvent` 立即唤醒，`WaitTimeout(5ms)` 仅作活窗复核，无 `sleep(1)` 轮询。
6. **Deferred 能力不预埋占位**，每项有触发条件（见 `CONTRACT.md §9`）。
7. **`fake` 是 CI 契约的唯一载体**（见 `CONTRACT.md §8`）；图形环境缺席时测试仍全绿；`WindowPumpOnce` 为 game/directui 提供非阻塞复用。

---

## 文档导航

| 文档 | 内容 |
|------|------|
| `CONTRACT.md` | 冻结契约：单元布局、类型/接口签名、线程模型、不变量、错误、Deferred、测试门禁、宿主与非阻塞泵（含 `Raw` 内缝） |
| `ARCHITECTURE.md` | 架构纵深：抽取缝、后端矩阵、事件/DPI/主循环、去消息化、与 gpu/webview/game888/directui 的组合（F4 单源） |
| `FINAL_ROADMAP.md` | 终局路线图：M-band→F1-F5 五维收敛至 1.0（含 5×方差与 `Raw` 单源决策） |
| `BENCH.md` | 性能基线：7 项中位 + 5×方差 + 三机残差诚实表 |
| `ROADMAP.md` | 分波实施图：S1→S5 全后端 + M-band→1.0（13 门禁，365/271µs，0泄漏） |
