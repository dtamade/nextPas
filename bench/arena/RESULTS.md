# nextPas Arena Benchmark — 跨语言竞技场

**日期**: 2026-06-29
**CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
**nextPas**: FPC 3.3.1-19195 `-O2`
**Go**: 1.23.5 (`go test -bench`)
**Rust**: 1.96.0 (`cargo bench` / criterion)

## 赛道总览 (12 赛道)

### vs Go: 7赢 0平 5输

| 赛道 | nextPas | Go | 比率 | 胜 |
|------|---------|-----|------|---|
| String/Concat | 1.27ms | 243ms | **0.005x** | ✅ 192x 快 |
| Sort/Int32 | 576µs | 1.14ms | **0.51x** | ✅ 1.98x 快 |
| JSON/Parse | 900µs | 2.64ms | **0.34x** | ✅ 2.93x 快 |
| String/Builder | 327µs | 941µs | **0.35x** | ✅ 2.88x 快 |
| HashMap/Lookup | 2.97ms | 3.85ms | **0.77x** | ✅ 1.30x 快 |
| HashMap/Insert | 9.62ms | 11.4ms | **0.85x** | ✅ 1.18x 快 |
| HashMap/Iterate | 1.34ms | 1.46ms | **0.92x** | ✅ 1.09x 快 |
| TOML/Parse | 24.6ms | 21.1ms | 1.17x | ❌ Go 快 17% |
| Regex/SimpleMatch | 1.12ms | 140µs | 8.0x | ❌ Go 快 8x |
| Regex/Match | 14.5ms | 957µs | 15.2x | ❌ Go 快 15x |
| Regex/FindAll | 16.6ms | 2.28ms | 7.3x | ❌ Go 快 7.3x |
| Regex/FindAllCapture | 28.2ms | 2.58ms | 10.9x | ❌ Go 快 11x |

### vs Rust: 待补充

## 大胜分析

### 🔥 String/Concat: 192x 快于 Go
Go 的 string 拼接是 O(n²) 的 copy-on-write。nextPas 的 AnsiString 使用引用计数 + COW 优化，每次拼接只需 memcpy。

### ✅ Sort/Int32: 1.98x 快于 Go
nextPas 使用 IntroSort + Tukey's ninther (三中位数的中位数)。Go 使用 pdqsort，对随机数据不如 Tukey's ninther 有效。

### ✅ JSON/Parse: 2.93x 快于 Go
nextPas 的 JSON DOM 解析器直接在输入上构建节点树。Go 的 encoding/json 使用反射 + interface{} 分配。

### ✅ String/Builder: 2.88x 快于 Go
nextPas 的 IStringBuilder 使用 Arena 预分配，AppendInt 无临时分配。Go strings.Builder 每次 WriteString 有边界检查开销。

### ✅ HashMap: 1.09-1.30x 快于 Go
Bitmap 迭代器 (O(count) vs O(n)) + SplitMix64 hash + 线性探测 (cache-friendly)。

## 技术细节

### HashMap 优化
- **Bitmap 迭代器**: 1 bit/bucket，O(count) 遍历替代 O(n) 链表
- **SplitMix64**: 整数键的 avalanche 比 split+multiply 更好
- **预分配容量**: Create(N) 直接分配，避免 rehash

### Sort 优化
- **IntroSort + Tukey's ninther**: N>128 时用三中位数的中位数
- **SortInt32 特化**: 无函数指针开销的 Int32 排序
- **有序/逆序检测**: 顶层 O(n) 检测特殊情况

### Regex 优化
- **DFA cache 复用**: TRegex 缓存 PDfaCache，跨调用复用
- **DfaCacheReset**: 只重置状态，保留已分配数组
- **DfaIsMatchCached/DfaFindAllCached**: 使用外部 cache 参数
- SimpleMatch: 5.28ms → 1.12ms (4.71x 提升)
- FindAll: 27.8ms → 16.6ms (1.68x 提升)
- vs Go 仍有 7-15x 差距: Go RE2 是 C++ 高度优化实现

## 文件清单

```
bench/arena/bench_arena2.pas     — nextPas 竞技场 (12 赛道)
bench/arena/bench_arena.go       — Go 竞技场 (12 赛道)
bench/arena/bench_arena.rs       — Rust 竞技场 (10 赛道)
bench/arena/np_sort_utils.pas    — Sort 工具 (bench-only)
bench/arena/Cargo.toml           — Rust 依赖配置
bench/arena/Makefile             — 构建脚本
```
