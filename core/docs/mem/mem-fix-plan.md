# mem 修复计划

> 基线日期：2026-06-22
> 工作树：`/home/dtamade/projects/nextPas/.worktrees/feat-arena-allocator`
> 输入文件：`core/docs/mem/mem-findings.md`
> 说明：当前 `mem-findings.md` 实际包含 **52** 条条目，不是 46 条。以下计划按当前文件里的 **52 条** 逐条评估。

## 结论摘要

- **P0 两条都是真问题**，而且都在 `core/src/nextpas.core.mem.arena.local.pas`，不是 `mem.allocator.pas`。最佳修法是 **DEBUG/Assert 保护 + Release 零额外分支**，避免影响热路径。
- **优先级最高的非 P0 风险不是代码 bug，而是分支与 `main` 的 surface 漂移**：
  当前分支相对 `main` 缺少 11 个 legacy/compat 文件，A-01 本质上是 **main 收敛问题**，不是“这轮代码刚删错了 11 个文件”。
- `TVirtualArena` 的大对象行为（`Reset` / `SaveMark` / `RestoreToMark` 不回收 large block）从现状看更像 **有意语义但缺文档/测试**，不建议在当前批次直接改 public 语义。
- `TShardedBlockPool.Reset` 的“潜在死锁”**当前锁图下没有充分证据成立**。更合理的动作是补 stress test 和锁序注释，不建议先改锁顺序。
- `IMemoryPool`“孤立无实现”这条 **已过时**：当前 `TSlabPool`、`TFixedSlabPool`、`TSlabPoolConcurrent`、`TSlabPoolSharded` 都实现了它。

## 处理原则

- **安全优先**：P0 第一批，且只接受不影响 Release 热路径的修法。
- **先收敛，再清理**：所有跟 `main` surface 有关的条目先单独收敛，不把“缺 main 文件”混进普通 bugfix。
- **区分 bug 与 contract**：真实 bug 修代码；有意行为但文档缺失的项，先补文档和测试，不随意改 public 语义。
- **验证先 focused 后 benchmark**：每批先跑对应 mem focused gate，再跑 `git diff --check` / `make hygiene`；涉及热路径的批次补跑 mem benchmark。
- **不牺牲性能换安心**：`AllocFast` / `AllocAlignedFast` / `AllocUnsafe` 不加 Release 分支检查；只允许 `Assert`、source-contract、benchmark 三件套。

## Finding 分流

| 分流 | 数量 | 说明 |
|---|---:|---|
| 直接代码修复/补测试 | 21 | 真 bug、真缺口，应该落代码或 focused test |
| 文档/契约冻结 | 11 | 当前实现更像有意语义，但缺文档或 contract test |
| `main` 收敛 / 架构决策 | 13 | 先和 `main` 对齐，再决定是否继续清理 |
| 建议关闭 / 降级 | 7 | 当前分支已过时、证据不足，或不值得在本轮动刀 |

## 推荐批次

### Batch 1: `arena.local` P0 快速路径防护

**目标**

- 处理 `S-01`、`S-02`
- 不改变 Release 热路径的指令形状

**涉及文件**

- `core/src/nextpas.core.mem.arena.local.pas`
- `core/tests/nextpas.core.mem/test_arena_class/test_arena_class.lpr`
- 如需 source-contract：`core/tests/nextpas.core.mem/test_contracts/test_contracts.lpr`

**具体改动**

- 在 `AllocFast` 上增加仅 DEBUG 生效的前置断言：
  `FBacking <> nil`、`ASize > 0`、`FOffset <= FCapacity`、`ASize <= FCapacity - FOffset`
- 在 `AllocAlignedFast` 上增加仅 DEBUG 生效的前置断言：
  `FBacking <> nil`、`ASize > 0`、`AAlign > 0`、`IsPowerOfTwo(AAlign)`、容量不越界
- 不引入 Release 分支检查，不修改返回值语义
- 补 2 类测试：
  - 现有正路径测试继续覆盖顺序分配/对齐
  - 新增 debug-only/source-contract 断言存在性验证，防止后续被删掉

**影响范围**

- 仅 `TLocalArena` 快速 API
- 不涉及 `TVirtualArena.AllocUnsafe`

**风险**

- 低
- 主要风险是测试设计不当导致在 assertions-off 构建下误报

**预估工时**

- 0.5 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_arena_class`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_contracts`
- `make -C core/benchmarks/nextpas.core.mem/bench_arena_vs_rtl run`
- `git diff --check`
- `make hygiene`

### Batch 2: 与 `main` 的 mem surface 收敛

**目标**

- 处理 `A-01`、`A-02`
- 先把“当前分支缺 `main` 文件”与“当前分支真实 bug”拆开

**涉及文件**

- 当前分支缺失的 11 个 `core/src/nextpas.core.mem*.pas`
- `core/src/nextpas.core.mem.pas`
- `core/tests/architecture/source_contracts/architecture_contract_registry.json`
- `core/tests/nextpas.core.architecture/test_core_architecture_contracts/check_core_architecture_contracts.sh`

**具体改动**

- 从最新 `main` 先 replay / cherry-pick 这 11 个 compat/legacy surface，确认 branch 对 `main` 不再天然缺文件
- 明确 `nextpas.core.mem.pas` 门面策略：
  - **推荐**：维持“核心门面 + 高级子模块 direct uses”的最小门面
  - 在门面头部和 contract test 中显式写清楚，不再靠隐式导出猜
- 若决定继续保留薄兼容 wrapper，则同步更新 architecture/source-contract truth
- 若决定删除 wrapper，则必须同步更新：
  - source contract registry
  - architecture contract checker
  - 依赖这些 wrapper 的 test/fixture/doc

**影响范围**

- mem public surface
- architecture/source-contract tests
- 与 `main` 的后续 landing 风险

**风险**

- 中
- 这是整个计划里最容易“修了代码但 landing 还是错”的一批

**预估工时**

- 1 到 1.5 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_contracts`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_l0_dependency_boundaries`
- `bash core/tests/nextpas.core.architecture/test_core_architecture_contracts/check_core_architecture_contracts.sh`
- `git diff --check`
- `make hygiene`

### Batch 3: dead mimalloc / dead alias / 低风险清理

**目标**

- 处理 `A-03`、`A-04`、`A-09`、`Q-07`

**涉及文件**

- `core/src/nextpas.core.mem.mimalloc.pas`
- `core/src/nextpas.core.mem.mimalloc.ffi.pas`
- `core/src/nextpas.core.mem.allocator.mimalloc.pas`
- `core/src/nextpas.core.mem.base.pas`
- `core/src/nextpas.core.mem.blockpool.pas`
- 相关 contract/test 文件

**具体改动**

- 删除零仓库生产引用的旧 `mem.mimalloc` / `mem.mimalloc.ffi`
- 从 `allocator.mimalloc` 去掉 `nextpas.core.path` 死导入
- 保留 `nextpas.core.os.env`，因为当前实现确实用 `GetEnvironmentVariable`
- 删除 `TArenaMarker` 死别名，统一只保留 `TArenaMark`
- 给 `TBlockPoolBase` 补 `deprecated` 关键字，而不是只靠注释说“已废弃”

**影响范围**

- mimalloc surface
- public type alias
- source-contract / compile gate

**风险**

- 低到中
- 最大风险是删死代码时漏掉 contract fixture 或兼容导出

**预估工时**

- 0.5 到 1 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_default_allocator`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_memory_manager_rtl`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_contracts`
- `git diff --check`
- `make hygiene`

### Batch 4: `TVirtualArena` 真实 hardening + 语义冻结

**目标**

- 处理 `M-02`、`T-02` 的 `ResetHard/AllocUnsafe` 缺口
- 冻结 `B-02`、`B-03`、`B-04`、`M-01`、`Q-04`、`Q-05` 的当前语义

**涉及文件**

- `core/src/nextpas.core.mem.arena.virtual.pas`
- `core/src/nextpas.core.mem.arena.base.pas`（如需仅文档说明，不建议改 public layout）
- `core/tests/nextpas.core.mem/test_arena_compiler/test_arena_compiler.lpr`
- `core/docs/mem/API.md`
- `core/docs/mem/ARCHITECTURE.md`
- `core/docs/mem/README.md`

**具体改动**

- **代码修复**
  - 给 `AllocNoPointer` 加下溢前置检查，避免 `PtrUInt` wrap-around
  - 把 `COMMIT_CHUNK_SIZE` 从 typed const 改成真正 `const`（`Q-01` 可一并做）
- **测试补强**
  - 补 `ResetHard` focused tests
  - 补 `AllocUnsafe` focused tests，只验证当前 contract，不给它加 Release guard
  - 补 large-object 语义测试：
    - `Reset` 后 large object 仍计入 `FLargeUsed`
    - `SaveMark/RestoreToMark` 不回收 large object
- **文档冻结**
  - 明确 `AllocUnsafe` 的前提：调用方自保，统计值不完整，对齐不保证
  - 明确 `Reset` / `ResetHard` / `Release` 的差异
  - 明确大对象是 independent lifecycle，不受 mark/reset 影响
- **不做的事**
  - 本批不改 large-object lifecycle 语义
  - 本批不扩展“带错误码的 alloc”API

**影响范围**

- `TVirtualArena`
- arena 文档与 focused tests

**风险**

- 中
- 风险点在于把“实现事实”写成“稳定 contract”后，后续再改语义代价会上升

**预估工时**

- 1 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_arena_compiler`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_platform_virtual`
- `make -C core/benchmarks/nextpas.core.mem/bench_arena_vs_rtl run`
- `git diff --check`
- `make hygiene`

### Batch 5: concurrent wrapper 与 sharded pool 并发语义补强

**目标**

- 处理 `R-01`、`R-02`、`R-04`、`M-03`
- 对 `R-03` 做证据化验证，而不是先改锁序

**涉及文件**

- `core/src/nextpas.core.mem.arena.concurrent.pas`
- `core/src/nextpas.core.mem.blockpool.concurrent.pas`
- `core/src/nextpas.core.mem.blockpool.sharded.pas`
- `core/src/nextpas.core.mem.mutex.pas`
- `core/tests/nextpas.core.mem/test_concurrent_wrappers/test_concurrent_wrappers.lpr`
- `core/tests/nextpas.core.mem/test_sharded_pools/test_sharded_pools.lpr`

**具体改动**

- 给 `TArenaConcurrent.UsedSize` / `RemainingSize` 补锁，保证 wrapper 的 thread-safe 叙述与实现一致
- 给 `TBlockPoolConcurrent.Available` / `InUse` 补锁；`BlockSize` / `Capacity` 可维持无锁只读
- `TMemMutex.Init` 文档化为“仅能在单线程初始化阶段调用”；如果要增强，可补 debug assert，不建议做 record 级 once-init
- `TShardedBlockPool` 线程缓存：
  - **推荐**：在实现未补 thread-exit cleanup 前，显式拒绝 `ThreadCacheCapacity > 0`
  - 这样比“默默把配置吞掉并把代码留着”更安全
- `R-03` 不直接改锁顺序，先补：
  - `Reset` vs `Acquire/Release` stress test
  - route/shard 锁序注释

**影响范围**

- 并发包装器
- sharded pool config 行为

**风险**

- 中
- 非功能风险主要是 wrapper 读方法加锁后吞吐下降，但这是包装器可接受代价

**预估工时**

- 1 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_concurrent_wrappers`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_sharded_pools`
- `git diff --check`
- `make hygiene`

### Batch 6: slab/pool surface 硬化与缺测补齐

**目标**

- 处理 `A-10`、`M-04`、`T-01`、`T-03`、`T-04`
- 顺带把 `A-05`、`A-06`、`A-07` 的真实状态写清楚

**涉及文件**

- `core/src/nextpas.core.mem.pool.slab.pas`
- `core/src/nextpas.core.mem.pool.pas`
- `core/src/nextpas.core.mem.pool.memory_pool.pas`
- `core/src/nextpas.core.mem.blockpool.pas`
- `core/tests/nextpas.core.mem/test_slab_pool/test_slab_pool.lpr`
- `core/tests/nextpas.core.mem/test_pool/test_pool.lpr`
- `core/tests/nextpas.core.mem/test_blockpool/test_blockpool.lpr`
- `core/tests/nextpas.core.mem/test_oom/test_oom.lpr`

**具体改动**

- `TSlabPool.PageKeyOf` 改成不依赖 `FSegments[0]`：
  - **推荐**：把 `PageShift` 缓存在 `TSlabPool` 自身字段中
  - 不建议每次都去假定第一个 segment 存在
- `IMemoryPool` 不删除；补文档说明它的实现者与定位
- `IPool` / `IBlockPool` 的 Acquire 差异写进 API contract
- 为当前缺 direct test 的 surface 补最小 focused tests：
  - `allocator.callback`
  - `mutex`
  - `rwlock`
  - `pool.memory_pool`（通过 `TSlabPool` / `TFixedSlabPool` surface 间接验证）
- OOM 方面补足：
  - `VirtualArena` 极端 large alloc fail-close
  - `ChunkedArena` segment growth OOM
  - `mapped` / slab 失败路径

**影响范围**

- pool/slab surface
- mem test matrix

**风险**

- 中
- `PageKeyOf` 修法如果选错，会影响 slab 路由正确性

**预估工时**

- 1 到 1.5 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_slab_pool`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_pool`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_blockpool`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_oom`
- `git diff --check`
- `make hygiene`

### Batch 7: 性能与统计修正

**目标**

- 处理 `P-01`、`P-02`、`P-03`、`P-04`
- 把 `A-13` 保持为 debt，不混进本批大改

**涉及文件**

- `core/src/nextpas.core.mem.arena.chunked.pas`
- `core/src/nextpas.core.mem.arena.local.pas`
- `core/src/nextpas.core.mem.ring_buffer.pas`
- `core/src/nextpas.core.mem.arena.base.pas`（仅当 `TArenaStats` contract 需要调整）

**具体改动**

- `TChunkedArena.FSegments` / `FFreeSegments` 改几何扩容，避免每次 `+1`
- `TArenaStats.AllocCount`：
  - **推荐**：短期做饱和返回，保持 public record 不变
  - 不建议这轮直接把字段从 `SizeUInt` 改成 `QWord`
- `TLocalArena` 缓存对齐 mask，减少 `AllocAligned` 热路径重复计算
- `TRingBuffer` 对 `pow2 capacity` 走位与快速路径，统一复用 helper
- 不在这一批处理 `SysUtils` 迁移；该项应单独作为 L0 debt slice

**影响范围**

- arena 性能
- ring buffer 性能
- stats contract

**风险**

- 中
- 这批最需要 benchmark 约束，避免“修得更复杂但没收益”

**预估工时**

- 1 天

**验证**

- `make focused FOCUS=core/tests/nextpas.core.mem/test_arena_growable`
- `make focused FOCUS=core/tests/nextpas.core.mem/test_stack_pool`
- `make -C core/benchmarks/nextpas.core.mem/bench_alloc run`
- `make -C core/benchmarks/nextpas.core.mem/bench_arena_vs_rtl run`
- `git diff --check`
- `make hygiene`

### Batch 8: 文档刷新与低优先级风格债

**目标**

- 处理 `D-01`、`D-02`、`D-03`
- 收口 `A-15`、`B-08` 这类不值得单独开大批次的风格项

**涉及文件**

- `core/docs/mem/ARCHITECTURE.md`
- `core/docs/mem/API.md`
- `core/docs/mem/README.md`
- 如需：`core/docs/mem/mapped-family-ownership-decision.md`

**具体改动**

- 重写 mem 架构文档，反映当前真实文件结构和 owner boundary
- API 文档改成“当前 contract truth”，去掉旧名词：
  - `TFastArena`
  - `TGrowableArena`
  - `TArenaMarker`
- README 补：
  - Arena 选择指南
  - `IAllocator` vs `IArena` 使用时机
  - `AllocFast` / `AllocAlignedFast` / `AllocUnsafe` 前提
  - mapped family owner boundary
- 文件名下划线/参数命名不做大规模 rename，只在文档标债，不制造无收益 churn

**影响范围**

- mem 文档
- architecture/source-contract docs truth

**风险**

- 低
- 风险主要是文档写成“理想状态”而不是“当前真实状态”

**预估工时**

- 0.5 到 1 天

**验证**

- `bash core/tests/nextpas.core.architecture/test_core_architecture_contracts/check_core_architecture_contracts.sh`
- `git diff --check`
- `make hygiene`

## 不建议在本轮直接做的事

- **直接改 `TVirtualArena` large-object lifecycle**：会触及 `TArenaMark` / public arena contract，建议先冻结文档和 tests，再决定要不要另开语义重构。
- **给 `TChunkedArena` 硬补 `AllocUnsafe`**：这是 API 扩张，不是 bugfix；除非 benchmark 明确证明必要，否则不建议加。
- **为 `TShardedBlockPool.Reset` 先改锁顺序**：当前锁图没有充分证据证明死锁，先补 stress test 更稳。
- **把 `TArenaStats.AllocCount` 直接改成 `QWord`**：会扩散 public surface；当前更稳的做法是先饱和返回。
- **处理 `compiler/` 为什么不用 mem 模块**：这是编译器/架构问题，不应混入本轮 mem 修复。

## Findings 判定矩阵

| ID | 判定 | 处理建议 | 难度 | 批次 |
|---|---|---|---|---|
| A-01 | 真实，但属于 `main` 收敛差异 | replay / 对齐 11 个 `main` surface，再决定删留 | 中 | Batch 2 |
| A-02 | 真实 | 先定门面策略，再更新 contract/test | 中 | Batch 2 |
| A-03 | 真实 | 删除旧 `mem.mimalloc*` 死代码 | 低 | Batch 3 |
| A-04 | 部分真实 | 删 `nextpas.core.path` 死导入；`os.env` 先保留 | 低 | Batch 3 |
| A-05 | 已过时 | 关闭；`IMemoryPool` 当前有多实现者 | 低 | 关闭 |
| A-06 | 部分真实 | 不删；补“无生产 consumer、但有 tests”说明 | 低 | Batch 8 |
| A-07 | 真实 | 先记录 duplication，暂不在本轮强行合并实现 | 中 | Batch 2 |
| A-08 | 部分真实 | 保留 `manager.*`，补命名/定位说明 | 低 | Batch 8 |
| A-09 | 真实 | 删除 `TArenaMarker` 死别名 | 低 | Batch 3 |
| A-10 | 真实 | API 文档明确 `IPool` / `IBlockPool` 差异 | 低 | Batch 6 |
| A-11 | 真实观察项 | 不在本轮 mem lane 处理 | 低 | 观察 |
| A-12 | 真实观察项 | 按现有 owner doc 保持不动 | 低 | 观察 |
| A-13 | 真实 debt | 记录到后续 L0 debt，不混入当前批次 | 中 | 后续 |
| A-14 | 部分真实 | wrapper 仍有 mem 内部 consumer，先不删 | 低 | Batch 8 |
| A-15 | 真实 style debt | 仅记债，不做大规模 rename | 低 | Batch 8 |
| B-01 | 真实 | 文档化“构造失败抛异常 / 分配失败返回 nil” | 低 | Batch 4 / 8 |
| B-02 | 真实且有意 | 文档+test 固化，不改 Release 行为 | 低 | Batch 4 |
| B-03 | 真实且有意 | 文档+test 固化 large-object lifecycle | 中 | Batch 4 |
| B-04 | 真实 | 文档明确 `Reset` / `ResetHard` 差异 | 低 | Batch 4 |
| B-05 | 真实 | 文档说明 `IAllocator` vs `IArena` 命名定位 | 低 | Batch 8 |
| B-06 | 不建议本轮处理 | 关闭为“API parity 愿望”，不是 bug | 低 | 关闭 |
| B-07 | 真实且有意 | 文档说明 `TVirtualArena` record 不实现接口的原因 | 低 | Batch 8 |
| B-08 | 真实 style debt | 不做大规模 rename，只在 touched files 顺手统一 | 低 | Batch 8 |
| S-01 | 真实 P0 | DEBUG assert + focused test + benchmark | 低 | Batch 1 |
| S-02 | 真实 P0 | DEBUG assert + focused test + benchmark | 低 | Batch 1 |
| R-01 | 真实 | 给 `UsedSize` / `RemainingSize` 补锁 | 低 | Batch 5 |
| R-02 | 真实 | 给 `Available` / `InUse` 补锁 | 低 | Batch 5 |
| R-03 | 证据不足 | 改为 stress test + 锁序注释，不先改实现 | 中 | Batch 5 |
| R-04 | 真实 | 文档化单线程 init 前提，必要时加 debug assert | 低 | Batch 5 |
| M-01 | 真实且有意 | 文档+test 固化，不改 public 语义 | 中 | Batch 4 |
| M-02 | 真实 | 给 `AllocNoPointer` 加下溢前置检查 | 低 | Batch 4 |
| M-03 | 真实 | 显式拒绝 `ThreadCacheCapacity > 0` 或删死路径 | 中 | Batch 5 |
| M-04 | 真实 | `PageKeyOf` 改为不依赖 `FSegments[0]` | 低 | Batch 6 |
| T-01 | 大体真实 | 补 direct tests，优先 callback/mutex/rwlock | 中 | Batch 6 |
| T-02 | 部分真实 | `AllocUnsafe` / `ResetHard` 补测；`AllocFast*` 已有测试 | 低 | Batch 4 |
| T-03 | 真实 | 加高竞争 stress test | 中 | Batch 6 |
| T-04 | 真实 | 补 arena/slab/mmap 失败路径测试 | 中 | Batch 6 |
| P-01 | 真实 | `FSegments` / cache 几何扩容 | 低 | Batch 7 |
| P-02 | 真实 | 短期做饱和返回，不改 public type | 中 | Batch 7 |
| P-03 | 真实 | `TLocalArena` 缓存 alignment mask | 低 | Batch 7 |
| P-04 | 真实 | `pow2 capacity` 走位与快速路径 | 中 | Batch 7 |
| P-05 | 低价值观察项 | 关闭；先看 benchmark，不为 inline 而 inline | 低 | 关闭 |
| Q-01 | 真实 | typed const 改真正 `const` | 低 | Batch 4 |
| Q-02 | 真实但暂不处理 | 不加上限；先靠文档说明 large-object 行为 | 中 | 观察 |
| Q-03 | 不成立 | 当前 `Resize` 路径不存在实际除零 | 低 | 关闭 |
| Q-04 | 真实且有意 | 文档写清前提，不加 Release guard | 低 | Batch 4 |
| Q-05 | 真实 | 先文档化；错误码 API 另起设计 | 中 | Batch 4 |
| Q-06 | debug-only 观察项 | 不作为当前批次目标 | 低 | 观察 |
| Q-07 | 真实 | `deprecated` 关键字补齐 | 低 | Batch 3 |
| D-01 | 真实 | 重写 `ARCHITECTURE.md` | 低 | Batch 8 |
| D-02 | 真实 | 重写 `API.md` | 低 | Batch 8 |
| D-03 | 真实 | README 补使用指南与 owner boundary | 低 | Batch 8 |

## 总体排期建议

| 批次 | 预估 |
|---|---:|
| Batch 1 | 0.5 天 |
| Batch 2 | 1.0 - 1.5 天 |
| Batch 3 | 0.5 - 1.0 天 |
| Batch 4 | 1.0 天 |
| Batch 5 | 1.0 天 |
| Batch 6 | 1.0 - 1.5 天 |
| Batch 7 | 1.0 天 |
| Batch 8 | 0.5 - 1.0 天 |
| **合计** | **6.5 - 8.5 天** |

## 推荐执行顺序

1. Batch 1
2. Batch 2
3. Batch 3
4. Batch 4
5. Batch 5
6. Batch 6
7. Batch 7
8. Batch 8

这个顺序的核心原因是：先把 **P0** 和 **`main` 收敛** 做掉，再处理真实 correctness，再做 tests/perf/docs。否则后面的很多改动会继续建立在漂移的 surface 上。
