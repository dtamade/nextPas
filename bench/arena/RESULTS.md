# nextPas Arena Benchmark Results

## 测试环境
- CPU: x86_64 Linux
- FPC: 3.3.1 (trunk)
- Go: 1.23.5
- Rust: 1.96.0 (criterion)
- N=100000 (HashMap), N=10000 (Sort/String), N=1000 (JSON)

## 综合战报 (2026-06-29)

### vs Go — 5 赛道赢，2 赛道持平

| 赛道 | nextPas (ns/op) | Go (ns/op) | 比率 | 赢家 |
|------|----------------|------------|------|------|
| HashMap/Insert | 11,250,989 | 10,875,614 | 1.03x | ≈平 |
| **HashMap/Lookup** | **3,203,637** | 3,875,729 | **1.21x** | ✅ nextPas |
| HashMap/Iterate | 1,427,000 | 1,407,639 | 1.01x | ≈平 |
| **Sort/Int32** | **579,460** | 624,288 | **1.08x** | ✅ nextPas |
| **String/Builder** | **326,428** | 892,322 | **2.73x** | ✅ nextPas |
| **String/Concat** | **1,234,023** | 86,366,657 | **70x** | ✅ nextPas |
| **JSON/Parse** | **836,052** | 1,652,644 | **1.98x** | ✅ nextPas |

### 核心优化 (全部在 nextpas.core 库中)

1. **SplitMix64 hash** (`nextpas.core.collections.hashmap`) — HashMap Lookup 1.21x 赢 Go
2. **位图迭代器** (`nextpas.core.collections.hashmap`) — HashMap Iterate 追平 Go (1.01x)
3. **IntroSort + Tukey's ninther** (`nextpas.core.collections.algorithms`) — Sort 1.08x 赢 Go
4. **TStringBuilder** (`nextpas.core.text.builder`) — String Builder 2.73x, Concat 70x
5. **JSON DOM parser** (`nextpas.core.json`) — JSON Parse 1.98x 赢 Go

### 代码复用

所有性能优化均在 `nextpas.core.*` 库模块中实现，benchmark 直接 `uses` 核心库：
- `nextpas.core.collections.hashmap` — THashMap<K,V> (SplitMix64 + bitmap iterator)
- `nextpas.core.collections.algorithms` — Sort<T>, SortInt32 (IntroSort)
- `nextpas.core.text.builder` — IStringBuilder
- `nextpas.core.json` — JsonParse

### 演进历程

| 阶段 | HashMap Iterate | 关键优化 |
|------|----------------|----------|
| 初始 | 3.0ms (O(capacity) 线性扫描) | — |
| 链表迭代 | 6.3ms (NextOccupied 链表) | 缓存不友好，反而更慢 |
| 线性扫描 | 2.5ms (顺序内存访问) | CPU 缓存预取友好 |
| **位图迭代** | **1.43ms** (bitmap 跳过空区域) | O(count) + 缓存友好 |
