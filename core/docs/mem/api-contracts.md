# IAllocator API Contracts

Source of truth for the abstract allocator surface in
`nextpas.core.mem.intf`. Implementors and callers should treat this document
and the unit's `{** ... *}` comments as the same contract.

Related types: `TAllocatorTraits`, `EAllocError` / `TAllocError` in
`nextpas.core.mem.error`.

## IAllocator Contract

`IAllocator` is the canonical nextpas.core memory allocation interface. It
exposes five members: `GetMem`, `AllocMem`, `ReallocMem`, `FreeMem`, and
`Traits`.

### Ownership

- The **caller owns** every non-nil pointer returned by `GetMem`, `AllocMem`,
  or a successful `ReallocMem`.
- The caller must release that pointer with **`FreeMem` on the same
  `IAllocator` instance** that produced it (or the instance that currently
  owns the allocation after a successful realloc).
- The allocator instance must outlive any outstanding allocations made through
  it, unless a higher-level design (for example an arena reset) documents a
  different bulk lifetime.

### Zero-size

| Call | Required result |
|------|-----------------|
| `GetMem(0)` | `nil` |
| `AllocMem(0)` | `nil` |

Zero-size requests do not allocate and do not raise.

### Nil-pointer

| Call | Required result |
|------|-----------------|
| `FreeMem(nil)` | no-op |

Passing `nil` to `FreeMem` is always safe.

### Realloc semantics

| Call | Equivalent behavior |
|------|---------------------|
| `ReallocMem(nil, size)` | `GetMem(size)` |
| `ReallocMem(ptr, 0)` | `FreeMem(ptr)`, then return `nil` |
| `ReallocMem(ptr, size)` with `ptr <> nil` and `size > 0` | resize; may move the block and copy `min(old, new)` bytes |

On **failure** of a non-nil, non-zero realloc (`ptr <> nil` and `size > 0`),
the function returns `nil` and the **original pointer remains valid**. Callers
must not free or use a "new" pointer that was never returned.

### Double-free

Calling `FreeMem` twice on the same non-nil pointer is **undefined behavior**.

Debug allocators (for example Guard or Sentinel wrappers) may detect this and
raise `EAllocError` with codes such as `aeInvalidPointer`, `aeDoubleFree`, or
`aeSentinelCorrupted`. Production allocators may not detect it. Callers must
not rely on a raise; they must not double-free.

### Thread safety

Concurrency is **not** assumed by default. Whether methods may be called from
multiple threads at once depends on `Traits.ThreadSafe`:

- `ThreadSafe = True`: concurrent calls to all methods are allowed.
- `ThreadSafe = False`: the caller must serialize access (or use a
  thread-safe wrapper).

### Method summary

| Method | Success | OOM / failure | Special inputs |
|--------|---------|---------------|----------------|
| `GetMem(ASize)` | uninitialized block | `nil` | `ASize=0` → `nil` |
| `AllocMem(ASize)` | zero-filled block | `nil` | `ASize=0` → `nil` |
| `ReallocMem(APtr, ASize)` | new (or same) pointer | `nil` (original still valid when resize fails) | see table above |
| `FreeMem(APtr)` | releases ownership | n/a | `nil` → no-op |
| `Traits` | capability record | n/a | stable for the instance lifetime |

## Error Handling

### Out of memory

- `GetMem`, `AllocMem`, and failed resize paths of `ReallocMem` return **`nil`**.
- They **do not raise** for ordinary OOM under this contract.
- Callers must check for `nil` after every allocation attempt.

### Invalid pointer

- Freeing a pointer that was never returned by this allocator, or was already
  freed, is undefined behavior on the base contract.
- Debug allocators (Guard, Sentinel, tracking layers) may raise `EAllocError`
  with `aeInvalidPointer` or `aeSentinelCorrupted`.

### Double-free

- Same as invalid pointer at the contract level: undefined behavior.
- Debug allocators may raise `EAllocError` with `aeInvalidPointer`,
  `aeDoubleFree`, or `aeSentinelCorrupted`.

### Realloc not supported

- If `Traits.SupportsRealloc = False`, some implementors raise
  `aeReallocNotSupported` or document a fallback. Prefer checking `Traits`
  before relying on efficient resize.

## TAllocatorTraits

| Field | Meaning |
|-------|---------|
| `ZeroInitialized` | `AllocMem` returns memory filled with zeros. Does **not** force `GetMem` to zero-fill. |
| `ThreadSafe` | All five methods may be used concurrently from multiple threads. |
| `SupportsRealloc` | `ReallocMem` can resize efficiently (in place or with a supported move). When `False`, resize may be unsupported or expensive. |

## Implementor Guidelines

1. **Implement all five members** of `IAllocator`.
2. **Honor zero-size and nil contracts**: `GetMem(0)` / `AllocMem(0)` → `nil`;
   `FreeMem(nil)` → no-op; `ReallocMem(nil, size)` / `ReallocMem(ptr, 0)` as
   above.
3. **OOM returns `nil`** for allocation paths; do not raise for ordinary OOM
   unless a specialized debug mode is explicitly documented.
4. **On failed realloc of a live block**, keep the original pointer valid and
   return `nil`.
5. **Set `Traits` honestly**:
   - Set `ZeroInitialized` only if `AllocMem` always zeros.
   - Set `ThreadSafe` only if concurrent method calls are safe.
   - Set `SupportsRealloc` only if `ReallocMem` is a real, supported path.
6. **Do not invent ownership**: pointers must be freeable with this instance's
   `FreeMem` (or a clearly documented parent that shares the same free path).
7. **Prefer raising only for debug-detectable corruption** (`EAllocError` and
   `TAllocError` codes), not for normal control flow such as OOM.

## See also

- Unit: `core/src/nextpas.core.mem.intf.pas`
- Errors: `core/src/nextpas.core.mem.error.pas`
- Module overview: `core/docs/mem/README.md`
- Broader mem notes: `core/docs/mem/CONTRACT.md`, `core/docs/mem/API.md`
