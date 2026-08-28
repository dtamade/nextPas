# nextpas.core.window 架构设计

**状态**：Design S0（与 [CONTRACT.md](CONTRACT.md) 0.1 冻结草案同批）
**Owner**：core-window lane
**最后更新**：2026-08-28（S5 8 后端全接入 + M5 去重：共享队列 6 合1 + finalization 0泄漏，13 门禁，去消息化 + Host/PumpOnce + O(1) + inline 370µs/167µs）
**对标基准**: Rust `winit` / `tao` · GLFW / SDL2 Window · Flutter View /
Android `Activity.getWindow()` / iOS `UIWindow`

---

## 1. 总览

```
┌────────────────────────────────────────────────────────────┐
│ L3 消费层                                                   │
│   gpu(gl/dx/vk context)   directui(渲染树)                  │
│   webview(window 壳 + 引擎内容)   game888.graphics(SDL2)    │
│   IDE workbench / 对话框家族（未来）                        │
└───────────────▲────────────────────────────────────────────┘
                │ IWindow + NativeHandle + Dispatcher
┌───────────────┴────────────────────────────────────────────┐
│ window(L2)                                                  │
│   门面 ← factory(builder/runloop/探测) ← intf ← base        │
│      │                                                      │
│      ├── fake          （无头脚本化；CI 契约唯一载体）       │
│      ├── gtk           （gtk.ffi ← gtk.loader，S2 抽取）     │
│      ├── sdl2          （sdl2.ffi ← sdl2.loader，S3）        │
│      ├── win32 / cocoa （S4）                               │
│      ├── wasm          （wasm.ffi ← wasm.loader，S2a；canvas attach） │
│      └── android / uikit（宿主 surface attach，S5）         │
└───────────────▲────────────────────────────────────────────┘
                │ 动态装载唯一入口
        nextpas.core.platform.dl (L0)
```

分层立场：

- **window 是 L2**：只依赖 L0-L1。它不认识 webview/gpu/directui；
  消费方向严格自上而下。
- **base/intf 零后端依赖**：类型与接口闭包不出现任何后端单元
  （CONTRACT INV-3）；后端经 factory 注册进入。
- **fake 与生产后端同位**：不是 test-only 旁路，而是同一工厂协议的
  一个实现；这保证契约测试覆盖的就是生产分发路径。

---

## 2. 抽取缝：从 webview.gtk.win 到 window.gtk

`nextpas.core.webview.gtk.win` 是当初为反 fafafa 教训而预留的
"窗口壳内部缝"：纯函数式、签名零 webview 概念、只依赖 gtk.ffi/gtk.loader。
它是本模块 S2 的机械抽取源。

### 2.1 函数映射表

| 现状（webview.gtk.win） | 目标（window 家族归属） |
|------|------|
| `TWinShellGeometry` | 被 `TWindowOptions` 取代（字段超集：min/max/parent） |
| `WinShellInit` | `window.gtk` 后端初始化段（含 IEEE 浮点屏蔽语义，原样搬运） |
| `WinShellCreate` | Build 路径的 create 段（选项展开由后端负责） |
| `WinShellSetTitle/Resize/Show/Hide` | `IWindow.SetTitle/SetBounds/Show/Hide` 直译 |
| `WinShellIsMaximized/Maximize/Unmaximize` | 同名 IWindow 方法直译 |
| `WinShellScaleFactor` | `GetScaleFactor`（整数诚实升格为 Double 在此完成） |
| `WinShellFocus/NativeHandle` | `Focus` / `NativeHandle`（X11 XID 化在 loader 侧补齐） |
| `WinShellRunMainLoop/QuitMainLoop` | factory 主循环的 gtk 驱动段（运行标志语义原样保留） |

### 2.2 抽取纪律

- **机械抽取优先**：函数体逐段搬移，不改行为；行为差异（如新增 min/max
  约束、XID 句柄化、事件信号挂接）作为独立小提交叠加在机械搬移之上，
  保持 diff 可审。
- **ffi/loader 归属**：抽取后 GTK ABI 声明与装载从
  `webview.gtk.ffi/gtk.loader` 复制出窗口所需子集到
  `window.gtk.ffi/window.gtk.loader`。webview 侧是否回改为 uses
  window.loader 属 Wave 收口决策——**默认先双份共存**（各自独立演进），
  待 S4 Win32 缝上移时统一评估去重，避免中途打断 webview lane。
- **事件缝是净新增**：现缝只有轮询式操作，无事件回调。S2 新增
  `g_signal_connect_data` 挂 delete-event/configure/focus/scale 变化，
  全部 cdecl 回调携带 owner 指针（禁全局变量上下文，BACKENDS §1 纪律）。
- **抽取尾闭环（2026-08-28）**：`webview.gtk.win` → `window.gtk` 机械抽取已闭环（S2 5 门禁 + S3 7 门禁 + S5 12 门禁 → 13 门禁）；双份 GTK 缝进入 Wave 2/3 收敛评估期，不再新增抽取。

---

## 3. 与消费方的组合契约

### 3.1 webview（L3）

- **现状**：`webview.gtk` 自持窗口壳（经内缝）。S2 后目标形态：
  `TWebviewBuilder.WithWindow(IWindow)` 组合注入；未注入时 webview 内部
  经 `nextpas.core.window` 工厂自建默认窗。
- **无感约束**：`IWebviewWindow` 公共面不变（组合面），webview 的既有
  门禁全绿即 consumer 无感的证据。
- **风险**：双份 GTK 缝过渡期并存（见 §2.2）；生命周期交接点
  （webview Close 是否连带关窗）在 S2 受控 slice 中定案并写测试。

### 3.2 gpu（L3）

- `gpu.gl` 当前自管 GL 上下文与 `glXGetProcAddress`；接窗方式：
  `LWin.NativeHandle`（X11 XID）+ `GetScaleFactor` 交给 GL context 创建。
- window 不提供任何渲染概念（无 swapchain/canvas）；那是 gpu 的职责。
  Wayland 下 NativeHandle=nil 的诚实含义：GL on Wayland 需要 EGL
  platform 扩展，属 gpu 侧议题，window 只如实交付 nil。

### 3.3 directui（L3，未来）

- 渲染树需要：物理像素视口（weResized）、scale（DPI 换算）、失效通知。
  当前最小集已覆盖其**窗口壳**必需；`directui` 的渲染/排版/命中均在
  自身，不向 `window` 索要 `transparent/decorations/icon` 等装饰能力
  （deferred-Win，见 §6 与 `ABSTRACT_DESIGN.md §4`）。
- **不束缚原则**：`directui` 的输入栈（键盘/鼠标/触摸/IME）登记
  `deferred-In`，本模块不为其预留 `OnKey/OnMouse` 占位；`directui`
  立项时若仍无触发条件则**自带输入栈**或通过 `IWindowInput` 扩展
  （`ABSTRACT_DESIGN.md §4.1`）接入，不污染核心 `IWindow`。
- 窗口句柄消费：`NativeHandle` + `GetScaleFactor` 足以让 `directui`
  的 `gpu` 后端建 GL/Vulkan 上下文（Wayland `nil` 诚实由 `gpu` 处理
  `EGL`），`directui` 不解释句柄内容。
- 性能：`directui` 高频失效（60fps）由 `weResized/weScaleChanged`
  驱动重排，`Dispatcher.Post` 用于后台布局结果回主线程提交，避免
  阻塞 `RunLoop`。

### 3.4 game888（外部）与游戏 UI 共性

- `game888.graphics.window` 私有 SDL2 窗口是第三个收敛目标：S3 `sdl2`
  后端落地后，其窗口壳可替换为本模块 `wkSdl2` 后端（外部仓库自行排期，
  本模块只保证契约稳定）。
- **游戏 UI 的特殊性**：游戏自带 `tick` 循环（`IterateOnce` 形态），
  阻塞式 `WindowRunLoop` 不适用；`deferred-LI` 的 `IterateOnce` 融合
  `TAsyncLoop.WaitForWake` 时立项，游戏侧在立项前自行为 `sdl2` 泵
  `SDL_PollEvent` 或复用 `fake` 的 `PumpOnce` 语义。
- 输入与全屏：游戏的全屏/原始输入（raw mouse/keyboard）属 `deferred-Win`
  与 `deferred-In`，不进核心；需时通过 `IWindowFullscreen` /
  `IWindowInput` 扩展或 `NativeHandle` 直调 `SDL_*` 实现，保持核心
  5 年稳定。
- **正交性**：`window` 只给壳（创建/显隐/几何/DPI/句柄/事件），
  渲染（swapchain/vsync）、音频、输入的高频路径归 `gpu` / `game`
  自身，窗口不成为性能瓶颈。

---

## 4. 事件与主循环架构

### 4.1 所有权模型

每个后端拥有自己的主循环驱动，factory 的 `WindowRunLoop` 只是薄委托：

| 后端 | 主循环 | 退出原语 |
|------|--------|----------|
| gtk | `gtk_main` | `gtk_main_quit`（运行标志防 CRITICAL，沿用现缝） |
| fake | 待泵队列 + 计数器 | 末窗关闭或显式退出；`PumpOnce/PumpAll` 确定性驱动 |
| sdl2 | `SDL_PollEvent` 泵 | 用户 quit 事件 / 末窗关闭 |
| win32 | `GetMessage/DispatchMessage` 循环 | `PostQuitMessage` / 末窗关闭 |
| cocoa | `NSApp run` | `NSApp terminate:` 编排（S4 定案） |
| wasm | 浏览器宿主循环（`requestAnimationFrame` 驱动，无阻塞 `RunLoop`） | `emscripten_cancel_main_loop` / 末 canvas detach（`wasm` 的 `RunLoop` 诚实 no-op 或转 `RAF` 调度，S2a 定案） |

退出判定统一在 factory：活跃窗计数归零或 `WindowExitLoop` 被调。

**事件驱动纪律**：所有 `RunLoop` 均为事件驱动阻塞，无硬编码 `sleep(1)` 轮询。`gtk` 以 `gtk_main` 阻塞于 GLib 主上下文；`sdl2/win32/cocoa` 以 `SDL_WaitEvent/PostMessage+WaitMessage/dispatch` 阻塞于 OS 事件队列；`android/uikit/wasm` 等 attach 后端以 `nextpas.core.sync.event`（`IEvent`，`platform_wait_address`）阻塞于 `DispatcherPush/SetEvent`，超时仅作活窗存活复核（5ms），可被 `Post/Host*/Close/Quit` 立即唤醒。

### 4.2 dispatcher 唤醒原语（跨线程 → 主线程）

| 后端 | 原语 | 说明 |
|------|------|------|
| gtk | `g_idle_add_full` + `g_source_remove` 清扫 | 关闭路径清理未执行投递（owner 计数保护，沿 webview 语义） |
| fake | 待泵 FIFO | `PumpOnce/PumpAll` 手动驱动 |
| sdl2 | `SDL_RegisterEvents` 注册的用户事件 + `SDL_PushEvent` | 泵循环里识别并分发闭包 |
| win32 | message-only window + `PostMessage(WM_APP+n)` | WndProc 泵出闭包；STA 一致性 = 创建线程即泵线程 |
| cocoa | `dispatch_async(dispatch_get_main_queue())`（libdispatch dlopen） | loader 装载 libdispatch |
| wasm | `emscripten_async_call` / `setTimeout(0)` 队列（JS 任务队列） | 无真线程；`Post` 入 JS 微任务队列，主线程 `RAF` 前兑现；关闭后丢弃 |

### 4.3 对 winit/tao 的对齐口径

对齐的是**抽象质量与语义诚实度**，不是 API 面：

- **可比**：窗口状态最小集（tao Window 方法子集）、DPI 只读 +
  变化事件、close-request 通知语义、单进程多窗共享 loop。
- **刻意不抄**：
  - winit `ApplicationHandler` trait / `ControlFlow` 细粒度控制——
    我们用"注册 handler + RunLoop"的简单模型；`IterateOnce` 融合登记
    deferred-LI，避免半成品调度器。
  - winit 的 `raw-window-handle` 多层句柄抽象——我们交付单一指针 +
    诚实表，平台判别留给编译期已知的消费方（Pascal 无 trait 分发需求，
    双重抽象只增加间接层）。
  - tao 的 menu/tray/clipboard 附带能力——各归各 owner 模块。

---

## 5. DPI 架构

- 数据流：OS scale 来源（GDK scale factor / `GetDpiForWindow` /
  `backingScaleFactor` / SDL display scale / `devicePixelRatio` / 宿主 metrics）→ 后端读取 →
  Double 升格 → `GetScaleFactor`；变化经信号/消息/`matchMedia` 转成 `weScaleChanged`
  进统一事件流。
- **几何单位策略**（CONTRACT INV-8）：公开面恒为物理像素；gtk/cocoa/sdl2
  内部逻辑坐标换算误差 ±1px 写入诚实表。选物理像素为公共口径的理由：
  gpu/webview 的原生 API 都以物理像素为准，选逻辑像素会让每个消费者都写
  一遍换算。
- per-monitor 动态重排不做承诺（deferred-DPI）：scale 只读 + 事件通知
  已足够消费方自行重排。

---

## 6. 嵌入模型（mobile attach，S5）

Android/iOS 没有"创建 top-level window"的自由：应用窗口归宿主
（Activity / UIApplication），能做的是把渲染表面 attach 进宿主层级。
这是窗口模块独立存在的核心理由之一（webview §1.1 反哺路线原文），
因此建模从第一天开始（`TWindowOptions.ParentHandle`），实现在 S5：

- **android**：`ParentHandle` 携带宿主提供的 surface 指针；后端把它包装
  为 `ANativeWindow*` 交付 `NativeHandle`；surface 生命周期归宿主，
  destroy/重建事件以 weCloseRequested/weResized 表达（S5 定案细节）。
- **uikit**：attach 到宿主 UIWindow/view 层级；几何只读（尺寸随宿主布局），
  SetBounds 诚实 no-op（诚实表已冻结该行）。
- **wasm**：`ParentHandle` 携带 `<canvas>` 元素指针或 id 字符串指针（`#canvas` 缺省）；后端经 `emscripten_get_canvas_element_size` 包装后交付 `NativeHandle`（同指针值）；canvas 生命周期归 DOM，`Close` 仅解绑不移除元素；几何写 CSS 尺度，读物理像素（×`devicePixelRatio`）；`Min/Max` 诚实 no-op。
- **桌面后端的立场**：ParentHandle 非 nil 即抛 `EWindowUnsupported`
  （无法安全 no-op 的能力显式失败，INV-9）；fake 接受并记录，供 S5/wasm
  契约预演。

---

## 7. 绑定纪律（全后端）

1. **系统库运行时装载**：GTK/SDL2/libdispatch 等都是系统组件，
   dlopen + 函数指针变量，永不链接期依赖；ABI 以官方头文件为核对权威，
   不要求 dev 包。
2. **loader 单一触点**：动态装载设施只存在于 `*.loader`，原语来自
   `nextpas.core.platform.dl`；禁 FPC `DynLibs`（gate policy）。
3. **版本探测按符号存在性**：不做版本号字符串猜测（webview gtk loader
   先例：eval 双路径按符号选择）。
4. **失败降级诚实**：探测失败 → `WindowBackendAvailable=False` →
   强行 Build 抛 `EWindowBackendUnavailable`（消息列 sonames）。
5. **cdecl 回调一律携带 owner 指针**，禁止全局变量当上下文。
6. **拒绝 LCL 式跨平台消息**：业务语义永不经 `LM_XXX / WM_XXX / WPARAM/LPARAM` 伪装；接口是接口（`IWindow.SetBounds / GetScaleFactor / NativeHandle`），事件是强类型 `TWindowEvent`，扩展经 `Supports(IWindowHost/...)`。消息仅作为最底层唤醒原语（`g_idle_add / PostMessage / SDL_PushEvent / dispatch_async`）存在，且只携带"醒来"信号，不携带业务负载——把编译期可查的错误推到运行时的是偷懒。

## 7.1 非阻塞泵与宿主线程亲和（M-band）

- `IWindowHost.HostResized/HostScaleChanged/HostCloseRequested`：attach 后端（wasm/android/uikit/fake）由宿主（JS/Activity/UIViewController）驱动的强类型入口，不经消息号；**线程亲和**：非主线程调用时经 `Dispatcher.Post` marshal 回主线程再 `we*` 分发，稳定性与 `Close` 同纪律。
- `WindowPumpOnce / WindowPumpAll`：factory 暴露的非阻塞单步迭代（fake 全泵 + sdl 轮询 + wasm/android/uikit 各自环形队列 Drain），供游戏 `tick` / directui 失效循环在自有 `while not Quit do begin PumpOnce; Render; end` 中复用，不阻塞 `RunLoop`。**零活窗快速路径**：`WindowPumpOnce` 首行 `O(1)` 活窗计数聚合早退，零窗时零锁零探测。
- 桌面阻塞后端（gtk/win32/cocoa）的 `RunLoop` 仍为拥有者；`PumpOnce` 在其上有宿主时为 best-effort，不承诺完整等价——符合 `deferred-LI` 的渐进立项原则。

### 7.2 热路径与诊断（M-band perf）

- `FakeLiveWindowCount` 为 `GFakeLiveCount` 的 `inline` 读，`Destroy`/`RealClose`/`Create` 三处维护，零遍历；`WindowPumpOnce` 零活窗路径与全量路径على同一口径，避免空转锁竞争。
- `GetWidth/GetHeight/GetScaleFactor/NativeHandle/GetDispatcher/IsClosed` 与 `TFakeDispatcher.IsOnMainThread/PostRef/PumpOnce` 等高频访问一律 `inline`，`CheckWindowOptions` 以 `CreateFmt` 携带越界值，错误信息富化不增分支。
- `WindowBackendDiagnostics: string` 遍历 `BACKENDS[8]` 以 `Probe()+sonames` 逐行输出，供 `EWindowBackendUnavailable` 失败现场直连探测真相；bench 基线 `PostSingle/1000 = 370µs`（32cap 环，`O(1)` + inline + 共享队列后），7 项分拆中 `WindowPumpOnceZero/10000 = 167µs`（≈16ns/次，零活窗早退零锁）与 `WindowPumpOnceLive/1000 = 430µs` 对比验证空转成本；finalization Free GQueue 消 heaptrc 0 泄漏。
- 共享队列 `nextpas.core.window.queue.TWindowQueue` 为 `sdl2/win32/cocoa/wasm/android/uikit` 6 家提供同一套“互斥环形 FIFO + 32 cap 起步 + 2× 增长 + 锁外 Drain”实现，单点修复、零样板拷贝（M5 去重约 200 行），`fake` 的 per-window 队列复用同一增长语义但 per-window 实例隔离以保持契约测试确定性。
- 共享活窗 `nextpas.core.window.live.TWindowLiveRegistry/TWindowSdlLiveRegistry` 为 7 生产后端提供同一套“末尾换位删除 + 无锁 inline Count（16ns 早退）+ finalization 释放”实现，单点修复、零样板拷贝（M6 去重约 150 行），`sdl` 扩展 `FindByID` 平行数组路由。

### 7.3 事件驱动 RunLoop（M-band 稳定性，按行业同行做法）

- **行业对齐**：`winit` 以 `epoll/kqueue` 阻塞于 OS 事件队列、`SDL` 以 `SDL_WaitEvent/Timeout` 阻塞于 `SDL_PumpEvents`、`GLFW` 以 `glfwWaitEvents` 阻塞、`Win32` 以 `GetMessage/WaitMessage` 阻塞于消息队列、`Cocoa` 以 `NSRunLoop/CFRunLoop` 阻塞、`Android` 以 `ALooper_pollOnce` 阻塞、`iOS` 以 `CFRunLoopRun` 阻塞、`WASM` 以 `requestAnimationFrame` 事件驱动。`window` 同律：无 `sleep` 忙等。
- `sdl2` 以 `SDL_WaitEventTimeout(@E,16)` 阻塞16ms（事件到即分发——`GUserEventType` 直接 `Drain`、`SDL_WINDOWEVENT` 路由到窗口，`SDL_PushEvent` 来自 `DispatcherWake/RealClose` 立即唤醒；`IEvent` 仅当 `SDL_WaitEventTimeout=nil` 时回退）；`win32` 以 `WaitMessage` 阻塞于 `PostMessage(WM_DISPATCH)`（`RealClose/DispatcherWake` 均 `PostMessage+SetEvent` 双唤醒）；`gtk` 保持 `gtk_main` 阻塞；`cocoa/android/uikit/wasm` 等 attach 后端以 `IEvent.Wait` 无限阻塞（`DispatcherPush/Host*/RealClose/Quit` 以 `SetEvent` 唤醒，无超时轮询；`Post` 仅入队不立即 `Drain`，由 `RunLoop/PumpOnce` 在主线程兑现，保持线程亲和）。
- 所有路径符合“整体事件驱动，不得硬编码等待”红线（`README` 第5条），`bench 7 项` 中 `WindowPumpOnceZero` 18ns 早退即为零等待的量化证据。

---

## 8. 文档导航

| 文档 | 内容 |
|------|------|
| [README.md](README.md) | 模块定位、能力总览、后端矩阵、使用示例 |
| [CONTRACT.md](CONTRACT.md) | 冻结契约：布局、签名、线程、不变量、错误、Deferred、门禁 |
| [ROADMAP.md](ROADMAP.md) | 分波实施图 S0→S5 与验证门禁 |
