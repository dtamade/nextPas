#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
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

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n -P --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

proof_file="tests/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL native-probe control-query boundary contract\n'

require_match "$proof_file" \
  'function TryQueryConnectionInfoControl\(\s*ACtxtHandle: PCtxtHandle;\s*out AConnectionInfo: TSecPkgContext_ConnectionInfo;\s*out AStatus: SECURITY_STATUS\s*\): Boolean;' \
  'WinSSL proof defines a dedicated control-query helper for connection info'

require_match "$proof_file" \
  'AStatus := QueryContextAttributesW\(ACtxtHandle,\s*SECPKG_ATTR_CONNECTION_INFO,\s*@AConnectionInfo\);' \
  'WinSSL control-query helper probes connection info through QueryContextAttributesW'

require_match "$proof_file" \
  'native_probe label=%s stage=before_control_query attribute=connection_info' \
  'WinSSL native probe emits a marker before the control query'

require_match "$proof_file" \
  'native_probe label=%s stage=after_control_query status=0x%x protocol=0x%x cipher=0x%x' \
  'WinSSL native probe emits a marker after the control query succeeds'

require_match "$proof_file" \
  'native_probe label=%s stage=control_query_failed status=0x%x' \
  'WinSSL native probe emits a marker when the control query returns a failing status'

printf '[PASS] WinSSL native-probe control-query boundary contract passed\n'
