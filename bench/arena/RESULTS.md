# Arena — nextPas vs Go vs Rust 综合竞技场 (Final)

> **Date**: 2026-06-29
> **Machine**: Intel Xeon E5-2696 v4 @ 2.20GHz, 44 cores
> **Compilers**: FPC 3.3.1 / Go 1.23.5 / Rust 1.96.0
> **关键**: 所有 nextPas 代码直接使用 core 库，零 hack

## 结果

| 赛道 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| **HashMap/Insert** (100K) | 109 ns/e | 120 ns/e | 37 ns/e | **赢 1.10x** | 输 2.95x |
| **HashMap/Lookup** (100K) | 30.2 ns/e | 39.7 ns/e | 35 ns/e | **赢 1.31x** | 输 1.16x |
| **HashMap/Iterate** (100K) | 29.7 ns/e | 14.7 ns/e | — | 输 2.02x | — |
| **Sort/Int32** (10K) | 561 µs | ~330 µs* | 152 µs | 输 1.70x | 输 3.69x |
| **String/Builder** (10K) | 322 µs | 527 µs | 263 µs | **赢 1.64x** | 输 1.22x |
| **String/Concat** (10K) | 1,230 µs | 131,000 µs | 278 µs | **赢 106x** | 输 4.42x |
| **JSON/Parse** (1K users) | 879 µs | 1,694 µs | 320 µs | **赢 1.93x** | 输 2.75x |

*Go Sort 数据来自 1K 外推

## 胜负

| 对手 | 赢 | 输 |
|------|-----|-----|
| vs Go | **4/6** | 2/6 |
| vs Rust | 0/5 | 5/5 |

## 本次优化沉淀到 core 的改动

| Commit | 改动 | 效果 |
|--------|------|------|
| 33aec78e5 | `HashOfUInt64` → SplitMix64 | HashMap Insert/Lookup 各 +25% |
| 8f8c197fb | `Sort<T>` → IntroSort | O(n log n) 保证，小分区 +10x |
| 915dcbff5 | TBucket.NextOccupied 链表 | Iterate O(count) 替代 O(capacity) |

所有改动 21/21 HashMap + 16/16 SwissTable + 52/52 Vec 测试全绿。
