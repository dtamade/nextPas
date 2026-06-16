# Atomic/Lockfree 模块完善计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 atomic/lockfree 模块打磨到 nextpas.core 框架级标准：100% 接口测试覆盖、规范文档、基准对照。

**Architecture:** atomic (L0) + lockfree (L0) 已完成核心实现。本轮聚焦质量收口：修复已知 bug、补全测试覆盖、规范化文档、基准对照。

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, futex-based wait/notify

---

## 当前状态

| 维度 | 状态 | 说明 |
|------|------|------|
| 实现 | ✅ | atomic 45 tests, lockfree 70 tests, stress 13 tests, 0 leaks |
| SPMC bug | ✅ 已修 | TryEnqueue 满队列死循环，已修复并回归测试 |
| CAS helpers | ✅ | _cas_success_order/_cas_failure_order 已提取到 interface |
| UInt64 Fetch | ✅ | FetchMax/FetchMin/FetchNand 已补全 |
| EBR 文档 | ✅ | TOCTOU 安全约束已记录 |
| 冗余 WakeAll | ✅ | SPMC/SPSC 已清理 |
| 测试覆盖 | ✅ | SPMC 11/11, SegQueue 6/6, EBR 10/10 API 全绿 |
| JavaDoc | ✅ | SPMC/SegQueue/EBR public API 全部文档化 |

### 合并状态
```
main HEAD: 6b850fb4b fix(lockfree): address code review findings (M1/M2/m2)
           954b2877a docs(lockfree): add JavaDoc comments to SPMC/SegQueue/EBR
           c78acd0c7 test(lockfree): add missing SPMC/SegQueue/EBR tests
```

---

## Task 1: 基准对照体系完善

**目标**: 自动化运行 Go/Rust/C++ 基准并生成对比报告

**当前基准** (2026-06-15):
- SPSC 1P+1C: 4.4 M ops/sec
- MPMC 2P+2C: 1.2 M ops/sec
- SegQueue 2P+2C: 1.5 M ops/sec
- SPMC 1P+2C: 2.6 M ops/sec

**待做**:
- [ ] 补全 SPMC 基准场景 (1P+4C, 1P+8C)
- [ ] 补全 EBR 性能基准 (retire/collect 吞吐)
- [ ] 运行 Go channel 对照基准
- [ ] 运行 Rust crossbeam 对照基准
- [ ] 生成性能对比报告

### Task 1.1: 补全 SPMC 和 EBR 基准
**文件**: `core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr`
**修改**: 添加 BenchSpmc(1P+4C), BenchEbr 场景

### Task 1.2: 运行 Go/Rust/C++ 对照基准
**执行**: 编译运行 compare_go/main.go, compare_rust/main.rs, compare_cpp/main.cpp

### Task 1.3: 生成性能对比报告
**输出**: `core/docs/lockfree/benchmark-comparison.md`

---

## Task 2: 无锁数据结构扩充

### Task 2.1: Hazard Pointer
**优先级**: 中
**说明**: 与 EBR 互补的内存回收方案，适用于读多写少场景
**文件**: `core/src/nextpas.core.lockfree.hazard.pas`

### Task 2.2: 无锁 HashMap
**优先级**: 高
**说明**: 基于 SwissTable 的并发安全 HashMap
**文件**: `core/src/nextpas.core.lockfree.hashmap.pas`

### Task 2.3: 无锁 SkipList
**优先级**: 中
**说明**: 无锁排序 Map，支持范围查询
**文件**: `core/src/nextpas.core.lockfree.skiplist.pas`

---

## Task 3: SIMD 加速优化

**目标**: 对关键路径应用 SIMD 优化

**候选路径**:
- [ ] SPSC/MPMC batch 操作 SIMD 批量拷贝
- [ ] SegQueue segment 初始化 SIMD 清零
- [ ] 原子操作批量版本 (batch CAS)

---

## Task 4: 文档体系完善

**目标**: 对标 Rust std::sync 和 crossbeam 文档质量

- [ ] API 参考手册
- [ ] 性能调优指南
- [ ] 线程安全契约矩阵
- [ ] 与 Go/Rust 对应物的映射表

---

## Task 5: 生态推广

- [ ] 在 nextPas 社区发布模块介绍
- [ ] 编写教程示例
- [ ] 集成到编译器自举路径 (HIR/LLVM 的并发数据结构)

---

## 执行顺序

```
Task 1 (基准) → Task 2 (扩充) → Task 3 (SIMD) → Task 4 (文档) → Task 5 (推广)
```

## 验证命令

```bash
# 完整测试
make -C core/tests/nextpas.core.atomic/test_atomic clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test

# 基准
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
```
