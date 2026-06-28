# nextPas Arena Benchmark Results

## 测试环境
- CPU: x86_64 Linux
- FPC: 3.3.1 (trunk)
- Go: 1.23.5
- Rust: 1.96.0 (criterion)
- N=100000 (HashMap), N=10000 (Sort/String), N=1000 (JSON)

## 综合战报 (2026-06-29)

### vs Go — 5 胜 2 负

| 赛道 | nextPas (ns/op) | Go (ns/op) | 比率 | 赢家 |
|------|----------------|------------|------|------|
| HashMap/Insert | 11,258,947 | 10,875,614 | 1.04x | ≈平 |
| **HashMap/Lookup** | **3,191,269** | 3,875,729 | **1.21x** | ✅ nextPas |
| HashMap/Iterate | 2,499,211 | 1,407,639 | 1.77x | Go |
| **Sort/Int32** | **588,885** | 624,288 | **1.06x** | ✅ nextPas |
| **String/Builder** | **326,852** | 892,322 | **2.73x** | ✅ nextPas |
| **String/Concat** | **1,242,333** | 86,366,657 | **69.5x** | ✅ nextPas |
| **JSON/Parse** | **872,972** | 1,652,644 | **1.89x** | ✅ nextPas |

### 核心优化 (全部在 nextpas.core 库中)

1. **SplitMix64 hash** (`nextpas.core.collections.hashmap`) — HashMap Lookup 赢 Go
2. **IntroSort** (`nextpas.core.collections.algorithms`) — Sort 赢 Go
3. **TStringBuilder** (`nextpas.core.text.builder`) — String Builder/Concat 大胜
4. **JSON DOM parser** (`nextpas.core.json`) — JSON Parse 赢 Go
5. **线性扫描迭代器** — HashMap Iterate 从 4.47x 差距改善到 1.77x

### 代码复用

所有性能优化均在 `nextpas.core.*` 库模块中实现，benchmark 直接 `uses` 核心库：
- `nextpas.core.collections.hashmap` — THashMap<K,V>
- `nextpas.core.collections.algorithms` — Sort<T>, SortInt32
- `nextpas.core.text.builder` — IStringBuilder
- `nextpas.core.json` — JsonParse

### 剩余差距

| 差距 | 原因 | 改进方向 |
|------|------|----------|
| HashMap Iterate 1.77x | 线性扫描 vs Go 的 Hmap 优化 | SwissTable 后端 |
| HashMap Insert 1.04x | 接近平手 | 微调 |
