#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
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

factory_file="src/nextpas.core.tls.factory.pas"
openssl_file="src/nextpas.core.tls.openssl.backed.pas"
wolfssl_file="src/nextpas.core.tls.wolfssl.lib.pas"
winssl_file="src/nextpas.core.tls.winssl.lib.pas"
freepascal_file="src/nextpas.core.tls.freepascal.lib.pas"
mbedtls_file="src/nextpas.core.tls.mbedtls.lib.pas"
contract_src="tests/contract/test_factory_config_verifymode_empty_set_entry.pas"
build_root="tmp/test_factory_config_verifymode_empty_set_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_factory_config_verifymode_empty_set_entry"

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

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "factory verify-mode empty-set contract source must compile"
fi

"$binary"

printf '[PASS] factory config verify-mode empty-set semantics contract passed\n'
