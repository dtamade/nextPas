# Atomic/Lockfree 模块性能优化与扩展计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> **创建时间**: 2026-06-16
> **父计划**: core/docs/plans/2026-06-16-atomic-lockfree-polish.md (polish 已完成)

**Goal:** 将 atomic/lockfree 模块推向世界级水平 — 性能全面对标并超越 Go channel + Rust crossbeam，API 完整度对标 Rust std::sync。

**Architecture:** L0 atomic (原子操作原语) + L0 lockfree (无锁数据结构)，依赖 FPC RTL 和 futex。

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, futex-based wait/notify, SIMD (SSE/AVX/NEON)

---

## 当前状态

| 维度 | 状态 | 说明 |
|------|------|------|
| 核心实现 | ✅ | 7 个数据结构 + EBR + 原子类型 |
| 测试覆盖 | ✅ | 128 tests, 0 leaks, 100% API |
| 代码风格 | ✅ | const/缩进/JavaDoc 全部合规 |
| 基准框架 | ✅ | Pascal 基准 + Go/Rust/C++ 对照源 |
| 文档 | 🚧 | JavaDoc 完成，性能报告待补 |
| 性能 | 🚧 | 有基准数据，未与 Go/Rust 实战对比 |

---

## Phase 1: 基准对照体系 (2-3 轮)

### Task 1.1: 自动化基准对比脚本

**目标**: 一键运行 Pascal/Go/Rust/C++ 基准并生成对比报告

**文件**:
- Create: `core/benchmarks/nextpas.core.lockfree/bench_lockfree/run_comparison.sh`
- Modify: `core/benchmarks/nextpas.core.lockfree/bench_lockfree/Makefile`

**Step 1**: 创建 `run_comparison.sh`
```bash
#!/bin/bash
# 自动运行 Pascal/Go/Rust/C++ 基准并生成对比报告
set -euo pipefail

BENCH_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT="$BENCH_DIR/benchmark_report_$(date +%Y%m%d).md"

echo "# Lockfree Benchmark Comparison ($(date +%Y-%m-%d))" > "$REPORT"
echo "" >> "$REPORT"
echo "| Scenario | Pascal | Go | Rust | C++ | Winner |" >> "$REPORT"
echo "|----------|--------|----|------|-----|--------|" >> "$REPORT"

# Run Pascal benchmark
echo "Running Pascal benchmark..."
make -C "$BENCH_DIR" clean run > /tmp/pascal_bench.txt 2>&1

# Run Go benchmark
echo "Running Go benchmark..."
cd "$BENCH_DIR/compare_go" && go build -o /tmp/go_bench main.go && /tmp/go_bench > /tmp/go_bench.txt 2>&1

# Run Rust benchmark
echo "Running Rust benchmark..."
cd "$BENCH_DIR/compare_rust" && cargo run --release > /tmp/rust_bench.txt 2>&1

# Run C++ benchmark
echo "Running C++ benchmark..."
cd "$BENCH_DIR/compare_cpp" && g++ -O3 -std=c++17 -pthread main.cpp -o /tmp/cpp_bench && /tmp/cpp_bench > /tmp/cpp_bench.txt 2>&1

# Parse and generate report
echo "Generating report..."
# (parsing logic to extract numbers)
```

### Task 1.2: 补全 SPMC 和 EBR 基准场景

**目标**: 基准覆盖所有数据结构的典型并发模式

**文件**: `core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr`

**新增场景**:
- SPMC 1P+4C (当前只有 1P+2C)
- SPMC 1P+8C
- EBR retire+collect 吞吐 (单线程/多线程)
- SegQueue 4P+4C 高并发

### Task 1.3: 运行首次完整对比

**执行**: 运行 Task 1.1 脚本，生成基准对比报告
**输出**: `core/docs/lockfree/benchmark-comparison-2026-06-16.md`

---

## Phase 2: 性能优化 (3-5 轮)

### Task 2.1: 消除双次通知冗余 (M3)

**目标**: 优化 SPMC wait/timeout 路径的唤醒开销

**当前问题**: TryEnqueue 成功时调用 LockFreeNotifyData，之后 EnqueueWait 又调用 LockFreeWakeAll，epoch 递增两次，且 LockFreeWakeAll 无论有无等待者都做系统调用。

**文件**: `core/src/nextpas.core.lockfree.spmc.pas`

**优化方案**: 移除 wait/timeout 方法中的 LockFreeWakeAll，只依赖 TryEnqueue/TryDequeue 内部的 LockFreeNotifyData/LockFreeNotifySpace。

**Step 1**: 移除 EnqueueWait 中的 LockFreeWakeAll (line ~153)
**Step 2**: 移除 DequeueWait 中的 LockFreeWakeAll (line ~171)
**Step 3**: 移除 EnqueueTimeout 中的 LockFreeWakeAll (line ~186, ~198)
**Step 4**: 移除 DequeueTimeout 中的 LockFreeWakeAll (line ~220)
**Step 5**: 运行完整测试套件确认无回归
**Step 6**: 运行基准测量改进

### Task 2.2: SPSC/MPMC 批量操作 SIMD 加速

**目标**: 对 batch enqueue/dequeue 使用 SIMD 批量拷贝

**依赖**: nextpas.core.simd 模块 (L1)

**文件**: 
- `core/src/nextpas.core.lockfree.spsc.pas`
- `core/src/nextpas.core.lockfree.mpmc.pas`

### Task 2.3: SegQueue 预分配优化

**目标**: 减少 segment 分配开销

**文件**: `core/src/nextpas.core.lockfree.segqueue.pas`

**优化方案**: 
- 维护一个 segment 空闲链表（从已回收的 segment 复用）
- 预分配前几个 segment

### Task 2.4: Cache Line 对齐审计

**目标**: 确保所有热路径字段无 false sharing

**检查项**:
- SPSC: ✅ 已有 FPadProducer/FPadConsumer
- MPMC: ✅ 已有 FPadProducer/FPadConsumer
- SPMC: 检查 FEnqueuePos/FDequeuePos 对齐
- SegQueue: 检查 FHead/FTail 对齐
- Stack: 检查 FHead 对齐
- Deque: 检查 FBottom/FTop 对齐

---

## Phase 3: 数据结构扩展 (3-4 轮)

### Task 3.1: Hazard Pointer

**优先级**: 中
**目标**: 与 EBR 互补的内存回收方案

**文件**: `core/src/nextpas.core.lockfree.hazard.pas`

**API 设计**:
```pascal
type
  THazardDomain = class
    constructor Create(const ACount: PtrUInt);
    destructor Destroy; override;
    function Protect(const AIndex: PtrUInt; const APtr: Pointer): Pointer;
    procedure Clear(const AIndex: PtrUInt);
    procedure Retire(const AData: Pointer; const AReclaim: TLockFreeReclaimProc);
    procedure Collect;
  end;
```

### Task 3.2: 无锁 MPMC 有界通道 (Channel)

**优先级**: 高
**目标**: 对标 Go channel + Rust crossbeam::channel

**文件**: `core/src/nextpas.core.lockfree.channel.pas`

**特性**:
- 有界 MPMC
- select 多路复用
- close 广播
- 对标 Go channel API

### Task 3.3: 无锁 HashMap

**优先级**: 中
**目标**: 基于分片锁 + SwissTable 的并发 HashMap

**文件**: `core/src/nextpas.core.lockfree.hashmap.pas`

---

## Phase 4: 文档与推广 (2 轮)

### Task 4.1: 性能对比报告

**输出**: `core/docs/lockfree/benchmark-comparison.md`
**内容**: Pascal vs Go vs Rust vs C++ 的详细性能数据、分析、优化建议

### Task 4.2: API 参考手册

**输出**: `core/docs/lockfree/api-reference.md`
**内容**: 每个数据结构的使用示例、线程安全契约、性能特征

### Task 4.3: 选型决策树

**输出**: `core/docs/lockfree/selection-guide.md`
**内容**: 根据并发模式选择合适的数据结构

---

## 执行顺序

```
Phase 1 (基准) → Phase 2 (优化) → Phase 3 (扩展) → Phase 4 (文档)
```

## 验证命令

```bash
# 完整测试
make -C core/tests/nextpas.core.atomic/test_atomic clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test

# 基准
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run

# 完整对比 (需要 Go/Rust/C++ 工具链)
bash core/benchmarks/nextpas.core.lockfree/bench_lockfree/run_comparison.sh
```
