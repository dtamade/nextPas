# mem 模块全面审查报告

> 扫描时间：2026-06-23
> 上次审查：2026-06-21
> 分支：feat/arena-allocator
> 基线变更：`fdfd70a70`, `f93a7ca47`, `381e89f62`
> 当前范围：`core/src/nextpas.core.mem*.pas`（64 文件）+ `core/tests/nextpas.core.mem/*`（29 项目，静态计数 286 个 `T.Run`）+ `core/docs/mem/*`
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

### A-04 ⚠️ mimalloc 动态加载策略仍把 env/path 发现逻辑留在 mem 层

**P2 | 文件：`core/src/nextpas.core.mem.allocator.mimalloc.pas`**

复核后确认：
- `nextpas.core.path` **不是**死导入；当前确实用它提供 `ExtractFilePath` / 路径分隔符语义
- 但 `allocator.mimalloc` 仍直接依赖 `nextpas.core.os.env` + `nextpas.core.path` 实现以下策略：
  - 环境变量覆盖
  - 可执行文件相对 `lib/<platform>/` 搜索
  - 系统路径回退

这不是立即的行为 bug，但确实让“部署路径发现策略”留在 mem allocator 单元里，继续扩大了 mem 层的职责面。`f93a7ca47` 虽然清掉了 `SysUtils`，但没有进一步收紧这块 owner boundary。

**建议**：
- 若保留动态加载策略，至少在架构/部署文档里明确搜索顺序
- 若目标是收紧 owner boundary，可把路径/环境发现下沉到专门的 loader helper

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

### A-07 ⚠️ `TLocalBlockPool` 与 `TBlockPool` 仍存在表面重叠

**P3 | 文件：`core/src/nextpas.core.mem.pool.pas`, `core/src/nextpas.core.mem.blockpool.pas`**

两者仍然都提供固定块分配语义，但定位不同：
- `TLocalBlockPool`：class-only，本地简单池
- `TBlockPool`：`IBlockPool` / `IBlockPoolBatch` 接口面，带对齐/批量/范围查询

这已不算严重设计错误，但模块外观仍然重复，API 选择成本偏高。

**建议**：在模块文档里明确“何时选 local class，何时选 interface blockpool”。

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

### A-12 ⚠️ `memory_map` / `mapped_*` 仍处在 mem 与 io 之间的迁移带

**P3 | 文件：`core/src/nextpas.core.mem.memory_map.pas`, `core/src/nextpas.core.mem.mapped_slab_pool.pas`, `core/src/nextpas.core.mem.mapped_ring_buffer*.pas`**

这批单元的归属仍不纯：
- `mapped_ring_buffer*` 已经是 deprecated wrapper，目标是 `io.mapped.*`
- `memory_map` / `mapped_slab_pool` 仍保留在 mem 命名空间

**建议**：继续把 mapped-family 当成迁移面，不要再向 mem 侧扩张新 API。

---

### A-13 [FIXED] 旧报告中的 `SysUtils` 直接依赖已清理

`f93a7ca47` 已把旧报告点名的 `allocator.mimalloc` / `allocator.tracking` / `pool.fixed` 上的 `SysUtils` 依赖移除。

---

### A-14 ⚠️ `mutex` / `rwlock` 仍是很薄的包装层

**P3 | 文件：`core/src/nextpas.core.mem.mutex.pas`, `core/src/nextpas.core.mem.rwlock.pas`**

这两个单元仍基本只转发到 `platform.sync`。其中 `mutex` 有基础测试，但 `rwlock` 仍缺直接 focused gate；整体上它们仍增加了一层额外 public surface。

**建议**：文档明确这是 mem 层兼容包装，而不是新并发原语层。

---

### A-15 ⚠️ 文件命名仍混用下划线与点号风格

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

这是持续性的命名治理债。

---

### A-16 ⚠️ `mem.pool.adapter` 已经脱离当前接口，属于失活兼容层

**P1 | 文件：`core/src/nextpas.core.mem.pool.adapter.pas`**

当前源码存在三类硬失真：
- `uses nextpas.core.mem.layout`，但该单元当前树中不存在
- 仍以旧接口实现 `IArena.Alloc(const aLayout: TMemLayout): TAllocResult`
- 仍调用现行 `IArena` 不存在的 `TotalSize`

同时：
- 全仓库无当前消费者
- `core/tests/nextpas.core.mem/*` 无编译/行为覆盖

这不是“未使用也没关系”的兼容层，而是已经与当前接口面断裂的休眠代码。

**建议**：
- 要么补 compile gate 并修到当前接口
- 要么明确归档/删除，避免继续留在活跃源码树制造假表面

---

### A-17 ⚠️ 多个 public 兼容/实验单元处于“零消费 + 零验证”状态

**P2 | 文件组**：
- `nextpas.core.mem.aligned`
- `nextpas.core.mem.allocator.instrumentation`
- `nextpas.core.mem.allocator.numa`
- `nextpas.core.mem.manager.mimalloc`
- `nextpas.core.mem.stats`
- `nextpas.core.mem.adapters`
- `nextpas.core.mem.interfaces`
- `nextpas.core.mem.stack_scope_helpers`

这些单元要么全仓库零消费者，要么只有非常边缘的文档/兼容角色；当前也没有 focused test。它们共同抬高了表面积，但没有验证成本与之匹配。

**建议**：把它们拆成“保留兼容层”和“实验/待归档”两组，分别加 compile gate 或显式归档策略。

---

### A-18 ⚠️ `mem.arena.growable` 已经是不可编译的失活 public unit

**P1 | 文件：`core/src/nextpas.core.mem.arena.growable.pas`**

这不是普通的“零消费者旧代码”，而是当前源码树里一个可直接复现的坏表面：
- 全仓库没有 live consumer
- 单元仍声明 `TGrowingArena = class(TInterfacedObject, IArena)`，却没有 `uses nextpas.core.mem.arena.intf`
- 仍保留旧式 `TArenaMarker` / `TotalSize` 语义
- 直接编译探针 `uses nextpas.core.mem.arena.growable;` 当前失败：`Identifier not found "IArena"`

这意味着源码树里仍挂着一个 public unit，但当前既不被真实代码消费，也不被任何 focused gate 编译。

**建议**：
- 要么修回现行 `IArena` / `TArenaMark` 体系并补 compile gate
- 要么明确归档/删除，不要继续让文档和测试制造“它仍然可用”的错觉

---

## 二、API 设计

### B-01 ⚠️ Arena 错误契约仍没有在 canonical API 文档里说清

**P2 | 文件：`core/src/nextpas.core.mem.arena.intf.pas`, `core/docs/mem/API.md`**

当前用户需要自己推断两套行为：
- 构造/初始化失败：抛异常
- `Alloc*` 失败：返回 `nil`

源码里这套规则大致稳定，但 `core/docs/mem/API.md` 仍没把它作为总约定写清。

**建议**：在 API 文档或 `IArena` 顶部注释中集中说明“构造失败抛异常，分配失败返回 nil”。

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

### B-04 ⚠️ `Reset` / `ResetHard` / 各 Arena 语义差异仍未在 canonical API 文档同步

**P2 | 文件：`core/docs/mem/API.md`, `core/src/nextpas.core.mem.arena.intf.pas`**

当前真实行为：
- `IArena` 只有 `Reset`
- `TVirtualArena` 还有 `ResetHard`
- `TLocalArena` / `TChunkedArena` / `TVirtualArena` 的 reset 代价和资源语义并不相同

但 canonical API 文档仍停留在旧版类型/方法描述，外部读者很难从文档层看出差异。

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

### B-08 ⚠️ 参数命名风格仍混杂

**P3**

当前 public API 仍同时存在：
- `ASize` / `AAlign` / `AMark`
- `aSize` / `aAlignment` / `aDst`

属于纯风格债，不影响行为，但和 `core/docs/design-conventions.md` 的一致性要求还有距离。

---

### B-09 ⚠️ `IArena.AllocAligned` 在不同实现间的“小对齐值”语义不一致

**P2 | 文件**：
- `core/src/nextpas.core.mem.arena.local.pas`
- `core/src/nextpas.core.mem.arena.chunked.pas`
- `core/src/nextpas.core.mem.arena.virtual.pas`

当前三种实现对小对齐值的处理不同：
- `TLocalArena.AllocAligned`：接受任意 2 的幂，包括 `< SizeOf(Pointer)` 的值
- `TChunkedArena.AllocAligned`：`< MEM_DEFAULT_ALIGN` 直接返回 `nil`
- `TVirtualArena.AllocAligned`：把 `< SizeOf(Pointer)` 的值抬到 `SizeOf(Pointer)`

同一个 `IArena` 方法名，对齐契约却不一致，而且文档没有写清。

**建议**：统一成“全部拒绝”或“全部提升到最小对齐”之一，并把规则写进 `IArena` 文档。

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

### S-03 ⚠️ `TCallbackAllocator` 在 non-contract 构建下可接受 `nil` 回调，后续会直接跳空函数指针

**P1 | 文件：`core/src/nextpas.core.mem.allocator.callback.pas`**

当前构造函数只在 `NEXTPAS_CORE_CONTRACTS` 打开时抛 `EArgumentNil`。如果 contracts 关闭：
- `nil` 回调会被保存到字段
- 后续 `DoGetMem` / `DoAllocMem` / `DoReallocMem` / `DoFreeMem` 会直接调用这些 `nil` 函数指针

这会把输入校验缺失直接升级成运行时崩溃。

**测试现状**：
- `test_contracts` 覆盖了正常回调路径
- 没有覆盖 “`nil` 回调 + contracts off” 负路径

**建议**：无条件校验回调非 `nil`，不要把安全性绑定到 contracts 编译开关。

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

### R-04 ⚠️ `TMemMutex.Init/Done` 仍不是线程安全的一次性初始化

**P2 | 文件：`core/src/nextpas.core.mem.mutex.pas`**

`Init` / `Done` 只靠 `FInitialized` 布尔字段判断，没有 CAS/once 语义。两个线程同时初始化同一个 record 时，仍可能双初始化或 init/done 交叉。

当前测试只覆盖“未初始化直接 Acquire/Release 抛错”和普通高竞争使用，没有覆盖竞态初始化。

---

### R-05 ⚠️ `TMemRwLock.Init/Done` 复制了同样的竞态初始化模式

**P2 | 文件：`core/src/nextpas.core.mem.rwlock.pas`**

`TMemRwLock` 与 `TMemMutex` 一样：
- `FInitialized` 非原子
- 没有一次性初始化保护
- 没有相关测试

这是旧报告没有覆盖到的同类问题。

---

### R-06 ⚠️ `manager.mimalloc` 全局安装/卸载缺少锁保护

**P1 | 文件：`core/src/nextpas.core.mem.manager.mimalloc.pas`**

对比：
- `manager.crt`：有 `GManagerLock`
- `manager.rtl`：有 `GManagerLock`
- `manager.mimalloc`：直接读写 `GInstalled` / `GOldManager` / `GAlloc`，无锁

这意味着多线程并发调用安装/卸载时，可能发生全局 `TMemoryManager` 状态竞争。更糟的是，当前 `core/tests/nextpas.core.mem` 没有任何针对 `InstallMimallocMemoryManager` 的 focused gate。

---

## 五、内存安全

### M-01 ⚠️ 大对象与 `SaveMark/RestoreToMark` 的关系仍然容易误用

**P2 | 文件：`core/src/nextpas.core.mem.arena.virtual.pas`**

当前真实语义仍是：
- `SaveMark/RestoreToMark` 只回退 bump pointer
- 已分配的大对象 mmap 不会被回收

虽然 README/ARCHITECTURE 已经写出“大对象不受 mark/reset 影响”，但源码方法级注释和 API.md 仍没有把这个行为贴到 `SaveMark/RestoreToMark` 上，外部调用方仍然很容易把它当成真正的 rollback。

---

### M-02 ⚠️ `AllocNoPointer` 的下溢保护仍然不正确

**P1 | 文件：`core/src/nextpas.core.mem.arena.virtual.pas`**

当前保护代码是：
- `if PtrUInt(aSize) > PtrUInt(FBackPtr) then Exit;`

这比较的是“请求大小 vs 当前绝对地址”，而不是“请求大小 vs 当前 back 区剩余空间”。随后仍会执行：
- `LNewBack := PtrUInt(FBackPtr) - PtrUInt(aSize);`

正确的边界应当基于 `FBackPtr - FBackBase` 或与 `FFrontPtr` 的剩余距离来判断。当前写法不能证明这段减法在所有情况下都不会越过 reservation 边界。

---

### M-03 [FIXED] `thread cache` 泄漏路径已被硬禁用

当前 `TShardedBlockPool.Create` 在 `ThreadCacheCapacity > 0` 时直接抛错，并且 `test_sharded_pools` 专门验证了这个拒绝路径。

旧报告里的“代码仍可走到泄漏路径”不再成立。

---

### M-04 [FIXED] `TSlabPool.PageKeyOf` 不再访问 `FSegments[0]`

当前实现已改成固定 page shift 路径，不再依赖 `FSegments[0]`。

---

## 六、测试覆盖

### T-01 ⚠️ 当前缺的不是“总量”，而是几个 public/dormant surface 没有 focused gate

**P1 | 现状**

当前 mem 测试量并不小：
- 29 个测试项目
- 静态计数 286 个 `T.Run`

但仍有几块 public surface 没有 focused 保护：
- `manager.mimalloc`：无安装/卸载测试
- `pool.adapter`：无 compile gate，且当前已与现行接口脱节
- `arena.growable`：无 compile gate，且当前单元已不能独立编译
- `allocator.callback`：无 `nil` 回调负路径测试
- `allocator.crt` / `allocator.foundation`：只有间接覆盖，没有直接 surface gate

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

### T-04 ⚠️ OOM 负路径仍缺少 VirtualArena 的 reserve/commit/mmap 失败注入

**P2 | 文件：`core/tests/nextpas.core.mem/test_oom/test_oom.lpr`**

当前 OOM 套件已覆盖：
- `TLocalArena`
- `TChunkedArena`
- fixed/growable pool
- `ring_buffer`
- `stack_pool`

但仍没覆盖：
- `TVirtualArena_Init` 的 `platform_virtual_reserve` 失败
- `CommitFrontRegion/CommitBackRegion` 失败
- 大对象 `platform_mmap_create_anonymous` 失败

这意味着 VirtualArena 最危险的宿主内存失败路径仍靠人工阅读证明。

---

### T-05 ⚠️ `test_arena_growable` 并没有覆盖 `mem.arena.growable`

**P1 | 文件：`core/tests/nextpas.core.mem/test_arena_growable/*`, `core/src/nextpas.core.mem.arena.growable.pas`**

当前 `test_arena_growable` 套件名会误导读者：
- 测试程序实际 `uses nextpas.core.mem.arena.chunked`
- 所有 case 都在实例化 `TChunkedArena`
- 没有任何一行引用 `nextpas.core.mem.arena.growable` / `TGrowingArena`

结果是：
- public unit `mem.arena.growable` 已经编译失败
- 测试名却仍然暗示“growable arena 已被覆盖”

**建议**：
- 要么把该套件重命名为 `test_arena_chunked`
- 要么补一个真正编译/行为覆盖 `mem.arena.growable` 的 gate

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

### P-03 ⚠️ `TLocalArena.AllocAligned` 仍在每次调用重新做 `IsPowerOfTwo`

**P3 | 文件：`core/src/nextpas.core.mem.arena.local.pas`**

这是很小的热路径损耗，不影响正确性，但和 `TVirtualArena` 的 cached alignment 策略相比仍不一致。

---

### P-04 ⚠️ `TRingBuffer` 的批量路径仍大量使用 `% FCapacity`

**P3 | 文件：`core/src/nextpas.core.mem.ring_buffer.pas`**

当前 `Push/Pop/Peek/Find/SetElementAt/DropElements` 的多元素路径仍直接用 `mod FCapacity`，没有复用 `GetNextIndex` + 2 幂容量快速路径。

这是纯性能债，不是正确性问题。

---

### P-05 [FIXED] `CommitFrontRegion inline` 不再作为当前问题跟踪

当前实现已经把真正热路径中的 syscall 判断压缩到最少；继续纠结 record method 是否 inline 的收益很低，本轮不再保留该条。

---

## 八、代码质量

### Q-01 [FIXED] `COMMIT_CHUNK_SIZE` 已是正常 `const`

旧报告里的 typed constant 问题已不存在。

---

### Q-02 ⚠️ `FLargeBlocks` 仍然是无上限增长数组

**P3 | 文件：`core/src/nextpas.core.mem.arena.virtual.pas`**

大对象跟踪仍按 2x 动态数组扩容，没有回收策略或上限。对于极端“大量独立大对象 + 长生命周期 arena”场景，metadata 会持续增长。

---

### Q-03 [FIXED] `TRingBuffer.Resize` 的除零怀疑本轮未成立

当前 `Resize` 对 `aNewCapacity = 0` 提前返回，`FTail := FCount mod FCapacity` 前也做了 `if FCapacity > 0` 判断，旧报告里的该条不再成立。

---

### Q-04 [FIXED] `AllocUnsafe` 未对齐已转为显式契约说明

README / ARCHITECTURE 已写明 `AllocUnsafe` 不保证对齐，这条不再单列为“隐藏行为问题”。

---

### Q-05 ⚠️ VirtualArena 大对象 / commit 失败仍只有 `nil`，没有原因分层

**P2 | 文件：`core/src/nextpas.core.mem.arena.virtual.pas`**

当前这些失败路径都只能返回 `nil`：
- 大对象 mmap 失败
- front/back commit 失败

调用方无法区分：
- 容量不足
- 宿主 syscall 失败
- 地址空间/commit 失败

对于调试和日志定位都不友好。

---

### Q-06 ⚠️ `NEXTPAS_ARENA_LEAK_CHECK` 统计量仍是半原子状态

**P3 | 文件：`core/src/nextpas.core.mem.arena.virtual.pas`**

当前：
- `GArenaInstanceCount` 用 `InterLockedIncrement/Decrement`
- `GArenaTotalMapped` 仍有普通 `Inc/Dec`

这只影响 debug leak-check 统计，不影响生产分配语义，但读数并非严格线程安全。

---

### Q-07 [FIXED] `TBlockPoolBase` 已删除

`381e89f62` 已直接删除旧的废弃基类，原条目关闭。

---

## 九、文档

### D-01 ⚠️ `ARCHITECTURE.md` 虽然明显改善，但仍存在关键失真

**P1 | 文件：`core/docs/mem/ARCHITECTURE.md`**

这份文档已经比上次好很多，确实补上了：
- `arena.concurrent`
- `AllocUnsafe`
- 大对象生命周期
- “高级子模块需直接 uses”的门面策略

但它仍有会误导读者的关键旧事实：
- 仍把 `nextpas.core.mem.arena.growable` 描述为活跃 L1 单元；而该 unit 当前直接编译探针就报 `Identifier not found "IArena"`
- `IAllocator` 代码片段仍写旧签名 `FreeMem(aPtr): SizeUInt`，与现行 `procedure FreeMem(aDst)` / `FreeAligned` 能力不一致

所以它已经不再是“最滞后”的文档，但也还不能算已同步完成。

---

### D-02 ⚠️ `API.md` 仍然是当前最失真的 mem 文档

**P1 | 文件：`core/docs/mem/API.md`**

当前仍在写不存在或已变形的接口面：
- `IArena.TotalSize`
- `TFastArena`
- `TGrowableArena`
- `TFastArenaAllocator` 包装旧 `TFastArena`

而真实代码已经是：
- `TVirtualArena`
- `TChunkedArena`
- 现行 `IArena` 不含 `TotalSize`

这是当前 mem 文档里最需要优先修的文件。

---

### D-03 ⚠️ `README.md` / `BENCHMARKS.md` / `ROADMAP-EXTENSION.md` 与当前代码不同步

**P1 | 文件组**：
- `core/docs/mem/README.md`
- `core/docs/mem/BENCHMARKS.md`
- `core/docs/mem/ROADMAP-EXTENSION.md`

已确认的漂移点：
- `README.md` 仍写 `324+ tests across 24+ suites`，而当前树是 29 个测试项目、静态计数 286 个 `T.Run`
- `BENCHMARKS.md` 仍写 `Reset: madvise(MADV_DONTNEED) 归还物理页`，但实际代码是 `Reset` 保留 committed pages，`ResetHard` 才 decommit
- `ROADMAP-EXTENSION.md` 写“线程退出自动回收 / 自动 DrainTLS: 支持 FPC threadvar cleanup hook”，而当前 `arena.thread` 仍要求调用方显式 `DrainTLS`

这些不是措辞问题，而是会误导使用者的行为级失真。

---

## 十、汇总

### 状态统计

| 状态 | 数量 | 说明 |
|------|------|------|
| **[FIXED] / 关闭** | **31** | 包含真实修复项，以及本轮复核后不再成立/不再作为缺陷跟踪的旧条目 |
| **仍然开放** | **29** | 当前树上仍能被代码、测试或文档直接证明的问题 |
| **新增** | **8** | 本轮新增：`A-16`、`A-17`、`A-18`、`B-09`、`S-03`、`R-05`、`R-06`、`T-05` |

### 当前最高优先级（建议先处理）

1. **A-18 / P1**：`mem.arena.growable` 是当前源码树里可复现的不可编译 public unit
2. **A-16 / P1**：`mem.pool.adapter` 已与当前接口脱节，且无任何 compile gate
3. **S-03 / P1**：`allocator.callback` 在 non-contract 构建下允许 `nil` 回调并会直接跳空函数指针
4. **R-06 / P1**：`manager.mimalloc` 缺少安装锁，直接并发改全局 `TMemoryManager`
5. **M-02 / P1**：`TVirtualArena.AllocNoPointer` 的下溢保护条件不正确
6. **D-01 / D-02 / D-03 / T-05 / P1**：架构/API/测试名仍在制造过时或错误的 public surface 认知

### 处理建议顺序

1. 先处理 **已经失活且会误导外部读者的源码树单元**：`mem.arena.growable`、`mem.pool.adapter`
2. 再处理 **会导致运行时崩溃或全局状态竞争的 public surface**：`allocator.callback`、`manager.mimalloc`
3. 然后处理 **VirtualArena 的真实边界问题**：`AllocNoPointer`、大对象 mark/restore 契约、失败原因表达
4. 同步修 **canonical 文档与测试名**：先 `ARCHITECTURE.md` / `API.md`，再 `README/BENCHMARKS/ROADMAP`，最后处理 `test_arena_growable` 命名或真实覆盖
5. 最后收拾 **低优先级外观债**：命名、薄包装、重复表面、热路径小优化
