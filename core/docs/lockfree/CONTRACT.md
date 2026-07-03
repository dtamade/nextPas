# nextpas.core.lockfree 代码契约

**模块路径**：`core/src/nextpas.core.lockfree*.pas`（14 个源文件）
**层级**：L0（依赖 base, atomic）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| lockfree.base | TEbrRetiredNode, TEbrDomain, TEbrGuard 基础类型 |
| lockfree.ebr | 基于 Epoch 的内存回收 |
| lockfree.stack | TLockFreeStackImpl, TLockFreeStack 无锁栈 |
| lockfree.segqueue | 分段无锁队列 |
| lockfree.channel | 无锁通道 |
| lockfree.deque | TWorkStealingDequeImpl, TWorkStealingDeque 工作窃取双端队列 |
| lockfree.hashmap | 无锁哈希表 |
| lockfree.mpmc | 多生产者多消费者队列 |
| lockfree.mpsc | 多生产者单消费者队列 |
| lockfree.hazard | Hazard Pointer 内存回收 |
| lockfree.pas | 门面 re-export |

### 1.2 核心类型

```pascal
generic TLockFreeStack<T> = class
  procedure Push(const AValue: T);
  function TryPop(out AValue: T): Boolean;
end;

generic TWorkStealingDeque<T> = class
  procedure Push(const AValue: T);
  function TryPop(out AValue: T): Boolean;
  function TrySteal(out AValue: T): Boolean;
end;
```

---

## 2. 不变量

- EBR 保护期内的节点不被回收
- 无锁栈 Push/Pop 满足 LIFO 顺序
- 工作窃取双端队列：Owner 从尾部 Pop，Thief 从头部 Steal

---

## 3. 错误处理

- `TryPop`/`TrySteal` 空时返回 False
- 不抛异常

---

## 4. 线程安全

- 所有操作使用 CAS/原子指令，无锁
- EBR 使用 TLS 线程本地状态

---

## 5. 内存管理

- EBR 管理延迟回收，避免 ABA 问题
- Hazard Pointer 提供精确内存回收

---

## 6. 测试覆盖

- `test_lockfree`: Stack/SegQueue/Deque/Channel/HashMap/MPMC/MPSC/EBR/Hazard
