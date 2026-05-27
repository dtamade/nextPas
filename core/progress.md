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

## Next

- Continue the interface design discussion one decision at a time before more code changes.
- Continue the structural audit across remaining containers.
- Build a full facade public-surface map before deciding how to handle open generic interface visibility.
- Keep implementation tuning until after interface and architecture review are agreed.
