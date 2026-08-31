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

tls_file="core/src/nextpas.core.tls.tls.pas"
builder_file="core/src/nextpas.core.tls.connection.builder.pas"
example_simple="core/tests/nextpas.core.tls/examples/test_real_websites.pas"
example_enhanced="core/tests/nextpas.core.tls/examples/test_real_websites_enhanced.pas"
example_comprehensive="core/tests/nextpas.core.tls/examples/test_real_websites_comprehensive.pas"

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
require_fixed "$example_simple" "Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "simple website example must adopt type-safe timeout"
require_fixed "$example_enhanced" "Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "enhanced website example must adopt type-safe timeout"
require_fixed "$example_comprehensive" "Connector := TSSLConnector.FromContext(Ctx).WithTimeout(TTimeoutDuration.Seconds(15));" \
  "comprehensive website example must adopt type-safe timeout"


printf '[PASS] connector timeout safety contract passed\n'
