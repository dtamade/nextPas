# Atomic/Lockfree 模块完善计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将 atomic/lockfree 模块打磨到 nextpas.core 框架级标准：100% 接口测试覆盖、规范文档、基准对照。

**Architecture:** atomic (L0) + lockfree (L0) 已完成核心实现。本轮聚焦质量收口：修复已知 bug、补全测试覆盖、规范化文档、基准对照。

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, futex-based wait/notify

---

## 当前状态

| 维度 | 状态 | 说明 |
|------|------|------|
| 实现 | ✅ | atomic 45 tests, lockfree 61 tests, stress 13 tests, 0 leaks |
| SPMC bug | ✅ 已修 | TryEnqueue 满队列死循环，已修复并回归测试 |
| CAS helpers | ✅ | _cas_success_order/_cas_failure_order 已提取到 interface |
| UInt64 Fetch | ✅ | FetchMax/FetchMin/FetchNand 已补全 |
| EBR 文档 | ✅ | TOCTOU 安全约束已记录 |
| 冗余 WakeAll | ✅ | SPMC/SPSC 已清理 |

## 待办任务

### Task 1: SPMC/SPSC 代码质量审计

**目标**: 对照 design-conventions.md 审计代码风格

**检查项**:
- [ ] 2 空格缩进（无 Tab）
- [ ] 参数 `const` 修饰
- [ ] 变量 `L` 前缀
- [ ] 字段 `F` 前缀
- [ ] 注释 `{** ... *}` JavaDoc 风格
- [ ] begin/end Allman 风格
- [ ] 单元体积 < 800 行

**涉及文件**:
- `core/src/nextpas.core.lockfree.spmc.pas`
- `core/src/nextpas.core.lockfree.segqueue.pas`
- `core/src/nextpas.core.lockfree.ebr.pas`
- `core/src/nextpas.core.lockfree.wait.pas`

### Task 2: 测试覆盖审计

**目标**: 确保所有 public API 有测试覆盖

**SPMC 公共 API 检查**:
- [ ] TryEnqueue (基础 + 满队列)
- [ ] TryDequeue (基础 + 空队列)
- [ ] EnqueueWait (阻塞 + 唤醒)
- [ ] DequeueWait (阻塞 + 唤醒)
- [ ] EnqueueTimeout (超时 + 成功)
- [ ] DequeueTimeout (超时 + 成功)
- [ ] IsEmpty / IsFull / ApproxCount / Capacity
- [ ] Managed type 拒绝

**SegQueue 公共 API 检查**:
- [ ] Enqueue (单线程 + 多线程)
- [ ] TryDequeue (单线程 + 多线程)
- [ ] IsEmpty / ApproxCount
- [ ] Managed type 拒绝
- [ ] Segment 滚转
- [ ] EBR 并发回收安全

**EBR 公共 API 检查**:
- [ ] Create / Destroy
- [ ] Enter / Leave
- [ ] Retire
- [ ] Collect
- [ ] Guard Acquire / Release
- [ ] 并发 retire + collect 安全

### Task 3: 文档规范化

**目标**: 对照 design-conventions.md §12.5 规范化文档结构

**当前**: `docs/lockfree/README.md`, `docs/atomic/README.md`
**目标**: 确保 README 包含模块职责、API 入口、使用示例、线程安全契约

**检查项**:
- [ ] 模块职责说明
- [ ] API 入口列表
- [ ] 使用示例代码
- [ ] 线程安全契约
- [ ] 线性化点文档
- [ ] Close/Destroy 纪律
- [ ] EBR 安全约束

### Task 4: 基准对照

**目标**: 与 FPC RTL、Go、Rust 同等功能对比

**当前基准** (2026-06-15):
- SPSC 1P+1C: 4.4 M ops/sec
- MPMC 2P+2C: 1.2 M ops/sec
- SegQueue 2P+2C: 1.5 M ops/sec
- SPMC 1P+2C: 2.6 M ops/sec

**需要对照**:
- [ ] FPC RTL TThreadList / TFPObjectList (mutex-based)
- [ ] Go channels (buffered)
- [ ] Rust crossbeam-channel (bounded)
- [ ] Rust std::sync::mpmc

### Task 5: Stress 测试增强

**目标**: 补充 SPMC timeout 路径的并发测试

**新增测试**:
- [ ] SPMC 1P+4C EnqueueTimeout 竞争
- [ ] SegQueue 4P+4C 长时间运行 (100K+ items)
- [ ] EBR 并发 retire + collect (多线程)

---

## 执行顺序

```
Task 1 (代码审计) → Task 2 (测试覆盖) → Task 3 (文档) → Task 4 (基准) → Task 5 (stress)
```

每完成一个 Task，运行完整测试套件确认无回归，然后提交 git。

## 验证命令

```bash
# 完整测试
make -C core/tests/nextpas.core.atomic/test_atomic clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test

# 基准
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
```
