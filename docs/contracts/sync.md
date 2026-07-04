# nextpas.core.sync 代码契约

> 模块路径: `core/src/nextpas.core.sync.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

同步原语门面。聚合 Mutex、RWLock、SpinLock、WaitGroup、CondVar、
Semaphore、Barrier、Event、Once 共 9 种同步原语。

---

## 接口签名

### 工厂函数

```pascal
function Mutex: IMutex;
function FutexMutex: IMutex;      { futex 优化版本 }
function RWLock: IRWLock;
function WaitGroup: IWaitGroup;
function CondVar: ICondVar;
function Once: IOnce;
function SpinLock: ISpinLock;
function Semaphore(AInitial: Int32 = 1): ISemaphore;
function Barrier(ACount: Int32): IBarrier;
function Event(AManualReset: Boolean = True): IEvent;
```

### 核心接口

```pascal
type
  ILock = interface
    procedure Acquire;
    procedure Release;
    function TryAcquire: Boolean;
  end;

  IMutex = interface(ILock)
    { 独占锁 }
  end;

  IRWLock = interface
    procedure AcquireRead;
    procedure AcquireWrite;
    procedure ReleaseRead;
    procedure ReleaseWrite;
    function TryAcquireRead: Boolean;
    function TryAcquireWrite: Boolean;
  end;

  IWaitGroup = interface
    procedure Add(ADelta: Int32);
    procedure Done;
    procedure Wait;
  end;

  ICondVar = interface
    procedure Wait(AMutex: IMutex);
    function WaitFor(AMutex: IMutex; ATimeoutMs: Int32): Boolean;
    procedure Signal;
    procedure Broadcast;
  end;

  IOnce = interface
    procedure DoCall(AProc: TOnceProc);
  end;

  ISemaphore = interface
    procedure Acquire;
    procedure Release;
    function TryAcquire: Boolean;
  end;

  IBarrier = interface
    function Wait: TBarrierWaitResult;
  end;

  IEvent = interface
    procedure WaitFor;
    function WaitForTimeout(AMs: Int32): Boolean;
    procedure Signal;
    procedure Reset;
  end;
```

---

## 后置条件

1. `Mutex`: 返回新互斥锁实例
2. `WaitGroup.Add(n)`: 计数器增加 n
3. `WaitGroup.Done()`: 计数器减 1
4. `WaitGroup.Wait()`: 阻塞直到计数器为 0
5. `Once.DoCall`: 回调只执行一次（首次调用）

---

## 错误语义

| 场景 | 行为 |
|------|------|
| WaitGroup 计数器为负 | raise EInvalidState |
| CondVar.Wait 非持有者调用 | 未定义行为 |
| Semaphore 释放超过获取次数 | raise EInvalidState |

---

## 线程安全

- **所有同步原语完全线程安全**
- 这是它们存在的唯一目的

---

## 内存管理

- 所有原语为接口类型，引用计数自动管理
- 底层使用 platform.sync 的 pthread/futex/CRITICAL_SECTION

---

## 测试覆盖

| 套件 | 路径 |
|------|------|
| test_sync_* | `core/tests/nextpas.core.sync/` |

---

## 依赖关系

- 依赖: `nextpas.core.platform.sync`（底层原语）
- 被依赖: collections (ConcurrentHashMap), lockfree, http, net

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
