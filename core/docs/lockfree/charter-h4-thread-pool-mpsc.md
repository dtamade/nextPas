# H4-1 Charter — `thread.pool` Submit 路径接入 T1 MPSC

> **Status**: charter **open**（2026-07-20）— **未授权实现**直至本页验收勾选 + lane/总控确认
> **Owner**: atomic-lockfree（跨模块需 thread 侧配合验证）
> **编号**: **H4-1**（**不是** R9）
> **依据**: READY「Additional cross-module consumer wiring → requires new charter」

---

## 1. 目标

将 `nextpas.core.thread.pool`（**非** worksteal 池）的 **任务投递队列** 从「mutex + 内部列表」改为：

- 热路径：`nextpas.core.lockfree.mpsc`（`TMpscQueueImpl` / unmanaged 任务节点指针）
- 保留：worker 等待 / WaitAll / Shutdown 所需的 mutex/condvar（或等价）

**证明**：第三个跨模块 T1 消费者（H3-1 async MPSC、H3-5 worksteal deque 之后）。

---

## 2. 非目标

- 改 `thread.pool.worksteal`（H3-5 已完成）
- 改 http / net / async.loop 本切片
- T2 进默认门面；R8 生产化；删 legacy CAS；改 Closed 语义
- invent R9

---

## 3. 依赖与边界

| 规则 | 说明 |
|------|------|
| 方向 | `thread` → `lockfree.mpsc`；**禁止** lockfree → thread |
| 元素 | **unmanaged** 任务节点（`Pointer` / 堆上 task record），禁止 managed 直接入队 |
| 生命周期 | `Shutdown`：拒绝新 Submit → `FQueue.Close` → join workers → drain/Free 队列 → Free 池 |
| Progress | 池整体 = concurrent；MPSC try 路径 LF；WaitAll/空闲等待可阻塞 |

对齐：`async.loop` pending MPSC 模式；`Close → join → Free`（CONTRACT）。

---

## 4. API / 行为约束

1. 公共 API（`Submit` / `WaitAll` / `Shutdown` / worker 数）**行为兼容**现有测试。
2. Shutdown 后 Submit 失败语义与现实现一致（抛错或拒绝，文档化）。
3. 任务至少执行一次；不要求公平调度。
4. 可选：source-contract 钉 `uses nextpas.core.lockfree.mpsc`。

---

## 5. 测试与门

| 门 | 要求 |
|----|------|
| 行为 | `core/tests/nextpas.core.thread/test_thread`（或现有 pool 测试）扩展：多 Submit + WaitAll + Shutdown |
| 契约 | source-contract：MPSC uses + Close 在 Shutdown 路径 |
| 回归 | `verify-t1` 不破坏；可选新目标 `verify-h4-consumers` 或并入 h3-consumers 文档说明 |
| hygiene | `make hygiene` |

---

## 6. 风险

| 风险 | 缓解 |
|------|------|
| 关闭竞态（Submit vs Close） | Close 后 Enqueue 失败；worker 退出条件明确 |
| 空队列 busy-spin | worker 在 empty 时 condvar/wait，**不**纯 spin MPSC |
| 任务泄漏 | Destroy 前 drain 或文档要求 WaitAll |
| 跨 lane 冲突 | path-limited；只动 `thread.pool.pas` + 测试 + 本 charter 文档 |

---

## 7. 验收清单（实现切片）

- [ ] 实现 + 行为测绿
- [ ] Shutdown / Close 纪律可审计
- [ ] consumer-audit §2.7 更新
- [ ] READY / quality-parity 指针
- [ ] path-limited land

---

## 8. 实现授权

本文件 alone **不**授权改生产代码。
实现前：在 issue/会话中明确「**H4-1 implement approved**」，再开独立切片。

**备选（更高风险，本 charter 不覆盖）**：`net.server.threaded` 接入队列 — 需 net lane 联合 charter。
