# SIMD 512-bit Alignment Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce the nextpas.core SIMD 512-bit alignment contract through docs, assertions, runtime tests, and source-contract smoke.

**Architecture:** Ordinary 512-bit records remain value payloads with no 64-byte address promise. Backend record paths stay unaligned-safe; explicit aligned pointer APIs assert 64-byte alignment and tests prove allocation owners provide it.

**Tech Stack:** FreePascal 3.3.1-style Pascal, fpcunit, Python source-contract smoke, SIMD Makefile gates.

---

## File Structure

- Modify `src/nextpas.core.simd.base.pas`: clarify 512-bit record alignment contract.
- Modify `src/nextpas.core.simd.intrinsics.base.pas`: clarify `TM512` payload vs storage alignment.
- Modify `src/nextpas.core.simd.intrinsics.avx512.pas`: add 64-byte assertions for aligned load/store only.
- Modify `src/nextpas.core.simd.memutils.pas`: keep constants and optionally strengthen comments; do not change allocator behavior unless tests expose failure.
- Modify `tests/nextpas.core.simd/nextpas.core.simd.memutils.aliases.testcase.pas`: add 64-byte allocation tests.
- Create `tests/nextpas.core.simd/check_avx512_alignment_contract.py`: source-contract smoke.
- Modify `tests/nextpas.core.simd/Makefile`: include the smoke in `audit`.

## Task 1: Baseline

- [ ] Run focused baseline:

```bash
make -C tests/nextpas.core.simd clean test
```

Expected: existing SIMD focused suite passes before production edits.

## Task 2: RED Runtime Alignment Tests

- [ ] Add fpcunit tests:

```pascal
procedure Test_AlignedAlloc_64ByteAlignedAndWritable;
procedure Test_TAlignedArray_64ByteAligned;
procedure Test_SimdAlloc_Sa64_64ByteAligned;
```

- [ ] Run RED:

```bash
make -C tests/nextpas.core.simd clean test
```

Expected before implementation/docs update: tests may pass if allocator already works; this still creates executable regression coverage for the missing contract.

## Task 3: RED Source-Contract Smoke

- [ ] Create `tests/nextpas.core.simd/check_avx512_alignment_contract.py` that scans:

```text
src/nextpas.core.simd.base.pas
src/nextpas.core.simd.avx512*
src/nextpas.core.simd.intrinsics.base.pas
src/nextpas.core.simd.intrinsics.avx512.pas
src/nextpas.core.simd.memutils.pas
```

- [ ] It must fail if AVX-512 backend sources contain aligned 512-bit memory mnemonics such as `vmovaps`, `vmovapd`, `vmovdqa32`, or `vmovdqa64`.
- [ ] It must fail if the base contract still contains language implying stack/ordinary records are 64-byte aligned.
- [ ] Run RED:

```bash
python3 tests/nextpas.core.simd/check_avx512_alignment_contract.py
```

Expected: fails until contract wording and aligned API assertions are present.

## Task 4: GREEN Contract and Assertions

- [ ] Update 512-bit type comments to state ordinary records are not 64-byte storage owners.
- [ ] Add `Assert(IsPointerAligned64(Ptr), ...)` helper or equivalent to aligned AVX-512 load/store functions.
- [ ] Leave `avx512_loadu_ps512` and `avx512_storeu_ps512` unaligned.
- [ ] Run focused tests:

```bash
make -C tests/nextpas.core.simd clean test
python3 tests/nextpas.core.simd/check_avx512_alignment_contract.py
```

Expected: PASS.

## Task 5: Wire Audit and Verify

- [ ] Add source-contract smoke to `make -C tests/nextpas.core.simd audit`.
- [ ] Run:

```bash
make -C tests/nextpas.core.simd audit
git diff --check
git status --short --branch
```

Expected: PASS and only scoped files changed.

## Task 6: Review and Commit

- [ ] Ask read-only reviewer/subagent to check final diff against the design.
- [ ] Commit only scoped files:

```bash
git add src/nextpas.core.simd.base.pas src/nextpas.core.simd.intrinsics.base.pas src/nextpas.core.simd.intrinsics.avx512.pas src/nextpas.core.simd.memutils.pas tests/nextpas.core.simd/nextpas.core.simd.memutils.aliases.testcase.pas tests/nextpas.core.simd/check_avx512_alignment_contract.py tests/nextpas.core.simd/Makefile docs/plans/2026-06-06-simd512-alignment-contract-design.md docs/plans/2026-06-06-simd512-alignment-contract-plan.md task_plan.md findings.md progress.md
git commit -m "fix(simd): enforce avx512 alignment contract"
```
