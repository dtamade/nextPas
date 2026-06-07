# nextPas compiler C6-H4 string return ownership design

## Goal

C6-H4 should close the next narrow string ownership hole after C6-H3 without
pretending that the full Pascal managed string runtime is complete.

The recommended next slice is **direct string return ownership transfer**:

- compiler-emitted direct string-return routines return an ownership descriptor
- return slots can own heap buffers produced by concat, `IntToStr`, or moved
  local owners
- direct callers that assign the returned value into owned standalone slots
  consume that ownership descriptor
- static, literal, borrowed, and alias values still carry no owner

This is the smallest high-quality slice because it fixes the C6-H3 callee-owned
return leak and the local-owned return dangling-pointer hazard without changing
object field layout, string parameter ABI, refcounting, copy-on-write, deep copy,
or unwind cleanup.

## Current live truth after C6-H3

C6-H3 landed standalone owned string sidecars:

```text
visible string value:
  ptr
  len

owned standalone slot:
  name$ptr
  name$len
  name$owner
  name$alloc_size
```

Current ownership facts:

- standalone string locals and top-level variables are owned slots
- string parameters are borrowed slots
- literal/static strings are borrowed constants
- plain assignment copies `{ptr,len}` and clears destination ownership
- `Copy(S, start, len)` is a substring alias and clears destination ownership
- string fields remain visible `{ptr,len}` only
- owned concat and owned `IntToStr` already return
  `{ptr,len,owner,alloc_size}` for owned standalone destinations
- ordinary cleanup calls `@np_string_release(owner, alloc_size)` only for owned
  standalone slots

Current return facts:

- string-returning routines still return `{ptr,i64 len}`
- the function result slot has only visible `$ptr/$len`
- direct call assignment stores only returned `{ptr,len}` and clears caller
  destination ownership
- C6-H3 tests explicitly reject `@np_str_return_owned`

This means a function can allocate a string internally and return only the
visible pointer and length. The caller has no owner metadata, so the allocation
is leaked. If the returned pointer aliases an owned local that is cleaned before
return, the caller can receive a dangling pointer.

## Recommendation

Implement C6-H4 as a direct, move-only return descriptor slice.

For compiler-emitted direct Pascal routines with string return type, change the
internal return ABI from:

```text
{ ptr, i64 len }
```

to:

```text
{ ptr, i64 len, ptr owner, i64 alloc_size }
```

The descriptor contract is:

- `ptr/len` are the visible string value
- `owner/alloc_size` are the release authority
- `{owner = null, alloc_size = 0}` means borrowed/static/no-release
- `{owner <> null, alloc_size > 0}` means the caller owns the allocation
- `alloc_size` must equal the exact allocator request size for `owner`
- callers release only through `@np_string_release(owner, alloc_size)`
- callers must never free the visible `ptr/len`

This ABI is compiler-internal for now. External routines, imported routines,
virtual/interface dispatch, and any future stable FFI string ABI remain out of
scope unless a later spec explicitly adopts the four-field descriptor there.

## Return slot model

The function result variable becomes an owned return slot:

```text
Result$ptr
Result$len
Result$owner
Result$alloc_size
```

For Pascal functions that use the function name as the result variable, the
same rule applies to that hidden result name.

Return-slot rules:

- assigning a literal/static string to the result stores visible `ptr/len` and
  clears `owner/alloc_size`
- assigning concat or `IntToStr` to the result stores the owned helper's
  four-field descriptor
- assigning a direct owned-return call to the result consumes the callee
  descriptor
- returning an owned local slot moves its `owner/alloc_size` into the result
  slot and clears the source owner
- returning a borrowed source stores `{ptr,len,null,0}`
- function exit returns the result descriptor and must not release the result
  owner in the callee
- ordinary cleanup still releases all other owned local slots before function
  exit

The local-owner move rule is intentionally narrow. It exists only for assignment
into the return slot. The source slot becomes a borrowed alias after the move.
C6-H4 does not introduce general move assignment, deep copy, uniqueness
analysis, or reference counting.

## Caller consumption model

C6-H4 consumes owned return descriptors only in owned standalone destinations
and return slots.

For:

```pascal
S := MakeText();
```

where `S` is an owned standalone slot:

1. evaluate call arguments using the existing borrowed string argument ABI
2. call `MakeText` and receive `{ptr,len,owner,alloc_size}`
3. release the old `S$owner/S$alloc_size`
4. store returned `ptr/len` into `S$ptr/S$len`
5. store returned `owner/alloc_size` into `S$owner/S$alloc_size`

For:

```pascal
Result := MakeText();
```

the same descriptor is stored into the return slot.

If a direct owned-return result is used in a target that cannot own it, the
compiler must not silently drop owner metadata. In C6-H4 those shapes are either
left as legacy borrowed paths when the callee is not using the owned return ABI,
or they must fail closed in RED contracts until a later temporary/argument
lifetime slice defines the owner boundary.

Examples that remain out of scope as owners:

- passing `MakeText()` directly as a string argument
- storing `MakeText()` directly into a string field
- concatenating directly with an owned return temporary
- returning through virtual/interface dispatch
- external or imported string-returning functions

## Field string ownership remains deferred

C6-H4 must not solve string fields.

String fields currently use two visible object slots:

```text
field idx + 0: ptr
field idx + 1: len
```

That layout remains frozen for C6-H4. There are no field owner sidecars, no
object string cleanup helper, and no change to `@np_object_free_release`.

Repeated field assignment can still leak or alias because a field has no
release authority. Fixing that requires a dedicated object-layout ABI slice:

- where field owner sidecars live
- how inherited field indexes shift
- when `Destroy` runs relative to field string cleanup
- whether base-typed `Free` cleans only compile-time fields or runtime type
  fields

Those questions belong to a later field-string ownership slice, not C6-H4.

## String argument ownership remains deferred

String parameters stay borrowed in C6-H4.

The call ABI for string parameters remains:

```text
ptr, i64 len
```

Rules:

- callees do not release string parameters
- passing an owned local string borrows its visible `ptr/len`
- passing a literal/static string borrows constant storage
- passing an alias string borrows the aliased storage
- no `owner/alloc_size` is passed through ordinary arguments

Passing an owned return temporary directly as an argument needs a temporary
owner lifetime rule. That is deferred because it must define whether the
temporary is released after the call, transferred to the callee, or retained by
the caller.

## Literal, static, Copy, substring, and IntToStr rules

Literal and static strings:

- always return or assign as `{ptr,len,null,0}`
- are never released

Plain string assignment:

- remains shallow `{ptr,len}` copy
- destination old owner is released before overwrite
- destination owner is cleared unless the destination is the return slot and
  the source owner is explicitly moved

`Copy(S, start, len)`:

- remains a substring alias in C6-H4
- stores `S.ptr + start - 1` and requested length
- carries `{owner=null, alloc_size=0}`
- is not deep-copied and must not be released

`IntToStr`:

- remains an owned producer when assigned to an owned standalone slot
- becomes an owned producer when assigned to the return slot
- visible `ptr` may be an interior pointer
- release always uses `owner/alloc_size`

Concat:

- remains an owned producer for owned standalone destinations
- becomes an owned producer for the return slot
- remains legacy visible `{ptr,len}` for deferred field/call paths unless those
  paths are made fail-closed for owned callee results

## Deferred items

C6-H4 explicitly does not implement:

- string field owner sidecars
- object string-field cleanup
- field string assignment release
- direct owned return assignment into string fields
- direct owned return temporaries as call arguments
- owned string parameter transfer
- virtual/interface string return ownership
- external/FFI string return ownership
- refcounted strings
- copy-on-write strings
- deep assignment
- deep `Copy` / substring allocation
- alias lifetime analysis
- managed elements containing strings
- record fields containing strings
- array elements containing strings
- exception/unwind cleanup
- polymorphic runtime-type finalization

These are not optional cleanup details. Each one needs its own RED contracts
because it changes ownership, layout, or lifetime boundaries.

## RED source-contract plan

The C6-H4 RED source contracts must fail before implementation and must prove:

- a string-return function emits an explicit owned-return HIR contract
- the result slot has `owner/alloc_size` sidecars
- the emitted direct function return type is `{ptr, i64, ptr, i64}` or an
  equivalent four-field descriptor
- `ret-str` returns `ptr`, `len`, `owner`, and `alloc_size`
- concat assigned to the result uses the owned concat helper
- `IntToStr` assigned to the result uses the owned `IntToStr` helper
- literal/static returns carry `owner=null` and `alloc_size=0`
- returning an owned local moves owner metadata to the result slot and clears
  the source owner
- the callee does not release the returned owner before `ret`
- caller assignment from a direct string-return function stores all four fields
  into an owned destination
- caller assignment releases the destination's previous owner after the call
  result is materialized
- assigning a returned descriptor into another return slot preserves ownership
  for chained returns
- string params remain `var-decl-str-borrowed-runtime`
- string argument calls still pass only `ptr,len`
- string fields remain two visible slots with no owner sidecars
- object free still does not emit `np_object_string_cleanup`
- `@np_object_free_release` remains field-agnostic
- `Copy` remains a borrowed substring alias
- legacy virtual/interface/external string return paths do not silently drop an
  owned descriptor
- C6-G allocator, C6-H1 dynarray, C6-H2 field dynarray, and C6-H3 standalone
  string ownership contracts still pass

Suggested test file:

```text
tests/hir/test_hir_string_return_ownership_contract.pas
```

The exact HIR node names can be chosen in the implementation plan, but the
source contracts must make ownership explicit. Do not infer ownership from
variable names alone.

## RED runtime smoke plan

Runtime smokes must be repeatable from one focused command and must internally
drive `opt -> llc -> clang -> run` like the C6-H3 smoke.

Required smokes:

- direct concat return: callee returns `'head' + suffix`, caller reads first and
  last byte, then ordinary cleanup releases through the returned owner
- direct `IntToStr` return: callee returns `IntToStr(42)`, caller reads `42`,
  and cleanup releases through owner base, not visible interior pointer
- repeated caller assignment: `S := MakeA(); S := MakeB();` releases the first
  returned owner and keeps the second value readable
- literal/static return: callee returns a literal and cleanup does not trap
- local owned move return: callee assigns an owned local into the result slot,
  returns it, and caller reads/releases safely after callee locals are cleaned
- chained return: `Outer := Inner();` transfers owner through two return slots

Every passing runtime case should exit `42`. Fault cases may be source-contract
only unless the implementation plan decides to add a dedicated trap smoke.

Suggested test file:

```text
tests/hir/test_hir_string_return_ownership_runtime_smoke.pas
```

## Verification envelope

Focused gates for implementation:

- `tests/hir/test_hir_string_return_ownership_contract.pas`
- `tests/hir/test_hir_string_return_ownership_runtime_smoke.pas`
- existing C6-H3 string ownership contracts and runtime smoke
- existing C6-H1/C6-H2 managed lifecycle contracts
- focused HIR node-kind gate if new node kinds are added

Closeout gates for implementation:

- `git diff --check`
- `make hygiene`
- `./build/verify_local.sh`

Full local verification is required before a C6-H4 implementation can be
reported Ready because the slice changes function return ABI and call lowering
semantics. For this spec-only gate, `git diff --check` is sufficient.

## Landing boundary

C6-H4 landing candidates must not include unrelated old compiler-lane history
or generated artifacts.

Expected retained paths for an eventual implementation package:

- this spec
- a C6-H4 implementation plan
- focused C6-H4 source-contract and runtime-smoke tests
- minimal compiler sema/HIR/emitter changes needed for the return descriptor
- minimal verify hook changes only if needed to make the smoke a stable gate

Explicitly excluded:

- `build/.tmp/**`
- old C6-H3 package worktrees or commits
- unrelated `core/` changes
- string field ownership
- string parameter ownership
- refcount/COW/deep-copy/unwind work
