# mem 模块测试覆盖补全计划

> **目标**: 将测试从 688 提升到 800+，覆盖所有 allocator 专属测试
> **起始**: 2026-07-10
> **基线**: 58 套件 / 688 测试

## Phase 1: Allocator 专属测试 (24 个)

### P1-1: 高优先级 — 完全无测试的 allocator

| # | Allocator | 源文件行数 | 当前覆盖 | 计划测试数 |
|---|-----------|-----------|----------|-----------|
| 1 | TCountingAllocator | ~150 | 无 | 10 |
| 2 | TDualAllocator | ~200 | 无 | 10 |
| 3 | TGroupAllocator | ~200 | 无 | 10 |
| 4 | TSlidingAllocator | ~180 | 无 | 10 |
| 5 | TPageAllocator | ~150 | 无 | 10 |
| 6 | TFreelistAllocator | ~200 | 无 | 10 |
| 7 | TLoggingAllocator | ~150 | 无 | 10 |

### P1-2: 中优先级 — 有间接测试但无专属目录

| # | Allocator | 当前覆盖 | 计划测试数 |
|---|-----------|----------|-----------|
| 8 | TArenaGroupAllocator | test_concurrent | 10 |
| 9 | TBaseAllocator | test_allocator_base | 10 |
| 10 | TCallbackAllocator | test_callback_allocator | 10 |
| 11 | TCrtAllocator | test_allocator_crt (2) | 8 |
| 12 | TDebugAllocator | test_debug_allocator | 10 |
| 13 | TFallbackAllocator | test_fallback_allocator | 10 |
| 14 | TFoundationAllocator | test_allocator_foundation (3) | 8 |
| 15 | TGrowingAllocator | test_growing_allocator | 10 |
| 16 | TLeakCheckAllocator | test_leak_check_allocator | 10 |
| 17 | TMimallocAllocator | test_allocator_mimalloc | 8 |
| 18 | TMmapAllocator | test_mmap_allocator | 10 |
| 19 | TStatsAllocator | test_stats_allocator | 10 |
| 20 | TTrackingAllocator | test_tracking_allocator | 10 |
| 21 | TZeroedAllocator | test_zeroed_allocator | 10 |

### P1-3: 低优先级 — 基础设施/加载器

| # | Allocator | 说明 | 计划测试数 |
|---|-----------|------|-----------|
| 22 | TBaseAllocator | 已有 test_allocator_base (7) | 补充边界 |
| 23 | TMimallocLoader | 加载器，编译 gate 已有 | 5 |

## Phase 2: 扩充薄弱测试套件

| # | 当前套件 | 当前测试数 | 目标测试数 | 新增内容 |
|---|----------|-----------|-----------|----------|
| 1 | test_slab_thread_safety | 2 | 12 | 多线程并发、ABA 防护、碎片化 |
| 2 | test_default_allocator | 2 | 10 | Traits、ReallocMem、边界 |
| 3 | test_allocator_crt | 2 | 10 | CRT 特性、对齐、大分配 |
| 4 | test_soak | 3 | 12 | 长时间运行、内存压力、碎片化 |
| 5 | test_pressure | 4 | 12 | 高竞争、OOM 降级、恢复 |
| 6 | test_concurrent | 4 | 12 | 多线程竞争、ABA、race condition |

## Phase 3: 深度边界测试

| # | 测试类型 | 说明 | 计划测试数 |
|---|----------|------|-----------|
| 1 | 边界条件 | MaxInt、0、1 字节分配 | 10 |
| 2 | 异常路径 | OOM、double-free、use-after-free | 10 |
| 3 | 并发竞争 | 多线程同时分配/释放 | 10 |
| 4 | 内存踩踏 | 检测越界写入 | 8 |

## Phase 4: 基础设施修复

| # | ID | 说明 | 工作量 |
|---|-----|------|--------|
| 1 | TC-013 | Makefile clean target | 5 分钟 |
| 2 | TC-017 | deprecated API 测试 | 30 分钟 |

## 执行策略

1. **批量创建**: 使用脚本批量生成测试目录和 Makefile
2. **模板化**: 统一测试模板，减少重复代码
3. **逐步验证**: 每完成一批立即运行验证
4. **分批提交**: 每 5-10 个测试套件提交一次

## 预期结果

- **新增测试套件**: ~20 个
- **新增测试**: ~200 个
- **最终测试数**: 880+
- **覆盖率**: 100% allocator 专属测试
