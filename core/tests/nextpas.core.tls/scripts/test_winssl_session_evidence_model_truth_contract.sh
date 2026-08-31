#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$message"
  else
    fail "$message" "missing fixed string in $file: $needle"
  fi
}

proof_file="core/tests/nextpas.core.tls/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL session evidence-model truth contract\n'

require_fixed "$proof_file" \
  "evidence_model public_reuse_truth=conservative_shared_path native_probe_truth=isolated_worker_opt_in" \
  "WinSSL session-resumption proof must emit a stable evidence-model marker"

require_fixed "$proof_file" \
  "native_probe_enabled=%s native_observed_reuse=%s native_probe_succeeded=%s require_reuse=%s require_native_reuse=%s session_configured=%s" \
  "WinSSL session-resumption summary must keep public truth and native-probe truth separated"














printf '[PASS] WinSSL session evidence-model truth contract passed\n'
