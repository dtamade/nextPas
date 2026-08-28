# nextpas.core.window Roadmap

**Authority**: 本文件是 window 模块**向前开发**的唯一执行入口。
**Companion**: 定位见 [README.md](README.md)；契约见 [CONTRACT.md](CONTRACT.md)；
架构纵深见 [ARCHITECTURE.md](ARCHITECTURE.md)；抽象原则见 [ABSTRACT_DESIGN.md](ABSTRACT_DESIGN.md)。
**Updated**: 2026-08-28（M-band 去消息化+宿主泵：IWindowHost + PumpOnce + 13门禁 391µs/1000；NEXT=M-band 维持）

---

## 0. 进场 30 秒

1. **当前 NEXT = M-band**（S5 已完成；S4 win32/cocoa、S3 sdl2、S2 gtk、S2a wasm 全部落地）。
2. 波次铁律：**契约先行，fake 同批，生产后端逐波**；每波必须能独立
   land 且全门禁绿。
3. 跨模块纪律：S2 触碰 `webview`、S4 与 `webview` Wave 2/3 协同——
   每波 Land paths 显式声明 + 双端 focused gate；冲突时 Needs Review。
4. Deferred 能力不占位（CONTRACT §9）；想做的第一反应是查登记簿，
   没有触发条件就不做。

---

## 1. 北极星

把散落在 `webview.gtk.win` / `gpu.gl` / `game888.graphics.window` 三处的
窗口能力收敛为一个可对标 winit/tao 抽象质量的 L2 窗口家族，
让 gpu/directui/webview/game888 共享同一窗口契约：

| 支柱 | 含义 |
|------|------|
| 复用 | 一个契约四个消费者；新后端只实现一次 |
| 诚实 | NativeHandle/DPI/几何差异全部上诚实表；不支持即抛错不假装 |
| 可测 | fake 是 CI 契约唯一载体；无图形环境全绿 |
| 纪律 | base/intf 零后端依赖；loader 唯一触 platform.dl；Deferred 不占位 |

---

## 2. 当前状态快照（回写处）

| 项 | 状态 |
|----|------|
| Stage | **M-band**（2026-08-28）：`IWindowHost` + `WindowPumpOnce/PumpAll` + dispatcher 32cap + `test_window_host` 7用例，`bench_dispatcher` 391µs/1000，`make focused` 13门禁全绿 |
| 源码 | `core/src/nextpas.core.window.{base,intf,fake,factory,wasm.ffi,wasm.loader,wasm,gtk.ffi,gtk.loader,gtk,sdl2.ffi,sdl2.loader,sdl2,win32.ffi,win32.loader,win32,cocoa.ffi,cocoa.loader,cocoa,android.ffi,android.loader,android,uikit.ffi,uikit.loader,uikit}.pas + window.pas`（S1-M-band） |
| Registry | 已进入：`window` L2 draft（`core/docs/core-module-registry.md` 一行） |
| **NEXT** | **M-band**（维护带常驻；13门禁绿，PERF 基线 391µs） |

---

## 3. 分波实施图

### S1 — 契约 + fake 家族（首个 source family）

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-27)** — 5 单元 + 4 门禁 + registry 同批落地；`make focused` 全绿, `source-contract=pass`, `hygiene=pass` |
| **Do** | ①`window.base`（kinds/options/event/句柄别名/错误族 + Check 校验）；②`window.intf`（IWindow/IWindowDispatcher/回调命名类型）；③`window.fake`（注入事件、PumpOnce/PumpAll、状态脚本、假句柄）；④`window.factory`（注册表/TWindowBuilder/RunLoop 对/能力探测）；⑤门面 re-export；⑥契约测试套件（全走 fake）；⑦source-contract 扫描扩展（INV-3/4/5）；⑧registry 条目同批进入 |
| **Don't** | 不建任何生产后端单元（gtk.ffi 也不要）；不做 Deferred 登记簿里任何能力；不动 webview/gpu 任何文件 |
| **Done when** | 契约测试覆盖 CONTRACT §8 首行清单全项且绿；source-contract 门禁含 window 规则且绿；registry 行存在且架构门禁接受；`make hygiene` 干净 |
| **Gates** | `make focused FOCUS=core/tests/nextpas.core.window/<gate>` 全绿；source-contract gate；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.window*.pas`；`core/tests/nextpas.core.window/**`；`core/docs/window/**`；`core/docs/core-module-registry.md`（仅 registry 一行）；`tests/architecture/source_contracts/`（window 扫描段） |
| **风险与兜底** | FPC 匿名回调/interface 细节踩坑 → 先落最小接口骨架再扩；factory 探测顺序定案争议 → 按"平台原生 > wasm > gtk > sdl2"冻结并在测试钉死（S2a） |

### S2a — WASM kind + ffi（抽象不束缚补齐，小步增量）

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-28)** — `wkWasm` 入枚举（`High-1`）、`window.wasm.ffi` 5 导入存根（`emscripten_*`）、`factory` 探测序与 `ParentHandle` attach 语义扩展、诚实表 wasm 列、测试 kind 序 + attach 友好、`ABSTRACT_DESIGN` §7-8 补 directui/game/wasm 正交性 |
| **Do** | ①`window.base` 加 `wkWasm`；②`window.wasm.ffi`（无逻辑无 external）；③`window.factory` 探测序/ParentHandle 集；④`CONTRACT`/`ARCHITECTURE`/`ABSTRACT_DESIGN` 诚实表与正交性补齐；⑤测试增量；⑥`source-contract` 扩展 wasm |
| **Don't** | 不建 `wasm.loader/.wasm` 生产后端；不加 `TWindowOptions` 字段；不触 `webview/gpu` |
| **Done when** | `wkWasm` 在 `High-1` 且探测序含 wasm；`ParentHandle` 桌面拒、attach（含 wasm）接受；诚实表 wasm 行可审；4 门禁全绿 |
| **Gates** | `make focused` 4 门禁绿；`source-contract=pass`；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.window*.pas`；`core/tests/nextpas.core.window/**`；`core/docs/window/**` |
| **风险与兜底** | wasm 后端真实实现缺位 → 仅 ffi 存根 + `WindowBackendAvailable=False` 诚实降级，强 Build 抛 `ecNotFound` |

### S2 — GTK 后端抽取（受控跨模块 slice）

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-28)** — `window.gtk.ffi` 子集 ABI + `gtk.loader` 独立探测（libgtk/gobject/glib）+ `window.gtk` 机械抽取（映射表 ARCHITECTURE §2.1，IEEE 屏蔽原样）+ 6 信号挂接（delete/configure/focus-in/out/scale/state/destroy）+ `g_idle_add_full` dispatcher + `test_window_gtk_runtime` 探测式 3 用例；5 门禁全绿，`NEXTPAS_WINDOW_GTK_REQUIRED` 开关，bench 推 S3 |
| **Do** | ①`window.gtk.ffi` 窗口子集 ABI；②`window.gtk.loader` 独立 dlopen/绑定；③`window.gtk` 机械抽取+信号（delete→weCloseRequested, configure→weResized, focus→weFocus*, scale→weScaleChanged）；④`factory` 探测/创建/RunLoop 接管；⑤`test_window_gtk_runtime` + 5 门禁 |
| **跨模块说明** | **原因**：抽取是既定反哺路线（webview CONTRACT §1.1），webview 首受益。**范围**：读 `webview.gtk.win` 为源，不改 webview 生产代码（双份共存，S4 去重）。**风险**：webview 并行漂移 → 以 f961037 为基准。**额外验证**：`test_window_factory` 探测式容忍无显示；`test_window_gtk_runtime` Xvfb 往返 |
| **Don't** | 不改 `IWebviewWindow`；不做组合注入收口；不动 webview ffi/loader |
| **Done when** | 加载探测与诚实降级可测；冒烟 Xvfb 下 title/bounds/scale/close/dispatcher 往返绿，CI 无显示 SKIP；`factory` 5 门禁 + hygiene 全绿 |
| **Gates** | `make focused` 5 门禁绿；`git diff --check`；`make hygiene` |
| **Land paths** | `core/src/nextpas.core.window.gtk*.pas`；`core/src/nextpas.core.window.factory.pas`；`core/tests/nextpas.core.window/test_window_gtk_runtime/**`；`core/tests/nextpas.core.window/**`；`core/docs/window/**` |
| **风险与兜底** | 无显示 → SKIP + REQUIRED 开关；回调生命周期 → owner 指针 + Disconnect 清扫 + dispatcher DropAll |

### S3 — SDL2 后端

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-28)** — `window.sdl2.ffi`（SDL2 窗口子集 ABI，无 external）+ `sdl2.loader`（libSDL2 dlopen，DisplayScale 可选）+ `window.sdl2`（窗口壳/事件泵/用户事件 dispatcher/WMInfo Honest nil on Wayland）+ `test_window_sdl2_runtime` 探测式 3 用例全绿；`factory` 探测/创建/RunLoop 接管；`bench_dispatcher` + `test_window_stress` 同批落地补齐 S2 延期债务 |
| **Do** | `window.sdl2.ffi/.loader/.sdl2`：SDL_CreateWindow 族、事件泵（SDL_PollEvent → TWindowEvent 映射：close→weCloseRequested/resized→weResized/moved→weMoved/focus→weFocus*）、用户事件 dispatcher（SDL_RegisterEvents+SDL_PushEvent+互斥环）、WMInfo 句柄化（X11/HWND/Cocoa/Wayland nil）、DisplayScale 可选；game888 复用评估文档化 |
| **跨模块说明** | **原因**：game888 私有 SDL2 窗口是第三个收敛目标，S3 底座即其复用前置（ROADMAP §1 北极星）。**范围**：仅新增 window sdl2 三件套与 runtime 测试，不改 game888 仓库。**风险**：SDL2 多驱动差异（X11/Wayland/Windows/Cocoa）→ WMInfo 诚实表已冻，CI 无 SDL2 时 SKIP+REQUIRED 开关兜底。**额外验证**：`test_window_factory` 探测式改造（gtk/sdl2 双探针）+ `test_window_sdl2_runtime` + `test_window_stress` + bench 基线 + hygiene 全绿 |
| **Don't** | 不做渲染/音频等 SDL 其余子系统；不让 sdl2 后端依赖 gtk 任何单元 |
| **Done when** | 加载探测与诚实降级可测；冒烟创建→title/bounds/maximize→scale读取→dispatcher wake→close幂等多窗 Xvfb/dummy 下绿，CI 无 SDL2 SKIP；诚实表 sdl2 列复核；`test_window_stress` 并发 4×2000 全绿；`bench_dispatcher` 基线落盘 |
| **Gates** | `make focused` 7 门禁绿（source-contracts+base+fake+factory+gtk_runtime+sdl2_runtime+stress）+ `bench_dispatcher` + compile-only（非 Linux 语法级） + `git diff --check` + `make hygiene` |
| **Land paths** | `core/src/nextpas.core.window.sdl2*.pas`；`core/src/nextpas.core.window.factory.pas`；`core/tests/nextpas.core.window/test_window_sdl2_runtime/**`；`core/tests/nextpas.core.window/test_window_stress/**`；`core/benchmarks/nextpas.core.window/bench_dispatcher/**`；`core/tests/nextpas.core.window/test_window_factory/**`（探测式改造）；`core/tests/nextpas.core.window/Makefile`；`core/docs/window/**` |
| **风险与兜底** | SDL2 <2.24 无 display scale → 诚实回退 1.0（已实现，可选符号）；CI 无 SDL2 → SKIP + REQUIRED 开关；窗口句柄 Wayland nil 诚实表已冻；dispatcher 全局互斥环 FIFO，GDestroying 兜底关闭期投递丢弃 |

### S4 — Win32 / Cocoa 后端（与 webview Wave 2/3 协同）

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-28)** — `window.win32.ffi/.loader/.win32`（user32/kernel32 dlopen，WM_CLOSE/SIZE/MOVE/FOCUS/DPICHANGED→TWindowEvent，message-only PostMessage dispatcher）+ `window.cocoa.ffi/.loader/.cocoa`（libobjc/libdispatch/AppKit 探测，纯 C objc_msgSend 无需 objectivec1，dispatch_async 唤醒）+ factory 注册表重构（BACKENDS 8 项统一收敛，InitBackends 懒初始化），`test_window_{win32,cocoa}_runtime` 各 2 用例（Linux 诚实 SKIP，REQUIRED 开关，compile-only 门禁）+ `test_window_factory` 双探针扩展（win32/cocoa） |
| **跨模块说明** | **原因**：避免两套后端各养一份 Win32/Cocoa 窗口缝（webview §1.1(b) 既定触发；本波先完成 window 侧 compile-only 诚实底座，webview Wave 2/3 组合切换随各自 wave 再收口，避免中途打断 webview lane）。**范围**：仅新增 window win32/cocoa 三件套与 runtime 测试 + factory 注册表重构，不改 webview 生产代码（双份共存，S5 再评估去重）。**风险**：Windows runner 缺位、stage0 不支持 objectivec1 → 纯 C 形态 + Linux compile-only + 探测 SKIP 为最低证据线，ROADMAP 如实记录 residual。**额外验证**：`test_window_factory` 4 探针（gtk/sdl2/win32/cocoa）+ `test_window_{win32,cocoa}_runtime` + 9 门禁 + hygiene 全绿 |
| **Do** | `window.win32.ffi`（HWND/MSG/WNDCLASSEX 等 + 函数指针）、`win32.loader`（user32/kernel32 dlopen，GetDpiForWindow 可选）、`window.win32`（RegisterClass/CreateWindowEx/WndProc→TWindowEvent，GWLP_USERDATA 路由，WM_GETMINMAXINFO 约束，message-only dispatcher）；`window.cocoa.ffi`（id/SEL/Class_ + objc_msgSend/libdispatch）、`cocoa.loader`（libobjc/libdispatch/AppKit 探测）、`window.cocoa`（NSWindow 纯 C 占位 + dispatch_async 队列）；factory 注册表重构 |
| **Don't** | 不做 rendering/输入等扩展；不让 win32/cocoa 依赖 gtk/sdl2 |
| **Done when** | 加载探测与诚实降级可测；Linux 上 `WindowWin32IsAvailable=False`/`WindowCocoaIsAvailable=False` → Build 抛 `ecNotFound`，create 探测 SKIP；compile-only 通过；factory 4 探针全绿；9 门禁 + hygiene 全绿；webview 回归推迟到 Wave 2/3 时再验（本波仅保证 window 侧不破坏 webview 编译） |
| **Gates** | `make focused` 9 门禁绿（source-contracts+base+fake+factory+gtk_runtime+sdl2_runtime+win32_runtime+cocoa_runtime+stress）+ compile-only + `git diff --check` + `make hygiene` |
| **Land paths** | `core/src/nextpas.core.window.{win32,cocoa}.ffi.pas`；`core/src/nextpas.core.window.{win32,cocoa}.loader.pas`；`core/src/nextpas.core.window.{win32,cocoa}.pas`；`core/src/nextpas.core.window.factory.pas`（注册表重构）；`core/tests/nextpas.core.window/test_window_{win32,cocoa}_runtime/**`；`core/tests/nextpas.core.window/test_window_factory/**`；`core/tests/nextpas.core.window/Makefile`；`core/docs/window/**` |
| **风险与兜底** | Linux 无 user32/AppKit → 诚实 `Loaded=False` + `REQUIRED` 开关；Win32 dispatcher 用隐藏 message-only 窗口，避免与业务窗口混；Cocoa 用 `dispatch_async_f` 纯 C 回调，避免 block 捕获；stage0 无 objcclass → 纯 C 形态，残差记录 |

### S5 — Mobile attach（android / uikit）+ wasm loader 实装

| 字段 | 内容 |
|------|------|
| **Status** | **done (2026-08-28)** — `window.wasm.loader/.wasm`（canvas attach 实装：CSS×ratio 物理，Min/Max no-op，Supports+NativeHandle，dispatcher 环）+ `window.android.ffi/.loader/.android`（ANativeWindow attach 只读几何）+ `window.uikit.ffi/.loader/.uikit`（UIWindow attach 只读）+ factory 8 后端全收敛（探测/创建/Live/Run/Quit 统一），`test_window_{wasm,android,uikit}_runtime` 各 3 用例（Linux 诚实 SKIP + attach 友好/ParentHandle 必需 + 只读几何）+ `test_window_factory` 7 探针（gtk/sdl2/win32/cocoa/wasm/android/uikit） |
| **Do** | `window.wasm.ffi/.loader/.wasm` 收口（emscripten env import 5 个，devicePixelRatio 可选，CSS/物理双口径）；`window.android.ffi/.loader/.android`、`window.uikit.ffi/.loader/.uikit` attach 最小面；factory 注册表接入 wasm/android/uikit `Probe/Create/Live/Run/Quit`；RunLoop 混合泵扩展 Live 全后端；`ParentHandle` 桌面拒 4 种、attach 友好 3 种 |
| **Don't** | 不做 Activity/UIApplication 托管（宿主模型归 app 层）；不做 top-level 创建伪装；不做 wasm `requestAnimationFrame` 真绑定（当前同步 Drain，host loop `RAF` 衔接留给 `webview.wasm`） |
| **Done when** | 加载探测与诚实降级可测；Linux 上 `Wasm/Android/UIKitIsAvailable=False` → Build 抛 `ecNotFound` 或 `Unsupported`（ParentHandle 缺失）；attach 路径诚实表 mobile/wasm 列复核；12 门禁 + hygiene 全绿 |
| **Gates** | `make focused` 12 门禁绿（source-contracts+base+fake+factory+gtk/sdl2/win32/cocoa/wasm/android/uikit+stress）+ compile-only + `git diff --check` + `make hygiene` |
| **Land paths** | `core/src/nextpas.core.window.{wasm,android,uikit}*.pas`；`core/src/nextpas.core.window.factory.pas`（注册表 8 后端）；`core/tests/nextpas.core.window/test_window_{wasm,android,uikit}_runtime/**`；`core/tests/nextpas.core.window/test_window_factory/**`；`core/tests/nextpas.core.window/Makefile`；`core/docs/window/**` |
| **风险与兜底** | Linux 无 libandroid/libUIKit/emscripten → 诚实 `Loaded=False` + `REQUIRED` 开关；ANativeWindow/UIWindow 指针生命周期归宿主，`Close` 不销毁；wasm `devicePixelRatio` 缺席回退 1.0；`SetBounds` 在 attach/wasm 上 no-op 已冻表 |

### M-band — 维护带（永续兜底）

Era 全堵时的合法工作池：doc-truth 对齐、flake 修复、诚实表复核刷新、
机械抽取收尾、门禁拆分。禁止：新公开 API 家族、Deferred 提前实现、
宣称升级。

---

## 4. 硬约束

- 每波 land 必须回写本文件（Status/NEXT/changelog 一行）。
- 正确性 gate 红 → 该波整波回滚，不带红 landing。
- 跨模块波次必须有原因/范围/风险/额外验证四要素（S2/S4 已示范）。
- registry 只在首个 source family 同批进入，文档先行不抢跑。

---

## 5. 变更日志

| 日期 | 变更 |
|------|------|
| 2026-08-28 | M-band 去消息化+宿主泵：`IWindowHost` + `WindowPumpOnce/PumpAll` + dispatcher 32cap + `test_window_host` 7用例 + bench 391µs/1000；13门禁全绿；NEXT=M-band 维持 |
| 2026-08-28 | S5 mobile attach 落地：`wasm/android/uikit .ffi/loader/pas` 全接入 factory 8 后端 + `test_window_{wasm,android,uikit}_runtime` 各 3 用例；12 门禁全绿；NEXT=M-band |
| 2026-08-28 | S4 win32/cocoa 落地：`win32/cocoa .ffi/loader/pas` + factory 注册表 8 后端收敛 + `test_window_{win32,cocoa}_runtime`；9 门禁全绿；NEXT=S5 |
| 2026-08-28 | S3 sdl2 落地：`sdl2.ffi/loader/sdl2` + 用户事件 dispatcher + WMInfo/DisplayScale + `test_window_sdl2_runtime` + `test_window_stress` + `bench_dispatcher`；7 门禁全绿；NEXT=S4 |
| 2026-08-28 | S2 gtk 落地：`gtk.ffi/loader/gtk` + 6 信号/dispatcher + factory 接管 + `test_window_gtk_runtime` 3 用例；5 门禁全绿；NEXT=S3 |
| 2026-08-28 | S2a wasm 增量：`wkWasm` + `wasm.ffi` + 探测序/ParentHandle/诚实表扩展 + directui/game 不束缚抽象补齐；4 门禁全绿；NEXT=S2 gtk |
| 2026-08-27 | S1 family 落地：5 单元（base/intf/fake/factory/门面）+ 4 门禁 + registry；INV-3/4/5 全绿；NEXT=S2 |
| 2026-08-26 | S0 文档 slice 落地：四件套进 `core/docs/window/`；NEXT=S1 |
