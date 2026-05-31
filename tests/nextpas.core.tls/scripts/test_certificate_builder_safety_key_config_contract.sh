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

builder="src/nextpas.core.tls.cert.builder.pas"
impl="src/nextpas.core.tls.cert.builder.impl.pas"
cert_facade="src/nextpas.core.tls.cert.pas"
quick="src/nextpas.core.tls.quick.pas"
readme="README.md"
contract_src="tests/contract/test_certificate_builder_safety_key_config_entry.pas"
build_root="tmp/test_certificate_builder_safety_key_config_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_certificate_builder_safety_key_config_entry"

printf '[TEST] certificate builder safety key config contract\n'

require_fixed "$builder" "function WithRSAKey(const ASize: TKeySize): ICertificateBuilder; overload;" \
  "builder interface must export TKeySize overload"
require_fixed "$builder" "function WithECDSAKey(ACurve: TEllipticCurve): ICertificateBuilder; overload;" \
  "builder interface must export TEllipticCurve overload"
require_fixed "$impl" "function WithRSAKey(const ASize: TKeySize): ICertificateBuilder;" \
  "builder implementation must support TKeySize overload"
require_fixed "$impl" "function WithECDSAKey(ACurve: TEllipticCurve): ICertificateBuilder;" \
  "builder implementation must support TEllipticCurve overload"
require_fixed "$impl" "ECDSA certificate keys do not support X25519/X448 curves" \
  "builder implementation must reject ECDH-only curves for ECDSA cert keys"
require_fixed "$cert_facade" ".WithRSAKey(TKeySize.Bits(2048))" \
  "high-level certificate facade must adopt type-safe RSA config"
require_fixed "$cert_facade" ".WithECDSAKey(ec_P256)" \
  "high-level certificate facade must adopt type-safe ECDSA config"
require_fixed "$quick" ".WithRSAKey(TKeySize.Bits(2048))" \
  "quick helper must adopt type-safe RSA config"
require_fixed "$quick" ".WithRSAKey(TKeySize.Bits(4096))" \
  "quick CA helper must adopt type-safe RSA config"
require_fixed "$readme" "  fafafa.ssl," \
  "README certificate example must import the facade type-safe surface"
require_fixed "$readme" '.WithRSAKey(TKeySize.Bits(2048))' \
  "README certificate example must show type-safe RSA config"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "certificate builder safety-key contract source must compile"
fi

"$binary"

printf '[PASS] certificate builder safety key config contract passed\n'
