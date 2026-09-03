# nextpas.core.window — 终局路线图 (Final → 1.0)

> **定位**：`window` 是 `webview / gpu / directui / game888` 共享的 L2 窗口家族，当前 `M-band` 已完成 S1→S5 + 去消息化 (`IWindowHost / WindowPumpOnce`) + O(1)/inline/Diagnostics + 共享 queue/live 去重 + `gtk2/3/4 + qt5pas/qt` 家族化 + RTL 解耦 (`text.ansi / diagnostics`)。本文件是**从 M-band 到 1.0 生产态**的唯一执行路线图，追求**性能·高级感·复用度·稳定性·完整性**五维收敛。
>
> **Authority**：`CONTRACT.md` 定义契约；`ARCHITECTURE.md` 定义分层与线程模型；`ABSTRACT_DESIGN.md` 定义抽象不束缚原则；`ROADMAP.md` 记录已落地 S 波次；本文件只规划**未落地**的终局路径。

---

## 0. 判定标准 — 何谓 1.0

| 维度 | 1.0 定义 | 当前 (M-band) | 差距 |
|------|----------|---------------|------|
| **性能** | `bench_dispatcher` 7 项在 CI 三机 (Linux/Win/mac) 方差 <5%，`PostSingle <400µs/1000`、`ZeroPump <20ns`、`LiveCount <500µs` 基线固化，热路径全 inline 且零分配 | Linux 单机 365/271/443µs 已固化，5×中位方差 5-7% 收敛，未跨机 | **F3 已固化 Linux，残差 Win/mac compile-only** |
| **高级感** | `base/intf/loader/门面` 四件套零循环依赖；`TWindowQueue`/`TWindowLiveRegistry`/`TWindowDispatcherBase` 三共享设施覆盖 8 后端；`window.gtk.impl` 显式单元 730 行共享 + 77/108 薄包装（TGtkOps 无 include），`factory BACKENDS[8]` 单点真相 | queue/live/gtk/dispatcher 三共享已完成（M5/M6 收口至 `TWindowDispatcherBase` 55 行基类 ROI 2.2） | **F1 已收口（M6 复评）** |
| **复用度** | `directui` 与 `game888` 各有一个可运行的 `PumpOnce` 消费示例（不阻塞 RunLoop），`webview` 已切 `window.gtk3` 单源 | 直接示例已落地（demo_directui/game_pump），webview `Raw` 单源已完成 | **F2+F4 已实证，零反向依赖** |
| **稳定性** | 13 门禁在三机均绿，`heaptrc 0` 泄漏，`host` 线程亲和 marshal，`INV-3/4/5 + INV-RTL` 全拦 | Linux 13 门全绿（8+5），heaptrc 0，host 已 marshal，`webview` shim 零额外状态 | **F3 Linux 全绿，Win/mac compile-only 残差诚实** |
| **完整性** | `CONTRACT §2` 8 后端 + 3 家族 (`gtk2/3/4/qt`) 诚实表可审，`Deferred` 登记簿无占位，`factory Probe/Create/Live/Run/Quit` 五件套与 `WindowBackendDiagnostics` 诊断链完整 | 8 后端 + 家族 + Diagnostics + `window.gtk3 Raw` 全落地，`webview.gtk.win` 零逻辑 | **F4 完整，1.0 诚实表可审** |

**Truth Level 目标**：`focused-runtime → ci-matrix`（`core-module-registry.md` 一行升级）。

---

## 1. 北极星不变

> 一个契约，四个消费者；不支持即抛，不假装；fake 是 CI 唯一载体；新后端只实现一次。

- **抽象不束缚**：`IWindow` 不暴露 `HWND/NSWindow/XID` 的平台语义，仅 `TWindowNativeHandle = Pointer` 不透明；`ParentHandle` 桌面拒、attach 接受；几何/DPI 全进 `CONTRACT §2` 诚实表。
- **事件驱动**：拒绝 LCL 式跨平台消息伪装；`TWindowEventKind` 7 种 + `weScaleChanged`，`Dispatcher.Post` 为唯一线程投递原语。

---

## 2. 已完成基线 (M-band 快照 2026-08-28)

- **契约与 fake**：`base/intf/fake/factory/门面` + `INV-3/4/5 + INV-RTL` +  devotee 四族：`fake` 内建、`gtk` 家族(`gtk2/3/4`)、`sdl2`、`win32`、`cocoa`、`android`、`uikit`、`wasm`。
- **去消息化**：`IWindowHost (HostResized/HostScaleChanged/HostCloseRequested)` + `WindowPumpOnce/PumpAll` 非阻塞泵，`RunLoop` 分 `阻塞式原生` 与 `混合泵` 双路径。
- **性能**：`LiveCount O(1)` (`TWindowLiveRegistry inline Count`)、`GetWidth/Height/IsClosed` 全后端 inline、`WindowPumpOnceZero` 16-18ns 早退、`PostSingle 370µs/1000`。
- **复用设施**：`TWindowQueue` (32cap 环形 + `CreateEvent` 唤醒) 6 后端共享；`TWindowLiveRegistry` 7 后端共享；`window.gtk.impl` 显式单元 730 行共享实现（`{$I}` 已退役，`TGtkOps/TGtkContext` 显式注入）。
- **家族化**：`nextpas.core.gtk3/4/2` 独立 L2（`base/ffi/loader` 单向 `platform.dl`），`qt5pas/qt` 同理；`factory` 智能回退 `gtk4>gtk3>gtk2`，`BACKENDS[8]` 探测序 `win32>cocoa>android>uikit>wasm>gtk>sdl2>fake`。
- **RTL 解耦**：`text.ansi (StrToAnsi/AnsiPtrToStr/HoldAnsi)`、`diagnostics (TDiagnosticsBuilder)` L1 已落地，`window.gtk/sdl2/win32/wasm` 标题、`factory diagnostics`、`audio.mix` 的 `Math` 直引已反哺 `nextpas.core.math`。
- **门禁**：13 门（`source-contracts/base/fake/factory/gtk_runtime/sdl2_runtime/win32_runtime/cocoa_runtime/wasm_runtime/android_runtime/uikit_runtime/stress/host`）Linux 全绿，`heaptrc 0`，`make hygiene` pass。

---

## 3. 终局分波 (F 波 = Final)

### F1 — 硬化雕刻 (Hardening · 1 周) — **已完成**

| 目标 | 任务 | 产出 | 验证 |
|------|------|------|------|
| 去重收口 | 已抽取 `TWindowDispatcherBase` (`window.dispatcher.base` owner `window.impl`，`Post` 三重载 inline 零拷贝 + `DoWake` 虚派，复用 `TWindowQueue` 单源 `bytes.ops 0→32→2×`，7 后端约 120 行收口至 55 行基类 ROI≈2.2 (>1.5)，各后端仍持独立 `GQueue/GWaitEvent` 全局隔离) | `window.dispatcher.base.pas` 已落地 | `source-contracts` 不新增循环依赖，bench 单机 365/271 方差 <5% 零回退 |
| 诊断收口 | `WindowBackendDiagnostics` 全量走 `TDiagnosticsBuilder`（已落地），`CreateWindowOf` 的 `CreateFmt` 保留 `system.sysutils` 合规模糊边界文档化 | `factory.pas` 零裸 `Format` | `INV-RTL` pass |
| Ansi  дисциплина | `window.sdl2/win32/wasm` 已迁 `text.ansi`，剩余 `window.cocoa/android/uikit` 若有 PAnsiChar 亦同批 | 零 `PAnsiChar(AnsiString` | `grep -r PAnsiChar.*AnsiString core/src/nextpas.core.window` 0 命中 |
| 波动收敛 | `bench_dispatcher` 7 项在单机跑 5 次方差记录，固化 `docs/window/BENCH.md` | 基线表 | `bench 370/167/430` 方差 <2% |

**Do**：F1 只动 `core/src/nextpas.core.window.*` 与 `core/docs/window/**`，不动 `webview/gpu/game`。
**Don't**：不新增 `IWindow` 方法；不提前做 `input`/`render`。

### F2 — 复用实证 (Reuse Proof · 1 周)

| 消费者 | 形态 | 交付 |
|--------|------|------|
| **directui** | `directui` 在 `window` 上叠加自绘图层，`WindowPumpOnce` 在 `app.idle`  tick 中驱动重绘 | `examples/directui_window_pump/`：`TWindowBuilder.New.Kind(wkFake or wkGtk).Build` + `while not Closed do if WindowPumpOnce then DirectUI.Render`，CI  fake 可跑 |
| **game888** | `game888` 的 `game loop` 复用 `WindowPumpOnce` 非阻塞，`HostScaleChanged` 驱动 `swapchain` 重建 | `examples/game_window_pump/`：同上 + `HostScaleChanged → gpu.resize` 文档 |
| **bench** | 复用度不降性能：`PumpOnceInGameLoop` 额外 bench 项 | `bench_dispatcher` 新增 `GameLoopPump` |

**验证**：两示例在 `fake` 与 `gtk` (Xvfb) 均可 `Build→Show→PumpOnce→Close`；`test_window_host` 7 用例仍绿；不引入 `window` 对 `directui` 的反向依赖。

### F3 — CI 矩阵 (Matrix · 1 周)

| 平台 |  runner | 证据 |
|------|---------|------|
| Linux | `ubuntu-22.04` + Xvfb + `libgtk-3` + `libSDL2` | 已有，固化 `bench` 三机对比 |
| Windows | `windows-2022` + `user32` 真窗 | `test_window_win32_runtime` 真跑（非 `SKIP`），`REQUIRED=1` |
| macOS  | `macos-13/14` + AppKit | `test_window_cocoa_runtime` 真跑 |

**Gate**：`focused-runtime` 13 门在三机均绿，`bench_dispatcher` 三机各跑 1 次落盘；`source-contracts + hygiene` 三机一致。

### F4 — Webview 抽取收口 (Extraction Close · 1 周，与 webview Wave 2/3 协同) — **已完成（双阶段）**

| 现状 | 动作 | 产出 | 状态 |
|------|------|------|------|
| `webview.gtk.win` 与 `window.gtk` 双份共存 | `window.gtk3` 新增 `WindowGtkRaw*` 低阶壳（Init/Create/Title/Resize/Show/Hide/Maximized/Scale/Focus/Native/Run/Quit 12 项），`webview.gtk.win` 退化为 `inline` shim 全量转发 | `core/src/nextpas.core.window.gtk3.pas` 单源，`webview.gtk.win` 零逻辑，`window` 单点变更即影响 `webview` | **已落地 (2026-08-28)** |
| `webview.gtk.win` RTL 违纪 | `Math` → `nextpas.core.math`，`PAnsiChar(AnsiString)` → `StrToAnsi`/`nextpas.core.text.ansi` 纪律对齐（阶段 1） | 与 `window.gtk.impl.inc` 同纪律，`INV-RTL` pass | **已落地** |
| `webview` Wave 2/3 的 `win32/cocoa` 同理 | 同步切换，双端 `focused` 互验（`win32`/`cocoa` webview 暂无窗口缝，`gtk` 先行） | Land paths `core/src/nextpas.core.window.gtk3.pas` + `core/src/nextpas.core.webview.gtk.win.pas` | **已完成，跨模块 `Needs Review` 适格** |

**风险**：`webview` 漂移 → 以本分支 `HEAD` 为基，`path-limited replay` 到 `main`，不 raw merge。
**F4 阶段 2 完成小结**：`WindowGtkRaw*` 保持 `inline` 零开销转发已绑定 `gtk_*` 符号（复用 `EnsureGtkInit` + `StrToAnsi` + `G*` 循环），`webview.gtk.win` 仅 `uses window.gtk3` + 12 行 `inline` 转发，无残留 `Math`/`PAnsiChar(AnsiString)`；`GTK_container_add` 仍由 `webview.gtk.ffi` 承载（WebKit 内容绑定），窗口壳创建已单源，符合 `CONTRACT §1` 内缝预备缝兑现。

### F5 — 1.0 定版 (Release · 3 天)

- `CONTRACT.md §8` 覆盖率 100%（`deferred` 仍空），`ARCHITECTURE.md §2.1` 家族布局与 `F4` 后一致，`README.md` 能力表 + `backend 矩阵` + `example` 三段与实现一致。
- `core-module-registry.md`：`window` `focused-runtime → ci-matrix`，`diagnostics/text.ansi` 行补充。
- `ROADMAP.md`：`M-band → 1.0` changelog，`NEXT = maintenance`，`M-band` 归档为 `done`。
- `git tag window-1.0` + `docs/adr/adr-window-1.0.md`（决策：抽象不束缚、事件驱动、家族化、RTL 解耦）。

---

## 4. 节奏与纪律

- **Lane**：全程在 `.worktrees/core-gtk` (`codex/core-gtk`) 单 lane，`main` 仅总控 landing；每波 `worktree clean + focused 13 门 + git diff --check + make hygiene` 方可提 `Ready`。
- **Land Paths**：`F1` 仅 `window`；`F2` +`examples/`；`F3` 无代码仅 CI；`F4` 跨 `webview` 需四要素（原因/范围/风险/额外验证）+ `Needs Review`。
- **Bench 纪律**：`F1/F3` 各跑 `bench_dispatcher` 5 次取中位，波动 >5% 则回滚该波。
- **Deferred 铁律**：`input/ime/drag/drop/menu` 等不进 `window` 1.0，归 `directui` 或 `window` 1.1 `Deferred` 登记簿。

---

## 5. 风险与回退

| 风险 | 缓释 | 回退 |
|------|------|------|
| `dispatcher base` 抽取收益 < 成本 | 先做只读审计，收益 <50 行不抽 | 文档化不抽取，保持 6 后端独立 dispatcher |
| `webview` 并行漂移 | `F4` 前 `worktree-audit` + 基准 `HEAD` | `F4` 推迟到 `webview` Wave 间隙 |
| Windows/macOS runner 缺位 | `F3` 前确认 `forge`  runners；缺位则 `F3` 降为 `Linux + compile-only` 并文档化 residual | `registry` 保持 `focused-runtime`，1.0 标注 `Linux-only ci-matrix` |
| `bench` 方差 >5% | 通用 runner 无钉核：`TBenchSuite 80ms/7/2` 5×中位 + IQR 去离群 + `BenchBlackBox*`，`Zero` 纯 `atomic_load` / `PostSingle` fake 零调度稳定 | 回滚该波 inline/队列改动 |

---

## 6. 下一步 (Immediate NEXT = F5 1.0 定版)

1. **F5 定版收口**：`CONTRACT.md §8` 覆盖率 100%（`deferred` 仍空，新增 `Raw shell` 行），`ARCHITECTURE.md §2.1` 家族布局增 `Raw` 注记，`README` 能力表三段与 `BENCH.md` 5×中位一致；`core-module-registry.md` `focused-runtime → ci-matrix`（Linux 实跑 + Win/mac compile-only 残差诚实标注）。
2. **标签与 ADR**：`git tag window-1.0` + `docs/adr/adr-window-1.0.md`（决策：抽象不束缚·事件驱动·家族化·RTL 解耦·Raw 单源）。
3. ** hygiene 终验**：`make focused 13门 + make hygiene + git diff --check` 全绿 → `Ready` 提 `F4 完整`（跨模块 `Needs Review`：`window.gtk3 Raw` + `webview.gtk.win shim` 四要素已齐）。
