# nextPas Crypto Benchmark — 跨语言哈希性能

**日期**: 2026-06-29
**CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
**nextPas**: FPC 3.3.1 `-O3` — `nextpas.core.crypto.hash` (纯 Pascal)
**Go**: 1.23.5 — `crypto/md5`, `crypto/sha256`, `crypto/sha512` (手写汇编)
**Rust**: 1.96.0 — `md-5`, `sha2` crate (手写汇编 via `cpufeatures`)

## 测试参数

- Small: 1B × 10000 iterations (context reuse)
- Large: 1KB × 1000 iterations (context reuse)

## 结果

| 赛道 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| MD5/Small | 5.37ms | 1.58ms | 1.69ms | 3.4x 慢 | 3.2x 慢 |
| MD5/Large | 5.24ms | 1.82ms | 2.45ms | 2.9x 慢 | 2.1x 慢 |
| SHA256/Small | 9.35ms | 3.09ms | 3.99ms | 3.0x 慢 | 2.3x 慢 |
| SHA256/Large | 13.6ms | 3.65ms | 6.22ms | 3.7x 慢 | 2.2x 慢 |
| SHA512/Small | 13.7ms | 3.88ms | 4.66ms | 3.5x 慢 | 2.9x 慢 |
| SHA512/Large | 10.2ms | 2.82ms | 3.66ms | 3.6x 慢 | 2.8x 慢 |

## 差距分析

Pascal 比 Go 慢 3-3.7x，比 Rust 慢 2.1-3.2x。

**根本原因**: Go 和 Rust 的 SHA-256/MD5 使用**手写汇编** (amd64 SIMD)：
- Go: `crypto/sha256` 有 AVX2/SHA-NI 版本
- Rust: `sha2` crate 通过 `cpufeatures` 检测 CPU 特性，用汇编优化核心轮函数
- Pascal: **纯 Pascal** 实现，依赖编译器优化 Transform 循环

**差距不在于语言，而在于汇编优化**。Pascal 的纯算法实现能打到 Go/Rust 的 1/3 已经很好。

## 优化方向

1. **SHA-NI 硬件指令**: Intel Goldmont+ / AMD Zen+ 起支持，可直接用 `sha256rnds2` 指令
2. **手写汇编 Transform**: 用 FPC `assembler` 为 MD5/SHA-256 的核心轮函数写 asm
3. **SIMD 批量哈希**: 一次处理多个独立 hash（Pipelining）
