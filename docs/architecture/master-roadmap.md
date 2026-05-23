# nextPas 主路线图

用这份路线图把 nextPas 从“已经有不少专题规范”推进到“这些规范真的沿同一条主线收敛”。
它回答的不是某一轮会话要改哪几个文件，而是整个项目应该按什么顺序把控制面、语法前端、
语义核心、后端/工具链、workspace/tooling、GUI framework 和 IDE 接起来，才能保持现代、高性能、优雅，
同时继续建立在真实 FPC 源码取证之上。

如果你要看当前批次怎么执行，读
`docs/plans/2026-03-24-nextpas-master-roadmap-plan.md`。
如果你要看 compiler 自己应该按什么顺序接管，读
`compiler-roadmap.md`。
如果你要看 FPC `stage0 -> stage1 -> stage2` 的自举所有权路径，读
`bootstrap-roadmap.md`。这份文档只负责“整个产品面先长什么、后长什么”的长期顺序。
所有路线图切片还必须遵守 `architecture-principles-specification.md`：长期愿景只有在
owner、truth object、projection、promotion gate 和诚实非目标都清楚时，才算进入可落地设计。

## 先把主路线图的约束写清楚

这份路线图继续受这些已接受事实约束：

- `/home/dtamade/projects/fpc` 是当前 FPC 兼容性基线，也是架构取证来源。
- Linux x86_64 仍是当前唯一宿主与目标基线。
- FreePascal 仍是 `stage0` 宿主工具链，直到 `bootstrap-roadmap.md` 的晋级门槛被真实赢下。
- 第一阶段不发明新 Pascal 语法，`ABI compatibility is deferred`。
- 文档、命令表面、验证入口和证据必须一起推进，不能只升级其中一层。
- nextPas 的长期自举路线要建立在仓库内的 nextPas-native `rtl/core` 之上，而不是长期依赖
  仓库外未完成的 core framework 或宿主 RTL 习惯。
- 正确性、性能、可维护性和优雅性必须落成可验证 contract，不能停留在愿景描述。

因此，这份主路线图不会把 nextPas 写成“先做个 compiler，剩下以后再说”，也不会把 GUI、IDE、
package manager 或 cross toolchain 写成脱离编译器与 workspace truth 的孤立 side project。

## 用两条轴一起看 nextPas

nextPas 的长期推进要同时看两条轴：

- 产品轴：Control Surface and Session Foundation -> Syntax Frontend ->
  Unit Resolution and Semantic Core -> Typed HIR / MIR / Backend / Toolchain Boundary ->
  Target / Cross / LLVM / C Interop -> Workspace and Developer Tooling Integration ->
  GUI Framework and IDE
- 自举轴：`stage0` -> `stage1` -> `stage2`

可以先用一个 ASCII 示意把关系看清：

```text
Product growth:
  Control Surface and Session Foundation
    -> Syntax Frontend
    -> Unit Resolution and Semantic Core
    -> Typed HIR / MIR / Backend / Toolchain Boundary
    -> Target / Cross / LLVM / C Interop
    -> Workspace and Developer Tooling Integration
    -> GUI Framework and IDE

Bootstrap ownership:
  stage0 -> stage1 -> stage2
```

这里最关键的判断是：

- `bootstrap-roadmap.md` 负责谁来拥有编译路径
- `compiler-roadmap.md` 负责 compiler 自己按什么顺序接管
- 这份 `master-roadmap.md` 负责 nextPas 作为整套开发环境先长什么骨架

这三份路线图必须配合，但不应该互相代替。

## 先看全局顺序，再看每一段门槛

| 段落 | 核心焦点                                       | 为什么现在排在这里                                                                              |
| ---- | ---------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| 1    | Control Surface and Session Foundation         | 没有统一命令表面和 session ownership，后面的 syntax / sema / toolchain 能力就没有稳定外壳       |
| 2    | Syntax Frontend                                | 没有 lexer、`Green CST` 与 AST facade，前端数据边界就会继续退回历史解析习惯                     |
| 3    | Unit Resolution and Semantic Core              | 没有 `UnitGraph`、`Typed HIR` 和结构化 diagnostics，就还没有真正可复用的产品级语义真相          |
| 4    | Typed HIR / MIR / Backend / Toolchain Boundary | 没有显式 `Typed HIR`、`MIR`、artifact plan 和 toolchain orchestration，下游仍会退化成隐式副作用 |
| 5    | Target / Cross / LLVM / C Interop              | 没有 host/target/sysroot/foreign contract，cross、LLVM 和 C linking 会各写一套私货              |
| 6    | Workspace and Developer Tooling Integration    | 没有 shared workspace truth，package manager、CLI、language service 和 future IDE 会分叉        |
| 7    | GUI Framework and IDE                          | 只有在 compiler/toolchain/workspace truth 稳定后，自有 GUI 与 IDE 才不会长成第二套系统          |

下面每一段都只回答三件事：

- 这一段到底要冻结什么
- 进入下一段前必须赢下什么 promotion gate
- 出现什么症状时必须回退

当前仓库还需要额外冻结一条近期排期纪律：

- 只要 front-end semantic truth、source-root / workspace truth 还在靠“先扫目录再猜”的最小基线撑着，
  下一轮优先级就不应继续偏向 richer toolchain projection
- tool invocation plan、status event、build trace 已经有最小闭环后，优先级应先回到
  resolver/diagnostics/workspace ownership 的可解释性，再继续扩多 step toolchain richness

## 1. Control Surface and Session Foundation

这一段的目标，是把 nextPas 先收成一个可机器消费、可验证、可留证的最小开发环境控制面，
同时把最小编译会话所有权固定下来。

这一段至少要稳定这些事实：

- `nextpas build`、`tests/run_all_tests.sh`、`build/verify_local.sh` 共同站在统一 command surface 上
- `CommandIntent`、`CommandExecutionContext`、`CommandResultEnvelope` 这类控制面词汇不再分叉
- `stage0` driver、test harness 和 local verification 使用一致的 target id、failure kind 和 result envelope 口径
- `CompilationSession`、`Source database`、target facts view 与 diagnostics sink 有明确 owner
- 文档能明确解释每条公开命令面到底属于什么层，而不是靠 shell 文本约定

进入下一段前，这一段的 promotion gate 至少包括：

- build/test/verify 三条最小命令面都有 machine-readable result bridge
- 本地验证和 CI 消费的是同一条公开命令契约，而不是两套私有脚本习惯
- 命令级成功/失败类别能被 diagnostics 和 evidence 稳定复用
- session 能稳定拥有源码输入、目标事实和诊断汇聚面

出现这些情况时必须回退：

- 新能力重新要求使用文本抓取来判断成功或失败
- `build`、`test`、`verify` 对 target 或 failure 的叫法重新分叉
- source、target、diagnostics 重新漂回全局状态
- 文档说的公开表面和仓库真实命令路径不一致

## 2. Syntax Frontend

这一段的目标，是把源码前端收成现代、可分层、可复用的结构，而不是继续沿用历史解析习惯。

这一段至少要冻结这些事实：

- `Source database -> Lexer -> Green CST -> AST facade` 是唯一推荐的前端主骨架
- `Green CST` 继续保持 immutable 结构，而不是靠 AST 原地回写塞语义结论
- syntax failure 会进入结构化 diagnostics，而不是停留在 CLI 文本输出
- 前端数据生命周期需要继续服务 interning、arena 和后续 cheap reparse 方向

进入下一段前，这一段的 promotion gate 至少包括：

- 对基线 smoke 输入，lexer、green tree 和 AST facade 已有最小可执行骨架
- parser failure 已经能进入统一 diagnostics sink
- 前端数据结构的生命周期边界已经可解释，而不是继续留给 driver 或 backend 猜

出现这些情况时必须回退：

- `syntax` 直接回写语义层状态
- parser failure 只能通过命令失败字符串观察
- 语法树被重复物化成多份长期对象图

## 3. Unit Resolution and Semantic Core

这一段的目标，是把 nextPas 从“有了会话壳”推进到“有了真正可复用的语义核心与 unit 解析真相”。

这一段至少要冻结这些事实：

- `UnitId`、`ResolvedUnit`、`SearchPathSet`、`UnitGraph` 是 unit/module 行为的正式持有者
- `Typed HIR`、symbol graph、type graph 和结构化 diagnostics 开始成为语义层真相
- interface / implementation 边界、unit cycle、missing unit、ambiguous unit 都进入正式失败类别

进入下一段前，这一段的 promotion gate 至少包括：

- name resolution 结果会进入 `UnitGraph`，而不是只停留在路径拼接或字符串查找
- 语义失败开始进入结构化 diagnostics sink，而不是继续散落在 driver 或 backend

出现这些情况时必须回退：

- 语义判断依赖 AST 原地回写或隐式 side table
- unit 解析重新退回“试几个目录看看”的路径习惯
- runtime 或 backend 需要重新猜 unit/init/semantic facts

## 4. Typed HIR / MIR / Backend / Toolchain Boundary

这一段的目标，是让 `Typed HIR` 之后的世界保持显式分层，把后端和外部工具调用都从历史副作用里拆出来。

这一段至少要冻结这些事实：

- `Typed HIR -> MIR -> Codegen adapter -> target-aware output path` 是正式下游链路
- assembler、linker、archiver、resource tool 属于独立 orchestration 层
- backend 只消费 `MIR + TargetFacts + output intent`
- object、archive、executable、installed unit artifact 的产物计划是显式结果，而不是目录扫描副作用

进入下一段前，这一段的 promotion gate 至少包括：

- `MIR` 已经成为正式 backend input contract，而不是新的语义游乐场
- tool invocation 有显式 plan、profile 和失败映射
- 产物落点开始稳定对齐 `units/<target>/`、`bin/`、`lib/`、`share/`

出现这些情况时必须回退：

- backend 重新做 overload resolution、type inference 或 runtime helper 选择
- assembler/linker 调用再次退回 opaque shell 模板复制
- output path 不能解释文件为什么落到那里

## 5. Target / Cross / LLVM / C Interop

这一段的目标，是把 target-aware truth 真正写成统一控制面，让 cross compilation、LLVM backend
和 C interop 共享同一套正式输入。

这一段至少要冻结这些事实：

- `HostFacts + TargetFacts + ToolchainBinding + Sysroot` 是 cross toolchain 的统一主键
- LLVM backend 只是 `Codegen adapter` 的一个 specialization
- calling convention、symbol binding、library binding 是统一 foreign contract
- C library resolution、sysroot search 和 final link ordering 继续属于 toolchain control plane

进入下一段前，这一段的 promotion gate 至少包括：

- target profile、LLVM target profile 和 foreign ABI contract 不再各自维护一套名字系统
- cross compilation 不再依赖 host fallback 才能解释 target library 或 runtime lookup
- LLVM backend 与 native backend 消费同一套 `MIR`、`TargetFacts` 和 C interop contract

出现这些情况时必须回退：

- LLVM backend 开始要求第二套前端或第二套上游 IR
- cross target 行为重新散落进 driver、backend 或 shell wrapper
- C interop 直接产出 raw linker args，而不是逻辑 link request

## 6. Workspace and Developer Tooling Integration

这一段的目标，是把 nextPas 真正推成类似 Rust/Go 那样的现代开发环境，而不是“有很多工具，但每个工具都维护一份自己的项目真相”。

这一段至少要冻结这些事实：

- `WorkspaceModel`、`PackageRef`、`TargetSelection`、`ArtifactRootSet` 是 shared workspace truth
- `PackageManifest`、`PackageLock`、`PackageInstallPlan` 建立在 workspace 与 toolchain control plane 之上
- `pkg`、`env`、`fmt`、`doc`、`doctor`、`query` 这类工具是 thin entrypoint + shared core
- language service、CLI、package workflow 和 future IDE 都消费同一份 workspace truth

进入下一段前，这一段的 promotion gate 至少包括：

- package/workspace tools 不需要再各自重写 root discovery、target selection 或 install placement
- install root、cache root、build root 和 source root 已能被明确区分
- workspace truth 能解释 CLI、language service 和 package actions 为什么看到同一套项目状态

出现这些情况时必须回退：

- IDE、CLI、package tool 或 language service 各自维护私有 project model
- package/install 结果不能对齐 `units/<target>/`、`lib/`、`share/`
- 新工具必须复制一套 target/toolchain/workspace 推导逻辑才能工作

## 7. GUI Framework and IDE

这一段的目标，是把 nextPas 的最终产品形态完成闭环：Pascal-first、硬件加速的 GUI framework，
以及建立在同一套 compiler/toolchain/workspace truth 之上的自有 IDE。

这一段至少要冻结这些事实：

- `UiScene`、`UiRuntime`、`RenderBackend`、`PlatformShell` 是 GUI stack 的四个正式对象
- `RenderAssetBundle`、text/layout、interaction、theme、motion、accessibility 都继续挂在同一套 UI stack 上
- IDE workbench 建立在自有 GUI framework 之上，而不是第二套宿主系统或 widget compatibility layer
- IDE 的 build/test/package/debug/editor workflow 继续复用 compiler、toolchain、harness 与 workspace truth

进入这一段后的 promotion gate 至少包括：

- GUI 主路径是 hardware-accelerated rendering，而不是 CPU paint callback 默认路径
- IDE 不拥有第二套 runtime、第二套 platform shell、第二套 workspace truth 或第二套 theme/motion system
- preview、designer、package actions 和 test/build orchestration 都能回到同一条控制面

出现这些情况时必须回退：

- GUI 重新退化成 LCL-style compatibility layer 或一组 toolkit wrapper
- IDE 重新长出私有 runtime、私有 shell、私有 package graph 或私有 build graph
- preview surface 不能复用正式 render asset pipeline 与 diagnostics/result contract

## 每一段都要遵守同一套推进纪律

不管当前推进到哪一段，nextPas 都要遵守同一组跨段规则：

1. 先冻结少量但硬的 truth object，再扩实现面。
2. 每次推进都要同时落到仓库实体、验证命令和证据文件。
3. 新系统必须优先复用已有 control plane，而不是平行长第二套。
4. 如果某一段还需要靠未文档化宿主行为撑着，就不能假装已经晋级。
5. 始终保留回退到最近一个已验证 `stage0` 基线的路径。
6. compiler/toolchain 与 future public RTL 要优先复用同一套 `rtl/core` 基础层，不允许各长一套私有底层。

这套纪律的目的，是让“现代、高性能、优雅”不再只是形容词，而是能直接决定推进顺序的架构规则。

## 这份路线图故意不做什么

- 不把当前会话批次、证据路径或临时阻塞写成长期架构真相。
- 不改写 `bootstrap-roadmap.md` 对 `stage0`、`stage1`、`stage2` 的所有权边界。
- 不因为已经有 GUI/IDE 规范，就把它们提前挪成当前实现主线。
- 不把 package manager、cross compilation、LLVM backend 或 IDE 写成彼此独立的孤立产品。
- 不把“参考 Rust / Go”误解成只复制目录名，而忽略 shared core、thin entrypoint 和统一 workspace truth。

这份主路线图真正要交付的是：一条从当前 `stage0` 控制面，稳步走向 next-generation Pascal
developer environment 的唯一推荐主线。
