# H5-1 Charter — net poll completion queue → T1 MPSC

> **Status**: **done / landed on lane**（2026-07-21 implement · 2026-07-26 Maintenance 终态）
> **Owner**: atomic-lockfree（跨模块触 `net.server`）
> **编号**: **H5-1**（**不是** R9）
> **依据**: READY「主战场在高层消费者」；consumer-audit；用户批准 Wave 0–2 方案
> **Evidence**: `test_net_server`（行为 + H5 source-contract）；挂入 `verify-h3-consumers`（`NET_SERVER_TEST_DIR`）；feat `fc0db1c0f`

---

## 0. 决策

| 项 | 决策 |
|----|------|
| 目标类型 | `TTcpServerPollCompletionQueue`（`nextpas.core.net.server.runtime`） |
| 原语 | `specialize TMpscQueueImpl<Pointer>`（T1 **MPSC**） |
| 为何 MPSC 非 SegQueue | **单消费者**（reactor `DrainPendingCompletions`）；多 worker 仅 Enqueue |
| 元素 | managed `ITcpServer*` **禁止**直接入队 → 堆节点 `PCompletionNode` + `Pointer`（同 H4-1） |
| 依赖方向 | `net` (L2) → `lockfree.mpsc` (L1) **合法**；禁止 lockfree → net |
| 对外 API | 保持 `Enqueue` / `Drain` / `Clear` 签名；readiness 调用方最小改动 |

---

## 1. 现状 → 目标

| | 现状 | 目标 |
|--|------|------|
| 同步 | `IMutex` + 动态数组 | 无锁 MPSC 入队；Drain 单线程 |
| 进度 | 锁并发 | 生产者 lock-free 入队；单消费者 drain |
| 生命周期 | Free 时丢数组 | `Close` → drain residual 节点 → Free |

---

## 2. 非目标

- 不改 HTTP H1 每连接出站状态机
- 不替换 `tls.ringbuffer.lockfree`（byte SPSC 旁路）
- 不扩 T2 门面 / R8 / 删 legacy CAS
- 不 invent R9

---

## 3. 生命周期

```
ReleaseRuntimeContext:
  WorkerHandoff.Shutdown   // 停 producer
  DrainPendingCompletions  // Complete 剩余
  CompletionQueue.Clear    // discard residual（接口释放）
  ConnWorkers.Shutdown

Destroy(CompletionQueue):
  Close MPSC → drain residual nodes → Free queue
```

Enqueue after Close：`TryEnqueue` 失败 → 释放节点（不泄漏 interface）。

---

## 4. 验收

- [x] 实现 + `test_net_server` 绿（41 + H5 source-contract）
- [x] source-contract：`lockfree.mpsc` + `TMpscQueueImpl` + `PCompletionNode` + `FQueue.Close`
- [x] 热路径无 `IMutex` 保护 completion 数组入队
- [x] consumer-audit / READY 登记第 4 消费者
- [ ] path-limited land（随本波提交）
## 5. 验证

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.net.server/test_net_server clean test
make -C core/tests/nextpas.core.lockfree verify-h3-consumers
make hygiene
```
