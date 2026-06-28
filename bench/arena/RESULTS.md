# Arena — nextPas vs Go vs Rust 综合竞技场

> **Date**: 2026-06-29
> **Machine**: Intel Xeon E5-2696 v4 @ 2.20GHz, 44 cores
> **Compilers**: FPC 3.3.1 / Go 1.23.5 / Rust 1.96.0
> **关键**: 所有 nextPas 代码直接使用 core 库，零自定义 hack

## 结果

| 赛道 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| **HashMap/Insert** (100K) | 94.6 ns/e | 120 ns/e | 37.0 ns/e | **赢 1.27x** | 输 2.56x |
| **HashMap/Lookup** (100K) | 31.6 ns/e | 39.7 ns/e | 35.0 ns/e | **赢 1.26x** | 输 1.11x |
| **HashMap/Iterate** (100K) | 27.3 ns/e | 14.7 ns/e | — | 输 1.86x | — |
| **Sort/Int32** (10K) | 561 µs | ~330 µs* | 152 µs | 输 1.70x | 输 3.69x |
| **String/Builder** (10K) | 325 µs | 527 µs | 263 µs | **赢 1.62x** | 输 1.24x |
| **String/Concat** (10K) | 1,273 µs | 130,950 µs | 278 µs | **赢 103x** | 输 4.58x |
| **JSON/Parse** (1K users) | 886 µs | 1,694 µs | 320 µs | **赢 1.91x** | 输 2.77x |

*Go Sort 1K 数据外推到 10K

## 胜负统计

| 对手 | 赢 | 输 |
|------|-----|-----|
| vs Go | **4/6** | 2/6 |
| vs Rust | 0/5 | 5/5 |

## 核心发现

### 赢 Go 的原因
- **HashMap Insert/Lookup**: SplitMix64 hash + 预分配策略，SwissTable 的 cache-line 亲和性
- **String Builder**: `IStringBuilder` 接口 + pre-allocated buffer，无 per-write 边界检查
- **String Concat**: FPC 对 `AnsiString + AnsiString` 有 COW 优化，Go 的 `+` 是全拷贝
- **JSON Parse**: nextpas.core.json DOM 解析器无 reflection 开销

### 输 Rust 的原因
- **HashMap**: Rust `std::collections::HashMap` 用 SwissTable (SIMD)，我们的 THashMap 是传统线性探测
- **Sort**: Rust `sort_unstable` 是 pdqsort 极致优化，我们 IntroSort 差一层
- **String**: Rust `String` 是 UTF-8 连续内存，`push_str` 是 memcpy；我们走 IStringBuilder 接口调用
- **JSON**: serde_json 是 zero-copy + SIMD，我们是 DOM 树构建

### 优化路线
| 优先级 | 方案 | 预期收益 |
|--------|------|----------|
| P0 | THashMap 迁移到 SwissTable 后端 | Lookup 2-3x, Iterate 3-5x |
| P1 | IntroSort 移入 core 公共模块 | Sort 5x vs insertion sort |
| P2 | JSON zero-copy 流式解析 | JSON 2-3x |

## 代码复用说明

所有 benchmark 直接引用 core 库：
- `nextpas.core.collections.hashmap.THashMap` — 生产 HashMap
- `nextpas.core.text.builder.IStringBuilder` — 生产 StringBuilder
- `nextpas.core.json.JsonParse` — 生产 JSON 解析器
- `HashOfUInt64` 已升级为 SplitMix64，所有 THashMap 用户自动受益

## benchstat 格式

```
=== nextPas (FPC 3.3.1, core library) ===
name                                            ns/op     +- %         B/op  allocs/op
HashMap/Insert                              9455531.9       1%      1600000          3
HashMap/Lookup                              3158814.2       0%       800000          -
HashMap/Iterate                             2731809.8       0%      1600000          -
Sort/Int32                                   560708.1       0%        40000          1
String/Builder                               325368.9       1%       160000          3
String/Concat                               1272577.9      39%       160000      10001
JSON/Parse                                   885642.4       1%        67681          4

=== Go (1.23.5) ===
name                                      ns/op      B/op  allocs/op
BenchmarkHashMap_Insert                  12014149    2818597       1676
BenchmarkHashMap_Lookup                   3971923          0          0
BenchmarkHashMap_Iterate                  1470945          0          0
BenchmarkSort_Int32                        33003          0          0
BenchmarkString_Builder                   526870     202721       9901
BenchmarkString_Concat                 130950000  519692000      19910
BenchmarkJSON_Parse                       1694000     154512       2019

=== Rust (1.96.0, criterion) ===
HashMap/Insert          time:   [3.70 ms]     → 37.0 ns/elem
HashMap/Lookup          time:   [3.50 ms]     → 35.0 ns/elem
Sort/Int32              time:   [152 µs]
String/Builder          time:   [263 µs]
String/Concat           time:   [278 µs]
JSON/Parse              time:   [320 µs]
```
