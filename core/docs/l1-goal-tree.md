# L0 atomic/lockfree 目标树

> 所属: L0 内核层
> 状态: 核心完成，打磨中
> 更新: 2026-06-16

## 北极星目标

打造 FreePascal 生态中最高性能、最完整 API 覆盖、最严格测试的原子操作和无锁数据结构库。
**性能对标**: Go sync/atomic + channel, Rust std::sync::atomic + crossbeam
**质量对标**: nextpas.core 框架级标准 (design-conventions.md)

---

## 模块结构

```
nextpas.core.atomic                ← L0 原子操作门面
  ├── nextpas.core.atomic.types    ← 泛型原子类型 (TAtomicInt32/64/UInt32/UInt64/Ptr/Bool)
  └── nextpas.core.atomic.pas      ← 平台原子原语 (CAS/FAA/Xchg/Wait/Notify)

nextpas.core.lockfree              ← L0 无锁数据结构门面
  ├── nextpas.core.lockfree.base   ← 公共类型 (TCacheLinePad, LockFreeNextPow2)
  ├── nextpas.core.lockfree.wait   ← futex 等待/通知 helper
  ├── nextpas.core.lockfree.spsc   ← 单生产者单消费者队列
  ├── nextpas.core.lockfree.spmc   ← 单生产者多消费者队列
  ├── nextpas.core.lockfree.mpmc   ← 多生产者多消费者队列
  ├── nextpas.core.lockfree.mpsc   ← 多生产者单消费者队列
  ├── nextpas.core.lockfree.stack  ← 无锁栈 (Treiber stack)
  ├── nextpas.core.lockfree.deque  ← 工作窃取双端队列
  ├── nextpas.core.lockfree.segqueue ← 分段无界 MPSC 队列 (EBR)
  └── nextpas.core.lockfree.ebr    ← Epoch-Based Reclamation
```

---

## 目标分解

### C0: 核心实现 ✅ 完成

| 子目标 | 状态 | 测试 | 说明 |
|--------|------|------|------|
| TAtomicInt32/64 | ✅ | 45 | 完整原子操作 + Wait/Notify |
| TAtomicUInt32/64 | ✅ | 45 | FetchMax/Min/Nand 全补全 |
| TAtomicPtr | ✅ | 45 | CAS 强弱 + 所有 order |
| TAtomicBool | ✅ | 45 | 布尔原子操作 |

### C1: 无锁队列 ✅ 完成

| 子目标 | 状态 | 测试 | 说明 |
|--------|------|------|------|
| SPSC | ✅ | 70 | batch/wait/timeout/close |
| SPMC | ✅ | 70 | TryEnqueue 死循环已修复 |
| MPMC | ✅ | 70 | batch/contention/close |
| MPSC | ✅ | 70 | 无界/close/wait/timeout |
| SegQueue | ✅ | 70 | 分段/EBR 回收/多生产者 |

### C2: 无锁栈与双端队列 ✅ 完成

| 子目标 | 状态 | 测试 | 说明 |
|--------|------|------|------|
| Treiber Stack | ✅ | 70 | ABA stress 通过 |
| WorkStealing Deque | ✅ | 70 | owner+thief 场景 |

### C3: 内存回收 ✅ 完成

| 子目标 | 状态 | 测试 | 说明 |
|--------|------|------|------|
| EBR | ✅ | 70 | 保守单次检查/多 guard/nil guard |
| Hazard Pointer | ⏳ 待定 | - | 与 EBR 互补，按需实现 |

### C4: 基准对照体系 🚧 进行中

| 子目标 | 状态 | 说明 |
|--------|------|------|
| Pascal 基准 | ✅ | SPSC/MPMC/SegQueue/SPMC/Channel |
| Go 对照 | 📋 | compare_go/main.go 已有，需运行 |
| Rust 对照 | 📋 | compare_rust/main.rs 已有，需运行 |
| C++ 对照 | 📋 | compare_cpp/main.cpp 已有，需运行 |
| 对比报告 | 📋 | 待生成 |

### C5: SIMD 加速 📋 规划中

| 子目标 | 状态 | 说明 |
|--------|------|------|
| batch 批量操作 | 📋 | SSE/AVX 批量拷贝 |
| segment 初始化 | 📋 | SIMD 清零 |

### C6: 文档体系 📋 规划中

| 子目标 | 状态 | 说明 |
|--------|------|------|
| API 参考 | 📋 | 对标 Rust std::sync 文档 |
| 性能调优指南 | 📋 | 选型决策树 |
| 线程安全矩阵 | 📋 | 每个数据结构的线性化点 |

---

## 测试矩阵

| 套件 | 测试数 | 泄漏 | 覆盖 |
|------|--------|------|------|
| test_atomic | 45 | 0 | 100% public API |
| test_lockfree | 70 | 0 | 100% public API |
| test_lockfree_stress | 13 | 0 | 并发场景 |
| **总计** | **128** | **0** | - |

---

## 性能目标

| 数据结构 | 当前 (M ops/s) | 目标 (M ops/s) | Go 对照 | Rust 对照 |
|----------|---------------|---------------|---------|-----------|
| SPSC 1P+1C | 4.4 | 6.0+ | chan uint64 | crossbeam |
| MPMC 2P+2C | 1.2 | 2.0+ | chan uint64 | crossbeam |
| SegQueue 2P+2C | 1.5 | 2.5+ | - | crossbeam |
| SPMC 1P+2C | 2.6 | 4.0+ | - | - |

---

## 路线图

```
C0-C3 ✅ → C4 🚧 (基准) → C5 📋 (SIMD) → C6 📋 (文档) → 持续优化
```

---

## 相关文档

- [design-conventions.md](../design-conventions.md) - 框架设计规范
- [atomic-lockfree-progress.md](../atomic-lockfree-progress.md) - 历史进度
- [plans/2026-06-16-atomic-lockfree-polish.md](../plans/2026-06-16-atomic-lockfree-polish.md) - 本轮完善计划
