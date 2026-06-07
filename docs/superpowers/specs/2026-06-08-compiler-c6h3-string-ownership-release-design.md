# nextPas compiler C6-H3 string ownership and release design

## Goal

Freeze the first honest string lifecycle slice after C6-H1 and C6-H2.

C6-H3 is not "managed strings are complete". It is the first point where the
compiler stops treating every string slot as an interchangeable `{ptr,len}`
alias and starts recording which standalone string values own heap storage that
must be released.

The narrow goal is:

- preserve today's visible string ABI
- add compiler-private ownership state for standalone string slots
- release heap buffers produced by owned string producers
- avoid freeing literals, field aliases, substring aliases, shallow copies, and
  call/return values whose ownership is not frozen yet

This keeps C6-H3 implementable and testable without pulling in refcounting,
copy-on-write, string fields, or polymorphic object finalization.

## Context

C6-G froze the allocator contract:

- `@np_alloc(size)` returns the caller-visible payload pointer
- `@np_free(ptr, size)` receives the exact allocator request size
- large allocations use allocator-private hidden preludes
- small frees must not probe before the caller-visible pointer

C6-H1 added standalone dynarray resize/release. C6-H2 added field dynarray
`{ptr,len}` slots and object-field dynarray cleanup.

Both slices intentionally deferred strings because current string lowering is
alias-heavy:

- string local and parameter values use `{ptr,len}`
- string fields already consume two object slots `{ptr,len}`
- plain string assignment copies only `{ptr,len}`
- `Copy(S, start, len)` points into the source buffer instead of allocating a
  new owned string
- field string load/store copies only `{ptr,len}`
- string calls and returns expose only `{ptr,len}`
- concat allocates fresh storage, but the result has no release owner today
- `IntToStr` allocates 21 bytes and returns an interior pointer into that
  allocation, so the visible pointer is not safe to pass to `@np_free`

These facts make visible `{ptr,len}` insufficient as an ownership ABI.

## Recommendation

Implement C6-H3 as **standalone string owned-sidecar release**.

Use the visible string value ABI only for what callers can observe:

```text
visible string value = { ptr, len }
```

Add compiler-private ownership sidecars only for slots that are allowed to own
heap storage:

```text
owned standalone string slot:
  name$ptr        visible byte pointer
  name$len        visible byte length
  name$owner      allocator request pointer, or null
  name$alloc_size exact request size originally passed to @np_alloc
```

Rules:

- `name$ptr/name$len` remain the language-visible string value.
- `name$owner/name$alloc_size` are hidden compiler/runtime state.
- releasing a string slot uses `name$owner/name$alloc_size`, never
  `name$ptr/name$len`.
- a borrowed/static/alias string value has `owner = null` and
  `alloc_size = 0`.
- an owned heap string has `owner <> null` and `alloc_size` equal to the exact
  allocator request size.

This handles both normal owned buffers and the current `IntToStr` shape, where
`ptr` may be an interior pointer but `owner` still names the allocation base.

## Alternatives considered

### Option A: release strings from visible `{ptr,len}`

Pros:

- smallest apparent implementation

Cons:

- unsafe for `IntToStr`, which returns an interior pointer
- unsafe for `Copy`, which returns an alias into another string
- unsafe for literals and field loads
- violates C6-G because `len` is not necessarily the allocator request size

Rejected.

### Option B: full Pascal managed string runtime now

This means refcounting, copy-on-write, deep `Copy`, substring lifetime
extension, call/return ownership, field finalization, and unwind cleanup.

Pros:

- closer to long-term Pascal semantics

Cons:

- too broad for one verifiable compiler slice
- requires ABI decisions outside current source contracts
- risks breaking C6-H1/C6-H2 object/dynarray lifecycle guarantees

Rejected for C6-H3.

### Option C: standalone owned sidecars first

Pros:

- preserves current public `{ptr,len}` ABI
- works with C6-G's exact request-size free contract
- allows `concat` and `IntToStr` buffers to be released safely
- lets borrowed aliases remain explicit no-release values
- keeps string fields and return ownership deferred instead of pretending they
  are solved

Recommended.

## Current live string ABI truth

### Standalone string locals and globals

Current `var-decl-str-runtime` lowers to two storage slots:

- `name$ptr`
- `name$len`

For top-level runtime vars those become globals. For locals they become
allocas. There is no ownership slot today.

C6-H3 keeps `name$ptr/name$len` as the visible ABI and adds sidecars only for
owned standalone slots.

### String parameters

Current string params enter a function as two ABI parameters:

- pointer
- length

The callee stores them into local `param$ptr/param$len` slots. The current ABI
does not carry ownership.

C6-H3 freezes string params as borrowed. Callees must not release parameter
storage.

### String fields

Class string fields already consume two object slots:

- field index `idx + 0`: pointer
- field index `idx + 1`: length

`Length(FieldStr)` and field load/store read or write these two slots. There is
no field ownership sidecar and no object string cleanup.

C6-H3 must not change object layout for string fields.

### String function return

String-returning functions currently return:

```text
{ ptr, i64 len }
```

`ret-str-runtime` inserts the visible pointer and length into that result. The
return ABI does not carry ownership.

C6-H3 keeps return ownership deferred. A function return result assigned into a
standalone owned slot is treated as borrowed/unknown in this slice unless a
later reviewed ABI slice adds ownership transfer.

## Ownership classes

### Owned standalone slot

An owned standalone string slot is a local or top-level string variable whose
lifetime belongs to the current frame or root program.

Examples:

- `var S: string;` in a procedure
- `var S: AnsiString;` at program scope

An owned standalone slot can currently hold either an owned value or a borrowed
value. Its sidecars describe the current value:

- owned current value: `owner <> null`, `alloc_size > 0`
- borrowed current value: `owner = null`, `alloc_size = 0`

Ordinary exit cleanup releases only current owned values.

### Borrowed string param

A borrowed string param is a visible `{ptr,len}` pair supplied by a caller.

Rules:

- callee must not release it
- callee may pass it to helpers as a read-only string input
- assigning it into an owned standalone slot makes the destination borrowed
  after releasing any previous owned value

### Static literal string

A string literal points at an emitted LLVM constant.

Rules:

- never release literal storage
- literal assignment releases the destination's previous owned value, then
  stores `owner = null`, `alloc_size = 0`

### Alias string

Alias strings point at storage owned elsewhere or not owned at all by the slot.

Alias producers in C6-H3:

- plain string assignment from another string variable
- `Copy(S, start, len)` as currently lowered
- field string load
- field string store source
- string call result
- string return result

Rules:

- alias values have `owner = null`, `alloc_size = 0`
- alias values are not released by the receiving slot
- before overwriting an owned slot with an alias, release the old owned value

### Owned producer result

Owned producer results are fresh heap buffers that must be released by the
receiving owned standalone slot.

C6-H3 owns only these producers:

- string concat assigned to an owned standalone slot
- `IntToStr(...)` assigned to an owned standalone slot

Owned producer helpers must provide both visible value and owner sidecar data:

```text
{ ptr, len, owner, alloc_size }
```

`ptr/len` are stored into the visible slots. `owner/alloc_size` are stored into
the ownership sidecars.

## Runtime helper contracts

### `@np_string_release`

```text
declare internal void @np_string_release(ptr %owner, i64 %alloc_size)
```

Contract:

- `{null, 0}` is a no-op
- `owner = null` with `alloc_size <> 0` is a string runtime fault
- `owner <> null` with `alloc_size = 0` is a string runtime fault
- otherwise call `@np_free(owner, alloc_size)`
- `alloc_size` must be the exact request size originally passed to `@np_alloc`

The helper must not inspect the visible string pointer or visible string
length.

### `@np_string_fault`

```text
declare internal void @np_string_fault(i64 %code, i64 %arg0, i64 %arg1)
```

The first implementation must trap with `@llvm.trap()` and `unreachable`,
matching the current allocator and dynarray helper style.

Initial codes:

- `1` = release owner/size mismatch
- `2` = concat length overflow
- `3` = owned producer allocation-size mismatch
- `4` = invalid owned sidecar state

### Owned concat helper

The existing `@np_str_concat(ptr, len, ptr, len) -> {ptr,len}` is not enough
for owned-sidecar release because it does not return owner metadata.

C6-H3 requires an owned-producer helper, or an equivalent lowering, with this
contract:

```text
declare internal {ptr, i64, ptr, i64} @np_str_concat_owned(
  ptr %a_ptr,
  i64 %a_len,
  ptr %b_ptr,
  i64 %b_len
)
```

Contract:

- `total = a_len + b_len`
- overflow traps through `@np_string_fault(2, a_len, b_len)`
- `total = 0` returns `{null, 0, null, 0}`
- otherwise allocate exactly `total` bytes
- visible `ptr` equals owner pointer for concat
- visible `len` equals `total`
- owner pointer is the exact pointer returned by `@np_alloc(total)`
- `alloc_size` equals `total`

The legacy `@np_str_concat` may remain for deferred field/call paths during the
transition, but owned standalone assignment must use the owned-producer
contract.

### Owned `IntToStr` helper

Current `@np_int_to_str` allocates 21 bytes and returns a pointer inside that
allocation. C6-H3 must not free that visible pointer.

C6-H3 requires an owned-producer helper, or an equivalent lowering, with this
contract:

```text
declare internal {ptr, i64, ptr, i64} @np_int_to_str_owned(i64 %value)
```

Contract:

- the visible pointer may be inside the allocated buffer
- visible length is the number of printable bytes
- owner pointer is the exact pointer returned by `@np_alloc(alloc_size)`
- the first implementation is allowed to keep `alloc_size = 21`
- release uses `{owner, alloc_size}`, not `{ptr, len}`

Future slices may change the helper to allocate the exact digit count, but
C6-H3 does not require that optimization.

## HIR source contract changes

C6-H3 must make ownership explicit in HIR instead of overloading today's
`var-decl-str-runtime` everywhere.

Required new or refined contracts:

- standalone local/top-level string declaration emits an owned string slot
  contract
- string parameter declaration emits a borrowed string slot contract
- return string slot is not treated as an ordinary cleanup-owned local
- generated field-store temps are not treated as cleanup-owned escaping slots
- ordinary exit emits string cleanup for owned standalone slots only
- assignment to an owned slot releases previous owned state before replacing
  the visible value and sidecars
- borrowed/alias assignments clear sidecars to `{null, 0}`
- owned producer assignments store sidecars from the owned helper result

Suggested node names for implementation planning:

- `var-decl-str-owned-runtime`
- `var-decl-str-borrowed-runtime`
- `string-cleanup-runtime`
- `assign-str-owned-concat-runtime`
- `int-to-str-owned-runtime`

The exact names may be adjusted in the implementation plan, but RED contracts
must prove the ownership distinction is explicit and not inferred from names
alone.

## Assignment semantics

### Literal assignment

For:

```pascal
S := 'abc';
```

C6-H3 semantics:

1. release old `S$owner/S$alloc_size` if owned
2. store literal pointer into `S$ptr`
3. store literal byte length into `S$len`
4. store `null` into `S$owner`
5. store `0` into `S$alloc_size`

### Shallow variable assignment

For:

```pascal
B := A;
```

Current lowering copies `A$ptr/A$len`. C6-H3 keeps it a borrowed alias.

Semantics:

1. release old `B` owner if owned
2. copy `A$ptr/A$len`
3. set `B$owner = null`
4. set `B$alloc_size = 0`

C6-H3 does not make this a deep copy and does not add refcounting.

### `Copy` assignment

Current `Copy(S, start, len)` computes `S$ptr + start - 1` and stores that
interior pointer with the requested length.

C6-H3 keeps this as an alias:

- release previous destination owner before overwrite
- set destination owner sidecars to `{null, 0}`
- do not free the substring pointer

Deep `Copy` semantics are deferred.

### Concat assignment

For:

```pascal
S := A + B;
```

when `S` is an owned standalone slot:

1. evaluate/read operands before releasing `S` so `S := S + X` stays safe
2. call the owned concat helper
3. release old `S` owner if owned
4. store visible `{ptr,len}`
5. store `{owner,alloc_size}`

Concat into string fields, call arguments, or deferred temps remains outside
C6-H3.

### `IntToStr` assignment

For:

```pascal
S := IntToStr(I);
```

when `S` is an owned standalone slot:

1. call the owned `IntToStr` helper
2. release old `S` owner if owned
3. store visible `{ptr,len}`
4. store `{owner,alloc_size}`

The visible pointer may be an interior pointer. Only `owner/alloc_size` may be
released.

### Call result assignment

For:

```pascal
S := MakeString();
```

C6-H3 treats the returned `{ptr,len}` as borrowed/unknown:

1. release old `S` owner if owned
2. store returned `{ptr,len}`
3. set sidecars to `{null, 0}`

This avoids freeing an ABI result whose ownership is not encoded. It may still
leak buffers produced inside the callee; that is the C6-H4 return ownership
debt, not a C6-H3 failure.

### Field string assignment

String fields remain visible `{ptr,len}` only.

C6-H3 must preserve the current field-store behavior:

- literal field assignment stores literal pointer and length
- variable field assignment stores source pointer and length
- concat-to-field may still route through existing temporary lowering
- no object string cleanup is generated
- no field sidecars are introduced

This means repeated field string assignment can still leak or alias. That is
explicitly deferred.

## Cleanup ordering

Owned string cleanup follows the same ordinary-exit limitation as C6-H1
dynarray cleanup.

Cleanup points in scope:

- implicit end of procedure/function/program
- explicit `Exit`
- root program `Halt` lowering where current dynarray cleanup already runs

Cleanup points out of scope:

- exception unwind
- `try/finally` transfer semantics beyond existing ordinary paths
- early runtime traps
- interprocedural return ownership

Within a function:

- cleanup must run before scalar return or halt
- cleanup must not release the string return value unless a later ABI slice
  explicitly transfers ownership
- borrowed params are never cleaned
- generated escaping field-store temps are never ordinary-cleaned in C6-H3

## Object lifecycle boundary

C6-H2 object free lowering is:

1. nil guard
2. effective `Destroy`
3. compiler-owned dynarray field cleanup
4. `@np_object_free_release`

C6-H3 must not change that object release contract.

Frozen object/string boundary:

- no `@np_object_string_cleanup_*` helper in C6-H3
- no string field walk during `Obj.Free`
- `@np_object_free_release` remains field-agnostic
- string field cleanup waits for a later reviewed field-string ownership slice

## Size and memory-safety invariants

These invariants are mandatory:

- visible `{ptr,len}` is not an ownership proof
- `owner = null` means no release
- `owner <> null` means `alloc_size` is the exact allocator request size
- release always calls `@np_free(owner, alloc_size)`
- release never calls `@np_free(ptr, len)`
- concat overflow traps before allocation
- owned producer helpers must not return `owner <> null` with `alloc_size = 0`
- assignments release old owner only after RHS operands are materialized
- self-concat must not release the old buffer before the concat helper has read
  it
- zero-length owned producer results must normalize to `{null, 0, null, 0}`

## Deferred items

C6-H3 explicitly does not implement:

- refcounted strings
- copy-on-write
- deep string assignment
- deep `Copy` / substring allocation
- string return ownership transfer
- string call-result ownership
- string field sidecars
- object string-field cleanup
- property-backed string ownership
- string arrays or managed elements
- record fields containing strings
- interface or class fields containing managed strings
- exception/unwind cleanup
- polymorphic runtime-type finalization
- compatibility with pre-C6-H3 internal string slot sidecars

## RED source contracts

Before implementation, RED tests must prove:

- standalone string locals/top-level vars are distinguished from borrowed
  string params
- string params are no-cleanup borrowed slots
- owned standalone slots have sidecar storage in LLVM
- literal assignment releases previous owner and clears sidecars
- shallow string copy remains alias/no-owner
- `Copy` remains alias/no-owner and does not free an interior visible pointer
- concat to an owned standalone slot uses owned helper metadata
- `IntToStr` to an owned standalone slot uses owner base/request metadata
- self-concat materializes RHS before releasing the old destination owner
- ordinary exit emits `@np_string_release` for owned standalone slots
- string return slots are not ordinary-cleaned
- call-result assignment remains borrowed/unknown
- string field load/store paths remain layout-compatible and no-cleanup
- object `Free` still has dynarray cleanup only, no string cleanup
- `@np_object_free_release` remains field-agnostic
- C6-G allocator and C6-H1/H2 dynarray contracts still pass

## RED runtime smokes

Runtime smokes must be repeatable from one focused command and must assert:

- owned concat assigned to a standalone string writes correct first/last bytes
  and exits after cleanup
- repeated concat assignment releases the old buffer and keeps the new value
  readable
- `IntToStr` assigned to a standalone string reads the visible digit span and
  releases through owner base/request size without freeing the interior pointer
- borrowed literal/copy/substring cleanup does not trap
- borrowed string parameter is not released by the callee
- string field store/read still works and object `Free` does not attempt string
  cleanup

## Focused and closeout gates

Focused gates for C6-H3 implementation should include:

- C6-H3 string source contracts
- C6-H3 string runtime smoke
- existing C6-G large allocator runtime smoke
- existing C6-H1 dynarray source/runtime smokes
- existing C6-H2 field dynarray source/runtime smokes
- HIR node-kind gate

Closeout gates:

- `git diff --check`
- `make hygiene`
- `./build/verify_local.sh`

Because C6-H3 changes runtime semantics, `./build/verify_local.sh` is required
before any `Ready` package report.

## Review package boundary

This spec-only node must include only this C6-H3 design document.

The later C6-H3 implementation package must not include:

- old `codex/compiler` branch-only docs/history
- C6-H2 landing-candidate history
- `build/.tmp/**`
- unrelated core/system or verify-local truth changes
- string field ownership implementation
- return ownership implementation
- refcount/COW implementation
