# nextPas Arena Benchmark — 跨语言竞技场

**日期**: 2026-06-29
**CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
**nextPas**: FPC 3.3.1-19195 `-O2`
**Go**: 1.23.5 (`go test -bench`)
**Rust**: 1.96.0 (`cargo bench` / criterion)

## 赛道总览 (10 赛道)

| 赛道 | nextPas | Go | 比率 | 胜 |
|------|---------|-----|------|---|
| HashMap/Insert | 9.62ms | 12.8ms | **0.75x** | ✅ |
| HashMap/Lookup | 2.97ms | 4.45ms | **0.67x** | ✅ |
| HashMap/Iterate | 1.34ms | 1.46ms | **0.92x** | ✅ |
| Sort/Int32 (N=10k) | 576µs | 573µs | 1.01x | ≈ |
| String/Builder | 327µs | 862µs | **0.38x** | ✅ |
| String/Concat | 1.27ms | 178ms | **0.007x** | ✅ |
| JSON/Parse | 900µs | 2.63ms | **0.34x** | ✅ |
| TOML/Parse | 24.6ms | 18.7ms | 1.32x | ❌ |
| Regex/Match | 14.5ms | 1.01ms | 14.4x | ❌ |
| Regex/SimpleMatch | 1.12ms | 143µs | 7.8x | ❌ |
| Regex/FindAll | 27.8ms | 2.55ms | 10.9x | ❌ |

## vs Go: 6 赢 / 1 平 / 4 输

### ✅ 大胜 (碾压级)

- **String/Concat**: nextPas 0.007x = **140x 快于 Go** — 不可思议的差距
- **String/Builder**: nextPas 0.38x = **2.64x 快于 Go** — IStringBuilder 零拷贝
- **JSON/Parse**: nextPas 0.34x = **2.92x 快于 Go** — DOM 解析器高效

### ✅ 胜

- **HashMap/Lookup**: nextPas 0.67x = **1.50x 快于 Go** — bitmap 迭代 + SplitMix64
- **HashMap/Insert**: nextPas 0.75x = **1.33x 快于 Go** — 预分配 + 线性探测
- **HashMap/Iterate**: nextPas 0.92x = **1.09x 快于 Go** — bitmap O(count) 迭代

### ≈ 平

- **Sort/Int32**: 基本持平 (1.01x) — IntroSort + Tukey's ninther

### ❌ 输

- **TOML/Parse**: Go 1.32x 快于 nextPas — Go BurntSushi/toml 更成熟
- **Regex/Match**: Go 14.4x 快于 nextPas — RE2 引擎极度优化
- **Regex/SimpleMatch**: Go 7.8x 快于 nextPas — DFA 缓存差异
- **Regex/FindAll**: Go 10.9x 快于 nextPas — 同上

## vs Rust: 待补充

(需要 Rust criterion 结果)

## 技术细节

### HashMap 优化
- **Bitmap 迭代器**: 1 bit/bucket，O(count) 遍历替代 O(n) 链表
- **SplitMix64**: 整数键的 avalanche 比 split+multiply 更好
- **预分配容量**: Create(N) 直接分配，避免 rehash

### Sort 优化
- **IntroSort + Tukey's ninther**: N>128 时用三中位数的中位数
- **SortInt32 特化**: 无函数指针开销的 Int32 排序
- **有序/逆序检测**: 顶层 O(n) 检测特殊情况

### Regex 现状
- DFA cache 复用优化已实现 (SimpleMatch 4.71x 提升)
- 仍比 Go RE2 慢 ~8x，主要差距在:
  - Go RE2 是 C++ 高度优化实现
  - 每次 IsMatch 仍有 DfaCacheReset 开销
  - Thompson NFA 模拟 vs 原生 DFA 查表

## 文件清单

```
bench_arena2.pas        — nextPas 竞技场 (10 赛道)
bench_arena_test.go     — Go 竞技场 (10 赛道)
bench_arena.rs          — Rust 竞技场 (10 赛道)
np_sort_utils.pas       — Sort 工具 (bench-only)
Cargo.toml              — Rust 依赖配置
```
