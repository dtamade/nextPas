# nextpas.core.window 代码契约（冻结草案）

**模块路径**：`core/src/nextpas.core.window*.pas`（含 family shards `window.live/queue/hash/dispatcher.base/live.arena` + `window.gtk.dispatcher/window` + 8 后端；已落地四件套 `window.loop/chrome/input/view/dialog/dpi/event/constraints` 各 `base←intf←impl←门面` 独立 Owner，见 §1/§7.1）
**层级**：L2 家族（依赖 L0-L1：`base/errors/atomic/sync/bytes.ops` + `platform.dl` 缝 + 单向 L2 `gtk2/3/4/qt5pas/qt`，守 `L0→L1→L2` 单向禁同层循环，被 L3 `gpu/directui/webview` 与外部 `game888` 复用；**四件套** `base←intf←impl←门面` Owner 边界清晰：`base` 纯数据类型零行为零 L1 依赖，`intf` 零后端，`impl` Owner 单源 `bytes.ops 0→32→2×` inline 零拷贝 O(1)均摊守 L0-L3，`门面` 仅 re-export 禁 family shard，经 `TWindowFamilyToken strict private sentinel + inline IsValid` 三重锁定 CONTRACT §1 + registry `Public facade=no` + source-contract；**9 INV 业务域** INV-10~18 已按 Owner 四件套闭环（8 物理模块 + `dialog` 双INV 聚合），单源 `bytes.ops` inline 零拷贝 heaptrc 0 暂无可抽新模块候选，业务缺口反哺 `bytes.ops/platform.dl` Owner）
**Owner**：core-window lane（`window` 主族 Owner；family shards `live/queue/hash/dispatcher.base/live.arena` Owner `window.impl`，已落地四件套各归 `window.loop/chrome/input/view/dialog/dpi/event/constraints` Owner，守四件套与 L0-L3）
**最后更新**：2026-09-02（S5 8 后端全量 + F1-F4 单源收口 + DPI/Event 四件套抽离，13 门禁，去消息化 + Host/PumpOnce + O(1) inline 零拷贝，registry ci-matrix 诚实）
**版本**：1.0（已冻结：单元布局/类型/接口签名/线程模型/INV-1~INV-9/诚实表/错误族/Deferred 与门禁；registry truth `ci-matrix`（Linux 13门 runtime + Win/mac compile-only 残差诚实，见 FINAL_ROADMAP F3/CI_MATRIX）；`DefaultWindowKind` 探测顺序单源于 factory `BACKENDS[8]` `win32>cocoa>android>uikit>wasm>gtk>sdl2>fake`）
**对标基准**: Rust `winit` + `tao`（窗口壳最小集）/ GLFW / SDL2 Window /
Flutter View / Android `Activity.getWindow()` / iOS `UIWindow`

---

## 1. 家族布局

| 单元 | 层 | 职责 | 波次 |
|------|----|------|------|
| `nextpas.core.window.base` | 类型根 | kinds/options/event/句柄别名/错误族（含 `EWindowError` 族）+ `DefaultWindowOptions` 纯构造（base 仅纯数据类型，零行为、零 L1 依赖，只依赖 `base/errors`，守四件套与 L0-L3） | S1 |
| `nextpas.core.window.impl` | 实现 | 校验与容量策略（`CheckWindowOptions/Constraints/ValidateWindowMinMax` 薄分支；`WindowGrowCapacity` 单源 `bytes.ops`）；仅家族共享设施（`live/queue/hash/dispatcher`）复用本单元，业务域直连 `bytes.ops` Owner（见依赖方向） | S1 |
| `nextpas.core.window.intf` | 接口 | `IWindow` / `IWindowDispatcher` / 回调命名类型全集 | S1 |
| `nextpas.core.window.fake` | 测试后端 | 无头脚本化后端：注入事件、手动泵 dispatcher，契约测试唯一载体 | S1 |
| `nextpas.core.window.factory` | 工厂 | `TWindowBuilder` + `CreateWindowOf` 校验（`CheckWindowOptions` 单源 `window.impl→bytes.ops`）+ 薄委托 `registry/probe`（factory 不持探测真相，详见 registry/probe 行） | S1 |
| `nextpas.core.window.registry` | L2 内部（family 聚合） | 动态注册表 `TBackendDesc[11]`：排序单源 `CBackendOrder[11] win32>cocoa>android>uikit>wasm>gtk4>gtk3>gtk2>qt>sdl2>fake` + double-checked+mutex 线程安全 + 聚合 `RunLoop/ExitLoop/PumpOnce/PumpAll/LiveGtkSmart/CreateGtkSmart/Diagnostics`（gtk4>3>2 智能回退单源），`factory` 薄委托单源，`IsDesktopKind` inline 零拷贝 O(1)，`bytes.ops 0→32→2×` 单源 O(1)均摊，`atomic_load/fetch_add` 16ns 快路径，heaptrc 0 释放，禁门面 re-export | S1 |
| `nextpas.core.window.probe` | L2 内部（探测单源） | `Probe*` 12 项：`ProbeGtk4/3/2/ProbeGtk(聚合)/ProbeQt5Pas/ProbeQt/ProbeSdl2/ProbeWin32/ProbeCocoa/ProbeWasm/ProbeAndroid/ProbeUIKit/ProbeFake`（经 `*.loader TryLoad*` 单源 dlopen，进程幂等零堆分配，冷路径非 inline 守 I-Cache，`gtk` 聚合与 registry 同源） | S1 |
| `nextpas.core.window` | 门面 | 聚合 re-export 全部公共 API（禁 re-export `live/queue/hash/dispatcher.base/gtk.dispatcher/window` 家族内 shard 与 `registry/probe` 内部单元） | S1 |
| `nextpas.core.gtk3/4/2.base` / `.ffi` / `.loader` | L2 独立家族 | GTK 2/3/4 ABI+动态装载（dlopen 多 soname，BindOpt，可选符号）；window 仅为消费者（伦理扭转，单向依赖） | S2-扭转 |
| `nextpas.core.qt5pas/qt` | L2 独立家族 | Qt 绑定（qt5pas 复用 libQt5Pas.so；qt 为自包装 libnextpas-qt.so 多版本 shim，deferred） | qt |
| `nextpas.core.window.gtk3/4/2` | 后端适配 | Linux GTK 2/3/4 薄适配（显式依赖 `window.gtk.impl` 共享单元，族显式 `WindowGtk4IsAvailable` 等；`window.gtk` 为 deprecated shim→gtk3；`gtk3` 另暴露 `WindowGtkRaw*` 12 项低阶壳供 L3 webview 单源复用） | S2+扭转+F4 |
| `nextpas.core.window.gtk.impl` | 共享枢纽 | GTK 共享显式枢纽（原 860 行三职责已分治，保留 `TGtkOps/TGtkContext`/活窗聚合/轻量转发，三者均 <600 行；显式 uses：`window.base/intf/impl/live/queue + sync/math/text.ansi/platform.thread + bytes.ops 单源 0→32→2×`，零 include；INV-3/INV-5 可静态扫描） | polish |
| `nextpas.core.window.gtk.dispatcher` | 家族内共享 | Dispatcher 单源 `g_idle_add_full`+环形队列 per-instance（`TWindowGtkDispatcher`，复用 `TWindowQueue 32cap 2×` 与 `TWindowDispatcherBase` DoWake 虚派单源，Burst N→1，Clear 逐条 nil） | polish+分治 |
| `nextpas.core.window.gtk.window` | 家族内共享 | 窗口形态+7 信号回调单源（`TWindowGtk`+`CbDelete/Configure/Focus/Scale/Destroy/State`，标题零拷贝 `StrToPAnsiView`，变体直存 Method/Proc inline，幂等 Close/Destroy） | polish+分治 |
| `nextpas.core.window.sdl2.ffi/.loader/.sdl2` | 后端 | SDL2 `SDL_Window`，game888 未来底座 | S3 |
| `nextpas.core.window.live` | 家族内共享设施 | 活窗注册表 `TWindowLiveRegistry`/`TWindowSdlLiveRegistry` 末尾换位删除 O(1) inline 零拷贝 + 开放寻址哈希 O(1) `FindByID`/`Unregister` 单源 `bytes.ops WindowGrowCapacity 0→32→2×` 负载≤0.5 16ns 零锁早退 (owner `window.impl`, `TWindowFamilyToken` 编译期隔离, 不经门面) | M6 修复 + 分治 |
| `nextpas.core.window.live.arena` | 家族内共享子设施 | 活窗批量 arena 子 shard `TLiveBuildArena`（8 数组聚合 via `LiveArenaEnsureBatch` 单源 `bytes.ops` inline 零拷贝 O(1)，池化与阈值收缩单源 `bytes.ops` 通用抽象 `ARENA_POOL_SIZE/MAX_RETRIES/AcquireSlot/RecycleSlot/Finalize` 容量与释放托管不丢；仅 `window.live` uses，不经门面，`window.impl` Token 隔离，守四件套子 shard，详见 `BENCH.md` 与 `window.live.arena` 单元注释） | 匠心修复 |
| `nextpas.core.window.queue` | 家族内共享设施 | 环形队列 `TWindowQueue`：互斥环形 FIFO 32cap 起步 2×增长 + 锁外 `Drain` + `DroppedCount` 原子背压双轨可观测（`DroppedCapCount` RingMax 16384 限幅 `Warn` + `DroppedOomCount` 堆分配失败 `Error` 双轨细分，`DroppedCount` 为双轨之和兼容单轨观测，`Enqueue/TryEnqueue` 均返 `False` + 分级日志上游显式查双轨，零二次堆抖动 via `CowDiscard` 托管释放不丢），供 7 后端复用，家族内共享（owner: `window.impl`，编译期需 `TWindowFamilyToken`（`window.impl` inline 零拷贝 IsValid，strict private sentinel）方可构造，不经公共门面 re-export，仅后端 uses，边界显式；registry `window.queue` 行 Public facade=no + source-contract；`TWindowDispatcherBase` 已提纯（`window.dispatcher.base`），见 ARCHITECTURE §4.2 / FINAL_ROADMAP F1；已分治 `base/ring/backpressure` 三子 shard 各 <150 行，门面 ~780 行 <800 软阈值（环形FIFO+COW重试+背压双轨分治复用 `bytes.ops` 单源 inline 零拷贝，I-Cache 优雅）；BENCH 门禁可观测，inline 原子 O(1) 零拷贝） | M5 + 编译期 owner 隔离（owner收口至window.impl）+ 匠心修复背压双轨可观测（OOM vs RingMax 分级 Warn/Error）+ 匠心分治（800 软阈值内聚→分治，`queue.base/ring/backpressure` 三子 shard） |
| `nextpas.core.window.queue.base` | 家族内共享子设施 | 队列基类纯数据类型 `TWindowWorkKind/TWindowWorkItem/TWindowCowCtx`（仅 `queue` uses，不经门面，`window.impl` Token 间接隔离，守 `base←impl`，`bytes.ops` 单源） | 匠心分治 |
| `nextpas.core.window.queue.ring` | 家族内共享子设施 | 队列环形 Arena `TQueueRingArena` 64 槽 lock-free LIFO `QueueRingArenaAcquire/Recycle` via `bytes.ops` `ArenaPoolAcquireSlot/RecycleSlot/Finalize` 单源池化通用抽象，阈值收缩 8192，仅 `queue` uses，不经门面，`window.impl` Token 间接隔离，守 `base←impl`，inline 零拷贝 O(1) Burst64 | 匠心分治 |
| `nextpas.core.window.queue.backpressure` | 家族内共享子设施 | 队列背压策略 `TWindowQueueBackpressure` 双轨 `Cap/Oom` 原子计数 `IncCap/IncOom/Total/CapCount/OomCount` inline 零拷贝 O(1) 可复用策略，单源 `bytes.ops` 阈值 `WindowQueueRingMax` 16384，仅 `queue` uses，不经门面，`window.impl` Token 间接隔离，守 `base←impl`，零二次堆抖动 via `CowDiscard` 托管不丢 | 匠心分治 |
| `nextpas.core.window.hash` | 家族内共享设施 | 哈希助手 `WindowHash*`：开放寻址线性探测双哈希（Pointer/U32），负载≤0.5 阈值 0.5 Via `WindowGrowCapacity` 0→32→2× 幂二单源（bytes.ops via window.impl）掩码探查，删除回填集群重插，供 `window.live` 复用，家族内共享（owner: `window.impl`，编译期需 `TWindowFamilyToken`（`window.impl` inline 零拷贝 IsValid，strict private sentinel）方可调用，不经公共门面 re-export，仅 `window.live` uses，边界四重锁定（token 编译期 + registry + source-contract + bytes.ops 单源旁路门禁禁直调 Bytes*），重建批量>1k 计数排序桶序 O(n+cap) 单次散列+单次探查均摊 O(1) 控 16k 集群退化，小表直插零额外分配，突发池化 5 桶经 bytes.ops THashRebuildArena 32 槽 lock-free LIFO 共享池抽象（与 LiveArena 同源 ARENA_POOL_SIZE=BYTES_BUILDER_MIN_GROW shr1=32 0→32→2× via HashRebuildArenaAcquire/Recycle + ArenaPoolAcquireSlot/RecycleSlot/Finalize 单源池化通用抽象 inline 零拷贝，阈值收缩 8192 防突发后常驻堆，finalization 托管释放不丢 via ArenaPoolFinalize 单源，线程池零泄漏），inline 零拷贝） | 匠心修复：hash 5 桶 threadvar 容量只增不缩已收口至 THashRebuildArena 共享池 + 阈值收缩 +ArenaPoolFinalize 单源，池分立已收口至 bytes.ops 单源池化通用抽象 ARENA_POOL_SIZE/MAX_RETRIES/AcquireSlot/RecycleSlot/Finalize，与 LiveArena 同源 32 槽 + 0→32→2× + finalization 零泄漏零分散 |
| `nextpas.core.window.dispatcher.base` | 家族内共享设施 | Dispatcher 基类 `TWindowDispatcherBase`：owner 线程 + `Post` 三重载各 inline 零分支直达零拷贝直存变体 `wwkRef/wwkMethod/wwkProc` 单源 `bytes.ops 0→32→2×`（热路径零 case 避调度，冷路径 `EnsureQueue` 单外联守 I-Cache 防热路径复制膨胀）+ `DoWake` 虚派隔离平台唤醒（`SDL_PushEvent/PostMessage/dispatch_async/SetEvent`），供 7 后端复用（各后端仍持独立 `GQueue/GWaitEvent` 全局隔离，ROI≈2.2 120行收口至55行）；家族内共享（owner: `window.impl`，编译期需 `TWindowFamilyToken`（`window.impl` inline 零拷贝 IsValid，strict private sentinel）显式 `RequireWindowFamilyToken` 校验方可构造，`Post` 三重载零分支直达零重复，不经公共门面 re-export，仅后端 uses） | M6 去重：inline 零拷贝 + 虚派唤醒 + 单源 bytes.ops（owner 收口至 window.impl，显式 token + 热路径 inline 直存 / 冷路径 EnsureQueue 单外联守 I-Cache 零额外分支省 I-Cache） |
| `nextpas.core.window.win32.*` | 后端 | `CreateWindowEx` + `WM_*` | S4 |
| `nextpas.core.window.cocoa.*` | 后端 | `NSWindow` / `NSView` | S4 |
| `nextpas.core.window.wasm.ffi/.loader/.wasm` | 后端 | WASM `<canvas>` attach（`devicePixelRatio` + CSS/物理双口径） | S2a |
| `nextpas.core.window.android.*` / `.uikit.*` | 后端 | 宿主 surface attach（`ParentHandle` 非 nil 路径） | S5 |
| `nextpas.core.window.loop.base/intf/impl` + `window.loop` 门面 | L2 | 事件循环 `IWindowLoop/TWindowLoopOptions`（Owner 四件套；`Tick/RequestExit` 幂等，与 `async` L1 协作） | INV-10 已落地四件套，见 `core/docs/window.loop/CONTRACT.md` |
| `nextpas.core.window.chrome.base/intf/impl` + `window.chrome` 门面 | L2 | 高级视觉 `TWindowChromeOptions/IWindowChrome`（Owner 四件套；`Decorated/Transparent/Shadow/Opacity` 诚实表） | INV-12 已落地四件套，见 `core/docs/window.chrome/CONTRACT.md` |
| `nextpas.core.window.input.base/intf/impl` + `window.input` 门面 | L2 | 输入栈 `TWindowInputKind/Event/Options/IWindowInput`（Owner 四件套；键鼠触摸/IME 细分） | INV-14 已落地四件套，见 `core/docs/window.input/CONTRACT.md` |
| `nextpas.core.window.view.base/intf/impl` + `window.view` 门面 | L2 | 多视图 `TWindowViewId/Options/IWindowView/IWindowViewHost`（Owner 四件套） | INV-16 已落地四件套，见 `core/docs/window.view/CONTRACT.md` |
| `nextpas.core.dialog.base/intf/impl` + `dialog` 门面 | L3 shim | 对话框 `TWindowDialogKind/Options/IWindowDialog`（Owner 四件套；双 INV-11/17 聚合 → `dialog` L3） | INV-11/17 已落地四件套，见 `core/docs/dialog/CONTRACT.md` |
| `nextpas.core.window.dpi.base/intf/impl` + `window.dpi` 门面 | L2 | DPI 监听 `TWindowDpiInfo/Options/IWindowDpiSubscription`（Owner 四件套；per-monitor 可撤销） | INV-15 已落地四件套，见 `core/docs/window.dpi/CONTRACT.md` |
| `nextpas.core.window.event.base/intf/impl` + `window.event` 门面 | L2 | 事件订阅 `TWindowEventHandle/IWindowEventBus`（Owner 四件套；可撤销 Handle 非覆盖） | INV-18 已落地四件套，见 `core/docs/window.event/CONTRACT.md` |
| `nextpas.core.window.constraints.base/intf/impl` + `window.constraints` 门面 | L2 | 运行期约束 `TWindowConstraints/IWindowConstraints`（Owner 四件套；`SetMin/Max` 薄分支校验） | INV-13 已落地四件套，见 `core/docs/window.constraints/CONTRACT.md` |

### 依赖方向（伦理扭转：gtk/qt独立L2，window单向消费；2026-09 gtk 分治无循环；S5 薄委托：factory→registry/probe）

```
gtk3/4/2.base←ffi←loader / qt base←ffi←loader (独立 L2，不知window)
base←intf←fake─┐  probe→registry→factory←门面─┘ one-way (factory薄委托单源，redis→net, ProbeGtk gtk4>3>2 单源 CBackendOrder)
base←window.gtk.impl←gtk3/4/2 (TGtkOps显式)  sdl2/win32/cocoa/android/uikit同位
window.gtk.impl←window.gtk.dispatcher (g_idle_add_full+ring, per-instance; 单向→impl)
window.gtk.impl←window.gtk.window (窗口+7信号, →impl+dispatcher; 单向无循环)
registry→live/queue/hash/dispatcher.base (聚合单源，TWindowFamilyToken 编译期隔离)
probe→*.loader(TryLoad*) (探测单源，零堆分配)
window.impl 约束校验本地化守 L0-L3 无循环（业务以 CONTRACT 为准）
window.chrome/loop/input/view/dialog/dpi/event/constraints → bytes.ops direct L2→L1（Owner 四件套单源；缺口反哺 bytes.ops，见各子模块 CONTRACT §1 与 BENCH.md）
```

- **`base`/`intf`零后端**：uses 禁 `window.<backend>* / fake / factory`（INV-3）。
- `*.ffi`仅ABI类型常量函数指针、**无逻辑无`external`**；系统库一律运行时装载（严于design-conventions §6）。
- **`*.loader`唯一`platform.dl`装载点**，禁`DynLibs`；生产单元禁raw host units（`Windows/BaseUnix/Unix/ctypes/X`等，INV-4），真相收敛`ffi+loader`；装载失败`WindowBackendAvailable=False`→强`Build`抛`EWindowBackendUnavailable`带sonames。

### 注册表时机

registry已随S1落地（`check_architecture_source_contracts`放行）：L2 / owner core-window / facade yes / deps L0-L1（含diagnostics/text/system.typinfo）+ `platform.dl` + one-way L2 `gtk2/3/4/qt` / truth `ci-matrix`（见FINAL_ROADMAP F3/CI_MATRIX）。职责收口注册/排序/聚合+RunLoop/Pump薄委托（`factory` → `registry` 单源），探测归`probe`（`window.probe` 12项 `Probe*` 单源 dlopen），诊断经`TDiagnosticsBuilder`，sonames由loader常量单源注入。

> 容量与性能：全族 `WindowGrowCapacity` 统一单源 `bytes.ops 0→32→2×` inline 零拷贝 O(1)均摊，heaptrc 0；证据集中于 `BENCH.md` 与各子模块 `CONTRACT §1`，不逐格重复（高级感守契约抽象）。
> 已落地 8 物理模块（INV-10~18 → `window.loop/chrome/input/view/dialog/dpi/event/constraints`，`dialog`双INV聚合）均按 Owner 四件套 `base←intf←impl←门面` 落地，守 L0-L3 / INV-3，业务缺口已反哺 `bytes.ops` owner，核心未膨胀；详见 §7.1 与 registry 已落地行。

---

## 2. 语义诚实表

跨平台差异显式声明，不做假装。每个后端接入前逐格复核本表并在其
focused/runtime 门禁中断言可测格。

### 2.1 NativeHandle 诚实表（冻结，S2a 补 wasm 行）

| 后端 | `NativeHandle` 返回 | 说明 |
|------|---------------------|------|
| `gtk`（X11 会话） | X11 Window id（XID，以指针宽度整数承载） | `gdk_x11_window_get_xid` |
| `gtk`（Wayland 会话） | **nil** | Wayland 合成器不暴露可嵌入原生句柄；嵌入场景非目标 |
| `sdl2` | 按 windowing subsystem：X11 XID / HWND / NSWindow* / Wayland nil | `SDL_GetWindowWMInfo` 判别 subsystem |
| `win32` | HWND | 客户区顶层窗口句柄 |
| `cocoa` | NSWindow* | 外部消费须自行桥接 ObjC 世界 |
| `wasm` | `EMSCRIPTEN` canvas 元素指针（attach 形态；`ParentHandle` 携带 canvas id 指针） | `emscripten_get_canvas_element_size` 的 `target` 指向的 `<canvas>`；`Close` 后 nil，生命周期归 DOM |
| `android` | ANativeWindow* | attach 形态；surface 生命周期归宿主 Activity |
| `uikit` | UIWindow* | attach 形态 |
| `fake` | 确定性生成的非零假句柄 | 仅用于断言句柄传递链，永不解释内容 |

规则：本模块只交付句柄**永不解释**（消费方建GL/webview自判）；`Show`后除Wayland外非nil（GTK realize前不承诺），`Close`后一律nil；不设`HandleOS()`伪抽象，用`platform.info`自判。

### 2.2 行为差异矩阵

| 能力 | gtk | sdl2 | win32 | cocoa | wasm | android | uikit | fake |
|------|-----|------|-------|-------|------|---------|-------|------|
| Min/Max 尺寸约束 | `gtk_geometry_hints` 生效 | `SDL_SetWindowMinimumSize` 生效 | `WM_GETMINMAXINFO` 生效 | `contentMinSize`/`contentMaxSize` 生效 | **忽略**：canvas 尺寸归 CSS/浏览器布局，`Build` 选项 `Min/Max` 诚实 no-op | **忽略**：surface 尺寸归宿主布局，诚实 no-op | **忽略**：同 android | 生效（校验逻辑同 base） |
| GetScaleFactor | 整数诚实升格（典型 1/2） | ≥2.24 `SDL_GetWindowDisplayScale`；缺席回退 1.0（诚实标注） | `GetDpiForWindow/96` | `backingScaleFactor` | `emscripten_get_device_pixel_ratio`（`1.0..3.0`），浏览器缩放时 `weScaleChanged` | 宿主 display metrics（当前 1.0 诚实） | `UIScreen.scale`（当前 2.0/3.0 诚实） | 固定 1.0，可脚本化改 |
| weMoved 事件 | 发（配置协议决定精度） | 发 | 发 | 发 | **不发**：canvas 无全局屏幕坐标 | **不发**：surface 无全局屏幕坐标 | **不发** | 仅脚本注入 |
| Wayland weMoved | **不发**（无全局坐标） | 不发 | — | — | — | — | — | — |
| GetTitle | WM 级同步读；未设置过 '' | `SDL_GetWindowTitle` | `GetWindowText` | `title` property | `document.title` 同步（宿主归 `webview.wasm`） | 缓存（宿主标题归 Activity） | 缓存（宿主标题归 UIWindow） | 缓存读 |
| Focus | `present` | `RaiseWindow` | `SetForegroundWindow` | `makeKeyAndOrderFront` | `canvas.focus()`（宿主可为 no-op） | 宿主焦点（no-op） | 宿主焦点（no-op） | 状态位翻转 |
| IsMinimized/Maximized | 查询式真值（gdk window state 位） | `SDL_WINDOW_*` 状态位 | `IsIconic/IsZoomed` | `isMiniaturized`/`isZoomed` | **诚实 no-op**：`IsMinimized=False`/`IsMaximized=False` 恒假 | **诚实 no-op** | **诚实 no-op** | 状态位 |
| ParentHandle（attach） | **不支持**：Build 抛 `EWindowUnsupported` | 同左（S3） | 同左 | 同左 | **接受**：`ParentHandle` 携带 canvas 元素指针/id 指针（attach 唯一形态） | **必需**：携带 `ANativeWindow*`，缺失抛 `Unsupported` | **必需**：携带 `UIWindow*`，缺失抛 `Unsupported` | 记录并接受（供 attach 契约预演） |
| 几何单位换算 | 内部逻辑像素，读写按 scale 换算物理口径，往返误差 ±1px | 同左（点坐标） | 物理像素直通 | 点坐标换算，±1px | CSS 像素×`devicePixelRatio`=物理像素；`SetBounds` 写 CSS 尺度，内部×ratio 得物理往返 | 物理像素直通（只读） | 点坐标（只读，×scale） | 物理像素直通 |

几何口径：`SetBounds/GetWidth/GetHeight/weResized/weMoved`一律**物理像素**；逻辑=物理/scale，换算归消费方，内部逻辑后端负责误差±1px入表。

高级视觉：`decorations/透明/阴影/动画` 诚实表高级感不变量已由 `window.chrome` L2 承载（INV-12 已落地四件套 `window.chrome.base/intf/impl+门面`，原 Deferred P3低→现 P2中已晋升 L2 交付，单源 `bytes.ops 0→32→2×` inline 零拷贝，详见 §7.1/独立契约 `window.chrome/CONTRACT.md`）；输入栈已由 `window.input` L2 承载（INV-14 已落地），事件循环/对话框/多视图已由 `window.loop/view/dialog` 承载（INV-10/11/16/17 已落地），见 §7.1。

---

## 3. 核心类型（window.base）

### 3.1 后端种类

```pascal
TWindowKind = (wkGtk2, wkGtk3, wkGtk4, wkQt, wkSdl2, wkWin32, wkCocoa, wkAndroid, wkUIKit, wkWasm, wkFake);

const
  wkGtk = wkGtk3; // deprecated shim，兼容旧 wkGtk → wkGtk3
```

11 种（`core/src/nextpas.core.window.base.pas:11` 单一真相），生产种类在前、`wkFake` 收尾
（对齐 `TWebviewKind` 排列惯例，`wkWasm` 紧邻 `wkFake` 之前属 attach 族；`wkGtk2/3/4` 为 GTK 版本钉选，
`wkQt` 为 Qt 族，`wkGtk` 为 `wkGtk3` 的 deprecated 别名，factory 对 `wkGtk` 以 `gtk4>gtk3>gtk2` 智能回退）。
能力驱动的缺省选择 `DefaultWindowKind: TWindowKind` 定义在 **factory**（探测需要 loader 参与），base 只拥有枚举本身。

### 3.2 窗口选项

```pascal
TWindowNativeHandle = type Pointer;

TWindowSize = record // 强类型尺寸：Width/Height 封装，inline 零拷贝防裸 Integer 误用
  Width: Integer;  // 默认 1024，<=0 用引擎默认
  Height: Integer; // 默认 768
  class function Create(AWidth, AHeight: Integer): TWindowSize; static; inline;
  class function Default: TWindowSize; static; inline;
end;

TWindowConstraints = record // 强类型约束：Min/Max 4 字段封装，inline 零拷贝，业务以 CONTRACT 为准
  MinWidth: Integer;  // 0 = 不设限制
  MinHeight: Integer;
  MaxWidth: Integer;  // 0 = 不设限制
  MaxHeight: Integer;
  class function Create(AMinWidth, AMinHeight, AMaxWidth, AMaxHeight: Integer): TWindowConstraints; static; inline;
  class function Default: TWindowConstraints; static; inline;
end;

TWindowOptions = record
  Title: string;              // 默认 ''
  Size: TWindowSize;          // 默认 Default，<=0 用引擎默认（强类型封装防裸 Integer 平铺）
  Constraints: TWindowConstraints; // 默认空（0 不限制），Min/Max 强类型封装防误用
  Resizable: Boolean;         // 默认 True
  Maximized: Boolean;         // 默认 False；启动即最大化
  ParentHandle: TWindowNativeHandle; // 默认 nil；非 nil = embedded attach
                              // （S5 android/uikit 生效；桌面后端 Build 抛
                              //   EWindowInvalidState，见诚实表）
end;

function DefaultWindowOptions: TWindowOptions; // base：纯构造，inline（零 L1 依赖）
function WindowGrowCapacity(ACurrent: Integer): Integer; inline; // impl 单源转发 bytes.ops 0→32→2×（base 纯数据类型不承载，SizeUInt 重载家族零调用已剔除，守单源 0→32→2× inline 零拷贝）
procedure CheckWindowOptions(const AOptions: TWindowOptions); // impl：校验实现，inline 薄分支（Size/Constraints 双记录校验）
```

`CheckWindowOptions`（`window.impl` 单源）校验规则（违反即 `EWindowInvalidState`）：
尺寸字段一律 >= 0；`<=0` 的 Width/Height 表示引擎默认；
Max 与 Min 同时为正时必须满足 max >= min。窗口创建后一律隐藏，
可见性由 `Show` 显式给出（无 `Visible` 选项——事件 handler 应先于
Show 注册，示例即此顺序）。

### 3.3 事件 record

```pascal
TWindowEventKind =
  (weResized, weMoved, weCloseRequested, weClosed, weFocusChanged, weScaleChanged);

const
  weFocusIn = weFocusChanged;
  weFocusOut = weFocusChanged;

TWindowPixel = type Integer; // 物理像素强类型，distinct

const
  WINDOW_SCALE_EPSILON = 1e-9; // 高频 weScaleChanged 每帧一次去抖阈值，单源于 window.base，业务以 CONTRACT 为准
  WINDOW_SCALE_IDENTITY_FACTOR = 1.0;

TWindowScale = record // 尺度强类型，Double 外覆，inline 零拷贝值语义
  class function FromFactor(const AFactor: Double): TWindowScale; static; inline;
  class function Identity: TWindowScale; static; inline; // 1.0
  class function Invalid: TWindowScale; static; inline; // 0.0 非法哨兵
  function Factor: Double; inline;
  function ToDouble: Double; inline;
  function IsValid: Boolean; inline; // Factor > 0
  function IsIdentity: Boolean; inline; // Abs(Factor-1.0) <= WINDOW_SCALE_EPSILON，防精确相等流水线停顿
  function Equals(const AOther: TWindowScale): Boolean; inline; // Abs diff <= EPSILON
  class operator = (const A, B: TWindowScale): Boolean; inline; // epsilon 近似
  class operator <> (const A, B: TWindowScale): Boolean; inline;
end;

TWindowEvent = record
  Kind: TWindowEventKind;
  Width: TWindowPixel;   // weResized：新客户区宽（物理像素强类型）
  Height: TWindowPixel;  // weResized：新客户区高（物理像素强类型）
  X: TWindowPixel;       // weMoved：屏幕坐标（物理像素强类型；Wayland 不发）
  Y: TWindowPixel;       // weMoved
  NewScale: TWindowScale; // weScaleChanged：强类型尺度
end;

TWindowEventHandler = reference to procedure(const AEvent: TWindowEvent);
```

无关字段保持零值。**单一事件入口**：一切通知（含 scale 变化）都经
`OnEvent` 以 `TWindowEvent` 分发，不设第二套 per-event 注册面——这是对
webview `OnScaleChanged` 独立注册面的有意收紧，理由见 §4.2。

### 3.4 错误族

派生自框架根异常；类目定值在 S1 对照 `nextpas.core.exception.TErrorCategory`
校准并逐类写测试（括号内为暂定映射）：

```pascal
EWindowError                = class(ENextPasError); // 族基类（ecInternal）
EWindowBackendUnavailable   = class(EWindowError);  // dlopen/探测失败（ecNotFound）
EWindowNotInitialized       = class(EWindowError);  // 后端未初始化即使用（ecInternal）
EWindowInvalidState         = class(EWindowError);  // 选项非法/重复误用/Close 后操作等（ecInternal）
EWindowClosed               = class(EWindowError);  // Close 之后仍发起操作（ecInternal）
EWindowUnsupported          = class(EWindowError);  // 后端诚实表明确不支持的能力（ecInternal）
```

`EWindowUnsupported` 用于"诚实表说不支持且调用方仍请求"的显式失败
（如桌面后端收到 `ParentHandle`），与静默 no-op 严格区分：能安全 no-op 的
能力按诚实表 no-op，不能伪装的能力必须抛错。

---

## 4. 接口契约

对外一律 interface（COM 引用计数），消费方不手写释放。三种回调形式
（ref/method/proc）并存遵循 design-conventions §8；下文签名只列匿名形，
method/proc 重载同形省略。

### 4.1 主线程投递（intf）

```pascal
TWindowProcRef    = reference to procedure;
TWindowProcMethod = procedure of object;
TWindowProc       = procedure;

IWindowDispatcher = interface
  { 任意线程把闭包投递到 UI 主线程执行；末窗关闭后投递被静默丢弃 }
  procedure Post(AProc: TWindowProcRef); overload;   // 显式代价：匿名捕获堆分配 64k/1000，见性能 SLA
  procedure Post(AProc: TWindowProcMethod); overload; // 热路径默认：零分配 inline 直存 wwkMethod
  procedure Post(AProc: TWindowProc); overload;       // 热路径默认：零分配 inline 直存 wwkProc
  function IsOnMainThread: Boolean;
  property OnMainThread: Boolean read IsOnMainThread;
end;
```

**性能 SLA（冻结，单源 `BENCH.md` §单次全量）**：
- `Post(Method/Proc)` 热路径 `inline` 零拷贝直存 `wwkMethod/wwkProc` 单源 `bytes.ops 0→32→2×` + `Drain` 单锁批量快照，`<250µs/1000` 0 allocs（`BenchPostSingle` 210µs 中位，方差 <5%）；`Post(Ref)` 显式堆分配仅参考；
- `WindowPumpOnceZero` 单一口径 16ns <30ns 纯净：`TWindowQueue.TryStealRing atomic_load(FCount)=0` + `WindowTotalLiveCount/FakeHasPendingPosts` 单次原子读 inline 零锁早退，单次 16ns 与批量 10k 均摊 16ns 同口径 <30ns 单一 SLA（LiveGtkSmart 已移至非零分支消除 +10ns 偏差，WindowQueueSnapMax 8192 via bytes.ops 单源 inline 零拷贝 O(1)均摊，ManagedRingTransfer 单源托管不丢；bench_dispatcher 双项 WindowPumpOnceZero/1 + WindowPumpOnceZero/10000 同口径硬化）；
- 排程抖动以 `LiveReal` 真机为主基线，三机矩阵 5×中位双门禁（单机<5% 且跨机<5%，Zero 单一口径 16ns 纯净）详见 `BENCH.md`，业务以 `CONTRACT` 为准。

各后端主线程唤醒原语：GTK = `g_idle_add_full`；sdl2 = 用户事件
（`SDL_RegisterEvents` + `SDL_PushEvent`）经自家泵分发；win32 =
隐藏 message-only window `PostMessage`；cocoa = `dispatch_async(main)`；
fake = 待泵队列。唤醒原语属于后端接口的一部分（ARCHITECTURE §4）。

### 4.2 窗口（intf）— 小接口组合（ISP）

> 匠心修复：`IWindow` 由 9 个 <6 方法小接口组合而成（各持独立 GUID，`Supports` 按需探测），
> 拒绝 20+ 方法单体靠分区注释维持可读；`IWindow` 为轻量组合门面（多继承 + 单一 GUID `002` 兼容存量 `W.Show` 直调），
> 新代码可依赖 `IWindowTitle`/`IWindowGeometry` 等小口径 mock 单 facet；守四件套与 L0-L3 零后端依赖，
> 性能虚表一跳直达、OnEvent 变体直存 Method/Proc inline 零拷贝，资源 VariantClear 托管不丢。

```pascal
IWindowLifecycle = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A010}'] procedure Close; function IsClosed: Boolean; end;
IWindowVisibility = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A011}'] procedure Show; procedure Hide; function IsVisible: Boolean; procedure Focus; end;
IWindowTitle = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A012}'] procedure SetTitle(const ATitle: string); function GetTitle: string; end;
IWindowGeometry = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A013}'] procedure SetBounds(AWidth,AHeight: Integer); function GetWidth: Integer; function GetHeight: Integer; procedure SetResizable(AResizable: Boolean); end;
IWindowState = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A014}'] procedure Maximize; procedure Unmaximize; function IsMaximized: Boolean; procedure Minimize; procedure Restore; function IsMinimized: Boolean; end;
IWindowScale = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A015}'] function GetScaleFactor: Double; end;
IWindowNativeHandle = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A016}'] function NativeHandle: TWindowNativeHandle; end;
IWindowDispatcherProvider = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A017}'] function GetDispatcher: IWindowDispatcher; property Dispatcher: IWindowDispatcher read GetDispatcher; end;
IWindowEvents = interface ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A018}'] procedure OnEvent(AHandler: TWindowEventHandler); overload; procedure OnEvent(AHandler: TWindowEventMethod); overload; procedure OnEvent(AHandler: TWindowEventProc); overload; end;
IWindow = interface(IWindowLifecycle, IWindowVisibility, IWindowTitle, IWindowGeometry, IWindowState, IWindowScale, IWindowNativeHandle, IWindowDispatcherProvider, IWindowEvents)
  ['{8F1A2B3C-4D5E-4F60-9A8B-C0D1E2F3A002}'] end;
```

设计决定（对 README 能力表的收紧，在此钉死）：

- **不设独立 `OnScaleChanged` 注册方法**：scale 变化统一以
  `weScaleChanged` 事件走 `OnEvent`（`NewScale` 字段携带新值）。双通道
  投递同一信号会造成触发序歧义；winit 亦为单通道事件流。
- **运行期 `SetMin/Max` 已独立四件套（INV-13）**：`SetMinSize/SetMaxSize` 运行期改约束已抽至 `window.constraints` `base/intf/impl+门面` 单源复用 `CheckWindowConstraints` `inline` 零拷贝 O(1) 薄分支校验（`bytes.ops 0→32→2×` 单源 via `WindowConstraintsGrowCapacity`），window.impl 已去 L2→L2 薄转发本地 inline 校验守 L0-L3，`TWindowConstraints/IWindowConstraints` 端到端载体 `Apply/SetMin/Max` inline O(1) zero-copy，`heaptrc 0`；`window.constraints` 已在 `core-module-registry` 落地 Public facade=yes source-contract，独立契约见 `core/docs/window.constraints/CONTRACT.md`，业务以 CONTRACT 为准、缺能力反哺 `bytes.ops` owner。
- 事件反注册句柄由 `window.event` `IWindowEventBus/IWindowEventSubscription` 承载（可撤销 `TWindowEventHandle`，`WindowEventGrowCapacity` 单源 `bytes.ops 0→32→2×` inline 零拷贝 O(1)均摊，`Unsubscribe` 幂等 `heaptrc 0`）；`IWindow.OnEvent` 保留覆盖语义（最后注册者生效）兼容存量，新增订阅路径可多句柄并存。

### 4.3 工厂与主循环（factory）

```pascal
IWindowBuilder = interface
  function Kind(AKind: TWindowKind): IWindowBuilder;   // 显式钉后端
  function Title(const ATitle: string): IWindowBuilder;
  function Size(AWidth, AHeight: Integer): IWindowBuilder;
  function MinSize(AWidth, AHeight: Integer): IWindowBuilder;
  function MaxSize(AWidth, AHeight: Integer): IWindowBuilder;
  function Resizable(AResizable: Boolean): IWindowBuilder;
  function StartMaximized(AMaximized: Boolean): IWindowBuilder;
  function Parent(AHandle: TWindowNativeHandle): IWindowBuilder;
  function Options(const AOptions: TWindowOptions): IWindowBuilder; // 整体覆盖
  function Build: IWindow;
end;

TWindowBuilder = record
  class function New: IWindowBuilder; static;
end;

{ 主循环所有权：阻塞直到最后一个未 Close 的窗口关闭，或 ExitLoop 被调 }
procedure WindowRunLoop;
procedure WindowExitLoop;

{ 非阻塞泵：为 game/directui tick 循环提供单步迭代（M-band 落地，不阻塞） }
function WindowPumpOnce: Boolean;
procedure WindowPumpAll;

{ 能力探测（factory 持 loader 真相；base 不知道这些函数的存在） }
function WindowBackendAvailable(AKind: TWindowKind): Boolean;
function DefaultWindowKind: TWindowKind;

{ 宿主驱动扩展：attach 后端由宿主经 Supports 探测调用，拒绝 LM_ 消息伪装 }
type
  IWindowHost = interface
    ['{7E9A2B3C-3D4E-4F60-9A8B-C1D2E3F4A005}']
    procedure HostResized(AWidth, AHeight: Integer);
    procedure HostScaleChanged(ANewScale: Double);
    procedure HostCloseRequested;
  end;
```

- `Kind()`缺省=`DefaultWindowKind`单源`factory.BACKENDS[8]` O(1)查表 `win32>cocoa>android>uikit>wasm>gtk(聚合gtk4>3>2)>sdl2>fake`（平台原生>wasm>gtk>sdl2），不可用`Build` fail-fast抛`EWindowBackendUnavailable`；`Build`可多窗共享主线程/主循环，消费方负责`Close`幂等。
- 退出：末窗关闭或`WindowExitLoop`；`weCloseRequested`先于销毁投递；`RunLoop`期间宿主勿占线程，后台经`Dispatcher.Post`回主线程。
- 不uses `TAsyncLoop`；`IterateOnce`属deferred-LI，S1不留接口，M-band以`WindowPumpOnce/PumpAll`供game/directui `tick`复用。

### 4.4 fake 驱动面（fake）

纯 Pascal、无线程、无图形依赖；契约测试的唯一载体（INV-7）。驱动面
经 `Supports` 探测获得，命名在 S1 定案，语义现在冻结：

- **注入事件**：把构造好的 `TWindowEvent` 送入与本生产后端同一条
  `OnEvent` 分发路径（不是旁路直呼 handler）——保证被测的就是分发机制。
- **手动泵**：`PumpOnce` 至多执行一条待处理投递、`PumpAll` 清空队列；
  顺序 FIFO 确定。`Post` 在 fake 上不入队真线程，只积累待泵闭包。
- **状态脚本**：scale 值、最大化/最小化/焦点/可见状态位均可直接改写，
  用于驱动 `weScaleChanged` 等派生事件的生成路径。
- **句柄**：确定性生成的非零假句柄，`Close` 后归 nil（与生产后端同规）。

---

## 5. 线程模型

1. **UI 主线程** = 创建窗口并驱动后端主循环的线程。一个进程可有多个窗口，
   但全部窗口共享同一 UI 主线程与同一主循环。
2. **一切用户回调（`OnEvent` handler、`Post` 投递的闭包）都在 UI 主线程
   触发**。引擎/OS 事件天然在主线程到达，后端不得把它们抛到别的线程。
3. **跨线程安全面只有两处**，其余方法按"UI 线程亲和"对待（违例属编程
   错误，debug 构建断言）：
   - `IWindowDispatcher.Post`（任意线程 → 主线程）
   - `IWindow.Close`（任意线程；内部 marshal 到主线程执行，幂等）
4. **不提供任何同步阻塞形态**（无 `WaitForClose`、无嵌套消息泵、无忙轮询）。
   fafafa 教训 #1 制度化。
5. handler 内抛出的异常沿主循环栈向上传播、使 `WindowRunLoop` 展开
   （try/finally 保证运行态标志复位）——编程错误 fail-fast，由应用边界
   （main）统一捕获；本模块不吞不包装用户回调异常。
6. 与 `async.loop` 的关系见 §4.3：无编译期依赖，应用层组合。

---

## 6. 生命周期 / DPI / 多窗口

### 6.1 窗口生命周期

```
Build（隐藏创建，选项已校验）
  → Show → [OnEvent 流]
  → 用户点关闭钮 / 系统 close 请求 → weCloseRequested（可忽略 = 不关）
  → 应用调 Close（幂等；marshal 主线程）
  → 后端销毁原生资源（主线程完成）→ IsClosed=True → NativeHandle=nil
  → COM 引用计数归零释放接口壳
```

- `weCloseRequested` 只是通知：不响应就不关闭（close-request veto 的
  交互式确认 UI 属 deferred，见 §9）。
- Close 后除 `IsClosed`/`NativeHandle` 外一切方法抛 `EWindowClosed`（INV-1）。
- 进程退出不强制要求显式 Close：末窗关闭驱动循环退出；残留接口壳由
  引用计数兜底。

### 6.2 DPI 契约

- `GetScaleFactor: Double` 只读；GTK 整数值诚实升格（1.0/2.0…），
  各后端取值方式见诚实表。
- 逻辑坐标 = 物理像素 / scale；换算时机归消费方。
- scale 变化（显示器迁移、系统缩放变更）以 `weScaleChanged(NewScale)`
  经 `OnEvent` 投递；per-monitor 动态重排由 `window.dpi` `IWindowDpi/IWindowDpiSubscription` 承载（可撤销订阅，`NotifyChanged` inline 零拷贝 O(n)，`WindowDpiGrowCapacity` 单源 `bytes.ops 0→32→2×`），核心 `weScaleChanged` 标量路径保持兼容。
- 移动端（S5）scale 来自宿主 surface 的 display metrics；attach 形态下
  窗口几何只读（尺寸归宿主布局），SetBounds 为诚实 no-op——S5 定案前
  此行先冻在诚实表。
- wasm 端 scale = `devicePixelRatio`（浏览器缩放/显示器迁移时 `weScaleChanged`），几何写 CSS 尺度内部×ratio 得物理；attach 形态下 `ParentHandle` 携带 canvas 指针/id 指针，`Min/Max` 诚实 no-op。

### 6.3 多窗口

- `TWindowBuilder.New...Build` 可多次调用；每窗独立 `IWindow`，共享主循环。
- 事件顺序：单窗内严格 FIFO；跨窗相对顺序未定义（不得依赖）。
- 循环退出条件与计数口径见 §4.3；`WindowExitLoop` 幂等且可在任意时刻调用
  （主线程亲和）。

---

## 7. 不变量

- **INV-1** `Close` 幂等；Close 后除 `IsClosed` / `NativeHandle` 外一切
  方法抛 `EWindowClosed`；`NativeHandle` 在 Close 完成后恒为 nil。
- **INV-2** 一切用户回调恰在 UI 主线程触发；每事件对当前 handler 恰好
  投递一次；单窗事件序 FIFO；窗口销毁后不再产生该窗事件。
- **INV-3** `base`/`intf` 的 uses 闭包不出现任何 `window.<backend>*`、
  `window.fake`、`window.factory` 单元（source-contract 门禁冻结）。
- **INV-4** 生产单元（非 loader）不出现 raw host units（`DynLibs`/
  `Windows`/`BaseUnix`/`Unix`/`ctypes`/`X`/`CocoaAll`…）；平台真相全部
  收敛在后端 `ffi` + `loader`。
- **INV-5** `*.ffi` 无逻辑、无 `external`：只有类型、常量、函数指针变量；
  装载动作只存在于 `*.loader` 且只经 `nextpas.core.platform.dl`。
- **INV-6** `weCloseRequested` 先于任何销毁动作投递；不响应即不关闭。
- **INV-7** `fake` 是契约测试唯一载体；CI 无图形环境全绿。fake 注入事件
  走与生产后端同一条分发路径，不存在测试专用旁路。
- **INV-8** 几何公开口径恒为物理像素；内部逻辑坐标的后端负责换算并把
  误差写入诚实表，不得让消费方感知单位漂移。
- **INV-9** 后端不支持且无法安全 no-op 的能力必须显式抛
  `EWindowUnsupported`，禁止静默假装成功（诚实原则）。

### 7.1 已落地四件套（闭环，暂无新模块候选，详见 ROADMAP §6）

> 状态：INV-10~18 已按 Owner 四件套 `base←intf←impl←门面` 落地 8 物理模块（`dialog` 双 INV 聚合），守 L0-L3 / INV-3，容量策略统一单源 `bytes.ops`（`WindowGrowCapacity 0→32→2×` inline 零拷贝 O(1)均摊，heaptrc 0；证据见 BENCH.md 与各子模块 CONTRACT §1），业务缺口已反哺 `bytes.ops` owner，业务不变量闭环，暂无可抽新模块候选，核心未膨胀；冻结核心 11 种 `TWindowKind` + 6 种 `TWindowEventKind` 强类型单源于 `window.base` 为最小闭包，不再新增 Event/Interface，registry 真相以 `ci-matrix` 为准。

| INV | 能力 | Owner / 目标模块 | 优先级 | 状态 |
|---|---|---|---|---|
| INV-10 | `IterateOnce` 融合 (LI) | `window.loop` L2 + `async` L1 | P2 中 | 已落地四件套 `window.loop.base/intf/impl+门面` |
| INV-11 | close 交互确认 (Win) | `dialog` L3 | P2 中 | 已落地四件套 `dialog.base/intf/impl+门面` |
| INV-12 | `chrome` 全批 (decorations/透明/阴影/动画) | `window.chrome` L2 | P2 中 | 已落地四件套 `window.chrome.base/intf/impl+门面` |
| INV-13 | 运行期 SetMin/Max | `window.constraints` L2 | P1 高 | 已落地四件套 `window.constraints.base/intf/impl+门面` |
| INV-14 | 输入 In (键鼠触摸/IME) | `window.input` L2 | P1 高 | 已落地四件套 `window.input.base/intf/impl+门面` |
| INV-15 | per-monitor 重排 | `window.dpi` L2 | P2 中 | 已落地四件套 `window.dpi.base/intf/impl+门面` |
| INV-16 | 多 view/通信 | `window.view` L2 | P2 中 | 已落地四件套 `window.view.base/intf/impl+门面` |
| INV-17 | 父子/modal | `dialog` L3 | P2 中 | 已落地四件套（同 INV-11 归 `dialog`） |
| INV-18 | 事件反注册句柄 | `window.event` L2 | P2 中 | 已落地四件套 `window.event.base/intf/impl+门面` |

规则：9 项（8 物理模块 + `dialog` 双 INV 聚合）已按 Owner 四件套落地，守 L0-L3 / INV-3，单源 `bytes.ops`（性能 inline 零拷贝 O(1)均摊、heaptrc 0 见 BENCH.md，已补 source-contract）；业务以 CONTRACT 为准、缺能力反哺 `bytes.ops` owner；业务不变量已闭环，暂无可抽新模块候选，后续若确需新 `EventKind/Interface/背压` 再按四件套与 `bytes.ops` 单源评估（详见 §9 索引）。

---

## 8. 测试门禁

| 门禁 | 载体 | 要求 |
|------|------|------|
| 契约测试（CI 必跑，全走 fake） | `tests/nextpas.core.window/test_*` | options 校验、状态机（show/hide/maximize/minimize/close 幂等）、事件注入与分发序（INV-2/INV-6）、dispatcher 泵语义、factory 选择逻辑与 fail-fast、错误族类目、句柄 nil 纪律（Close 后） |
| source-contract | `tests/architecture/source_contracts/` 扩展 | INV-3/INV-4 静态扫描；INV-5 `*.ffi` 无逻辑无 `external` 检查；raw host units 白名单外零容忍 |
| 运行时冒烟（本地/Linux CI） | `test_window_gtk_runtime`（S2 起） | 探测到 GTK3 才跑；Xvfb 下建窗→title/bounds/maximize 往返→scale 读取→close 幂等；未探测到输出 SKIP，`NEXTPAS_WINDOW_GTK_REQUIRED=1` 强制 |
| compile-only | 非 Linux host | gtk/sdl2/win32/cocoa 单元参与语法级编译门禁（不链接） |
| benchmark | `benchmarks/nextpas.core.window/bench_dispatcher`（`nextpas.core.bench`，单次调用不内循环） | 热路径 `PostSingle/1` `inline` 0 allocs 零拷贝直存 `wwkMethod/wwkProc` via `bytes.ops 0→32→2×` 单源 `BenchBlackBoxPtr` 防 DCE；`PumpOnceSingle/1`/`DrainSingle/1`/`Post→Pump→Drain` 交叉 `inline` 单次 `atomic_load` 16ns <30ns 零锁；`LiveReal` 真机 `Show→Post→PumpOnce→Close` 主基线；9 INV 业务域 `chrome/loop/input/view/dialog/dpi/event/constraints` 各 `*GrowCapacity/Check/*Subscribe/*Dispatch/*Apply` 单次调用 `inline` 零拷贝 O(1)均摊 `bytes.ops` 单源无内循环 `BenchBlackBox*` 防 DCE；三机矩阵 5×中位双门禁（单机<5% 且跨机<5%）详见 `BENCH.md` 进 `ci-matrix` |

runtime 冒烟允许的最大环境假设：存在 GTK3 运行库；不要求 dev 包
（ABI 自声明）。

---

## 9. Deferred 登记簿（索引，已闭环，详见 §7.1 / ROADMAP §6）

> 已落地状态以 §7.1 为准，本节仅保留历史索引，不重复登记落地细节与性能链路（防双表漂移）；INV-10~18 已闭环，暂无可抽新模块候选。Deferred≠计划内，触发前不占位；若后续确需新能力，晋级纪律：四件套齐否则 INV-3 红，缺能力反哺 `bytes.ops` 单源 / `platform.dl`；稳定性 heaptrc 0 见 §7.1 / BENCH.md。

| 类别 | 代表能力 | 触发条件 | Owner → INV | 优先级 |
|------|----------|----------|-------------|--------|
| LI | `IterateOnce` 融合 | 接 `TAsyncLoop` 时 | `window.loop` L2 → INV-10 | P2 中 |
| Win | close确认 / `chrome`全批(透明/阴影/动画) / SetMinMax | 弹窗 / tao二批诚实表 / 运行中改约束 | `dialog`→11 / `chrome`→12 / `window.constraints`→13 | P2/P2/P1 |
| In | 键鼠/触摸/滚轮/IME | `directui/game` 需 native input | `window.input` L2 → INV-14 | P1 高 |
| DPI | per-monitor 重排 | 多显示器一等需求 | `window.dpi` L2 → INV-15 | P2 中 |
| Arch/Ev | 多 view/父子/modal/反注册 | 消费者 / 对话框立项 / 高频换 handler | `view`→16 / `dialog`→17 / `window.event`→18 | P2 中 |

---

## 10. 稳定性

- 当前 `ci-matrix`（Linux 13门 runtime + Win/mac compile-only 残差诚实，`focused-runtime` 已达，`ci-matrix` 诚实标注见 CI_MATRIX/BENCH）；registry 条目 `window` L2 已落地，INV-1~INV-9 与诚实表冻结，`DefaultWindowKind` 探测顺序以 `factory.BACKENDS[8]` 为单源（`win32>cocoa>android>uikit>wasm>gtk>sdl2>fake`，`gtk` 聚合 `gtk4>gtk3>gtk2`），不另存副本。
- 公共 API 变更纪律：`intf` 单元视为冻结候选，改动必须过契约测试并更新
  本文件（含诚实表逐格复核）。
