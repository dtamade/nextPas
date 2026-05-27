# nextpas.core collections refactor plan

## Goal

Stabilize the `collections` module copied from `fafafa.core`, then refactor it into the `nextpas.core` facade/base/intf/implementation architecture without simplifying behavior.

## Active Scope

- Only `src/nextpas.core.collections*.pas` and collections planning/verification records.
- Do not touch platform/compiler work in this thread.
- Do not add broad unit tests during architecture churn unless needed as a compile/contract probe.

## Current Phase

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

## Verification Commands

- `git diff --check`
- `make -C tests/nextpas.core.collections/test_facade test`
- `make test`
