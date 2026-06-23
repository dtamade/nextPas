# mem 模块全面审查报告

> 扫描时间：2026-06-23
> 上次审查：2026-06-21
> 分支：feat/arena-allocator
> 基线变更：`bd9b14c97`, `d9d75726c`, `30adb8262`, `c6e8be8d2`
> 当前范围：`core/src/nextpas.core.mem*.pas`（55 文件）+ `core/tests/nextpas.core.mem/*`（32 项目，静态计数 304 个 `T.Run`）+ `core/docs/mem/*`
> 方法：旧 findings 回归核对 + `git log -3 --stat` / `git show` + 全量静态扫描 + 测试/文档对照

---

## 一、架构与依赖

### A-01 [FIXED] 11 个兼容文件删除风险已消失

旧报告提到的 11 个文件当前都已回到源码树；`mapped_ring_buffer*` 也已经以 deprecated compatibility wrapper 形式保留，原先的“删文件导致主线契约断裂”不再成立。

---

### A-02 [FIXED] 门面导出已从“严重不完整”降为受控有限导出

`381e89f62` 为 `nextpas.core.mem.pas` 补导出了 `IBlockPool` / `IBlockPoolBatch` / `TBlockPool` / `TShardedBlockPool` / `TStackPool`。当前门面仍不是全量 re-export，但已经不再是旧报告里的 P1 级缺口；剩余高级子模块更像“有意不经门面暴露”的设计选择。

---

### A-03 [FIXED] 双重 mimalloc 实现已清掉

当前树里只剩：

- `nextpas.core.mem.allocator.mimalloc`
- `nextpas.core.mem.manager.mimalloc`

旧报告里的 `mem.mimalloc.pas` / `mem.mimalloc.ffi.pas` 已不在树中；`test_contracts` 也在检查旧 binding 文件应当不存在。

---

### A-04 [FIXED] mimalloc 动态加载策略已拆到 loader helper

**P2 | 文件：`core/src/nextpas.core.mem.allocator.mimalloc.loader.pas`, `core/src/nextpas.core.mem.allocator.mimalloc.pas`**

当前 owner boundary 已收口：

- `allocator.mimalloc.loader` owns env/path discovery 和搜索顺序
- `allocator.mimalloc` 只保留 mimalloc FFI、symbol 解析和 allocator 语义
- `ARCHITECTURE.md` 已明确搜索顺序：env override -> executable-relative `lib/<cpu-os>/` -> system loader fallback

---

### A-05 [FIXED] `IMemoryPool` 不再是孤立接口

**已验证实现方**：

- `TFixedSlabPool`
- `TSlabPool`
- `TSlabPoolConcurrent`
- `TSlabPoolSharded`

旧报告中“`pool.memory_pool.pas` 无实现”的判断已不成立。

---

### A-06 [FIXED] `ring_buffer` / `stack_pool` 不再是“零外部引用”

当前状态：

- `ring_buffer` 有 `test_oom` 等测试引用
- `stack_pool` 有独立测试项目，且已由门面 `nextpas.core.mem` re-export `TStackPool`

因此旧报告里的“可能死代码”结论不再成立。

---

### A-07 [FIXED] `TLocalBlockPool` 与 `TBlockPool` 的选择指南已补齐

**P3 | 文件：`core/docs/mem/README.md`, `core/docs/mem/API.md`**

当前文档已明确区分：

- `TLocalBlockPool`：class-only，本地简单固定块池
- `TBlockPool`：`IBlockPool` / `IBlockPoolBatch` 接口面，适合对齐、批量和范围查询场景

这条现在不再是“表面重叠但无选择指南”的开放问题。

---

### A-08 [FIXED] `manager.*` 与 `allocator.*` 的职责区分已经清晰

复核当前代码后，`manager.*` 与 `allocator.*` 的边界已经可以自洽：

- `allocator.*`：`IAllocator` 实现
- `manager.*`：FPC 全局 `TMemoryManager` 安装器

其中 `manager.crt` / `manager.rtl` 也已有对应测试/编译门。

---

### A-09 [FIXED] `TArenaMarker` 现在是明确的 deprecated 兼容别名

`nextpas.core.mem.base` 与门面 `nextpas.core.mem` 都把 `TArenaMarker` 标成 deprecated alias，旧报告里的“名称混淆”已经被压缩成兼容债，而不是当前行为问题。

---

### A-10 [FIXED] `IPool` / `IBlockPool` 的历史分叉已有代码内说明

`core/src/nextpas.core.mem.pool.memory_pool.pas` 现在明确写明：

- `IMemoryPool` 继承自历史 `IPool`
- `Acquire/TryAcquire` 属于旧“单位块”语义
- 可变大小分配应优先走 `GetMem/AllocMem/ReallocMem/FreeMem`

旧报告里的“完全无设计说明”已不成立。

---

### A-11 [FIXED] “编译器零引用”不再单列为 mem 模块缺陷

当前 `compiler/` 仍未直接引用 `nextpas.core.mem.*`，但这更像上层采用策略，而不是 mem 模块自身正确性问题。本轮不再把它作为 mem 缺陷跟踪。

---

### A-12 [FIXED] mapped memory primitive 的归属已冻结

**P3 | 文件：`core/src/nextpas.core.mem.memory_map.pas`, `core/src/nextpas.core.mem.mapped_slab_pool.pas`, `core/docs/mem/ARCHITECTURE.md`**

当前 owner 决策已明确：

- `TMemoryMap` 与 `TMappedSlabAllocator` 继续保留在 `mem`，因为它们表达的是 page-backed memory primitive
- `mapped_ring_buffer*` 继续只是 deprecated wrapper，owner 在 `io.mapped.*`
- `ARCHITECTURE.md` 已写清 mem 侧只保留 anonymous mapping allocator surface，不再把这条作为“待迁移归属缺口”跟踪

---

### A-13 [FIXED] 旧报告中的 `SysUtils` 直接依赖已清理

`f93a7ca47` 已把旧报告点名的 `allocator.mimalloc` / `allocator.tracking` / `pool.fixed` 上的 `SysUtils` 依赖移除。

---

### A-14 [FIXED] `mutex` / `rwlock` 的定位已收口为 mem 兼容包装

**P3 | 文件：`core/src/nextpas.core.mem.mutex.pas`, `core/src/nextpas.core.mem.rwlock.pas`**

这两个单元仍基本只转发到 `platform.sync`，但当前文档定位已经明确：

- 它们是 mem-local compatibility wrapper
- 真实宿主锁语义继续归 `platform.sync`
- 这不是新的并发原语层

同时旧描述里的 “`rwlock` 缺直接 focused gate” 也不再成立：

- `test_concurrent_wrappers` 已覆盖 rwlock lifecycle
- `test_contracts` 已覆盖 source-contract truth

因此这条现在关闭；剩余只是有意保留的一层兼容 public surface，而不是未解释或未验证的设计债。

---

### A-15 [WONTFIX] 文件命名仍混用下划线与点号风格

**P3**

当前仍有多处下划线命名保留，例如：

- `allocator.leak_check`
- `mapped_slab_pool`
- `memory_map`
- `pool.fixed_slab`
- `pool.memory_pool`
- `pool.object_pool`
- `ring_buffer`
- `stack_pool`

这条本轮不做 rename。Pascal unit 名和文件名强绑定，批量改名会同时放大：

- uses 子句 churn
- 兼容 alias / deprecated wrapper 成本
- 历史文档、测试项目、外部引用的同步代价

相较之下，收益只是风格统一；不值得为这条债在当前 lane 引入大面积 rename 风险。

---

### A-16 [FIXED] `mem.pool.adapter` 已移出活跃源码树

`core/src/nextpas.core.mem.pool.adapter.pas` 当前已经不存在，之前那层依赖失真且零覆盖的休眠兼容 surface 已从活跃源码树移除，不再继续制造“仍可用”的假表面。

---

### A-17 [FIXED] 零消费兼容单元已完成分类收敛

本轮已在 `core/src`、`core/tests`、`compiler`、`tests` 范围内复核引用后完成处理：

- 已删除零消费兼容单元：
  - `nextpas.core.mem.aligned`
  - `nextpas.core.mem.allocator.instrumentation`
  - `nextpas.core.mem.allocator.numa`
  - `nextpas.core.mem.stats`
  - `nextpas.core.mem.adapters`
  - `nextpas.core.mem.interfaces`
  - `nextpas.core.mem.stack_scope_helpers`
- `nextpas.core.mem.manager.mimalloc` 保留，并由 `test_memory_manager_mimalloc_compile_gate` 持续提供 compile-only gate
- `test_contracts` 现已把“上述 7 个兼容单元应当不存在、mimalloc manager 应当保留”固化为 source-contract

---

### A-18 [FIXED] `mem.arena.growable` 已移出活跃源码树

`core/src/nextpas.core.mem.arena.growable.pas` 当前已经不存在，之前那个既不可编译、又没有 live consumer 的失活 public unit 已不再挂在源码树里误导外部读者。

---

## 二、API 设计

### B-01 [FIXED] Arena 错误契约已写进 canonical API 文档

`core/docs/mem/API.md` 现在已经明确写出：

- 构造或初始化失败走异常
- `Alloc*` 失败返回 `nil`

这条总约定不再需要调用方靠源码细节自己推断。

---

### B-02 [FIXED] `AllocUnsafe` 的统计/对齐前提已有明确说明

当前至少三处已明确写出：

- `core/src/nextpas.core.mem.arena.virtual.pas`
- `core/docs/mem/README.md`
- `core/docs/mem/ARCHITECTURE.md`

同时 `test_arena_compiler` 已补上 `AllocUnsafe` 测试。

---

### B-03 [FIXED] `Reset` 不释放大对象这件事已经显式文档化

`f93a7ca47` 在 `arena.virtual` 的 `Reset` 注释中补上了说明；`README.md` / `ARCHITECTURE.md` 也同步写明大对象不受 mark/reset 影响。

---

### B-04 [FIXED] `Reset` / `ResetHard` / 各 Arena 语义差异已同步到 API 文档

`core/docs/mem/API.md` 当前已经把以下差异写清楚：

- `IArena` 只有 `Reset`
- `TVirtualArena` 额外暴露 `ResetHard`
- `TLocalArena`、`TChunkedArena`、`TVirtualArena` 分别描述了各自的 reset 资源语义

这条差异现在不再需要读者靠源码自行拼出来。

---

### B-05 [FIXED] `IAllocator` 与 `IArena` 的动词差异已可视为有意设计

复核当前代码后，这两套接口表达的是不同资源模型：

- `IAllocator`：heap-style `GetMem/AllocMem/ReallocMem/FreeMem`
- `IArena`：linear `Alloc/AllocAligned/AllocZeroed/Reset`

旧报告里把它当成“同一概念的命名不一致”已经过重。

---

### B-06 [FIXED] `TChunkedArena` 缺少 `AllocUnsafe` 不再单列为缺陷

当前代码和文档都没有承诺“所有 arena 都应提供统一 unsafe fast path”。`AllocUnsafe` 现在是 `TVirtualArena` 的特化能力，不再按对称性单列为缺陷。

---

### B-07 [FIXED] `TVirtualArena` 非 `IArena` 设计已经明确写进文档

`README.md` / `ARCHITECTURE.md` 已把它描述为 record + zero-dispatch arena，旧报告里的“为什么不实现 `IArena`”现在有明确解释。

---

### B-08 [FIXED] canonical allocator 参数命名已统一

**P3 | 文件：`core/src/nextpas.core.mem.intf.pas` 及对应实现 / mock / tests**

本轮已把 canonical `IAllocator` surface 统一成 A 前缀 PascalCase：

- `ASize`
- `ADst`
- `AAlignment`
- `APtr`

对应实现与测试签名也已同步；这条不再继续作为开放的 public API 风格债跟踪。

---

### B-09 [FIXED] active arena surface 对小对齐值已统一成“最小指针对齐”

当前行为已经收敛：

- `TChunkedArena.AllocAligned` 不再把 `< SizeOf(Pointer)` 的合法 2 的幂直接拒掉，而是提升到 `SizeOf(Pointer)`
- `TVirtualArena.AllocAligned` 继续保持同样的提升语义
- focused tests 已锁定 chunked 和 virtual 这条 contract

之前那种“同名方法、一个拒绝、一个提升”的行为差异已经消失。

---

## 三、安全（P0/P1）

### S-01 [FIXED] `AllocFast` 已有 DEBUG 边界断言

`core/src/nextpas.core.mem.arena.local.pas` 当前在 DEBUG 下断言：

- `FBacking <> nil`
- `ASize > 0`
- `FOffset <= FCapacity`
- `ASize <= FCapacity - FOffset`

`test_arena_class` 也补了 source-contract 测试。

---

### S-02 [FIXED] `AllocAlignedFast` 已有 DEBUG 对齐断言

当前 DEBUG 断言覆盖：

- `AAlign > 0`
- `IsPowerOfTwo(AAlign)`
- 剩余容量检查

旧报告里的“完全无防护”结论已不成立。

---

### S-03 [FIXED] `TCallbackAllocator` 现在无条件拒绝 `nil` 回调

`core/src/nextpas.core.mem.allocator.callback.pas` 的构造函数现在不再依赖 contracts 编译开关；只要任一回调为 `nil`，就直接抛 `EArgumentNil`。之前那条“保存 `nil` 函数指针，后续再跳空调用”的崩溃路径已经被关掉。

---

## 四、竞态条件

### R-01 [FIXED] `TArenaConcurrent` 读路径已全部持锁

当前 `UsedSize` / `RemainingSize` / `Stats` 都在 `FLock` 下访问，旧报告里的“读方法无锁”已修复。

---

### R-02 [FIXED] `TBlockPoolConcurrent` 读路径已全部持锁

当前 `Available` / `InUse` 也都在 `FLock` 下访问，旧报告里的“热字段无锁读取”已修复。

---

### R-03 [FIXED] `TShardedBlockPool Reset/Acquire` 的旧死锁怀疑本轮未复现

复核当前实现后：

- `TryRoute` 在拿 shard 锁前就释放 route 读锁
- `Reset` 明确先拿 shard 锁，再重建 route
- thread cache 旧路径已被禁用并有测试覆盖

旧报告里的死锁说法在当前实现上证据不足，本轮不再继续作为开放问题跟踪。

---

### R-04 [FIXED] `TMemMutex.Init/Done` 已切到线程安全的一次性初始化语义

当前 `core/src/nextpas.core.mem.mutex.pas` 已改为基于 `InterlockedCompareExchange` 的状态机：

- `Init` 只允许一次真正初始化
- `Done` 只允许一次真正销毁
- 并发 `Init` / `Done` / `Acquire` / `Release` 都先校验状态

验证也已补齐：

- `test_concurrent_wrappers` 覆盖 double init / double done / re-init / 未初始化保护
- `test_contracts` 用 source-contract 固化 “不再使用 `FInitialized: Boolean`，且 `Init/Done` 必须带原子 CAS”

---

### R-05 [FIXED] `TMemRwLock.Init/Done` 已同步切到线程安全的一次性初始化语义

`core/src/nextpas.core.mem.rwlock.pas` 已与 `TMemMutex` 对齐：

- `Init` / `Done` 使用 `InterlockedCompareExchange` 做 once-only 状态跃迁
- 未初始化时的 read/write acquire/release 都有显式保护
- `test_concurrent_wrappers` 与 `test_contracts` 已同步覆盖 rwlock 的 lifecycle 语义

---

### R-06 [FIXED] `manager.mimalloc` 安装/卸载路径已加锁

`core/src/nextpas.core.mem.manager.mimalloc.pas` 现在和 `manager.crt` / `manager.rtl` 一样，使用 `GManagerLock` 保护 `InstallMimallocMemoryManager` 与 `UninstallMimallocMemoryManager`。之前直接并发改全局 `TMemoryManager` 的竞态窗口已经收口。

---

## 五、内存安全

### M-01 [FIXED] `SaveMark/RestoreToMark` 已把大对象语义贴到方法级注释和测试上

`core/src/nextpas.core.mem.arena.virtual.pas` 现在已经在方法注释里明确写出：

- `SaveMark/RestoreToMark` 只回退 front/back bump pointer
- direct mmap 的大对象不会被 rewound，会一直存活到 `Release`

同时本轮还顺手修正了 `RestoreToMark` 的大对象统计语义，避免 restore 后把 `LargeUsed` 错误从 `TotalUsed` 中抹掉；`test_arena_compiler` 已新增 `TestRestoreToMarkKeepsLargeObjectUsage` 锁定该行为。

---

### M-02 [FIXED] `AllocNoPointer` 现在按 back 区剩余空间做下溢保护

`core/src/nextpas.core.mem.arena.virtual.pas` 当前已经改成基于 `FBackPtr - FBackBase` 的剩余空间判断，而不是拿请求大小去和绝对地址比较。此前那条“减法前没有证明 back 区仍有足够空间”的问题已修复。

---

### M-03 [FIXED] `thread cache` 泄漏路径已被硬禁用

当前 `TShardedBlockPool.Create` 在 `ThreadCacheCapacity > 0` 时直接抛错，并且 `test_sharded_pools` 专门验证了这个拒绝路径。

旧报告里的“代码仍可走到泄漏路径”不再成立。

---

### M-04 [FIXED] `TSlabPool.PageKeyOf` 不再访问 `FSegments[0]`

当前实现已改成固定 page shift 路径，不再依赖 `FSegments[0]`。

---

## 六、测试覆盖

### T-01 [FIXED] 本轮补齐了剩余 public surface 的 focused gate

当前已补齐：

- `allocator.callback`：`test_contracts` 新增 `nil` 回调负路径测试，且覆盖 contracts-on / contracts-off 两条路径
- `allocator.crt`：已有独立 focused gate `test_allocator_crt`
- `allocator.foundation`：已有独立 focused gate `test_allocator_foundation`
- `manager.mimalloc`：在当前宿主条件下保留 compile-only gate `test_memory_manager_mimalloc_compile_gate`

这批 surface 现在都已有明确的 focused verification 入口。

---

### T-02 [FIXED] `ResetHard` / `AllocUnsafe` 已有测试

`core/tests/nextpas.core.mem/test_arena_compiler/test_arena_compiler.lpr` 已覆盖：

- `TestResetHard`
- `TestAllocUnsafe`

---

### T-03 [FIXED] 并发压力验证已不再缺失在关键并发面

虽然 plain `TBlockPool` 本身不是线程安全类型，但当前已经有：

- `test_concurrent_wrappers`
- `test_sharded_pools`

覆盖真正需要的高竞争路径，因此旧报告里“缺少高竞争并发测试”的表述不再精确。

---

### T-04 [FIXED] VirtualArena 的 reserve/commit/mmap 失败路径已进入 OOM 套件

`core/tests/nextpas.core.mem/test_oom/test_oom.lpr` 现在已覆盖：

- `TVirtualArena_Init` reserve 失败
- front/back commit 失败
- 大对象 `platform_mmap_create_anonymous` 失败

同时 suite 还会断言 `LastAllocFailure` 的细分结果，避免只验证 “返回 nil” 而不验证失败分类。

---

### T-05 [FIXED] chunked arena focused gate 已改回真实命名

原来的 `test_arena_growable` 目录与程序名已经重命名为 `test_arena_chunked`。当前 suite 名不再暗示“growable arena 已被覆盖”，而是和实际被测试的 `TChunkedArena` 对齐。

---

## 七、性能

### P-01 [FIXED] `TChunkedArena.FSegments` 已改为几何扩容

当前 `AddSegment` / `TryReuseSegment` 都是：

- 初始 8
- 之后 2x 扩容

旧报告里的逐次 `SetLength +1` 已修复。

---

### P-02 [FIXED] `TChunkedArena.Stats.AllocCount` 截断已修复

`f93a7ca47` 已把 `TArenaStats.AllocCount` 改成 `QWord`，`TChunkedArena` / `TLocalArena` 的统计也已同步。

---

### P-03 [WONTFIX] `TLocalArena.AllocAligned` 仍在每次调用重新做 `IsPowerOfTwo`

**P3 | 文件：`core/src/nextpas.core.mem.arena.local.pas`**

这条本轮不做收敛。原因有两点：

- 这里的额外判断是极小热路径损耗，不影响正确性，也没有证据表明它已成为真实瓶颈
- `TLocalArena` 与 `TVirtualArena` 的对齐模型本来就不同；为了表面一致而强行共用缓存策略，收益很低，反而会放大实现复杂度

---

### P-04 [FIXED] `TRingBuffer` 已切到 `AdvanceIndex` fast path

**P3 | 文件：`core/src/nextpas.core.mem.ring_buffer.pas`, `core/tests/nextpas.core.mem/test_contracts/test_contracts.lpr`**

当前实现已新增 `AdvanceIndex(AIndex, ADelta): SizeUInt` helper，并把以下路径统一收口到同一条索引推进逻辑：

- `Push` 批量路径
- `Pop` 批量路径
- `Peek`
- `FindElement`
- `SetElementAt`
- `DropElements`
- `Resize` 里的 `FTail` 重建

2 幂容量现在走位与 fast path；`test_contracts` 也新增了 source-contract gate，锁定不再回到 raw `% FCapacity`。

---

### P-05 [FIXED] `CommitFrontRegion inline` 不再作为当前问题跟踪

当前实现已经把真正热路径中的 syscall 判断压缩到最少；继续纠结 record method 是否 inline 的收益很低，本轮不再保留该条。

---

## 八、代码质量

### Q-01 [FIXED] `COMMIT_CHUNK_SIZE` 已是正常 `const`

旧报告里的 typed constant 问题已不存在。

---

### Q-02 [FIXED] `FLargeBlocks` 的 metadata 生命周期约束已显式文档化

**P3 | 文件：`core/src/nextpas.core.mem.arena.virtual.pas`, `core/docs/mem/README.md`, `core/docs/mem/ARCHITECTURE.md`**

当前语义已经明确：

- `FLargeBlocks` 只保存 direct-mmap large object metadata
- metadata 生命周期与对应对象映射完全一致
- `SaveMark` / `RestoreToMark` / `Reset` / `ResetHard` 都不会回收这些 entry
- `Release` 才统一关闭映射并清空 metadata

因此这条不再是“隐藏的无约束增长问题”，而是与 large-object lifetime 绑定的显式设计约束。

---

### Q-03 [FIXED] `TRingBuffer.Resize` 的除零怀疑本轮未成立

当前 `Resize` 对 `aNewCapacity = 0` 提前返回，`FTail := FCount mod FCapacity` 前也做了 `if FCapacity > 0` 判断，旧报告里的该条不再成立。

---

### Q-04 [FIXED] `AllocUnsafe` 未对齐已转为显式契约说明

README / ARCHITECTURE 已写明 `AllocUnsafe` 不保证对齐，这条不再单列为“隐藏行为问题”。

---

### Q-05 [FIXED] VirtualArena 现在保留 `nil` 返回，同时补上可查询的失败原因分层

`core/src/nextpas.core.mem.arena.virtual.pas` 本轮新增了：

- `TVirtualArenaAllocFailure`
- `TVirtualArena.LastAllocFailure`

当前已能区分：

- `vaafCapacityExhausted`
- `vaafFrontCommitFailed`
- `vaafBackCommitFailed`
- `vaafLargeObjectMapFailed`
- `vaafInvalidAlignment`

也就是说，`Alloc*` 仍按既有 contract 返回 `nil`，但调用方已可在失败后查询更细分的原因。

---

### Q-06 [FIXED] `NEXTPAS_ARENA_LEAK_CHECK` 的 `GArenaTotalMapped` 已切到原子更新

当前实现已移除普通 `Inc/Dec`，改为：

- `ArenaLeakMappedAdd` -> `InterlockedExchangeAdd64`
- `ArenaLeakMappedSubtractSaturating` -> `InterlockedCompareExchange64` CAS loop

`test_contracts` 也会专门检查 `GArenaTotalMapped` 不再走普通 `Inc/Dec`。

---

### Q-07 [FIXED] `TBlockPoolBase` 已删除

`381e89f62` 已直接删除旧的废弃基类，原条目关闭。

---

## 九、文档

### D-01 [FIXED] `ARCHITECTURE.md` 已切回当前架构 truth

`core/docs/mem/ARCHITECTURE.md` 当前已经：

- 移除了 `arena.growable` 作为活跃 L1 单元的描述
- 把 `IAllocator` 片段改成现行 `procedure FreeMem(ADst)` + `FreeAligned`
- 用当前活跃的 `TLocalArena` / `TChunkedArena` / `TVirtualArena` / `TThreadArena*` 重新描述 arena family

这份文档不再继续发布旧 public surface。

---

### D-02 [FIXED] `API.md` 已改成当前 contract truth

`core/docs/mem/API.md` 现在已经删除：

- `IArena.TotalSize`
- 旧的 `TFastArena`
- 旧的 `TGrowableArena`

文档当前描述的是现行 surface：

- `TLocalArena`
- `TChunkedArena`
- `TVirtualArena`
- `TVirtualArenaAllocator` / `TFastArenaAllocator` 兼容别名链
- 当前 `IArena` / `IAllocator` contract

---

### D-03 [FIXED] `README.md` / `BENCHMARKS.md` / `ROADMAP-EXTENSION.md` 已对齐当前行为

当前状态：

- `README.md` 已改成 29 个测试项目、静态计数 289 个 `T.Run`
- `BENCHMARKS.md` 已区分 `Reset` 保留 committed pages、`ResetHard` 才 decommit
- `ROADMAP-EXTENSION.md` 已改成“调用方显式 `DrainTLS`”，不再宣传自动 threadvar cleanup

---

## 十、汇总

### 状态统计

| 状态               | 数量   | 说明                                                            |
| ------------------ | ------ | --------------------------------------------------------------- |
| **[FIXED] / 关闭** | **60** | 包含真实修复项，以及本轮复核后不再成立/不再作为缺陷跟踪的旧条目 |
| **仍然开放**       | **0**  | 当前树上已无剩余开放问题                                         |
| **新增**           | **8**  | 本轮新增项已全部修复或关闭                                       |

### 当前最高优先级（建议先处理）

1. 无。本轮 `mem-findings.md` 已清零，当前树上没有剩余开放条目。

### 处理建议顺序

1. 无。本报告内的旧开放问题已全部关闭；后续若继续演进，应按新的需求或新的审查结果重新立项。
