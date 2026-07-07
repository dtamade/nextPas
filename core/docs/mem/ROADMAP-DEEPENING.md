# mem 模块深化路线图

> **状态**: 执行中
> **起始**: 2026-07-07
> **基线**: 46 suites / 649 tests / 0 failures

## Phase 1: 测试加固

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P1-1 | Property-based fuzzing | ✅ | test_arena_prop: 10 不变量测试 |
| P1-2 | Memory tagging | ✅ | TTrackingAllocator.SetTag + 4 测试 |
| P1-3 | Long-running stress | ✅ | test_soak: 4T continuous + fragmentation + ratio |

## Phase 2: 性能优化

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P2-1 | Per-sizeclass stats | 待做 | TShardedBlockPool 命中率/碎片率统计 |
| P2-2 | Arena Compact | 待做 | TChunkedArena 合并空闲段 |
| P2-3 | SIMD zero | 待做 | AVX2/NEON FillChar 大块清零 |

## Phase 3: 功能扩展

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P3-1 | ThreadArena auto-cleanup | 待做 | pthread_key 自动 DrainTLS |
| P3-2 | Allocator composition | 待做 | 通用 fallback/pool/arena 组合器 |

## Phase 4: 集成与文档

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P4-1 | API Guide 场景示例 | 待做 | 5 个完整代码示例 |
| P4-2 | Compiler 集成验证 | 待做 | 编译器使用 mem 模块验证 |
| P4-3 | Benchmark CI | 待做 | 基准测试 CI 集成 |
