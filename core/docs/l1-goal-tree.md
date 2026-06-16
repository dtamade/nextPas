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
- [x] Pascal/Go/C++ 基准运行
- [ ] Rust 基准 (crossbeam)
- [ ] 完整对比报告

### C5: SIMD 加速 📋 规划中
- [ ] Codex 已否决通用 SIMD batch 方案
- [ ] 替代: SPSC 连续段 Move 优化

### C6: 文档体系 📋 规划中
- [ ] API 参考手册
- [ ] 选型决策树

---

## 测试矩阵

| 套件 | 测试数 | 泄漏 |
|------|--------|------|
| test_atomic | 45 | 0 |
| test_lockfree | 77 | 0 |
| test_lockfree_stress | 13 | 0 |
| **总计** | **135** | **0** |

## 性能目标

| 数据结构 | 当前 (M ops/s) | 目标 |
|----------|---------------|------|
| SPSC 1P+1C | 4.4 | 6.0+ |
| MPMC 2P+2C | 1.29 | 2.0+ |
| SegQueue 2P+2C | 1.5 | 2.5+ |
| SPMC 1P+2C | 2.6 | 4.0+ |

## 证据级别报告

| 模块 | 定位 | 证据 |
|------|------|------|
| `atomic` | 原子操作 (Load/Store/CAS/Fetch*, 全内存序) | source-contract / forced compile / focused runtime: atomic 43/43 |
| `lockfree` | 无锁 (MPMC/SPSC/MPSC/Stack/Deque) | source-contract / focused runtime / stress: lockfree stress 12/12 |
