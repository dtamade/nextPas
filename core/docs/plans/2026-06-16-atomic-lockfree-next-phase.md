# Atomic/Lockfree 下一阶段工作清单

> 创建: 2026-06-16 | 状态: 🚧 执行中

## Phase 1: 基准对照体系 (当前)

- [ ] Task 1.1: 创建自动化基准对比脚本 `run_comparison.sh`
- [ ] Task 1.2: 补全 SPMC 和 EBR 基准场景
- [ ] Task 1.3: 运行首次完整对比并生成报告

## Phase 2: 性能优化

- [ ] Task 2.1: 消除 SPMC 双次通知冗余
- [ ] Task 2.2: SPSC/MPMC 批量操作 SIMD 加速
- [ ] Task 2.3: SegQueue 预分配优化
- [ ] Task 2.4: Cache Line 对齐审计

## Phase 3: 数据结构扩展

- [ ] Task 3.1: Hazard Pointer
- [ ] Task 3.2: 无锁 MPMC Channel (对标 Go chan)
- [ ] Task 3.3: 无锁 HashMap (分片 SwissTable)

## Phase 4: 文档与推广

- [ ] Task 4.1: 性能对比报告
- [ ] Task 4.2: API 参考手册
- [ ] Task 4.3: 选型决策树
