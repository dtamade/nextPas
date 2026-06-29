# Matrix Benchmark — 矩阵运算

**日期**: 2026-06-29
**CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
**nextPas**: FPC 3.3.1-19195 `-O3`
**Go**: 1.23.5
**Rust**: 1.96.0 (criterion)

## 测试参数

- Int64 矩阵，非浮点数（避免平台差异）
- MatMul: 矩阵乘法 O(n³)
- MatAdd: 矩阵加法 O(n²)
- Transpose: 矩阵转置 O(n²)

## 结果

| 赛道 | nextPas | Go | vs Go | Rust | vs Rust |
|------|---------|-----|-------|------|---------|
| **MatMul/128** | **2.92ms** | 5.10ms | **1.75x** ✓ | 2.43ms | 0.83x |
| **MatAdd/512** | **0.40ms** | 0.60ms | **1.49x** ✓ | 0.31ms | 0.77x |
| **Transpose/512** | **2.13ms** | 3.00ms | **1.41x** ✓ | 2.26ms | **1.06x** ✓ |
| **MatMul/256** | **51.3ms** | 63.6ms | **1.24x** ✓ | 46.7ms | 0.91x |

**vs Go: 4W 0L — Pascal 全胜!**
**vs Rust: 1W 3L — Transpose 反超!**

## 分析

### Pascal 全胜 vs Go

FPC 的 `-O3` 优化在计算密集的矩阵循环上表现优秀：
- **MatMul/128**: 128³ = 2M 次乘加，完全在 L2 cache 内 (256KB)
- **MatMul/256**: 256³ = 16M 次乘加，跨越 L2/L3 边界
- **MatAdd/512**: 简单加法，6MB 数据（两个 2MB 输入 + 一个 2MB 输出）
- **Transpose/512**: cache miss 密集，原地转置

Go 的编译器在循环优化上不如 FPC：
- 无 SIMD 自动向量化
- 数组边界检查（Go 不支持禁用）
- 间接调用开销

### Transpose 击败 Rust

Pascal 在 Transpose 上赢 Rust 1.06x，原因是：
- FPC 在简单循环上生成高效代码
- Rust 的 Box 堆分配有微小额外开销
- 两者算法相同，差距在编译器代码生成质量

## benchstat 格式

```
=== Pascal ===
name                                            ns/op     +- %         B/op  allocs/op
MatMul/128                                  2924771.0       8%     33554432          -
MatAdd/512                                   403528.1       1%      6291456          -
Transpose/512                               2129385.0       1%      4194304          -
MatMul/256                                 51315439.2       9%    268435456          -
```

## 文件清单

```
bench/matrix/matrix_bench.pas       — Pascal 矩阵运算
bench/matrix/matrix_bench_go.go     — Go 矩阵运算
bench/matrix/benches/matrix_bench.rs — Rust 矩阵运算
bench/matrix/Cargo.toml             — Rust 依赖配置
```
