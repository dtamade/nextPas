# Window × Webview 优雅组合设计 — 单一窗口所有权 + 内容组合

**状态**: Draft for Review (2026-08-31)
**Owner**: core-window + core-webview 联合 lane (当前 worktree `core-webview`)
**决策层**: L2 `window` 单一所有权，L3 `webview` 组合消费
**前置清理**: `core-window` worktree/分支已整干净 (2026-08-31: 11 个 `landing/*window*` 已合入主线并删除, `codex/core-window` 重建到 `main:d1f54552e`, 仅保留 `codex/core-window` + `archive/gpu-window-recovery` + `recovery/*` 归档)

---

## 1. 背景 — 为什么 webview 切不到 window

### 1.1 历史包袱
`webview/CONTRACT §1.1` 在 Wave 1 刻意不建 `window` 模块, 用 `webview.gtk.win` 内缝先行。F4 时 `window` 1.0 已 11 后端 (`gtk2/3/4/qt/sdl2/win32/cocoa/wasm/android/uikit/fake`)、`gtk.impl.inc` 718 行共享、`window.live/queue` 单源, 并通过 `WindowGtkRaw*` 12 项低阶壳把 `webview.gtk.win` 退化为 `inline shim` 单源。但这只是 **Raw 指针级单源**, 不是接口级组合:

- `window` 公共面是 `IWindow` (COM 接口, 单一 `OnEvent(TWindowEvent)`, `IWindowDispatcher`, `WindowRunLoop/WindowPumpOnce`, `TWindowNativeHandle`, 物理像素几何)
- `webview` 公共面是 `IWebviewWindow` (COM 接口, 分散的 `OnNavigationStarted/Finished/Failed/OnReady/OnScaleChanged`, `IWebviewDispatcher`, `WebviewRunLoop`, `TWebviewNativeHandle`, 含 `Navigate/Eval/Emit/Invokes/Assets`)

两者 **shell 方法签名几乎 1:1 重复** (`SetTitle/SetBounds/Show/Hide/Maximize/Minimize/GetScaleFactor/Focus/NativeHandle/Close/IsClosed/Dispatcher`), 但 webview 无法 `uses window.IWindow` 组合, 只能 `uses window.gtk3.WindowGtkRaw*` Raw 指针。

### 1.2 当前 7 大重复/割裂 (严重度排序)

| # | 痛点 | 证据 | 影响 |
|---|------|------|------|
| P1 | **双 live 注册表 + 双 run loop** | `webview.factory.WebviewRunLoop` 轮询 `GtkLiveWindowCount/WebView2LiveWindowCount/WkLiveWindowCount/FakeLiveWindowCount` 四表; `window.factory.WindowRunLoop` 轮询 `window.live.TWindowLiveRegistry` 单表。两套 `GExitRequested`+`WinShellRunMainLoop/Win32ShellRunMainLoop`。 | 单进程双泵, `game888/directui` 的 `WindowPumpOnce` tick 循环无法驱动 webview。性能: 额外一次 `platform_thread_yield` + 重复 `IsClosed` 扫描。 |
| P2 | **双 dispatcher 队列** | `webview.intf.IWebviewDispatcher` vs `window.intf.IWindowDispatcher` 语义 1:1 (任意线程→主线程, Close 后丢弃, `IsOnMainThread`), 各自 `g_idle_add_full/PostMessage/dispatch_async`。 | 投递分裂, handler 完成态需跨两队列 marshal, `fake` 的 `PumpOnce` 需各泵一次。 |
| P3 | **win32/cocoa 仍双份壳** | `webview.webview2.win.Win32Shell*` 400 行 `RegisterClassExW/WndProc/GetDpiForWindow/DispatchWnd` vs `window.win32` 同款; `wk` 桩同理。F4 只单源了 gtk。 | 改 `window.win32` 的 DPI 或 `WM_DPICHANGED` 需同步改 `webview.webview2.win`, 违背单源。 |
| P4 | **Raw 非通用** | `WindowGtkRawCreate(Title,W,H,...):Pointer` vs `Win32ShellCreate(TWin32ShellGeometry):Pointer` 签名不统一, 暴露 `Pointer`+`PAnsiChar` 裸指针, 无类型安全, 无法跨后端抽象。 | webview 每新增后端 (qt/wasm 等) 都要写一套 Raw 适配, 违背 `window` 通用承诺。 |
| P5 | **事件模型割裂** | `window`: 单一 `OnEvent(TWindowEvent)` 含 `weResized/weMoved/weScaleChanged/weDpiChanged/weCloseRequested/weClosed/weKeyDown/...` 12 种; `webview`: 6 个独立注册面 `OnNavigation*/OnReady/OnScaleChanged/OnWindowClosed`。 | `weResized→put_Bounds` 同步、`weScaleChanged→IWebviewWindow.OnScaleChanged` 需手写转发表, 易遗漏。 |
| P6 | **attach 语义缺失** | `window` 的 `TWindowOptions.ParentHandle` 在 `wasm/android/uikit` 为必需 (宿主 surface attach), `webview` 的 `TWebviewOptions` 无 `Parent` 概念, 只能创建顶层窗。 | `webview` 无法复用 `directui/game` 已有的 `IWindow` 作为容器, 移动端/WASM 无法嵌入。 |
| P7 | **NativeHandle 语义重复** | 两模块各定义 `T*NativeHandle = type Pointer` + 诚实表 (X11 XID/Wayland nil/HWND/NSWindow* 等), 表内容 90% 重叠。 | 消费方需记忆两份表, 嵌入 `gpu` 上下文时 handle 来源歧义。 |

### 1.3 结论: window 形态不优雅的根因
`window` 的通用性在于 `IWindow` 接口, 但对 `webview` 暴露的是 `Window*Raw*` 裸指针 — 这是 **实现细节泄露**。优雅的形态应是 **window 只暴露 `IWindow` (容器), webview 组合它**, 而非 webview 绕过 `IWindow` 直接调 `gtk_window_new`。

---

## 2. 目标与非目标

**目标 (Goals)**:
- G1 单一所有权: 进程内 **唯一** live 注册表/queue/run loop, 归 `window`。`webview` 零自建 loop/queue。
- G2 真通用: `webview` 在 11 个 `window` 后端上均可创建 (顶层窗) 或 attach (子视图), 包括 `wasm/android/uikit` 的宿主 surface 形态。
- G3 零成本: shell 方法 `SetTitle/SetBounds/Show/...` 均为 `inline` 转发到内层 `IWindow`, 无虚表二次分发、无额外分配、无 `PAnsiChar(AnsiString)` (经 `text.ansi`)。
- G4 可演进: `webview` 的引擎绑定 (`WebKitWebView/WebView2/WKWebView`) 作为 **child view** 挂到 `IWindow.NativeHandle` 容器, 与 `gpu/directui` 同为 `window` 的内容消费者, 不污染 `window`。
- G5 单泵: `WindowPumpOnce` 一次泵即驱动 `window` 事件 + `webview` 导航/桥回执, `game` tick 循环 `while not Quit do begin WindowPumpOnce; GameTick; Render; end` 天然复用。

**非目标 (Non-Goals)**:
- 不把 `WebKit`/`WebView2` API 塞进 `window` (window 零 webview 概念, INV-3 保持)。
- 不统一 `IWindow` 与 `IWebviewWindow` 为同一接口 (职责不同: window=壳, webview=壳+引擎内容)。
- 不在本次做 `IterateOnce` 与 `TAsyncLoop` 融合 (deferred-LI 保持, 本设计只保证 `WindowPumpOnce` 可复用)。

---

## 3. 设计 — 组合优于继承

### 3.1 架构图

```
L2 window (sole owner, 平台无关)    L3 webview (composer, 平台无关, has-a)
┌─────────────────────┐         ┌──────────────────────────────┐
│ IWindow (shell)     │◄──has──│ IWebviewWindow               │
│  NativeHandle ──────┼──parent──► FWindow: IWindow (owned)   │  // 组合包含
│  OnEvent ───────────┼──forward─► FEngine: Pointer            │  // WebKit*/Wv2/WK*
│  Dispatcher ────────┼──reuse──►  bridge / assets             │
│  live/queue/loop    │         │  Invokes / Eval / Navigate   │
└─────────────────────┘         └──────────────────────────────┘
         WindowRunLoop / WindowPumpOnce  (唯一泵, webview 零自建)
  调用: View.Window.Show / View.Navigate / View.Window.OnEvent
  多态糖: View.QueryInterface(IWindow) 可当 IWindow 传参
```

**所有权 (has-a 纯组合)**: `TWebviewImpl = class(TInterfacedObject, IWebviewWindow, IWindow)` 私有类持有 `FWindow: IWindow` (COM 引用计数拥有, 平台无关) + `FEngine: Pointer` (WebKitWebView*/ICoreWebView2Controller/WKWebView*)。`Close` 仅毁 `FEngine`, 不 `FWindow.Close` (若 ParentWindow 传入则不拥有, 顶层窗则拥有)。`FWindow.OnEvent` 为唯一窗口事件源, 内部转译 `weResized→engine put_Bounds`, `weScaleChanged→转调`, `weCloseRequested→OnWindowClosed`。`IWindow` 同时实现仅为糖: `QueryInterface(IWindow)` 可把 IWebviewWindow 当 IWindow 传参, 日常一律 `View.Window.Show`。

### 3.2 接口变更 (最小必要)

**window 侧 — 零变更**:
`window` 保持零 webview 概念, 无需新增 API。`webview` 通过 `TWindowOptions.ParentHandle := AParent.NativeHandle` 间接复用 attach 语义(已在 `wasm/android/uikit` 生效)。

**webview 侧 — 核心变更 (平台无关)**:
```pascal
// webview.base — 零变更 (保持 base 纯类型, 不引 IWindow, 避免 base←intf 倒置)
// TWebviewOptions 保持 14 字段不变 (Title/Width/Height/MinMax/Resizable/Maximized/DebugTools/SchemeName/InitialHtml/Url/DevServerUrl/DataDirectory/EphemeralSession/InitScripts)

// webview.factory — 新增组合构造 (Parent 经工厂参数, 不进 base)
function CreateWebviewOf(AKind: TWebviewKind; const AOptions: TWebviewOptions): IWebviewWindow; // 已有: 顶层窗 (内部自建 IWindow)
function CreateWebviewOn(const AParent: IWindow; const AOptions: TWebviewOptions): IWebviewWindow; // 新增: attach 到已有 IWindow (Parent=nil 时同 CreateWebviewOf)
// Builder 新增
function Parent(const AWindow: IWindow): IWebviewBuilder; // 链式指定父窗, 内部存 FParent: IWindow, Build 时走 CreateWebviewOn
```

// webview.intf — 组合包含 (has-a, 纯组合, 不继承 IWindow)
IWebviewWindow = interface
  ['{7C1E4A20-83B5-4E97-9D42-A6B1C2D3E006}'] // 保持原 GUID
  // 组合入口: 平台无关的 IWindow (L2), webview 仅持有不拥有创口
  function GetWindow: IWindow;
  property Window: IWindow read GetWindow;

  // webview 专有 (壳方法不重复, 一律经 Window 访问: Window.Show/Window.SetTitle...)
  procedure Navigate(const AUrl: string);
  procedure NavigateToString(const AHtml: string);
  procedure Reload; procedure Stop;
  function CanGoBack: Boolean; function GoBack: Boolean;
  function CanGoForward: Boolean; function GoForward: Boolean;
  procedure Eval(const AJavascript: string; ACallback: TWebviewEvalCallback; AOnError: TWebviewEvalErrorCallback);
  procedure Emit(const AEvent, APayloadJson: string);
  // 事件: 导航/就绪 (窗口事件 weResized/weScaleChanged 归 Window.OnEvent, 不重复)
  procedure OnNavigationStarted(AHandler: TWebviewNavEventHandler); overload;
  procedure OnNavigationFinished(AHandler: TWebviewNavEventHandler); overload;
  procedure OnNavigationFailed(AHandler: TWebviewNavFailedHandler); overload;
  procedure OnReady(AHandler: TWebviewNotifyHandler); overload;
  // 组合资源
  function GetInvokes: IWebviewInvokeRegistry; property Invokes: IWebviewInvokeRegistry read GetInvokes;
  function GetAssets: IWebviewAssets; property Assets: IWebviewAssets read GetAssets;
  // 生命周期: 仅毁引擎, 不连带 Window.Close (由外部 IWindow owner 决定)
  procedure Close;
  function IsClosed: Boolean;
end;
// 糖: 需要把 IWebviewWindow 当 IWindow 传参时, 经 QueryInterface(IWindow) 或 Window 属性, 私有实现同时实现两接口

// webview.factory — loop 统一
procedure WebviewRunLoop; inline; //  deprecated shim → WindowRunLoop  (保持兼容, 下一主版本移除)
procedure WebviewExitLoop; inline; // → WindowExitLoop
```

**语义 (Parent 经工厂, 不进 base)**:
- `AParent=nil` (默认, CreateWebviewOf): `TWebviewImpl.Create` 内部 `FWindow := CreateWindowOf(DefaultWindowKind, WindowOptionsOf(AOptions))`, `FOwnsWindow:=True`, 再 `FEngine := CreateEngine(FWindow.NativeHandle, AOptions)`。
- `AParent<>nil` (CreateWebviewOn): 跳过 `CreateWindowOf`, `FWindow := AParent`, `FOwnsWindow:=False`, `FEngine := CreateEngine(FWindow.NativeHandle, AOptions)`。`Close` 仅毁 `FEngine`, 不 `FWindow.Close` (由外部 owner 负责)。顶层窗几何来自 `TWebviewOptions`, attach 窗几何归父窗 (`weResized` 同步)。

### 3.3 性能 — 零成本组合

- **转发**: 零重复壳 — 壳一律 `View.Window.*` (Show/SetTitle/SetBounds...), 无 `inline` 转发成本; 糖 `QueryInterface(IWindow)` 同 `FWindow`。
- **queue/live**: 复用 `window.live.TWindowLiveRegistry` + `window.queue.TWindowQueue` (32 cap 起步, 2× 增长, 锁外 Drain, `inline Count` 早退 16ns)。删除 `webview` 的 `GLiveWindows/FIdleTags/GFakeDispatcher` 三表, 减少一次 `platform_thread_yield`。
- **泵**: `WebviewRunLoop` 删除轮询四表的 `while not GExitRequested do if GtkLive... else if W2...`, 改为 `WindowRunLoop` 单表。`WindowPumpOnce` 单次 26ns 早退 (无活窗), `webview` 桥回执经 `FWindow.Dispatcher.Post` 同一队列。
- **字符串**: 全量经 `text.ansi.StrToAnsi/AnsiPtrToStr/HoldAnsi`, 零 `PAnsiChar(AnsiString)` (window 5.0 已零命中, webview 沿用)。

### 3.4 通用性 — 11 后端全覆盖

| window 后端 | webview 引擎 | 创建形态 | 证据 |
|------------|-------------|---------|------|
| gtk3/4/2 | WebKitGTK | 顶层窗或 `Parent(IWindow)` child (`gtk_container_add`) | 现有 gtk 路径单源保留, 删除 `webview.gtk.win` shim |
| win32 | WebView2 | 顶层窗或 child (`SetParent` + `put_Bounds` 随 `weResized` 同步) | 删除 `webview.webview2.win` 的 `RegisterClass/WndProc`, 复用 `window.win32` 的 `WM_SIZE/WM_DPICHANGED` 转译 |
| cocoa | WKWebView | 顶层窗或 child (`addSubview`) | `window.cocoa` 已 `NSWindow`, webview 仅加 `WKWebView` child |
| qt | - | 顶层窗 (暂无 QtWebEngine 绑定, `WebviewBackendAvailable(wvQt)=False` 诚实) | window 已 qt, webview 未来接 `QWebEngineView` |
| sdl2 | - | 同 qt (sdl 无系统 web 引擎) | 诚实 `Unavailable` |
| wasm | - | **attach 必需** (`ParentWindow` 非 nil, `emscripten` canvas child) | 复用 `window.wasm` 的 `ParentHandle` attach, webview 在 wasm 上为 `html <iframe>` 或 `fetch` 形态 (deferred) |
| android/uikit | - | **attach 必需** (`ParentWindow` 宿主 surface) | 复用 `window.android/uikit` 的 `ANativeWindow*`/`UIWindow*`, webview Engine 为系统 `WebView` child |
| fake | fake | 顶层或 attach (fake IWindow 同为 fake) | 契约测试 `CreateWebviewOn(CreateFakeWindow(...), ...)` 覆盖 |

### 3.5 依赖方向 (伦理正确)

```
window.base ← window.intf ← window.fake/factory/live/queue/gtx... (L2)
                ↑
                │ uses (L3→L2 允许)
                │
webview.base ← webview.intf ← webview.bridge/mime ← webview.fake/vfs ← webview.gtk/webview2/wk ← webview.factory ← 门面 (L3)
```
`window` 零 `uses webview.*` (INV-3 保持)。`webview` 的 `webview.gtk` 等后端改为 `uses window.factory, window.intf` + `webview.*.ffi/loader` (engine 专有), 删除 `uses webview.gtk.win/webview2.win`。

---

## 4. 迁移 — 受控跨模块 slice

### 4.1 分片 (每片一 commit, 可回滚, worktree 隔离)

| Slice | 内容 | Land paths | 验证 |
|-------|------|-----------|------|
| M1 | 本文落主线: 仅文档, 零代码, `window` 零变更 | `docs/plans/window-webview-composition-*.md` | `make hygiene` |
| M2 | `webview.base`: 零变更 (Parent 不进 base, 保持 base 纯类型) — 本片跳过, 合并至 M3 | — | — |
| M3 | `webview.factory`: 新增 `CreateWebviewOn/Builder.Parent`, `TWebviewImpl` 组合骨架 (`FWindow: IWindow` + `FEngine` 占位), `Fake` 先行 (attach 语义) + `Dispatcher/Window` 转发 | `core/src/nextpas.core.webview.factory.pas`, `core/src/nextpas.core.webview.fake.pas`, `core/src/nextpas.core.webview.intf.pas` | `test_webview_fake_window` 10→14 (新增 `Parent` 复用/attach/Close 不连带) |
| M4 | `webview.gtk`: 改 `TGtkWebview` 为 `FWindow: IWindow` 组合, `gtk_container_add(FWindow.NativeHandle, FWebView)` + `weResized/weScaleChanged` 转译, 删除 `webview.gtk.win` 的 shell 创建, 保留 `webview.gtk.ffi/loader` | `core/src/nextpas.core.webview.gtk.pas`, 删除 `core/src/nextpas.core.webview.gtk.win.pas` (或留 deprecated shim) | `test_webview_gtk_backend` Xvfb, `demo_webview` 手工 |
| M5 | `webview.webview2/wk`: 同 M4, `FWindow: IWindow` + child `HWND/WKWebView`, 删除 `webview.webview2.win.pas` 的 `RegisterClass/WndProc`, 改 `weResized→put_Bounds` 经 `FWindow.OnEvent` | `core/src/nextpas.core.webview.webview2.pas`, `core/src/nextpas.core.webview.wk.pas`, 删除 `*.win.pas` | `test_webview_webview2_post` wine, `test_webview_wk_loader` |
| M6 | `webview.factory` loop 统一: `WebviewRunLoop→WindowRunLoop`, `WebviewExitLoop→WindowExitLoop` inline shim, 删除 `GtkLiveWindowCount` 等四表轮询, 资产路由不变 | `core/src/nextpas.core.webview.factory.pas` | `make focused FOCUS=core/tests/nextpas.core.webview` 全绿, `bench_webview_bridge` 无回归 |
| M7 | 门面/文档/门禁: `webview.pas` re-export `IWindow` 方法 (继承已覆盖), `CONTRACT.md` 更新家族布局/依赖图/INV-4, `source_contracts` 更新 | `core/src/nextpas.core.webview.pas`, `core/docs/webview/*`, `tests/architecture/source_contracts/*` | `make hygiene` + `source_contracts` + `demo_webview` 双 demo |

### 4.2 风险与回滚
- **风险1**: `FWindow.NativeHandle` 在 `Show` 前为 nil (GTK realize 前) — 引擎 child 需在 `FWindow.Show` 后创建, 或监听 `weResized` 首次。回滚: M4 单片 revert。
- **风险2**: `fake` 的 `ParentWindow` 生命周期 (外部 owner vs webview 拥有) — 约定 `CreateWebviewOn` 不拥有父窗, `Close` 只毁引擎。回滚: M3 单片。
- **风险3**: `window` 的 `TWindowNativeHandle` 与 `webview` 的 `TWebviewNativeHandle` 类型别名重复 — M7 统一为 `window.base.TWindowNativeHandle` 单源。

---

## 5. 验证

- `make focused FOCUS=core/tests/nextpas.core.webview` 13 门 + `core/tests/nextpas.core.window` 13 门 双绿
- `make focused FOCUS=core/tests/nextpas.core.window/test_window_gtk_runtime` Xvfb + `test_webview_gtk_backend` Xvfb
- `wine` 下 `test_webview_webview2_post` (WebView2)
- `bench_webview_bridge` + `bench_window_dispatcher` 双基线无回归 (单泵 26ns 诚实)
- `make hygiene` + `source_contracts` (INV-3/INV-4 零违规)

---

## 6. 附: 清理证据 (2026-08-31)

- `git branch --merged main` 11 个 `landing/*window*` (M/M2-M6/window-1.0) 已删除
- `codex/core-window-input`, `codex/gpu-window`, `gpu-window` 已删除 (已合入)
- `core-window` worktree 重建到 `main:d1f54552e` (原 24dfa47cb 3.5-input 分叉已归档, 主线已 5.1)
- 保留 `codex/core-window` (active lane), `archive/gpu-window-recovery-20260722`, `recovery/gpu-window-wip-20260722` 归档
- 当前 `codex/core-window` HEAD `d1f54552e`, clean, `git worktree list` 仅 1 window worktree

---

## 7. 下一步 — 等你拍板

- 若认可本设计, 我即按 M1-M7 在 `codex/core-window` (或新建 `codex/window-webview-composition`) worktree 逐片落地, 每片 `focused` 证据 + `hygiene`, 不 raw merge。
- 若有调整 (如 `IWindow` 继承 vs 组合、是否保留 `WebviewRunLoop` shim、是否先做 `qt/wasm` 探针), 直接批注, 我按批注改本文档再开工。

