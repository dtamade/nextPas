#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

factory_file="core/src/nextpas.core.tls.factory.pas"
openssl_file="core/src/nextpas.core.tls.openssl.backed.pas"
wolfssl_file="core/src/nextpas.core.tls.wolfssl.lib.pas"
winssl_file="core/src/nextpas.core.tls.winssl.lib.pas"
freepascal_file="core/src/nextpas.core.tls.freepascal.lib.pas"
mbedtls_file="core/src/nextpas.core.tls.mbedtls.lib.pas"

printf '[TEST] factory config verify-mode empty-set semantics contract\n'

require_fixed "$factory_file" "Result.SetVerifyMode(LVerifyMode);" \
  "factory one-shot config path must apply caller-provided VerifyMode even when it is an empty set"
require_fixed "$openssl_file" "if LVerifyMode <> Result.GetVerifyMode then" \
  "OpenSSL direct-library path must compare VerifyMode against current context value instead of treating empty set as unset"
require_fixed "$wolfssl_file" "Result.SetVerifyMode(LVerifyMode);" \
  "WolfSSL direct-library path must apply caller-provided VerifyMode even when it is an empty set"
require_fixed "$winssl_file" "Result.SetVerifyMode(LVerifyMode);" \
  "WinSSL direct-library path must apply caller-provided VerifyMode even when it is an empty set"
require_fixed "$freepascal_file" "Result.SetVerifyMode(LVerifyMode);" \
  "FreePascal direct-library path must apply caller-provided VerifyMode even when it is an empty set"
require_fixed "$mbedtls_file" "Result.SetVerifyMode(LVerifyMode);" \
  "MbedTLS direct-library path must apply caller-provided VerifyMode even when it is an empty set"


printf '[PASS] factory config verify-mode empty-set semantics contract passed\n'
