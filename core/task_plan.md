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

## Verification Commands

- `git diff --check`
- `make -C tests/nextpas.core.collections/test_facade test`
- `make test`
