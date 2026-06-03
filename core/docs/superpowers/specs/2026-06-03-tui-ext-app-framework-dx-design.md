# nextpas.core.tui ext 应用框架与 D 轴设计（方案 C）

## 背景真相

`nextpas.core.tui` 的四层 facade 已经冻结：

- `nextpas.core.tui` 负责 correctness-first 默认闭包
- `nextpas.core.tui.ext` 负责 stable app/runtime framework
- `nextpas.core.tui.experimental` 负责高波动协议能力
- `nextpas.core.tui.full` 负责迁移兼容

当前 `ext` 也已经有了真实 runtime floor，而不只是门面说法：

- `TApp` 默认驱动 `TScreenStack`
- `TScreenStack` 多屏 lifecycle 已有 focused proof
- task completion dispatch contract 已收口到 `test_tui_app 22/22`
- `demo_hello` 已经改成 `TApp + TScreen` 的 app-first 入口

因此当前的核心问题，不再是“要不要做应用框架”，而是：

- 如何把 `D` 轴的开发体验做成长期稳定的 public contract
- 同时不牺牲 `A` 的终端正确性和 `C` 的热路径纪律
- 并且让 `B` 的状态/任务/多屏/多窗口演进始终放在正确 owning layer

如果这一步处理不好，后续最容易出现两类漂移：

- 把 DX 理解成 README 和 demo 的表层润色，导致 `ext` 内核 contract 不稳
- 过早引入大而全的状态系统或多窗口系统，反过来污染 `core` 的终端正确性闭包

## 目标

本 spec 不是重写双轨设计，而是把方案 C 在 `D` 轴上的执行规则写清楚：

- 产品目标仍然是 A/B/C/D 全部做强
- `D` 是当前对外主轴，要让用户更自然地写出 app-first TUI
- 但工程顺序不能是“先做表层 DX，再补框架骨架”

当前单一推荐路线是：

1. `B` 先收口稳定骨架
2. `A` 作为 release gate 持续卡住正确性边界
3. `D` 把已经稳定的骨架变成自然 API、示例和教学路径
4. `C` 贯穿 hot path 纪律，但大规模 benchmark 对照留到最后一轮

换句话说，这条线的真实执行顺序是：

`B 骨架 -> A 门禁 -> D 表层 -> C 放大`

而不是简单地“用户说要 DX，所以先堆 builder 和 demo”。

## 为什么 `D` 轴必须以 `B` 骨架先行

`nextpas.core.tui` 不是 retained-mode GUI toolkit，而是 immediate-mode TUI framework。
在这种模型里，真正决定 DX 是否稳定的不是 widget 目录大小，而是下面这些 runtime truth：

- app loop 是否只有一条稳定 happy path
- screen 的 ownership 是否明确
- task completion 是否只能沿一条可证明的主线程回投路径进入 UI
- shared state 会不会被偷渡成 widget 内部黑盒状态

如果这些点不先冻结，DX 只会变成：

- 例子能跑，但 contract 不稳
- facade 能编，但应用写大后 ownership 混乱
- 多屏、多任务、多窗口一叠加就重新回到 callback spaghetti

因此当前 `D` 轴的正确落法不是继续扩“更像产品”的表层 API，而是先把 `ext` 作为稳定应用框架层的边界写死。

## `ext` 的 owning contract

### 1. `TApp` 拥有唯一稳定 runtime loop

`TApp` 是 `ext` 的 runtime owner。app-first 路径里，只有 `TApp` 应该负责：

- 进入和退出 terminal session
- frame cadence
- poll timeout 选择
- event dispatch
- task completion drain
- quit 生命周期

在 app-first 路径里，普通应用不应该自己重新拼第二套 `TTerminal.BeginFrame/EndFrame/PollEvent` loop。

这条约束的意义不是限制灵活性，而是保证：

- `core` 继续允许底层 caller 直接持有 terminal loop
- `ext` 则始终只有一条稳定、可教学、可验证的 framework path

### 2. `TScreen` / `TScreenStack` 拥有导航和视图生命周期

`TScreen` 是 app-level view boundary，`TScreenStack` 是稳定导航 owner。

当前 contract 已经锁定：

- render 默认进入 top screen
- event 默认进入 top screen
- completion 默认进入 top screen
- stack 自己拥有 `Push / Pop / Replace` lifecycle
- screen 可以通过 `RequestQuit` 停止 app loop

因此后续所有 D 轴增强都必须建立在 screen-first 模型上，而不是重新退回“app callback 主导一切”的 ad-hoc 方式。

callback 仍保留，但它只应承担：

- 轻量 demo
- adapter escape hatch
- 少量特殊 orchestration

它不是长期推荐的主 happy path。

### 3. `TTaskManager` 只拥有后台执行，不拥有 UI policy

`TTaskManager` 的职责要继续保持克制：

- 负责后台任务调度
- 负责取消信号
- 负责 completion queue
- 负责把结果安全地回投到 app loop

它不应该偷偷承担：

- UI toast policy
- 默认 retry policy
- screen transition policy
- shared state mutation policy

UI policy 只能发生在 `TApp` / `TScreen` 的 completion handler 里。

这条边界现在已经有 focused truth：

- default top-screen ownership
- explicit callback precedence
- no dual propagation
- cancel / fail / success status pass-through
- quit-before-render-poll

后续 task 相关增强，也必须以这些 contract 为基础向前长，而不是回头做第二套异步入口。

### 4. 状态必须显式归属于 app 或 screen，不能藏进 widget

`nextpas.core.tui` 继续坚持 immediate-mode 纪律：

- widget 负责 render
- widget state 继续保持显式 record/object
- screen-local state 放在 screen 自己的字段里
- cross-screen shared state 归 app-owned layer

这意味着当前路线明确拒绝两种方向：

- widget 自带隐式 retained state，调用者不知 ownership
- framework 直接推一个全局单例 store，让所有 screen/widget 偷读偷写

当前最小 shared state seam 已经落在 `ext` 的 app-owned boundary：

- `TApp.SharedStateObject` 拥有 app-level shared state object
- `TScreenStack.SharedStateObject` 沿 runtime ownership 传播同一对象
- `TScreen.SharedStateObject` 提供 screen 只读观察面
- completion-time shared-state write ownership 仍留在 app callback / top-screen completion path

它不是全局 store，也不是 reducer / message bus。后续继续扩 shared state 时，也必须属于
`ext` 的 app-owned boundary，而不是：

- `core` terminal 层
- widget catalog 内部
- task thread 本身

### 5. 组合能力属于 `ext`，但不应反向污染 `core`

`panel`、theme、focus、interaction、keybind、loading、animator 这些能力的正确位置仍然是 `ext`。

它们可以让 DX 更自然，但不能反过来要求：

- 默认 `core` facade 导出 `TApp`
- terminal correctness contract 为了 app convenience 失去边界
- experimental protocol type 混进默认 app runtime path

因此这条 spec 再次锁定：

- `core` 继续做最小 correctness closure
- `ext` 继续做 stable framework surface
- `experimental` 继续做 opt-in protocol layer
- `full` 继续做 migration umbrella

## D 轴的真实交付物

方案 C 下，`D` 轴不再被定义成“多几个 demo”或“接口更短一点”，而是下面四类交付物一起成立：

### 1. 自然 public path

用户写稳定应用时，应当自然进入：

- `uses nextpas.core.tui.ext`
- `TApp + TScreen`
- screen-local state
- app/task completion on main thread

而不是：

- 先从 `full` 起步
- 直接裸写 terminal loop
- 再从 callback 慢慢拼出 framework

### 2. compile surface 足够自洽

`ext` facade 必须导出写一个小型 app 所需的自然类型，而不要求用户在多个单元间跳来跳去补最基本的名字。

最低要求包括：

- `TApp`
- `TScreen` / `TScreenStack`
- `TRect`
- `TBuffer`
- `TEvent`
- `TStyle`
- 常用 helper，如 `IsQuit` / `StyleDefault`

### 3. docs/examples 教学路径和 live source 一致

README、example 和 façade contract 必须持续对齐：

- 文档教什么，focused compile/runtime proof 就验证什么
- example 走什么 happy path，框架 contract 就优先保护什么 happy path

这条规则已经在 `demo_hello` 上落地，后续要继续保持，不允许 README 漂到一条未被 proof 支撑的“理想路径”。

### 4. 复杂能力也要保持 Pascal-native 直觉

后续如果往上补 shared state、workspace、多窗口、command palette、notification center，
也不应把 API 变成“只适合框架作者懂”的 DSL。

正确方向是：

- 明确 ownership
- 明确生命周期
- 明确线程边界
- builder 只服务自然表达，不掩盖状态真实归属

## 下一阶段的实现顺序

这份 spec 之后，不建议立刻跳到“大而全状态系统”或“真正多窗口 runtime”。

推荐顺序如下。

### 阶段 1：冻结最小 app-owned shared state boundary（已完成）

当前已经落地的最小 contract 是：

- `TApp.SharedStateObject`
- `TScreenStack.SharedStateObject`
- `TScreen.SharedStateObject`
- `test_tui_app` 已证明 commit-before-first-render 与 ownership-across-transition
- `test_tui_ext_facade` 已证明 ext compile/runtime surface 可直接使用这条 seam

这一步的意义是把 shared state 放进 `ext` 的 owning layer，而不是让它继续停留在
test-only truth 或 callback 约定俗成里。

### 阶段 2：继续收口 shared-state API ergonomics

下一步不该跳到大状态系统，而是继续把已经存在的边界做得更自然、更稳：

- typed injection / typed accessor 约定
- owner conventions 和生命周期约束
- 仍通过 completion path 保持主线程 write gate
- 仍不引入全局 store 或复杂 message bus

### 阶段 3：补齐 app-first examples/docs pack

在 runtime skeleton 和 shared state boundary 都稳定后，再系统化扩 docs/examples：

- single-screen hello
- multi-screen navigation
- task completion example
- panel/layout composition example
- theme/focus/keybind example

这样 teaching path 才不会继续漂。

### 阶段 4：为 workspace / multi-window 留对演进 seam

多窗口不是“再开一个 terminal loop”，而应建立在当前 `TApp + TScreenStack + frame budget + task`
之上。

这条线当前只要求把 seam 留对，不要求一口气实现完整 window manager。

最低约束是：

- workspace/window orchestration 归 `ext`
- 不绕过 `TApp`
- 不绕过 current terminal/session truth
- 不把 protocol feature 绑死进 window contract

### 阶段 5：最后再做 benchmark 对照放大

性能不是最后才想起，而是现在就不允许破坏 hot path discipline。

但真正大规模 benchmark 对照轮，仍应放在上述 contract 基本冻结之后。

否则会反复优化：

- 还没稳定的 API
- 还会继续移动的 ownership 边界
- 还没收口的 framework path

## 当前完成定义

当前这条 spec 写完后，并不意味着 `D` 轴已经完成。

它只意味着下面几件事已经被明确锁定：

- `D` 轴继续以 `ext` 为 owning layer
- 产品目标仍是 A/B/C/D 全都要
- 工程顺序采用 `B 骨架 -> A 门禁 -> D 表层 -> C 放大`
- `ext` 的最小 app-owned shared-state injection seam 已经落地
- 下一批实现优先继续收口 shared-state API ergonomics 和 teaching path

只要后续工作偏离这些规则，就应该视为偏离方案 C，而不是“只是实现细节不同”。

## 验证与收口要求

这份 spec 本身是 design-only 交付，不新增 runtime proof。

但它对后续所有 D 轴切片提出统一 gate：

- 改动 `ext` runtime contract：必须 fresh 跑 `test_tui_app`
- 改动 `ext` compile surface：必须 fresh 跑 `test_tui_ext_facade`
- 改动 docs taught path：必须至少 build 对应 example
- 任何新增 public app/runtime surface：必须带 focused leak-free proof
- 不跑全仓测试，不把 TUI 工作漂回 repo-wide verification

当前推荐最小 gate 继续是：

- `make -C core/tests/nextpas.core.tui/test_tui_app clean test`
- `make -C core/tests/nextpas.core.tui/test_tui_ext_facade clean test`
- 对应 example build
- heaptrc `0 unfreed memory blocks`

## 结论

方案 C 下，`D` 轴不是一条独立于 A/B/C 的“做产品感”分支，而是：

- 由 `B` 决定骨架
- 由 `A` 卡住 correctness truth
- 由 `D` 把稳定骨架变成自然 public path
- 由 `C` 在最后一轮做体系化放大

`nextpas.core.tui.ext` 现在就是这条路线的 owning layer。后续所有 app framework、state、task、
workspace 和教学路径工作，都应先问一句：

“这是不是在让 `ext` 的稳定 happy path 更真，而不是更花？”
