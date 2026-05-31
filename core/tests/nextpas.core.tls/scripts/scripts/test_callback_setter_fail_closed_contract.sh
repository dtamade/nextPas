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

base_file="src/nextpas.core.tls.base.pas"
api_reference_file="docs/reference/API_REFERENCE.md"
openssl_ctx="src/nextpas.core.tls.openssl.context.pas"
freepascal_ctx="src/nextpas.core.tls.freepascal.context.pas"
wolfssl_ctx="src/nextpas.core.tls.wolfssl.context.pas"
mbedtls_ctx="src/nextpas.core.tls.mbedtls.context.pas"

echo "[TEST] callback setter fail-closed contract"

require_fixed "$base_file" \
  "在安装非 nil 的 verify/password/info callback 前，先检查 ISSLLibrary.GetCapabilities.SupportsCallbacks；对 SupportsCallbacks=False 的 backend，non-nil 赋值应抛出 unsupported，nil 仅用于清除并回到默认行为。" \
  "base interface docs must explain callback capability gating and nil-clear semantics"

require_fixed "$api_reference_file" \
  '在安装非 nil 的 Verify/Password/Info callback 前，先检查 `ISSLLibrary.GetCapabilities.SupportsCallbacks`；对 `SupportsCallbacks=False` 的 backend，non-nil 赋值应抛出 unsupported，`nil` 仅用于清除并回到默认行为。' \
  "API reference must explain callback capability gating and nil-clear semantics"

require_match "$api_reference_file" \
  'TSSLVerifyCallback = function\(const aCertificate: TSSLCertificateInfo;\s*const aErrorCode: Integer;\s*const aErrorMessage: string\): Boolean of object;' \
  "API reference must publish the current TSSLVerifyCallback signature"
require_match "$api_reference_file" \
  'TSSLPasswordCallback = function\(var aPassword: string;\s*const aIsRetry: Boolean\): Boolean of object;' \
  "API reference must publish the current TSSLPasswordCallback signature"
require_match "$api_reference_file" \
  'TSSLInfoCallback = procedure\(const aWhere: Integer;\s*const aRet: Integer;\s*const aState: string\) of object;' \
  "API reference must publish the current TSSLInfoCallback signature"

require_match "$openssl_ctx" \
  "procedure TOpenSSLContext\\.SetVerifyCallback\\(ACallback: TSSLVerifyCallback\\);.*?if Assigned\\(ACallback\\) then.*?RequirePublishedOpenSSLContextCallbackSurface\\('TOpenSSLContext\\.SetVerifyCallback'\\);" \
  "OpenSSL verify callback setter must guard non-nil assignment behind the published callback-surface gate"
require_match "$openssl_ctx" \
  "procedure TOpenSSLContext\\.SetPasswordCallback\\(ACallback: TSSLPasswordCallback\\);.*?if Assigned\\(ACallback\\) then.*?RequirePublishedOpenSSLContextCallbackSurface\\('TOpenSSLContext\\.SetPasswordCallback'\\);" \
  "OpenSSL password callback setter must guard non-nil assignment behind the published callback-surface gate"
require_match "$openssl_ctx" \
  "procedure TOpenSSLContext\\.SetInfoCallback\\(ACallback: TSSLInfoCallback\\);.*?if Assigned\\(ACallback\\) then.*?RequirePublishedOpenSSLContextCallbackSurface\\('TOpenSSLContext\\.SetInfoCallback'\\);" \
  "OpenSSL info callback setter must guard non-nil assignment behind the published callback-surface gate"

require_match "$freepascal_ctx" \
  "procedure TFreePascalContext\\.SetVerifyCallback\\(ACallback: TSSLVerifyCallback\\);.*?FVerifyCallback := ACallback;" \
  "FreePascal verify callback setter must store non-nil assignments"
require_match "$freepascal_ctx" \
  "function TFreePascalContext\\.GetVerifyCallback: TSSLVerifyCallback;.*?Result := FVerifyCallback;" \
  "FreePascal verify callback getter must return the stored callback"
require_match "$freepascal_ctx" \
  "procedure TFreePascalContext\\.SetPasswordCallback\\(ACallback: TSSLPasswordCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Password callback', 'TFreePascalContext\\.SetPasswordCallback'\\);.*?FPasswordCallback := nil;" \
  "FreePascal password callback setter must fail-closed on non-nil assignment"
require_match "$freepascal_ctx" \
  "procedure TFreePascalContext\\.SetInfoCallback\\(ACallback: TSSLInfoCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Info callback', 'TFreePascalContext\\.SetInfoCallback'\\);.*?FInfoCallback := nil;" \
  "FreePascal info callback setter must fail-closed on non-nil assignment"

require_match "$wolfssl_ctx" \
  "procedure TWolfSSLContext\\.SetVerifyCallback\\(ACallback: TSSLVerifyCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Verify callback', 'TWolfSSLContext\\.SetVerifyCallback'\\);.*?FVerifyCallback := nil;" \
  "WolfSSL verify callback setter must fail-closed on non-nil assignment"
require_match "$wolfssl_ctx" \
  "procedure TWolfSSLContext\\.SetPasswordCallback\\(ACallback: TSSLPasswordCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Password callback', 'TWolfSSLContext\\.SetPasswordCallback'\\);.*?FPasswordCallback := nil;" \
  "WolfSSL password callback setter must fail-closed on non-nil assignment"
require_match "$wolfssl_ctx" \
  "procedure TWolfSSLContext\\.SetInfoCallback\\(ACallback: TSSLInfoCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Info callback', 'TWolfSSLContext\\.SetInfoCallback'\\);.*?FInfoCallback := nil;" \
  "WolfSSL info callback setter must fail-closed on non-nil assignment"

require_match "$mbedtls_ctx" \
  "procedure TMbedTLSContext\\.SetVerifyCallback\\(ACallback: TSSLVerifyCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Verify callback', 'TMbedTLSContext\\.SetVerifyCallback'\\);.*?FVerifyCallback := nil;" \
  "MbedTLS verify callback setter must fail-closed on non-nil assignment"
require_match "$mbedtls_ctx" \
  "procedure TMbedTLSContext\\.SetPasswordCallback\\(ACallback: TSSLPasswordCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Password callback', 'TMbedTLSContext\\.SetPasswordCallback'\\);.*?FPasswordCallback := nil;" \
  "MbedTLS password callback setter must fail-closed on non-nil assignment"
require_match "$mbedtls_ctx" \
  "procedure TMbedTLSContext\\.SetInfoCallback\\(ACallback: TSSLInfoCallback\\);.*?if Assigned\\(ACallback\\) then.*?RejectUnsupportedCallbackAssignment\\('Info callback', 'TMbedTLSContext\\.SetInfoCallback'\\);.*?FInfoCallback := nil;" \
  "MbedTLS info callback setter must fail-closed on non-nil assignment"

echo "[PASS] callback setter fail-closed contract passed"
