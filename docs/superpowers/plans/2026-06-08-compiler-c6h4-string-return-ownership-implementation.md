# C6-H4 String Return Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the C6-H4 direct string-return ownership slice so compiler-emitted direct Pascal string-return routines transfer `{ptr,len,owner,alloc_size}` to owned standalone callers without changing fields, params, virtual/interface returns, external returns, refcounting, deep copy, or unwind cleanup.

**Architecture:** Treat C6-H4 as an internal direct-call ABI migration, not a public string ABI. RED contracts first freeze the four-field return descriptor, owned result slots, caller consumption order, owned local move-to-result, and deferred/fail-closed boundaries. The implementation then minimally updates sema, typed HIR, HIR builder, LLVM emitter, and verify hooks while keeping C6-G, C6-H1, C6-H2, and C6-H3 regression gates green.

**Tech Stack:** Free Pascal, nextPas sema/HIR/LLVM emitter, LLVM IR runtime helpers, `tests/hir`, `build/verify_local.sh`

---

## Baseline And Scope

- Base: `origin/main@c615192d16e27fcbf66e159a3e93ae41b065a5bb` or newer.
- Design baseline: `docs/superpowers/specs/2026-06-08-compiler-c6h4-string-return-ownership-design.md`.
- Plan package path: `docs/superpowers/plans/2026-06-08-compiler-c6h4-string-return-ownership-implementation.md`.
- This plan is docs-only. Do not add RED tests, production code, build hooks, or generated artifacts in this commit.
- Before implementation, re-check `git fetch origin main`, `git status --short --branch`, and `git rev-list --left-right --count origin/main...HEAD`.

## Hard Invariants

- Direct compiler-emitted Pascal string-return functions migrate internally from `{ptr,i64}` to `{ptr,i64,ptr owner,i64 alloc_size}`.
- The descriptor release authority is `owner/alloc_size`; visible `ptr/len` must never be freed directly.
- `alloc_size` is the exact allocator request size stored with the owner.
- `{owner=null, alloc_size=0}` means borrowed, static, literal, or alias; cleanup must not release it.
- `Result` and function-name result slots gain `$owner/$alloc_size` sidecars.
- Caller assignment must materialize returned four fields, then release the destination old owner, then store all four returned fields.
- String params remain borrowed `ptr,len`; no owner metadata passes through normal arguments.
- String fields remain object visible slots `idx` and `idx+1`; no field owner sidecar and no object string cleanup.
- Virtual, interface, external, imported, and public FFI string returns remain legacy or fail-closed. Do not globalize the owned ABI through every `htkString` return.
- C6-H4 does not support mixed old/new compiled unit string-return ABI. Cross-unit ABI metadata is deferred.

## File Map For Implementation

- `tests/hir/test_hir_string_return_ownership_contract.pas`
  - New RED source contracts for direct owned string-return ABI and fail-closed boundaries.
- `tests/hir/test_hir_string_return_ownership_runtime_smoke.pas`
  - New repeatable runtime smoke that drives `opt -> llc -> clang -> run`.
- `tests/hir/test_hir_node_kind.pas`
  - Modify only if C6-H4 adds new typed HIR node names.
- `compiler/sema/np_semantic_analyzer.pas`
  - Mark direct string-return functions, owned result slots, return-slot assignment, and owned local move-to-result.
- `compiler/ir/np_hir_types.pas`
  - Add any explicit C6-H4 node kinds required by the RED contracts.
- `compiler/ir/np_hir_builder.pas`
  - Lower four-field return descriptors, caller consumption, result-slot storage, and source-owner clear after move.
- `compiler/ir/np_hir_llvm_emitter.pas`
  - Emit direct owned return signatures, calls, extraction, stores, and `ret` descriptor construction.
- `build/verify_local.sh`
  - Add only the minimal stable C6-H4 focused gate hooks after RED/GREEN are proven.

## Task 1: Commit This Plan

**Files:**
- Create: `docs/superpowers/plans/2026-06-08-compiler-c6h4-string-return-ownership-implementation.md`

- [ ] Write this plan as the only changed file.
- [ ] Run `git diff --check`; expected: no output, exit 0.
- [ ] Run `git status --short --branch`; expected: only this plan file is modified or added before commit.
- [ ] Commit:

```sh
git add docs/superpowers/plans/2026-06-08-compiler-c6h4-string-return-ownership-implementation.md
git commit -m "docs(compiler): plan C6-H4 string return ownership"
```

Expected: one docs-only commit.

## Task 2: Add RED Source Contracts

**Files:**
- Create: `tests/hir/test_hir_string_return_ownership_contract.pas`
- Modify: `tests/hir/test_hir_string_ownership_contract.pas`
- Modify: `tests/hir/test_hir_node_kind.pas` only if new node kinds are introduced

- [ ] Add positive direct-return contracts:
  - direct string-return function emits explicit owned-return HIR truth
  - emitted return type is `{ptr, i64, ptr, i64}`
  - `Result` and function-name result slots have `$ptr/$len/$owner/$alloc_size`
  - `ret-str` returns `ptr`, `len`, `owner`, and `alloc_size`
  - concat assigned to result uses `@np_str_concat_owned`
  - `IntToStr` assigned to result uses `@np_int_to_str_owned`
  - literal/static return stores `{owner=null, alloc_size=0}`
  - `Copy` return remains borrowed alias `{owner=null, alloc_size=0}`
  - owned local assigned to result moves owner metadata and clears the source owner
  - chained return preserves the four-field descriptor through the outer result slot
- [ ] Add caller-consumption contracts:
  - `S := MakeText()` stores all four returned fields into owned standalone `S`
  - old `S$owner/S$alloc_size` is released only after the call descriptor is materialized
  - `Result := MakeText()` stores the callee descriptor into the return slot
  - repeated result overwrite releases the old result owner before replacing it
- [ ] Replace the C6-H3 "return ownership deferred" assertion with C6-H4 RED assertions; do not delete the historical boundary without a replacement gate.
- [ ] Add deferred/fail-closed contracts for owner-dropping shapes:
  - `Take(MakeText())`
  - `Obj.Field := MakeText()`
  - `S := Obj.VirtualText()`
  - `S := I.Text()`
  - `S := ExternalText()`
  - `Length(MakeText())`
  - `Copy(MakeText(), 1, 1)`
  - `'x' + MakeText()`
- [ ] Add preserved-boundary contracts:
  - string params remain `var-decl-str-borrowed-runtime`
  - string argument calls still pass only `ptr,len`
  - string fields remain two visible slots with no owner sidecar
  - `@np_object_free_release` remains field-agnostic
  - virtual/interface/external string return paths do not silently drop owned descriptors
- [ ] Run the focused contract binary. Expected RED before implementation: failures name the missing C6-H4 owned-return truth.
- [ ] Commit RED contracts:

```sh
git add tests/hir/test_hir_string_return_ownership_contract.pas \
  tests/hir/test_hir_string_ownership_contract.pas tests/hir/test_hir_node_kind.pas
git commit -m "test(compiler): add C6-H4 string return ownership contracts"
```

## Task 3: Add RED Runtime Smokes

**Files:**
- Create: `tests/hir/test_hir_string_return_ownership_runtime_smoke.pas`

- [ ] Use the C6-H3 runtime-smoke harness shape: generate LLVM, write outputs into a caller-supplied `build/.tmp/...` directory, then run `opt -passes=verify`, `llc`, `clang`, and the executable.
- [ ] Add six exit-42 cases:
  - `direct-concat-return`: callee returns `'head' + suffix`, caller checks first and last byte, cleanup releases returned owner
  - `direct-inttostr-return`: callee returns `IntToStr(42)`, caller reads `42`, cleanup releases owner base
  - `repeated-assignment-release-old-owner`: `S := MakeA(); S := MakeB();` releases the first owner and keeps the second readable
  - `literal-static-no-release`: literal return uses null owner and cleanup does not trap
  - `owned-local-move-to-result`: callee moves owned local to result, source owner is clear, caller can read and release
  - `chained-return`: `Outer` returns `Inner()` and descriptor survives both return slots
- [ ] Run the focused runtime smoke. Expected RED before implementation: missing four-field direct return ABI or missing owner propagation.
- [ ] Commit RED smoke:

```sh
git add tests/hir/test_hir_string_return_ownership_runtime_smoke.pas
git commit -m "test(compiler): add C6-H4 string return runtime smoke"
```

## Task 4: Mark Direct Owned Return In Sema

**Files:**
- Modify: `compiler/sema/np_semantic_analyzer.pas`
- Modify: `compiler/ir/np_hir_types.pas` if new node kinds are needed

- [ ] Add explicit direct-owned-return truth for compiler-emitted Pascal string-return functions only.
- [ ] Emit owned return-slot declarations for `Result` and function-name result variables.
- [ ] Emit owned-return assignment nodes for concat, `IntToStr`, direct call result, literal/static, `Copy`, and owned local move-to-result.
- [ ] Keep borrowed params as borrowed string declarations and keep normal argument lowering as `ptr,len`.
- [ ] Keep string fields and virtual/interface/external returns outside the owned direct ABI.
- [ ] Run RED source contracts. Expected: sema-level contracts should move toward GREEN while builder/emitter contracts remain RED.
- [ ] Commit:

```sh
git add compiler/sema/np_semantic_analyzer.pas compiler/ir/np_hir_types.pas
git commit -m "feat(compiler): mark C6-H4 direct string return ownership"
```

## Task 5: Lower Return Descriptors In HIR Builder

**Files:**
- Modify: `compiler/ir/np_hir_builder.pas`
- Modify: `compiler/ir/np_hir_types.pas` if parser mappings are still missing

- [ ] Reuse C6-H3 `ClearStringOwner`, `ReleaseStringOwner`, and owned producer storage helpers where possible.
- [ ] Add return-slot storage for four-field descriptors.
- [ ] Add owned-call assignment lowering: call, extract `ptr/len/owner/alloc_size`, release old destination owner, store returned descriptor.
- [ ] Add owned local move-to-result lowering: copy visible fields and owner fields, then clear source owner.
- [ ] Ensure callee ordinary cleanup skips the returned owner but still releases all other owned locals.
- [ ] Fail closed for unsupported owner-dropping targets rather than silently clearing returned ownership.
- [ ] Run source contracts. Expected: HIR/builder contracts GREEN or only emitter text/runtime contracts remain RED.
- [ ] Commit:

```sh
git add compiler/ir/np_hir_builder.pas compiler/ir/np_hir_types.pas
git commit -m "feat(compiler): lower C6-H4 string return descriptors"
```

## Task 6: Emit Direct Owned Return ABI In LLVM

**Files:**
- Modify: `compiler/ir/np_hir_llvm_emitter.pas`

- [ ] Add an internal direct string-return ABI marker so only compiler-emitted direct string-return functions use `{ptr,i64,ptr,i64}`.
- [ ] Update direct function signatures, direct string calls, extraction, stores, and `ret` construction for the four-field descriptor.
- [ ] Preserve string parameter ABI as `ptr,i64`.
- [ ] Preserve virtual/interface/external string return ABI as legacy or fail-closed; do not update VMT/IMT or FFI ABI in C6-H4.
- [ ] Preserve C6-H3 helpers `@np_str_concat_owned`, `@np_int_to_str_owned`, and `@np_string_release`.
- [ ] Run source contracts and runtime smoke. Expected: C6-H4 focused gates GREEN.
- [ ] Commit:

```sh
git add compiler/ir/np_hir_llvm_emitter.pas
git commit -m "feat(compiler): emit C6-H4 owned string return ABI"
```

## Task 7: Add Stable Verify Hooks And Regression Gates

**Files:**
- Modify: `build/verify_local.sh`

- [ ] Add minimal `require_path` entries for the two C6-H4 test files.
- [ ] Add a source-contract block for `test_hir_string_return_ownership_contract.pas`.
- [ ] Add a runtime-smoke block for `test_hir_string_return_ownership_runtime_smoke.pas`, passing an output directory under the verify temp root.
- [ ] Print explicit pass/fail status for C6-H4 source and runtime gates.
- [ ] Do not rewrite old C6-H3 truth or unrelated LLVM smoke expected exits.
- [ ] Run implementation focused gates:

```sh
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h4-src -FUbuild/.tmp/c6h4-src tests/hir/test_hir_string_return_ownership_contract.pas
build/.tmp/c6h4-src/test_hir_string_return_ownership_contract
fpc -Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Furtl/core/base -Furtl/core/text -FEbuild/.tmp/c6h4-runtime -FUbuild/.tmp/c6h4-runtime tests/hir/test_hir_string_return_ownership_runtime_smoke.pas
build/.tmp/c6h4-runtime/test_hir_string_return_ownership_runtime_smoke build/.tmp/c6h4-runtime/out
```

Expected: both pass after implementation.

- [ ] Run regression gates: C6-G large alloc smoke, C6-H1 dynarray gates, C6-H2 field dynarray gates, and C6-H3 string ownership contract/runtime smoke.
- [ ] Commit:

```sh
git add build/verify_local.sh
git commit -m "test(verify): add C6-H4 string return gates"
```

## Task 8: Close The Implementation Package

**Files:**
- No new files beyond the retained C6-H4 package.

- [ ] Run:

```sh
git diff --check
make hygiene
./build/verify_local.sh
```

- [ ] Confirm no generated artifacts are retained:

```sh
git status --short --branch
git diff --name-status origin/main...HEAD
```

- [ ] Ready report must include branch, worktree, HEAD, base `origin/main`, commit range, retained files, excluded files, focused verification, `git diff --check`, `make hygiene`, full verify result, and landing recommendation.

## Deferred Scope

- string field owner sidecars, field assignment release, object string cleanup, and class layout changes
- string parameter ownership transfer
- direct owned return temporaries as arguments, concat operands, `Length`, `Copy`, compare, or `WriteLn` inputs
- virtual/interface string return ownership and VMT/IMT ABI
- external/imported/FFI/public string return ABI
- cross-unit mixed ABI metadata
- refcounting, copy-on-write, deep assignment, deep `Copy`, substring allocation, and alias lifetime analysis
- record, array, dynarray, or managed-element string finalization
- exception/unwind cleanup
- polymorphic runtime-type finalization
