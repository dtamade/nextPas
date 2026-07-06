# mem-findings: 代码质量 + 架构 + 可维护性

## 统计
- 总发现: 26
- major: 8, minor: 10, suggestion: 6, P2 fixed: 2

---

### [QA-001] pool.fixed.pas 和 allocator.mimalloc.pas 直接引用 FPC SysUtils
- **严重度**: major
- **维度**: architecture
- **文件**: `nextpas.core.mem.pool.fixed.pas:198`, `nextpas.core.mem.allocator.mimalloc.pas:41`
- **描述**: `pool.fixed.pas` 在 `{$IFDEF FAF_MEM_DEBUG}` 下 uses SysUtils；`allocator.mimalloc.pas` 在 implementation 中无条件 uses SysUtils。违反"除 nextpas.core.system 外不得引用 FPC RTL"的架构规则。
- **影响**: 破坏 musl 兼容性和 sysroot 编译路径。`allocator.mimalloc.pas` 是无条件引用，即使非 DEBUG 也会拉入 SysUtils。
- **建议**: 替换为 `nextpas.core.text.conv`（IntToStr 等）或 `nextpas.core.log.intf`（日志输出）。

### [QA-002] 几乎所有 25 个测试项目直接引用 FPC SysUtils/Classes
- **严重度**: major
- **维度**: architecture
- **文件**: `core/tests/nextpas.core.mem/test_*/test_*.lpr`
- **描述**: 19 个测试文件 import SysUtils，3 个 import Classes。应使用 nextpas.core 框架等价物（nextpas.core.test, nextpas.core.text.conv 等）。bench 模块审查时已修复同类问题。
- **影响**: 测试无法在 sysroot/musl 环境下编译。如果框架在 musl 上运行，这些测试全部失败。
- **建议**: 批量替换 SysUtils → nextpas.core.text.conv（Format/IntToStr），Classes → 按需替换。

### [QA-003] AlignUp 函数重复实现 — ⚠️ 低优先级质量债务
- **严重度**: minor (降级)
- **维度**: quality
- **文件**: `mem.base.pas:56`（canonical）, `mem.allocator.base.pas:50`（私有 AlignUpPtr）, `mem.pool.slab.pas:250`（私有 AlignUpPtrLocal）
- **描述**: `AlignUp(SizeUInt)` 的 canonical 实现在 `mem.base.pas`。`allocator.mmap.pas` 的本地副本已移除。剩余的是两个私有 pointer helper 的局部重复实现。
- **影响**: 维护成本低（都是私有函数，不暴露公共 API）。
- **状态**: 低优先级，不建议单独开一轮重构。

### [QA-004] IAllocator 接口以 alias/re-export 形式分散 — ⚠️ 历史兼容残留
- **严重度**: minor (降级)
- **维度**: architecture
- **文件**: `mem.intf.pas:24`（canonical）, `mem.allocator.pas:37`（必要 facade）, `mem.interfaces.pas:14`（compat alias）
- **描述**: `IAllocator` 的 canonical 定义在 `mem.intf.pas`。`mem.allocator.pas` 是必要门面，便于外部直接拿 allocator 家族。`mem.interfaces.pas` 是历史兼容残留，注释与实际 alias 不一致。
- **影响**: 不应强行全面收敛，只需未来清理 `mem.interfaces` 的 compat alias 或至少补 deprecated/文档说明。
- **状态**: 历史兼容残留，无需立即处理。

### [QA-005] IPool/IArena 接口层级分散 — ⚠️ 低优先级质量债务
- **严重度**: minor (降级)
- **维度**: architecture
- **文件**: 多文件
- **描述**: 当前活跃链路是 `IPool` → `IMemoryPool` → `IFixedSlabPool`；另有 `IBlockPool/IArena` 在 blockpool.pas。旧的 `IMemPool/IStackPool/ISlabPool` 只留在 compat 单元里，仓库内未看到活跃消费者。
- **影响**: 根因是 v1/v2 兼容层并存，不是当前设计失控。
- **状态**: 低优先级，优先做文档澄清和弃用计划，不建议现在做大规模接口重排。

### [QA-006] mem.utils.pas 1313 行 / 71 个导出函数 — deferred
- **严重度**: major → deferred
- **维度**: maintainability
- **文件**: `nextpas.core.mem.utils.pas` (1379 行)
- **描述**: 此文件包含内存操作工具（Copy/Fill/Zero/Compare/AlignUp）、IsOverlap、IsPowerOfTwo、memcpy/memmove FFI 声明、以及大量 8/16/32 位宽度的变体。
- **影响**: 同一工具域内聚性仍在，拆分引入跨文件依赖开销。
- **状态**: deferred — 风险/收益不匹配。后续按 seam 拆分时顺带处理。

### [QA-007] pool.fixed.pas — ❌ 非真实问题
- **严重度**: 删除 (降级)
- **维度**: maintainability
- **文件**: `nextpas.core.mem.pool.fixed.pas`
- **描述**: 现状是 597 行，只包含 `TFixedPool` 和 `TFixedPoolConcurrent` 两个核心类，低于 800 行软阈值。原描述"5 个类"不符合当前代码。
- **状态**: 非真实问题，无需单独拆分。

### [QA-008] utils.pas 中 Copy/Zero/Compare 与 FPC System 单元同名 — deferred
- **严重度**: major → deferred
- **维度**: quality
- **文件**: `nextpas.core.mem.utils.pas`
- **描述**: `Copy`, `Zero`, `Compare`, `Fill` 都是 FPC System 单元中已有函数的同名或近似名。
- **影响**: facade uses 限制了影响面（零个 mem 子单元在 interface 段 import utils）。
- **状态**: deferred — API 改名代价大，当前影响面极小。

### [QA-009] mem.mem_pool.pas 是 28 行的兼容 shim
- **严重度**: minor
- **维度**: maintainability
- **文件**: `nextpas.core.mem.mem_pool.pas`
- **描述**: 此文件仅 re-export `nextpas.core.mem.pool.fixed` 的内容。没有 deprecated 标记。
- **影响**: 增加编译时间和模块图复杂度。下游如果 import 此文件，依赖链不透明。
- **建议**: 添加 deprecated 标记（类似 `mem.aligned.pas` 的做法）。

### [QA-010] mem.pool.memory_pool.pas 仅 28 行，只定义 IMemoryPool 接口
- **严重度**: minor
- **维度**: architecture
- **文件**: `nextpas.core.mem.pool.memory_pool.pas`
- **描述**: 此文件只定义了 `IMemoryPool = interface(IPool)` 加两个方法声明。28 行。
- **影响**: 接口定义碎片化。IPool 在 pool.base.pas，IMemoryPool 在 pool.memory_pool.pas，IFixedSlabPool 在 pool.fixed_slab.pas。
- **建议**: 考虑合并到 pool.base.pas 或创建统一的 pool.interfaces.pas。

### [QA-011] adapters.pas 桥接 v1 和 v2 接口 — 过渡期代码
- **严重度**: minor
- **维度**: architecture
- **文件**: `nextpas.core.mem.pool.adapter.pas` (426 行)
- **描述**: 文件头注释说明"Adapter classes to bridge v1.x pool interfaces (IMemPool, IStackPool) with v2.0 pool interfaces (IBlockPool, IArena)"。这是过渡代码，包含 4 个适配器类。
- **影响**: 如果 v1 接口已废弃，这些适配器最终需要移除。但没有 deprecated 标记或移除时间表。
- **建议**: 在文件头添加 v1 接口的废弃时间表，或标记为 deprecated（如果 v1 接口已不再被下游使用）。

### [QA-012] TFixedPoolGrowable 和 TGrowingFixedPool 命名不一致
- **严重度**: minor
- **维度**: quality
- **文件**: `pool.fixed.pas` (TFixedPoolGrowable) vs `pool.fixed.growable.pas` (TGrowingFixedPool)
- **描述**: 两个"可增长固定池"类名不一致：`TFixedPoolGrowable` 在 `pool.fixed.pas`，`TGrowingFixedPool` 在 `pool.fixed.growable.pas`。前缀 TFixed vs TGrowing，后缀 Growable vs FixedPool。
- **影响**: 使用者不清楚两者关系和区别。
- **建议**: 统一命名约定，或在文档中说明关系。

### [QA-013] stack_pool.pas 包含 6 个类 + 6 个 deprecated 别名
- **严重度**: minor
- **维度**: maintainability
- **文件**: `nextpas.core.mem.stack_pool.pas` (944 行)
- **描述**: 定义了 TStackPool, TStackPoolPolicy, TScopedStackPool, TStackPoolScope, TAutoStackPoolScope, TStackPoolScopeManager，加上 4 个 deprecated 别名和 3 个 deprecated 函数。
- **影响**: 文件过长，deprecated 代码占 10+ 行。
- **建议**: deprecated 别名可以在下一个大版本移除。

### [QA-014] ring_buffer.pas 726 行 — 独立数据结构放在 mem 模块中
- **严重度**: minor
- **维度**: architecture
- **文件**: `nextpas.core.mem.ring_buffer.pas`
- **描述**: Ring buffer 是通用数据结构，放在 mem 模块中不太合适。类似地 `mapped_ring_buffer` 已经迁移到 `nextpas.core.io.mapped.ring_buffer`，但非映射版本仍在 mem 中。
- **影响**: 如果其他模块需要 ring buffer，必须依赖 mem 模块。
- **建议**: 考虑迁移到 `nextpas.core.collections.ring_buffer` 或保持现状但添加文档说明为什么它在 mem 中。

### [QA-015] blockpool.sharded.pas 1395 行 — deferred
- **严重度**: minor → deferred
- **维度**: maintainability
- **文件**: `nextpas.core.mem.blockpool.sharded.pas` (1395 行)
- **描述**: 包含 TShardedBlockPool + 路由表 + PageMap + remote free + thread cache。
- **影响**: 认知负荷高，但拆分需要暴露内部数据结构为跨文件接口。
- **状态**: deferred — 高复杂度拆分风险高，CS-008 backoff 修复后不再有正确性问题。

### [QA-016] pool.fixed_slab.pas 1687 行 — 最大文件
- **严重度**: minor
- **维度**: maintainability
- **文件**: `nextpas.core.mem.pool.fixed_slab.pas`
- **描述**: 实现了 nginx 风格的 slab 分配器。1687 行，包含 ngx_slab 算法、IFixedSlabPool 接口、TFixedSlabPool 类。
- **影响**: 单个文件过大，难以审查和维护。
- **建议**: 将 slab 算法核心（page/slot 管理）提取为内部实现单元，只在 fixed_slab.pas 中暴露公共 API。

### [QA-017] nextpas.core.math 在 mem L0 模块中的使用
- **严重度**: minor
- **维度**: architecture
- **文件**: `arena.growable.pas:16`, `blockpool.growable.pas:16`, `pool.fixed.growable.pas:14`, `stack_pool.pas:351`
- **描述**: 4 个 mem 源文件 import `nextpas.core.math`。虽然 math 模块标记为 L0 兼容（注释"✅ Math facade (for trunc)"），但 mem 作为 L0 层依赖 math 层是否合适需要确认。
- **影响**: 如果 math 模块将来引入 L1+ 依赖，这些文件会意外升级。
- **建议**: 确认 math 模块确实是 L0，或考虑用 FPC 内置 `trunc` 替代 math facade。

### [QA-018] error.pas 异常层级 — ✅ 已复核关闭
- **严重度**: suggestion → 已关闭
- **维度**: architecture
- **文件**: `nextpas.core.mem.error.pas`
- **描述**: 原 finding 文本已过时。现状是 `TAllocError` + `EAllocError / EOutOfMemory / EInvalidLayout / EInvalidPointer / EDoubleFree`，与 TAllocError 错误码表配套。
- **状态**: 当前粒度合理，暂不建议单独收敛；后续若做错误语义统一，再整体评估。

### [QA-019] mimalloc.pas 门面层 — ✅ 已失效
- **严重度**: suggestion → 已关闭
- **维度**: quality
- **文件**: `nextpas.core.mem.mimalloc.pas`
- **描述**: 原描述"只暴露 3 个函数的薄门面"已失真。真正的 owner/loader 逻辑在 `allocator.mimalloc.pas`。
- **状态**: 已失效，无需处理。

### [QA-020] mem.pas re-export 列表 — ✅ 已复核关闭
- **严重度**: suggestion → 已关闭
- **维度**: architecture
- **文件**: `nextpas.core.mem.pas`
- **描述**: `core/docs/mem/README.md` 已明确 Stable Surface，且与 `nextpas.core.mem.pas` 当前 re-export 基本对齐。
- **状态**: 无需代码改动。

### [QA-021] mem.base.pas 中 NextPowerOfTwo 的 inline 标记 — ✅ 已修复
- **严重度**: suggestion → 已关闭
- **维度**: quality
- **文件**: `nextpas.core.mem.base.pas:33`
- **描述**: `NextPowerOfTwo` 的前向声明已移除 `inline` 标记，消除编译器警告。
- **状态**: 已修复。

### [QA-022] 薄文件/compat alias — ✅ 已添加 deprecated 标记
- **严重度**: suggestion → 已处理
- **维度**: maintainability
- **文件**: `mem.mem_pool.pas`, `mem.interfaces.pas`
- **描述**: `mem.mem_pool.pas` 所有类型别名已添加 deprecated 标记。`mem.interfaces.pas` 的 IAllocator 别名和 v1 接口（IMemPool/IStackPool/ISlabPool）已添加 deprecated 标记。
- **状态**: 已处理。mem.default.pas 保留为有意 seam。

### [QA-023] IObjectPool 泛型约束 — ✅ 已修复
- **严重度**: suggestion → 已关闭
- **维度**: quality
- **文件**: `nextpas.core.mem.pool.object_pool.pas`
- **描述**: `IObjectPool<T>` 已声明为 `generic IObjectPool<T: TObject>`，与 `TObjectPool<T: TObject>` 约束一致。
- **状态**: 已修复，本项关闭。

### [QA-025] TVirtualArenaAllocator.Traits.ZeroInitialized 与实现矛盾 — ✅ 已修复
- **严重度**: P2 → 已关闭
- **维度**: interface consistency
- **文件**: `nextpas.core.mem.allocator.arena.pas:95-101`
- **描述**: `DoAllocMem` 调用 `FArena.AllocZeroed`（确实零填充），但 `Traits` 报告 `ZeroInitialized=False`。消费者看到 False 后可能双重清零。
- **状态**: 已修复为 `True`。六维审查第三轮发现。

### [QA-024] FPC PPU 缓存风险
- **严重度**: suggestion
- **维度**: infrastructure
- **描述**: 测试 Makefile 使用 `$(FPC) ... -FU$(BUILD_DIR)` 但没有 `-vn` 或 PPU 新鲜度检查。如果源文件修改但 PPU 时间戳更新不及时，可能使用过时的 PPU。
- **影响**: 开发者修改源码后测试可能不反映最新改动。
- **建议**: 在 Makefile 中添加 PPU 清理或 freshness 检查（类似 bench 审查中的 stale PPU 发现）。

### [QA-025] 6 个 mem 源文件直接使用 FPC System.TRTLCriticalSection — ✅ 已修复
- **严重度**: major
- **维度**: architecture
- **文件**: `allocator.rtl.pas`, `allocator.crt.pas`, `arena.thread.pas`, `allocator.tracking.pas`, `allocator.mmap.pas`, `allocator.mimalloc.pas`
- **描述**: 6 个文件使用 FPC `System` 单元的 `TRTLCriticalSection`/`InitCriticalSection`/`DoneCriticalSection`/`EnterCriticalSection`/`LeaveCriticalSection`。这些是隐式 `System` 单元类型，不出现在 `uses` 子句中，L0 边界脚本无法检测。
- **修复策略**:
  - 实例字段 (`tracking.pas`, `mmap.pas`, `arena.thread.pas`) → `TMemMutex`（来自 `nextpas.core.mem.mutex`，封装 `TPlatformMutex`）
  - 全局单例锁 (`rtl.pas`, `crt.pas`, `mimalloc.pas`) → `TPlatformMutex`（来自 `nextpas.core.platform.sync`，零初始化等效 `pthread_mutex_t` 默认值）
  - 选择 `TPlatformMutex` 而非 `TMemMutex` 的原因：`TMemMutex` 需要显式 `Init`，但全局变量的 `initialization` 段可能在其他单元之后执行，导致时序问题
- **影响**: 消除所有 FPC System 隐式依赖（除编译器内建函数外）
- **附加修复**: L0 边界脚本增加 Phase 2 标识符扫描（`TRTLCriticalSection` 等 5 个标识符），防止回归
- **状态**: ✅ 已修复，6 文件 + L0 脚本增强
