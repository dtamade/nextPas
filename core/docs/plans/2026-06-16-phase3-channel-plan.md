# Phase 3 Lockfree Channel 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现无锁 MPMC Channel，对标 Go channel 语义。

**Architecture:** 基于 SPSC 队列 + futex wait/notify，独立于 mutex-based TChannel。

**Tech Stack:** FreePascal 3.3.1, Linux x86_64, futex

---

## 设计决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 内部队列 | 独立 SPSC ring buffer | 复用成熟实现，避免重复造轮子 |
| Close 语义 | Go 风格：close 后仍可读已入队数据 | 业界标准 |
| Select | 暂不支持 | 需要多 channel 等待基础设施 |
| 与 TChannel 关系 | 独立实现，不替换 | lockfree 版本性能更高但无 select |

## API 设计

```pascal
type
  generic TLockFreeChannel<T> = class
    constructor Create(const ACapacity: PtrUInt);
    destructor Destroy; override;
    procedure Send(const AValue: T);
    function TrySend(const AValue: T): Boolean;
    function SendTimeout(const AValue: T; const ATimeoutNs: Int64): Boolean;
    function Receive(out AValue: T): Boolean;
    function TryReceive(out AValue: T): Boolean;
    function ReceiveTimeout(out AValue: T; const ATimeoutNs: Int64): Boolean;
    procedure Close;
    function IsClosed: Boolean;
    function ApproxLen: PtrUInt;
    function Capacity: PtrUInt;
  end;
```

## 实现策略

内部基于已有的 SPMC 队列（序列锁 ring buffer）：
- Send → TryEnqueue + wait on space epoch
- Receive → TryDequeue + wait on data epoch
- Close → 设置标志位 + wake all waiters

## 文件

- Create: `core/src/nextpas.core.lockfree.channel.pas`
- Modify: `core/src/nextpas.core.lockfree.pas` (facade)
- Test: `core/tests/nextpas.core.lockfree/test_lockfree/test_lockfree.lpr`

## 测试策略

1. 基础 Send/Receive
2. TrySend/TryReceive 非阻塞
3. SendTimeout/ReceiveTimeout
4. Close 唤醒等待者
5. Close 后可读剩余数据
6. 并发 2P+2C
7. Managed type 拒绝
8. 0 泄漏

## 执行步骤

### Step 1: 创建 channel.pas
### Step 2: 集成到 facade
### Step 3: 添加 8 个测试
### Step 4: 运行完整测试套件
### Step 5: 基准对照 Go channel
