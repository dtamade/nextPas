# Atomic preferred path (consumer short guide)

> **Date**: 2026-07-26
> **Authority**: [`CONTRACT.md`](CONTRACT.md) §1.4 · [`README.md`](README.md)
> **Audience**: any module using `nextpas.core.atomic` (async, thread, net, lockfree, future HTTP, …)

## Prefer (new code)

| Need | API |
|------|-----|
| Scalar RMW / load-store | `atomic_load` / `atomic_store` / `atomic_fetch_*` + `mo_*` |
| CAS | `atomic_compare_exchange_strong` / `_weak` → **Boolean** + `var Expected` |
| Typed ownership | `TAtomicInt32` / `TAtomicUInt64` / `TAtomicBool` / `TAtomicPtr<T>` / … + PascalCase `moAcquire`… |
| Pointer byte offset | main facade `atomic_fetch_add/sub(var Pointer; PtrInt)` |
| Refcount | `TAtomicRefCount` only (`Inc` / `TryInc` / `Dec` / `Load` / `IntoInner`) |

Style rule: one naming family per function — do not mix `mo_acquire` and `moAcquire` in the same routine.

## Legacy (keep, do not spread)

| Surface | Note |
|---------|------|
| `AtomicCompareExchange32/64/Ptr` | Returns **observed value**, **not** Boolean. Success = `result = expected` (old expected). |
| PascalCase `AtomicLoad32` / `AtomicFetchAdd*` / `AtomicWait*` | Compat wrappers; equivalent to `atomic_*` |
| `atomic.compat` pointer bitwise | Do not grow on main facade |

**Tests covering legacy ≠ recommendation for new code.**

## Common mistakes

1. Treating `AtomicCompareExchange32` return as `True/False`.
2. Using `GetMut` / `IntoInner` under concurrent access.
3. Unaligned / packed storage as `TAtomic*`.
4. Wait/notify without a **predicate loop** (especially fallback buckets).
5. Resurrecting zero refcount via raw store on `TAtomicRefCount` storage.

## Verify residual (production)

```bash
make focused FOCUS=core/tests/nextpas.core.lockfree/test_lockfree_preferred_path
# production Atomic*( call form outside nextpas.core.atomic* should stay 0
```

Full semantics: [`CONTRACT.md`](CONTRACT.md), [`README.md`](README.md).
Lockfree joint status: [`../lockfree/READY.md`](../lockfree/READY.md).
