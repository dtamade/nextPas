# L0 atomic/lockfree 目标树

> 所属: L0 内核层 | 更新: 2026-06-16

## 北极星

打造 FreePascal 生态中最高性能、最完整 API 覆盖、最严格测试的原子操作和无锁数据结构库。
性能对标: Go channel + Rust crossbeam

---

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
