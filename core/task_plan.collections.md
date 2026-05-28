# nextpas.core collections refactor plan

## Goal

Stabilize the `collections` module copied from `fafafa.core`, then refactor it into the `nextpas.core` facade/base/intf/implementation architecture without simplifying behavior.

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

### Current Micro Batch: SkipList / Trie Map Vocabulary

- [x] Review `SkipList`, `Trie`, `LruCache`, and `orderedmap.rb` key/value API semantics before editing.
- [x] Align `ISkipList<K,V>` / `TSkipList<K,V>` with `TryGetValue`, checked `Get`, `Add`, `AddOrAssign`, and procedure `Put`.
- [x] Align `ITrie<V>` / `TTrie<V>` with the same key/value vocabulary for string keys.
- [x] Add facade `MakeSkipList` and `MakeTrie` factories so working public containers have interface-first constructors.
- [x] Keep `LruCache.Get(out)` unchanged in this batch because it is a cache hit/miss operation that mutates recency and statistics.
- [x] Verify focused collections tests.
- [x] Record full-suite blocker from unrelated platform WIP.

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

- [ ] Review interface shape container by container.
- [ ] Propose interface improvements before implementation tuning.
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

## Verification Commands

- `git diff --check`
- `make -C tests/nextpas.core.collections/test_facade test`
- `make test`
