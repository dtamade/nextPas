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

api_file="src/nextpas.core.tls.wolfssl.api.pas"
context_file="src/nextpas.core.tls.wolfssl.context.pas"
connection_file="src/nextpas.core.tls.wolfssl.connection.pas"
lib_file="src/nextpas.core.tls.wolfssl.lib.pas"

require_match "$api_file" \
  'TwolfSSL_UseOCSPStapling = function\(ssl: PWOLFSSL;\s*statusType: Byte;\s*options: Byte\): Integer; cdecl;' \
  'wolfSSL_UseOCSPStapling binding uses status_type + options signature'
require_match "$api_file" \
  'TwolfSSL_CTX_UseOCSPStapling = function\(ctx: PWOLFSSL_CTX;\s*statusType: Byte;\s*options: Byte\): Integer; cdecl;' \
  'wolfSSL_CTX_UseOCSPStapling binding is present'
require_match "$api_file" \
  'TwolfSSL_set_tlsext_status_ocsp_resp = function\(ssl: PWOLFSSL;\s*resp: PByte;\s*len: Integer\): PtrInt; cdecl;' \
  'wolfSSL_set_tlsext_status_ocsp_resp binding is present'
require_match "$api_file" \
  'TwolfSSL_CTX_set_tlsext_status_cb = function\(ctx: PWOLFSSL_CTX;\s*cb: TwolfSSL_tlsextStatusCb\): Integer; cdecl;' \
  'wolfSSL_CTX_set_tlsext_status_cb binding is present'
require_match "$api_file" \
  'TwolfSSL_CTX_set_tlsext_status_arg = function\(ctx: PWOLFSSL_CTX;\s*arg: Pointer\): PtrInt; cdecl;' \
  'wolfSSL_CTX_set_tlsext_status_arg binding is present'
require_match "$api_file" \
  "GetProc\\('wolfSSL_CTX_set_tlsext_status_cb'\\)" \
  'wolfSSL_CTX_set_tlsext_status_cb is loaded dynamically'
require_match "$api_file" \
  "GetProc\\('wolfSSL_set_tlsext_status_ocsp_resp'\\)" \
  'wolfSSL_set_tlsext_status_ocsp_resp is loaded dynamically'

require_match "$context_file" \
  'function WolfSSLServerOCSPStaplingStatusCallback\(ssl: PWOLFSSL;\s*arg: Pointer\): Integer; cdecl;' \
  'server stapling callback function exists'
require_match "$context_file" \
  'wolfSSL_CTX_set_tlsext_status_cb\(FWolfSSLCtx,\s*@WolfSSLServerOCSPStaplingStatusCallback\)' \
  'server context registers stapling callback'
require_match "$context_file" \
  'wolfSSL_set_tlsext_status_ocsp_resp\(ssl,\s*LResponseCopy,\s*Length\(LResponse\)\)' \
  'server callback injects stapled response into native WolfSSL handle'
require_match "$context_file" \
  'Result := fafafa\.ssl\.wolfssl\.connection\.TWolfSSLConnection\.Create\(Self,\s*ASocket\);' \
  'server context socket connection path uses modern WolfSSL connection unit'
require_match "$context_file" \
  'Result := fafafa\.ssl\.wolfssl\.connection\.TWolfSSLConnection\.Create\(Self,\s*AStream\);' \
  'server context stream connection path uses modern WolfSSL connection unit'

require_match "$connection_file" \
  'wolfSSL_UseOCSPStapling\(FWolfSSL,\s*WOLFSSL_CSR_OCSP,\s*WOLFSSL_CSR_OCSP_USE_NONCE\)' \
  'client connection requests OCSP stapling before handshake'
require_match "$connection_file" \
  'function TWolfSSLConnection\.DoGetOCSPStaplingEnabled: Boolean;.*?Result := Length\(DoGetOCSPResponse\) > 0;' \
  'connection OCSP enabled surface is based on actual stapled response presence'

require_match "$lib_file" \
  'Result\.OCSPStaplingSupport := sslSupportExperimental' \
  'WolfSSL OCSP stapling capability is downgraded to experimental'
require_absent "$lib_file" \
  'Result\.OCSPStaplingSupport := sslSupportStable' \
  'WolfSSL OCSP stapling capability no longer claims stable support'
