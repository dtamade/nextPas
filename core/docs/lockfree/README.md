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

`nextpas.core.lockfree` facade exposes `TSpscQueue<T>`, `TMpmcQueue<T>`, `TMpscQueue<T>`,
`TLockFreeStack<T>`, and `TWorkStealingDeque<T>` so consumers can use the public lockfree
surface without importing implementation submodules directly.

The facade and submodule public names are wrapper classes over shared `*Impl<T>` implementation
bases. Keep variables and parameters on one public boundary; the wrappers are source-compatible
constructors, not Pascal type aliases.

## API 边界

`TSpscQueue<T>` 只有一个 producer 和一个 consumer 可以并发使用。`TryEnqueue` / `TryDequeue`
是非阻塞操作；`EnqueueWait` / `DequeueWait` 通过 wait-address seam 阻塞；timeout 版本使用纳秒超时。
batch API 是连续单元素操作的批量便利方法，不表示整个 batch 具有一个共同线性化点。
`TSpscQueue<T>.EnqueueBatch` returns 0 after `Close` and must not publish new items.

`TMpmcQueue<T>` 支持多个 producer 和多个 consumer。队列是固定容量 ring，构造时把容量提升到
power-of-two。`Close` 会阻止新的 `TryEnqueue` 成功并唤醒等待者；consumer 仍可 drain 已发布元素。
`TMpmcQueue<T>.EnqueueBatch` returns 0 after `Close` and must not publish new items.

`TMpscQueue<T>` 是多 producer、单 consumer 队列。`Enqueue` 是过程，不返回 close 结果；`Close`
只作为 consumer 等待唤醒和终止信号。调用方必须让 producer 协作停止、join producer，并 drain
队列后再销毁对象。

`TLockFreeStack<T>` 是固定容量 stack。push/pop 会先从内部 free-list 取得或归还 slot，因此不是
无界栈，也不动态分配节点。
`TLockFreeStack<T>` capacity is limited to `High(Int32)` because tagged heads pack a 32-bit slot index
with a 32-bit tag; larger capacities are rejected with `EArgumentError`.

`TWorkStealingDeque<T>` 是 work-stealing deque：owner 线程执行 `TryPush` / `TryPop`，thief
线程只执行 `TrySteal`。当前实现没有 close/wait surface。

固定容量结构会拒绝 0 容量。`TSpscQueue<T>`、`TMpmcQueue<T>` 和 `TWorkStealingDeque<T>` 会把容量提升到
power-of-two；超过最大可表示 power-of-two 的容量会被拒绝，而不是溢出后继续构造。

## Thread safety contract

`TSpscQueue<T>` permits exactly one producer-side caller and exactly one consumer-side caller; multiple producers or multiple consumers on the same queue are outside the contract.
`TMpmcQueue<T>` permits multiple concurrent producers and consumers; `Close` may race with producers, after which new enqueue attempts fail while consumers may drain already published items.
`TMpscQueue<T>` permits multiple producers and exactly one consumer; `Enqueue` does not observe `Close`, so callers must stop and join producers before destroy.
`TLockFreeStack<T>` permits multiple concurrent `TryPush` / `TryPop` callers over its fixed slot pool; capacity bounds and unmanaged element restrictions still apply.
`TWorkStealingDeque<T>` permits exactly one owner thread for `TryPush` / `TryPop` and multiple thief threads for `TrySteal`; owner methods are not multi-owner safe.

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
- Pointer-sized `atomic_load` / `atomic_store` / `atomic_exchange` for `TMpscQueue<T>` node links;
  node pointers must not be widened through legacy `AtomicLoad64` / `AtomicStore64` / `AtomicExchange64` casts.
- `CpuPause` 作为自旋提示。
- `atomic_wait` / `atomic_notify_*` 背后的 `platform_wait_address32`、
  `platform_wake_address_one` 和 `platform_wake_address_all` seam。

`nextpas.core.lockfree.wait` 只等待 32-bit epoch 地址。不要在 lockfree 层自行扩展 64-bit 或 pointer
wait；如果要扩展，先设计 atomic/platform wait-address contract，再补 consumer gate。
Wait helpers receive the caller-observed epoch and only block while the epoch is unchanged. This closes the
notify-between-retry-and-wait window: if a producer or consumer advances the epoch before the platform wait,
the helper returns instead of sleeping on the new epoch.

## 验证

普通 lockfree 切片至少运行：

```bash
make hygiene
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test
make -C core/tests/nextpas.core.lockfree/test_lockfree clean test-debug
make -C core/tests/nextpas.core.lockfree/test_lockfree_stress clean test
git diff --check
git status --short --branch
```

`test_lockfree` 包含 API 行为、close/timeout、managed type guard 和 source-contract 覆盖。
`test-debug` 用 `-dDEBUG` 编译 focused gate，用来执行 `TMpscQueue<T>.Destroy` 的
close-before-destroy assert，防止测试代码绕过 MPSC producer-stop / drain 纪律。
`test_lockfree_stress` 覆盖本地 Linux x86_64 上的多线程压力场景。没有目标机 runtime gate 时，只能声称
source-contract 或本机 Linux x86_64 runtime 证据，不能宣称其他平台已实机验证。

## Benchmark

当前 benchmark 入口是：

```bash
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean run
```

Pascal benchmark 源码位于
`core/benchmarks/nextpas.core.lockfree/bench_lockfree/bench_lockfree.lpr`。它覆盖：

- `TSpscQueue<T>` 的 1 producer + 1 consumer blocking wait 路径。
- `TMpmcQueue<T>` 的 2 producer + 2 consumer blocking wait 路径。
- `nextpas.core.thread.channel` mutex channel 的 1 producer + 1 consumer 对照基线。
- `TSpscQueue<T>` 和 `TMpmcQueue<T>` 的 single-thread `Try*` hot path。

benchmark 使用 `OPS=1000000`、容量 `1024`，Makefile 默认编译参数是 `-MObjFPC -Sh -O2`。
运行输出会先打印 `platform/compiler flags/input size/baseline` envelope，再打印各场景的
ms、M ops/sec 和 ns/op。
Pascal benchmark keeps consumed values in a printed sink to reduce optimizer-elision risk.
Pascal benchmark hot paths should not add extra per-item progress atomics that Rust/Go/C++ comparison sources do not pay; keep only scenario-result sink accumulation and synchronization required by the queue contract itself.
External Rust/Go/C++ comparison sources should follow the same consumed-value sink discipline.
External Rust/Go/C++ comparison sources should follow the same logical input ranges as the Pascal benchmark: SPSC/mutex/1T use 1..OPS, and bounded MPMC uses two producers each sending 1..OPS div 2.

`compare_rust/main.rs` 是外部 Rust comparison source，用于后续手动对照。Rust std nearest equivalents: `std::sync::mpsc` for 1P+1C, `Mutex + Condvar + VecDeque` for bounded 2P+2C approximation, and `Mutex<VecDeque>` for the 1T baseline.
`compare_go/main.go` 是外部 Go comparison source。Go std nearest equivalents: buffered `chan uint64` for 1P+1C and 2P+2C, and same-goroutine buffered channel send/receive for the 1T baseline.
`compare_cpp/main.cpp` 是外部 C++ comparison source。C++ std nearest equivalents: `std::queue<uint64_t>` guarded by `std::mutex` and `std::condition_variable` for bounded 1P+1C and 2P+2C, and the same guarded queue for the 1T baseline.
当前 Pascal benchmark 不会自动编译或运行 Rust、Go 或 C++ 程序；除非同一机器、同一轮次实际运行并记录外部输出，否则不能把它当作 Rust、Go 或 C++ runtime baseline 证据。

当前推荐的对照入口是 `bench_lockfree` Makefile：

```bash
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-rust-compare
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-go-compare
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree run-cpp-compare
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree compare
```

这些 target 最终会在 `core/build/projects/nextpas.core.lockfree/bench_lockfree/...` 下产出并运行：

- Rust：`rustc -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)`
- Go：`go build -o $(GO_COMPARE_BIN) compare_go/main.go`
- C++：`g++ -std=c++17 -O2 -pthread compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)`

性能结论必须带上平台、编译参数、输入规模、benchmark 输出和 baseline 说明。没有这些证据时，不应写入
性能胜过 Rust/Go/C++ 标准库的结论。
