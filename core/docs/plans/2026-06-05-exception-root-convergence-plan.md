# Exception Root Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce one official nextpas.core framework exception root and complete the first compatibility slice for timeout and out-of-memory exceptions.

**Architecture:** Add `nextpas.core.exception` as the L0 root contract. Make `base`, `errors`, and `mem.error` depend downward on it, preserving compatibility while removing duplicate public timeout and OOM roots.

**Stage 1B extension:** After the root slice, migrate the most dangerous remaining production seams discovered by audit: `TVec` allocation failures, mem `aeOutOfMemory` producers, and the TUI module root.

**Tech Stack:** FreePascal 3.3.1, nextpas.core L0 Pascal units, Makefile-based tests, heaptrc verification.

---

## File Structure

- Create `src/nextpas.core.exception.pas`: canonical L0 exception root, categories, inner exception ownership, shared exception classes.
- Modify `src/nextpas.core.base.pas`: legacy base exception compatibility under `ENextPasError`; alias shared exception names.
- Modify `src/nextpas.core.errors.pas`: facade/taxonomy re-export of canonical root and common exceptions.
- Modify `src/nextpas.core.mem.error.pas`: allocation-specific exceptions under unified root; preserve `TAllocError` and `EAllocError.Error`.
- Modify `src/nextpas.core.collections.vec.pas`: use canonical OOM for reserve failures.
- Modify mem producer units that raise `aeOutOfMemory`: blockpool, growable blockpool, growable arena, fixed pool, growable fixed pool, ring buffer, and stack pool.
- Modify `src/nextpas.core.tui.error.pas`: make `ETui` inherit directly from `ENextPasError`.
- Create `tests/nextpas.core.exception/test_exception_root/Makefile`.
- Create `tests/nextpas.core.exception/test_exception_root/test_exception_root.lpr`.
- Modify `tests/nextpas.core.errors/test_errors/test_errors.lpr`: prove legacy `nextpas.core.errors` consumers see canonical root.
- Modify `tests/nextpas.core.collections/test_vec/test_vec.lpr`: prove reserve failures catch as canonical OOM.
- Create `tests/nextpas.core.mem/test_oom/*`: prove mem OOM producers catch as canonical OOM while non-OOM allocation errors remain `EAllocError`.
- Modify `tests/nextpas.core.tui/test_tui_error/test_tui_error.lpr`: prove TUI catches as `ENextPasError` and remains `ECore` compatible.
- Optionally create `tests/nextpas.core.mem/test_exception_root/*` if allocation-specific constructor/catch coverage cannot fit the exception root test without adding a mem dependency.
- Update `task_plan.md`, `findings.md`, and `progress.md`.

## Task 1: RED test for canonical root and duplicate-type convergence

**Files:**
- Create: `tests/nextpas.core.exception/test_exception_root/Makefile`
- Create: `tests/nextpas.core.exception/test_exception_root/test_exception_root.lpr`

- [ ] **Step 1: Write failing canonical root test**

The test must assert:

- `ECore` is catchable as `ENextPasError`.
- Legacy `on E: ECore` catches canonical timeout and OOM aliases.
- `nextpas.core.base.ETimeoutError` and `nextpas.core.errors.ETimeoutError` resolve to the same runtime class.
- `nextpas.core.errors.EOutOfMemoryError` catches compatibility `nextpas.core.base.EOutOfMemory`.
- `nextpas.core.mem.error.EAllocError` is catchable as `ENextPasError`.
- `TAllocResult.Err(aeOutOfMemory).ExpectPtr` raises an exception catchable as `EOutOfMemoryError` and `ENextPasError`.

- [ ] **Step 2: Run RED**

Run:

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
```

Expected: fail to compile because `nextpas.core.exception` does not exist.

## Task 2: Implement `nextpas.core.exception`

**Files:**
- Create: `src/nextpas.core.exception.pas`

- [ ] **Step 1: Add canonical root unit**

Define:

- `Exception = SysUtils.Exception`
- `ExceptClass = SysUtils.ExceptClass`
- `EConvertError = SysUtils.EConvertError`
- `EAssertionFailed = SysUtils.EAssertionFailed`
- `TErrorCategory`
- `ENextPasError`
- common subclasses including `ETimeoutError`, `EArgumentError`, `EIOError`, `EOutOfMemoryError`, and compatibility `EOutOfMemory`.

- [ ] **Step 2: Run root test**

Run:

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
```

Expected: still fail because `base`, `errors`, and `mem.error` have not been rewired.

## Task 3: Rewire `base` and `errors`

**Files:**
- Modify: `src/nextpas.core.base.pas`
- Modify: `src/nextpas.core.errors.pas`
- Modify: `tests/nextpas.core.errors/test_errors/test_errors.lpr`

- [ ] **Step 1: Update base compatibility**

Make `ECore` a compatibility alias of `ENextPasError`. Keep legacy base-specific exceptions source-compatible under `ECore`. Re-export canonical timeout and OOM names without creating new class identities.

- [ ] **Step 2: Update errors facade**

Make `nextpas.core.errors` depend on `nextpas.core.exception` and expose the same public names from the canonical unit. Do not keep duplicate class definitions for `ENextPasError`, `ETimeoutError`, or `EOutOfMemoryError`.

- [ ] **Step 3: Run root and errors tests**

Run:

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
make -C tests/nextpas.core.errors/test_errors clean test
```

Expected: root may still fail on mem allocation coverage until Task 4; errors should pass or fail only on expected mem-related missing pieces.

## Task 4: Rewire `mem.error`

**Files:**
- Modify: `src/nextpas.core.mem.error.pas`
- Optionally create: `tests/nextpas.core.mem/test_exception_root/Makefile`
- Optionally create: `tests/nextpas.core.mem/test_exception_root/test_exception_root.lpr`

- [ ] **Step 1: Put allocation exceptions under the unified root**

Make `EAllocError` inherit from `ENextPasError` or the canonical resource-exhausted lineage. Preserve `constructor Create(aError: TAllocError; const aMsg: string = '')` and `property Error`.

- [ ] **Step 2: Keep OOM compatibility**

Ensure allocation OOM exceptions are catchable as `EOutOfMemoryError` and `ENextPasError`. If constructor compatibility needs a mem-specific subclass, keep it under `EOutOfMemoryError`.

Because Pascal exceptions have single inheritance, do not pretend `mem.error.EOutOfMemory` can also remain an `EAllocError` subclass after it moves into the canonical OOM lineage. Preserve source construction and `Error: TAllocError`; migrate OOM catch sites to `EOutOfMemoryError` in later stages if any appear.

- [ ] **Step 3: Run focused tests**

Run:

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
make -C tests/nextpas.core.errors/test_errors clean test
```

Expected: both pass with heaptrc `0 unfreed memory blocks`.

## Task 5: Focused HTTP timeout guard

**Files:**
- Prefer no source edits.
- Only touch HTTP tests/source if unqualified timeout names become ambiguous.

- [ ] **Step 1: Run HTTP server timeout gate**

Run:

```bash
make -C tests/nextpas.core.http/test_http_server clean test
```

Expected: pass with heaptrc `0 unfreed memory blocks`.

- [ ] **Step 2: If ambiguity appears, apply mechanical qualification only**

Allowed fix: qualify `ETimeoutError` references so they resolve to the canonical exception. Not allowed: behavior changes in parser, transport, benchmarks, request handling, or response handling.

## Task 6: Final review, docs, and commit

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

- [ ] **Step 1: Run final focused verification**

Run:

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
make -C tests/nextpas.core.errors/test_errors clean test
make -C tests/nextpas.core.http/test_http_server clean test
git diff --check
git status --short --branch
```

Expected: tests pass with zero leaks; diff check has no whitespace errors; status shows only intended files.

- [ ] **Step 2: Commit**

Run:

```bash
git add src/nextpas.core.exception.pas src/nextpas.core.base.pas src/nextpas.core.errors.pas src/nextpas.core.mem.error.pas tests/nextpas.core.exception tests/nextpas.core.errors/test_errors/test_errors.lpr docs/plans/2026-06-05-exception-root-convergence-design.md docs/plans/2026-06-05-exception-root-convergence-plan.md task_plan.md findings.md progress.md
git commit -m "refactor(errors): introduce unified framework exception root"
```

Do not merge into `main` while the shared checkout contains HTTP colleague work.

## Task 7: Stage 1B production seam migration

**Files:**
- Modify: `src/nextpas.core.collections.vec.pas`
- Modify: `src/nextpas.core.mem.blockpool.pas`
- Modify: `src/nextpas.core.mem.blockpool.growable.pas`
- Modify: `src/nextpas.core.mem.arena.growable.pas`
- Modify: `src/nextpas.core.mem.pool.fixed.pas`
- Modify: `src/nextpas.core.mem.pool.fixed.growable.pas`
- Modify: `src/nextpas.core.mem.ring_buffer.pas`
- Modify: `src/nextpas.core.mem.stack_pool.pas`
- Modify: `src/nextpas.core.tui.error.pas`
- Modify: `tests/nextpas.core.collections/test_vec/test_vec.lpr`
- Create: `tests/nextpas.core.mem/test_oom/Makefile`
- Create: `tests/nextpas.core.mem/test_oom/test_oom.lpr`
- Modify: `tests/nextpas.core.tui/test_tui_error/test_tui_error.lpr`

- [x] **Step 1: RED for `TVec` OOM**

Add deterministic tests for `Reserve` and `ReserveExact` failures. Avoid real huge allocation; use add-overflow after a one-element push.

- [x] **Step 2: GREEN for `TVec` OOM**

Change `TVec.Reserve` and `TVec.ReserveExact` to raise canonical `EOutOfMemory`.

- [x] **Step 3: RED for mem OOM producer semantics**

Add `tests/nextpas.core.mem/test_oom` using overflow paths and failing allocators to prove mem OOM producers must catch as `EOutOfMemoryError` and not as non-OOM `EAllocError`.

- [x] **Step 4: GREEN for mem OOM producer semantics**

Change `aeOutOfMemory` producer raises in the affected mem units to `EOutOfMemory.Create(...)`. Keep non-OOM allocation failures under `EAllocError` and module-specific subclasses.

- [x] **Step 5: TUI root migration**

Use a source-contract RED for `class(ECore)`, then migrate `ETui` to `ENextPasError`. Keep tests proving legacy `ECore` catch compatibility.

- [x] **Step 6: Stage 1B verification**

Run:

```bash
make -C tests/nextpas.core.exception/test_exception_root clean test
make -C tests/nextpas.core.errors/test_errors clean test
make -C tests/nextpas.core.base/test_base clean test
make -C tests/nextpas.core.collections/test_vec clean test
make -C tests/nextpas.core.mem/test_oom clean test
make -C tests/nextpas.core.mem/test_mem clean test
make -C tests/nextpas.core.mem/test_arena clean test
make -C tests/nextpas.core.mem/test_arena_class clean test
make -C tests/nextpas.core.mem/test_pool clean test
make -C tests/nextpas.core.mem/test_blockpool clean test
make -C tests/nextpas.core.mem/test_contracts clean test
make -C tests/nextpas.core.tui/test_tui_error clean test
make -C tests/nextpas.core.http/test_http_server clean test
git diff --check
```

Expected: all tests pass with heaptrc `0 unfreed memory blocks`; static audits show no production `ECore.Create`, no production `class(ECore)` outside `nextpas.core.base`, no `EAllocError.Create(aeOutOfMemory...)`, and a single public `ETimeoutError` class.
