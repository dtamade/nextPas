# nextpas.core.tui 双轨并行强化设计

## 背景真相

`nextpas.core.tui` 的迁移主体已经完成，并且本地 `main` 已经包含 TUI 合并提交
`5b04c3fe merge(tui): integrate feat/tui-migration onto main`。

这意味着当前问题已经从“是否能把 TUI 迁进去”切换成“如何把它继续做成 FreePascal 领域最强的
TUI 框架”。当前风险不在模块缺失，而在后续强化路线如果没有分层边界，会把下面几类问题重新搅在一起：

- 终端正确性与应用框架能力共用一个默认门面，导致稳定 surface 难以冻结
- capability 探测、兼容投影和真实运行态混在一起，调用方很难知道什么是 runtime truth
- 图像、clipboard 这类高波动能力会回流污染默认 facade
- app/runtime 层如果直接依赖探测细节，会拖慢 terminal core 的正确性收口

## 目标

方案 C 采用双轨并行，但不是平均用力，而是通过分层门面把两条主轴同时推进：

1. `Terminal Correctness Core`
   保证 Unicode、输入协议、ANSI/鼠标/图像能力边界、终端生命周期、跨终端兼容的默认正确性。
2. `Application Framework Ext`
   在不污染默认正确性闭包的前提下，做强状态管理、任务系统、多屏、多窗口演进点和可组合 widget/app 架构。

总目标是同时服务用户提出的 A/B/C/D：

- A 终端正确性第一
- B 应用框架第一
- C 性能第一
- D 开发体验第一

执行顺序上采取“正确性定边界，框架并行落地，性能和 DX 穿透全程”的策略，而不是先堆功能再回头修边界。

## 第一里程碑范围

第一里程碑采用“双轨平衡版”，要求 Core 和 Ext 都拿出可以持续回归的稳定主线。

### 在范围内

- 冻结 `core / ext / experimental / full` 四层 facade 语义
- 冻结 terminal capability contract 的 runtime truth 语义
- 让 `core` 成为默认入口，只包含终端正确性的最小闭包
- 让 `ext` 承载稳定 app/runtime 能力
- 让 `experimental` 隔离高波动协议与副作用能力
- 为四层 facade 建 focused compile/runtime/leak gates

### 不在范围内

- 不做仓库级全量 benchmark 体系
- 不承诺所有终端的真实图像协议 runtime 证据
- 不把多窗口系统一次性做完；第一里程碑只把演进 seam 留对
- 不为了兼容旧宽门面而放弃新的默认边界

## 设计总览

### 1. 四层门面

#### `nextpas.core.tui`

默认入口，只暴露终端正确性的最小闭包：

- base / color / modifier / style / cell
- buffer / overlay / text / text.format
- layout / layout.grid / layout.dsl
- event / input
- ansi / backend.ansi / backend.test
- terminal
- 基础 widget：block / paragraph / list / table / input / tabs / scrollbar / clear

这个门面的职责只有四类：

- 文本与 layout 正确性
- frame/render 正确性
- input/event 正确性
- 基础 widget 组合能力

#### `nextpas.core.tui.ext`

稳定增强入口，只承载已经准备长期维护的框架能力：

- app / app.screen
- task / frame_budget
- focus / interaction / keybind
- theme / anim / animator / loading
- panel 和稳定扩展 widget

`ext` 可以依赖 `core`，但不能重新定义 terminal truth，也不能反向要求 `core` 引入 experimental protocol。

#### `nextpas.core.tui.experimental`

高波动能力隔离层：

- image_cap
- sixel
- image_mgr
- clipboard
- 后续其他强副作用、强环境依赖的协议能力

实验层允许探测策略和 API 快速迭代，但不能默认回流到 `core`。需要这些能力的消费方必须显式 opt-in。

#### `nextpas.core.tui.full`

迁移兼容门面：

- 保留旧的宽 surface
- 服务现有调用方逐步迁移
- 不作为新代码默认入口

### 2. 双轨主轴

#### A 轨：Terminal Correctness Core

这一轨负责把默认正确性做到最强，优先级最高：

- grapheme-aware 宽度与写入覆盖语义
- ANSI diff/render 生命周期
- input parser 对 ASCII / UTF-8 / CSI / kitty / SGR mouse 的正确投影
- terminal enter/leave、raw mode、SIGWINCH、cursor、alt-screen 的一致性
- capability profile 的 runtime truth

Core 的原则是“保守启用，显式降级”。如果 capability 不能证明 active，就只能停在 detected 或 fallback。

#### B 轨：Application Framework Ext

这一轨负责把应用开发组织力做到最强：

- `TApp` 事件循环
- `app.screen` 的多屏切换与生命周期
- `task` 的后台任务、取消、结果回传
- `focus` / `interaction` / `keybind` 的 UI 行为骨架
- `panel` 等复杂组合 widget 的稳定组织方式

Ext 的原则是“框架消费 Core truth，不重做 terminal 判断”。App 层只读取冻结后的 capability/runtime state，
不直接接触探测 heuristics。

### 3. Capability Contract

`TTerminal.CapabilityProfile` 必须成为运行时唯一真相。每个 capability 至少要能表达：

- `Requested`
- `Detected`
- `Active`
- `Verified`
- `FallbackReason`

语义约束如下：

- `Requested`：调用方或默认策略是否申请过该能力
- `Detected`：环境 hint、probe 或静态规则判断“可能可用”
- `Active`：当前 session 实际启用的能力
- `Verified`：是否有更强证据证明 active 真成立
- `FallbackReason`：为什么没有进入 active，或为什么从 detected 降级

兼容属性如 `HasTruecolor`、`HasKittyKeyboard`、`ImageProtocol` 只保留为 `Active` 状态的投影。
它们不能再承担 candidate hint 或决策源职责。

### 4. App Framework Boundary

第一里程碑不强推最终多窗口实现，但要把 seam 立对：

- `TApp` 负责 run loop、frame cadence、event 分发、task drain
- `TScreen` 负责视图层级、输入处理、render 入口
- `task` 负责后台工作与主线程结果回投
- `panel` / complex widget 负责局部布局编排，不承担进程级 runtime 决策

未来多窗口能力应建立在 screen/session/frame budget 之上，而不是直接从 terminal 分叉出第二套 runtime。

## 第一里程碑交付物

### Core 交付物

- `nextpas.core.tui` 默认门面冻结
- core facade 的正向 compile proof
- core facade 的反向 reject proof
- terminal capability contract focused tests
- terminal / input / buffer / backend focused regressions 持续全绿

### Ext 交付物

- `nextpas.core.tui.ext` 门面冻结
- `TApp`、`app.screen`、`task`、`panel` 的 focused surface tests
- 至少一条 app/runtime happy path proof，证明 ext 能稳定消费 core truth

### Experimental 交付物

- `nextpas.core.tui.experimental` 门面冻结
- image / clipboard 能力与默认 core surface 隔离
- experimental focused compile tests

### Migration 交付物

- `nextpas.core.tui.full` 保持兼容
- README 和目标树明确说明四层用法与推荐入口

## 验证路线

第一里程碑只维护 TUI 相关 focused gates，不跑全量仓库测试。

建议 gate 组：

- `test_tui_core_facade`
- `test_tui_ext_facade`
- `test_tui_experimental_facade`
- `test_tui_facade`（兼容面）
- `test_tui_terminal`
- `test_tui_backend`
- `test_tui_image_cap`
- `test_tui_buffer`
- `test_tui_widget_intf`

验证要求：

- 改动面 compile/runtime proof 必须存在
- 所有 focused tests 必须带 heaptrc `0 unfreed memory blocks`
- benchmark 只保留 TUI smoke：
  - `bench_diff`
  - `bench_render`
  - `bench_input`
  - `bench_layout`

## 执行顺序

第一里程碑按下面顺序推进：

1. 文档和 truth reset
   明确 TUI 已进主线，停止把历史 merge candidate 当成当前唯一落地点
2. facade freeze
   收口 `core / ext / experimental / full`
3. capability contract freeze
   收口 `CapabilityProfile` 与兼容投影关系
4. focused gate freeze
   把 facade/capability/terminal/app 的 focused tests 补齐
5. 小步强化
   在冻结边界内推进 Unicode、input、task、screen、panel 等增强

## 风险与对策

### 风险 1：默认门面继续变宽

对策：用 core negative proof 防止 `app`、`clipboard`、experimental protocol 回流到默认入口。

### 风险 2：capability heuristic 污染 runtime truth

对策：把 `Detected` 和 `Active` 明确拆开，兼容属性只读 active 投影。

### 风险 3：框架层反向绑死 terminal 实现细节

对策：ext 只消费 core 已冻结 contract，不直接依赖探测实现或 experimental type。

### 风险 4：历史 merge-prep 文档继续误导后续工作

对策：在 merge-prep 和目标树里同步写明主线已含 TUI，后续工作转入 post-merge strengthening。

## 第一里程碑完成判定

只有同时满足下面条件，第一里程碑才算完成：

- `nextpas.core.tui` 成为真正的 correctness-first 默认入口
- `nextpas.core.tui.ext` 成为稳定的 app/runtime 入口
- `nextpas.core.tui.experimental` 把高波动能力隔离干净
- `CapabilityProfile` 成为 runtime truth，兼容属性不再承担探测语义
- focused TUI tests 与 benchmark smoke 全绿，并保留 heaptrc 0 泄漏证据

## 结论

方案 C 的关键不是“所有方向一起冲”，而是用清晰分层让两条主轴并行且不互相拖垮。

`core` 负责把终端正确性做到最强，`ext` 负责把应用框架做到最强，`experimental` 负责吸收高波动协议，
`full` 负责迁移兼容。只有先把这套边界冻住，后续性能、DX、多窗口和协议增强才不会持续反复打架。
