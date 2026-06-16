# nextPas compiler C6-H5 string call argument ownership design

## Status

Needs Review.

C6-H5 is a spec-only gate. It does not authorize RED tests, production code,
build script edits, or runtime implementation.

## Context

C6-H4 landed direct owned string return ownership. A direct compiler-emitted
Pascal string-return function can now return an internal descriptor:

```text
{ptr, len, owner, alloc_size}
```

Owned standalone assignment can consume that descriptor and release the old
destination owner. C6-H4 deliberately fails closed when that owned return is
used as a temporary consumer, including:

```pascal
Take(MakeText());
Wrap(MakeText());
Length(MakeText());
Copy(MakeText(), 1, 1);
```

The current diagnostic for those paths is
`sema.c6h4-owned-string-return-deferred-consumer`. That fail-closed behavior is
correct for C6-H4 because ordinary string parameters still pass only borrowed
`ptr,len`. Silently dropping `owner,alloc_size` would leak owned return buffers.

## Recommended C6-H5 slice

C6-H5 should implement the narrowest next slice: **direct owned string return
temporaries consumed as ordinary borrowed string call arguments**.

The target shape is:

```pascal
Take(MakeText());
S := Wrap(MakeText());
```

where:

- `MakeText` is a direct compiler-emitted Pascal string-return function using
  the C6-H4 owned return descriptor.
- `Take` or `Wrap` consumes the argument through the existing borrowed string
  parameter ABI, `ptr, len`.
- The call site owns the temporary descriptor and releases it after the
  enclosing call finishes.

C6-H5 should not change the visible string parameter ABI. Callees still borrow
string arguments and still receive only `ptr,len`.

## Ownership truth

An owned return temporary used as a call argument has a caller-owned temporary
lifetime.

For:

```pascal
Take(MakeText());
```

the caller must:

1. evaluate `MakeText()` and materialize `{ptr,len,owner,alloc_size}` into a
   compiler-private temporary descriptor
2. pass only `ptr,len` to `Take`
3. keep `owner,alloc_size` live across the full call to `Take`
4. release `owner,alloc_size` after `Take` returns
5. clear the temporary owner after release so ordinary cleanup cannot double
   free it

The callee must not release the argument. The callee cannot retain the borrowed
argument beyond the call because C6-H5 does not introduce escape analysis,
reference counting, or copy-on-write.

For nested calls:

```pascal
S := Wrap(MakeText());
```

the caller of `Wrap` owns and releases the `MakeText()` temporary after `Wrap`
returns. If `Wrap` returns an owned string descriptor, the outer assignment
uses the existing C6-H4 owned return assignment rule for `S`.

Temporary releases must occur after all argument-producing calls for the
enclosing call have completed and after the enclosing call returns. They must
occur before the next statement boundary and before ordinary local cleanup at
scope exit.

## Evaluation order

C6-H5 must freeze left-to-right argument evaluation for compiler-emitted direct
calls that include owned string return temporaries.

For:

```pascal
Take2(MakeA(), MakeB());
```

the caller must:

1. evaluate `MakeA()` into temporary `tmp0`
2. evaluate `MakeB()` into temporary `tmp1`
3. call `Take2(tmp0.ptr, tmp0.len, tmp1.ptr, tmp1.len)`
4. release `tmp1`
5. release `tmp0`

The release order should be reverse creation order. This mirrors stack cleanup,
keeps the rule deterministic, and avoids depending on callee behavior.

If later lowering proves that a platform or backend needs a different
evaluation order, that change must be explicit in a target/runtime ABI spec.
C6-H5 should not leave this unspecified.

## Assignment and return interaction

C6-H5 composes with C6-H4, but it must not broaden C6-H4.

Allowed:

```pascal
S := Wrap(MakeText());
Result := Wrap(MakeText());
```

If `Wrap` is a direct owned string-return function, the outer result descriptor
is consumed by the existing C6-H4 destination rule. The inner `MakeText()`
temporary is still caller-owned by the call site that invokes `Wrap`, and is
released after `Wrap` returns.

Not allowed in C6-H5:

```pascal
Result := MakeText() + S;
```

Concat operands with owned return temporaries need a separate expression
temporary and helper contract. They remain deferred unless the C6-H5
implementation plan explicitly chooses to fail them closed.

## Fail-closed rules

C6-H5 should replace the broad C6-H4 fail-closed rule only for ordinary direct
call arguments that can borrow `ptr,len` and release the temporary after the
call.

The compiler must still fail closed for:

- assigning an owned return temporary into a string field
- passing an owned return temporary to `var` or `out` string parameters
- passing an owned return temporary to any parameter that can store or mutate
  the argument address
- using an owned return temporary as `Length`, `Copy`, concat, comparison, or
  `WriteLn` input until those consumers have explicit temporary rules
- virtual, interface, external, imported, or cross-unit string-return callees
  without owned-return metadata
- overloaded calls where the selected callee cannot be proven before temporary
  ownership lowering
- call arguments whose evaluation would require unmanaged alias lifetime
  extension beyond the enclosing call

The diagnostic can keep the existing C6-H4 code for now or introduce a more
specific C6-H5 code. If a new code is used, it should name the precise blocked
consumer, for example `sema.c6h5-owned-string-temp-unsupported-consumer`.

## HIR and backend contract direction

C6-H5 should make temporary ownership explicit in HIR. The source contract
should not infer the rule from variable names or raw LLVM text alone.

Suggested HIR truth:

- `string-temp-owned-runtime` declares a compiler-private temporary descriptor
  with `ptr,len,owner,alloc_size`
- `string-temp-borrow-arg-runtime` passes `ptr,len` from the temporary to the
  callee
- `string-temp-release-runtime` releases `owner,alloc_size` after the enclosing
  call returns
- release nodes are ordered after the call and before the next statement cleanup
- release nodes clear the temporary owner after release

LLVM lowering should reuse C6-H3/C6-H4 helpers:

- `@np_string_release(owner, alloc_size)`
- C6-H4 owned return descriptor extraction
- existing borrowed string argument lowering

No new public runtime helper is required for the first slice.

## RED source-contract plan

The RED source contracts for C6-H5 should prove:

- `Take(MakeText())` no longer fails with the C6-H4 deferred-consumer
  diagnostic once C6-H5 is implemented
- `MakeText()` materializes an owned temporary descriptor at the call site
- normal string parameter ABI remains `ptr,len`; no owner metadata is passed to
  the callee
- `@np_string_release` for the temporary appears after the enclosing call
- repeated owned temporary arguments release in reverse creation order
- nested `S := Wrap(MakeText())` preserves the outer C6-H4 assignment contract
  and releases the inner temporary after `Wrap` returns
- `var`/`out` string params remain fail-closed
- string field assignment from owned return remains fail-closed
- `Length(MakeText())`, `Copy(MakeText(), ...)`, concat, comparison, and
  `WriteLn(MakeText())` remain fail-closed unless separately specified
- virtual/interface/external/cross-unit returns remain fail-closed or legacy,
  never silently dropping owner metadata
- C6-H4 direct assignment contracts still pass unchanged

Suggested test file for a later RED package:

```text
tests/hir/test_hir_string_call_argument_ownership_contract.pas
```

## Runtime smoke plan

Runtime smokes for a later implementation should be repeatable and should drive
`opt -> llc -> clang -> run` like existing C6-H3/C6-H4 smokes.

Required exit-42 cases:

- `Take(MakeText())` reads first and last byte inside `Take`, then caller
  releases the temporary
- `S := Wrap(MakeText())` verifies the inner temporary is released after
  `Wrap`, while the outer returned descriptor remains readable by `S`
- `Take2(MakeA(), MakeB())` verifies both arguments are readable and both
  temporaries are released exactly once
- literal/static arguments still pass borrowed `ptr,len` and never call
  `@np_string_release`

Fault-path smokes are not required in the first runtime smoke. Unsupported
shapes should be covered by source diagnostics first.

## Focused gates

A later C6-H5 implementation package should run:

- C6-H5 source contracts
- C6-H5 runtime smoke
- C6-H4 string return ownership source/runtime regressions
- C6-H3 standalone string ownership source/runtime regressions
- C6-H1/C6-H2 dynarray regressions if HIR cleanup ordering changes
- `git diff --check`
- `make hygiene`
- `./build/verify_local.sh` for any semantic or codegen implementation

This spec-only gate only requires:

```sh
git diff --check origin/main...HEAD
git status --short --branch
```

## Deferred scope

C6-H5 does not implement:

- string field owner sidecars
- string field assignment release
- object string-field cleanup
- `var` or `out` string parameter ownership
- callee-retained string argument ownership
- return temporary as concat operand
- return temporary as `Length`, `Copy`, comparison, or `WriteLn` input
- virtual or interface string return ownership
- external, imported, or FFI string return ownership
- cross-unit owned string return ABI metadata
- refcounting
- copy-on-write
- deep assignment
- deep `Copy` or substring allocation
- alias lifetime analysis beyond the enclosing direct call
- managed element finalization
- exception or unwind cleanup
- polymorphic runtime-type finalization

These are still architecture debts, not optional polish. Each needs its own
contract slice before implementation.
