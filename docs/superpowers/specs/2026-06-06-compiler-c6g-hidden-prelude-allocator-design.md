# nextPas compiler C6-G hidden-prelude allocator design

## What this changes

C6-F closed the allocator's brk-heap correctness gap for free-list reuse,
top-of-heap reclaim, and repeated adjacent coalesce. The remaining allocator
gap is not just "support mmap somehow", but "support mmap without poisoning the
meaning of the pointer returned by `@np_alloc`".

This design makes large allocation a first-class allocator capability by giving
`@np_alloc` and `@np_free` an internal hidden prelude for mmap-backed blocks.
Small blocks keep the current brk/free-list path. Large blocks bypass the brk
heap, carry their allocator metadata in a prelude that callers never see, and
return directly to the OS through `munmap`.

The important property is that the public contract does not change:

- callers of `@np_alloc` still receive a usable payload pointer
- callers of `@np_free(ptr %raw, i64 %size)` still pass the same payload/base
  pointer they received before
- object allocation still preserves the current 24-byte object header ABI

The new metadata exists only in the hidden allocator prelude for mmap-backed
blocks.

## Why C6-G needs this shape

The current allocator has two truths that matter:

1. `@np_alloc` is not object-only. It also backs direct payload consumers such
   as string concat buffers and array storage.
2. Direct consumers treat the returned pointer as the first usable byte of
   payload.

That means a "large block marker" cannot be stored inside the returned payload
region. Writing allocator metadata into `raw+16` or any other visible payload
offset would corrupt real data for non-object consumers.

That is why the strongest long-term direction is a hidden-prelude allocator
contract, not an object-only special case and not a visible-payload marker.

## Design goals

- Keep `@np_alloc` and `@np_free` as the single allocator boundary for both
  object and non-object consumers.
- Preserve the current 24-byte object header ABI.
- Preserve the current direct `@np_alloc` payload contract.
- Add mmap/munmap capability without widening every caller-visible allocation
  header.
- Keep the existing small-allocation brk/free-list/coalesce path intact.
- Create room for future allocator metadata growth such as page alignment,
  allocation statistics, diagnostics, and policy tuning.

## Non-goals

This slice does not introduce:

- address-ordered free-list insertion
- string or dynarray release
- runtime allocation statistics reporting
- allocator diagnostics beyond the current invalid-release trap
- page-cache reuse for mmap-backed large blocks
- a unified policy that reuses large mmap blocks from a secondary free-list

## Current truth to preserve

These facts stay true after C6-G:

- `@np_alloc(i64 %size)` still returns a caller-usable payload pointer.
- `@np_free(ptr %raw, i64 %size)` still accepts the caller-visible block
  pointer, not an internal mmap base pointer.
- `@np_object_alloc(i64 %size)` still returns `payload = raw + 24` for the
  object header it owns.
- small allocations still use the current first-fit free-list and brk fallback.
- small frees still use top-of-heap reclaim and restart-scan coalesce.

## Hard allocator contracts

This slice has to freeze three contracts before implementation:

### `@np_alloc` size contract

`@np_alloc(i64 %size)` receives the exact allocator request size for the block
it is about to return.

- direct payload consumers pass the payload length they want to own
- `@np_object_alloc(i64 payload_size)` computes `%total = payload_size + 24`
  and passes `%total` into `@np_alloc`

That means object-path thresholding is based on `%total`, not on the object
payload length alone.

### `@np_free` size contract

`@np_free(ptr %raw, i64 %size)` receives the same allocator request size that
was previously passed into `@np_alloc` for the block now being released.

- direct payload free passes the original direct request size
- object free must no longer pass the object payload size into `@np_free`
- `@np_object_release_valid(ptr %raw, i64 payload_size)` must compute
  `%alloc.size = payload_size + 24` and pass `%alloc.size` into `@np_free`

This change is required so `@np_free` can decide whether it is even allowed to
probe for a hidden prelude.

### Threshold ownership

The large-allocation threshold is allocator-private policy, not a language
contract and not part of the external object ABI.

The first C6-G implementation should freeze these allocator-private constants:

- `NP_ALLOCATOR_PAGE_SIZE = 4096`
- `NP_ALLOCATOR_PRELUDE_SIZE = 16`
- `NP_ALLOCATOR_LARGE_THRESHOLD = 65536`

Future slices may retune these constants, but C6-G must treat them as fixed
internal helper constants and use the same values in alloc, free, contracts,
and runtime smoke.

## Two allocator families

After C6-G the allocator has two internal families:

### Small family

Small allocations keep the existing layout and lifecycle:

- allocation request enters `@np_alloc`
- allocator first scans `@__heap_free`
- if no fitting block exists, allocator extends the brk heap
- returned pointer is the heap block base
- free path uses `%size` to recover `%free.total`, then does top reclaim or
  free-list/coalesce

Nothing in this path should change semantically.

### Large family

Large allocations become mmap-backed:

- allocation request enters `@np_alloc`
- allocator checks a fixed large-allocation threshold using the request size
- for large requests, allocator maps a region bigger than the caller-visible
  payload
- the mapped region starts with a hidden allocator prelude
- the returned pointer is `mapped_base + prelude_size`
- the caller never sees or touches the hidden prelude
- free path subtracts `prelude_size` from the payload pointer, validates the
  prelude, and unmaps the full region

This is the long-term-stable shape because it keeps allocator metadata private.

## Hidden prelude layout

The first C6-G version should keep the prelude minimal and explicit.

Recommended prelude fields:

- offset 0: allocator kind / large-allocation magic
- offset 8: mapped length in bytes

That gives a 16-byte prelude:

```text
mapped_base
  +0   i64 magic
  +8   i64 mapped_len
payload_ptr = mapped_base + 16
```

The initial magic can be a fixed 64-bit constant owned by the allocator. The
mapped length is the exact length passed to `munmap`.

No caller-visible API should depend on these offsets. They are allocator-private
metadata.

The first C6-G implementation should freeze one explicit magic value:

- `NP_ALLOCATOR_LARGE_MAGIC = 131388245100000016`

## Threshold and size model

The threshold decision belongs in `@np_alloc`, based on the caller-visible
request size passed into that helper.

For direct payload users, `%size` is already the payload length.
For object allocation, `@np_object_alloc` still computes `%total = %size + 24`
and passes that full object block size into `@np_alloc`.

That means the threshold applies to the actual allocator request, not just the
object payload length.

This keeps the decision local and avoids special object-only policy branches.

## Size and mapping invariants

These invariants must hold for every mmap-backed large block:

- `requested_size` is the exact `%size` passed to `@np_alloc`
- `mapped_len = round_up(requested_size + prelude_size, page_size)`
- `mapped_len` must be stored verbatim in the hidden prelude
- the stored `mapped_len` must be the exact length passed to `munmap`
- the pointer returned to the caller is `mapped_base + prelude_size`

No path is allowed to recompute a different `munmap` length later from a fresh
rounding formula. The stored mapped length is the single source of truth.

### Overflow rules

The allocator must reject these cases through a fatal allocator fault path:

- `requested_size + prelude_size` overflows `i64`
- `requested_size + 24` overflows when `@np_object_alloc` computes `%total`
- `round_up(requested_size + prelude_size, page_size)` overflows `i64`
- stored `mapped_len` is smaller than `requested_size + prelude_size`

Silent wraparound is not allowed.

## Allocation path

The intended C6-G `@np_alloc` shape is:

1. entry checks whether `%size` is at or above the large-allocation threshold
2. small path continues to the current free-list scan and brk logic
3. large path computes `%mapped_len = round_up(%size + prelude_size, page_size)`
4. large path issues `mmap`
5. large path writes the hidden prelude at the mapped base
6. large path returns `mapped_base + prelude_size`

The important ownership rule is:

- the returned pointer always names the first caller-usable payload byte

Large allocation must not reuse the brk heap globals and must not push anything
into `@__heap_free`.

### `mmap` failure semantics

The first C6-G implementation should treat mmap failures as fatal runtime
faults, consistent with the current minimal invalid-release trap model.

- syscall result equal to `MAP_FAILED` triggers allocator fault
- allocator fault shape is an internal helper:
  `@np_allocator_fault(i64 %code, i64 %arg0, i64 %arg1)`
- the helper immediately calls `@llvm.trap()` and emits `unreachable`

The first code set should be:

- `1` = object total overflow
- `2` = prelude add overflow
- `3` = page-round overflow
- `4` = mmap failed
- `5` = large free magic mismatch
- `6` = stored mapped length invalid
- `7` = munmap failed

## Free path

The intended C6-G `@np_free` shape is:

1. entry first checks `if %size < large_threshold`
2. if `%size < large_threshold`, it must go directly to the existing small free
   path and must not read `%raw - prelude_size`
3. only if `%size >= large_threshold` may the helper compute
   `%prelude.base = %raw - prelude_size`
4. large-candidate path loads the prelude magic and stored mapped length
5. if the magic mismatches, allocator fault `large free magic mismatch`
6. if the stored mapped length is invalid, allocator fault `stored mapped length invalid`
7. otherwise issue `munmap(prelude_base, mapped_len)` and return immediately
8. small path remains the current top-of-heap reclaim plus restart-scan
   coalesce path

This order is the critical safety rule for C6-G: small-family frees must never
probe memory before `%raw`.

This also makes large-vs-small a real allocator-family split instead of a
visible payload marker.

### `munmap` failure semantics

`munmap` failure is fatal in the first C6-G slice.

- `munmap` non-zero result triggers allocator fault code `7`
- the allocator does not retry, warn, or fall back to the small free path

That keeps the first implementation simple, explicit, and verifier-friendly.

## Validation model

The first C6-G slice should stay pragmatic:

- large free path validates only the hidden-prelude magic before taking the
  `munmap` branch, plus the stored mapped length invariants
- small free path keeps using the current object-header validation through
  `@np_object_free_release`

This means C6-G is still not a complete general invalid-free detector for every
non-object direct allocation. That is acceptable because the current compiler
runtime contract already only gives strong ownership validation to the object
path.

## Object path impact

`@np_object_alloc` does not need a new public contract.

It still:

- computes `%total = %size + 24`
- delegates to `@np_alloc`
- writes the 24-byte object header into the returned raw block
- returns `raw + 24`

When `@np_alloc` decides that `%total` is large, the object block simply lives
inside the mmap-backed payload region. The object header remains at offset 0 of
that payload block, exactly as before.

This is the key reason the hidden-prelude design preserves the 24-byte ABI.

## Direct payload consumer impact

Direct consumers such as string concat and array allocation also keep their
existing contract:

- they still receive a pointer to the first payload byte
- they do not need to know whether the allocator used brk or mmap
- they do not need a new header or marker protocol

This is what makes the hidden-prelude design stronger than the visible-marker
alternatives.

## Focused verification envelope

The first C6-G proof can no longer be source-contract only. It needs one direct
runtime smoke in addition to the LLVM source contracts.

### RED source-contract additions

Minimum LLVM contract additions:

1. `@np_alloc` has a large-allocation branch before the small free-list/brk path
2. large path computes page-rounded `mapped_len`
3. large path issues `mmap`
4. large path writes hidden-prelude magic and mapped length
5. large path returns `mapped_base + prelude_size`
6. `@np_free` first checks `%size < large_threshold` before any prelude probe
7. large free path subtracts `prelude_size` only after the threshold gate
8. large free path issues `munmap` with the stored mapped length
9. small free path still contains the current top-reclaim and coalesce shape
10. allocator fault helper traps for overflow, mmap failure, magic mismatch,
    mapped-length invalidity, and munmap failure
11. `@np_object_alloc` still writes the 24-byte object header into the payload
    region returned by `@np_alloc`

The existing focused tests should be extended, not replaced:

- `test_hir_object_free_contract`
- `test_hir_class_alloc_contract`

### RED runtime-smoke additions

Add one focused large-allocation toolchain smoke for direct payload consumers
and one focused LLVM destructor smoke for large objects:

1. direct large allocation toolchain smoke:
   - request `NP_ALLOCATOR_LARGE_THRESHOLD` bytes through a synthetic direct
     `@np_alloc` call
   - write the first byte and the last byte of the returned block
   - read both bytes back successfully
   - free the block through `@np_free(ptr, request_size)`
   - this proves the returned pointer begins at usable payload, not at the
     hidden prelude, and that `munmap` uses the stored mapped length
2. object large allocation LLVM destructor smoke:
   - allocate an object whose `%total` crosses the large threshold
   - exercise constructor/destructor or destroy/free flow successfully
   - keep the source contract assertion that object payload remains `raw + 24`

### Focused gates

Focused verification for the first implementation should include:

- `test_hir_object_free_contract`
- `test_hir_class_alloc_contract`
- the new large-allocation toolchain smoke
- a focused LLVM object destroy/free smoke covering the large object path

### Closeout gates

Closeout verification for C6-G should be:

- `git diff --check`
- `make hygiene`
- `./build/verify_local.sh`

## Risks and tradeoffs

### Why this is stronger than an object-only mmap path

An object-only path would leave direct `@np_alloc` consumers outside the real
allocator contract. That would postpone the hardest ABI problem instead of
solving it.

### Why this is stronger than a visible payload marker

A visible payload marker contaminates memory the caller believes is theirs. That
is fundamentally incompatible with direct payload users.

### What this still leaves for later

This design still leaves open:

- whether large frees should ever be cached instead of immediately unmapped
- whether the allocator should gain stronger validation for non-object direct
  allocations

Those are real next-stage questions, but they do not block the first hidden
prelude implementation.

## Recommended next step

Implement C6-G with TDD in the existing compiler allocator contract tests:

- first freeze the updated alloc/free size contracts and family-decision order
  in focused LLVM source contracts
- then add the direct large-allocation runtime smoke and the large-object smoke
- then emit the minimal mmap/munmap implementation plus allocator fault helper
- then rerun the focused gates and the full local verification gate
