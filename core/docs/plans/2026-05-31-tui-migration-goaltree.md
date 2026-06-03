# nextpas.core.tui 迁移目标树（项目总控地图）

> 持续更新。每轮工作后同步状态。源：fafafa.tui → 目标：nextpas.core.tui（L3 框架层）

## 总目标

把 fafafa.tui（ratatui 风格 TUI 框架）完整迁移为 `nextpas.core.tui` 模块，成为 FreePascal 领域最优秀的 TUI 框架之一。

- 设计：接口优先（IWidget/IBlock/IList... 全继承 IWidget），热路径零开销
- 纪律：每个接口 100% 单测覆盖 + 无内存泄漏（-gh 验证）才算完成
- 基准：fpc rtl / go / rust 对照（最终 benchmark 对照轮做；当前 merge-prep 只要求 FreePascal 基线与 CI smoke 真相）
- 文档/注释/多场景测试覆盖

## 核心设计决策（已锁定）

1. **Widget = class + interface**：每个 widget 是 `class(TInterfacedObject, IXxx)`，所有可调用方法（含 builder 链、Inner、RenderStateful）都声明在接口上，builder 返回自身接口类型，`New` 返回接口。COM 引用计数，消费方全程持接口引用，不混用类引用。
2. **数据层 = record**：TRect/TColor/TModifier/TStyle/TCell/TText/TLayout/TListState 等纯数据保持 record（规范要求）。
3. **TBuffer = class（保持）**：曾考虑改 record，与 Codex 深入讨论后撤销，保持 fafafa 原样的 class。理由：① Codex 诚实评估——热路径性能与 owner 是 class/record 无关（热成本在 cell 内存遍历）；② record 化要配套 TBufferRef 视图 + 改全部 widget/Frame 签名 + 双重释放纪律，复杂度不值；③ class 零迁移风险、零 silent break（widget `Render(const AArea; ABuf: TBuffer)` 按值传对象指针，写入直达原 buffer）；④ TTerminal 只持有 4 个 buffer，一次性堆分配可忽略。widget Render 签名沿用 `ABuffer: TBuffer`（class 引用语义）。
4. **ByteBuilder**：用 core 的 `nextpas.core.text.builder.TStringBuilder`（已具备 AppendChar/AppendBytes/AppendUInt/AppendHex/Clear），仅补 FlushToFd helper。
5. **执行**：copy-then-modify。完整源码已暂存在 `core/_migration/`（不编译，作参照）。逐文件改造落地到 `src/`。

## 环境

- Canonical worktree：`/home/dtamade/.config/superpowers/worktrees/nextPas/tui-main-merge-20260602`
  （分支 `codex/tui-main-merge-20260602`，当前 TUI 唯一继续开发线）
- `core` 子目录：canonical worktree 内 `core/`
- 历史参考 worktree：
  - ` /home/dtamade/.config/superpowers/worktrees/nextPas/tui-main-safe-20260603`
    （分支 `codex/tui-main-safe-20260603`，只保留为已吸收增量的对照源，不再继续开发）
  - `/home/dtamade/projects/nextPas/core-tui-migration`
    （分支 `feat/tui-migration`，迁移完成后的历史参考，不再作为主线入口）
- 暂存源：`core/_migration/`（fafafa.tui 完整 src/tests/docs/benchmarks/examples）
- settings.inc：`core/src/nextpas.core.settings.inc`（已确认，含 NEXTPAS_LINUX/X86_64 等）
- 异常基类：`ECore`（继承 Exception）→ ETui 系继承 ECore

## 依赖替换总表

| fafafa 原始                     | nextpas.core 替代                                    |
| ------------------------------- | ---------------------------------------------------- |
| ftui_grapheme UTF8 解码         | nextpas.core.text.utf8.UTF8Decode                    |
| ftui_grapheme.CodepointWidth    | nextpas.core.text.width（新建 L1）                   |
| ftui_bytes.TByteBuilder         | nextpas.core.text.builder.TStringBuilder + FlushToFd |
| ftui_platform (BaseUnix/termio) | nextpas.core.platform.console + posix.ffi            |
| ftui_platform SIGWINCH          | nextpas.core.platform.signal                         |
| ftui_platform read/write        | nextpas.core.platform.posix.ffi                      |
| ftui_platform 等待可读          | nextpas.core.platform.io (epoll)                     |
| ftui_platform TickMs            | nextpas.core.platform.time                           |
| ftui_testkit                    | nextpas.core.testing.TTestRunner                     |

---

## Phase 进度

### Phase 8 — Post-merge Dual-track Strengthening [进行中]

- [x] 统一 TUI worktree 路线：
      `codex/tui-main-merge-20260602` 作为唯一 canonical worktree；
      `codex/tui-main-safe-20260603` 与 `feat/tui-migration`
      只保留历史参考角色，不再继续并行开发
- [x] 吸收 `safe` 线仍有价值的终端/测试增量：
      wide-glyph test backend cursor parity；
      `BeginFrame/EndFrame` lifecycle defensive proofs；
      当前增量已直接落在 canonical worktree 的 live diff 中
- [x] 冻结 `nextpas.core.tui` 默认 correctness-first facade
- [x] 冻结 `nextpas.core.tui.ext` stable app/runtime facade
- [x] 冻结方案 C 下 `ext` 的 D 轴执行规则：
      `core/docs/superpowers/specs/2026-06-03-tui-ext-app-framework-dx-design.md`
      已明确 `D` 是对外主轴，但工程顺序必须遵守
      `B 骨架 -> A 门禁 -> D 表层 -> C 放大`
- [x] 冻结 `ext` 的 screen-driven app DX contract：
      `TApp` 默认驱动 `TScreenStack`，`test_tui_app` 已锁定 render / event / quit 三条 truth
- [x] 冻结 `TScreenStack` 多屏 lifecycle contract：
      `test_tui_app` 已扩到 `8/8`，覆盖 `Push / Pop / Replace`、rollback 和 defensive ownership guard
- [x] 冻结 `ext` 的 task-completion dispatch contract：
      默认 completion path 进入 top screen；explicit app callback 接管 batch；
      no dual propagation；quit 在 completion 后立即生效；
      `test_tui_app` 现已到 `28/28`，覆盖 default screen path、callback precedence、
      callback/screen quit-before-render-poll、multi-slot drain order、
      mixed-status multi-slot status fidelity on top-screen / callback path、
      callback-without-top-screen fallback、no-handler drain、
      follow-up completion ownership after screen transition、
      render/event ownership after completion-driven transition、
      render/event ownership after callback-driven transition、
      follow-up completion ownership after callback-driven transition、
      cancelled follow-up completion ownership after completion-driven transition、
      cancelled follow-up completion ownership after callback-driven transition、
      app-owned shared-state commit before first render、
      callback-owned shared-state ownership across screen transition、
      bootstrap first screen from callback without top screen、
      follow-up fallback to screen after callback ownership release、
      callback completion overflow ordering and result preservation across loop iterations、
      real cancelled completion handoff to top screen / callback path
- [x] 冻结 `ext` 的最小 app-owned shared-state injection contract：
      `TApp.SharedStateObject` 拥有 app-level shared state；
      `TScreenStack.SharedStateObject` 在 runtime owner 上向 screen 传播同一对象；
      `TScreen.SharedStateObject` 提供只读观察面；
      `test_tui_app` / `test_tui_ext_facade` 已覆盖 commit-before-first-render、
      ownership-across-transition 与 facade surface proof
- [x] 冻结 `nextpas.core.tui.experimental` volatile protocol facade
- [x] 保留 `nextpas.core.tui.full` migration compatibility facade
- [x] 收口 `TTerminal.CapabilityProfile` 的 runtime truth 语义：
      `requested / detected / active / verified / fallback_reason`
- [x] 补齐 capability truth focused regressions：
      `test_tui_terminal` capability profile proofs /
      `test_tui_image_cap` deterministic hint proofs
- [x] 补齐 focused surface tests：
      `test_tui_core_facade` / `test_tui_ext_facade` / `test_tui_experimental_facade`
- [x] 收口 public docs truth：
      `docs/tui/README.md` / `ARCHITECTURE.md` / `TIER_REGISTRY.md`
- [x] 冻结 focused TUI verification envelope：
      `cap_base` / `core_facade` / `ext_facade` / `experimental_facade` /
      `facade` / `terminal` / `image_cap` / `backend` / `buffer` / `widget_intf` /
      `benchmarks/nextpas.core.tui/run_all.sh`
- [ ] 持续维护 terminal / backend / buffer / image_cap / widget-intf focused regressions
- [ ] 按 `2026-06-03-tui-ext-app-framework-dx-design.md` 继续收口 `ext`
      的 shared-state API ergonomics：
      typed injection / owner conventions / helper accessors，仍不引入全局 store 或 message bus
- [x] 仅维护 TUI benchmark smoke，不在此阶段重启全仓 benchmark 对照轮

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
- 全部 widget 单元测试覆盖；最终全量回归见当前状态的 32 测试项目 / 246 用例记录

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
- [x] 2026-06-03 docs/facade freeze：README quick-start 已切到 `nextpas.core.tui.ext` 并由
      `test_tui_ext_facade` 编译覆盖；`test_tui_facade` 现在只证明 `nextpas.core.tui.full`
      compatibility facade；`ARCHITECTURE.md` / `TIER_REGISTRY.md` 也已对齐四层 facade truth。
- [x] 2026-06-03 app DX truth：`nextpas.core.tui.app` 现在拥有 `Screens`，默认
      `Render` / `HandleEvent` 会委托给 `TScreenStack`，app loop 也会消费
      `TScreenStack.RequestQuit`；`test_tui_app` 现已扩到 `8/8`，继续覆盖
      `Push / Pop / Replace` 的 lifecycle order、failed `OnEnter` rollback、
      `nil` / already-owned defensive guard；`demo_hello` 也已改成
      `TApp + TScreen` app-first hello。
- [x] 2026-06-03 full facade contract audit：`test_tui_facade` 已扩成 `7/7`，新增
      `full facade covers ext and experimental contract` 与
      `full facade advanced widget catalog remains usable`，把 `full` umbrella 对
      `ext + experimental` 关键 surface 和 advanced widget catalog 的兼容语义都变成
      focused compile proof。
- [x] 2026-06-03 core facade boundary audit：`test_tui_core_facade` 的 negative harness 现已继续拒绝
      `TGauge` / `TSparkline` / `TCanvas`，把 representative `full`-only advanced widgets
      也冻结成默认 facade 不可见的 compile contract。
- [x] 2026-06-03 terminal input correctness：`test_tui_terminal` 已扩到 `103/103`，新增
      plain `CSI H/F` regressions、
      control-letter `Ctrl+A/Ctrl+G/Ctrl+K/Ctrl+N/Ctrl+Z` regressions、
      `SGR mouse` middle/right down regressions、
      `SGR mouse` middle/right release regressions、
      `SGR mouse` middle/right drag regressions、
      `CSI 7~` / `CSI 8~` legacy Home/End regressions、
      `CSI 11~` / `CSI 14~` / `CSI 17~` / `CSI 20~` / `CSI 23~`
      legacy function-key regressions、
      `CSI B/C/D` plain direction regressions、`CSI Z` xterm BackTab regression、
      kitty `Alt+Tab` modifier regression、kitty `Ctrl+Esc` modifier regression、
      line-feed-as-enter regression、ctrl-h-backspace-alias regression、
      `CSI 1~` legacy Home regression、`CSI 4~` legacy End regression、
      `SS3 Q/R/S` legacy `F2/F3/F4` regression、
      single-byte `Tab` regression、single-byte `Backspace` regression、
      `ESC ESC` bare-escape ordering regression、`Alt+ASCII` regression、
      `Alt+Enter` regression、
      invalid Alt+UTF-8 lead ESC preservation regression、
      incomplete Alt+UTF-8 prefix ESC preservation regression、
      incomplete SS3 prefix ESC preservation regression、
      incomplete CSI prefix ESC preservation regression、
      SGR mouse release contract regression、
      SGR mouse motion-only contract regression、
      SGR mouse drag-with-modifiers regression、
      SGR mouse scroll-up regression、
      SGR mouse scroll-down-with-ctrl regression、
      CSI arrow-with-ctrl regression、
      CSI pagedown-with-shift-alt regression、
      CSI home-with-shift regression、
      CSI end-with-ctrl regression、
      CSI f5-with-shift-ctrl regression、
      CSI f12-with-alt regression、
      CSI insert regression、
      CSI delete-with-ctrl regression、
      CSI pageup-with-shift regression、
      CSI f10-with-alt-ctrl regression、
      bracketed paste start regression、
      SS3 legacy f1 regression、
      SS3 legacy end regression、
      SS3 legacy home regression、
      kitty shift-enter modifier regression、
      kitty alt-backspace modifier regression、
      kitty alt-codepoint modifier regression、
      lone `ESC` waits-for-more-before-EOF regression、
      incomplete `CSI` waits-for-more regression、
      incomplete `SS3` waits-for-more regression、
      incomplete UTF-8 waits-for-more regression、
      incomplete Alt+UTF-8 waits-for-more regression、
      invalid-bytes-recover-following-UTF8 regression、
      invalid-byte-between-events-is-skipped regression、
      kitty `Shift+Alt+Tab` normalization regression、
      kitty `Shift+Alt+Ctrl+Tab` normalization regression、
      incomplete kitty keyboard waits-for-more regression、
      incomplete SGR mouse waits-for-more regression、
      incomplete kitty keyboard prefix preserves esc regression、
      incomplete SGR mouse prefix preserves esc regression、
      direct `ESC` alt-tab regression、
      direct `ESC` alt-backspace regression、
      direct `ESC` alt-ctrl-space regression、
      terminal options default/editor-default contract regression、
      terminal options native-selection suppression regression、
      terminal options application-selection mouse-mode regression、
      wezterm capability profile regression、
      ghostty capability profile regression、
      sixel capability independence regression、
      bracketed paste close marker regression、kitty keyboard Shift-Tab normalization regression、
      Alt+UTF-8 preservation regression、Ctrl+Space preservation regression、control punctuation regression，
      确保 lone `ESC`、截断 `ESC [` / `ESC O`、截断 UTF-8 / Alt+UTF-8 在 non-EOF 路径里会先等待更多字节，
      leading invalid bytes 也会在 terminal queue seam 中被逐字节跳过，
      后续合法事件仍会继续被扫描出来，
      kitty `Tab -> BackTab` normalization 在 strip synthetic `Shift` 的同时也会保留真实的 `Alt` / `Ctrl`，
      kitty keyboard 与 SGR mouse 进入 deep `CSI` sub-branch 后，在 non-EOF 路径里也会继续等待更多字节，
      且即使在 EOF/timeout 路径里也会先保住 bare `Esc`，随后把 `[` / `9` / `<` 等 remainder bytes
      继续按普通字符交回给 terminal seam，
      direct `ESC` prefix 也不只会提升普通 ASCII / Enter / UTF-8，连 `Tab` / `Backspace` /
      `Ctrl-Space` 这类 non-char/control-key 路径也会稳定保留 `kmAlt`，
      `TTerminalOptions.Default` / `EditorDefault` / `NativeSelectionWheel`
      的 policy truth 也已进入 focused proof，明确 freeze 了 mouse tracking / alternate scroll /
      selection mode 的组合语义，
      `WezTerm` / `Ghostty` 这类 kitty-compatible terminal 的 capability profile
      也已进入 focused proof，明确 freeze 了 kitty keyboard candidate 与 kitty image protocol
      的组合语义，而 `foot` / sixel 这类输出能力也被证明不会误提升成 kitty keyboard candidate，
      而无效/截断 Alt+UTF-8 前缀、`ESC O` 与 `ESC [` 在 EOF/timeout 路径里都会先保住 bare `Esc`、
      `SGR 1006` release 会通过最终字符 `m` 暴露 `mkUp` 同时保留按钮身份，
      `Cb=35` 的 motion-only SGR mouse 会稳定暴露为 `mkMoved + mbNone`，
      `Cb=44` 的 motion+left-button+shift+alt 会稳定暴露为 `mkDrag + mbLeft + [kmShift, kmAlt]`，
      `Cb=64` / `Cb=81` 的 SGR scroll 也会稳定暴露为 `mkScrollUp` / `mkScrollDown` 并保留 `kmCtrl`，
      `CSI 1;5A` 会稳定暴露为 `kcUp + [kmCtrl]`，`CSI 6;4~` 会稳定暴露为
      `kcPageDown + [kmShift, kmAlt]`，kitty `CSI 13;2u` / `CSI 127;3u` / `CSI 97;3u`
      也会稳定保留 `Shift+Enter`、`Alt+Backspace`、`Alt+a` 的 modifier truth，
      `CSI 1;2H` / `CSI 1;5F` / `CSI 15;6~` / `CSI 24;3~` / `SS3 P` / `SS3 H`
      也会稳定保留 Home/End/F-key/legacy SS3 truth，
      `CSI 2~` / `CSI 3;5~` / `CSI 5;2~` / `CSI 21;7~` / `CSI 200~` / `SS3 F`
      也会稳定保留 Insert/Delete/PageUp/F10/paste-start/legacy End truth，
      `CSI 201~` 被静默吞掉、
      kitty `CSI 9;2u` 与 xterm `CSI Z` 一起归一为 `kcBackTab`，
      ESC 前缀 Unicode 输入不会丢失 `kmAlt`，`Ctrl+Space` 不会在 parser 层被吞掉，且
      `Ctrl-\ / Ctrl-] / Ctrl-^ / Ctrl-_` 不会再被错误解成 `| } ~ DEL`。

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
- 2026-06-02 merge-prep truth：README/catalog/facade 已对齐；`test_tui_facade` 曾为 5/5；
  `nextpas.core.text.number.pow10.inc` typed constant warning 已修复，facade 编译 warning=0；
  benchmark smoke 无 warning 行。
- 2026-06-03 docs/facade truth：README quick-start 已改为 `nextpas.core.tui.ext` 并由
  `test_tui_ext_facade 1/1` 证明；`test_tui_facade 7/7` 现在承担 `nextpas.core.tui.full`
  compatibility proof；`docs/tui/TIER_REGISTRY.md` 与 `docs/tui/WIDGET_CATALOG.md`
  已冻结四层 facade ownership。
- 2026-06-03 core boundary truth：`test_tui_core_facade` 仍为 `1/1`，且 negative harness 现已同时拒绝
  `TApp` / `clipboard` / `image capability` / `TGauge` / `TSparkline` / `TCanvas`，
  证明默认 `nextpas.core.tui` 没有把 representative advanced widgets 回流进来。
- 2026-06-03 terminal/input truth：`test_tui_terminal` 现为 `103/103`；single-byte `9` /
  `127` 现在都已被 focused proof 冻结为 `kcTab` / `kcBackspace`，single-byte `10` / `8`
  也都已被 focused proof 冻结为 `kcEnter` / `kcBackspace`；`ESC ESC` 也会稳定按顺序发出
  两个 bare `kcEsc`；`ESC a` 与 `ESC CR` 也都已被 focused proof 冻结为
  `kcChar('a') + [kmAlt]` 与 `kcEnter + [kmAlt]`；同时 `ESC HT` / `ESC DEL` / `ESC NUL`
  现在也已被 focused proof 冻结为 `kcTab + [kmAlt]` / `kcBackspace + [kmAlt]` /
  `kcChar(' ') + [kmAlt, kmCtrl]`，证明 direct `ESC` prefix promotion 不会只停留在
  printable/enter/utf8 路径；`CSI 1~` / `CSI 4~` 也已被 focused proof
  冻结为 legacy `Home` / `End` contract，`SS3 Q/R/S` 也已被 focused proof 冻结为 legacy
  `F2/F3/F4` contract；plain `CSI B/C/D` 也已被 focused proof 冻结为 `kcDown` / `kcRight` /
  `kcLeft` contract，plain `CSI H/F` 也已被 focused proof 冻结为 `kcHome` / `kcEnd` contract，
  control-letter representative `Ctrl+A/Ctrl+G/Ctrl+K/Ctrl+N/Ctrl+Z` 也已被 focused proof
  冻结为 `ParseSingleByte` control-letter formula contract；`CSI Z` 也已被 focused proof
  冻结为 xterm `kcBackTab` contract，
  kitty `CSI 9;3u` / `CSI 27;5u` 也已被 focused proof 冻结为
  `kcTab + [kmAlt]` / `kcEsc + [kmCtrl]` contract；同时 `CSI 7~` / `CSI 8~` 也已被 focused proof
  冻结为 legacy `Home` / `End` aliases，`CSI 11~` / `CSI 14~` / `CSI 17~` / `CSI 20~` /
  `CSI 23~` 也已被 focused proof 冻结为 `F1` / `F4` / `F6` / `F9` / `F11` contract；
  `SGR 1006` 的 `CSI < 1;...M/m`、`CSI < 2;...M/m`、`CSI < 33;...M`、`CSI < 34;...M`
  也都已被 focused proof 冻结为 middle/right 的 `mkDown` / `mkUp` / `mkDrag` button-identity contract；
  lone `ESC` 在 `AAtEOF=False` 时现在会继续等待更多字节，直到 `AAtEOF=True` 才回退成 bare `kcEsc`；
  incomplete `ESC [` / `ESC O` / UTF-8 / Alt+UTF-8 在 non-EOF 路径里也都会继续缓冲，待 remainder 到达后再解析成最终事件；
  incomplete kitty keyboard / SGR mouse prefixes 现在也会在 deep `ParseCSI` branches 里继续缓冲，
  待 final `u` / `M` 到达后再解析成最终 key / mouse event，不会在协议子路径内部提前掉出 `NeedMore` contract；
  同时 incomplete kitty keyboard / SGR mouse prefixes 在 EOF/timeout 路径里现在也都会先发出 bare `kcEsc`，
  然后把至少 `[` / `9` / `<` 这些 remainder bytes 继续按普通字符交回后续 poll，
  不会在 deep `ParseCSI` fallback 路径里把前导 Esc 或剩余字节一起吞掉；
  leading invalid bytes 现在也会在 `TryParseQueuedEvent` 的 `prInvalid` loop 里被逐字节跳过，
  后续合法 UTF-8 或 ASCII 事件仍会继续被扫描并返回，不会因为坏字节夹在队列里就卡死；
  无效/截断 Alt+UTF-8 前缀、
  `ESC O` 与 `ESC [` 在 EOF/timeout 路径里现在都会先发出 bare `kcEsc`，不再吞掉前导 Esc；
  其中 `O` / `[` remainder 仍会继续按普通字符解析，而 Alt+UTF-8 remainder 仍沿用当前
  invalid/truncated UTF-8 语义；`CSI 200~` 仍产生 `evPaste`，
  `CSI 201~` 则被 terminal seam 静默吞掉，不再向消费者泄漏 `evNone`；kitty `CSI 9;2u`
  现在与 xterm `CSI Z` 一样归一为 `kcBackTab`，不再泄漏 synthetic `kmShift`；`Alt+UTF-8`
  同时 kitty `CSI 9;4u` / `CSI 9;8u` 也已被 focused proof 冻结为
  `kcBackTab + [kmAlt]` / `kcBackTab + [kmAlt, kmCtrl]` contract，证明 BackTab normalization
  只会 strip synthetic `kmShift`，不会把真实 modifiers 一起吞掉；`Alt+UTF-8`
  也会整体解析为 `kcChar + kmAlt`，不再在 ESC 丢弃后退化成裸 Unicode 字符；`Ctrl+Space`
  现在会稳定发出 `kcChar(' ') + kmCtrl`，不再在 `NUL` 路径中被静默丢弃；`Ctrl-\ / Ctrl-] / Ctrl-^ / Ctrl-_`
  现在也会稳定发出正确 control punctuation 码点，而不是被错误解成 `| } ~ DEL`；同时
  `TTerminalOptions.Default` / `EditorDefault` 现在也已被 focused proof 冻结为
  full mouse tracking on、alternate scroll off 的默认 contract；`NativeSelectionWheel`
  现在也已被 focused proof 冻结为 suppress runtime mouse tracking 并启用 alternate scroll，
  而 application selection 也已被 focused proof 冻结为会保留显式配置的 mouse mode；
  `COLORTERM=24bit` 现在也已被 focused proof 冻结为 truecolor alias contract；
  `TERM_PROGRAM=WezTerm` / `ghostty` 现在也已被 focused proof 冻结为
  kitty keyboard detected-but-negotiation-pending + `ipKitty` image protocol contract；
  `TERM=foot` 现在也已被 focused proof 冻结为 `ipSixel` image protocol truth，
  且不会误提升成 kitty keyboard candidate；
  同时
  `SGR 1006` 的 `CSI < 0;...m` 现已被 focused proof 冻结为 `mkUp + 对应按钮`，
  `CSI < 35;...M` 也已被 focused proof 冻结为 `mkMoved + mbNone`，`CSI < 44;...M`
  已被 focused proof 冻结为 `mkDrag + mbLeft + [kmShift, kmAlt]`，`CSI < 64;...M`
  与 `CSI < 81;...M` 也已被 focused proof 冻结为 `mkScrollUp` / `mkScrollDown + [kmCtrl]`；
  `CSI 1;5A`、`CSI 6;4~`、`CSI 13;2u`、`CSI 127;3u`、`CSI 97;3u` 也都已被 focused proof
  冻结为各自的 modifier-preserving keyboard contract；`CSI 1;2H`、`CSI 1;5F`、`CSI 15;6~`、
  `CSI 24;3~`、`SS3 P`、`SS3 H` 也都已被 focused proof 冻结为 Home/End/F-key/legacy SS3 contract；
  `CSI 2~`、`CSI 3;5~`、`CSI 5;2~`、`CSI 21;7~`、`CSI 200~`、`SS3 F`
  也都已被 focused proof 冻结为 Insert/Delete/PageUp/F10/paste-start/legacy End contract。
- 2026-06-02 final verification envelope：fresh focused tests（facade/widget_intf/buffer）全通过且 heaptrc 0；
  full TUI tests `32 projects / 246 passed / 0 failed / 13 heaptrc zero summaries / warning_count=0`；
  benchmark smoke `4` 项、`status=0`、`warning_count=0`。
- 2026-06-03 主线真相更新：本地 `main` 已包含
  `5b04c3fe merge(tui): integrate feat/tui-migration onto main`。因此 TUI 当前阶段不再是
  “等待是否能合入主线”，而是“进入 post-merge dual-track strengthening”。
- 2026-06-02 clean integration candidate：已在
  `/home/dtamade/.config/superpowers/worktrees/nextPas/tui-main-merge-20260602`
  的 `codex/tui-main-merge-20260602` 分支上，从 `main@8581cd55` 实际 merge
  `feat/tui-migration@00a6dd93`；冲突仅在共享 planning files，已保守保留 `main` 侧当前控制面。
- 2026-06-02 post-merge proof：supporting/focused tests
  `test_platform_console_raw 5/5`、`test_grapheme 11/11`、`test_text_width 19/19`、
  `test_tui_facade 5/5`、`test_tui_widget_intf 4/4` 均 heaptrc 0；full TUI tests 仍为
  `32 projects / 246 passed / 0 failed / 13 heaptrc zero summaries / warning_count=0`；
  benchmark smoke 仍为 `4` 项、`status=0`、`warning_count=0`；3 个 TUI examples 全部可编译且
  `warning_count=0`。
- 2026-06-03 repo-level verify truth（第三轮）：
  `tests/run_all_tests.sh` 已恢复，`make -C core test` / `make -C core examples` 已恢复 green，
  `make -C core benchmarks` 也已从“目录缺 Makefile”推进到真实 benchmark API 漂移，并已继续收口
  `bench_hash` 对 `nextpas.core.hash` facade 的旧 API 调用；targeted `bench_hash` 现已可运行。
  当前新的 benchmark blocker 是 `bench_sort_fpcrtl` 的时间尺度异常：full sweep 已推进到该
  compare baseline，但它长时间占满单核，直接加 `timeout 30s` 运行返回 `exit=124`。`bash build/verify_local.sh`
  继续深入后，LLVM `obj-compose` 的真实参数类型 bug 已修复，并新增 focused regression
  `test_hir_class_obj_compose_contract` 锁定调用点必须发射 `i64` 实参而非 `ptr`。同时已确认
  `llvm_linked_list` 不是可机械回滚的 42 drift，而是 `0ac172f1` 的真实修正反例。
  `hello_with_units` 的 semantic smoke expectation drift 现已收口：
  `build/verify_local.sh` 已对齐 live `symbol-count=19` / `type-count=27`，
  `semantic-smoke-check=pass`。`core-time-check` 也已对齐 live
  `--- nextpas.core.time: 16 total, 16 passed, 0 failed ---` 并恢复为 pass。
  `core-sync-posix-fallback-check` 的 forced fallback 摘要失配也已收口：
  force flag 只切换 Linux wait-address 到 POSIX fallback 实现，不裁剪
  `test_sync.lpr` 的测试注册；live 稳定输出
  `--- nextpas.core.sync: 28 total, 28 passed, 0 failed ---`，旧的
  `11 total, 11 passed, 0 failed` 已确认只是 verify expectation drift。
  fresh `bash build/verify_local.sh` 现已全绿，输出 `verify-local=pass` 与
  `human-summary=local verification passed`。这进一步证明这些 wider-route truth
  cleanup 不应归因到 `nextpas.core.tui` merge regression。
- **迁移主体完成。** 当前状态已提升为 verified merge candidate；剩余仅是等待安全的主线窗口推进
  `main` 引用或决定正式合并路径。
- **2026-06-03 路线修正：** 上述“等待安全主线窗口”已不再是主任务，因为 TUI 已经进入本地 `main`。
  当前主任务改为按 `core/docs/plans/2026-06-03-tui-dual-track-design.md` 推进 post-merge
  strengthening，把终端正确性、应用框架、性能和 DX 的后续演进装进清晰边界里。

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
- 文档注释 {\*\* \*} 内不能出现裸 { （触发嵌套注释告警）
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
- [x] 2026-06-03 backend runtime/output correctness：`test_tui_backend` 已扩到 `12/12`，新增
      alternate-screen click-tracking sequence regression、
      alternate-screen scroll-only regression、
      leave-alternate reset/disable ordering regression、
      adjacent-patch cursor/style reuse regression、
      default-style reset regression、
      style-change reapply regression、
      wide-glyph cursor-advance regression，
      确保 `TAnsiBackend.EnterAlternate(amMouseClick, False)` 会先 enter alt，再启用 click tracking，
      `EnterAlternate(amMouseNone, True)` 会只启用 alt screen + alternate scroll，
      `LeaveAlternate(amMouseDrag, True)` 则会先 `SGR reset`，再 disable drag/extended mouse
      与 alternate scroll，最后 leave alt screen；同时 `DrawPatchesN`
      也已被 focused proof 冻结为：
      相邻同样式 patch 会复用光标与 style state、回到默认样式时会 reset 防止颜色泄漏、
      样式真正变化时会 reset + reapply 但不会多发光标移动、宽字形后的普通 cell
      不会再因 `Width/Skip` 差异被误判成 style change。
- 2026-06-03 backend/runtime truth：`test_tui_backend` 现为 `12/12`；`TAnsiBackend`
  进入/离开 alternate screen 的 control-plane sequence 现在也已被 focused proof 冻结：
  `EnterAlternate(amMouseClick, False)` 会稳定发出 `1049h -> 1000h -> 1006h`，
  `EnterAlternate(amMouseNone, True)` 会稳定发出 `1049h -> 1007h`，
  `LeaveAlternate(amMouseDrag, True)` 会稳定发出
  `0m -> 1002l -> 1006l -> 1007l -> 1049l`，
  证明 runtime policy 到 ANSI sequence 的组合顺序不再只是实现细节，而是受保护 contract；同时
  `DrawPatchesN` 的 render cache 旧实现曾把 `Width/Skip` 错并进 style truth，
  导致宽字形后的 default-style cell 多发一次 `SGR reset`；现已通过 focused regression
  打出并修复，style cache 只再跟踪 `Fg/Bg/Ul/Modifier`，backend output truth 因而继续收口到
  真正影响 ANSI 样式输出的字段。
