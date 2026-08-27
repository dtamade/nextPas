# nextpas.core.window

**状态**: Design S0 — 契约冻结前，源码未落地；注册表项随 S1 首个 family 同批进入
**层级**: L2 系统能力（依赖 L0-L1；被 L3 的 `webview` / `gpu` / `directui` / 外部 `game888` 复用）
**Owner**: core-window lane
**最后更新**: 2026-08-26
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
* 当前散落在 `nextpas.core.webview.gtk.win`（内部缝 `WinShell*` 纯函数转发）、`nextpas.core.gpu.gl`（自管 `glXGetProcAddress`）、`game888.graphics.window`（私有 SDL2 窗口）三处的窗口能力收敛到同一契约。

**命名说明**：公共模块名定为 `window` 而非 `shell`。`shell` 仅见于 Eclipse SWT 与 Wayland 协议的极小范围，主流跨平台框架清一色叫 `Window`（`winit::Window` / `tao::Window` / `QWindow` / `SDL_Window` / `GLFWwindow`，Android 自身即 `Activity.getWindow()`、iOS 即 `UIWindow`），Flutter 称 `FlutterView` 亦为同一语义。移动端的 `attach 到宿主 Surface（Activity/UIView）` 只是 `WindowKind = Embedded` 的一种实现形态，不是另一个概念；与 `tui` / `webview` 的 `view` 亦不混淆。文档内唯一需要解释的是 `Window = TopLevel on desktop, Embedded Surface on Android/iOS`。

---

## 能力总览

| 域 | 最小闭包（S1） | 后续扩展（Deferred 登记，触发前不占位） |
|---|---|---|
| 生命周期 | `Create / Show / Hide / Close(幂等) / IsClosed / IsVisible / Focus` | `close-request veto（关闭前确认）` |
| 标题与几何 | `Title / SetBounds(Width/Height) / Min/Max / Resizable / Maximized-Minimize-Restore / GetBounds` | `decorations / transparent / alwaysOnTop / icon / fullscreen / dragRegion` |
| DPI | `GetScaleFactor: Double（GTK 整数诚实升格） / OnScaleChanged`，逻辑坐标 = 物理像素 / scale | `per-monitor dynamic reflow` |
| 输入与事件 | `OnEvent(TWindowEvent)` 统一分发（Close/Resized/Moved/FocusIn/Out/ScaleChanged），主线程投递 `IWindowDispatcher.Post` | `键盘/鼠标/触摸/滚轮细分事件、IME` |
| 句柄 | `NativeHandle: TWindowNativeHandle`（X11 XID / HWND / NSWindow* / ANativeWindow* / Wayland nil 诚实表） | — |
| 主循环 | `WindowRunLoop / WindowExitLoop`（阻塞至末窗关闭或显式退出）；`fake` 提供 `PumpOnce` 确定性驱动 | `IterateOnce` 融入 `TAsyncLoop` |
| 多窗口 | `TWindowBuilder.New … Build: IWindow` 可多次调用，共享同一 UI 主循环；`Run` 为单窗便捷封装（Build+Show+RunLoop，CONTRACT §4.3） | `多 view 单窗 / 窗口间通信` |

跨平台差异一律以 **语义诚实表** 记录在 `CONTRACT.md §2`，不做假装。

---

## 依赖方向

```
base ← intf ← fake ─┐
                 factory ← 门面
base ← gtk.ffi ← gtk.loader ← gtk ─┘
              sdl2.ffi ← sdl2.loader ← sdl2 ─┘  （同位）
              win32.* / cocoa.* / android.*  同 gtk 位，波次接入
```

* `base` / `intf` 禁止 `uses` 任何后端、`factory`、`bridge`。
* `*.ffi` 只含 ABI 类型与函数指针变量，无逻辑、无 `external`。
* `*.loader` 是家族内唯一允许触碰动态装载设施的单元，原语一律来自 `nextpas.core.platform.dl`，**禁止 `DynLibs`**。
* 生产单元（非 loader）禁止出现 `Windows` / `BaseUnix` / `Unix` / `ctypes` 等 raw host units。

---

## 后端矩阵

| 后端 | 平台 | 窗口实现 | 波次 |
|------|------|----------|------|
| `gtk` | Linux | GTK3 `GtkWindow` | S2（从 `webview.gtk.win` 机械抽取）+ S1 `fake` 并行 |
| `fake` | 全平台无头 | 纯 Pascal 脚本化驱动 | S1（契约测试唯一载体） |
| `sdl2` | 全平台（含 game888 复用） | SDL2 `SDL_Window` / `SDL_CreateWindow` | S3 |
| `win32` | Windows | `CreateWindowEx` + `WM_*` | S4（与 `webview` Wave 2 同步抽取，避免双份 Win32 缝） |
| `cocoa` | macOS | `NSWindow` / `NSView` | S4 |
| `android` | Android | `ANativeWindow` attach 到 `Activity`（`ParentHandle` 非 nil） | S5 |
| `uikit` | iOS | `UIWindow` / `UIView` attach | S5 |

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

嵌入内容（gpu / webview / directui）统一经句柄：

```pascal
// gpu 侧：拿句柄建 GL 上下文
Ctx := gl_context_create(LWin.NativeHandle, LWin.GetScaleFactor);
 // webview 侧：组合 window 壳 + web 内容（S2 后 webview.gtk 改为组合本模块）
WvWin := TWebviewBuilder.New.WithWindow(LWin).Navigate('npres://app/index.html').Build;
```

前端无需关心后端；单元测试一律走 `wvFake / winFake`：

```pascal
LWin := TWindowBuilder.New.Kind(wkFake).Size(800, 600).Build;
LWin.Show;
Check(LWin.IsVisible);
LWin.Close;
Check(LWin.IsClosed);
```

---

## 设计红线

1. **base/intf 零后端依赖**；后端经工厂注册进入。
2. **eval/渲染均不提供同步阻塞形态**；跨线程只走 `IWindowDispatcher.Post`。
3. **所有用户回调统一在 UI 主线程触发**；可跨线程的仅 `Post` 与 `Close(内部 marshal, 幂等)`。
4. **Deferred 能力不预埋占位**，每项有触发条件（见 `CONTRACT.md §9`）。
5. **`fake` 是 CI 契约的唯一载体**（见 `CONTRACT.md §8`）；图形环境缺席时测试仍全绿。

---

## 文档导航

| 文档 | 内容 |
|------|------|
| `CONTRACT.md` | 冻结契约：单元布局、类型/接口签名、线程模型、不变量、错误、Deferred、测试门禁 |
| `ARCHITECTURE.md` | 架构纵深：抽取缝、后端矩阵、事件/DPI/主循环、与 gpu/webview/game888/directui 的组合 |
| `ROADMAP.md` | 分波实施图：S1 docs+fake → S2 抽取 → S3 SDL2 → S4 Win32/Cocoa+directui → S5 mobile |
