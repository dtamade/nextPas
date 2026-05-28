# SIMD Non-X86 Native Evidence (20260411-000000)

- Root: /tmp/nextpas.core
- Host Arch: riscv64
- Backend: RISCVV
- Output Root: /tmp/riscvv/run
- Environment: /home/dtamade/projects/nextpas.core/tests/nextpas.core.simd/fixtures/native-evidence/native-evidence-riscvv-20260411-000000/environment.txt

## list-suites
[BUILD] OK
[TEST] Running: /tmp/riscvv/run/bin2/nextpas.core.simd.test --list-suites
[TEST] OK
[LEAK] OK

## DispatchAPI + PublicAbi
[BUILD] OK
[TEST] Running: /tmp/riscvv/run/bin2/nextpas.core.simd.test --suite=TTestCase_DispatchAPI,TTestCase_PublicAbi
[TEST] OK
[LEAK] OK

## Runtime Parity (TTestCase_NonX86BackendParity,TTestCase_DataPlane)
[BUILD] OK
[TEST] Running: /tmp/riscvv/run/bin2/nextpas.core.simd.test --suite=TTestCase_NonX86BackendParity,TTestCase_DataPlane
[TEST] OK
[LEAK] OK

## Implementation Audit
[NONX86-IMPL-AUDIT] >>> helper-semantics
NONX86_HELPER_SEMANTICS_SUMMARY checks=41 status=ok
[NONX86-IMPL-AUDIT] >>> wiring-sync
WIRING_SYNC_SUMMARY legacy=60 grouped=60 helper=60 missing=0 extra=0 markers_missing=0 strict_extra=1 shared_legacy=1 shared_grouped=1
[NONX86-IMPL-AUDIT] >>> riscvv-abi-shape
RISCVV_ABI_SHAPE_SUMMARY direct_functions=123 explicit_checks=10 missing_result_store=0 suspicious_a0_loads=0 status=ok
[NONX86-IMPL-AUDIT] >>> register-truthfulness-neon
NONX86_REGISTER_TRUTHFULNESS_SUMMARY backend=neon assignments=411 asm_exact=209 asm_suffix_only=9 wrapper_only=193 scalar_passthrough=0 no_def=0 miswired=0 strict=1
[NONX86-IMPL-AUDIT] >>> register-truthfulness-riscvv
NONX86_REGISTER_TRUTHFULNESS_SUMMARY backend=riscvv assignments=467 asm_exact=337 asm_suffix_only=110 wrapper_only=20 scalar_passthrough=0 no_def=0 miswired=0 strict=1
[NONX86-IMPL-AUDIT] >>> key-slot-audit
NONX86_KEY_SLOT_AUDIT_SUMMARY backends=neon,riscvv slots=20 issues=0 status=ok
[NONX86-IMPL-AUDIT] >>> targeted-release-suites
[BUILD] OK
[TEST] Running: /tmp/riscvv/run/bin2/nextpas.core.simd.test --suite=TTestCase_DispatchAPI,TTestCase_DirectDispatch,TTestCase_DataPlane
[TEST] OK
[LEAK] OK
NONX86_IMPL_AUDIT_SUMMARY steps=6 native_evidence=skip targeted_output_root=/tmp/riscvv/run status=ok

## Check
[BUILD] OK
[CHECK] OK
