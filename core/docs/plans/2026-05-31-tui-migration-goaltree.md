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
3. **TBuffer = record（已改）**：原 fafafa 是 class，改为 advanced record。理由：① 省一次堆分配（外部不主动 new，由 TTerminal 嵌入持有）；② swap 仍 O(1)（FPC 托管动态数组字段赋值只拷指针+引用计数，不拷 cell 数据）；③ 与 JSON TStringBuilder 的 record-first 风格一致。代价：widget Render 签名用 `var ABuffer: TBuffer`（更明确表达"渲染会写 buffer"）。需 Init/Done 手动生命周期。
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

### Phase 0 — Core 前置依赖 [进行中]
- [x] nextpas.core.text.width（CodepointWidth + StringDisplayWidth + ASCII 快路径）✅ 10/10 测试通过，无泄漏
- [ ] FlushToFd helper（EINTR/short-write 重试）→ 推迟到 Phase 3（terminal 一起做，有消费方才能验证）
- [ ] platform_console_enter_raw / leave_raw → 推迟到 Phase 3
- [ ] 确认 SIGWINCH 导出可用 → Phase 3

> 策略调整：raw mode / FlushToFd 无消费方时无法真正验证，与 Phase 3 terminal 合并实施。
> 先推进 Phase 1 基础类型（零外部依赖、纯数据，可立即测试），让模块骨架立起来。

### Phase 1 — 基础类型 [进行中]
- [x] nextpas.core.tui.base（TRect/TPosition/TSize/TMargin/TDirection）← ftui_rect ✅ 9/9 测试，无泄漏，Codex 审查通过
- [x] nextpas.core.tui.error（ETui/ETuiBuffer/ETuiLayout/ETuiBackend/ETuiInput）← ftui_error ✅ 3/3，无泄漏，继承 ECore
- [x] nextpas.core.tui.color ← ftui_color ✅ 5/5，无泄漏，TColor 4 字节；命名色 TUI_BLACK 风格；variant record 不能含方法，构造用自由函数
- [x] nextpas.core.tui.modifier ← ftui_modifier ✅ 5/5，无泄漏，TModifier 2 字节（packset 2）
- [x] nextpas.core.tui.style ← ftui_style ✅ 7/7，无泄漏，TStyle 16 字节，Patch 语义对齐 ratatui
- [x] nextpas.core.tui.cell ← ftui_cell ✅ 9/9，无泄漏，TCell 40 字节（QWord 比较保留）
- [ ] nextpas.core.tui.widget.intf（IWidget 基础接口）→ 移至 Phase 2 buffer 之后（Render 签名引用 TBuffer）

### Phase 2 — Buffer + Text + Layout [未开始]
- [ ] buffer ← ftui_buffer / overlay ← ftui_overlay
- [ ] text ← ftui_text / text.format ← ftui_format
- [ ] borders ← ftui_borders
- [ ] layout ← ftui_layout / layout.grid ← ftui_grid / layout.dsl ← ftui_layout_dsl

### Phase 3 — ANSI Backend + Terminal [未开始]
- [ ] ansi ← ftui_ansi / backend.ansi ← ftui_ansi_backend
- [ ] backend.test ← ftui_test_backend
- [ ] terminal ← ftui_terminal / terminal.raw ← ftui_termios + platform

### Phase 4 — Event + Input [未开始]
- [ ] event ← ftui_event
- [ ] input ← ftui_input_parser
- [ ] interaction ← ftui_interaction / focus ← ftui_focus / keybind ← ftui_keybind

### Phase 5 — Core Widgets [未开始]
- [ ] block / paragraph / list / table / gauge / tabs / scrollbar / clear / input / sparkline / barchart / canvas

### Phase 6 — Extended Widgets [未开始]
- [ ] tree / dialog / menu / modal / select / panel / split_pane / popover / toast / tooltip / statusbar / form / scrollview / virtual_list / input_editor / calendar / linechart / markdown / syntax / image / diffview / file_tree / kanban / timeline / breadcrumb / progress_group / command_palette / notification_center

### Phase 7 — App + 收尾 [未开始]
- [ ] app ← ftui_app / app.screen ← ftui_screen
- [ ] anim ← ftui_anim / animator / theme ← ftui_theme / chat_theme
- [ ] task ← ftui_task / loading / frame_budget / clipboard / sixel / image_mgr / 能力检测
- [ ] 门面 nextpas.core.tui.pas
- [ ] docs/tui/ + examples + benchmarks

---

## 当前状态

- 已完成：worktree、源码暂存、设计决策锁定、目标树
- Phase 0.1 ✅ text.width（12/12，无泄漏，Codex 审查 + 宽度表补缺）
- Phase 1 ✅ base/error/color/modifier/style/cell 全部完成（共 38 测试，全无泄漏）
  - 关键验证：TColor=4B, TModifier=2B, TStyle=16B, TCell=40B（packed 布局保留）
  - 设计微调：colour 命名常量 TUI_*；variant record 不含方法（FPC 限制），构造用自由函数
- 下一步：Phase 2 — buffer（record 化）→ widget.intf（IWidget）→ text → borders → layout

## 关键技术笔记

- variant record（含 case 部分）在 FPC 不能声明 class function/method，构造器必须用自由函数
- packed 布局指令 {$packenum 1}{$packset 2} 必须在每个相关单元单独声明（settings.inc 未含）
- TCell 40 字节断言 {$if SizeOf(TCell)<>40} 保留，QWord×5 比较依赖它
- 测试 Makefile 模板：-O2 -gl -gh，BUILD_DIR 在 core/build/projects/<module>/<test>/
