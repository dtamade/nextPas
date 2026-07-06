# Experimental ASM Compiler-Ready Blockers

## Latest Wave (2026-02-22, 01:36)

- mainline gate (`gate-strict`, with qemu chain): PASS  
  - summary: `tests/nextpas.core.simd/logs/qemu-multiarch-20260222-013045/summary.md`
- dedicated RVV opcode lane (`riscvv-opcode-lane`, default `compile_target=project`): PASS  
  - summary: `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-225950/summary.md`
- strict project-target compile check (`SIMD_RVV_COMPILE_TARGET=project`): PASS  
  - summary: `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-225804/summary.md`
- non-x86 experimental asm lane (`SIMD_QEMU_ENABLE_BACKEND_ASM=1` + `*_ASM_COMPILER_READY`): PASS  
  - summary: `tests/nextpas.core.simd/logs/qemu-multiarch-20260222-012357/summary.md`

## Dedicated RVV Lane Status (Current)

| Item | Status | Evidence |
|---|---|---|
| compile-only (`project`) opcode verification (prebuilt patched compiler + qemu-x86_64 wrapper) | PASS | `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-225804/compile_only.log` |
| suite (`TTestCase_NonX86IEEE754`) under compiler-ready runtime define | PASS | `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-225950/suite.log` |
| bench (`RISCVV_vs_Scalar`) under compiler-ready runtime define | PASS | `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-225950/bench.log` |

## Lane Architecture (Now)

1. default `compile_target` is `project`.
2. prebuilt compiler defaults to `/opt/fpcupdeluxe/fpcsrc/compiler/ppcrossrv64_v`.
3. prebuilt units defaults to `/opt/fpcupdeluxe/fpc-rvv-units/riscv64-linux`.
4. smoke lane no longer rewrites asm `.attribute`; it now relies on patched compiler output end-to-end.
5. suite/bench keep runtime defines (`...RISCVV_ASM_COMPILER_READY`, without opcode-ready define) to stay aligned with stable gate semantics.

## Resolved Blockers

- `COMPILE_TARGET=project` full target compile under prebuilt patched toolchain: RESOLVED.
- RVV asm attribute workaround in smoke lane: REMOVED.
- RVV lane default promotion from `smoke` to `project`: COMPLETED.

## Remaining Blockers (Current)

- none (with default `SIMD_QEMU_BUILD_POLICY=if-missing` and warm local images)
- note: if forcing `SIMD_QEMU_BUILD_POLICY=always`, intermittent Docker Hub metadata/network issues can still surface in external environments.

## Experimental ASM Probe Snapshot

- latest asm probe report: `tests/nextpas.core.simd/docs/experimental_asm_blockers.md`
- latest asm probe summary: `tests/nextpas.core.simd/logs/qemu-multiarch-20260222-012357/summary.md`
- baseline check: `tests/nextpas.core.simd/docs/experimental_asm_expected_failures.json`

## Historical References

- prior failing project-target wave: `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-221228/summary.md`
- prior smoke-attribute workaround wave: `tests/nextpas.core.simd/logs/rvv-opcode-lane-20260221-215626/summary.md`
