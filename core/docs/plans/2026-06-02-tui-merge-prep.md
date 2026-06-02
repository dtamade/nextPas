# nextpas.core.tui Merge Prep

## 结论

`nextpas.core.tui` 当前已具备合并到 `nextpas.core` 主线的模块内条件，并且已经在干净 integration
候选分支上完成了一次真实 merge + post-merge verification：

- facade / README / catalog / 目标树 已对齐
- TUI 自身公开面测试通过
- 全量 TUI 回归通过
- 4 个 benchmark smoke 可运行
- facade 编译 warning 已收口到 0
- examples 编译 warning 已收口到 0

当前已验证的候选分支信息：

- Worktree：`/home/dtamade/.config/superpowers/worktrees/nextPas/tui-main-merge-20260602`
- Branch：`codex/tui-main-merge-20260602`
- Base：`main@8581cd55`
- Merge source：`feat/tui-migration@00a6dd93`

注意：主 checkout `/home/dtamade/projects/nextPas` 仍然带有 unrelated dirty changes，本轮不安全直接推进
本地 `main`；当前交付物是 **verified merge candidate**，不是“已在现有主 checkout 完成快进”。

## Merge 前真相

### 1. 文档与公开面

- README quick-start 已改为真实可编译 API：`OnRenderCb`
- README quick-start 已由 `test_tui_facade` 编译覆盖
- `WIDGET_CATALOG.md` 的 `TChatTheme` 命名已与 facade 对齐

### 2. 测试基线

- 全量 TUI 测试项目：`32`
- 全量 TUI 用例：`246`
- heaptrc 摘要数：`13`
- 关键 focused 证据：
  - `test_tui_facade`：`5/5`，`0 unfreed memory blocks`
  - `test_tui_widget_intf`：`4/4`，`0 unfreed memory blocks`
  - `test_tui_buffer`：`21/21`，`0 unfreed memory blocks`

### 2.1 2026-06-02 最终 verification envelope

- focused tests fresh pass：
  - `test_tui_facade` → `5/5`，heaptrc `0 unfreed memory blocks`
  - `test_tui_widget_intf` → `4/4`，heaptrc `0 unfreed memory blocks`
  - `test_tui_buffer` → `21/21`，heaptrc `0 unfreed memory blocks`
- full TUI tests fresh pass：
  - `32` 项目
  - `246/246` 用例通过
  - `13` 个 heaptrc zero summaries
  - `warning_count=0`

### 2.2 2026-06-02 integration candidate 真相

- 实际 merge 在干净 worktree 中执行，未触碰主 checkout 的 unrelated WIP。
- merge 冲突全部落在共享 planning/control files，而不在 TUI 源码本体：
  - `findings.md`
  - `progress.md`
  - `task_plan.md`
  - `core/findings.md`
  - `core/progress.md`
  - `core/task_plan.md`
- 冲突处理策略：这些共享控制面一律保留 `main` 侧版本，避免把 HTTP/crypto/platform 等并行批次的
  当前执行面误改成 TUI 语境；TUI 自身的路线图、merge-prep、架构与 benchmark 真相继续由
  `core/docs/plans/` 和 `core/docs/tui/` 承载。
- supporting/focused post-merge fresh pass：
  - `test_platform_console_raw` → `5/5`，heaptrc `0 unfreed memory blocks`
  - `test_grapheme` → `11/11`，heaptrc `0 unfreed memory blocks`
  - `test_text_width` → `19/19`，heaptrc `0 unfreed memory blocks`
  - `test_tui_facade` → `5/5`，heaptrc `0 unfreed memory blocks`
  - `test_tui_widget_intf` → `4/4`，heaptrc `0 unfreed memory blocks`
- full TUI regression post-merge：
  - `32` 项目
  - `246/246` 用例通过
  - `13` 个 heaptrc zero summaries
  - `warning_count=0`
- benchmark smoke post-merge：
  - `4` 个 benchmark
  - `status=0`
  - `warning_count=0`
- TUI examples post-merge：
  - `demo_hello` / `demo_layout` / `demo_widgets` 全部可编译
  - `warning_count=0`
  - 期间顺手修复 `demo_widgets.lpr` 的 `case` 未覆盖 warning；仅补 `else ;`，不改运行语义

### 3. Benchmark smoke 基线

- `DiffInto 200x50 (10 changed rows)`：`46.7 us`
- `DiffInto 200x50 (identical)`：`26.3 us`
- `Full render 120x40 (block+list+para+gauge)`：`155.3 us`
- `ParseOne ASCII/CSI/UTF-8`：`44-50 ns`
- `Grid 8x8 uniform`：`4.4 us`

## Warning 审计

### facade 编译 warning

- warning 总数：`0`
- TUI 自身单元 warning 行数：`0`
- `nextpas.core.text.number.pow10.inc` warning 行数：`0`

结论：此前 facade 编译 warning 的唯一来源 `nextpas.core.text.number.pow10.inc` 已通过
`QWord($...)` typed constant 显式类型化修复；当前 `uses nextpas.core.tui` 编译面已达到 warning=0。

### benchmark smoke warning

- warning 行数：`0`

### benchmark smoke fresh envelope

- `status=0`
- benchmark 数：`4`
- `warning_count=0`

### examples fresh envelope

- `status=0`
- example 数：`3`
- `warning_count=0`

## 建议的合并说明

1. `nextpas.core.tui` 模块内测试、文档、benchmark smoke 已闭环
2. facade compile 现在已是零 warning，可直接作为合并前基线
3. 实际 merge candidate 已验证通过；剩余工作是等一个安全的 `main` 窗口来推进主 checkout 或决定正式合并路径

## 推荐合并前命令

```bash
make -C core/tests/nextpas.core.tui/test_tui_facade clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
make -C core/tests/nextpas.core.tui/test_tui_widget_intf clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
make -C core/tests/nextpas.core.tui/test_tui_buffer clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc core/benchmarks/nextpas.core.tui/run_all.sh
```
