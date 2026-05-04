# nextPas 交叉编译规范

用这份规范定义 nextPas 第一阶段之后要逐步收紧的交叉编译边界。它回答的不是
“现在立刻支持多少 host/target 组合”，而是“host facts、target facts、toolchain binding、
sysroot 与产物布局应该怎样被建模，才能让项目以后支持 cross compilation 时，不需要先推翻
已经写好的编译器主骨架”。

这份文档和 `target-platform-specification.md`、`backend-specification.md`、
`distribution-layout-specification.md` 一起工作。前者冻结当前启用的目标规格，这里冻结
host/target 分离与 cross toolchain 的长期边界。如果你要看 LLVM-specific target profile，
继续读 `llvm-backend-specification.md`。如果你要看 C library、C symbol 与 sysroot library
解析如何配合，继续读 `c-interop-specification.md`。如果你要看 assembler、linker、
archiver、resource compiler 与 developer-facing tool surface 如何进入统一控制面，
继续读 `toolchain-specification.md`。

## 先看 FPC 真源码已经把哪些 cross 能力写成真实事实

这份规范直接回应这些 FPC 真实源码事实：

- `compiler/systems.pas`
  - `tsysteminfo` 同时持有 assembler、linker、`Cprefix`、`sharedClibprefix` /
    `sharedClibext`、ABI、alignment 和 `llvmdatalayout`
- `compiler/systems/i_linux.pas`
  - `system_x86_64_linux_info`、`system_aarch64_linux_info` 等 target info 明确不是同一套事实
  - 就算都叫 Linux，assembler kind、alignment、ABI、LLVM data layout 也可能不同
- `compiler/systems/t_linux.pas`
  - `SetupLibrarySearchPath` 明确把 `sysrootpath` 和 “cross-compiling into account” 写进库搜索逻辑
  - `SetupDynlinker` 在找不到目标动态链接器时，会把“可能正在 cross compiling”当成正式分支
  - link script 组装在 `sysrootpath` 存在时会切换行为，说明 cross-link 不是 shell 小技巧

换句话说，FPC 现有实现已经证明：cross compilation 需要的是显式 target facts、
显式 sysroot、显式 toolchain binding，而不是把 `--target` 当成一个孤立字符串。

## 当前支持面继续收紧，但架构不能把 `host == target` 写死

nextPas 当前第一阶段仍然只启用：

```text
host = linux-x86_64
target = linux-x86_64
```

这条约束仍然有效；它来自 ADR、`stage0` 路线图和当前 smoke 证据。

但这不等于架构可以把 `host` 与 `target` 混成一个值。交叉编译规范要求：

- host facts 从一开始就是显式输入，即使当前默认等于宿主机器
- target facts 从一开始就是显式输入，即使当前唯一合法值仍是 `linux-x86_64`
- driver、backend、C interop 和 output path 不能把 “当前只有一个目标” 误写成
  “系统永远不需要 host/target 分离”

这是为了避免以后一碰 cross compilation，就必须回头重写 target model、link model 和
artifact layout。

## 只保留四个必要核心对象

nextPas 在交叉编译主题下先冻结四个必要对象：

- `HostFacts`
- `TargetFacts`
- `ToolchainBinding`
- `Sysroot`

它们的职责如下：

| 对象               | 负责什么                                                            |
| ------------------ | ------------------------------------------------------------------- |
| `HostFacts`        | 描述当前编译器进程运行在哪个宿主上，以及工具发现、路径语义等事实    |
| `TargetFacts`      | 描述目标 ABI、object format、runtime/link/layout 与 symbol 规则     |
| `ToolchainBinding` | 描述某个 host-to-target 组合该使用哪套 backend、assembler、linker   |
| `Sysroot`          | 描述目标头文件、库、runtime 产物与 linker search roots 的显式根集合 |

这里的重点是少而硬，而不是为了“看起来支持很多平台”就发明一堆模糊层。

## `TargetFacts` 必须大于一个目标名字

`target-platform-specification.md` 当前已经有 `build/targets/linux-x86_64.toml`。这里进一步冻结：

一个合法 `TargetFacts` 至少要显式承载：

- target id
- CPU / OS / ABI
- object format
- assembler flavor
- linker flavor
- runtime layout key
- C symbol prefix 与 C library naming convention
- LLVM triple / data layout（如果该目标允许 LLVM backend）

这直接对应 FPC `tsysteminfo` 里今天真实存在的字段，而不是架构文档的想象补充。

## `HostFacts` 不能偷用 `TargetFacts`

host 与 target 的职责必须分开：

- `HostFacts` 负责工具可执行文件发现、路径分隔、宿主进程调用限制
- `TargetFacts` 负责目标 ABI、符号规则、链接输入和产物布局
- 后端选择可以依赖二者组合，但不能让 target facts 反过来假装自己知道宿主路径布局
- sysroot 解析可以依赖 target facts，但不能直接从 host 默认路径盲猜

这条规则可以挡住很多“本机能编就算可以 cross”的伪设计。

## `ToolchainBinding` 必须是 host-to-target 关系，而不是 target 私有附注

交叉编译真正复杂的部分不是 target name，而是 host-to-target 的工具绑定。

因此 nextPas 冻结：

- `ToolchainBinding` 以 host-to-target pair 为主键
- binding 至少描述 backend family、assembler、linker、archiver、resource tool
- binding 可以引用 target facts，但不拷贝一整份 target facts
- binding 决定的是“谁来生产目标产物”，不是“目标语义是什么”

推荐的控制面分层是：

- `build/targets/<target>.toml`
- `build/toolchains/<host>-to-<target>.toml`

这里先冻结边界，不要求第一阶段马上把整个矩阵都实现出来。

## `Sysroot` 必须是显式编译器输入

FPC `t_linux.pas` 已经说明：library search path、dynamic linker 决策和 cross-link 行为，
都必须认真对待 `sysrootpath`。

nextPas 第一阶段先冻结这些规则：

- `Sysroot` 是显式输入，不从 host 默认 `/usr/lib` 之类路径偷猜
- target library search、C library search、runtime import search 都先经过 `Sysroot`
- 如果没有提供 sysroot，就只能走当前已文档化的本机同目标路径
- 如果提供的 sysroot 与 `TargetFacts` 不匹配，必须给出结构化 diagnostics

这样后续 cross compilation 才是 controlled build，而不是 path luck。

## installed units 仍然按 target 归档，不按 host 归档

交叉编译不应该破坏公开发行语义。

因此：

- installed unit layout 继续以 `units/<target>/` 为公开键
- target 相关 object/unit/runtime 结果归 target 维度，而不是 host 维度
- host 相关工具差异属于 build/toolchain 层，不属于公开发行布局
- 一个 host 可以为多个 target 生产产物，但每个 target 仍只对应自己的 installed layout

这条规则把 cross compilation 和 `distribution-layout-specification.md` 接起来，避免公开路径失控。

## backend 选择必须经过 `ToolchainBinding`，不是命令行字符串拼接

交叉编译规范要求：

- `driver` 先解析 `HostFacts + TargetFacts + ToolchainBinding + Sysroot`
- `backend` 再消费已经收紧的 target/backend profile
- assembler/linker orchestration 由 binding 决定，不允许每个 backend 私自找工具
- LLVM backend、native backend、future external backend 都只能通过 binding 被选中

这条边界把 cross compilation 和 `backend-specification.md` 正式接起来。

## C interop 与 sysroot 必须一起设计

只设计 target，不设计 C library/linking，是假的交叉编译设计。

nextPas 明确要求：

- C symbol prefix、shared/static C library naming 来自 `TargetFacts`
- `external 'c'` 或等价 library binding 必须走 target sysroot search
- backend 不用 host 的 libc 命名规则去猜 target 的链接输入
- 如果 target 需要不同 ABI 或不同 `Cprefix`，必须在 target facts 里显式写出

更细的 symbol、calling convention 和 import/export 规则由 `c-interop-specification.md` 定义。

## 最终 link model 必须由 target、interop、sysroot 与 binding 一起收敛

FPC 的真实源码已经把这件事拆得很清楚：

- `link.pas` 的 `TLinker` 明确分开 `ObjectFiles`、`SharedLibFiles`、`StaticLibFiles`、
  `FrameworkFiles` 和 `OrderedSymbols`
- `pdecsub.pas` 的 `proc_get_importname` 与 `pdecvar.pas` 的 `AddExternalImport`
  说明 external symbol / import library request 不是 linker 自己猜出来的
- `t_linux.pas` 的 `SetupLibrarySearchPath`、`SetupDynlinker` 又说明 search root 和 dynamic linker
  继续受 `sysrootpath` 控制

因此 nextPas 继续冻结：

- backend 负责产出 object-level artifact intent 与 runtime helper intent
- C interop 负责产出 foreign symbol binding、logical library request 与等价 import intent
- `Sysroot + TargetFacts` 负责把 logical request 解析到 target-aware search roots、physical filename
  规则与 dynamic linker 选择
- `ToolchainBinding + LinkerProfile` 负责把上面这些输入序列化成真正的 linker invocation、
  response file 和 sidecar script

最重要的一条是：

- final raw linker argv 只能由 toolchain control plane 生成
- backend、C interop、package workflow 和 `env` 都不能各自手写一份“差不多能跑”的 link command

只有这样，cross compilation 才是正式控制面，而不是把不同层的字符串碰巧拼到一起。

## LLVM data layout 与 cross compilation 不能各自维护一套 target truth

FPC 的 target info 已经把 `llvmdatalayout` 写进系统表。nextPas 必须保持同样的原则：

- LLVM triple / data layout 属于 `TargetFacts`
- LLVM backend 不单独维护第二套 target description
- 如果某个 target 没有合法 LLVM profile，就必须明确报 `backend-unavailable-for-target`
- host toolchain 是否存在 `llc` / `opt` / `lld` 属于 `ToolchainBinding`，不属于 `TargetFacts`

这能防止“target 说自己是 AArch64，LLVM backend 却按另一套 data layout 生成”这种灾难。

## 交叉编译 diagnostics 必须从一开始就有正式失败类别

至少要稳定这些失败类别：

- `driver.unsupported-host-target-pair`
- `driver.missing-toolchain-binding`
- `driver.missing-sysroot`
- `driver.sysroot-target-mismatch`
- `backend.backend-unavailable-for-target`
- `backend.target-toolchain-mismatch`

每条这类诊断至少要保留：

- host id
- target id
- requested backend/toolchain
- relevant sysroot
- failing tool or missing profile

交叉编译失败不能退化成“命令行失败了，也许是 PATH 问题”。

## `stage0`、`stage1` 与 `stage2` 如何接这层设计

- `stage0`
  - 当前只允许 `linux-x86_64 -> linux-x86_64`
  - 但 host/target/toolchain/sysroot 的对象边界必须先文档化
- `stage1`
  - 可以先引入 compile-only 或 emit-only 的非本机 target 调查
  - 但必须继续通过 structured diagnostics 和 target facts 驱动
- `stage2`
  - 只有当 backend、runtime、C interop 与 distribution layout 都能解释 host/target 分离后，
    才允许把 cross compilation 扩成更大支持面

## 第一阶段非目标

- 不把多 target execution support 宣告为当前基线能力
- 不在这一阶段承诺所有 cross target 都可运行 smoke
- 不把 sysroot discovery 变成魔法自动探测系统
- 不允许 host 默认路径偷偷覆盖 target library/runtime 规则
- 不把 LLVM triple/data layout、C ABI 或 linker flavor 分散到多处各自维护

第一阶段真正要交付的是：一套哪怕当前只启用一个 host/target pair，也已经把交叉编译所需的
host/target/toolchain/sysroot 边界提前写清的现代设计。
