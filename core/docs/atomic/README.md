# nextpas.core.atomic

`nextpas.core.atomic` 提供 nextpas.core 内部和上层模块共享的原子操作基础。新代码优先使用
`atomic_*` 函数或 `TAtomic*` 类型安全 record；PascalCase facade 和部分 pointer
arith/bitwise overload 属于 legacy compatibility surface，只为旧调用点迁移保留。

## 模块分层

当前 live source set 由这些单元组成：

| 单元 | 职责 |
| --- | --- |
| `nextpas.core.atomic.core` | `memory_order_t`、fence、`cpu_pause`、tagged pointer packing 的低层公共 seam。 |
| `nextpas.core.atomic` | 主 facade，暴露 `atomic_*` 函数、`AtomicLoad32` 等 legacy PascalCase wrapper、wait/notify 和 tagged pointer 原子操作。 |
| `nextpas.core.atomic.types` | Rust/C++ 风格的类型安全 record：`TAtomicInt32`、`TAtomicUInt64`、`TAtomicBool`、`TAtomicFlag`、`TAtomicISize`、`TAtomicUSize`、`TAtomicRefCount`、`TAtomicPtr<T>`。 |
| `nextpas.core.atomic.compat` | 旧调用点兼容层，镜像 PascalCase API，并保留部分不建议扩大的 pointer arithmetic/bitwise overload。 |

`core/docs/archive/atomic/nextpas.core.atomic.x86_64.snapshot.txt` 是历史 x86_64 实现快照，
只用于解释旧评审上下文；它不是 live source set，也不能作为当前 runtime 行为证据。

## API 选择

优先级：

1. 新的低层或热路径代码使用 `atomic_*`，例如 `atomic_load(Value, mo_acquire)`。
2. 需要更清晰所有权和类型边界时使用 `TAtomic*` record。
3. 旧 PascalCase surface，例如 `AtomicLoad32`、`AtomicFetchAdd64`、`AtomicWait32`，只用于兼容旧代码。
4. `nextpas.core.atomic.compat` 中的 pointer arithmetic/bitwise overload 不再扩大；新代码应使用整数或 typed pointer API 明确表达意图。

Compatibility boundary: pointer arithmetic/bitwise overloads stay in `nextpas.core.atomic.compat` and must not be added to the main facade.
`atomic_fetch_add/sub(var Pointer; PtrInt)` are the canonical main-facade pointer arithmetic APIs: they apply byte offsets, return the previous pointer, and publish the adjusted pointer; pointer bitwise overloads remain compat-only.
The legacy pointer arithmetic/bitwise overloads and helper aliases have focused runtime coverage in the atomic test gate; this does not make them preferred APIs for new code.

`TAtomicRefCount` 是专用引用计数器，不是通用 `PtrUInt` 原子类型。它只暴露 `Load`、`Inc`、
`TryInc`、`Dec`、`IntoInner`，刻意不暴露 `Store`、`Exchange`、`FetchAdd`、`FetchSub`
或 `GetMut`，避免调用方破坏引用计数纪律。
`Load` defaults to `mo_relaxed`; `Inc` must not resurrect a zero refcount, and `TryInc` returns `False` instead of resurrecting when the count is already zero.
`TryInc` writes `0` to `ANewValue` when the refcount is already zero, so failure leaves a stable non-resurrected out value for destruction-side callers.
`With at least one live owner and no overflow, `TryInc` is the concurrent borrow path: it succeeds from non-zero state, and balanced `Dec` calls do not publish zero before the last owner releases its reference.
`TryInc` racing the last owner release is linearized by the CAS result: success means the borrow observed and extended a non-zero count before zero, failure means the zero-state release won first and clears `ANewValue` to `0`, and across the owner release plus every successful borrowed release exactly one `Dec` performs the final drop to zero.
`Dec` publishes the release-side decrement, and a final drop to zero issues an acquire fence before destruction-side cleanup proceeds.
`Inc` and `TryInc` raise `EResourceExhaustedError` on `High(PtrUInt)` overflow, and `Dec` raises `EInvalidOperationError` if the refcount is already zero.

`atomic_flag_t` and `TAtomicFlag` model C++ `atomic_flag`: `test_and_set` returns the previous set state, `clear` resets the flag, and `test` observes without modifying.

`nextpas.core.atomic` facade exposes scalar typed records, `TAtomicRefCount`, and generic `TAtomicPtr<T>`;
consumers should not need to import `nextpas.core.atomic.types` just to use the public typed-record surface.
Typed atomic records own their storage. Except for `TAtomicFlag`, whose `is_lock_free` method reports the guaranteed atomic-flag truth, their `is_lock_free` methods report the current backend capability for the represented scalar width (`atomic_is_lock_free_32`, `atomic_is_lock_free_64`, or `atomic_is_lock_free_ptr`) when the atomic object is stored with its natural alignment. This is not an arbitrary-address guarantee: callers must not reinterpret packed fields, byte buffers, or manually offset pointers as `TAtomic*` records unless they can prove the resulting object and backing field keep the natural alignment required by that scalar width.
Packed records, `{$PACKRECORDS 1}` / `{$PACKRECORDS C}`, `absolute` overlays, variant-record overlays, byte-buffer reinterpretation, and manual pointer arithmetic are outside the typed atomic contract unless natural alignment is proven before any atomic operation.
`GetMut` and `IntoInner` are exclusive-access escape hatches. Use them only when no other thread can concurrently access the same atomic object. `GetMut` exposes the backing storage for initialization, teardown, or controlled single-owner mutation; it does not turn non-atomic or unaligned storage into a valid atomic object. `IntoInner` reads the backing value under the same exclusive-access assumption and must not be treated as a concurrent load.
`TAtomicInt32` and `TAtomicUInt32` follow `atomic_is_lock_free_32`; `Increment`/`Decrement` return the new value after adding or subtracting one, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.
`TAtomicInt32` and `TAtomicUInt32` keep the scalar RMW return-old semantics in typed form: `FetchAdd` / `FetchSub` / `FetchAnd` / `FetchOr` / `FetchXor` return the previous value and publish the updated Int32/UInt32 payload through the wrapper storage.
`TAtomicUInt32` uses modulo-2^32 unsigned arithmetic for `Increment`/`Decrement` and `FetchAdd`/`FetchSub`; `TAtomicUInt64` uses modulo-2^64 arithmetic when its public 64-bit surface is compiled; `TAtomicUSize` uses modulo pointer-width unsigned arithmetic.
`TAtomicInt64` and `TAtomicUInt64` follow `atomic_is_lock_free_64`; `Increment`/`Decrement` return the new value after adding or subtracting one, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.
`TAtomicInt64` and `TAtomicUInt64` are compiled only under `CPU64 OR CPUX86`; tests for their runtime contracts use the same gate, and targets outside that gate must not be reported as having this public typed 64-bit surface.
On i386, `atomic_is_lock_free_64` is runtime-detected from CMPXCHG8B support; when CMPXCHG8B is unavailable, the typed 64-bit API is still present but 64-bit operations use the fallback lock path.
`TAtomicInt64` and `TAtomicUInt64` keep the scalar 64-bit RMW return-old semantics in typed form: `FetchAdd` / `FetchSub` / `FetchAnd` / `FetchOr` / `FetchXor` return the previous value and publish the updated Int64/UInt64 payload through the wrapper storage.
`TAtomicISize` and `TAtomicUSize` follow `atomic_is_lock_free_ptr`; `Increment`/`Decrement` return the new value after adding or subtracting one, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.
`TAtomicISize` and `TAtomicUSize` keep the scalar pointer-sized RMW return-old semantics in typed form: `FetchAdd` / `FetchSub` / `FetchAnd` / `FetchOr` / `FetchXor` return the previous value and publish the updated PtrInt/PtrUInt payload through the wrapper storage.
`TAtomicInt32`/`TAtomicUInt32`, `TAtomicInt64`/`TAtomicUInt64`, and `TAtomicISize`/`TAtomicUSize` share the same convenience CAS contract: `CompareExchangeStrong` / `CompareExchangeWeak` write the observed value back to `AExpected` on mismatch, and a matching weak CAS publishes the replacement value through the typed record facade.
Single-order typed CAS treats `mo_consume` as `mo_acquire` for the success order and derives a legal acquire failure order instead of exposing release/acq_rel on failure.
`TAtomicBool` stores a normalized `0/1` Int32 payload, `Load`/`Store`/`Exchange` map that payload to Boolean, `FetchAnd/Or/Xor/Nand` return the previous Boolean value while keeping the stored domain within `False/True`, and `is_lock_free` follows `atomic_is_lock_free_32`.
`TAtomicBool.GetMut` is the exclusive-access raw escape hatch: it exposes the backing `Int32`, where `0` is false and any non-zero value reads as true. `Load` and `IntoInner` only project raw storage to Boolean and do not rewrite non-normal storage; `FetchAnd/Or/Xor/Nand` compute from Boolean truth (`raw <> 0`) and publish a normalized `0/1` result, so non-normal raw true values introduced through `GetMut` are normalized by the next successful Boolean RMW.
`TAtomicPtr<T>` follows `atomic_is_lock_free_ptr`; `Load`/`Store`/`Exchange` publish the pointed-to address, strong/weak CAS update both the stored pointer and the observed expected pointer, and `GetMut` / `IntoInner` stay exclusive-access escape hatches rather than concurrent APIs.
Direct `nextpas.core.atomic.types.TAtomicPtr<T>` follows the same load/store/exchange/CAS/GetMut/IntoInner contract as the facade pointer wrapper; facade use remains preferred for ordinary consumers.

## 内存序语义

`memory_order_t` 包含 `mo_relaxed`、`mo_consume`、`mo_acquire`、`mo_release`、`mo_acq_rel`
和 `mo_seq_cst`。无参数 overload 默认使用 `mo_seq_cst`，这是当前公开 API 的最强默认语义。

当前实现要点：

- `atomic_thread_fence(mo_seq_cst)` 通过专用 `atomic_seq_cst_fence` 路由；PPC/PPC64 使用 heavyweight `sync`。
- No-argument scalar/pointer `atomic_store` wrappers and `atomic_flag_test` route through `mo_seq_cst`; callers must pass an explicit weaker order when they want relaxed/acquire/release behavior.
- `atomic_signal_fence` 是 compiler fence seam，不作为硬件可见性保证。
- x86/x86_64 的 `mo_seq_cst` load 使用 locked/fenced helper，不能退回 plain load + compiler barrier。
- 非 x86 的 `mo_seq_cst` load/store 通过 source-contract 约束 fence contract；没有目标机 runtime 证据时，不应写成实机验证结论。
- CAS single-order wrapper 会把成功序中的 `mo_consume` 规范化为 acquire，并派生合法 failure order；failure order 不包含 release/acq_rel。
- `TAtomicPtr<T>` single-order CAS normalizes `mo_consume` success to acquire and derives a legal failure order; failure order never includes release or acq_rel.
- Invalid explicit orders raise `EArgumentError`: load rejects `mo_release`/`mo_acq_rel`, store rejects `mo_consume`/`mo_acquire`/`mo_acq_rel`, and dual-order CAS rejects release/acq_rel failure orders or failure orders stronger than success.
- `atomic_fetch_max/min/nand` return the previous value, publish `max(old, arg)` / `min(old, arg)` / `not (old and arg)`, and their no-argument overloads default to `mo_seq_cst`.

## AtomicWait/Notify

当前 wait/notify surface 只覆盖 32-bit address wait：

- `atomic_wait(var Int32/UInt32, Expected, TimeoutNs)`
- `atomic_notify_one(var Int32/UInt32)`
- `atomic_notify_all(var Int32/UInt32)`
- legacy wrapper：`AtomicWait32`、`AtomicNotifyOne32`、`AtomicNotifyAll32`

主实现只通过 `platform_wait_address32`、`platform_wake_address_one` 和
`platform_wake_address_all` 暴露平台能力。不要在 atomic 层自行扩展 64-bit 或 pointer wait；
如果要扩展，先设计 platform contract，再补当前模块 consumer gate。

## Tagged Pointer

`atomic_tagged_ptr_t` 用于 ABA-sensitive 数据结构的 pointer + tag 组合：

- x86_64 使用 high-tag packing，并在 release path 拒绝不能安全打包的非 canonical pointer。
- 非 x86 使用 low-bit tag packing，要求 pointer 对齐并检查 tag 是否能放入 `TAG_BITS`。
- `atomic_tagged_ptr_load/store/exchange` and single-order tagged pointer CAS defaults use `mo_seq_cst` unless the caller passes an explicit memory order.
- Tagged pointer explicit load/store/CAS APIs follow the same invalid-order contract and raise `EArgumentError` when callers pass illegal explicit orders.
- `atomic_tagged_ptr_next` wraps to `0` after the maximum representable tag, and `atomic_tagged_ptr_update` uses that modulo increment when it swaps in a new pointer.
- `atomic_tagged_ptr_update_tag` preserves the current pointer and only replaces the tag.

## 跨平台边界

当前 focused gate 在本地 Linux x86_64 上运行，source-contract 额外约束了一些 arch-specific
路径文本，例如 x86/x86_64 `mo_seq_cst` load helper、PPC fence helper、i386 64-bit fallback
lock cleanup、非 x86 fence-load-fence 结构。没有对应目标机 runtime gate 时，只能声称 source-contract
覆盖，不能声称该平台已实机通过。

FPC 目前会输出 inline/assembler note。这些 note 是已知基线噪音；不要为了隐藏 note 修改语义或删除
source-contract。

## 验证

普通 atomic 切片至少运行：

```bash
make hygiene
make -C core/tests/nextpas.core.atomic/test_atomic clean test
git diff --check
git status --short --branch
```

如果触碰 platform wait-address、fence、异常类型或相邻模块 API，需要追加被触达模块自己的
focused gate。涉及跨平台 fence 或 arch-specific helper 时，至少补 source-contract 或 compile gate，
并在没有目标机 runtime 时登记残余风险。

## Benchmark

当前 benchmark 入口是：

```bash
make -C core/benchmarks/nextpas.core.atomic/bench_atomic clean run
```

Pascal benchmark 源码位于
`core/benchmarks/nextpas.core.atomic/bench_atomic/bench_atomic.lpr`。它覆盖单线程热路径：

- plain local variable increment，作为本机单线程循环/局部变量开销上下文。
- `AtomicLoad32` / `AtomicStore32` relaxed load-store 路径。
- `AtomicFetchAdd32` relaxed read-modify-write 路径。
- `AtomicCompareExchange32` seq_cst success path。
- `TAtomicUInt32.FetchAdd` typed record facade 路径。

benchmark 使用 `ITERS=1000000`，Makefile 默认编译参数是 `-MObjFPC -Sh -O2`。
运行输出会先打印 `platform/compiler flags/input size/baseline` envelope，再打印各场景的
ms、M ops/sec 和 ns/op。

当前 baseline 只是同一 Pascal 程序里的 plain local variable 操作；plain baseline uses loop-index-dependent local integer work to reduce optimizer folding risk，用于帮助判断单线程测试开销；
The Pascal benchmark keeps only the final per-scenario result in the printed sink; hot loops should use local temporaries instead of per-iteration global sink writes so Rust/Go/C++ comparison sources can mirror the same logical workload.
它不是 Rust、Go 或 C++ runtime 对照。`compare_rust/main.rs` 是外部 Rust comparison source，
`compare_go/main.go` 是外部 Go `sync/atomic` comparison source，`compare_cpp/main.cpp` 是外部
C++ `std::atomic` comparison source；这些文件用于后续同机手动对照。当前 Pascal benchmark 不会自动编译或运行
Rust、Go 或 C++ 程序。性能结论必须带上平台、编译参数、输入规模、benchmark 输出和 baseline 说明。没有同一机器、
同一轮次的外部 runtime 输出时，不应写入胜过 Rust/Go/C++ 标准库的结论。

当前推荐的对照入口是 `bench_atomic` Makefile：

```bash
make -C core/benchmarks/nextpas.core.atomic/bench_atomic run-rust-compare
make -C core/benchmarks/nextpas.core.atomic/bench_atomic run-go-compare
make -C core/benchmarks/nextpas.core.atomic/bench_atomic run-cpp-compare
make -C core/benchmarks/nextpas.core.atomic/bench_atomic compare
```

这些 target 最终会在 `core/build/projects/nextpas.core.atomic/bench_atomic/...` 下产出并运行：

- Rust：`rustc -C opt-level=3 compare_rust/main.rs -o $(RUST_COMPARE_BIN)`
- Go：`go build -o $(GO_COMPARE_BIN) compare_go/main.go`
- C++：`g++ -std=c++17 -O2 compare_cpp/main.cpp -o $(CPP_COMPARE_BIN)`
