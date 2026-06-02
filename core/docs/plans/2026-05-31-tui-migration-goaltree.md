# nextpas.core.tui 迁移目标树（项目总控地图）

> 持续更新。每轮工作后同步状态。源：fafafa.tui → 目标：nextpas.core.tui（L3 框架层）

## 总目标

把 fafafa.tui（ratatui 风格 TUI 框架）完整迁移为 `nextpas.core.tui` 模块，成为 FreePascal 领域最优秀的 TUI 框架之一。

- 设计：接口优先（IWidget/IBlock/IList... 全继承 IWidget），热路径零开销
- 纪律：每个接口 100% 单测覆盖 + 无内存泄漏（-gh 验证）才算完成
- 基准：fpc rtl / go / rust 对照（最后一轮做）
- 文档/注释/多场景测试覆盖

## 核心设计决策（已锁定）

1. **Widget = class + interface**：每个 widget 是 `class(TInterfacedObject, IXxx)`，所有可调用方法（含 builder 链、Inner、RenderStateful）都声明在接口上，builder 返回自身接口类型，`New` 返回接口。COM 引用计数，消费方全程持接口引用，不混用类引用。
2. **数据层 = record**：TRect/TColor/TModifier/TStyle/TCell/TText/TLayout/TListState 等纯数据保持 record（规范要求）。
3. **TBuffer = class（保持）**：曾考虑改 record，与 Codex 深入讨论后撤销，保持 fafafa 原样的 class。理由：① Codex 诚实评估——热路径性能与 owner 是 class/record 无关（热成本在 cell 内存遍历）；② record 化要配套 TBufferRef 视图 + 改全部 widget/Frame 签名 + 双重释放纪律，复杂度不值；③ class 零迁移风险、零 silent break（widget `Render(const AArea; ABuf: TBuffer)` 按值传对象指针，写入直达原 buffer）；④ TTerminal 只持有 4 个 buffer，一次性堆分配可忽略。widget Render 签名沿用 `ABuffer: TBuffer`（class 引用语义）。
4. **ByteBuilder**：用 core 的 `nextpas.core.text.builder.TStringBuilder`（已具备 AppendChar/AppendBytes/AppendUInt/AppendHex/Clear），仅补 FlushToFd helper。
5. **执行**：copy-then-modify。完整源码已暂存在 `core/_migration/`（不编译，作参照）。逐文件改造落地到 `src/`。

## 环境

- Worktree：`/home/dtamade/projects/nextPas/core-tui-migration`（分支 `feat/tui-migration`，基于 core HEAD a3e64e34）
- core 子目录：worktree 内 `core/`
- 暂存源：`core/_migration/`（fafafa.tui 完整 src/tests/docs/benchmarks/examples）
- settings.inc：`core/src/nextpas.core.settings.inc`（已确认，含 NEXTPAS_LINUX/X86_64 等）
- 异常基类：`ECore`（继承 Exception）→ ETui 系继承 ECore

## 依赖替换总表

| fafafa 原始 | nextpas.core 替代 |
|---|---|
| ftui_grapheme UTF8 解码 | nextpas.core.text.utf8.UTF8Decode |
| ftui_grapheme.CodepointWidth | nextpas.core.text.width（新建 L1） |
| ftui_bytes.TByteBuilder | nextpas.core.text.builder.TStringBuilder + FlushToFd |
| ftui_platform (BaseUnix/termio) | nextpas.core.platform.console + posix.ffi |
| ftui_platform SIGWINCH | nextpas.core.platform.signal |
| ftui_platform read/write | nextpas.core.platform.posix.ffi |
| ftui_platform 等待可读 | nextpas.core.platform.io (epoll) |
| ftui_platform TickMs | nextpas.core.platform.time |
| ftui_testkit | nextpas.core.testing.TTestRunner |

---

## Phase 进度

### Phase 0 — Core 前置依赖 [完成]
- [x] nextpas.core.text.width（CodepointWidth + StringDisplayWidth + ASCII/SIMD 快路径 + grapheme-aware 非 ASCII 路径）✅ 19/19 测试通过，无泄漏

> Phase 0 已收束。raw mode / write plumbing / SIGWINCH 已并入 `nextpas.core.platform.console`、
> `nextpas.core.platform.signal` 和 `nextpas.core.tui.terminal`，不再单列为独立前置项。

### Phase 1 — 基础类型 [完成]
- [x] nextpas.core.tui.base ← ftui_rect ✅ 9/9
- [x] nextpas.core.tui.error ← ftui_error ✅ 3/3
- [x] nextpas.core.tui.color ← ftui_color ✅ 5/5
- [x] nextpas.core.tui.modifier ← ftui_modifier ✅ 5/5
- [x] nextpas.core.tui.style ← ftui_style ✅ 7/7
- [x] nextpas.core.tui.cell ← ftui_cell ✅ 9/9
- [x] nextpas.core.tui.widget.intf（IWidget 基础接口）✅ 4/4，class 实现+多态集合+TWidgetAdapter+引用计数验证

### Phase 2 — Buffer + Text + Layout [完成]
- [x] nextpas.core.tui.image_cap ← ftui_image_cap ✅（图像协议检测）
- [x] nextpas.core.tui.buffer ← ftui_buffer ✅ 21/21，保持 class，热路径全保留
- [x] nextpas.core.tui.overlay ← ftui_overlay ✅ 6/6，稀疏覆盖层 + merge
- [x] nextpas.core.tui.text ← ftui_text ✅ 12/12，TSpan/TLine/TText，宽度走 text.width
- [x] nextpas.core.tui.borders ← ftui_borders ✅ 6/6，5 套边框字形集
- [x] nextpas.core.tui.layout ← ftui_layout ✅ 9/9，6 遍约束求解器（用 base.TDirection）
- [x] nextpas.core.tui.layout.grid ← ftui_grid ✅ 4/4，2D 网格切分
- [x] nextpas.core.tui.layout.dsl ← ftui_layout_dsl ✅ 3/3，约束/切分短名 DSL
- [x] nextpas.core.tui.text.format ← ftui_format ✅ 5/5，字节数人类可读格式化

### Phase 3 — ANSI Backend + Terminal [完成]
- [x] ansi ← ftui_ansi / backend.ansi ← ftui_ansi_backend
- [x] backend.test ← ftui_test_backend
- [x] terminal ← ftui_terminal / terminal.raw ← ftui_termios + platform

### Phase 4 — Event + Input [完成]
- [x] nextpas.core.tui.event（161 行，TEvent variant: key/mouse/resize + 便利构造器）
- [x] nextpas.core.tui.input（443 行，纯函数 byte-stream parser: ASCII/UTF-8/CSI/kitty/SGR mouse）
- [x] nextpas.core.tui.interaction（121 行，pointer capture + session + hit test + hover）
- [x] nextpas.core.tui.focus（218 行，TFocusManager: tab-order + spatial navigation）
- [x] nextpas.core.tui.keybind（246 行，TKeybindManager: modal bindings Normal/Insert/Visual/Command）
- 测试：test_tui_event + test_tui_interaction + terminal 集成测试（inject bytes → assert events）

### Phase 5 — Core Widgets [完成]
- [x] block / paragraph / list / table / gauge / tabs / scrollbar / clear / input / sparkline / barchart / canvas
- 全部转为 class(TInterfacedObject, IWidget, IXxx) 模式
- TScrollbar 重设计：样式吸收为内部字段，标准 IWidget.Render 签名

### Phase 6 — Extended Widgets [完成]
- [x] tree / dialog / menu / modal / select / panel / split_pane / popover / toast / tooltip / statusbar / form / scrollview / virtual_list / input_editor / calendar / linechart / markdown / syntax / diffview / file_tree / kanban / timeline / breadcrumb / progress_group / command_palette / notification_center
- TPanel 重设计：RenderGrid 返回 TPanelGrid，Render 作为 IWidget 标准入口
- TInputEditor 重设计：样式参数吸收为 builder，标准 IWidget.Render 签名
- 全部 widget 单元测试覆盖；最终全量回归见当前状态的 32 测试项目 / 240 用例记录

### Phase 7 — App + 收尾 [完成]
- [x] nextpas.core.tui.app / app.screen（事件循环 + 多屏）
- [x] nextpas.core.tui.anim / animator（动画原语 + 帧调度）
- [x] nextpas.core.tui.theme（配色方案）
- [x] nextpas.core.tui.task / frame_budget / clipboard / sixel（辅助模块）
- [x] nextpas.core.tui.pas（门面 re-export，2026-06-01 facade API surface 测试补强）
- [x] examples: demo_hello / demo_layout / demo_widgets
- [x] benchmarks: bench_diff / bench_render / bench_input / bench_layout
- [x] benchmark smoke：`benchmarks/nextpas.core.tui/run_all.sh` 聚合 4 个基准，并接入 TUI CI smoke
- [x] docs/tui/README.md

### 2026-06-01 — API Surface 收口 [完成]
- [x] `nextpas.core.tui` 门面补齐自然名称 re-export：基础类型、样式、buffer、text、layout、event、terminal、app、全部 catalog widget 接口/类和常用 state/data 类型。
- [x] 保留 `TTui*` / `ITui*` 兼容别名，降低消费方迁移风险。
- [x] 新增 `test_tui_facade` 编译期 API 测试，证明 `uses nextpas.core.tui` 可直接使用 README/catalog 中的核心类型与 widget builder。
- [x] `TWidgetAdapter` 决策：保留为自定义 render function / 外部 widget 桥接扩展点，并通过 facade 导出 `TWidgetRenderFn` / `TWidgetAdapter`。
- [x] `TWidgetAdapter.Create(nil)` fail-fast 抛出 `EArgumentException`，防止 nil render function 造成后续调用崩溃或未接管对象泄漏。
- [x] `/codex` 复盘 follow-up：补齐 `TWrap` / `WRAP_TRIM` / `TContentAlign` 等 builder 支撑类型；`BorderSet*` 改为 facade thin forwarding，避免复制初始化值。
- [x] focused heaptrc 证据：`test_tui_facade` 5/5 通过、0 unfreed；`test_tui_widget_intf` 4/4 通过、0 unfreed。
- [x] 全量 TUI 回归：32 个测试项目、246 用例全部通过；13 个 heaptrc 摘要均为 `0 unfreed memory blocks`。
- [x] Unicode/grapheme 关键回归：family emoji、skin tone modifier 覆盖 text.grapheme / text.width / tui.buffer；keycap emoji 覆盖 text.grapheme / text.width / tui.buffer / tui.text。
- [x] 2026-06-02 benchmark 收口：修复 `bench_render` 的 IGauge builder 用法，4 个 TUI benchmark 全部可运行；
  `docs/tui/BENCHMARK.md` 记录 FreePascal TUI 基线，并明确 CI smoke 与跨 runtime 对照边界。
- [x] 2026-06-02 merge-prep 审计：README quick-start 已对齐真实 facade API，并由 `test_tui_facade`
  编译覆盖；随后已收口 `nextpas.core.text.number.pow10.inc` typed constant warning，
  当前 facade 编译 warning=0，TUI 自身单元 warning 行数为 0；benchmark smoke 编译 warning 行数为 0。

---

## 当前状态

- Phase 0.1 ✅ text.width
- Phase 1 ✅ 基础类型（base/error/color/modifier/style/cell/widget.intf）
- Phase 2 ✅ Buffer + Text + Layout（image_cap/buffer/overlay/text/borders/layout/grid/dsl/format）
- Phase 3 ✅ ANSI Backend + Terminal（ansi/backend.ansi/backend.test/terminal）
- Phase 4 ✅ Event + Input（event/input/interaction/focus/keybind）
- Phase 5 ✅ Core Widgets（12 个，全部 class+interface）
- Phase 6 ✅ Extended Widgets（28 个，全部 class+interface + 单元测试）
- Phase 7 ✅ App Layer（app/anim/theme/task/sixel/clipboard/frame_budget/门面/examples/benchmarks）
- 全量回归：32 测试项目、246 用例全通过；13 个 heaptrc 摘要全 0 泄漏
- 累计 77 src 单元、3 examples、4 benchmarks
- 2026-06-02 benchmark baseline：Full render 120x40 约 155us；DiffInto 200x50 changed-row 约 46.7us；
  input parse 约 44-50ns；8x8 grid layout 约 4.4us。CI 运行 benchmark smoke，不设置 hosted runner 绝对阈值。
- 2026-06-02 buffer overwrite hardening：`SetString` / `SetStringN` / `SetStringP` 在覆盖旧宽字形
  lead/tail cell 时先清理重叠残留，避免同一帧内留下 stale `Width=2`/`Skip=True` 状态；
  `test_tui_buffer` 扩至 21/21，覆盖窄字形覆盖宽字形 lead/tail 与 `SetStringP` 路径。
- 2026-06-02 merge-prep truth：README/catalog/facade 已对齐；`test_tui_facade` 现为 5/5；
  `nextpas.core.text.number.pow10.inc` typed constant warning 已修复，facade 编译 warning=0；
  benchmark smoke 无 warning 行。
- **迁移主体完成。** 剩余：merge 前最终真相审计、全量 verification envelope、合并准备清单。

### Phase 3 — ANSI Backend + Terminal [完成]
- [x] platform 前置依赖（platform.console: set_raw/restore_raw/read/write/wait_readable/get_size; platform.signal: SIGWINCH）
- [x] nextpas.core.tui.ansi（346 行，ANSI escape emitter → TStringBuilder）
- [x] nextpas.core.tui.backend.ansi（223 行，DiffEntries → ANSI bytes → platform_console_write）
- [x] nextpas.core.tui.backend.test（126 行，内存 test backend）
- [x] nextpas.core.tui.terminal（704 行，双缓冲 + overlay + input queue + SIGWINCH + BeginFrame/EndFrame）
- terminal.raw 不需要独立单元（raw mode 在 platform.console 层）
- 测试：test_tui_ansi + test_tui_backend + test_tui_terminal 全通过

## 关键技术笔记

- variant record（含 case 部分）在 FPC 不能声明 class function/method，构造器必须用自由函数
- packed 布局指令 {$packenum 1}{$packset 2} 必须在每个相关单元单独声明（settings.inc 未含）
- TCell 40 字节断言 {$if SizeOf(TCell)<>40} 保留，QWord×5 比较依赖它
- color/style 也加了 SizeOf 断言（防 packed 指令误删）
- 测试 Makefile 模板：-O2 -gl -gh，BUILD_DIR 在 core/build/projects/<module>/<test>/
- TBuffer 保持 class（与 Codex 讨论后定，热路径性能与 owner 类型无关）
- buffer/overlay grapheme：本地 GraphemeAt helper 委托 text.grapheme.GraphemeNext
- managed-type 函数 Result（如 TBufferLines）显式 `Result := nil` 消除 FPC 未初始化警告
- 文档注释 {** *} 内不能出现裸 { （触发嵌套注释告警）
- IWidget 接口：class(TInterfacedObject, IWidget) 实现，多态集合 array of IWidget，引用计数自动释放

## 有意偏离原始的设计升级（intentional divergence）

- **Unicode 宽度模型升级**：全库（buffer/overlay/text）的字符串宽度从 fafafa 原始的
  "仅控制字符 0 宽，其余 1 宽，东亚少量 2 宽" 升级为 nextpas.core.text.width +
  nextpas.core.text.grapheme 的 grapheme-aware 模型：纯 ASCII 走 SIMD 快路径，非 ASCII 通过
  GraphemeNext 统一处理组合标记、ZWJ emoji、skin tone modifier、keycap emoji、变体选择符和
  扩展东亚宽字符。
  - 理由：Unicode 上更正确；全库用同一 text.width/text.grapheme 管线，buffer/overlay/text 内部自洽
    不会错位；符合"打造最优秀框架"目标。
  - 影响：含组合标记/ZWJ 的字符串宽度比旧版更小（更准），影响 wrap/alignment。
  - 已 Codex 复盘确认：这是系统级有意升级，非局部 bug。测试全过、0 泄漏。
