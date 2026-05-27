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
