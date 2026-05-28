# nextpas.core collections findings

## 2026-05-27: facade re-export limits under FPC 3.3.1

- `uses nextpas.core.collections` does not automatically expose generic interfaces from child units such as `IVec<T>` or `ILruCache<K,V>`.
- A direct probe with only `uses nextpas.core.collections` and `var V: specialize IVec<Integer>;` fails with `Identifier not found "IVec"`.
- Open generic aliases like `generic IVec<T> = specialize IVec<T>` do not compile in current FPC 3.3.1 syntax.
- Derived facade interfaces compile only in narrow unqualified cases, but they would create a distinct interface type and can change the contract of factories returning the original child-unit interfaces. Treat this as a separate design decision.
- Function/procedure callback types with identical signatures are assignment-compatible, so facade-level callback type re-export is a safe low-risk improvement.
- Decision for now: record this as an unresolved public-interface design problem and continue interface design discussion before changing the architecture.

## 2026-05-27: hashmap / treemap / lrucache base-intf ownership

- `hashmap.intf` correctly depends on `hashmap.base` because its Entry API signatures expose `TValueSupplierFunc` and `TValueModifierProc`.
- `treemap.intf` correctly depends on `treemap.base` because its range and Entry API signatures expose `TKeyValueCallback`, `TTreeValueSupplierFunc`, and `TTreeValueModifierProc`.
- `lrucache.intf` does not expose hash/equality callback types, so it does not need to depend on `lrucache.base`.
- `lrucache.pas` correctly depends on `lrucache.base` because its implementation and constructor use `THashFunc`, `TEqualsFunc`, and `TLruNode`.

## 2026-05-27: public factory design decisions

- `collections` is interface-first: normal users should receive interfaces from factories and should not need to instantiate implementation classes directly.
- Short factories such as `Vec<T>` are rejected for now because the family cannot stay clean around Pascal keywords such as `set`; `MakeXxx` is the unified factory naming family.
- The facade should not keep compatibility aliases for rejected short factories. Since the framework is unreleased, stale public constructors should be removed instead of carried as API baggage.
- A working public implementation such as `TreeMap`, `LinkedHashMap`, `VecDeque`, or `SkipList` should expose a matching public factory.
- Default semantic factories are acceptable when useful, for example `MakeMap<K,V>` as the recommended default map. These must clearly document which concrete implementation they currently choose.
- Do not add `IMap<K,V>`, `ISet<T>`, `IOrderedMap<K,V>`, or similar default semantic interface aliases at this stage. FPC generic alias and interface identity risks make this a poor fit for the current facade.

## 2026-05-27: map-like method semantics

- `TryGetValue(Key, out Value): Boolean` is the safe lookup form. It does not throw for a missing key and does not mutate the map.
- `Get(Key): Value` should mean the key must exist; absence is an exceptional condition.
- `Add(Key, Value): Boolean` inserts only when absent.
- `AddOrAssign(Key, Value): Boolean` inserts or updates and reports whether a new key was inserted.
- `Put(Key, Value)` writes without reporting whether it inserted or updated.
- Current copied code may still have transitional aliases such as `Get(Key, out Value)` or `Put` returning `Boolean`; these should be reviewed during interface tuning rather than treated as the final shape.

## 2026-05-27: sequence indexed access semantics

- `Get(Index): T` and `Put(Index, Value)` are checked operations and throw on invalid indexes.
- `GetUnchecked(Index): T` and `PutUnchecked(Index, Value)` are the unsafe fast path and require clear documentation that the caller owns bounds correctness.
- Do not add `TryGet(Index, out Value): Boolean` to the base array/indexed-access contract. For array-like containers, an invalid index is a caller error, and callers that want a non-throwing branch can check `Count` before indexing.
- Spell unsafe fast-path method names with `Unchecked` as one word, not `UnChecked`. Current copied names such as `GetUnChecked`, `ReadUnChecked`, and `SortUnChecked` are transitional and should be renamed consistently during interface tuning.
- Apply this model consistently across `Vec`, `Array`, `List`, `Deque`, and other array-like indexed sequence containers. Keep `TryXxx` for operations where failure is normal domain behavior, such as map lookup or empty pop.

## 2026-05-27: container algorithm API ergonomics

- Rich container algorithm methods are not a design flaw by themselves. Complete container capabilities naturally create a larger public surface than minimal standard-library containers.
- Do not move algorithms out of container APIs solely to make interfaces look smaller. Free-function algorithms would still need the same overload families and would make common use less direct.
- Keep the three callback overload families for functions, methods, and anonymous references when they improve call-site ergonomics. Replacing them with option records would make ordinary Pascal usage heavier.
- Future interface tuning should focus on semantic ownership, naming consistency, inheritance clarity, and removing true duplicates, not on flattening useful method-style APIs. Increasing the number of interfaces or methods is acceptable when it makes capability boundaries and reuse relationships clearer; removing APIs is acceptable when the design is redundant, wrong, semantically confusing, or not worth its maintenance burden.
- Implementation tuning should reuse shared algorithm cores where possible so rich interfaces do not imply repeated algorithm bodies in every container.

## 2026-05-27: IArray contiguous capability boundary

- `IArray<T>` should mean a mutable, indexable, contiguous-storage array-like sequence, not the universal parent for every linear or indexed container.
- The large algorithm surface on `IArray<T>` is acceptable because traversal, search, replace, rearrangement, sorting, binary search, and block memory operations are natural capabilities for contiguous arrays.
- `Vec` should inherit `IArray<T>` and reuse those capabilities because it would otherwise need to expose and implement the same operations itself.
- Non-contiguous indexed containers, such as ring-buffer deque implementations, should not inherit `IArray<T>` just to share indexed access. They must not promise `GetMemory` or other contiguous-storage contracts unless they can actually provide them.
- If non-contiguous sequences need shared indexed behavior later, introduce a separate indexed-sequence contract that does not expose contiguous memory.

## 2026-05-27: bulk load and append ownership

- `TryLoadFrom` and `TryAppend` are natural capabilities for collections in general: load a container and append a container without throwing on normal failure.
- These methods should not be removed merely because they appear while reviewing `IArray<T>`. They are not array-only concepts, but they are valid for array-like containers too.
- Interface tuning should regularize where these methods are declared. The likely owner is the common collection interface layer, with array/vector interfaces exposing inherited or specialized overloads where needed.
- Keep the semantic split between throwing `LoadFrom`/`Append`, unchecked `LoadFromUnchecked`/`AppendUnchecked`, and non-throwing `TryLoadFrom`/`TryAppend`.

## 2026-05-27: contiguous block read/write semantics

- Preserve the richer block operation model instead of collapsing it into fewer names.
- `Overwrite` is an array-like operation: it writes into an existing valid range and must not change `Count`.
- `Read` copies an existing valid range out to caller-owned storage and must not mutate the container.
- `Copy` copies an existing valid range within the same contiguous container and must not change `Count`.
- `Write` is a vector-style operation: it writes at an index and may extend `Count`; capacity growth follows the container's normal growth strategy.
- `WriteExact` has the same write/extend shape as `Write`, but when growth is required it grows capacity exactly to the required size instead of applying the growth strategy. Its name should be documented around exact capacity behavior, not mistaken for "must not extend" behavior.
- `Overwrite` naturally belongs on the contiguous array capability layer. `Write` and `WriteExact` naturally belong on the vector/growable sequence layer because they can extend logical length.
- Interface tuning should make overload symmetry explicit, especially checked and unchecked partial container overloads such as `Overwrite(Collection, Count)`.

## 2026-05-28: size and capacity semantics

- Preserve the distinct size/capacity vocabulary rather than flattening it.
- `Resize(NewSize)` changes logical `Count`. Growing initializes new elements; shrinking finalizes/discards tail elements. Capacity growth follows the container's normal policy.
- `EnsureCapacity(Capacity)` ensures an absolute capacity and does not change `Count`.
- Existing `IArray<T>.Ensure(Count)` currently means ensuring absolute element capacity. During naming cleanup, prefer `EnsureCapacity` for this meaning because plain `Ensure` is too easy to confuse with `Reserve`.
- `Reserve(Additional)` is a growable-vector operation: it ensures room for `Count + Additional` elements and follows the normal growth strategy.
- `ReserveExact(Additional)` is the exact-capacity counterpart of `Reserve`: it ensures room for `Count + Additional` elements without applying the growth strategy.
- `ResizeExact(NewSize)` changes logical `Count` and sets capacity exactly to `NewSize`.
- `Shrink`, `ShrinkTo`, `ShrinkToFit`, and `FreeBuffer` are explicit vector capacity-release controls. They belong to growable vector-style containers rather than the contiguous array capability base.
- The key distinction for public docs: `Resize` is about length, `EnsureCapacity` is about absolute capacity, `Reserve` is about append headroom, and `Exact` is about bypassing the growth strategy.

## 2026-05-28: Vec dynamic sequence semantics

- `IVec<T>` should own growable sequence operations that change logical order or length: `Insert`, `Push`, `Pop`, `Peek`, `Delete`, `DeleteSwap`, indexed extraction, `Drain`, `SplitOff`, `Splice`, `Retain`, `Filter`, `Any`, `All`, `Dedup`, and `DedupBy`.
- `Insert(Index, ...)` inserts before `Index`, accepts `0 <= Index <= Count`, preserves existing element order, and may grow capacity.
- `Push(...)` is the tail append family. It can coexist with common `Append` because `Push` expresses stack/vector usage while `Append` expresses generic collection composition.
- `Pop` removes from the tail. Checked `Pop` throws on empty; `TryPop` returns `False` for empty or invalid parameters. Batch `TryPop(..., Count = 0)` should be a successful no-op.
- `Peek` observes tail elements without mutation. Checked `Peek` throws on empty; `TryPeek` returns `False` for empty or invalid parameters. Borrowed pointer APIs such as `PeekRange(Count)` may return `nil` for `Count = 0` because no element range exists.
- `Delete(Index[, Count])` discards elements by position and preserves order. `DeleteSwap(Index[, Count])` discards elements by position without preserving order.
- Indexed extraction should not keep public `Remove(Index)` because it is ambiguous with value-based removal. Final preserving extraction names should be `RemoveAt(Index): T` and `TryRemoveAt(Index, out Element): Boolean`.
- Order-unstable indexed extraction needs an explicit swap-removal name, for example `SwapRemoveAt(Index): T` and `TrySwapRemoveAt(Index, out Element): Boolean`, rather than `RemoveSwap(Index)`.
- Pointer and dynamic-array extraction helpers remain useful for high-performance callers, but final names should include positional intent, for example `RemoveCopyAt` / `RemoveArrayAt` and swap-removal counterparts.
- `Drain`, `SplitOff`, and `Splice` are valid vector sequence operations, not excess API. Their range overflow policy must be explicit: current copied code clips some counts while `Delete` throws, and the final public contract should either document that difference or regularize it during interface tuning.
- `Filter` returns a new vector and `Retain` mutates in place. `Any` and `All` are natural short-circuit sequence predicates. `Dedup` and `DedupBy` are natural adjacent-duplicate vector operations.
- Zero-count batch operations should be successful no-ops where no element pointer is semantically required. This should be applied consistently across `TryPop`, `TryPeek`, copy/remove helpers, and future range operations.

## 2026-05-28: naming cleanup batch

- Naming cleanup is required for framework polish, but it should be mechanical and complete rather than scattered across unrelated refactors.
- `Unchecked` is the final spelling for unsafe fast-path methods. Rename all copied `UnChecked` identifiers and references as one batch.
- `Overwrite` is the final spelling. Rename copied `OverWrite` identifiers and references as one batch.
- Algorithm names should use normal PascalCase word boundaries: `FindIf`, `FindIfNot`, `FindLastIf`, `FindLastIfNot`, `CountIf`, `ReplaceIf`. Copied `FindIF`, `CountIF`, and `ReplaceIF` spellings are transitional.
- Type spelling should consistently use `SizeUInt`, not `SizeUint`.
- Parameter declarations should follow project spacing, for example `aIndex: SizeUInt` instead of `aIndex:SizeUInt`.
- The batch must update public interfaces, implementation method declarations/bodies, comments/docs, tests, examples, and facade references together, then run compile verification. Partial renames will break interface implementation matching in FPC.
- Pure comment cleanup can ride with the matching identifier batch when it prevents stale docs; unrelated prose cleanup should wait.

## 2026-05-28: collections macro naming cleanup

- Collections source should use `NEXTPAS_*` conditional symbols instead of copied `FAFAFA_*` symbols.
- `NEXTPAS_CORE_INLINE`, `NEXTPAS_CORE_ANONYMOUS_REFERENCES`, and `NEXTPAS_CORE_CONTRACTS` are the canonical core-wide symbols defined by `nextpas.core.settings.inc`.
- `NEXTPAS_COLLECTIONS_TYPE_ALIASES`, `NEXTPAS_COLLECTIONS_DISABLE_HASH`, `NEXTPAS_COLLECTIONS_FACADE`, and `NEXTPAS_COLLECTIONS_STRICT_ERASEAFTER` are collections-owned symbols because they control collections API shape or collections implementation behavior.
- Keep temporary `FAFAFA_CORE_*` compatibility definitions in `nextpas.core.settings.inc` until non-collections copied modules such as `mem` are migrated. Do not rename mem macro references in the collections-only batch.

## 2026-05-27: sequence mutation method semantics

- `Delete(Index)` means delete by position and discard the element.
- Current copied `Vec` and `VecDeque` interfaces use `Remove(Index): T` and `Remove(Index, var Element)` for indexed extraction, but this is transitional copied API rather than the final public shape.
- Final indexed sequence APIs should use `RemoveAt(Index): T` and `TryRemoveAt(Index, out Element): Boolean` for indexed extraction.
- Do not keep `Remove(Index)` alongside `RemoveAt(Index)` as a public synonym. The framework is unreleased, so there is no compatibility burden that justifies carrying duplicate names.
- Value-based `Remove(Value)` belongs only to containers whose contract is explicitly value/key lookup and removal.
- Positional pointer/array extraction helpers should also carry `At`: `RemoveCopyAt` and `RemoveArrayAt` for order-preserving extraction; `SwapRemoveAt`, `SwapRemoveCopyAt`, and `SwapRemoveArrayAt` for order-unstable extraction. This keeps the whole indexed extraction family visibly separate from value/key removal.
- The pure rename batch should not hide a larger API addition. `Deque` and `VecDeque` already had a non-throwing indexed extraction method and now expose it as `TryRemoveAt`; `Vec` still needs a separate decision/batch for adding `TryRemoveAt` and possibly `TrySwapRemoveAt`.

## 2026-05-28: Vec try indexed extraction

- `Vec` should expose non-throwing single-element indexed extraction as `TryRemoveAt(Index, var Element): Boolean` and `TrySwapRemoveAt(Index, var Element): Boolean`.
- `TryRemoveAt` preserves order and mirrors `RemoveAt`; `TrySwapRemoveAt` may reorder and mirrors `SwapRemoveAt`.
- Invalid indexes return `False`. Valid indexes remove the element and return `True`.
- Do not add `TrySwapRemoveAt` to `Deque` / `VecDeque` in this batch. Ring-buffer deques retain weaker indexed semantics than contiguous vectors, and a symmetric swap-removal try API would overstate their vector-like contract.

## 2026-05-28: IArray checked partial overwrite exposure

- `IArray<T>` documented partial collection overwrite but exposed only `OverwriteUnchecked(Index, Collection, Count)`.
- `TArray<T>` and `TVec<T>` already implement the checked `Overwrite(Index, Collection, Count)` overload, so the interface should expose it instead of forcing callers to use the unchecked form for partial collection overwrite.
- `Ensure` must not be mechanically renamed to `EnsureCapacity` yet. Current `TArray.Ensure` and `TVec.Ensure` call `Resize` and change logical `Count`, while `TVec.EnsureCapacity` only guarantees backing capacity. The final name and ownership require a separate interface decision.
- The checked partial collection `Overwrite` doc block must not include the `Unchecked` convention text. Checked/unchecked overload pairs should keep their public docs visibly separated so the safe API contract is not weakened by copied warning text.

## 2026-05-28: Vec compatibility alias cleanup

- Exact scans found no remaining `FindIF`, `FindIFNot`, `CountIF`, `ReplaceIF`, `UnChecked`, or `SizeUint` symbols in collections source/tests.
- `TVec.TrimToSize` was only a Java compatibility alias for `ShrinkToFit`. Because nextpas.core has no published compatibility burden, the alias should be removed rather than carried as a stale public concrete-class method.
- `TVecDeque.TrimToSize(aNewSize)` is a different logical-length trimming helper used by deque split/trim flows. It should not be changed in the `TVec` capacity-alias cleanup batch.
- `TVec.Pop(out Element): Boolean` was another concrete-class-only compatibility alias for `TryPop(var Element): Boolean`. `IVec<T>` already exposes the intended split: non-throwing `TryPop(...)` and checked throwing `Pop: T`.
- `Stack`, `Queue`, `Deque`, and `VecDeque` have their own `Pop(out): Boolean` contracts. Removing the `TVec` alias does not imply changing those container families in the same batch.
- `TVec.TryPeekCopy(Pointer, 0)` should mirror the existing dynamic-array `TryPeek(Array, 0)` behavior and succeed as a no-op. A nil pointer remains invalid when `Count > 0`.
- `TVec.PeekRange(0)` should continue returning `nil`, because it returns a borrowed internal range pointer and no element range exists for zero count.
- `TVec.TryPop(Pointer, 0)` should mirror dynamic-array `TryPop(Array, 0)` and return `True` without reading `aDst` or mutating the vector. A nil destination remains invalid when `Count > 0`.
- `TVec.RemoveCopyAt`, `RemoveArrayAt`, `SwapRemoveCopyAt`, and `SwapRemoveArrayAt` already treat `Count = 0` as successful checked no-ops. Pointer variants must not touch `aDst` in that path; dynamic-array variants currently leave the destination array length unchanged.
- `IVec<T>` delete/remove docs should not mention negative counts because their count parameters are `SizeUInt`. The useful contract is zero-count no-op, nil destination behavior for pointer variants, and range errors for invalid index/count spans.
- `Drain(Start, Count)` final range contract for Vec-like sequence APIs should be: `Count = 0` returns an empty Vec and leaves the source unchanged; `Count > 0` requires `Start < CountOfSource`; if `Start` is valid but `Count` extends past the tail, the drained range is clipped to the tail.
- `SplitOff(Index)` keeps the Rust-like split contract: `Index <= Count` is valid, `Index = Count` returns an empty right-hand vector, and `Index > Count` raises `EOutOfRange`.
- `Splice(Index, RemoveCount, Insert)` keeps the JavaScript/Rust-like replacement contract: `Index <= Count` is valid, `RemoveCount = 0` is pure insertion, and an oversized remove count is clipped to the tail before insertion.
