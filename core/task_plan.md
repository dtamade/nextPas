# nextpas.core collections refactor plan

## Goal

Stabilize the `collections` module copied from `fafafa.core`, then refactor it into the `nextpas.core` facade/base/intf/implementation architecture without simplifying behavior.

## Active Scope

- Only `src/nextpas.core.collections*.pas` and collections planning/verification records.
- Do not touch platform/compiler work in this thread.
- Do not add broad unit tests during architecture churn unless needed as a compile/contract probe.

## Current Phase

### Current Micro Batch: Copied Macro Names

- [x] Migrate collections source from copied `FAFAFA_CORE_*` / `FAFAFA_COLLECTIONS_*` macro names to canonical `NEXTPAS_*` names.
- [x] Keep old `FAFAFA_CORE_*` compatibility definitions temporarily in `nextpas.core.settings.inc` because `mem` still uses them.
- [x] Do not rename mem/platform/compiler macro references in this collections batch.

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
- Unsafe fast-path methods use `Unchecked` as one word, for example `GetUnchecked`, `PutUnchecked`, `ReadUnchecked`, and `SortUnchecked`. Current copied `UnChecked` spellings are transitional and should be renamed as a complete interface-tuning batch.
- Naming cleanup must be done as complete mechanical batches rather than piecemeal edits: `UnChecked` -> `Unchecked`, `OverWrite` -> `Overwrite`, `FindIF`/`FindIFNot` -> `FindIf`/`FindIfNot`, `CountIF` -> `CountIf`, `ReplaceIF` -> `ReplaceIf`, `SizeUint` -> `SizeUInt`, and spacing such as `aIndex:SizeUInt` -> `aIndex: SizeUInt`. Update interface declarations, implementation methods, docs/comments, factories/tests/examples that reference the public names, and then run compile verification.
- Sequence mutation APIs distinguish discard and extraction. `Delete(Index)` deletes by position and discards the element. Final indexed sequence APIs use `RemoveAt(Index): T` and `TryRemoveAt(Index, out Element): Boolean` for positional extraction. Do not keep `Remove(Index)` as a public indexed-extraction synonym: the framework is unreleased and has no compatibility burden, so stale duplicate names should be removed during interface tuning. Value-based `Remove(Value)` belongs only to containers that explicitly support value lookup/removal semantics.

## Verification Commands

- `git diff --check`
- `make -C tests/nextpas.core.collections/test_facade test`
- `make test`
