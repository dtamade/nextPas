# nextPas compiler-system 自举主线设计

> 状态：草案，已完成方向确认，待书面审阅
>
> 第一阶段目标平台：Linux x86_64
>
> stage0：FreePascal

## 这份设计解决什么

compiler 与 L0 system 不是两个独立产品。`System` 是每个 Pascal 程序的第一条隐式源码依赖，
compiler 负责理解并降低其中的语言级声明，runtime 负责执行这些声明对应的 helper 与生命周期语义。
三者必须沿同一条自举主线演进。

当前仓库没有把这条主线收成一份真相：

- `rtl/core/system/System.pas` 被文档指定为 canonical magic unit，但仍是最小骨架。
- `units/linux-x86_64/System.pas` 是 compiler 实际消费的 target-installed unit，却已经独立扩展，
  与 canonical source 不一致。
- `core/src/nextpas.core.system*` 同时维护 FPC-routed surface 和另一套 nextPas kernel 声明，
  包括 compiler root、RTTI、managed types 与 runtime helper 表面。
- compiler 的 sema、HIR 和 backend 还保留分散的 `np.system.*` 字符串与 helper 映射。
- 当前 stage2 脚本只构建独立 unit object，没有生成并执行完整的 A、B、C 三代 compiler。

这份设计把它们收成一个 compiler-system bootstrap spine，同时保留清晰、无环的源码 owner boundary。

## 设计结论

### compiler 与 system 共同规划

compiler、magic `System`、`nextpas.core.system` contract、runtime helper 与 bootstrap gate 使用同一条
长期 lane 和同一份路线图。任何改变语言运行期契约的切片都必须纵向验证：

```text
System declaration
  -> compiler symbol binding
  -> typed semantic/HIR intent
  -> runtime/backend helper
  -> executable behavior
```

纵向切片可以在一个原子提交中同时修改 compiler 与 system。按目录拆成两个提交、却让中间状态无法
编译或 contract 不一致，不符合可回滚要求。

### compiler 仍保留最小前置内核

`System` 是源码和运行时层的起手单元，不是 compiler 实现本身的第一行代码。compiler 必须先拥有
一个不依赖 `System.pas` 的最小前置内核，才能解析并加载 `System`：

- token、parser 与基础 AST/green tree
- unit identity、search path 与 implicit runtime edge
- compiler intrinsic scalar/pointer facts
- `{$compiler_root}`、`{$compiler_type_kind}` 等 kernel directive
- 足以建立 symbol/type graph 的最小语义机制

这个前置内核不是公开 RTL，也不复制 `TObject`、RTTI 或 managed-type runtime 行为。它只提供加载
source-backed `System` 所需的编译器能力。

### magic `System` 是唯一 compiler root

`rtl/core/system/System.pas` 及其同目录 include family 是 compiler-visible root declarations 的
canonical owner。它负责：

- compiler intrinsic 类型的公开名称与目标尺寸锚点
- `TObject`、`TClass` 与最低 VMT/layout 声明
- string、interface、dynamic array 与 managed record 的最低布局和生命周期声明
- 最小 `TTypeKind` / RTTI compiler truth
- exception root 与 raise/unwind handshake 声明
- process/unit init/fini 与 compilerproc/helper 签名
- memory-manager hook 声明，但不接管 allocator 实现

`System` 不依赖 `nextpas.core`。否则 compiler 必须先编译 core 才能理解第一条隐式单元，形成
bootstrap dependency cycle。

### installed `System` 只是 target projection

`units/linux-x86_64/System.pas` 不再独立演化。第一阶段采用机械 projection：

1. target-neutral 声明进入 `rtl/core/system/System.pas` 或同目录 canonical includes。
2. Linux x86_64 差异通过 canonical source 显式包含的 target fragment 表达。
3. 一个明确的同步入口生成或复制 `units/linux-x86_64/System.pas`。
4. parity gate 比较 canonical output 与 installed copy；不一致立即失败。

迁移时不能用当前较小的 canonical file 覆盖 installed file。必须先逐项审计 installed file 已有符号，
把真实 compiler consumer 需要的声明迁回 canonical family，再建立 projection。

compiler 的 semantic/query/build 测试只消费 installed projection，从而验证发行布局中的真实输入；
source-contract gate 同时验证 canonical ownership 与 projection parity。

### `nextpas.core.system` 不再定义第二套根类型

`core/src/nextpas.core.system.pas` 是 namespaced facade 和 compiler/runtime contract 入口，不是第二个
magic unit。最终形态遵循这些规则：

- FPC 路径 alias/route 到 host `System`。
- nextPas 路径 alias/route 到 nextPas-owned magic `System`。
- `nextpas.core.system.contracts` 保持 constants-only，不实现 runtime 行为。
- compiler-visible root type、VMT、RTTI 和 managed-layout 声明只由 canonical magic `System` 拥有。
- 当前 `nextpas.core.system.*.inc` 中属于 magic kernel 的内容迁入或复用 canonical family；不能继续
  独立复制 `TObject`、`TTypeKind` 或 ABI layout。
- facade helper 只做 alias 或 inline forwarding，真实实现仍留在 base、mem、text、fs、time、thread、
  io 等 owner module。

`nextpas.core.system.sysutils` 和 `nextpas.core.system.classes` 属于 compatibility facade，不进入 compiler
bootstrap kernel。它们只有在真实 consumer pressure、owner delegation 和 focused tests 同时存在时
才保留或扩展。

## 自举依赖保持单向

```text
FPC stage0
  -> compiler pre-System kernel
  -> target-installed System projection
  -> semantic model and typed HIR contracts
  -> runtime/CRT/backend implementation
  -> stage A compiler + System bundle
  -> stage B rebuild
  -> stage C rebuild and comparison
```

这条链禁止以下反向依赖：

- magic `System` 依赖 `nextpas.core`
- compiler parser/resolver 依赖由 `System` 才能声明的 class/runtime 行为
- runtime helper 重新推导 compiler semantic truth
- compatibility facade 成为加载 magic `System` 的前置条件
- resolver 通过排除合法 dependency 来掩盖 backend 或 assembler failure

## compiler 使用 typed system contract

`np.system.*` 名称是 compiler 与 runtime 之间的语义 contract，不应长期作为跨层字符串协议。

compiler 侧增加一个集中 adapter，将 constants-only system vocabulary 映射为 typed contract kind。
Semantic model、HIR 和 MIR 传递 enum/record identity；只有 diagnostics、trace 和稳定文本投影需要
格式化为 `np.system.*` 名称。

每个 contract record 至少携带：

- contract kind
- source symbol 或 owner unit identity
- target type/layout identity（适用时）
- ownership/lifetime intent
- failure behavior

backend helper symbol 是 contract 的实现映射，不是 semantic authority。新增 helper 前必须先有
system contract、typed compiler mapping 和 focused executable proof。

### contract ledger 让纵向映射可检查

compiler 侧使用一个机器可检查的 `TSystemContractKind` ledger，不再靠文档或分散的 `if Name = ...`
维持映射。推荐 owner 是 `compiler/ir/np_system_contracts.pas`，它消费 constants-only
`nextpas.core.system.contracts` vocabulary，并为每个 contract 固定：

- typed contract kind 与稳定 semantic name
- source declaration owner 与要求的 symbol/type identity
- semantic/HIR/MIR 表达
- runtime/backend helper mapping
- ownership/lifetime policy
- failure policy
- focused source、compile 和 executable evidence

ledger 必须一对一覆盖 live `np.system.*` vocabulary。缺少 source owner、重复 semantic name、缺少 helper
mapping 或缺少 evidence 的条目都让 contract gate 失败。文档 coverage table 由 ledger 投影或校验，不能
成为另一份手工维护的权威数据。

### contract fingerprint 标识实际编译真相

每次 compiler-system build 计算内部 `SystemContractFingerprint`：

```text
SHA-256(
  canonical installed System bytes
  + normalized contract ledger
  + target layout facts
  + compiler semantic schema version
)
```

fingerprint 进入 compilation session、cache key、build trace、command envelope 和 stage identity。A、B、C
自举必须报告实际使用的 compiler path、source revision、target identity 与 fingerprint，harness 据此拒绝
错代调用、stale installed System 或 layout/contract 漂移。

fingerprint 是内部构建身份，不是公开 ABI version。它不承诺跨版本二进制兼容，也不包含工作目录、
时间戳或其他机器特有数据。

## 按六个里程碑推进

### M0：收敛 System truth

- 冻结 system API 扩张。
- 建立 magic source、installed projection、namespaced facade、compiler mapping 与 runtime helper 的
  coverage matrix。
- 建立机器可检查的 contract ledger，并让现有文档 coverage table 与它一致。
- 审计两个 `System.pas` 的现有差异及真实 consumer。
- 把必需声明迁回 canonical family。
- 增加 projection/sync 入口和 parity gate。
- 修正 README、goal tree、readiness 与 source-contract 的冲突状态。

完成标准：canonical source 与 installed projection 一致，仓库只有一个 compiler root type owner。

### M1：完成最小 bootstrap kernel

- 收敛 scalar/pointer aliases、`TObject/TClass`、VMT、managed types、最低 RTTI 与 exception root。
- 明确 compiler-owned intrinsic facts 与 source-owned public declarations 的边界。
- FPC-routed 和 nextPas-routed 两条编译路径都通过 forced compile。
- 从 kernel 排除 path/fs/env/date/collections 等便利 API。

完成标准：compiler 能从 installed `System` 绑定所有第一阶段 kernel symbols，不依赖 broad facade。

### M2：类型化 compiler-system contract

- 将分散的 `np.system.*` string dispatch 收到 typed adapter。
- 让 source-backed symbol identity 贯穿 sema、HIR、MIR/backend mapping。
- 生成并投影 deterministic `SystemContractFingerprint`，将其接入 session、cache 与 stage identity。
- 修复 source-contract gate 对单个物理 `.pas` 文件的脆弱锁定，改为 logical owner family 或 executable
  behavior proof。
- 逐项冻结 object、interface、string、dynamic array、exception 与 lifecycle mapping。

完成标准：每个 live contract 都能从 System declaration 追踪到 executable helper，没有未登记 magic string。

### M3：纵向接通 runtime behavior

按依赖顺序实现并验证：

1. process init/fini
2. unit init/fini ordering
3. object create/destroy/free
4. interface addref/release
5. string/dynamic-array/managed-record lifetime
6. exception raise/unwind/finally
7. allocator/memory-manager handshake

每项都包含声明、compiler lowering、runtime helper、失败路径和 leak-sensitive executable test。

完成标准：不再用文档或 source token 代替 runtime proof。

### M4：建立真实 A/B/C 自举

- 修复完整 compiler dependency closure 中真实出现的 assembler/backend blocker。
- stage A 必须是可执行 compiler，不是独立 unit object 集合。
- stage A 构建 compiler + canonical System bundle，得到 stage B。
- stage B 执行同一输入得到 stage C。
- 验证 B/C stage identity、命令来源、输出存在性、可执行性、diagnostics 与 artifact comparison。

当前 SIMD external-assembler failure 属于这一步的真实阻塞，但 resolver platform exclusion 不是修复。
由于根 checkout 有其他 owner 的 active SIMD 改动，compiler-system lane 在其 landing 或显式 handoff 前
不修改重叠 SIMD 文件。

完成标准：A -> B -> C 全链实际执行，任一步缺失、调用错代或产物不可执行都会让 gate 失败。

### M5：冻结确定性与性能

- 冷编译、热编译和重复构建基线
- dependency/incremental cache invalidation
- B/C artifact 与 behavior determinism
- typed contract dispatch 的分配与查找成本
- immutable System semantic snapshot 的命中率、构建成本与失效边界
- System projection 不触发每次编译时的仓库扫描或隐式写入

direct-object toolchain 可以在这里作为新的显式 plan family 评估。它不能静默替换当前
`bootstrap-native-assemble-link` production path。

完成标准：正确性、确定性和性能都有 fresh gate，不以一次成功自举替代长期基线。

## 失败必须在所属层暴露

compiler-system spine 使用 fail-fast、typed diagnostic：

| Failure                            | Owner                  | Required evidence                                           |
| ---------------------------------- | ---------------------- | ----------------------------------------------------------- |
| canonical/installed mismatch       | System projection      | parity gate 指出两个路径与首个差异                          |
| implicit System missing/unreadable | resolver               | typed resolution diagnostic 与 consulted provenance         |
| compiler root/type-kind 重复或缺失 | sema/type graph        | source symbol 与 owner unit diagnostic                      |
| contract 未登记或 helper 无映射    | typed contract adapter | contract kind、source owner 与 backend mapping diagnostic   |
| contract fingerprint 不一致        | session/bootstrap      | expected/actual fingerprint、stage identity 与 target facts |
| runtime helper/link symbol 缺失    | backend/toolchain      | exact failed step、symbol、object inputs                    |
| stage 调用了错误 compiler          | bootstrap harness      | expected/actual stage identity 与 executable path           |
| runtime ownership/lifecycle 错误   | runtime                | executable regression、exit status 与 leak/fault evidence   |

不允许用 fallback silently 选择 host `System`、跳过依赖单元或把 failed stage 标记为成功。

## 验证矩阵

每个纵向切片按影响面选择证据，但进入 landing 前至少覆盖：

- source truth：System canonical ownership、installed parity、contract coverage
- identity truth：normalized contract ledger、fingerprint 与 stage provenance
- forced compile：FPC-routed 与 nextPas-routed kernel path
- compiler consumer：implicit/explicit `System` resolution、definition binding、typed HIR/MIR mapping
- runtime：当前 contract 的成功、边界、失败与 leak-sensitive test
- bootstrap：真实 A/B/C executable chain
- repository：`git diff --check`、`make hygiene`

source-contract 只证明文本/owner boundary；forced compile 不证明 runtime；单个 executable test 也不证明
bootstrap。报告必须分别列出证据，不能用一个绿色命令替代全部 truth category。

## 性能约束

- implicit `System` 通过 target-installed provenance 直接解析，不以全仓扫描决定是否加入 graph。
- UnitGraph 只包含 root、implicit runtime 与真实 `uses` closure。
- typed contract identity 避免在 sema/HIR/backend 热路径反复比较和解析字符串。
- compiler 为每个 `(SystemContractFingerprint, target facts)` 建立一个 immutable
  `TSystemSemanticSnapshot`。snapshot 包含 source file identity、root symbols/types、layout facts 与 typed
  contract bindings，由同一 compilation session 或 workspace analysis context 中的所有 unit 只读共享。
- System snapshot 每个有效 key 只解析和分析一次；canonical projection、target layout、contract ledger 或
  compiler semantic schema 任一变化都会建立新 snapshot。禁止用 path-only key 或 mutable process-global
  cache 复用旧 truth。
- System kernel 保持最小，避免每个程序隐式加载 broad compatibility facade。
- projection 是显式 build/install 动作，不在普通 compiler invocation 中修改源码树。
- 性能优化不得弱化 failure attribution、determinism 或 owner boundary。

## Git 与并发开发纪律

长期责任 lane 为：

- worktree：`.worktrees/compiler-system`
- branch：`codex/compiler-system`

默认允许的实现路径是 compiler、`rtl/core/system`、`core/src/nextpas.core.system*`、target-installed
System projection、对应测试、脚本和文档。受控跨模块修改必须说明 design reason、风险和额外 gate。

长期 lane 不 raw merge 到 `main`。每个 ready slice 从最新 `main` 创建 landing candidate，按提交 replay，
检查历史和最终 diff 的允许路径，运行双模块 focused verification，然后 ff-only landing。

根 checkout 与其他 worktree 的 dirty 文件属于其 owner。尤其是当前 active SIMD/bench 路径，未经 handoff
不能复制、修改、暂存或纳入 compiler-system 提交。

## 非目标

这条主线当前不做：

- Linux x86_64 之外的 target 扩展
- FPC ABI/binary compatibility 承诺
- broad SysUtils/Classes/System API 扩张
- 把 allocator、fs、path、time、thread 或 collections 实现搬进 System
- resolver platform-exclude
- 用 FPC internal object emission 临时替换稳定 production plan
- 为了文档变绿而删除已有 consumer 所需声明
- 在 A/B/C 自举完成前宣称 self-host ready

## 回退信号

出现以下任一情况，停止扩能力并回到 owner/truth 设计：

- 新增第二个 `TObject`、`TTypeKind`、VMT 或 managed-layout authority
- installed `System` 可以绕过 canonical source 单独修改
- compiler/runtime 使用未登记的字符串 helper 名称
- magic `System` 开始依赖 `nextpas.core` convenience modules
- source-contract 通过，但 executable behavior 仍无证据
- bootstrap 脚本只检查文件存在，不执行下一代 compiler
- 为绕过 assembler/backend failure 而隐藏合法 dependency

## 完成定义

compiler-system 第一阶段只有同时满足以下条件才完成：

1. magic `System` 有唯一 canonical source，所有 installed copies 是可验证 projection。
2. `nextpas.core.system` 不再定义平行 compiler root truth。
3. compiler microkernel、source-backed symbols、typed contracts 与 runtime helpers 的边界无环且可追踪。
4. machine-checkable ledger 一对一覆盖 live contracts，fingerprint 能标识实际 System/target/schema truth。
5. immutable System semantic snapshot 有确定的 key、owner、失效规则和命中证据。
6. 第一阶段 runtime contracts 均有 compiler consumer 和 executable failure/success evidence。
7. stage A、B、C 都是实际执行的 compiler，并重建同一份 compiler-system bundle。
8. focused gates、`git diff --check` 与 `make hygiene` 在最新-main landing candidate 上通过。
9. 文档只声明 fresh evidence 能证明的能力。
