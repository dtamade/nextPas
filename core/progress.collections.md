# nextpas.core collections progress

## 2026-05-27

- Continued the collections-only cleanup after the smallvec/trie base split.
- Audited `hashmap`, `treemap`, and `lrucache` `.base/.intf/.pas` responsibility boundaries.
- Confirmed that FPC 3.3.1 cannot safely express open generic facade aliases for child-unit interfaces.
- Updated `nextpas.core.collections` to explicitly expose public callback types used by collections factories and algorithms.
- Verified the facade callback compile probe and existing collections facade test.
- Discussed factory naming and interface-first direction. Current direction: interface-first remains desired; short factories are rejected because names like `Set_` are not acceptable; `MakeXxx` is the likely clean public factory family.
- Confirmed with a local probe that users cannot currently declare `IVec<T>` from `nextpas.core.collections` alone. This is recorded for later architecture resolution.
- Added design decisions from discussion: every public working container implementation needs a public factory, and default semantic factories are allowed if their concrete mapping is documented.
- Agreed not to add default semantic interface aliases for now. `MakeMap` may return `IHashMap`; no separate `IMap` alias is introduced yet.
- Agreed that map-like `Get`/`Put` and `TryGetValue`/`AddOrAssign` have distinct semantics and should not be treated as duplicate aliases in the final interface.
- Agreed that array-like indexed access does not need a base `TryGet`: invalid indexes are caller errors, checked `Get`/`Put` throw, and callers that need a non-throwing branch should check `Count` before indexing. `Unchecked` remains the explicit unsafe fast path.
- Agreed that unsafe fast-path method names use `Unchecked` as one word. Copied `UnChecked` spellings are transitional and should be renamed consistently during interface tuning.
- Corrected sequence mutation semantics after reviewing current `Vec`/`VecDeque` contracts: `Delete(Index)` discards by position, while copied `Remove(Index): T` extracts by position. Final indexed sequence APIs should use `RemoveAt(Index): T` / `TryRemoveAt(Index, out Element): Boolean`; `Remove(Index)` should be removed during interface tuning instead of kept as compatibility baggage. Value-based `Remove(Value)` is not the default indexed sequence meaning.
- Agreed that rich method-style algorithms and the three callback overload families should remain part of the container API experience. The next tuning target is cleaner interface appearance, inheritance clarity, and shared algorithm implementation reuse, not moving useful algorithms away from containers or reducing API count for its own sake. Redundant, wrong, confusing, or low-value APIs can still be removed.
- Agreed that `IArray<T>` is the rich capability base for mutable, indexable, contiguous-storage array-like sequences. `Vec` should inherit and reuse this layer; non-contiguous indexed containers such as ring-buffer deque implementations should not inherit it because they cannot honestly promise contiguous memory APIs such as `GetMemory`.
- Agreed that `TryLoadFrom` and `TryAppend` are natural common collection capabilities rather than array-only clutter. They should remain available and be regularized at the common collection/interface ownership layer during interface tuning.
- Agreed to preserve the distinct block operation semantics: `Overwrite` writes inside an existing range without changing `Count`, `Read` copies out, `Copy` copies internally, `Write` may extend using normal growth, and `WriteExact` may extend with exact capacity growth. `Overwrite` belongs to contiguous array capability; `Write`/`WriteExact` belong to growable vector-style capability.
- Agreed on size/capacity vocabulary: `Resize` changes logical `Count`; `EnsureCapacity` ensures absolute capacity; `Reserve` ensures append headroom (`Count + Additional`); `Exact` variants bypass the growth strategy; shrink/free-buffer operations belong to growable vector-style containers, not the array capability base.
- Reviewed `IVec<T>` dynamic sequence methods and recorded the interface direction: preserve the rich Vec sequence API, keep `Push`/`Pop`/`Peek`, distinguish `Delete` from `RemoveAt`, use explicit swap-removal naming for order-unstable extraction, keep `Drain`/`SplitOff`/`Splice`/`Retain`/`Filter`/`Dedup`, and regularize zero-count batch no-op behavior.
- Recorded the naming cleanup batch: `UnChecked` to `Unchecked`, `OverWrite` to `Overwrite`, `FindIF`/`CountIF`/`ReplaceIF` to `FindIf`/`CountIf`/`ReplaceIf`, `SizeUint` to `SizeUInt`, and parameter spacing cleanup. This should be done as a complete mechanical refactor with compile verification.
- Implemented the first low-risk naming cleanup batch across collections source units: `SizeUint` is now `SizeUInt`, and missing parameter spacing such as `aIndex:SizeUInt` was normalized in `arr`, `vec`, and `vecdeque` units.
- Verified the batch with `make -C tests/nextpas.core.collections/test_vec test`, `make -C tests/nextpas.core.collections/test_deque test`, `make -C tests/nextpas.core.collections/test_facade test`, and full `make test`; all completed with zero failures.

## 2026-05-28

- Implemented the second naming cleanup batch across collections source units: copied `OverWrite` identifiers, comments, internal calls, and exception messages are now spelled `Overwrite`.
- Kept `OverwriteOldest` circular-buffer policy names unchanged because they are a separate public concept, not the contiguous block overwrite operation.
- Implemented the third naming cleanup batch across collections source units: copied `UnChecked` identifiers, comments, internal calls, exception messages, and interface declarations are now spelled `Unchecked`.
- Kept calls to `nextpas.core.mem.utils.CopyUnChecked` unchanged because that symbol belongs to the `mem` module and is outside this collections-only batch.
- Implemented the fourth naming cleanup batch across collections source units: copied algorithm names now use PascalCase `If` spellings (`FindIf`, `FindIfNot`, `FindLastIf`, `FindLastIfNot`, `CountIf`, and `ReplaceIf`), including unchecked variants, internal `Do*` hooks, comments, and exception text.
- Confirmed there are no remaining `FindIF`, `FindLastIF`, `CountIF`, or `ReplaceIF` spellings in collections source or existing collections tests.
- Removed rejected short facade factories from `nextpas.core.collections`: `Vec`, `Deque`, `Map`, `Set_`, `OrdMap`, and `OrdSet` are no longer exported. The facade test now uses the accepted `MakeXxx` factory family.
- Implemented the next naming cleanup batch across collections source units: copied `FAFAFA_CORE_*` and `FAFAFA_COLLECTIONS_*` conditional symbols are now `NEXTPAS_CORE_*` or `NEXTPAS_COLLECTIONS_*` as appropriate.
- Added canonical `NEXTPAS_CORE_INLINE`, `NEXTPAS_CORE_ANONYMOUS_REFERENCES`, and `NEXTPAS_CORE_CONTRACTS` definitions to `nextpas.core.settings.inc` while keeping temporary `FAFAFA_CORE_*` compatibility aliases for non-collections copied modules such as `mem`.
- Started the indexed extraction naming batch. Surface review found positional `Remove`/`RemoveSwap` APIs on `Vec`, `VecDeque`, and `Deque`, plus an internal `MultiMap` use of vector swap-removal. Key/value `Remove` APIs in maps, sets, trie, cache, and forward list remain out of scope and should keep their names.
- Implemented the indexed extraction naming batch: positional extraction now uses `RemoveAt` / `SwapRemoveAt`, pointer and array extraction helpers now use `RemoveCopyAt` / `RemoveArrayAt` and `SwapRemoveCopyAt` / `SwapRemoveArrayAt`, `Deque.TryRemove` is now `TryRemoveAt`, and `MultiMap` now calls `Vec.SwapRemoveAt` internally.
- Verified the batch with residual scans for old positional names, `git diff --check`, focused `test_vec` / `test_deque` / `test_facade`, and full `make test`; all completed with zero failures.
- Added `TryRemoveAt` and `TrySwapRemoveAt` to `IVec<T>` / `TVec<T>` only. `VecDeque` / `Deque` did not receive a new swap-removal try API because their ring-buffer indexing semantics stay intentionally weaker than `Vec`.
- Verified the Vec try indexed extraction batch with `git diff --check`, symbol scan, focused `test_vec` / `test_facade`, and full `make test`; all completed with zero failures.
- Restored collections-specific planning files as `task_plan.collections.md`, `findings.collections.md`, and `progress.collections.md` because the root planning trio is currently owned by the active platform Wave 13 thread.
- Reviewed the next Vec/Array family interface-tuning candidates. `Ensure` was rejected as a mechanical rename because current implementations resize logical `Count`; the safer batch is exposing the already implemented checked partial collection `Overwrite` overload on `IArray<T>`.
- Exposed `IArray<T>.Overwrite(Index, Collection, Count)` as a checked partial collection overwrite overload and split the stale checked/unchecked doc block. No implementation behavior changed because `TArray<T>` and `TVec<T>` already had matching methods.
- Verified this batch with `git diff --check`, focused `test_vec` / `test_contracts` / `test_facade`, and full `make test`; all completed with zero failures.
- Started the next micro batch as an interface-doc cleanup only: removed stale `Unchecked` warning text from the checked partial collection `Overwrite` doc block in `IArray<T>`, keeping method declarations and implementations unchanged.
- Verified the doc-boundary cleanup with `git diff --check`, focused `test_vec` / `test_contracts` / `test_facade`, and full `make test`; all completed with zero failures.
- Started the next naming cleanup batch. Exact scans found no remaining `FindIF` / `CountIF` / `ReplaceIF` / `UnChecked` / `SizeUint` residues in collections source/tests, so the actionable cleanup is the copied `TVec.TrimToSize` Java compatibility alias.
- Removed `TVec.TrimToSize`; callers should use `ShrinkToFit`. Left `TVecDeque.TrimToSize(aNewSize)` unchanged because it trims logical length and is not the same capacity-shrink alias.
- Verified the alias cleanup with `git diff --check`, focused `test_vec` / `test_facade`, and full `make test`; all completed with zero failures.
- Started the next Vec surface cleanup batch. Removed the concrete-class-only `TVec.Pop(out Element): Boolean` alias, leaving `TryPop(var Element): Boolean` for non-throwing extraction and `Pop: T` for checked throwing extraction. Other container families with intentional `Pop(out): Boolean` contracts were left untouched.
- Verified the Vec pop alias cleanup with `git diff --check`, focused `test_vec` / `test_facade`, and full `make test`; all completed with zero failures.
- Started the next Vec tail-observation semantics batch. `TryPeek(var array, 0)` already succeeds and `PeekRange(0)` already returns `nil`; changed `TryPeekCopy(Pointer, 0)` to succeed as the same zero-count no-op while keeping `nil` invalid for non-zero counts.
- Verified the Vec TryPeek zero-count batch with `git diff --check`, focused `test_vec` / `test_facade`, and full `make test`; all completed with zero failures.
- Started the next Vec tail-extraction zero-count batch. `TryPop(var array, 0)` already succeeds; changed `TryPop(Pointer, 0)` to succeed without touching the destination pointer, while keeping `nil` invalid for non-zero counts.
- Verified the Vec TryPop pointer zero-count batch with `git diff --check`, focused `test_vec` / `test_facade`, and full `make test`; all completed with zero failures.

## Next

- Continue the naming cleanup implementation one batch at a time.
- Next interface-tuning batch: continue reviewing Vec and array-family method naming/ownership after the try indexed extraction gap.
- Continue the structural audit across remaining containers.
- Build a full facade public-surface map before deciding how to handle open generic interface visibility.
- Keep implementation tuning until after interface and architecture review are agreed.
