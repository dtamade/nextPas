#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_present() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_match() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$message"
  fi
}

base_file="src/nextpas.core.tls.base.pas"
openssl_ssl_api="src/nextpas.core.tls.openssl.api.ssl.pas"
openssl_lib="src/nextpas.core.tls.openssl.backed.pas"
openssl_ctx="src/nextpas.core.tls.openssl.context.pas"
winssl_lib="src/nextpas.core.tls.winssl.lib.pas"
winssl_ctx="src/nextpas.core.tls.winssl.context.pas"
winssl_conn="src/nextpas.core.tls.winssl.connection.pas"
freepascal_lib="src/nextpas.core.tls.freepascal.lib.pas"
freepascal_ctx="src/nextpas.core.tls.freepascal.context.pas"
freepascal_conn="src/nextpas.core.tls.freepascal.connection.pas"
freepascal_validation="src/nextpas.core.tls.freepascal.connection.validation.inc"
wolfssl_lib="src/nextpas.core.tls.wolfssl.lib.pas"
wolfssl_ctx="src/nextpas.core.tls.wolfssl.context.pas"
wolfssl_conn="src/nextpas.core.tls.wolfssl.connection.pas"
mbedtls_lib="src/nextpas.core.tls.mbedtls.lib.pas"
mbedtls_ctx="src/nextpas.core.tls.mbedtls.context.pas"
mbedtls_conn="src/nextpas.core.tls.mbedtls.connection.pas"

echo "[TEST] callback capability truth contract"

require_present "$base_file" "SupportsCallbacks: Boolean;" \
  "base capability record must continue to expose SupportsCallbacks"

require_match "$openssl_ssl_api" \
  "function OpenSSLPublishedContextCallbackSurfaceReady: Boolean;.*?Assigned\\(SSL_CTX_set_cert_verify_callback\\).*?Assigned\\(SSL_CTX_set_default_passwd_cb\\).*?Assigned\\(SSL_CTX_set_default_passwd_cb_userdata\\).*?Assigned\\(SSL_CTX_set_info_callback\\)" \
  "OpenSSL callback publication helper must require verify/password/userdata/info runtime helpers together"
require_absent "$openssl_lib" "Result.SupportsCallbacks := True;" \
  "OpenSSL must not publish SupportsCallbacks unconditionally"
require_present "$openssl_lib" "Result.SupportsCallbacks := OpenSSLPublishedContextCallbackSurfaceReady;" \
  "OpenSSL published callback capability must follow the runtime callback-surface gate"
require_present "$openssl_ctx" "SSL_CTX_set_cert_verify_callback(FSSLContext, @VerifyCertificateCallback, Self)" \
  "OpenSSL verify callback wiring must remain live"
require_present "$openssl_ctx" "SSL_CTX_set_default_passwd_cb(FSSLContext, @PasswordCallbackThunk);" \
  "OpenSSL password callback wiring must remain live"
require_present "$openssl_ctx" "SSL_CTX_set_default_passwd_cb_userdata(FSSLContext, Self);" \
  "OpenSSL password callback publication must continue to bind userdata for thunk dispatch"
require_present "$openssl_ctx" "SSL_CTX_set_info_callback(FSSLContext, @InfoCallbackThunk)" \
  "OpenSSL info callback wiring must remain live"

require_present "$winssl_lib" "Result.SupportsCallbacks := True;" \
  "WinSSL capability truth must publish SupportsCallbacks while runtime callback wiring exists"
require_present "$winssl_ctx" "function TWinSSLContext.GetWinSSLVerifyCallback: TSSLVerifyCallback;" \
  "WinSSL context must still expose verify callback accessors"
require_present "$winssl_ctx" "function TWinSSLContext.GetWinSSLInfoCallback: TSSLInfoCallback;" \
  "WinSSL context must still expose info callback accessors"
require_present "$winssl_conn" "LCallback := LContextAccess.GetWinSSLInfoCallback;" \
  "WinSSL connection must still consume the published info callback runtime path"
require_present "$winssl_conn" "LVerifyCallback := LContextAccess.GetWinSSLVerifyCallback;" \
  "WinSSL connection must still consume the published verify callback runtime path"

require_present "$freepascal_lib" "Result.SupportsCallbacks := True;" \
  "FreePascal must publish SupportsCallbacks while verify callback runtime wiring exists"
require_present "$freepascal_ctx" "function GetVerifyCallback: TSSLVerifyCallback;" \
  "FreePascal context must expose verify callback accessors"
require_present "$freepascal_validation" "LVerifyCallback := LVerifyCallbackAccess.GetVerifyCallback;" \
  "FreePascal connection validation must consume the published verify callback runtime path"
require_absent "$freepascal_conn" "InfoCallback" \
  "FreePascal connection runtime must stay info-callback-free while only verify callback is published"
require_absent "$freepascal_conn" "PasswordCallback" \
  "FreePascal connection runtime must stay password-callback-free while only verify callback is published"
require_present "$freepascal_ctx" "procedure TFreePascalContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);" \
  "FreePascal setter surface must remain present for interface compatibility"

require_present "$wolfssl_lib" "Result.SupportsCallbacks := False;" \
  "WolfSSL must not publish SupportsCallbacks before callback runtime wiring exists"
require_absent "$wolfssl_conn" "VerifyCallback" \
  "WolfSSL connection runtime must stay callback-free while SupportsCallbacks is false"
require_absent "$wolfssl_conn" "InfoCallback" \
  "WolfSSL connection runtime must stay info-callback-free while SupportsCallbacks is false"
require_absent "$wolfssl_conn" "PasswordCallback" \
  "WolfSSL connection runtime must stay password-callback-free while SupportsCallbacks is false"
require_present "$wolfssl_ctx" "procedure TWolfSSLContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);" \
  "WolfSSL setter surface must remain present for interface compatibility"

require_present "$mbedtls_lib" "Result.SupportsCallbacks := False;" \
  "MbedTLS must not publish SupportsCallbacks before callback runtime wiring exists"
require_absent "$mbedtls_conn" "VerifyCallback" \
  "MbedTLS connection runtime must stay callback-free while SupportsCallbacks is false"
require_absent "$mbedtls_conn" "InfoCallback" \
  "MbedTLS connection runtime must stay info-callback-free while SupportsCallbacks is false"
require_absent "$mbedtls_conn" "PasswordCallback" \
  "MbedTLS connection runtime must stay password-callback-free while SupportsCallbacks is false"
require_present "$mbedtls_ctx" "procedure TMbedTLSContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);" \
  "MbedTLS setter surface must remain present for interface compatibility"

echo "[PASS] callback capability truth remains aligned with runtime/source classification"
