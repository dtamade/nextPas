# Lockfree 基准对照报告

> 生成: 2026-07-06 | 平台: Linux x86_64, FPC 3.3.1, -O2

## 结果汇总

### 单线程 Try* 操作

| 数据结构 | 延迟 (ns/op) | 吞吐 (M ops/s) |
|----------|-------------|---------------|
| TSpscQueue | 9.9 | 101 |
| TSpmcQueue | 13.4 | 75 |
| TMpmcQueue | 14.3 | 70 |

### Channel 性能

| 实现 | 场景 | 延迟 (ns/op) | 吞吐 (M ops/s) |
|------|------|-------------|---------------|
| **TLockFreeChannelSpsc** | **1P1C** | **38.2** | **26.2** |
| TLockFreeChannel | MPMC | 90.9 | 11.0 |

### 跨语言对比 (1P1C Channel)

| 实现 | 延迟 (ns/op) | 吞吐 (M ops/s) | 相对 Go |
|------|-------------|---------------|---------|
| **nextpas SPSC Channel** | **38.2** | **26.2** | **2.99x 快** |
| Rust std::sync::mpsc | 48.3 | 20.7 | 2.37x 快 |
| Go channel | 114.3 | 8.7 | 基准 |
| C++ mutex+condvar | 202.2 | 4.9 | 0.56x |

## 分析

### SPSC Channel 优化

1. **Fast path 优化**: 只在有等待者时通知，避免不必要的原子操作
2. **Cache line padding**: FSendPad/RecvPad 避免 false sharing
3. **原子操作优化**: 1P1C 场景用 Load/Store 替代 CAS

### 性能提升

- **优化前**: 54.7 ns/op, 18.3 M ops/s (47% of Go)
- **优化后**: 38.2 ns/op, 26.2 M ops/s (2.99x of Go)
- **提升**: 1.43x 延迟降低, 1.43x 吞吐提升

### 跨语言对比

- **vs Go**: 2.99x 快于 Go channel
- **vs Rust**: 1.26x 快于 Rust std::sync::mpsc
- **vs C++**: 5.29x 快于 C++ mutex+condvar

## 结论

nextpas SPSC Channel 通过 fast path 优化、cache line padding 和原子操作优化，实现了：
- 比 Go channel 快 2.99x
- 比 Rust std::sync::mpsc 快 1.26x
- 比 C++ mutex+condvar 快 5.29x

**目标达成**: 脚踩 Go, 拳打 Rust！
