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

connection_file="src/nextpas.core.tls.winssl.connection.pas"

require_match "$connection_file" \
  'function TWinSSLConnection\.DoGetVerifyResult: Integer;.*?if \(FHandshakeState = sslHsNotStarted\) or \(FHandshakeState = sslHsInProgress\) then\s+Exit\(-1\);' \
  'winssl verify-result getter short-circuits fresh pre-handshake state to -1'
require_match "$connection_file" \
  'function TWinSSLConnection\.DoGetVerifyResultString: string;.*?if \(FHandshakeState = sslHsNotStarted\) or \(FHandshakeState = sslHsInProgress\) then\s+Exit\('"'Not verified'"'\);' \
  'winssl verify-result string getter surfaces Not verified before handshake completes'
require_match "$connection_file" \
  'function TWinSSLConnection\.DoGetVerifyResult: Integer;.*?TryResolvePeerValidationRole\(LIsClient\).*?ValidatePeerCertificate\(LIsClient,\s*LVerifyError\)' \
  'winssl verify-result getter still reuses explicit peer-validation role after the pre-handshake guard'

