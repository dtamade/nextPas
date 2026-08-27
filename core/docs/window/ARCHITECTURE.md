# nextpas.core.window 架构设计

**状态**：Design S0（与 [CONTRACT.md](CONTRACT.md) 0.1 冻结草案同批）
**Owner**：core-window lane
**最后更新**：2026-08-26
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
  当前最小集已覆盖；native input 事件（键盘/鼠标）登记 deferred-In，
  directui 立项时若仍无触发条件则自带输入栈。

### 3.4 game888（外部）

- `game888.graphics.window` 私有 SDL2 窗口是第三个收敛目标：S3 sdl2
  后端落地后，其窗口壳可替换为本模块 `wkSdl2` 后端（外部仓库自行排期，
  本模块只保证契约稳定）。

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

退出判定统一在 factory：活跃窗计数归零或 `WindowExitLoop` 被调。

### 4.2 dispatcher 唤醒原语（跨线程 → 主线程）

| 后端 | 原语 | 说明 |
|------|------|------|
| gtk | `g_idle_add_full` + `g_source_remove` 清扫 | 关闭路径清理未执行投递（owner 计数保护，沿 webview 语义） |
| fake | 待泵 FIFO | `PumpOnce/PumpAll` 手动驱动 |
| sdl2 | `SDL_RegisterEvents` 注册的用户事件 + `SDL_PushEvent` | 泵循环里识别并分发闭包 |
| win32 | message-only window + `PostMessage(WM_APP+n)` | WndProc 泵出闭包；STA 一致性 = 创建线程即泵线程 |
| cocoa | `dispatch_async(dispatch_get_main_queue())`（libdispatch dlopen） | loader 装载 libdispatch |

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
  `backingScaleFactor` / SDL display scale / 宿主 metrics）→ 后端读取 →
  Double 升格 → `GetScaleFactor`；变化经信号/消息转成 `weScaleChanged`
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
- **桌面后端的立场**：ParentHandle 非 nil 即抛 `EWindowUnsupported`
  （无法安全 no-op 的能力显式失败，INV-9）；fake 接受并记录，供 S5
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

---

## 8. 文档导航

| 文档 | 内容 |
|------|------|
| [README.md](README.md) | 模块定位、能力总览、后端矩阵、使用示例 |
| [CONTRACT.md](CONTRACT.md) | 冻结契约：布局、签名、线程、不变量、错误、Deferred、门禁 |
| [ROADMAP.md](ROADMAP.md) | 分波实施图 S0→S5 与验证门禁 |
