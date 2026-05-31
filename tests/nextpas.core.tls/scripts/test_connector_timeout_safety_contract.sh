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

tls_file="src/nextpas.core.tls.tls.pas"
builder_file="src/nextpas.core.tls.connection.builder.pas"
integration_doc="docs/INTEGRATION_GUIDE.md"
migration_doc="docs/guides/MIGRATION_GUIDE.md"
example_simple="tests/examples/test_real_websites.pas"
example_enhanced="tests/examples/test_real_websites_enhanced.pas"
example_comprehensive="tests/examples/test_real_websites_comprehensive.pas"
contract_src="tests/contract/test_connector_timeout_safety_entry.pas"
build_root="tmp/test_connector_timeout_safety_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_connector_timeout_safety_entry"

printf '[TEST] connector timeout safety contract\n'

require_fixed "$tls_file" "function WithTimeout(const ATimeout: TTimeoutDuration): TSSLConnector; overload;" \
  "connector must export TTimeoutDuration overload"
require_fixed "$tls_file" "function WithTimeout(const ATimeout: TTimeoutDuration): TSSLAcceptor; overload;" \
  "acceptor must export TTimeoutDuration overload"
require_fixed "$builder_file" "function WithTimeout(const ATimeout: TTimeoutDuration): ISSLConnectionBuilder; overload;" \
  "connection builder must export TTimeoutDuration overload"
require_fixed "$tls_file" "Timeout duration exceeds Integer millisecond range" \
  "TLS facade must guard timeout overflow during type-safe bridge"
require_fixed "$builder_file" "Timeout duration exceeds Integer millisecond range" \
  "connection builder must guard timeout overflow during type-safe bridge"
require_fixed "$integration_doc" "TLS := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "integration guide must show type-safe connector timeout"
require_fixed "$migration_doc" "LTLS := TSSLConnector.FromContext(LContext).WithTimeout(TTimeoutDuration.Seconds(15))" \
  "migration guide must show type-safe connector timeout"
require_fixed "$example_simple" "Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "simple website example must adopt type-safe timeout"
require_fixed "$example_enhanced" "Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "enhanced website example must adopt type-safe timeout"
require_fixed "$example_comprehensive" "Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "comprehensive website example must adopt type-safe timeout"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "connector timeout safety contract source must compile"
fi

"$binary"

printf '[PASS] connector timeout safety contract passed\n'
