# nextpas.core.lockfree 代码契约

> 模块路径: `core/src/nextpas.core.lockfree.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

无锁数据结构集合。提供 SPSC/MPMC 队列、无锁栈、无锁哈希表、
epoch-based reclamation (EBR)、hazard pointer 和 channel。

---

## 数据结构

| 类型 | 单元 | 特性 |
|------|------|------|
| TSpscQueue<T> | `spsc.pas` | 单生产者单消费者队列 |
| TMpmcQueue<T> | `mpmc.pas` | 多生产者多消费者队列 |
| TLockFreeStack<T> | `stack.pas` | 无锁栈 |
| TMpscQueue<T> | `mpsc.pas` | 多生产者单消费者队列 |
| TSpmcQueue<T> | `spmc.pas` | 单生产者多消费者队列 |
| TLockFreeDeque<T> | `deque.pas` | 无锁双端队列 |
| TLockFreeHashMap<K,V> | `hashmap.pas` | 无锁哈希表 |
| TSegQueue<T> | `segqueue.pas` | 分段队列 |
| TChannel<T> | `channel.pas` | Go 风格 channel |

## 内存回收

| 类型 | 单元 | 特性 |
|------|------|------|
| TEbrDomain/TEbrGuard | `ebr.pas` | Epoch-based reclamation |
| THazardDomain | `hazard.pas` | Hazard pointer |

---

## 线程安全

- **所有数据结构完全线程安全**
- 无锁设计，基于 CAS 原子操作
- EBR/Hazard 保证安全内存回收

---

## 依赖关系

- 依赖: base, atomic, mem
- 被依赖: net.server, http (连接池), collections.concurrent

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
