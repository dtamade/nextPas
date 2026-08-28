# nextpas.core.window — 终局路线图 (Final → 1.0)

> **定位**：`window` 是 `webview / gpu / directui / game888` 共享的 L2 窗口家族，当前 `M-band` 已完成 S1→S5 + 去消息化 (`IWindowHost / WindowPumpOnce`) + O(1)/inline/Diagnostics + 共享 queue/live 去重 + `gtk2/3/4 + qt5pas/qt` 家族化 + RTL 解耦 (`text.ansi / diagnostics`)。本文件是**从 M-band 到 1.0 生产态**的唯一执行路线图，追求**性能·高级感·复用度·稳定性·完整性**五维收敛。
>
> **Authority**：`CONTRACT.md` 定义契约；`ARCHITECTURE.md` 定义分层与线程模型；`ABSTRACT_DESIGN.md` 定义抽象不束缚原则；`ROADMAP.md` 记录已落地 S 波次；本文件只规划**未落地**的终局路径。

---

## 0. 判定标准 — 何谓 1.0

| 维度 | 1.0 定义 | 当前 (M-band) | 差距 |
|------|----------|---------------|------|
| **性能** | `bench_dispatcher` 7 项在 CI 三机 (Linux/Win/mac) 方差 <5%，`PostSingle <400µs/1000`、`ZeroPump <20ns`、`LiveCount <500µs` 基线固化，热路径全 inline 且零分配 | Linux 单机 365/271/443µs 已固化，5×中位方差 5-7% 收敛，未跨机 | **F3 已固化 Linux，残差 Win/mac compile-only** |
| **高级感** | `base/intf/loader/门面` 四件套零循环依赖；`TWindowQueue`/`TWindowLiveRegistry`/`TWindowDispatcherBase` 三共享设施覆盖 8 后端；`gtk.impl.inc` 719 行共享 + 77/108 薄包装，`factory BACKENDS[8]` 单点真相 | queue/live/gtk共享已完成，dispatcher base 审计结论“保持独立” | **F1 已收口** |
| **复用度** | `directui` 与 `game888` 各有一个可运行的 `PumpOnce` 消费示例（不阻塞 RunLoop），`webview` 已切 `window.gtk3` 单源 | 直接示例已落地（demo_directui/game_pump），webview F4 阶段 1 纪律对齐 | **F2 已实证，F4 阶段 1 纪律收口** |
| **稳定性** | 13 门禁在三机均绿，`heaptrc 0` 泄漏，`host` 线程亲和 marshal，`INV-3/4/5 + INV-RTL` 全拦 | Linux 13 门全绿（8+5），heaptrc 0，host 已 marshal | **F3 Linux 全绿，阶段 2 补三机** |
| **完整性** | `CONTRACT §2` 8 后端 + 3 家族 (`gtk2/3/4/qt`) 诚实表可审，`Deferred` 登记簿无占位，`factory Probe/Create/Live/Run/Quit` 五件套与 `WindowBackendDiagnostics` 诊断链完整 | 8 后端 + 家族 + Diagnostics 全落地，webview 纪律 1.0 收口 | **F4 阶段 1 完整，阶段 2 单源化 1.1** |

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
- **复用设施**：`TWindowQueue` (32cap 环形 + `CreateEvent` 唤醒) 6 后端共享；`TWindowLiveRegistry` 7 后端共享；`gtk.impl.inc` 719 行共享实现。
- **家族化**：`nextpas.core.gtk3/4/2` 独立 L2（`base/ffi/loader` 单向 `platform.dl`），`qt5pas/qt` 同理；`factory` 智能回退 `gtk4>gtk3>gtk2`，`BACKENDS[8]` 探测序 `win32>cocoa>android>uikit>wasm>gtk>sdl2>fake`。
- **RTL 解耦**：`text.ansi (StrToAnsi/AnsiPtrToStr/HoldAnsi)`、`diagnostics (TDiagnosticsBuilder)` L1 已落地，`window.gtk/sdl2/win32/wasm` 标题、`factory diagnostics`、`audio.mix` 的 `Math` 直引已反哺 `nextpas.core.math`。
- **门禁**：13 门（`source-contracts/base/fake/factory/gtk_runtime/sdl2_runtime/win32_runtime/cocoa_runtime/wasm_runtime/android_runtime/uikit_runtime/stress/host`）Linux 全绿，`heaptrc 0`，`make hygiene` pass。

---

## 3. 终局分波 (F 波 = Final)

### F1 — 硬化雕刻 (Hardening · 1 周) — **当前 NEXT**

| 目标 | 任务 | 产出 | 验证 |
|------|------|------|------|
| 去重收口 | 若审计确认收益，抽取 `TWindowDispatcherBase` (owner 线程 + `Post` 三重载 + `Track/DropAll`) 统一 8 后端 dispatcher 外壳；否则文档化“不抽取”决策 | `window.dispatcher.base.pas` 或 ADR | `source-contracts` 不新增循环依赖 |
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

### F4 — Webview 抽取收口 (Extraction Close · 1 周，与 webview Wave 2/3 协同) — **阶段 1 已落地**

| 现状 | 动作 | 产出 | 状态 |
|------|------|------|------|
| `webview.gtk.win` 与 `window.gtk` 双份共存 | `webview.gtk` 改 `CreateWindowGtk`/`WindowGtkIsAvailable` 消费 `window`，删除 `webview.gtk.win` 冗余实现；`gpu.gl` 同理若有窗口缝 | `core/src/nextpas.core.webview.gtk.pas` 单源，`window` 单点变更即影响 `webview` | **阶段 2 待 window 暴露 raw shell API** |
| `webview.gtk.win` RTL 违纪 | `Math` → `nextpas.core.math`，`PAnsiChar(AnsiString)` → `StrToAnsi`/`nextpas.core.text.ansi` 纪律对齐 | 与 `window.gtk.impl.inc` 同纪律，`INV-RTL` pass | **阶段 1 已落地 (2026-08-28)** |
| `webview` Wave 2/3 的 `win32/cocoa` 同理 | 同步切换，双端 `focused` 互验 | Land paths 显式 `core/src/nextpas.core.webview.*` + `core/src/nextpas.core.window.*`，`Needs Review` | **阶段 2 与 Wave 2 间隙协同** |

**风险**：`webview` 漂移 → 以本分支 `HEAD` 为基，`path-limited replay` 到 `main`，不 raw merge。
**F4 阶段 1 决策**：`webview.gtk.win` 保持独立薄壳（FPU 屏蔽+Ansi 纪律已对齐），全量单源化需 `window.gtk3` 先暴露 `RawCreate/Title/Geometry` 的低阶壳 API（返回 `Pointer GtkWindow*` 供 `gtk_container_add`），避免 `webview` 被迫经 `IWindow` 高阶抽象嵌入 WebKit；该 API 属 `window` 1.1 `RawShell` 登记，1.0 不强行耦合。

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
| `bench` 方差 >5% | 固定 `cpufreq` + `isolcpus` + 5 次中位 | 回滚该波 inline/队列改动 |

---

## 6. 下一步 (Immediate NEXT = F4 阶段 2 → F5)

1. **F4 阶段 2（window 1.1 预研）**：为 `window.gtk3` 增 `WindowGtkRawShell` 低阶 API（`Create/Title/Geometry/Show/Hide/Scale/Native` 返回 `Pointer`），使 `webview.gtk.win` 可退化为 `deprecated shim` 单源转发，`webview.gtk` 消费 `window.gtk3.RawCreate` + `gtk_container_add`。
2. **F5 定版**：`CONTRACT §8` 覆盖率 100%，`ARCHITECTURE` 家族布局与 `F4` 后一致，`README` 能力表三段一致；`core-module-registry` `focused-runtime → ci-matrix`（Linux-only 标注残差），`git tag window-1.0`。
3. ** hygiene 终验**：`make focused 13门 + make hygiene + git diff --check` 全绿 → `Ready` 提 `F4 阶段 1`（跨模块需 `Needs Review` 四要素）。
