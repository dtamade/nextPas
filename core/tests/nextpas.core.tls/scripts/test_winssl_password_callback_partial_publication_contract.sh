#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$message"
  fi
}

require_fixed() {
  local file="$1"
  local text="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$text" "$file"; then
    fail "$message"
  fi
}

winssl_ctx="src/nextpas.core.tls.winssl.context.pas"
winssl_test="tests/unit/test_winssl_comprehensive.pas"
callback_runtime_contract="tests/test_backend_callback_setter_fail_closed_contract.pas"
api_reference_file="docs/reference/API_REFERENCE.md"
winssl_design_file="docs/reference/WINSSL_DESIGN.md"

echo "[TEST] WinSSL password callback partial-publication contract"

require_match "$winssl_ctx" \
  "procedure TWinSSLContext\\.SetPasswordCallback\\(ACallback: TSSLPasswordCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Password callback', 'TWinSSLContext\\.SetPasswordCallback'\\);.*?FPasswordCallback := nil;" \
  "WinSSL password callback setter must fail-closed on non-nil assignment"
require_match "$winssl_ctx" \
  "procedure TWinSSLContext\\.SetVerifyCallback\\(ACallback: TSSLVerifyCallback\\);.*?FVerifyCallback := ACallback;" \
  "WinSSL verify callback setter must remain published"
require_match "$winssl_ctx" \
  "procedure TWinSSLContext\\.SetInfoCallback\\(ACallback: TSSLInfoCallback\\);.*?FInfoCallback := ACallback;" \
  "WinSSL info callback setter must remain published"

require_fixed "$api_reference_file" \
  'SupportsCallbacks=True 只表示至少一条 published context callback path 存在；具体 callback 种类仍可能 backend-specific。当前 WinSSL 仅发布 verify/info runtime path，password callback 仍为 unsupported。' \
  "API reference must record the current WinSSL partial callback publication truth"
require_fixed "$winssl_design_file" \
  '- 当前 published callback surface = verify/info；password callback 仍未接入 WinSSL runtime，non-nil assignment 应 fail-closed 为 unsupported' \
  "WinSSL design doc must record password callback unsupported truth"

require_match "$winssl_test" \
  "LContext\\.SetVerifyCallback\\(@LCallbacks\\.VerifyCallback\\);.*?Pass\\('Verify callback set'\\);.*?try.*?LContext\\.SetPasswordCallback\\(@LCallbacks\\.PasswordCallback\\);.*?Fail\\('Password callback', 'Expected unsupported semantics for WinSSL password callback'\\);.*?on E: ESSLException do.*?Pass\\('Password callback unsupported as expected'\\);.*?LContext\\.SetInfoCallback\\(@LCallbacks\\.InfoCallback\\);.*?Pass\\('Info callback set'\\);" \
  "WinSSL comprehensive test must expect password callback unsupported while verify/info remain published"

require_fixed "$callback_runtime_contract" \
  "CheckWinSSLPartialBackend(sslWinSSL);" \
  "callback runtime contract must special-case WinSSL partial callback publication"

echo "[PASS] WinSSL password callback partial-publication contract passed"
