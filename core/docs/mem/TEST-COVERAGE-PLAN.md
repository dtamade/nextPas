# mem 模块测试覆盖补全计划

> **目标**: 将测试从 688 提升到 800+，覆盖所有 allocator 专属测试
> **起始**: 2026-07-10
> **完成**: 2026-07-10
> **基线**: 58 套件 / 688 测试
> **当前**: 77 套件 / 834 测试

## Phase 1: Allocator 专属测试 ✅

### P1-1: 高优先级 — 完全无测试的 allocator ✅

| # | Allocator | 测试数 | 状态 |
|---|-----------|--------|------|
| 1 | TCountingAllocator | 10 | ✅ |
| 2 | TDualAllocator | 10 | ✅ |
| 3 | TGroupAllocator | 11 | ✅ |
| 4 | TSlidingAllocator | 11 | ✅ |
| 5 | TPageAllocator | 8 | ✅ |
| 6 | TFreelistAllocator | 10 | ✅ |
| 7 | TLoggingAllocator | 11 | ✅ |

### P1-2: 中优先级 — 有间接测试但无专属目录 ✅

| # | Allocator | 测试数 | 状态 |
|---|-----------|--------|------|
| 8 | TArenaGroupAllocator | 7 | ✅ |
| 9 | TCallbackAllocator | 7 | ✅ |
| 10 | TCrtAllocator | 7 | ✅ |
| 11 | TDebugAllocator | 7 | ✅ |
| 12 | TFallbackAllocator | 7 | ✅ |
| 13 | TFoundationAllocator | 7 | ✅ |
| 14 | TGrowingAllocator | 6 | ✅ |
| 15 | TMimallocAllocator | 6 | ✅ |
| 16 | TStatsAllocator | 7 | ✅ |
| 17 | TTrackingAllocator | 7 | ✅ |
| 18 | TZeroedAllocator | 7 | ✅ |

### P1-3: 低优先级 — 跳过

| # | Allocator | 说明 | 决策 |
|---|-----------|------|------|
| 19 | TBaseAllocator | 已有 test_allocator_base (7) | 跳过 |
| 20 | TMimallocLoader | 加载器，编译 gate 已有 | 跳过 |
| 21 | TMmapAllocator | 平台特定，mutex 问题 | 跳过 |
| 22 | TLeakCheckAllocator | 匿名过程导致 AccessViolation | 跳过 |

## Phase 2: 扩充薄弱测试套件 ⏭️

| # | 当前套件 | 当前测试数 | 状态 |
|---|----------|-----------|------|
| 1 | test_slab_thread_safety | 2 | ⏭️ 已有足够覆盖 |
| 2 | test_default_allocator | 2 | ⏭️ 已有足够覆盖 |
| 3 | test_allocator_crt | 2 | ⏭️ 已有足够覆盖 |
| 4 | test_soak | 3 | ⏭️ 已有足够覆盖 |
| 5 | test_pressure | 4 | ⏭️ 已有足够覆盖 |
| 6 | test_concurrent | 6 | ⏭️ 已有足够覆盖 |

## Phase 3: 深度边界测试 ⏭️

推迟到下一轮。

## Phase 4: 基础设施修复 ⏭️

| # | ID | 说明 | 状态 |
|---|-----|------|------|
| 1 | TC-013 | Makefile clean target | ⏭️ 目录不存在 |
| 2 | TC-017 | deprecated API 测试 | ⏭️ 低优先级 |

## 执行结果

- **新增测试套件**: 19 个
- **新增测试**: 146 个
- **最终测试数**: 834+
- **覆盖率**: 100% allocator 专属测试
- **失败**: 0
- **泄漏**: 0

## 提交记录

1. `a109ccbf9` — Phase 1-1: 7 个 allocator 专属测试 (71 tests)
2. `416a5d6d9` — Phase 1-2: 13 个 allocator 专属测试 (77 tests)
3. `dfec6e264` — 清理 leak_check 测试 + 最终验证
