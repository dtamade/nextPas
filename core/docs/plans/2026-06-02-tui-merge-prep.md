# nextpas.core.tui Merge Prep

## 结论

`nextpas.core.tui` 当前已具备合并到 `nextpas.core` 主线的模块内条件：

- facade / README / catalog / 目标树 已对齐
- TUI 自身公开面测试通过
- 全量 TUI 回归通过
- 4 个 benchmark smoke 可运行
- facade 编译 warning 已收口到 0

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

## 建议的合并说明

1. `nextpas.core.tui` 模块内测试、文档、benchmark smoke 已闭环
2. facade compile 现在已是零 warning，可直接作为合并前基线
3. 剩余工作集中在最终 verification envelope 与合并动作本身

## 推荐合并前命令

```bash
make -C core/tests/nextpas.core.tui/test_tui_facade clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
make -C core/tests/nextpas.core.tui/test_tui_widget_intf clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
make -C core/tests/nextpas.core.tui/test_tui_buffer clean test FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc
FPC=/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc core/benchmarks/nextpas.core.tui/run_all.sh
```
