# C6-H5 String Call Argument Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the C6-H5 owned string-return temporary-as-call-argument slice so direct owned string returns can be borrowed by ordinary string parameters and released by the caller after the enclosing call.

**Architecture:** Keep the visible string parameter ABI as borrowed `ptr,len`. Add explicit HIR temporary ownership truth for `{ptr,len,owner,alloc_size}` descriptors, release those temporaries after the enclosing call in reverse creation order, and keep every unsupported consumer fail-closed. Execute RED source contracts first, RED runtime smoke second, then minimal GREEN implementation.

**Tech Stack:** Free Pascal, nextPas sema/HIR/LLVM emitter, existing C6-H3/C6-H4 string helpers, `tests/hir`, `build/verify_local.sh`

---

## Baseline And Scope

- Base: `origin/main@0ca2d77c71818160172ed0d6c11fb0b7dc2549c2` or newer.
- Design baseline: `docs/superpowers/specs/2026-06-08-compiler-c6h5-string-call-argument-ownership-design.md`.
- Plan path: `docs/superpowers/plans/2026-06-08-compiler-c6h5-string-call-argument-ownership-implementation.md`.
- This plan commit is docs-only. Do not add RED tests, production code, build hooks, or generated artifacts in this commit.
- C6-H5 is not C6-H6. Do not expand into string fields, retained params, virtual/interface/external ABI, refcounting, COW, deep copy, or unwind cleanup.

## Hard Invariants

- C6-H5 supports only direct compiler-emitted Pascal owned string returns used as ordinary borrowed string call arguments.
- The callee string parameter ABI remains `ptr,i64 len`; no `owner` or `alloc_size` is passed through ordinary arguments.
- The caller owns every temporary descriptor created for an owned return argument.
- Temporary release authority is always `owner/alloc_size`, never visible `ptr/len`.
- Release occurs after the enclosing call returns and before the next statement boundary.
- Multiple owned temporary arguments release in reverse creation order.
- Temporary release clears the temporary owner so ordinary cleanup cannot double free it.
- `var`/`out` string params, string fields, `Length`, `Copy`, concat, compare, `WriteLn`, virtual/interface/external/cross-unit returns stay fail-closed.
- Exception/unwind cleanup is explicitly deferred. C6-H5 only covers ordinary completion of the enclosing call.
- Unsupported consumers must fail closed with a named diagnostic; they must not silently drop `owner/alloc_size`.

## File Map

- `docs/superpowers/plans/2026-06-08-compiler-c6h5-string-call-argument-ownership-implementation.md`
  - This docs-only implementation plan.
- `tests/hir/test_hir_string_call_argument_ownership_contract.pas`
  - New RED source contracts for explicit HIR temporary ownership nodes and fail-closed boundaries.
- `tests/hir/test_hir_string_call_argument_ownership_runtime_smoke.pas`
  - New RED runtime smoke for ordinary completion release behavior.
- `tests/hir/test_hir_node_kind.pas`
  - Add only C6-H5 HIR node names if represented as `THIRNodeKind` values.
- `tests/hir/test_hir_string_return_ownership_contract.pas`
  - Preserve C6-H4 regression assertions; update only if C6-H5 replaces one fail-closed assertion with stronger C6-H5 coverage.
- `compiler/sema/np_semantic_analyzer.pas`
  - Classify supported owned-return argument consumers and keep unsupported consumers fail-closed.
- `compiler/ir/np_hir_types.pas`
  - Add explicit node kind names if the HIR truth is modeled as stable node kinds.
- `compiler/ir/np_hir_model.pas`
  - Add any minimal fields needed to represent temporary ownership in typed HIR.
- `compiler/ir/np_hir_builder.pas`
  - Materialize temporary descriptors, pass borrowed `ptr,len`, emit post-call releases, and order releases.
- `compiler/ir/np_hir_llvm_emitter.pas`
  - Lower C6-H5 temp nodes using C6-H4 descriptor extraction and `@np_string_release`.
- `build/verify_local.sh`
  - Add stable C6-H5 focused gates only after RED/GREEN are proven.

## Task 1: Commit This Plan

**Files:**
- Create: `docs/superpowers/plans/2026-06-08-compiler-c6h5-string-call-argument-ownership-implementation.md`

- [ ] Write this plan as the only new file in the plan commit.
- [ ] Confirm the accepted C6-H5 design spec exists in the same package or has landed in `origin/main`.
- [ ] Run:

```sh
git diff --check origin/main...HEAD
git status --short --branch
```

Expected: diff-check exits 0; status shows only C6-H5 docs commits ahead.

- [ ] Commit:

```sh
git add docs/superpowers/plans/2026-06-08-compiler-c6h5-string-call-argument-ownership-implementation.md
git commit -m "docs(compiler): plan C6-H5 string call argument ownership"
```

## Task 2: Add RED Source Contracts

**Files:**
- Create: `tests/hir/test_hir_string_call_argument_ownership_contract.pas`
- Modify: `tests/hir/test_hir_node_kind.pas` only if adding explicit node kinds
- Modify: `tests/hir/test_hir_string_return_ownership_contract.pas` only to preserve or replace the old argument fail-closed assertion with C6-H5-specific coverage

- [ ] Add a contract source with:

```pascal
program c6h5_string_argument_contract;

function MakeText: string;
begin
  Result := 'head' + 'tail';
end;

procedure Take(S: string);
begin
end;

begin
  Take(MakeText());
end.
```

- [ ] Assert sema/HIR now contains explicit C6-H5 temporary ownership truth. The RED failure name must be `missing-string-temp-owned-runtime` or more specific. Do not rely on LLVM text alone.
- [ ] Require stable HIR truth for:
  - `string-temp-owned-runtime` or equivalent explicit temp descriptor node
  - `string-temp-borrow-arg-runtime` or equivalent `ptr,len` borrow node
  - `string-temp-release-runtime` or equivalent post-call release node
  - temporary descriptor fields: `ptr`, `len`, `owner`, `alloc_size`
- [ ] Assert the call argument ABI remains borrowed:

```text
Take(arg.ptr, arg.len)
```

No owner metadata may be passed as a normal string parameter.

- [ ] Add a two-argument source:

```pascal
procedure Take2(A, B: string);
begin
end;

begin
  Take2(MakeA(), MakeB());
end.
```

- [ ] Assert temporary creation order is `MakeA` then `MakeB`.
- [ ] Assert release order is reverse creation order: release `MakeB` temp, then `MakeA` temp.
- [ ] Add nested direct-return assignment source:

```pascal
function Wrap(S: string): string;
begin
  Result := S + '!';
end;

begin
  S := Wrap(MakeText());
end.
```

- [ ] Assert the inner `MakeText()` temporary is released after `Wrap` returns.
- [ ] Assert the outer `Wrap` owned return descriptor is consumed by the existing C6-H4 assignment rule.
- [ ] Add fail-closed source contracts for:
  - `TObj.Field := MakeText()`
  - `TakeVar(MakeText())` where `TakeVar(var S: string)`
  - `TakeOut(MakeText())` where `TakeOut(out S: string)`
  - `Length(MakeText())`
  - `Copy(MakeText(), 1, 1)`
  - `MakeText() + 'x'` and `'x' + MakeText()`
  - `if MakeText() = 'x' then`
  - `WriteLn(MakeText())`
  - virtual/interface/external/cross-unit string return consumers
- [ ] Require a named diagnostic for unsupported consumers, either the existing `sema.c6h4-owned-string-return-deferred-consumer` or the new `sema.c6h5-owned-string-temp-unsupported-consumer`.
- [ ] Re-run the source contract. Expected RED before implementation: the supported `Take(MakeText())` case fails because explicit temp ownership nodes do not exist yet.
- [ ] Commit:

```sh
git add tests/hir/test_hir_string_call_argument_ownership_contract.pas \
  tests/hir/test_hir_node_kind.pas \
  tests/hir/test_hir_string_return_ownership_contract.pas
git commit -m "test(compiler): add C6-H5 string argument RED contracts"
```

## Task 3: Add RED Runtime Smoke

**Files:**
- Create: `tests/hir/test_hir_string_call_argument_ownership_runtime_smoke.pas`

- [ ] Use the existing HIR runtime smoke pattern: generate LLVM, write it to a temp output directory, run `opt -passes=verify`, `llc`, `clang`, then run the executable.
- [ ] Add `Take(MakeText())` exit-42 case:
  - `Take` reads first and last byte.
  - Caller releases `MakeText()` temp after `Take` returns.
  - Cleanup must not double release.
- [ ] Add `S := Wrap(MakeText())` exit-42 case:
  - `Wrap` borrows its argument.
  - Caller releases the inner `MakeText()` temp after `Wrap` returns.
  - Existing C6-H4 assignment owns and later releases the outer `Wrap` return descriptor.
- [ ] Add `Take2(MakeA(), MakeB())` exit-42 case:
  - Both arguments are readable inside `Take2`.
  - Both temporaries release exactly once.
  - Release order is reverse creation order.
- [ ] Add literal/static borrowed argument case:
  - Passing a literal string must not call `@np_string_release` for that argument.
- [ ] Keep fault cases in source contracts, not runtime smoke, for this slice.
- [ ] Run the runtime smoke. Expected RED before implementation: missing explicit temp ownership lowering or missing post-call release.
- [ ] Commit:

```sh
git add tests/hir/test_hir_string_call_argument_ownership_runtime_smoke.pas
git commit -m "test(compiler): add C6-H5 string argument runtime RED smoke"
```

## Task 4: Mark Supported And Unsupported Consumers In Sema

**Files:**
- Modify: `compiler/sema/np_semantic_analyzer.pas`
- Modify: `compiler/ir/np_hir_types.pas` only if sema emits new explicit node names

- [ ] Refine `NodeConsumesOwnedStringReturnDeferred` so ordinary direct call arguments are not rejected when all of these are true:
  - callee is a direct compiler-emitted Pascal routine
  - selected parameter is an ordinary by-value `string`
  - argument is a direct owned string-return function call
  - no `var`, `out`, field, virtual/interface/external/cross-unit, or overloaded unresolved boundary is involved
- [ ] Keep all unsupported consumers fail-closed.
- [ ] Emit or annotate HIR source truth for owned temp argument creation. The next builder step must not rediscover ownership from raw syntax.
- [ ] Do not change public string parameter ABI.
- [ ] Run source contracts. Expected: sema fail-closed cases remain GREEN; explicit temp HIR/builder contracts may remain RED.
- [ ] Commit:

```sh
git add compiler/sema/np_semantic_analyzer.pas compiler/ir/np_hir_types.pas
git commit -m "feat(compiler): classify C6-H5 string argument temporaries"
```

## Task 5: Lower Explicit Temporary Ownership In HIR Builder

**Files:**
- Modify: `compiler/ir/np_hir_builder.pas`
- Modify: `compiler/ir/np_hir_model.pas`
- Modify: `compiler/ir/np_hir_types.pas` if node kind mappings are still missing

- [ ] Add helper logic to allocate a compiler-private temporary descriptor with four fields:

```text
tmp.ptr
tmp.len
tmp.owner
tmp.alloc_size
```

- [ ] When lowering a supported call argument `MakeText()`, call the C6-H4 owned return function and extract all four fields into the temp descriptor.
- [ ] Lower the actual argument as borrowed `tmp.ptr,tmp.len`.
- [ ] Queue post-call releases for all owned temps created for that enclosing call.
- [ ] Emit releases after the enclosing call returns and before the next statement cleanup.
- [ ] Emit releases in reverse creation order.
- [ ] After each release, clear `tmp.owner` and set `tmp.alloc_size` to `0`.
- [ ] Do not add unwind cleanup. Add no code suggesting exception paths are safe.
- [ ] Run source contracts. Expected: HIR node/order contracts GREEN or emitter text contracts remain RED.
- [ ] Commit:

```sh
git add compiler/ir/np_hir_builder.pas compiler/ir/np_hir_model.pas compiler/ir/np_hir_types.pas
git commit -m "feat(compiler): lower C6-H5 string argument temp ownership"
```

## Task 6: Emit Temporary Releases In LLVM

**Files:**
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`

- [ ] Lower `string-temp-owned-runtime` by reusing C6-H4 owned return descriptor extraction:
  - `string_owned_extract_ptr`
  - `string_owned_extract_len`
  - `string_owned_extract_owner`
  - `string_owned_extract_alloc_size`
- [ ] Lower `string-temp-borrow-arg-runtime` as ordinary borrowed `ptr,len`.
- [ ] Lower `string-temp-release-runtime` as:

```llvm
call void @np_string_release(ptr %tmp.owner, i64 %tmp.alloc_size)
store ptr null, ptr %tmp.owner.slot
store i64 0, ptr %tmp.alloc_size.slot
```

- [ ] Preserve `@np_string_release` as the only runtime release helper for this slice.
- [ ] Ensure no owner metadata appears in ordinary callee parameter lists.
- [ ] Run source contracts and runtime smoke. Expected: C6-H5 focused gates GREEN.
- [ ] Commit:

```sh
git add compiler/ir/np_hir_llvm_emitter.pas
git commit -m "feat(compiler): emit C6-H5 string argument temp releases"
```

## Task 7: Add Stable Verify Hooks And Regression Gates

**Files:**
- Modify: `build/verify_local.sh`

- [ ] Add `require_path` entries for:
  - `tests/hir/test_hir_string_call_argument_ownership_contract.pas`
  - `tests/hir/test_hir_string_call_argument_ownership_runtime_smoke.pas`
- [ ] Add a focused source-contract block that prints:

```text
hir-string-call-argument-ownership-contract=running
hir-string-call-argument-ownership-contract=pass
```

- [ ] Add a focused runtime-smoke block that prints:

```text
hir-string-call-argument-ownership-runtime-smoke=running
hir-string-call-argument-ownership-runtime-smoke=pass
```

- [ ] Do not rewrite unrelated verify truth.
- [ ] Run focused gates:

```sh
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h5-src -FUbuild/.tmp/c6h5-src tests/hir/test_hir_string_call_argument_ownership_contract.pas
build/.tmp/c6h5-src/test_hir_string_call_argument_ownership_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h5-runtime -FUbuild/.tmp/c6h5-runtime tests/hir/test_hir_string_call_argument_ownership_runtime_smoke.pas
build/.tmp/c6h5-runtime/test_hir_string_call_argument_ownership_runtime_smoke build/.tmp/c6h5-runtime/out
```

- [ ] Run regression gates:
  - C6-H4 string return ownership source/runtime
  - C6-H3 string ownership source/runtime
  - C6-H1 dynarray source/runtime
  - C6-H2 field dynarray source/runtime
  - C6-G large alloc runtime and object free contracts
- [ ] Commit:

```sh
git add build/verify_local.sh
git commit -m "test(verify): add C6-H5 string argument gates"
```

## Task 8: Close The C6-H5 Implementation Package

**Files:**
- No new files beyond C6-H5 docs/tests and minimal compiler/build implementation files.

- [ ] Run:

```sh
git diff --check origin/main...HEAD
make hygiene
./build/verify_local.sh
```

- [ ] Remove generated artifacts:

```sh
rm -rf build/.tmp build/harness build/stage0-bootstrap .nextpas .sisyphus
find tests -path '*/.nextpas' -type d -prune -exec rm -rf -- {} +
```

- [ ] Confirm clean package:

```sh
git status --short --branch --untracked-files=all
git diff --name-status origin/main...HEAD
```

- [ ] Ready report must include branch, worktree, HEAD, base `origin/main`, commit range, retained files, excluded files, RED evidence, focused verification, `git diff --check`, `make hygiene`, full verify result, and landing recommendation.

## Deferred Scope

C6-H5 does not implement:

- string field owner sidecars
- string field assignment release
- object string-field cleanup
- `var` or `out` string parameter ownership
- callee-retained string argument ownership
- owned return temporary as concat operand
- owned return temporary as `Length`, `Copy`, comparison, or `WriteLn` input
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

These are explicitly deferred. A later slice must add RED contracts before
changing any of these boundaries.
