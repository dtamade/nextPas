# nextPas RTL 规范

用这份规范定义 nextPas 第一阶段 RTL 的边界。它回答的不是“要不要一次性重做整棵
FPC RTL 树”，而是“在 Linux x86_64 的 `stage0` 基线上，哪些运行时行为必须
先被保留下来，哪些目录边界必须先被写清楚，哪些内容必须继续延后”。

## 把 `rtl/` 视为受约束的兼容层

`rtl/` 是 nextPas 运行时兼容工作的父边界。第一阶段中的现代化 RTL，指的是：

- 对外继续保留 FreePascal 生态能够识别的运行时表面。
- 对内把历史上容易混在一起的职责重新拆清，形成更明确的所有权。
- 让运行时行为能够被 `tests/rtl/`、`tests/harness/` 和 smoke 路径直接验证。
- 先服务 `stage0` 的可执行基线，而不是抢跑到整体替换或全生态覆盖。

这意味着 nextPas 可以重建 RTL 的内部组织方式，但不能模糊已经文档化的
可观察行为。

## nextPas 必须长出自己的 toolchain-first RTL

nextPas 的长期目标不是“继续依赖宿主 FPC 的 RTL 习惯，然后有一天突然自举成功”，
也不是“长期依赖仓库外另一个 core library 项目”。要想让 compiler、toolchain、runtime SDK、
package tooling 和 future IDE 真正收敛成同一套系统，nextPas 必须直接在仓库内长出
自己的 `toolchain-first RTL`。

这里的关键词不是“大而全”，而是：

- 先服务 compiler / toolchain 的高频工作负载
- 先服务自举路径，而不是先服务通用应用生态
- 先把少量但硬的 core runtime truth 做扎实，再向外长成更宽公共 RTL

这意味着 nextPas 之后的 RTL 方向应该是：

- `rtl/core/system/`
  - process startup / shutdown、unit init/fini、runtime contract dispatch
  - nextPas-owned 最小 `System` 子集，平替编译器自举代码和 `core` 框架当前从 FPC
    `System` 隐式获得的最低事实
- `rtl/core/base`
  - 基础类型、错误/result 约定、stable id / span / small support types
- `rtl/core/mem`
  - allocator、arena、buffer、copy/fill、compiler-friendly memory discipline
- `rtl/core/text`
  - bytes、string/piece、path、symbol/interned-friendly text helpers
- `rtl/core/collections`
  - vector、map、set、deque 等工具链高频数据结构
- `rtl/core/fs` / `rtl/core/process` / `rtl/core/time`
  - 直接服务编译器、构建器、包管理器与 future IDE 的系统抽象

这套分层的目的，是让 nextPas 的 compiler/toolchain 和 future public RTL 共享同一套基础层，
而不是前者偷偷长成私有 runtime，后者再长成另一套用户态标准库。

## 先把第一批 nextPas-native core RTL 实体落在仓库里

为了避免这条路线再次退回“只有文档和口号”，当前仓库里优先落的第一批 core RTL 实体冻结为：

- `rtl/core/base/np_base_types.pas`
  - 固定最小 `status/result` vocabulary、stable id 和 span support types
- `rtl/core/mem/np_allocator.pas`
  - 固定最小 allocator contract 与 compiler-friendly `TBumpArena`
- `rtl/core/text/np_text_primitives.pas`
  - 固定最小 path/identity normalization 与 text file ingestion contract

这些层先落地，不是因为 `fs`、`process` 不重要，而是因为 compiler/session、
diagnostics、HIR/MIR lowering 与 future toolchain orchestration 会先反复碰到
result/span/allocation/path discipline。如果这层还没有 nextPas 自己的 truth，后面的 core RTL
只会继续退回宿主习惯或编译器私有 helper。

## `rtl/core/` 与 `rtl/crt/` 的职责必须分开

第一阶段的 RTL 采用显式分层，而不是把所有运行时关注点堆进一个模糊的总目录。

| 区域               | 第一阶段职责                                                | 必须避免的误用                         |
| ------------------ | ----------------------------------------------------------- | -------------------------------------- |
| `rtl/`             | 作为运行时兼容父边界，承载 nextPas 对核心运行时的总体承诺   | 把它写成“以后再说”的占位目录           |
| `rtl/core/`        | 放置核心运行时服务，以及 `System` 和相关基线 units 所需行为 | 与控制台导向行为混写，导致验证粒度消失 |
| `rtl/core/system/` | 承接 `System` 相关的最小公开表面与后续实现落点              | 把它当作任意杂项辅助代码的收纳箱       |
| `rtl/crt/`         | 单独容纳控制台导向行为，并与核心 RTL 保持明确边界           | 被泛化 RTL 文案吞没，失去独立规范      |

这份分工承接了 `docs/architecture/directory-structure-specification.md` 中已经冻结的目录结构规范。
如果后续实现无法明确说明某段运行时代码属于 `rtl/core/` 还是 `rtl/crt/`，
说明边界定义还不够清楚，而不是文档可以被省略。

还要进一步冻结一条规则：

- `rtl/core/system/` 不是 `rtl/core/` 的代名词
- allocator、text/path、collections、fs/process 这类 compiler/toolchain 共享基础设施
  不能继续被塞成 `System` 附属杂项
- future public RTL 也不应该绕开这些 core 层，另长第二套低层基础设施

## 第一阶段必须保留的 RTL 行为

根据兼容性矩阵，RTL 行为是第一阶段硬目标。这里的“保留”指可观察行为与
验证路径的稳定，不要求内部继续沿用 FPC 的历史源码组织。

| 行为层             | 第一阶段要求                                                            |
| ------------------ | ----------------------------------------------------------------------- |
| `System` 基线      | 保持 smoke 路径和基线套件依赖的程序启动、退出、基础运行时服务与相关约定 |
| 核心文件与文本处理 | 保持基线样例依赖的文件处理、文本 I/O 和相关失败路径                     |
| unit 运行期配合    | 与编译器侧的 unit 查找与组织规则配合，确保运行期初始化边界保持可解释    |
| 确定性失败表面     | 当 RTL 行为未满足预期时，提供可留证、可回放的失败结果，而不是隐式退化   |

对 nextPas-native toolchain RTL 来说，还必须再加一条：

| toolchain 基础层 | 让 compiler / build / package / future IDE 共享同一套 allocator、text/path、fs/process 与 collections truth |

`System` 基线还要明确承接 class/object 的最低语义事实。当前仓库已经落地最小
source-backed `System.pas` / `TObject` slice：implicit runtime `System` 会在语义层指向
target-installed `units/linux-x86_64/System.pas`，普通 `class` 默认继承 `System.TObject`，
`Obj.Free` 会通过继承 member lookup 绑定到 `TObject.Free`，no-fold typed HIR 也会把继承
路径上的 `Free` lowering 到当前有效 `Destroy` runtime call，并通过 `np.system.object_free`
contract 记录 nil guard 与 heap release intent；HIR builder 已把该 contract 保留为
`np.system.object_free` intrinsic marker，带 receiver pointer 与 effective `Destroy` target；
匹配的后续 `Destroy` lowering 会标记为 `np.system.object_free.destroy` owned marker。
`heap-release true` 会继续投影成 `np.system.object_free.release` marker。LLVM HIR emitter 已把
这组 marker 降成真实 receiver nil branch，让 `Destroy` call 与 `@np_object_free_release`
hook 只在非空分支执行；class allocation lowering 也已先进入 `@np_object_alloc` helper，再由
helper 申请 16-byte header + payload，写入 payload size 与 magic 后返回 payload pointer。
release helper 会从 payload pointer 回退读取该 header、校验 magic，并把合法 header 分到
`release:` 占位块、非法 header 直接分到 `done:`。当前 object alloc/release helpers 仍是
最小 ownership contract，不是真实 allocator free、diagnostics/trap failure path 或完整
validation runtime。
这个 source-backed truth 现在不再依赖用户显式写 `uses System`；但 implicit runtime 仍保持
`OriginClass=implicit-runtime`，backend extra assemble/link 不会因此自动把 `System.pas`
加进每个 program。显式 `uses System` 仍会继续解析真实源码，并可把 implicit runtime 节点升级为
explicit source provenance。长期方向仍然不是在语义层硬编码更多名字，而是让 nextPas-owned
`System` 继续提供真实 lifetime helper，把 object allocation/free helpers 接到 allocator free、
header validation diagnostics/trap、unit init/fini 等运行期能力。

这里的运行时规范与 `Source syntax`、`Core semantics` 互相配合，但不互相替代。
语法和核心语义决定程序“被如何理解”，RTL 决定这些程序在运行期“如何表现”。

如果你要看编译器如何把这些运行时语义显式交给 `rtl/core/system/`，继续读
`runtime-bootstrap-specification.md`。

## RTL 文档必须服务验证路径

第一阶段的 RTL 规范不是背景说明，而是 `promotion gate` 的一部分。最小验证关系如下：

- `tests/rtl/` 负责承接核心运行时行为断言。
- `tests/crt/` 单独覆盖控制台导向行为，避免 CRT 被混入泛化 RTL。
- `tests/harness/` 负责把这些断言组织为可重复执行的检查。
- smoke 路径负责证明 `stage0` 驱动入口与 RTL 基线在 Linux x86_64 上能连通。

如果某项运行时改动无法说明它会影响哪一类测试，或者它应该归属 `tests/rtl/`
还是 `tests/crt/`，那么这项改动还没有准备好进入基线。

## `stage0`、`stage1` 与 `stage2` 的运行时所有权关系

- `stage0`：FreePascal 继续扮演宿主编译器，nextPas 先冻结 RTL 边界、
  文档和验证方式。
- `stage1`：nextPas 可以接管更多 RTL 内部实现，并开始让 compiler / toolchain 真实依赖
  nextPas-native `rtl/core`，但不能破坏已经公开的运行时边界与测试分类。
- `stage2`：只有在兼容性证据足够时，才允许调查更深的自托管与运行时接管路径。

阶段升级可以改变“谁来实现”，但不能跳过“先把规范写清楚、把验证保留下来”。

把自举路径写得更直白一点，就是：

```text
stage0:
  FPC compiles nextPas compiler/toolchain + nextPas rtl/core

stage1:
  nextPas compiler/toolchain begins to live on nextPas-native rtl/core

stage2:
  nextPas uses its own compiler/toolchain to rebuild that same rtl/core
```

## 第一阶段非目标

这份 RTL 规范同样要明确写出不做什么：

- 不追求一次性覆盖整个 FPC RTL 树。
- 不把 CRT 行为折叠回泛化 RTL 文案。
- 不通过 RTL 扩展去引入 `No new syntax` 之外的新语言表面。
- 不把 ABI 稳定性写成第一阶段承诺，`ABI compatibility is deferred`。
- 不把 Linux x86_64 之外的平台支持混入当前基线。
- 不把仓库外未完成的 core framework 当作长期正式依赖。
- 不让 compiler / toolchain 为了短期进度，长期依赖宿主 RTL 习惯或各写各的私有基础层。

第一阶段要交付的是“可验证的 RTL 边界”，不是“看起来很大但无法证明的运行时愿景”。
