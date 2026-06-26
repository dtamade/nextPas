# mem 模块自举+测试补全规划 v2

> 目标：打造 FreePascal 领域最优秀的内存管理框架
> 分支：codex/mem
> 日期：2026-06-25
> 基于 Codex R1 审查修正（session: 019f0267-b482-7ef0-86eb-8d85e461ead4）

## 一、总体目标

1. **自举就绪**：nextPas 编译器能编译 nextpas.core.mem 全部源码
2. **测试硬化**：回归测试覆盖所有已修复 bug + 关键路径 100% 覆盖
3. **基准复核**：性能数据准确、可复现、符合 design-conventions 规范

## 二、线路 A：自举就绪

### A0: 前置条件检查

**目标**：确认 C6-A（freestanding allocator）状态

**步骤**：
1. 检查 `compiler/docs/compiler-goal-tree.md` 中 C6-A 节点状态
2. 如果 C6-A 未完成，记录为阻塞条件并评估是否可部分推进
3. 产出前置条件报告

**验收**：明确 C6-A 依赖关系，决定是否继续或等待

### A1: ✅ 自举可行性探查（已完成 - 2026-06-26）

**Codex 审查结论**：

| 单元 | 编译状态 | 备注 |
|------|---------|------|
| `nextpas.core.mem.base` | ✅ success | 纯类型定义，无外部依赖 |
| `nextpas.core.mem.intf` | ✅ success | 接口定义，依赖 base |
| `nextpas.core.mem.error` | ❌ **失败** | 第一个失败单元 |
| `nextpas.core.mem` (门面) | ❌ 失败 | 被 error 阻塞 |

**真实阻塞：SysUtils stub 循环依赖**
```
nextpas.core.exception.pas → uses SysUtils → units/linux-x86_64/SysUtils.pas → uses nextpas.core.exception
```
- `core/src/nextpas.core.exception.pas:10` 继承 `SysUtils.Exception`
- `units/linux-x86_64/SysUtils.pas:7` re-export `nextpas.core.exception.Exception`
- `mem.error` 依赖 `nextpas.core.exception`，进入循环

**语法特性验证**（全部通过 nextPas `query symbols` probe）：
- ✅ default params（arena.chunked.pas:67）
- ✅ overloaded constructors（arena.chunked.pas:67）
- ✅ threadvar（arena.thread.pas:140）
- ✅ packed record（allocator.mmap.pas:54）
- ✅ cdecl external（allocator.mimalloc.pas:48）
- ✅ generic + reference to（pool.object_pool.pas:26）
- ✅ on E:（编译器已支持，mem 源码未使用）

### A2: Host/Runtime Surface Closure

**目标**：确保 `units/linux-x86_64/` 下有 mem 依赖的所有 FPC stub

**步骤**：
1. 分析 mem 源码的 uses 依赖树（含子模块）
2. 识别缺少 stub 的 FPC 单元
3. 创建最小 stub（仅提供名称桥接，不含实现）
4. 验证 FPC + nextPas 双编译通过

**验收**：FPC 编译无 missing unit 错误

### A3: 自举编译修复

**目标**：逐一修复 A1 发现的编译问题

**优先级**（按 blocker 类别）：
1. platform/runtime 依赖（A2 处理）
2. external/ABI 绑定（可能需要编译器修复）
3. packed layout（可能需要编译器修复）
4. TLS/threadvar（依赖 C6-A）
5. generic + reference-to（可能需要编译器修复）
6. interface/refcount（可能需要编译器修复）

**验收**：每个修复有对应的编译测试

### A4: Representative Consumer Matrix 验证

**目标**：不仅编译门面，而是编译代表性使用场景

**步骤**：
1. 识别 mem 的典型消费者模式：
   - 纯 Arena 使用（TLocalArena + Alloc/Reset）
   - Pool + Allocator 链（TSlabPool + PoolAllocator + FallbackAllocator）
   - 并发场景（TArenaConcurrent + TThreadArenaManager）
   - 大对象分配（TVirtualArena + AllocLargeObject）
2. 为每个消费者模式编写最小 nextPas 编译测试
3. 验证 FPC + nextPas 双编译通过

**验收**：4 个消费者模式全部编译通过

## 三、线路 B：回归硬化

### B1: 已修复 bug 回归测试

**目标**：为六轮修复的 83 个 findings 补充回归测试

| 测试名 | 覆盖的 Finding | 文件 |
|--------|---------------|------|
| `TestObjectPoolMaxSizeBoundary` | R-15: Dec(FTotalCreated) 正确性 | test_object_pool |
| `TestAcquireUncheckedStats` | R-14: FTotalAllocs 正确递增 | test_blockpool |
| `TestFallbackReallocZeroSize` | R-21: ASize=0 早返回 + entry 清理 | test_fallback_allocator |
| `TestFallbackReallocFailureReturnsNil` | R-21: 失败返回 nil 而非原指针 | test_fallback_allocator |
| `TestObjectPoolDoubleReleaseDetection` | R-22: 双重释放抛 EDoubleFree | test_object_pool |

### B0: Codex 发现的门面测试缺口

| 测试名 | 覆盖点 | 文件 |
|--------|--------|------|
| `TestFacadeAllocZeroed` | 门面 `AllocZeroed` helper | test_mem |
| `TestFacadeAllocArray` | 门面 `AllocArray` helper | test_mem |
| `TestMakeFixedSlabPoolOverloads` | `MakeFixedSlabPool` 3 个重载 | test_slab_pool |
| `TestIBlockPoolInterfaceConsumer` | `IBlockPool` interface-typed 使用 | test_blockpool |

### B2: AllocAligned 路径测试

| 测试名 | 覆盖点 | 文件 |
|--------|--------|------|
| `TestFixedSlabAlignedDirectPath` | AAlignment <= 8 时不走 fallback | test_slab_pool |
| `TestSlabAlignedDirectPath` | TSlabPool 小对齐直接路径 | test_slab_pool |
| `TestArenaResetThenAllocAligned` | Reset 后 AllocAligned 正确对齐 | test_arena |
| `TestChunkedArenaMarkAcrossSegmentsAllocAligned` | 跨段 mark/restore 后 AllocAligned | test_arena_chunked |

### B3: 错误路径测试

| 测试名 | 覆盖点 | 文件 |
|--------|--------|------|
| `TestSlabPoolOomWhenBackingFails` | TSlabPool 底层 allocator 失败时返回 nil | test_slab_pool |
| `TestFixedSlabPoolZeroCapacity` | Create(0) 后操作安全 | test_slab_pool |
| `TestSizeClassPoolDoubleFree` | TSizeClassPool 双重释放行为 | test_sizeclass_pool |

### B4: 并发场景测试

| 测试名 | 覆盖点 | 文件 |
|--------|--------|------|
| `TestShardedBlockPoolStatsAggregated` | 竞争后统计聚合正确 | test_sharded_pools |
| `TestShardedSlabAllocAlignedContention` | AllocAligned 并发安全 | test_sharded_pools |
| `TestArenaConcurrentMultipleMarkRestore` | 多次 mark/restore 循环 | test_concurrent_wrappers |

## 四、线路 C：设计改进（P3）

### C1: TTrackingAllocator double-free 检测

**方案**：`RemoveRecord` 未匹配时抛 `EAllocError(aeDoubleFree)`

### C2: Traits.ZeroInitialized 语义文档化

**方案**：在 `IAllocator` 接口文档中明确 `ZeroInitialized` 仅对 `AllocMem` 有效

### C3: TFallbackAllocator Traits 合并

**方案**：`Traits` 返回合并后的结果，任一支持对齐则 `SupportsAligned := True`

## 五、线路 D：基准复核

### D1: 测试框架迁移

**目标**：所有测试迁移到 `nextpas.core.test`（当前部分仍用 deprecated `nextpas.core.testing`）

**步骤**：
1. 识别仍使用 `nextpas.core.testing` 的测试项目
2. 逐个迁移到 `nextpas.core.test`
3. 验证迁移后测试行为不变

### D2: 基准框架规范化

**目标**：所有基准测试使用 `nextpas.core.bench`（当前有手写计时）

**步骤**：
1. 识别仍使用手写计时的基准项目
2. 迁移到 `nextpas.core.bench`
3. 重新运行基准，产出准确数据

### D3: README 数据同步

**目标**：`core/docs/mem/README.md` 中的测试/基准数据与实际一致

**步骤**：
1. 统计实际 T.Run cases 数量
2. 更新 README 中的数据
3. 同步 benchmarks 数据

## 六、执行顺序（依赖图）

```
A1 ✅ (已完成) ──→ A2 (修复 SysUtils 循环) ──→ A3 (全模块验证) ──→ A4 (消费者验证)
                    ↓
                    B0 (门面测试缺口) ←── 可与 A2 并行
                    ↓
                    B1 (回归测试) ←── 可与 A2 并行
                    ↓
                    B2 (AllocAligned) ←── A3 完成后
                    ↓
                    B3 (错误路径) ←── A3 完成后
                    ↓
                    B4 (并发) ←── A4 完成后
                    ↓
                    C1-C3 (设计改进) ←── B0-B4 完成后
                    ↓
                    D1-D3 (基准复核) ←── 全部完成后
```

**并行策略**：
- B0/B1 可与 A2 并行（测试不依赖自举修复）
- B2/B3 可并行（独立测试路径）
- C1-C3 可并行（独立设计改进）

## 七、验收标准

### 自举验收（线路 A）
- [ ] C6-A 前置条件明确
- [ ] Blocker matrix 覆盖全部 mem 源码单元
- [ ] FPC stub 完备，双编译通过
- [ ] 4 个 representative consumer 模式编译通过

### 测试验收（线路 B）
- [ ] 343 → 357+ T.Run cases（新增 14+ 测试）
- [ ] 100% 公共 API 覆盖（重点：AllocAligned、ReallocMem、Reset/RestoreToMark）
- [ ] heaptrc 0 leaks
- [ ] 30/30 test suites 全绿

### 设计验收（线路 C）
- [ ] TTrackingAllocator double-free 检测生效
- [ ] Traits 语义文档完备
- [ ] TFallbackAllocator Traits 合并正确

### 基准验收（线路 D）
- [ ] 全部测试使用 `nextpas.core.test`
- [ ] 全部基准使用 `nextpas.core.bench`
- [ ] README 数据与实际一致
- [ ] 基准数据可复现、准确

## 八、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| C6-A 未完成，TLS/threadvar 阻塞 | A3 部分阻塞 | 记录为已知限制，继续其他类别 |
| nextPas 编译器不支持某些语法 | A3 阻塞 | 优先修复编译器或适配源码 |
| 测试迁移工作量大 | D1 延期 | 按风险分批，高风险优先 |

## 九、关联文档

- 编译器目标树：`compiler/docs/compiler-goal-tree.md`
- 自举进度：`docs/plans/selfhost-blockers-roadmap.md`
- 设计规范：`core/docs/design-conventions.md`
- mem 模块文档：`core/docs/mem/README.md`
- Blocker matrix：`core/docs/mem/selfhost-blocker-matrix.md`（待创建）
