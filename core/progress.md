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
- Agreed that indexed sequence containers use checked access by default, optional `TryGet`, and explicit `Unchecked` methods for unsafe fast paths.

## Next

- Continue the interface design discussion one decision at a time before more code changes.
- Continue the structural audit across remaining containers.
- Build a full facade public-surface map before deciding how to handle open generic interface visibility.
- Keep implementation tuning until after interface and architecture review are agreed.
