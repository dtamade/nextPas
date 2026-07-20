# H4-1 Charter — `thread.pool` 任务队列接入 T1 SegQueue

> **Status**: **implemented**（2026-07-20）
> **Owner**: atomic-lockfree
> **编号**: **H4-1**（**不是** R9）
> **依据**: READY 跨模块消费者需 charter；用户会话批准实现

---

## 0. 实现修正（相对初稿）

初稿写 **MPSC**，但 `TMpscQueue` 为 **严格单消费者**，而默认线程池有 **N 个 worker** 并发 `TryDequeue`。

**落地选择**：`specialize TSegQueueImpl<Pointer>`（T1 无界 **MPMC** segment 队列）存 `PTaskNode`：

| 项 | 值 |
|----|-----|
| 多 producer | Submit / SubmitDirect / SubmitBatch |
| 多 consumer | N workers |
| 元素 | unmanaged `Pointer` → 堆/池内 `TTaskNode`（节点内可持 managed `TThreadTask`） |
| 空闲等待 | mutex + condvar（非纯 spin） |
| Shutdown | Close queue → Broadcast → join workers → drain residual |

文件：`core/src/nextpas.core.thread.pool.pas`。

---

## 1. 目标（已达成）

第三个跨模块 T1 消费者：`thread.pool` → `lockfree.segqueue`（H3-1 async MPSC、H3-5 worksteal deque 之后）。

---

## 2. 非目标（仍成立）

- 不改 `thread.pool.worksteal`
- 不接 http/net 本切片
- 不扩 T2 门面 / R8 / 删 legacy CAS

---

## 3. 验收

- [x] 实现 + `test_thread` 行为测
- [x] source-contract：`lockfree.segqueue` + `FQueue.Close`
- [x] consumer-audit / READY 指针
- [ ] path-limited land（随本波提交）

---

## 4. 验证

```bash
make -C core/tests/nextpas.core.thread/test_thread clean test
make -C core/tests/nextpas.core.thread/test_worksteal clean test
```
