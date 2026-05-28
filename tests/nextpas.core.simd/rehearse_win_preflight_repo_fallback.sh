#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PREFLIGHT_SCRIPT="${ROOT}/preflight_windows_b07_evidence_gh.sh"

if [[ ! -f "${PREFLIGHT_SCRIPT}" ]]; then
  echo "[PREFLIGHT-REPO-FALLBACK] Missing script: ${PREFLIGHT_SCRIPT}"
  exit 2
fi

LTmpRoot="$(mktemp -d)"
cleanup() {
  rm -rf "${LTmpRoot}"
}
trap cleanup EXIT

LRepoRoot="${LTmpRoot}/repo"
mkdir -p "${LRepoRoot}/tests/nextpas.core.simd" "${LTmpRoot}/bin"
cp "${PREFLIGHT_SCRIPT}" "${LRepoRoot}/tests/nextpas.core.simd/"

git -C "${LRepoRoot}" init -q
git -C "${LRepoRoot}" remote add origin "https://github.com/example/simd-fallback.git"

cat > "${LTmpRoot}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "auth" && "$2" == "status" ]]; then
  exit 0
fi

if [[ "$1" == "repo" && "$2" == "view" ]]; then
  exit 1
fi

if [[ "$1" == "workflow" && "$2" == "list" ]]; then
  cat <<'JSON'
[
  {
    "id": 1,
    "name": "simd-windows-b07-evidence",
    "path": ".github/workflows/simd-windows-b07-evidence.yml",
    "state": "active"
  }
]
JSON
  exit 0
fi

if [[ "$1" == "run" && "$2" == "list" ]]; then
  LRecentRunCreatedAtUtc="$(python3 - <<'PY'
from datetime import datetime, timedelta, timezone
print((datetime.now(timezone.utc) - timedelta(minutes=30)).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"
  cat <<JSON
[
  {
    "databaseId": 123,
    "status": "completed",
    "conclusion": "failure",
    "createdAt": "${LRecentRunCreatedAtUtc}",
    "url": "https://github.com/example/simd-fallback/actions/runs/123",
    "event": "workflow_dispatch"
  }
]
JSON
  exit 0
fi

if [[ "$1" == "run" && "$2" == "view" ]]; then
  cat <<'TEXT'
X The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings
TEXT
  exit 0
fi

if [[ "$1" == "api" ]]; then
  echo "[]"
  exit 0
fi

echo "unexpected gh args: $*" >&2
exit 2
EOF
chmod +x "${LTmpRoot}/bin/gh"

set +e
LRunOutput="$(
  cd "${LRepoRoot}" && \
  PATH="${LTmpRoot}/bin:${PATH}" \
  bash tests/nextpas.core.simd/preflight_windows_b07_evidence_gh.sh 2>&1
)"
LRunRc=$?
set -e

printf '%s\n' "${LRunOutput}"

if [[ "${LRunRc}" != "31" ]]; then
  echo "[PREFLIGHT-REPO-FALLBACK] FAILED: expected rc=31 but got ${LRunRc}"
  exit 1
fi

if grep -F -- "REPO_RESOLVE_FAILED" <<<"${LRunOutput}" >/dev/null; then
  echo "[PREFLIGHT-REPO-FALLBACK] FAILED: fallback should avoid REPO_RESOLVE_FAILED"
  exit 1
fi

if ! grep -F -- "RECENT_BILLING_BLOCK" <<<"${LRunOutput}" >/dev/null; then
  echo "[PREFLIGHT-REPO-FALLBACK] FAILED: missing billing block result"
  exit 1
fi

if ! grep -F -- '"repo": "example/simd-fallback"' "${LRepoRoot}/tests/nextpas.core.simd/logs/win_preflight_latest.json" >/dev/null; then
  echo "[PREFLIGHT-REPO-FALLBACK] FAILED: report json missing repo resolved from origin"
  cat "${LRepoRoot}/tests/nextpas.core.simd/logs/win_preflight_latest.json"
  exit 1
fi

echo "[PREFLIGHT-REPO-FALLBACK] OK"
