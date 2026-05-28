#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HELPER="${ROOT}/print_windows_b07_closeout_3cmd.sh"

if [[ ! -f "${HELPER}" ]]; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] Missing helper: ${HELPER}"
  exit 2
fi

LTmpRoot="$(mktemp -d)"
cleanup() {
  rm -rf "${LTmpRoot}"
}
trap cleanup EXIT

LCaseBlocked="${LTmpRoot}/case_blocked"
mkdir -p "${LCaseBlocked}/logs"
cp "${HELPER}" "${LCaseBlocked}/print_windows_b07_closeout_3cmd.sh"
chmod +x "${LCaseBlocked}/print_windows_b07_closeout_3cmd.sh"

cat > "${LCaseBlocked}/logs/win_preflight_latest.json" <<'EOM'
{
  "checked_at_utc": "2026-05-17T05:28:29Z",
  "status": "FAIL",
  "code": "RECENT_BILLING_BLOCK",
  "exit_code": 31
}
EOM

"${LCaseBlocked}/print_windows_b07_closeout_3cmd.sh" SIMD-REHEARSAL-152 > "${LCaseBlocked}/stdout.txt"

if ! grep -F -- "[CLOSEOUT] WARN latest preflight is RECENT_BILLING_BLOCK" "${LCaseBlocked}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: blocked case missing warning banner"
  cat "${LCaseBlocked}/stdout.txt"
  exit 1
fi

if ! grep -F -- "不要直接执行下面的 \`win-evidence-via-gh\` 主入口命令。" "${LCaseBlocked}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: blocked case missing do-not-run warning"
  cat "${LCaseBlocked}/stdout.txt"
  exit 1
fi

if ! grep -F -- "closeout-release SIMD-REHEARSAL-152" "${LCaseBlocked}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: blocked case missing batch id substitution"
  cat "${LCaseBlocked}/stdout.txt"
  exit 1
fi

if ! grep -F -- "native Windows \`lazbuild.exe\`" "${LCaseBlocked}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: blocked case missing native lazbuild requirement"
  cat "${LCaseBlocked}/stdout.txt"
  exit 1
fi

if ! grep -F -- "\$env:LAZBUILD = 'C:\\Lazarus\\lazbuild.exe'" "${LCaseBlocked}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: blocked case missing LAZBUILD override snippet"
  cat "${LCaseBlocked}/stdout.txt"
  exit 1
fi

if ! grep -F -- "当前本机 Wine 不属于这种环境，不要把它当成 host-side Unix bridge 逃生口。" "${LCaseBlocked}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: blocked case missing bash-gate/Wine caveat"
  cat "${LCaseBlocked}/stdout.txt"
  exit 1
fi

LCasePass="${LTmpRoot}/case_pass"
mkdir -p "${LCasePass}/logs"
cp "${HELPER}" "${LCasePass}/print_windows_b07_closeout_3cmd.sh"
chmod +x "${LCasePass}/print_windows_b07_closeout_3cmd.sh"

cat > "${LCasePass}/logs/win_preflight_latest.json" <<'EOM'
{
  "checked_at_utc": "2026-05-17T05:28:29Z",
  "status": "PASS",
  "code": "OK",
  "exit_code": 0
}
EOM

"${LCasePass}/print_windows_b07_closeout_3cmd.sh" SIMD-REHEARSAL-OK > "${LCasePass}/stdout.txt"

if grep -F -- "[CLOSEOUT] WARN latest preflight is RECENT_BILLING_BLOCK" "${LCasePass}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: pass case should not emit billing warning"
  cat "${LCasePass}/stdout.txt"
  exit 1
fi

if ! grep -F -- "closeout-release SIMD-REHEARSAL-OK" "${LCasePass}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: pass case missing batch id substitution"
  cat "${LCasePass}/stdout.txt"
  exit 1
fi

if ! grep -F -- "native Windows \`lazbuild.exe\`" "${LCasePass}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: pass case missing native lazbuild requirement"
  cat "${LCasePass}/stdout.txt"
  exit 1
fi

if ! grep -F -- "当前本机 Wine 不属于这种环境，不要把它当成 host-side Unix bridge 逃生口。" "${LCasePass}/stdout.txt" >/dev/null; then
  echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] FAILED: pass case missing bash-gate/Wine caveat"
  cat "${LCasePass}/stdout.txt"
  exit 1
fi

echo "[WIN-CLOSEOUT-3CMD-REHEARSAL] OK"
