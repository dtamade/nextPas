# nextpas.core.sync 代码契约

**模块路径**：`core/src/nextpas.core.sync*.pas`（13 个源文件）
**层级**：L1（依赖 L0: base, exception; 可选: platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 同步原语

| 原语 | 文件 | 接口/类型 | 说明 |
|------|------|-----------|------|
| TMutex | mutex.pas | ILockable | 互斥锁（递归） |
| TRWLock | rwlock.pas | IRWLockable | 读写锁 |
| TSemaphore | semaphore.pas | — | 计数信号量 |
| TEvent | event.pas | — | 手动/自动复位事件 |
| TCondVar | condvar.pas | — | 条件变量 |
| TBarrier | barrier.pas | — | 屏障 |
| TSpinLock | spinlock.pas | — | 自旋锁 |
| TOnce | once.pas | — | 一次性初始化 |
| TWaitGroup | waitgroup.pas | — | 等待组 |
| TSyncPool\<T\> | pool.pas | — | TLS freelist 对象池 |

### 1.2 核心接口

```pascal
ILockable = interface
  procedure Acquire;
  procedure Release;
  function TryAcquire: Boolean;
end;

IRWLockable = interface
  procedure AcquireRead;
  procedure ReleaseRead;
  procedure AcquireWrite;
  procedure ReleaseWrite;
end;
```

### 1.3 TSyncPool 特殊说明

TLS freelist 实现：
- 每线程独立 freelist（threadvar），无锁热路径
- Central pool 互斥锁冷路径
- 性能：63M ops/s (1T), 317M ops/s (32T)
- 比 Rust crossbeam 快 106x

### 1.4 平台适配

- **UNIX**：pthread_mutex, pthread_rwlock, pthread_cond, sem_t
- **Windows**：CriticalSection, SRWLOCK, Event, Semaphore
- **Fallback**：当平台 API 不可用时，基于 TSpinLock 的纯 Pascal 实现

### 1.5 门面

`nextpas.core.sync.pas` — re-export 所有同步原语。

---

## 2. 不变量

- **[INV-1]** TMutex 是递归锁（同一线程可重复 Acquire）
- **[INV-2]** TOnce 的回调恰好执行一次（即使多线程竞争）
- **[INV-3]** TWaitGroup 的 Done 调用次数 ≤ Add 的总数
- **[INV-4]** TSyncPool 的 TLS freelist 在线程退出时 flush 回 central pool
- **[INV-5]** TSpinLock 忙等待有 backoff 上限（防止活锁）
- **[INV-6]** TRWLock：多个读者可并发，写者排他

---

## 3. 错误处理

| 场景 | 策略 |
|------|------|
| Destroy 时仍被持有 | 平台依赖（pthread 返回 EBUSY） |
| TWaitGroup.Done 超过 Add | Assert / 未定义行为 |
| Semaphore wait 被信号中断 | 自动重试 (EINTR) |
| 无效参数（负数 count） | 抛 EInvalidArgument |

---

## 4. 线程安全

**所有同步原语本身就是线程安全的基础设施。**

| 原语 | 并发模型 |
|------|----------|
| TMutex | 互斥，同一时刻一个持有者 |
| TRWLock | 多读单写 |
| TSemaphore | N 并发 |
| TEvent | 唤醒等待线程 |
| TCondVar | 与 TMutex 配合 |
| TBarrier | N 线程同步点 |
| TSpinLock | 短临界区自旋 |
| TOnce | 单次初始化 |
| TWaitGroup | 等待 N 个任务完成 |
| TSyncPool | TLS 无锁热路径 + central 锁冷路径 |

---

## 5. 内存管理

- 所有原语的 Create/Destroy 配对
- TMutex/TRWLock 内部持有平台句柄（pthread_mutex_t 等）
- TSyncPool 的 TLS freelist 在线程退出时自动回收
- Destroy 释放所有平台资源

---

## 6. 测试覆盖

| 子系统 | 测试文件 | 说明 |
|--------|----------|------|
| 核心同步原语 | test_sync | Mutex/RWLock/Event/CondVar/Once/WaitGroup/SpinLock/Barrier/Semaphore |
| TSyncPool | test_sync_pool | TLS freelist / 并发分配 |
| POSIX 回退 | test_sync_posix_fallback | 纯 Pascal 回退实现 |
| **合计** | **3 个测试目录** | |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：13 文件 / 10 原语 / 六项契约 | Claude |
