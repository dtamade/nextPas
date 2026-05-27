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
- Apply this model consistently across `Vec`, `Array`, `List`, `Deque`, and other array-like indexed sequence containers. Keep `TryXxx` for operations where failure is normal domain behavior, such as map lookup or empty pop.

## 2026-05-27: sequence mutation method semantics

- `Delete(Index)` means delete by position and discard the element.
- Current copied `Vec` and `VecDeque` interfaces use `Remove(Index): T` and `Remove(Index, var Element)` for indexed extraction, but this is transitional copied API rather than the final public shape.
- Final indexed sequence APIs should use `RemoveAt(Index): T` and `TryRemoveAt(Index, out Element): Boolean` for indexed extraction.
- Do not keep `Remove(Index)` alongside `RemoveAt(Index)` as a public synonym. The framework is unreleased, so there is no compatibility burden that justifies carrying duplicate names.
- Value-based `Remove(Value)` belongs only to containers whose contract is explicitly value/key lookup and removal.
