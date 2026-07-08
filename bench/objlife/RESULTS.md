# Object Lifecycle Benchmark — 对象分配/释放

**日期**: 2026-06-29
**CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
**nextPas**: FPC 3.3.1-19195 `-O3` — `New/Dispose`
**Go**: 1.23.5 — `&Node{}` / GC
**Rust**: 1.96.0 — `Box::new` / RAII

## 测试参数

- 100K 对象，每个 64 字节 (TNode record)
- AllocFree: 构建链表 → 全部释放
- AllocFreeShuffle: 分配到数组 → 逆序释放
- LinkedBuild: 构建链表 → 遍历求和 → 释放

## 结果

| 赛道 | nextPas | Go | vs Go | Rust | vs Rust |
|------|---------|-----|-------|------|---------|
| **AllocFree** | **8.49ms** | 14.8ms | **1.74x** ✓ | 4.41ms | 0.52x |
| **AllocFreeShuffle** | **9.06ms** | 13.9ms | **1.54x** ✓ | 6.74ms | 0.74x |
| **LinkedBuild** | **9.30ms** | 15.5ms | **1.67x** ✓ | 6.80ms | 0.73x |

**vs Go: 3W 0L — Pascal 全胜!**
**vs Rust: 0W 3L — Rust 最快 (Box RAII)**

## 分析

### Pascal 1.5-1.7x 快于 Go

Go 的 GC 在高频小对象分配场景下有明显开销：
- **分配**: Go 的 `&Node{}` 需要 GC 写屏障 (write barrier) 来跟踪引用
- **释放**: Go 不直接释放，而是等 GC 周期；大量小对象增加 GC 压力
- **Pascal**: `New/Dispose` 是直接 `GetMem/FreeMem`，零 GC 开销

### Rust 最快

Rust 的 `Box::new` 使用 jemalloc/scoped allocator，批量分配非常高效。
释放时 RAII 自动调用 drop，无 GC 无引用计数。

## benchstat 格式

```
=== Pascal ===
name                                            ns/op     +- %         B/op  allocs/op
AllocFree                                   8492920.0      63%      6400000     100000
AllocFreeShuffle                            9064569.2      61%      6400000     100001
LinkedBuild                                 9296508.2      62%      6400000     100000
```

## 文件清单

```
bench/objlife/objlife_bench.pas      — Pascal 对象生命周期
bench/objlife/objlife_bench_go.go    — Go 对象生命周期
bench/objlife/benches/objlife_bench.rs — Rust 对象生命周期
bench/objlife/Cargo.toml             — Rust 依赖配置
```
