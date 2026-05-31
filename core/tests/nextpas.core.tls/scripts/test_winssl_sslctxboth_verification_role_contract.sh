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

require_absent() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$name" "unexpected pattern still present in $file: $pattern"
  else
    pass "$name"
  fi
}

connection_file="src/nextpas.core.tls.winssl.connection.pas"

require_match "$connection_file" \
  'FPeerValidationRoleKnown: Boolean;\s+FPeerValidationRoleIsClient: Boolean;' \
  'winssl connection stores explicit peer-validation role state'
require_match "$connection_file" \
  'procedure RememberPeerValidationRole\(AIsClient: Boolean\);' \
  'winssl connection declares explicit peer-validation role recorder'
require_match "$connection_file" \
  'function TryResolvePeerValidationRole\(out AIsClient: Boolean\): Boolean;' \
  'winssl connection declares peer-validation role resolver'
require_match "$connection_file" \
  'function ValidatePeerCertificate\(AIsClient: Boolean;\s+out AVerifyError: Integer\): Boolean;' \
  'winssl certificate validation accepts explicit client-server role'
require_absent "$connection_file" \
  'function ValidatePeerCertificate\(out AVerifyError: Integer\): Boolean;' \
  'legacy role-less winssl certificate validation signature is removed'
require_match "$connection_file" \
  'function TWinSSLConnection\.DoConnect: Boolean;.*?RememberPeerValidationRole\(True\);.*?ValidatePeerCertificate\(True,\s*LVerifyError\)' \
  'explicit Connect records and uses client validation role'
require_match "$connection_file" \
  'function TWinSSLConnection\.DoAccept: Boolean;.*?RememberPeerValidationRole\(False\);.*?ValidatePeerCertificate\(False,\s*LVerifyError\)' \
  'explicit Accept records and uses server validation role'
require_match "$connection_file" \
  'function TWinSSLConnection\.DoGetVerifyResult: Integer;.*?TryResolvePeerValidationRole\(LIsClient\).*?ValidatePeerCertificate\(LIsClient,\s*LVerifyError\)' \
  'verify-result getter reuses resolved peer-validation role'
require_absent "$connection_file" \
  'LNeedCert := \(LContextType = sslCtxClient\) or \(sslVerifyFailIfNoPeerCert in LVerifyMode\);' \
  'peer certificate requirement no longer depends on strict context equality'
require_absent "$connection_file" \
  'if \(LContextType = sslCtxClient\) and\s+not \(sslCertVerifyIgnoreHostname in LVerifyFlags\) then' \
  'hostname verification no longer depends on strict context equality'
require_absent "$connection_file" \
  'if LContextType = sslCtxServer then\s+LSSLExtra\.dwAuthType := AUTHTYPE_CLIENT\s+else\s+LSSLExtra\.dwAuthType := AUTHTYPE_SERVER;' \
  'chain policy auth type no longer depends on strict context equality'
