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
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

proof_file="tests/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL native-probe stage markers contract\n'

require_match "$proof_file" \
  'function TryQueryNativeSessionReuse\(const AConn: ISSLConnection;\s*const ALabel: string;' \
  'WinSSL native probe helper accepts an explicit label for stage-level evidence'

require_match "$proof_file" \
  'native_probe label=%s stage=before_supports' \
  'WinSSL native probe emits a marker before the owner-surface Supports check'

require_match "$proof_file" \
  'native_probe label=%s stage=after_supports' \
  'WinSSL native probe emits a marker after the owner-surface Supports check succeeds'

require_match "$proof_file" \
  'native_probe label=%s stage=before_get_native_handle' \
  'WinSSL native probe emits a marker before GetNativeHandle'

require_match "$proof_file" \
  'native_probe label=%s stage=after_get_native_handle handle_nil=%s' \
  'WinSSL native probe emits a marker after GetNativeHandle and records whether the handle is nil'

require_match "$proof_file" \
  'native_probe label=%s stage=before_query_context_attributes' \
  'WinSSL native probe emits a marker immediately before QueryContextAttributesW'

require_match "$proof_file" \
  'native_probe label=%s stage=after_query_context_attributes status=0x%x reused=%s flags=0x%x' \
  'WinSSL native probe emits a marker after QueryContextAttributesW returns successfully'

require_match "$proof_file" \
  'native_probe label=%s stage=query_failed status=0x%x' \
  'WinSSL native probe emits a marker when QueryContextAttributesW returns a failing status'

require_match "$proof_file" \
  'native_probe label=%s stage=exception class=%s message=%s' \
  'WinSSL native probe emits a marker when the probe body raises an exception'

printf '[PASS] WinSSL native-probe stage markers contract passed\n'
