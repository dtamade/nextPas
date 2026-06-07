# nextPas compiler C6-H2 field dynarray slot ABI and object-field release design

## Goal

Freeze the next narrow managed-lifecycle slice after C6-H1:

- give object-owned dynarray fields a real slot ABI instead of today's
  pointer-only placeholder
- stop repeated owner-field `SetLength` from leaking old storage
- define where dynarray field cleanup happens during object `Free`

This slice is still **not** "managed fields are done". It is:

- dynarray fields only
- owner-object field slots only
- ordinary `Free` lifecycle only

It does **not** pull string ownership into the same change.

## Context

This spec is written against:

- `docs/plans/support/2026-06-07-module-status-board.md` on `main`
  - compiler lane is frozen after C6-H1 and may only move through a new spec
- `docs/superpowers/specs/2026-06-07-compiler-c6h-dynarray-release-first-slice-design.md`
  - C6-H1 explicitly deferred field dynarray slot ABI changes, field
    `SetLength`, and object `Free` cleanup
- live compiler code in `codex/compiler@038d24c9`
  - this is the landed-equivalent C6-H1 compiler truth

## Recommendation

Do **not** try to solve "all managed object fields" in one step.

Start with **C6-H2 dynarray field slot normalization**:

- field dynarray slots become `{ptr,len}` pairs in object layout
- owner-field `SetLength` uses the same `@np_dynarray_resize` boundary as
  C6-H1 standalone slots
- object `Free` gains a compiler-owned dynarray-field cleanup step before heap
  release
- `@np_object_free_release` stays allocator/header-only and never walks fields

Keep these out of scope:

- string field ownership or release
- `Other.FieldArr` mutation ownership
- array assignment/copy alias rules
- managed element finalization
- exception/unwind cleanup
- VMT-wide dynamic cleanup redesign

## Current Live Truth

### 1. Field dynarray slots are pointer-only today

Current class field array declarations are recorded as pointer-typed field
slots:

- when a class field type node is `gnkArrayType`, semantic metadata rewrites
  the field type to `Pointer`
  - see `compiler/sema/np_semantic_analyzer.pas:5428-5433`
- field-array metadata records `$arr_elem_type` and optional
  `$arr_elem_size`, but there is no field `$len` slot metadata
  - see `compiler/sema/np_semantic_analyzer.pas:5451-5458`
- unlike string fields, array fields only advance `FieldIndex` by one slot
  - string fields use `Inc(FieldIndex, 2)`
  - non-record, non-string array fields fall through to plain `Inc(FieldIndex)`
  - see `compiler/sema/np_semantic_analyzer.pas:5466-5490`

So the live object layout truth is:

- dynarray field slot stores only the element-0 pointer
- no length slot exists in object storage
- dynarray fields are currently indistinguishable from raw pointer fields at
  the low-level field-slot ABI

### 2. Field-array element access already assumes "slot contains ptr"

Structured field-array addressing already treats the class field as an address
to a pointer slot:

- sema builds `shekField` for the field slot and wraps it in `shekArrayElem`
  for field-array elements
  - see `compiler/sema/np_semantic_analyzer.pas:7956-8107`
- builder lowers field-array element access by:
  1. taking the field slot address
  2. loading a pointer from that slot
  3. `gep`-indexing into the backing buffer
  - see `compiler/ir/np_hir_builder.pas:1025-1117`

That means any C6-H2 ABI change must preserve:

- field dynarray ptr slot still points at element 0
- field-array element addressing still starts from the ptr slot

### 3. Repeated field `SetLength` currently leaks

Current field `SetLength` support is a narrow implicit-current-class hack:

- sema recognizes only `SetLength(FieldArr, n)` where `FieldArr` is a bare
  identifier field in the current class
  - it emits `assign-arr-elem-runtime` with display name
    `__field_setlength__`
  - operand shape is `self <tab> field_idx <tab> new_len_blob`
  - see `compiler/sema/np_semantic_analyzer.pas:11084-11103`
- builder special-cases `__field_setlength__`
  - computes the field slot address
  - calls bare `arr_alloc`
  - stores the returned pointer into the field slot
  - see `compiler/ir/np_hir_builder.pas:4718-4761`

What it does **not** do:

- it does not load the old pointer
- it does not know the old length
- it does not call `@np_dynarray_resize`
- it does not release old storage
- it does not store a new length
- it does not use `elem_size`

So repeated field `SetLength` truth today is:

- only implicit owner-field syntax is recognized
- every resize overwrites the pointer
- old storage leaks

### 4. `Length(field dynarray)` has no frozen contract today

`Length` currently has two array/string shapes:

- standalone runtime strings and arrays use `%name$len`
  - see `compiler/sema/np_semantic_analyzer.pas:6894-6919`
- current-class string fields use `field self <idx + 1>`
  - see `compiler/sema/np_semantic_analyzer.pas:6921-6928`

There is no corresponding field-dynarray length branch.

So the live truth is:

- field dynarrays have element access
- field dynarrays do not have a frozen `Length(...)` slot contract

### 5. Object `Free` does not clean dynarray fields today

Current `Free` lowering is split into destroy then heap release:

- sema turns `Obj.Free` into `object-free-runtime` plus the paired destroy call
  contract
  - see `compiler/sema/np_semantic_analyzer.pas:11283-11313`
- builder converts that pair into:
  - `np.system.object_free.destroy`
  - then `np.system.object_free.release`
  - see `compiler/ir/np_hir_builder.pas:3798-3940`
- emitter lowers `np.system.object_free.release` to `@np_object_free_release`
  - header validation
  - magic poisoning
  - `@np_free(raw, size + 24)`
  - see `compiler/ir/np_hir_llvm_emitter.pas:1499-1529`

There is no field walk, no dynarray release, and no length-aware cleanup in
that path.

### 6. C6-H1 cleanup machinery ignores fields by construction

C6-H1 cleanup only scans standalone runtime array vars:

- `EmitOwnedDynArrayCleanupNodes` iterates `FRuntimeArrVarNames`
  - see `compiler/sema/np_semantic_analyzer.pas:658-673`
- those names come from standalone var/param registration, not class field
  layout
  - see `compiler/sema/np_semantic_analyzer.pas:597-607` and
    `compiler/sema/np_semantic_analyzer.pas:6710-6733`

So object fields are outside the existing ordinary-exit cleanup model.

## Why C6-H2 Must Change the Field ABI

C6-H1 could avoid a payload header because standalone dynarray length already
lived in `%name$len`.

Field dynarrays do not have that luxury:

- repeated resize needs old request size
- object cleanup needs exact release size
- `@np_free` cannot accept silent size mismatch under the C6-G allocator
  contract

With today's pointer-only field slot, the compiler has nowhere truthful to get
the old element count.

That makes pointer-only field slots a dead end for correct resize/free.

## Alternatives Considered

### Option A: keep one pointer slot and infer length elsewhere

Possible variants:

- recover length from a dynarray-specific payload header
- add side tables keyed by object pointer + field index
- hide field length in allocator-private memory

Pros:

- avoids changing object field indexes

Cons:

- introduces a second hidden-header story on top of C6-G allocator prelude
- breaks the clean C6-H1 rule that dynarray logical size is explicit
- complicates object cleanup and repeated resize
- makes field dynarrays semantically different from standalone dynarrays for no
  good reason

Rejected.

### Option B: widen dynarray fields to `{ptr,len}` slots and keep cleanup in compiler-generated code

Pros:

- mirrors standalone dynarray ownership state
- gives repeated resize and `Free` exact sizes without hidden dynarray headers
- preserves allocator/runtime separation
- keeps `@np_object_free_release` simple and allocator-focused

Cons:

- changes class field indexes after a dynarray field
- requires explicit dynarray-field metadata instead of "pretend pointer"

Recommended.

### Option C: solve generic object finalization now

This would mix in:

- string fields
- managed elements inside dynarrays
- record/class/interface recursive cleanup
- unwind/finally semantics
- dynamic runtime type cleanup hooks

Rejected for C6-H2. The slice becomes too broad to verify honestly.

## C6-H2 Scope

### In scope

1. Dynarray field slot ABI normalization
   - class/object dynarray fields occupy two object slots: `{ptr,len}`
2. Owner-field resize
   - implicit current-class field syntax: `SetLength(FieldArr, n)`
   - explicit owner syntax: `SetLength(Self.FieldArr, n)`
3. Object `Free` dynarray-field cleanup
   - release object-owned dynarray fields before heap release
4. Field length truth needed by the above ABI
   - `Length(FieldArr)` / `Length(Self.FieldArr)` becomes a read of the len slot

### Out of scope

- string field slot ABI or release
- `SetLength(Other.FieldArr, n)` ownership semantics
- dynarray field assignment/copy/alias rules
- array return ownership
- managed element finalization inside dynarray fields
- exception/unwind cleanup
- VMT/dynamic-runtime cleanup redesign
- object property-backed dynarray ownership

## Frozen C6-H2 ABI

### 1. Field dynarray storage shape

For every dynarray field `T.FItems`, C6-H2 freezes:

- `T.FItems$idx`
  - index of the pointer slot
- `T.FItems$arr = 1`
  - marks this field as a dynarray field instead of a raw pointer field
- `T.FItems$arr_elem_type`
  - existing element type metadata stays
- `T.FItems$arr_elem_size`
  - existing optional element-size metadata stays

The object layout at `T.FItems$idx` becomes:

- slot `idx + 0`: element-0 pointer
- slot `idx + 1`: logical length in elements

Effects:

- dynarray fields consume two 8-byte object slots
- later field indexes shift just like they already do for string fields
- the pointer slot remains the array data root for field-array element access

### 2. Metadata model

Current "array field is just pointer" metadata is not sufficient.

C6-H2 requires field metadata to distinguish:

- raw pointer field
- string field
- dynarray field
- record field

At minimum:

- semantic type metadata gains an explicit dynarray-field bit
- inherited field metadata preserves that bit

This is required so object cleanup does not free arbitrary pointer fields.

### 3. Length truth

For dynarray fields under C6-H2:

- field length is the stored `idx + 1` slot
- `Length(FieldArr)` and `Length(Self.FieldArr)` read that slot directly
- null pointer with zero length is the empty-field state

No hidden dynarray header is introduced for field length.

## Owner-Field `SetLength` Contract

### Current truth being replaced

The legacy `__field_setlength__` `assign-arr-elem-runtime` path is a temporary
allocate-only hack and must not survive C6-H2 as the field-resize contract.

### New contract

Owner-field resize lowers through the same logical boundary as standalone
dynarrays:

```text
@np_dynarray_resize(old_ptr, old_len, new_len, elem_size)
```

but the slot source is object field storage instead of `%name$ptr/%name$len`.

### Producer boundary

C6-H2 should use a dedicated field-resize HIR contract instead of overloading
`assign-arr-elem-runtime '__field_setlength__'`.

The new contract must explicitly carry:

- owner receiver slot
  - initially only `self`
- dynarray field pointer-slot index
- requested new length
- element size

This keeps resize semantically separate from element store.

### Receiver rule

C6-H2 covers only owner-object receivers:

- `SetLength(FieldArr, n)`
- `SetLength(Self.FieldArr, n)`

`SetLength(Other.FieldArr, n)` is deferred because it raises another ownership
question:

- is mutating another object's dynarray field by reference already part of the
  supported ownership model?

C6-H2 says "not yet".

### Resize behavior

Owner-field resize must:

1. load old ptr from `idx + 0`
2. load old len from `idx + 1`
3. compute `elem_size`
4. call `@np_dynarray_resize`
5. store returned ptr back to `idx + 0`
6. store `%new_len` to `idx + 1`

Special cases:

- `%new_len = 0`
  - field becomes `{null, 0}`
- empty field
  - represented as `{null, 0}`

The old pointer-only `arr_alloc` overwrite path is invalid under C6-H2.

## Object `Free` Cleanup Boundary

### Boundary decision

Field dynarray cleanup belongs **between** owned destroy execution and raw heap
release.

It does **not** belong inside `@np_object_free_release`.

### Why the cleanup boundary stays out of `@np_object_free_release`

`@np_object_free_release` is currently an allocator/header helper:

- validate object header
- poison release magic
- free raw storage

It has no field-layout truth and should stay independent from class metadata.

Mixing field cleanup into that helper would:

- couple allocator/runtime helpers to compiler field-layout metadata
- push managed-object policy into a low-level heap boundary
- make later string/interface/record cleanup harder to stage cleanly

### C6-H2 cleanup shape

For `Obj.Free`, after the destroy call returns and before
`np.system.object_free.release`, the compiler inserts a hidden dynarray-field
cleanup step for the receiver's static class.

Conceptually:

1. nil guard
2. call destroy
3. call hidden dynarray-field cleanup helper
4. call `np.system.object_free.release`

The hidden cleanup helper:

- receives the object pointer
- visits dynarray fields known from the receiver's compile-time class metadata
- loads `{ptr,len}` for each dynarray field
- calls `@np_dynarray_release(ptr, len, elem_size)`
- clears the field back to `{null, 0}`

### Classes without explicit destructor

C6-H2 cleanup must **not** depend on the class having a user-declared
`Destroy`.

That is why the cleanup step is a distinct hidden boundary, not "inject cleanup
only into handwritten destructor bodies".

If the object is being freed, dynarray-field cleanup still runs even when the
effective destroy implementation is inherited, as long as the receiver's
compile-time class is the one being lowered.

### Inheritance

The hidden cleanup boundary must cover inherited dynarray fields as well as the
current class's own dynarray fields.

The contract should be explicit and deterministic:

- clean most-derived class dynarray fields first
- then inherited dynarray fields in ancestor order

This order is mostly future-proofing. For raw dynarray buffer release, the main
point is to make it explicit and stable.

## What C6-H2 Still Defers

### 1. String field ownership

String fields already use a two-slot layout pattern, but their ownership model
is still blocked on:

- shallow copy
- substring aliasing
- concat ownership
- return ownership

C6-H2 must not fold that debt into dynarray-field work.

### 2. Foreign-object field mutation

Deferred:

- `SetLength(Other.FieldArr, n)`
- `SetLength(SomeBase.FieldArr, n)` through non-owner receivers

This needs a separate ownership story for "mutating someone else's managed
field".

### 3. Polymorphic runtime cleanup redesign

Current `Free` lowering is not a general VMT-driven finalization framework.

C6-H2 does not attempt to solve:

- freeing a most-derived instance through a base-typed receiver with a
  runtime-type-specific dynarray cleanup hook
- runtime-type-based field cleanup hooks
- generic VMT cleanup slots
- fully polymorphic managed finalization

If the project later wants dynamic-type cleanup truth, that is a separate
follow-up slice.

### 4. Managed element finalization

Deferred:

- dynarray fields whose elements are strings
- dynarray fields whose elements are dynarrays
- dynarray fields whose elements are records needing recursive release

C6-H2 releases only the outer backing buffer.

### 5. Exception/unwind cleanup

C6-H2 only defines ordinary `Free` lifecycle cleanup, not unwinding.

## Future RED Targets For This Spec

This round is spec-only, but the implementation slice that follows should have
RED coverage for:

- dynarray field metadata changing from pointer-only to explicit `{ptr,len}`
- owner-field `SetLength` using field resize, not `__field_setlength__`
- repeated owner-field `SetLength` releasing old storage
- `Length(FieldArr)` / `Length(Self.FieldArr)` reading the len slot
- `Obj.Free` calling hidden dynarray-field cleanup before heap release
- inherited dynarray fields participating in cleanup
- string lowering and string field release remaining untouched
- `@np_object_free_release` staying field-agnostic

## Decision Summary

C6-H2 should be the slice that makes dynarray fields honest:

- today they only pretend to be pointers
- after C6-H2 they become explicit `{ptr,len}` object-owned slots
- repeated owner-field `SetLength` becomes size-correct
- `Free` gains dynarray-field cleanup at the compiler/object-lifecycle boundary
- allocator helpers remain allocator helpers

That is the narrowest slice that is implementable, verifiable, and does not
lie about string ownership or generic managed-finalization maturity.
