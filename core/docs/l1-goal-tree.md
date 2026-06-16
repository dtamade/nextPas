# L0 atomic/lockfree 目标树

> 最后更新: 2026-06-16 | 真相口径: source-contract / focused runtime / forced compile / CI matrix

## 北极星

打造 FreePascal 生态中最高性能、最完整 API 覆盖、最严格测试的原子操作和无锁数据结构库。
性能对标: Go channel + Rust crossbeam

---

| 模块 | 职责 | 状态 |
|------|------|------|
| `base` | 核心类型、异常、TByteSpan、契约 | ✅ 完成 |
| `errors` | 异常层级 (ENextPasError 体系) | ✅ 完成 |
| `platform` | OS API 封装 (posix/linux/darwin/windows) | ✅ 完成 (Tier 1 全绿) |
| `mem` | 内存管理 (IAllocator/Pool/Arena/StackPool) | ✅ 完成 |
| `atomic` | 原子操作 (Load/Store/CAS/Fetch*, 全内存序) | ✅ 完成 |
| `math` | 数学函数 (Min/Max/Clamp/Abs/Pow/Trig) | 🔶 M8 partial: source-contract + Linux focused runtime/heaptrc; Win64 forced compile; macOS/Windows host runtime and CI matrix pending |
| `simd` | SIMD 抽象 (SSE2/AVX2/NEON, 统一宽度 API) | ✅ 完成 |

## 目标分解

### C0: 核心原子类型 ✅
TAtomicInt32/64, TAtomicUInt32/64, TAtomicPtr, TAtomicBool | 45 tests, 0 leaks

### C1: 无锁队列 ✅
SPSC, SPMC, MPMC, MPSC, SegQueue | 70 tests, 0 leaks

### C2: 无锁栈与双端队列 ✅
Treiber Stack, WorkStealing Deque | ABA stress 通过

### C3: 内存回收 ✅
EBR (Epoch-Based Reclamation) | Hazard Pointer ⏳ 待定

### C4: 基准对照 🚧 进行中
- [ ] 自动化对比脚本
- [ ] 补全 SPMC/EBR 基准
- [ ] Go/Rust/C++ 实战对比
- [ ] 性能报告

### C5: SIMD 加速 📋 规划中
- [ ] batch 批量操作 SSE/AVX
- [ ] segment 初始化 SIMD 清零

### C6: 文档体系 📋 规划中
- [ ] API 参考手册
- [ ] 性能调优指南
- [ ] 选型决策树

---

## 测试矩阵

| 套件 | 测试数 | 泄漏 |
|------|--------|------|
| test_atomic | 45 | 0 |
| test_lockfree | 70 | 0 |
| test_lockfree_stress | 13 | 0 |
| **总计** | **128** | **0** |

## 性能目标

| 数据结构 | 当前 (M ops/s) | 目标 |
|----------|---------------|------|
| SPSC 1P+1C | 4.4 | 6.0+ |
| MPMC 2P+2C | 1.2 | 2.0+ |
| SegQueue 2P+2C | 1.5 | 2.5+ |
| SPMC 1P+2C | 2.6 | 4.0+ |
