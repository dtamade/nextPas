# mem 模块深化路线图（历史 — 时代 A）

> **SUPERSEDED（2026-07-17）**: 见 [../ROADMAP.md](../ROADMAP.md)。

> **状态**: 基本完成
> **起始**: 2026-07-07
> **基线**: 46 suites / 649 tests / 0 failures
> **当前**: 46 suites / 650 tests / 0 failures

## Phase 1: 测试加固 ✅

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P1-1 | Property-based fuzzing | ✅ | test_arena_prop: 10 不变量测试 |
| P1-2 | Memory tagging | ✅ | TTrackingAllocator.SetTag + 4 测试 |
| P1-3 | Long-running stress | ✅ | test_soak: 4T continuous + fragmentation + ratio |

## Phase 2: 性能优化 ✅

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P2-1 | Per-sizeclass stats | ✅ | TBlockPoolStats: TotalAcquires/CacheHits/Utilization |
| P2-2 | Arena Compact | ✅ | TChunkedArena.Compact: 合并相邻缓存段 |
| P2-3 | SIMD zero | ⏭️ | 跳过：FPC 内置 FillChar 已有 SSE2/AVX 优化 |

## Phase 3: 功能扩展 ✅

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P3-1 | ThreadArena auto-cleanup | ✅ | 已有 pthread_key 自动 DrainTLS |
| P3-2 | Allocator composition | ✅ | 已有 TFallbackAllocator/TFallbackArena |

## Phase 4: 集成与文档 ✅

| # | 项目 | 状态 | 说明 |
|---|------|------|------|
| P4-1 | API Guide 场景示例 | ✅ | 5 个完整代码示例 |
| P4-2 | Compiler 集成验证 | ✅ | 无 blocker，编译器当前不需要 mem |
| P4-3 | Benchmark CI | ⏭️ | 已有 bench 模块，CI 集成待 CI 环境就绪 |
