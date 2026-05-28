@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=test"
if not "%~1"=="" shift

set "NORMALIZED_TEST_ARGS="
:collect_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--list" (
  set "NORMALIZED_TEST_ARGS=!NORMALIZED_TEST_ARGS! --list-suites"
) else (
  set "NORMALIZED_TEST_ARGS=!NORMALIZED_TEST_ARGS! %1"
)
shift
goto :collect_args
:args_done

set "ROOT=%SIMD_SCRIPT_ROOT%"
if "%ROOT%"=="" set "ROOT=%~dp0"
if not "%ROOT%"=="" if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"
if not exist "%ROOT%buildOrTest.bat" set "ROOT=%CD%\tests\nextpas.core.simd\"
if not "%ROOT:~-1%"=="\" set "ROOT=%ROOT%\"
set "OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
if "%OUTPUT_ROOT%"=="" set "OUTPUT_ROOT=%ROOT%"
set "PROJ=%ROOT%nextpas.core.simd.test.lpi"
set "BIN_DIR=%OUTPUT_ROOT%\bin2"
set "LIB_DIR=%OUTPUT_ROOT%\lib2"
set "TARGET_CPU="
for /f "delims=" %%I in ('fpc -iTP 2^>nul') do if not defined TARGET_CPU set "TARGET_CPU=%%I"
if not defined TARGET_CPU set "TARGET_CPU=nativecpu"
set "TARGET_OS="
for /f "delims=" %%I in ('fpc -iTO 2^>nul') do if not defined TARGET_OS set "TARGET_OS=%%I"
if not defined TARGET_OS set "TARGET_OS=nativeos"
set "UNIT_DIR=%LIB_DIR%\%TARGET_CPU%-%TARGET_OS%"
set "BIN=%BIN_DIR%\nextpas.core.simd.test.exe"
set "LOG_DIR=%OUTPUT_ROOT%\logs"
set "BUILD_LOG=%LOG_DIR%\build.txt"
set "TEST_LOG=%LOG_DIR%\test.txt"
set "GATE_SUMMARY_LOG=%LOG_DIR%\gate_summary.md"
set "GATE_SUMMARY_JSON_LOG=%LOG_DIR%\gate_summary.json"
set "DISPATCH_PREINIT_SMOKE_SRC=%ROOT%nextpas.core.simd.dispatch_preinit_smoke.pas"
set "PUBLIC_SMOKE_SRC=%ROOT%nextpas.core.simd.public_smoke.pas"
set "BACKEND_OPS_SRC=%ROOT%test_backend_ops.pas"
set "SIMD_BOUNDARY_SRC=%ROOT%test_simd_boundary.pas"

if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%UNIT_DIR%" mkdir "%UNIT_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set "LAZBUILD_EXE=%LAZBUILD%"
if "%LAZBUILD_EXE%"=="" set "LAZBUILD_EXE=%ProgramFiles%\Lazarus\lazbuild.exe"
set "LAZBUILD_CONFIG_IS_PATH=0"
if not "%LAZBUILD_EXE:\=%"=="%LAZBUILD_EXE%" set "LAZBUILD_CONFIG_IS_PATH=1"
if not "%LAZBUILD_EXE:/=%"=="%LAZBUILD_EXE%" set "LAZBUILD_CONFIG_IS_PATH=1"
if not "%LAZBUILD_EXE::=%"=="%LAZBUILD_EXE%" set "LAZBUILD_CONFIG_IS_PATH=1"
if "%LAZBUILD_CONFIG_IS_PATH%"=="1" if not exist "%LAZBUILD_EXE%" set "LAZBUILD_EXE=lazbuild"

set "MODE=%FAFAFA_BUILD_MODE%"
if "%MODE%"=="" set "MODE=Release"

if /I "%ACTION%"=="clean" goto :clean
if /I "%ACTION%"=="build" goto :build
if /I "%ACTION%"=="check" goto :check
if /I "%ACTION%"=="test" goto :test
if /I "%ACTION%"=="test-concurrent-repeat" goto :test_concurrent_repeat
if /I "%ACTION%"=="cpuinfo-lazy-repeat" goto :cpuinfo_lazy_repeat
if /I "%ACTION%"=="debug" goto :debug_action
if /I "%ACTION%"=="release" goto :release_action
if /I "%ACTION%"=="gate" goto :gate
if /I "%ACTION%"=="gate-strict" goto :gate_strict
if /I "%ACTION%"=="closeout-release" goto :closeout_release
if /I "%ACTION%"=="sse2-structure-check" goto :sse2_structure_check
if /I "%ACTION%"=="sse2-contracts" goto :sse2_contracts
if /I "%ACTION%"=="impl-smoke-sse2" goto :impl_smoke_sse2
if /I "%ACTION%"=="impl-smoke-x86" goto :impl_smoke_x86
if /I "%ACTION%"=="impl-smoke-nonx86" goto :impl_smoke_nonx86
if /I "%ACTION%"=="impl-audit-nonx86" goto :impl_audit_nonx86
if /I "%ACTION%"=="helper-semantics" goto :helper_semantics
if /I "%ACTION%"=="riscvv-sensitive-hold-set" goto :riscvv_sensitive_hold_set
if /I "%ACTION%"=="key-slot-audit" goto :key_slot_audit
if /I "%ACTION%"=="implementation-matrix-sync" goto :implementation_matrix_sync
if /I "%ACTION%"=="riscvv-abi-shape" goto :riscvv_abi_shape
if /I "%ACTION%"=="source-reachability" goto :source_reachability
if /I "%ACTION%"=="closeout-host-local" goto :closeout_host_local
if /I "%ACTION%"=="import-nonx86-native-evidence" goto :import_nonx86_native_evidence
if /I "%ACTION%"=="closeout-host-local-from-import" goto :closeout_host_local_from_import
if /I "%ACTION%"=="interface-completeness" goto :interface_completeness
if /I "%ACTION%"=="public-api-coverage" goto :public_api_coverage
if /I "%ACTION%"=="dispatch-read-scope" goto :dispatch_read_scope
if /I "%ACTION%"=="dataplane-consumer-scope" goto :dataplane_consumer_scope
if /I "%ACTION%"=="direct-dispatch-scope" goto :direct_dispatch_scope
if /I "%ACTION%"=="metadata-query-scope" goto :metadata_query_scope
if /I "%ACTION%"=="contract-signature" goto :contract_signature
if /I "%ACTION%"=="publicabi-signature" goto :publicabi_signature
if /I "%ACTION%"=="publicabi-smoke" goto :publicabi_smoke
if /I "%ACTION%"=="adapter-sync-pascal" goto :adapter_sync_pascal
if /I "%ACTION%"=="adapter-sync" goto :adapter_sync
if /I "%ACTION%"=="runner-parity" goto :runner_parity
if /I "%ACTION%"=="closeout-guard" goto :closeout_guard
if /I "%ACTION%"=="parity-suites" goto :parity_suites
if /I "%ACTION%"=="gate-summary" goto :gate_summary
if /I "%ACTION%"=="gate-summary-sample" goto :gate_summary_sample
if /I "%ACTION%"=="gate-summary-rehearsal" goto :gate_summary_rehearsal
if /I "%ACTION%"=="gate-summary-inject" goto :gate_summary_inject
if /I "%ACTION%"=="gate-summary-rollback" goto :gate_summary_rollback
if /I "%ACTION%"=="gate-summary-backups" goto :gate_summary_backups
if /I "%ACTION%"=="gate-summary-selfcheck" goto :gate_summary_selfcheck
if /I "%ACTION%"=="release-evidence" goto :release_evidence
if /I "%ACTION%"=="historical-closeout-note-check" goto :historical_closeout_note_check
if /I "%ACTION%"=="active-closeout-truth-check" goto :active_closeout_truth_check
if /I "%ACTION%"=="perf-smoke" goto :perf_smoke
if /I "%ACTION%"=="nonx86-optin-list-suites" goto :nonx86_optin_list_suites
if /I "%ACTION%"=="nonx86-ieee754" goto :nonx86_ieee754
if /I "%ACTION%"=="backend-bench" goto :backend_bench
if /I "%ACTION%"=="qemu-nonx86-evidence" goto :qemu_nonx86_evidence
if /I "%ACTION%"=="qemu-cpuinfo-nonx86-evidence" goto :qemu_cpuinfo_nonx86_evidence
if /I "%ACTION%"=="qemu-cpuinfo-nonx86-full-evidence" goto :qemu_cpuinfo_nonx86_full_evidence
if /I "%ACTION%"=="qemu-cpuinfo-nonx86-full-repeat" goto :qemu_cpuinfo_nonx86_full_repeat
if /I "%ACTION%"=="qemu-cpuinfo-retry-rehearsal" goto :qemu_cpuinfo_retry_rehearsal
if /I "%ACTION%"=="qemu-cpuinfo-nonx86-suite-repeat" goto :qemu_cpuinfo_nonx86_suite_repeat
if /I "%ACTION%"=="qemu-arch-matrix-evidence" goto :qemu_arch_matrix_evidence
if /I "%ACTION%"=="qemu-nonx86-experimental-asm" goto :qemu_nonx86_experimental_asm
if /I "%ACTION%"=="riscvv-opcode-lane" goto :riscvv_opcode_lane
if /I "%ACTION%"=="qemu-experimental-report" goto :qemu_experimental_report
if /I "%ACTION%"=="qemu-experimental-baseline-check" goto :qemu_experimental_baseline_check
if /I "%ACTION%"=="coverage" goto :coverage
if /I "%ACTION%"=="wiring-sync" goto :wiring_sync
if /I "%ACTION%"=="experimental-intrinsics" goto :experimental_intrinsics
if /I "%ACTION%"=="experimental-intrinsics-tests" goto :experimental_intrinsics_tests
if /I "%ACTION%"=="evidence-linux" goto :evidence_linux
if /I "%ACTION%"=="native-evidence" goto :native_evidence
if /I "%ACTION%"=="native-evidence-via-gh" goto :native_evidence_via_gh
if /I "%ACTION%"=="native-evidence-via-gh-clean" goto :native_evidence_via_gh_clean
if /I "%ACTION%"=="verify-nonx86-native-evidence" goto :verify_nonx86_native_evidence
if /I "%ACTION%"=="riscvv-runner-registration" goto :riscvv_runner_registration
if /I "%ACTION%"=="riscvv-runner-host-preflight" goto :riscvv_runner_host_preflight
if /I "%ACTION%"=="riscvv-runner-3cmd" goto :riscvv_runner_3cmd
if /I "%ACTION%"=="restore-nightly-evidence" goto :restore_nightly_evidence
if /I "%ACTION%"=="evidence-win" goto :evidence_win
if /I "%ACTION%"=="win-evidence-preflight" goto :win_evidence_preflight
if /I "%ACTION%"=="win-evidence-via-gh" goto :win_evidence_via_gh
if /I "%ACTION%"=="verify-win-evidence" goto :verify_win_evidence
if /I "%ACTION%"=="evidence-win-verify" goto :evidence_win_verify
if /I "%ACTION%"=="finalize-win-evidence" goto :finalize_win_evidence
if /I "%ACTION%"=="win-closeout-dryrun" goto :win_closeout_dryrun
if /I "%ACTION%"=="win-closeout-snippets" goto :win_closeout_snippets
if /I "%ACTION%"=="win-closeout-3cmd" goto :win_closeout_3cmd
if /I "%ACTION%"=="freeze-status" goto :freeze_status
if /I "%ACTION%"=="freeze-status-linux" goto :freeze_status_linux
if /I "%ACTION%"=="win-closeout-finalize" goto :win_closeout_finalize
if /I "%ACTION%"=="freeze-status-rehearsal" goto :freeze_status_rehearsal

echo Usage: %~nx0 [clean^|build^|check^|test^|test-concurrent-repeat^|cpuinfo-lazy-repeat^|debug^|release^|gate^|gate-strict^|closeout-release^|sse2-structure-check^|sse2-contracts^|impl-smoke-sse2^|impl-smoke-x86^|impl-smoke-nonx86^|impl-audit-nonx86^|helper-semantics^|riscvv-sensitive-hold-set^|key-slot-audit^|implementation-matrix-sync^|riscvv-abi-shape^|source-reachability^|closeout-host-local^|import-nonx86-native-evidence^|closeout-host-local-from-import^|interface-completeness^|public-api-coverage^|dispatch-read-scope^|dataplane-consumer-scope^|direct-dispatch-scope^|metadata-query-scope^|contract-signature^|publicabi-signature^|publicabi-smoke^|adapter-sync-pascal^|adapter-sync^|runner-parity^|closeout-guard^|parity-suites^|gate-summary^|gate-summary-sample^|gate-summary-rehearsal^|gate-summary-inject^|gate-summary-rollback^|gate-summary-backups^|gate-summary-selfcheck^|release-evidence^|historical-closeout-note-check^|active-closeout-truth-check^|perf-smoke^|nonx86-optin-list-suites^|nonx86-ieee754^|backend-bench^|qemu-nonx86-evidence^|qemu-cpuinfo-nonx86-evidence^|qemu-cpuinfo-nonx86-full-evidence^|qemu-cpuinfo-nonx86-full-repeat^|qemu-cpuinfo-retry-rehearsal^|qemu-cpuinfo-nonx86-suite-repeat^|qemu-arch-matrix-evidence^|qemu-nonx86-experimental-asm^|riscvv-opcode-lane^|qemu-experimental-report^|qemu-experimental-baseline-check^|coverage^|wiring-sync^|experimental-intrinsics^|experimental-intrinsics-tests^|evidence-linux^|native-evidence^|native-evidence-via-gh^|native-evidence-via-gh-clean^|verify-nonx86-native-evidence^|riscvv-runner-registration^|riscvv-runner-host-preflight^|riscvv-runner-3cmd^|restore-nightly-evidence^|evidence-win^|win-evidence-preflight^|win-evidence-via-gh^|verify-win-evidence^|evidence-win-verify^|finalize-win-evidence^|win-closeout-dryrun^|win-closeout-snippets^|win-closeout-3cmd^|freeze-status^|freeze-status-linux^|win-closeout-finalize^|freeze-status-rehearsal] [test-args...]
echo   Experimental note: default entry chain isolates experimental intrinsics behind dedicated checks.
echo   gate/gate-strict PASS is not blanket release-grade approval for every experimental path.
echo   gate         Fast/base gate for routine SIMD changes
echo   gate-strict  Release/closeout gate with perf, repeats, and evidence checks
echo   closeout-release  Canonical release closeout entry ^(delegates to shell runner^)
echo   cpuinfo-lazy-repeat  Repeat CPUInfo lazy-path verification under release mode
echo   sse2-structure-check  Structural guard for SSE2 register/include layout
echo   sse2-contracts  Focused SSE2 moved-surface contract suite
echo   impl-smoke-sse2  Targeted SSE2 structure + contract/backend/runtime/dataplane smoke
echo   impl-smoke-x86  Lightweight bounded x86 implementation smoke via DispatchAPI frontier proofs
echo   impl-smoke-nonx86  Lightweight daily non-x86 implementation smoke
echo   impl-audit-nonx86  Aggregate implementation-side non-x86 audit
echo   helper-semantics  Run the non-x86 helper semantics Python audit only
echo   riscvv-sensitive-hold-set  Fail-close the remaining RISCVV no-asm sensitive hold set
echo   key-slot-audit  Audit key non-x86 wide slots against backend-owned/base-scalar expectations
echo   implementation-matrix-sync  Fail-close active implementation-matrix drift
echo   riscvv-abi-shape  Run the RISCVV ABI-shape Python audit only
echo   source-reachability  Run the SIMD source reachability Python audit only
echo   interface-completeness  Check public facade/dispatch/backend implementation completeness
echo   public-api-coverage  Check public facade/api test-source coverage ^(default strict-thin^)
echo   dispatch-read-scope  Fail-close GetDispatchTable direct-read scope drift
echo   dataplane-consumer-scope  Fail-close dataplane consumer scope drift
echo   direct-dispatch-scope  Fail-close GetDirectDispatchTable scope drift
echo   metadata-query-scope  Fail-close metadata helper scope drift
echo   contract-signature  Check dispatch contract signature drift
echo   publicabi-signature  Check public ABI signature drift
echo   publicabi-smoke  Run the standalone public ABI smoke
echo   adapter-sync-pascal  Build/run the backend adapter Pascal smoke
echo   adapter-sync  Audit backend adapter spec/generated sync
echo   runner-parity  Fast shell/batch runner parity selfcheck ^(delegates to shell runner^)
echo   closeout-guard  Run the Windows closeout/doc/runbook guard bundle ^(delegates to shell runner^)
echo   parity-suites  Run focused DispatchAPI + DirectDispatch parity suites
echo   coverage  Check SIMD intrinsics direct-test coverage
echo   wiring-sync  Audit non-x86 wiring consistency
echo   experimental-intrinsics  Check experimental intrinsics isolation
echo   experimental-intrinsics-tests  Run the experimental intrinsics test suite
echo   closeout-host-local  Host-local strict closeout ^(non-x86 native evidence fail-close, windows evidence optional^)
echo   import-nonx86-native-evidence  Import external arm64/riscv64 native evidence into fixtures/ and verify it
echo   closeout-host-local-from-import  Import external arm64/riscv64 native evidence, verify it, then run host-local strict closeout
echo   gate-summary  Print the canonical gate summary table
echo   gate-summary-sample  Generate a sample gate summary fixture
echo   gate-summary-rehearsal  Rehearse gate-summary threshold shaping
echo   gate-summary-inject  Inject a sample gate summary into canonical logs
echo   gate-summary-rollback  Restore the previous gate summary backup
echo   gate-summary-backups  List available gate-summary backups
echo   gate-summary-selfcheck  Rehearse gate-summary/freeze-status selfcheck ^(delegates to shell runner^)
echo   release-evidence  Aggregate existing gate/freeze/native evidence into release_evidence.json ^(delegates to shell runner^)
echo   historical-closeout-note-check  Fail-close when historical closeout/freeze plans lose Current HEAD guidance ^(delegates to shell runner^)
echo   active-closeout-truth-check  Fail-close when active closeout docs drift from current HEAD truth ^(delegates to shell runner^)
echo   perf-smoke  Run the lightweight backend benchmark smoke
echo   nonx86-optin-list-suites  List suites with NEON/RISCVV backends compiled in
echo   nonx86-ieee754  Run the non-x86 IEEE754 parity suite
echo   backend-bench  Run the backend benchmark harness ^(delegates to shell runner^)
echo   qemu-nonx86-evidence  Collect non-x86 runtime evidence via QEMU ^(delegates to shell runner^)
echo   qemu-cpuinfo-nonx86-evidence  Collect non-x86 CPUInfo cross evidence via QEMU ^(delegates to shell runner^)
echo   qemu-cpuinfo-nonx86-full-evidence  Run the full non-x86 CPUInfo evidence sweep via QEMU ^(delegates to shell runner^)
echo   qemu-cpuinfo-nonx86-full-repeat  Repeat the full non-x86 CPUInfo evidence sweep via QEMU ^(delegates to shell runner^)
echo   qemu-cpuinfo-retry-rehearsal  Rehearse CPUInfo QEMU retry diagnostics via fail-once injection ^(delegates to shell runner^)
echo   qemu-cpuinfo-nonx86-suite-repeat  Repeat the non-x86 CPUInfo suite matrix via QEMU ^(delegates to shell runner^)
echo   qemu-arch-matrix-evidence  Collect architecture-matrix evidence via QEMU ^(delegates to shell runner^)
echo   qemu-nonx86-experimental-asm  Run experimental non-x86 asm sweeps via QEMU ^(delegates to shell runner^)
echo   riscvv-opcode-lane  Probe RISCVV opcode-lane contract ^(delegates to shell runner^)
echo   qemu-experimental-report  Report latest QEMU experimental blockers ^(delegates to shell runner^)
echo   qemu-experimental-baseline-check  Check latest QEMU experimental baseline ^(delegates to shell runner^)
echo   evidence-linux  Collect Linux-side release evidence ^(delegates to shell runner^)
echo   native-evidence  Collect non-x86 native evidence ^(delegates to shell runner^)
echo   native-evidence-via-gh  Dispatch/download non-x86 native evidence via GitHub Actions ^(delegates to shell runner^)
echo   native-evidence-via-gh-clean  Reuse a temporary clean worktree for GitHub native-evidence dispatch ^(delegates to shell runner^)
echo   verify-nonx86-native-evidence  Verify imported non-x86 native evidence ^(delegates to shell runner^)
echo   riscvv-runner-registration  Prepare repo-side RISCVV runner registration guidance ^(delegates to shell runner^)
echo   riscvv-runner-host-preflight  Fail-close preflight for a real riscv64 runner host ^(delegates to shell runner^)
echo   riscvv-runner-3cmd  Print the recommended RISCVV native-evidence bootstrap flow ^(delegates to shell runner^)
echo   restore-nightly-evidence  Restore nightly evidence into canonical logs ^(delegates to shell runner^)
echo   evidence-win  Windows-only native evidence capture alias
echo   win-evidence-preflight  Check whether GitHub-hosted Windows evidence can run now ^(delegates to shell runner^)
echo   win-evidence-via-gh  Dispatch GitHub-hosted Windows evidence collection ^(delegates to shell runner^)
echo   verify-win-evidence  Verify Windows evidence log against the batch verifier
echo   evidence-win-verify  Windows-only alias for verify-win-evidence
echo   finalize-win-evidence  Low-level finalize helper for split Windows evidence flows
echo   win-closeout-dryrun  Print Windows closeout dry-run guidance ^(delegates to shell runner^)
echo   win-closeout-snippets  Print Windows closeout copyable snippets ^(delegates to shell runner^)
echo   win-closeout-3cmd  Print the recommended Windows closeout command chain
echo   freeze-status  Evaluate current release freeze readiness ^(delegates to shell runner^)
echo   freeze-status-linux  Evaluate freeze readiness using Linux-side evidence only ^(delegates to shell runner^)
echo   freeze-status-rehearsal  Rehearse freeze-status failure shaping ^(delegates to shell runner^)
echo   win-closeout-finalize  Verify native evidence, backfill cross gate, then finalize
echo Suggested flow: check -^> targeted suites -^> gate; use gate-strict before release/closeout.
echo QEMU env: SIMD_QEMU_BUILD_POLICY=always^|if-missing^|skip ^(default: if-missing^)
echo Isolation env: SIMD_OUTPUT_ROOT=C:\temp\simd-run-123 ^(override bin2/lib2/logs root^)
echo Build env: SIMD_ENABLE_NEON_BACKEND=1 ^(compile NEON backend into the test binary for opt-in verification/fallback coverage^)
echo Build env: SIMD_ENABLE_RISCVV_BACKEND=1 ^(compile RISCV-V backend into the test binary for opt-in verification/fallback coverage^)
echo Build env: SIMD_ENABLE_AVX512_BACKEND=1 ^(compile AVX-512 backend into the test binary for opt-in verification^)
exit /b 2

:helper_semantics
call :nonx86_helper_semantics_check
exit /b %ERRORLEVEL%

:riscvv_sensitive_hold_set
set "RISCVV_SENSITIVE_HOLD_SET_SCRIPT=%ROOT%check_riscvv_sensitive_hold_set.py"
if not exist "%RISCVV_SENSITIVE_HOLD_SET_SCRIPT%" (
  echo [RISCVV-HOLD] Missing checker: %RISCVV_SENSITIVE_HOLD_SET_SCRIPT%
  exit /b 2
)
if "%SIMD_RISCVV_SENSITIVE_HOLD_SET_JSON_FILE%"=="" set "SIMD_RISCVV_SENSITIVE_HOLD_SET_JSON_FILE=%LOG_DIR%\riscvv_sensitive_hold_set.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [RISCVV-HOLD] Running: py -3 %RISCVV_SENSITIVE_HOLD_SET_SCRIPT% --summary-line --json-file "%SIMD_RISCVV_SENSITIVE_HOLD_SET_JSON_FILE%"
  py -3 "%RISCVV_SENSITIVE_HOLD_SET_SCRIPT%" --summary-line --json-file "%SIMD_RISCVV_SENSITIVE_HOLD_SET_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [RISCVV-HOLD] Running: python %RISCVV_SENSITIVE_HOLD_SET_SCRIPT% --summary-line --json-file "%SIMD_RISCVV_SENSITIVE_HOLD_SET_JSON_FILE%"
  python "%RISCVV_SENSITIVE_HOLD_SET_SCRIPT%" --summary-line --json-file "%SIMD_RISCVV_SENSITIVE_HOLD_SET_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [RISCVV-HOLD] FAILED (python runtime not found; tried py and python)
exit /b 2

:debug_action
set "MODE=Debug"
goto :test

:release_action
goto :release

:riscvv_abi_shape
call :riscvv_abi_shape_check
exit /b %ERRORLEVEL%

:source_reachability
call :source_reachability_check
exit /b %ERRORLEVEL%

:runner_parity
where bash >nul 2>nul
if errorlevel 1 (
  echo [RUNNER-PARITY] FAILED ^(bash runtime not found; runner-parity requires bash to preserve shell parity^)
  exit /b 2
)

echo [RUNNER-PARITY] Running: bash %ROOT%BuildOrTest.sh runner-parity %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" runner-parity %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:closeout_guard
where bash >nul 2>nul
if errorlevel 1 (
  echo [CLOSEOUT-GUARD] FAILED ^(bash runtime not found; closeout-guard requires bash to preserve shell parity^)
  exit /b 2
)

echo [CLOSEOUT-GUARD] Running: bash %ROOT%BuildOrTest.sh closeout-guard %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" closeout-guard %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_cpuinfo_retry_rehearsal
where bash >nul 2>nul
if errorlevel 1 (
  echo [RETRY-REHEARSAL] FAILED ^(bash runtime not found; qemu-cpuinfo-retry-rehearsal requires bash to preserve shell parity^)
  exit /b 2
)

echo [RETRY-REHEARSAL] Running: bash %ROOT%BuildOrTest.sh qemu-cpuinfo-retry-rehearsal %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" qemu-cpuinfo-retry-rehearsal %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:verify_win_evidence
set "VERIFY_SCRIPT=%ROOT%verify_windows_b07_evidence.bat"
set "VERIFY_ARGS=%NORMALIZED_TEST_ARGS%"
if not exist "%VERIFY_SCRIPT%" (
  echo [EVIDENCE] Missing verifier: %VERIFY_SCRIPT%
  exit /b 2
)
if "%VERIFY_ARGS%"=="" (
  call "%VERIFY_SCRIPT%" "%ROOT%logs\windows_b07_gate.log"
) else (
  call "%VERIFY_SCRIPT%" %VERIFY_ARGS%
)
exit /b %ERRORLEVEL%

:evidence_win_verify
set "EVIDENCE_SCRIPT=%ROOT%collect_windows_b07_evidence.bat"
set "VERIFY_SCRIPT=%ROOT%verify_windows_b07_evidence.bat"
set "VERIFY_ARGS=%NORMALIZED_TEST_ARGS%"
if not exist "%EVIDENCE_SCRIPT%" (
  echo [EVIDENCE] Missing collector: %EVIDENCE_SCRIPT%
  exit /b 2
)
if not exist "%VERIFY_SCRIPT%" (
  echo [EVIDENCE] Missing verifier: %VERIFY_SCRIPT%
  exit /b 2
)
call "%EVIDENCE_SCRIPT%"
if errorlevel 1 exit /b 1
if "%VERIFY_ARGS%"=="" (
  call "%VERIFY_SCRIPT%" "%ROOT%logs\windows_b07_gate.log"
) else (
  call "%VERIFY_SCRIPT%" %VERIFY_ARGS%
)
exit /b %ERRORLEVEL%

:gate_summary_selfcheck
where bash >nul 2>nul
if errorlevel 1 (
  echo [GATE-SUMMARY-SELFCHECK] FAILED ^(bash runtime not found; gate-summary-selfcheck requires bash to preserve shell parity^)
  exit /b 2
)

echo [GATE-SUMMARY-SELFCHECK] Running: bash %ROOT%BuildOrTest.sh gate-summary-selfcheck %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" gate-summary-selfcheck %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:release_evidence
where bash >nul 2>nul
if errorlevel 1 (
  echo [RELEASE-EVIDENCE] FAILED ^(bash runtime not found; release-evidence requires bash to preserve shell parity^)
  exit /b 2
)

echo [RELEASE-EVIDENCE] Running: bash %ROOT%BuildOrTest.sh release-evidence %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" release-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:historical_closeout_note_check
where bash >nul 2>nul
if errorlevel 1 (
  echo [HISTORICAL-CLOSEOUT-NOTE-CHECK] FAILED ^(bash runtime not found; historical-closeout-note-check requires bash to preserve shell parity^)
  exit /b 2
)

echo [HISTORICAL-CLOSEOUT-NOTE-CHECK] Running: bash %ROOT%BuildOrTest.sh historical-closeout-note-check %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" historical-closeout-note-check %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:active_closeout_truth_check
where bash >nul 2>nul
if errorlevel 1 (
  echo [ACTIVE-CLOSEOUT-TRUTH-CHECK] FAILED ^(bash runtime not found; active-closeout-truth-check requires bash to preserve shell parity^)
  exit /b 2
)

echo [ACTIVE-CLOSEOUT-TRUTH-CHECK] Running: bash %ROOT%BuildOrTest.sh active-closeout-truth-check %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" active-closeout-truth-check %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:evidence_linux
where bash >nul 2>nul
if errorlevel 1 (
  echo [EVIDENCE-LINUX] FAILED ^(bash runtime not found; evidence-linux requires bash to preserve shell parity^)
  exit /b 2
)

echo [EVIDENCE-LINUX] Running: bash %ROOT%BuildOrTest.sh evidence-linux %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" evidence-linux %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:native_evidence
where bash >nul 2>nul
if errorlevel 1 (
  echo [NATIVE-EVIDENCE] FAILED ^(bash runtime not found; native-evidence requires bash to preserve shell parity^)
  exit /b 2
)

echo [NATIVE-EVIDENCE] Running: bash %ROOT%BuildOrTest.sh native-evidence %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" native-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:native_evidence_via_gh
where bash >nul 2>nul
if errorlevel 1 (
  echo [NATIVE-EVIDENCE-GH] FAILED ^(bash runtime not found; native-evidence-via-gh requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)

echo [NATIVE-EVIDENCE-GH] Running: bash %ROOT%BuildOrTest.sh native-evidence-via-gh %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" native-evidence-via-gh %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:native_evidence_via_gh_clean
where bash >nul 2>nul
if errorlevel 1 (
  echo [NATIVE-EVIDENCE-GH-CLEAN] FAILED ^(bash runtime not found; native-evidence-via-gh-clean requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)

echo [NATIVE-EVIDENCE-GH-CLEAN] Running: bash %ROOT%BuildOrTest.sh native-evidence-via-gh-clean %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" native-evidence-via-gh-clean %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:verify_nonx86_native_evidence
where bash >nul 2>nul
if errorlevel 1 (
  echo [VERIFY-NONX86-NATIVE-EVIDENCE] FAILED ^(bash runtime not found; verify-nonx86-native-evidence requires bash to preserve shell parity^)
  exit /b 2
)

echo [VERIFY-NONX86-NATIVE-EVIDENCE] Running: bash %ROOT%BuildOrTest.sh verify-nonx86-native-evidence %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" verify-nonx86-native-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:riscvv_runner_registration
where bash >nul 2>nul
if errorlevel 1 (
  echo [RISCVV-RUNNER] FAILED ^(bash runtime not found; riscvv-runner-registration requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)

echo [RISCVV-RUNNER] Running: bash %ROOT%BuildOrTest.sh riscvv-runner-registration %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" riscvv-runner-registration %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:riscvv_runner_host_preflight
where bash >nul 2>nul
if errorlevel 1 (
  echo [RISCVV-RUNNER] FAILED ^(bash runtime not found; riscvv-runner-host-preflight requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)

echo [RISCVV-RUNNER] Running: bash %ROOT%BuildOrTest.sh riscvv-runner-host-preflight %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" riscvv-runner-host-preflight %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:riscvv_runner_3cmd
where bash >nul 2>nul
if errorlevel 1 (
  echo [RISCVV-RUNNER] FAILED ^(bash runtime not found; riscvv-runner-3cmd requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)

echo [RISCVV-RUNNER] Running: bash %ROOT%BuildOrTest.sh riscvv-runner-3cmd %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" riscvv-runner-3cmd %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:restore_nightly_evidence
where bash >nul 2>nul
if errorlevel 1 (
  echo [RESTORE-NIGHTLY-EVIDENCE] FAILED ^(bash runtime not found; restore-nightly-evidence requires bash to preserve shell parity^)
  exit /b 2
)

echo [RESTORE-NIGHTLY-EVIDENCE] Running: bash %ROOT%BuildOrTest.sh restore-nightly-evidence %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" restore-nightly-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:win_evidence_via_gh
where bash >nul 2>nul
if errorlevel 1 (
  echo [WIN-EVIDENCE-VIA-GH] FAILED ^(bash runtime not found; win-evidence-via-gh requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)

echo [WIN-EVIDENCE-VIA-GH] Running: bash %ROOT%BuildOrTest.sh win-evidence-via-gh %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" win-evidence-via-gh %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:win_closeout_dryrun
where bash >nul 2>nul
if errorlevel 1 (
  echo [WIN-CLOSEOUT-DRYRUN] FAILED ^(bash runtime not found; win-closeout-dryrun requires bash to preserve shell parity^)
  exit /b 2
)

echo [WIN-CLOSEOUT-DRYRUN] Running: bash %ROOT%BuildOrTest.sh win-closeout-dryrun %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" win-closeout-dryrun %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:win_closeout_snippets
where bash >nul 2>nul
if errorlevel 1 (
  echo [WIN-CLOSEOUT-SNIPPETS] FAILED ^(bash runtime not found; win-closeout-snippets requires bash to preserve shell parity^)
  exit /b 2
)

echo [WIN-CLOSEOUT-SNIPPETS] Running: bash %ROOT%BuildOrTest.sh win-closeout-snippets %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" win-closeout-snippets %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:freeze_status
where bash >nul 2>nul
if errorlevel 1 (
  echo [FREEZE-STATUS] FAILED ^(bash runtime not found; freeze-status requires bash to preserve shell parity^)
  exit /b 2
)

echo [FREEZE-STATUS] Running: bash %ROOT%BuildOrTest.sh freeze-status %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" freeze-status %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:freeze_status_linux
where bash >nul 2>nul
if errorlevel 1 (
  echo [FREEZE-STATUS-LINUX] FAILED ^(bash runtime not found; freeze-status-linux requires bash to preserve shell parity^)
  exit /b 2
)

echo [FREEZE-STATUS-LINUX] Running: bash %ROOT%BuildOrTest.sh freeze-status-linux %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" freeze-status-linux %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:freeze_status_rehearsal
where bash >nul 2>nul
if errorlevel 1 (
  echo [FREEZE-STATUS-REHEARSAL] FAILED ^(bash runtime not found; freeze-status-rehearsal requires bash to preserve shell parity^)
  exit /b 2
)

echo [FREEZE-STATUS-REHEARSAL] Running: bash %ROOT%BuildOrTest.sh freeze-status-rehearsal %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" freeze-status-rehearsal %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:clean
echo [CLEAN] Removing %BIN_DIR%, %LIB_DIR%, %LOG_DIR%
if exist "%BIN_DIR%" rmdir /s /q "%BIN_DIR%"
if exist "%LIB_DIR%" rmdir /s /q "%LIB_DIR%"
if exist "%LOG_DIR%" rmdir /s /q "%LOG_DIR%"
if exist "%OUTPUT_ROOT%\nonx86.optin" rmdir /s /q "%OUTPUT_ROOT%\nonx86.optin"
if exist "%OUTPUT_ROOT%\dispatch.preinit.smoke" rmdir /s /q "%OUTPUT_ROOT%\dispatch.preinit.smoke"
if exist "%OUTPUT_ROOT%\public.smoke" rmdir /s /q "%OUTPUT_ROOT%\public.smoke"
if exist "%OUTPUT_ROOT%\backend.ops" rmdir /s /q "%OUTPUT_ROOT%\backend.ops"
if exist "%OUTPUT_ROOT%\simd.boundary" rmdir /s /q "%OUTPUT_ROOT%\simd.boundary"
if /I not "%OUTPUT_ROOT%"=="%ROOT%" (
  echo [CLEAN] Removing isolated child outputs under %OUTPUT_ROOT%
  if exist "%OUTPUT_ROOT%\bin" rmdir /s /q "%OUTPUT_ROOT%\bin"
  if exist "%OUTPUT_ROOT%\lib" rmdir /s /q "%OUTPUT_ROOT%\lib"
  if exist "%OUTPUT_ROOT%\cpuinfo" rmdir /s /q "%OUTPUT_ROOT%\cpuinfo"
  if exist "%OUTPUT_ROOT%\cpuinfo.x86" rmdir /s /q "%OUTPUT_ROOT%\cpuinfo.x86"
  if exist "%OUTPUT_ROOT%\intrinsics.experimental" rmdir /s /q "%OUTPUT_ROOT%\intrinsics.experimental"
  if exist "%OUTPUT_ROOT%\publicabi" rmdir /s /q "%OUTPUT_ROOT%\publicabi"
  if exist "%OUTPUT_ROOT%\run_all" rmdir /s /q "%OUTPUT_ROOT%\run_all"
)
exit /b 0

:build
echo [BUILD] Project: %PROJ% (mode=%MODE%, output_root=%OUTPUT_ROOT%)
echo. > "%BUILD_LOG%"
>> "%BUILD_LOG%" echo [BUILD] ROOT=%ROOT%
>> "%BUILD_LOG%" echo [BUILD] LAZBUILD=%LAZBUILD_EXE%
>> "%BUILD_LOG%" echo [BUILD] BIN=%BIN%
>> "%BUILD_LOG%" echo [BUILD] UNIT_DIR=%UNIT_DIR%
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
if not exist "%UNIT_DIR%" mkdir "%UNIT_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LAZBUILD_IS_PATH=0"
if not "%LAZBUILD_EXE:\=%"=="%LAZBUILD_EXE%" set "LAZBUILD_IS_PATH=1"
if not "%LAZBUILD_EXE:/=%"=="%LAZBUILD_EXE%" set "LAZBUILD_IS_PATH=1"
if not "%LAZBUILD_EXE::=%"=="%LAZBUILD_EXE%" set "LAZBUILD_IS_PATH=1"
if "%LAZBUILD_IS_PATH%"=="1" (
  if not exist "%LAZBUILD_EXE%" (
    >> "%BUILD_LOG%" echo [BUILD] TOOLCHAIN BLOCK: configured LAZBUILD path does not exist: %LAZBUILD_EXE%
    >> "%BUILD_LOG%" echo [BUILD] Hint: install native Windows lazbuild.exe or set LAZBUILD to a valid Windows .exe/.bat/.cmd wrapper
    echo [BUILD] FAILED ^(see %BUILD_LOG%^ )
    type "%BUILD_LOG%"
    exit /b 1
  )
)
set "LAZBUILD_EXTRA_OPTS="
if /I "%SIMD_SUPPRESS_BUILD_WARNINGS%"=="1" set "LAZBUILD_EXTRA_OPTS=--opt=-vw- --opt=-vh- --opt=-vn-"
if /I "%SIMD_ENABLE_NEON_BACKEND%"=="1" set "LAZBUILD_EXTRA_OPTS=%LAZBUILD_EXTRA_OPTS% --opt=-dFAFAFA_SIMD_TEST_REGISTER_NEON_BACKEND"
if /I "%SIMD_ENABLE_RISCVV_BACKEND%"=="1" set "LAZBUILD_EXTRA_OPTS=%LAZBUILD_EXTRA_OPTS% --opt=-dFAFAFA_SIMD_TEST_REGISTER_RISCVV_BACKEND"
if /I "%SIMD_ENABLE_AVX512_BACKEND%"=="1" set "LAZBUILD_EXTRA_OPTS=%LAZBUILD_EXTRA_OPTS% --opt=-dSIMD_BACKEND_AVX512"
if /I "%SIMD_ENABLE_LINEINFO%"=="1" set "LAZBUILD_EXTRA_OPTS=%LAZBUILD_EXTRA_OPTS% --opt=-gl"
set "LAZBUILD_EXT=%LAZBUILD_EXE:~-4%"
>> "%BUILD_LOG%" echo [BUILD] LAZBUILD_EXT=%LAZBUILD_EXT%
>> "%BUILD_LOG%" echo [BUILD] Invoking lazbuild...
if /I "%LAZBUILD_EXT%"==".bat" (
  if exist "%LAZBUILD_EXE%" (
    call "%LAZBUILD_EXE%" --build-mode=%MODE% --build-all "--opt=-FE%BIN_DIR%" "--opt=-FU%UNIT_DIR%" %LAZBUILD_EXTRA_OPTS% "%PROJ%" >> "%BUILD_LOG%" 2>&1
  ) else (
    call %LAZBUILD_EXE% --build-mode=%MODE% --build-all "--opt=-FE%BIN_DIR%" "--opt=-FU%UNIT_DIR%" %LAZBUILD_EXTRA_OPTS% "%PROJ%" >> "%BUILD_LOG%" 2>&1
  )
) else if /I "%LAZBUILD_EXT%"==".cmd" (
  if exist "%LAZBUILD_EXE%" (
    call "%LAZBUILD_EXE%" --build-mode=%MODE% --build-all "--opt=-FE%BIN_DIR%" "--opt=-FU%UNIT_DIR%" %LAZBUILD_EXTRA_OPTS% "%PROJ%" >> "%BUILD_LOG%" 2>&1
  ) else (
    call %LAZBUILD_EXE% --build-mode=%MODE% --build-all "--opt=-FE%BIN_DIR%" "--opt=-FU%UNIT_DIR%" %LAZBUILD_EXTRA_OPTS% "%PROJ%" >> "%BUILD_LOG%" 2>&1
  )
) else if exist "%LAZBUILD_EXE%" (
  "%LAZBUILD_EXE%" --build-mode=%MODE% --build-all "--opt=-FE%BIN_DIR%" "--opt=-FU%UNIT_DIR%" %LAZBUILD_EXTRA_OPTS% "%PROJ%" >> "%BUILD_LOG%" 2>&1
) else (
  %LAZBUILD_EXE% --build-mode=%MODE% --build-all "--opt=-FE%BIN_DIR%" "--opt=-FU%UNIT_DIR%" %LAZBUILD_EXTRA_OPTS% "%PROJ%" >> "%BUILD_LOG%" 2>&1
)
set "BUILD_RC=%ERRORLEVEL%"
if /I "%SIMD_SUPPRESS_BUILD_WARNINGS%"=="1" (
  if exist "%BIN%" (
    echo [BUILD] OK
    exit /b 0
  )
  findstr /c:"(1008)" "%BUILD_LOG%" >nul 2>nul
  if not errorlevel 1 (
    echo [BUILD] OK
    exit /b 0
  )
)
if not "%BUILD_RC%"=="0" (
  echo [BUILD] FAILED ^(see %BUILD_LOG%^ )
  type "%BUILD_LOG%"
  exit /b 1
)
if not exist "%BIN%" (
  echo [BUILD] FAILED ^(binary missing after build: %BIN%^)
  type "%BUILD_LOG%"
  exit /b 1
)
echo [BUILD] OK
exit /b 0

:check
set "PREV_SIMD_SUPPRESS_BUILD_WARNINGS=%SIMD_SUPPRESS_BUILD_WARNINGS%"
set "SIMD_SUPPRESS_BUILD_WARNINGS=1"
call :build
set "CHECK_BUILD_RC=%ERRORLEVEL%"
if defined PREV_SIMD_SUPPRESS_BUILD_WARNINGS (
  set "SIMD_SUPPRESS_BUILD_WARNINGS=%PREV_SIMD_SUPPRESS_BUILD_WARNINGS%"
) else (
  set "SIMD_SUPPRESS_BUILD_WARNINGS="
)
set "PREV_SIMD_SUPPRESS_BUILD_WARNINGS="
if not "%CHECK_BUILD_RC%"=="0" exit /b 1
findstr /r /c:"src\fafafa\.core\.simd\..*Warning:" /c:"src\fafafa\.core\.simd\..*Hint:" "%BUILD_LOG%" | findstr /v /c:"src\nextpas.core.simd.intrinsics.avx2.pas" >nul 2>nul
if not errorlevel 1 (
  echo [CHECK] Found warnings/hints from stable SIMD units in build log
  type "%BUILD_LOG%"
  exit /b 1
)
findstr /r /c:"src\fafafa\.core\.simd\..*Warning:" /c:"src\fafafa\.core\.simd\..*Hint:" "%BUILD_LOG%" | findstr /c:"src\nextpas.core.simd.intrinsics.avx2.pas" >nul 2>nul
if not errorlevel 1 echo [CHECK] Ignoring experimental intrinsics hints from src\nextpas.core.simd.intrinsics.avx2.pas
echo [CHECK] OK (no SIMD-unit warnings/hints on stable path)

echo [CHECK] Backend adapter sync ^(python-only^)
set "SIMD_ADAPTER_SYNC_SKIP_BUILD=1"
set "SIMD_ADAPTER_SYNC_PASCAL_SMOKE=0"
call :adapter_sync
set "ADAPTER_SYNC_RC=%ERRORLEVEL%"
set "SIMD_ADAPTER_SYNC_SKIP_BUILD="
set "SIMD_ADAPTER_SYNC_PASCAL_SMOKE="
if not "%ADAPTER_SYNC_RC%"=="0" exit /b %ADAPTER_SYNC_RC%

call :nonx86_helper_semantics_check
if errorlevel 1 exit /b 1

call :key_slot_audit_check_internal
if errorlevel 1 exit /b 1

call :riscvv_abi_shape_check
if errorlevel 1 exit /b 1

call :register_include_check
if errorlevel 1 exit /b 1

call :source_reachability_check
if errorlevel 1 exit /b 1

call :metadata_query_scope
if errorlevel 1 exit /b 1

call :dataplane_consumer_scope
if errorlevel 1 exit /b 1

call :direct_dispatch_scope
if errorlevel 1 exit /b 1

call :dispatch_read_scope
if errorlevel 1 exit /b 1

call :sse2_structure_check
if errorlevel 1 exit /b 1

call :suite_manifest_check
if errorlevel 1 exit /b 1

if /I "%SIMD_CHECK_NONX86_OPTIN%"=="0" (
  echo [CHECK] SKIP optional non-x86 opt-in suite listing ^(set SIMD_CHECK_NONX86_OPTIN=1 to enable^)
) else (
  echo [CHECK] Optional non-x86 opt-in suite listing enabled
  call "%ROOT%buildOrTest.bat" nonx86-optin-list-suites
  if errorlevel 1 exit /b 1
)

call :run_backend_ops_internal
if errorlevel 1 exit /b 1

call :run_simd_boundary_internal
if errorlevel 1 exit /b 1

call :run_public_smoke_internal
if errorlevel 1 exit /b 1

call :run_dispatch_preinit_smoke_internal
if errorlevel 1 exit /b 1

echo [CHECK] implementation-matrix-sync
call "%ROOT%buildOrTest.bat" implementation-matrix-sync
if errorlevel 1 exit /b 1

echo [CHECK] riscvv-sensitive-hold-set
call "%ROOT%buildOrTest.bat" riscvv-sensitive-hold-set
if errorlevel 1 exit /b 1

if /I not "%SIMD_CHECK_WIRING_SYNC%"=="0" (
  echo [CHECK] wiring-sync
  call "%ROOT%buildOrTest.bat" wiring-sync
  if errorlevel 1 exit /b 1
) else (
  echo [CHECK] SKIP wiring-sync ^(set SIMD_CHECK_WIRING_SYNC=0 to disable^)
)

call :register_truthfulness_check 1
if errorlevel 1 exit /b 1

if /I "%SIMD_CHECK_EXPERIMENTAL%"=="0" (
  echo [CHECK] SKIP optional experimental isolation ^(set SIMD_CHECK_EXPERIMENTAL=1 to enable^)
) else (
  echo [CHECK] Experimental intrinsics isolation
  call "%ROOT%buildOrTest.bat" experimental-intrinsics
  if errorlevel 1 exit /b 1
)

exit /b 0

:register_include_check
set "REGISTER_INCLUDE_SCRIPT=%ROOT%check_backend_register_include_consistency.py"
if not exist "%REGISTER_INCLUDE_SCRIPT%" (
  echo [REGISTER-INCLUDE] Missing checker: %REGISTER_INCLUDE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [REGISTER-INCLUDE] Running: py -3 %REGISTER_INCLUDE_SCRIPT% --summary-line
  py -3 "%REGISTER_INCLUDE_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [REGISTER-INCLUDE] Running: python %REGISTER_INCLUDE_SCRIPT% --summary-line
  python "%REGISTER_INCLUDE_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [REGISTER-INCLUDE] FAILED (python runtime not found; tried py and python)
exit /b 2

:nonx86_helper_semantics_check
set "HELPER_SEMANTICS_SCRIPT=%ROOT%check_nonx86_helper_semantics.py"
if not exist "%HELPER_SEMANTICS_SCRIPT%" (
  echo [HELPER-SEMANTICS] Missing checker: %HELPER_SEMANTICS_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [HELPER-SEMANTICS] Running: py -3 %HELPER_SEMANTICS_SCRIPT% --summary-line
  py -3 "%HELPER_SEMANTICS_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [HELPER-SEMANTICS] Running: python %HELPER_SEMANTICS_SCRIPT% --summary-line
  python "%HELPER_SEMANTICS_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [HELPER-SEMANTICS] FAILED (python runtime not found; tried py and python)
exit /b 2

:key_slot_audit_check_internal
set "KEY_SLOT_AUDIT_SCRIPT=%ROOT%check_nonx86_key_slot_audit.py"
if not exist "%KEY_SLOT_AUDIT_SCRIPT%" (
  echo [KEY-SLOT-AUDIT] Missing checker: %KEY_SLOT_AUDIT_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [KEY-SLOT-AUDIT] Running: py -3 %KEY_SLOT_AUDIT_SCRIPT% --summary-line
  py -3 "%KEY_SLOT_AUDIT_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [KEY-SLOT-AUDIT] Running: python %KEY_SLOT_AUDIT_SCRIPT% --summary-line
  python "%KEY_SLOT_AUDIT_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [KEY-SLOT-AUDIT] FAILED (python runtime not found; tried py and python)
exit /b 2

:riscvv_abi_shape_check
set "RISCVV_ABI_SHAPE_SCRIPT=%ROOT%check_riscvv_abi_shape.py"
if not exist "%RISCVV_ABI_SHAPE_SCRIPT%" (
  echo [RISCVV-ABI] Missing checker: %RISCVV_ABI_SHAPE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [RISCVV-ABI] Running: py -3 %RISCVV_ABI_SHAPE_SCRIPT% --summary-line
  py -3 "%RISCVV_ABI_SHAPE_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [RISCVV-ABI] Running: python %RISCVV_ABI_SHAPE_SCRIPT% --summary-line
  python "%RISCVV_ABI_SHAPE_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [RISCVV-ABI] FAILED (python runtime not found; tried py and python)
exit /b 2

:source_reachability_check
set "SOURCE_REACHABILITY_SCRIPT=%ROOT%check_simd_source_reachability.py"
if not exist "%SOURCE_REACHABILITY_SCRIPT%" (
  echo [SOURCE-REACHABILITY] Missing checker: %SOURCE_REACHABILITY_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [SOURCE-REACHABILITY] Running: py -3 %SOURCE_REACHABILITY_SCRIPT% --summary-line
  py -3 "%SOURCE_REACHABILITY_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [SOURCE-REACHABILITY] Running: python %SOURCE_REACHABILITY_SCRIPT% --summary-line
  python "%SOURCE_REACHABILITY_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [SOURCE-REACHABILITY] FAILED (python runtime not found; tried py and python)
exit /b 2

:sse2_structure_check
set "SSE2_STRUCTURE_SCRIPT=%ROOT%check_sse2_structure.py"
if not exist "%SSE2_STRUCTURE_SCRIPT%" (
  echo [SSE2-STRUCTURE] Missing checker: %SSE2_STRUCTURE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [SSE2-STRUCTURE] Running: py -3 %SSE2_STRUCTURE_SCRIPT% --summary-line
  py -3 "%SSE2_STRUCTURE_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [SSE2-STRUCTURE] Running: python %SSE2_STRUCTURE_SCRIPT% --summary-line
  python "%SSE2_STRUCTURE_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [SSE2-STRUCTURE] FAILED (python runtime not found; tried py and python)
exit /b 2

:sse2_contracts
call "%ROOT%buildOrTest.bat" test --suite=TTestCase_SSE2Contracts
if errorlevel 1 exit /b 1
exit /b 0

:register_truthfulness_check
set "REGISTER_TRUTH_SCRIPT=%ROOT%check_nonx86_register_truthfulness.py"
set "REGISTER_TRUTH_STRICT=%~1"
set "REGISTER_TRUTH_ARGS="
if /I "%REGISTER_TRUTH_STRICT%"=="1" set "REGISTER_TRUTH_ARGS=--strict"

if not exist "%REGISTER_TRUTH_SCRIPT%" (
  echo [REG-TRUTH] Missing checker: %REGISTER_TRUTH_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [REG-TRUTH] Running: py -3 %REGISTER_TRUTH_SCRIPT% --backend neon --summary-line %REGISTER_TRUTH_ARGS%
  py -3 "%REGISTER_TRUTH_SCRIPT%" --backend neon --summary-line %REGISTER_TRUTH_ARGS%
  if errorlevel 1 exit /b %ERRORLEVEL%
) else (
  where python >nul 2>nul
  if not errorlevel 1 (
    echo [REG-TRUTH] Running: python %REGISTER_TRUTH_SCRIPT% --backend neon --summary-line %REGISTER_TRUTH_ARGS%
    python "%REGISTER_TRUTH_SCRIPT%" --backend neon --summary-line %REGISTER_TRUTH_ARGS%
    if errorlevel 1 exit /b %ERRORLEVEL%
  ) else (
    echo [REG-TRUTH] FAILED (python runtime not found; tried py and python)
    exit /b 2
  )
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [REG-TRUTH] Running: py -3 %REGISTER_TRUTH_SCRIPT% --backend riscvv --summary-line %REGISTER_TRUTH_ARGS%
  py -3 "%REGISTER_TRUTH_SCRIPT%" --backend riscvv --summary-line %REGISTER_TRUTH_ARGS%
  if errorlevel 1 exit /b %ERRORLEVEL%
) else (
  where python >nul 2>nul
  if not errorlevel 1 (
    echo [REG-TRUTH] Running: python %REGISTER_TRUTH_SCRIPT% --backend riscvv --summary-line %REGISTER_TRUTH_ARGS%
    python "%REGISTER_TRUTH_SCRIPT%" --backend riscvv --summary-line %REGISTER_TRUTH_ARGS%
    if errorlevel 1 exit /b %ERRORLEVEL%
  ) else (
    echo [REG-TRUTH] FAILED (python runtime not found; tried py and python)
    exit /b 2
  )
)
exit /b 0

:suite_manifest_check
set "SUITE_MANIFEST_SCRIPT=%ROOT%check_suite_manifest_sync.py"
if not exist "%SUITE_MANIFEST_SCRIPT%" (
  echo [SUITE-MANIFEST] Missing checker: %SUITE_MANIFEST_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [SUITE-MANIFEST] Running: py -3 %SUITE_MANIFEST_SCRIPT% --summary-line
  py -3 "%SUITE_MANIFEST_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [SUITE-MANIFEST] Running: python %SUITE_MANIFEST_SCRIPT% --summary-line
  python "%SUITE_MANIFEST_SCRIPT%" --summary-line
  exit /b %ERRORLEVEL%
)

echo [SUITE-MANIFEST] FAILED (python runtime not found; tried py and python)
exit /b 2

:interface_completeness
set "INTERFACE_SCRIPT=%ROOT%check_interface_implementation_completeness.py"
if not exist "%INTERFACE_SCRIPT%" (
  echo [INTERFACE-CHECK] Missing checker: %INTERFACE_SCRIPT%
  exit /b 2
)
if "%SIMD_INTERFACE_COMPLETENESS_STRICT_LEVEL%"=="" set "SIMD_INTERFACE_COMPLETENESS_STRICT_LEVEL=p2"
if "%SIMD_INTERFACE_COMPLETENESS_JSON_FILE%"=="" set "SIMD_INTERFACE_COMPLETENESS_JSON_FILE=%LOG_DIR%\interface_completeness.json"
if "%SIMD_INTERFACE_COMPLETENESS_MD_FILE%"=="" set "SIMD_INTERFACE_COMPLETENESS_MD_FILE=%LOG_DIR%\interface_completeness.md"

where py >nul 2>nul
if not errorlevel 1 (
  echo [INTERFACE-CHECK] Running: py -3 %INTERFACE_SCRIPT% --strict --strict-level "%SIMD_INTERFACE_COMPLETENESS_STRICT_LEVEL%" --json-file "%SIMD_INTERFACE_COMPLETENESS_JSON_FILE%" --md-file "%SIMD_INTERFACE_COMPLETENESS_MD_FILE%"
  py -3 "%INTERFACE_SCRIPT%" --strict --strict-level "%SIMD_INTERFACE_COMPLETENESS_STRICT_LEVEL%" --json-file "%SIMD_INTERFACE_COMPLETENESS_JSON_FILE%" --md-file "%SIMD_INTERFACE_COMPLETENESS_MD_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [INTERFACE-CHECK] Running: python %INTERFACE_SCRIPT% --strict --strict-level "%SIMD_INTERFACE_COMPLETENESS_STRICT_LEVEL%" --json-file "%SIMD_INTERFACE_COMPLETENESS_JSON_FILE%" --md-file "%SIMD_INTERFACE_COMPLETENESS_MD_FILE%"
  python "%INTERFACE_SCRIPT%" --strict --strict-level "%SIMD_INTERFACE_COMPLETENESS_STRICT_LEVEL%" --json-file "%SIMD_INTERFACE_COMPLETENESS_JSON_FILE%" --md-file "%SIMD_INTERFACE_COMPLETENESS_MD_FILE%"
  exit /b %ERRORLEVEL%
)

echo [INTERFACE-CHECK] FAILED (python runtime not found; tried py and python)
exit /b 2

:public_api_coverage
set "PUBLIC_API_COVERAGE_SCRIPT=%ROOT%check_public_api_test_coverage.py"
if "%SIMD_PUBLIC_API_TEST_COVERAGE_STRICT_THIN%"=="" set "SIMD_PUBLIC_API_TEST_COVERAGE_STRICT_THIN=1"
set "PUBLIC_API_COVERAGE_ARGS=--summary-line --min-refs 2"
if not "%SIMD_PUBLIC_API_TEST_COVERAGE_MIN_REFS%"=="" set "PUBLIC_API_COVERAGE_ARGS=--summary-line --min-refs %SIMD_PUBLIC_API_TEST_COVERAGE_MIN_REFS%"
if /I "%SIMD_PUBLIC_API_TEST_COVERAGE_STRICT_THIN%"=="1" set "PUBLIC_API_COVERAGE_ARGS=%PUBLIC_API_COVERAGE_ARGS% --strict-thin"
if "%SIMD_PUBLIC_API_TEST_COVERAGE_JSON_FILE%"=="" set "SIMD_PUBLIC_API_TEST_COVERAGE_JSON_FILE=%LOG_DIR%\public_api_test_coverage.json"
if "%SIMD_PUBLIC_API_TEST_COVERAGE_MD_FILE%"=="" set "SIMD_PUBLIC_API_TEST_COVERAGE_MD_FILE=%LOG_DIR%\public_api_test_coverage.md"
if not exist "%PUBLIC_API_COVERAGE_SCRIPT%" (
  echo [PUBLIC-API-COVERAGE] Missing checker: %PUBLIC_API_COVERAGE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [PUBLIC-API-COVERAGE] Running: py -3 %PUBLIC_API_COVERAGE_SCRIPT% %PUBLIC_API_COVERAGE_ARGS% --json-file "%SIMD_PUBLIC_API_TEST_COVERAGE_JSON_FILE%" --md-file "%SIMD_PUBLIC_API_TEST_COVERAGE_MD_FILE%"
  py -3 "%PUBLIC_API_COVERAGE_SCRIPT%" %PUBLIC_API_COVERAGE_ARGS% --json-file "%SIMD_PUBLIC_API_TEST_COVERAGE_JSON_FILE%" --md-file "%SIMD_PUBLIC_API_TEST_COVERAGE_MD_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [PUBLIC-API-COVERAGE] Running: python %PUBLIC_API_COVERAGE_SCRIPT% %PUBLIC_API_COVERAGE_ARGS% --json-file "%SIMD_PUBLIC_API_TEST_COVERAGE_JSON_FILE%" --md-file "%SIMD_PUBLIC_API_TEST_COVERAGE_MD_FILE%"
  python "%PUBLIC_API_COVERAGE_SCRIPT%" %PUBLIC_API_COVERAGE_ARGS% --json-file "%SIMD_PUBLIC_API_TEST_COVERAGE_JSON_FILE%" --md-file "%SIMD_PUBLIC_API_TEST_COVERAGE_MD_FILE%"
  exit /b %ERRORLEVEL%
)

echo [PUBLIC-API-COVERAGE] FAILED (python runtime not found; tried py and python)
exit /b 2

:dispatch_read_scope
set "DISPATCH_READ_SCOPE_SCRIPT=%ROOT%check_dispatch_read_scope.py"
if not exist "%DISPATCH_READ_SCOPE_SCRIPT%" (
  echo [DISPATCH-READ-SCOPE] Missing checker: %DISPATCH_READ_SCOPE_SCRIPT%
  exit /b 2
)
if "%SIMD_DISPATCH_READ_SCOPE_JSON_FILE%"=="" set "SIMD_DISPATCH_READ_SCOPE_JSON_FILE=%LOG_DIR%\dispatch_read_scope.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [DISPATCH-READ-SCOPE] Running: py -3 %DISPATCH_READ_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_DISPATCH_READ_SCOPE_JSON_FILE%"
  py -3 "%DISPATCH_READ_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_DISPATCH_READ_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [DISPATCH-READ-SCOPE] Running: python %DISPATCH_READ_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_DISPATCH_READ_SCOPE_JSON_FILE%"
  python "%DISPATCH_READ_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_DISPATCH_READ_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [DISPATCH-READ-SCOPE] FAILED (python runtime not found; tried py and python)
exit /b 2

:dataplane_consumer_scope
set "DATAPLANE_CONSUMER_SCOPE_SCRIPT=%ROOT%check_dataplane_consumer_scope.py"
if not exist "%DATAPLANE_CONSUMER_SCOPE_SCRIPT%" (
  echo [DATAPLANE-SCOPE] Missing checker: %DATAPLANE_CONSUMER_SCOPE_SCRIPT%
  exit /b 2
)
if "%SIMD_DATAPLANE_CONSUMER_SCOPE_JSON_FILE%"=="" set "SIMD_DATAPLANE_CONSUMER_SCOPE_JSON_FILE=%LOG_DIR%\dataplane_consumer_scope.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [DATAPLANE-SCOPE] Running: py -3 %DATAPLANE_CONSUMER_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_DATAPLANE_CONSUMER_SCOPE_JSON_FILE%"
  py -3 "%DATAPLANE_CONSUMER_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_DATAPLANE_CONSUMER_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [DATAPLANE-SCOPE] Running: python %DATAPLANE_CONSUMER_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_DATAPLANE_CONSUMER_SCOPE_JSON_FILE%"
  python "%DATAPLANE_CONSUMER_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_DATAPLANE_CONSUMER_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [DATAPLANE-SCOPE] FAILED (python runtime not found; tried py and python)
exit /b 2

:direct_dispatch_scope
set "DIRECT_DISPATCH_SCOPE_SCRIPT=%ROOT%check_direct_dispatch_scope.py"
if not exist "%DIRECT_DISPATCH_SCOPE_SCRIPT%" (
  echo [DIRECT-SCOPE] Missing checker: %DIRECT_DISPATCH_SCOPE_SCRIPT%
  exit /b 2
)
if "%SIMD_DIRECT_DISPATCH_SCOPE_JSON_FILE%"=="" set "SIMD_DIRECT_DISPATCH_SCOPE_JSON_FILE=%LOG_DIR%\direct_dispatch_scope.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [DIRECT-SCOPE] Running: py -3 %DIRECT_DISPATCH_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_DIRECT_DISPATCH_SCOPE_JSON_FILE%"
  py -3 "%DIRECT_DISPATCH_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_DIRECT_DISPATCH_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [DIRECT-SCOPE] Running: python %DIRECT_DISPATCH_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_DIRECT_DISPATCH_SCOPE_JSON_FILE%"
  python "%DIRECT_DISPATCH_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_DIRECT_DISPATCH_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [DIRECT-SCOPE] FAILED (python runtime not found; tried py and python)
exit /b 2

:metadata_query_scope
set "METADATA_QUERY_SCOPE_SCRIPT=%ROOT%check_metadata_query_scope.py"
if not exist "%METADATA_QUERY_SCOPE_SCRIPT%" (
  echo [METADATA-SCOPE] Missing checker: %METADATA_QUERY_SCOPE_SCRIPT%
  exit /b 2
)
if "%SIMD_METADATA_QUERY_SCOPE_JSON_FILE%"=="" set "SIMD_METADATA_QUERY_SCOPE_JSON_FILE=%LOG_DIR%\metadata_query_scope.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [METADATA-SCOPE] Running: py -3 %METADATA_QUERY_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_METADATA_QUERY_SCOPE_JSON_FILE%"
  py -3 "%METADATA_QUERY_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_METADATA_QUERY_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [METADATA-SCOPE] Running: python %METADATA_QUERY_SCOPE_SCRIPT% --summary-line --json-file "%SIMD_METADATA_QUERY_SCOPE_JSON_FILE%"
  python "%METADATA_QUERY_SCOPE_SCRIPT%" --summary-line --json-file "%SIMD_METADATA_QUERY_SCOPE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [METADATA-SCOPE] FAILED (python runtime not found; tried py and python)
exit /b 2

:contract_signature
set "CONTRACT_SCRIPT=%ROOT%check_dispatch_contract_signature.py"
if not exist "%CONTRACT_SCRIPT%" (
  echo [DISPATCH-CONTRACT] Missing checker: %CONTRACT_SCRIPT%
  exit /b 2
)
if "%SIMD_DISPATCH_CONTRACT_JSON_FILE%"=="" set "SIMD_DISPATCH_CONTRACT_JSON_FILE=%LOG_DIR%\dispatch_contract_signature.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [DISPATCH-CONTRACT] Running: py -3 %CONTRACT_SCRIPT% --summary-line --json-file "%SIMD_DISPATCH_CONTRACT_JSON_FILE%"
  py -3 "%CONTRACT_SCRIPT%" --summary-line --json-file "%SIMD_DISPATCH_CONTRACT_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [DISPATCH-CONTRACT] Running: python %CONTRACT_SCRIPT% --summary-line --json-file "%SIMD_DISPATCH_CONTRACT_JSON_FILE%"
  python "%CONTRACT_SCRIPT%" --summary-line --json-file "%SIMD_DISPATCH_CONTRACT_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [DISPATCH-CONTRACT] FAILED (python runtime not found; tried py and python)
exit /b 2

:publicabi_signature
set "PUBLIC_ABI_SCRIPT=%ROOT%check_public_abi_signature.py"
if not exist "%PUBLIC_ABI_SCRIPT%" (
  echo [PUBLIC-ABI] Missing checker: %PUBLIC_ABI_SCRIPT%
  exit /b 2
)
if "%SIMD_PUBLIC_ABI_JSON_FILE%"=="" set "SIMD_PUBLIC_ABI_JSON_FILE=%LOG_DIR%\public_abi_signature.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [PUBLIC-ABI] Running: py -3 %PUBLIC_ABI_SCRIPT% --summary-line --json-file "%SIMD_PUBLIC_ABI_JSON_FILE%"
  py -3 "%PUBLIC_ABI_SCRIPT%" --summary-line --json-file "%SIMD_PUBLIC_ABI_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [PUBLIC-ABI] Running: python %PUBLIC_ABI_SCRIPT% --summary-line --json-file "%SIMD_PUBLIC_ABI_JSON_FILE%"
  python "%PUBLIC_ABI_SCRIPT%" --summary-line --json-file "%SIMD_PUBLIC_ABI_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [PUBLIC-ABI] FAILED (python runtime not found; tried py and python)
exit /b 2

:publicabi_smoke
set "PUBLICABI_RUNNER=%ROOT%..\nextpas.core.simd.publicabi\BuildOrTest.bat"
if not exist "%PUBLICABI_RUNNER%" (
  echo [PUBLICABI] Missing runner: %PUBLICABI_RUNNER%
  exit /b 2
)
if "%TESTS_ROOT%"=="" set "TESTS_ROOT=%ROOT%.."
set "PUBLICABI_OUTPUT_ROOT="
if /I "%OUTPUT_ROOT%"=="%ROOT%" (
  set "PUBLICABI_OUTPUT_ROOT=%TESTS_ROOT%\nextpas.core.simd.publicabi"
) else (
  set "PUBLICABI_OUTPUT_ROOT=%OUTPUT_ROOT%\publicabi"
)
set "PREV_SIMD_OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
set "SIMD_OUTPUT_ROOT=%PUBLICABI_OUTPUT_ROOT%"
call "%PUBLICABI_RUNNER%" test
set "PUBLICABI_RC=%ERRORLEVEL%"
set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
set "PREV_SIMD_OUTPUT_ROOT="
set "PUBLICABI_OUTPUT_ROOT="
exit /b %PUBLICABI_RC%

:adapter_sync_pascal
echo [ADAPTER-SYNC-PASCAL] suite=TTestCase_DispatchAPI
call "%ROOT%buildOrTest.bat" test --suite=TTestCase_DispatchAPI
if errorlevel 1 exit /b 1
exit /b 0

:adapter_sync
if /I "%SIMD_ADAPTER_SYNC_SKIP_BUILD%"=="1" (
  echo [ADAPTER-SYNC] SKIP build ^(SIMD_ADAPTER_SYNC_SKIP_BUILD=1^)
) else (
  call :build
  if errorlevel 1 exit /b 1
)

if /I "%SIMD_ADAPTER_SYNC_PASCAL_SMOKE%"=="0" (
  echo [ADAPTER-SYNC] SKIP Pascal smoke ^(SIMD_ADAPTER_SYNC_PASCAL_SMOKE=0^)
) else (
  call :adapter_sync_pascal
  if errorlevel 1 exit /b 1
)

set "ADAPTER_SYNC_SCRIPT=%ROOT%check_backend_adapter_sync.py"
if not exist "%ADAPTER_SYNC_SCRIPT%" (
  echo [ADAPTER-SYNC] Missing checker: %ADAPTER_SYNC_SCRIPT%
  exit /b 2
)

set "ADAPTER_SYNC_NO_STRICT="
if /I "%SIMD_ADAPTER_SYNC_STRICT%"=="0" set "ADAPTER_SYNC_NO_STRICT=--no-strict"

where py >nul 2>nul
if not errorlevel 1 (
  echo [ADAPTER-SYNC] Running: py -3 %ADAPTER_SYNC_SCRIPT% --summary-line %ADAPTER_SYNC_NO_STRICT%
  echo [ADAPTER-SYNC] Checker now also verifies CSV spec ^<-> generated include drift, dispatch slot existence, and FillBaseDispatchTable coverage.
  py -3 "%ADAPTER_SYNC_SCRIPT%" --summary-line %ADAPTER_SYNC_NO_STRICT%
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [ADAPTER-SYNC] Running: python %ADAPTER_SYNC_SCRIPT% --summary-line %ADAPTER_SYNC_NO_STRICT%
  echo [ADAPTER-SYNC] Checker now also verifies CSV spec ^<-> generated include drift, dispatch slot existence, and FillBaseDispatchTable coverage.
  python "%ADAPTER_SYNC_SCRIPT%" --summary-line %ADAPTER_SYNC_NO_STRICT%
  exit /b %ERRORLEVEL%
)

echo [ADAPTER-SYNC] FAILED (python runtime not found; tried py and python)
exit /b 2

:parity_suites
call "%ROOT%buildOrTest.bat" test --suite=TTestCase_DispatchAPI
if errorlevel 1 exit /b 1
call "%ROOT%buildOrTest.bat" test --suite=TTestCase_DirectDispatch
if errorlevel 1 exit /b 1
call "%ROOT%buildOrTest.bat" test --suite=TTestCase_DirectDispatchConcurrent
if errorlevel 1 exit /b 1
echo [PARITY] OK
exit /b 0

:coverage
set "COVERAGE_SCRIPT=%ROOT%check_intrinsics_coverage.py"
set "COVERAGE_ARGS="
if "%SIMD_COVERAGE_JSON_FILE%"=="" set "SIMD_COVERAGE_JSON_FILE=%LOG_DIR%\intrinsics_coverage.json"
if /I "%SIMD_COVERAGE_STRICT_EXTRA%"=="1" set "COVERAGE_ARGS=%COVERAGE_ARGS% --strict-extra"
if /I "%SIMD_COVERAGE_REQUIRE_AVX2%"=="1" set "COVERAGE_ARGS=%COVERAGE_ARGS% --require-avx2"
if /I "%SIMD_COVERAGE_REQUIRE_EXPERIMENTAL%"=="1" set "COVERAGE_ARGS=%COVERAGE_ARGS% --require-experimental"
if not exist "%COVERAGE_SCRIPT%" (
  echo [COVERAGE] Missing checker: %COVERAGE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [COVERAGE] Running: py -3 %COVERAGE_SCRIPT% %COVERAGE_ARGS% --summary-line --json-file "%SIMD_COVERAGE_JSON_FILE%"
  py -3 "%COVERAGE_SCRIPT%" %COVERAGE_ARGS% --summary-line --json-file "%SIMD_COVERAGE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [COVERAGE] Running: python %COVERAGE_SCRIPT% %COVERAGE_ARGS% --summary-line --json-file "%SIMD_COVERAGE_JSON_FILE%"
  python "%COVERAGE_SCRIPT%" %COVERAGE_ARGS% --summary-line --json-file "%SIMD_COVERAGE_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [COVERAGE] FAILED (python runtime not found; tried py and python)
exit /b 2


:experimental_intrinsics
set "EXPERIMENTAL_SCRIPT=%ROOT%check_intrinsics_experimental_status.py"
if not exist "%EXPERIMENTAL_SCRIPT%" (
  echo [EXPERIMENTAL] Missing checker: %EXPERIMENTAL_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [EXPERIMENTAL] Running: py -3 %EXPERIMENTAL_SCRIPT%
  py -3 "%EXPERIMENTAL_SCRIPT%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [EXPERIMENTAL] Running: python %EXPERIMENTAL_SCRIPT%
  python "%EXPERIMENTAL_SCRIPT%"
  exit /b %ERRORLEVEL%
)

echo [EXPERIMENTAL] FAILED (python runtime not found; tried py and python)
exit /b 2

:experimental_intrinsics_tests
set "EXPERIMENTAL_TESTS_RUNNER=%ROOT%..\nextpas.core.simd.intrinsics.experimental\BuildOrTest.sh"
if not exist "%EXPERIMENTAL_TESTS_RUNNER%" (
  echo [EXPERIMENTAL-TESTS] Missing runner: %EXPERIMENTAL_TESTS_RUNNER%
  exit /b 2
)
set "EXPERIMENTAL_OUTPUT_ROOT="
if /I "%OUTPUT_ROOT%"=="%ROOT%" (
  set "EXPERIMENTAL_OUTPUT_ROOT=%TESTS_ROOT%\nextpas.core.simd.intrinsics.experimental"
) else (
  set "EXPERIMENTAL_OUTPUT_ROOT=%OUTPUT_ROOT%\intrinsics.experimental"
)
where bash >nul 2>nul
if errorlevel 1 (
  echo [EXPERIMENTAL-TESTS] FAILED ^(bash runtime not found; native batch experimental runner parity is not guaranteed^)
  exit /b 2
)
set "PREV_SIMD_OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
set "SIMD_OUTPUT_ROOT=%EXPERIMENTAL_OUTPUT_ROOT%"
echo [EXPERIMENTAL-TESTS] Running: bash %EXPERIMENTAL_TESTS_RUNNER% test-all
bash "%EXPERIMENTAL_TESTS_RUNNER%" test-all
set "EXPERIMENTAL_TESTS_RC=%ERRORLEVEL%"
set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
set "PREV_SIMD_OUTPUT_ROOT="
set "EXPERIMENTAL_OUTPUT_ROOT="
exit /b %EXPERIMENTAL_TESTS_RC%


:wiring_sync
set "WIRING_SYNC_SCRIPT=%ROOT%check_nonx86_wiring_sync.py"
set "WIRING_SYNC_ARGS="
if /I "%SIMD_WIRING_SYNC_STRICT_EXTRA%"=="1" set "WIRING_SYNC_ARGS=--strict-extra"
if not exist "%WIRING_SYNC_SCRIPT%" (
  echo [WIRING-SYNC] Missing checker: %WIRING_SYNC_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [WIRING-SYNC] Running: py -3 %WIRING_SYNC_SCRIPT% %WIRING_SYNC_ARGS%
  py -3 "%WIRING_SYNC_SCRIPT%" %WIRING_SYNC_ARGS%
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [WIRING-SYNC] Running: python %WIRING_SYNC_SCRIPT% %WIRING_SYNC_ARGS%
  python "%WIRING_SYNC_SCRIPT%" %WIRING_SYNC_ARGS%
  exit /b %ERRORLEVEL%
)

echo [WIRING-SYNC] FAILED (python runtime not found; tried py and python)
exit /b 2

:check_heap_leaks
findstr /r /c:"^[1-9][0-9]* unfreed memory blocks" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [LEAK] FAILED: heaptrc reports unfreed blocks
  type "%TEST_LOG%"
  exit /b 1
)
echo [LEAK] OK
exit /b 0

:release
set "MODE=Release"
call :test
if errorlevel 1 exit /b 1
if /I "%SIMD_RELEASE_STRICT_GATE%"=="0" (
  echo [RELEASE] SKIP strict gate ^(SIMD_RELEASE_STRICT_GATE=0^)
  exit /b 0
)
echo [RELEASE] Running strict gate ^(set SIMD_RELEASE_STRICT_GATE=0 to skip^)
call "%ROOT%buildOrTest.bat" gate-strict
exit /b %ERRORLEVEL%

:test
call :build
if errorlevel 1 exit /b 1

if not exist "%BIN%" (
  echo [TEST] Missing binary: %BIN%
  exit /b 2
)

set "LIST_SUITES_MODE=0"
echo %NORMALIZED_TEST_ARGS% | findstr /l /c:"--list-suites" >nul 2>nul
if not errorlevel 1 set "LIST_SUITES_MODE=1"

echo [TEST] Running: %BIN%%NORMALIZED_TEST_ARGS%
echo. > "%TEST_LOG%"
"%BIN%" %NORMALIZED_TEST_ARGS% > "%TEST_LOG%" 2>&1
set "TEST_RC=%ERRORLEVEL%"
if /I "%SIMD_SUPPRESS_BUILD_WARNINGS%"=="1" (
  findstr /c:"Failures: 0" "%TEST_LOG%" >nul 2>nul
  if not errorlevel 1 findstr /c:"Errors: 0" "%TEST_LOG%" >nul 2>nul && set "TEST_RC=0"
)
if not "%TEST_RC%"=="0" if "%LIST_SUITES_MODE%"=="1" (
  findstr /b /c:"Available suites:" "%TEST_LOG%" >nul 2>nul
  if not errorlevel 1 (
    findstr /i /c:"Access violation" /c:"EAccessViolation" /c:"Invalid option" /c:"Unhandled exception" /c:"Some tests failed!" /c:"ERROR:" "%TEST_LOG%" >nul 2>nul
    if errorlevel 1 (
      echo [TEST] WARN: --list-suites returned rc=%TEST_RC% after printing suite manifest; treating as success
      set "TEST_RC=0"
    )
  )
)
if not "%TEST_RC%"=="0" (
  echo [TEST] FAILED ^(see %TEST_LOG%^ )
  type "%TEST_LOG%"
  exit /b 1
)
findstr /b /c:"Invalid option" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [TEST] FAILED: unsupported test argument (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 2
)
findstr /r /c:"Number of failures:[ ]*[1-9][0-9]*" /c:"Number of errors:[ ]*[1-9][0-9]*" /c:"Time:.* E:[1-9][0-9]*" /c:"Time:.* F:[1-9][0-9]*" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [TEST] FAILED: test runner reports failures/errors (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 1
)
echo [TEST] OK

call :check_heap_leaks
exit /b %ERRORLEVEL%

:test_concurrent_repeat
set "REPEAT_ROUNDS="
for /f "tokens=1" %%R in ("%NORMALIZED_TEST_ARGS%") do set "REPEAT_ROUNDS=%%R"
if "%REPEAT_ROUNDS%"=="" set "REPEAT_ROUNDS=%SIMD_CONCURRENT_REPEAT_ROUNDS%"
if "%REPEAT_ROUNDS%"=="" set "REPEAT_ROUNDS=10"

echo(%REPEAT_ROUNDS%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
  echo [REPEAT] Invalid rounds: %REPEAT_ROUNDS% ^(expect positive integer^)
  exit /b 2
)

call :build
if errorlevel 1 exit /b 1

for /L %%I in (1,1,%REPEAT_ROUNDS%) do (
  echo [REPEAT] %%I/%REPEAT_ROUNDS% suite=TTestCase_SimdConcurrent
  echo. > "%TEST_LOG%"
  "%BIN%" --suite=TTestCase_SimdConcurrent > "%TEST_LOG%" 2>&1
  if errorlevel 1 (
    echo [TEST] FAILED (see %TEST_LOG%)
    type "%TEST_LOG%"
    exit /b 1
  )
  findstr /b /c:"Invalid option" "%TEST_LOG%" >nul 2>nul
  if not errorlevel 1 (
    echo [TEST] FAILED: unsupported test argument (see %TEST_LOG%)
    type "%TEST_LOG%"
    exit /b 2
  )
  findstr /r /c:"Number of failures:[ ]*[1-9][0-9]*" /c:"Number of errors:[ ]*[1-9][0-9]*" /c:"Time:.* E:[1-9][0-9]*" /c:"Time:.* F:[1-9][0-9]*" "%TEST_LOG%" >nul 2>nul
  if not errorlevel 1 (
    echo [TEST] FAILED: test runner reports failures/errors (see %TEST_LOG%)
    type "%TEST_LOG%"
    exit /b 1
  )
  call :check_heap_leaks
  if errorlevel 1 exit /b 1
  copy /y "%TEST_LOG%" "%LOG_DIR%\repeat.TTestCase_SimdConcurrent.%%I.txt" >nul
)

echo [REPEAT] OK suite=TTestCase_SimdConcurrent rounds=%REPEAT_ROUNDS%
exit /b 0

:cpuinfo_lazy_repeat
set "TESTS_ROOT=%ROOT%.."
set "CPUINFO_RUNNER=%TESTS_ROOT%\nextpas.core.simd.cpuinfo\buildOrTest.bat"
if /I "%OUTPUT_ROOT%"=="%ROOT%" (
  set "CPUINFO_OUTPUT_ROOT=%TESTS_ROOT%\nextpas.core.simd.cpuinfo"
) else (
  set "CPUINFO_OUTPUT_ROOT=%OUTPUT_ROOT%\cpuinfo"
)
set "CPUINFO_TEST_LOG=%CPUINFO_OUTPUT_ROOT%\logs\test.txt"
set "CPUINFO_LOG_DIR=%CPUINFO_OUTPUT_ROOT%\logs"

if not exist "%CPUINFO_RUNNER%" (
  echo [CPUINFO-LAZY] Missing runner: %CPUINFO_RUNNER%
  exit /b 2
)

set "CPUINFO_REPEAT_ROUNDS="
for /f "tokens=1" %%R in ("%NORMALIZED_TEST_ARGS%") do set "CPUINFO_REPEAT_ROUNDS=%%R"
if "%CPUINFO_REPEAT_ROUNDS%"=="" set "CPUINFO_REPEAT_ROUNDS=%SIMD_CPUINFO_LAZY_REPEAT_ROUNDS%"
if "%CPUINFO_REPEAT_ROUNDS%"=="" set "CPUINFO_REPEAT_ROUNDS=5"

echo(%CPUINFO_REPEAT_ROUNDS%| findstr /r "^[1-9][0-9]*$" >nul
if errorlevel 1 (
  echo [CPUINFO-LAZY] Invalid rounds: %CPUINFO_REPEAT_ROUNDS% ^(expect positive integer^)
  exit /b 2
)

set "SIMD_OUTPUT_ROOT=%CPUINFO_OUTPUT_ROOT%"
call "%CPUINFO_RUNNER%" test --list-suites
if errorlevel 1 exit /b 1

findstr /c:"TTestCase_LazyCPUInfo" "%CPUINFO_TEST_LOG%" >nul 2>nul
if errorlevel 1 (
  echo [CPUINFO-LAZY] Missing suite TTestCase_LazyCPUInfo ^(see %CPUINFO_TEST_LOG%^)
  exit /b 2
)

for /L %%I in (1,1,%CPUINFO_REPEAT_ROUNDS%) do (
  echo [CPUINFO-LAZY] %%I/%CPUINFO_REPEAT_ROUNDS% suite=TTestCase_LazyCPUInfo
  set "SIMD_OUTPUT_ROOT=%CPUINFO_OUTPUT_ROOT%"
  call "%CPUINFO_RUNNER%" test --suite=TTestCase_LazyCPUInfo
  if errorlevel 1 exit /b 1
  copy /y "%CPUINFO_TEST_LOG%" "%CPUINFO_LOG_DIR%\repeat.TTestCase_LazyCPUInfo.%%I.txt" >nul
)

echo [CPUINFO-LAZY] OK suite=TTestCase_LazyCPUInfo rounds=%CPUINFO_REPEAT_ROUNDS%
exit /b 0

:nonx86_optin_list_suites
call :run_nonx86_optin_list_suites_for neon
if errorlevel 1 exit /b 1
call :run_nonx86_optin_list_suites_for riscvv
exit /b %ERRORLEVEL%

:run_nonx86_optin_list_suites_for
if "%~1"=="" (
  echo [NONX86-OPTIN] Missing backend selector
  exit /b 2
)
if /I "%OUTPUT_ROOT%"=="%ROOT%" (
  set "NONX86_OPTIN_OUTPUT_ROOT=%ROOT%nonx86.optin\%~1"
) else (
  set "NONX86_OPTIN_OUTPUT_ROOT=%OUTPUT_ROOT%\nonx86.optin\%~1"
)
set "PREV_SIMD_OUTPUT_ROOT=%SIMD_OUTPUT_ROOT%"
set "PREV_SIMD_ENABLE_NEON_BACKEND=%SIMD_ENABLE_NEON_BACKEND%"
set "PREV_SIMD_ENABLE_RISCVV_BACKEND=%SIMD_ENABLE_RISCVV_BACKEND%"
set "PREV_SIMD_ENABLE_LINEINFO=%SIMD_ENABLE_LINEINFO%"
set "PREV_SIMD_SUPPRESS_BUILD_WARNINGS=%SIMD_SUPPRESS_BUILD_WARNINGS%"
set "SIMD_OUTPUT_ROOT=%NONX86_OPTIN_OUTPUT_ROOT%"
if /I "%~1"=="neon" (
  set "SIMD_ENABLE_NEON_BACKEND=1"
  set "SIMD_ENABLE_RISCVV_BACKEND="
) else if /I "%~1"=="riscvv" (
  set "SIMD_ENABLE_NEON_BACKEND="
  set "SIMD_ENABLE_RISCVV_BACKEND=1"
) else (
  echo [NONX86-OPTIN] Unknown backend: %~1
  set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
  set "SIMD_ENABLE_NEON_BACKEND=%PREV_SIMD_ENABLE_NEON_BACKEND%"
  set "SIMD_ENABLE_RISCVV_BACKEND=%PREV_SIMD_ENABLE_RISCVV_BACKEND%"
  if defined PREV_SIMD_SUPPRESS_BUILD_WARNINGS (
    set "SIMD_SUPPRESS_BUILD_WARNINGS=%PREV_SIMD_SUPPRESS_BUILD_WARNINGS%"
  ) else (
    set "SIMD_SUPPRESS_BUILD_WARNINGS="
  )
  set "PREV_SIMD_SUPPRESS_BUILD_WARNINGS="
  exit /b 2
)
echo [NONX86-OPTIN] %~1: test --list-suites
set "SIMD_ENABLE_LINEINFO=1"
set "SIMD_SUPPRESS_BUILD_WARNINGS=1"
call "%ROOT%buildOrTest.bat" test --list-suites
set "NONX86_OPTIN_RC=%ERRORLEVEL%"
set "SIMD_OUTPUT_ROOT=%PREV_SIMD_OUTPUT_ROOT%"
set "SIMD_ENABLE_NEON_BACKEND=%PREV_SIMD_ENABLE_NEON_BACKEND%"
set "SIMD_ENABLE_RISCVV_BACKEND=%PREV_SIMD_ENABLE_RISCVV_BACKEND%"
if defined PREV_SIMD_ENABLE_LINEINFO (
  set "SIMD_ENABLE_LINEINFO=%PREV_SIMD_ENABLE_LINEINFO%"
) else (
  set "SIMD_ENABLE_LINEINFO="
)
if defined PREV_SIMD_SUPPRESS_BUILD_WARNINGS (
  set "SIMD_SUPPRESS_BUILD_WARNINGS=%PREV_SIMD_SUPPRESS_BUILD_WARNINGS%"
) else (
  set "SIMD_SUPPRESS_BUILD_WARNINGS="
)
set "PREV_SIMD_OUTPUT_ROOT="
set "PREV_SIMD_ENABLE_NEON_BACKEND="
set "PREV_SIMD_ENABLE_RISCVV_BACKEND="
set "PREV_SIMD_ENABLE_LINEINFO="
set "PREV_SIMD_SUPPRESS_BUILD_WARNINGS="
set "NONX86_OPTIN_OUTPUT_ROOT="
exit /b %NONX86_OPTIN_RC%

:run_dispatch_preinit_smoke_internal
if not exist "%DISPATCH_PREINIT_SMOKE_SRC%" (
  echo [DISPATCH-PREINIT] Missing smoke source: %DISPATCH_PREINIT_SMOKE_SRC%
  exit /b 2
)
set "DISPATCH_PREINIT_OUTPUT_ROOT=%OUTPUT_ROOT%\dispatch.preinit.smoke"
if /I "%OUTPUT_ROOT%"=="%ROOT%" set "DISPATCH_PREINIT_OUTPUT_ROOT=%ROOT%dispatch.preinit.smoke"
set "DISPATCH_PREINIT_BIN_DIR=%DISPATCH_PREINIT_OUTPUT_ROOT%\bin"
set "DISPATCH_PREINIT_LIB_DIR=%DISPATCH_PREINIT_OUTPUT_ROOT%\lib\%TARGET_CPU%-%TARGET_OS%"
set "DISPATCH_PREINIT_LOG_DIR=%DISPATCH_PREINIT_OUTPUT_ROOT%\logs"
set "DISPATCH_PREINIT_BUILD_LOG=%DISPATCH_PREINIT_LOG_DIR%\build.txt"
set "DISPATCH_PREINIT_TEST_LOG=%DISPATCH_PREINIT_LOG_DIR%\test.txt"
set "DISPATCH_PREINIT_BIN=%DISPATCH_PREINIT_BIN_DIR%\nextpas.core.simd.dispatch_preinit_smoke.exe"
if not exist "%DISPATCH_PREINIT_BIN_DIR%" mkdir "%DISPATCH_PREINIT_BIN_DIR%"
if not exist "%DISPATCH_PREINIT_LIB_DIR%" mkdir "%DISPATCH_PREINIT_LIB_DIR%"
if not exist "%DISPATCH_PREINIT_LOG_DIR%" mkdir "%DISPATCH_PREINIT_LOG_DIR%"
echo [DISPATCH-PREINIT] Building standalone smoke: %DISPATCH_PREINIT_SMOKE_SRC%
fpc -B -Mobjfpc -Scghi -O3 -Fi"%ROOT%..\..\src" -Fu"%ROOT%..\..\src" -Fu"%ROOT%" -FE"%DISPATCH_PREINIT_BIN_DIR%" -FU"%DISPATCH_PREINIT_LIB_DIR%" "%DISPATCH_PREINIT_SMOKE_SRC%" > "%DISPATCH_PREINIT_BUILD_LOG%" 2>&1
if errorlevel 1 (
  echo [DISPATCH-PREINIT] BUILD FAILED ^(see %DISPATCH_PREINIT_BUILD_LOG%^)
  type "%DISPATCH_PREINIT_BUILD_LOG%"
  exit /b 1
)
if not exist "%DISPATCH_PREINIT_BIN%" (
  echo [DISPATCH-PREINIT] BUILD FAILED ^(binary missing: %DISPATCH_PREINIT_BIN%^)
  type "%DISPATCH_PREINIT_BUILD_LOG%"
  exit /b 1
)
echo [DISPATCH-PREINIT] Running standalone smoke: %DISPATCH_PREINIT_BIN%
"%DISPATCH_PREINIT_BIN%" > "%DISPATCH_PREINIT_TEST_LOG%" 2>&1
if errorlevel 1 (
  echo [DISPATCH-PREINIT] FAILED ^(see %DISPATCH_PREINIT_TEST_LOG%^)
  type "%DISPATCH_PREINIT_TEST_LOG%"
  exit /b 1
)
echo [DISPATCH-PREINIT] OK
exit /b 0

:run_backend_ops_internal
if not exist "%BACKEND_OPS_SRC%" (
  echo [BACKEND-OPS] Missing source: %BACKEND_OPS_SRC%
  exit /b 2
)
set "BACKEND_OPS_OUTPUT_ROOT=%OUTPUT_ROOT%\backend.ops"
if /I "%OUTPUT_ROOT%"=="%ROOT%" set "BACKEND_OPS_OUTPUT_ROOT=%ROOT%backend.ops"
set "BACKEND_OPS_BIN_DIR=%BACKEND_OPS_OUTPUT_ROOT%\bin"
set "BACKEND_OPS_LIB_DIR=%BACKEND_OPS_OUTPUT_ROOT%\lib\%TARGET_CPU%-%TARGET_OS%"
set "BACKEND_OPS_LOG_DIR=%BACKEND_OPS_OUTPUT_ROOT%\logs"
set "BACKEND_OPS_BUILD_LOG=%BACKEND_OPS_LOG_DIR%\build.txt"
set "BACKEND_OPS_TEST_LOG=%BACKEND_OPS_LOG_DIR%\test.txt"
set "BACKEND_OPS_BIN=%BACKEND_OPS_BIN_DIR%\test_backend_ops.exe"
if not exist "%BACKEND_OPS_BIN_DIR%" mkdir "%BACKEND_OPS_BIN_DIR%"
if not exist "%BACKEND_OPS_LIB_DIR%" mkdir "%BACKEND_OPS_LIB_DIR%"
if not exist "%BACKEND_OPS_LOG_DIR%" mkdir "%BACKEND_OPS_LOG_DIR%"
echo [BACKEND-OPS] Building standalone program: %BACKEND_OPS_SRC%
fpc -B -Mobjfpc -Scghi -O3 -Fi"%ROOT%..\..\src" -Fu"%ROOT%..\..\src" -Fu"%ROOT%" -FE"%BACKEND_OPS_BIN_DIR%" -FU"%BACKEND_OPS_LIB_DIR%" "%BACKEND_OPS_SRC%" > "%BACKEND_OPS_BUILD_LOG%" 2>&1
if errorlevel 1 (
  echo [BACKEND-OPS] BUILD FAILED ^(see %BACKEND_OPS_BUILD_LOG%^)
  type "%BACKEND_OPS_BUILD_LOG%"
  exit /b 1
)
if not exist "%BACKEND_OPS_BIN%" (
  echo [BACKEND-OPS] BUILD FAILED ^(binary missing: %BACKEND_OPS_BIN%^)
  type "%BACKEND_OPS_BUILD_LOG%"
  exit /b 1
)
echo [BACKEND-OPS] Running standalone program: %BACKEND_OPS_BIN%
"%BACKEND_OPS_BIN%" > "%BACKEND_OPS_TEST_LOG%" 2>&1
if errorlevel 1 (
  echo [BACKEND-OPS] FAILED ^(see %BACKEND_OPS_TEST_LOG%^)
  type "%BACKEND_OPS_TEST_LOG%"
  exit /b 1
)
type "%BACKEND_OPS_TEST_LOG%"
exit /b 0

:run_simd_boundary_internal
if not exist "%SIMD_BOUNDARY_SRC%" (
  echo [SIMD-BOUNDARY] Missing source: %SIMD_BOUNDARY_SRC%
  exit /b 2
)
set "SIMD_BOUNDARY_OUTPUT_ROOT=%OUTPUT_ROOT%\simd.boundary"
if /I "%OUTPUT_ROOT%"=="%ROOT%" set "SIMD_BOUNDARY_OUTPUT_ROOT=%ROOT%simd.boundary"
set "SIMD_BOUNDARY_BIN_DIR=%SIMD_BOUNDARY_OUTPUT_ROOT%\bin"
set "SIMD_BOUNDARY_LIB_DIR=%SIMD_BOUNDARY_OUTPUT_ROOT%\lib\%TARGET_CPU%-%TARGET_OS%"
set "SIMD_BOUNDARY_LOG_DIR=%SIMD_BOUNDARY_OUTPUT_ROOT%\logs"
set "SIMD_BOUNDARY_BUILD_LOG=%SIMD_BOUNDARY_LOG_DIR%\build.txt"
set "SIMD_BOUNDARY_TEST_LOG=%SIMD_BOUNDARY_LOG_DIR%\test.txt"
set "SIMD_BOUNDARY_BIN=%SIMD_BOUNDARY_BIN_DIR%\test_simd_boundary.exe"
if not exist "%SIMD_BOUNDARY_BIN_DIR%" mkdir "%SIMD_BOUNDARY_BIN_DIR%"
if not exist "%SIMD_BOUNDARY_LIB_DIR%" mkdir "%SIMD_BOUNDARY_LIB_DIR%"
if not exist "%SIMD_BOUNDARY_LOG_DIR%" mkdir "%SIMD_BOUNDARY_LOG_DIR%"
echo [SIMD-BOUNDARY] Building standalone program: %SIMD_BOUNDARY_SRC%
fpc -B -Mobjfpc -Scghi -O3 -Fi"%ROOT%..\..\src" -Fu"%ROOT%..\..\src" -Fu"%ROOT%" -FE"%SIMD_BOUNDARY_BIN_DIR%" -FU"%SIMD_BOUNDARY_LIB_DIR%" "%SIMD_BOUNDARY_SRC%" > "%SIMD_BOUNDARY_BUILD_LOG%" 2>&1
if errorlevel 1 (
  echo [SIMD-BOUNDARY] BUILD FAILED ^(see %SIMD_BOUNDARY_BUILD_LOG%^)
  type "%SIMD_BOUNDARY_BUILD_LOG%"
  exit /b 1
)
if not exist "%SIMD_BOUNDARY_BIN%" (
  echo [SIMD-BOUNDARY] BUILD FAILED ^(binary missing: %SIMD_BOUNDARY_BIN%^)
  type "%SIMD_BOUNDARY_BUILD_LOG%"
  exit /b 1
)
echo [SIMD-BOUNDARY] Running standalone program: %SIMD_BOUNDARY_BIN%
"%SIMD_BOUNDARY_BIN%" > "%SIMD_BOUNDARY_TEST_LOG%" 2>&1
if errorlevel 1 (
  echo [SIMD-BOUNDARY] FAILED ^(see %SIMD_BOUNDARY_TEST_LOG%^)
  type "%SIMD_BOUNDARY_TEST_LOG%"
  exit /b 1
)
type "%SIMD_BOUNDARY_TEST_LOG%"
exit /b 0

:run_public_smoke_internal
if not exist "%PUBLIC_SMOKE_SRC%" (
  echo [PUBLIC-SMOKE] Missing smoke source: %PUBLIC_SMOKE_SRC%
  exit /b 2
)
set "PUBLIC_SMOKE_OUTPUT_ROOT=%OUTPUT_ROOT%\public.smoke"
if /I "%OUTPUT_ROOT%"=="%ROOT%" set "PUBLIC_SMOKE_OUTPUT_ROOT=%ROOT%public.smoke"
set "PUBLIC_SMOKE_BIN_DIR=%PUBLIC_SMOKE_OUTPUT_ROOT%\bin"
set "PUBLIC_SMOKE_LIB_DIR=%PUBLIC_SMOKE_OUTPUT_ROOT%\lib\%TARGET_CPU%-%TARGET_OS%"
set "PUBLIC_SMOKE_LOG_DIR=%PUBLIC_SMOKE_OUTPUT_ROOT%\logs"
set "PUBLIC_SMOKE_BUILD_LOG=%PUBLIC_SMOKE_LOG_DIR%\build.txt"
set "PUBLIC_SMOKE_TEST_LOG=%PUBLIC_SMOKE_LOG_DIR%\test.txt"
set "PUBLIC_SMOKE_BIN=%PUBLIC_SMOKE_BIN_DIR%\nextpas.core.simd.public_smoke.exe"
if not exist "%PUBLIC_SMOKE_BIN_DIR%" mkdir "%PUBLIC_SMOKE_BIN_DIR%"
if not exist "%PUBLIC_SMOKE_LIB_DIR%" mkdir "%PUBLIC_SMOKE_LIB_DIR%"
if not exist "%PUBLIC_SMOKE_LOG_DIR%" mkdir "%PUBLIC_SMOKE_LOG_DIR%"
echo [PUBLIC-SMOKE] Building standalone smoke: %PUBLIC_SMOKE_SRC%
fpc -B -Mobjfpc -Scghi -O3 -Fi"%ROOT%..\..\src" -Fu"%ROOT%..\..\src" -Fu"%ROOT%" -FE"%PUBLIC_SMOKE_BIN_DIR%" -FU"%PUBLIC_SMOKE_LIB_DIR%" "%PUBLIC_SMOKE_SRC%" > "%PUBLIC_SMOKE_BUILD_LOG%" 2>&1
if errorlevel 1 (
  echo [PUBLIC-SMOKE] BUILD FAILED ^(see %PUBLIC_SMOKE_BUILD_LOG%^)
  type "%PUBLIC_SMOKE_BUILD_LOG%"
  exit /b 1
)
if not exist "%PUBLIC_SMOKE_BIN%" (
  echo [PUBLIC-SMOKE] BUILD FAILED ^(binary missing: %PUBLIC_SMOKE_BIN%^)
  type "%PUBLIC_SMOKE_BUILD_LOG%"
  exit /b 1
)
echo [PUBLIC-SMOKE] Running standalone smoke: %PUBLIC_SMOKE_BIN%
"%PUBLIC_SMOKE_BIN%" > "%PUBLIC_SMOKE_TEST_LOG%" 2>&1
if errorlevel 1 (
  echo [PUBLIC-SMOKE] FAILED ^(see %PUBLIC_SMOKE_TEST_LOG%^)
  type "%PUBLIC_SMOKE_TEST_LOG%"
  exit /b 1
)
type "%PUBLIC_SMOKE_TEST_LOG%"
exit /b 0

:nonx86_ieee754
call "%ROOT%buildOrTest.bat" test --list-suites
if errorlevel 1 exit /b 1
findstr /c:"TTestCase_NonX86IEEE754" "%TEST_LOG%" >nul 2>nul
if errorlevel 1 (
  echo [NONX86-IEEE754] SKIP (suite TTestCase_NonX86IEEE754 not present in this build)
  exit /b 0
)
call "%ROOT%buildOrTest.bat" test --suite=TTestCase_NonX86IEEE754
exit /b %ERRORLEVEL%

:impl_audit_nonx86
where bash >nul 2>nul
if errorlevel 1 (
  echo [IMPL-AUDIT] FAILED ^(bash runtime not found; impl-audit-nonx86 requires bash to preserve shell parity^)
  exit /b 2
)

echo [IMPL-AUDIT] Running: bash %ROOT%BuildOrTest.sh impl-audit-nonx86 %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" impl-audit-nonx86 %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:impl_smoke_x86
where bash >nul 2>nul
if errorlevel 1 (
  echo [IMPL-SMOKE-X86] FAILED ^(bash runtime not found; impl-smoke-x86 requires bash to preserve shell parity^)
  exit /b 2
)

echo [IMPL-SMOKE-X86] Running: bash %ROOT%BuildOrTest.sh impl-smoke-x86 %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" impl-smoke-x86 %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:impl_smoke_sse2
where bash >nul 2>nul
if errorlevel 1 (
  echo [IMPL-SMOKE-SSE2] FAILED ^(bash runtime not found; impl-smoke-sse2 requires bash to preserve shell parity^)
  exit /b 2
)

echo [IMPL-SMOKE-SSE2] Running: bash %ROOT%BuildOrTest.sh impl-smoke-sse2 %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" impl-smoke-sse2 %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:impl_smoke_nonx86
where bash >nul 2>nul
if errorlevel 1 (
  echo [IMPL-SMOKE] FAILED ^(bash runtime not found; impl-smoke-nonx86 requires bash to preserve shell parity^)
  exit /b 2
)

echo [IMPL-SMOKE] Running: bash %ROOT%BuildOrTest.sh impl-smoke-nonx86 %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" impl-smoke-nonx86 %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:key_slot_audit
where bash >nul 2>nul
if errorlevel 1 (
  echo [KEY-SLOT-AUDIT] FAILED ^(bash runtime not found; key-slot-audit requires bash to preserve shell parity^)
  exit /b 2
)

echo [KEY-SLOT-AUDIT] Running: bash %ROOT%BuildOrTest.sh key-slot-audit %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" key-slot-audit %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:implementation_matrix_sync
set "IMPLEMENTATION_MATRIX_SYNC_SCRIPT=%ROOT%check_implementation_matrix_sync.py"
if not exist "%IMPLEMENTATION_MATRIX_SYNC_SCRIPT%" (
  echo [IMPL-MATRIX] Missing checker: %IMPLEMENTATION_MATRIX_SYNC_SCRIPT%
  exit /b 2
)
if "%SIMD_IMPLEMENTATION_MATRIX_SYNC_JSON_FILE%"=="" set "SIMD_IMPLEMENTATION_MATRIX_SYNC_JSON_FILE=%LOG_DIR%\implementation_matrix_sync.json"

where py >nul 2>nul
if not errorlevel 1 (
  echo [IMPL-MATRIX] Running: py -3 %IMPLEMENTATION_MATRIX_SYNC_SCRIPT% --summary-line --json-file "%SIMD_IMPLEMENTATION_MATRIX_SYNC_JSON_FILE%"
  py -3 "%IMPLEMENTATION_MATRIX_SYNC_SCRIPT%" --summary-line --json-file "%SIMD_IMPLEMENTATION_MATRIX_SYNC_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [IMPL-MATRIX] Running: python %IMPLEMENTATION_MATRIX_SYNC_SCRIPT% --summary-line --json-file "%SIMD_IMPLEMENTATION_MATRIX_SYNC_JSON_FILE%"
  python "%IMPLEMENTATION_MATRIX_SYNC_SCRIPT%" --summary-line --json-file "%SIMD_IMPLEMENTATION_MATRIX_SYNC_JSON_FILE%"
  exit /b %ERRORLEVEL%
)

echo [IMPL-MATRIX] FAILED (python runtime not found; tried py and python)
exit /b 2

:closeout_host_local
where bash >nul 2>nul
if errorlevel 1 (
  echo [CLOSEOUT-HOST-LOCAL] FAILED ^(bash runtime not found; closeout-host-local requires bash to preserve shell parity^)
  exit /b 2
)

echo [CLOSEOUT-HOST-LOCAL] Running: bash %ROOT%BuildOrTest.sh closeout-host-local %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" closeout-host-local %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:import_nonx86_native_evidence
where bash >nul 2>nul
if errorlevel 1 (
  echo [IMPORT] FAILED ^(bash runtime not found; import-nonx86-native-evidence requires bash to preserve shell parity^)
  exit /b 2
)

echo [IMPORT] Running: bash %ROOT%BuildOrTest.sh import-nonx86-native-evidence %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" import-nonx86-native-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:closeout_host_local_from_import
where bash >nul 2>nul
if errorlevel 1 (
  echo [CLOSEOUT-HOST-LOCAL-FROM-IMPORT] FAILED ^(bash runtime not found; closeout-host-local-from-import requires bash to preserve shell parity^)
  exit /b 2
)

echo [CLOSEOUT-HOST-LOCAL-FROM-IMPORT] Running: bash %ROOT%BuildOrTest.sh closeout-host-local-from-import %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" closeout-host-local-from-import %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:backend_bench
set "BENCH_SCRIPT=%ROOT%run_backend_benchmarks.sh"
if not exist "%BENCH_SCRIPT%" (
  echo [BENCH] Missing benchmark script: %BENCH_SCRIPT%
  exit /b 2
)

call :require_backend_bench_bash_runtime
if errorlevel 1 exit /b 2

echo [BENCH] Running: bash %BENCH_SCRIPT%
bash "%BENCH_SCRIPT%" %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:require_backend_bench_bash_runtime
where bash >nul 2>nul
if errorlevel 1 (
  echo [BENCH] FAILED ^(bash runtime not found; backend-bench requires bash to preserve shell parity^)
  exit /b 2
)
exit /b 0

:require_qemu_bash_runtime
where bash >nul 2>nul
if errorlevel 1 (
  echo [QEMU] FAILED ^(bash runtime not found; qemu multiarch actions require bash to preserve shell parity^)
  exit /b 2
)
exit /b 0

:qemu_nonx86_evidence
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
echo [QEMU] Running: bash %QEMU_SCRIPT% nonx86-evidence %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" nonx86-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_cpuinfo_nonx86_evidence
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
echo [QEMU] Running: bash %QEMU_SCRIPT% cpuinfo-nonx86-evidence %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" cpuinfo-nonx86-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_cpuinfo_nonx86_full_evidence
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
echo [QEMU] Running: bash %QEMU_SCRIPT% cpuinfo-nonx86-full-evidence %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" cpuinfo-nonx86-full-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_cpuinfo_nonx86_full_repeat
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
echo [QEMU] Running: bash %QEMU_SCRIPT% cpuinfo-nonx86-full-repeat %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" cpuinfo-nonx86-full-repeat %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_cpuinfo_nonx86_suite_repeat
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
echo [QEMU] Running: bash %QEMU_SCRIPT% cpuinfo-nonx86-suite-repeat %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" cpuinfo-nonx86-suite-repeat %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_arch_matrix_evidence
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
echo [QEMU] Running: bash %QEMU_SCRIPT% arch-matrix-evidence %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" arch-matrix-evidence %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_nonx86_experimental_asm
set "QEMU_SCRIPT=%ROOT%docker\run_multiarch_qemu.sh"
if not exist "%QEMU_SCRIPT%" (
  echo [QEMU] Missing script: %QEMU_SCRIPT%
  exit /b 2
)

call :require_qemu_bash_runtime
if errorlevel 1 exit /b 2

set "QEMU_BUILD_POLICY=%SIMD_QEMU_BUILD_POLICY%"
if "!QEMU_BUILD_POLICY!"=="" set "QEMU_BUILD_POLICY=if-missing"
echo [QEMU] Build policy: !QEMU_BUILD_POLICY! ^(always^|if-missing^|skip^)
if "%SIMD_QEMU_EXPERIMENTAL_DEFINE%"=="" set "SIMD_QEMU_EXPERIMENTAL_DEFINE=-dFAFAFA_SIMD_EXPERIMENTAL_BACKEND_ASM"
echo [QEMU] Experimental asm env:
echo [QEMU]   SIMD_QEMU_ENABLE_BACKEND_ASM=%SIMD_QEMU_ENABLE_BACKEND_ASM%
echo [QEMU]   SIMD_QEMU_BACKEND_ASM_PROBE_MODE=%SIMD_QEMU_BACKEND_ASM_PROBE_MODE%
echo [QEMU]   SIMD_QEMU_EXPERIMENTAL_ARM64_COMPILER_DEFINE=%SIMD_QEMU_EXPERIMENTAL_ARM64_COMPILER_DEFINE%
echo [QEMU]   SIMD_QEMU_EXPERIMENTAL_RISCV64_COMPILER_DEFINE=%SIMD_QEMU_EXPERIMENTAL_RISCV64_COMPILER_DEFINE%
echo [QEMU]   SIMD_QEMU_EXPERIMENTAL_RISCV64_OPCODE_DEFINE=%SIMD_QEMU_EXPERIMENTAL_RISCV64_OPCODE_DEFINE%
echo [QEMU] Running: bash %QEMU_SCRIPT% nonx86-experimental-asm %NORMALIZED_TEST_ARGS%
bash "%QEMU_SCRIPT%" nonx86-experimental-asm %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:qemu_experimental_report
set "QEMU_EXP_REPORT_SCRIPT=%ROOT%report_qemu_experimental_blockers.py"
if not exist "%QEMU_EXP_REPORT_SCRIPT%" (
  echo [QEMU-EXPERIMENTAL-REPORT] Missing script: %QEMU_EXP_REPORT_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [QEMU-EXPERIMENTAL-REPORT] Running: py -3 %QEMU_EXP_REPORT_SCRIPT% --latest %NORMALIZED_TEST_ARGS%
  py -3 "%QEMU_EXP_REPORT_SCRIPT%" --latest %NORMALIZED_TEST_ARGS%
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [QEMU-EXPERIMENTAL-REPORT] Running: python %QEMU_EXP_REPORT_SCRIPT% --latest %NORMALIZED_TEST_ARGS%
  python "%QEMU_EXP_REPORT_SCRIPT%" --latest %NORMALIZED_TEST_ARGS%
  exit /b %ERRORLEVEL%
)

echo [QEMU-EXPERIMENTAL-REPORT] FAILED ^(python runtime not found; tried py and python^)
exit /b 2

:qemu_experimental_baseline_check
set "QEMU_EXP_BASELINE_SCRIPT=%ROOT%check_experimental_failure_baseline.py"
if not exist "%QEMU_EXP_BASELINE_SCRIPT%" (
  echo [QEMU-EXPERIMENTAL-BASELINE] Missing script: %QEMU_EXP_BASELINE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  echo [QEMU-EXPERIMENTAL-BASELINE] Running: py -3 %QEMU_EXP_BASELINE_SCRIPT% --latest %NORMALIZED_TEST_ARGS%
  py -3 "%QEMU_EXP_BASELINE_SCRIPT%" --latest %NORMALIZED_TEST_ARGS%
  exit /b %ERRORLEVEL%
)

where python >nul 2>nul
if not errorlevel 1 (
  echo [QEMU-EXPERIMENTAL-BASELINE] Running: python %QEMU_EXP_BASELINE_SCRIPT% --latest %NORMALIZED_TEST_ARGS%
  python "%QEMU_EXP_BASELINE_SCRIPT%" --latest %NORMALIZED_TEST_ARGS%
  exit /b %ERRORLEVEL%
)

echo [QEMU-EXPERIMENTAL-BASELINE] FAILED ^(python runtime not found; tried py and python^)
exit /b 2

:riscvv_opcode_lane
set "RVV_LANE_SCRIPT=%ROOT%docker\run_riscvv_opcode_lane.sh"
if not exist "%RVV_LANE_SCRIPT%" (
  echo [RVV-LANE] Missing script: %RVV_LANE_SCRIPT%
  exit /b 2
)

call :require_rvv_lane_bash_runtime
if errorlevel 1 exit /b 2

echo [RVV-LANE] Running: bash %RVV_LANE_SCRIPT% %NORMALIZED_TEST_ARGS%
bash "%RVV_LANE_SCRIPT%" %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:require_rvv_lane_bash_runtime
where bash >nul 2>nul
if errorlevel 1 (
  echo [RVV-LANE] FAILED ^(bash runtime not found; riscvv-opcode-lane requires bash to preserve shell parity^)
  exit /b 2
)
exit /b 0

:perf_smoke
call :build
if errorlevel 1 exit /b 1

if not exist "%BIN%" (
  echo [PERF] Missing binary: %BIN%
  exit /b 2
)

set "PERF_ARGS=--bench-only"
if /I not "%SIMD_PERF_VECTOR_ASM%"=="0" (
  if /I "%SIMD_PERF_VECTOR_ASM%"=="1" (
    set "PERF_ARGS=%PERF_ARGS% --vector-asm"
  ) else if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    set "PERF_ARGS=%PERF_ARGS% --vector-asm"
  )
)

echo [PERF] Running: %BIN% %PERF_ARGS%
echo. > "%TEST_LOG%"
"%BIN%" %PERF_ARGS% > "%TEST_LOG%" 2>&1
if errorlevel 1 (
  echo [PERF] FAILED (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 1
)

findstr /b /c:"Invalid option" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [PERF] FAILED: unsupported bench argument (see %TEST_LOG%)
  type "%TEST_LOG%"
  exit /b 2
)

call :check_heap_leaks
if errorlevel 1 exit /b 1

findstr /c:"=== SIMD Benchmark (" "%TEST_LOG%" >nul 2>nul
if errorlevel 1 (
  echo [PERF] FAILED: benchmark header not found in %TEST_LOG%
  type "%TEST_LOG%"
  exit /b 1
)

findstr /c:"/Scalar)" "%TEST_LOG%" >nul 2>nul
if not errorlevel 1 (
  echo [PERF] FAILED ^(active backend is Scalar; perf-smoke requires non-scalar backend evidence^)
  exit /b 1
)

set "PERF_CHECK_SCRIPT=%ROOT%check_perf_smoke_log.py"
if exist "%PERF_CHECK_SCRIPT%" (
  where py >nul 2>nul
  if not errorlevel 1 (
    py -3 "%PERF_CHECK_SCRIPT%" "%TEST_LOG%"
    exit /b %ERRORLEVEL%
  )
  where python >nul 2>nul
  if not errorlevel 1 (
    python "%PERF_CHECK_SCRIPT%" "%TEST_LOG%"
    exit /b %ERRORLEVEL%
  )
)

echo [PERF] OK
exit /b 0

:require_release_gate_prereqs
set "HAS_PYTHON=0"
where py >nul 2>nul
if not errorlevel 1 set "HAS_PYTHON=1"
where python >nul 2>nul
if not errorlevel 1 set "HAS_PYTHON=1"
if "%HAS_PYTHON%"=="0" (
  echo [GATE] Missing python runtime required by release-gate
  exit /b 2
)
where bash >nul 2>nul
if errorlevel 1 (
  echo [GATE] Missing bash required by release-gate
  exit /b 2
)
exit /b 0

:gate_strict
echo [GATE] Running gate-strict as release-gate profile
echo [GATE] Note: release-gate adds stronger evidence, but experimental paths still keep a separate maturity boundary
call :require_release_gate_prereqs
if errorlevel 1 exit /b %ERRORLEVEL%
set "SIMD_GATE_INTERFACE_COMPLETENESS=1"
set "SIMD_GATE_PUBLIC_API_COVERAGE=1"
set "SIMD_GATE_CONTRACT_SIGNATURE=1"
set "SIMD_GATE_PUBLICABI_SIGNATURE=1"
set "SIMD_GATE_PUBLICABI_SMOKE=1"
set "SIMD_GATE_ADAPTER_SYNC_PASCAL=1"
set "SIMD_GATE_ADAPTER_SYNC=1"
set "SIMD_GATE_PARITY_SUITES=1"
set "SIMD_GATE_WIRING_SYNC=1"
set "SIMD_WIRING_SYNC_STRICT_EXTRA=1"
set "SIMD_GATE_COVERAGE=1"
set "SIMD_COVERAGE_STRICT_EXTRA=1"
set "SIMD_COVERAGE_REQUIRE_AVX2=1"
set "SIMD_COVERAGE_REQUIRE_EXPERIMENTAL=1"
if "%SIMD_GATE_PERF_SMOKE%"=="" set "SIMD_GATE_PERF_SMOKE=0"
set "SIMD_GATE_EXPERIMENTAL=1"
set "SIMD_GATE_EXPERIMENTAL_TESTS=1"
set "SIMD_GATE_NONX86_IEEE754=1"
if "%SIMD_GATE_CPUINFO_LAZY_REPEAT%"=="" set "SIMD_GATE_CPUINFO_LAZY_REPEAT=3"
set "SIMD_GATE_QEMU_NONX86_EVIDENCE=0"
if "%SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE%"=="" set "SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1"
if "%SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE%"=="" set "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1"
if "%SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT%"=="" set "SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1"
if "%SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE%"=="" set "SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0"
if "%SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE%"=="" set "SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1"
if "%SIMD_QEMU_CPUINFO_REPEAT_ROUNDS%"=="" set "SIMD_QEMU_CPUINFO_REPEAT_ROUNDS=1"
if "%SIMD_GATE_CONCURRENT_REPEAT%"=="" set "SIMD_GATE_CONCURRENT_REPEAT=10"
call "%ROOT%buildOrTest.bat" gate
exit /b %ERRORLEVEL%

:closeout_release
where bash >nul 2>nul
if errorlevel 1 (
  echo [CLOSEOUT-RELEASE] FAILED ^(bash runtime not found; closeout-release requires Git Bash / WSL as the canonical entrypoint^)
  exit /b 2
)
echo [CLOSEOUT-RELEASE] Running: bash %ROOT%BuildOrTest.sh closeout-release %NORMALIZED_TEST_ARGS%
bash "%ROOT%BuildOrTest.sh" closeout-release %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:gate
set "SELF=%ROOT%buildOrTest.bat"
set "TESTS_ROOT=%ROOT%.."
if "%SIMD_GATE_INTERFACE_COMPLETENESS%"=="" set "SIMD_GATE_INTERFACE_COMPLETENESS=1"
if "%SIMD_GATE_PUBLIC_API_COVERAGE%"=="" set "SIMD_GATE_PUBLIC_API_COVERAGE=1"
if "%SIMD_GATE_CONTRACT_SIGNATURE%"=="" set "SIMD_GATE_CONTRACT_SIGNATURE=1"
if "%SIMD_GATE_PUBLICABI_SIGNATURE%"=="" set "SIMD_GATE_PUBLICABI_SIGNATURE=1"
if "%SIMD_GATE_PUBLICABI_SMOKE%"=="" set "SIMD_GATE_PUBLICABI_SMOKE=1"
if "%SIMD_GATE_ADAPTER_SYNC_PASCAL%"=="" set "SIMD_GATE_ADAPTER_SYNC_PASCAL=1"
if "%SIMD_GATE_ADAPTER_SYNC%"=="" set "SIMD_GATE_ADAPTER_SYNC=1"
if "%SIMD_GATE_PARITY_SUITES%"=="" set "SIMD_GATE_PARITY_SUITES=1"
if "%SIMD_GATE_WIRING_SYNC%"=="" set "SIMD_GATE_WIRING_SYNC=1"
if "%SIMD_GATE_COVERAGE%"=="" set "SIMD_GATE_COVERAGE=1"

if /I "%SIMD_GATE_EXPERIMENTAL_TESTS%"=="1" (
  echo [GATE] Profile: release-gate ^(release/closeout complete gate^)
) else (
  echo [GATE] Profile: fast-gate ^(routine/base gate^)
)
echo [GATE] Experimental boundary: default entry chain keeps experimental intrinsics isolated.
echo [GATE] Note: gate/gate-strict PASS does not imply every experimental path is release-grade.

echo [GATE] 1/6 Build + check SIMD module
call "%SELF%" check
if errorlevel 1 exit /b 1

if /I "%SIMD_GATE_INTERFACE_COMPLETENESS%"=="1" (
  echo [GATE] Optional interface completeness check
  call "%SELF%" interface-completeness
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional interface completeness ^(set SIMD_GATE_INTERFACE_COMPLETENESS=1 to enable^)
)

if /I "%SIMD_GATE_PUBLIC_API_COVERAGE%"=="1" (
  echo [GATE] Public API test coverage ^(default strict-thin^)
  call "%SELF%" public-api-coverage
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional public API test coverage ^(set SIMD_GATE_PUBLIC_API_COVERAGE=1 to enable^)
)

if /I "%SIMD_GATE_CONTRACT_SIGNATURE%"=="1" (
  echo [GATE] Optional dispatch contract signature
  call "%SELF%" contract-signature
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional dispatch contract signature ^(set SIMD_GATE_CONTRACT_SIGNATURE=1 to enable^)
)

if /I "%SIMD_GATE_PUBLICABI_SIGNATURE%"=="1" (
  echo [GATE] Optional public ABI signature
  call "%SELF%" publicabi-signature
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional public ABI signature ^(set SIMD_GATE_PUBLICABI_SIGNATURE=1 to enable^)
)

if /I "%SIMD_GATE_PUBLICABI_SMOKE%"=="1" (
  echo [GATE] Optional public ABI smoke
  call "%SELF%" publicabi-smoke
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional public ABI smoke ^(set SIMD_GATE_PUBLICABI_SMOKE=1 to enable^)
)

if /I "%SIMD_GATE_ADAPTER_SYNC_PASCAL%"=="1" (
  echo [GATE] Optional backend adapter sync Pascal smoke
  call "%SELF%" adapter-sync-pascal
  if errorlevel 1 exit /b 1
  set "SIMD_ADAPTER_SYNC_PASCAL_SMOKE=0"
) else (
  echo [GATE] SKIP optional backend adapter sync Pascal smoke ^(set SIMD_GATE_ADAPTER_SYNC_PASCAL=1 to enable^)
)

if /I "%SIMD_GATE_ADAPTER_SYNC%"=="1" (
  echo [GATE] Optional backend adapter sync
  call "%SELF%" adapter-sync
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional backend adapter sync ^(set SIMD_GATE_ADAPTER_SYNC=1 to enable^)
)

echo [GATE] 2/6 SIMD list suites
call "%SELF%" test --list-suites
if errorlevel 1 exit /b 1

echo [GATE] 3/6 SIMD AVX2 stable vector suites
call "%SELF%" test --suite=TTestCase_VecI32x8
if errorlevel 1 exit /b 1
call "%SELF%" test --suite=TTestCase_VecU32x8
if errorlevel 1 exit /b 1
call "%SELF%" test --suite=TTestCase_VecF64x4
if errorlevel 1 exit /b 1

if /I "%SIMD_GATE_PARITY_SUITES%"=="0" (
  echo [GATE] SKIP optional cross-backend parity suites ^(set SIMD_GATE_PARITY_SUITES=1 to enable^)
) else (
  echo [GATE] Optional cross-backend parity suites
  call "%SELF%" test --suite=TTestCase_DispatchAPI
  if errorlevel 1 exit /b 1
  call "%SELF%" test --suite=TTestCase_DirectDispatch
  if errorlevel 1 exit /b 1
  call "%SELF%" test --suite=TTestCase_DirectDispatchConcurrent
  if errorlevel 1 exit /b 1
)

if /I "%SIMD_GATE_NONX86_IEEE754%"=="0" (
  echo [GATE] SKIP optional non-x86 IEEE754 suite ^(set SIMD_GATE_NONX86_IEEE754=1 to enable^)
) else (
  echo [GATE] Optional non-x86 IEEE754 suite
  call "%SELF%" nonx86-ieee754
  if errorlevel 1 exit /b 1
)

echo [GATE] 4/6 CPUInfo portable suites
if /I "%OUTPUT_ROOT%"=="%ROOT%" (
  set "CPUINFO_OUTPUT_ROOT=%TESTS_ROOT%\nextpas.core.simd.cpuinfo"
) else (
  set "CPUINFO_OUTPUT_ROOT=%OUTPUT_ROOT%\cpuinfo"
)
set "SIMD_OUTPUT_ROOT=%CPUINFO_OUTPUT_ROOT%"
call "%TESTS_ROOT%\nextpas.core.simd.cpuinfo\buildOrTest.bat" test --list-suites
if errorlevel 1 exit /b 1
set "SIMD_OUTPUT_ROOT=%CPUINFO_OUTPUT_ROOT%"
call "%TESTS_ROOT%\nextpas.core.simd.cpuinfo\buildOrTest.bat" test --suite=TTestCase_PlatformSpecific
if errorlevel 1 exit /b 1

if /I "%SIMD_GATE_CPUINFO_LAZY_REPEAT%"=="0" (
  echo [GATE] SKIP optional cpuinfo lazy repeat ^(set SIMD_GATE_CPUINFO_LAZY_REPEAT=5 to enable^)
) else (
  echo [GATE] Optional cpuinfo lazy repeat ^(%SIMD_GATE_CPUINFO_LAZY_REPEAT% rounds^)
  call "%SELF%" cpuinfo-lazy-repeat %SIMD_GATE_CPUINFO_LAZY_REPEAT%
  if errorlevel 1 exit /b 1
)

echo [GATE] 5/6 CPUInfo x86 suites
if /I "%OUTPUT_ROOT%"=="%ROOT%" (
  set "CPUINFO_X86_OUTPUT_ROOT=%TESTS_ROOT%\nextpas.core.simd.cpuinfo.x86"
) else (
  set "CPUINFO_X86_OUTPUT_ROOT=%OUTPUT_ROOT%\cpuinfo.x86"
)
set "SIMD_OUTPUT_ROOT=%CPUINFO_X86_OUTPUT_ROOT%"
call "%TESTS_ROOT%\nextpas.core.simd.cpuinfo.x86\buildOrTest.bat" test --list-suites
if errorlevel 1 exit /b 1
set "SIMD_OUTPUT_ROOT=%CPUINFO_X86_OUTPUT_ROOT%"
call "%TESTS_ROOT%\nextpas.core.simd.cpuinfo.x86\buildOrTest.bat" test --suite=TTestCase_Global
if errorlevel 1 exit /b 1
set "SIMD_OUTPUT_ROOT=%OUTPUT_ROOT%"

echo [GATE] 6/6 Filtered run_all check chain
set "STOP_ON_FAIL=1"
set "RUN_ACTION=check"
call "%TESTS_ROOT%\run_all_tests.bat" =nextpas.core.simd =nextpas.core.simd.cpuinfo =nextpas.core.simd.cpuinfo.x86 =nextpas.core.simd.intrinsics.sse =nextpas.core.simd.intrinsics.mmx
if errorlevel 1 exit /b 1

if /I "%SIMD_GATE_CONCURRENT_REPEAT%"=="0" (
  echo [GATE] SKIP optional concurrent repeat ^(set SIMD_GATE_CONCURRENT_REPEAT=10 to enable^)
) else (
  echo [GATE] Optional concurrent repeat ^(%SIMD_GATE_CONCURRENT_REPEAT% rounds^)
  call "%SELF%" test-concurrent-repeat %SIMD_GATE_CONCURRENT_REPEAT%
  if errorlevel 1 exit /b 1
)

if /I "%SIMD_GATE_COVERAGE%"=="1" (
  echo [GATE] Optional intrinsics coverage
  call "%SELF%" coverage
  if errorlevel 1 exit /b 1
)

if /I "%SIMD_GATE_PERF_SMOKE%"=="1" (
  echo [GATE] Optional perf smoke
  call "%SELF%" perf-smoke
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional perf smoke ^(set SIMD_GATE_PERF_SMOKE=1 to enable^)
)

if /I "%SIMD_GATE_EXPERIMENTAL%"=="0" (
  echo [GATE] SKIP optional experimental isolation ^(set SIMD_GATE_EXPERIMENTAL=1 to enable^)
) else (
  echo [GATE] Optional experimental intrinsics isolation
  call "%SELF%" experimental-intrinsics
  if errorlevel 1 exit /b 1
)

if /I "%SIMD_GATE_EXPERIMENTAL_TESTS%"=="0" (
  echo [GATE] SKIP optional experimental tests ^(set SIMD_GATE_EXPERIMENTAL_TESTS=1 to enable^)
) else (
  echo [GATE] Optional experimental intrinsics tests
  call "%SELF%" experimental-intrinsics-tests
  if errorlevel 1 exit /b 1
)

if /I "%SIMD_GATE_WIRING_SYNC%"=="1" (
  echo [GATE] Optional wiring-sync enabled
  call "%SELF%" wiring-sync
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional wiring-sync ^(set SIMD_GATE_WIRING_SYNC=1 to enable^)
)

echo [GATE] Register-truthfulness
call :register_truthfulness_check 1
if errorlevel 1 exit /b 1

if /I "%SIMD_GATE_QEMU_NONX86_EVIDENCE%"=="1" (
  echo [GATE] Optional qemu non-x86 evidence
  call "%SELF%" qemu-nonx86-evidence
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional qemu non-x86 evidence ^(set SIMD_GATE_QEMU_NONX86_EVIDENCE=1 to enable^)
)

if /I "%SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE%"=="1" (
  echo [GATE] Optional qemu cpuinfo non-x86 evidence
  call "%SELF%" qemu-cpuinfo-nonx86-evidence
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional qemu cpuinfo non-x86 evidence ^(set SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 to enable^)
)

if /I "%SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE%"=="1" (
  echo [GATE] Optional qemu cpuinfo non-x86 full evidence
  call "%SELF%" qemu-cpuinfo-nonx86-full-evidence
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional qemu cpuinfo non-x86 full evidence ^(set SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 to enable^)
)

if /I "%SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT%"=="1" (
  echo [GATE] Optional qemu cpuinfo non-x86 full repeat
  call "%SELF%" qemu-cpuinfo-nonx86-full-repeat
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional qemu cpuinfo non-x86 full repeat ^(set SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 to enable^)
)

if /I "%SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE%"=="1" (
  echo [GATE] Optional qemu arch matrix evidence
  call "%SELF%" qemu-arch-matrix-evidence
  if errorlevel 1 exit /b 1
) else (
  echo [GATE] SKIP optional qemu arch matrix evidence ^(set SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=1 to enable^)
)

set "WIN_EVIDENCE_LOG=%ROOT%logs\windows_b07_gate.log"
if exist "%WIN_EVIDENCE_LOG%" (
  if /I "%SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE%"=="1" (
    echo [GATE] Evidence verify ^(required^)
    call "%SELF%" verify-win-evidence "%WIN_EVIDENCE_LOG%"
    if errorlevel 1 exit /b 1
  ) else (
    echo [GATE] Optional evidence verify ^(set SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 to enforce^)
    call "%SELF%" verify-win-evidence "%WIN_EVIDENCE_LOG%"
    if errorlevel 1 (
      echo [GATE] SKIP optional evidence verify ^(verification failed; set SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 to enforce^)
    ) else (
      echo [GATE] Optional evidence verify PASS
    )
  )
) else (
  if /I "%SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE%"=="1" (
    echo [GATE] FAIL required windows evidence log missing: %WIN_EVIDENCE_LOG%
    exit /b 1
  ) else (
    echo [GATE] SKIP evidence verify ^(windows log not present: %WIN_EVIDENCE_LOG%^)
  )
)

echo [GATE] OK
exit /b 0

:evidence_win
set "EVIDENCE_SCRIPT=%ROOT%collect_windows_b07_evidence.bat"
if not exist "%EVIDENCE_SCRIPT%" (
  echo [EVIDENCE] Missing collector: %EVIDENCE_SCRIPT%
  exit /b 2
)
call "%EVIDENCE_SCRIPT%"
exit /b %ERRORLEVEL%

:win_evidence_preflight
set "PREFLIGHT_SCRIPT=%ROOT%preflight_windows_b07_evidence_gh.sh"
if not exist "%PREFLIGHT_SCRIPT%" (
  echo [PREFLIGHT] Missing script: %PREFLIGHT_SCRIPT%
  exit /b 2
)
where bash >nul 2>nul
if errorlevel 1 (
  echo [PREFLIGHT] Missing bash ^(require Git Bash / WSL^)
  exit /b 2
)
echo [PREFLIGHT] Running: bash %PREFLIGHT_SCRIPT% %NORMALIZED_TEST_ARGS%
bash "%PREFLIGHT_SCRIPT%" %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:verify_win_evidence
set "VERIFY_SCRIPT=%ROOT%verify_windows_b07_evidence.bat"
set "VERIFY_ARGS=%NORMALIZED_TEST_ARGS%"
if not exist "%VERIFY_SCRIPT%" (
  echo [EVIDENCE] Missing verifier: %VERIFY_SCRIPT%
  exit /b 2
)
if "%VERIFY_ARGS%"=="" (
  call "%VERIFY_SCRIPT%" "%ROOT%logs\windows_b07_gate.log"
) else (
  call "%VERIFY_SCRIPT%" %VERIFY_ARGS%
)
exit /b %ERRORLEVEL%

:evidence_win_verify
set "EVIDENCE_SCRIPT=%ROOT%collect_windows_b07_evidence.bat"
set "VERIFY_SCRIPT=%ROOT%verify_windows_b07_evidence.bat"
if not exist "%EVIDENCE_SCRIPT%" (
  echo [EVIDENCE] Missing collector: %EVIDENCE_SCRIPT%
  exit /b 2
)
if not exist "%VERIFY_SCRIPT%" (
  echo [EVIDENCE] Missing verifier: %VERIFY_SCRIPT%
  exit /b 2
)
call "%EVIDENCE_SCRIPT%"
if errorlevel 1 exit /b 1
set "VERIFY_ARGS=%NORMALIZED_TEST_ARGS%"
if "%VERIFY_ARGS%"=="" (
  call "%VERIFY_SCRIPT%" "%ROOT%logs\windows_b07_gate.log"
) else (
  call "%VERIFY_SCRIPT%" %VERIFY_ARGS%
)
exit /b %ERRORLEVEL%

:finalize_win_evidence
set "FINALIZE_SCRIPT=%ROOT%finalize_windows_b07_closeout.sh"
if not exist "%FINALIZE_SCRIPT%" (
  echo [CLOSEOUT] Missing finalize script: %FINALIZE_SCRIPT%
  exit /b 2
)
where bash >nul 2>nul
if errorlevel 1 (
  echo [CLOSEOUT] Missing bash ^(require Git Bash / WSL^)
  exit /b 2
)
echo [CLOSEOUT] Running: bash %FINALIZE_SCRIPT% %NORMALIZED_TEST_ARGS%
bash "%FINALIZE_SCRIPT%" %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:win_closeout_3cmd
set "BATCH_ID="
for /f "tokens=1" %%A in ("%NORMALIZED_TEST_ARGS%") do set "BATCH_ID=%%A"
if "%BATCH_ID%"=="" set "BATCH_ID=SIMD-YYYYMMDD-152"
set "PREFLIGHT_JSON=%ROOT%logs\win_preflight_latest.json"
if exist "%PREFLIGHT_JSON%" (
  findstr /c:"\"code\": \"RECENT_BILLING_BLOCK\"" "%PREFLIGHT_JSON%" >nul 2>nul
  if not errorlevel 1 (
    echo [CLOSEOUT] WARN latest preflight is RECENT_BILLING_BLOCK
    echo.
    echo    Current local win-evidence-preflight is blocked by GitHub Billing/quota.
    echo    Restore GitHub Billing/quota or switch to a real Windows runner before step 1.
    echo.
  )
)
echo [CLOSEOUT] Windows evidence closeout: recommended command chain
echo.
echo Preferred canonical entry ^(Git Bash / WSL^):
echo    FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-release %BATCH_ID%
echo.
echo 0^) Preflight GH blockage ^(Git Bash / WSL, recommended^)
echo    bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-preflight
echo.
echo 1^) Collect and verify evidence ^(PowerShell/CMD^)
echo    Requirement: native Windows lazbuild.exe / Windows wrapper only ^(do not use Wine/cmd as a fake Windows runner^)
echo    Example override: set LAZBUILD=C:\Lazarus\lazbuild.exe
echo    tests\nextpas.core.simd\buildOrTest.bat evidence-win-verify
echo.
echo 2^) Backfill cross gate with fail-close ^(Git Bash / WSL^)
echo    SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate
echo.
echo 3^) One-shot closeout ^(Git Bash / WSL^)
echo    bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize %BATCH_ID%
echo.
echo 4^) Confirm freeze status ^(Git Bash / WSL^)
echo    bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status
echo.
echo Notes:
echo    Step 3 runs finalize ^> freeze-status ^> apply, and apply is blocked unless freeze_ready=true.
echo    If step 0 returns RECENT_BILLING_BLOCK, fix GitHub Billing/quota first.
echo    LAZBUILD for step 1 must resolve to a native Windows .exe/.bat/.cmd, not a Wine-visible Linux ELF under Z:\opt\...
echo    Current local Wine probes also did not yield a working host-side Unix bridge ^(`where bash` / `start /unix`^); do not treat them as a substitute for native Windows LAZBUILD.
exit /b 0

:win_closeout_finalize
set "RUNNER_SCRIPT=%ROOT%run_windows_b07_closeout_finalize.sh"
if not exist "%RUNNER_SCRIPT%" (
  echo [CLOSEOUT] Missing runner: %RUNNER_SCRIPT%
  exit /b 2
)
where bash >nul 2>nul
if errorlevel 1 (
  echo [CLOSEOUT] Missing bash ^(require Git Bash / WSL^)
  exit /b 2
)
call "%ROOT%buildOrTest.bat" evidence-win-verify
if errorlevel 1 exit /b 1
set "SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1"
echo [CLOSEOUT] Backfill cross gate ^(SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1^)
bash "%ROOT%BuildOrTest.sh" gate
if errorlevel 1 exit /b 1
echo [CLOSEOUT] Running: bash %RUNNER_SCRIPT% %NORMALIZED_TEST_ARGS%
bash "%RUNNER_SCRIPT%" %NORMALIZED_TEST_ARGS%
exit /b %ERRORLEVEL%

:gate_summary_sample
set "SAMPLE_SCRIPT=%ROOT%generate_gate_summary_sample.py"
set "SAMPLE_SCENARIO=%~1"
if "%SAMPLE_SCENARIO%"=="" set "SAMPLE_SCENARIO=mixed"
set "SAMPLE_OUTPUT=%~2"
if "%SAMPLE_OUTPUT%"=="" set "SAMPLE_OUTPUT=%LOG_DIR%\gate_summary.sample.%SAMPLE_SCENARIO%.md"
if "%SIMD_GATE_STEP_WARN_MS%"=="" set "SIMD_GATE_STEP_WARN_MS=20000"
if "%SIMD_GATE_STEP_FAIL_MS%"=="" set "SIMD_GATE_STEP_FAIL_MS=120000"

if not exist "%SAMPLE_SCRIPT%" (
  echo [GATE-SUMMARY-SAMPLE] Missing generator: %SAMPLE_SCRIPT%
  exit /b 2
)

where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%SAMPLE_SCRIPT%" --scenario "%SAMPLE_SCENARIO%" --warn-ms %SIMD_GATE_STEP_WARN_MS% --fail-ms %SIMD_GATE_STEP_FAIL_MS% --output "%SAMPLE_OUTPUT%"
  if errorlevel 1 exit /b 1
  echo [GATE-SUMMARY-SAMPLE] output=%SAMPLE_OUTPUT%
  exit /b 0
)

where python >nul 2>nul
if not errorlevel 1 (
  python "%SAMPLE_SCRIPT%" --scenario "%SAMPLE_SCENARIO%" --warn-ms %SIMD_GATE_STEP_WARN_MS% --fail-ms %SIMD_GATE_STEP_FAIL_MS% --output "%SAMPLE_OUTPUT%"
  if errorlevel 1 exit /b 1
  echo [GATE-SUMMARY-SAMPLE] output=%SAMPLE_OUTPUT%
  exit /b 0
)

echo [GATE-SUMMARY-SAMPLE] FAILED ^(python runtime not found; gate-summary-sample requires python^)
exit /b 2

:gate_summary_rehearsal
set "REHEARSAL_SCRIPT=%ROOT%rehearse_gate_summary_thresholds.sh"
if not exist "%REHEARSAL_SCRIPT%" (
  echo [GATE-SUMMARY-REHEARSAL] Missing script: %REHEARSAL_SCRIPT%
  exit /b 2
)

where bash >nul 2>nul
if errorlevel 1 (
  echo [GATE-SUMMARY-REHEARSAL] FAILED ^(bash runtime not found; gate-summary-rehearsal requires bash^)
  exit /b 2
)

bash "%REHEARSAL_SCRIPT%"
exit /b %ERRORLEVEL%

:gate_summary_inject
set "SAMPLE_SCRIPT=%ROOT%generate_gate_summary_sample.py"
set "SAMPLE_SCENARIO=%~1"
if "%SAMPLE_SCENARIO%"=="" set "SAMPLE_SCENARIO=mixed"
set "SUMMARY_FILE=%SIMD_GATE_SUMMARY_FILE%"
if "%SUMMARY_FILE%"=="" set "SUMMARY_FILE=%GATE_SUMMARY_LOG%"
set "SAMPLE_OUTPUT=%~2"
if "%SAMPLE_OUTPUT%"=="" set "SAMPLE_OUTPUT=%LOG_DIR%\rehearsal\injected\gate_summary.injected.%SAMPLE_SCENARIO%.md"
set "BACKUP_DIR=%LOG_DIR%\rehearsal\backups"
if "%SIMD_GATE_STEP_WARN_MS%"=="" set "SIMD_GATE_STEP_WARN_MS=20000"
if "%SIMD_GATE_STEP_FAIL_MS%"=="" set "SIMD_GATE_STEP_FAIL_MS=120000"

if not exist "%SAMPLE_SCRIPT%" (
  echo [GATE-SUMMARY-INJECT] Missing generator: %SAMPLE_SCRIPT%
  exit /b 2
)
if not exist "%LOG_DIR%\rehearsal\injected" mkdir "%LOG_DIR%\rehearsal\injected"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%SAMPLE_SCRIPT%" --scenario "%SAMPLE_SCENARIO%" --warn-ms %SIMD_GATE_STEP_WARN_MS% --fail-ms %SIMD_GATE_STEP_FAIL_MS% --output "%SAMPLE_OUTPUT%"
  if errorlevel 1 exit /b 1
  goto :gate_summary_inject_apply
)

where python >nul 2>nul
if not errorlevel 1 (
  python "%SAMPLE_SCRIPT%" --scenario "%SAMPLE_SCENARIO%" --warn-ms %SIMD_GATE_STEP_WARN_MS% --fail-ms %SIMD_GATE_STEP_FAIL_MS% --output "%SAMPLE_OUTPUT%"
  if errorlevel 1 exit /b 1
  goto :gate_summary_inject_apply
)

echo [GATE-SUMMARY-INJECT] FAILED ^(python runtime not found; gate-summary-inject requires python^)
exit /b 2

:gate_summary_inject_apply
if /I "%SIMD_GATE_SUMMARY_APPLY%"=="1" (
  set "STAMP=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
  set "STAMP=%STAMP: =0%"
  set "BACKUP_FILE=%BACKUP_DIR%\gate_summary.backup.!STAMP!.md"
  if exist "%SUMMARY_FILE%" (
    copy /y "%SUMMARY_FILE%" "!BACKUP_FILE!" >nul
    echo [GATE-SUMMARY-INJECT] backup=!BACKUP_FILE!
  )
  copy /y "%SAMPLE_OUTPUT%" "%SUMMARY_FILE%" >nul
  echo [GATE-SUMMARY-INJECT] applied target=%SUMMARY_FILE%
) else (
  echo [GATE-SUMMARY-INJECT] non-invasive mode ^(set SIMD_GATE_SUMMARY_APPLY=1 to replace target^)
)

echo [GATE-SUMMARY-INJECT] sample=%SAMPLE_OUTPUT%
exit /b 0

:gate_summary_rollback
set "SUMMARY_FILE=%SIMD_GATE_SUMMARY_FILE%"
if "%SUMMARY_FILE%"=="" set "SUMMARY_FILE=%GATE_SUMMARY_LOG%"
set "BACKUP_DIR=%LOG_DIR%\rehearsal\backups"
set "RESTORE_FILE=%SIMD_GATE_SUMMARY_BACKUP_FILE%"

if "%RESTORE_FILE%"=="" (
  for /f "delims=" %%f in ('dir /b /a-d /o-n "%BACKUP_DIR%\gate_summary.backup.*.md" 2^>nul') do (
    set "RESTORE_FILE=%BACKUP_DIR%\%%f"
    goto :gate_summary_rollback_do
  )
) else (
  goto :gate_summary_rollback_do
)

echo [GATE-SUMMARY-ROLLBACK] No backup found
exit /b 2

:gate_summary_rollback_do
if not exist "%RESTORE_FILE%" (
  echo [GATE-SUMMARY-ROLLBACK] Backup not found: %RESTORE_FILE%
  exit /b 2
)
copy /y "%RESTORE_FILE%" "%SUMMARY_FILE%" >nul
echo [GATE-SUMMARY-ROLLBACK] restored=%SUMMARY_FILE% from=%RESTORE_FILE%
exit /b 0

:gate_summary_backups
set "BACKUP_DIR=%LOG_DIR%\rehearsal\backups"
if not exist "%BACKUP_DIR%" (
  echo [GATE-SUMMARY-BACKUPS] none
  exit /b 0
)

dir /b /a-d /o-n "%BACKUP_DIR%\gate_summary.backup.*.md" >nul 2>nul
if errorlevel 1 (
  echo [GATE-SUMMARY-BACKUPS] none
  exit /b 0
)

echo [GATE-SUMMARY-BACKUPS] dir=%BACKUP_DIR%
dir /b /a-d /o-n "%BACKUP_DIR%\gate_summary.backup.*.md"
exit /b 0

:gate_summary
set "SUMMARY_FILE=%SIMD_GATE_SUMMARY_FILE%"
if "%SUMMARY_FILE%"=="" set "SUMMARY_FILE=%GATE_SUMMARY_LOG%"
if "%SIMD_GATE_STEP_WARN_MS%"=="" set "SIMD_GATE_STEP_WARN_MS=20000"
if "%SIMD_GATE_STEP_FAIL_MS%"=="" set "SIMD_GATE_STEP_FAIL_MS=120000"
set "SUMMARY_FILTER=%SIMD_GATE_SUMMARY_FILTER%"
if "%SUMMARY_FILTER%"=="" set "SUMMARY_FILTER=ALL"
if "%SIMD_GATE_SUMMARY_MAX_DETAIL%"=="" set "SIMD_GATE_SUMMARY_MAX_DETAIL=260"

if not exist "%SUMMARY_FILE%" (
  echo [GATE-SUMMARY] Missing summary file: %SUMMARY_FILE%
  exit /b 2
)

echo [GATE-SUMMARY] %SUMMARY_FILE%
echo [GATE-SUMMARY] thresholds: warn_ms=%SIMD_GATE_STEP_WARN_MS%, fail_ms=%SIMD_GATE_STEP_FAIL_MS%
echo [GATE-SUMMARY] filter=%SUMMARY_FILTER%, max_detail=%SIMD_GATE_SUMMARY_MAX_DETAIL%

if /I "%SUMMARY_FILTER%"=="ALL" (
  type "%SUMMARY_FILE%"
) else if /I "%SUMMARY_FILTER%"=="FAIL" (
  findstr /r /c:"^| Time |" /c:"^|---|" /c:"| FAIL |" "%SUMMARY_FILE%"
) else if /I "%SUMMARY_FILTER%"=="SLOW" (
  findstr /r /c:"^| Time |" /c:"^|---|" /c:"| SLOW_WARN |" /c:"| SLOW_CRIT |" /c:"| SLOW_FAIL |" "%SUMMARY_FILE%"
) else (
  echo [GATE-SUMMARY] WARN: unsupported filter=%SUMMARY_FILTER%, fallback=ALL
  set "SUMMARY_FILTER=ALL"
  type "%SUMMARY_FILE%"
)

if /I "%SIMD_GATE_SUMMARY_JSON%"=="1" (
  set "SUMMARY_JSON_FILE=%SIMD_GATE_SUMMARY_JSON_FILE%"
  if "%SUMMARY_JSON_FILE%"=="" set "SUMMARY_JSON_FILE=%GATE_SUMMARY_JSON_LOG%"
  set "EXPORT_SCRIPT=%ROOT%export_gate_summary_json.py"
  if not exist "%EXPORT_SCRIPT%" (
    echo [GATE-SUMMARY] Missing exporter: %EXPORT_SCRIPT%
    exit /b 2
  )

  where py >nul 2>nul
  if not errorlevel 1 (
    py -3 "%EXPORT_SCRIPT%" --input "%SUMMARY_FILE%" --output "%SUMMARY_JSON_FILE%" --filter "%SUMMARY_FILTER%" --warn-ms %SIMD_GATE_STEP_WARN_MS% --fail-ms %SIMD_GATE_STEP_FAIL_MS%
    if errorlevel 1 exit /b 1
    echo [GATE-SUMMARY] json=%SUMMARY_JSON_FILE%
    exit /b 0
  )

  where python >nul 2>nul
  if not errorlevel 1 (
    python "%EXPORT_SCRIPT%" --input "%SUMMARY_FILE%" --output "%SUMMARY_JSON_FILE%" --filter "%SUMMARY_FILTER%" --warn-ms %SIMD_GATE_STEP_WARN_MS% --fail-ms %SIMD_GATE_STEP_FAIL_MS%
    if errorlevel 1 exit /b 1
    echo [GATE-SUMMARY] json=%SUMMARY_JSON_FILE%
    exit /b 0
  )

  echo [GATE-SUMMARY] FAILED ^(python runtime not found; SIMD_GATE_SUMMARY_JSON=1 requires python^)
  exit /b 2
)

exit /b 0
