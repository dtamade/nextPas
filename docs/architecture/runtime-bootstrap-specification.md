# nextPas 运行时自举规范

用这份规范定义 nextPas 编译器与 `rtl/core/system/` 之间的稳定握手边界。它回答的不是
“第一阶段要不要立刻完整重写 `System`”，而是“在 Linux x86_64 的 `stage0` 基线上，
程序启动、退出、unit 初始化/清理、runtime helper 引用与失败留证应该如何保持显式、
可验证、可继续演进”。

这份文档承接 `compiler-pipeline-specification.md` 中已经冻结的 runtime handshake 原则，
同时细化 `rtl-specification.md` 里提到的 `System` 基线。如果你要看 `Typed HIR` 本身
应该如何表达 intrinsic、symbol、type 和语义结论，继续读 `semantic-model-specification.md`。
如果你要看 init/fini 顺序依赖的 `UnitGraph` 前提如何建立，继续读 `unit-resolution-specification.md`。
如果你要看 compile diagnostic 和 runtime failure 如何分界，继续读
`diagnostics-specification.md`。如果你要看 backend 如何消费 runtime contract 与
target facts，而不是自己重做 helper 选择，继续读 `backend-specification.md`。
如果你要看 future GUI stack 为什么要把 `UiRuntime` 作为正式骨架，而不是继续塞进
`System` 杂项里，继续读 `gui-framework-specification.md`。
如果你要看 `RuntimeClock`、`DispatchCycle`、`UiInvalidation` 和 `UiTaskQueue` 为什么也不该塞进
`System` 杂项里，继续读 `ui-runtime-specification.md`。
如果你要看 motion clock、transition scheduler 与 sampled temporal truth 为什么也不该塞进
`System` 杂项里，继续读 `ui-motion-specification.md`。
如果你要看 scene lowering 与 surface frame 为什么也不该塞进 `System` 杂项里，继续读
`ui-rendering-specification.md`。如果你要看 shader、atlas、font metadata、theme/image sidecar
和 render asset pipeline 为什么也不该塞进 `System` 杂项里，继续读
`render-asset-pipeline-specification.md`。
如果你要看这份边界在回应 FPC 真源码里的哪些历史耦合，继续读 `fpc-source-grounding-specification.md`。

## 先看 FPC 真源码如何把 init/final 前提散在几层里

这份 runtime bootstrap 规范不是抽象口号，它直接回应这些真实源码事实：

- `compiler/compiler.pas`：driver 入口显式调用 `InitSystems`，说明 process-level startup facts
  今天由 compiler driver 全局初始化驱动
- `compiler/pmodules.pas`：`force_init_final` 依赖 `globalsymtable` / `localsymtable`
  的 `needs_init_final`
- `compiler/symtable.pas`：`tstoredsymtable` 和相关 unit/global symtable 自己分析
  `needs_init_final`

nextPas 需要保留这些能力，但不能继续把它们分散在 driver、symtable 和 module load 副作用里。

## runtime bootstrap 不等于整个 toolchain RTL

这份规范的中心是 `compiler <-> rtl/core/system/` 的握手，但 nextPas 要自举成功，
不能只有一层 `System` contract。编译器、构建器、包工具和 future IDE 还需要一套
共享的、nextPas-native 的 core runtime 基础层，例如 allocator、text/path、collections、
fs/process、time。

这些能力和 `System` 的关系应该是：

- `rtl/core/system/`
  - 负责 process startup / shutdown、unit init/fini、runtime contract dispatch
  - 负责 nextPas-owned 最小 `System` 子集，先平替自举代码和 `core` 框架当前从 FPC
    `System` 隐式获得的最低对象生命周期与基础运行时事实
- `rtl/core/base` / `mem` / `text` / `collections` / `fs` / `process` / `time`
  - 负责 compiler/toolchain 自己要长期依赖的基础设施

如果把这两层重新混成一个“什么都丢进 `System`”的方向，nextPas 后面一定会再次退化成
隐式宿主依赖。

反过来，如果没有 nextPas 自己的 `System` 基线，编译器也会在语义层缺少 `TObject` /
`Free` / destructor / unit init-fini 这些最底层事实，导致自举代码和 `core` 框架仍然必须
从宿主 FPC RTL 借语义。`System` 平替因此是自举路线的最低依赖，不是外围库任务。

当前仓库里的实现切片已经从 `rtl/core/base`、`rtl/core/mem` 和 `rtl/core/text`
推进到 source-backed `System` truth：`rtl/core/system/System.pas` 与
`units/linux-x86_64/System.pas` 先提供 `TObject.Create`、`TObject.Destroy` 和
`TObject.Free`。这让 implicit runtime 的语义分析可以把普通 class 的隐式 `TObject`
父类和 `Obj.Free` 绑定落到真实 symbol 上，即使 root source 没有显式 `uses System`。
no-fold typed HIR 现在还会复制隐式 `TObject` 父类的 VMT slot/function truth，并把
`Obj.Free` lowering 到当前有效 `Destroy` runtime call；只继承 `System.TObject.Destroy`
的普通 class 会落到 `TObject.Destroy`。同一 lowering 还会生成 `np.system.object_free`
contract，记录 receiver、effective `Destroy`、nil guard 和 heap release intent。
`THIRBuilder` 已把这个 contract 保留为 HIR `np.system.object_free` intrinsic marker，
带 receiver pointer operand 和 effective `Destroy` target；紧随其后的匹配 `Destroy`
lowering 会成为 `np.system.object_free.destroy` owned marker；`heap-release true` 还会成为
`np.system.object_free.release` marker。LLVM HIR emitter 会把这组 marker 降成 receiver nil
branch：nil receiver 直接汇合到 `objectfree.end.*`，非 nil receiver 进入
`objectfree.destroy.*` 后调用 effective `Destroy`，再调用 `@np_object_free_release` hook。
class allocation lowering 也已进入 `@np_object_alloc(i64 size)` helper，再由 helper 委托到底层
`@np_alloc` 申请 16-byte header + payload；header offset 0 存 payload size，offset 8 存
magic `1313882451`，返回值是 payload pointer。`@np_object_free_release` 会从 payload pointer
回退读取 header，校验 magic，并把合法 header 分到 `release:` 占位块、非法 header 直接分到
`invalid:`；invalid path 会调用
`@np_object_release_invalid(ptr %raw, i64 %size, i64 %magic)` 后汇合到 `done:`；invalid helper 当前会
调用 `@llvm.trap()` 并发出 `unreachable`。`release:` 当前调用
`@np_object_release_valid(ptr %raw, i64 %size)`，把已验证的 header raw pointer 与 payload size
交给 future allocator free 的唯一边界，并在当前实现中清零 header magic，让重复释放进入
invalid-release trap。当前 object alloc/release helpers 只是最小 ownership contract。它们仍不是完整
`System` 重写，也没有把
implicit runtime 改成自动编译/链接 `System.pas`；backend 仍把 implicit runtime 排除在额外
assemble/link 之外。后续应在这个 source-backed 边界上继续补 allocator free、结构化 diagnostics、
dynamic dispatch runtime helper、unit init/fini、helper 和 lowering。

## 把 compiler 和 runtime 的边界写成硬约束

nextPas 要现代、高性能、优雅，就不能让编译器和运行时通过隐式约定互相“猜”。

因此，第一阶段先冻结这四条约束：

- 编译器负责决定程序和 unit 的语义顺序，不把名字解析、unit 依赖判断留给 runtime。
- runtime 负责执行已经确定下来的启动、初始化、清理和退出动作，不反向参与语义分析。
- backend 只能消费显式 runtime helper 引用或显式启动语义，不允许自己私下发明另一套
  `System` 规则。
- `stage0` 虽然继续由 FreePascal 托管最外层构建路径，但 nextPas 仍然要先把这条边界文档化，
  否则后续 `stage1` 只会把历史耦合重新搬进来。
- compiler / toolchain 共享基础设施必须优先进入 nextPas 自己的 `rtl/core`，而不是长期留在
  宿主 RTL 习惯、仓库外库项目或编译器私有 helper 里。

## 程序启动链只允许一条清晰顺序

第一阶段推荐的运行时自举顺序如下：

```text
CompilationSession
  -> Typed HIR / MIR lowering decides runtime-required semantics
  -> emitted entry path references explicit runtime helpers
  -> rtl/core/system performs process startup
  -> unit initialization runs in dependency order
  -> program body executes
  -> unit finalization runs in reverse dependency order
  -> rtl/core/system performs process shutdown and exit reporting
```

这条顺序的重点不是“长得像传统 Pascal”，而是每一步都必须有明确所有者：

- `CompilationSession` 持有 target facts、`UnitGraph`、diagnostics sink 与 lowering 需要的
  会话事实。
- `Typed HIR` / `MIR` 决定哪些 runtime action 是程序语义的一部分。
- entry path 只引用显式 helper，不拼接模糊 magic string。
- `rtl/core/system/` 执行 process startup、unit init/fini 与 process shutdown。
- `rtl/core` 的其他基础层负责给 compiler/toolchain 提供 allocator、text/path、fs/process
  与 collections 这类长期共享能力。

如果未来实现无法说明某一步属于谁，就说明架构还不够清楚。

## 哪些语义必须留在编译器，哪些职责交给 runtime

| 边界             | 编译器负责什么                                                | runtime 负责什么                             |
| ---------------- | ------------------------------------------------------------- | -------------------------------------------- |
| unit 身份与依赖  | 解析 unit 名、建立 `UnitGraph`、决定依赖边                    | 不重新扫描路径或重新做 unit 解析             |
| 初始化/清理计划  | 计算 init/fini 顺序、把需要的 helper 点显式写入 lowering 结果 | 按既定顺序执行，并维护每个 unit 的运行期状态 |
| 语义判断         | 类型检查、重载解析、常量求值、内建语义判断                    | 不重新做语言语义判定                         |
| process 生命周期 | 决定程序需要哪些启动/退出语义点                               | 建立进程级运行时状态、执行启动与退出         |
| 失败分类         | 生成编译期结构化 diagnostics                                  | 生成运行期可留证失败结果，不伪装成编译期错误 |

这里最关键的一点是：`Typed HIR` 必须表达“程序需要哪些 runtime semantics”，但不需要在
这一层直接承载底层进程状态、文件句柄或控制台状态。

## 把 `unit` 初始化与清理顺序写死

unit 初始化与清理不能继续作为 backend 特例或历史习惯存在。第一阶段先冻结以下行为：

- 初始化顺序来自已解析的 `UnitGraph`，不是 runtime 自己按路径顺手发现。
- 每个 unit 在单次进程执行中最多初始化一次。
- 只有初始化成功完成的 unit 才允许进入 finalization 集合。
- finalization 顺序必须是 initialization 顺序的反向依赖序。
- 如果某个 unit 初始化失败，程序主体不得继续执行。
- 如果某个 unit 初始化失败，runtime 只允许清理已经成功初始化过的 units。

这组规则的目的，是让 unit 行为既能与 Pascal 兼容预期对齐，又能被 `tests/rtl/`、
`tests/harness/` 和后续回归样例稳定消费。

## runtime helper 必须通过显式 contract name 引用

编译器引用 runtime 协助点时，不应该把真实符号名、backend 特例和语义名字混在一起。

第一阶段先冻结一组最小 contract name 语义：

| contract name             | 语义                       |
| ------------------------- | -------------------------- |
| `np.system.process_init`  | 建立 process 级运行时状态  |
| `np.system.process_fini`  | 执行 process 级退出与收尾  |
| `np.system.unit_init`     | 进入某个 unit 的初始化入口 |
| `np.system.unit_fini`     | 进入某个 unit 的清理入口   |
| `np.system.halt`          | 以显式退出语义终止程序     |
| `np.system.object_free`   | 对象 `Free` 的 nil guard、destructor 与 heap release 契约 |
| `np.system.runtime_fault` | 报告不可忽略的运行期故障   |

这里的 contract name 是编译器与 runtime 边界上的规范名字，不等同于最终 ABI、符号导出名
或 object-level 调用约定。

允许 backend 或宿主适配层做的事：

- 把 contract name 映射到当前阶段可用的真实调用落点。
- 为 `stage0` 宿主路径保留必要的适配层。

不允许做的事：

- 在不同 backend 各自偷偷起不同 helper 名。
- 把 contract name 退化成散落在 lowering 分支里的字符串常量。
- 没有文档就直接把某段运行时语义塞进 codegen 特例。

## `Typed HIR` 与 runtime 的职责分界必须稳定

为了避免语义和运行期边界重新混写，nextPas 先冻结以下分工：

- `Typed HIR`
  - 表达 unit 依赖、初始化需求、清理需求和内建过程语义
  - 表达哪些点需要 runtime helper 参与
  - 表达会影响正确性的控制流与语义结论
- runtime
  - 承接 process state、unit state、文件/文本 I/O 状态和其他实际运行期资源
  - 执行 `System` 级启动、退出、unit init/fini
  - 在失败时给出可留证的运行期结果

因此，“需要 runtime”本身是前端语义结论；“runtime 具体怎么执行”才是 `rtl/core/system/`
的职责。

## diagnostics 不能跨边界变形

编译期失败和运行期失败都要可解释，但不能混成一层。

第一阶段要求：

- 编译器继续通过结构化 diagnostics sink 报告 syntax、resolution、sema、lowering 失败。
- runtime failure 不回写成伪造的 compile diagnostic。
- `harness` 与证据留存至少要能区分这几类运行期失败：
  - `runtime-startup-failed`
  - `unit-initialization-failed`
  - `unit-finalization-failed`
  - `runtime-abort`
- 运行期失败仍然要保留清晰退出语义，不能只表现为“进程非零退出但不知道为什么”。

这不是要求第一阶段就做完整异常系统，而是要求 compiler/runtime 边界上的失败结果
可分类、可回放、可留证。

## 性能模型要直接进入 runtime bootstrap 设计

运行时自举不是只能谈语义，也必须直接约束性能方向。

第一阶段坚持这些规则：

- unit init/fini 顺序优先在编译期或 lowering 结果中预计算，不在运行期重复做图遍历。
- runtime helper 选择优先走显式 contract dispatch，不做字符串查找驱动的热路径分派。
- process startup 所需的 target facts 由编译器会话统一读取，不让 runtime 再推导第二遍。
- 编译器与 runtime 的共享名字优先使用 interned identity 或等价稳定标识，不重复分配和比较
  原始字符串。
- `stage0` 宿主适配层可以存在，但不能成为长期性能模型的默认中心。
- 编译器热路径需要的 allocator、text/path、collections 和 fs/process helper 优先进入
  nextPas-native `rtl/core`，而不是继续散落在编译器私有 util 单元里。

这保证“先写清楚边界”不会演化成“以后永远只能靠慢路径 glue code”。

## `stage0`、`stage1` 与 `stage2` 如何接这条边界

- `stage0`
  - FreePascal 继续承担最外层宿主编译器角色
  - nextPas 先冻结 startup/shutdown、unit init/fini 与 helper naming 的规范
  - smoke 路径和 `harness` 负责证明这条边界已经可引用、可验证
- `stage1`
  - nextPas 前端与 lowering 开始显式产出 runtime helper 引用
  - `Typed HIR` / `MIR` 开始正式承接 unit init/fini 与 runtime-required semantics
- `stage2`
  - 只有当 helper naming、diagnostics 边界和 runtime bootstrap 证据已经稳定后，
    才允许调查更深的 backend / self-hosting 接管

这意味着 runtime bootstrap spec 不是空谈未来，它直接决定 `stage1` 该怎么接管，
以及 `stage2` 在什么前提下才值得进入。

## 第一阶段非目标

- 不把这份规范写成完整 `System` 重写方案。
- 不提前冻结 ABI、object layout 或符号导出格式，`ABI compatibility is deferred`。
- 不把 CRT 控制台行为混回 `rtl/core/system/`。
- 不允许 runtime 自己补做名字解析、类型判断或 unit 查找。
- 不把 `stage0` 的宿主适配细节误写成长期唯一实现形态。

第一阶段真正要交付的是：一条能把 `compiler/`、`rtl/core/system/`、`tests/` 和
`stage0` 宿主路径接起来的显式运行时自举边界。
