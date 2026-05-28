#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FREEZE_SCRIPT="${ROOT}/evaluate_simd_freeze_status.py"
VERIFY_SCRIPT="${ROOT}/verify_windows_b07_evidence.sh"

if [[ ! -f "${FREEZE_SCRIPT}" ]]; then
  echo "[FREEZE-REHEARSAL] Missing freeze script: ${FREEZE_SCRIPT}"
  exit 2
fi

if [[ ! -x "${VERIFY_SCRIPT}" ]]; then
  echo "[FREEZE-REHEARSAL] Missing verifier script: ${VERIFY_SCRIPT}"
  exit 2
fi

LTmpRoot="$(mktemp -d)"
cleanup() {
  rm -rf "${LTmpRoot}"
}
trap cleanup EXIT

LCaseNotReady="${LTmpRoot}/case_not_ready/tests/nextpas.core.simd"
LCaseReady="${LTmpRoot}/case_ready/tests/nextpas.core.simd"
LCaseReadyPreflightBlocked="${LTmpRoot}/case_ready_preflight_blocked/tests/nextpas.core.simd"
LCaseLinuxLazy="${LTmpRoot}/case_linux_lazy/tests/nextpas.core.simd"
LCaseLinuxPlatforms="${LTmpRoot}/case_linux_platforms/tests/nextpas.core.simd"
LCaseBatchFallback="${LTmpRoot}/case_batch_fallback/tests/nextpas.core.simd"
LCaseMainlineFallback="${LTmpRoot}/case_mainline_fallback/tests/nextpas.core.simd"
LCaseLatestMainline="${LTmpRoot}/case_latest_mainline/tests/nextpas.core.simd"

mkdir -p "${LCaseNotReady}/logs" "${LCaseNotReady}/docs" "${LTmpRoot}/case_not_ready/docs/plans"
mkdir -p "${LCaseReady}/logs" "${LCaseReady}/docs" "${LTmpRoot}/case_ready/docs/plans"
mkdir -p "${LCaseReadyPreflightBlocked}/logs" "${LCaseReadyPreflightBlocked}/docs" "${LTmpRoot}/case_ready_preflight_blocked/docs/plans"
mkdir -p "${LCaseLinuxLazy}/logs" "${LCaseLinuxLazy}/docs" "${LTmpRoot}/case_linux_lazy/docs/plans"
mkdir -p "${LCaseLinuxPlatforms}/logs" "${LCaseLinuxPlatforms}/docs" "${LTmpRoot}/case_linux_platforms/docs/plans"
mkdir -p "${LCaseBatchFallback}/logs/windows-closeout/SIMD-20260210-152" "${LCaseBatchFallback}/docs" "${LTmpRoot}/case_batch_fallback/docs/plans"
mkdir -p "${LCaseMainlineFallback}/logs/rehearsal/backups" "${LCaseMainlineFallback}/docs" "${LTmpRoot}/case_mainline_fallback/docs/plans"
mkdir -p "${LCaseLatestMainline}/logs/rehearsal/backups" "${LCaseLatestMainline}/docs" "${LTmpRoot}/case_latest_mainline/docs/plans" "${LTmpRoot}/case_latest_mainline/src"

cp "${FREEZE_SCRIPT}" "${LCaseNotReady}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseReady}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseReadyPreflightBlocked}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseLinuxLazy}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseLinuxPlatforms}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseBatchFallback}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseMainlineFallback}/evaluate_simd_freeze_status.py"
cp "${FREEZE_SCRIPT}" "${LCaseLatestMainline}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseNotReady}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseReady}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseReadyPreflightBlocked}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseLinuxLazy}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseLinuxPlatforms}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseBatchFallback}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseMainlineFallback}/verify_windows_b07_evidence.sh"
cp "${VERIFY_SCRIPT}" "${LCaseLatestMainline}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseNotReady}/verify_windows_b07_evidence.sh" "${LCaseReady}/verify_windows_b07_evidence.sh" "${LCaseReadyPreflightBlocked}/verify_windows_b07_evidence.sh" "${LCaseLinuxLazy}/verify_windows_b07_evidence.sh" "${LCaseLinuxPlatforms}/verify_windows_b07_evidence.sh" "${LCaseBatchFallback}/verify_windows_b07_evidence.sh" "${LCaseMainlineFallback}/verify_windows_b07_evidence.sh" "${LCaseLatestMainline}/verify_windows_b07_evidence.sh"

# ---------- Case A: NOT READY ----------
cat > "${LCaseNotReady}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseNotReady}/logs/windows_b07_gate.simulated.log" <<'EOM'
[B07] Windows evidence capture
[B07] Command: buildOrTest.bat gate
[B07] GateSummaryJson: /tmp/rehearse.windows_b07_gate.simulated.summary-json.missing
[GATE] 1/6 Build + check SIMD module
[BACKEND-OPS] Building standalone program: C:\simd\tests\nextpas.core.simd\test_backend_ops.pas
[SIMD-BOUNDARY] Building standalone program: C:\simd\tests\nextpas.core.simd\test_simd_boundary.pas
[PUBLIC-SMOKE] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.public_smoke.pas
[DISPATCH-PREINIT] OK
[GATE] Optional public ABI smoke
[GATE] 2/6 SIMD list suites
[GATE] 3/6 SIMD AVX2 stable vector suites
[GATE] 4/6 CPUInfo portable suites
[GATE] 5/6 CPUInfo x86 suites
[GATE] 6/6 Filtered run_all check chain
[GATE] OK
[B07] GATE_EXIT_CODE=0
Total:  5
Passed: 5
Failed: 0
[B07] Total: 5
[B07] Passed: 5
[B07] Failed: 0
EOM

cat > "${LCaseNotReady}/logs/windows_b07_closeout_summary.simulated.md" <<'EOM'
# simulated summary
EOM

cat > "${LTmpRoot}/case_not_ready/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [ ] **Windows 实机证据未归档**
EOM

cat > "${LCaseNotReady}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [ ] Windows 实机证据日志已归档（当前缺口）
EOM

cat > "${LCaseNotReady}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：脚本入口 + 校验入口已就绪（待 Windows 实机日志）
EOM

set +e
python3 "${LCaseNotReady}/evaluate_simd_freeze_status.py" --root "${LCaseNotReady}" --json-file "${LCaseNotReady}/logs/freeze_status.json" > "${LCaseNotReady}/logs/freeze_stdout.txt" 2>&1
LNotReadyRc=$?
set -e
if [[ "${LNotReadyRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_not_ready should return non-zero"
  cat "${LCaseNotReady}/logs/freeze_stdout.txt"
  exit 1
fi

if ! grep -F -- "ready=False" "${LCaseNotReady}/logs/freeze_stdout.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_not_ready missing ready=False"
  cat "${LCaseNotReady}/logs/freeze_stdout.txt"
  exit 1
fi

python3 - "${LCaseNotReady}/logs/freeze_status.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("ready") is not False:
    print("[FREEZE-REHEARSAL] FAILED: case_not_ready json ready should be false")
    sys.exit(1)
if payload.get("freeze_ready") is not False:
    print("[FREEZE-REHEARSAL] FAILED: case_not_ready json freeze_ready should be false")
    sys.exit(1)
if payload.get("linux_only") is not False:
    print("[FREEZE-REHEARSAL] FAILED: case_not_ready json linux_only should be false")
    sys.exit(1)
PY

# ---------- Case B: READY ----------
cat > "${LCaseReady}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Debug | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:00 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseReady}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows [Version 10.0.22631.4602]
[B07] Started: 2026/02/10 00:00:00.00
[B07] Working dir: C:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[B07] GateSummaryJson: /tmp/rehearse.windows_b07_gate.summary-json.missing
[GATE] 1/6 Build + check SIMD module
[BACKEND-OPS] Building standalone program: C:\simd\tests\nextpas.core.simd\test_backend_ops.pas
[BACKEND-OPS] Running standalone program: C:\simd\tests\nextpas.core.simd\backend.ops\bin\test_backend_ops.exe
[SIMD-BOUNDARY] Building standalone program: C:\simd\tests\nextpas.core.simd\test_simd_boundary.pas
[SIMD-BOUNDARY] Running standalone program: C:\simd\tests\nextpas.core.simd\simd.boundary\bin\test_simd_boundary.exe
[PUBLIC-SMOKE] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.public_smoke.pas
[PUBLIC-SMOKE] Running standalone smoke: C:\simd\tests\nextpas.core.simd\public.smoke\bin\nextpas.core.simd.public_smoke.exe
[PASS] Default backend is AVX2
[DISPATCH-PREINIT] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.dispatch_preinit_smoke.pas
[DISPATCH-PREINIT] Running standalone smoke: C:\simd\tests\nextpas.core.simd\dispatch.preinit.smoke\bin\nextpas.core.simd.dispatch_preinit_smoke.exe
[DISPATCH-PREINIT] OK
[GATE] Optional public ABI smoke
[GATE] 2/6 SIMD list suites
[GATE] 3/6 SIMD AVX2 stable vector suites
[GATE] 4/6 CPUInfo portable suites
[GATE] 5/6 CPUInfo x86 suites
[GATE] 6/6 Filtered run_all check chain
[GATE] OK
[B07] GATE_EXIT_CODE=0
Total:  5
Passed: 5
Failed: 0
[B07] Total: 5
[B07] Passed: 5
[B07] Failed: 0
EOM

cat > "${LCaseReady}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: PASS
EOM

cat > "${LTmpRoot}/case_ready/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseReady}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseReady}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseReady}/evaluate_simd_freeze_status.py" --root "${LCaseReady}" --json-file "${LCaseReady}/logs/freeze_status.json" > "${LCaseReady}/logs/freeze_stdout.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseReady}/logs/freeze_stdout.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ready missing ready=True"
  cat "${LCaseReady}/logs/freeze_stdout.txt"
  exit 1
fi

python3 - "${LCaseReady}/logs/freeze_status.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("ready") is not True:
    print("[FREEZE-REHEARSAL] FAILED: case_ready json ready should be true")
    sys.exit(1)
if payload.get("freeze_ready") is not True:
    print("[FREEZE-REHEARSAL] FAILED: case_ready json freeze_ready should be true")
    sys.exit(1)
if payload.get("linux_only") is not False:
    print("[FREEZE-REHEARSAL] FAILED: case_ready json linux_only should be false")
    sys.exit(1)
PY

# ---------- Case B1: READY SHOULD DEMOTE GH PREFLIGHT FAIL TO NON-READINESS SIGNAL ----------
cp "${LCaseReady}/logs/gate_summary.md" "${LCaseReadyPreflightBlocked}/logs/gate_summary.md"
cp "${LCaseReady}/logs/windows_b07_gate.log" "${LCaseReadyPreflightBlocked}/logs/windows_b07_gate.log"
cp "${LCaseReady}/logs/windows_b07_closeout_summary.md" "${LCaseReadyPreflightBlocked}/logs/windows_b07_closeout_summary.md"
cp "${LTmpRoot}/case_ready/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" "${LTmpRoot}/case_ready_preflight_blocked/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md"
cp "${LCaseReady}/docs/simd_release_candidate_checklist.md" "${LCaseReadyPreflightBlocked}/docs/simd_release_candidate_checklist.md"
cp "${LCaseReady}/docs/simd_completeness_matrix.md" "${LCaseReadyPreflightBlocked}/docs/simd_completeness_matrix.md"

cat > "${LCaseReadyPreflightBlocked}/logs/win_preflight_latest.json" <<'EOM'
{
  "status": "FAIL",
  "code": "RECENT_BILLING_BLOCK",
  "message": "workflow=simd-windows-b07-evidence.yml; run=123; message=billing blocked",
  "checked_at_utc": "2026-02-10T00:00:00Z",
  "billing_window_hours": 999999
}
EOM

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseReadyPreflightBlocked}/evaluate_simd_freeze_status.py" --root "${LCaseReadyPreflightBlocked}" --json-file "${LCaseReadyPreflightBlocked}/logs/freeze_status.json" > "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ready_preflight_blocked missing ready=True"
  cat "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt"
  exit 1
fi

if ! grep -F -- "SKIP    windows_preflight_latest" "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ready_preflight_blocked should demote preflight fail to SKIP"
  cat "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt"
  exit 1
fi

if ! grep -F -- "not a current readiness signal" "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ready_preflight_blocked should explain the demotion"
  cat "${LCaseReadyPreflightBlocked}/logs/freeze_stdout.txt"
  exit 1
fi

# ---------- Case B2: HISTORICAL DOC MARKERS SHOULD IGNORE NOTES AND ACCEPT CURRENT WORDING ----------
LCaseHistoricalDocMarkers="${LTmpRoot}/case_historical_doc_markers/tests/nextpas.core.simd"
mkdir -p "${LCaseHistoricalDocMarkers}/logs" "${LCaseHistoricalDocMarkers}/docs" "${LTmpRoot}/case_historical_doc_markers/docs/plans"
cp "${FREEZE_SCRIPT}" "${LCaseHistoricalDocMarkers}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseHistoricalDocMarkers}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseHistoricalDocMarkers}/verify_windows_b07_evidence.sh"
cp "${LCaseReady}/logs/gate_summary.md" "${LCaseHistoricalDocMarkers}/logs/gate_summary.md"
cp "${LCaseReady}/logs/windows_b07_gate.log" "${LCaseHistoricalDocMarkers}/logs/windows_b07_gate.log"
cp "${LCaseReady}/logs/windows_b07_closeout_summary.md" "${LCaseHistoricalDocMarkers}/logs/windows_b07_closeout_summary.md"

cat > "${LTmpRoot}/case_historical_doc_markers/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
说明：Windows 实机证据已归档这类表述在这里是历史归档事实，不是当前 HEAD ready 信号。
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseHistoricalDocMarkers}/docs/simd_release_candidate_checklist.md" <<'EOM'
说明：Windows 实机证据日志已归档这类短语可能先出现在解释行里，脚本不能因此漏掉真正的 checkbox。
- [x] Windows 实机证据日志曾归档（历史批次）
EOM

cat > "${LCaseHistoricalDocMarkers}/docs/simd_completeness_matrix.md" <<'EOM'
- 注意：这里的“已归档”表示历史 Windows 实机证据批次曾闭环，不等于当前 `HEAD` 仍是 `cross-ready`。
- [x] Windows 实机证据曾归档（历史批次；脚本+校验器+日志）
EOM

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseHistoricalDocMarkers}/evaluate_simd_freeze_status.py" --root "${LCaseHistoricalDocMarkers}" --json-file "${LCaseHistoricalDocMarkers}/logs/freeze_status_historical_doc_markers.json" > "${LCaseHistoricalDocMarkers}/logs/freeze_stdout_historical_doc_markers.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseHistoricalDocMarkers}/logs/freeze_stdout_historical_doc_markers.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_historical_doc_markers missing ready=True"
  cat "${LCaseHistoricalDocMarkers}/logs/freeze_stdout_historical_doc_markers.txt"
  exit 1
fi

for LPattern in \
  "PASS    roadmap_windows_closed" \
  "PASS    rc_windows_closed" \
  "PASS    matrix_windows_closed"
do
  if ! grep -F -- "${LPattern}" "${LCaseHistoricalDocMarkers}/logs/freeze_stdout_historical_doc_markers.txt" >/dev/null; then
    echo "[FREEZE-REHEARSAL] FAILED: case_historical_doc_markers missing ${LPattern}"
    cat "${LCaseHistoricalDocMarkers}/logs/freeze_stdout_historical_doc_markers.txt"
    exit 1
  fi
done

# ---------- Case C: STALE SUMMARY (must fail) ----------
cat > "${LCaseReady}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL
EOM

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseReady}/evaluate_simd_freeze_status.py" --root "${LCaseReady}" --json-file "${LCaseReady}/logs/freeze_status_stale.json" > "${LCaseReady}/logs/freeze_stdout_stale.txt" 2>&1
LStaleRc=$?
set -e

if [[ "${LStaleRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_stale_summary should return non-zero"
  cat "${LCaseReady}/logs/freeze_stdout_stale.txt"
  exit 1
fi

if ! grep -F -- "summary missing '- Result: PASS'" "${LCaseReady}/logs/freeze_stdout_stale.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_stale_summary missing expected stale reason"
  cat "${LCaseReady}/logs/freeze_stdout_stale.txt"
  exit 1
fi

# ---------- Case D: VERIFY FAIL + SUMMARY FAIL MARKER (summary check should pass) ----------
cat > "${LCaseReady}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Started: 2026/02/10 00:00:00.00
[B07] Command: buildOrTest.bat gate
[B07] GATE_EXIT_CODE=0
[B07] Total: 3
[B07] Passed: 3
[B07] Failed: 0
EOM

cat > "${LCaseReady}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseReady}/evaluate_simd_freeze_status.py" --root "${LCaseReady}" --json-file "${LCaseReady}/logs/freeze_status_verifyfail.json" > "${LCaseReady}/logs/freeze_stdout_verifyfail.txt" 2>&1
LVerifyFailRc=$?
set -e

if [[ "${LVerifyFailRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_verify_fail should return non-zero"
  cat "${LCaseReady}/logs/freeze_stdout_verifyfail.txt"
  exit 1
fi

if ! grep -F -- "windows_closeout_summary: summary matches verifier FAIL" "${LCaseReady}/logs/freeze_stdout_verifyfail.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_verify_fail summary consistency check not PASS"
  cat "${LCaseReady}/logs/freeze_stdout_verifyfail.txt"
  exit 1
fi

# ---------- Case E: LINUX-ONLY + REQUIRE CPUINFO LAZY REPEAT ----------
cat > "${LCaseLinuxLazy}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LTmpRoot}/case_linux_lazy/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [ ] **Windows 实机证据未归档**
EOM

cat > "${LCaseLinuxLazy}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [ ] Windows 实机证据日志已归档（当前缺口）
EOM

cat > "${LCaseLinuxLazy}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：脚本入口 + 校验入口已就绪（待 Windows 实机日志）
EOM

set +e
SIMD_FREEZE_REQUIRE_CPUINFO_LAZY_REPEAT=1 \
python3 "${LCaseLinuxLazy}/evaluate_simd_freeze_status.py" --linux-only --root "${LCaseLinuxLazy}" --json-file "${LCaseLinuxLazy}/logs/freeze_status_lazy_missing.json" > "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_missing.txt" 2>&1
LLazyMissingRc=$?
set -e

if [[ "${LLazyMissingRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_lazy missing-step should return non-zero"
  cat "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_missing.txt"
  exit 1
fi

if ! grep -F -- "linux_cpuinfo_lazy_repeat" "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_missing.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_lazy missing-step should report linux_cpuinfo_lazy_repeat"
  cat "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_missing.txt"
  exit 1
fi

cat > "${LCaseLinuxLazy}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | cpuinfo-lazy-repeat | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

SIMD_FREEZE_REQUIRE_CPUINFO_LAZY_REPEAT=1 \
python3 "${LCaseLinuxLazy}/evaluate_simd_freeze_status.py" --linux-only --root "${LCaseLinuxLazy}" --json-file "${LCaseLinuxLazy}/logs/freeze_status_lazy_pass.json" > "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_pass.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_pass.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_lazy pass-step missing ready=True"
  cat "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_pass.txt"
  exit 1
fi

if ! grep -F -- "linux_cpuinfo_lazy_repeat: step PASS" "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_pass.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_lazy pass-step missing linux_cpuinfo_lazy_repeat PASS"
  cat "${LCaseLinuxLazy}/logs/freeze_stdout_lazy_pass.txt"
  exit 1
fi

python3 - "${LCaseLinuxLazy}/logs/freeze_status_lazy_pass.json" <<'PY'
import json
import sys
from pathlib import Path

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if payload.get("ready") is not True:
    print("[FREEZE-REHEARSAL] FAILED: case_linux_lazy pass-step json ready should be true")
    sys.exit(1)
if payload.get("freeze_ready") is not True:
    print("[FREEZE-REHEARSAL] FAILED: case_linux_lazy pass-step json freeze_ready should be true")
    sys.exit(1)
if payload.get("linux_only") is not True:
    print("[FREEZE-REHEARSAL] FAILED: case_linux_lazy pass-step json linux_only should be true")
    sys.exit(1)
PY

# ---------- Case F: LINUX-ONLY + REQUIRE QEMU CPUINFO NONX86 PLATFORM COVERAGE ----------
cat > "${LCaseLinuxPlatforms}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | qemu-cpuinfo-nonx86-evidence | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:12 | qemu-cpuinfo-nonx86-full-evidence | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:13 | qemu-cpuinfo-nonx86-full-repeat | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:14 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LTmpRoot}/case_linux_platforms/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [ ] **Windows 实机证据未归档**
EOM

cat > "${LCaseLinuxPlatforms}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [ ] Windows 实机证据日志已归档（当前缺口）
EOM

cat > "${LCaseLinuxPlatforms}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：脚本入口 + 校验入口已就绪（待 Windows 实机日志）
EOM

mkdir -p "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000010"
mkdir -p "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000011"
mkdir -p "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000012"
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000010/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:10+08:00
- scenario: cpuinfo-nonx86-evidence
- platforms: linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000011/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:11+08:00
- scenario: cpuinfo-nonx86-full-evidence
- platforms: linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000012/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:12+08:00
- scenario: cpuinfo-nonx86-full-repeat
- platforms: linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 \
python3 "${LCaseLinuxPlatforms}/evaluate_simd_freeze_status.py" --linux-only --root "${LCaseLinuxPlatforms}" --json-file "${LCaseLinuxPlatforms}/logs/freeze_status_platform_missing.json" > "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt" 2>&1
LPlatformMissingRc=$?
set -e

if [[ "${LPlatformMissingRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms missing arm-v7 should return non-zero"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt"
  exit 1
fi

if ! grep -F -- "linux_qemu_cpuinfo_nonx86_full_evidence_platforms" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms missing platform-check output for full-evidence"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt"
  exit 1
fi

if ! grep -F -- "linux_qemu_cpuinfo_nonx86_evidence_platforms" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms missing platform-check output for nonx86-evidence"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt"
  exit 1
fi

if ! grep -F -- "linux_qemu_cpuinfo_nonx86_full_repeat_platforms" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms missing platform-check output for full-repeat"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_missing.txt"
  exit 1
fi

cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000010/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:10+08:00
- scenario: cpuinfo-nonx86-evidence
- platforms: linux/arm/v7 linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm/v7 | PASS | `arm-v7.log` |
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000011/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:11+08:00
- scenario: cpuinfo-nonx86-full-evidence
- platforms: linux/arm/v7 linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm/v7 | PASS | `arm-v7.log` |
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000012/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:12+08:00
- scenario: cpuinfo-nonx86-full-repeat
- platforms: linux/arm/v7 linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm/v7 | PASS | `arm-v7.log` |
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 \
python3 "${LCaseLinuxPlatforms}/evaluate_simd_freeze_status.py" --linux-only --root "${LCaseLinuxPlatforms}" --json-file "${LCaseLinuxPlatforms}/logs/freeze_status_platform_pass.json" > "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_pass.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_pass.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms full coverage should produce ready=True"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_pass.txt"
  exit 1
fi

# Newer incomplete summaries must not override gate-step aligned evidence.
mkdir -p "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000020"
mkdir -p "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000021"
mkdir -p "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000022"
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000020/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:20+08:00
- scenario: cpuinfo-nonx86-evidence
- platforms: linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000021/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:21+08:00
- scenario: cpuinfo-nonx86-full-evidence
- platforms: linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM
cat > "${LCaseLinuxPlatforms}/logs/qemu-multiarch-20260210-000022/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:00:22+08:00
- scenario: cpuinfo-nonx86-full-repeat
- platforms: linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 \
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 \
python3 "${LCaseLinuxPlatforms}/evaluate_simd_freeze_status.py" --linux-only --root "${LCaseLinuxPlatforms}" --json-file "${LCaseLinuxPlatforms}/logs/freeze_status_platform_anchor.json" > "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms anchor check should stay ready=True"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt"
  exit 1
fi

if grep -F -- "qemu-multiarch-20260210-000020" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms anchor check selected newer incomplete nonx86-evidence summary"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt"
  exit 1
fi

if grep -F -- "qemu-multiarch-20260210-000021" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms anchor check selected newer incomplete nonx86-full-evidence summary"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt"
  exit 1
fi

if grep -F -- "qemu-multiarch-20260210-000022" "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_linux_platforms anchor check selected newer incomplete nonx86-full-repeat summary"
  cat "${LCaseLinuxPlatforms}/logs/freeze_stdout_platform_anchor.txt"
  exit 1
fi

# ---------- Case G: CROSS-READY FALLBACK TO BATCH CLOSEOUT GATE SNAPSHOT ----------
cat > "${LCaseBatchFallback}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:10:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:10:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:11 | evidence-verify | SKIP | - | SKIP | require-win-evidence=0 | - |
| 2026-02-10 00:10:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseBatchFallback}/logs/windows-closeout/SIMD-20260210-152/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:05:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:05:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:11 | qemu-cpuinfo-nonx86-evidence | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:12 | evidence-verify | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:05:13 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseBatchFallback}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows [Version 10.0.22631.4602]
[B07] Started: 2026/02/10 00:00:00.00
[B07] Working dir: C:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[B07] GateSummaryJson: /tmp/rehearse.windows_b07_gate.batch-fallback.summary-json.missing
[GATE] 1/6 Build + check SIMD module
[BACKEND-OPS] Building standalone program: C:\simd\tests\nextpas.core.simd\test_backend_ops.pas
[BACKEND-OPS] Running standalone program: C:\simd\tests\nextpas.core.simd\backend.ops\bin\test_backend_ops.exe
[SIMD-BOUNDARY] Building standalone program: C:\simd\tests\nextpas.core.simd\test_simd_boundary.pas
[SIMD-BOUNDARY] Running standalone program: C:\simd\tests\nextpas.core.simd\simd.boundary\bin\test_simd_boundary.exe
[PUBLIC-SMOKE] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.public_smoke.pas
[PUBLIC-SMOKE] Running standalone smoke: C:\simd\tests\nextpas.core.simd\public.smoke\bin\nextpas.core.simd.public_smoke.exe
[PASS] Default backend is AVX2
[DISPATCH-PREINIT] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.dispatch_preinit_smoke.pas
[DISPATCH-PREINIT] Running standalone smoke: C:\simd\tests\nextpas.core.simd\dispatch.preinit.smoke\bin\nextpas.core.simd.dispatch_preinit_smoke.exe
[DISPATCH-PREINIT] OK
[GATE] Optional public ABI smoke
[GATE] 2/6 SIMD list suites
[GATE] 3/6 SIMD AVX2 stable vector suites
[GATE] 4/6 CPUInfo portable suites
[GATE] 5/6 CPUInfo x86 suites
[GATE] 6/6 Filtered run_all check chain
[GATE] OK
[B07] GATE_EXIT_CODE=0
Total:  5
Passed: 5
Failed: 0
[B07] Total: 5
[B07] Passed: 5
[B07] Failed: 0
EOM

cat > "${LCaseBatchFallback}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: PASS
EOM

cat > "${LTmpRoot}/case_batch_fallback/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseBatchFallback}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseBatchFallback}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

mkdir -p "${LCaseBatchFallback}/logs/qemu-multiarch-20260210-000511"
cat > "${LCaseBatchFallback}/logs/qemu-multiarch-20260210-000511/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:05:11+08:00
- scenario: cpuinfo-nonx86-evidence
- platforms: linux/arm/v7 linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm/v7 | PASS | `armv7.log` |
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
python3 "${LCaseBatchFallback}/evaluate_simd_freeze_status.py" --root "${LCaseBatchFallback}" --json-file "${LCaseBatchFallback}/logs/freeze_status_batch_fallback.json" > "${LCaseBatchFallback}/logs/freeze_stdout_batch_fallback.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseBatchFallback}/logs/freeze_stdout_batch_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_batch_fallback should stay ready=True via closeout snapshot"
  cat "${LCaseBatchFallback}/logs/freeze_stdout_batch_fallback.txt"
  exit 1
fi

if ! grep -F -- "selected fallback closeout gate snapshot" "${LCaseBatchFallback}/logs/freeze_stdout_batch_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_batch_fallback missing fallback selection detail"
  cat "${LCaseBatchFallback}/logs/freeze_stdout_batch_fallback.txt"
  exit 1
fi

# ---------- Case H: CROSS MODE SHOULD FALL BACK TO MAINLINE-READY BACKUP SNAPSHOT ----------
cat > "${LCaseMainlineFallback}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:10:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:10:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:11 | qemu-cpuinfo-nonx86-evidence | SKIP | - | SKIP | SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=0 | - |
| 2026-02-10 00:10:12 | evidence-verify | SKIP | - | SKIP | require-win-evidence=0 | - |
| 2026-02-10 00:10:13 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseMainlineFallback}/logs/rehearsal/backups/gate_summary.backup.20260210-000700-000.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:07:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:07:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:11 | qemu-cpuinfo-nonx86-evidence | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:12 | evidence-verify | SKIP | 100 | SKIP | optional evidence verify failed rc=1; set SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 to enforce fail-close | - |
| 2026-02-10 00:07:13 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseMainlineFallback}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Started: 2026/02/10 00:00:00.00
[B07] Command: buildOrTest.bat gate
[B07] GATE_EXIT_CODE=0
[B07] Total: 3
[B07] Passed: 3
[B07] Failed: 0
EOM

cat > "${LCaseMainlineFallback}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

cat > "${LTmpRoot}/case_mainline_fallback/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseMainlineFallback}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseMainlineFallback}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

mkdir -p "${LCaseMainlineFallback}/logs/qemu-multiarch-20260210-000711"
cat > "${LCaseMainlineFallback}/logs/qemu-multiarch-20260210-000711/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:07:11+08:00
- scenario: cpuinfo-nonx86-evidence
- platforms: linux/arm/v7 linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm/v7 | PASS | `armv7.log` |
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
python3 "${LCaseMainlineFallback}/evaluate_simd_freeze_status.py" --root "${LCaseMainlineFallback}" --json-file "${LCaseMainlineFallback}/logs/freeze_status_mainline_fallback.json" > "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" 2>&1
LMainlineFallbackRc=$?
set -e

if [[ "${LMainlineFallbackRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback should stay non-zero because cross closeout is still incomplete"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

if ! grep -F -- "mainline-ready=True" "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback should preserve mainline-ready=True via backup snapshot"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

if ! grep -F -- "cross-ready=False" "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback should keep cross-ready=False"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

if ! grep -F -- "selected fallback backup gate snapshot" "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback missing backup fallback selection detail"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

if ! grep -F -- "linux_gate_required_steps_mainline: all required gate steps are PASS" "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback should report mainline gate steps PASS"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

if ! grep -F -- "cross_gate_required_steps: non-pass: evidence-verify=SKIP" "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback should still report cross gate omission"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

if ! grep -F -- "see windows_evidence_verify for the current failure root cause" "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_mainline_fallback should point to windows_evidence_verify instead of restating the failure"
  cat "${LCaseMainlineFallback}/logs/freeze_stdout_mainline_fallback.txt"
  exit 1
fi

# ---------- Case H2: LATEST MAINLINE-COMPLETE GATE MUST BE PREFERRED OVER OLDER BACKUP ----------
cat > "${LCaseLatestMainline}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:10:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:10:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:11 | qemu-cpuinfo-nonx86-evidence | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:10:12 | evidence-verify | SKIP | 100 | SKIP | optional evidence verify failed rc=1; set SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 to enforce fail-close | - |
| 2026-02-10 00:10:13 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseLatestMainline}/logs/rehearsal/backups/gate_summary.backup.20260210-000700-000.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:07:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:07:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:11 | qemu-cpuinfo-nonx86-evidence | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:07:12 | evidence-verify | SKIP | 100 | SKIP | optional evidence verify failed rc=1; set SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 to enforce fail-close | - |
| 2026-02-10 00:07:13 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseLatestMainline}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Started: 2026/02/10 00:09:00.00
[B07] Command: buildOrTest.bat gate
[B07] GATE_EXIT_CODE=0
[B07] Total: 3
[B07] Passed: 3
[B07] Failed: 0
EOM

cat > "${LCaseLatestMainline}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

cat > "${LTmpRoot}/case_latest_mainline/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseLatestMainline}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseLatestMainline}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

cat > "${LTmpRoot}/case_latest_mainline/src/nextpas.core.simd.intrinsics.x86.sse2.pas" <<'EOM'
unit nextpas.core.simd.intrinsics.x86.sse2;
EOM

mkdir -p "${LCaseLatestMainline}/logs/qemu-multiarch-20260210-001011"
cat > "${LCaseLatestMainline}/logs/qemu-multiarch-20260210-001011/summary.md" <<'EOM'
# SIMD QEMU Multiarch Report

- time: 2026-02-10T00:10:11+08:00
- scenario: cpuinfo-nonx86-evidence
- platforms: linux/arm/v7 linux/arm64 linux/riscv64

| Platform | Status | Log |
|---|---|---|
| linux/arm/v7 | PASS | `armv7.log` |
| linux/arm64 | PASS | `arm64.log` |
| linux/riscv64 | PASS | `riscv64.log` |
EOM

touch -d '10 minutes ago' "${LCaseLatestMainline}/logs/gate_summary.md"
touch -d '30 minutes ago' "${LCaseLatestMainline}/logs/rehearsal/backups/gate_summary.backup.20260210-000700-000.md"
touch -d '20 minutes ago' "${LTmpRoot}/case_latest_mainline/src/nextpas.core.simd.intrinsics.x86.sse2.pas"
touch -d '25 minutes ago' "${LCaseLatestMainline}/logs/windows_b07_gate.log"
touch -d '24 minutes ago' "${LCaseLatestMainline}/logs/windows_b07_closeout_summary.md"

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=1 \
python3 "${LCaseLatestMainline}/evaluate_simd_freeze_status.py" --root "${LCaseLatestMainline}" --json-file "${LCaseLatestMainline}/logs/freeze_status_latest_mainline.json" > "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt" 2>&1
LLatestMainlineRc=$?
set -e

if [[ "${LLatestMainlineRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_latest_mainline should stay non-zero because cross closeout is still incomplete"
  cat "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt"
  exit 1
fi

if ! grep -F -- "mainline-ready=True" "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_latest_mainline should keep mainline-ready=True via latest gate"
  cat "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt"
  exit 1
fi

if ! grep -F -- "cross-ready=False" "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_latest_mainline should keep cross-ready=False"
  cat "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt"
  exit 1
fi

if grep -F -- "selected fallback backup gate snapshot" "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_latest_mainline should not fall back to the older backup when latest gate already covers mainline-required steps"
  cat "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt"
  exit 1
fi

if grep -F -- "linux_sources_not_newer_than_gate: artifact older than latest source" "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_latest_mainline should not report stale gate freshness against the older backup"
  cat "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt"
  exit 1
fi

if ! grep -F -- "cross_gate_required_steps: non-pass: evidence-verify=SKIP" "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_latest_mainline should still report cross gate omission"
  cat "${LCaseLatestMainline}/logs/freeze_stdout_latest_mainline.txt"
  exit 1
fi

# ---------- Case I: SOURCE NEWER THAN GATE ARTIFACT ----------
LCaseSourceFresh="${LTmpRoot}/case_source_newer/tests/nextpas.core.simd"
mkdir -p "${LCaseSourceFresh}/logs" "${LCaseSourceFresh}/docs" "${LTmpRoot}/case_source_newer/docs/plans" "${LTmpRoot}/case_source_newer/src"
cp "${FREEZE_SCRIPT}" "${LCaseSourceFresh}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseSourceFresh}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseSourceFresh}/verify_windows_b07_evidence.sh"

cat > "${LCaseSourceFresh}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseSourceFresh}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows [Version 10.0.22631.4602]
[B07] Started: 2026/02/10 00:00:00.00
[B07] Working dir: C:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[B07] GateSummaryJson: /tmp/rehearse.windows_b07_gate.source-fresh.summary-json.missing
[GATE] 1/6 Build + check SIMD module
[BACKEND-OPS] Building standalone program: C:\simd\tests\nextpas.core.simd\test_backend_ops.pas
[BACKEND-OPS] Running standalone program: C:\simd\tests\nextpas.core.simd\backend.ops\bin\test_backend_ops.exe
[SIMD-BOUNDARY] Building standalone program: C:\simd\tests\nextpas.core.simd\test_simd_boundary.pas
[SIMD-BOUNDARY] Running standalone program: C:\simd\tests\nextpas.core.simd\simd.boundary\bin\test_simd_boundary.exe
[PUBLIC-SMOKE] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.public_smoke.pas
[PUBLIC-SMOKE] Running standalone smoke: C:\simd\tests\nextpas.core.simd\public.smoke\bin\nextpas.core.simd.public_smoke.exe
[PASS] Default backend is AVX2
[DISPATCH-PREINIT] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.dispatch_preinit_smoke.pas
[DISPATCH-PREINIT] Running standalone smoke: C:\simd\tests\nextpas.core.simd\dispatch.preinit.smoke\bin\nextpas.core.simd.dispatch_preinit_smoke.exe
[DISPATCH-PREINIT] OK
[GATE] Optional public ABI smoke
[GATE] 2/6 SIMD list suites
[GATE] 3/6 SIMD AVX2 stable vector suites
[GATE] 4/6 CPUInfo portable suites
[GATE] 5/6 CPUInfo x86 suites
[GATE] 6/6 Filtered run_all check chain
[GATE] OK
[B07] GATE_EXIT_CODE=0
Total:  5
Passed: 5
Failed: 0
[B07] Total: 5
[B07] Passed: 5
[B07] Failed: 0
EOM

cat > "${LCaseSourceFresh}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: PASS
EOM

cat > "${LTmpRoot}/case_source_newer/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseSourceFresh}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseSourceFresh}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

cat > "${LTmpRoot}/case_source_newer/src/nextpas.core.simd.pas" <<'EOM'
unit nextpas.core.simd;
EOM

touch -d '2026-02-10 00:00:30' "${LTmpRoot}/case_source_newer/src/nextpas.core.simd.pas"
touch -d '2026-02-10 00:00:00' "${LCaseSourceFresh}/logs/gate_summary.md"
touch -d '2026-02-10 00:00:00' "${LCaseSourceFresh}/logs/windows_b07_gate.log"

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseSourceFresh}/evaluate_simd_freeze_status.py" --root "${LCaseSourceFresh}" --json-file "${LCaseSourceFresh}/logs/freeze_status_source_newer.json" > "${LCaseSourceFresh}/logs/freeze_stdout_source_newer.txt" 2>&1
LSourceNewerRc=$?
set -e

if [[ "${LSourceNewerRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_source_newer should return non-zero"
  cat "${LCaseSourceFresh}/logs/freeze_stdout_source_newer.txt"
  exit 1
fi

if ! grep -F -- "linux_sources_not_newer_than_gate: artifact older than latest source" "${LCaseSourceFresh}/logs/freeze_stdout_source_newer.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_source_newer missing source freshness failure"
  cat "${LCaseSourceFresh}/logs/freeze_stdout_source_newer.txt"
  exit 1
fi

# ---------- Case J: IGNORED COMPILE ARTIFACT NEWER THAN EVIDENCE (should stay ready) ----------
LCaseIgnoredArtifact="${LTmpRoot}/case_ignored_artifact/tests/nextpas.core.simd"
mkdir -p "${LCaseIgnoredArtifact}/logs" "${LCaseIgnoredArtifact}/docs" "${LTmpRoot}/case_ignored_artifact/docs/plans" "${LTmpRoot}/case_ignored_artifact/src"
cp "${LTmpRoot}/case_ready/tests/nextpas.core.simd/evaluate_simd_freeze_status.py" "${LCaseIgnoredArtifact}/evaluate_simd_freeze_status.py"
cp "${LTmpRoot}/case_ready/tests/nextpas.core.simd/verify_windows_b07_evidence.sh" "${LCaseIgnoredArtifact}/verify_windows_b07_evidence.sh"

cat > "${LCaseIgnoredArtifact}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Debug | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:00 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseIgnoredArtifact}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows [Version 10.0.22631.4602]
[B07] Started: 2026/02/10 00:00:00.00
[B07] Working dir: C:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[B07] GateSummaryJson: /tmp/rehearse.windows_b07_gate.ignored-artifact.summary-json.missing
[GATE] 1/6 Build + check SIMD module
[BACKEND-OPS] Building standalone program: C:\simd\tests\nextpas.core.simd\test_backend_ops.pas
[BACKEND-OPS] Running standalone program: C:\simd\tests\nextpas.core.simd\backend.ops\bin\test_backend_ops.exe
[SIMD-BOUNDARY] Building standalone program: C:\simd\tests\nextpas.core.simd\test_simd_boundary.pas
[SIMD-BOUNDARY] Running standalone program: C:\simd\tests\nextpas.core.simd\simd.boundary\bin\test_simd_boundary.exe
[PUBLIC-SMOKE] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.public_smoke.pas
[PUBLIC-SMOKE] Running standalone smoke: C:\simd\tests\nextpas.core.simd\public.smoke\bin\nextpas.core.simd.public_smoke.exe
[PASS] Default backend is AVX2
[DISPATCH-PREINIT] Building standalone smoke: C:\simd\tests\nextpas.core.simd\nextpas.core.simd.dispatch_preinit_smoke.pas
[DISPATCH-PREINIT] Running standalone smoke: C:\simd\tests\nextpas.core.simd\dispatch.preinit.smoke\bin\nextpas.core.simd.dispatch_preinit_smoke.exe
[DISPATCH-PREINIT] OK
[GATE] Optional public ABI smoke
[GATE] 2/6 SIMD list suites
[GATE] 3/6 SIMD AVX2 stable vector suites
[GATE] 4/6 CPUInfo portable suites
[GATE] 5/6 CPUInfo x86 suites
[GATE] 6/6 Filtered run_all check chain
[GATE] OK
[B07] GATE_EXIT_CODE=0
Total:  5
Passed: 5
Failed: 0
[B07] Total: 5
[B07] Passed: 5
[B07] Failed: 0
EOM

cat > "${LCaseIgnoredArtifact}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: PASS
EOM

cat > "${LTmpRoot}/case_ignored_artifact/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseIgnoredArtifact}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseIgnoredArtifact}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

cat > "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.pas" <<'EOM'
unit nextpas.core.simd;
EOM
cat > "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.neon.facade_platform.inc" <<'EOM'
// Intentional empty include boundary used by freeze-status rehearsal.
EOM
cat > "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.avx512.fallback.inc" <<'EOM'
// Intentional empty include boundary used by freeze-status rehearsal.
EOM
cat > "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.neon.dot.inc" <<'EOM'
// Intentional empty include boundary used by freeze-status rehearsal.
EOM
cat > "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.riscvv.ppu" <<'EOM'
compiled artifact placeholder
EOM

python3 - "${LCaseIgnoredArtifact}/logs/gate_summary.md" "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.pas" "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.riscvv.ppu" "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.neon.facade_platform.inc" "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.avx512.fallback.inc" "${LTmpRoot}/case_ignored_artifact/src/nextpas.core.simd.neon.dot.inc" <<'PY'
from pathlib import Path
import os
import sys

artifact = Path(sys.argv[1])
real_source = Path(sys.argv[2])
compiled_artifact = Path(sys.argv[3])
empty_boundary = Path(sys.argv[4])
empty_boundary_avx512 = Path(sys.argv[5])
empty_boundary_neon_dot = Path(sys.argv[6])
base = artifact.stat().st_mtime
os.utime(real_source, (base - 30, base - 30))
os.utime(compiled_artifact, (base + 30, base + 30))
os.utime(empty_boundary, (base + 45, base + 45))
os.utime(empty_boundary_avx512, (base + 50, base + 50))
os.utime(empty_boundary_neon_dot, (base + 55, base + 55))
PY

SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 python3 "${LCaseIgnoredArtifact}/evaluate_simd_freeze_status.py" --root "${LCaseIgnoredArtifact}" --json-file "${LCaseIgnoredArtifact}/logs/freeze_status_ignored_artifact.json" > "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt" 2>&1

if ! grep -F -- "ready=True" "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ignored_artifact should stay ready=True"
  cat "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt"
  exit 1
fi

if grep -F -- "latest_source=" "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt" | grep -F ".ppu" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ignored_artifact should not treat .ppu as latest source"
  cat "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt"
  exit 1
fi

if grep -F -- "latest_source=" "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt" | grep -F "neon.facade_platform.inc" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ignored_artifact should not treat intentional empty include boundaries as latest source"
  cat "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt"
  exit 1
fi

if grep -F -- "latest_source=" "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt" | grep -E "avx512\\.fallback\\.inc|neon\\.dot\\.inc" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_ignored_artifact should not treat retired fallback/dot empty include boundaries as latest source"
  cat "${LCaseIgnoredArtifact}/logs/freeze_stdout_ignored_artifact.txt"
  exit 1
fi

# ---------- Case K: WINDOWS VERIFY FAIL SHOULD SURFACE ROOT-CAUSE HINT ----------
LCaseWindowsHint="${LTmpRoot}/case_windows_hint/tests/nextpas.core.simd"
mkdir -p "${LCaseWindowsHint}/logs" "${LCaseWindowsHint}/docs" "${LTmpRoot}/case_windows_hint/docs/plans"
cp "${FREEZE_SCRIPT}" "${LCaseWindowsHint}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseWindowsHint}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseWindowsHint}/verify_windows_b07_evidence.sh"

cat > "${LCaseWindowsHint}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | SKIP | - | SKIP | require-win-evidence=0 | - |
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseWindowsHint}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows 10.0.19043
[B07] Started: 5/17/2026 12:42 PM
[B07] Working dir: Z:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[BUILD] FAILED (see Z:\simd\tests\nextpas.core.simd\logs\build.txt)
Can't recognize '"lazbuild" --build-mode=Release "demo.lpi"' as an internal or external command, or batch script.
[B07] GateSummaryJson: missing
[B07] GateSummaryExportRc: skipped-native-batch
[B07] GATE_EXIT_CODE=1
EOM

cat > "${LCaseWindowsHint}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

cat > "${LTmpRoot}/case_windows_hint/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseWindowsHint}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseWindowsHint}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseWindowsHint}/evaluate_simd_freeze_status.py" --root "${LCaseWindowsHint}" --json-file "${LCaseWindowsHint}/logs/freeze_status_windows_hint.json" > "${LCaseWindowsHint}/logs/freeze_stdout_windows_hint.txt" 2>&1
LWindowsHintRc=$?
set -e

if [[ "${LWindowsHintRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_hint should return non-zero"
  cat "${LCaseWindowsHint}/logs/freeze_stdout_windows_hint.txt"
  exit 1
fi

if ! grep -F -- "root-cause hint:" "${LCaseWindowsHint}/logs/freeze_stdout_windows_hint.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_hint missing root-cause hint"
  cat "${LCaseWindowsHint}/logs/freeze_stdout_windows_hint.txt"
  exit 1
fi

if ! grep -F -- "Can't recognize '\"lazbuild\"" "${LCaseWindowsHint}/logs/freeze_stdout_windows_hint.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_hint missing lazbuild failure detail"
  cat "${LCaseWindowsHint}/logs/freeze_stdout_windows_hint.txt"
  exit 1
fi

# ---------- Case L: WINDOWS LOG SHOULD BE STALE WHEN PRODUCER INPUTS ARE NEWER ----------
LCaseWindowsProducerNewer="${LTmpRoot}/case_windows_producer_newer/tests/nextpas.core.simd"
mkdir -p "${LCaseWindowsProducerNewer}/logs" "${LCaseWindowsProducerNewer}/docs" "${LTmpRoot}/case_windows_producer_newer/docs/plans"
cp "${FREEZE_SCRIPT}" "${LCaseWindowsProducerNewer}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseWindowsProducerNewer}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseWindowsProducerNewer}/verify_windows_b07_evidence.sh"

cat > "${LCaseWindowsProducerNewer}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | SKIP | - | SKIP | require-win-evidence=0 | - |
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseWindowsProducerNewer}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows 10.0.19043
[B07] Started: 5/17/2026 12:42 PM
[B07] Working dir: Z:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[BUILD] FAILED (see Z:\simd\tests\nextpas.core.simd\logs\build.txt)
Can't recognize '"lazbuild" --build-mode=Release "demo.lpi"' as an internal or external command, or batch script.
[B07] GateSummaryJson: missing
[B07] GateSummaryExportRc: skipped-native-batch
[B07] GATE_EXIT_CODE=1
EOM

cat > "${LCaseWindowsProducerNewer}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

cat > "${LCaseWindowsProducerNewer}/buildOrTest.bat" <<'EOM'
@echo off
rem rehearse newer batch runner input
EOM

cat > "${LCaseWindowsProducerNewer}/collect_windows_b07_evidence.bat" <<'EOM'
@echo off
rem rehearse evidence collector
EOM

cat > "${LTmpRoot}/case_windows_producer_newer/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseWindowsProducerNewer}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseWindowsProducerNewer}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

python3 - "${LCaseWindowsProducerNewer}/logs/windows_b07_gate.log" "${LCaseWindowsProducerNewer}/buildOrTest.bat" "${LCaseWindowsProducerNewer}/collect_windows_b07_evidence.bat" <<'PY'
from pathlib import Path
import os
import sys

artifact = Path(sys.argv[1])
build_bat = Path(sys.argv[2])
collector_bat = Path(sys.argv[3])
base = artifact.stat().st_mtime
os.utime(build_bat, (base + 120, base + 120))
os.utime(collector_bat, (base + 60, base + 60))
PY

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseWindowsProducerNewer}/evaluate_simd_freeze_status.py" --root "${LCaseWindowsProducerNewer}" --json-file "${LCaseWindowsProducerNewer}/logs/freeze_status_windows_producer_newer.json" > "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt" 2>&1
LWindowsProducerNewerRc=$?
set -e

if [[ "${LWindowsProducerNewerRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_producer_newer should return non-zero"
  cat "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt"
  exit 1
fi

if ! grep -F -- "windows_evidence_inputs_not_newer_than_log" "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_producer_newer missing producer freshness failure"
  cat "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt"
  exit 1
fi

if ! grep -F -- "stale evidence log:" "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_producer_newer missing stale evidence note"
  cat "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt"
  exit 1
fi

if ! grep -F -- "windows_closeout_summary" "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_producer_newer missing closeout summary check"
  cat "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt"
  exit 1
fi

if ! grep -F -- "stale summary:" "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_producer_newer missing stale summary note"
  cat "${LCaseWindowsProducerNewer}/logs/freeze_stdout_windows_producer_newer.txt"
  exit 1
fi

# ---------- Case M: CLOSEOUT SUMMARY MUST NOT BE OLDER THAN CURRENT WINDOWS LOG ----------
LCaseCloseoutSummaryOlder="${LTmpRoot}/case_closeout_summary_older/tests/nextpas.core.simd"
mkdir -p "${LCaseCloseoutSummaryOlder}/logs" "${LCaseCloseoutSummaryOlder}/docs" "${LTmpRoot}/case_closeout_summary_older/docs/plans"
cp "${FREEZE_SCRIPT}" "${LCaseCloseoutSummaryOlder}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseCloseoutSummaryOlder}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseCloseoutSummaryOlder}/verify_windows_b07_evidence.sh"

cat > "${LCaseCloseoutSummaryOlder}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | SKIP | - | SKIP | require-win-evidence=0 | - |
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseCloseoutSummaryOlder}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows 10.0.19043
[B07] Started: 5/17/2026 17:27 PM
[B07] Working dir: Z:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[BUILD] FAILED (see Z:\simd\tests\nextpas.core.simd\logs\build.txt)
Can't recognize 'lazbuild --build-mode=Release "demo.lpi"' as an internal or external command, or batch script.
[B07] GateSummaryJson: missing
[B07] GateSummaryExportRc: skipped-native-batch
[B07] GATE_EXIT_CODE=1
EOM

cat > "${LCaseCloseoutSummaryOlder}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

cat > "${LTmpRoot}/case_closeout_summary_older/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseCloseoutSummaryOlder}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseCloseoutSummaryOlder}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

python3 - "${LCaseCloseoutSummaryOlder}/logs/windows_b07_gate.log" "${LCaseCloseoutSummaryOlder}/logs/windows_b07_closeout_summary.md" <<'PY'
from pathlib import Path
import os
import sys

log_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])
base = log_path.stat().st_mtime
os.utime(summary_path, (base - 120, base - 120))
PY

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseCloseoutSummaryOlder}/evaluate_simd_freeze_status.py" --root "${LCaseCloseoutSummaryOlder}" --json-file "${LCaseCloseoutSummaryOlder}/logs/freeze_status_closeout_summary_older.json" > "${LCaseCloseoutSummaryOlder}/logs/freeze_stdout_closeout_summary_older.txt" 2>&1
LCloseoutSummaryOlderRc=$?
set -e

if [[ "${LCloseoutSummaryOlderRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_closeout_summary_older should return non-zero"
  cat "${LCaseCloseoutSummaryOlder}/logs/freeze_stdout_closeout_summary_older.txt"
  exit 1
fi

if ! grep -F -- "windows_closeout_summary_not_older_than_log" "${LCaseCloseoutSummaryOlder}/logs/freeze_stdout_closeout_summary_older.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_closeout_summary_older missing summary freshness check"
  cat "${LCaseCloseoutSummaryOlder}/logs/freeze_stdout_closeout_summary_older.txt"
  exit 1
fi

if ! grep -F -- "stale summary: closeout summary is older than current windows evidence log" "${LCaseCloseoutSummaryOlder}/logs/freeze_stdout_closeout_summary_older.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_closeout_summary_older missing stale closeout-summary note"
  cat "${LCaseCloseoutSummaryOlder}/logs/freeze_stdout_closeout_summary_older.txt"
  exit 1
fi

# ---------- Case N: TOOLCHAIN BLOCK SHOULD ADD NATIVE WINDOWS NEXT-ACTION ----------
LCaseWindowsToolchainAction="${LTmpRoot}/case_windows_toolchain_action/tests/nextpas.core.simd"
mkdir -p "${LCaseWindowsToolchainAction}/logs" "${LCaseWindowsToolchainAction}/docs" "${LTmpRoot}/case_windows_toolchain_action/docs/plans"
cp "${FREEZE_SCRIPT}" "${LCaseWindowsToolchainAction}/evaluate_simd_freeze_status.py"
cp "${VERIFY_SCRIPT}" "${LCaseWindowsToolchainAction}/verify_windows_b07_evidence.sh"
chmod +x "${LCaseWindowsToolchainAction}/verify_windows_b07_evidence.sh"

cat > "${LCaseWindowsToolchainAction}/logs/gate_summary.md" <<'EOM'
| Time | Step | Status | DurationMs | Event | Detail | Artifacts |
|---|---|---|---|---|---|---|
| 2026-02-10 00:00:00 | gate | START | - | START | mode=Release | - |
| 2026-02-10 00:00:01 | build-check | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | interface-completeness | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:02 | public-api-coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:03 | cross-backend-parity | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:04 | wiring-sync | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:05 | coverage | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:06 | simd-list-suites | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:07 | simd-avx2-fallback | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:08 | cpuinfo-portable | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:09 | cpuinfo-x86 | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:10 | run-all-chain | PASS | 100 | NORMAL | ok | - |
| 2026-02-10 00:00:11 | evidence-verify | SKIP | - | SKIP | require-win-evidence=0 | - |
| 2026-02-10 00:00:12 | gate | PASS | 1000 | NORMAL | all steps passed | - |
EOM

cat > "${LCaseWindowsToolchainAction}/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows 10.0.19043
[B07] Started: 5/17/2026 17:49 PM
[B07] Working dir: Z:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[BUILD] FAILED (see Z:\simd\tests\nextpas.core.simd\logs\build.txt)
[BUILD] TOOLCHAIN BLOCK: cmd.exe cannot resolve LAZBUILD command "lazbuild"
[B07] GateSummaryJson: missing
[B07] GateSummaryExportRc: skipped-native-batch
[B07] GATE_EXIT_CODE=1
EOM

cat > "${LCaseWindowsToolchainAction}/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "logs/windows_b07_gate.log"
- Result: FAIL (rc=1)
EOM

cat > "${LTmpRoot}/case_windows_toolchain_action/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [x] **Windows 实机证据已归档**
EOM

cat > "${LCaseWindowsToolchainAction}/docs/simd_release_candidate_checklist.md" <<'EOM'
- [x] Windows 实机证据日志已归档
EOM

cat > "${LCaseWindowsToolchainAction}/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：实机日志已归档（脚本入口 + 校验入口）
EOM

set +e
SIMD_FREEZE_REQUIRE_QEMU_CPUINFO_NONX86_EVIDENCE=0 \
python3 "${LCaseWindowsToolchainAction}/evaluate_simd_freeze_status.py" --root "${LCaseWindowsToolchainAction}" --json-file "${LCaseWindowsToolchainAction}/logs/freeze_status_windows_toolchain_action.json" > "${LCaseWindowsToolchainAction}/logs/freeze_stdout_windows_toolchain_action.txt" 2>&1
LWindowsToolchainActionRc=$?
set -e

if [[ "${LWindowsToolchainActionRc}" -eq 0 ]]; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_toolchain_action should return non-zero"
  cat "${LCaseWindowsToolchainAction}/logs/freeze_stdout_windows_toolchain_action.txt"
  exit 1
fi

if ! grep -F -- "Provide a real Windows runner with native Windows lazbuild.exe" "${LCaseWindowsToolchainAction}/logs/freeze_stdout_windows_toolchain_action.txt" >/dev/null; then
  echo "[FREEZE-REHEARSAL] FAILED: case_windows_toolchain_action missing native windows next-action"
  cat "${LCaseWindowsToolchainAction}/logs/freeze_stdout_windows_toolchain_action.txt"
  exit 1
fi

echo "[FREEZE-REHEARSAL] OK"
echo "[FREEZE-REHEARSAL] case_not_ready_rc=${LNotReadyRc}"
echo "[FREEZE-REHEARSAL] case_historical_doc_markers_rc=0"
echo "[FREEZE-REHEARSAL] case_stale_summary_rc=${LStaleRc}"
echo "[FREEZE-REHEARSAL] case_verify_fail_rc=${LVerifyFailRc}"
echo "[FREEZE-REHEARSAL] case_linux_lazy_missing_rc=${LLazyMissingRc}"
echo "[FREEZE-REHEARSAL] case_linux_platform_missing_rc=${LPlatformMissingRc}"
echo "[FREEZE-REHEARSAL] case_batch_fallback_rc=0"
echo "[FREEZE-REHEARSAL] case_mainline_fallback_rc=${LMainlineFallbackRc}"
echo "[FREEZE-REHEARSAL] case_source_newer_rc=${LSourceNewerRc}"
echo "[FREEZE-REHEARSAL] case_ignored_artifact_rc=0"
echo "[FREEZE-REHEARSAL] case_windows_hint_rc=${LWindowsHintRc}"
echo "[FREEZE-REHEARSAL] case_windows_producer_newer_rc=${LWindowsProducerNewerRc}"
echo "[FREEZE-REHEARSAL] case_closeout_summary_older_rc=${LCloseoutSummaryOlderRc}"
echo "[FREEZE-REHEARSAL] case_windows_toolchain_action_rc=${LWindowsToolchainActionRc}"
