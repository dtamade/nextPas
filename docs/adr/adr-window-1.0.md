# ADR window-1.0 — nextpas.core.window 1.0 定版决策

**状态**: Accepted 2026-08-28
**模块**: `nextpas.core.window` L2 家族 + `gtk2/3/4/qt` 独立 L2
**标签**: `window-1.0`

## 背景

`window` 自 S1 起历经 S2-wasm、S3-sdl2、S4-win32/cocoa、S5-android/uikit/wasm-attach、M-band 去消息化、F1 硬化、F2 复用实证、F3 CI 矩阵、F4 双阶段单源收口，13 门禁 Linux 全绿、Win/mac compile-only 残差诚实、`bench_dispatcher` 5×方差收敛、heaptrc 0。本 ADR 封存 1.0 的四项核心决策与一条单源伦理决策。

## 决策

### 1. 抽象不束缚（Abstract Unbound）

`IWindow` 仅暴露 `TWindowNativeHandle = Pointer` 不透明句柄与物理像素几何，不暴露 `HWND/NSWindow/XID` 平台语义；`ParentHandle` 桌面拒、attach 接受；几何/DPI 全进 `CONTRACT §2` 诚实表。消费方（gpu/webview/directui/game888）用 `platform.info` 自行判别，不设 `HandleOS()` 伪抽象。

### 2. 事件驱动去消息化

拒绝 LCL 式跨平台消息伪装；`TWindowEventKind` 7 种 + `weScaleChanged` 单通道 `OnEvent` 分发，`IWindowDispatcher.Post` 为唯一线程投递原语。唤醒原语按后端诚实：`g_idle_add_full / SDL_PushEvent / PostMessage / dispatch_async`，`WaitTimeout(5ms)` 仅活窗复核，无 `sleep(1)` 轮询。

### 3. 家族化与伦理扭转

`gtk2/3/4/qt5pas/qt` 自立 L2 独立家族（`base/ffi/loader` 单向 `platform.dl`），`window` 单向消费，`factory BACKENDS[8]` 能力驱动 `ProbeGtk聚合4>3>2智能回退`，探测序 `win32>cocoa>android>uikit>wasm>gtk>sdl2>fake`。`gtk.impl.inc` 719 行共享 + `gtk3/4/2` 薄包装消除三拷贝。

### 4. RTL 解耦与纪律

禁止 `uses SysUtils/Math/TypInfo/Classes` 裸引；`text.ansi (StrToAnsi/AnsiPtrToStr/HoldAnsi)`、`diagnostics (TDiagnosticsBuilder)`、`math (SetExceptionMask)` L1 已反哺落地，`window.gtk/sdl2/win32/wasm` 标题与 `factory diagnostics`、`webview.gtk.win` 全量迁移，`INV-RTL` 门禁全拦。

### 5. Raw 单源（F4 伦理收口）

`window` 为 `webview/gpu/directui/game888` 共享 L2，`webview.gtk.win` 的窗口壳不应双份。`window.gtk3` 暴露 `WindowGtkRaw*` 12 项低阶壳（Init/Create/Title/Resize/Show/Hide/IsMaximized/Maximize/Unmaximize/Scale/Focus/Native/Run/Quit）`inline` 零开销转发已绑定 `gtk_*`，`webview.gtk.win` 退化为 12 行 `inline` shim 单源转发，`GTK_container_add` 仍由 `webview.gtk.ffi` 承载 WebKit 内容，窗口创建已单源，符合 `CONTRACT §1` 内缝预备缝兑现。

## 后果

- 消费方零反向依赖，`directui/game` 以 `WindowPumpOnce` 非阻塞复用，`webview` 单点变更即可跟随 `window`。
- `TWindowQueue(32cap环形)` 与 `TWindowLiveRegistry(O(1) inline)` 双共享设施覆盖 8 后端；热路径 `GetWidth/GetHeight/IsClosed/GetDispatcher/IsOnMainThread` 全 `inline`，`WindowPumpOnceZero` 264µs/10k≈26ns 早退（家族化 +10ns 诚实）。
- Truth Level `focused-runtime → ci-matrix (Linux runtime + Win/mac compile-only)`，三机均绿为后续 `window-1.1` 完整 `ci-matrix` 目标。

## 备选

- `TWindowDispatcherBase` 已抽取至 `nextpas.core.window.dispatcher.base`（55 行基类收口 7 后端 120 行样板 ROI≈2.2，各后端仍持独立 `GQueue/GWaitEvent` 全局隔离，`DoWake` 虚派仅唤醒路径），见 FINAL_ROADMAP F1 复评。
- `webview.gtk.win` 若经 `IWindow` 高阶抽象嵌入 WebKit 将强耦合生命周期，Raw 低阶壳为最小必要缝。

## 链接

- `core/docs/window/CONTRACT.md` §1 家族布局、`§2` 诚实表、`§8` 门禁
- `core/docs/window/FINAL_ROADMAP.md` F1-F5 波次、`BENCH.md` 5×方差
- `core/docs/window/README.md` 1.0 能力总览
