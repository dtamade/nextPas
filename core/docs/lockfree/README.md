# nextpas.core.lockfree

`nextpas.core.lockfree` 提供 nextpas.core 内部可复用的无锁数据结构。当前模块优先服务
runtime/framework 内部热路径，而不是公开宣称完整替代 Rust std、Go std 或 C++ std 的并发容器。
所有结构只接受 unmanaged element type；`string`、interface、dynamic array 等 managed 类型会被拒绝。

## 模块分层

当前 live source set 由这些单元组成：

| 单元 | 职责 |
| --- | --- |
| `nextpas.core.lockfree.base` | 公共容量 helper 与自旋参数。 |
| `nextpas.core.lockfree.wait` | 数据/空间等待 helper，复用 atomic wait-address 平台 seam。 |
| `nextpas.core.lockfree.spsc` | `TSpscQueue<T>`，有界 single-producer/single-consumer ring queue。 |
| `nextpas.core.lockfree.mpmc` | `TMpmcQueue<T>`，有界 multi-producer/multi-consumer ring queue。 |
| `nextpas.core.lockfree.mpsc` | `TMpscQueue<T>`，无界 multi-producer/single-consumer linked queue。 |
| `nextpas.core.lockfree.stack` | `TLockFreeStack<T>`，有界 stack，内部使用 tagged index 处理 ABA-sensitive top/free-list。 |
| `nextpas.core.lockfree.deque` | `TWorkStealingDeque<T>`，有界 single-owner push/pop + multi-thief steal deque。 |
| `nextpas.core.lockfree` | 聚合 facade。 |

## API 边界

`TSpscQueue<T>` 只有一个 producer 和一个 consumer 可以并发使用。`TryEnqueue` / `TryDequeue`
是非阻塞操作；`EnqueueWait` / `DequeueWait` 通过 wait-address seam 阻塞；timeout 版本使用纳秒超时。
batch API 是连续单元素操作的批量便利方法，不表示整个 batch 具有一个共同线性化点。

`TMpmcQueue<T>` 支持多个 producer 和多个 consumer。队列是固定容量 ring，构造时把容量提升到
power-of-two。`Close` 会阻止新的 `TryEnqueue` 成功并唤醒等待者；consumer 仍可 drain 已发布元素。

`TMpscQueue<T>` 是多 producer、单 consumer 队列。`Enqueue` 是过程，不返回 close 结果；`Close`
只作为 consumer 等待唤醒和终止信号。调用方必须让 producer 协作停止、join producer，并 drain
队列后再销毁对象。

`TLockFreeStack<T>` 是固定容量 stack。push/pop 会先从内部 free-list 取得或归还 slot，因此不是
无界栈，也不动态分配节点。

`TWorkStealingDeque<T>` 是 work-stealing deque：owner 线程执行 `TryPush` / `TryPop`，thief
线程只执行 `TrySteal`。当前实现没有 close/wait surface。

## Linearization points

- `TSpscQueue<T>.TryEnqueue`：写入 slot 后，对 `FTailPublished` 的 release store 发布元素。
- `TSpscQueue<T>.TryDequeue`：读取 slot 后，对 `FHeadPublished` 的 release store 发布空间。
- `TMpmcQueue<T>.TryEnqueue`：成功 CAS `FEnqueuePos` 后取得 slot，随后对 slot `Sequence` 的
  release store 发布元素。
- `TMpmcQueue<T>.TryDequeue`：成功 CAS `FDequeuePos` 后取得 slot，随后对 slot `Sequence` 的
  release store 回收空间。
- `TMpscQueue<T>.Enqueue`：对 `FHead` 的 exchange 取得前驱节点，随后 release store 到前驱
  `Next` 发布节点。
- `TMpscQueue<T>.TryDequeue`：单 consumer 推进 `FTail` 并取得节点值；当队列处于 stub 修复路径时，
  当前实现依赖 producer 已通过 `Next` 发布节点。
- `TLockFreeStack<T>.TryPush`：free-list CAS 取得 slot，top CAS 发布该 slot。
- `TLockFreeStack<T>.TryPop`：top CAS 取得 slot，读取并清空 value 后，free-list CAS 归还 slot。
- `TWorkStealingDeque<T>.TryPush`：owner 写入 buffer 后，对 `FBottom` 的 release store 发布元素。
- `TWorkStealingDeque<T>.TryPop`：owner 递减 `FBottom`；最后一个元素需要 top CAS 与 thief 仲裁。
- `TWorkStealingDeque<T>.TrySteal`：成功 CAS `FTop` 取得元素。

这些点是 source-contract 和当前实现说明，不是跨平台 runtime proof。

## ABA

`TLockFreeStack<T>` 把 32-bit index 和 32-bit tag 打包到 64-bit head 中。`FTop` 和 `FFreeHead`
都使用 tagged index，降低固定 slot 被快速 pop/push 后复用导致的 ABA 风险。

`TMpmcQueue<T>` 使用 per-slot sequence number 区分 ring slot 的生命周期；sequence 是 ring queue
的发布/回收 token。

`TWorkStealingDeque<T>` 使用 monotonic `FTop` / `FBottom` counter 和最后元素 CAS 仲裁。当前没有
hazard pointer 或 epoch reclamation，因为 deque 存储是固定数组。

## Memory reclamation

`TSpscQueue<T>`、`TMpmcQueue<T>`、`TLockFreeStack<T>` 和 `TWorkStealingDeque<T>` 都使用固定数组或固定
slot。它们不在 hot path 动态分配节点，并要求 `T` 为 unmanaged type。

`TMpscQueue<T>` 使用 `New` / `Dispose` 管理链表节点。该结构只有一个 consumer，因此 consumer 可以在
成功 dequeue 后释放旧 tail 节点。模块当前没有 hazard pointer、epoch reclamation 或 reference
count reclamation；安全边界依赖 single-consumer contract，以及销毁前 producer 已停止。

## Close/Destroy discipline

`TSpscQueue<T>` 和 `TMpmcQueue<T>` 的 `Close` 会设置 closed flag 并唤醒 data/space waiters。close 后
producer 侧等待操作应返回失败，consumer 侧可继续 drain 已发布元素。

`TMpscQueue<T>` 的 `Close` 不会让 `Enqueue` 自动失败。它只唤醒等待中的 consumer，并让
`DequeueWait` / `DequeueTimeout` 在当前无元素时返回失败。销毁前必须满足：

1. 已调用 `Close`。
2. producer 已停止并 join。
3. consumer 已 drain 队列。

debug build 中 `TMpscQueue.Destroy` 保留 close-before-destroy assert，用来冻结这条纪律。

## Atomic dependency

lockfree 模块依赖 `nextpas.core.atomic` 的以下契约：

- `AtomicLoad32/64`、`AtomicStore32/64`、`AtomicCompareExchange64` 和 `AtomicExchange64` 的
  acquire/release/acq_rel/seq_cst 语义。
- `CpuPause` 作为自旋提示。
- `atomic_wait` / `atomic_notify_*` 背后的 `platform_wait_address32`、
  `platform_wake_address_one` 和 `platform_wake_address_all` seam。

`nextpas.core.lockfree.wait` 只等待 32-bit epoch 地址。不要在 lockfree 层自行扩展 64-bit 或 pointer
wait；如果要扩展，先设计 atomic/platform wait-address contract，再补 consumer gate。

## 验证

普通 lockfree 切片至少运行：

```bash
make hygiene
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
git diff --check
git status --short --branch
```

`test_lockfree` 包含 API 行为、close/timeout、managed type guard 和 source-contract 覆盖。
`test_lockfree_stress` 覆盖本地 Linux x86_64 上的多线程压力场景。没有目标机 runtime gate 时，只能声称
source-contract 或本机 Linux x86_64 runtime 证据，不能宣称其他平台已实机验证。

当前模块还缺少正式 benchmark harness；在补充 benchmark、平台、编译参数、输入规模和对照基线前，不应
写入性能胜过 Rust/Go/C++ 标准库的结论。
