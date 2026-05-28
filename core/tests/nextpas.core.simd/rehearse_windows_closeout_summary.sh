#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FINALIZE_SCRIPT="${ROOT}/finalize_windows_b07_closeout.sh"
SNIPPET_SCRIPT="${ROOT}/apply_windows_b07_closeout_updates.sh"

if [[ ! -f "${FINALIZE_SCRIPT}" ]]; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] Missing finalize script: ${FINALIZE_SCRIPT}"
  exit 2
fi

if [[ ! -f "${SNIPPET_SCRIPT}" ]]; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] Missing snippet script: ${SNIPPET_SCRIPT}"
  exit 2
fi

LTmpRoot="$(mktemp -d)"
cleanup() {
  rm -rf "${LTmpRoot}"
}
trap cleanup EXIT

LCaseFail="${LTmpRoot}/case_fail"
mkdir -p "${LCaseFail}"
cp "${FINALIZE_SCRIPT}" "${LCaseFail}/finalize_windows_b07_closeout.sh"
cp "${SNIPPET_SCRIPT}" "${LCaseFail}/apply_windows_b07_closeout_updates.sh"
chmod +x "${LCaseFail}/finalize_windows_b07_closeout.sh"
chmod +x "${LCaseFail}/apply_windows_b07_closeout_updates.sh"

cat > "${LCaseFail}/verify_windows_b07_evidence.sh" <<'EOM'
#!/usr/bin/env bash
echo "[EVIDENCE] Missing pattern: [GATE] OK"
exit 1
EOM
chmod +x "${LCaseFail}/verify_windows_b07_evidence.sh"

cat > "${LCaseFail}/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[B07] Source: collect_windows_b07_evidence.bat
[B07] HostOS: Windows_NT
[B07] CmdVer: Microsoft Windows 10.0.19043
[B07] Started: 5/17/2026 6:09 PM
[B07] Working dir: Z:\simd\tests\nextpas.core.simd\
[B07] Command: buildOrTest.bat gate
[BUILD] FAILED (see Z:\simd\tests\nextpas.core.simd\logs\build.txt)
[BUILD] TOOLCHAIN BLOCK: cmd.exe cannot resolve LAZBUILD command "lazbuild"
[BUILD] Hint: install native Windows lazbuild.exe or set LAZBUILD to a Windows .exe/.bat/.cmd wrapper visible to cmd.exe
[B07] GateSummaryJson: missing
[B07] GateSummaryExportRc: skipped-native-batch
[B07] GATE_EXIT_CODE=1
EOM

set +e
"${LCaseFail}/finalize_windows_b07_closeout.sh" "${LCaseFail}/windows_b07_gate.log" "${LCaseFail}/windows_b07_closeout_summary.md" > "${LCaseFail}/stdout.txt" 2>&1
LFailRc=$?
set -e

if [[ "${LFailRc}" -eq 0 ]]; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: fail case should return non-zero"
  cat "${LCaseFail}/stdout.txt"
  exit 1
fi

if ! grep -F -- "## Failure Boundary" "${LCaseFail}/windows_b07_closeout_summary.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: missing failure-boundary section"
  cat "${LCaseFail}/windows_b07_closeout_summary.md"
  exit 1
fi

if ! grep -F -- 'Root Cause Hint: [BUILD] TOOLCHAIN BLOCK: cmd.exe cannot resolve LAZBUILD command "lazbuild"' "${LCaseFail}/windows_b07_closeout_summary.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: missing toolchain root-cause hint"
  cat "${LCaseFail}/windows_b07_closeout_summary.md"
  exit 1
fi

if ! grep -F -- 'Recommended Action: Provide a real Windows runner with native Windows lazbuild.exe' "${LCaseFail}/windows_b07_closeout_summary.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: missing recommended action"
  cat "${LCaseFail}/windows_b07_closeout_summary.md"
  exit 1
fi

if ! grep -F -- 'First Verifier Issue: [EVIDENCE] Missing pattern: [GATE] OK' "${LCaseFail}/windows_b07_closeout_summary.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: missing first verifier issue"
  cat "${LCaseFail}/windows_b07_closeout_summary.md"
  exit 1
fi

"${LCaseFail}/apply_windows_b07_closeout_updates.sh" "${LCaseFail}/windows_b07_closeout_summary.md" > "${LCaseFail}/snippets.txt"

if ! grep -F -- '当前失败边界：[BUILD] TOOLCHAIN BLOCK: cmd.exe cannot resolve LAZBUILD command "lazbuild"' "${LCaseFail}/snippets.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: snippets missing failure boundary"
  cat "${LCaseFail}/snippets.txt"
  exit 1
fi

if ! grep -F -- '建议动作：Provide a real Windows runner with native Windows lazbuild.exe' "${LCaseFail}/snippets.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: snippets missing recommended action"
  cat "${LCaseFail}/snippets.txt"
  exit 1
fi

# ---------- APPLY CASE: STRUCTURED REPLACEMENTS SHOULD KEEP CURRENT LIVE WORDING ----------
LCaseApply="${LTmpRoot}/case_apply"
mkdir -p "${LCaseApply}/tests/nextpas.core.simd/docs" "${LCaseApply}/tests/nextpas.core.simd/logs" "${LCaseApply}/docs/plans"
cp "${SNIPPET_SCRIPT}" "${LCaseApply}/tests/nextpas.core.simd/apply_windows_b07_closeout_updates.sh"
chmod +x "${LCaseApply}/tests/nextpas.core.simd/apply_windows_b07_closeout_updates.sh"

cat > "${LCaseApply}/tests/nextpas.core.simd/verify_windows_b07_evidence.sh" <<'EOM'
#!/usr/bin/env bash
exit 0
EOM
chmod +x "${LCaseApply}/tests/nextpas.core.simd/verify_windows_b07_evidence.sh"

cat > "${LCaseApply}/tests/nextpas.core.simd/logs/windows_b07_gate.log" <<'EOM'
[B07] Windows evidence capture
[GATE] OK
EOM

cat > "${LCaseApply}/tests/nextpas.core.simd/logs/freeze_status.json" <<'EOM'
{
  "mode": "cross-platform",
  "freeze_ready": true,
  "cross_ready": true
}
EOM

cat > "${LCaseApply}/tests/nextpas.core.simd/logs/windows_b07_closeout_summary.md" <<'EOM'
# SIMD Windows B07 Closeout Summary

- Generated: 2026-05-17 19:30:00 +0800
- Evidence Log: tests/nextpas.core.simd/logs/windows_b07_gate.log

## Verification

- Verifier: verify_windows_b07_evidence.sh
- Command: bash verify_windows_b07_evidence.sh "tests/nextpas.core.simd/logs/windows_b07_gate.log"
- Result: PASS
EOM

cat > "${LCaseApply}/docs/plans/2026-02-09-simd-unblock-closeout-roadmap.md" <<'EOM'
- [ ] **Windows 实机证据未归档**
EOM

cat > "${LCaseApply}/tests/nextpas.core.simd/docs/simd_completeness_matrix.md" <<'EOM'
- Windows 证据：脚本入口 + 校验入口已就绪（待 Windows 实机日志）
- [~] Windows 证据脚本+校验器就绪（待实机执行产出）
EOM

cat > "${LCaseApply}/tests/nextpas.core.simd/docs/simd_release_candidate_checklist.md" <<'EOM'
- [ ] Windows 实机证据日志已归档（当前缺口）
- Windows 侧：待补实机日志后完成跨平台证据闭环。
EOM

mkdir -p "${LCaseApply}/plans/scratch/2026-04-08-simd-review"
cat > "${LCaseApply}/plans/scratch/2026-04-08-simd-review/progress.md" <<'EOM'
# SIMD Review Progress
EOM

"${LCaseApply}/tests/nextpas.core.simd/apply_windows_b07_closeout_updates.sh" \
  "${LCaseApply}/tests/nextpas.core.simd/logs/windows_b07_closeout_summary.md" \
  --apply \
  --freeze-json "${LCaseApply}/tests/nextpas.core.simd/logs/freeze_status.json" \
  --target-root "${LCaseApply}" \
  --batch-id SIMD-APPLY-20260517 > "${LCaseApply}/apply_stdout.txt"

if ! grep -F -- 'Windows 实机证据日志曾归档（历史批次）' "${LCaseApply}/tests/nextpas.core.simd/docs/simd_release_candidate_checklist.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: apply case should keep RC historical wording"
  cat "${LCaseApply}/tests/nextpas.core.simd/docs/simd_release_candidate_checklist.md"
  exit 1
fi

if ! grep -F -- 'Windows 实机证据曾归档（历史批次；脚本+校验器+日志）' "${LCaseApply}/tests/nextpas.core.simd/docs/simd_completeness_matrix.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: apply case should keep matrix historical wording"
  cat "${LCaseApply}/tests/nextpas.core.simd/docs/simd_completeness_matrix.md"
  exit 1
fi

if ! grep -F -- '当前 `HEAD` 是否完成跨平台证据闭环，仍以最新 `freeze-status` 为准。' "${LCaseApply}/tests/nextpas.core.simd/docs/simd_release_candidate_checklist.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: apply case should keep RC freeze-status caveat"
  cat "${LCaseApply}/tests/nextpas.core.simd/docs/simd_release_candidate_checklist.md"
  exit 1
fi

if ! grep -F -- 'SIMD-WIN-CLOSEOUT-2026-05-17' "${LCaseApply}/plans/scratch/2026-04-08-simd-review/progress.md" >/dev/null; then
  echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] FAILED: apply case should append scratch progress marker"
  cat "${LCaseApply}/plans/scratch/2026-04-08-simd-review/progress.md"
  exit 1
fi

echo "[WIN-CLOSEOUT-SUMMARY-REHEARSAL] OK"
