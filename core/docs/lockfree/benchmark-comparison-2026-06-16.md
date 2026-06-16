# Lockfree 基准对照报告

> 生成: 2026-06-16 | 平台: Linux x86_64 (Intel i7-12700H)

## 结果汇总

| Scenario | Pascal | Go | C++ | Rust |
|----------|--------|----|-----|------|
| SPSC 1P+1C | 4.40 M ops/s | 4.44 M ops/s | 5.02 M ops/s | TBD |
| MPMC 2P+2C | 1.29 M ops/s | 1.33 M ops/s | 1.37 M ops/s | TBD |
| SegQueue 2P+2C | 1.50 M ops/s | N/A | N/A | TBD |
| SPMC 1P+2C | 2.60 M ops/s | N/A | N/A | TBD |
| Mutex Channel | 0.63 M ops/s | 1.33 M ops/s | N/A | TBD |

## 分析

- Pascal SPSC 达 C++ 的 87.6%，MPMC 达 C++ 的 94.2%
- Pascal SegQueue/SPMC 为独有数据结构
- Mutex Channel 差距大（Go channel runtime 优化），futex 替代可改善
