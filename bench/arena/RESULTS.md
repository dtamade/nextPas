# nextPas Arena Benchmark Results

## 测试环境
- CPU: x86_64 Linux
- FPC: 3.3.1 (trunk)
- Go: 1.23.5
- Rust: 1.96.0 (sort_unstable/pdqsort + criterion + serde_json)
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

### vs Rust — 1 赛道赢，6 赛道负

| 赛道 | nextPas (ns/op) | Rust (ns/op) | 比率 | 赢家 |
|------|----------------|-------------|------|------|
| HashMap/Insert | 11,250,989 | 3,933,800 | 2.86x | Rust |
| **HashMap/Lookup** | **3,203,637** | 3,573,700 | **1.12x** | ✅ nextPas |
| Sort/Int32 | 579,460 | 157,710 | 3.67x | Rust |
| String/Builder | 326,428 | 242,290 | 1.35x | Rust |
| String/Concat | 1,234,023 | 266,390 | 4.64x | Rust |
| JSON/Parse | 836,052 | 336,800 | 2.48x | Rust |

### Sort 跨尺寸对比

| N | nextPas (ns) | Go (ns) | Rust (ns) | np/Go | np/Rust |
|---|-------------|---------|-----------|-------|---------|
| 1,000 | 22,043 | 31,538 | 10,297 | **1.43x 赢** | 2.14x |
| 10,000 | 567,332 | 616,215 | 151,371 | **1.09x 赢** | 3.75x |
| 100,000 | 8,180,608 | 7,642,901 | 1,951,950 | 1.07x | 4.19x |
| 1,000,000 | 90,178,842 | 88,256,020 | 23,218,277 | 1.02x | 3.88x |

### 核心优化 (全部在 nextpas.core 库中)

1. **SplitMix64 hash** (`nextpas.core.collections.hashmap`) — Lookup 赢 Go+Rust
2. **Bitmap iterator** (`nextpas.core.collections.hashmap`) — Iterate 追平 Go
3. **Block partitioning IntroSort** (`nextpas.core.collections.algorithms`) — Sort 赢 Go
4. **TStringBuilder** (`nextpas.core.text.builder`) — String 70x 赢 Go
5. **JSON DOM parser** (`nextpas.core.json`) — JSON 1.98x 赢 Go

### 代码复用

所有性能优化均在 `nextpas.core.*` 库模块中实现，benchmark 直接 `uses` 核心库。

### 剩余差距分析

| 差距 | 原因 | 改进方向 |
|------|------|----------|
| vs Rust Sort 3.75x | LLVM codegen + 完整 pdqsort | LLVM 后端 (P4) |
| vs Rust HashMap Insert 2.86x | SwissTable + LLVM | SwissTable 迁移 |
| vs Rust String 1.35-4.64x | LLVM codegen | LLVM 后端 |
| vs Rust JSON 2.48x | serde_json SIMD + 零拷贝 | 流式 parser |
