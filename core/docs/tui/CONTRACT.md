# nextpas.core.tui 代码契约

**模块路径**：`core/src/nextpas.core.tui*.pas`（81 个源文件）
**层级**：L3（依赖 L0-L2: text, sync, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.31

---

## 概要

L3 终端 UI：双缓冲 + immediate-mode widget + 分层 facade（core / ext / experimental / full）。
默认 `nextpas.core.tui` 只保证终端正确性；app/runtime 走 `.ext`，协议能力走 `.experimental`。

**模块状态**: Maintenance Idle · 主线封板（见 [ROADMAP.md](ROADMAP.md)）。

**模块完整开发地图（北极星 / Done / 阶段）**: [ROADMAP.md](ROADMAP.md)

### Facade 控件分层（Phase B）

| Facade | 稳定控件 |
|--------|----------|
| core | Block/Paragraph/List/Table/Tabs/Scrollbar/Clear/Input |
| ext | Panel + ScrollView + Modal + Dialog + SplitPane + **Select** + Gauge/Sparkline/Canvas（PH33 P4 解禁扩面，2026-08-23）+ app/runtime |
| full | 其余 advanced catalog（migration） |

---

## 1. 接口契约

### 1.1 架构概览

```
┌──────────────────────────────────────────────────────────┐
│ Public facades                                           │
│ nextpas.core.tui | .ext | .experimental | .full          │
├──────────────────────────────────────────────────────────┤
│ App/runtime layer                                        │
│ TApp, screens, tasks, themes, panel orchestration        │
├──────────────────────────────────────────────────────────┤
│ Widget layer                                              │
│ IWidget hierarchy, basic widgets, advanced widgets       │
├──────────────────────────────────────────────────────────┤
│ Text/layout/render model                                  │
│ TText, TLayout, TBuffer, overlay, diff                   │
├──────────────────────────────────────────────────────────┤
│ Terminal/runtime truth                                    │
│ TTerminal, capability profile, ANSI backend, input       │
├──────────────────────────────────────────────────────────┤
│ Platform                                                  │
│ console, signal, time, io                                │
└──────────────────────────────────────────────────────────┘
```

**核心模块**:
- `tui.base` ← 基础类型 (TColor, TKeyEvent, TRect, TSize)
- `tui.buffer` ← 双缓冲区 (framebuffer)
- `tui.style` ← 样式系统 (bold/italic/underline/fg/bg)
- `tui.widget.*` ← 控件集合 (Block/Paragraph/List/Table/...)
- `tui.layout.*` ← 布局引擎 (VBox/HBox/Grid/Flex)
- `tui.event` ← 事件系统 (键盘/鼠标/焦点/resize)
- `tui.backend.ansi` ← ANSI 终端渲染后端
- `tui.input` ← 终端输入 (raw mode, mouse tracking)
- `tui.app` ← TApplication 主循环
- `tui.pas` ← 门面

### 1.2 核心接口（Immediate Mode）

```pascal
{ 无状态渲染契约 —— 所有 widget 的统一接口 }
IWidget = interface
  procedure Render(const AArea: TRect; ABuffer: TBuffer);
end;

{ 有状态 widget 通过专属接口的 RenderStateful 扩展 }
IXxx = interface(IWidget)
  procedure RenderStateful(const AArea: TRect; ABuffer: TBuffer;
    var AState: TXxxState);
end;

{ 事件处理在 state record 上直接调用（非接口方法） }
TXxxState = record
  function HandleKey(const K: TKeyEvent): Boolean;
  // ...
end;
```

**设计意图**:
- IWidget 仅定义渲染契约，不持有状态、不缓存渲染结果
- 有状态 widget 的 state record 类型各异，无法统一到泛型接口（FPC 限制）
- 事件处理在 state 上而非 interface 上，与 ratatui `StatefulWidget` 模式一致
- widget 不持有子引用——这是 immediate mode，不是 retained mode 控件树

**Stateful 事件约定（Phase U1）**:
1. **规范路径（新代码 / core·ext 稳定控件）**: 状态在**外部 record**；`function HandleKey(const K: TKeyEvent): Boolean`（True=已消费）；`RenderStateful(..., var AState)` 在专属接口。
2. **允许例外（full / 重型编辑器）**: 对象持状态 + 多命令方法（如 `IInputEditor`）；`HandleKey` **应为** `function: Boolean`（U2 起 `IInputEditor` 已对齐）；**不得**再引入新的 procedure-only HandleKey。
3. **鼠标**: 交互控件可在 widget 或 state 上 `HandleMouse`，返回 Boolean 表示消费（`TSplitPane` 先例）。

### 1.3 控件列表

详见 `WIDGET_CATALOG.md`。按 facade 分层：

| Facade | Widget 数量 | 定位 |
|--------|------------|------|
| `nextpas.core.tui` | 8 | 终端正确性最小闭包 |
| `nextpas.core.tui.ext` | 1 | 稳定 app/runtime 编排 |
| `nextpas.core.tui.full` | 30+ | 完整 widget 目录 |

---

## 2. 不变量

- **[INV-1]** 双缓冲：仅 dirty 区域刷新到终端（dirty row bitmask）
- **[INV-2]** Immediate mode：widget 不保留帧间状态，state 由调用方持有
- **[INV-3]** 接口引用计数：widget 通过 COM 接口引用计数管理生命周期
- **[INV-4]** 门面分层：`core` 不依赖 `ext`/`full`，`ext` 不依赖 `full`

---

## 3. 错误处理

- 热路径绝不靠异常控制流——越界走返回 nil / 边界裁剪
- 异常仅用于违反不变量（帧生命周期违规、nil 渲染函数）
- 异常层次：`ETui` > `ETuiBuffer` / `ETuiLayout` / `ETuiBackend` / `ETuiInput`
- Debug 模式 Assert 验证前置条件（release 零开销）

---

## 4. 线程安全

- UI 线程单线程操作
- 事件队列通过 `nextpas.core.sync` 原语跨线程投递
- `TTaskManager` 提供后台任务调度
- **线程前置契约**：任何链接 `tui.task` 传递闭包（`ext`/`full`/`app`/
  `app.screen`/`loading`/`task`）的程序，必须把 `nextpas.core.thread.init`
  作为 uses 的**第一个单元**。历史根因：缺失时 FPC Unix 无线程管理器，
  `TTaskManager.Spawn` 的任务线程跑在单线程 RTL 上（堆无锁/AnsiString
  引用计数非原子/异常帧共享），表现为随机 segfault 且编译零告警。
  门禁：C11（examples/tests/benchmarks 全量扫描）。
- **fail-fast 门卫**：`nextpas.core.tui.task` 自身 implementation uses
  `thread.init`。这**不能**替代应用侧首位声明——FPC 约束：sync/mem 等更
  底层单元的 initialization 已触碰线程 API（置 `ThreadingAlreadyUsed`），
  cthreads 晚装即 runerror 211。但正因如此，忘记首位声明的程序会在**启动
  时确定性报错**（"Make cthreads one of the first units..."）而非随机
  segfault。库内引用的价值 = 把静默死亡换成自解释失败；代价 = 链接闭包内
  所有程序（含从不 Spawn 的）都必须显式首位声明，demo 模板已全部带上。

---

## 5. 内存管理

- TBuffer / TOverlayBuffer 默认 `array of` 托管 dynarray（`SetLength`）
- **可选** `IAllocator`（`CreateEmpty/CreateFilled/Create(..., AAllocator)`；`nil` = 默认路径）
- non-nil 路径：cell/marks 走 `GetMem`/`FreeMem`；`Destroy`/`Resize` 配对释放
- `TTerminal.Create(AAllocator)` 将分配器下传到 prev/curr/merged/overlay 与 `TAnsiBackend`（`InitWith`）
- buffer 生命周期 ⊆ allocator 生命周期（接口 refcount）
- widget 通过接口引用计数自动释放
- Diff patch / image placements / input queue 仍用进程堆 dynarray（Phase 2 未迁）

### 5.1 Capability 会话协商

- `Truecolor`：`COLORTERM=truecolor|24bit` → Detected+Active+**Verified**（**env-attested**；非 DA 查询）


- `CapabilityProfile.KittyKeyboard`：env hint → **Detected**；`EnterTui` 发出
  `CSI = 5 ; 1 u`（disambiguate + report alternate keys）后 **Active=True**，
  并异步发出 **query** `CSI ? u`（`FallbackReason=query-pending`）
- 终端应答 `CSI ? <flags> u`：若 `(flags and 5) <> 0` → **Verified=True**；
  `flags=0` → 保持 Active，Verified=False（`query-flags-zero`）；
  无应答不阻塞、不回退 Active
- `LeaveTui` 发出 `CSI < u` 并收回 Active/Verified（`FallbackReason=session-ended`）
- 解析：`TryParseKittyKeyboardFlagsReply`；不产生用户事件

### 5.2 Terminal focus reporting（DECSET 1004）

- `TTerminalOptions.FocusReporting`（默认 **False**，opt-in）
- 启用时 `EnterTui` 发 `CSI ? 1004 h`，`LeaveTui` 配对 `CSI ? 1004 l`
- 终端应答：`CSI I` → `evFocus`/`fkIn`；`CSI O` → `evFocus`/`fkOut`
- 与 `nextpas.core.tui.focus` 的 **TFocusManager**（控件焦点）无关

### 5.3 Bracketed paste（DECSET 2004）

- `TTerminalOptions.BracketedPaste`（默认 **False**，opt-in）
- 启用时 `EnterTui` / test frame runtime 发 `CSI ? 2004 h`，`LeaveTui` 配对 `CSI ? 2004 l`
- 解析：`CSI 200 ~` → `evPaste`；`CSI 201 ~` 成功消费且 **不** 产生 `evPaste`（None）
- Editor 路径可显式打开；默认 off 避免干扰终端原生选择粘贴

### 5.4 Synchronized update（DECSET 2026）

- `TTerminalOptions.SynchronizedUpdate`（默认 **True**，crossterm/ratatui 对齐）
- `EndFrame` 在 `DrawPatches` + cursor 更新外包一层：`CSI ? 2026 h` … `CSI ? 2026 l`
- 不支持的终端通常忽略未知 DECSET；可设 `False` 关闭
- Emitter：`AnsiBeginSynchronizedUpdate` / `AnsiEndSynchronizedUpdate`；backend 转发

### 5.5 Auto-wrap / DECAWM（DECSET 7）

- `EnterAlternate` 在 `1049h` 后发 `CSI ? 7 l`（关闭自动换行）
- `LeaveAlternate` 在 `1049l` 前发 `CSI ? 7 h`（恢复）
- 失败模式：保留 wrap 时长行/宽格会被终端 reflow，破坏 immediate-mode 格网
- Emitter：`AnsiDisableAutoWrap` / `AnsiEnableAutoWrap`

### 5.6 EnterTui 失败诊断（Phase U1）

- `EnterTui: Boolean` **保留**（兼容）
- 每次调用更新 `TTerminal.LastEnterResult: TTuiEnterResult`
  - `Ok` / `Failure: TTuiEnterFailure` / `Reason` 稳定 token
  - tokens：`''`（成功）| `not-a-terminal` | `set-raw-failed` | `session-setup-failed`
- `TryEnterTui` 返回 `LastEnterResult`（等价于 Enter 后读取）
- `TApp` 失败时：`App.Terminal.LastEnterResult`（不改 `DoEnterTui: Boolean`）

---

## 6. 测试

- 95+ 个测试目录，1650+ T.Test 注册
- heaptrc 全覆盖（编译器标志 `-gh -dHEAPTRC_ACTIVE`）
- 0 泄漏，0 失败
- 测试源 0 SysUtils / BaseUnix / Unix 直接引用
- tracking allocator 覆盖 TBuffer/TOverlay 可选路径
- Kitty keyboard push/pop/query + profile Active/**Verified** 有 focused 覆盖

### 6.1 Scorecard 与跨语言对标（Wave Q1–Q15 + M1 Maintenance）

- **权威热路径门禁**: `core/tests/nextpas.core.tui/scorecard`（SC1–SC30）
  - SC1–SC25：Q 线质量主维度
  - **SC26** Keybind；**SC27** FrameBudget；**SC28** Sync 2026；**SC29** DECAWM；**SC30** Enter 原因
- **纲领**: `PARITY-GO-RUST.md` · `SCORECARD.md`
- **同方法论对照**: `bench_go_rust`
- **契约脚本**: `./scripts/tui-contract-check.sh`
  - **C7** SCORECARD/CONTRACT/scorecard.lpr 对齐至 SC30
  - **C8** core facade reject 编译失败（scrollview/modal/dialog/split_pane/select）
  - **C9** Wine pure-path suite 存在（buffer/color/input）
  - **C10** examples facade 纪律（除 demo_widgets 外须 ext、禁 full）
- 密度：clear/intf ≥16；tier facade ≥12；examples ≥7
- 晋升：scrollview/modal/dialog/split_pane/select 已在 **ext**；core reject 保持；B3 候选表清空
- 测量：SCORECARD 以 **RELEASE=1** 发布口径刷新（Phase E1）；不对 ns 设硬阈值

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-23 | 1.31 | PH33 P4 ext facade 扩面：gauge/canvas/sparkline 解禁进 ext（六别名照 full 命名；ext rejects 探针 canvas/gauge/sparkline 删除翻转、正测 data widgets surface 就位守门）；core facade 窄门面与 C8 名单不变 | Grok |
| 2026-07-21 | 1.30 | Idle-Seal：文档主线封板（无 API/行为变更） | Claude |
| 2026-07-20 | 1.29 | Phase U2：去双别名 + HandleKey Boolean + Enter enable_ansi | Claude |
| 2026-07-20 | 1.28 | Phase U1：Enter 诊断 + Stateful 约定 + C10 facade 纪律 | Claude |
| 2026-07-20 | 1.27 | Phase E3：DECAWM wrap-off on EnterAlternate + SC29 | Claude |
| 2026-07-20 | 1.26 | Phase E2：DECSET 2026 Synchronized Update + SC28 | Claude |
| 2026-07-20 | 1.25 | Phase E1：RELEASE=1 快照 + C2 wine + C9；无新 SC | Claude |
| 2026-07-20 | 1.24 | Idle 单点：TSelect 晋升 ext；core reject_select；B3 表清空 | Claude |
| 2026-07-20 | 1.23 | Idle 单点：TSplitPane 晋升 ext；core reject_split_pane | Claude |
| 2026-07-20 | 1.22 | Idle 单点：TDialog 晋升 ext；core reject_dialog | Claude |
| 2026-07-20 | 1.21 | Phase B 收尾：B3 停止晋升；Maintenance Idle | Claude |
| 2026-07-20 | 1.20 | Phase B1：scrollview+modal 晋升 ext；TIER/WIDGET_CATALOG 同步 | Claude |
| 2026-07-20 | 1.19 | 权威 ROADMAP 完整开发地图（Done 清单 + Phase A–F） | Claude |
| 2026-07-20 | 1.18 | M1 Maintenance：SC26 keybind + SC27 frame budget；reject scrollview/modal；C8 | Claude |
| 2026-07-20 | 1.17 | SC23 indexed SGR + SC24 style-change patches + SC25 focus Tab；C7 升级 | Claude |
| 2026-07-20 | 1.16 | SC20 SGR rgb + SC21 DrawPatches + SC22 ratio；contract-check C7 | Claude |
| 2026-07-20 | 1.15 | SC17 backend mouse modes + SC18 resize + SC19 pct layout；examples multi-demo | Claude |
| 2026-07-20 | 1.14 | SC14 hsplit + SC15 输入韧性 + SC16 diff 上界；PARITY 质量矩阵；bench HSplit | Claude |
| 2026-07-20 | 1.13 | SC12 Kitty Verified + SC13 paste session；bench layout/overlay；tier facade ≥12 | Claude |
| 2026-07-20 | 1.12 | SC10 mouse + SC11 paste；DECSET 2004 opt-in；clear/intf/wine 密度收口 | Claude |
| 2026-07-20 | 1.11 | SC9 overlay merge；tier facade/stress/wine 密度 | Claude |
| 2026-07-20 | 1.10 | Scorecard SC8 truecolor；facade_surface focus 转发；wine 加厚 | Claude |
| 2026-07-20 | 1.9 | Truecolor Verified=env-attested；error/backend_test/image_mgr/cap/integration 密度 | Claude |
| 2026-07-20 | 1.8 | Scorecard SC6 focus + SC7 CJK width；ext 密度底线 | Claude |
| 2026-07-20 | 1.7 | DECSET 1004 focus reporting + 核心 suite 密度 ≥12 | Claude |
| 2026-07-20 | 1.6 | Kitty keyboard query `CSI ? u` → Verified（非阻塞） | Claude |
| 2026-07-19 | 1.5 | Wave Q1：scorecard + PARITY + bench_go_rust + 输入/clear/intf 加厚 | Claude |
| 2026-07-19 | 1.4 | Kitty keyboard 会话 push/pop 协商 → Active | Claude |
| 2026-07-19 | 1.3 | 可选 IAllocator：TBuffer/TOverlay/TTerminal/ANSI | Claude |
| 2026-07-19 | 1.2 | 测试计数 1567→1630；测试 SysUtils 清零；docs/contracts 改指针 | Claude |
| 2026-07-11 | 1.1 | 全面重写：对齐实际实现，修正接口签名、控件列表、不变量 | Claude |
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-31 | 1.31 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
