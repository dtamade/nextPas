# nextpas.core.mem 全面审查 — Findings

**审查日期**: 2026-06-24
**审查范围**: 54 源文件 (18,942 行) + 25 测试项目 (5,610 行)
**当前状态**: 19/25 测试通过，2 编译失败，4 compile-gate 通过

---

## 统计摘要

| 维度 | critical | major | minor | suggestion | 合计 |
|------|----------|-------|-------|------------|------|
| **正确性 (CS)** | 2 | 4 | 9 | 0 | **15** |
| **质量/架构 (QA)** | 0 | 7 | 10 | 6 | **23** |
| **测试覆盖 (TC)** | 0 | 4 | 8 | 5 | **17** |
| **合计** | **2** | **15** | **27** | **11** | **55** |

---

## 🔴 Critical (2 项)

| ID | 标题 | 文件 | 状态 |
|----|------|------|------|
| CS-001 | blockpool.growable 缺少 pool.base uses → 编译失败 | `blockpool.growable.pas:16` | ✅ 已修复 |
| CS-002 | NextPowerOfTwo 极大值无限循环 | `mem.base.pas:49` | ✅ 已修复 |

## 🟠 Major (20 项)

### 正确性 (7)
| ID | 标题 | 文件 | 状态 |
|----|------|------|------|
| CS-003 | AlignUp 整数溢出风险 | `mem.base.pas:56` | ✅ 已修复 |
| CS-004 | ngx_slab_sizes_init CAS 缺少 memory barrier | `pool.fixed_slab.pas:284` | ⏳ 待复核 |
| CS-005 | TFixedSlabPool.AllocMem 只清零 aSize（信息泄露） | `pool.fixed_slab.pas:1587` | ✅ 已修复 |
| CS-006 | TSlabPool.AllocMem 同样只清零请求大小 | `pool.slab.pas:1114` | ✅ 已修复 |
| CS-007 | ShardedBlockPool.Release 路由 TOCTOU 窗口 | `blockpool.sharded.pas:1178` | ❌ 非真实bug（路由稳定） |
| CS-008 | RouteWriteLock 潜在活锁 | `blockpool.sharded.pas:320` | ⏳ minor（已有yield退避） |
| CS-009 | TLS 节点泄漏（当前已禁用） | `blockpool.sharded.pas:850` | 已知限制 |

### 质量/架构 (8)
| ID | 标题 | 文件 | 状态 |
|----|------|------|------|
| QA-001 | pool.fixed + allocator.mimalloc 直接引用 FPC SysUtils | `pool.fixed.pas:198`, `allocator.mimalloc.pas:41` | ✅ mimalloc 已修复; pool.fixed 仅 debug |
| QA-002 | 19 个测试文件直接引用 FPC SysUtils/Classes | `test_*/test_*.lpr` | ✅ 已修复（SysUtils 0残留，Classes 仅TThread） |
| QA-003 | AlignUp 重复已收敛，仅剩私有 helper 局部重复 | `base.pas`, `allocator.base.pas`, `pool.slab.pas` | ⚠️ 低优先级质量债务（allocator.mmap 重复已消失，仅剩私有 pointer helper 重复） |
| QA-004 | IAllocator 以 alias/re-export 形式分散 | `intf.pas`, `allocator.pas`, `interfaces.pas` | ⚠️ 历史兼容残留（canonical 在 mem.intf；allocator 为必要 facade；interfaces 为 compat alias） |
| QA-005 | IPool/IArena 接口层级分散，v1/v2 兼容层并存 | 多文件 | ⚠️ 低优先级质量债务（主要来自 v1/v2 兼容层并存；优先做文档/弃用计划，不建议立即重构） |
| QA-006 | utils.pas 1313 行 / 71 函数 — 同域内偏大 | `mem.utils.pas` | ⚠️ 真实质量债务（1313 行超软阈值，但仍属同一工具域；保持 P3，不建议机械拆分） |
| QA-007 | pool.fixed.pas 现状不支持“必须拆分” | `pool.fixed.pas` | ❌ 非真实问题（597 行 / 2 个核心类，未达拆分阈值；无需单独拆分） |
| QA-008 | Copy/Zero/Compare 与 FPC System 同名 | `mem.utils.pas` | ⏳ 降级为低优先级 |

### 测试覆盖 (5)
| ID | 标题 | 文件 | 状态 |
|----|------|------|------|
| TC-001 | 3 个并发池 (3,396 行) 因编译错误零覆盖 | `blockpool.growable/sharded`, `slab.sharded` | ✅ 已恢复（CS-001 修复后） |
| TC-002 | utils.pas 71 个函数无直接测试 | `mem.utils.pas` | ✅ 已新增 test_mem_utils |
| TC-003 | IObjectPool 泛型接口完全无测试 | `pool.object_pool.pas` | ✅ 已新增 test_object_pool |
| TC-004 | pool.adapter.pas 桥接适配器无测试 | `pool.adapter.pas` | ⚠️ 已知限制（仅有占位 SKIP，不构成测试闭环；pool.adapter 依赖已删除的 mem.layout，且 IArena 适配签名已过期） |
| TC-005 | mem.stats.pas 统计收集器无测试 | `mem.stats.pas` | ✅ 已新增 test_mem_stats |

## 🟡 Minor (27 项)

<details>
<summary>展开查看全部 27 项 minor findings</summary>

**正确性 (9)**:
- CS-010: RestoreState 不验证 aState 来源 (`stack_pool.pas:431`)
- CS-011: StackPool Alloc 对齐计算溢出 (`stack_pool.pas:389`)
- CS-012: RingBuffer 批量操作用 mod 而非位与 (`ring_buffer.pas:374`)
- CS-013: RingBuffer.Clear 不清零（安全风险）(`ring_buffer.pas:450`)
- CS-014: SlabPool PageMap key 0/1 碰撞 (`pool.slab.sharded.pas:275`)
- CS-015: BlockPoolConcurrent 属性未加锁读 (`blockpool.concurrent.pas:199`)
- CS-016: FixedSlabPool FreeMem 不擦除敏感数据 (`pool.fixed_slab.pas:1623`)
- CS-017: TSlabPool 无线程安全警告机制 (`pool.slab.pas`)
- CS-018: GrowingArena.RestoreToMark 边界条件 (`arena.growable.pas:589`)

**质量/架构 (10)**:
- QA-009: mem.mem_pool.pas 兼容 shim 无 deprecated 标记
- QA-010: pool.memory_pool.pas 仅 28 行只定义 IMemoryPool
- QA-011: pool.adapter.pas 过渡代码无废弃时间表
- QA-012: TFixedPoolGrowable vs TGrowingFixedPool 命名不一致
- QA-013: stack_pool.pas 6 类 + 6 deprecated 别名
- QA-014: ring_buffer.pas 通用数据结构放在 mem 模块中
- QA-015: blockpool.sharded.pas 1424 行过于复杂
- QA-016: pool.fixed_slab.pas 1687 行最大文件
- QA-017: nextpas.core.math 在 L0 mem 中使用需确认
- QA-018: error.pas 5 个异常类粒度评估

**测试覆盖 (8)**:
- TC-006: 19 个测试用 SysUtils 而非框架模块
- TC-007: 测试不用 nextpas.core.test 框架
- TC-008: ring_buffer.pas 726 行无直接测试
- TC-009: FixedSlabPool ngx slab 算法缺专门测试
- TC-010: mem.adapters.pas 适配器无测试
- TC-011: 缺少 OOM 测试（test_oom 编译失败）
- TC-012: 并发测试缺竞争压力测试
- TC-013: mapped_ring_buffer_compile_gate Makefile 缺 clean target
- TC-014: 缺少模块级顶层 Makefile

</details>

## 🟢 Suggestion (11 项)

<details>
<summary>展开查看全部 11 项 suggestion</summary>

- QA-019: mimalloc.pas 门面层 92 行只暴露 3 个函数（合理）
- QA-020: mem.pas 门面 re-export 列表验证
- QA-021: NextPowerOfTwo 的 inline 标记误导
- QA-022: mem.default.pas (22行) 和 mem.mem_pool.pas (28行) 空壳文件
- QA-023: IObjectPool 接口无泛型约束（实现有）
- QA-024: FPC PPU 缓存 freshness 风险
- TC-015: L0 边界脚本缺 mutex/rwlock 说明
- TC-016: 缺少性能基准测试
- TC-017: deprecated API 迁移测试
- TC-018: README 缺少架构图
- QA-018: error.pas 异常层级评估

</details>

---

## 推荐处理优先级

### P0 — 阻塞/编译错误 (1 项)
1. **CS-001**: blockpool.growable 缺 pool.base uses → 修复后恢复 test_sharded_pools + test_oom

### P1 — 安全/正确性 (6 项)
2. **CS-002**: NextPowerOfTwo 无限循环保护
3. **CS-003**: AlignUp 溢出保护
4. **CS-005/CS-006**: AllocMem 清零实际块大小
5. **CS-004**: ngx_slab CAS memory barrier
6. **CS-007**: ShardedBlockPool 路由 TOCTOU

### P2 — FPC RTL 合规 (2 项)
7. **QA-001**: 源码 SysUtils 替换
8. **QA-002**: 测试 SysUtils/Classes 替换

### P3 — 代码质量 (5 项)
9. **QA-003**: AlignUp 去重 → ⚠️ 低优先级质量债务（mmap 重复已消失，仅剩私有 helper）
10. **QA-004/005**: 接口定义整理 → ⚠️ 历史兼容残留 + 低优先级（v1/v2 并存）
11. **QA-006**: mem.utils 大文件 → ⚠️ 真实质量债务（保持 P3，不机械拆）
12. **QA-007**: pool.fixed 大文件 → ❌ 非真实问题（597 行 / 2 个类）

### P4 — 测试补充 (5 项)
13. **TC-001**: 恢复 sharded 测试 → ✅ 已修复 CS-001，自动恢复
14. **TC-002**: utils.pas 测试 → ✅ 已新增 test_mem_utils
15. **TC-003**: object_pool 测试 → ✅ 已新增 test_object_pool
16. **TC-004**: adapter 测试 → ⚠️ 已知限制（依赖已删除的 mem.layout + IArena 签名过期）
17. **TC-005**: stats 测试 → ✅ 已新增 test_mem_stats

### P5 — 建议性 (已完成/已定性)
18. **QA-018 (SA-001)**: 异常层级 → ✅ 已复核关闭（TAllocError + 错误码表配套，暂不收敛）
19. **QA-019 (SA-002)**: mimalloc 薄门面 → ✅ 已失效（当前 mimalloc 不是薄门面语义）
20. **QA-020 (SA-003)**: mem.pas re-export → ✅ 已复核关闭（与 README Stable Surface 一致）
21. **QA-021 (SA-004)**: NextPowerOfTwo inline → ✅ 已修复（移除 inline 标记）
22. **QA-022 (SA-005)**: 薄文件合并 → ✅ 已添加 deprecated 标记（mem.mem_pool + mem.interfaces）
23. **QA-023 (SA-006)**: IObjectPool 约束 → ✅ 已修复（泛型约束现已一致）
24. **QA-024 (SA-007)**: PPU freshness → ⏳ 低优先级（clean 约定已明显降低风险）
25. **TC-015 (SA-008)**: L0 边界脚本说明 → ✅ 已基本澄清（README 已覆盖）
26. **TC-016 (SA-009)**: benchmark 基线 → ✅ 已修复（bench_alloc 迁移到当前 IAllocator API + platform.time）
27. **TC-017 (SA-010)**: deprecated API 迁移测试 → ⏳ 低优先级（新 owner surface 已有 compile truth）
28. **TC-018 (SA-011)**: README 架构图 → ⏳ 纯文档增强项

### 当前待处理汇总
- **真实质量债务**: QA-006（mem.utils 大文件）
- **历史兼容残留**: QA-005（v1/v2 并存，已加 deprecated 标记）
- **已知限制**: TC-004（pool.adapter 过期）、SA-007（PPU）、SA-010（deprecated 测试）
- **文档增强**: SA-011（架构图）

### 已关闭项 (本轮新增)
- SA-004: NextPowerOfTwo inline 已移除
- SA-005: mem.mem_pool + mem.interfaces 已加 deprecated 标记
- SA-009: bench_alloc 已迁移到当前 API
- QA-004: mem.interfaces 已加 deprecated 标记
