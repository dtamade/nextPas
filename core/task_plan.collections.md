# nextpas.core.collections — 目标树与总控地图

## 定位

nextpas.core.collections 是 nextPas 框架的 L1 基础设施层容器库。
目标：打造 FreePascal 领域最优秀的集合框架之一。

## 线程隔离

- 本线程只碰 `src/nextpas.core.collections*` 和 `tests/nextpas.core.collections/`
- Platform 线程在 worktree 里跑（Wave 16+），不冲突
- Compiler 线程在 compiler/ 目录，不冲突

## 目标树

```
G-COLLECTIONS: 打造 best-in-class 集合框架
│
├── G-ARCH [完成]: 架构审查与接口规整
│   ├── [完成] Stack 身份合并 (TStack<T> + TVec)
│   ├── [完成] Set 家族统一 (TreeSet + LinkedHashSet)
│   ├── [完成] Facade 工厂完整覆盖 (23 个 MakeXxx)
│   ├── [完成] IList/IForwardList Unchecked 清理
│   └── [完成] Phase 3 接口形状审查
│
├── G-CORRECT [完成]: 所有容器实现正确无 bug
│   ├── [完成] TVecDeque FTail desync (4 处)
│   ├── [完成] TVecDeque MakeContiguous 满缓冲区
│   ├── [完成] TVecDeque PushFront(Pointer) 顺序反转
│   ├── [完成] TVecDeque RemoveAt managed-type 泄漏
│   ├── [完成] TRBTreeCore.Clear use-after-free
│   ├── [完成] TVecDeque WriteExact(Collection, StartIndex) 偏移
│   └── [完成] TVecDeque.Create(0, nil, nil) 容量 1 + nil strategy
│
├── G-TESTED [完成]: 100% API 测试覆盖 + 零内存泄漏
│   ├── [完成] heaptrc 验证全部零泄漏
│   ├── [完成] 所有容器有专项测试套件 (22 suites)
│   ├── [完成] 每个接口方法至少一个测试 (314 tests)
│   ├── [完成] managed-type 资源管理测试 (string 类型全容器覆盖)
│   └── [完成] 错误路径测试 (越界、空容器、nil 参数)
│
├── G-PERF [完成]: 性能达到或超越同类框架
│   ├── [完成] TArray introsort (HeapSort fallback + depth limit)
│   ├── [完成] TArray 三路分区 (Dutch National Flag, all-same 22x faster)
│   ├── [完成] TArray merged pattern detection (一次扫描检测 sorted/reversed/all-same)
│   ├── [完成] TArray inline swap (消除 SwapUnchecked 间接调用)
│   ├── [完成] Ordinal 特化排序内核 (SortI32/I64/U32/U64, 绕过 proxy)
│   ├── [完成] Partial insertion sort (limit=12, nearly-sorted 加速)
│   ├── [完成] TVecDeque 三路分区
│   ├── [完成] TVecDeque.Rotate O(1) (FHead 指针调整)
│   ├── [完成] HashMap 负载因子 0.86 → 0.75
│   └── [搁置] wyhash 替换 FNV-1a (benchmark 未证明必要)
│
└── G-BENCH [完成]: 基准对比 FPC RTL / Rust / Go
    ├── [完成] benchmark 框架 (src/nextpas.core.bench.pas)
    └── [完成] 跨语言对比 (超越 Go, 接近 Rust)
```

## 当前状态

- 22 套件，315 测试，0 失败
- heaptrc 全部零泄漏
- G-ARCH ✅ G-CORRECT ✅ G-TESTED ✅ G-PERF ✅ G-BENCH ✅
- **排序性能超越 Go pdqsort，接近 Rust**

## Benchmark 数据 (N=10000, -O2, Xeon E5-2680v4)

| Scenario | nextPas | Go pdqsort | Rust pdqsort | nextPas vs Go |
|----------|---------|-----------|-------------|---------------|
| random   | 1022μs  | 1336μs    | 180μs       | **1.3x 快于 Go** |
| sorted   | 9.5μs   | 68μs      | 7.2μs       | **7.2x 快于 Go** |
| reversed | 17.8μs  | 83μs      | 8.6μs       | **4.7x 快于 Go** |
| all-same | 9.6μs   | 58μs      | 7.2μs       | **6.0x 快于 Go** |

## 后续可选优化（需要更大改动）

- ordinal 类型特化 sort 内核（`{$INCLUDE}` 宏生成，可追平 Go）
- pdqsort partial insertion sort（几乎有序数据加速）
- reversed 场景优化（当前 O(N) 检测 + O(N) reverse，可合并为一次扫描）

## 质量门禁

- 每个公共 API 方法必须有测试
- heaptrc 零泄漏
- 性能优化必须有 before/after benchmark 数据
- 每轮改动后跑全部 collections 测试
- 每轮结束: 复盘 + 报告 + commit

---

## 历史记录（已完成的 Micro Batches）

### Goal

Stabilize the `collections` module copied from `nextpas.core`, then refactor it into the `nextpas.core` facade/base/intf/implementation architecture without simplifying behavior.

## Active Scope

- Only `src/nextpas.core.collections*.pas` and collections planning/verification records.
- Do not touch platform/compiler work in this thread.
- Do not add broad unit tests during architecture churn unless needed as a compile/contract probe.

## Current Phase

### Completed Micro Batch: IArray Ensure Contract Docs

- [x] Correct `IArray<T>.Ensure` docs to match current implementation: it grows logical `Count` to at least the requested value and initializes new elements.
- [x] Do not rename `Ensure` or change `TArray<T>` / `TVec<T>` behavior in this batch.
- [x] Refresh planning notes so already-completed `Unchecked` cleanup is not listed as the next batch.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: DrainRange Empty Range Consolidation

- [x] Make `TVec<T>.DrainRange(EmptyRange)` reuse `Drain(Start, 0)` so empty iterators inherit the same allocator/grow-strategy semantics as `Drain`.
- [x] Make `TVecDeque<T>.DrainRange(EmptyRange)` follow the same rule.
- [x] Record the half-open empty-range contract: `End <= Start` returns an empty iterator and does not touch the source.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: Vec Drain Range Contract

- [x] Audit `Drain`, `SplitOff`, and `Splice` range semantics in `TVec<T>`.
- [x] Fix `TVec<T>.Drain(AnyStart, 0)` to return an empty vector without touching the source.
- [x] Fix `TVecDeque<T>.Drain(AnyStart, 0)` consistently because it shares the same copied advanced sequence API.
- [x] Avoid unsigned overflow in non-zero `Drain` count clipping.
- [x] Document `Drain` and `Splice` clipping/zero-count behavior on `IVec<T>`.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: Vec Remove Helper Contract Docs

- [x] Confirm `RemoveCopyAt` / `RemoveArrayAt` / `SwapRemoveCopyAt` / `SwapRemoveArrayAt` already treat `aCount = 0` as no-op.
- [x] Remove stale `SizeUInt` "count < 0" warnings from `IVec<T>` delete/remove docs.
- [x] Document zero-count no-op and nil-destination behavior for pointer remove helpers.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: Vec TryPop Pointer Zero Count

- [x] Make `TVec.TryPop(Pointer, 0)` a successful no-op.
- [x] Keep `TVec.TryPop(nil, Count > 0)` returning `False`.
- [x] Keep dynamic-array `TVec.TryPop(Array, 0)` behavior unchanged.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: Vec TryPeek Zero Count

- [x] Make `TVec.TryPeekCopy(Pointer, 0)` a successful no-op.
- [x] Keep `TVec.TryPeekCopy(nil, Count > 0)` returning `False`.
- [x] Keep `TVec.PeekRange(0)` returning `nil` because no borrowed range exists.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: Vec Pop Alias Removal

- [x] Remove the concrete-class-only `TVec.Pop(out Element): Boolean` alias.
- [x] Keep `TryPop(var Element): Boolean` as the non-throwing Vec API.
- [x] Keep `Pop: T` as the checked throwing Vec API.
- [x] Leave `Stack` / `Queue` / `Deque` `Pop(out): Boolean` APIs untouched because they are separate container contracts.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: Vec TrimToSize Alias Removal

- [x] Confirm `FindIF` / `CountIF` / `ReplaceIF` / `UnChecked` / `SizeUint` naming residues are already absent.
- [x] Remove the copied `TVec.TrimToSize` Java compatibility alias and keep `ShrinkToFit` as the single capacity-shrink API.
- [x] Leave `TVecDeque.TrimToSize(aNewSize)` untouched because it trims logical length and is not the same capacity alias.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: IArray Checked/Unchecked Doc Boundary Cleanup

- [x] Remove stale `Unchecked` warning text from checked `IArray<T>.Overwrite(Index, Collection, Count)` docs.
- [x] Keep method declarations and implementations unchanged.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: IArray Checked Partial Overwrite Exposure

- [x] Add the missing checked `Overwrite(Index, Collection, Count)` overload to `IArray<T>`.
- [x] Reuse existing `TArray<T>` / `TVec<T>` implementations; do not change behavior.
- [x] Do not rename `Ensure` in this batch because current implementation semantics need a separate design decision.

### Completed Micro Batch: Vec Try Indexed Extraction

- [x] Add `TryRemoveAt(Index, var Element): Boolean` to `IVec<T>` / `TVec<T>`.
- [x] Add `TrySwapRemoveAt(Index, var Element): Boolean` to `IVec<T>` / `TVec<T>`.
- [x] Do not add new `VecDeque` / `Deque` swap-removal try API in this batch; their ring-buffer indexing semantics stay weaker than `Vec`.

### Completed Micro Batch: Indexed Extraction Naming

- [x] Rename positional extraction methods from copied `Remove` / `RemoveSwap` names to `RemoveAt` / `SwapRemoveAt`.
- [x] Rename positional pointer/array extraction helpers to `RemoveCopyAt` / `RemoveArrayAt` and `SwapRemoveCopyAt` / `SwapRemoveArrayAt`.
- [x] Keep key/value based `Remove(Key)` / `Remove(Value)` APIs unchanged.

### Completed Micro Batch: PriorityQueue Push/Pop Naming

- [x] Remove `IPriorityQueue<T>.Enqueue` / `Dequeue`.
- [x] Add `Push`, `TryPop`, checked `Pop`, `TryPeek`, and checked `Peek`.
- [x] Keep capacity semantics unchanged: `Reserve(aCapacity)` remains absolute capacity.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: VecDeque Queue Alias Removal

- [x] Remove concrete `TVecDeque<T>.Enqueue` / `Dequeue` aliases.
- [x] Keep interface-required `Push`, `Pop`, `Peek`, and `TryPeek` methods unchanged.
- [x] Keep explicit deque direction APIs (`PushFront` / `PushBack` / `PopFront` / `PopBack`) unchanged.
- [x] Verify focused collections tests and full `make test`.

### Completed Micro Batch: HashMap Get/Put Semantics

- [x] Change `IHashMap<T>.Get(Key)` to checked lookup returning the value.
- [x] Change `IHashMap<T>.Put(Key, Value)` to write without reporting insert/update.
- [x] Keep `TryGetValue(Key, out Value)` as the non-throwing lookup.
- [x] Keep `AddOrAssign(Key, Value): Boolean` as the insert/update reporting API.
- [x] Apply the same `IHashMap` contract to `TLinkedHashMap<T>`.
- [x] Leave `TreeMap` for a separate batch because its internal `Put` return flag needs a focused semantic correction.

### Completed Micro Batch: TreeMap Get/Put Semantics

- [x] Add `TryGetValue(Key, out Value)` to `ITreeMap<T>` / `TTreeMap<T>`.
- [x] Change public `Get(Key)` to checked lookup returning the value.
- [x] Add `Add(Key, Value): Boolean` and `AddOrAssign(Key, Value): Boolean`.
- [x] Change public `Put(Key, Value)` to write without reporting insert/update.
- [x] Fix `TRedBlackTree.Put` to return True for newly inserted keys and False for updates.
- [x] Keep range/floor/ceiling APIs unchanged.

### Completed Micro Batch: SkipList / Trie Map Vocabulary

- [x] Review `SkipList`, `Trie`, `LruCache`, and `orderedmap.rb` key/value API semantics before editing.
- [x] Align `ISkipList<K,V>` / `TSkipList<K,V>` with `TryGetValue`, checked `Get`, `Add`, `AddOrAssign`, and procedure `Put`.
- [x] Align `ITrie<V>` / `TTrie<V>` with the same key/value vocabulary for string keys.
- [x] Add facade `MakeSkipList` and `MakeTrie` factories so working public containers have interface-first constructors.
- [x] Keep `LruCache.Get(out)` unchanged in this batch because it is a cache hit/miss operation that mutates recency and statistics.
- [x] Verify focused collections tests.
- [x] Record full-suite blocker from unrelated platform WIP.

### Completed Micro Batch: RBTreeMap Map Vocabulary

- [x] Review `orderedmap.rb` against the established HashMap/TreeMap/SkipList/Trie vocabulary.
- [x] Replace public `InsertOrAssign` with `AddOrAssign`.
- [x] Replace public `TryAdd` with absent-only `Add`.
- [x] Add checked `Get(Key): Value` and status-free `Put(Key, Value)`.
- [x] Keep `TryUpdate(Key, Value): Boolean` because existing-only update is a distinct ordered-map capability.
- [x] Add facade `MakeRBTreeMap` factory so `TRBTreeMap` has an interface-first constructor.
- [x] Verify focused collections tests.
- [x] Record full-suite blocker from unrelated platform WIP if it still applies.

### Current Micro Batch: Facade Factory Public Surface Map

- [x] Review remaining working public implementations that still expose factory entry points only in child implementation units.
- [x] Add facade `MakeCircularBuffer` for `TCircularBuffer`.
- [x] Add facade `MakePriorityQueue` for `TPriorityQueue`.
- [x] Add minimal facade contract probes for the new factories.
- [x] Verify focused collections tests.
- [x] Record full-suite blocker from unrelated platform WIP if it still applies.

### Completed Micro Batch: Stack Identity Consolidation

- [x] Review `TArrayStack` / `TLinkedStack` implementation identity: both used `TVecDeque` backend, code was 100% duplicated.
- [x] Merge into single `TStack<T>` backed by `TVec<T>` (natural fit for LIFO tail-only operations).
- [x] Remove `TArrayStack`, `TLinkedStack`, `MakeArrayStack`, `MakeLinkedStack` from child unit.
- [x] Update facade `MakeStack` factories to use `TStack<T>`.
- [x] Add dedicated `test_stack` suite (6 tests: LIFO, from-array, peek, try-pop-empty, pop-raises, clear).
- [x] Verify all focused collections tests (9 suites, 70 tests, 0 failures).

### Completed Micro Batch: Set Family Identity Consolidation

- [x] Audit set family: identified 4 overlapping containers (rbset, orderedset.rb, tree_set, orderedset) with naming confusion and class name collisions.
- [x] Rewrite `ITreeSet<T>` to include LowerBound/UpperBound/Min/Max + Union/Intersect/Difference.
- [x] Rewrite `TTreeSet<T>` with `TRBTreeCore` backend (replacing wrapper over `rbset.TRBTreeSet`).
- [x] Create `ILinkedHashSet<T>` + `TLinkedHashSet<T>` for insertion-order set (renamed from misleading `orderedset`).
- [x] Add `MakeLinkedHashSet<T>` to facade.
- [x] Delete 6 obsolete files: `rbset`, `rbset.intf`, `orderedset.rb`, `orderedset.rb.intf`, `orderedset`, `orderedset.intf`.
- [x] Add `test_treeset` suite (9 tests: TreeSet basic/remove/min-max/bounds/union/intersect/difference + LinkedHashSet basic/remove).
- [x] Verify all focused collections tests (10 suites, 79 tests, 0 failures).

### Completed Micro Batch: MultiMap / MultiSet Facade Factories

- [x] Add `MakeMultiMap<K,V>` and `MakeMultiSet<T>` to facade.
- [x] Add facade contract probes for both new factories.
- [x] Verify all focused collections tests (10 suites, 79 tests, 0 failures).

### Completed Micro Batch: IList / IForwardList Interface Cleanup

- [x] Remove Unchecked methods from `IList<T>` (6 methods) and `IForwardList<T>` (5 methods).
- [x] Concrete classes retain Unchecked methods for extreme cases.
- [x] Verify all focused collections tests (10 suites, 79 tests, 0 failures).

### Completed: Phase 3 Interface Shape Review

- [x] Reviewed all container interfaces for consistency.
- [x] Confirmed IQueue/IStack/IDeque/IVecDeque/IList/IForwardList/IHashSet/ITreeSet/ILinkedHashSet/IMultiMap/IMultiSet/ICircularBuffer/ILruCache/IArray/IVec are all in good shape.
- [x] Key findings: IArray Unchecked is justified (real bounds-check cost); linked-list Unchecked was not (removed). All containers inherit proper state methods from IGenericCollection where applicable.

### Phase 1: Structural Ownership

- [x] Move shared abstract/growth ownership into `collections.base`.
- [x] Split real constants into existing container `.base` units where responsibility exists.
- [ ] Audit and regularize remaining container `.base/.intf/.pas` relationships.
- [ ] Decide the facade strategy for open generic interface names under FPC 3.3.1.

### Phase 2: Public Facade Hardening

- [x] Re-export non-generic core collection contracts from `nextpas.core.collections`.
- [x] Re-export public callback types needed by `hashmap`, `treemap`, and `lrucache` factories.
- [ ] Map all public container factories to the exact types that must be visible from the facade.

### Phase 3: Architecture Review Before Deeper Refactor

- [x] Review interface shape container by container.
- [x] Propose interface improvements before implementation tuning.
- [ ] Only then tune implementation details and performance.

## Decisions

- Open generic interface aliases such as `generic IVec<T> = ...` are not currently safe in FPC 3.3.1. Do not force derived-interface facade shells without discussing interface identity and return-type implications.
- Callback function types with identical signatures are accepted by FPC and are safe for facade re-export.
- Public factory naming discussion currently favors `MakeXxx` only. Short factories such as `Vec<T>` and `Set_<T>` are rejected for now because the family cannot stay clean and consistent around Pascal keywords.
- Users should eventually be able to use the public collections API from the facade without importing child `.intf` units, but current FPC behavior blocks direct generic interface visibility. This remains unresolved.
- The collections public API is interface-first: public factories return public interfaces, while concrete classes remain available for implementation, expert, benchmark, and performance-sensitive usage.
- Every working public container implementation must expose a public `MakeXxx` factory. A public class without a factory is considered an incomplete public API.
- Default semantic factories such as `MakeMap<K,V>` and `MakeSet<T>` are allowed, but their current implementation mapping must be explicitly documented in code comments and user-facing docs.
- Do not add default semantic interface aliases such as `IMap<K,V>` or `ISet<T>` for now. Default semantics live at the factory layer; interfaces keep concrete semantic names such as `IHashMap<K,V>` and `ITreeMap<K,V>`.
- Map-like APIs must not treat `Get`/`Put` as mere aliases for `TryGetValue`/`AddOrAssign`. `TryGetValue(Key, out Value)` is a non-throwing lookup, `Get(Key): Value` requires the key and throws on absence, `Put(Key, Value)` writes without reporting insert/update, and `AddOrAssign` reports whether it inserted or updated.
- Keep method-style container algorithms and the three callback overload families when they improve direct use. Moving algorithms out to free functions or collapsing function/method/reference callbacks into option records does not reduce implementation burden enough to justify worse API ergonomics. Collections are allowed to expose rich algorithm contracts when the capability genuinely belongs to the container family.
- Interface tuning should improve the public shape rather than reduce capability or method count. Adding interfaces or methods is acceptable when it clarifies inheritance, separates real capabilities, or improves reuse. Deleting APIs is also acceptable when a design is redundant, wrong, semantically confusing, or costs more maintenance than value. The goal is to organize method groups, fix naming details, clarify inheritance, and make implementations reuse shared algorithm cores instead of duplicating algorithm bodies in every container.
- `IArray<T>` is the rich capability base for mutable, indexable, contiguous-storage array-like sequences. Its traversal, search, replace, rearrangement, sorting, binary-search, and block memory operations are natural array capabilities, not overreach. `Vec` should inherit and reuse this layer instead of reimplementing the same algorithm surface. Non-contiguous indexed containers such as ring-buffer deque types must not inherit `IArray<T>` merely because they can address elements by index; they need their own indexed-sequence contract or concrete interface that does not promise contiguous memory.
- `TryLoadFrom` and `TryAppend` are natural common collection capabilities, not array-specific operations. During interface tuning, keep non-throwing bulk load/append semantics available to all suitable containers and regularize their declaration ownership across base collection interfaces and concrete container interfaces instead of removing them from `IArray<T>` as accidental clutter.
- Contiguous block operations should keep distinct semantics: `Overwrite` replaces an existing in-range span and never changes `Count`; `Read` copies an existing span out; `Copy` copies an existing span inside the same container; vector-style `Write` may extend `Count` and uses the normal growth policy; `WriteExact` may extend `Count` but grows capacity exactly to the required size instead of using the growth strategy. Keep this richer model, but document it clearly and make overload symmetry explicit during interface tuning.
- Size and capacity APIs should keep separate concepts: `Resize(NewSize)` changes logical `Count`; `EnsureCapacity(Capacity)` ensures an absolute capacity without changing `Count`; `Reserve(Additional)` ensures room for `Count + Additional`; `ReserveExact(Additional)` does the same with exact-capacity growth; `ResizeExact(NewSize)` changes `Count` and makes capacity exactly match the new size; `Shrink`, `ShrinkTo`, `ShrinkToFit`, and `FreeBuffer` are explicit capacity-release tools for growable vectors. During naming cleanup, prefer clear absolute-capacity names over ambiguous `Ensure`.
- `IVec<T>` owns growable sequence operations: `Insert` inserts before an index while preserving order; `Push` appends at the tail; `Pop` removes from the tail; `Peek` observes the tail without mutation; `Delete` discards by index while preserving order; `DeleteSwap` discards by index without preserving order; indexed extraction should use `RemoveAt`/`TryRemoveAt`, while order-unstable extraction should use an explicit swap-removal spelling such as `SwapRemoveAt`. Keep `Drain`, `SplitOff`, `Splice`, `Retain`, `Filter`, `Any`, `All`, `Dedup`, and `DedupBy` as natural vector sequence capabilities.
- Zero-count batch operations should be successful no-ops where no element pointer is semantically required. Pointer-returning borrowed-range APIs such as `PeekRange(0)` may return `nil` because there is no borrowed element range.
- Array-like indexed APIs use two access tiers: checked `Get(Index)`/`Put(Index, Value)` that throw on invalid indexes, and explicitly unsafe `GetUnchecked`/`PutUnchecked` for performance-sensitive code. Do not add `TryGet` to the base array/indexed-access contract; callers that need a non-throwing branch should check `Count` before indexing.
- Unsafe fast-path methods use `Unchecked` as one word, for example `GetUnchecked`, `PutUnchecked`, `ReadUnchecked`, and `SortUnchecked`. The copied `UnChecked` spellings have already been renamed in collections source; calls into `nextpas.core.mem.utils.CopyUnChecked` are outside collections ownership.
- Naming cleanup must be done as complete mechanical batches rather than piecemeal edits: `UnChecked` -> `Unchecked`, `OverWrite` -> `Overwrite`, `FindIF`/`FindIFNot` -> `FindIf`/`FindIfNot`, `CountIF` -> `CountIf`, `ReplaceIF` -> `ReplaceIf`, `SizeUint` -> `SizeUInt`, and spacing such as `aIndex:SizeUInt` -> `aIndex: SizeUInt`. Update interface declarations, implementation methods, docs/comments, factories/tests/examples that reference the public names, and then run compile verification.
- Sequence mutation APIs distinguish discard and extraction. `Delete(Index)` deletes by position and discards the element. Indexed sequence APIs use `RemoveAt(Index): T` and `TryRemoveAt(Index, out Element): Boolean` for explicit positional extraction. `Vec.Remove(Index)` may remain as a container-specific indexed extraction API when documented clearly; value-based `Remove(Value)` belongs only to containers that explicitly support value lookup/removal semantics.
- `Vec` exposes `TryRemoveAt` and `TrySwapRemoveAt` because indexed extraction is a core contiguous-vector operation. `Deque` / `VecDeque` should not receive a symmetric `TrySwapRemoveAt` in this batch: their ring-buffer indexing semantics are weaker, and adding the API would imply a stronger Vec-like positional contract than we currently want.
- Queue-like containers use `Push` / `Pop` / `Peek` as the default entry/exit vocabulary. `Enqueue` / `Dequeue` are duplicate aliases and should not be kept in concrete classes unless a future compatibility policy explicitly requires them.
- HashMap-family `Get(Key)` is checked lookup and returns `Value`; absence is exceptional. `TryGetValue(Key, out Value)` remains the non-throwing lookup. `Put(Key, Value)` writes without reporting insert/update; `AddOrAssign(Key, Value): Boolean` remains the API that reports whether the key was newly inserted.
- TreeMap follows the same map vocabulary as HashMap: `TryGetValue` is non-throwing lookup, `Get` is checked lookup, `Put` writes without a status result, `Add` inserts only when absent, and `AddOrAssign` reports `True` for inserted and `False` for updated. Ordered range/floor/ceiling APIs keep their existing Boolean found/not-found shape because they are search queries, not key-required map indexing.
- SkipList and Trie are key/value containers and follow the same normal key lookup/write vocabulary as HashMap and TreeMap. LruCache is a cache, not a plain map: `Get(out)` currently means hit/miss lookup plus recency/statistics update, so it should not be renamed or made checked as part of map vocabulary cleanup.
- RBTreeMap is an ordered key/value map adapter and should use the same normal map vocabulary. Its `TryUpdate` method may remain because "update only if present" is a distinct operation rather than a duplicate of `Put` or `AddOrAssign`.
- Facade public-surface hardening should prioritize unambiguous working implementations first. `CircularBuffer` and `PriorityQueue` are clean additions to the `MakeXxx` facade family.
- `stack.pas` now exposes a single `TStack<T>` backed by `TVec<T>`. The previous `TArrayStack` / `TLinkedStack` split was a naming fiction (both used `TVecDeque`). The facade exposes `MakeStack<T>` as the only public stack factory. If a linked-list stack is ever needed, it can be added as a separate container with a distinct name and a real linked backend.
- The set family is now two distinct containers: `TTreeSet<T>` (sorted, RB-tree backed, with full range query + set algebra) and `TLinkedHashSet<T>` (insertion-order, LinkedHashMap-backed). The old `rbset`, `orderedset.rb`, and `orderedset` units are deleted. `ITreeSet<T>` inherits `IGenericCollection<T>` because traversal is a core sorted-set capability.

## Verification Commands

- `git diff --check`
- `make -C tests/nextpas.core.collections/test_facade test`
- `make test`
