# SIMD 512-bit Alignment Contract Design

## Goal

Make the AVX-512 512-bit alignment contract explicit and enforceable without weakening existing SSE, AVX2, NEON, or scalar correctness paths.

## Problem

FPC `CODEALIGN RECORDMIN` tops out at 32 bytes. AVX-512 aligned load/store instructions require a 64-byte address. A 512-bit record can be a 64-byte payload, but an ordinary record variable, stack local, array element, object field, or hidden function result address must not be treated as 64-byte aligned.

## Contract

- 512-bit record types are value types with 64-byte payload size. They are not 64-byte storage owners.
- AVX-512 backend routines that read/write record parameters or hidden return buffers must use unaligned-safe transfer instructions or Pascal copy semantics.
- APIs named aligned may require 64-byte pointer alignment only when they assert that precondition and document that callers must use explicit aligned storage.
- Explicit 64-byte storage means `SimdAlloc(..., sa64)`, `AlignedAlloc(..., SIMD_ALIGN_64)`, `TAlignedArray<T>.Create(..., SIMD_ALIGN_64)`, or a future storage type with an equivalent test-backed contract.

## Implementation Shape

- Update comments in `nextpas.core.simd.base` and `nextpas.core.simd.intrinsics.base` so public type docs do not imply ordinary record/stack 64-byte address safety.
- Add `IsAligned(Ptr, SIMD_ALIGN_64)` assertions to aligned AVX-512 load/store functions in `nextpas.core.simd.intrinsics.avx512`.
- Keep unaligned AVX-512 backend asm unchanged where it already uses `vmovups`, `vmovupd`, or `vmovdqu64`.
- Add 64-byte allocation tests to `nextpas.core.simd.memutils.aliases.testcase`.
- Add `check_avx512_alignment_contract.py` as a source-contract smoke for prohibited aligned 512-bit memory operations in AVX-512 backend includes.

## Verification Strategy

- Focused fpcunit suite locks allocation and regression behavior.
- Source-contract smoke catches future accidental `vmovaps`/`vmovapd`/`vmovdqa*` in AVX-512 backend files.
- Compile/source checks are sufficient on non-AVX-512 machines because the risky contract is about source shape and pointer preconditions.
- Real AVX-512 hardware should additionally run the AVX-512 backend suites with `SIMD_BACKEND_AVX512` and vector asm enabled.

## Non-Goals

- No benchmark work in this round.
- No broad SIMD regeneration.
- No attempt to make FPC ordinary records guarantee 64-byte storage alignment.
- No changes to AVX2, SSE, NEON, or scalar semantics.
