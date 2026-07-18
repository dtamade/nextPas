# Atomic & Lockfree 长期研究路线图

> 创建: 2026-07-08 | 更新: 2026-07-17
> **状态**: 研究线（= 主路线图 **R8**）· **非默认推进**
> **主线请看** [`roadmap.md`](roadmap.md)。本文仅 NUMA / TSX / TLA+ 研究扩展。
>
> **当前诚实状态（优先读）**：[`r8-research-status.md`](r8-research-status.md)
> — Phase 1–2（NUMA / RTM / TLA 基线）已落地；**NUMA Phase 3 线程亲和 residual / 未完成**；
> R8 **不进**默认门面；不污染 `verify-t1`。本文保留历史计划细节，冲突时以 r8-research-status + CONTRACT 为准。

## 1. 概述

本文档规划 atomic-lockfree 模块的三项长期研究任务：

| 任务 | 目标 | 预计工时 | 状态 |
|------|------|----------|------|
| NUMA 感知 | 针对 NUMA 架构优化内存分配和数据布局 | 40h | ✅ Phase 1-2 完成 |
| 硬件事务内存 | Intel TSX 支持，提升并发性能 | 40h | ✅ Phase 1-2 完成 |
| 形式化验证 | TLA+ 模型验证关键算法正确性 | 80h | ✅ Phase 1-2 完成 |

---

## 2. NUMA 感知优化

### 2.1 目标

- 检测系统 NUMA 拓扑（节点数、CPU 映射）
- 在特定 NUMA 节点上分配内存
- 数据结构按 NUMA 节点分片
- 线程亲和性绑定

### 2.2 实现计划

#### Phase 1: NUMA 拓扑检测 (8h)

```
core/src/nextpas.core.numa.pas          ← NUMA 拓扑检测接口
core/src/nextpas.core.numa.linux.pas    ← Linux /sys/devices/system/node 实现
core/src/nextpas.core.numa.windows.pas  ← Windows GetNumaProcessorNode 实现
```

**API 设计**:

```pascal
type
  TNumaNode = record
    Id: Integer;
    CpuCount: Integer;
    Cpus: array of Integer;
  end;

function NumaNodeCount: Integer;
function NumaGetNodeForCpu(ACpuId: Integer): Integer;
function NumaGetCurrentNode: Integer;
function NumaAllocOnNode(ASize: PtrUInt; ANode: Integer): Pointer;
procedure NumaFreeOnNode(APtr: Pointer; ASize: PtrUInt; ANode: Integer);
```

#### Phase 2: NUMA 感知数据结构 (16h) ✅

修改 HashMap/SkipList/BTree 按 NUMA 节点分片：

```pascal
type
  TNumaShardedHashMap = class
  private
    FShards: array of TShard;  // 每个 NUMA 节点一组分片
    FNodeCount: Integer;
  public
    function GetShard(AKey: UInt64): Integer;  // 基于 key + 当前节点
  end;
```

**实现**:
- `nextpas.core.lockfree.hashnuma.pas`: NUMA 感知 HashMap
- 按 NUMA 节点分片，每个节点独立的 HashMap 实例
- 哈希值路由到对应节点，减少跨节点访问
- 38 个测试全通过

#### Phase 3: 线程亲和性 (8h)

```pascal
procedure NumaSetThreadAffinity(AThread: TThread; ANode: Integer);
function NumaGetOptimalNode: Integer;  // 返回负载最低的节点
```

#### Phase 4: 测试与基准 (8h)

- NUMA 拓扑检测测试
- 跨节点性能对比
- 负载均衡验证

---

## 3. 硬件事务内存 (Intel TSX)

### 3.1 目标

- 使用 Intel TSX (Restricted Transactional Memory) 替代锁
- 提供自动回退路径（TSX 不可用时使用 CAS）
- 针对 HashMap/SkipList 的读多写少场景优化

### 3.2 实现计划

#### Phase 1: TSX 基础设施 (12h)

```
core/src/nextpas.core.lockfree.rtm.pas    ← RTM 内联汇编封装
core/src/nextpas.core.lockfree.rtm.pas    ← 事务内存抽象
```

**API 设计**:

```pascal
type
  TRtmStatus = (rtmStarted, rtmAborted, rtmRetry, rtmFallback);

function RtmBegin: TRtmStatus;
procedure RtmEnd;
procedure RtmAbort(AAbortCode: Byte = 0);
function RtmIsSupported: Boolean;
```

**内联汇编 (x86_64)**:

```pascal
function RtmBegin: TRtmStatus; assembler;
asm
  mov rax, 0
  .byte $c7, $f8  ; XBEGIN
  // ... fallback path
end;
```

#### Phase 2: 事务内存数据结构 (16h) ✅

为 HashMap 添加 TSX 优化的读路径：

```pascal
function TShardedHashMap.Get(AKey: UInt64): Pointer;
var
  LStatus: TRtmStatus;
begin
  repeat
    LStatus := RtmBegin;
    case LStatus of
      rtmStarted:
        begin
          Result := DoGet(AKey);
          RtmEnd;
          Exit;
        end;
      rtmRetry:
        Continue;
      rtmFallback:
        begin
          // CAS fallback
          Result := DoGetWithCAS(AKey);
          Exit;
        end;
    end;
  until False;
end;
```

#### Phase 3: 测试与基准 (12h)

- TSX 可用性检测
- 并发读性能对比
- 冲突回退测试

---

## 4. 形式化验证

### 4.1 目标

- 为关键算法建立 TLA+ 模型
- 验证无锁算法的正确性（无死锁、无饥饿、线性化）
- 生成测试用例覆盖边界情况

### 4.2 实现计划

#### Phase 1: SPSC 队列 TLA+ 模型 (20h)

```
core/docs/lockfree/formal/tla/SpscQueue.tla       ← SPSC 队列模型
core/docs/lockfree/formal/tla/SpscQueue.cfg        ← 配置文件
core/docs/lockfree/formal/tla/SpscQueueTest.tla    ← 测试属性
```

**关键属性**:

```tla
\* 无死锁
NoDeadlock == <>[](\E p \in Producers: p.state = "ready")
             \/ <>[](\E c \in Consumers: c.state = "ready")

\* 线性化
Linearizability == \A op1, op2 \in Operations:
  (op1.start < op2.start) => (op1.linearization < op2.linearization)

\* FIFO 顺序
FifoOrder == \A e1, e2 \in Enqueued:
  (e1.time < e2.time) => (e1.position < e2.position)
```

#### Phase 2: MPMC 队列 TLA+ 模型 (20h) ✅

更复杂的模型，包含：
- CAS 原子操作
- ABA 问题检测
- 内存回收 (EBR) 安全性

#### Phase 3: Channel TLA+ 模型 (20h) ✅

包含：
- 阻塞/超时语义
- Close 语义
- Select 多路复用

#### Phase 4: 测试生成 (20h) ✅

从 TLA+ 模型生成 Pascal 测试用例，覆盖：
- 所有可能的交错顺序
- 边界条件（满/空/单元素）
- 并发冲突场景

**实现**:
- `test_lockfree_formal.lpr`: 基于 TLA+ 模型的测试用例
- 覆盖 TypeOK、FIFO 顺序、边界、空队列、Close 语义、Resize 安全
- 83 个测试全通过

---

## 5. 优先级与依赖

```
Phase 1: NUMA 拓扑检测 (无依赖)
    ↓
Phase 2: TSX 基础设施 (无依赖)
    ↓
Phase 3: NUMA 感知数据结构 (依赖 Phase 1)
    ↓
Phase 4: TSX 数据结构优化 (依赖 Phase 2)
    ↓
Phase 5: TLA+ SPSC 模型 (无依赖)
    ↓
Phase 6: TLA+ MPMC 模型 (依赖 Phase 5)
    ↓
Phase 7: TLA+ Channel 模型 (依赖 Phase 6)
```

---

## 6. 验证标准

### 6.1 NUMA 感知

- [ ] 正确检测 NUMA 节点数
- [ ] 内存分配在指定节点
- [ ] 跨节点访问性能提升 ≥20%
- [ ] 所有现有测试通过

### 6.2 硬件事务内存

- [ ] TSX 可用性正确检测
- [ ] 读操作性能提升 ≥30%
- [ ] 冲突回退正确处理
- [ ] 所有现有测试通过

### 6.3 形式化验证

- [ ] TLA+ 模型通过 TLC 模型检查
- [ ] 无死锁/无饥饿属性验证通过
- [ ] 生成的测试覆盖所有边界情况
- [ ] 文档完整

---

## 7. 风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| TSX 硬件不可用 | 高 | 提供 CAS 回退路径 |
| NUMA 检测 API 差异 | 中 | 抽象层隔离平台差异 |
| TLA+ 模型复杂度 | 高 | 分阶段建模，先简后繁 |
| 性能提升不明显 | 中 | 基准测试验证，可选启用 |

---

## 8. 交付物

### 8.1 代码

- `nextpas.core.numa.pas` - NUMA 拓扑检测
- `nextpas.core.lockfree.rtm.pas` - Intel TSX 封装
- 修改 HashMap/SkipList 支持 NUMA 分片

### 8.2 文档

- NUMA 使用指南
- TSX 使用指南
- TLA+ 模型说明

### 8.3 测试

- NUMA 检测测试
- TSX 功能测试
- TLA+ 生成的边界测试
