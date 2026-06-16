# nextPas compiler C6-H1 dynarray release first-slice design

## Goal

Freeze the first post-C6-G runtime-lifecycle slice as a narrow, verifiable
dynarray-only contract. This slice is not "managed runtime finished". It is
"standalone owned dynarray slots stop leaking through repeated `SetLength` and
ordinary function/program exit, without pretending that string aliasing or
object-field finalization are already solved."

## Recommendation

Do **not** start with unified string + dynarray release.

Start with **C6-H1 standalone dynarray release**:

- standalone owned dynarray vars use explicit resize/release helpers
- repeated `SetLength` frees or reuses old storage through one helper boundary
- owned dynarray locals and top-level vars release on ordinary `Exit` /
  implicit return / `Halt`
- borrowed dynarray params are explicitly marked borrowed and never released by
  the callee

Keep these out of scope for this first slice:

- string release
- object-field dynarray release
- array return ownership
- managed element finalization
- exception/unwind cleanup

This is the smallest slice that is still honest, testable, and aligned with
the current codebase truth.

## Why not string first

Current string lowering is not unique-ownership-friendly:

- substring/copy is pointer aliasing, not owned copy
  - `ProcessCopyStr` writes `dst.ptr = src.ptr + offset` and `dst.len = len`
    instead of allocating a new buffer
  - see `compiler/ir/np_hir_builder.pas:4010`
- plain string copy is shallow pointer/length copy
  - `ProcessAssignStrCopy` only copies `%ptr/%len`
  - see `compiler/ir/np_hir_builder.pas:4163`
- concat allocates fresh heap storage through `@np_alloc`, but there is still
  no release or alias tracking
  - `ProcessAssignStrConcat` lowers to `str_concat`
  - `@np_str_concat` allocates with `@np_alloc(i64 %total)`
  - see `compiler/ir/np_hir_builder.pas:4449` and
    `compiler/ir/np_hir_llvm_emitter.pas:1309`
- string return has a dedicated `ret-str-runtime` path, so ownership would
  immediately spill into call/return ABI and alias rules
  - see `compiler/sema/np_semantic_analyzer.pas:10094` and
    `compiler/sema/np_semantic_analyzer.pas:12385`

That means string release is blocked on a larger design:

- borrowed vs owned string slots
- substring alias lifetime
- shallow copy vs move vs refcount rules
- function return ownership

Dynarray does not have that same surface today.

## Why dynarray can be sliced cleanly first

Current dynarray lowering is much narrower:

- no dedicated array return node exists today
  - explicit/implicit function exit only emits `ret-str-runtime` or scalar
    `ret-runtime`
  - there is no `ret-arr-runtime`
  - see `compiler/sema/np_semantic_analyzer.pas:10094` and
    `compiler/sema/np_semantic_analyzer.pas:12385`
- ordinary standalone `SetLength(arr, n)` already has a single producer
  boundary
  - sema emits `setlength-arr-runtime`
  - builder lowers that to `arr_alloc` / `arr_alloc_sized`
  - emitter maps both directly to `@np_alloc`
  - see `compiler/sema/np_semantic_analyzer.pas:10993`,
    `compiler/ir/np_hir_builder.pas:4519`,
    `compiler/ir/np_hir_llvm_emitter.pas:661`
- current standalone dynarray slots are just `%ptr/%len`
  - local/global slots are created by `var-decl-arr-runtime`
  - parameter slots are also currently lowered into the same shape
  - see `compiler/ir/np_hir_builder.pas:3124`

Because the current supported dynarray surface is mostly "standalone slot owns
one heap block addressed by `%ptr` and sized by `%len * elem_size`", C6-G's
request-size allocator contract is already enough to free those blocks without
inventing another payload header.

## Alternatives considered

### Option A: unified string + dynarray release now

Pros:

- moves faster toward the long-term managed-runtime story

Cons:

- mixes two different ownership problems
- immediately drags in string alias/refcount/call-return rules
- not minimal enough for RED

Rejected for C6-H1.

### Option B: dynarray-only standalone release first

Pros:

- uses existing `%ptr/%len` slot model
- reuses C6-G `@np_free(ptr, request_size)` contract directly
- gives a clean RED path for `SetLength` and ordinary exits
- does not lie about string or object-field maturity

Cons:

- leaves object-field dynarray cleanup and string ownership for later slices

Recommended.

### Option C: allocator-only follow-up such as address-ordered insertion

Pros:

- technically smaller than lifecycle work

Cons:

- does not address the next correctness debt called out by current goal trees
- leaves `SetLength`-driven leaks untouched

Rejected as the next compiler slice.

## Current truth to preserve

These facts remain true after C6-H1:

- direct `@np_alloc` payload semantics stay unchanged
- C6-G hidden-prelude large-family rules stay allocator-private
- standalone dynarray data pointer still points at element 0
- dynarray length still lives in the existing `%name$len` slot
- string lowering stays exactly as-is in this slice
- current field-array path stays preserved, not silently redefined

## Slice boundary

### In scope

1. Standalone owned dynarray slots
   - local `var` dynarray declarations
   - top-level program dynarray vars lowered in `_start`
2. Borrowed dynarray params
   - open-array style incoming `%ptr/%len`
   - callee may read/write through the borrowed slot but must not release it
3. Repeated standalone `SetLength`
   - old storage must be copied/freed through one helper
4. Ordinary owned-slot cleanup points
   - explicit `Exit`
   - implicit function/procedure end
   - `Halt`

### Out of scope

- string release of any kind
- substring/copy/concat ownership redesign
- object-field dynarray slot ABI changes
- `SetLength(self.FieldArr, ...)` redesign
- object `Free` finalization of dynarray fields
- array return ownership
- dynarray assignment/copy semantics beyond current supported surface
- exception/unwind cleanup
- managed element finalization for strings/dynarrays/records inside arrays

## Ownership classes

### 1. Owned standalone dynarray slot

An owned standalone dynarray slot is a `%ptr/%len` pair whose lifetime belongs
to the current function/program frame.

Examples:

- local `var A: array of Integer;`
- top-level `var A: array of Integer;` in the root program

Rules:

- `SetLength` may allocate, reallocate, shrink, or free through the resize
  helper
- ordinary exits must release the slot if `%ptr <> null` and `%len > 0`

### 2. Borrowed dynarray param slot

Borrowed dynarray params keep the existing incoming `%ptr/%len` ABI but gain an
explicit ownership distinction.

Rules:

- the callee never releases borrowed params
- resizing a borrowed param is out of scope for C6-H1
- a borrowed slot can still be indexed/read through the current lowering paths

### 3. Deferred dynarray field slot

Dynarray fields are intentionally deferred because their slot ABI is not frozen
yet.

Today the codebase has evidence that field dynarray lowering is incomplete:

- `SetLength(self.FieldArr, ...)` currently goes through
  `assign-arr-elem-runtime '__field_setlength__'`
  - see `compiler/sema/np_semantic_analyzer.pas:11026`
- builder stores the new pointer into the field path, but this path does not
  freeze a complete standalone field release contract in C6-H1
  - see `compiler/ir/np_hir_builder.pas:4670`
- `Length(self.FieldStr)` has a dedicated field-length rule for strings, but
  there is no corresponding frozen field-array length contract here
  - see `compiler/sema/np_semantic_analyzer.pas:6854`

C6-H1 therefore preserves field-array behavior and leaves field-slot ownership
normalization to C6-H2.

## New helper contracts

### `@np_dynarray_resize`

```text
declare internal ptr @np_dynarray_resize(
  ptr %old_ptr,
  i64 %old_len,
  i64 %new_len,
  i64 %elem_size
)
```

Contract:

- `%old_len` and `%new_len` are element counts
- `%elem_size` is the per-element storage size in bytes
- old request size is `%old_len * %elem_size`
- new request size is `%new_len * %elem_size`
- returned pointer is the new element-0 pointer, or `null` when `%new_len = 0`

Behavior:

1. if `%new_len = 0`
   - free old storage when `%old_ptr <> null` and `%old_len > 0`
   - return `null`
2. if `%old_ptr = null` or `%old_len = 0`
   - allocate `%new_len * %elem_size`
   - return fresh pointer
3. otherwise
   - allocate new storage
   - copy `min(old_len, new_len) * elem_size` bytes
   - free old storage using the old request size
   - return new pointer

`@np_dynarray_resize` is a pure runtime helper boundary. It owns the copy/free
sequence so `SetLength` no longer open-codes allocate-only behavior.

### `@np_dynarray_release`

```text
declare internal void @np_dynarray_release(
  ptr %ptr,
  i64 %len,
  i64 %elem_size
)
```

Contract:

- release request size is `%len * %elem_size`
- `@np_free` must receive the exact original request size
- releasing `{null, 0}` is a no-op
- non-null pointer with zero length, or null pointer with non-zero length, is a
  fatal runtime fault in owned-slot paths

This helper only frees the backing buffer. It does not recurse into managed
elements in C6-H1.

## Helper size and fault invariants

These invariants are frozen for C6-H1:

- `%elem_size > 0`
- `%old_len >= 0`, `%new_len >= 0`
- `%old_len * %elem_size` must not overflow `i64`
- `%new_len * %elem_size` must not overflow `i64`
- `min(old_len, new_len) * %elem_size` must not overflow `i64`
- owned-slot release path must not call `@np_free` with a silently mismatched
  request size

Failure shape:

- freeze a dedicated internal trap helper:

```text
declare internal void @np_dynarray_fault(i64 %code, i64 %arg0, i64 %arg1)
```

- initial fault codes:
  - `1` = old byte-size overflow
  - `2` = new byte-size overflow
  - `3` = copy byte-size overflow
  - `4` = invalid owned-slot state
- allocation/free syscalls still keep using the existing allocator-fault path;
  `@np_dynarray_fault` is only for dynarray logical-state invariants

## HIR and lowering contracts

### Producer distinction

C6-H1 must make borrowed dynarray params explicit instead of leaving them
indistinguishable from owned local slots.

Freeze a dedicated borrowed declaration node:

```text
var-decl-arr-borrowed-runtime
```

Contract:

- `var-decl-arr-runtime` means owned standalone slot
- `var-decl-arr-borrowed-runtime` means borrowed incoming `%ptr/%len` pair
- RED must prove the builder distinguishes the two node kinds
- borrowed params must not generate automatic release nodes
- borrowed params must not lower `SetLength` through the owned resize helper in
  C6-H1

### `SetLength`

For owned standalone dynarray vars:

- `setlength-arr-runtime` no longer lowers to bare `arr_alloc*`
- builder must load old `%ptr/%len`
- builder must call `@np_dynarray_resize`
- builder must store returned `%ptr`
- builder must store `%new_len` into the existing `%len` slot

For field-array `__field_setlength__`:

- preserved as-is in C6-H1
- explicitly deferred, not silently changed

For borrowed dynarray params:

- C6-H1 does not lower `SetLength` through the owned resize helper
- RED must prove borrowed-param fixtures do not get the owned resize path by
  accident

### Cleanup node

Add an explicit dynarray cleanup node for owned standalone slots.

Semantic contract:

- one cleanup node per owned dynarray slot at each ordinary exit edge
- cleanup node loads `%ptr/%len`
- cleanup node calls `@np_dynarray_release`
- cleanup node then clears the slot to `{null, 0}` to prevent duplicate release
  on the same path

### Exit insertion points

C6-H1 ordinary cleanup must cover:

- explicit `Exit`
- implicit end-of-function / end-of-procedure return
- `Halt`
- synthetic final halt in `_start`

C6-H1 does **not** promise cleanup on:

- `raise-runtime`
- exception unwind
- abnormal trap/fault paths

## Validation plan

### RED source contracts

1. Borrowed vs owned dynarray slot distinction is visible in HIR/source
   contracts.
2. Standalone `SetLength` lowers to `@np_dynarray_resize`, not bare
   `@np_alloc`.
3. `@np_dynarray_resize` computes old/new byte counts from
   `len * elem_size`.
4. Resize helper copies `min(old_len, new_len) * elem_size` bytes before
   freeing old storage.
5. `@np_dynarray_release` uses stored `%len * elem_size` request size when
   calling `@np_free`.
6. Owned standalone dynarray slots emit cleanup before explicit `Exit`,
   implicit return, and `Halt`.
7. Borrowed dynarray params do not emit cleanup.
8. Borrowed dynarray params do not lower `SetLength` through
   `@np_dynarray_resize`.
9. Existing field `__field_setlength__` path is preserved and explicitly marked
   deferred.
10. String lowering remains untouched:
   - shallow copy preserved
   - substring alias preserved
   - concat still uses `@np_str_concat`

### RED runtime smokes

1. Direct helper smoke:
   - allocate old dynarray payload
   - write sentinel prefix bytes
   - resize upward
   - confirm prefix bytes survive
   - release successfully
   - exit `42`
2. Compiler-generated standalone dynarray smoke:
   - Pascal source with local dynarray
   - `SetLength(A, 4)` -> fill -> `SetLength(A, 8)`
   - read back preserved prefix values
   - ordinary program exit succeeds with expected code
3. Exit cleanup smoke:
   - Pascal source with owned local dynarray and explicit `Exit`
   - source contract proves release node occurs before `ret-runtime`

### Focused gates

- HIR contract tests for owned/borrowed slot distinction
- HIR contract tests for standalone `SetLength` resize lowering
- dynarray helper runtime smoke
- standalone Pascal dynarray runtime smoke

### Closeout gates

- focused HIR contracts
- dynarray runtime smokes
- `git diff --check`
- `make hygiene`
- `./build/verify_local.sh` after implementation because runtime/codegen
  semantics change

## Deferred follow-up slices

### C6-H2: field dynarray slot ABI + object-field release

Freeze class/record field dynarray slot layout, field length access, repeated
field `SetLength`, and object `Free`-time dynarray field cleanup.

### C6-H3: string ownership redesign

Freeze borrowed vs owned string slots, substring alias rules, concat return
ownership, shallow copy policy, and string release.

## Review questions

Before RED starts, total control should confirm these three decisions:

1. C6-H1 is allowed to be dynarray-only even though the broader C6 debt still
   says "string/dynarray release".
2. Borrowed dynarray params will be made explicit in HIR instead of continuing
   to masquerade as owned local slots.
3. Field dynarray release is intentionally deferred to C6-H2 because the field
   slot ABI is not frozen enough yet.
